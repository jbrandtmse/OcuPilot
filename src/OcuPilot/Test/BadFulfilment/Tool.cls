/// <p>Fixture: a <code>write</code>-kind tool declaring <code>FULFILMENT = "client"</code>
/// (Story 4.7, AC9), so <class>OcuPilot.Test.BadFulfilment.Registry</class> exercises
/// <method>OcuPilot.Screen.Tool.Registry.FulfilmentProblem</method>'s build-time refusal of that
/// combination -- a client-fulfilled tool can never pass the write restraint path.</p>
Class OcuPilot.Test.BadFulfilment.Tool Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.badfulfilment.write";

Parameter KIND = "write";

Parameter FULFILMENT = "client";

Parameter DESCRIPTION = "Fixture: a write-kind tool that wrongly declares client fulfilment.";

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
