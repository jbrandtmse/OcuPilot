/// <p>The OAuth 2.0 screen's server client Update JWKS tool (AD-27, AD-51): propose refreshing one
/// registered client's stored public key set from its JWKS URL. It reads the client's key-set state
/// fresh through <class>OcuPilot.Port.OAuthRegisteredClientPort</class>'s <code>JWKS</code> read and
/// mints a proposal; the port carries the write out through the vendor's own
/// <code>OAuth2.Server.Client.RefreshJWKS</code>, because the admin API has no such request type. It
/// writes nothing.</p>
/// <p><b>The vendor's effect</b>: the key set is fetched from the stored <code>jwks_uri</code> and
/// stored; when it differs from the one stored, the client's <code>ClientCredentials</code> is
/// cleared. A client with no JWKS URL is refused by name, at the agent's mint
/// (<method>ArgumentProblem</method>) and by the port, which the tab's row action reaches.</p>
/// <p>The fingerprint covers the JWKS URL and the credentials: a change to either since the mint
/// changes what the refresh would fetch or clear. The key count it replaces is the card's row.</p>
Class OcuPilot.Screen.Tool.OAuthRegisteredClientUpdateJwks Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverclients.updatejwks";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerClientTab";

Parameter DESCRIPTION = "Propose refreshing one registered OAuth 2.0 client's public keys from its JWKS URL. It changes nothing by itself: it answers a proposal the user reviews and confirms. When the key set fetched differs from the stored one, this instance also clears the client's X.509 credentials. Name the client by its client id exactly as the server client descriptions list reports it. A client with no JWKS URL is refused.";

/// <p>The row action this tool carries out from the Server client descriptions tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "updatejwks";

/// <p>The port's own read and write types (AD-51, AD-52).</p>
Parameter READTYPE = "JWKS";

Parameter WRITETYPE = "REFRESHJWKS";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthRegisteredClientPort";

/// <p>The top-level names the <code>JWKS</code> read answers.</p>
Parameter READANSWERS = "JwksUri,ClientCredentials,PublicKeys";

Parameter PRECONDITIONFIELD = "JwksUri";

Parameter FINGERPRINTSUBJECT = "JwksUri,ClientCredentials";

/// <p>The label of the card's one row: the number of keys the stored public key set holds, which the
/// refresh replaces (AD-51).</p>
Parameter STATEFIELD = "PublicKeys";

Parameter WRITERESOURCE = "%Admin_OAuth2_Registration";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ServerClients"
}

ClassMethod IdArgument() As %String
{
    Quit "ClientId"
}

ClassMethod IdParam() As %String
{
    Quit "clientId"
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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The client whose public keys to refresh, by its client id exactly as the server client descriptions list reports it.", "string")
    Quit tSchema
}

/// <p>A client with no JWKS URL is refused by name at the mint, with the port's own sentence
/// (<parameter>OcuPilot.Api.Error.OAUTHSERVERCLIENTJWKSNOURI</parameter>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    If $IsObject($Get(tFresh)) && (tFresh.%Get(..#PRECONDITIONFIELD) = "") Set pProblem = ##class(OcuPilot.Api.Error).#REASONOAUTHSERVERCLIENTJWKSNOURI
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

/// <p>The card's one row, from the fresh read <var>pFresh</var>: the stored key count, replaced by the
/// set fetched from the JWKS URL, which the card names. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report that server client's JWKS URL, so its public keys cannot be refreshed"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#STATEFIELD), pFresh.%GetTypeOf(..#STATEFIELD)), "string")
    Do tRow.%Set("after", pFresh.%Get(..#PRECONDITIONFIELD), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
