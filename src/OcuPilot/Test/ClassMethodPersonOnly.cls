/// <p>Story 24.6's person-only rule for the class method console (AD-10, AD-53), <class>OcuPilot.Test.UnitTestPersonOnly</class>
/// with its parameters overridden: <code>explorer.classmethod.run</code> is in none of the agent's lists, resolves to the agent by
/// no name, is refused <code>PROHIBITED.PERSONONLY</code> by a set whose registry lists it as advertised, and every registered
/// write of the class method endpoint declares <code>PERSONGATE</code> and is unadvertised. Its screen has no read tool, so the
/// legs that look for one are skipped.</p>
/// <p>Live-safe and unarmed, as its parent is.</p>
Class OcuPilot.Test.ClassMethodPersonOnly Extends OcuPilot.Test.UnitTestPersonOnly
{

Parameter TOOLNAME = "explorer.classmethod.run";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.ExplorerClassMethodRun";

Parameter WIRENAME = "explorer_classmethod_run";

Parameter READWIRENAME = "";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerClassMethod";

Parameter LITERAL = "classmethod";

Parameter ENDPOINT = "ClassMethod";

Parameter QUERY = "class method console";

}
