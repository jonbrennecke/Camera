import AVFoundation
import Camera
import UIKit
import VideoEffects

class ViewController: UIViewController {
  let playerView = EffectPlayerView()

  override func viewDidLoad() {
    super.viewDidLoad()
    playerView.frame = view.bounds
    view.addSubview(playerView)

    guard let url = Bundle.main.url(forResource: "depth-example.MOV", withExtension: nil) else {
      fatalError("Couldn't find example video")
    }
    let asset = AVAsset(url: url)
    playerView.asset = asset

    guard case let (videoTrack: .some(videoTrack),
                    depthTrack: .some(depthTrack)) = getVideoAndDepthTrackAssociation(for: asset) else {
      fatalError("Couldn't find video/depth track in example video")
    }
    playerView.effects = EffectConfig(
      filters: [
        DepthBlurFilter(
          videoTrack: videoTrack,
          disparityTrack: depthTrack,
          previewMode: .portrait
        ),
      ]
    )
  }
}
