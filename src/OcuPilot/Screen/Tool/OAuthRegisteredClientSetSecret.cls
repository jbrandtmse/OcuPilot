/// <p>The OAuth 2.0 screen's server client secret tool (AD-51, AD-56 (i)): propose storing a new
/// client secret for one client registered with this instance's authorization server. It reads the
/// client fresh through <class>OcuPilot.Port.OAuthRegisteredClientPort</class> and mints a proposal
/// whose card asks for the secret at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b>: the vendor's secret type takes exactly
/// <code>{ClientSecret}</code>. The kernel supplies it at the write from the descriptor's declaration
/// (<parameter>SECRETBODY</parameter>); the model can never supply one, and no read, proposal, diff,
/// ledger row or log line carries one (AD-35). A confirm that supplies none is refused by the port,
/// because the vendor would clear the stored secret.</p>
/// <p><b>It is destructive</b>: the client's application must use the new secret from then on
/// (<method>Consequence</method>). Its fingerprint covers the client's name and type; the secret is
/// never read back.</p>
Class OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverclients.setsecret";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerClientTab";

Parameter DESCRIPTION = "Propose storing a new client secret for one client registered with this instance's OAuth 2.0 authorization server. It changes nothing by itself: it answers a proposal the user reviews, and the user types the secret on the card when confirming. The client's application must then use the new secret. Never send a secret: name the client by its client id exactly as the server client descriptions list reports it, and nothing else.";

/// <p>The vendor's own secret request type.</p>
Parameter WRITETYPE = "SECRET";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "ClientSecret";

/// <p>Declared: the application that holds the old secret stops being able to use it.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names the <code>GET</code> answers that the subject reads.</p>
Parameter READANSWERS = "Name,ClientType";

Parameter PRECONDITIONFIELD = "ClientType";

Parameter FINGERPRINTSUBJECT = "Name,ClientType";

Parameter PORTCLASS = "OcuPilot.Port.OAuthRegisteredClientPort";

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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The client whose secret is to be stored, by its client id exactly as the server client descriptions list reports it. The secret is typed by the user at confirmation and is never an argument.", "string")
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

/// <p>The card's row: <code>{field: ClientSecret, before: "", after: ""}</code>, so the card masks it
/// and asks for it. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") || (pFresh.%Get(..#PRECONDITIONFIELD) = "") {
        Set pProblem = "this instance did not report that server client's own record, so no secret is stored for it"
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
    Quit $$$OK
}

/// <p>The effect the card names: the client's application must use the new secret from then on
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTSERVERCLIENTSECRET</parameter>).</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTSERVERCLIENTSECRET
}

}
