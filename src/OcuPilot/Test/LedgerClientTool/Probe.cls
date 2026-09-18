/// <p>Fixture: a client-fulfilled tool declaring its <code>Value</code> argument secret (AD-3,
/// Story 4.7), so <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method>'s own
/// secret-argument wiring can be driven with a name no pattern matches -- the client-fulfilled
/// counterpart of <class>OcuPilot.Test.LedgerTool.Probe</class>. Its own package, a sibling of
/// <package>OcuPilot.Test.LedgerTool</package> rather than nested under it, keeps it out of every
/// other ledger fixture registry's discovery (whose <code>ToolPackage</code> is
/// <code>OcuPilot.Test.LedgerTool.</code>, a prefix a nested package would also match), so it changes
/// no existing tool count.</p>
Class OcuPilot.Test.LedgerClientTool.Probe Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.ledger.clientread";

Parameter KIND = "read";

Parameter FULFILMENT = "client";

Parameter DESCRIPTION = "Fixture: a client-fulfilled read tool one of whose arguments is declared secret.";

/// <p>Declared: <code>Value</code>, the same name no pattern in
/// <method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method> matches.</p>
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
    Quit {"type": "object", "properties": {"navigated": {"type": "boolean"}}, "required": ["navigated"], "additionalProperties": false}
}

/// <p>A fixed directive, needing no screen registry to resolve: the point of this fixture is the
/// secret declaration <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> reads, not
/// route validation, which <class>OcuPilot.Screen.Tool.Navigate</class>'s own tests already cover.</p>
ClassMethod Directive(pDescriptor As %String, pArgs As %DynamicAbstractObject, Output pRoute As %String, Output pEntityId As %String, Output pFault As %DynamicObject) As %Status
{
    Set pRoute = "probe/ledger/clientroute"
    Set pEntityId = ""
    Set pFault = ""
    Quit $$$OK
}

/// <p>Never called: a client-fulfilled tool's body runs in the browser
/// (<class>OcuPilot.Screen.Tool.Navigate</class>'s own <method>View</method> follows the same
/// discipline). Answers a loud refusal rather than serving anything, so a mis-wiring fails where it
/// happened.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerClientTool.Probe.View should never be called")
}

}
