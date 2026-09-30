/// <p>Test-only <class>OcuPilot.Screen.Tool.LocalDatabaseExpand</class> subclass declaring
/// <class>OcuPilot.Test.DatabaseVolumePort</class> as its port, so the agent's mint of Add a volume reads
/// the new volume directory that port was armed with (Story 18.4). Outside the tool package, so the
/// registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamVolumeLocalDatabaseExpand Extends OcuPilot.Screen.Tool.LocalDatabaseExpand
{

Parameter PORTCLASS = "OcuPilot.Test.DatabaseVolumePort";

}
