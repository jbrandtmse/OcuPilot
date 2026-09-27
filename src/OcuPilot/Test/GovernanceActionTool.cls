/// <p>Fixture: a write tool declaring <parameter>OcuPilot.Screen.Tool.Base.GOVERNANCEACTION</parameter>,
/// so the <code>tool:action</code> key form is exercised although no shipped tool declares one. It
/// lives under <code>OcuPilot.Test.</code>, which the production registry never discovers, and it
/// has no baseline line: every key it yields is disabled unless a setting says otherwise.</p>
Class OcuPilot.Test.GovernanceActionTool Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.governed.act";

Parameter KIND = "write";

Parameter DESCRIPTION = "Probe: acts on the probe target, one of two actions.";

Parameter GOVERNANCEACTION = "Action";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {"Action": {"type": "string", "enum": ["start", "stop"], "description": "What to do."}}, "required": ["Action"], "additionalProperties": false}
}

ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = {}
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

}
