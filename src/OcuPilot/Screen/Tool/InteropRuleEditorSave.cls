/// <p>The agent's save of the class text behind the business rule editor screen (Story 20.16,
/// <class>OcuPilot.Screen.Tool.InteropEditorSave</class>): a change to a business rule, which the person confirms.
/// It admits a subclass of <code>Ens.Rule.Definition</code> and no other class.</p>
Class OcuPilot.Screen.Tool.InteropRuleEditorSave Extends OcuPilot.Screen.Tool.InteropEditorSave
{

Parameter TOOLNAME = "interop.ruleeditor.save";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropRuleEditor";

Parameter KINDBASE = "Ens.Rule.Definition";

Parameter KINDNOUN = "a business rule";

Parameter READWITH = "interop.ruleeditor.source";

Parameter DESCRIPTION = {"Propose a change to one business rule, the class the business rule editor screen shows, in the turn's namespace, which the user confirms. Confirm saves the class text, compiles it as the user and opens the document again in the editor, which drops any change not saved there; the card shows the compile's outcome, which this tool never answers. " _ ..#WARN _ " Read the class's text first with interop.ruleeditor.source, then send Edits: one to 20 replacements, each an object with exactly Old and New. Each Old is copied exactly from that read and must occur exactly once in the stored text, and New replaces it. " _ ..#MATCHRULE _ " A class that is not a business rule, a class whose name begins with %, an OcuPilot class, a class in %SYS and a class stored in another database are refused; explorer.classes.save changes other classes."};

}
