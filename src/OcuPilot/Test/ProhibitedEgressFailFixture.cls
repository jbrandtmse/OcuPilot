/// <p>Test-only <class>OcuPilot.Test.ProhibitedFixture</class> subclass whose outbound settings read fails: the class
/// <method>OcuPilot.Kernel.Proposal.Prohibited.EgressStateClass</method> names is this one, and its
/// <method>Resolve</method> answers an error status. Every predicate is the shipped one.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ProhibitedEgressFailFixture Extends OcuPilot.Test.ProhibitedFixture
{

ClassMethod EgressStateClass() As %String
{
    Quit $ClassName()
}

/// <p>The read that fails.</p>
ClassMethod Resolve(Output pSettings) As %Status
{
    Kill pSettings
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProhibitedEgressFailFixture: the outbound settings cannot be read")
}

}
