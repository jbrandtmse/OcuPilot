/// <p>The OAuth 2.0 screen's authorization server delete tool (AD-6, AD-51, AD-53): propose removing
/// this instance's authorization server configuration. It reads the configuration fresh through
/// <class>OcuPilot.Port.OAuthAuthorizationServerPort</class> and mints a proposal whose card lists
/// what would go. It writes nothing. The Authorization server tab's <code>delete</code> row action is
/// the same operation (AD-53).</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, and the tool
/// admits no settable field.</p>
/// <p><b>It is destructive</b>: the vendor deletes every client registered with the server and every
/// session with it. The fingerprint covers the issuer endpoint and the registered clients, so a
/// client registered or removed since the mint refuses the confirm.</p>
Class OcuPilot.Screen.Tool.OAuthAuthorizationServerDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserver.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerTab";

Parameter DESCRIPTION = "Propose deleting this instance's OAuth 2.0 authorization server configuration, together with every client registered with it. It changes nothing by itself: it answers a proposal the user reviews and confirms.";

/// <p>The row action this tool carries out from the Authorization server tab (AD-5, AD-53).</p>
Parameter SCREENACTIONS = "delete";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted configuration and its registered clients are gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter READANSWERS = "IssuerEndpoint,Clients,ClientsHidden";

Parameter PRECONDITIONFIELD = "IssuerEndpoint";

Parameter FINGERPRINTSUBJECT = "IssuerEndpoint,Clients,ClientsHidden";

Parameter PORTCLASS = "OcuPilot.Port.OAuthAuthorizationServerPort";

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

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: the issuer
/// endpoint, and the registered clients removed with it. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report its authorization server configuration, so there is none to delete"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#PRECONDITIONFIELD, "string")
    Do tRow.%Set("before", pFresh.%Get(..#PRECONDITIONFIELD), "string")
    Do tRow.%Set("after", "", "string")
    Do tRow.%Set("removed", 1, "boolean")
    Do pRows.%Push(tRow)
    Set tClients = ##class(OcuPilot.Area.Security.OAuthAuthorizationServerRules).ClientsRow(pFresh, 1)
    If $IsObject(tClients) Do pRows.%Push(tClients)
    Quit $$$OK
}

/// <p>The kernel-owned consequence of this payload: a delete names the clients it deletes
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ServerConsequence</method>).</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).ServerConsequence("delete", pPrivileged, pEffect)
}

}
