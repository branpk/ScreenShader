import Metal
import MetalKit

class MetalView: MTKView {
  var metalLayer: CAMetalLayer {
    return self.layer as! CAMetalLayer
  }

  override func makeBackingLayer() -> CALayer {
    return CAMetalLayer()
  }
}

class MetalRenderer {
  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private var textureCache: CVMetalTextureCache!
  private var activeEffectSource: String? = nil
  private var renderPipeline: MTLRenderPipelineState? = nil

  init(metalLayer: CAMetalLayer) {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Unable to access a Metal device on this system.")
    }
    self.device = device

    guard let queue = self.device.makeCommandQueue() else {
      fatalError("Could not create command queue.")
    }
    self.commandQueue = queue

    metalLayer.device = self.device
    metalLayer.pixelFormat = .bgra8Unorm
    metalLayer.framebufferOnly = true
    metalLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 1.0
    metalLayer.isOpaque = false
    metalLayer.backgroundColor = NSColor.clear.cgColor

    var cache: CVMetalTextureCache?
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &cache)
    if let createdCache = cache {
      self.textureCache = createdCache
    } else {
      fatalError("Could not create CVMetalTextureCache.")
    }
  }

  static func buildRenderPipeline(device: MTLDevice, effectSource: String) throws
    -> MTLRenderPipelineState
  {
    let librarySource = """
      #include <metal_stdlib>
      using namespace metal;

      struct ShaderInput {
        // A texture containing the input screen capture data.
        texture2d<float> inputTexture;
        // The texture coordinates for indexing into inputTexture at the current
        // position.
        float2 texCoord;
      };

      \(effectSource)

      struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
      };

      vertex VertexOut vertex_main(uint vertexId [[vertex_id]]) {
        float2 quadVertices[6] = {
          float2(-1.0, -1.0),
          float2( 1.0, -1.0),
          float2(-1.0,  1.0),
          float2(-1.0,  1.0),
          float2( 1.0, -1.0),
          float2( 1.0,  1.0)
        };

        VertexOut out;
        out.position = float4(quadVertices[vertexId], 0.0, 1.0);
        out.texCoord = float2(
          (quadVertices[vertexId].x + 1.0) * 0.5,
          (-quadVertices[vertexId].y + 1.0) * 0.5);
        return out;
      }

      fragment float4 fragment_main(
        VertexOut in [[stage_in]],
        texture2d<float> inTexture [[texture(0)]]
      ) {
        ShaderInput shaderInput;
        shaderInput.inputTexture = inTexture;
        shaderInput.texCoord = in.texCoord;
        return shaderFunction(shaderInput);
      }
      """

    let library = try device.makeLibrary(source: librarySource, options: nil)

    let vertexFunction = library.makeFunction(name: "vertex_main")
    let fragmentFunction = library.makeFunction(name: "fragment_main")

    guard vertexFunction != nil && fragmentFunction != nil else {
      throw NSError(
        domain: "MetalRenderer", code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: "Could not find vertex_main or fragment_main in effect source."
        ])
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
  }

  func setEffectSource(_ effectSource: String?) throws {
    guard let effectSource = effectSource else {
      self.activeEffectSource = nil
      self.renderPipeline = nil
      return
    }
    self.activeEffectSource = effectSource
    do {
      self.renderPipeline = try Self.buildRenderPipeline(
        device: self.device, effectSource: effectSource)
    } catch {
      self.renderPipeline = nil
      throw error
    }
  }

  func renderContentBuffer(window: NSWindow, contentBuffer: CVPixelBuffer) {
    guard let drawable = (window.contentView as? MetalView)?.metalLayer.nextDrawable() else {
      return
    }

    let width = CVPixelBufferGetWidth(contentBuffer)
    let height = CVPixelBufferGetHeight(contentBuffer)

    var tempTextureRef: CVMetalTexture?
    let status = CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      self.textureCache,
      contentBuffer,
      nil,
      .bgra8Unorm,
      width,
      height,
      0,
      &tempTextureRef)

    guard status == kCVReturnSuccess, let textureRef = tempTextureRef,
      let texture = CVMetalTextureGetTexture(textureRef)
    else {
      return
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].storeAction = .store
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

    guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    // Set scissor rect to exclude the menu bar.
    if let screen = NSScreen.main {
      let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0
      let visibleFrame = screen.visibleFrame
      let screenHeight = screen.frame.height
      let scissorRect = MTLScissorRect(
        x: Int(visibleFrame.origin.x * scaleFactor),
        y: Int((screenHeight - visibleFrame.origin.y - visibleFrame.height) * scaleFactor),
        width: Int(visibleFrame.width * scaleFactor),
        height: Int(visibleFrame.height * scaleFactor)
      )
      encoder.setScissorRect(scissorRect)
    }

    if let renderPipeline = self.renderPipeline {
      encoder.setRenderPipelineState(renderPipeline)
      encoder.setFragmentTexture(texture, index: 0)
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }

    encoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
