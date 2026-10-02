/// <p>The Routines list's export (Story 19.13, <class>OcuPilot.Screen.Tool.ExplorerExport</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineExport Extends OcuPilot.Screen.Tool.ExplorerExport
{

Parameter TOOLNAME = "explorer.routines.export";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

Parameter DESCRIPTION = "Propose exporting up to 100 routines or include files of the route's namespace to one XML file on the server. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name each exactly as the Routines list reports it, such as Name.mac or Name.inc, separated by commas, and name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. The exported XML is shown to the user, never to you.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

}
