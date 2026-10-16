import Foundation

/// Shared protocol between the Mac Catalyst app and the AppKit plugin bundle.
/// The plugin's principal class must conform to this protocol.
@objc(StatusBarBridgeProtocol) protocol StatusBarBridgeProtocol {
    func setupStatusBar()
    func hideAllWindows()
    /// Headless-Betrieb: kein Menüleisten-Symbol, Fenster werden sofort und dauerhaft versteckt.
    func startHeadlessMode()
}
