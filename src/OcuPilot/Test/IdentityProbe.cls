/// <p>Fixture: <class>OcuPilot.Kernel.Identity</class> reading through
/// <class>OcuPilot.Test.IdentityUnknownState</class> instead of the real escalation, so the
/// unreadable-flag branch is observable (Story 5.4, AC7). Everything else is the shipped code.</p>
Class OcuPilot.Test.IdentityProbe Extends OcuPilot.Kernel.Identity
{

ClassMethod StateClass() As %String
{
    Quit "OcuPilot.Test.IdentityUnknownState"
}

}
