/// <p>The Globals list's import (Story 21.17, <class>OcuPilot.Screen.Tool.ExplorerImport</class>): the same operation as the Classes and
/// Routines lists' imports, so a file's every document is loaded, its globals versioned by their content
/// (<method>OcuPilot.Port.AtelierPort.Examine</method>) and judged by the code arm and the globals' (AD-10).</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalImport Extends OcuPilot.Screen.Tool.ExplorerImport
{

Parameter TOOLNAME = "explorer.globals.import";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerGlobalList";

Parameter DESCRIPTION = "Propose importing every document one file on the server holds into the route's namespace: an XML export, such as one the Globals list's export wrote, or one .cls, .mac, .inc or .int file. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'import' as the id, name the file by `root` and `path` as for export, and set Compile. The import replaces each document of the same name in the namespace without asking, a global's every node included, so say so in the rationale. What it loads and the compiler's output are shown to the user, never to you. Importing needs WRITE on the namespace's routines database; a file holding a document whose name begins with OcuPilot, a global of the instance's code or one stored in OcuPilot's own or a system database, or a global above 3,000,000 characters that it would replace, is refused.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTGLOBALS
}

}
