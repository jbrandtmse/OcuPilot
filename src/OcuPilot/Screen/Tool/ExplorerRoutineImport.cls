/// <p>The Routines list's import (Story 19.13, <class>OcuPilot.Screen.Tool.ExplorerImport</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineImport Extends OcuPilot.Screen.Tool.ExplorerImport
{

Parameter TOOLNAME = "explorer.routines.import";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

Parameter DESCRIPTION = "Propose importing every document one file on the server holds into the route's namespace: an XML export, or one .cls, .mac, .inc or .int file. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'import' as the id, name the file by `root` and `path` as for export, and set Compile. The import replaces each document of the same name in the namespace without asking, so say so in the rationale. What it loads and the compiler's output are shown to the user, never to you. Importing needs WRITE on the namespace's routines database, and a file holding a document whose name begins with OcuPilot is refused.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

}
