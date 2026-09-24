/// <p>Test-only <class>OcuPilot.Kernel.Provider.TestCall</class> that makes the call in process:
/// <method>Call</method> runs <code>InvokeDraft</code> in this process with <var>pWaited</var> 0
/// and never times out. <class>OcuPilot.Test.DefinitionsProbe</class> answers it, so every
/// in-process <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> driver keeps the
/// process-private stubs of <class>OcuPilot.Test.ProviderPortProbe</class>, which a child job
/// cannot see.</p>
/// <p>It is also the gateway seam's stub: while <method>SetGateway</method> has armed a value,
/// <method>GatewayClass</method> answers this class, whose
/// <method>GatewayResponseTimeout</method> answers that value.</p>
Class OcuPilot.Test.AgentConnectionInline Extends OcuPilot.Kernel.Provider.TestCall
{

ClassMethod Call(pPortClass As %String, ByRef pValues, ByRef pMessages, pBound As %Numeric, Output pResponse As OcuPilot.Kernel.Provider.Response, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWaited As %Integer, Output pTimedOut As %Boolean)
{
    Set pWaited = 0
    Set pTimedOut = 0
    Kill tTools
    Do $ClassMethod(pPortClass, "InvokeDraft", .pValues, .pMessages, .tTools, "", .pResponse, .pHttpStatus, .pFault)
}

/// <p>This class while a gateway value is armed, the shipped reader otherwise.</p>
ClassMethod GatewayClass() As %String
{
    If $Data(^||OcuPilotAgentConnectionInline("gateway")) Quit "OcuPilot.Test.AgentConnectionInline"
    Quit ##super()
}

/// <p>Answer <var>pTimeout</var> from the gateway read from now on; <method>Forget</method>
/// disarms.</p>
ClassMethod SetGateway(pTimeout As %String)
{
    Set ^||OcuPilotAgentConnectionInline("gateway") = pTimeout
}

/// <p>Disarm the gateway value.</p>
ClassMethod Forget()
{
    Kill ^||OcuPilotAgentConnectionInline
}

/// <p>The armed value, in the shape <method>OcuPilot.Install.Installer.GatewayResponseTimeout</method>
/// answers: <var>pSource</var> <code>""</code> when the value is <code>""</code>, as the installer
/// answers when neither source does.</p>
ClassMethod GatewayResponseTimeout(Output pTimeout As %String, Output pSource As %String) As %Status
{
    Set pTimeout = $Get(^||OcuPilotAgentConnectionInline("gateway"))
    Set pSource = $Select(pTimeout = "": "", 1: "probe")
    Quit $$$OK
}

}
