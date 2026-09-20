/// <p>Fixture: a storage face whose <method>GuardedUserEnabled</method> answers "enabled" while
/// reporting that it could not read the flag, so
/// <method>OcuPilot.Kernel.Identity.IsEnabled</method>'s fail-closed branch can be driven (Story
/// 5.4, AC7). No instance produces that state on demand: the escalation either reads the flag or
/// raises.</p>
/// <p>It escalates nothing and reads nothing.</p>
Class OcuPilot.Test.IdentityUnknownState Extends %RegisteredObject
{

ClassMethod GuardedUserEnabled(pUserName As %String, Output pKnown As %Boolean) As %Boolean
{
    Set pKnown = 0
    Quit 1
}

}
