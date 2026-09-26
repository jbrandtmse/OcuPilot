/// <p>The OAuth 2.0 screen's Update JWKS tool (AD-51, AD-27): propose refreshing one server
/// description's stored public key set from its JWKS URL. It reads the description's key-set state
/// fresh through <class>OcuPilot.Port.OAuthServerPort</class>'s <code>JWKS</code> read and mints a
/// proposal; the port carries the write out through the vendor's own
/// <code>OAuth2.ServerDefinition.RefreshJWKS</code>, because the admin API has no such request type.
/// It writes nothing.</p>
/// <p><b>The vendor's effect</b>: the key set is fetched from the stored <code>jwks_uri</code> and
/// stored; when it differs from the one stored, the description's <code>ServerCredentials</code> is
/// cleared. A description with no JWKS URL is refused by name, at the agent's mint
/// (<method>ArgumentProblem</method>) and by the port, which the screen's row action reaches.</p>
/// <p>The fingerprint covers the JWKS URL, the SSL/TLS configuration and the server credentials: a
/// change to any since the mint changes what the refresh would fetch or clear.</p>
Class OcuPilot.Screen.Tool.OAuthServerDescriptionUpdateJwks Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverdescriptions.updatejwks";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter DESCRIPTION = "Propose refreshing one OAuth 2.0 server description's public key set from its JWKS URL. It changes nothing by itself: it answers a proposal the user reviews and confirms. When the key set fetched differs from the stored one, this instance also clears the description's X.509 server credentials. Name the description by its issuer endpoint exactly as the server descriptions list reports it. A description with no JWKS URL is refused.";

/// <p>The row action this tool carries out from the Server descriptions tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "updatejwks";

/// <p>The port's own read and write types (AD-51, AD-52).</p>
Parameter READTYPE = "JWKS";

Parameter WRITETYPE = "REFRESHJWKS";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

Parameter PORTCLASS = "OcuPilot.Port.OAuthServerPort";

/// <p>The top-level names the <code>JWKS</code> read answers.</p>
Parameter READANSWERS = "JwksUri,SSLConfiguration,ServerCredentials";

Parameter PRECONDITIONFIELD = "JwksUri";

Parameter FINGERPRINTSUBJECT = "JwksUri,SSLConfiguration,ServerCredentials";

/// <p>The label of the card's one row: the stored key set the refresh replaces, which no read
/// answers (AD-51).</p>
Parameter STATEFIELD = "PublicJWKS";

Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Client.ServerDefinition"
}

ClassMethod IdArgument() As %String
{
    Quit "IssuerEndpoint"
}

ClassMethod IdParam() As %String
{
    Quit "issuer"
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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The description whose key set to refresh, by its issuer endpoint exactly as the server descriptions list reports it.", "string")
    Quit tSchema
}

/// <p>A description with no JWKS URL is refused by name at the mint, with the port's own sentence
/// (<parameter>OcuPilot.Api.Error.OAUTHNOJWKSURI</parameter>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    If $IsObject($Get(tFresh)) && (tFresh.%Get(..#PRECONDITIONFIELD) = "") Set pProblem = ##class(OcuPilot.Api.Error).#REASONOAUTHNOJWKSURI
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

/// <p>The card's one row, from the fresh read <var>pFresh</var>: the stored key set, replaced by the
/// one fetched from the JWKS URL. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report that server description's JWKS URL, so its key set cannot be refreshed"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pFresh.%Get(..#PRECONDITIONFIELD), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
