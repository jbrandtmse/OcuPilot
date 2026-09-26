/// <p>Test-only <class>OcuPilot.Api.Definitions</class> whose bound, and optionally whose call
/// class, are process-private switches: <method>TestBoundSeconds</method> and
/// <method>TestCallClass</method> answer them when set. The port stays the shipped
/// <class>OcuPilot.Port.ProviderPort</class> and, unless switched, the call the shipped
/// <class>OcuPilot.Kernel.Provider.TestCall</class>, so the child job it spawns reaches the armed
/// <code>turnprobe</code> row, whose script a separate process can read.</p>
Class OcuPilot.Test.AgentConnectionProbe Extends OcuPilot.Api.Definitions
{

/// <p>The switched bound, or the shipped one when no switch is set.</p>
ClassMethod TestBoundSeconds() As %Integer
{
    If $Get(^||OcuPilotAgentConnectionProbe("bound")) '= "" Quit ^||OcuPilotAgentConnectionProbe("bound")
    Quit ##super()
}

/// <p>The switched call class, or the shipped one when no switch is set.</p>
ClassMethod TestCallClass() As %String
{
    If $Get(^||OcuPilotAgentConnectionProbe("call")) '= "" Quit ^||OcuPilotAgentConnectionProbe("call")
    Quit ##super()
}

/// <p>Make the next calls through <var>pClass</var>; <code>""</code> restores the shipped
/// class.</p>
ClassMethod SetCall(pClass As %String)
{
    Set ^||OcuPilotAgentConnectionProbe("call") = pClass
}

/// <p>Bound the next calls at <var>pSeconds</var>; <code>""</code> restores the shipped bound.</p>
ClassMethod SetBound(pSeconds As %String)
{
    Set ^||OcuPilotAgentConnectionProbe("bound") = pSeconds
}

/// <p>Forget the switch.</p>
ClassMethod Forget()
{
    Kill ^||OcuPilotAgentConnectionProbe
}

}
