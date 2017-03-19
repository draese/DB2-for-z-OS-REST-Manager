// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Enumeration of error codes for the `RESTClient`
///
/// - ConnectFailure: Issues with the URL
/// - ServerClosedConnection: Server side close of connection (i.e. auth error)
/// - ServiceProcessingFailed: Server side processing error
/// - ContentTypeMissing: Content Type isn't JSON
/// - SQLError: Specified SQL has an error
/// - UserDBMissing: The REST database or its tables are not present
/// - UnknwonStatusCode: Sever side unknown error
/// - ResponseNotJSON: Issues when parsing the JSON server response
/// - URLError: URL is malformed
/// - ServicesNotFound: Services couldn't be received from DB2
/// - OptionsNotFound: Bind options couldn't be received from DB2
/// - Unknown: Whatever other unknown error scenario
enum ClientError: Int {
    case ConnectFailure
    case ServerClosedConnection  = 400
    case ServiceProcessingFailed = 401
    case ContentTypeMissing      = 415
    case SQLError                = 500
    case UserDBMissing           = 503
    case UnknwonStatusCode
    case ResponseNotJSON
    case URLError
    case ServicesNotFound
    case OptionsNotFound
    case Unknown
}

/// Specifies the requested service, when a failure happened.
///
/// All `RESTClient` services are exeucted asynchronously. Errors
/// are all delivered to the consumer's `handleError` method, which
/// has to figure out the failing scenario. The invoked/requested
/// service can be detected via this `RequestType~
///
/// - ReceiveServices: receiveServices was called
/// - RegisterNewService: registerNew wasc alled
/// - DropService: drop was called
/// - ReceiveOptions: receiveCreateOptions was called
enum RequestType {
    case ReceiveServices
    case RegisterNewService
    case DropService
    case ReceiveOptions
}

/// Describes a single, by DB2 known REST service.
///
/// This struture is a data container for the information about a
/// single, previously registered service. When receiving the list
/// of DB2 REST services via the `receiveServices` class, these are
/// delivered as an array of instances of this struct.
struct Service {
    var name: String
    var description: String
    var collectionID: String
    var url: URL
}

/// Describes all possible bind options.
///
/// When calling the `receiveCreateOptions` method to get all possible
/// bind options, an instance of this structure is delivered. Each 
/// option is an instance of the inner struct `BindMultipleSelect`  and
/// the different options are delivered in an array.
struct CreateOptions {
    /// Inner struct to describe a single bind option
    struct BindMultipleSelect {
        var name: String           /// bind option name
        var desctiprion: String    /// description, used for the tooltip
        var values: Array<String>  /// array of allowed values for option
    }
    
    /// Array of all allowed bind options
    var bindMultipleSelect: Array<BindMultipleSelect>?
}

/// Helper to execute all DB2 REST services.
///
/// An instance of this class is used to perform all REST service invocations
/// against the DB2 REST interface. Each of the services is invoked asynchronously,
/// therefore there has to be a `RESTClientConsumer` registered to the `RESTClient`
/// to be notified about the results or potential errors. This consumer is passed
/// into the constructors of this class.
///
/// - Note: Be aware that all invocations of the consumer's methods are done from
///         within a (non-main) service thread.
class RESTClient {
    private var _consumer:   RESTClientConsumer
    private var _url:        URL? = nil
    private var _authString: String
    
    // constant definitions
    private static let STATUSCODE          = "StatusCode"
    private static let STATUSDESCRIPTION   = "StatusDescription"

    private static let REQ_GET             = "GET"
    private static let REQ_POST            = "POST"
    private static let REQ_AUTHORIZATION   = "Authorization"
    private static let REQ_RECEIVESERVICES = "services"
    private static let REQ_SERVICEMANAGER  = "services/DB2ServiceManager"
    
