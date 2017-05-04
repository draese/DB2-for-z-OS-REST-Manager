// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Formatter that is used to verify the input in a host name text field.
///
/// # From Wikipedia:
/// Hostnames are composed of series of labels concatenated with dots, as are all 
/// domain names. For example, "en.wikipedia.org" is a hostname. Each label must 
/// be from 1 to 63 characters long, and the entire hostname (including the
/// delimiting dots but not a trailing dot) has a maximum of 253 ASCII characters.
/// The Internet standards (Requests for Comments) for protocols mandate that 
/// component hostname labels may contain only the ASCII letters 'a' through 'z' 
/// (in a case-insensitive manner), the digits '0' through '9', and the hyphen ('-'). 
/// The original specification of hostnames in RFC 952, mandated that labels could 
/// not start with a digit or with a hyphen, and must not end with a hyphen. However, 
/// a subsequent specification (RFC 1123) permitted hostname labels to start with 
/// digits. No other symbols, punctuation characters, or white space are permitted.
/// While a hostname may not contain other characters, such as the underscore 
/// character (_), other DNS names may contain the underscore. Systems such as
/// DomainKeys and service records use the underscore as a means to assure that their 
/// special character is not confused with hostnames. 
/// For example, _http._sctp.www.example.com specifies a service pointer for an
/// SCTP capable webserver host (www) in the domain example.com. Note that some 
/// applications (e.g. Microsoft Internet Explorer) won't work correctly if any part 
/// of the hostname contains an underscore character. One common cause of
/// non-compliance with this specification is that the rules are not applied 
/// consistently across the board when domain names are chosen and registered.
class HostNameFormatter: InputValidationFormatter {
    /// Check that the passed in string is a valid host name.
    ///
    /// - Parameter input: The input string of the text field
    /// - Returns: True if the passed in string is a valid host name
    override func isValid( input: String ) -> Bool {
        let allowedCharSet = CharacterSet( charactersIn: "-_" ).union( CharacterSet.letters ).union( CharacterSet.decimalDigits )
        let labels         = input.components( separatedBy: "." )
        var ret            = true
        
        // no empty labels allowed
        if input.contains( ".." ) {
            ret = false
        }
        
        for labelIndex in 0..<labels.count {
            let label = labels[labelIndex]
            
            if !label.isEmpty {
                // single label cannot exceed 63 characters
                if label.characters.count > 63 {
                    ret = false
                }
                
                // should only contain letters, digits and -,_
                if ret {
                    for c in label.unicodeScalars {
                        if allowedCharSet.contains( c ) == false {
                            ret = false
                            break
                        }
                    }
                }
                
                // if number only, don't exceed valid IP range 0/1..255
                if ret {
                    if label.hasPrefix( "0" ) && label.characters.count > 1 {
                        ret = false;
                    }
                    else if let n = Int( label ) {
                        // only 1st and 4th element needs to be non-null
                        if labelIndex == 1 || labelIndex == 2 {
                            if n > 255 {
                                ret = false
                            }
                            else if n == 0 && label.characters.count > 1 {
                                ret = false
                            }
                        }
                        else if n < 1 || n > 255 {
                            ret = false
                        }
                    }
                }
            }
            
            if ret == false {
                break
            }
        }
        
        return ret
    }
}
