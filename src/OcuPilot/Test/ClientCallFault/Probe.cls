/// <p>Fixture: a client-fulfilled tool whose <code>Directive</code> answers an error status and
/// leaves <var>pFault</var> empty, which is the one branch of
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> no landed fixture reaches --
/// <class>OcuPilot.Test.LedgerClientTool.Probe</class>'s directive always succeeds, and every
/// shipped <code>Directive</code> that refuses carries a fault code.</p>
/// <p>Its own package, so it changes no other registry's tool count.</p>
Class OcuPilot.Test.ClientCallFault.Probe Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.clientfault.read";

Parameter KIND = "read";

Parameter FULFILMENT = "client";

Parameter DESCRIPTION = "Fixture: a client-fulfilled read tool whose Directive fails without a fault code.";

ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {"Name": {"type": "string"}}, "required": [], "additionalProperties": false}
}

ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {"navigated": {"type": "boolean"}}, "required": ["navigated"], "additionalProperties": false}
}

/// <p><b>The signature mirrors <method>OcuPilot.Screen.Tool.Navigate.Directive</method> exactly</b>,
/// trailing <var>pCriterion</var> and <var>pCriteria</var> included: <class>OcuPilot.Kernel.Agent.Dispatch</class> calls it
/// positionally by name, and a near-miss compiles and answers <code>TOOL.UNAVAILABLE</code> rather
/// than failing where it was written (Story 5.8).</p>
/// <p>The whole point of the fixture: an error status with no fault object at all, so the resolver
/// takes its <code>Else</code> leg -- log the failure, normalise the status, answer the generic
/// unavailable result.</p>
ClassMethod Directive(pDescriptor As %String, pArgs As %DynamicAbstractObject, Output pRoute As %String, Output pEntityId As %String, Output pFault As %DynamicObject, Output pCriterion As %String, Output pCriteria As %DynamicObject) As %Status
{
    Set pCriterion = ""
    Set pCriteria = ""
    Set pRoute = ""
    Set pEntityId = ""
    Set pFault = ""
    Quit $$$ERROR($$$GeneralError, "clientfaultprobe: the directive failed with no fault code")
}

/// <p>Never called: a client-fulfilled tool's body runs in the browser.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ClientCallFault.Probe.View should never be called")
}

}
