import AVFoundation
import ImageUtils

class CameraDepthDataObserver: Observer {
  private weak var delegate: CameraDepthDataDelegate?

  internal init(delegate: CameraDepthDataDelegate) {
    self.delegate = delegate
  }

  func cameraManagerDidOutput(disparityPixelBuffer: PixelBuffer, calibrationData: AVCameraCalibrationData?) {
    delegate?.cameraManagerDidOutput(
      disparityPixelBuffer: disparityPixelBuffer,
      calibrationData: calibrationData
    )
  }

  func cameraManagerDidOutput(videoPixelBuffer: PixelBuffer) {
    delegate?.cameraManagerDidOutput(
      videoPixelBuffer: videoPixelBuffer
    )
  }

  func cameraManagerDidFocus(on focusPoint: CGPoint) {
    delegate?.cameraManagerDidFocus(on: focusPoint)
  }
}
