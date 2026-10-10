/// <p>Test-only seam for <class>OcuPilot.Test.UserCopyConfirm</class>: <class>OcuPilot.Port.UserCopyPort</class> with its
/// <code>%Admin_Secure</code> test answered no, so that the port's own gate is what refuses a copy, called in-process
/// with no route and no confirm before it. Production never calls this class.</p>
Class OcuPilot.Test.UserCopyNoGate Extends OcuPilot.Port.UserCopyPort
{

/// <p>Answer no to every resource, as a caller that holds none would.</p>
ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    Quit 0
}

}
