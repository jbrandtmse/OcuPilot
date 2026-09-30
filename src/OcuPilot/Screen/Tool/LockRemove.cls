/// <p>The Locks list's removal of one lock (AD-6, AD-51, AD-52, AD-53): remove the lock whose
/// <code>DeleteID</code> is the target. Two callers reach it: the Locks list's Remove locks dialog
/// through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body and admits one argument,
/// <parameter>OVERRIDEFIELD</parameter>, which reaches <class>OcuPilot.Port.LockPort</class> through the
/// port query (<method>PortQuery</method>) as the vendor's in-transaction check. The fresh read is the
/// port's <code>ROW</code>, the one lock whose <code>DeleteID</code> is the id exactly, and the write is
/// its <code>REMOVE</code>, one <code>Lock</code> <code>DELETE</code> sent only for an id that re-read
/// holds.</p>
/// <p><b>The in-transaction check</b> (DW-1073) is the vendor's own: the port asks it for a local
/// owner unless <parameter>OVERRIDEFIELD</parameter> is true, and never for a remote one, as the classic
/// page does. Its 409 is refused <code>LOCK.INTRANSACTION</code> with nothing removed; a proposal that
/// overrides it on a local owner carries that code as its consequence
/// (<parameter>CONSEQUENCEINTRANSACTION</parameter>).</p>
/// <p><b>It declares <code>%DB_IRISSYS:WRITE</code> beyond the list's pairs</b> (AD-8 as amended
/// 2026-09-30), since the vendor answers <code>#921</code> on every removal without it, and the classic
/// Manage Locks page's custom resource (AD-44). A lock on one of OcuPilot's own globals is refused by
/// the kernel (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTLOCK</parameter>) on both
/// callers.</p>
/// <p>A subclass that removes an owner's locks declares its own name, action, read, write, subject and
/// precondition, and answers the owner-kind refusal in <method>OwnerProblem</method>.</p>
Class OcuPilot.Screen.Tool.LockRemove Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.locks.remove";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LockList";

Parameter DESCRIPTION = "Propose removing one lock on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the lock by its DeleteID exactly as the locks list reports it. Removing a lock lets another process take it at once, whatever its owner was using it to protect. RemoveInTransaction false asks the instance to refuse the removal when the owning process is in an open transaction; true removes it anyway and leaves that transaction running without it, so propose true only once the user has chosen that. A lock on one of OcuPilot's own globals is refused.";

/// <p>The port that reads the lock and sequences its removal (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.LockPort";

/// <p>The Locks list's Remove locks dialog's "This lock", whose one value is
/// <parameter>OVERRIDEFIELD</parameter> (AD-56 (ii)).</p>
Parameter SCREENACTIONS = "remove";

Parameter SCREENVALUES = "remove=RemoveInTransaction";

/// <p>The fresh read: the one lock, answered by the port.</p>
Parameter READTYPE = "ROW";

/// <p>The port's removal of the one lock.</p>
Parameter WRITETYPE = "REMOVE";

/// <p>No body: the port composes the vendor's query (<parameter>OcuPilot.Port.LockPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: another process may take a removed lock at once, and whatever its owner was
/// protecting with it is unprotected.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>What <parameter>READTYPE</parameter> answers through the port (DW-1475).</p>
Parameter READANSWERS = "DeleteID,Pid,Owner,RemoteOwner,Reference,ModeCount,Directory,System,RemoveInTransaction";

Parameter PRECONDITIONFIELD = "DeleteID";

Parameter FINGERPRINTSUBJECT = "DeleteID,RemoteOwner,RemoveInTransaction";

/// <p>The one argument: whether the removal goes ahead when the owner is in an open transaction.</p>
Parameter OVERRIDEFIELD = "RemoveInTransaction";

/// <p>The pair every removal needs beyond the list's own (AD-8 as amended 2026-09-30).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic page whose operation these removals perform (AD-44 as amended 2026-09-30).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Locks";

/// <p>The consequence a proposal that overrides the in-transaction check on a local owner carries:
/// the code the lock port answers the vendor's in-transaction refusal with, which the client maps to
/// <code>lockRemoveInTransaction</code>.</p>
Parameter CONSEQUENCEINTRANSACTION = "LOCK.INTRANSACTION";

/// <p>An owner-scope removal of a remote client's locks, pinned equal to
/// <code>lockRemoveRefusalRemote</code>.</p>
Parameter REMOTEREASON = "Its owner is a remote client, not a process on this instance.";

/// <p>A remote-client removal of a local process's locks, pinned equal to
/// <code>lockRemoveRefusalLocal</code>.</p>
Parameter LOCALREASON = "Its owner is a process on this instance, not a remote client.";

/// <p>An owner set beyond <parameter>OcuPilot.Port.LockPort.MAXOWNERLOCKS</parameter>, pinned equal
/// to <code>lockRemoveTooMany</code>.</p>
Parameter TOOMANYREASON = "This owner holds more than 200 locks, and one removal names at most 200.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.LockPort).#LOCKENDPOINT
}

