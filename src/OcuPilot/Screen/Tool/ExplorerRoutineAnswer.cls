/// <p>The Routines list's answer to a source-control question (Story 21.38, <class>OcuPilot.Screen.Tool.ExplorerSourceControlAnswer</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineAnswer Extends OcuPilot.Screen.Tool.ExplorerSourceControlAnswer
{

Parameter TOOLNAME = "explorer.routines.answer";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

Parameter DESCRIPTION = "Answer a question the namespace's source-control class asked about one routine after a create or a delete. A person's own answer reaches this tool; it is never offered to the agent.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

}
