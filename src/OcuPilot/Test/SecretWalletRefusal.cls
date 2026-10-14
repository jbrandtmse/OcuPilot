/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass that answers a wallet rung refusal the test armed
/// instead of reading the wallet, so the provider base and port can be driven through a refusal no least-privileged
/// principal has to be logged in to produce. <method>Arm</method> names the code and the pair; <method>ArmRaise</method>
/// instead makes the shipped arm's value-free listing raise, so its failure path runs as shipped. Unarmed, and for every
/// other rung, <method>Resolve</method> is the shipped one.</p>
/// <p>What the refusal stands in for is the ladder's arm alone, which <class>OcuPilot.Test.WalletRung</class> drives as
/// real principals; what runs unchanged here is what the base and the port do with the refusal it answers.</p>
Class OcuPilot.Test.SecretWalletRefusal Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>Refuse every <code>wallet</code> resolution from now on with <var>pCode</var> and <var>pPair</var>.</p>
ClassMethod Arm(pCode As %String, pPair As %String)
{
    Set ^||OcuPilotSecretWalletRefusal = $ListBuild(pCode, pPair)
}

/// <p>Make the <code>wallet</code> arm's listing of the wallet raise from now on.</p>
ClassMethod ArmRaise()
{
    Set ^||OcuPilotSecretWalletRefusal("raise") = 1
}

/// <p>Forget the armed refusal and the armed raise.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotSecretWalletRefusal
}

/// <p>The armed refusal for the <code>wallet</code> rung, and the shipped resolution for anything else.</p>
ClassMethod Resolve(pCredType As %String, pEnvVarName As %String = "", pCredentialName As %String = "", Output pTransient As %Boolean, Output pRefusal As %List, pEndpointUrl As %String = "") As %String
{
    If (pCredType = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPEWALLET) && ($Data(^||OcuPilotSecretWalletRefusal) # 2) {
        Set pTransient = 0
        Set pRefusal = ^||OcuPilotSecretWalletRefusal
        Quit ""
    }
    Quit ##super(pCredType, pEnvVarName, pCredentialName, .pTransient, .pRefusal, pEndpointUrl)
}

/// <p>The shipped listing, or a raise when <method>ArmRaise</method> was called.</p>
ClassMethod WalletListsKeyValue(pName As %String) As %Boolean [ Private ]
{
    If $Get(^||OcuPilotSecretWalletRefusal("raise")) Throw ##class(%Exception.General).%New("probe", 5001, "WalletListsKeyValue", "the wallet listing raised")
    Quit ##super(pName)
}

}
