// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Verifies that the passed in string doesn't contain whitespace characters.
///
/// This formatter is associated with the userID and password fields. It only
/// makes sure that the text field dpesn't contain whitespace characters.
class AuthFormatter: InputValidationFormatter {
    /// Returns true as long as there are no whitespaces present.
    ///
    /// - Parameter input: The string to verify
    /// - Returns: True if there are no whitespaces
    override func isValid(input: String) -> Bool {
        var ret = true
        
        for c in input.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains( c ) {
                ret = false
                break
            }
        }
        
        return ret
    }
}
