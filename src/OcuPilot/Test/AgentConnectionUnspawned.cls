/// <p>Test-only <class>OcuPilot.Kernel.Provider.TestCall</class> whose spawn is never accepted:
/// <method>Spawn</method> records the arguments it was handed for the child's <code>JOB</code> and
/// answers 0, starting nothing, so <method>Call</method> takes its spawn-failed path with no
/// provider call made. Needs nothing of the environment.</p>
Class OcuPilot.Test.AgentConnectionUnspawned Extends OcuPilot.Kernel.Provider.TestCall
{

ClassMethod Spawn(pNonce As %String, pPortClass As %String, pValuesJson As %String, pNeedsKey As %Boolean, pMessagesJson As %String, Output pChild As %Integer) As %Boolean
{
    Set pChild = ""
    Set ^||OcuPilotAgentConnectionUnspawned("values") = pValuesJson
    Set ^||OcuPilotAgentConnectionUnspawned("messages") = pMessagesJson
    Set ^||OcuPilotAgentConnectionUnspawned("needsKey") = pNeedsKey
    Quit 0
}

/// <p>What the last <method>Spawn</method> was handed under <var>pWhat</var>: <code>values</code>,
/// <code>messages</code> or <code>needsKey</code>.</p>
ClassMethod Handed(pWhat As %String) As %String
{
    Quit $Get(^||OcuPilotAgentConnectionUnspawned(pWhat))
}

/// <p>Forget what was handed.</p>
ClassMethod Forget()
{
    Kill ^||OcuPilotAgentConnectionUnspawned
}

}
