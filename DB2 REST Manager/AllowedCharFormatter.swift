// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Formatter to verify that only listed characters are used.
///
/// This verifying formatter checks the input characters against
/// a provided character set and only returns true
class AllowedCharFormatter: InputValidationFormatter {
    private var _charSet: CharacterSet
    
    /// Predefined character sets
    struct AllowedChars {
        /// Characters, allowed in service names
        static let Name = CharacterSet.alphanumerics.union( CharacterSet( charactersIn: "-_$@#" ) )
    }
    
    /// Creates a new formatter for the given character set.
    ///
    /// - Parameter charSet: Lists all allowed characters
    init( charSet: CharacterSet ) {
        _charSet = charSet
        
        super.init()
    }
    
    /// Required (but not implemented) constructor for deserialization
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Ensures that all characters are in the provided set.
    ///
    /// - Parameter input: The string to verify
    /// - Returns: True if all characters are part of the set
    override func isValid( input: String ) -> Bool {
        var ret = true;
        
        for c in input.unicodeScalars {
            if _charSet.contains( c ) == false {
                ret = false;
                break;
            }
        }
        
        return ret;
    }
}
