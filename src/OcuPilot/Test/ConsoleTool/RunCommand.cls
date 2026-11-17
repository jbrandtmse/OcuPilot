/// <p>Fixture: the shipped command console tool with its port replaced by <class>OcuPilot.Test.DevToolPortFixture</class>, whose
/// harvest port records each body call instead of running it, so a test sends a person's Run through
/// <class>OcuPilot.Api.ScreenAction</class> without a command ever running (Story 24.6). Every other declaration is the shipped
/// tool's.</p>
Class OcuPilot.Test.ConsoleTool.RunCommand Extends OcuPilot.Screen.Tool.ExplorerCommandRun
{

Parameter PORTCLASS = "OcuPilot.Test.DevToolPortFixture";

}
