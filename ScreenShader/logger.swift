import Foundation

class Logger {
  static let shared = Logger()
  private let logFile: URL
  private let dateFormatter: DateFormatter

  private init() {
    // Use app bundle's parent directory for logging
    let bundlePath = Bundle.main.bundlePath
    let projectDir = (bundlePath as NSString).deletingLastPathComponent
    logFile = URL(fileURLWithPath: projectDir).appendingPathComponent("ScreenShader.log")

    dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

    // Clear log on start
    try? "".write(to: logFile, atomically: true, encoding: .utf8)
    log("Logger initialized, log file: \(logFile.path)")
  }

  func log(_ message: String) {
    let timestamp = dateFormatter.string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"

    print(logMessage, terminator: "")

    if let handle = try? FileHandle(forWritingTo: logFile) {
      handle.seekToEndOfFile()
      if let data = logMessage.data(using: .utf8) {
        handle.write(data)
      }
      handle.closeFile()
    } else {
      try? logMessage.write(to: logFile, atomically: true, encoding: .utf8)
    }
  }

  var logFilePath: String {
    return logFile.path
  }
}
