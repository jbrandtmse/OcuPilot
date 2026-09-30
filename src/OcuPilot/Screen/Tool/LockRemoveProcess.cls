/// <p>The Locks list's removal of every lock one local process holds (AD-6, AD-48, AD-51, AD-52):
/// the owner is the target lock's own, the <code>DeleteID</code>'s third piece, compared exactly.
/// The fresh read is the port's <code>OWNER</code>, which enumerates that owner's locks, and the
/// write is its <code>REMOVEOWNER</code>, one <code>Lock</code> <code>DELETE</code> per enumerated
/// lock the re-read still holds.</p>
/// <p><b>The set is enumerated at the mint and fingerprinted</b> (<code>DeleteIDs</code>), so a lock
/// the owner takes or releases after the mint refuses the confirm, and a lock taken later is never
/// removed. A set above <parameter>OcuPilot.Port.LockPort.MAXOWNERLOCKS</parameter> is refused, and
/// so is a remote owner, whose locks <class>OcuPilot.Screen.Tool.LockRemoveClient</class>
/// removes.</p>
Class OcuPilot.Screen.Tool.LockRemoveProcess Extends OcuPilot.Screen.Tool.LockRemove
{

Parameter TOOLNAME = "osmgmt.locks.removeprocess";

Parameter DESCRIPTION = "Propose removing every lock one process on this instance holds. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name any one of the process's locks by its DeleteID exactly as the locks list reports it; the proposal lists every lock of that process, and a lock the process takes after it is not removed. Removing a lock lets another process take it at once. RemoveInTransaction false asks the instance to refuse a removal when the process is in an open transaction; true removes its locks anyway, so propose true only once the user has chosen that. A lock held by a remote client is refused here, and so is a set above 200 locks or one holding a lock on OcuPilot's own globals.";

Parameter SCREENACTIONS = "removeprocess";

Parameter SCREENVALUES = "removeprocess=RemoveInTransaction";

/// <p>The fresh read: the owner's locks, answered by the port.</p>
Parameter READTYPE = "OWNER";

Parameter WRITETYPE = "REMOVEOWNER";

/// <p>What <parameter>READTYPE</parameter> answers through the port (DW-1475).</p>
Parameter READANSWERS = "DeleteID,Pid,Owner,RemoteOwner,DeleteIDs,Locks,RemoveInTransaction";

Parameter PRECONDITIONFIELD = "DeleteIDs";

Parameter FINGERPRINTSUBJECT = "Owner,DeleteIDs,RemoteOwner,RemoveInTransaction";

/// <p>Whether this tool acts on a remote owner's locks rather than a local process's.</p>
Parameter REMOTE As BOOLEAN = 0;

/// <p>The owner's locks, as the fresh read enumerates them.</p>
ClassMethod LocksOf(pFresh As %DynamicObject) As %DynamicArray
{
    If pFresh.%GetTypeOf("Locks") '= "array" Quit []
    Quit pFresh.%Get("Locks")
}

/// <p><parameter>OcuPilot.Screen.Tool.LockRemove.REMOTEREASON</parameter> or
/// <parameter>OcuPilot.Screen.Tool.LockRemove.LOCALREASON</parameter> for an owner of the kind this
/// tool does not act on, <parameter>OcuPilot.Screen.Tool.LockRemove.TOOMANYREASON</parameter> for a
/// set above <parameter>OcuPilot.Port.LockPort.MAXOWNERLOCKS</parameter>, and an unpublished problem
/// for a read that enumerated no set.</p>
ClassMethod OwnerProblem(pFresh As %DynamicObject) As %String
{
    If (pFresh.%GetTypeOf("RemoteOwner") '= "boolean") || (pFresh.%GetTypeOf("Locks") '= "array") Quit "this instance did not report which locks that lock's owner holds"
    Set tRemote = ''pFresh.%Get("RemoteOwner")
    If tRemote && '..#REMOTE Quit ..#REMOTEREASON
    If 'tRemote && ..#REMOTE Quit ..#LOCALREASON
    If pFresh.%Get("Locks").%Size() > ##class(OcuPilot.Port.LockPort).#MAXOWNERLOCKS Quit ..#TOOMANYREASON
    Quit ""
}

}
