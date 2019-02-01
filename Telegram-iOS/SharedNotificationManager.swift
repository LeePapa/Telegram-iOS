import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

private final class PollStateContext {
    let subscribers = Bag<(Bool) -> Void>()
    var disposable: Disposable?
    
    deinit {
        self.disposable?.dispose()
    }
    
    var isEmpty: Bool {
        return self.disposable == nil && self.subscribers.isEmpty
    }
}

final class SharedNotificationManager {
    private let episodeId: UInt32
    
    private let clearNotificationsManager: ClearNotificationsManager
    
    private var inForeground: Bool = false
    private var inForegroundDisposable: Disposable?
    
    private var accountsAndKeys: [(Account, Bool, MasterNotificationKey)]?
    private var accountsAndKeysDisposable: Disposable?
    
    private var encryptedNotifications: [[AnyHashable: Any]] = []
    
    private var pollStateContexts: [AccountRecordId: PollStateContext] = [:]
    
    init(episodeId: UInt32, clearNotificationsManager: ClearNotificationsManager, inForeground: Signal<Bool, NoError>, accounts: Signal<[(Account, Bool)], NoError>) {
        assert(Queue.mainQueue().isCurrent())
        
        self.episodeId = episodeId
        self.clearNotificationsManager = clearNotificationsManager
        
        self.inForegroundDisposable = (inForeground
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inForeground = value
        })
        
