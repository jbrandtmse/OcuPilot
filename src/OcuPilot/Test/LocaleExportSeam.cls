/// <p><class>OcuPilot.Screen.Tool.LocaleExport</class> reaching its locale through <class>OcuPilot.Test.LocaleGateSeam</class>, so no export is made. Its
/// mint is <class>OcuPilot.Test.LocaleExportSeamMint</class>. It lives in the test package, which the tool registry never lists. <b>Not a
/// <class>%UnitTest.TestCase</class></b>.</p>
Class OcuPilot.Test.LocaleExportSeam Extends OcuPilot.Screen.Tool.LocaleExport
{

Parameter PORTCLASS = "OcuPilot.Test.LocaleGateSeam";

ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Test.LocaleExportSeamMint"
}

}
