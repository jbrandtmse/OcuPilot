/// <p>Story 10.2's OpenAI family: the shipped <code>openai</code> catalog row driven through
/// <method>OcuPilot.Port.ProviderPort.Invoke</method> in its own dialect, the shared retry, the
/// no-retry-after-a-raise rule and the vendor-text mapping on that family, and the key-shape gate
/// a row declaring no prefix falls back to.</p>
/// <p><b>Needs nothing of the environment but a writable protected database and a resolver that
/// answers the shipped endpoint's host.</b> No socket is opened: the shipped adapter's transport,
/// sleep and clock are replaced by <class>OcuPilot.Test.OpenAIStub</class>, which the shipped row
/// is re-adapted to by <class>OcuPilot.Test.CatalogProbeShipped</class>. Every other column of
/// that row -- its endpoint, its model, its tuning, its key prefix -- is the shipped one. The one
/// stored definition each method needs is created and removed here.</p>
Class OcuPilot.Test.OpenAIAdapter Extends %UnitTest.TestCase
{

/// <p>The port entry, with its switched catalog, gate, credential class and TLS answer.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>The catalog that re-adapts the two shipped non-canonical rows to their stubs.</p>
Parameter CATALOG = "OcuPilot.Test.CatalogProbeShipped";

/// <p>The stub the <code>openai</code> row answers under that catalog.</p>
Parameter STUB = "OcuPilot.Test.OpenAIStub";

/// <p>The same catalog with this family's key drifted, so its fail-closed arm has a caller.</p>
Parameter DRIFTCATALOG = "OcuPilot.Test.CatalogProbeDrift";

/// <p>The shipped provider key under test.</p>
Parameter PROVIDERKEY = "openai";

/// <p>The credential the shape gate accepts: non-empty and free of whitespace, which is all a row
/// declaring no prefix can require.</p>
Parameter PROBEKEY = "probeopenaikeyabcdefghijklmn";

/// <p>A credential of the shape the gate exists to catch -- the paste that brought a space with
/// it.</p>
Parameter PASTEDKEY = "probeopenaikey abcdefghijklmn";

/// <p>A key prefix no catalog row declares, for the arm of the shared gate no row reaches.</p>
Parameter PROBEKEYPREFIX = "sk-probe-";

/// <p>A credential carrying <parameter>PROBEKEYPREFIX</parameter>, so the prefix arm accepts
/// it.</p>
Parameter PREFIXEDKEY = "sk-probe-abcdefghijklmn";

/// <p>The wire name of the one tool every request leg advertises.</p>
Parameter TOOLNAME = "logs_errors_read";

/// <p>The system prompt every request leg sends.</p>
Parameter SYSTEMPROMPT = "you are a probe";

/// <p>A Chat Completions reply carrying text, one tool call whose arguments are a JSON string, a
/// stop reason and both usage figures.</p>
Parameter REPLY = "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""looking"",""tool_calls"":[{""id"":""call1"",""type"":""function"",""function"":{""name"":""logs_errors_read"",""arguments"":""{\""maxRows\"":5}""}}]},""finish_reason"":""tool_calls""}],""usage"":{""prompt_tokens"":31,""completion_tokens"":7}}";

/// <p>The error body this family refuses with, whose <code>error.message</code> is the only part
/// that may reach <code>detail.providerText</code>.</p>
Parameter ERRORBODY = "{""error"":{""type"":""invalid_request_error"",""message"":""the vendor's own words"",""code"":""model_not_found""}}";

/// <p>Arm a clean port over the re-adapting catalog, a clean stub and a resolvable
/// credential.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetCatalogClass", ..#CATALOG)
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit $$$OK
}

