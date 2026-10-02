/// <p>The Routines list's save, which the routine editor sends (Story 19.3, <class>OcuPilot.Screen.Tool.ExplorerSave</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineSave Extends OcuPilot.Screen.Tool.ExplorerSave
{

Parameter TOOLNAME = "explorer.routines.save";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

Parameter DESCRIPTION = "Save one routine's or include file's text, as the routine editor's Save does. A person's own Save reaches this tool; it is never offered to the agent.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

}
