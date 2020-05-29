import AVFoundation
import Camera
import UIKit
import VideoEffects

class ViewController: UIViewController {
  let playerView = EffectPlayerView()

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let url = Bundle.main.url(forResource: "depth-example", withExtension: "mov") else {
      fatalError("Couldn't find example video")
    }
    let asset = AVAsset(url: url)
    guard case let (videoTrack: .some(videoTrack),
                    depthTrack: .some(depthTrack)) = getVideoAndDepthTrackAssociation(for: asset) else {
      fatalError("Couldn't find video/depth track in example video")
    }
    playerView.effects = EffectConfig(
      filters: [
//        ColorControlsFilter.grayscale,
        DepthBlurFilter(
          videoTrack: videoTrack,
          disparityTrack: depthTrack,
          previewMode: .portrait
        ),
      ],
      timeRange: CMTimeRange(start: .zero, end: CMTime(seconds: 3, preferredTimescale: 600))
    )
    playerView.asset = asset
    playerView.frame = view.bounds
    view.addSubview(playerView)
  }
}
