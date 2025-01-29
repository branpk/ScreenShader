import AppKit

class SourceTextView: NSTextView {
  override func insertTab(_ sender: Any?) {
    self.insertText("  ", replacementRange: self.selectedRange())
  }
}

class EffectViewController: NSViewController, NSTextFieldDelegate, NSTextViewDelegate {
  var effects: Effects! = nil
  var effect: UUID! = nil
  var onUpdate: () -> Void = {}
  var onDelete: () -> Void = {}

  private var stackView: NSStackView! = nil
  private var nameField: NSTextField! = nil
  private var activeButton: NSButton! = nil
  private var deleteButton: NSButton! = nil
  private var shaderField: NSTextView! = nil
  private var saveButton: NSButton! = nil

  override func loadView() {
    self.view = NSView()
    self.view.translatesAutoresizingMaskIntoConstraints = false

    self.stackView = NSStackView()
    self.stackView.orientation = .vertical
    self.stackView.spacing = 10
    self.stackView.alignment = .leading
    self.stackView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(self.stackView)

    self.nameField = NSTextField()
    self.nameField.placeholderString = "Effect Name"
    self.nameField.focusRingType = .none
    self.nameField.delegate = self
    self.nameField.translatesAutoresizingMaskIntoConstraints = false
    self.nameField.stringValue = self.effects.getName(effect: self.effect)
    self.stackView.addArrangedSubview(self.nameField)

    self.activeButton = NSButton(
      checkboxWithTitle: "Active (only one effect can be active at a time)",
      target: self,
      action: #selector(self.toggleActive))
    self.activeButton.translatesAutoresizingMaskIntoConstraints = false
    self.activeButton.state = self.effects.isActive(effect: self.effect) ? .on : .off
    self.stackView.addArrangedSubview(self.activeButton)

    self.deleteButton = NSButton(
      title: "Delete effect",
      target: self,
      action: #selector(self.deleteEffect))
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = false
    self.stackView.addArrangedSubview(self.deleteButton)

    self.shaderField = SourceTextView()
    self.shaderField.isEditable = true
    self.shaderField.isVerticallyResizable = true
    self.shaderField.isHorizontallyResizable = true
    self.shaderField.font = NSFont.monospacedSystemFont(
      ofSize: NSFont.systemFontSize, weight: .regular)
    self.shaderField.string = self.effects.getShader(effect: self.effect)
    self.shaderField.delegate = self
    self.shaderField.allowsUndo = true

    let shaderScrollView = NSScrollView()
    shaderScrollView.documentView = self.shaderField
    shaderScrollView.hasVerticalScroller = true
    shaderScrollView.hasHorizontalScroller = true
    shaderScrollView.translatesAutoresizingMaskIntoConstraints = false
    self.stackView.addArrangedSubview(shaderScrollView)

    self.saveButton = NSButton(
      title: "Save",
      target: self,
      action: #selector(self.onSaveButton))
    self.saveButton.translatesAutoresizingMaskIntoConstraints = false
    self.saveButton.isEnabled = false
    self.stackView.addArrangedSubview(self.saveButton)

    NSLayoutConstraint.activate([
      self.stackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 10),
      self.stackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -10),
      self.stackView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
      self.stackView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -10),

      self.shaderField.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
    ])
  }

  @objc func toggleActive() {
    self.effects.toggleActive(effect: self.effect)
    self.onUpdate()
  }

  @objc func deleteEffect() {
    self.effects.delete(effect: self.effect)
    self.onDelete()
  }

  @objc func onSaveButton() {
    self.effects.setShader(effect: self.effect, shader: self.shaderField.string)
    self.saveButton.isEnabled = false
    self.onUpdate()
  }

  func controlTextDidChange(_ obj: Notification) {
    let newName = self.nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if !newName.isEmpty {
      self.effects.setName(effect: self.effect, newName: self.nameField.stringValue)
      self.onUpdate()
    }
  }

  func textDidChange(_ notification: Notification) {
    self.saveButton.isEnabled = true
  }

  func refreshActiveCheckbox() {
    self.activeButton.state = self.effects.isActive(effect: self.effect) ? .on : .off
  }
}
