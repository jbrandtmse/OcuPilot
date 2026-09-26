/// <p>Test-only <class>OcuPilot.Area.WebApp.Create</class> subclass with one replaced seam:
/// <method>PortClass</method> answers <class>OcuPilot.Test.ProposalFixture</class> instead of the
/// tool's own declared port -- the seam <class>OcuPilot.Area.WebApp.Create</class>'s own doc comment
/// names. Everything else -- the name rules, the live name-taken read, the prohibited check and
/// the derivation -- is the shipped <method>Perform</method>.</p>
/// <p><b>Nothing this class reaches writes to the instance.</b> The confirmed write goes to the
/// fixture, which records the body the port received (<method>OcuPilot.Test.ProposalFixture.LastWriteBody</method>)
/// without creating a web application. The name-taken read <method>OcuPilot.Area.WebApp.FormRules.Taken</method>
/// makes is not this seam and still reads the live instance, so a caller of this class must still
/// name a target the instance genuinely does not hold.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.CreateFixture Extends OcuPilot.Area.WebApp.Create
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

}
