/// <p>Fixture: a storage face whose <method>GuardedUserEnabled</method> answers "enabled" while
/// reporting that it could not read the flag, so
/// <method>OcuPilot.Kernel.Identity.IsEnabled</method>'s fail-closed branch can be driven (Story
/// 5.4, AC7). No instance produces that state on demand: the escalation either reads the flag or
/// raises.</p>
/// <p>It escalates nothing and reads nothing.</p>
Class OcuPilot.Test.IdentityUnknownState Extends %RegisteredObject
{

/// <p><var>pUnavailable</var> is 0 on purpose: the escalation is reported as having been in
/// effect, so what this fixture drives is the "the read answered nothing about the account"
/// branch and not the "OcuPilot's install is broken" branch, which
/// <class>OcuPilot.Test.Disabled</class> drives against the real application instead.</p>
ClassMethod GuardedUserEnabled(pUserName As %String, Output pKnown As %Boolean, Output pUnavailable As %Boolean) As %Boolean
{
    Set pKnown = 0
    Set pUnavailable = 0
    Quit 1
}

}
