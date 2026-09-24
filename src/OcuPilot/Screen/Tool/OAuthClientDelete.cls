/// <p>The OAuth 2.0 screen's client configuration delete tool (AD-6, AD-51, FR-44): propose removing
/// one client configuration. It reads the configuration fresh through the vendor's own
/// <code>Security.OAuth2.Client.ClientConfiguration</code> <code>GET</code> and mints a proposal
/// whose card lists what would go. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is
/// <code>IsTypePut()</code> or the change-secret type, so <code>DELETE</code> reads no body, the tool
/// admits no settable field, and its field list is empty by derivation (AD-3).</p>
/// <p><b>Its fingerprint covers a declared subject</b>: the server description the configuration is
/// registered with, its client type, its default scope and whether it is enabled. The identity is
/// outside the subject (AD-13, AD-51). The subject names neither <code>Metadata</code>, which the
/// <code>GET</code> answers unmasked and which carries <code>client_secret</code> and
/// <code>registration_access_token</code>, nor <code>ClientCredentials</code>, so the stored payload,
/// the diff, the ledger row and the answer carry no secret (AD-35).</p>
/// <p><b>It is destructive</b>: the vendor's <code>DeleteId</code> also deletes every token stored for
/// the configuration, and nothing proposes it back. For a dynamically registered configuration
/// (<code>Metadata.registration_client_uri</code> set) it also asks the authorization server to
/// delete the registration, and ignores that request's outcome.</p>
/// <p>AD-10 names no OAuth 2.0 effect, so the prohibited set covers this type with the reviewed-few
/// sweep alone (<class>OcuPilot.Kernel.Proposal.Prohibited</class>).</p>
Class OcuPilot.Screen.Tool.OAuthClientDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthclients.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthClientTab";

Parameter DESCRIPTION = "Propose deleting one OAuth 2.0 client configuration from this instance, together with every token stored for it; a dynamically registered configuration is also deregistered at its authorization server. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the configuration exactly as the client configurations list reports it.";

/// <p>The row action this tool carries out from the Client configurations tab (AD-5, AD-53). It
/// sends no argument, because it sends no body.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The vendor's own delete request type. Measured on this build: the endpoint's
/// <code>RunDelete</code> answers 404 when <code>OAuth2.Client.Exists</code> is false and otherwise
/// calls <code>DeleteId</code>, and its <code>ValidateQueryParams</code> requires
/// <code>applicationName</code> for every non-list type.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The AD-14 action this write performs: the row is removed.</p>
Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted client configuration and its stored tokens are gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off a live <code>GET</code>
/// on this build, less <code>Metadata</code>, which is never named anywhere a declaration can reach
/// (AD-35). <class>OcuPilot.Test.OAuthTabs</class> pins the set against the live read.</p>
Parameter READANSWERS = "ServerDefinition,Enabled,Description,ClientType,SSLConfiguration,RedirectionEndpoint,JWTAudience,JWTInterval,ClientId,ClientCredentials,DefaultScope";

/// <p>The read field this tool's precondition reads: <code>ClientType</code> is required on
/// <code>OAuth2.Client</code>, so a read that answers none did not answer the configuration's own
/// record.</p>
Parameter PRECONDITIONFIELD = "ClientType";

/// <p>The subject the fingerprint covers: what the user reviewed about the configuration.</p>
Parameter FINGERPRINTSUBJECT = "ServerDefinition,ClientType,DefaultScope,Enabled";

/// <p><code>%Admin_OAuth2_Client:USE</code>, the endpoint's own <code>ResourcesOR()</code> resource and
/// the one <code>OAuth2.Client</code>'s <code>DeleteId</code> checks at <code>USE</code>. The tab
/// already declares it, so the resolved set is the tab's own two pairs (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Client";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Client.ClientConfiguration"
}

/// <p>The configuration's IdKey, as the client configurations list reports it.</p>
ClassMethod IdArgument() As %String
{
    Quit "ApplicationName"
}

/// <p>The vendor's query parameter for the configuration.</p>
ClassMethod IdParam() As %String
{
    Quit "applicationName"
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The client configuration to delete, by its application name, exactly as this instance's own client configurations list reports it. A configuration the list does not report is refused.", "string")
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
            Set pProblem = "this instance did not report that client configuration's own record, and a configuration whose type is unknown is not one to delete"
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