    /// Creates a new REST client based on the passed in connection parameters.
    ///
    /// The so created `RESTClient` will try to connect DB2 based on the given URL,
    /// which therefore has to specify the protocol (http/https), host and port. The
    /// user ID and passwords are also passed in. This constructor is not verifying 
    /// that the provided values are correct. Therefore, the first call to any of 
    /// the client's methods might reveal issues with the URL or authorization 
    /// later on.
    ///
    /// - Parameters:
    ///   - consumer: Will be notified about invocation results or errors
    ///   - url: The full qualified DB2 URL to connect to
    ///   - userID: UserID, having authorizations to query/create/drop services
    ///   - password: Matching password (clear text)
    init( consumer: RESTClientConsumer, url: URL, userID: String, password: String ) {
        let concat = "\(userID):\(password)"
        
        _consumer = consumer
        _url      = url;
        
        // store userID/password as http auth string (base64)
        _authString = "Basic \(concat.data( using: String.Encoding.utf8 )!.base64EncodedString())"
    }
    
    /// Derives a new client based on same connection settings with different consumer.
    ///
    /// This constructor is used to create a new client that is of course connecting to 
    /// the same DB2 server (therefore derives the connection and authorization settings)
    /// but notifies a different consumer about the results. This is used to handle only
    /// the expected results for a specific operation in dedicated consumer implementations.
    ///
    /// - Parameters:
    ///   - consumer: The new consumer to notify about results or errors
    ///   - deriveFrom: The `RESTClient` to get the connect settings from
    init( consumer: RESTClientConsumer, deriveFrom: RESTClient ) {
        self._consumer   = consumer
        self._url        = deriveFrom._url
        self._authString = deriveFrom._authString
    }
    
    /// Receives a list of all known/registered DB2 REST services.
    ///
    /// This method is used to get the list of known REST services (the built in REST
    /// management services are filtered out) from DB2. The services are delivered by
    /// calling the `servicesReceived` of the `RestClientConsumer`. Errors are delivered
    /// by calling its `handleError` method.
    ///
    /// - Note: REST services are invoked asynchronously. This method will return before
    ///         the actual server response is received and delivered to the consumer.
    func receiveServices() {
        if let request = getRequest( relativePath: RESTClient.REQ_RECEIVESERVICES, withMethod: RESTClient.REQ_GET ) {
            // create asynchronous task
            URLSession.shared.dataTask( with: request) { (data, resp, respErr) in
                if let respDict = self.parseResponse( requestType: RequestType.ReceiveServices, data: data, respErr: respErr ) {
                    if let services = respDict["DB2Services"] as? Array<Dictionary<String,Any>> {
                        var serviceArray = Array<Service>()
                        
                        // map all JSON service objects to Service instances
                        for service in services {
                            let name = service["ServiceName"] as? String ?? "Unknown"
                            let desc = service["ServiceDescription"] as? String ?? "Not provided"
                            let coll = service["ServiceCollectionID"] as? String ?? "N/A"
                            let urlS = service["ServiceURL"] as? String
                            
                            // skip the DB2 "built in" services
                            if urlS != nil && name != "DB2ServiceDiscover" && name != "DB2ServiceManager" {
                                if let urlObj = URL( string: urlS! ) {
                                    serviceArray.append( Service(name: name, description: desc, collectionID: coll, url: urlObj ) )
                                }
                            }
                        }
                        
                        // deliver services to consumer
                        self._consumer.servicesReceived( services: serviceArray )
                    }
                    else {
                        // notify about error
                        self._consumer.handleError( requestType: RequestType.ReceiveServices,
                                                    code: ClientError.ServicesNotFound,
                                                    message: nil );
                    }
                }
            }.resume()
        }
    }
    
