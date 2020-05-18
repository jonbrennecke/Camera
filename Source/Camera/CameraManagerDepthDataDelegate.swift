import AVFoundation
import ImageUtils

protocol CameraDepthDataDelegate: AnyObject {
  var isPaused: Bool { get set }
  func cameraManagerDidOutput(disparityPixelBuffer: PixelBuffer, calibrationData: AVCameraCalibrationData?)
  func cameraManagerDidOutput(videoPixelBuffer: PixelBuffer)
  func cameraManagerDidFocus(on focusPoint: CGPoint)
}