        self.accountsAndKeysDisposable = (accounts
        |> mapToSignal { accounts -> Signal<[(Account, Bool, MasterNotificationKey)], NoError> in
            let signals = accounts.map { account, isCurrent -> Signal<(Account, Bool, MasterNotificationKey), NoError> in
                return masterNotificationsKey(account: account, ignoreDisabled: true)
                |> map { key -> (Account, Bool, MasterNotificationKey) in
                    return (account, isCurrent, key)
                }
            }
            return combineLatest(signals)
        }
        |> deliverOnMainQueue).start(next: { [weak self] accountsAndKeys in
            guard let strongSelf = self else {
                return
            }
            let shouldProcess = strongSelf.accountsAndKeys == nil
            strongSelf.accountsAndKeys = accountsAndKeys
            if shouldProcess {
                strongSelf.process()
            }
        })
    }
    
    deinit {
        self.inForegroundDisposable?.dispose()
        self.accountsAndKeysDisposable?.dispose()
    }
    
    func isPollingState(accountId: AccountRecordId) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let context: PollStateContext
            if let current = self.pollStateContexts[accountId] {
                context = current
            } else {
                context = PollStateContext()
                self.pollStateContexts[accountId] = context
            }
            subscriber.putNext(context.disposable != nil)
            let index = context.subscribers.add({ value in
                subscriber.putNext(value)
            })
            
            return ActionDisposable { [weak context] in
                Queue.mainQueue().async {
                    if let current = self.pollStateContexts[accountId], current === context {
                        current.subscribers.remove(index)
                        if current.isEmpty {
                            self.pollStateContexts.removeValue(forKey: accountId)
                        }
                    }
                }
            }
        }
    }
    
    private func beginPollingState(account: Account) {
        let accountId = account.id
        let context: PollStateContext
        if let current = self.pollStateContexts[accountId] {
            context = current
        } else {
            context = PollStateContext()
            self.pollStateContexts[accountId] = context
        }
        let previousDisposable = context.disposable
        context.disposable = (account.stateManager.pollStateUpdateCompletion()
        |> deliverOnMainQueue).start(next: { [weak self, weak context] _ in
            guard let strongSelf = self else {
                return
            }
            if let current = strongSelf.pollStateContexts[accountId], current === context {
                if let disposable = current.disposable {
                    disposable.dispose()
                    current.disposable = nil
                    for f in current.subscribers.copyItems() {
                        f(false)
                    }
                }
                if current.isEmpty {
                    strongSelf.pollStateContexts.removeValue(forKey: accountId)
                }
            }
        })
        previousDisposable?.dispose()
        if previousDisposable == nil {
            for f in context.subscribers.copyItems() {
                f(true)
            }
        }
    }
    
    func addEncryptedNotification(_ dict: [AnyHashable: Any]) {
        self.encryptedNotifications.append(dict)
        
        if self.accountsAndKeys != nil {
            self.process()
        }
    }
    
    private func process() {
        guard let accountsAndKeys = self.accountsAndKeys else {
            return
        }
        var decryptedNotifications: [(Account, Bool, [AnyHashable: Any])] = []
        for dict in self.encryptedNotifications {
            if var encryptedPayload = dict["p"] as? String {
                encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
                encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
                while encryptedPayload.count % 4 != 0 {
                    encryptedPayload.append("=")
                }
                if let data = Data(base64Encoded: encryptedPayload) {
                    inner: for (account, isCurrent, key) in accountsAndKeys {
                        if let decryptedData = decryptedNotificationPayload(key: key, data: data) {
                            if let decryptedDict = (try? JSONSerialization.jsonObject(with: decryptedData, options: [])) as? [AnyHashable: Any] {
                                decryptedNotifications.append((account, isCurrent, decryptedDict))
                            }
                            break inner
                        }
                    }
                }
            }
        }
        self.encryptedNotifications.removeAll()
        
        for (account, isCurrent, payload) in decryptedNotifications {
            var redactedPayload = payload
            if var aps = redactedPayload["aps"] as? [AnyHashable: Any] {
                if Logger.shared.redactSensitiveData {
                    if aps["alert"] != nil {
                        aps["alert"] = "[[redacted]]"
                    }
                    if aps["body"] != nil {
                        aps["body"] = "[[redacted]]"
                    }
                }
                redactedPayload["aps"] = aps
            }
            Logger.shared.log("Apns \(self.episodeId)", "\(redactedPayload)")
            
            let aps = payload["aps"] as? [AnyHashable: Any]
            
            var readMessageId: MessageId?
            var isCall = false
            var isAnnouncement = false
            var isLocationPolling = false
            var notificationRequestId: NotificationManagedNotificationRequestId?
            var isMutePolling = false
            var title: String = ""
            var body: String?
            var apnsSound: String?
            var configurationUpdate: (Int32, String, Int32, Data?)?
            if let aps = aps, let alert = aps["alert"] as? String {
                if let range = alert.range(of: ": ") {
                    title = String(alert[..<range.lowerBound])
                    body = String(alert[range.upperBound...])
                } else {
                    body = alert
                }
            } else if let aps = aps, let alert = aps["alert"] as? [AnyHashable: AnyObject] {
                if let alertBody = alert["body"] as? String {
                    body = alertBody
                    if let alertTitle = alert["title"] as? String {
                        title = alertTitle
                    }
                }
                if let locKey = alert["loc-key"] as? String {
                    if locKey == "PHONE_CALL_REQUEST" {
                        isCall = true
                    } else if locKey == "GEO_LIVE_PENDING" {
                        isLocationPolling = true
                    } else if locKey == "MESSAGE_MUTED" {
                        isMutePolling = true
                    }
                    let string = NSLocalizedString(locKey, comment: "")
                    if !string.isEmpty {
                        if let locArgs = alert["loc-args"] as? [AnyObject] {
                            var args: [CVarArg] = []
                            var failed = false
                            for arg in locArgs {
                                if let arg = arg as? CVarArg {
                                    args.append(arg)
                                } else {
                                    failed = true
                                    break
                                }
                            }
                            if failed {
                                body = "\(string)"
                            } else {
                                body = String(format: string, arguments: args)
                            }
                        } else {
                            body = "\(string)"
                        }
                    } else {
                        body = nil
                    }
                } else {
                    body = nil
                }
            }
            
            if let aps = aps, let address = aps["addr"] as? String, let datacenterId = aps["dc"] as? Int {
                var host = address
                var port: Int32 = 443
                if let range = address.range(of: ":") {
                    host = String(address[address.startIndex ..< range.lowerBound])
                    if let portValue = Int(String(address[range.upperBound...])) {
                        port = Int32(portValue)
                    }
                }
                var secret: Data?
                if let secretString = aps["sec"] as? String {
                    let data = dataWithHexString(secretString)
                    if data.count == 16 || data.count == 32 {
                        secret = data
                    }
                }
                configurationUpdate = (Int32(datacenterId), host, port, secret)
            }
            
            if let aps = aps, let sound = aps["sound"] as? String {
                apnsSound = sound
            }
            
            if payload["call_id"] != nil {
                isCall = true
            }
            
            if payload["announcement"] != nil {
                isAnnouncement = true
            }
            
            if let body = body {
                if isAnnouncement {
                    //presentAnnouncement
                } else {
                    var peerId: PeerId?
                    
                    if let fromId = payload["from_id"] {
                        let fromIdValue = fromId as! NSString
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
                    } else if let fromId = payload["chat_id"] {
                        let fromIdValue = fromId as! NSString
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
                    } else if let fromId = payload["channel_id"] {
                        let fromIdValue = fromId as! NSString
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
                    }
                    
                    if let msgId = payload["msg_id"] {
                        let msgIdValue = msgId as! NSString
                        if let peerId = peerId {
                            notificationRequestId = .messageId(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue)))
                        }
                    } else if let randomId = payload["random_id"] {
                        let randomIdValue = randomId as! NSString
                        var peerId: PeerId?
                        if let encryptionIdString = payload["encryption_id"] as? String, let encryptionId = Int32(encryptionIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: encryptionId)
                        }
                        notificationRequestId = .globallyUniqueId(randomIdValue.longLongValue, peerId)
                    } else {
                        isMutePolling = true
                    }
                }
            } else if let _ = payload["max_id"] {
                var peerId: PeerId?
                
                if let fromId = payload["from_id"] {
                    let fromIdValue = fromId as! NSString
                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
                } else if let fromId = payload["chat_id"] {
                    let fromIdValue = fromId as! NSString
                    peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
                } else if let fromId = payload["channel_id"] {
                    let fromIdValue = fromId as! NSString
                    peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
                }
                
                if let peerId = peerId {
                    if let msgId = payload["max_id"] {
                        let msgIdValue = msgId as! NSString
                        if msgIdValue.intValue != 0 {
                            readMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue))
                        }
                    }
                }
            }
            
            if notificationRequestId != nil || isMutePolling || isCall {
                if !self.inForeground || !isCurrent {
                    self.beginPollingState(account: account)
                }
            }
            if isLocationPolling {
                //addedWakeups.insert(.backgroundLocation)
            }
            
            if let readMessageId = readMessageId {
                self.clearNotificationsManager.append(readMessageId)
                self.clearNotificationsManager.commitNow()
                
                let _ = account.postbox.transaction(ignoreDisabled: true, { transaction -> Void in
                    transaction.applyIncomingReadMaxId(readMessageId)
                }).start()
            }
            
            if let (datacenterId, host, port, secret) = configurationUpdate {
                account.network.mergeBackupDatacenterAddress(datacenterId: datacenterId, host: host, port: port, secret: secret)
            }
        }
    }
}