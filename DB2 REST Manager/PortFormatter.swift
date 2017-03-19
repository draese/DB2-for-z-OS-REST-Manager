// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Verifies that only valid port numbers can be entered.
///
/// The formatter ensures that only numeric values on the range between 1 
/// and 64K can be entered into the associated text field.
class PortFormatter: InputValidationFormatter {
    /// Verifies that the string represents a valid port number
    ///
    /// - Parameter input: The string to verify
    /// - Returns: True if string is a valid port number
    override func isValid( input: String ) -> Bool {
        var ret = false

        if input.isEmpty {
            ret = true
        }
        else {
            if let value = Int( input ) {
                if value > 0 && value <= 65535 {
                    ret = true
                }
            }
        }
        
        return ret
    }
}
