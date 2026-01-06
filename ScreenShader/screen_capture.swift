import ScreenCaptureKit
import AppKit

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

        Logger.shared.log("startCapture: Available displays from SCShareableContent:")
        for d in content.displays {
          Logger.shared.log("  - displayID: \(d.displayID), width: \(d.width), height: \(d.height)")
        }

        Logger.shared.log("startCapture: Available NSScreens:")
        for screen in NSScreen.screens {
          let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
          Logger.shared.log("  - displayID: \(displayID), frame: \(screen.frame), isMain: \(screen == NSScreen.main)")
        }

        // Find the display matching NSScreen.main
        guard let mainScreen = NSScreen.main,
              let mainDisplayID = mainScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
          Logger.shared.log("startCapture: No main screen found, skipping capture.")
          self.capturing = false
          return
        }

        Logger.shared.log("startCapture: Main screen displayID: \(mainDisplayID), frame: \(mainScreen.frame)")

        guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
          Logger.shared.log("startCapture: No displays found, skipping capture.")
          self.capturing = false
          return
        }

        Logger.shared.log("startCapture: Selected display - displayID: \(display.displayID), width: \(display.width), height: \(display.height)")

        let excludedWindows = content.windows.filter { window in
          self.excludedWindowIDs.contains(window.windowID)
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        let scaleFactor = mainScreen.backingScaleFactor

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(CGFloat(display.width) * scaleFactor)
        streamConfig.height = Int(CGFloat(display.height) * scaleFactor)
        Logger.shared.log("startCapture: Stream config - width: \(streamConfig.width), height: \(streamConfig.height), scaleFactor: \(scaleFactor)")
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
        print("Failed to start screen capture: \(error.localizedDescription)")
        self.capturing = false
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

  func restartCapture() {
    stopCapture()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.startCapture()
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
