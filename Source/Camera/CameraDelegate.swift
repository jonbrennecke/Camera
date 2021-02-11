import AVFoundation

public protocol CameraDelegate {
    func camera(_ camera: Camera, didOutputDepthData depthData: AVDepthData)
    func camera(_ camera: Camera, didOutputVideoSampleBuffer videoSampleBuffer: CMSampleBuffer)
    func camera(_ camera: Camera, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer)
    func camera(_ camera: Camera, didFocusOn point: CGPoint)
}

extension CameraDelegate {
    func camera(_: Camera, didOutputDepthData _: AVDepthData) {
        // noop
    }

    func camera(_: Camera, didOutputVideoSampleBuffer _: CMSampleBuffer) {
        // noop
    }

    public func camera(_: Camera, didOutputAudioSampleBuffer _: CMSampleBuffer) {
        // noop
    }

    func camera(_: Camera, didFocusOn _: CGPoint) {
        // noop
    }
}
