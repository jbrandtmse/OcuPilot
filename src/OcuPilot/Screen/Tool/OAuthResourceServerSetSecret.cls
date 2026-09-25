/// <p>The OAuth 2.0 screen's resource server client secret tool (AD-51, AD-56 (i)): propose storing the
/// client secret one resource server presents to its introspection endpoint. It reads the server
/// fresh through <class>OcuPilot.Port.OAuthResourceServerPort</class> and mints a proposal whose card
/// asks for the secret at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b>: the vendor's <code>CHANGESECRET</code>
/// type takes exactly <code>{ClientSecret}</code>. The kernel supplies it at the write from the
/// descriptor's declaration (<parameter>SECRETBODY</parameter>); the model can never supply one, and
/// no read, proposal, diff, ledger row or log line carries one (AD-35). A confirm that supplies none
/// is refused by the port, because the vendor would store an empty secret.</p>
/// <p>Its fingerprint covers the issuer endpoint and the client ID; the secret is never read
/// back.</p>
Class OcuPilot.Screen.Tool.OAuthResourceServerSetSecret Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthresourceservers.setsecret";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthResourceServerTab";

Parameter DESCRIPTION = "Propose storing the client secret one OAuth 2.0 resource server on this instance presents to its introspection endpoint. It changes nothing by itself: it answers a proposal the user reviews, and the user types the secret on the card when confirming. Never send a secret: name the server exactly as the resource servers list reports it, and nothing else.";

/// <p>The vendor's own secret request type.</p>
Parameter WRITETYPE = "CHANGESECRET";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "ClientSecret";

/// <p>The top-level names the <code>GET</code> answers that the subject reads. The <code>GET</code>
/// answers neither the name nor the secret.</p>
Parameter READANSWERS = "IssuerEndpoint,ClientId";

Parameter PRECONDITIONFIELD = "ClientId";

Parameter FINGERPRINTSUBJECT = "IssuerEndpoint,ClientId";

Parameter PORTCLASS = "OcuPilot.Port.OAuthResourceServerPort";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ResourceServer"
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
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The resource server whose client secret is to be stored, by its name exactly as the resource servers list reports it. The secret is typed by the user at confirmation and is never an argument.", "string")
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

/// <p>The card's one row: <code>{field: ClientSecret, before: "", after: ""}</code>, so the card masks
/// it and asks for it. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report that resource server's own record, so no secret is stored for it"
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

}