/// <p>Leave no switch and no stored row for the next method, or the next class, to read.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Set tRemoved = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tRemoved, "every probe definition this method created is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The <b>shipped</b> row for this family, read through the unsubclassed catalog so every
/// value below it is the one a turn would use.</p>
Method ShippedRow() As %DynamicObject
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row(..#PROVIDERKEY, .tRow), 1, "the shipped " _ ..#PROVIDERKEY _ " row is readable")
    Quit tRow
}

/// <p>Create one enabled probe definition on this family's shipped row, taking its model, tuning
/// and credential reference from <var>pRow</var> so no value here is spelled twice, and hand back
/// its id.</p>
/// <p><b>Its <code>EndpointUrl</code> is left empty</b>, so the endpoint the call goes to is the
/// row's own <code>defaultEndpoint</code>, exactly as
/// <method>OcuPilot.Port.ProviderPort.EndpointOf</method> resolves it. Written straight through
/// the state class, as <method>OcuPilot.Test.AgentFixture.CreateDefinition</method> does, because
/// only Story 3.4's Test connection sets the verification flag an enable needs.</p>
Method StoredDefinition(pRow As %DynamicObject, pModel As %String = "") As %String
{
    Set tId = ""
    Try {
        Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
        Set tRow.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Shipped" _ ..#PROVIDERKEY
        Set tRow.Provider = ..#PROVIDERKEY
        Set tRow.Model = $Select(pModel '= "": pModel, 1: pRow.defaultModel)
        Set tRow.EndpointUrl = ""
        Set tRow.CredType = "env"
        Set tRow.EnvVarName = pRow.defaultEnvVarName
        Set tRow.CredentialName = ""
        Set tRow.MaxTokens = +pRow.canonicalMaxTokens
        Set tRow.Temperature = pRow.canonicalTemperature
        Set tRow.Enabled = 1
        Set tRow.ConnectionVerified = 1
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
        Do $$$AssertStatusOK(tSC, "the probe definition on the shipped row is stored")
        If $$$ISERR(tSC) Quit
        Set tId = tRow.%Id()
        Set tRow = ""
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "storing the probe definition did not raise")
    }
    Quit tId
}

/// <p>The canonical history every request leg translates: a plain user message, an assistant echo
/// carrying text and two calls to one tool, and a user message carrying both results.</p>
ClassMethod Canonical(Output pMessages)
{
    Kill pMessages
    Set pMessages = 3
    Set pMessages(1, "role") = "user"
    Set pMessages(1, "content") = "what is on this screen"
    Set pMessages(2, "role") = "assistant"
    Set pMessages(2, "blocks") = "[{""type"":""text"",""text"":""checking""},{""type"":""tool_use"",""id"":""call1"",""name"":""" _ ..#TOOLNAME _ """,""input"":{""maxRows"":5}}]"
    Set pMessages(3, "role") = "user"
    Set pMessages(3, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""call1"",""content"":""first""}]"
}

/// <p>The canonical tool array every request leg advertises.</p>
ClassMethod Tools(Output pTools)
{
    Kill pTools
    Set pTools = 1
    Set pTools(1, "name") = ..#TOOLNAME
    Set pTools(1, "description") = "read the error log"
    Set pTools(1, "inputSchema") = "{""type"":""object"",""properties"":{""maxRows"":{""type"":""integer"",""description"":""how many""}},""required"":[],""additionalProperties"":false}"
}

/// <p>The body the stub recorded on call <var>pCall</var>, parsed.</p>
ClassMethod RecordedBody(pCall As %Integer = 1) As %DynamicObject
{
    Set tBody = ""
    Try {
        Set tText = ##class(OcuPilot.Test.ProviderStub).Recorded("body", pCall)
        If tText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tText, "I", "UTF8"))
        If $IsObject(tParsed) Set tBody = tParsed
    } Catch ex {
        Set tBody = ""
    }
    Quit tBody
}

