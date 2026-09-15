/// <p>Test-only <class>OcuPilot.Port.ProviderPort</class> subclass that replaces its five seams
/// with switches, so every branch of the port can be driven in process and with no socket
/// opened.</p>
/// <p>The catalog is <class>OcuPilot.Test.CatalogProbe</class>, whose two extra rows name two
/// different stub adapters -- which is what makes "the adapter comes from the row" observable at a
/// floor whose shipped table holds one row. The gate is
/// <class>OcuPilot.Test.ProviderGate</class>, because the suite runs as <code>%All</code> and the
/// real check cannot be made to refuse. The credential class, the caller's identity and the
/// TLS-configuration answer are each a switch with an unset state that falls through to the
/// shipped behaviour, so a test that sets none of them exercises production's own path.</p>
/// <p><b>No method of the port itself is replaced.</b> The gate order, the endpoint judgement, the
/// adapter resolution, the request configuration and the fault are the shipped ones.</p>
Class OcuPilot.Test.ProviderPortProbe Extends OcuPilot.Port.ProviderPort
{

/// <p>Forget every switch, so the next call behaves as production does apart from the catalog and
/// the gate.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotProviderPortProbe
    Do ##class(OcuPilot.Test.ProviderGate).Allow()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
}

/// <p>Answer subsequent calls as <var>pUser</var> -- <code>UnknownUser</code> or
/// <code>_PUBLIC</code> to drive the anonymous refusal.</p>
ClassMethod SetUser(pUser As %String)
{
    Set ^||OcuPilotProviderPortProbe("user") = pUser
}

/// <p>Answer the TLS-configuration question with <var>pState</var>: <code>missing</code>,
/// <code>present</code>, or <code>""</code> to ask the instance for real.</p>
ClassMethod SetSslState(pState As %String)
{
    Set ^||OcuPilotProviderPortProbe("ssl") = pState
}

/// <p>Resolve credentials through <var>pClass</var> from now on; <code>""</code> restores the
/// shipped ladder.</p>
ClassMethod SetSecretClass(pClass As %String)
{
    Set ^||OcuPilotProviderPortProbe("secretClass") = pClass
}

/// <p>The two extra provider rows, so both columns this story added have a row that exercises
/// them.</p>
ClassMethod CatalogClass() As %String
{
    Quit "OcuPilot.Test.CatalogProbe"
}

/// <p>The switchable gate.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ProviderGate"
}

/// <p>The switched credential class, or the shipped one when no test set it.</p>
ClassMethod SecretClass() As %String
{
    If $Get(^||OcuPilotProviderPortProbe("secretClass")) '= "" Quit ^||OcuPilotProviderPortProbe("secretClass")
    Quit ##super()
}

/// <p>The switched caller, or the real one when no test set it.</p>
ClassMethod ResolvedUsername() As %String
{
    If $Data(^||OcuPilotProviderPortProbe("user")) Quit ^||OcuPilotProviderPortProbe("user")
    Quit ##super()
}

/// <p>The switched TLS answer, or the real <code>%SYS</code> read when no test set one.</p>
ClassMethod SslConfigurationMissing(pName As %String) As %Boolean
{
    Set tState = $Get(^||OcuPilotProviderPortProbe("ssl"))
    If tState = "missing" Quit 1
    If tState = "present" Quit 0
    Quit ##super(pName)
}

}
