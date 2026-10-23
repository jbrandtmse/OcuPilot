/// <p>The agent's read of the class text behind the data transformation editor screen (Story 20.16,
/// <class>OcuPilot.Screen.Tool.InteropEditorSource</class>): the text the screen's editor shows for a subclass of
/// <code>Ens.DataTransformDTL</code>, as saved on the instance.</p>
Class OcuPilot.Screen.Tool.InteropTransformEditorSource Extends OcuPilot.Screen.Tool.InteropEditorSource
{

Parameter TOOLNAME = "interop.transformeditor.source";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropTransformEditor";

Parameter NAMEHINT = "One data transformation class, as Package.Name.cls, spelled as interop.transforms.read answers its Name.";

Parameter DESCRIPTION = {"Read the source text of one data transformation written in DTL, the class the data transformation editor screen shows, as saved on this instance in the namespace this turn is scoped to; its XData holds the DTL. " _ ..#WARN _ " " _ ..#CUTTEXT};

}
