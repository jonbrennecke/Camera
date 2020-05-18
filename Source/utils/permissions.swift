import Photos

internal enum PermissionVariant {
  case captureDevice(mediaType: AVMediaType)
  case mediaLibrary
  case microphone
}

internal func requestPermissions(for permissions: [PermissionVariant], _ callback: @escaping (Bool) -> Void) {
  guard let last = permissions.last else {
    callback(true)
    return
  }
  requestPermission(for: last) { success in
    if !success {
      callback(false)
      return
    }
    let nextPermissions = Array(permissions[..<(permissions.count - 1)])
    requestPermissions(for: nextPermissions, callback)
  }
}

private func requestPermission(for permission: PermissionVariant, _ callback: @escaping (Bool) -> Void) {
  switch permission {
  case let .captureDevice(mediaType: mediaType):
    authorizeCaptureDevice(with: mediaType, callback)
  case .mediaLibrary:
    authorizeMediaLibrary(callback)
  case .microphone:
    authorizeMicrophone(callback)
  }
}

private func authorizeCaptureDevice(with mediaType: AVMediaType, _ callback: @escaping (Bool) -> Void) {
  switch AVCaptureDevice.authorizationStatus(for: mediaType) {
  case .authorized:
    return callback(true)
  case .notDetermined:
    AVCaptureDevice.requestAccess(for: mediaType) { granted in
      if granted {
        return callback(true)
      } else {
        return callback(false)
      }
    }
  case .denied:
    return callback(false)
  case .restricted:
    return callback(false)
    @unknown default:
    return callback(false)
  }
}

private func authorizeMediaLibrary(_ callback: @escaping (Bool) -> Void) {
  PHPhotoLibrary.requestAuthorization { status in
    switch status {
    case .authorized:
      return callback(true)
    case .denied:
      return callback(false)
    case .notDetermined:
      return callback(false)
    case .restricted:
      return callback(false)
      @unknown default:
      return callback(false)
    }
  }
}

private func authorizeMicrophone(_ callback: @escaping (Bool) -> Void) {
  switch AVCaptureDevice.authorizationStatus(for: .audio) {
  case .authorized:
    return callback(true)
  case .notDetermined:
    AVCaptureDevice.requestAccess(for: .audio) { granted in
      if granted {
        return callback(true)
      } else {
        return callback(false)
      }
    }
  case .denied:
    return callback(false)
  case .restricted:
    return callback(false)
    @unknown default:
    return callback(false)
  }
}

private func isAuthorized() -> Bool {
  if case .authorized = AVCaptureDevice.authorizationStatus(for: .video),
    case .authorized = AVCaptureDevice.authorizationStatus(for: .audio) {
    return true
  }
  return false
}

internal func permissionStatus(for permissions: [PermissionVariant]) -> Bool {
  return permissions.allSatisfy { permissionStatus(for: $0) }
}

internal func permissionStatus(for permission: PermissionVariant) -> Bool {
  switch permission {
  case .captureDevice(mediaType: .audio):
    return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
  case .captureDevice(mediaType: .video):
    return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
  case .mediaLibrary:
    return PHPhotoLibrary.authorizationStatus() == .authorized
  case .microphone:
    return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
  case .captureDevice:
    return false
  }
}
