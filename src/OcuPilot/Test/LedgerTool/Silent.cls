/// <p>Fixture: a read tool that declares nothing about its arguments -- it overrides no
/// <method>OcuPilot.Screen.Tool.Base.SecretArguments</method> -- so
/// <method>OcuPilot.Screen.Tool.Registry.ProviderTools</method>'s refusal has something to refuse
/// (AD-3). Its <code>Value</code> argument is exactly the one a name pattern cannot see.</p>
Class OcuPilot.Test.LedgerTool.Silent Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.silent.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "Fixture: a read tool that classifies none of its arguments.";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {"Value": {"type": "string"}}, "required": [], "additionalProperties": false}
}

ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {"ok": {"type": "boolean"}}, "required": ["ok"], "additionalProperties": false}
}

ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = {"ok": true}
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

}
