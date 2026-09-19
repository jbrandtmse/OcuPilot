/// <p>Fixture: a counting write tool (<class>OcuPilot.Test.DispatchTool.Counter</class>), so the
/// dispatcher's restraint branch has a write to gate.</p>
Class OcuPilot.Test.DispatchTool.Writer Extends OcuPilot.Test.DispatchTool.Counter
{

Parameter TOOLNAME = "probe.counter.write";

Parameter KIND = "write";

Parameter DESCRIPTION = "A fixture write tool that counts its calls.";

}
