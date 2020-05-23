import AVFoundation
import CoreGraphics
import ImageUtils
import MetalKit
import UIKit

public class EffectSession {
  private lazy var depthBlurEffect = DepthBlurEffect()

  private var depthDataObserver: CameraDepthDataObserver?

  public var previewMode: EffectPreviewMode = .normal

  internal weak var camera: Camera? {
    didSet {
      if camera != nil {
        let observer = CameraDepthDataObserver(delegate: self)
        camera?.depthDataObservers.addObserver(observer)
        depthDataObserver = observer
      }
    }
  }

  private var imageBufferResizer: ImageBufferResizer?

  private func createImageBufferResizer(size: Size<Int>) -> ImageBufferResizer? {
    guard let resizer = imageBufferResizer, size == resizer.size else {
      imageBufferResizer = ImageBufferResizer(
        size: size,
        bufferInfo: BufferInfo(pixelFormatType: kCVPixelFormatType_32BGRA)
      )
      return imageBufferResizer
    }
    return resizer
  }

  private func createCenteredAndResizedImage(
    withPixelBuffer pixelBuffer: PixelBuffer,
    size: CGSize,
    resizeMode: ResizeMode
  ) -> CIImage? {
    let imageBuffer = ImageBuffer(pixelBuffer: pixelBuffer)
    let scale = Float(scaleForResizing(pixelBuffer.size.cgSize(), to: size, resizeMode: resizeMode))
    let scaledSize = Size<Int>(
      width: Int((Float(pixelBuffer.size.width) * scale).rounded()),
      height: Int((Float(pixelBuffer.size.height) * scale).rounded())
    )
    guard
      let resizer = createImageBufferResizer(size: scaledSize),
      let resizedImageBuffer = resizer.resize(imageBuffer: imageBuffer),
      let image = resizedImageBuffer.makeCIImage()
    else {
      return nil
    }
    let yDiff = CGFloat(scaledSize.height) - CGFloat(size.height)
    let xDiff = CGFloat(scaledSize.width) - CGFloat(size.width)
    return image
      .transformed(by: CGAffineTransform(translationX: -xDiff * 0.5, y: -yDiff * 0.5))
  }

  internal func makeEffectImage(blurAperture: Float = 2.5, size: CGSize, resizeMode: ResizeMode) -> CIImage? {
    return autoreleasepool {
      // render unaltered video frames in "normal" preview mode
      if case .normal = previewMode {
        guard let videoPixelBuffer = videoPixelBuffer else {
          return nil
        }
        return createCenteredAndResizedImage(
          withPixelBuffer: videoPixelBuffer,
          size: size,
          resizeMode: resizeMode
        )
      }

      // render depth and portrait preview modes
      guard
        let disparityPixelBuffer = disparityPixelBuffer,
        let videoPixelBuffer = videoPixelBuffer
      else {
        return nil
      }
      guard
        let videoImage = createCenteredAndResizedImage(withPixelBuffer: videoPixelBuffer, size: size,
                                                       resizeMode: resizeMode),
        let disparityImage = ImageBuffer(pixelBuffer: disparityPixelBuffer).makeCIImage() else {
        return nil
      }
      return depthBlurEffect.makeEffectImage(
        previewMode: previewMode == .depth ? .depth : .portraitBlur,
        disparityImage: disparityImage,
        videoImage: videoImage,
        blurAperture: blurAperture,
        qualityFactor: 0.025
      )
    }
  }

  deinit {
    if let observer = depthDataObserver {
      camera?.depthDataObservers.removeObserver(observer)
    }
  }

  public var isPaused: Bool {
    get {
      return depthDataObserver?.isPaused ?? false
    }
    set {
      depthDataObserver?.isPaused = newValue
    }
  }

  // MARK: - Objective-C interface

  public var disparityPixelBuffer: PixelBuffer?

  public var calibrationData: AVCameraCalibrationData?

  public var videoPixelBuffer: PixelBuffer?

  public var focusPoint: CGPoint?
}

extension EffectSession: CameraDepthDataDelegate {
  func cameraManagerDidOutput(disparityPixelBuffer: PixelBuffer, calibrationData: AVCameraCalibrationData?) {
    self.disparityPixelBuffer = disparityPixelBuffer
    self.calibrationData = calibrationData
  }

  func cameraManagerDidOutput(videoPixelBuffer: PixelBuffer) {
    self.videoPixelBuffer = videoPixelBuffer
  }

  func cameraManagerDidFocus(on focusPoint: CGPoint) {
    self.focusPoint = focusPoint
  }
}
