/// <p>Test-only <class>OcuPilot.Screen.Tool.SqlSettingSet</class> subclass declaring <class>OcuPilot.Test.ConfigGateSeam</class> as its port, so a
/// screen action run through <class>OcuPilot.Test.SeamSqlActionFixture</class> reads and writes through the seam. Outside the tool package, so the
/// registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamSqlSettingSet Extends OcuPilot.Screen.Tool.SqlSettingSet
{

Parameter PORTCLASS = "OcuPilot.Test.ConfigGateSeam";

}
