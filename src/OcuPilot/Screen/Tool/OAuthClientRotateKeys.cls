/// <p>The OAuth 2.0 screen's Rotate Keys tool (AD-51): propose adding a new key pair to one client
/// configuration's key set. It reads the configuration fresh through
/// <class>OcuPilot.Port.OAuthClientPort</class> and mints a proposal; the port sends the vendor's own
/// <code>ROTATEKEYS</code>. It writes nothing.</p>
/// <p><b>Refused by name while <code>ClientCredentials</code> is set</b>: the client's keys then come
/// from that X.509 credential, and the vendor answers a rotation 200 while changing nothing. The mint
/// refuses it (<method>ArgumentProblem</method>) and so does the port, which the screen's row action
/// reaches.</p>
/// <p>The fingerprint covers <code>ClientCredentials</code>: setting one since the mint changes whether
/// the rotation does anything.</p>
Class OcuPilot.Screen.Tool.OAuthClientRotateKeys Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthclients.rotatekeys";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientTab";

Parameter DESCRIPTION = "Propose rotating one OAuth 2.0 client configuration's keys: this instance adds a new key pair to the client's key set and keeps the earlier ones. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the configuration by its application name exactly as the client configurations list reports it. A client whose keys come from an X.509 credential is refused.";

/// <p>The row action this tool carries out from the Client configurations tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "rotatekeys";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "ROTATEKEYS";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter PORTCLASS = "OcuPilot.Port.OAuthClientPort";

Parameter READANSWERS = "ClientCredentials";

Parameter PRECONDITIONFIELD = "ClientCredentials";

Parameter FINGERPRINTSUBJECT = "ClientCredentials";

/// <p>The label of the card's one row: the key set the rotation adds to, which no read answers
/// (AD-51).</p>
Parameter STATEFIELD = "PublicJWKS";

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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The client configuration whose keys to rotate, by its application name exactly as the client configurations list reports it.", "string")
    Quit tSchema
}

/// <p>A client whose keys come from its X.509 credential is refused by name at the mint, with the
/// port's own sentence (<parameter>OcuPilot.Api.Error.OAUTHCLIENTKEYSFROMCREDENTIALS</parameter>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    If $IsObject($Get(tFresh)) && (tFresh.%Get(..#PRECONDITIONFIELD) '= "") Set pProblem = ##class(OcuPilot.Api.Error).#REASONOAUTHCLIENTKEYSFROMCREDENTIALS
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

/// <p>The card's one row: the key set a new pair is added to. Neither side carries a value, since no
/// read answers the key set. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report that client configuration's credentials, so its keys cannot be rotated"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", "", "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
