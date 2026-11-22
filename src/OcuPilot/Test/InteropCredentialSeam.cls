/// <p>Test-only <class>OcuPilot.Test.ProhibitedFixture</class> subclass whose stored agent definitions cannot be read: the class
/// <method>OcuPilot.Kernel.Proposal.Prohibited.AgentStateClass</method> names is this one, and its
/// <method>GuardedCredentialNamedByEnabled</method> answers an error status. Every predicate is the shipped one.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropCredentialSeam Extends OcuPilot.Test.ProhibitedFixture
{

ClassMethod AgentStateClass() As %String
{
    Quit $ClassName()
}

/// <p>The read that fails.</p>
ClassMethod GuardedCredentialNamedByEnabled(pName As %String, Output pNamed As %Boolean) As %Status
{
    Set pNamed = 0
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropCredentialSeam: the stored agent definitions cannot be read")
}

}
