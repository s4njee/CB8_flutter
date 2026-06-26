import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Desktop sizing: keep the window usable — a minimum so it can't collapse,
    // and a sensible default on first launch.
    self.minSize = NSSize(width: 480, height: 600)
    self.setContentSize(NSSize(width: 1000, height: 760))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
