// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Base class for validating formatters.
///
/// Formatters are normally used to transform an object into a readable string
/// or vice versa but in this case we use it to prevent the user from entering
/// values in a text field that are not valid. We for example ensure that a 
/// port number text field can only have decimal digits. This is the "abstract"
/// base class, delivering the functionality to be set as formatter to text
/// fields. The deriving classes only have to implement the `isValid` method
/// to check if the passed in string matches their specifications.
class InputValidationFormatter: Formatter {
    /// Delivers a string representation of the passed in object
    ///
    /// - Parameter obj: The object to transform to string
    /// - Returns: The converted or empty string
    override func string(for obj: Any?) -> String {
        return (obj as? String) ?? ""
    }
    
    /// Returns the value for a passed in string.
    ///
    /// In our case, as we only use the formatter for input validation, we
    /// simply return a string for a string value.
    ///
    /// - Parameters:
    ///   - obj: The object to be generated (output pointer)
    ///   - string: The string to return as object
    ///   - error: Potential error information (ignored)
    /// - Returns: True (always the case here) on success
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        obj!.pointee = string as AnyObject
        return true
    }
    
    /// Called to verify if the passed in (partial) string is valid.
    ///
    /// This method is the main purpose of these filter classes. This implementation
    /// delegates the evaluation to the "abstract" `isValid` methid.
    ///
    /// - Parameters:
    ///   - partialString: The string to validate
    ///   - newString: new input pointer (ignored)
    ///   - error: pointer for output error information (ignored)
    /// - Returns: Result of the`isValid` call
    override func isPartialStringValid( _ partialString: String,
                                        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
                                        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        return isValid( input: partialString )
    }
    
    /// "Abstract" method to detect if a provided string is valid.
    ///
    /// This method has to be overridden to provide a mechanism to tell if the
    /// passed in string is valid for the associated text field. If the filter
    /// is for example used to check a port number, this method would verify
    /// that the string can be mapped to a valid numeric port number.
    /// This "abstract" implementation causes a fatal error.
    ///
    /// - Parameter input: The string to verify
    /// - Returns: True if the string was verified successfully
    func isValid( input: String ) -> Bool {
        fatalError( "isValid(input:) has not been implemented" )
    }
}
