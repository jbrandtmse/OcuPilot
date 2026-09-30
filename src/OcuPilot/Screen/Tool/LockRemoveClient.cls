/// <p>The Locks list's removal of every lock one remote client holds (AD-6, AD-51, AD-52): as
/// <class>OcuPilot.Screen.Tool.LockRemoveProcess</class>, for an owner the listing reports
/// <code>RemoteOwner</code> true, whose owner key is the client's (inference: the classic page's
/// <code>"C"_PidInternal</code>, read from vendor source). The vendor's in-transaction check is never
/// asked for a remote owner, as the classic page does not ask it, so its proposal carries no
/// consequence code; a local owner is refused.</p>
Class OcuPilot.Screen.Tool.LockRemoveClient Extends OcuPilot.Screen.Tool.LockRemoveProcess
{

Parameter TOOLNAME = "osmgmt.locks.removeclient";

Parameter DESCRIPTION = "Propose removing every lock one remote client holds on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name any one of the client's locks by its DeleteID exactly as the locks list reports it, where the list reports RemoteOwner true; the proposal lists every lock of that client, and a lock it takes after it is not removed. Removing a lock lets another process take it at once. The instance does not check a remote client's transactions, so RemoveInTransaction changes nothing here; send false. A lock held by a process on this instance is refused here, and so is a set above 200 locks or one holding a lock on OcuPilot's own globals.";

Parameter SCREENACTIONS = "removeclient";

Parameter SCREENVALUES = "removeclient=RemoveInTransaction";

Parameter REMOTE As BOOLEAN = 1;

}
