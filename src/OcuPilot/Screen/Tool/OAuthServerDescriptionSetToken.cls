/// <p>The OAuth 2.0 screen's registration access token tool (AD-51, AD-56 (i)): propose storing one
/// server description's registration access token -- the bearer token a dynamic client registration
/// against that server presents. It reads the description fresh through
/// <class>OcuPilot.Port.OAuthServerPort</class> and mints a proposal whose card asks for the token at
/// confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b>: the vendor's <code>TOKEN</code> request
/// type takes exactly <code>{InitialAccessToken}</code>. The kernel carries the secret as the
/// descriptor's one declaration (<parameter>SECRETBODY</parameter>) and supplies it at the write; the
/// model can never supply it, and no read, proposal, diff, ledger row or log line carries it
/// (AD-35). The editor's Save sends the same write after a Save whose body carried a token.</p>
/// <p>Its fingerprint covers the issuer; the token itself is never read back.</p>
Class OcuPilot.Screen.Tool.OAuthServerDescriptionSetToken Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverdescriptions.settoken";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter DESCRIPTION = "Propose storing a registration access token for one OAuth 2.0 server description on this instance. It changes nothing by itself: it answers a proposal the user reviews, and the user types the token on the card when confirming. Never send a token: name the description by its issuer endpoint exactly as the server descriptions list reports it, and nothing else.";

/// <p>The vendor's own token request type.</p>
Parameter WRITETYPE = "TOKEN";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "InitialAccessToken";

/// <p>The card's one row is labelled after the secret the card asks for, not a payload field.</p>
Parameter STATEFIELD = "InitialAccessToken";

Parameter PRECONDITIONFIELD = "IssuerEndpoint";

Parameter FINGERPRINTSUBJECT = "IssuerEndpoint";

Parameter PORTCLASS = "OcuPilot.Port.OAuthServerPort";

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

/// <p>None: the write sends no merge body.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The description whose registration access token is to be stored, by its issuer endpoint exactly as the server descriptions list reports it. The token is typed by the user at confirmation and is never an argument.", "string")
    Quit tSchema
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The card's one row: <code>{field: "InitialAccessToken", before: "", after: ""}</code>. It names
/// the declared secret, so the card masks it and asks for it; neither side carries a value. A read
/// that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") || (pFresh.%Get(..#PRECONDITIONFIELD) = "") {
        Set pProblem = "this instance did not report that server description's own record, and a description whose configuration is unknown is not one to store a token for"
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
