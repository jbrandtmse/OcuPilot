/// <p>The Story 18.36 fixture: the throwaway principals <class>OcuPilot.Test.DashboardDrillDownGate</class> signs
/// in as. It is <class>OcuPilot.Test.MetricsProbe</class>'s principal helpers, which are
/// <class>OcuPilot.Test.SqlActivityProbe</class>'s, under a prefix of its own, so a name of any of the three stories
/// is refused by the others' and each counts only its own leftovers.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DashboardDrillDownProbe Extends OcuPilot.Test.MetricsProbe
{

/// <p>The prefix every principal's name carries.</p>
Parameter PRINCIPALPREFIX = "OcuProbe1836";

}
