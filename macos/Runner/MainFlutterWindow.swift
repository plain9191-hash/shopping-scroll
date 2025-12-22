import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 창 크기 설정 (width: 1440, height: 990) - 데스크탑 스타일 (모바일 375x640 + 파스텔 배경)
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 990)
    let windowWidth: CGFloat = 1440
    let windowHeight: CGFloat = 990
    let windowX = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
    let windowY = (screenFrame.height - windowHeight) / 2 + screenFrame.origin.y
    let newFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    self.setFrame(newFrame, display: true)

    // 최소 창 크기 설정
    self.minSize = NSSize(width: 400, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
