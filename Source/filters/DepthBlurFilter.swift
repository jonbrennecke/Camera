import AVFoundation
import ImageUtils
import VideoEffects

public class DepthBlurFilter: CompositorFilter {
  public var videoTrack: CMPersistentTrackID?
  public var disparityTrack: CMPersistentTrackID?
  public var previewMode: EffectPreviewMode?
  public var blurAperture: Float

  private lazy var depthBlurEffect = DepthBlurEffect()

  public init(
    videoTrack: CMPersistentTrackID?,
    disparityTrack: CMPersistentTrackID?,
    previewMode: EffectPreviewMode?,
    blurAperture: Float = 2.5
  ) {
    self.videoTrack = videoTrack
    self.disparityTrack = disparityTrack
    self.previewMode = previewMode
    self.blurAperture = blurAperture
  }

  public func renderFilter(with _: CIImage, request: AVAsynchronousVideoCompositionRequest) -> CIImage? {
    if
      case .normal = previewMode,
      let videoTrack = videoTrack,
      let videoPixelBuffer = request.sourceFrame(byTrackID: videoTrack) {
      return ImageBuffer(cvPixelBuffer: videoPixelBuffer).makeCIImage()
    }

    // render depth and portrait preview modes
    if
      let videoTrack = videoTrack,
      let disparityTrack = disparityTrack,
      let disparityPixelBuffer = request.sourceFrame(byTrackID: disparityTrack),
      let videoPixelBuffer = request.sourceFrame(byTrackID: videoTrack),
      let videoImage = ImageBuffer(cvPixelBuffer: videoPixelBuffer).makeCIImage(),
      let disparityImage = ImageBuffer(cvPixelBuffer: disparityPixelBuffer).makeCIImage() {
      return depthBlurEffect.makeEffectImage(
        previewMode: previewMode == .depth ? .depth : .portraitBlur,
        disparityImage: disparityImage,
        videoImage: videoImage,
        blurAperture: blurAperture,
        qualityFactor: 0.025
      )
    }

    return nil
  }
}
