/// <p>Test-only <class>OcuPilot.Port.ProviderPort</class> subclass that replaces its five seams
/// with switches, so every branch of the port can be driven in process and with no socket
/// opened.</p>
/// <p>The catalog is <class>OcuPilot.Test.CatalogProbe</class> by default, two of whose extra rows
/// name two different stub adapters -- which is what makes "the adapter comes from the row"
/// observable at a floor whose shipped table holds one row -- or a switched catalog class when a
/// test sets one (<method>SetCatalogClass</method>), the same unset-falls-through shape every
/// other switch here uses. The gate is
/// <class>OcuPilot.Test.ProviderGate</class>, because the suite runs as <code>%All</code> and the
/// real check cannot be made to refuse. The credential class, the caller's identity and the
/// TLS-configuration answer are each a switch with an unset state that falls through to the
/// shipped behaviour, so a test that sets none of them exercises production's own path.</p>
/// <p><b>No method of the port itself is replaced.</b> The gate order, the endpoint judgement, the
/// adapter resolution, the request configuration and the fault are the shipped ones.
/// <method>LogRaw</method> records each line before calling the shipped one, so a test can read
/// what reached the log.</p>
Class OcuPilot.Test.ProviderPortProbe Extends OcuPilot.Port.ProviderPort
{

/// <p>Forget every switch, so the next call behaves as production does apart from the catalog and
/// the gate.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotProviderPortProbe
    Do ##class(OcuPilot.Test.ProviderGate).Allow()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
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

/// <p><class>OcuPilot.Test.CatalogProbe</class>'s extra provider rows, so every column a story
/// added has a row that exercises it -- or the switched catalog when a test set one with
/// <method>SetCatalogClass</method>.</p>
ClassMethod CatalogClass() As %String
{
    If $Get(^||OcuPilotProviderPortProbe("catalogClass")) '= "" Quit ^||OcuPilotProviderPortProbe("catalogClass")
    Quit "OcuPilot.Test.CatalogProbe"
}

/// <p>Resolve the catalog through <var>pClass</var> from now on; <code>""</code> restores the
/// shipped probe catalog. Story 3.4's DW-360 leg uses this to reach
/// <class>OcuPilot.Test.CatalogAnthropicStub</class>, whose <code>anthropic</code> row -- the
/// only key <method>OcuPilot.Kernel.AgentRules.Validate</method> accepts -- answers a stub
/// adapter.</p>
ClassMethod SetCatalogClass(pClass As %String)
{
    Set ^||OcuPilotProviderPortProbe("catalogClass") = pClass
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

/// <p>Record each line the port logs as <code>message | code | status text</code>, then write it
/// through the shipped <method>OcuPilot.Port.ProviderPort.LogRaw</method>.</p>
ClassMethod LogRaw(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotProviderPortProbe("log", $Increment(^||OcuPilotProviderPortProbe("log"))) = pMessage _ " | " _ pCode _ " | " _ $System.Status.GetErrorText(pStatus)
    Do ##super(pMessage, pStatus, pCode)
}

/// <p>Every line recorded since the last <method>Reset</method>, joined by <code>$Char(10)</code>,
/// or <code>""</code> when none was.</p>
ClassMethod Logged() As %String
{
    Set tLines = ""
    For tI = 1:1:+$Get(^||OcuPilotProviderPortProbe("log")) {
        Set tLines = tLines _ $Select(tI = 1: "", 1: $Char(10)) _ $Get(^||OcuPilotProviderPortProbe("log", tI))
    }
    Quit tLines
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
