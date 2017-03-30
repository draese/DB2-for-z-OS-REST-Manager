// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Cocoa

/// # Main View controller of the application.
///
/// This is the view controller that handles the UI for configuring the
/// connection parameters and for showing the already registered services.
/// The UI is stored on a tab view, where the first page is connection
/// parameters and the second page the table view with services. The
/// transition between both pages is done programmatically. The different
/// delegates and data sources are implemented as extensions to this
/// controller class.
class ViewController: NSViewController {
    @IBOutlet weak var _mainWindowTabView: NSTabView!
    @IBOutlet weak var _connectButton: NSButton!
    @IBOutlet weak var _connectHostName: NSTextField!
    @IBOutlet weak var _connectPort: NSTextField!
    @IBOutlet weak var _connectUseSSL: NSButton!
    @IBOutlet weak var _connectUser: NSTextField!
    @IBOutlet weak var _connectPassword: NSSecureTextField!
    @IBOutlet weak var _connectURLLabel: NSTextField!
    @IBOutlet weak var _serviceTableView: NSTableView!
    @IBOutlet weak var _dropServiceButton: NSButton!
    
    /// main instance of the RESTClient to talk to DB2
    fileprivate var _restClient: RESTClient?
    
    /// received list of know/registered services
    fileprivate var _servicesList: Array<Service>?
    
    /// constant definitions for user settings
    private static let UD_KEY_HOST    = "hostName"
    private static let UD_KEY_PORT    = "portNumber"
    private static let UD_KEY_SSL     = "isSSL"
    private static let UD_KEY_USER    = "userName"
    private static let UD_KEY_PASSWD  = "password"
    
    /// name of the segue, getting from main view to "register new service"
    private static let SEGUE_REGSITER = "registerServiceSegue"
    
    /// Computed R/O property to get the DB2 REST URL based on user input
    fileprivate var urlString: String {
        get {
            var urlLabel: String
            
            if _connectUseSSL.state == NSOnState {
                urlLabel = "https://"
            }
            else {
                urlLabel = "http://"
            }
            
            if _connectHostName.stringValue.isEmpty {
                urlLabel += "<host>:"
            }
            else {
                urlLabel += _connectHostName.stringValue + ":"
            }
            
            if let pVal = Int( _connectPort.stringValue ) {
                if pVal > 0 {
                    urlLabel += _connectPort.stringValue
                }
                else {
                    urlLabel += "<port>"
                }
            }
            else {
                urlLabel += "<port>"
            }
            
            return urlLabel
        }
    }
    
    /// Called after view got loaded / initialized.
    ///
    /// This override registers filters to the input text fields and
    /// loads the last used values back from user defaults into the UI.
    override func viewDidLoad() {
        super.viewDidLoad()

        // validate the content of text fields while typing
        _connectHostName.formatter = MaxLenFormatter( maxLength: 253, nextFormatter: HostNameFormatter() )
        _connectPort.formatter = PortFormatter()
        _connectUser.formatter = MaxLenFormatter( maxLength: 8, nextFormatter: AuthFormatter() )
        _connectPassword.formatter = MaxLenFormatter( maxLength: 8, nextFormatter: AuthFormatter() )

        restoreSettings()
    }

    /// Called when the application disappers (is closed).
    ///
    /// The handler here stores the current user input in the user
    /// defaults and then actually terminates the application as closing
    /// the main window is supposed to finish the application.
    override func viewDidDisappear() {
        storeSettings()
        NSApplication.shared().terminate(self)
    }
    
