/// <p>Test-only <class>OcuPilot.Screen.Tool.SqlActivityCancel</class> subclass declaring
/// <class>OcuPilot.Test.SqlActivitySeam</class> as its port, so a screen action run through
/// <class>OcuPilot.Test.SeamSqlActivityActionFixture</class> reads and cancels the rows and answers a test arms. Outside the tool
/// package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamSqlActivityCancel Extends OcuPilot.Screen.Tool.SqlActivityCancel
{

Parameter PORTCLASS = "OcuPilot.Test.SqlActivitySeam";

}
