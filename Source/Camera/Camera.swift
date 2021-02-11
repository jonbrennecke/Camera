import AVFoundation
import ImageUtils
import Photos

private let depthMinFramesPerSecond = Int(20)
private let videoMinFramesPerSecond = Int(20)
private let videoMaxFramesPerSecond = Int(30)

// the max number of concurrent drawables supported by CoreAnimation
private let maxSimultaneousFrames: Int = 3

public class Camera: NSObject {
    public enum CameraSetupError: Error {
        case failedToSetupVideoCaptureDevice
        case failedToSetupVideoInput
        case failedToSetupVideoOutput
        case failedToSetupDepthOutput
    }

    private class UnsafeInternalState {
        var depth: Bool
        var zoom: Float
        var exposure: Float
        var resolution: CameraResolutionPreset
        var position: AVCaptureDevice.Position

        init(
            depth: Bool,
            zoom: Float,
            exposure: Float,
            resolution: CameraResolutionPreset,
            position: AVCaptureDevice.Position
        ) {
            self.depth = depth
            self.zoom = zoom
            self.exposure = exposure
            self.resolution = resolution
            self.position = position
        }
    }

    private var unsafeInternalState: UnsafeInternalState = UnsafeInternalState(
        depth: false,
        zoom: 1.0,
        exposure: 0,
        resolution: .hd720p,
        position: .front // TODO: save defaults as constants
    )

    private func safelyWriteInternalState(_ callback: @escaping () -> Void) {
        cameraSetupQueue.async(flags: .barrier) {
            callback()
        }
    }

    private func safelyReadInternalState<T>(_ callback: () -> T) -> T {
        return cameraSetupQueue.sync {
            return callback()
        }
    }

    // MARK: - queues

    fileprivate let cameraOutputQueue = DispatchQueue(
        label: "com.jonbrennecke.Camera.cameraOutputQueue",
        qos: .userInteractive
    )

    fileprivate let cameraSetupQueue = DispatchQueue(
        label: "com.jonbrennecke.Camera.cameraSetupQueue",
        qos: .background,
        attributes: .concurrent
    )

    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    private var outputSemaphore = DispatchSemaphore(value: maxSimultaneousFrames)

    // MARK: video

    private var videoCaptureDevice: AVCaptureDevice?
    private var videoCaptureDeviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()

    // MARK: audio

    private var audioCaptureDevice: AVCaptureDevice?
    private var audioCaptureDeviceInput: AVCaptureDeviceInput?
    private let audioOutput = AVCaptureAudioDataOutput()

    private lazy var clock: CMClock = {
        captureSession.masterClock ?? CMClockGetHostTimeClock()
    }()

    internal var audioCaptureSession = AVCaptureSession()
    internal var captureSession = AVCaptureSession()

    // MARK: delegates

    public var delegate: CameraDelegate?

    // TODO: change this to a delegate pattern
    internal var resolutionObservers = ObserverCollection<CameraResolutionObserver>()

    // MARK: public interface

    public var paused = false

    // kCVPixelFormatType_32BGRA is required because of compatability with depth effects, but
    // if depth is disabled, this should be left as the default YpCbCr
    public var videoPixelFormat: OSType = kCVPixelFormatType_32BGRA

    public var depthPixelFormat: OSType = kCVPixelFormatType_DisparityFloat32

