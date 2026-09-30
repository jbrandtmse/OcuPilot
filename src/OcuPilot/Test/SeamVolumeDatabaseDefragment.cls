/// <p>Test-only <class>OcuPilot.Screen.Tool.DatabaseDefragment</class> subclass declaring
/// <class>OcuPilot.Test.DatabaseVolumePort</class> as its port, so the agent's mint of a defragment
/// reads the new volume directory and threshold that port was armed with (Story 18.4). Outside the
/// tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamVolumeDatabaseDefragment Extends OcuPilot.Screen.Tool.DatabaseDefragment
{

Parameter PORTCLASS = "OcuPilot.Test.DatabaseVolumePort";

}
