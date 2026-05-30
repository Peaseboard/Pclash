import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    // Build and assign the main menu
    NSApplication.shared.mainMenu = createMainMenu()
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
    editMenu.addItem(NSMenuItem(title: "撤销", action: #selector(NSApplication.undo(_:)), keyEquivalent: "z"))
    editMenu.addItem(NSMenuItem(title: "重做", action: #selector(NSApplication.redo(_:)), keyEquivalent: "Z"))
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
