import Foundation
import UIKit
import Postbox
import SwiftSignalKit

public final class CachedStickerAJpegRepresentation: CachedMediaResourceRepresentation {
    public let size: CGSize?
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        if let size = self.size {
            return "sticker-ajpeg-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "sticker-ajpeg"
        }
    }
    
    public init(size: CGSize?) {
        self.size = size
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedStickerAJpegRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

public enum CachedScaledImageRepresentationMode: Int32 {
    case fill = 0
    case aspectFit = 1
}

public final class CachedScaledImageRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let size: CGSize
    public let mode: CachedScaledImageRepresentationMode
    
    public var uniqueId: String {
        return "scaled-image-\(Int(self.size.width))x\(Int(self.size.height))-\(self.mode.rawValue)"
    }
    
    public init(size: CGSize, mode: CachedScaledImageRepresentationMode) {
        self.size = size
        self.mode = mode
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledImageRepresentation {
            return self.size == to.size && self.mode == to.mode
        } else {
            return false
        }
    }
}

public final class CachedVideoFirstFrameRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "first-frame"
    }
    
    public init() {
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is CachedVideoFirstFrameRepresentation {
            return true
        } else {
            return false
        }
    }
}

public final class CachedScaledVideoFirstFrameRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let size: CGSize
    
    public var uniqueId: String {
        return "scaled-frame-\(Int(self.size.width))x\(Int(self.size.height))"
    }
    
    public init(size: CGSize) {
        self.size = size
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledVideoFirstFrameRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

public final class CachedBlurredWallpaperRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "blurred-wallpaper"
    }
    
    public init() {
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is CachedBlurredWallpaperRepresentation {
            return true
        } else {
            return false
        }
    }
}

public final class CachedPatternWallpaperMaskRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let size: CGSize?
    
    public var uniqueId: String {
        if let size = self.size {
            return "pattern-wallpaper-mask-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "pattern-wallpaper-mask"
        }
    }
    
    public init(size: CGSize?) {
        self.size = size
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedPatternWallpaperMaskRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}


public final class CachedPatternWallpaperRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let color: Int32
    public let intensity: Int32
    
    public var uniqueId: String {
        return "pattern-wallpaper-\(self.color)-\(self.intensity)"
    }
    
    public init(color: Int32, intensity: Int32) {
        self.color = color
        self.intensity = intensity
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedPatternWallpaperRepresentation {
            return self.color == to.color && self.intensity == intensity
        } else {
            return false
        }
    }
}

public final class CachedAlbumArtworkRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let size: CGSize?
    
    public var uniqueId: String {
        if let size = self.size {
            return "album-artwork-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "album-artwork"
        }
    }
    
    public init(size: CGSize) {
        self.size = size
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedAlbumArtworkRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

public final class CachedEmojiThumbnailRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let outline: Bool
    
    public var uniqueId: String {
        return "emoji-thumb-\(self.outline ? 1 : 0)"
    }
    
    public init(outline: Bool) {
        self.outline = outline
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedEmojiThumbnailRepresentation {
            return self.outline == to.outline
        } else {
            return false
        }
    }
}

public final class CachedEmojiRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let tile: UInt8
    public let outline: Bool
    
    public var uniqueId: String {
        return "emoji-\(Int(self.tile))-\(self.outline ? 1 : 0)"
    }
    
    public init(tile: UInt8, outline: Bool) {
        self.tile = tile
        self.outline = outline
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedEmojiRepresentation {
            return self.tile == to.tile && self.outline == to.outline
        } else {
            return false
        }
    }
}

public final class CachedAnimatedStickerFirstFrameRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public let width: Int32
    public let height: Int32
    
    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
    
    public var uniqueId: String {
        return "animated-sticker-first-frame-\(self.width)x\(self.height)-v1"
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let other = to as? CachedAnimatedStickerFirstFrameRepresentation {
            if other.width != self.width {
                return false
            }
            if other.height != self.height {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

public final class CachedAnimatedStickerRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .shortLived
    
    public let width: Int32
    public let height: Int32
    
    public var uniqueId: String {
        return "animated-sticker-\(self.width)x\(self.height)-v8"
    }
    
    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let other = to as? CachedAnimatedStickerRepresentation {
            if other.width != self.width {
                return false
            }
            if other.height != self.height {
                return false
            }
            return true
        } else {
            return false
        }
    }
}
