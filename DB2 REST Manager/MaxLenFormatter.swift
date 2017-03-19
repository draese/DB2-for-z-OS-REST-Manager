// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Ensures the maximum length of characters in an input field.
///
/// This formatter is supposed to be chained with other formatters. While
/// an instance of this class makes sure that a maximum length is not 
/// exceeded, it delegates the verification of the content to the "next"
/// formatter, provided to a constructor.
class MaxLenFormatter: InputValidationFormatter {
    private let _maxLen: Int
    
    /// The formatter to verify the content
    var nextFormatter: InputValidationFormatter?
    
    /// Creates a new formatter for maximum length.
    ///
    /// - Parameter maxLength: The total length in characters
    init( maxLength: Int ) {
        _maxLen = maxLength
        super.init()
    }
    
    /// Creates a new formatter with a chained "next".
    ///
    /// - Parameters:
    ///   - maxLength: The maximum length in characters
    ///   - nextFormatter: The formatter to verify the content
    init( maxLength: Int, nextFormatter: InputValidationFormatter ) {
        _maxLen = maxLength
        self.nextFormatter = nextFormatter
        super.init()
    }
    
    /// Required but not implemented deserialization constructor
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Verifies the total length of the input string.
    ///
    /// After validating the length of the input string, the
    /// method delegates the content verifcation to the "next"
    /// formatter.
    ///
    /// - Parameter input: The string to verify
    /// - Returns: True if length and content are valid
    override func isValid(input: String) -> Bool {
        var ret = input.characters.count <= _maxLen
        
        if ret {
            if let next = self.nextFormatter {
                ret = next.isValid(input: input)
            }
        }
        
        return ret
    }
}
