/// <p>The Classes list's export (Story 19.13, <class>OcuPilot.Screen.Tool.ExplorerExport</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerClassExport Extends OcuPilot.Screen.Tool.ExplorerExport
{

Parameter TOOLNAME = "explorer.classes.export";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerClassList";

Parameter DESCRIPTION = "Propose exporting up to 100 classes of the route's namespace to one XML file on the server. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name each class exactly as the Classes list reports it, as Package.Name.cls, separated by commas, and name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. The exported XML goes to that file and is never shown to you.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES
}

}
