import AVFoundation
import ImageUtils

public protocol CameraDelegate {
    func camera(_ camera: Camera, didOutputDisparityPixelBuffer disparityPixelBuffer: PixelBuffer, calibrationData: AVCameraCalibrationData?)
    func camera(_ camera: Camera, didOutputVideoPixelBuffer videoPixelBuffer: PixelBuffer)
    func camera(_ camera: Camera, didFocusOn point: CGPoint)
}
