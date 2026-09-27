/// <p>Fixture: the retention sweep over an identity read that is unavailable, so
/// <method>OcuPilot.Kernel.Retention.IsGone</method>'s "an unreadable identity removes nothing"
/// branch can be driven (<class>OcuPilot.Test.Retention</class>). No instance produces that state
/// on demand. It escalates nothing and reads nothing.</p>
Class OcuPilot.Test.RetentionIdentityDown Extends OcuPilot.Kernel.Retention
{

ClassMethod IdentityClass() As %String
{
    Quit "OcuPilot.Test.RetentionIdentityDown"
}

/// <p>Answers that no account was read because the escalation was not in effect.</p>
ClassMethod GuardedUserEnabled(pUserName As %String, Output pKnown As %Boolean, Output pUnavailable As %Boolean) As %Boolean
{
    Set pKnown = 0
    Set pUnavailable = 1
    Quit 0
}

}