    /// Called on transition from main view to register new.
    ///
    /// The transition from the main view to the sheet that allows the creation
    /// of a new service is done via story board segue. This preapre method
    /// passes in the REST client and list of know services to the view controller
    /// that is responsible (RegisterServiceViewController) for handling the UI
    /// of the sheet that takes the parameters for the new service.
    ///
    /// - Parameters:
    ///   - segue: The story board seque to identify the transition
    ///   - sender: Sender of the event (ignored)
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == ViewController.SEGUE_REGSITER {
            let registerController = segue.destinationController as! RegisterServiceViewController
            
            // the regsheet will derive its own client from our RESTClient
            registerController.restClient = _restClient
            
            // allow checking for duplicate service names
            registerController.existingServices = _servicesList
            
            // refresh the services table upon completion (successful registration)
            registerController.completionHandler = { () -> Void in
                self._restClient?.receiveServices()
            }
        }
    }
    
    /// Local helper to store the UI input in user defaults.
    ///
    /// The user shouldn't need to enter the same connection settings like the
    /// host name or port whenever the application is restarted. This private
    /// helper method therefore takes the UI input and stores the values in the
    /// user defaults. It is called just before the application terminates.
    /// The password is not stored (by default) due to security concerns. If
    /// you want to store the password anyway, you have to specify the STOREPASSWD
    /// define on the compile.
    private func storeSettings() {
        let ud = UserDefaults.standard
        
        ud.set( _connectHostName.stringValue, forKey: ViewController.UD_KEY_HOST )
        ud.set( _connectPort.stringValue, forKey: ViewController.UD_KEY_PORT )
        ud.set( _connectUseSSL.state == NSOnState , forKey: ViewController.UD_KEY_SSL )
        ud.set( _connectUser.stringValue, forKey: ViewController.UD_KEY_USER )

        // by default, I don't store passwords (because they end up in clear text on disk)
        // Specify STOREPASSWD in SWIFT_ACTIVE_COMPILATION_CONDITIONS to enable password storing
        #if STOREPASSWD
            ud.set( _connectPassword.stringValue, forKey: ViewController.UD_KEY_PASSWD )
        #else
            ud.set( "", forKey: ViewController.UD_KEY_PASSWD )
        #endif
    }
    
    /// Private helper to restore values from user default to UI.
    ///
    /// This helper is reloading the values, that were stored on the last application
    /// termination, back from the user defaults into the current UI controls. It is
    /// called after the view is loaded.
    private func restoreSettings() {
        let ud = UserDefaults.standard
        _connectHostName.stringValue = ud.string( forKey: ViewController.UD_KEY_HOST ) ?? ""
        _connectPort.stringValue = ud.string(forKey: ViewController.UD_KEY_PORT ) ?? "446"
        
        if ud.bool(forKey: ViewController.UD_KEY_SSL ) {
            _connectUseSSL.state = NSOnState
        }
        else {
            _connectUseSSL.state = NSOffState
        }
        
        _connectUser.stringValue = ud.string(forKey: ViewController.UD_KEY_USER ) ?? ""
        
        // by default, I don't store passwords (because they end up in clear text on disk)
        // Specify STOREPASSWD in SWIFT_ACTIVE_COMPILATION_CONDITIONS to enable password storing
        #if STOREPASSWD
            _connectPassword.stringValue = ud.string(forKey: ViewController.UD_KEY_PASSWD ) ?? ""
        #else
            _connectPassword.stringValue = ""
        #endif
        
        _connectURLLabel.stringValue = self.urlString + "/services"
        _connectButton.isEnabled = checkInputFields()
    }
}

