/// <p>The managed file transfer connections' token revoke tool (AD-51, AD-52, Story 18.26): propose revoking one
/// connection's access token, through the vendor's <code>Security.MFT</code> <code>REVOKE</code>. It reads the
/// connection fresh through <class>OcuPilot.Port.MftPort</class>'s composed <code>STATE</code> and mints a
/// proposal whose card shows the connection leaving its authorized state. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>REVOKE</code> reads no body and takes the connection as
/// its <code>connection</code> query, so the tool admits no settable field. A connection that holds no token is
/// refused <parameter>OcuPilot.Api.MftConnectionError.TOKENNONE</parameter> by the fresh read, before anything is
/// minted or sent, because the vendor answers 200 and changes nothing there; a confirm reads that refusal as the
/// target having moved (<parameter>PRECONDITIONCODES</parameter>). Its fingerprint covers
/// <code>ApplicationName</code> and <code>IsAuthorized</code>. No token, hash or count is read, stored or shown
/// (AD-35). It is destructive: the connection cannot transfer files until it is authorized again on the classic
/// page, and a real revoke calls the file service, so every test that revokes a held token runs through
/// <class>OcuPilot.Test.MftSeamPort</class>.</p>
Class OcuPilot.Screen.Tool.MftConnectionRevoke Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.mftconnections.revoketoken";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.MftConnectionList";

Parameter DESCRIPTION = "Propose revoking the access token of one managed file transfer connection. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the connection exactly as the Managed file transfer connections list reports it. A connection that is not authorized holds no token and is refused. Once revoked the connection cannot transfer files until a person authorizes it again on the classic Managed File Transfer Connections page.";

/// <p>The port that composes the fresh read from the connection and its list row (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.MftPort";

Parameter READTYPE = "STATE";

Parameter WRITETYPE = "REVOKE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The connection is still listed, with its token gone.</p>
Parameter CHANGEACTION = "updated";

Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the list's Revoke token carries out (AD-53).</p>
Parameter SCREENACTIONS = "revoke-token";

/// <p>The names <parameter>READTYPE</parameter> answers: the connection's five fields and the list row's
/// <code>IsAuthorized</code>.</p>
Parameter READANSWERS = "Service,URL,SSLConfiguration,Username,ApplicationName,IsAuthorized";

/// <p>The card's one row is labelled <code>AccessToken</code>, which names the state the action removes rather
/// than a field the payload carries (AD-10, AD-51).</p>
Parameter STATEFIELD = "AccessToken";

Parameter PRECONDITIONFIELD = "IsAuthorized";

Parameter FINGERPRINTSUBJECT = "ApplicationName,IsAuthorized";

/// <p>The fresh read's refusal when the connection holds no token: a confirm reads it as the target having
/// moved.</p>
Parameter PRECONDITIONCODES = "MFT.TOKEN.NONE";

/// <p>The client maps it to <code>mftRevokeConsequence</code>.</p>
Parameter CONSEQUENCECODE = "MFT.REVOKE";

/// <p>The pair this tool requires beyond the list's own: none (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.MFT"
}

/// <p><class>OcuPilot.Screen.Tool.MftConnectionMint</class>, which refuses an empty name in the published
/// sentence.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MftConnectionMint"
}

ClassMethod IdParam() As %String
{
    Quit "connection"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.MftConnectionCreate).Described(##super(pDescriptor), 0)
}

/// <p><parameter>CONSEQUENCECODE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "AccessToken", before:
/// "Authorized", after: "", removed: true}</code>. A read that answered no <parameter>PRECONDITIONFIELD</parameter>
/// is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tState = ""
        If $IsObject(pFresh) Set tState = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
        If tState = "" {
            Set pProblem = "this instance did not report whether that connection is authorized, and a connection whose state is unknown is not one to revoke"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", tState, "string")
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

/// <p>What the caller must hold: the list's own pairs, each once (AD-8). The revoke runs on the classic list
/// page itself, so it declares no <code>CLASSICPAGES</code> (AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
