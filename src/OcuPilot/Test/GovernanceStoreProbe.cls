/// <p>Test double for <class>OcuPilot.Kernel.Governance.Policy</class> whose policy store cannot
/// be read: <method>StoreClass</method> names this class, and <method>GuardedAll</method> answers
/// an error with no values, as an unreadable <class>OcuPilot.Kernel.State.Policy</class> does.
/// Everything else is the shipped resolver's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and writes nothing.</p>
Class OcuPilot.Test.GovernanceStoreProbe Extends OcuPilot.Kernel.Governance.Policy
{

/// <p>This class, so <method>Resolve</method> reads the failing store below.</p>
ClassMethod StoreClass() As %String
{
    Quit $ClassName()
}

/// <p>A store read that fails: no values, version 0, and an error.</p>
ClassMethod GuardedAll(Output pValues, Output pVersion As %Integer) As %Status
{
    Kill pValues
    Set pVersion = 0
    Quit $$$ERROR($$$GeneralError, "the governance store probe cannot be read")
}

}
