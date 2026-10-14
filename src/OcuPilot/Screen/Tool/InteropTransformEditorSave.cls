/// <p>The agent's save of the class text behind the data transformation editor screen (Story 20.16,
/// <class>OcuPilot.Screen.Tool.InteropEditorSave</class>): a change to a data transformation written in DTL, which the person confirms.
/// It admits a subclass of <code>Ens.DataTransformDTL</code> and no other class.</p>
Class OcuPilot.Screen.Tool.InteropTransformEditorSave Extends OcuPilot.Screen.Tool.InteropEditorSave
{

Parameter TOOLNAME = "interop.transformeditor.save";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropTransformEditor";

Parameter KINDBASE = "Ens.DataTransformDTL";

Parameter KINDNOUN = "a data transformation written in DTL";

Parameter READWITH = "interop.transformeditor.source";

Parameter DESCRIPTION = {"Propose a change to one data transformation written in DTL, the class the data transformation editor screen shows, in the turn's namespace, which the user confirms. Confirm saves the class text, compiles it as the user and opens the document again in the editor, which drops any change not saved there; the card shows the compile's outcome, which this tool never answers. " _ ..#WARN _ " Read the class's text first with interop.transformeditor.source, then send Edits: one to 20 replacements, each an object with exactly Old and New. Each Old is copied exactly from that read and must occur exactly once in the stored text, and New replaces it. " _ ..#MATCHRULE _ " A class that is not a data transformation written in DTL, a class whose name begins with %, an OcuPilot class, a class in %SYS and a class stored in another database are refused; explorer.classes.save changes other classes."};

}
