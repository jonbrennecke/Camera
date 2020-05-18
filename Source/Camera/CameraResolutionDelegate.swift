import Foundation
import ImageUtils

protocol CameraResolutionDelegate: AnyObject {
  func cameraManagerDidChange(videoResolution: Size<Int>)
  func cameraManagerDidChange(depthResolution: Size<Int>)
}
