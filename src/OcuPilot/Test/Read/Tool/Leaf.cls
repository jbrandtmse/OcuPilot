/// <p>Fixture: a concrete tool class two levels below <class>OcuPilot.Screen.Tool.Base</class>,
/// declaring no kind of its own. Discovery by superclass equality misses it; discovery by
/// <code>%Extends</code> finds it with <class>OcuPilot.Test.Read.Tool.Middle</class>'s kind.</p>
Class OcuPilot.Test.Read.Tool.Leaf Extends OcuPilot.Test.Read.Tool.Middle
{

Parameter TOOLNAME = "test.leaf.write";

Parameter DESCRIPTION = "A fixture tool that is never dispatched.";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
}

}
