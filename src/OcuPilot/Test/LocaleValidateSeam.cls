/// <p><class>OcuPilot.Screen.Tool.LocaleValidate</class> reading through <class>OcuPilot.Test.LocaleGateSeam</class>, so the lines the vendor's checks
/// answer are the ones the test feeds. It lives in the test package, which the tool registry never lists. <b>Not a
/// <class>%UnitTest.TestCase</class></b>.</p>
Class OcuPilot.Test.LocaleValidateSeam Extends OcuPilot.Screen.Tool.LocaleValidate
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.LocaleGateSeam"
}

}
