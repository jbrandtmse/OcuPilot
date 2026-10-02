/// <p>The Classes list's save, which the class editor sends (Story 19.3, <class>OcuPilot.Screen.Tool.ExplorerSave</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerClassSave Extends OcuPilot.Screen.Tool.ExplorerSave
{

Parameter TOOLNAME = "explorer.classes.save";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerClassList";

Parameter DESCRIPTION = "Save one class's text, as the class editor's Save does. A person's own Save reaches this tool; it is never offered to the agent.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES
}

}
