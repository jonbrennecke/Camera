import AVFoundation

public protocol CameraDelegate {
    func camera(_ camera: Camera, didOutputDepthData depthData: AVDepthData)
    func camera(_ camera: Camera, didOutputVideoSampleBuffer videoSampleBuffer: CMSampleBuffer)
    func camera(_ camera: Camera, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer)
    func camera(_ camera: Camera, didFocusOn point: CGPoint)
}

extension CameraDelegate {
  func camera(_ camera: Camera, didOutputDepthData depthData: AVDepthData) {
      // noop
  }
  
  func camera(_ camera: Camera, didOutputVideoSampleBuffer videoSampleBuffer: CMSampleBuffer) {
    // noop
  }
  public func camera(_ camera: Camera, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
    // noop
  }
  
  func camera(_ camera: Camera, didFocusOn point: CGPoint) {
    // noop
  }
}
