/// <p>Fixture: the first of two tool classes declaring the same <parameter>TOOLNAME</parameter>
/// (<class>OcuPilot.Test.ClashTool.Second</class>), so
/// <class>OcuPilot.Test.ClashTool.Registry</class> exercises
/// <method>OcuPilot.Screen.Tool.Registry.Claim</method>'s duplicate-name refusal.</p>
Class OcuPilot.Test.ClashTool.First Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.clash.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "Fixture: one of two tools declaring the same name.";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
}

/// <p>Declared: none (AD-3). Fixture.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
}

ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = {}
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

}