/// <p>An adapter instance for a direct call, so the retry and refusal legs run against settings
/// this class states rather than against whatever the instance has stored.</p>
ClassMethod Adapter() As OcuPilot.Kernel.Provider.Base
{
    Set tAdapter = $ClassMethod(..#STUB, "%New")
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Quit tAdapter
}

/// <p>The value array a direct call reads, taking every provider fact from <var>pRow</var> --
/// including the two columns the port would otherwise copy in, <code>keyPrefix</code> and
/// <code>authVersion</code>.</p>
ClassMethod DirectValues(pRow As %DynamicObject, Output pValues)
{
    Kill pValues
    Set pValues("provider") = ..#PROVIDERKEY
    Set pValues("model") = pRow.defaultModel
    Set pValues("endpointUrl") = pRow.defaultEndpoint
    Set pValues("markedLocal") = 0
    Set pValues("credType") = "env"
    Set pValues("envVarName") = pRow.defaultEnvVarName
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = +pRow.canonicalMaxTokens
    Set pValues("temperature") = pRow.canonicalTemperature
    Set pValues("keyPrefix") = pRow.keyPrefix
    Set pValues("authVersion") = pRow.authVersion
}

/// <p><var>pFault</var>'s machine code, or <code>""</code> when the call produced no fault. Read
/// through here so a call that unexpectedly succeeded reports a failed assertion rather than
/// raising <code>&lt;INVALID OREF&gt;</code>.</p>
ClassMethod FaultCode(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.code
}

/// <p><var>pFault</var>'s whole rendered envelope, or <code>""</code>.</p>
ClassMethod Rendered(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.%ToJSON()
}

/// <p>AC1 -- a stored definition on the shipped <code>openai</code> row reaches that family's own
/// dialect: the transport seam is entered once with the row's own endpoint, the credential travels
/// on this family's header and no other, the body is a Chat Completions body built from the row's
/// own model and tuning, and the reply comes back as canonical text and tool-use blocks.</p>
/// <p>mutation: point <parameter>OcuPilot.Test.CatalogProbeShipped.OPENAISTUB</parameter> at
/// <class>OcuPilot.Test.ProviderStub</class>, the canonical family's stub, so the row this call
/// resolves names a canonical adapter -- red on the recorded header name and on the
/// <code>messages</code> / <code>max_completion_tokens</code> body assertions. Mutating the
/// shipped row's own column cannot bite: that catalog re-adapts the row to a stub regardless.</p>
Method TestAShippedOpenAiRowIsCalledInItsOwnDialect()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tId = ..StoredDefinition(tRow)
    If tId = "" Quit
    Do ..Canonical(.tMessages)
    Do ..Tools(.tTools)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, ..#SYSTEMPROMPT, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tFault), "", "with no fault: " _ ..Rendered(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), $Parameter(..#STUB, "STUBIDENTITY"), "the call was served by the class the row's adapterClass column named")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the POST seam was entered exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), tRow.defaultEndpoint, "and it was entered with the row's own endpoint")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "Authorization", "the credential travels on this family's header and neither of the canonical family's")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("contentType", 1), "application/json", "with a JSON content type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("sslCheckServerIdentity", 1), 1, "and the shared request configuration: the certificate identity is checked")

    Set tBody = ..RecordedBody(1)
    Do $$$AssertTrue($IsObject(tBody), "the outbound body was recorded and is JSON")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.model, tRow.defaultModel, "the body carries the row's own default model, which no code here spells")
    Do $$$AssertEquals(tBody.%GetTypeOf("max_completion_tokens"), "number", "the token cap is a JSON number")
    Do $$$AssertEquals(+tBody."max_completion_tokens", +tRow.canonicalMaxTokens, "carrying the row's own canonical maximum")
    Do $$$AssertEquals(tBody.%GetTypeOf("max_tokens"), "unassigned", "and the deprecated spelling is not sent at all")
    Do $$$AssertEquals(tBody.%GetTypeOf("temperature"), "unassigned", "the row declares no canonical temperature, so none is sent and the provider's default applies")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "messages.0.role"), "system", "the messages are this dialect's own, led by a system message")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "messages.2.tool_calls.0.id"), "call1", "with the assistant echo's tool calls under this dialect's key")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "messages.3.tool_call_id"), "call1", "and each result as its own tool message")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "tools.0.function.name"), ..#TOOLNAME, "the tools are declared where this dialect declares them")
    Do $$$AssertEquals(tBody.%GetTypeOf("contents"), "unassigned", "and no field of another dialect appears")

    Do $$$AssertEquals(tResponse.Text, "looking", "the reply's text becomes canonical text")
    Do $$$AssertEquals(tResponse.StopReason, "tool_use", "its stop reason becomes the canonical one")
    Do $$$AssertTrue(tResponse.ToolCallsJson [ """tool_use""", "and its tool calls become canonical tool_use blocks: " _ tResponse.ToolCallsJson)
    Do $$$AssertEquals(tResponse.RequestTokens, 31, "with this dialect's own usage field names read")
    Do $$$AssertEquals(tResponse.ResponseTokens, 7, "in both directions")
}

