/// <p>The managed file transfer connections' delete tool (AD-6, AD-8, AD-51, Story 18.26): propose removing one
/// connection from this instance. It reads the connection fresh through the vendor's own <code>Security.MFT</code>
/// <code>GET</code> and mints a proposal whose card lists the settings it removes. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, so the tool admits no
/// settable field. <b>The vendor's delete also deletes the connection's OAuth 2.0 client configuration</b>,
/// unless another connection names it, and that client's server description when no other client uses it
/// (measured at Story 18.26's plan); the proposal's consequence says so
/// (<parameter>CONSEQUENCECODE</parameter>). <class>OcuPilot.Port.MftPort</class> answers a delete the vendor
/// failed after removing the connection as done. Its fingerprint covers <code>ApplicationName</code>, the name of
/// the client configuration the delete removes with it. The delete runs on the classic list page itself, so it
/// declares no replaced page.</p>
Class OcuPilot.Screen.Tool.MftConnectionDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.mftconnections.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.MftConnectionList";

Parameter DESCRIPTION = "Propose deleting one managed file transfer connection. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the connection exactly as the Managed file transfer connections list reports it. The OAuth 2.0 client configuration the connection names is deleted with it unless another connection names it, and so is that client's server description when no other client uses it.";

Parameter PORTCLASS = "OcuPilot.Port.MftPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted connection is gone, and so is the client configuration it names.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Service,URL,SSLConfiguration,Username,ApplicationName";

/// <p>The rows the card lists: the settings the prohibited set reviews, which leave out <code>Service</code>.</p>
Parameter REMOVALROWS = "URL,SSLConfiguration,Username,ApplicationName";

Parameter PRECONDITIONFIELD = "ApplicationName";

Parameter FINGERPRINTSUBJECT = "ApplicationName";

/// <p>The client maps it to <code>mftDeleteConsequence</code>.</p>
Parameter CONSEQUENCECODE = "MFT.DELETE";

/// <p>The pair this tool requires beyond the list's own: none, and the declaration keeps the idiom of every tool
/// of the area (AD-8). Security's set is what the write needs, measured at Story 18.26's plan.</p>
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

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name the read answers, carrying the value the instance holds and no
/// after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report which OAuth 2.0 client configuration that connection names, and a connection whose client is unknown is not one to delete"
            Quit
        }
        Set tNames = $ListFromString(..#REMOVALROWS)
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            If pFresh.%GetTypeOf(tField) = "unassigned" Continue
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

/// <p>What the caller must hold: the list's own pairs, each once (AD-8). The delete runs on the classic list
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
