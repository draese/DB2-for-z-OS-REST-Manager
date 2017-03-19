// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Foundation

/// Consumer protocol definition for the `RESTClient`.
///
/// The `RESTClient` is performing the requests asynchronously. All results
/// or errors are reported asynchronous to a class, implementing this 
/// consumer protocol.
protocol RESTClientConsumer {
    /// Called as response to successful `receiveServices` call.
    ///
    /// The services were received from DB2 and are now delivered as an
    /// array of the `Service` class.
    ///
    /// - Note: The methods of the `RESTClientConsumer` are called from a
    ///         service thread. The call has to be move back into the main
    ///         UI thread if UI elements are updated in response to the 
    ///         REST notification.
    ///
    /// - Parameter services: The `Service` instances
    func servicesReceived( services: Array<Service> )
    
    /// Notification that a single service was created successfully.
    ///
    /// This method is called in response to the 'registerNew' method of
    /// the `RESTClient` class.
    ///
    /// - Note: The methods of the `RESTClientConsumer` are called from a
    ///         service thread. The call has to be move back into the main
    ///         UI thread if UI elements are updated in response to the
    ///         REST notification.
    func serviceCreatedSuccessfully()
    
    /// Notification that the specified service was dropped successfully.
    ///
    /// This notification method is invoked in response to the 'drop' method
    /// of the 'RESTClient' class. The dropped service is passed in to allow
    /// its removal from a UI.
    ///
    /// - Note: The methods of the `RESTClientConsumer` are called from a
    ///         service thread. The call has to be move back into the main
    ///         UI thread if UI elements are updated in response to the
    ///         REST notification.
    ///
    /// - Parameter service: The service that was dropped
    func serviceDroppedSuccessfully( service: Service )
    
    /// Delivers the bind options.
    ///
    /// The method is called in response to the `receiveCreateOptions`
    /// method of the 'RESTClient' class. It delivers the BIND options.
    ///
    /// - Note: The methods of the `RESTClientConsumer` are called from a
    ///         service thread. The call has to be move back into the main
    ///         UI thread if UI elements are updated in response to the
    ///         REST notification.
    ///
    /// - Parameter options: The optional bind values
    func createOptionsReceived( options: CreateOptions )
    
    /// Called to notify about errors in the REST invocations.
    ///
    /// All errors are reported to the consumers by calling the error
    /// handler methods. As the same error handler is called for different
    /// REST invocation scenarios, the first parameter can be used to 
    /// figure out the operation that causes the issue. The other paremeters
    /// specify error code and message text (potentially from the server).
    ///
    /// - Note: The methods of the `RESTClientConsumer` are called from a
    ///         service thread. The call has to be move back into the main
    ///         UI thread if UI elements are updated in response to the
    ///         REST notification. While all other methods of the protocol
    ///         are "optional" and only need to be implemented if the 
    ///         corresponding function of the `RESTClient` is called, you
    ///         always have to implement this error handler.
    ///
    /// - Parameters:
    ///   - requestType: Identifies the method that was invoked
    ///   - code: The error code
    ///   - message: Optional additional error text to be displayed
    func handleError( requestType: RequestType, code: ClientError, message: String? )
}

/// Default implementations for "optional" methods of RESTClientConsumer
///
/// All but the error handler methods are "optional". Therefore, a consumer
/// only has to implement the methods that correspond to the service that
/// was invoked on the `RESTClient`. This is done by giving default 
/// implementations for all methods, which terminate the program if not
/// overridden and still being required.
extension RESTClientConsumer {
    /// Default implementation that causes fatal error
    ///
    /// - Parameter services: The list of services (ignored)
    func servicesReceived( services: Array<Service> ) {
        fatalError( "servicesReceived(services:) has not been implemented" )
    }
    
    /// Default implementation that causes fatal error
    ///
    /// - Parameter service: the dropped service (ignored)
    func serviceDroppedSuccessfully( service: Service ) {
        fatalError( "serviceDroppedSuccessfully(service:) has not been implemented" )
    }
    
    /// Default implementation that causes fatal error
    func serviceCreatedSuccessfully() {
        fatalError( "serviceCratedSuccessfully() has not been implemented" )
    }
    
    /// Default implementation that causes fatal error
    ///
    /// - Parameter options: Received options (ignored)
    func createOptionsReceived( options: CreateOptions ) {
        fatalError( "createOptionsReceived(options:) has not been implemented" )
    }
}
