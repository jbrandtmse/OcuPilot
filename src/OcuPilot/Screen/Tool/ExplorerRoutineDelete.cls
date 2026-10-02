/// <p>The Routines list's delete (Story 19.2, <class>OcuPilot.Screen.Tool.ExplorerDelete</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineDelete Extends OcuPilot.Screen.Tool.ExplorerDelete
{

Parameter TOOLNAME = "explorer.routines.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

Parameter DESCRIPTION = "Propose deleting up to 100 routines or include files of the route's namespace in one call. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name each exactly as the Routines list reports it, such as Name.mac or Name.inc, separated by commas. A routine's source and its generated and object code are removed and cannot be restored from OcuPilot. Deleting needs WRITE on the namespace's routines database, and a routine whose name begins with OcuPilot is refused.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

}
