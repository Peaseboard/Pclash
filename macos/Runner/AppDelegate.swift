import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  
  // Status bar (menu bar / tray) item
  private var statusItem: NSStatusItem!
  private var statusMenu: NSMenu!
  private var eventMonitor: EventMonitor?
  
  // Proxy state
  private var isSystemProxyEnabled = false
  private var proxyGroups: [(name: String, nodes: [String])] = []
  private var currentMode = "rule"
  private var trafficUp = "0 B"
  private var trafficDown = "0 B"
  
  // Flutter method channel
  private var channel: FlutterMethodChannel?
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    // Ensure app is fully active
    NSApp.setActivationPolicy(.regular)
    
    // Build and assign the main window menu
    NSApplication.shared.mainMenu = createMainMenu()
    
    // Set up Flutter method channel for proxy updates
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    channel = FlutterMethodChannel(name: "com.pclash.app/status_bar", binaryMessenger: controller.engine.binaryMessenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    
    // Create status bar (menu bar) item - like ClashX's cat icon
    setupStatusBar()
  }
  
  // Handle method calls from Flutter
  private func handleMethodCall(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "updateProxyGroups":
      if let args = call.arguments as? [String: Any],
         let groups = args["groups"] as? [[String: Any]] {
        proxyGroups.removeAll()
        for group in groups {
          let name = group["name"] as? String ?? "Unknown"
          let nodes = group["nodes"] as? [String] ?? []
          proxyGroups.append((name: name, nodes: nodes))
        }
        rebuildStatusMenu()
      }
      result(nil)
      
    case "updateTraffic":
      if let args = call.arguments as? [String: Any] {
        trafficUp = args["up"] as? String ?? "0 B"
        trafficDown = args["down"] as? String ?? "0 B"
        rebuildStatusMenu()
      }
      result(nil)
      
    case "updateMode":
      if let mode = call.arguments as? String {
        currentMode = mode
        rebuildStatusMenu()
      }
      result(nil)
      
    case "setProxyEnabled":
      if let enabled = call.arguments as? Bool {
        isSystemProxyEnabled = enabled
        rebuildStatusMenu()
      }
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // Set up macOS status bar (menu bar / tray) item
  private func setupStatusBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(named: NSImage.statusAvailableName)
    statusItem.button?.image?.size = NSSize(width: 16, height: 16)
    statusItem.button?.image?.isTemplate = true
    
    // Load pea icon from app bundle if available
    if let iconImage = NSImage(named: "AppIcon") {
      iconImage.size = NSSize(width: 16, height: 16)
      iconImage.isTemplate = false
      statusItem.button?.image = iconImage
    }
    
    // Build initial menu
    rebuildStatusMenu()
    
    // Monitor clicks outside the menu to hide it
    eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      if let strongSelf = self, strongSelf.statusMenu.superMenu != nil {
        NSMenu.popUpContextMenu(strongSelf.statusMenu, with: event, for: strongSelf.statusItem.button!)
      }
    }
  }
  
  // Rebuild the status bar menu (called when proxy data changes)
  private func rebuildStatusMenu() {
    statusMenu = NSMenu()
    
    // Status indicator
    let statusTitle = isSystemProxyEnabled ? "✅ 系统代理已开启" : "❌ 系统代理未开启"
    let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
    statusItem.isEnabled = false
    statusMenu.addItem(statusItem)
    
    statusMenu.addItem(NSMenuItem.separator())
    
    // System proxy toggle
    let toggleTitle = isSystemProxyEnabled ? "关闭系统代理" : "开启系统代理"
    let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleSystemProxy), keyEquivalent: "")
    toggleItem.target = self
    statusMenu.addItem(toggleItem)
    
    statusMenu.addItem(NSMenuItem.separator())
    
    // Mode selector
    let modeLabel = NSMenuItem(title: "代理模式: \(currentMode.uppercased())", action: nil, keyEquivalent: "")
    modeLabel.isEnabled = false
    statusMenu.addItem(modeLabel)
    
    let modeMenu = NSMenu()
    for mode in ["rule", "global", "direct"] {
      let modeItem = NSMenuItem(title: mode.uppercased(), action: #selector(changeMode(_:)), keyEquivalent: "")
      modeItem.target = self
      modeItem.representedObject = mode
      if mode == currentMode {
        modeItem.state = .on
      }
      modeMenu.addItem(modeItem)
    }
    let modeSelector = NSMenuItem(title: "模式", action: nil, keyEquivalent: "")
    modeSelector.submenu = modeMenu
    statusMenu.addItem(modeSelector)
    
    statusMenu.addItem(NSMenuItem.separator())
    
    // Proxy groups
    for group in proxyGroups {
      let groupMenu = NSMenu()
      for node in group.nodes.prefix(20) { // Limit to 20 nodes per group
        let nodeItem = NSMenuItem(title: node, action: #selector(selectProxy(_:)), keyEquivalent: "")
        nodeItem.target = self
        nodeItem.representedObject = ["group": group.name, "node": node]
        groupMenu.addItem(nodeItem)
      }
      if group.nodes.count > 20 {
        groupMenu.addItem(NSMenuItem(title: "... 还有 \(group.nodes.count - 20) 个节点", action: nil, keyEquivalent: ""))
        groupMenu.items.last?.isEnabled = false
      }
      let groupSelector = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
      groupSelector.submenu = groupMenu
      statusMenu.addItem(groupSelector)
    }
    
    statusMenu.addItem(NSMenuItem.separator())
    
    // Traffic info
    let trafficTitle = "↑ \(trafficUp)  ↓ \(trafficDown)"
    let trafficItem = NSMenuItem(title: trafficTitle, action: nil, keyEquivalent: "")
    trafficItem.isEnabled = false
    statusMenu.addItem(trafficItem)
    
    statusMenu.addItem(NSMenuItem.separator())
    
    // Settings
    let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
    settingsItem.target = self
    statusMenu.addItem(settingsItem)
    
    // Quit
    let quitItem = NSMenuItem(title: "退出 PClash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    statusMenu.addItem(quitItem)
    
    statusItem.menu = statusMenu
  }
  
  @objc private func toggleSystemProxy() {
    isSystemProxyEnabled.toggle()
    rebuildStatusMenu()
    // Notify Flutter
    channel?.invokeMethod("onToggleProxy", arguments: isSystemProxyEnabled)
  }
  
  @objc private func changeMode(_ sender: NSMenuItem) {
    if let mode = sender.representedObject as? String {
      currentMode = mode
      rebuildStatusMenu()
      channel?.invokeMethod("onChangeMode", arguments: mode)
    }
  }
  
  @objc private func selectProxy(_ sender: NSMenuItem) {
    if let info = sender.representedObject as? [String: String] {
      channel?.invokeMethod("onSelectProxy", arguments: info)
    }
  }
  
  @objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
    channel?.invokeMethod("onOpenSettings", arguments: nil)
  }
  
  private func createMainMenu() -> NSMenu {
    let mainMenu = NSMenu(title: "PClash")
    
    // App Menu
    let appItem = NSMenuItem()
    let appMenu = NSMenu(title: "PClash")
    appMenu.addItem(NSMenuItem(title: "关于 PClash", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "设置…", action: nil, keyEquivalent: ","))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "退出 PClash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    
    // File Menu
    let fileItem = NSMenuItem()
    let fileMenu = NSMenu(title: "文件")
    fileMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
    fileItem.submenu = fileMenu
    mainMenu.addItem(fileItem)
    
    // Edit Menu
    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "编辑")
    editMenu.addItem(NSMenuItem(title: "撤销", action: Selector("undo:"), keyEquivalent: "z"))
    editMenu.addItem(NSMenuItem(title: "重做", action: Selector("redo:"), keyEquivalent: "Z"))
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    editMenu.addItem(NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)
    
    // View Menu
    let viewItem = NSMenuItem()
    let viewMenu = NSMenu(title: "显示")
    viewMenu.addItem(NSMenuItem(title: "全屏", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"))
    viewItem.submenu = viewMenu
    mainMenu.addItem(viewItem)
    
    // Window Menu
    let windowItem = NSMenuItem()
    let windowMenu = NSMenu(title: "窗口")
    windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
    windowMenu.addItem(NSMenuItem(title: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
    windowItem.submenu = windowMenu
    mainMenu.addItem(windowItem)
    
    // Help Menu
    let helpItem = NSMenuItem()
    let helpMenu = NSMenu(title: "帮助")
    helpMenu.addItem(NSMenuItem(title: "PClash 帮助", action: nil, keyEquivalent: ""))
    helpItem.submenu = helpMenu
    mainMenu.addItem(helpItem)
    
    return mainMenu
  }
}

// Event monitor to handle menu clicks
class EventMonitor {
  private var monitor: Any?
  private let mask: NSEvent.EventTypeMask
  private let handler: (NSEvent?) -> Void
  
  init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
    self.mask = mask
    self.handler = handler
    self.monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
  }
  
  deinit {
    if let monitor = self.monitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}
