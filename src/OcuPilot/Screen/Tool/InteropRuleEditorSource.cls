/// <p>The agent's read of the class text behind the business rule editor screen (Story 20.16,
/// <class>OcuPilot.Screen.Tool.InteropEditorSource</class>): the text the screen's editor shows for a subclass of
/// <code>Ens.Rule.Definition</code>, as saved on the instance.</p>
Class OcuPilot.Screen.Tool.InteropRuleEditorSource Extends OcuPilot.Screen.Tool.InteropEditorSource
{

Parameter TOOLNAME = "interop.ruleeditor.source";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropRuleEditor";

Parameter NAMEHINT = "One business rule class, as Package.Name.cls, spelled as interop.rules.read answers its Name.";

Parameter DESCRIPTION = {"Read the source text of one business rule, the class the business rule editor screen shows, as saved on this instance in the namespace this turn is scoped to; its XData holds the rule definition. " _ ..#WARN _ " " _ ..#CUTTEXT};

}