    public var videoResolution: Size<Int>? {
        guard let format = videoCaptureDevice?.activeFormat else {
            return nil
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        if let connection = videoOutput.connection(with: .video), connection.videoOrientation == .portrait {
            return Size(width: height, height: width)
        }
        return Size(width: width, height: height)
    }

    public var depthResolution: Size<Int>? {
        guard let format = videoCaptureDevice?.activeDepthDataFormat else {
            return nil
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        if let connection = videoOutput.connection(with: .video), connection.videoOrientation == .portrait {
            return Size(width: height, height: width)
        }
        return Size(width: width, height: height)
    }

    public var zoom: Float {
        get {
            return safelyReadInternalState {
                return unsafeInternalState.zoom
            }
        }
        set {
            safelyWriteInternalState { [weak self] in
                self?.unsafeInternalState.zoom = newValue
                self?.unsafeUpdateZoom()
            }
        }
    }

    public var supportedZoomRange: (min: Float, max: Float) {
        guard let videoCaptureDevice = videoCaptureDevice else {
            return (min: 1.0, max: 1.0)
        }
        if unsafeInternalState.depth {
            let min = Float(videoCaptureDevice.activeFormat.videoMinZoomFactorForDepthDataDelivery)
            let max = Float(videoCaptureDevice.activeFormat.videoMaxZoomFactorForDepthDataDelivery)
            return (min, max)
        }
        let max = Float(videoCaptureDevice.activeFormat.videoMaxZoomFactor)
        return (min: 1.0, max)
    }

    public var depth: Bool {
        get {
            return safelyReadInternalState {
                return unsafeInternalState.depth
            }
        }
        set {
            safelyWriteInternalState { [weak self] in
                self?.unsafeInternalState.depth = newValue
                self?.unsafeResetCamera()
            }
        }
    }

    public var resolution: CameraResolutionPreset {
        get {
            return safelyReadInternalState {
                return unsafeInternalState.resolution
            }
        }
        set {
            safelyWriteInternalState { [weak self] in
                self?.unsafeInternalState.resolution = newValue
                self?.unsafeResetCamera()
            }
        }
    }

    public var position: AVCaptureDevice.Position {
        get {
            return safelyReadInternalState {
                return unsafeInternalState.position
            }
        }
        set {
            safelyWriteInternalState { [weak self] in
                self?.unsafeInternalState.position = newValue
                self?.unsafeResetCamera()
            }
        }
    }

    public var exposure: Float {
        get {
            safelyReadInternalState {
                unsafeInternalState.exposure
            }
        }
        set {
            safelyWriteInternalState { [weak self] in
                self?.unsafeInternalState.exposure = newValue
                self?.unsafeUpdateExposure()
            }
        }
    }

    public var supportedExposureRange: (min: Float, max: Float) {
        guard let videoCaptureDevice = videoCaptureDevice else {
            return (min: 0, max: 0)
        }
        return (
            min: videoCaptureDevice.minExposureTargetBias,
            max: videoCaptureDevice.maxExposureTargetBias
        )
    }

    deinit {
        for _ in 0 ..< maxSimultaneousFrames {
            outputSemaphore.signal()
        }
    }

    private func withLockedVideoCaptureDevice(_ callback: (AVCaptureDevice) -> Void) {
        guard
            let videoCaptureDevice = videoCaptureDevice,
            case .some = try? videoCaptureDevice.lockForConfiguration()
        else {
            return
        }
        defer {
            videoCaptureDevice.unlockForConfiguration()
        }
        callback(videoCaptureDevice)
    }

    private func unsafeUpdateZoom() {
        withLockedVideoCaptureDevice { device in
            let (min, max) = supportedZoomRange
            let clampedZoom = clamp(unsafeInternalState.zoom, min: min, max: max)
            device.videoZoomFactor = CGFloat(clampedZoom)
        }
    }

    private func unsafeUpdateExposure() {
        withLockedVideoCaptureDevice { device in
            device.exposureMode = .locked
            let (min, max) = supportedExposureRange
            let clampedExposure = clamp(unsafeInternalState.exposure, min: min, max: max)
            device.setExposureTargetBias(clampedExposure)
        }
    }

    private func notifyResolutionObservers() {
        resolutionObservers.forEach { observer in
            if !observer.isPaused {
                if let videoResolution = videoResolution {
                    observer.cameraManagerDidChange(videoResolution: videoResolution)
                }
                if let depthResolution = depthResolution {
                    observer.cameraManagerDidChange(depthResolution: depthResolution)
                }
            }
        }
    }

    private func setCaptureSessionPreset(withResolution preset: CameraResolutionPreset) {
        let preset: AVCaptureSession.Preset = preset.avCaptureSessionPreset
        if captureSession.canSetSessionPreset(preset) {
            captureSession.sessionPreset = preset
        }
    }

    private func unsafeSetupVideoCaptureDevice() -> Bool {
        videoCaptureDevice = unsafeInternalState.depth
            ? depthEnabledCaptureDevice(withPosition: unsafeInternalState.position)
            : captureDevice(withPosition: unsafeInternalState.position)
        return videoCaptureDevice != nil
    }

    private func unsafeAttemptToSetupCameraCaptureSession() -> Result<Void, CameraSetupError> {
        setCaptureSessionPreset(withResolution: unsafeInternalState.resolution)
        if !unsafeSetupVideoCaptureDevice() {
            return .failure(.failedToSetupVideoCaptureDevice)
        }

        if !setupVideoInput() {
            return .failure(.failedToSetupVideoInput)
        }

        if !setupVideoOutput() {
            return .failure(.failedToSetupDepthOutput)
        }

        if unsafeInternalState.depth {
            if !setupDepthOutput() {
                return .failure(.failedToSetupDepthOutput)
            }
        }

        unsafeConfigureActiveFormat()
        outputSynchronizer = unsafeInternalState.depth
            ? AVCaptureDataOutputSynchronizer(
                dataOutputs: [videoOutput, depthOutput]
            )
            : AVCaptureDataOutputSynchronizer(
                dataOutputs: [videoOutput]
            )
        outputSynchronizer?.setDelegate(self, queue: DispatchQueue.main)
        return .success(())
    }

    private func setupVideoInput() -> Bool {
        withLockedVideoCaptureDevice { device in
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure

                if let previousInput = videoCaptureDeviceInput {
                    captureSession.removeInput(previousInput)
                }
                videoCaptureDeviceInput = try? AVCaptureDeviceInput(device: device)
                guard let videoCaptureDeviceInput = videoCaptureDeviceInput else {
                    return
                }
                if captureSession.canAddInput(videoCaptureDeviceInput) {
                    captureSession.addInput(videoCaptureDeviceInput)
                } else {
                    return
                }
                return
            }
        }
        return true
    }

    private func setupVideoOutput() -> Bool {
        captureSession.removeOutput(videoOutput)
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey: videoPixelFormat,
        ] as [String: Any]
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video) {
                connection.isEnabled = true
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if unsafeInternalState.position == .front, connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
        } else {
            return false
        }
        return true
    }

    private func setupDepthOutput() -> Bool {
        if captureSession.outputs.contains(depthOutput) {
            captureSession.removeOutput(depthOutput)
        }
        depthOutput.alwaysDiscardsLateDepthData = false
        depthOutput.isFilteringEnabled = true
        if captureSession.canAddOutput(depthOutput) {
            captureSession.addOutput(depthOutput)
            if let connection = depthOutput.connection(with: .depthData) {
                connection.isEnabled = true
            }
        } else {
            return false
        }
        return true
    }

    private func attemptToSetupAudioCaptureSession() -> Bool {
        do {
            try audioCaptureDevice?.lockForConfiguration()
            audioCaptureSession.beginConfiguration()
            if !setupAudioInput(captureSession: audioCaptureSession) {
                return false
            }
            setupAudioOutput(captureSession: audioCaptureSession)
            audioOutput.setSampleBufferDelegate(self, queue: cameraOutputQueue)
            audioCaptureSession.commitConfiguration()
            audioCaptureDevice?.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    private func setupAudioOutput(captureSession: AVCaptureSession) {
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
            if let connection = audioOutput.connection(with: .audio) {
                connection.isEnabled = true
            }
        }
    }

    private func setupAudioInput(captureSession: AVCaptureSession) -> Bool {
        audioCaptureDevice = AVCaptureDevice.default(for: .audio)
        guard let audioCaptureDevice = audioCaptureDevice else {
            return false
        }
        if let previousInput = audioCaptureDeviceInput {
            captureSession.removeInput(previousInput)
        }
        audioCaptureDeviceInput = try? AVCaptureDeviceInput(device: audioCaptureDevice)
        guard let audioCaptureDeviceInput = audioCaptureDeviceInput else {
            return false
        }
        if captureSession.canAddInput(audioCaptureDeviceInput) {
            captureSession.addInput(audioCaptureDeviceInput)
        } else {
            return false
        }
        return true
    }

    private func unsafeConfigureActiveFormat() {
        withLockedVideoCaptureDevice { videoCaptureDevice in
            let searchDescriptor = CameraFormatSearchDescriptor(
                depthPixelFormatTypeRule: unsafeInternalState.depth ? .oneOf([depthPixelFormat]) : .any,
                depthDimensionsRule: unsafeInternalState.depth
                    ? .greaterThanOrEqualTo(Size<Int>(width: 640, height: 360))
                    : .any,
                videoDimensionsRule: .equalTo(unsafeInternalState.resolution.landscapeSize),
                frameRateRule: .greaterThanOrEqualTo(20),
                sortRule: .maximizeFrameRate,
                depthFormatSortRule: .maximizeDimensions
            )
            defer { unsafeUpdateZoom() }
            guard let searchResult = searchDescriptor.search(formats: videoCaptureDevice.formats) else {
                return
            }
            videoCaptureDevice.activeFormat = searchResult.format
            videoCaptureDevice.activeDepthDataFormat = searchResult.depthDataFormat
            videoCaptureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(videoMinFramesPerSecond))
            videoCaptureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(videoMaxFramesPerSecond))
            videoCaptureDevice
                .activeDepthDataMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(depthMinFramesPerSecond))
        }
    }

    private func unsafeResetCamera() {
        let isRunning = captureSession.isRunning
        if isRunning {
            captureSession.stopRunning()
        }
        try? videoCaptureDevice?.lockForConfiguration()
        defer {
            videoCaptureDevice?.unlockForConfiguration()
        }
        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        if case let .failure(error) = unsafeAttemptToSetupCameraCaptureSession() {
            print("Failed to set up camera capture session", error)
        }
        if !attemptToSetupAudioCaptureSession() {
            print("Failed to set up audio capture session")
        }
        captureSession.commitConfiguration()
        notifyResolutionObservers()
        if isRunning {
            captureSession.startRunning()
        }
    }

    public func setAutoFocusPoint(_ point: CGPoint) {
        withLockedVideoCaptureDevice { device in
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            }
        }
    }

    public func setAutoExposurePoint(_ point: CGPoint) {
        withLockedVideoCaptureDevice { device in
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
        }
    }

    private static let requiredPermissions: [PermissionVariant] = [
        .captureDevice(mediaType: .video),
        .captureDevice(mediaType: .audio),
        .microphone,
        .mediaLibrary,
    ]

    public static func requestCameraPermissions(_ callback: @escaping (Bool) -> Void) {
        requestPermissions(for: requiredPermissions) { success in
            callback(success)
        }
    }

    public static func hasCameraPermissions() -> Bool {
        return permissionStatus(for: requiredPermissions)
    }

    public static func hasSupportedCameraDevice(withPosition position: AVCaptureDevice.Position) -> Bool {
        return getDepthEnabledCaptureDevices(withPosition: position).count > 0
    }

    public var supportedISORange: (min: Float, max: Float) {
        guard let format = videoCaptureDevice?.activeFormat else {
            return (min: 0, max: 0)
        }
        return (min: format.minISO, max: format.maxISO)
    }

    public var iso: Float {
        return videoCaptureDevice?.iso ?? 0
    }

    public func setISO(_ iso: Float, _ completionHandler: @escaping () -> Void) {
        guard let videoCaptureDevice = videoCaptureDevice else {
            completionHandler()
            return
        }
        if case .some = try? videoCaptureDevice.lockForConfiguration() {
            let duration = videoCaptureDevice.exposureDuration
            videoCaptureDevice.exposureMode = .custom
            videoCaptureDevice.setExposureModeCustom(duration: duration, iso: iso) { _ in
                completionHandler()
            }
            videoCaptureDevice.unlockForConfiguration()
        } else {
            completionHandler()
        }
    }

    public var aperture: Float {
        return videoCaptureDevice?.lensAperture ?? 0
    }

    public func setupCameraCaptureSession(
        _ completionHandler: @escaping (Result<Void, CameraSetupError>) -> Void
    ) {
        cameraSetupQueue.async { [weak self] in
            guard let strongSelf = self else { return } // TODO: return failure
            let isRunning = strongSelf.captureSession.isRunning
            if isRunning {
                strongSelf.captureSession.stopRunning()
            }
            strongSelf.captureSession.beginConfiguration()
            if case let .failure(error) = strongSelf.unsafeAttemptToSetupCameraCaptureSession() {
                return completionHandler(.failure(error))
            }
            if !strongSelf.attemptToSetupAudioCaptureSession() {
                print("Failed to set up audio capture session")
                // TODO: should be failure
                return completionHandler(.success(()))
            }
            strongSelf.captureSession.commitConfiguration()
            if isRunning {
                strongSelf.captureSession.startRunning()
            }
            completionHandler(.success(()))
        }
    }

    public func startPreview() {
        cameraSetupQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if case .authorized = AVCaptureDevice.authorizationStatus(for: .video) {
                if !strongSelf.captureSession.isRunning {
                    strongSelf.captureSession.startRunning()
                    strongSelf.notifyResolutionObservers()
                }
            }
        }
    }

    public func stopPreview() {
        cameraSetupQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.captureSession.isRunning else {
                return
            }
            strongSelf.captureSession.stopRunning()
        }
    }

    public func convert(_ point: CGPoint,
                        fromView view: UIView,
                        resizeMode: ResizeMode) -> CGPoint {
        guard let resolution = videoResolution else {
            return .zero
        }
        let scale = scaleForResizing(resolution.cgSize(), to: view.frame.size, resizeMode: resizeMode)
        let scaledSize = Size<Float>(
            width: Float(resolution.width) * Float(scale),
            height: Float(resolution.height) * Float(scale)
        )
        let yMin = abs(Float(view.frame.height) - scaledSize.height) * 0.5
        let yMax = yMin + scaledSize.height
        let xMin = abs(Float(view.frame.width) - scaledSize.width) * 0.5
        let xMax = xMin + scaledSize.width
        let clampedX = clamp(Float(point.x), min: xMin, max: xMax) - xMin
        let clampedY = clamp(Float(point.y), min: yMin, max: yMax) - yMin
        return CGPoint(
            x: CGFloat(clampedY / scaledSize.height),
            y: CGFloat(1 - (clampedX / scaledSize.width))
        )
    }
}

