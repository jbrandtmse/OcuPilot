/// <p>The Users list's token revoke tool (AD-51, AD-52, FR-75): propose revoking every OAuth 2.0
/// access token this instance's authorization server issued under one account's stored name. A token
/// issued under another capitalization of that name is not revoked. It reads the account
/// fresh through <class>OcuPilot.Port.TokenPort</class> and mints a proposal whose card names the
/// account. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>Security.OAuth2.Server</code>
/// <code>REVOKE</code> reads no body and takes the account as its <code>user</code> query
/// parameter, so the tool admits no settable field and its field list is empty by derivation
/// (AD-3). The port sends it under the account's stored name, because the vendor matches the
/// tokens' user name exactly.</p>
/// <p><b>Its fingerprint covers <code>Name</code></b>, the one field the write's precondition reads:
/// the port addresses the revoke by it. No admin endpoint reads token state, so no token, hash or
/// count is read, stored or shown (AD-3, AD-35).</p>
/// <p><b>It declares <code>%Admin_OAuth2_Registration:USE</code> beyond the list's own pairs</b>
/// (AD-8's named case): the endpoint's <code>ResourcesOR()</code> names it for
/// <code>REVOKE</code>, and the vendor's delete itself checks the list's
/// <code>%Admin_Secure:USE</code>.</p>
/// <p>It is destructive: a revoked token is gone, and nothing proposes it back. The prohibited set
/// refuses none of it (AD-10): the write removes no account and changes no field of one.</p>
Class OcuPilot.Screen.Tool.UserTokenRevoke Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.users.revoketokens";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

Parameter DESCRIPTION = "Propose revoking every OAuth 2.0 access token this instance's authorization server issued under one user account's name, matched exactly as this instance stores it; a token issued under another capitalization of that name is not revoked. Applications holding a revoked token must sign the user in again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the account exactly as the users list reports it.";

/// <p>The row action this tool carries out from the Users list (AD-5, AD-53). It sends no
/// argument, because it sends no body.</p>
Parameter SCREENACTIONS = "revoke-tokens";

/// <p>The port that reads the account and sends the revoke under its stored name (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.TokenPort";

/// <p>The account's own row, answered by <parameter>PORTCLASS</parameter>.</p>
Parameter READTYPE = "HOLDER";

/// <p>The vendor's own revoke request type.</p>
Parameter WRITETYPE = "REVOKE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The AD-14 action this write performs: the account is still listed, and its tokens are
/// gone.</p>
Parameter CHANGEACTION = "updated";

/// <p>Declared: a revoked token is gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names <parameter>READTYPE</parameter> answers: the <code>Security.User</code>
/// <code>LIST</code> row's own.</p>
Parameter READANSWERS = "Name,FullName,Namespace,Routine,Type,Enabled";

/// <p>The card's one row is labelled <code>OAuthTokens</code>, which names the state the action
/// removes rather than a field the payload carries (AD-10, AD-51).</p>
Parameter STATEFIELD = "OAuthTokens";

Parameter PRECONDITIONFIELD = "Name";

Parameter FINGERPRINTSUBJECT = "Name";

/// <p><code>%Admin_OAuth2_Registration:USE</code>, the endpoint's own <code>ResourcesOR()</code>
/// resource for <code>REVOKE</code> (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_OAuth2_Registration";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.Server"
}

/// <p>The vendor's query parameter for the account whose tokens are revoked.</p>
ClassMethod IdParam() As %String
{
    Quit "user"
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The user account whose OAuth 2.0 access tokens are revoked, exactly as this instance's own users list reports it. Every token this instance issued under that stored name is revoked, a token issued under another capitalization of it is not, and nothing changes until the user confirms.", "string")
    Quit tSchema
}

/// <p>The list's own pairs together with <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>,
/// each once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "OAuthTokens",
/// before: &lt;Name&gt;, after: "", removed: true}</code>. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tName = ""
        If $IsObject(pFresh) {
            Set tName = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
        }
        If tName = "" {
            Set pProblem = "this instance did not report that account's own record, and an account whose name is unknown is not one to revoke tokens for"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", tName, "string")
        Do tRow.%Set("after", "", "string")
        Do tRow.%Set("removed", 1, "boolean")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
