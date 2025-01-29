import AppKit

class Metrics {
  private var nextFrameID: Int = 0
  private var screenCaptureTimestamps: [Int: Double] = [:]
  private var numRenders: Int = 0
  private var totalLatency: Double = 0
  private var prevUpdateTimestamp: Double = 0

  var screenCaptureFPS: Double = 0
  var renderFPS: Double = 0
  var averageLatency: Double = 0

  func newFrameID() -> Int {
    let frameID = self.nextFrameID
    self.nextFrameID += 1
    return frameID
  }

  func recordScreenCapture(frameID: Int) {
    let timestamp = ProcessInfo.processInfo.systemUptime
    self.screenCaptureTimestamps[frameID] = timestamp
  }

  func recordRender(frameID: Int) {
    let timestamp = ProcessInfo.processInfo.systemUptime
    if let screenCaptureTimestamp = self.screenCaptureTimestamps[frameID] {
      let latency = timestamp - screenCaptureTimestamp
      self.numRenders += 1
      self.totalLatency += latency
    }
  }

  func updateStats() {
    let now = ProcessInfo.processInfo.systemUptime
    let delta = now - self.prevUpdateTimestamp
    self.prevUpdateTimestamp = now

    self.screenCaptureFPS = Double(self.screenCaptureTimestamps.count) / delta
    self.renderFPS = Double(self.numRenders) / delta
    self.averageLatency = self.numRenders == 0 ? 0 : self.totalLatency / Double(self.numRenders)

    self.screenCaptureTimestamps.removeAll()
    self.numRenders = 0
    self.totalLatency = 0
  }

  func printStats() {
    print("Screen capture FPS: \(self.screenCaptureFPS)")
    print("Render FPS: \(self.renderFPS)")
    print("Average latency (ms): \(self.averageLatency * 1000)")
  }
}
