/// <p>The OAuth 2.0 screen's authorization server key password tool (AD-51, AD-56 (i)): propose
/// storing the password of the private key the server credentials hold. It reads the configuration
/// fresh through <class>OcuPilot.Port.OAuthAuthorizationServerPort</class> and mints a proposal whose
/// card asks for the password at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b>: the vendor's <code>CHANGEPWD</code>
/// type takes exactly <code>{ServerPassword}</code>. The kernel supplies it at the write from the
/// descriptor's declaration (<parameter>SECRETBODY</parameter>); the model can never supply one, and
/// no read, proposal, diff, ledger row or log line carries one (AD-35). A confirm that supplies none
/// is refused by the port, because the vendor would clear the stored password.</p>
/// <p>Its fingerprint covers the issuer endpoint, the server credentials and the registered
/// clients; the password is never read back.</p>
Class OcuPilot.Screen.Tool.OAuthAuthorizationServerSetPassword Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserver.setpassword";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerTab";

Parameter DESCRIPTION = "Propose storing the password of the private key this instance's OAuth 2.0 authorization server signs with. It changes nothing by itself: it answers a proposal the user reviews, and the user types the password on the card when confirming. Never send a password: name the configuration and nothing else.";

/// <p>The vendor's own password request type.</p>
Parameter WRITETYPE = "CHANGEPWD";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "ServerPassword";

/// <p>The top-level names the <code>GET</code> answers that the subject reads.</p>
Parameter READANSWERS = "IssuerEndpoint,ServerCredentials,Clients,ClientsHidden";

Parameter PRECONDITIONFIELD = "IssuerEndpoint";

Parameter FINGERPRINTSUBJECT = "IssuerEndpoint,ServerCredentials,Clients,ClientsHidden";

Parameter PORTCLASS = "OcuPilot.Port.OAuthAuthorizationServerPort";

Parameter WRITERESOURCE = "%Admin_OAuth2_Server";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Server"
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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one authorization server configuration, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'. The password is typed by the user at confirmation and is never an argument.", "string")
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

/// <p>The card's rows: <code>{field: ServerPassword, before: "", after: ""}</code>, so the card masks
/// it and asks for it, and the registered clients the change reaches. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report its authorization server configuration, so no key password is stored for it"
        Quit $$$OK
    }
    Set tNames = ..SecretBodyNames()
    For tI = 1:1:$ListLength(tNames) {
        Set tRow = {}
        Do tRow.%Set("field", $List(tNames, tI), "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", "", "string")
        Do pRows.%Push(tRow)
    }
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