// MARK: Handling the Connection Settings
extension ViewController: NSTextFieldDelegate {
    /// Called whenever the state of the SSL checkbox is changed.
    /// This method just regenerates the content of the URL label to
    /// reflect the change in the SSL selection.
    /// - Parameter sender: The SSL checkbox (ignored)
    @IBAction func sslCheckBoxClicked(_ sender: Any) {
        _connectURLLabel.stringValue = self.urlString + "/services"
    }
    
    
    /// Called when the connect button is pressed.
    /// The handler then creates an URL based on the entered conenction
    /// settings and generates a new REST client to trigger the receive
    /// of the list of services from DB2. As soon as these services are
    /// received, the REST consumer will switch from the connection
    /// settings tab to the services list tab.
    ///
    /// - Parameter sender: The connect button (ignored)
    @IBAction func connectPressed( sender: NSButton ) {
        NSLog( "User requesting list of services" )
        
        // disable all controls
        setConnectControlEnablement(newState: false)
        
        _restClient = nil
        _servicesList = nil
        
        // create a new URL and REST client
        if let url = URL( string: self.urlString ) {
            _restClient = RESTClient( consumer: self, url: url, userID: _connectUser.stringValue, password: _connectPassword.stringValue )
            
            // this will eventually trigger the "servicesReceived" method
            _restClient!.receiveServices()
        }
    }
    
    
    /// Called whenever text in any of the text fields changes.
    /// The event is used to update the URL label, showing the concatenated
    /// URL while the user types changes in the text field.
    ///
    /// - Parameter obj: A notification object (ignored)
    override func controlTextDidChange(_ obj: Notification) {
        _connectURLLabel.stringValue = self.urlString + "/services"
        _connectButton.isEnabled = checkInputFields()
    }
    
    
    /// Private helper to adjust the enablement of connect controls.
    /// This method is used to either enable or disable all the controls
    /// (text fields, buttons) together based on the new input state. This
    /// is for example used to disable all controls while the list of known
    /// DB2 services is received.
    ///
    /// - Parameter newState: enables controls if true, disables otherwise
    fileprivate func setConnectControlEnablement( newState: Bool ) -> Void {
        _connectHostName.isEnabled = newState
        _connectPort.isEnabled = newState
        _connectUseSSL.isEnabled = newState
        _connectUser.isEnabled = newState
        _connectPassword.isEnabled = newState
        
        if newState {
            _connectButton.isEnabled = checkInputFields()
        }
        else {
            _connectButton.isEnabled = false
        }
    }
    
    /// Private helper to validate that input fields contain correct values.
    /// This helper is called whenever the application needs to decide to either
    /// enable the "connect" button (all input is valid) or disable it if input
    /// is missing. Therefore, this helper is called with every key stroke in 
    /// the connection settings tab.
    ///
    /// - Returns: True if all input is valid and connect can be pressed
    fileprivate func checkInputFields() -> Bool {
        let hostName   = _connectHostName.stringValue
        let portNumber = _connectPort.stringValue
        var ret        = true
        
        // validate that a host name is given
        if hostName.isEmpty == false {
            if hostName.hasPrefix( "." ) || hostName.hasSuffix( "." ) {
                ret = false
            }
        }
        else {
            ret = false
        }
        
        // ensure that we have a port number
        if ret {
            if let pVal = Int( portNumber ) {
                if pVal < 1 {
                    ret = false
                }
            }
            else {
                ret = false
            }
        }
        
        if ret {
            // having userID/password would also be helpful
            if _connectUser.stringValue.isEmpty ||
               _connectPassword.stringValue.isEmpty {
                ret = false
            }
        }
        
        return ret
    }
}

