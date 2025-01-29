import AppKit
import Metal
import MetalKit

class OverlayController: NSObject, MTKViewDelegate {
  private var config: Config
  private var metrics: Metrics
  private var errorMessage: ErrorMessage
  private var window: NSWindow!
  private var screenCapture: ScreenCapture!
  private var renderer: MetalRenderer!
  private var contentBuffer: CVPixelBuffer?
  private var frameID: Int?

  init(config: Config, metrics: Metrics, errorMessage: ErrorMessage) {
    self.config = config
    self.metrics = metrics
    self.errorMessage = errorMessage
    super.init()

    let contentRect = NSScreen.main!.frame

    self.window = NSWindow(
      contentRect: contentRect,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    self.window.isOpaque = false
    self.window.backgroundColor = .clear
    self.window.level = .screenSaver
    self.window.ignoresMouseEvents = true
    self.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let metalView = MetalView(frame: contentRect)
    metalView.delegate = self
    metalView.wantsLayer = true
    self.window.contentView = metalView
    self.window.makeKeyAndOrderFront(nil)

    self.renderer = MetalRenderer(metalLayer: metalView.metalLayer)

    self.screenCapture = ScreenCapture()
    self.screenCapture.config = self.config
    self.screenCapture.excludedWindowIDs = [CGWindowID(self.window.windowNumber)]
    self.screenCapture.onFrameReceived = { [weak self] contentBuffer in
      self?.receiveFrame(contentBuffer: contentBuffer)
    }
  }

  func receiveFrame(contentBuffer: CVPixelBuffer) {
    let frameID = self.metrics.newFrameID()
    self.metrics.recordScreenCapture(frameID: frameID)

    self.frameID = frameID
    self.contentBuffer = contentBuffer

    self.render()
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    // self.render()
  }

  func render() {
    if let contentBuffer = self.contentBuffer, let frameID = self.frameID {
      self.renderer.renderContentBuffer(window: self.window, contentBuffer: contentBuffer)

      self.metrics.recordRender(frameID: frameID)
      self.frameID = nil
      self.contentBuffer = nil
    }
  }

  func refreshConfig() {
    let activeEffect = self.config.effects.getActiveEffect()
    let active = activeEffect != nil

    let activeEffectShader = active ? self.config.effects.getShader(effect: activeEffect!) : nil

    do {
      try self.renderer.setEffectSource(activeEffectShader)
      self.errorMessage.clear()
    } catch {
      print("Effect shader error: \(error.localizedDescription)")
      self.errorMessage.set(error.localizedDescription)
    }

    // TODO: The window is briefly visible with the previous effect applied.
    // self.window.setIsVisible(active)
    // self.screenCapture.setCapturing(active)

    self.window.setIsVisible(true)
    self.screenCapture.setCapturing(true)
  }
}
