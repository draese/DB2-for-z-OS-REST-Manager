# DB2-for-zOS-REST-Manager
MacOS User Interface to list/register/drop new SQL based REST services in DB2 for z/OS Version 11 and 12

This program is a simple MacOS client for the REST functionality that is built into DDF of DB2 for z/OS 
Version 11 and Version 12. It allows the configuration of the URL (host, port, user name and password) and
then provides a list of already registered REST services. This list of services can be manipulated by
registering new services through the UI or dropping existing services.

All functionality is done via the DB2 built in REST API. There is no requirement for the JCC or other
client packages.

This program was developed, using XCode 8.2.1 on MacOS Sierra. All source is written in Swift 3.

Just open the project with XCode and build the product either for Debug or Release settings.
By default, the application stores configuration settings but it doesn't persist the user's password.
In order to also persist the password, you have to specify a *STOREPASSWD* in the active compilation
conditions on the build settings page.