// MARK: DataSource and Delegate handler for Services Table
extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
    /// definition of column identifiers
    private enum Col {
        static let Name        = "nameColumn"
        static let Description = "descriptionColumn"
        static let Collection  = "collectionColumn"
        static let URL         = "urlColumn"
    }
    
    /// Returns the displayed content of the services table.
    ///
    /// This method is called by the table view to query the content that
    /// is supposed to be displayed in a specific row/column of our list
    /// of know DB2 REST services.
    ///
    /// - Parameters:
    ///   - tableView: The table view with the services list (ignored)
    ///   - tableColumn: The column for which to get the content
    ///   - row: The row for which to get the content
    /// - Returns: delivers a string to be displayed in the table view
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var ret = ""
        
        if let sl = _servicesList {
            if row < sl.count {
                let service = sl[row]  // map row to entry in services array
                
                if let id = tableColumn?.identifier {
                    // map column ID to member of Service
                    switch( id ) {
                    case Col.Name:
                        ret = service.name
                    case Col.Description:
                        ret = service.description
                    case Col.Collection:
                        ret = service.collectionID
                    case Col.URL:
                        ret = service.url.absoluteString
                    default:
                        ret = "N/A"  // should not happen
                    }
                }
            }
        }
        
        return ret
    }
    
    /// Delivers the total amount of know services.
    ///
    /// The "list" of known services is represented by an array of the
    /// Service class. This array was received by the REST client when 
    /// the connect button was pressed. The amount of rows in the table
    /// equals the amount of Service instances in that array. This method
    /// is called by the table view to determine the amount of rows.
    ///
    /// - Parameter tableView: The services table (ignored)
    /// - Returns: The amount of known services.
    func numberOfRows(in tableView: NSTableView) -> Int {
        return _servicesList?.count ?? 0
    }

    /// Called whenever the selection of the service table changes.
    ///
    /// This handler is used to enable the "Drop Service" button if there
    /// is a service selected and to disable it otherwise.
    ///
    /// - Parameter notification: The notification object (ignored)
    func tableViewSelectionDidChange( _ notification: Notification ) {
        _dropServiceButton.isEnabled = (_serviceTableView.selectedRow != -1)
    }
    
    /// Action handler for the "Drop Service" button.
    ///
    /// This handler is invoked if the "Delete/Drop" service button is
    /// clicked. It shows an alert message to gather the user's confirmation
    /// and then uses the REST client to actually drop the currently selected
    /// service.
    ///
    /// - Parameter sender: The drop button (ignored)
    @IBAction func deleteServiceClicked( _ sender: Any ) {
        let row = _serviceTableView.selectedRow

        _dropServiceButton.isEnabled = false
        
        if let services = _servicesList {
            // get the currently selected service
            if row >= 0 && row < services.count {
                let alert = NSAlert()
                
                // prepare a warning message
                alert.alertStyle      = NSAlertStyle.warning
                alert.messageText     = "Really want to drop the service?"
                alert.informativeText = "Are you sure that you want to delete the service '\(services[row].name)' permanently?"
                alert.addButton(withTitle: "Cancel")
                alert.addButton(withTitle: "Drop")
                
                alert.beginSheetModal(for: self.view.window!, completionHandler: { (response: NSModalResponse) in
                    if response == NSAlertSecondButtonReturn {
                        // user pressed "Drop", so use REST client to remove service
                        self._restClient?.drop( service: services[row] )
                    }
                    else {
                        self._dropServiceButton.isEnabled = true
                    }
                })
                
            }
        }
    }
    
    /// Called when the user wants to go back to connection settings.
    ///
    /// The connection settings and the actual list of services are shown
    /// on two tab view pages. If the "back" button is pressed, we only 
    /// have to switch back to the first tab view page.
    ///
    /// - Parameter sender: The back button (ignored)
    @IBAction func backToConnectionPressed( _ sender: Any ) {
        _mainWindowTabView.selectTabViewItem(at: 0)
    }
}

// MARK: RESTClient protocol implementation
extension ViewController: RESTClientConsumer {
    /// Called by the REST client to deliver the list of known services.
    ///
    /// This method is called in response to the `receiveServices` method
    /// call of the `RESTClient` class. It delivers the list of known DB2
    /// REST services as an array of `Service` instances. 
    ///
    /// - Note: The method is called from within a background thread. UI
    ///         elements can't directly be manipulated from within this
    ///         thread!
    ///
    /// - Parameter services: The list of known DB2 REST services
    func servicesReceived( services: Array<Service> ) {
        NSLog( "Services received (count=\(services.count))" )
        OperationQueue.main.addOperation {
            // switch to 2nd page of tab view with the services table
            self.setConnectControlEnablement(newState: true)
            self._mainWindowTabView.selectTabViewItem(at: 1)
            
            // if list is empty: display an alert sheet
            if services.count == 0 {
                let alert = NSAlert()
                
                alert.alertStyle = NSWarningAlertStyle
                alert.addButton(withTitle: "OK" )
                alert.messageText = "No services found"
                alert.informativeText = "This program displays the user defined REST services only. " +
                    "The system provided services are filtered out.\n" +
                    "Currently, there is no user definded REST service existing. Use the " +
                "\"Register new...\" button to register the first service."
                
                if let win = self.view.window {
                    alert.beginSheetModal(for: win) { (resp: NSModalResponse) in
                        self.setConnectControlEnablement(newState: true)
                    }
                }
            }
            
            // tell the table view to reload
            self._servicesList = services
            self._serviceTableView.reloadData()
        }
    }
    
