/// <p><class>OcuPilot.Test.InteropAlertSeam</class> with the two list caps lowered to three, so a test pins the cap and one over without storing a thousand alerts (Story 24.17 Batch 1).
/// A parameter overridden here is compiled into this class's own copy of each method, so this class is recompiled with the port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropAlertCapSeam Extends OcuPilot.Test.InteropAlertSeam
{

Parameter ALERTSMAX As INTEGER = 3;

Parameter ALERTACTIONSMAX As INTEGER = 3;

}
