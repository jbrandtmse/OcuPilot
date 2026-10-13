/// <p>The Story 18.37 fixture: the throwaway principals <class>OcuPilot.Test.InteropUsageGate</class> signs
/// in as. It is <class>OcuPilot.Test.MetricsProbe</class>'s principal helpers, which are
/// <class>OcuPilot.Test.SqlActivityProbe</class>'s, under a prefix of its own, so a name of any of the
/// stories is refused by the others' and each counts only its own leftovers.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropUsageProbe Extends OcuPilot.Test.MetricsProbe
{

/// <p>The prefix every principal's name carries.</p>
Parameter PRINCIPALPREFIX = "OcuProbe1837";

}
