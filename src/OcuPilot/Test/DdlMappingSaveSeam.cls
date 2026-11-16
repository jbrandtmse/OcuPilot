/// <p><class>OcuPilot.Area.OsMgmt.DdlMappingSave</class> with its port the recording seam <class>OcuPilot.Test.ConfigGateSeam</class>, so a
/// test drives the Save's refusals and its create with nothing written to the instance. Nothing else differs from the shipped Save.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DdlMappingSaveSeam Extends OcuPilot.Area.OsMgmt.DdlMappingSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ConfigGateSeam"
}

}