    /// Used to register a new REST service.
    ///
    /// This method is used to register a new REST service (based on the passed in SQL)
    /// on the DB2 side. As a result, the `serviceCreatedSuccessfully` of the
    /// `RESTClientConsumer` will be called or `handleError` if issues were detected.
    ///
    /// - Parameters:
    ///   - serviceWithName: New unique name of the service
    ///   - description: Optional description of the new service
    ///   - collectionID: Optional collection ID of the service
    ///   - sql: The SQL text to execute upon service invocation
    ///   - bindOptions: Optional bind options as key/value pairs
    ///
    /// - Note: REST services are invoked asynchronously. This method will return before
    ///         the actual server response is received and delivered to the consumer.
    func registerNew( serviceWithName: String, description: String, collectionID: String, sql: String, bindOptions: Dictionary<String,String>? ) {
        if var request = getRequest(relativePath: RESTClient.REQ_SERVICEMANAGER, withMethod: RESTClient.REQ_POST ) {
            var payload = [ "requestType" : "createService",
                            "serviceName" : serviceWithName,
                            "sqlStmt"     : sql ]
            
            // provide optional values
            if description.isEmpty == false {
                payload["description"] = description
            }
            
            if collectionID.isEmpty == false {
                payload["collectionID"] = collectionID
            }
            
            // transfer the optional bind options 
            if let options = bindOptions {
                for option in options {
                    payload[option.key] = option.value
                }
            }

            request.setValue( "application/json", forHTTPHeaderField: "content-type" )
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions.prettyPrinted )
            
            // create an asynchronous request task
            URLSession.shared.dataTask( with: request) { (data, resp, respErr) in
                if let respDict = self.parseResponse(requestType: RequestType.RegisterNewService, data: data, respErr: respErr ) {
                    if let statusCode = respDict[RESTClient.STATUSCODE] as? Int {
                        if statusCode == 201 {
                            // all OK, communicate success
                            self._consumer.serviceCreatedSuccessfully()
                        }
                        else {
                            // server reported some status
                            self._consumer.handleError(requestType: RequestType.RegisterNewService, code: ClientError.Unknown, message: "StatusCode not correct" )
                        }
                    }
                    else {
                        // something is really wrong - no status at all
                        self._consumer.handleError(requestType: RequestType.RegisterNewService, code: ClientError.Unknown, message: "StatusCode not found" )
                    }
                }
            }.resume()
        }
    }
    
    /// Drops a previously created REST service again.
    ///
    /// This method is used to drop the service, that is identified by the passed
    /// in `Service` instance. If the operation is successful, the `serviceDroppedSuccessfully`
    /// of the `RESTClientConsumer` is called. Otherwise, errors are reported via the 
    /// `handleError` method.
    ///
    /// - Parameter service: The service that should be deleted/dropped
    ///
    /// - Note: REST services are invoked asynchronously. This method will return before
    ///         the actual server response is received and delivered to the consumer.
    func drop( service: Service ) {
        if var request = getRequest(relativePath: RESTClient.REQ_SERVICEMANAGER, withMethod: RESTClient.REQ_POST ) {
            let payload = ["requestType"  : "dropService",
                           "serviceName"  : service.name,
                           "collectionID" : service.collectionID]
            
            request.setValue( "application/json", forHTTPHeaderField: "content-type" )
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions.prettyPrinted )
            
            // use an asynchronous request task
            URLSession.shared.dataTask( with: request) { (data, resp, respErr) in
                if let respDict = self.parseResponse(requestType: RequestType.RegisterNewService, data: data, respErr: respErr ) {
                    if let statusCode = respDict[RESTClient.STATUSCODE] as? Int {
                        if statusCode == 200 {
                            // all OK
                            self._consumer.serviceDroppedSuccessfully( service: service )
                        }
                        else {
                            // service was not dropped
                            self._consumer.handleError(requestType: RequestType.DropService, code: ClientError.Unknown, message: "StatusCode not correct" )
                        }
                    }
                    else {
                        // something really wrong: no status at all
                        self._consumer.handleError(requestType: RequestType.DropService, code: ClientError.Unknown, message: "StatusCode not found" )
                    }
                }
            }.resume()
        }
    }
    
    /// Receive the existing/supported bind options.
    ///
    /// The list of bind options isn't hard coded in this client but received from DB2
    /// by using this method. They are then cached and displayed when a new service is
    /// registered. Currently, only the enumeration based bind options are supported.
    /// If the options are received correctly, they will be delivered to the 
    /// `createOptionsReceived` method of the `RESTClientConsumer` class. All errors,
    /// are delivered to the `handleError` method.
    ///
    /// - Note: REST services are invoked asynchronously. This method will return before
    ///         the actual server response is received and delivered to the consumer.
    func receiveCreateOptions() {
        if let request = getRequest(relativePath: RESTClient.REQ_SERVICEMANAGER, withMethod: RESTClient.REQ_GET ) {
            
            // create an asynchronous request task
            URLSession.shared.dataTask( with: request) { (data, resp, respErr) in
                if let respDict = self.parseResponse(requestType: RequestType.RegisterNewService, data: data, respErr: respErr ) {
                    // do recursive searcg for the request schema
                    if let requestSchema = self.findEntryBy(name: "requestschema", inDictionary: respDict ) as? NSDictionary {
                        if let properties = self.findEntryBy(name: "properties", inDictionary: requestSchema) as? Dictionary<String,Any> {
                            var allBindEnums = Array<CreateOptions.BindMultipleSelect>()
                            
                            // map each property into a single BindMultipleSelect instance
                            for entry in properties {
                                let key = entry.key
                                
                                if key.isEmpty == false {
                                    // only look at properties that start with upperCase character
                                    if CharacterSet.uppercaseLetters.contains( key.unicodeScalars.first! ) {
                                        if let val = entry.value as? Dictionary<String,Any> {
                                            if let listValues = val["enum"] as? Array<String> {
                                                let desc = val["description"] as? String ?? "Unknown"
                                                let opt = CreateOptions.BindMultipleSelect(name: key, desctiprion: desc, values: listValues )
                                                allBindEnums.append( opt )
                                            }
                                        }
                                    }
                                    else {
                                        NSLog( "receiveCreateOptions: Skipping option \(key)" )
                                    }
                                }
                            }

                            if allBindEnums.isEmpty == false {
                                // sort the options alphabetically by name
                                allBindEnums.sort(by: { (left, right) -> Bool in
                                    return left.name < right.name
                                })
                                
                                // report all options back to consumer
                                self._consumer.createOptionsReceived( options: CreateOptions(bindMultipleSelect: allBindEnums ))
                            }
                            else {
                                // options not found within JSON result
                                self._consumer.handleError(requestType: RequestType.ReceiveOptions,
                                                           code: ClientError.OptionsNotFound,
                                                           message: "No bind options found in response" )
                            }
                        }
                        else {
                            // properties not found within JSON result
                            self._consumer.handleError(requestType: RequestType.ReceiveOptions,
                                                       code: ClientError.OptionsNotFound,
                                                       message: "RequestSchema doesn't have properties" )
                        }
                    }
                    else {
                        // request schema not found within JSON result
                        self._consumer.handleError(requestType: RequestType.ReceiveOptions,
                                                   code: ClientError.OptionsNotFound,
                                                   message: "No RequestSchema in server response" )
                    }
                }
            }.resume()
        }
    }
    
    /// Helper to create a new `URLRequest`.
    ///
    /// Common helper to create an `URLRequest` instance and to provide it with 
    /// request method and authorization values. If there is an issue with the URL
    /// that was passed to the constructor of the client, the error is passed to
    /// the `handleError` of the `RESTClientConsumer` instance and `nil` is returned
    /// to the caller of this method.
    ///
    /// - Parameters:
    ///   - relativePath: Relative server path (to base URL passed to constructor)
    ///   - withMethod: request method (GET vs. POST)
    /// - Returns: A new URLRequest instance if successful
    private func getRequest( relativePath: String, withMethod: String ) -> URLRequest? {
        var ret: URLRequest? = nil;
        
        if let relURL = URL( string: relativePath, relativeTo: _url ) {
            // create/initialize the request
            var newRequest = URLRequest( url: relURL )
            newRequest.httpMethod = withMethod;
            newRequest.setValue( _authString, forHTTPHeaderField: RESTClient.REQ_AUTHORIZATION )
            ret = newRequest;
        }
        else {
            // URL was invalid
            _consumer.handleError( requestType: RequestType.ReceiveServices, code: ClientError.URLError, message: nil );
        }
        
        return ret;
    }
    
    /// Common helper to parse the server's JSON response.
    ///
    /// This helper is called to parse the JSON response from DB2 into a dictionary
    /// of key/value pairs. This helper also already handles common status error
    /// codes. Errors are directly reported to the `handleError` method of the 
    /// `RESTClientConsumer` instance. The returned dictionary might still contain
    /// additional error information.
    ///
    /// - Parameters:
    ///   - requestType: Passed to `handleError` if issues are found
    ///   - data: The server response as flat data
    ///   - respErr: API error information if request failed
    /// - Returns: A dictionary with the JSON key/value pairs
    private func parseResponse( requestType: RequestType, data: Data?, respErr: Error? ) -> NSDictionary? {
        var ret: NSDictionary? = nil;
        
        if let receivedError = respErr {
            // pass API errors to the consymer directly
            self._consumer.handleError( requestType: requestType,
                                        code: ClientError.ConnectFailure,
                                        message: receivedError.localizedDescription )
        }
        else {
            if let sourceData = data {
                // parse the string into a dictionary
                if let json = (try? JSONSerialization.jsonObject(with: sourceData,
                                                                 options: JSONSerialization.ReadingOptions.mutableContainers )) as? NSDictionary {
                    // handle common error status codes
                    if let statusCode = json[RESTClient.STATUSCODE] as? Int {
                        switch( statusCode ) {
                        case 200, 201: ret = json  // successful execution
                            
                        case 400:  // potential invalid REST request
                            self._consumer.handleError( requestType: requestType,
                                                        code: ClientError.ServerClosedConnection,
                                                        message: json[RESTClient.STATUSDESCRIPTION] as? String )
                            
                        case 401:  // RACF group not created or authorization error
                            self._consumer.handleError( requestType: requestType,
                                                        code: ClientError.ServiceProcessingFailed,
                                                        message: json[RESTClient.STATUSDESCRIPTION] as? String )
                        
                        case 415:  // content type was not correct in header
                            self._consumer.handleError(requestType: requestType,
                                                       code: ClientError.ContentTypeMissing,
                                                       message: json[RESTClient.STATUSDESCRIPTION] as? String )

                        case 500:  // SQL Error
                            self._consumer.handleError( requestType: requestType,
                                                        code: ClientError.SQLError,
                                                        message: json[RESTClient.STATUSDESCRIPTION] as? String )

                        case 503:  // SYSIBM.DSNSERVICE is not installed or is not correctly installed
                            self._consumer.handleError( requestType: requestType,
                                                        code: ClientError.UserDBMissing,
                                                        message: json[RESTClient.STATUSDESCRIPTION] as? String )
                            
                        default:  // unexpected status code
                            self._consumer.handleError( requestType: requestType,
                                                        code: ClientError.UnknwonStatusCode,
                                                        message: json[RESTClient.STATUSDESCRIPTION] as? String )
                        }
                    }
                    else {
                        // no status code found at all
                        ret = json;
                    }
                }
                else {
                    // JSON deserialization failed
                    self._consumer.handleError( requestType: requestType,
                                                code: ClientError.ResponseNotJSON,
                                                message: "JSON response wasn't parsed" )
                }
            }
        }
        
        return ret;
    }
    
    /// Recursive helper to find key/value pairs in JSON dictionaries.
    ///
    /// The JSON response is parsed into a dictionary, where the values can
    /// be arrays or dictionaries by themselves again. Instead of traversing
    /// the structure "manually", this helper can be used to find a key in
    /// the dictionary.
    ///
    /// - Parameters:
    ///   - name: Name of the key to search
    ///   - inDictionary: Source dictionary
    /// - Returns: The value, matching the key
    private func findEntryBy( name: String, inDictionary: NSDictionary ) -> Any? {
        for entry in inDictionary {
            if let key = entry.key as? String {
                let val = entry.value
                
                if key.lowercased() == name {
                    return val
                }

                // recursive search
                if val is NSDictionary {
                    let ret = findEntryBy(name: name, inDictionary: val as! NSDictionary )
                    if ret != nil {
                        return ret
                    }
                }
            }
        }
        
        return nil
    }
}
