import AVFoundation
import ImageUtils
import MetalKit
import UIKit

// the max number of concurrent drawables supported by CoreAnimation
private let maxSimultaneousFrames: Int = 3

open class CameraEffectView: MTKView {
  private lazy var commandQueue: MTLCommandQueue! = {
    let maxCommandBufferCount = 10
    guard let commandQueue = device?.makeCommandQueue(maxCommandBufferCount: maxCommandBufferCount) else {
      fatalError("Failed to create Metal command queue")
    }
    return commandQueue
  }()

  private lazy var context: CIContext! = {
    guard let device = device else {
      fatalError("Failed to get Metal device")
    }
    return CIContext(mtlDevice: device, options: [
      .workingColorSpace: NSNull(),
      .highQualityDownsample: false,
    ])
  }()

  public override var isPaused: Bool {
    didSet {
      effectSession.isPaused = isPaused
    }
  }

  private var imageExtent: CGRect = .zero
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private let renderSemaphore = DispatchSemaphore(value: maxSimultaneousFrames)
  private let effectSession = EffectSession()

  public weak var camera: Camera? {
    didSet {
      effectSession.camera = camera
    }
  }

  public var resizeMode: ResizeMode = .scaleAspectWidth
  public var blurAperture: Float = 2.4

  public var previewMode: EffectPreviewMode {
    get {
      return effectSession.previewMode
    }
    set {
      effectSession.previewMode = newValue
    }
  }

  public init() {
    guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
      fatalError("Failed to create Metal device")
    }
    super.init(frame: .zero, device: mtlDevice)
    framebufferOnly = false
    preferredFramesPerSecond = 24
    colorPixelFormat = .bgra8Unorm
    autoResizeDrawable = false
    enableSetNeedsDisplay = false
    drawableSize = frame.size
    contentScaleFactor = UIScreen.main.scale
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    contentScaleFactor = UIScreen.main.scale
  }

  public required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    for _ in 0 ..< maxSimultaneousFrames {
      renderSemaphore.signal()
    }
  }

  public override func didMoveToSuperview() {
    super.didMoveToSuperview()
    drawableSize = frame.size
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    drawableSize = frame.size
  }

  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    let startTime = CFAbsoluteTimeGetCurrent()
    defer {
      let executionTime = CFAbsoluteTimeGetCurrent() - startTime
    }
    render()
  }

  private func render() {
    _ = renderSemaphore.wait(timeout: DispatchTime.distantFuture)
    autoreleasepool {
      guard let image = effectSession.makeEffectImage(
        blurAperture: blurAperture,
        size: frame.size,
        resizeMode: resizeMode
      ) else {
        renderSemaphore.signal()
        return
      }
      imageExtent = image.extent
      present(image: image)
    }
  }

  private func present(image: CIImage) {
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      renderSemaphore.signal()
      return
    }
    defer { commandBuffer.commit() }
    guard let drawable = currentDrawable else {
      renderSemaphore.signal()
      return
    }
    context.render(
      image,
      to: drawable.texture,
      commandBuffer: commandBuffer,
      bounds: CGRect(origin: .zero, size: drawableSize),
      colorSpace: colorSpace
    )
    commandBuffer.addCompletedHandler { [weak self] _ in
      self?.renderSemaphore.signal()
    }
    commandBuffer.present(drawable, afterMinimumDuration: 1 / Double(preferredFramesPerSecond))
  }

  public func captureDevicePointConverted(fromLayerPoint layerPoint: CGPoint) -> CGPoint {
    let scale = scaleForResizing(imageExtent.size, to: frame.size, resizeMode: resizeMode)
    return CGPoint(
      x: abs((layerPoint.x / scale) / frame.width),
      y: abs(1 - (layerPoint.y / scale) / frame.height)
    )
  }
}
