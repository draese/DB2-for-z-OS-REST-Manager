// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Cocoa

@NSApplicationMain

/// # Delegate for application events.
///
/// This is the default AppDelegate implementation, not performing
/// any additional initialization or cleanup in its current
/// implementation.
class AppDelegate: NSObject, NSApplicationDelegate {
    /// Called when the application got loaded.
    ///
    /// - Parameter aNotification: The notification object (ignored)
    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    /// Called when the application got loaded.
    ///
    /// - Parameter aNotification: The notification object (ignored)
    func applicationWillTerminate(_ aNotification: Notification) {
    }
}
