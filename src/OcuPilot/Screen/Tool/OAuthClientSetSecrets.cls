/// <p>The OAuth 2.0 screen's client secrets tool (AD-51, AD-56 (i)): propose storing one client
/// configuration's client secret, private-key password or registration access token. It reads the
/// configuration fresh through <class>OcuPilot.Port.OAuthClientPort</class> and mints a proposal whose
/// card asks for each secret at confirm; any may be left empty, and an empty one keeps the stored
/// value. It writes nothing.</p>
/// <p><b>Its body is its declared secrets and nothing else</b>: the vendor's <code>CHANGESECRET</code>
/// type takes exactly those, the registration access token nested under <code>Metadata</code> by the
/// port. The kernel carries the secrets as the descriptor's declaration (<parameter>SECRETBODY</parameter>)
/// and supplies them at the write; the model can never supply one, and no read, proposal, diff, ledger
/// row or log line carries one (AD-35). A confirm that supplies none is refused by the port.</p>
/// <p>Its fingerprint covers the server description and the client type; the secrets are never read
/// back.</p>
Class OcuPilot.Screen.Tool.OAuthClientSetSecrets Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthclients.setsecrets";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientTab";

Parameter DESCRIPTION = "Propose storing a client secret, a private-key password or a registration access token for one OAuth 2.0 client configuration on this instance. It changes nothing by itself: it answers a proposal the user reviews, and the user types each secret on the card when confirming, leaving empty any to keep. Never send a secret: name the configuration by its application name exactly as the client configurations list reports it, and nothing else.";

/// <p>The vendor's own secrets request type.</p>
Parameter WRITETYPE = "CHANGESECRET";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "ClientSecret,ClientPassword,RegistrationAccessToken";

/// <p>The top-level names the <code>GET</code> answers that the subject reads. The <code>GET</code>
/// does not answer the application name.</p>
Parameter READANSWERS = "ServerDefinition,ClientType";

Parameter PRECONDITIONFIELD = "ClientType";

Parameter FINGERPRINTSUBJECT = "ServerDefinition,ClientType";

Parameter PORTCLASS = "OcuPilot.Port.OAuthClientPort";

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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The client configuration whose secrets are to be stored, by its application name exactly as the client configurations list reports it. The secrets are typed by the user at confirmation and are never arguments.", "string")
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

/// <p>The card's rows: one per declared secret, each <code>{field, before: "", after: "",
/// optional: true}</code>, so the card masks each, asks for it and lets it stay empty. A read that
/// answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") || (pFresh.%Get(..#PRECONDITIONFIELD) = "") {
        Set pProblem = "this instance did not report that client configuration's own record, and a configuration whose type is unknown is not one to store secrets for"
        Quit $$$OK
    }
    Set tNames = ..SecretBodyNames()
    For tI = 1:1:$ListLength(tNames) {
        Set tRow = {}
        Do tRow.%Set("field", $List(tNames, tI), "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", "", "string")
        Do tRow.%Set("optional", 1, "boolean")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

}
