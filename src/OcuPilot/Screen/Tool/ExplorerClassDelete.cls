/// <p>The Classes list's delete (Story 19.2, <class>OcuPilot.Screen.Tool.ExplorerDelete</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerClassDelete Extends OcuPilot.Screen.Tool.ExplorerDelete
{

Parameter TOOLNAME = "explorer.classes.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerClassList";

Parameter DESCRIPTION = "Propose deleting up to 100 classes of the route's namespace in one call. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name each class exactly as the Classes list reports it, as Package.Name.cls, separated by commas. Each class's source and compiled code are removed and cannot be restored from OcuPilot; a persistent class's stored data is kept. Deleting needs WRITE on the namespace's routines database, and a class whose name begins with OcuPilot is refused.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES
}

}
