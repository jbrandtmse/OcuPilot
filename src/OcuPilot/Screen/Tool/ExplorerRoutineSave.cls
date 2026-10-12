/// <p>The Routines list's save, which the routine editor sends and the agent proposes (Stories 19.3 and 20.21,
/// <class>OcuPilot.Screen.Tool.ExplorerSave</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineSave Extends OcuPilot.Screen.Tool.ExplorerSave
{

Parameter TOOLNAME = "explorer.routines.save";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

Parameter DESCRIPTION = "Propose a change to one routine's or include file's text in the turn's namespace, which the user confirms. Confirm saves the text and then compiles it as the user, and the card shows the outcome, which this tool never answers. Read the text first with explorer.routine.source, then send Edits: one to 20 replacements, each an object with exactly Old and New. Each Old is copied exactly from that read and must occur exactly once in the stored text, and New replaces it. Each Old is matched exactly, character for character, against the text this instance stores. The copy explorer.class.source and explorer.routine.source send can differ from it: control and invisible characters are removed, a key-shaped value reads [redacted], and the data delimiter's name is changed. Choose an Old that avoids those places. A routine whose name begins with %, an OcuPilot routine, a routine in %SYS, and a routine stored in another database are refused; the person can save those from the routine editor.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

ClassMethod DocumentEndpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINE
}

}
