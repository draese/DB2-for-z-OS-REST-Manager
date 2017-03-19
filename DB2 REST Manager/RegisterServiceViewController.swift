// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Cocoa

/// View controller for the panel that allows creating of new services.
///
/// The application allows to create/define a new REST service by asking the
/// user to provide information like name, description and of course the SQL
/// that is executed upon service invokation. These information is queried 
/// from within an own sheet (from the main story board) which is associated
/// with this view controller. The segue from the main view controller to
/// this controller ensures that the instance of this class is provided 
/// with a rest client and the list of already known services.
class RegisterServiceViewController: NSViewController, NSTextFieldDelegate, NSTextStorageDelegate {
    @IBOutlet weak var _registerButton: NSButton!
    @IBOutlet weak var _nameField: NSTextField!
    @IBOutlet weak var _descriptionField: NSTextField!
    @IBOutlet weak var _collectionField: NSTextField!
    @IBOutlet weak var _bindOptionsButton: NSButton!
    @IBOutlet var _sqlView: NSTextView!
    
    /// a RESTClient clone of the 'main' rest client
    fileprivate var _restClient: RESTClient?
    
    /// stores the optional bind settings (sub view)
    fileprivate var _bindOptions = Dictionary<String,String>()
    
    /// static cache for all available bind options
    fileprivate static var _createOptions: CreateOptions?
    
    /// known services (to disallow duplicate service names)
    var existingServices: Array<Service>?
    
    /// code, provided by main view controller to be executed upon completion
    var completionHandler: (()->Void)?
    
    
    /// Called when the view resources are loaded.
    ///
    /// This override is used to register formatter/filter instances to the
    /// various text fields.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // register formatters (as input filters) to the text fields
        _nameField.formatter = MaxLenFormatter( maxLength: 128, nextFormatter: AllowedCharFormatter( charSet: AllowedCharFormatter.AllowedChars.Name ) )
        _descriptionField.formatter = MaxLenFormatter(maxLength: 250)
        _collectionField.formatter = MaxLenFormatter(maxLength: 128, nextFormatter: AllowedCharFormatter( charSet: AllowedCharFormatter.AllowedChars.Name ) )
        
        // register as delegate to the SQL view
        _sqlView.textStorage?.delegate = self
        
        // we already know the bind options, so enable the button
        if RegisterServiceViewController._createOptions != nil {
            _bindOptionsButton.isEnabled = true
        }
    }
    
    /// Called when we have a transition to the bind options.
    ///
    /// The bind options are displayed if the corresponding button is
    /// pressed on the "register service" view. This is done via segue
    /// from the main story board. This `prepare` method is used to 
    /// prepare the view controller of the bind options.
    ///
    /// - Parameters:
    ///   - segue: The segue that triggered the call (ignored)
    ///   - sender: Sender of the call (ignored)
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let ovc = segue.destinationController as? OptionsViewController {
            ovc.selectableOptions = RegisterServiceViewController._createOptions
            ovc.selectedOptions = _bindOptions
            
            // get back the options if the sheet is closed
            ovc.completionHandler = { (sender: OptionsViewController) -> Void in
                self._bindOptions = sender.selectedOptions
            }
        }
    }
    
    /// Called whenever a text field content changed.
    ///
    /// The event is used to figure out if all text fields (including the
    /// SQL view) contain valid values and to enable the "register" button
    /// accordingly.
    ///
    /// - Parameter obj: The notification object (ignored)
    override func controlTextDidChange(_ obj: Notification) {
        // delegate verification to local helper
        _registerButton.isEnabled = checkInputFields()
    }
    
    /// Notification handler for changes in SQL text box
    ///
    /// The SQL text is edited in a text view and not (like the other in
    /// a text field). To detect text changes (verifying the content), this
    /// handler is registered to the text field.
    ///
    /// - Parameters:
    ///   - textStorage: the storage behind the text view (ignored)
    ///   - editedMask: information about editing (ignored)
    ///   - editedRange: range of change (ignored)
    ///   - delta: delta before/after change (ignored)
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        _registerButton.isEnabled = checkInputFields()
    }
    
    /// Action handler for the cancel button.
    ///
    /// The "register new service" view is shown as a modal sheet in front of
    /// the main window content. If this handler is called due to the cancel
    /// button action, we just close the view.
    ///
    /// - Parameter sender: The cancel button (ignored)
    @IBAction func cancelPressed(_ sender: Any) {
        self.view.window?.close()
    }
    
    /// Action handler for the register button.
    ///
    /// The register button is only enabled if the content of the text fields
    /// and SQL view is valid. Therefore, the content doesn't need to be checked
    /// in this handler again. This method extracts the content from the text
    /// fields and calls the `registerNew` method of the `RESTClient` class to
    /// create a new service definition on DB2 side. The result of the operation
    /// is then delivered asynchronous to the REST client's consumer.
    ///
    /// - Parameter sender: The register button (ignored)
    @IBAction func registerPressed(_ sender: Any) {
        if let client = _restClient {
            let name        = _nameField.stringValue
            let description = _descriptionField.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines )
            let collection  = _collectionField.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines )
            let sql         = _sqlView.textStorage?.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines ) ?? ""
            
            NSLog( "Request creation of new service with name: \(name)" )
            
            // Asynchronous request to register service via the RESTClient class.
            // The serviceCreatedSuccessfully method will be called upon success.
            client.registerNew(serviceWithName: name, description: description, collectionID: collection, sql: sql, bindOptions: _bindOptions )
        }
    }
    
    /// Helper to verify the content of the input text fields.
    ///
    /// This method is called whenever the content of any of the text fields or the
    /// SQL text view is changed. It returns true if all of the required fields
    /// have some non - blank content. This is used to enable/disable the "register"
    /// button.
    ///
    /// - Returns: True if the required fields have valid input
    private func checkInputFields() -> Bool {
        var ret = false
        
        // name and SQL text are required
        if let sql = _sqlView.string {
            ret = _nameField.stringValue.characters.count > 0 && sql.characters.count > 0
        }

        // check for duplicate service names
        if ret {
            if let knowServices = self.existingServices {
                for service in knowServices {
                    if service.name.lowercased() == _nameField.stringValue.lowercased() {
                        ret = false
                    }
                }
            }
        }

        return ret
    }
}

