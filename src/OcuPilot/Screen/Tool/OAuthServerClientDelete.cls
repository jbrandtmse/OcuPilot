/// <p>The OAuth 2.0 screen's server client description delete tool (AD-6, AD-51, FR-44): propose
/// removing one client registered with this instance's authorization server. It reads the client
/// fresh through the vendor's own <code>Security.OAuth2.ServerClients</code> <code>GET</code> and
/// mints a proposal whose card lists what would go. It writes nothing.</p>
/// <p><b>It is keyed by <code>ClientId</code>, not by <code>Name</code>.</b> The vendor's IdKey on
/// <code>OAuth2.Server.Client</code> is <code>ClientId</code>, <code>Name</code> has no unique index,
/// and the endpoint's non-list types require the <code>clientId</code> query parameter. A name could
/// not say which of two clients sharing it goes.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is true only for
/// a put, a post and the secret type, so <code>DELETE</code> reads no body and the tool admits no
/// settable field (AD-3).</p>
/// <p><b>Its fingerprint covers a declared subject</b>: the client's name, type, redirect URLs and
/// description, which is what the tab shows. The <code>GET</code> answers no <code>ClientId</code> of
/// its own, and the identity is the proposal's <code>TargetRef</code> (AD-13, AD-51). The subject
/// names neither <code>Metadata</code>, which carries <code>client_secret</code> and
/// <code>registration_access_token</code>, nor <code>ClientCredentials</code> (AD-35).</p>
/// <p><b>It is destructive</b>: the vendor's <code>DeleteId</code> revokes every access token issued
/// to the client, and nothing proposes it back. The vendor's <code>%OnAfterDelete</code> then
/// rebuilds the authorization server application's CORS allow-list from the clients that remain.</p>
/// <p>AD-10 names no OAuth 2.0 effect, so the prohibited set covers this type with the reviewed-few
/// sweep alone (<class>OcuPilot.Kernel.Proposal.Prohibited</class>).</p>
Class OcuPilot.Screen.Tool.OAuthServerClientDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthserverclients.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthServerClientTab";

Parameter DESCRIPTION = "Propose deleting one client description registered with this instance's OAuth 2.0 authorization server, which revokes every access token issued to it. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the client by its client id exactly as the server client descriptions list reports it; two clients may share a name, never a client id.";

/// <p>The row action this tool carries out from the Server client descriptions tab (AD-5, AD-53). It
/// sends no argument, because it sends no body.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The vendor's own delete request type. Measured on this build: the endpoint's
/// <code>RunDelete</code> answers 404 when <code>OAuth2.Server.Client.Exists</code> is false and
/// otherwise calls <code>DeleteId</code>, and its <code>ValidateQueryParams</code> requires
/// <code>clientId</code> for every type but a list and a post.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The AD-14 action this write performs: the row is removed.</p>
Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted server client and the access tokens issued to it are gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off a live <code>GET</code>
/// on this build, less <code>Metadata</code>, which is never named anywhere a declaration can reach
/// (AD-35). <class>OcuPilot.Test.OAuthTabs</class> pins the set against the live read.</p>
Parameter READANSWERS = "Name,RedirectURL,LaunchURL,Description,ClientType,ClientCredentials,DefaultScope";

/// <p>The read field this tool's precondition reads: <code>ClientType</code> is required on
/// <code>OAuth2.Server.Client</code>, so a read that answers none did not answer the client's own
/// record.</p>
Parameter PRECONDITIONFIELD = "ClientType";

/// <p>The subject the fingerprint covers: what the tab shows about the client beside its id.</p>
Parameter FINGERPRINTSUBJECT = "Name,ClientType,RedirectURL,Description";

/// <p><code>%Admin_OAuth2_Registration:USE</code>, the endpoint's own <code>ResourcesOR()</code>
/// resource and the one <code>OAuth2.Server.Client</code>'s <code>DeleteId</code> checks at
/// <code>USE</code>. The tab already declares it, so the resolved set is the tab's own two pairs
/// (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Registration";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ServerClients"
}

/// <p>The client's IdKey, as the server client descriptions list reports it.</p>
ClassMethod IdArgument() As %String
{
    Quit "ClientId"
}

/// <p>The vendor's query parameter for the client.</p>
ClassMethod IdParam() As %String
{
    Quit "clientId"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The server client to delete, by its client id, exactly as this instance's own server client descriptions list reports it. A name is not accepted, because two clients may share one. A client the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>The tab's own pairs together with <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>,
/// appended only when the tab does not already declare it (DW-1208).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the fresh <code>GET</code>
/// <var>pFresh</var>: one per subject field, with no after-state. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tReported = ""
        If $IsObject(pFresh) {
            Set tReported = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
        }
        If tReported = "" {
            Set pProblem = "this instance did not report that server client's own record, and a client whose type is unknown is not one to delete"
            Quit
        }
        Set tSubject = ..FingerprintSubject()
        For tI = 1:1:$ListLength(tSubject) {
            Set tField = $List(tSubject, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
