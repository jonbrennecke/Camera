import Foundation
import ImageUtils

class CameraResolutionObserver: Observer {
    private weak var delegate: CameraResolutionDelegate?

    internal init(delegate: CameraResolutionDelegate) {
        self.delegate = delegate
    }

    func cameraManagerDidChange(videoResolution: Size<Int>) {
        delegate?.cameraManagerDidChange(videoResolution: videoResolution)
    }

    func cameraManagerDidChange(depthResolution: Size<Int>) {
        delegate?.cameraManagerDidChange(depthResolution: depthResolution)
    }
}
