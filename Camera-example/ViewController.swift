import Camera
import UIKit

class ViewController: UIViewController {
  let cameraView = CameraEffectView()
  let camera = Camera()
  let shutterButton = UIButton()

  @objc func onShutterPress() {
    if camera.readyToRecord {
      camera.startCapture(withMetadata: nil) { _, _ in
        print("started capture")
      }
    } else {
      camera.stopCapture(andSaveToCameraRoll: true) { _, url in
        print("stopped capture", url?.absoluteString)
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // set up shutter button
    shutterButton.backgroundColor = .red
    shutterButton.setTitle("Capture", for: .normal)
    shutterButton.addTarget(self, action: #selector(onShutterPress), for: .touchDown)
    shutterButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(shutterButton)
    view.addConstraint(NSLayoutConstraint(
      item: shutterButton,
      attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: -100
    ))
    view.addConstraint(NSLayoutConstraint(
      item: shutterButton,
      attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0
    ))

    // set up camera view
    cameraView.camera = camera
    cameraView.frame = view.bounds
    cameraView.previewMode = .normal
    view.insertSubview(cameraView, at: 0)

    // set up camera
    camera.depthEnabled = false
    camera.position = .back
    camera.resolutionPreset = .vga // TODO: rename to "resolution"

    // start preview
    Camera.requestCameraPermissions { success in
      if !success {
        fatalError("Missing required camera permissions")
      }
      self.camera.setupCameraCaptureSession { result in
        if case let .failure(error) = result {
          fatalError("Failed to set up camera: \(error)")
        }
        self.camera.startPreview()
      }
    }
  }
}