/// <p>The re-adapting catalog <b>fails closed</b>: a shipped key it cannot match leaves
/// <method>OcuPilot.Test.CatalogProbeShipped.Table</method> answering an error
/// <class>%Status</class> and no table, so the port resolves no row and refuses the call. The
/// direction is what matters -- the alternative to a refusal is a row still naming the shipped
/// adapter, and a real POST carrying the probe credential to the vendor.</p>
/// <p><b>The catalog is asserted refused before the call is made</b>, not inferred from what the
/// call did afterwards.</p>
/// <p>mutation: delete the guard's refusal in
/// <method>OcuPilot.Test.CatalogProbeShipped.Table</method> so it answers its table whatever
/// matched -- red here on the error-status, empty-table and refusal assertions, while
/// <method>TestAShippedOpenAiRowIsCalledInItsOwnDialect</method> stays green. That test cannot
/// bite in its place: with the guard gone its drifted row keeps the shipped
/// <code>adapterClass</code>, so it reddens on the served-by assertion either way and pins the
/// re-adaptation rather than the refusal.</p>
Method TestADriftedShippedKeyLeavesTheReAdaptingCatalogAnsweringNothing()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Set tId = ..StoredDefinition(tRow)
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do $ClassMethod(..#PORT, "SetCatalogClass", ..#DRIFTCATALOG)
    Set tTableSC = $ClassMethod(..#DRIFTCATALOG, "Table", .tTable)
    Do $$$AssertStatusNotOK(tTableSC, "a shipped key the table does not declare makes the re-adapting catalog answer an error status")
    Do $$$AssertTrue('$IsObject(tTable), "and no table at all, so no row it could not re-adapt is handed out")
    Do ..Canonical(.tMessages)
    Do ..Tools(.tTools)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, ..#SYSTEMPROMPT, .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port still answers $$$OK")
    Do $$$AssertEquals(..FaultCode(tFault), "PROVIDER.UNCONFIGURED", "and refuses the turn, because no row resolved and so no adapter of any kind was constructed: " _ ..Rendered(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "the stand-in transport was never entered either")
}

/// <p>AC4 -- the shared rules hold on this family exactly as they do on the canonical one: a
/// retryable status is tried again after the provider's own honoured hint, a call that raised
/// mid-flight is never tried again, a refusal carries the vendor's message in
/// <code>detail.providerText</code> and nothing else of the body, and a retryable status on every
/// attempt ends the call <code>PROVIDER.UNAVAILABLE</code>. Every leg answers
/// <code>$$$OK</code>.</p>
/// <p>Driven against the adapter directly so the attempt ladder is the one this method states
/// rather than whatever the instance has stored.</p>
/// <p>mutation: have <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s attempt
/// <code>Catch</code> record a retryable status rather than a raise -- red on the one-attempt
/// assertion. Removing the mid-flight <code>Quit</code> alone cannot bite: the
/// <code>$$$ISERR(tIssueSC)</code> exit below it ends the loop on the same attempt.</p>
Method TestTheSharedRetryAndRefusalRulesHold()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ..DirectValues(tRow, .tValues)
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)

    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 3)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "", 5)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tRetried = ..Adapter()
    Do $$$AssertStatusOK(tRetried.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the retried call returns $$$OK")
    Set tRetried = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "one retry and no more")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), 5, "at the shared delay, which honours the provider's own hint over the backoff")
    Do $$$AssertEquals(tResponse.StopReason, "tool_use", "and the second attempt's reply is the answer")
    Do $$$AssertEquals(..FaultCode(tFault), "", "with no fault: " _ ..Rendered(tFault))

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tRaised = ..Adapter()
    Do $$$AssertStatusOK(tRaised.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tRaisedResponse, .tRaisedFault, .tRaisedStatus), "a call that raised mid-flight still returns $$$OK")
    Set tRaised = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and is never tried again, however many attempts the settings allow")
    Do $$$AssertEquals(..FaultCode(tRaisedFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "reporting PROVIDER.TRANSPORT")
    Do $$$AssertEquals(tRaisedResponse.StopReason, "error", "through the stop reason")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(400, ..#ERRORBODY)
    Set tRefused = ..Adapter()
    Do $$$AssertStatusOK(tRefused.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tRefusedResponse, .tRefusedFault, .tRefusedStatus), "a refused call returns $$$OK")
    Set tRefused = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "a determinate refusal is not retried")
    Do $$$AssertEquals(..FaultCode(tRefusedFault), ##class(OcuPilot.Api.Error).#PROVIDERREFUSED, "reporting PROVIDER.REFUSED")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tRefusedFault, "detail.providerText"), "the vendor's own words", "with this family's error.message as the provider text")
    Do $$$AssertEquals(..Rendered(tRefusedFault) [ "invalid_request_error", 0, "and no other part of the body: " _ ..Rendered(tRefusedFault))
    Do $$$AssertEquals(..Rendered(tRefusedFault) [ ..#PROBEKEY, 0, "and no part of the credential either")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(503, "")
    Set tExhausted = ..Adapter()
    Do $$$AssertStatusOK(tExhausted.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tExhaustedResponse, .tExhaustedFault, .tExhaustedStatus), "a call whose every attempt was refused returns $$$OK")
    Set tExhausted = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 3, "every attempt the settings allow was made")
    Do $$$AssertEquals(..FaultCode(tExhaustedFault), ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE, "and the call ends PROVIDER.UNAVAILABLE")
}

/// <p>The matrix's key-shape row on a family whose row declares no prefix: a credential carrying
/// whitespace is refused <code>PROVIDER.KEYSHAPE</code> with no socket opened, and the reason names
/// no key material. The same credential without the space is accepted, so the refusal is about the
/// shape and not about the value.</p>
/// <p>mutation: have <method>OcuPilot.Kernel.Provider.Base.KeyShapeAccepted</method> answer 1 for
/// an empty prefix -- red on the expected code and on the zero-calls assertion.</p>
Method TestAPastedKeyIsRefusedWithoutASocket()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.keyPrefix, "", "the shipped row declares no key prefix, so the gate has no grammar to check")
    Do ..DirectValues(tRow, .tValues)
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 1)

    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PASTEDKEY)
    Set tPasted = ..Adapter()
    Do $$$AssertStatusOK(tPasted.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the refused call returns $$$OK")
    Set tPasted = ""
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE, "a credential carrying whitespace is refused PROVIDER.KEYSHAPE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "before any socket is opened")
    Do $$$AssertEquals(..Rendered(tFault) [ ..#PASTEDKEY, 0, "and the reason names no key material: " _ ..Rendered(tFault))

    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tSound = ..Adapter()
    Do $$$AssertStatusOK(tSound.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tSoundResponse, .tSoundFault, .tSoundStatus), "the same credential without the space returns $$$OK")
    Set tSound = ""
    Do $$$AssertEquals(..FaultCode(tSoundFault), "", "and is accepted: " _ ..Rendered(tSoundFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "reaching the transport")
}

/// <p>The prefix arm of the shared key-shape gate, which no catalog row reaches: both rows that
/// delegate to it declare no prefix, and the family whose row declares one keeps its own test. It
/// is driven here because a row pairing a prefix with this gate is what Story 10.3 adds, and an
/// arm with no case either way is not enforced, it is merely written.</p>
/// <p>Both terms are asserted: a key of another shape is refused, and so is one carrying the right
/// prefix and a carriage return, which <method>%Net.HttpRequest.SetHeader</method> would otherwise
/// write onto the header verbatim.</p>
/// <p>mutation: have <method>OcuPilot.Kernel.Provider.Base.KeyShapeAccepted</method>'s prefix arm
/// answer 1 -- red on the wrong-prefix leg's expected code and on its zero-calls assertion.</p>
Method TestTheKeyShapeGatesPrefixArmRefusesAKeyOfAnotherShape()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ..DirectValues(tRow, .tValues)
    Set tValues("keyPrefix") = ..#PROBEKEYPREFIX
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 1)

    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Set tWrong = ..Adapter()
    Do $$$AssertStatusOK(tWrong.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the refused call returns $$$OK")
    Set tWrong = ""
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE, "a key that does not carry the row's prefix is refused PROVIDER.KEYSHAPE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "before any socket is opened")
    Do $$$AssertEquals(..Rendered(tFault) [ ..#PROBEKEY, 0, "and the reason names no key material: " _ ..Rendered(tFault))
    Do $$$AssertEquals(..Rendered(tFault) [ ..#PROBEKEYPREFIX, 1, "only the prefix the row declares, which is a table entry")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PREFIXEDKEY _ $Char(13))
    Set tRaw = ..Adapter()
    Do $$$AssertStatusOK(tRaw.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tRawResponse, .tRawFault, .tRawStatus), "the second refused call returns $$$OK")
    Set tRaw = ""
    Do $$$AssertEquals(..FaultCode(tRawFault), ##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE, "the right prefix does not license a control character in the value")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and that call opens no socket either")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PREFIXEDKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tSound = ..Adapter()
    Do $$$AssertStatusOK(tSound.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tSoundResponse, .tSoundFault, .tSoundStatus), "a key of the declared shape returns $$$OK")
    Set tSound = ""
    Do $$$AssertEquals(..FaultCode(tSoundFault), "", "and is accepted: " _ ..Rendered(tSoundFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "reaching the transport, so the arm is not simply refusing everything")
}

/// <p>The intent's "no empty auth header" on this family: a call whose key source carries no key
/// reaches the provider with <b>no</b> authentication header, rather than with an empty one the
/// vendor reads as a malformed credential.</p>
/// <p>mutation: drop the <code>If ..ApiKey = "" Quit</code> guard from
/// <method>OcuPilot.Kernel.Provider.OpenAI.ApplyAuth</method> -- red on the recorded header names,
/// which then carry this family's header with the scheme and nothing after it.</p>
Method TestACallWithNoKeySendsNoAuthenticationHeader()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ..DirectValues(tRow, .tValues)
    Set tValues("keySource") = $Parameter("OcuPilot.Kernel.Provider.Base", "KEYSOURCENONE")
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)

    Set tNoKey = ..Adapter()
    Do $$$AssertStatusOK(tNoKey.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the keyless call returns $$$OK")
    Set tNoKey = ""
    Do $$$AssertEquals(..FaultCode(tFault), "", "with no fault: " _ ..Rendered(tFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the transport was entered once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "", "carrying no authentication header at all")
}

}
