/// <p>Test-only <class>OcuPilot.Screen.Tool.AuditCopy</class> subclass declaring the base's default
/// port, so a screen caller resolves its port through its own <code>PortClass</code> seam. Outside
/// the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuditStartedCopy Extends OcuPilot.Screen.Tool.AuditCopy
{

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

}
