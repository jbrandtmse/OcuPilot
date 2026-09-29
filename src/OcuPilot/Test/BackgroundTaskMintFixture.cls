/// <p>Test-only <class>OcuPilot.Screen.Tool.BackgroundTaskMint</class> subclass whose one replaced
/// seam is the port: <method>PortClassOf</method> answers
/// <class>OcuPilot.Test.BackgroundTaskFixture</class>, so the mint's fresh read goes through the
/// shipped background task port with its answers armed. Everything else is the shipped mint.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackgroundTaskMintFixture Extends OcuPilot.Screen.Tool.BackgroundTaskMint
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit "OcuPilot.Test.BackgroundTaskFixture"
}

}