    /// Called by the `RESTClient` if a drop service was successful.
    ///
    /// This callback method is invoked by the `RESTClient` if a service
    /// was dropped successfully. This handler will then remove the entry
    /// from the table view as well.
    ///
    /// - Note: The method is called from within a background thread. UI
    ///         elements can't directly be manipulated from within this
    ///         thread!
    ///
    /// - Parameter service: The service that got dropped
    func serviceDroppedSuccessfully( service: Service ) {
        NSLog( "Service \(service.name) dropped successfully" )
        OperationQueue.main.addOperation {
            if var services = self._servicesList {
                for idx in 0 ..< services.count {
                    if services[idx].name == service.name {
                        services.remove(at: idx)
                        
                        // services is a copy of _servicesList. So pass the
                        // result list back and reload table data
                        self._servicesList = services
                        self._serviceTableView.reloadData()
                        break
                    }
                }
            }
            
            self._dropServiceButton.isEnabled = (self._serviceTableView.selectedRow != -1)
        }
    }
    
    /// Called by the `RESTClient` if receiving or dropping services failed.
    ///
    /// The REST operations are performed asynchronously by the `RESTClient` instance.
    /// Errors in receiving the list of services (when the connect button is pressed)
    /// or dropping an existing service are delivered by calling this method which is
    /// in turn responsible to display the error to the user.
    ///
    /// - Note: The method is called from within a background thread. UI elements can't 
    ///         directly be manipulated from within this thread!
    ///
    /// - Parameters:
    ///   - requestType: Identifies the operation, leading to the error
    ///   - code: The error code
    ///   - message: A localized error message to display as message details
    func handleError( requestType: RequestType, code: ClientError, message: String? ) {
        NSLog( "Error in client communication (\(code)): \(message ?? "unknown reason")" );
        
        // move the handling back into the main/UI thread
        OperationQueue.main.addOperation {
            let alert = NSAlert()
            
            // produce an error alert sheet
            alert.alertStyle = NSCriticalAlertStyle
            alert.addButton(withTitle: "Close" )
            
            switch( requestType ) {
            case RequestType.ReceiveServices:
                alert.messageText = "Error receiving list of services"
            default:
                alert.messageText = "Unexpected service response"
            }
            
            switch( code ) {
            case ClientError.UserDBMissing:
                alert.informativeText = "The user database/table (DSNSERVICE) was not created yet. " +
                "DDF therefore started w/o REST support.\nRecreate the table and restart DDF."
            case ClientError.ConnectFailure:
                alert.informativeText = "Couldn't connect to DB2."
            case ClientError.ServerClosedConnection, ClientError.ServiceProcessingFailed:
                alert.informativeText = "The DB2 REST service refused to handle the connection. " +
                    "This is most likely due to missing RACF permissions (the specified user is " +
                "not authorized to call REST services)."
            default:
                alert.informativeText = "An unknown error occurred."
            }
            
            // append server response if given
            if let m = message {
                alert.informativeText += "\n\nOriginal server response:\n-------------------------------------\n\(m)"
            }
            
            // display the error message sheet
            if let win = self.view.window {
                alert.beginSheetModal(for: win) { (resp: NSModalResponse) in
                    self.setConnectControlEnablement(newState: true)
                }
            }
            else {
                alert.runModal()
            }
        }
    }
}
