/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass whose <method>Store</method>
/// succeeds and then deletes the agent definition a test named, on its way out.</p>
/// <p>It exists for one branch of
/// <method>OcuPilot.Api.Definitions.HandleStoreCredential</method>: the arm that runs when the key
/// was written and the definition could not then be disabled. That arm is reachable only if the
/// row goes between the store and the clear, and a handler seam whose only consumer is a test is
/// what DW-352 refused -- so the interleave is done here, through the credential seam the handler
/// already publishes for its own reasons.</p>
/// <p><b>Everything else is inherited.</b> The write itself is the shipped
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method>, called through <code>##super</code>, so
/// the key really is behind the reference when the handler's next step fails -- which is the state
/// that arm's message describes.</p>
/// <p><b>Armed per run and disarmed on use</b>, so a class that leaves this seam selected does not
/// delete a definition on its next store.</p>
Class OcuPilot.Test.SecretDeletingStore Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>Delete definition <var>pId</var> after the next store, and no store after that.</p>
ClassMethod ArmDeletion(pId As %String)
{
    Set ^||OcuPilotSecretDeletingStore("id") = pId
}

/// <p>Forget any arming.</p>
ClassMethod Forget()
{
    Kill ^||OcuPilotSecretDeletingStore
}

/// <p>The shipped store, then the armed deletion. A store that failed deletes nothing: the arm
/// this exists to reach is "the key was written and the definition could not be disabled", and a
/// deletion after a failed write would reach a different branch entirely.</p>
ClassMethod Store(pCredentialName As %String, pBody As %DynamicObject, pField As %String, Output pCreated As %Boolean) As %Status
{
    Set tSC = ##super(pCredentialName, pBody, pField, .pCreated)
    If $$$ISERR(tSC) Quit tSC
    Set tId = $Get(^||OcuPilotSecretDeletingStore("id"))
    If tId = "" Quit tSC
    Kill ^||OcuPilotSecretDeletingStore
    Do ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tId)
    Quit tSC
}

}
