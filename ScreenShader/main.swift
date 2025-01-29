import AppKit
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
  private var config: Config!
  private var configChanged: Bool = false
  private var metrics: Metrics = Metrics()
  private var errorMessage: ErrorMessage = ErrorMessage()
  private var overlayController: OverlayController!
  private var statusItem: NSStatusItem!
  private var configWindowController: ConfigWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    if CGRequestScreenCaptureAccess() {
      print("Screen capture access granted.")
    } else {
      print("Screen capture access denied.")
      NSApp.terminate(nil)
    }
    
    self.config = Config.load()
    let configTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      if self.configChanged {
        self.config.save()
        self.configChanged = false
      }
    }
    RunLoop.current.add(configTimer, forMode: .common)

    let metricsTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
      self.metrics.updateStats()
      self.metrics.printStats()
    }
    RunLoop.current.add(metricsTimer, forMode: .common)

    setupMenuBar()
    createMenuBarIcon()

    self.overlayController = OverlayController(
      config: self.config, metrics: self.metrics, errorMessage: self.errorMessage)

    self.refreshConfig()
    self.openConfigWindow()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    self.openConfigWindow()
    return true
  }

  private func refreshConfig() {
    self.statusItem.button?.image = self.getMenuBarIcon()

    self.overlayController.refreshConfig()
    self.configWindowController?.refreshActiveEffects()

    // Indicate that the config should be saved to disk.
    self.configChanged = true
  }

  private func setupMenuBar() {
    let mainMenu = NSMenu()

    let appMenu = NSMenuItem()
    mainMenu.addItem(appMenu)
    let appSubMenu = NSMenu()
    appMenu.submenu = appSubMenu

    let settingsItem = NSMenuItem(
      title: "Settings", action: #selector(self.openConfigWindow), keyEquivalent: ",")
    settingsItem.target = self
    appSubMenu.addItem(settingsItem)

    appSubMenu.addItem(NSMenuItem.separator())
    appSubMenu.addItem(
      NSMenuItem(
        title: "Quit ScreenShader", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

    let editMenu = NSMenuItem()
    mainMenu.addItem(editMenu)
    let editSubMenu = NSMenu(title: "Edit")
    editMenu.submenu = editSubMenu

    editSubMenu.addItem(
      NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
    editSubMenu.addItem(
      NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
    editSubMenu.addItem(NSMenuItem.separator())
    editSubMenu.addItem(
      NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    editSubMenu.addItem(
      NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    editSubMenu.addItem(
      NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    editSubMenu.addItem(
      NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

    NSApp.mainMenu = mainMenu
  }

  private func createMenuBarIcon() {
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = self.statusItem.button {
      button.image = self.getMenuBarIcon()
      button.action = #selector(self.toggleEffect)
      button.target = self
    }
  }

  private func getMenuBarIcon() -> NSImage {
    let active = self.config.effects.anyEffectActive()
    let systemSymbolName = active ? "paintbrush.fill" : "paintbrush"
    return NSImage(
      systemSymbolName: systemSymbolName, accessibilityDescription: "ScreenShader")!
  }

  @objc private func toggleEffect() {
    if self.config.effects.anyEffectActive() {
      self.config.effects.deactivateAll()
    } else {
      self.config.effects.activateDefault()
    }
    self.refreshConfig()
  }

  @objc private func openConfigWindow() {
    if self.configWindowController != nil {
      self.configWindowController!.window?.makeKeyAndOrderFront(nil)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.center()

    self.configWindowController = ConfigWindowController(window: window)
    self.configWindowController!.config = self.config
    self.configWindowController!.onConfigUpdate = { [weak self] in
      self?.refreshConfig()
    }
    self.configWindowController!.errorMessage = self.errorMessage
    self.configWindowController!.createUI()

    window.makeKeyAndOrderFront(nil)
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
