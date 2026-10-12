/// <p>Test-only <class>OcuPilot.Screen.Tool.UserSqlGrant</class> subclass declaring
/// <class>OcuPilot.Test.SqlPrivilegeSeamPort</class> as its port, so a screen action's reads and writes are
/// recorded by the seam. Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamUserSqlGrant Extends OcuPilot.Screen.Tool.UserSqlGrant
{

Parameter PORTCLASS = "OcuPilot.Test.SqlPrivilegeSeamPort";

}
