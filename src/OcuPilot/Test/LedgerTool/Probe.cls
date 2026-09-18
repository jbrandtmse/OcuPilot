/// <p>Fixture: a read tool declaring its <code>Value</code> argument secret (AD-3), so the ledger's
/// declaration layer can be driven against a name no pattern matches -- which is the whole reason
/// the declaration exists.</p>
Class OcuPilot.Test.LedgerTool.Probe Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.ledger.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "Fixture: a read tool one of whose arguments is declared secret.";

/// <p>Declared: <code>Value</code>. A wallet secret's own field name, which
/// <method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method> does not match.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit $ListBuild("Value")
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {"Value": {"type": "string"}, "Name": {"type": "string"}}, "required": [], "additionalProperties": false}
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
