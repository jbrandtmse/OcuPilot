/// <p>The Routines list's compile (Story 19.2, <class>OcuPilot.Screen.Tool.ExplorerCompile</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineCompile Extends OcuPilot.Screen.Tool.ExplorerCompile
{

Parameter TOOLNAME = "explorer.routines.compile";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

Parameter DESCRIPTION = "Propose compiling up to 100 routines or include files of the route's namespace in one call. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name each exactly as the Routines list reports it, such as Name.mac or Name.inc, separated by commas, and set KeepSource, CompileDependents and SkipUpToDate. The compiler's output is shown to the user on the card, never to you. Compiling needs WRITE on the namespace's routines database, and a routine whose name begins with OcuPilot is refused.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

}
