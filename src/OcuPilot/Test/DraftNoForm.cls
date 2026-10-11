/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Draft</class> subclass whose one replaced seam is the
/// default port: <class>OcuPilot.Port.MgmntPort</class>, which answers a script form for its Service
/// endpoint's create and delete alone, so a tool declaring the default port with any other endpoint
/// reaches the missing-form refusal.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DraftNoForm Extends OcuPilot.Kernel.Proposal.Draft
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.MgmntPort"
}

}
