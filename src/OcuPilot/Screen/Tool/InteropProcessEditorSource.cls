/// <p>The agent's read of the class text behind the business process editor screen (Story 20.16,
/// <class>OcuPilot.Screen.Tool.InteropEditorSource</class>): the text the screen's editor shows for a subclass of
/// <code>Ens.BusinessProcessBPL</code>, as saved on the instance.</p>
Class OcuPilot.Screen.Tool.InteropProcessEditorSource Extends OcuPilot.Screen.Tool.InteropEditorSource
{

Parameter TOOLNAME = "interop.processeditor.source";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropProcessEditor";

Parameter NAMEHINT = "One business process class, as Package.Name.cls, spelled as interop.processes.read answers its Name.";

Parameter DESCRIPTION = {"Read the source text of one business process written in BPL, the class the business process editor screen shows, as saved on this instance in the namespace this turn is scoped to; its XData holds the BPL. " _ ..#WARN _ " " _ ..#CUTTEXT};

}
