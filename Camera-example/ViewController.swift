import Camera
import UIKit

class ViewController: UIViewController {
  let cameraView = CameraEffectView()
  let camera = Camera()
  let shutterButton = UIButton()
  let depthButton = UIButton()
  let switchCameraButton = UIButton()

  @objc func onPressShutter() {
    if camera.readyToRecord {
      camera.startCapture(withMetadata: nil) { _, _ in
        print("started capture")
      }
    } else {
      camera.stopCapture(andSaveToCameraRoll: true) { _, url in
        print("stopped capture: \(String(describing: url?.absoluteString))")
      }
    }
  }

  @objc func onPressDepthButton() {
    if camera.depth {
      camera.depth = false
      cameraView.previewMode = .normal
    } else {
      camera.depth = true
      cameraView.previewMode = .depth
    }
  }

  @objc func onPressSwitchCameraButton() {
    camera.position = camera.position == .front ? .back : .front
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    guard let touch = touches.first else { return }
    let layerPoint = touch.location(in: cameraView)
    let point = cameraView.captureDevicePointConverted(fromLayerPoint: layerPoint)
    camera.focus(on: point)
    camera.exposure(on: point)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // set up shutter button
    shutterButton.backgroundColor = .red
    shutterButton.setTitle("Capture", for: .normal)
    shutterButton.addTarget(self, action: #selector(onPressShutter), for: .touchDown)
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
    view.addConstraint(NSLayoutConstraint(
      item: shutterButton,
      attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 0.33, constant: 0
    ))

    // set up "depth" button
    depthButton.backgroundColor = .blue
    depthButton.setTitle("Depth", for: .normal)
    depthButton.addTarget(self, action: #selector(onPressDepthButton), for: .touchDown)
    depthButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(depthButton)
    view.addConstraint(NSLayoutConstraint(
      item: depthButton,
      attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: -100
    ))
    view.addConstraint(NSLayoutConstraint(
      item: depthButton,
      attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: 0
    ))
    view.addConstraint(NSLayoutConstraint(
      item: depthButton,
      attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 0.33, constant: 0
    ))

    // set up "switch camera" button
    switchCameraButton.backgroundColor = .purple
    switchCameraButton.setTitle("Switch Camera", for: .normal)
    switchCameraButton.addTarget(self, action: #selector(onPressSwitchCameraButton), for: .touchDown)
    switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(switchCameraButton)
    view.addConstraint(NSLayoutConstraint(
      item: switchCameraButton,
      attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: -100
    ))
    view.addConstraint(NSLayoutConstraint(
      item: switchCameraButton,
      attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1, constant: 0
    ))
    view.addConstraint(NSLayoutConstraint(
      item: switchCameraButton,
      attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 0.33, constant: 0
    ))

    // set up camera view
    cameraView.camera = camera
    cameraView.frame = view.bounds
    cameraView.previewMode = .normal
    view.insertSubview(cameraView, at: 0)

    // set up camera
    camera.depth = true
    camera.position = .back
    camera.resolution = .vga // TODO: rename to "resolution"
    camera.zoom = 5.0

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
