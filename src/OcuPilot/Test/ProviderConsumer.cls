/// <p><b>AC7, the Integration acceptance criterion.</b> A consumer holding only
/// <class>OcuPilot.Port.ProviderPort</class>'s public contract -- as Epic 4's turn and Story 3.4's
/// Test connection will -- observes a turn error it can render, and no exception, for every class
/// of provider failure.</p>
/// <p><b>What "only the public contract" means here, precisely.</b> Every assertion below reads
/// three things and nothing else: the <class>%Status</class> the port returned, the response's
/// <property>StopReason</property>, and the fault's <code>code</code>, <code>reason</code> and
/// <code>error</code>. No adapter property, no stub recording, no catalog row and no internal
/// method of the provider layer is inspected. Two of the four failures are refusals the port makes
/// before a transport exists to arrange anything on; the transport failure and the answered-turn
/// control reach past the port to queue a raise and a reply, because neither can be arranged from
/// outside the transport. <b>Arrangement is not assertion:</b> what this class reaches past the
/// port to <i>set up</i> is named here, and what it <i>asserts</i> is the port's three outputs and
/// nothing else, which is the property that makes it a consumer test.</p>
/// <p><b>Story 3.3's AC6 is the fifth method</b>,
/// <method>TestAStoredKeyServesATurnAndItsRemovalDisablesTheDefinition</method>: the same contract
/// asked of the credentials rung end to end -- a key stored, a turn served with it, the entry
/// removed, and the turn after it a renderable refusal leaving the definition disabled. It arranges
/// through <method>OcuPilot.Kernel.Secret.Ladder.Store</method> and asserts the port's outputs plus
/// the definition's own two flags.</p>
/// <p><method>OnBeforeOneTest</method> also sets the probe port's four switches, for the same
/// reason every class in this suite does: so no method depends on what the last one left behind.</p>
/// <p><b>Why a separate class rather than more methods on
/// <class>OcuPilot.Test.ProviderPort</class>.</b> That class asserts on what the port did inside --
/// which adapter served the call, what the request carried, how many times the seam was entered.
/// Those assertions would pass for a port whose contract no caller could actually use. This one
/// asserts only what a caller can see, so it fails if the contract is the thing that broke.</p>
Class OcuPilot.Test.ProviderConsumer Extends %UnitTest.TestCase
{

/// <p>The port the consumer calls. The probe subclass, because the shipped catalog's one row
/// points at the real Anthropic adapter and a consumer test must open no socket; every method of
/// the port itself is the shipped one.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>A credential of the shape the row's prefix requires, so the key-shape gate is not what any
/// method below is measuring.</p>
Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>Arm a clean port before each method.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit $$$OK
}

/// <p>The credential entry <method>TestAStoredKeyServesATurnAndItsRemovalDisablesTheDefinition</method>
/// writes and removes.</p>
Parameter PROBECREDENTIAL = "OcuPilotProbeCredential";

/// <p>A fabricated key of the shape the <code>probe-local</code> row's prefix requires. It is not a
/// credential and reaches no provider.</p>
Parameter STOREDKEY = "probe-local-storedbyocupilot";

/// <p>Leave no switch set, no definition and no credential entry for the next class to
/// inherit.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "no credential entry this class created survives it")
    Set tRemoved = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tRemoved, "every probe definition this class created is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The definition a consumer hands the port.</p>
ClassMethod Definition(pProvider As %String, pEndpoint As %String, Output pValues)
{
    Kill pValues
    Set pValues("provider") = pProvider
    Set pValues("model") = "probe-local-model-1"
    Set pValues("endpointUrl") = pEndpoint
    Set pValues("markedLocal") = 0
    Set pValues("credType") = "env"
    Set pValues("envVarName") = "OCUPILOT_PROBE_LOCAL_KEY"
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = 4000
    Set pValues("temperature") = 0
}

