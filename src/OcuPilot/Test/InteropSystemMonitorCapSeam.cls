/// <p><class>OcuPilot.Test.InteropSystemMonitorSeam</class> with the drill-downs' row limit lowered to three, so a test reads that three rows come whole, that four are cut at three, and that a caller
/// that asks for one row beyond its cap is answered it and so reads the truncation (Story 24.17 Batch 5).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropSystemMonitorCapSeam Extends OcuPilot.Test.InteropSystemMonitorSeam
{

Parameter SYSTEMMONITORROWSMAX As INTEGER = 3;

}
