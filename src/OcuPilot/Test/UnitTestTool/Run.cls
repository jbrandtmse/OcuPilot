/// <p>Fixture: the shipped unit-test run tool with its port replaced by <class>OcuPilot.Test.DevToolPortFixture</class>, whose
/// harvest port records each body call instead of running it, so a test sends a person's Run through
/// <class>OcuPilot.Api.ScreenAction</class> without a <code>%UnitTest</code> run ever starting (Story 24.5). Every other
/// declaration is the shipped tool's.</p>
Class OcuPilot.Test.UnitTestTool.Run Extends OcuPilot.Screen.Tool.ExplorerUnitTestRun
{

Parameter PORTCLASS = "OcuPilot.Test.DevToolPortFixture";

}
