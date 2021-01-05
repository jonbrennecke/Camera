import AVFoundation
import ImageUtils

public enum CameraResolutionPreset: Int {
    case hd720p
    case hd1080p
    case hd4K
    case vga

    var avCaptureSessionPreset: AVCaptureSession.Preset {
        switch self {
        case .hd4K:
            return .hd4K3840x2160
        case .hd720p:
            return .hd1280x720
        case .hd1080p:
            return .hd1920x1080
        case .vga:
            return .vga640x480
        }
    }

    var landscapeSize: Size<Int> {
        switch self {
        case .hd4K:
            return Size(width: 3840, height: 2160)
        case .hd720p:
            return Size(width: 1280, height: 720)
        case .hd1080p:
            return Size(width: 1920, height: 1080)
        case .vga:
            return Size(width: 640, height: 480)
        }
    }

    var portraitSize: Size<Int> {
        let size = landscapeSize
        return Size(width: size.height, height: size.width)
    }
}
