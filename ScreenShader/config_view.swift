import AppKit

class ConfigViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
  var config: Config! = nil
  var effects: Effects {
    return self.config.effects
  }
  var onConfigUpdate: () -> Void = {}
  var errorMessage: ErrorMessage! = nil

  private var tableView: NSTableView! = nil
  private var errorMessageField: NSTextField! = nil
  private var newEffectButton: NSButton! = nil
  private var contentPane: NSView! = nil
  private var effectToController: [UUID: EffectViewController] = [:]

  override func loadView() {
    let splitView = NSSplitView()
    splitView.dividerStyle = .thin
    splitView.isVertical = true
    splitView.translatesAutoresizingMaskIntoConstraints = false

    let tabsPane = NSStackView()
    tabsPane.orientation = .vertical
    tabsPane.spacing = 10
    tabsPane.translatesAutoresizingMaskIntoConstraints = false

    self.tableView = NSTableView()
    self.tableView.delegate = self
    self.tableView.dataSource = self
    self.tableView.headerView = nil
    self.tableView.focusRingType = .none

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Tabs"))
    column.title = "Tabs"
    self.tableView.addTableColumn(column)

    let scrollView = NSScrollView()
    scrollView.documentView = self.tableView
    scrollView.hasVerticalScroller = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    self.errorMessageField = NSTextField()
    self.errorMessageField.isEditable = false
    self.errorMessageField.drawsBackground = false
    self.errorMessageField.font = NSFont.monospacedSystemFont(
      ofSize: NSFont.systemFontSize, weight: .regular)
    self.errorMessageField.textColor = .red
    self.errorMessageField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    self.errorMessageField.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    self.errorMessageField.translatesAutoresizingMaskIntoConstraints = false

    self.errorMessage.onMessageChanged = {
      self.errorMessageField.stringValue = self.errorMessage.get() ?? ""
      self.errorMessageField.isHidden = self.errorMessage.get() == nil
    }
    self.errorMessage.onMessageChanged?()

    self.newEffectButton = NSButton(
      title: "New Effect", target: self, action: #selector(self.newEffect))
    self.newEffectButton.translatesAutoresizingMaskIntoConstraints = false

    tabsPane.addArrangedSubview(scrollView)
    tabsPane.addArrangedSubview(self.errorMessageField)
    tabsPane.addArrangedSubview(self.newEffectButton)

    self.contentPane = NSView()

    splitView.addArrangedSubview(tabsPane)
    splitView.addArrangedSubview(self.contentPane)

    NSLayoutConstraint.activate([
      scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

      self.errorMessageField.leftAnchor.constraint(equalTo: tabsPane.leftAnchor, constant: 10),
      self.errorMessageField.rightAnchor.constraint(equalTo: tabsPane.rightAnchor, constant: -10),

      self.newEffectButton.heightAnchor.constraint(equalToConstant: 30),
      self.newEffectButton.bottomAnchor.constraint(equalTo: tabsPane.bottomAnchor, constant: -10),

      self.contentPane.topAnchor.constraint(equalTo: splitView.topAnchor),
      self.contentPane.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),

      tabsPane.widthAnchor.constraint(equalTo: splitView.widthAnchor, multiplier: 0.3),
    ])

    self.view = splitView
    if self.effects.effectList().count > 0 {
      self.selectTab(index: 0)
    }
  }

  private func selectTab(index: Int) {
    self.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    self.tableView.scrollRowToVisible(index)
  }

  @objc private func newEffect() {
    let _ = self.effects.new()
    self.tableView.reloadData()
    self.selectTab(index: self.effects.effectList().count - 1)
    self.onConfigUpdate()
  }

  private func onUpdateEffect(effect: UUID) {
    self.tableView.reloadData()
    self.onConfigUpdate()
  }

  private func onDeleteEffect(effect: UUID) {
    self.tableView.reloadData()
    self.tableView.deselectAll(nil)
    self.effectToController.removeValue(forKey: effect)
    self.onConfigUpdate()
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    return self.effects.effectList().count
  }

  func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int)
    -> Any?
  {
    let effect = self.effects.effectList()[row]
    let name = self.effects.getName(effect: effect)
    let isActive = self.effects.isActive(effect: effect)
    return isActive ? "\(name) (active)" : name
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let selectedRow = self.tableView.selectedRow
    if selectedRow >= 0 && selectedRow < self.effects.effectList().count {
      let selectedEffect = self.effects.effectList()[selectedRow]

      if !self.effectToController.keys.contains(selectedEffect) {
        let controller = EffectViewController()
        controller.effects = self.effects
        controller.effect = selectedEffect
        controller.onUpdate = { self.onUpdateEffect(effect: selectedEffect) }
        controller.onDelete = { self.onDeleteEffect(effect: selectedEffect) }
        self.effectToController[selectedEffect] = controller
      }

      let controller = self.effectToController[selectedEffect]!
      self.contentPane.subviews = [controller.view]

      NSLayoutConstraint.activate([
        controller.view.leadingAnchor.constraint(equalTo: self.contentPane.leadingAnchor),
        controller.view.trailingAnchor.constraint(equalTo: self.contentPane.trailingAnchor),
        controller.view.topAnchor.constraint(equalTo: self.contentPane.topAnchor),
        controller.view.bottomAnchor.constraint(equalTo: self.contentPane.bottomAnchor),
      ])
    } else {
      self.contentPane.subviews = []
    }
    self.tableView.reloadData()
  }

  func refreshActiveEffects() {
    self.tableView.reloadData()
    for controller in self.effectToController.values {
      controller.refreshActiveCheckbox()
    }
  }
}

class ConfigWindowController: NSWindowController {
  var config: Config! = nil
  var errorMessage: ErrorMessage! = nil
  var onConfigUpdate: () -> Void = {}

  private var configViewController: ConfigViewController! = ConfigViewController()

  func createUI() {
    guard let window = self.window else { return }

    window.title = "ScreenShader Settings"

    self.configViewController.config = self.config
    self.configViewController.onConfigUpdate = self.onConfigUpdate
    self.configViewController.errorMessage = self.errorMessage
    window.contentView?.addSubview(self.configViewController.view)

    NSLayoutConstraint.activate([
      self.configViewController.view.leadingAnchor.constraint(
        equalTo: window.contentView!.leadingAnchor),
      self.configViewController.view.trailingAnchor.constraint(
        equalTo: window.contentView!.trailingAnchor),
      self.configViewController.view.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
      self.configViewController.view.bottomAnchor.constraint(
        equalTo: window.contentView!.bottomAnchor),
    ])
  }

  func refreshActiveEffects() {
    self.configViewController.refreshActiveEffects()
  }
}
