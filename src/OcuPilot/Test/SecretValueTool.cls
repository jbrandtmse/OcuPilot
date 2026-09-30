/// <p>Test-only write tool on the Users list whose screen action carries the screen's declared
/// <code>Password</code>, which this tool does not send as a secret: <class>OcuPilot.Screen.Tool.UserUpdate</class>
/// with one action added. It lives outside every tool registry's package, so it is never a
/// registered tool.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SecretValueTool Extends OcuPilot.Screen.Tool.UserUpdate
{

Parameter SCREENACTIONS = "reveal";

Parameter SCREENVALUES = "reveal=Password";

}
