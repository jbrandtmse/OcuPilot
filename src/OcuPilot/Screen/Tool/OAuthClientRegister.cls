/// <p>The OAuth 2.0 screen's Register tool (AD-51): propose registering one client configuration with
/// its authorization server by OpenID Connect dynamic client registration. It reads the configuration's
/// registration state through <class>OcuPilot.Port.OAuthClientPort</class>'s <code>REGISTRATION</code>
/// read and mints a proposal; the port sends the vendor's own <code>REGISTERCLIENT</code>. It writes
/// nothing.</p>
/// <p><b>The vendor's effect</b>: the instance posts the client's metadata to the server description's
/// registration endpoint, presenting the description's initial access token, and replaces the client's
/// ID and secret with the ones the authorization server issues. A client already registered, or whose
/// description has no registration endpoint, is refused by name at the mint
/// (<method>ArgumentProblem</method>) and by the port, which the screen's row action reaches.</p>
/// <p>The fingerprint covers the client ID, the registration URI and the registration endpoint.</p>
Class OcuPilot.Screen.Tool.OAuthClientRegister Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthclients.register";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientTab";

Parameter DESCRIPTION = "Propose registering one OAuth 2.0 client configuration with its authorization server by dynamic client registration. This instance calls the authorization server's registration endpoint and replaces the client's ID and secret with the ones it issues. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the configuration by its application name exactly as the client configurations list reports it. A client already registered, or whose server description has no registration endpoint, is refused.";

/// <p>The row action this tool carries out from the Client configurations tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "register";

/// <p>The port's own read and the vendor's write type (AD-51, AD-52).</p>
Parameter READTYPE = "REGISTRATION";

Parameter WRITETYPE = "REGISTERCLIENT";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthClientPort";

/// <p>The top-level names the <code>REGISTRATION</code> read answers.</p>
Parameter READANSWERS = "ClientId,RegistrationClientUri,ServerDefinition,RegistrationEndpoint";

Parameter PRECONDITIONFIELD = "ClientId";

Parameter FINGERPRINTSUBJECT = "ClientId,RegistrationClientUri,RegistrationEndpoint";

/// <p>The label of the card's one row: the client ID the registration issues.</p>
Parameter STATEFIELD = "ClientId";

Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Client.ClientConfiguration"
}

ClassMethod IdArgument() As %String
{
    Quit "ApplicationName"
}

ClassMethod IdParam() As %String
{
    Quit "applicationName"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The client configuration to register, by its application name exactly as the client configurations list reports it.", "string")
    Quit tSchema
}

/// <p>A registered client, or one whose description has no registration endpoint, is refused by name
/// at the mint, with the port's own sentence.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    If '$IsObject($Get(tFresh)) Quit $$$OK
    If (tFresh.%Get("ClientId") '= "") || (tFresh.%Get("RegistrationClientUri") '= "") {
        Set pProblem = ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTREGISTERED
    } ElseIf tFresh.%Get("RegistrationEndpoint") = "" {
        Set pProblem = ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTNOREGISTRATIONENDPOINT
    }
    Quit $$$OK
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The card's one row, from the <code>REGISTRATION</code> read <var>pFresh</var>: the client ID,
/// replaced by the one the authorization server issues. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report that client configuration's registration, so it cannot be registered"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", pFresh.%Get(..#PRECONDITIONFIELD), "string")
    Do tRow.%Set("after", pFresh.%Get("RegistrationEndpoint"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
