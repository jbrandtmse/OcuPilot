/// <p>Fixture: a counting read tool that is not advertised (AD-53), whose description would match a
/// search for it: it is listed, never sent to a provider and never found.</p>
Class OcuPilot.Test.ScopeTool.Hidden Extends OcuPilot.Test.DispatchTool.Counter
{

Parameter TOOLNAME = "probe.hidden.read";

Parameter KIND = "read";

Parameter ADVERTISED = 0;

Parameter DESCRIPTION = "A fixture read tool that is not advertised, and that the discovery tool must not find.";

}
