/// <p>AC1, AC3's request half and AC4's call-time half --
/// <class>OcuPilot.Port.ProviderPort</class>'s gate, its registry dispatch, the request it
/// configures, and the <code>PROVIDER.*</code> code each failure class produces.</p>
/// <p>Driven through <class>OcuPilot.Test.ProviderPortProbe</class>, which replaces five seams with
/// switches and nothing else: the catalog (two extra rows naming two different stub adapters), the
/// gate (because <code>%UnitTest</code> runs as <code>%All</code> and the real check cannot be made
/// to refuse), the credential class, the caller's identity and the TLS answer. Every method of the
/// port itself is the shipped one, and <b>no socket is opened</b>.</p>
Class OcuPilot.Test.ProviderPort Extends %UnitTest.TestCase
{

/// <p>The port under test.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>A credential of the shape the <code>probe-local</code> row's prefix requires.</p>
Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>A well-formed reply, so a call that reaches the transport succeeds.</p>
Parameter OKBODY = "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":2}}";

/// <p>Arm a clean port, a clean stub and a resolvable credential before each method.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit $$$OK
}

/// <p>Leave no switch set for the next method, or the next class, to inherit.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    ; Removed whether or not the method that wrote it reached its own delete: a settings row left
    ; behind would change what every later class resolves.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "no outbound settings row survives this method")
    Set tRemoved = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tRemoved, "every probe definition this method created is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Draft values for provider <var>pProvider</var> against <var>pEndpoint</var>.</p>
ClassMethod Draft(pProvider As %String, pEndpoint As %String, pMarkedLocal As %Boolean, Output pValues)
{
    Kill pValues
    Set pValues("provider") = pProvider
    Set pValues("model") = "probe-model-1"
    Set pValues("endpointUrl") = pEndpoint
    Set pValues("markedLocal") = pMarkedLocal
    Set pValues("credType") = "env"
    Set pValues("envVarName") = "OCUPILOT_PROBE_LOCAL_KEY"
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = 4000
    Set pValues("temperature") = 0
}

/// <p>One message, which every call below sends.</p>
ClassMethod Messages(Output pMessages)
{
    Kill pMessages
    Set pMessages = 1
    Set pMessages(1, "role") = "user"
    Set pMessages(1, "content") = "probe"
}

