/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Draft</class> subclass whose one replaced seam is the
/// default port: <class>OcuPilot.Port.MgmntPort</class>, which answers no script form for any
/// request type, so a tool declaring the default port reaches the missing-form refusal.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DraftNoForm Extends OcuPilot.Kernel.Proposal.Draft
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.MgmntPort"
}

}