// MARK: - Consumer interface of the RESTClient
extension RegisterServiceViewController: RESTClientConsumer {
    /// Property for the rest client.
    ///
    /// The here passed in RESTClient isn't used by this controller
    /// directly. Instead, a "clone" is created, based on the configuration
    /// of the passed in client. The difference is that the clone client
    /// has this `RESTClientConsumer` being registered for notifications.
    ///
    /// - Note: Setting the `RESTClient` via this property might actually
    ///         trigger the receive of the bind options from DB2. These
    ///         options are then cached and there is not another call to
    ///         receive the options later in the application.
    var restClient : RESTClient? {
        set(deriveFrom) {
            if let df = deriveFrom {
                // create a clone
                _restClient = RESTClient( consumer: self, deriveFrom: df )
                
                // receive bind options if they are not cached yet. They
                // will be delivered asynchronously to createOptionsReceived
                if RegisterServiceViewController._createOptions == nil {
                    _restClient?.receiveCreateOptions()
                }
            }
            else {
                _restClient = nil
            }
        }
        
        get {
            return _restClient
        }
    }
    
    /// Called if the service was created successfully.
    ///
    /// The `RESTClient` calls this method to notify that the asynchronous
    /// request to register a new service (started via 'registerNew') finished
    /// successfully. This method just notifies the completion handler (of the
    /// ViewController class), which then reloads the service list.
    ///
    /// - Note: This method is called from a service thread. To change UI settings,
    ///         the call has to be moved back to the main/UI thread.
    func serviceCreatedSuccessfully() {
        NSLog( "Service was created successfully" )
        
        // move operation to main/UI thread
        OperationQueue.main.addOperation {
            self.view.window?.close()
            
            if let handler = self.completionHandler {
                // notify about the completion
                handler()
            }
        }
    }
    
    /// Called if the list of bind options was received successfully.
    ///
    /// The `RESTClient` calls this method if the list of valid bind 
    /// options was received successfully. These settings are then
    /// cached (and exposed through the bind options dialog) because
    /// they can't change w/o DB2 being updated.
    ///
    /// - Note: This method is called from a service thread. To change UI
    ///         settings, the call has to be moved back to the main/UI
    ///         thread.
    ///
    /// - Parameter options: The received possible bind options
    func createOptionsReceived( options: CreateOptions ) {
        // cache the bind options
        RegisterServiceViewController._createOptions = options
        
        // enable the "Bind Options" button from within main thread
        OperationQueue.main.addOperation {
            if let button = self._bindOptionsButton {
                button.isEnabled = true
            }
        }
    }
    
    /// Called by `RESTClient` if an error occurred.
    ///
    /// All `RESTClient` operations are performed asynchronous. Not only
    /// the success (or receive options) notifications are delivered
    /// asynchronous but also errors that happened while creating a new
    /// service or receiving the options. This handler is called to deliver
    /// the error details. It displays the error message to the user.
    ///
    /// - Note: This method is called from a service thread. To change UI
    ///         settings, the call has to be moved back to the main/UI
    ///         thread.
    ///
    /// - Parameters:
    ///   - requestType: The operation that was performed
    ///   - code: Error code, describing the issue
    ///   - message: Server side error message
    func handleError( requestType: RequestType, code: ClientError, message: String? ) {
        NSLog( "ERROR registering the new serive: code=\(code), msg=\(message)" )
        
        // move the display of an error dialog back into the main thread
        OperationQueue.main.addOperation {
            let alert = NSAlert()
            
            alert.alertStyle = NSCriticalAlertStyle
            alert.addButton(withTitle: "Close" )
            
            // header text
            switch( requestType ) {
            case RequestType.RegisterNewService:
                alert.messageText = "Error registering services"
            case RequestType.ReceiveOptions:
                alert.messageText = "Bind options unavailable"
            default:
                alert.messageText = "Unexpected service response"
            }
            
            // map error code to error message
            switch( code ) {
            case ClientError.SQLError:
                alert.informativeText = "The SQL contains an error. The service was not created."
            case ClientError.OptionsNotFound:
                alert.informativeText = "Trying to receive the available bind options from DB2 failed.\n" +
                                        "The default bind options will be used."
            default:
                alert.informativeText = "An unknown error occurred."
            }
            
            // append server side error message if available
            if let m = message {
                alert.informativeText += "\n\nOriginal server response:\n-------------------------------------\n\(m)"
            }
            
            // show the error message as sheet
            if let win = self.view.window {
                alert.beginSheetModal(for: win) { (resp: NSModalResponse) in }
            }
            else {
                alert.runModal()
            }
        }
    }
}