/// <p>Call the port's draft entry with <var>pValues</var>.</p>
Method CallDraft(ByRef pValues, Output pResponse, Output pHttpStatus, Output pFault) As %Status
{
    Do ..Messages(.tMessages)
    Quit $ClassMethod(..#PORT, "InvokeDraft", .pValues, .tMessages, .tTools, "", .pResponse, .pHttpStatus, .pFault)
}

/// <p>Assert that a call answered <code>$$$OK</code> and reported <var>pCode</var> as a turn
/// error.</p>
Method AssertTurnError(pSC As %Status, pResponse As OcuPilot.Kernel.Provider.Response, pFault As %DynamicObject, pCode As %String, pWhat As %String)
{
    Do $$$AssertStatusOK(pSC, pWhat _ ": the port returns $$$OK")
    Do $$$AssertTrue($IsObject(pResponse), pWhat _ ": and a response object")
    If '$IsObject(pResponse) Quit
    Do $$$AssertEquals(pResponse.StopReason, "error", pWhat _ ": whose stop reason is the failure signal")
    Do $$$AssertTrue($IsObject(pFault), pWhat _ ": and a fault")
    If '$IsObject(pFault) Quit
    Do $$$AssertEquals(pFault.code, pCode, pWhat _ ": carrying " _ pCode _ " (" _ pFault.%ToJSON() _ ")")
}

/// <p>AD-21 -- <b>every</b> entry refuses an unauthenticated principal before any port work, and
/// both placeholders are refused, because on a Minimal-security instance
/// <code>UnknownUser</code> holds <code>%All</code>.</p>
Method TestAnAnonymousCallerIsRefusedByBothEntries()
{
    For tUser = "UnknownUser", "_PUBLIC", "" {
        Do $ClassMethod(..#PORT, "SetUser", tUser)
        Do ..Draft("probe-local", "https://api.anthropic.com/v1/messages", 0, .tValues)
        Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
        Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#AUTHANONYMOUS, "the draft entry as '" _ tUser _ "'")
        Do $$$AssertEquals(tHttpStatus, 401, "answered 401 for '" _ tUser _ "'")
        Do ..Messages(.tMessages)
        Set tSC2 = $ClassMethod(..#PORT, "Invoke", "1", .tMessages, .tTools, "", .tResponse2, .tHttpStatus2, .tFault2)
        Do ..AssertTurnError(tSC2, tResponse2, tFault2, ##class(OcuPilot.Api.Error).#AUTHANONYMOUS, "the stored entry as '" _ tUser _ "'")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no transport call was made on any of them")
}

/// <p>The draft entry additionally requires OcuPilot's administrative resource, and names the pair
/// that failed so a screen can say which privilege is missing (AD-8).</p>
/// <p><b>The stored entry does not</b>: its endpoint came from the protected database, where the
/// write gate already applied AD-42's rules to it. An ordinary user running a turn goes that
/// way.</p>
Method TestTheDraftEntryRequiresTheAdministrativeResource()
{
    Do ##class(OcuPilot.Test.ProviderGate).Deny()
    Do ..Draft("probe-local", "https://api.anthropic.com/v1/messages", 0, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "a draft call without the privilege")
    Do $$$AssertEquals(tHttpStatus, 403, "answered 403")
    Do $$$AssertEquals(tFault.detail.failedPair, "OcuPilotAdmin:USE", "naming the pair that failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no transport call was made")
}

/// <p><b>AC1</b> -- two catalog rows whose <code>adapterClass</code> columns name different classes
/// are served by the class each row names, with no other change anywhere.</p>
/// <p>Mutation: add an <code>If pKey = "probe-local"</code> branch to the port's adapter
/// resolution -- the second leg goes red, because the branch would override the column that points
/// the other way.</p>
Method TestTheAdapterComesFromTheRowsOwnColumn()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Draft("probe-local", "https://api.anthropic.com/v1/messages", 0, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the call against the local-allowed row returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), "stub", "and is served by the class that row names")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Draft("probe-endpoint-required", "https://api.anthropic.com/v1/messages", 0, .tAlt)
    Set tAlt("envVarName") = "OCUPILOT_PROBE_KEY"
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("probe-abcdefghijklmnop")
    Set tSC2 = ..CallDraft(.tAlt, .tResponse2, .tHttpStatus2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the call against the endpoint-required row returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), "stubalt", "and is served by the different class that row names")
}

/// <p>A provider the catalog does not declare, and a row whose adapter class this instance does not
/// hold, are both <code>PROVIDER.UNCONFIGURED</code> rather than an exception.</p>
Method TestAnUnservedProviderIsUnconfigured()
{
    Do ..Draft("no-such-provider", "https://api.anthropic.com/v1/messages", 0, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "a provider the catalog does not declare")
    Do $$$AssertEquals(tHttpStatus, 503, "answered 503")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no transport call was made")
}

/// <p>A row whose <code>adapterClass</code> names a class this instance does not compile is
/// <code>PROVIDER.UNCONFIGURED</code> too, told apart from a provider the catalog does not
/// declare at all only by which of <method>Dispatch</method>'s two adapter-resolution checks
/// caught it.</p>
/// <p>Mutation: delete the <code>%Dictionary.CompiledClass.%ExistsId</code> half of
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method>'s guard, leaving only the
/// <code>tAdapterClass = ""</code> test -- this goes red, reporting
/// <code>PROVIDER.TRANSPORT</code> instead: <code>$ClassMethod</code> against a name with no
/// compiled class raises <code>&lt;CLASS DOES NOT EXIST&gt;</code>, which <code>Dispatch</code>'s
/// caller catches and reports as a transport failure rather than as the configuration refusal this
/// actually is.</p>
Method TestARowNamingAnUncompiledAdapterClassIsUnconfigured()
{
    Do ..Draft(##class(OcuPilot.Test.CatalogProbe).#MISSINGADAPTERKEY, "https://api.anthropic.com/v1/messages", 0, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "a row naming an adapter class this instance does not compile")
    Do $$$AssertEquals(tHttpStatus, 503, "answered 503, the same as a provider the catalog does not declare")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no transport call was made")
}

/// <p>An id no definition holds is <code>PROVIDER.UNCONFIGURED</code> -- never a 500, and never a
/// call against an empty definition.</p>
Method TestAnUnknownDefinitionIdIsUnconfigured()
{
    Do ..Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", "999999999", .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "an id no definition holds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no transport call was made")
}

/// <p><b>AC4's call-time half</b> -- an endpoint whose resolved address is one OcuPilot will not
/// call is refused <b>before any socket is opened</b>, whatever the write gate accepted.</p>
/// <p>That is the rebinding case: the stored endpoint was judged at write time and its name now
/// resolves somewhere else, which a link-local literal stands in for here.</p>
/// <p>Mutation: delete the port's re-check -- every leg goes red, reporting a call that reached the
/// transport.</p>
Method TestTheEndpointIsJudgedAgainAtCallTime()
{
    For tEndpoint = "https://169.254.169.254/v1", "https://127.0.0.1/v1", "https://no-such-host-ocupilot.invalid/v1" {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ..Draft("probe-local", tEndpoint, 0, .tValues)
        Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
        Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, "the call-time check on " _ tEndpoint)
        Do $$$AssertEquals(tHttpStatus, 502, "answered as a gateway failure for " _ tEndpoint)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no socket was opened for " _ tEndpoint)
    }
    ; Link-local has no escape at call time either, so marking the definition local on a row that
    ; allows local does not open it.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ..Draft("probe-local", "https://169.254.169.254/v1", 1, .tMarked)
    Set tMarkedSC = ..CallDraft(.tMarked, .tMarkedResponse, .tMarkedStatus, .tMarkedFault)
    Do ..AssertTurnError(tMarkedSC, tMarkedResponse, tMarkedFault, ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, "link-local marked local on a row that allows local")
}

/// <p>A stored plain-HTTP endpoint on a row that does <b>not</b> allow local is refused at call
/// time, so a row that stopped allowing local closes an endpoint that was accepted under it.</p>
Method TestAPlainHttpEndpointNeedsTheRowsPermissionAtCallTime()
{
    Do ..Draft("probe-endpoint-required", "http://127.0.0.1:11434/v1", 1, .tValues)
    Set tValues("envVarName") = "OCUPILOT_PROBE_KEY"
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, "plain HTTP on a row that forbids local")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no socket was opened")
}

/// <p><b>AC3's request half</b> -- an HTTPS call carries the named TLS configuration, server
/// identity checking on, and the instance's stored timeout and proxy settings, read back from the
/// request object the stub recorded.</p>
Method TestAnHttpsCallCarriesTheConfiguredRequest()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tStored("proxyServer") = "proxy.probe.invalid"
    Set tStored("proxyPort") = 3128
    Set tStored("proxyHttps") = 1
    Set tStored("proxyTunnel") = 1
    Set tStored("timeoutSeconds") = 45
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tStored), "the instance's outbound settings are stored")
    Do ..Draft("probe-local", "https://api.anthropic.com/v1/messages", 0, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the configured call returns $$$OK")
    Set tStub = "OcuPilot.Test.ProviderStub"
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "sslConfiguration"), ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG, "the request carries the installer-created configuration name, never DefaultSSL")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "sslCheckServerIdentity"), 1, "with server-identity checking on")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "timeout"), 45, "the stored timeout, not a class parameter")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyServer"), "proxy.probe.invalid", "the stored proxy host")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyPort"), 3128, "its port")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyHttps"), 1, "whether the proxy leg is encrypted")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyTunnel"), 1, "and whether it is tunnelled")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "and the stored settings are removed again")
}