extension Camera: AVCaptureDataOutputSynchronizerDelegate {
    public func dataOutputSynchronizer(
        _: AVCaptureDataOutputSynchronizer, didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        if paused { return }
        _ = outputSemaphore.wait(timeout: .distantFuture)
        defer {
            outputSemaphore.signal()
        }

        // output depth data
        if let synchronizedDepthData = collection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData {
            if !synchronizedDepthData.depthDataWasDropped {
                let orientation: CGImagePropertyOrientation = activeCaptureDevicePosition(session: captureSession) ==
                    .some(.front)
                    ? .leftMirrored : .right
                let depthData = synchronizedDepthData.depthData.applyingExifOrientation(orientation)
                delegate?.camera(self, didOutputDepthData: depthData)
            }
        }

        // output video data
        if let synchronizedVideoData = collection
            .synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData {
            if !synchronizedVideoData.sampleBufferWasDropped {
                delegate?.camera(self, didOutputVideoSampleBuffer: synchronizedVideoData.sampleBuffer)
            }

            if let focusPoint = videoCaptureDevice?.focusPointOfInterest {
                delegate?.camera(self, didFocusOn: focusPoint)
            }
        }
    }
}

extension Camera: AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        delegate?.camera(self, didOutputAudioSampleBuffer: sampleBuffer)
    }
}
