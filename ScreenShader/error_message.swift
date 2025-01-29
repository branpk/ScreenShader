class ErrorMessage {
  private var message: String? = nil
  var onMessageChanged: (() -> Void)? = nil

  func get() -> String? {
    return self.message
  }

  func set(_ message: String) {
    self.message = message
    self.onMessageChanged?()
  }

  func clear() {
    if self.message != nil {
      self.message = nil
      self.onMessageChanged?()
    }
  }
}
