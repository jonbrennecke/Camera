Camera
---

Swift camera utilities with depth/disparity capture and portrait effects.

This library is designed around exposing unique camera features such as:

- Displaying a realtime preview of depth and portrait mode data from the camera
- A custom asset writer that can save depth/disparity data in the same file as standard video data.
- A video player with depth and portrait mode built-in.

### Setting up a camera preview

The `CameraEffectView` will display camera data in real-time with the given `previewMode`. The `previewMode` can be one of `.normal`, `.depth` or `.portrait`.

```swift
// Configure CameraEffectView
let cameraView = CameraEffectView()
let camera = Camera()
cameraView.camera = camera

// Set the preview mode (options are .normal, .depth or .portrait)
cameraView.previewMode = .portrait

// Configure camera
camera.depthEnabled = false
camera.position = .back
camera.resolutionPreset = .hd720p

Camera.requestCameraPermissions { success in
  if !success {
    fatalError("Missing required camera permissions")
  }
  camera.setupCameraCaptureSession { result in
    if case let .failure(error) = result {
      fatalError("Failed to set up camera: \(error)")
    }
    camera.startPreview()
  }
}
```

### Playing videos with embedded depth data

This library uses `EffectPlayerView` from [VideoEffects](https://github.com/jonbrennecke/VideoEffects). See the documentation of that library for more details.

The `DepthBlurFilter` is a custom filter for `EffectPlayerView` that let's you play video with depth effects. 

Use it like this:

```swift
let playerView = EffectPlayerView()
playerView.effects = EffectConfig(
  filters: [
    DepthBlurFilter(
      videoTrack: videoTrack,
      disparityTrack: depthTrack,
      previewMode: .portrait
    ),
  ]
)
```

See the example app in `Player-example` for full implementation details.

### Running the example app

Open the workspace `Camera.xcworkspace` and run the target `Camera-example` or `Player-example`.
