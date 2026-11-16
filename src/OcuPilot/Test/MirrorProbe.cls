/// <p>The Story 21.12 fixture: the throwaway principals <class>OcuPilot.Test.MirrorGate</class> signs in as. It is
/// <class>OcuPilot.Test.MetricsProbe</class>'s principal helpers under a prefix of its own, so a name of either story is refused by the
/// other's, and it counts the users and roles that prefix leaves behind (<method>Remaining</method>).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MirrorProbe Extends OcuPilot.Test.MetricsProbe
{

/// <p>The prefix every principal's name carries.</p>
Parameter PRINCIPALPREFIX = "OcuProbe2112";

}
