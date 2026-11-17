/// <p>Story 24.6's person-only rule for the command console (AD-10, AD-53), <class>OcuPilot.Test.UnitTestPersonOnly</class> with
/// its parameters overridden: <code>explorer.command.run</code> is in none of the agent's lists, resolves to the agent by no
/// name, is refused <code>PROHIBITED.PERSONONLY</code> by a set whose registry lists it as advertised, and every registered write
/// of the command endpoint declares <code>PERSONGATE</code> and is unadvertised. Its screen has no read tool, so the legs that
/// look for one are skipped.</p>
/// <p>Live-safe and unarmed, as its parent is.</p>
Class OcuPilot.Test.CommandPersonOnly Extends OcuPilot.Test.UnitTestPersonOnly
{

Parameter TOOLNAME = "explorer.command.run";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.ExplorerCommandRun";

Parameter WIRENAME = "explorer_command_run";

Parameter READWIRENAME = "";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerCommand";

Parameter LITERAL = "command";

Parameter ENDPOINT = "Command";

Parameter QUERY = "command console";

}