/// <p>Ask the port for one turn, the way a consumer would.</p>
Method Turn(ByRef pValues, Output pResponse, Output pHttpStatus, Output pFault) As %Status
{
    Set tMessages = 1
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "what is on this screen"
    Quit $ClassMethod(..#PORT, "InvokeDraft", .pValues, .tMessages, .tTools, "", .pResponse, .pHttpStatus, .pFault)
}

/// <p>Everything a consumer is entitled to assume about a failed turn: the call returned
/// <code>$$$OK</code>, nothing was raised, the response says the turn failed, and the fault is a
/// renderable envelope carrying a <code>PROVIDER.*</code> code from
/// <class>OcuPilot.Api.Error</class>'s own vocabulary.</p>
Method AssertRenderableTurnError(pSC As %Status, pResponse As OcuPilot.Kernel.Provider.Response, pHttpStatus As %Integer, pFault As %DynamicObject, pWhat As %String)
{
    Do $$$AssertStatusOK(pSC, pWhat _ ": the port returns $$$OK, so a consumer never has a status to interpret")
    Do $$$AssertTrue($IsObject(pResponse), pWhat _ ": a response object comes back on the failure path too")
    If '$IsObject(pResponse) Quit
    Do $$$AssertEquals(pResponse.StopReason, "error", pWhat _ ": whose stop reason is the one failure signal")
    Do $$$AssertTrue($IsObject(pFault), pWhat _ ": with a fault to render")
    If '$IsObject(pFault) Quit
    Do $$$AssertNotEquals(pFault.reason, "", pWhat _ ": carrying a reason a screen can show")
    Do $$$AssertNotEquals(pFault.error, "", pWhat _ ": a slug")
    Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(pFault.code), pWhat _ ": and a well-formed machine code a tool result can render: " _ pFault.code)
    Do $$$AssertEquals($Piece(pFault.code, ".", 1), "PROVIDER", pWhat _ ": from the provider vocabulary: " _ pFault.code)
    Do $$$AssertTrue(+pHttpStatus >= 400, pWhat _ ": and an HTTP status a route can answer with: " _ pHttpStatus)
}

/// <p>The control: a turn the provider answers is a turn a consumer can render as a reply.
/// Without it every failure assertion below would be satisfied by a port that failed
/// everything.</p>
Method TestAnAnsweredTurnIsNotAnError()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":2}}")
    Do ..Definition("probe-local", "https://api.anthropic.com/v1/messages", .tValues)
    Set tSC = ..Turn(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "an answered turn returns $$$OK")
    Do $$$AssertEquals(tResponse.StopReason, "end_turn", "and a stop reason that is not the failure signal")
    Do $$$AssertEquals(tResponse.Text, "hello", "with the reply a consumer renders")
    Do $$$AssertTrue('$IsObject(tFault), "and no fault at all")
}

