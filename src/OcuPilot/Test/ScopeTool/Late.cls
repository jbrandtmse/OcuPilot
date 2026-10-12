/// <p>Fixture: a counting read tool whose wire name sorts after every starting-set tool, so the last
/// tool of the array is deferred.</p>
Class OcuPilot.Test.ScopeTool.Late Extends OcuPilot.Test.DispatchTool.Counter
{

Parameter TOOLNAME = "zprobe.late.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "A fixture read tool that sorts last, and that counts its calls.";

}
