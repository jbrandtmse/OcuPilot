/// <p><class>OcuPilot.Kernel.Proposal.Prohibited</class> whose globals arm reads through <class>OcuPilot.Test.GlobalLocationSeam</class>, so
/// <class>OcuPilot.Test.GlobalWrite</class> asks the shipped arm about a global stored where a test says. Nothing else differs from the shipped set.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.GlobalProhibited Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod GlobalPortClass() As %String
{
    Quit "OcuPilot.Test.GlobalLocationSeam"
}

}
