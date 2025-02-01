import ScreenCaptureKit

class ScreenCapture {
  var config: Config! = nil
  var excludedWindowIDs: [CGWindowID] = []
  var onFrameReceived: (CVPixelBuffer) -> Void = { _ in }
  private var capturing: Bool = false
  private var stream: SCStream?
  private var streamOutput: StreamOutput?
  private let streamQueue = DispatchQueue(label: "ScreenCaptureKitStreamQueue")

  func startCapture() {
    if self.capturing {
      return
    }
    self.capturing = true

    Task {
      do {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
          fatalError("No displays found.")
        }

        let excludedWindows = content.windows.filter { window in
          self.excludedWindowIDs.contains(window.windowID)
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(CGFloat(display.width) * scaleFactor)
        streamConfig.height = Int(CGFloat(display.height) * scaleFactor)
        streamConfig.minimumFrameInterval = CMTime(
          value: 1, timescale: CMTimeScale(self.config.targetFPS))
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.capturesAudio = false
        streamConfig.showsCursor = false

        self.stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        self.streamOutput = StreamOutput(onFrameReceived: self.onFrameReceived)

        try self.stream!.addStreamOutput(
          self.streamOutput!, type: .screen, sampleHandlerQueue: self.streamQueue)

        try await self.stream!.startCapture()
        print("Started screen capture")
      } catch {
        fatalError("Failed to start screen capture: \(error.localizedDescription)")
      }
    }
  }

  func stopCapture() {
    if !self.capturing {
      return
    }
    self.capturing = false

    Task {
      do {
        try await self.stream?.stopCapture()
        self.stream = nil
        self.streamOutput = nil
        print("Stopped screen capture.")
      } catch {
        print("Failed to stop screen capture: \(error.localizedDescription)")
      }
    }
  }

  func setCapturing(_ capturing: Bool) {
    if capturing {
      self.startCapture()
    } else {
      self.stopCapture()
    }
  }
}

private class StreamOutput: NSObject, SCStreamOutput {
  private let onFrameReceived: (CVPixelBuffer) -> Void

  init(onFrameReceived: @escaping (CVPixelBuffer) -> Void) {
    self.onFrameReceived = onFrameReceived
  }

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == .screen else { return }
    if let buffer = sampleBuffer.imageBuffer {
      self.onFrameReceived(buffer)
    }
  }
}
