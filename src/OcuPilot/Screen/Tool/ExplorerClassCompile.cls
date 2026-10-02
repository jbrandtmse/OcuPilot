/// <p>The Classes list's compile (Story 19.2, <class>OcuPilot.Screen.Tool.ExplorerCompile</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerClassCompile Extends OcuPilot.Screen.Tool.ExplorerCompile
{

Parameter TOOLNAME = "explorer.classes.compile";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerClassList";

Parameter DESCRIPTION = "Propose compiling up to 100 classes of the route's namespace in one call. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name each class exactly as the Classes list reports it, as Package.Name.cls, separated by commas, and set KeepSource, CompileDependents and SkipUpToDate. The compiler's output is shown to the user on the card, never to you. Compiling needs WRITE on the namespace's routines database, and a class whose name begins with OcuPilot is refused.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES
}

}
