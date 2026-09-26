/// <p>A test Save: <class>OcuPilot.Area.Task.TaskSave</class> over
/// <class>OcuPilot.Test.TaskPortSkew</class>, so a create the rules accept is refused by the vendor
/// and the refusal's path through the Save can be observed.</p>
Class OcuPilot.Test.TaskSaveSkew Extends OcuPilot.Area.Task.TaskSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.TaskPortSkew"
}

}