/// <p>AC7 -- failure class one, a configuration the port cannot serve: the provider names no
/// adapter this instance holds.</p>
Method TestAnUnservableDefinitionIsARenderableTurnError()
{
    Do ..Definition("no-such-provider", "https://api.anthropic.com/v1/messages", .tValues)
    Set tSC = ..Turn(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertRenderableTurnError(tSC, tResponse, tHttpStatus, tFault, "a definition the port cannot serve")
}

/// <p>AC7 -- failure class two, an endpoint the address policy refuses. Nothing is arranged: the
/// port refuses before a transport exists to arrange anything on.</p>
Method TestARefusedEndpointIsARenderableTurnError()
{
    Do ..Definition("probe-local", "https://169.254.169.254/v1", .tValues)
    Set tSC = ..Turn(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertRenderableTurnError(tSC, tResponse, tHttpStatus, tFault, "an endpoint the address policy refuses")
}

/// <p>AC7 -- failure class three, a credential that does not resolve. The reason names the
/// reference; a consumer renders it and an operator can act on it.</p>
Method TestAnUnresolvedCredentialIsARenderableTurnError()
{
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ..Definition("probe-local", "https://api.anthropic.com/v1/messages", .tValues)
    Set tSC = ..Turn(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertRenderableTurnError(tSC, tResponse, tHttpStatus, tFault, "a credential that does not resolve")
}

/// <p>AC7 -- failure class four, the transport raising mid-flight. <b>The one thing this class
/// arranges</b>, because a transport failure cannot be arranged from outside the transport; the
/// assertions are still the port's own outputs alone.</p>
/// <p>Mutation: make the port return the error <class>%Status</class> instead of
/// <code>$$$OK</code> plus a fault -- every method here goes red, since a consumer asserts on the
/// envelope and never on a status.</p>
Method TestATransportFailureIsARenderableTurnError()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
    Do ..Definition("probe-local", "https://api.anthropic.com/v1/messages", .tValues)
    Set tSC = ..Turn(.tValues, .tResponse, .tHttpStatus, .tFault)
    Do ..AssertRenderableTurnError(tSC, tResponse, tHttpStatus, tFault, "a transport that raised mid-flight")
}

/// <p><b>AC6, the Integration acceptance criterion</b> -- a key put into the credential store is
/// what serves the next turn, and removing the entry behind the reference turns the turn after it
/// into a renderable refusal that leaves the definition disabled.</p>
/// <p><b>What is arranged and what is asserted.</b> Arranged: a stored definition on the
/// credentials rung, a key put there by <method>OcuPilot.Kernel.Secret.Ladder.Store</method> -- the
/// same call this story's endpoint makes -- and, afterwards, the entry's removal. Asserted: the
/// port's own three outputs, plus the definition's two flags, which are OcuPilot's own state and not
/// the provider or secret layers' internals. No adapter property, no stub recording and no ladder
/// internal is read.</p>
/// <p><b>The shipped ladder resolves it</b>: the port's credential seam is set to <code>""</code>,
/// which falls through to <parameter>OcuPilot.Port.ProviderPort.SECRETCLASS</parameter>. That is
/// what makes "served with the stored credential" a claim about the rung this story added rather
/// than about the probe.</p>
/// <p>That the first turn was served <i>with the stored key</i> is observable from the port alone:
/// a reference resolving to nothing answers <code>PROVIDER.CREDENTIAL</code> and a key of the wrong
/// shape answers <code>PROVIDER.KEYSHAPE</code>, so a stop reason that is not the failure signal is
/// only reachable with the stored value in hand.</p>
Method TestAStoredKeyServesATurnAndItsRemovalDisablesTheDefinition()
{
    If '##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable() {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#PROBECREDENTIAL), "", "the credentials rung is not reachable from " _ $Namespace _ ", so this leg is skipped and nothing was written")
        Quit
    }
    Do $ClassMethod(..#PORT, "SetSecretClass", "")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#PROBECREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#STOREDKEY), "apiKey"), "the key is put into the credential store")

    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentConsumerStored"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "creds"
    Set tRow.CredentialName = ..#PROBECREDENTIAL
    Set tRow.MaxTokens = 4000
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a definition on the credentials rung is stored")
    Set tId = tRow.%Id()
    Set tRow = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "and enabled and verified, as Test connection would leave it")

    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":2}}")
    Set tMessages = 1
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "what is on this screen"
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the turn against the stored definition returns $$$OK")
    Do $$$AssertEquals(tResponse.StopReason, "end_turn", "and is served, which is only reachable with the stored credential in hand")
    Do $$$AssertEquals(tResponse.Text, "hello", "with the reply a consumer renders")
    Do $$$AssertTrue('$IsObject(tFault), "and no fault at all")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":2}}")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "the entry behind the reference is then removed")
    Set tGoneSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tGoneResponse, .tGoneStatus, .tGoneFault)
    Do ..AssertRenderableTurnError(tGoneSC, tGoneResponse, tGoneStatus, tGoneFault, "a reference whose entry has been removed")
    Do $$$AssertEquals(tGoneFault.code, ##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL, "naming the reference rather than any other provider failure: " _ tGoneFault.%ToJSON())
    Do $$$AssertTrue(tGoneFault.reason [ ..#PROBECREDENTIAL, "and stating which reference could not be resolved: " _ tGoneFault.reason)
    Do $$$AssertEquals(tGoneFault.%ToJSON() [ ..#STOREDKEY, 0, "while carrying no part of the value that used to be there")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tAfter), "the definition reads back")
    Do $$$AssertEquals(tAfter.Enabled, 0, "left disabled by the turn that could not resolve its credential")
    Do $$$AssertEquals(tAfter.ConnectionVerified, 0, "and unverified")
    Set tAfter = ""
}

}
