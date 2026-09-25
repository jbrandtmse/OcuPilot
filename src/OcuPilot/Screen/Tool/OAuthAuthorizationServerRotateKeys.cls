/// <p>The OAuth 2.0 screen's authorization server Rotate Keys tool (AD-27, AD-51): propose adding a
/// new key pair to the key set the authorization server signs its tokens with. It reads the
/// configuration fresh through <class>OcuPilot.Port.OAuthAuthorizationServerPort</class> and mints a
/// proposal; the port calls the vendor's own <code>RotateKeys()</code>, which the admin API has no
/// request type for. It writes nothing.</p>
/// <p><b>Refused by name while <code>ServerCredentials</code> is set</b>: the keys then come from
/// that X.509 credential, and the next save rebuilds them from it. The mint refuses it
/// (<method>ArgumentProblem</method>) and so does the port, which the tab's row action reaches.</p>
/// <p>The fingerprint covers the server credentials and the registered clients, so setting
/// credentials or registering a client since the mint refuses the confirm.</p>
Class OcuPilot.Screen.Tool.OAuthAuthorizationServerRotateKeys Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserver.rotatekeys";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerTab";

Parameter DESCRIPTION = "Propose rotating this instance's OAuth 2.0 authorization server keys: a new key pair is added to the key set its tokens are signed with, and the earlier ones are kept. It changes nothing by itself: it answers a proposal the user reviews and confirms. A server whose keys come from its server credentials is refused.";

/// <p>The row action this tool carries out from the Authorization server tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "rotatekeys";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "ROTATEKEYS";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter PORTCLASS = "OcuPilot.Port.OAuthAuthorizationServerPort";

Parameter READANSWERS = "ServerCredentials,Clients,ClientsHidden";

Parameter PRECONDITIONFIELD = "ServerCredentials";

Parameter FINGERPRINTSUBJECT = "ServerCredentials,Clients,ClientsHidden";

/// <p>The label of the card's key row: the key set the rotation adds to, which no read answers
/// (AD-51).</p>
Parameter STATEFIELD = "Keys";

Parameter WRITERESOURCE = "%Admin_OAuth2_Server";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Server"
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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one authorization server configuration, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'.", "string")
    Quit tSchema
}

/// <p>A configuration whose keys come from its server credentials is refused by name at the mint,
/// with the port's own sentence (<parameter>OcuPilot.Api.Error.OAUTHSERVERKEYSCREDENTIALS</parameter>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    If $IsObject($Get(tFresh)) && (tFresh.%Get(..#PRECONDITIONFIELD) '= "") Set pProblem = ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERKEYSCREDENTIALS
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

/// <p>The card's rows: the key set a new pair is added to, which neither side shows because no read
/// answers it, and the registered clients the change reaches. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report its authorization server's credentials, so its keys cannot be rotated"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", "", "string")
    Do pRows.%Push(tRow)
    Set tClients = ##class(OcuPilot.Area.Security.OAuthAuthorizationServerRules).ClientsRow(pFresh, 0)
    If $IsObject(tClients) Do pRows.%Push(tClients)
    Quit $$$OK
}

/// <p>The kernel-owned consequence of this payload
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ServerConsequence</method>).</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).ServerConsequence("", pPrivileged, pEffect)
}

}