/// <p>The list's row key.</p>
ClassMethod IdArgument() As %String
{
    Quit "DeleteID"
}

/// <p>The query parameter the port reads the lock from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.LockPort).#IDPARAM
}

/// <p><parameter>OVERRIDEFIELD</parameter> alone: the tool sends no body, so its field list is empty
/// by derivation, and the one argument reaches the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#OVERRIDEFIELD)
}

/// <p>The identifying property described and <parameter>OVERRIDEFIELD</parameter> required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "A DeleteID the Locks read returned, copied exactly. A lock the list does not report is refused.", "string")
    }
    Do tProperties.%Set(..#OVERRIDEFIELD, {"type": "boolean", "description": "false asks the instance to refuse the removal when the owning process is in an open transaction, which removes nothing; true removes the lock anyway and leaves that transaction running without it."})
    Do tSchema.%Get("required").%Push(..#OVERRIDEFIELD)
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of the <parameter>CLASSICPAGES</parameter> page, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The removed rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per lock
/// the write removes, <code>{field: &lt;Reference&gt;, before: &lt;ModeCount&gt;, after: "",
/// removed: true}</code>. A read that names no lock, and one <method>OwnerProblem</method> refuses,
/// are <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that lock, and a lock nobody established is not one to remove"
            Quit
        }
        Set pProblem = ..OwnerProblem(pFresh)
        If pProblem '= "" Quit
        Set tLocks = ..LocksOf(pFresh)
        Set tIterator = tLocks.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLock) {
            If '$IsObject(tLock) Continue
            Set tRow = {}
            Do tRow.%Set("field", tLock.%Get("Reference"), "string")
            Do tRow.%Set("before", tLock.%Get("ModeCount"), "string")
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

/// <p>The locks the write removes, as the fresh read <var>pFresh</var> answers them: the one row
/// here.</p>
ClassMethod LocksOf(pFresh As %DynamicObject) As %DynamicArray
{
    Set tLocks = []
    Do tLocks.%Push(pFresh)
    Quit tLocks
}

/// <p>Why this tool does not act on the owner <var>pFresh</var> names, or <code>""</code>. None here:
/// one lock is removable whoever owns it.</p>
ClassMethod OwnerProblem(pFresh As %DynamicObject) As %String
{
    Quit ""
}

/// <p>The in-transaction check and the stored ids, under the port's own query keys, from the stored
/// payload <var>pPayload</var> (AD-52): <code>checkTxn</code> is <code>0</code> for a remote owner
/// and where <parameter>OVERRIDEFIELD</parameter> is true, <code>1</code> otherwise; the ids are the
/// payload's <code>DeleteIDs</code> where it carries them as an array, else its
/// <code>DeleteID</code>.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tRemote = (pPayload.%GetTypeOf("RemoteOwner") = "boolean") && pPayload.%Get("RemoteOwner")
    Set tOverride = (pPayload.%GetTypeOf(..#OVERRIDEFIELD) = "boolean") && pPayload.%Get(..#OVERRIDEFIELD)
    Set pQuery(##class(OcuPilot.Port.LockPort).#CHECKTXNQUERY) = $Select(tRemote || tOverride: 0, 1: 1)
    If pPayload.%GetTypeOf("DeleteIDs") = "array" {
        Set pQuery(##class(OcuPilot.Port.LockPort).#IDSQUERY) = pPayload.%Get("DeleteIDs").%ToJSON()
    } ElseIf (pPayload.%GetTypeOf("DeleteID") = "string") && (pPayload.%Get("DeleteID") '= "") {
        Set tIds = []
        Do tIds.%Push(pPayload.%Get("DeleteID"), "string")
        Set pQuery(##class(OcuPilot.Port.LockPort).#IDSQUERY) = tIds.%ToJSON()
    }
}

/// <p>The screen's value as this tool's argument (AD-56 (ii)): <code>true</code> or <code>false</code>,
/// and any other spelling refused.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tValue = ""
    If $IsObject(pValues) Set tValue = pValues.%Get(..#OVERRIDEFIELD)
    If (tValue '= "true") && (tValue '= "false") {
        Set pProblem = "'" _ ..#OVERRIDEFIELD _ "' is true or false"
        Quit $$$OK
    }
    Do pArgs.%Set(..#OVERRIDEFIELD, (tValue = "true"), "boolean")
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCEINTRANSACTION</parameter> for a payload that overrides the in-transaction
/// check on a local owner, and none otherwise: the proposal then says what removing the lock of an
/// owner in a transaction leaves behind.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) Quit ""
    If (pPayload.%GetTypeOf(..#OVERRIDEFIELD) '= "boolean") || 'pPayload.%Get(..#OVERRIDEFIELD) Quit ""
    If (pPayload.%GetTypeOf("RemoteOwner") = "boolean") && pPayload.%Get("RemoteOwner") Quit ""
    Quit ..#CONSEQUENCEINTRANSACTION
}

}
