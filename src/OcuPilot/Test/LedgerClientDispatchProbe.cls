/// <p>Fixture: the shipped dispatcher reading <class>OcuPilot.Test.LedgerClientTool.Registry</class>,
/// so <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> resolves a client-fulfilled
/// tool that declares a secret argument. No shipped client-fulfilled tool declares one
/// (<class>OcuPilot.Screen.Tool.Navigate</class> declares none), so without this the
/// client-fulfilled half of the mandatory-declaration wiring has nothing to exercise.</p>
Class OcuPilot.Test.LedgerClientDispatchProbe Extends OcuPilot.Kernel.Agent.Dispatch
{

ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Test.LedgerClientTool.Registry"
}

/// <p>DW-1381: the governance gate, answerable from this class so the two refusals
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> returns before it reads a
/// privilege pair -- a gate that could not decide and a gate that denied -- can be driven without
/// touching the instance's own governance policy. Unarmed, it is the shipped gate (Release 1
/// allows every registered tool), so a test that names neither <method>FailGate</method> nor
/// <method>DenyGate</method> behaves exactly as production.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.LedgerClientDispatchProbe"
}

/// <p>Answer the next <method>Decide</method> with an error status, the shape a policy read that
/// raised takes.</p>
ClassMethod FailGate()
{
    Set ^||OcuPilotLedgerClientGate("fail") = 1
}

/// <p>Answer the next <method>Decide</method> refused, with <var>pCode</var>
/// (<code>""</code> falls back to the shipped default,
/// <parameter>OcuPilot.Api.Error.TOOLDENIED</parameter>).</p>
ClassMethod DenyGate(pCode As %String = "")
{
    Set ^||OcuPilotLedgerClientGate("deny") = pCode
}

/// <p>Forget every armed gate answer, restoring the shipped gate's own allow-everything
/// decision.</p>
ClassMethod ClearGate()
{
    Kill ^||OcuPilotLedgerClientGate
}

ClassMethod Decide(pTool As %String, pKind As %String, pUser As %String, pArgs As %DynamicAbstractObject, Output pDecision) As %Status
{
    If $Get(^||OcuPilotLedgerClientGate("fail")) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerClientDispatchProbe: the probe answered the governance gate as failed")
    }
    If $Data(^||OcuPilotLedgerClientGate("deny")) {
        Kill pDecision
        Set pDecision("allowed") = 0
        Set pDecision("code") = ^||OcuPilotLedgerClientGate("deny")
        Quit $$$OK
    }
    Quit ##class(OcuPilot.Kernel.Governance.Gate).Decide(pTool, pKind, pUser, pArgs, .pDecision)
}

}
