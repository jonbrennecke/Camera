import AVFoundation

@available(iOS 11.1, *)
internal func depthEnabledCaptureDevice(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [
        .builtInTrueDepthCamera,
        .builtInDualCamera,
    ], mediaType: .video, position: position)
    return discoverySession.devices.first
}

internal func captureDevice(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [
        .builtInWideAngleCamera,
        .builtInTelephotoCamera,
    ], mediaType: .video, position: position)
    return discoverySession.devices.first
}

@available(iOS 11.1, *)
internal func getDepthEnabledCaptureDevices(withPosition position: AVCaptureDevice.Position) -> [AVCaptureDevice] {
    let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [
        .builtInTrueDepthCamera,
        .builtInDualCamera,
    ], mediaType: .video, position: position)
    return discoverySession.devices
}

private func getOppositeCameraPosition(session: AVCaptureSession,
                                       defaultPosition: AVCaptureDevice.Position = .front) -> AVCaptureDevice.Position {
    let device = activeCaptureDevice(session: session)
    switch device?.position {
    case .some(.back):
        return .front
    case .some(.front):
        return .back
    default:
        return defaultPosition
    }
}

internal func activeCaptureDevicePosition(session: AVCaptureSession) -> AVCaptureDevice.Position? {
    let device = activeCaptureDevice(session: session)
    return device?.position
}

private func activeCaptureDevice(session: AVCaptureSession) -> AVCaptureDevice? {
    return session.inputs.reduce(nil) { (device, input) -> AVCaptureDevice? in
        if input.isKind(of: AVCaptureDeviceInput.classForCoder()) {
            let device = (input as! AVCaptureDeviceInput).device
            if device.position != .unspecified {
                return device
            }
        }
        return device
    }
}