/// <p>A marked-local plain-HTTP endpoint on a row that allows it is called, and the request carries
/// <b>no</b> TLS configuration: there is no session to negotiate, and a configuration name on such
/// a request would read as one that was applied.</p>
Method TestAPlainHttpCallAppliesNoTls()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Draft("probe-local", "http://127.0.0.1:11434/v1/messages", 1, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the marked-local plain-HTTP call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and reaches the transport")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("sslConfiguration"), "", "with no TLS configuration on the request")
}

/// <p><b>AC3's refusal half</b> -- an HTTPS call whose named TLS configuration is absent is refused
/// with <code>PROVIDER.TLS</code>, naming the configuration, and <b>never</b> falls back to another
/// one or proceeds unencrypted.</p>
Method TestAMissingTlsConfigurationRefusesTheHttpsCall()
{
    Do $ClassMethod(..#PORT, "SetSslState", "missing")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Draft("probe-local", "https://api.anthropic.com/v1/messages", 0, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERTLS, "an absent TLS configuration")
    Do $$$AssertEquals(tHttpStatus, 503, "answered 503")
    Do $$$AssertTrue(tFault.reason [ ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG, "naming the configuration an administrator has to create: " _ tFault.reason)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no socket was opened")
}

/// <p>A plain-HTTP marked-local call is <b>not</b> refused for a missing TLS configuration: there
/// is no TLS on that path to be missing.</p>
Method TestAMissingTlsConfigurationDoesNotRefuseAPlainHttpCall()
{
    Do $ClassMethod(..#PORT, "SetSslState", "missing")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Draft("probe-local", "http://127.0.0.1:11434/v1/messages", 1, .tValues)
    Set tSC = ..CallDraft(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the plain-HTTP call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and reaches the transport")
}

/// <p><b>A definition the write path disabled is not called.</b> Story 3.1 clears
/// <code>Enabled</code> whenever a security field changes, and this port is the only place that
/// decision is ever spent: without the test, an endpoint or credential reference edited after the
/// last verification would be called on the next turn regardless.</p>
/// <p>The draft entry deliberately does not make the test -- testing a disabled definition is how
/// an operator re-enables it -- so the same values through <method>InvokeDraft</method> reach the
/// transport, which is what tells the two entries apart rather than leaving the flag untested on
/// one of them.</p>
/// <p>Mutation: delete the <code>enabled</code> test in
/// <method>OcuPilot.Port.ProviderPort.Invoke</method> -- the first leg goes red, reporting a call
/// that reached the transport.</p>
Method TestADisabledDefinitionIsNotCalledByTheStoredEntry()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentPortDisabled"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tRow.Enabled = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a disabled definition is created")
    Set tId = tRow.%Id()
    Set tRow = ""
    Do ..Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "a disabled definition through the stored entry")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no socket was opened")

    Do ..Draft("probe-local", "https://api.anthropic.com/v1/messages", 0, .tValues)
    Set tDraftSC = ..CallDraft(.tValues, .tDraftResponse, .tDraftStatus, .tDraftFault)
    Do $$$AssertStatusOK(tDraftSC, "while the same values through the draft entry return $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and do reach the transport, which is how an operator re-verifies one")
}

/// <p><b>AC4's call-time half over a stored definition</b>, which is the rebinding scenario as the
/// matrix frames it: the endpoint was accepted and saved, and the address behind it is now one
/// OcuPilot will not call.</p>
/// <p>The stored entry rather than the draft one, because the matrix's row is about a definition
/// that passed the write gate -- the state layer is what writes the row here, so the value is
/// stored exactly as an accepted one would be.</p>
Method TestAStoredDefinitionIsJudgedAgainAtCallTime()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentPortRebound"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://169.254.169.254/v1"
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tRow.Enabled = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a stored definition whose endpoint now resolves link-local is created")
    Set tId = tRow.%Id()
    Set tRow = ""
    Do ..Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, "a stored endpoint the address policy now refuses")
    Do $$$AssertEquals(tHttpStatus, 502, "answered as a gateway failure")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no socket was opened")
}

/// <p>The stored entry reads its definition from the protected database and calls with what it
/// found -- the path Epic 4's turn takes.</p>
Method TestTheStoredEntryCallsWithTheStoredDefinition()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentPortStored"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 1234
    Set tRow.Enabled = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a stored definition is created")
    Set tId = tRow.%Id()
    Set tRow = ""
    Do ..Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the stored call returns $$$OK")
    Do $$$AssertEquals(tResponse.StopReason, "end_turn", "and reports the reply")
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body"))
    Do $$$AssertTrue($IsObject(tBody), "the recorded body parses")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(+tBody."max_tokens", 1234, "carrying the stored definition's own tuning rather than a default")
    Do $$$AssertEquals(tBody.model, "probe-local-model-1", "and its model")
}

}
