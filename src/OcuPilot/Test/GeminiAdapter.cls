/// <p>Story 10.2's Gemini family: the shipped <code>gemini</code> catalog row driven through
/// <method>OcuPilot.Port.ProviderPort.Invoke</method> in its own dialect, the model-in-path
/// substitution and the refusal of a model that would not survive it, and the shared retry,
/// no-retry-after-a-raise and vendor-text rules on that family.</p>
/// <p><b>Needs nothing of the environment but a writable protected database and a resolver that
/// answers the shipped endpoint's host.</b> No socket is opened: the shipped adapter's transport,
/// sleep and clock are replaced by <class>OcuPilot.Test.GeminiStub</class>, which the shipped row
/// is re-adapted to by <class>OcuPilot.Test.CatalogProbeShipped</class>. Every other column of
/// that row -- its endpoint, its model, its tuning, its key prefix -- is the shipped one. Every
/// stored definition a method creates is removed here.</p>
Class OcuPilot.Test.GeminiAdapter Extends %UnitTest.TestCase
{

/// <p>The port entry, with its switched catalog, gate, credential class and TLS answer.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>The catalog that re-adapts the two shipped non-canonical rows to their stubs.</p>
Parameter CATALOG = "OcuPilot.Test.CatalogProbeShipped";

/// <p>The stub the <code>gemini</code> row answers under that catalog.</p>
Parameter STUB = "OcuPilot.Test.GeminiStub";

/// <p>The shipped adapter whose placeholder and model grammar this class reads, so neither is
/// spelled twice.</p>
Parameter ADAPTER = "OcuPilot.Kernel.Provider.Gemini";

/// <p>The shipped provider key under test.</p>
Parameter PROVIDERKEY = "gemini";

/// <p>The credential the shape gate accepts: non-empty and free of whitespace, which is all a row
/// declaring no prefix can require.</p>
Parameter PROBEKEY = "probegeminikeyabcdefghijklmn";

/// <p>The wire name of the one tool every request leg advertises.</p>
Parameter TOOLNAME = "logs_errors_read";

/// <p>The system prompt every request leg sends.</p>
Parameter SYSTEMPROMPT = "you are a probe";

/// <p>A <code>generateContent</code> reply carrying text, one function call, a finish reason and
/// both usage figures.</p>
Parameter REPLY = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""looking""},{""functionCall"":{""name"":""logs_errors_read"",""args"":{""maxRows"":5}}}]},""finishReason"":""STOP""}],""usageMetadata"":{""promptTokenCount"":41,""candidatesTokenCount"":11}}";

/// <p>The error body this family refuses with, whose <code>error.message</code> is the only part
/// that may reach <code>detail.providerText</code>.</p>
Parameter ERRORBODY = "{""error"":{""code"":400,""status"":""INVALID_ARGUMENT"",""message"":""the vendor's own words""}}";

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

/// <p>Create one enabled probe definition on this family's shipped row, taking its tuning and
/// credential reference from <var>pRow</var>, its model from <var>pModel</var> (the row's own when
/// that is empty) and a name distinguished by <var>pSuffix</var>, and hand back its id.</p>
/// <p><b>Its <code>EndpointUrl</code> is left empty</b>, so the endpoint the call goes to is the
/// row's own <code>defaultEndpoint</code> -- placeholder included -- exactly as
/// <method>OcuPilot.Port.ProviderPort.EndpointOf</method> resolves it.</p>
Method StoredDefinition(pRow As %DynamicObject, pModel As %String = "", pSuffix As %String = "") As %String
{
    Set tId = ""
    Try {
        Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
        Set tRow.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Shipped" _ ..#PROVIDERKEY _ pSuffix
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
/// carrying text and one tool call, and a user message carrying its result.</p>
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

/// <p>AC2 -- a stored definition on the shipped <code>gemini</code> row reaches that family's own
/// dialect: the recorded URL is the row's endpoint with the definition's model substituted for the
/// placeholder, the credential travels on this family's header and no other, the body is a
/// <code>generateContent</code> body, and the reply comes back as canonical blocks.</p>
/// <p>mutation: have <method>OcuPilot.Kernel.Provider.Gemini.RequestUrl</method> answer the
/// endpoint unchanged -- red on the recorded URL, which still carries the placeholder.</p>
Method TestAShippedGeminiRowIsCalledInItsOwnDialect()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Set tPlaceholder = $Parameter(..#ADAPTER, "MODELPLACEHOLDER")
    Do $$$AssertTrue(tRow.defaultEndpoint [ tPlaceholder, "the shipped row's endpoint names the model in its path: " _ tRow.defaultEndpoint)
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
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), $Replace(tRow.defaultEndpoint, tPlaceholder, tRow.defaultModel), "with the row's endpoint carrying the definition's model where the placeholder was")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1) [ tPlaceholder, 0, "and no placeholder left in it")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), "x-goog-api-key", "the credential travels on this family's header and on no other")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1) [ ..#PROBEKEY, 0, "and never in the URL, which the wider vendor API would also accept")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("contentType", 1), "application/json", "with a JSON content type")

    Set tBody = ..RecordedBody(1)
    Do $$$AssertTrue($IsObject(tBody), "the outbound body was recorded and is JSON")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "contents.1.role"), "model", "the body is this dialect's own, with the assistant turn as the model role")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "systemInstruction.parts.0.text"), ..#SYSTEMPROMPT, "the prompt travels as a system instruction rather than as a message")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tBody, "tools.0.functionDeclarations.0.name"), ..#TOOLNAME, "the tools are declared where this dialect declares them")
    Do $$$AssertEquals(+##class(OcuPilot.Test.Adapter).Path(tBody, "generationConfig.maxOutputTokens"), +tRow.canonicalMaxTokens, "the tuning is this dialect's generationConfig, carrying the row's own canonical maximum")
    Do $$$AssertEquals(tBody.generationConfig.%GetTypeOf("temperature"), "unassigned", "and no temperature, since the row declares no canonical one")
    Do $$$AssertEquals(tBody.%GetTypeOf("model"), "unassigned", "the model is not in the body: this family carries it in the URL")
    Do $$$AssertEquals(tBody.%GetTypeOf("messages"), "unassigned", "and no field of another dialect appears")

    Do $$$AssertEquals(tResponse.Text, "looking", "the reply's text parts become canonical text")
    Do $$$AssertEquals(tResponse.StopReason, "tool_use", "a reply that called a tool stops for that reason")
    Do $$$AssertTrue(tResponse.ToolCallsJson [ """tool_use""", "and its function call becomes a canonical tool_use block: " _ tResponse.ToolCallsJson)
    Do $$$AssertEquals(tResponse.RequestTokens, 41, "with this dialect's own usage field names read")
    Do $$$AssertEquals(tResponse.ResponseTokens, 11, "in both directions")
}

/// <p>AC3 -- a model the URL path could not carry is refused <code>PROVIDER.EGRESS</code> before
/// any socket is opened, and the reason names no credential. A model outside the grammar cannot
/// reach the path at all, which is what keeps a caller-supplied value out of a URL (AD-21).</p>
/// <p>mutation: drop the model-shape gate in
/// <method>OcuPilot.Kernel.Provider.Gemini.RequestUrl</method> -- red on the expected
/// <code>PROVIDER.EGRESS</code> code and on the zero-calls assertion.</p>
Method TestAModelThatWouldNotSurviveSubstitutionIsRefused()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals($Match("../../evil", $Parameter(..#ADAPTER, "MODELPATTERN")), 0, "a model carrying path characters is outside the grammar the adapter admits")
    Do $$$AssertEquals($Match(tRow.defaultModel, $Parameter(..#ADAPTER, "MODELPATTERN")), 1, "and the row's own model is inside it, so the grammar is not simply refusing everything")

    Do ..Tools(.tTools)
    Set tCase = 0
    For tBadModel = "../../evil", "evil.example.com/v1", "a model with spaces" {
        Set tCase = tCase + 1
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
        Set tId = ..StoredDefinition(tRow, tBadModel, "Bad" _ tCase)
        If tId = "" Continue
        Do ..Canonical(.tMessages)
        Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
        Do $$$AssertStatusOK(tSC, "model '" _ tBadModel _ "': the port still returns $$$OK")
        Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, "model '" _ tBadModel _ "': refused PROVIDER.EGRESS")
        Do $$$AssertEquals(tResponse.StopReason, "error", "model '" _ tBadModel _ "': reported through the stop reason")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "model '" _ tBadModel _ "': with no socket opened")
        Do $$$AssertEquals(..Rendered(tFault) [ ..#PROBEKEY, 0, "model '" _ tBadModel _ "': and no credential in the reason: " _ ..Rendered(tFault))
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), $Parameter("OcuPilot.Kernel.Provider.Base", "REASONBUILTURLEGRESS"), "model '" _ tBadModel _ "': with the reason that names the built URL rather than the endpoint's own address")
    }

    ; The positive control. Without it every assertion above would also hold on a host this
    ; instance cannot resolve, where the port refuses the same code before the adapter runs --
    ; so the refusals would be attributed to a model gate that never executed.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tSoundId = ..StoredDefinition(tRow, "", "Sound")
    If tSoundId = "" Quit
    Do ..Canonical(.tSoundMessages)
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "Invoke", tSoundId, .tSoundMessages, .tTools, "", .tSoundResponse, .tSoundStatus, .tSoundFault), "the row's own model on the same row and endpoint returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tSoundFault), "", "with no fault: " _ ..Rendered(tSoundFault))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and reaches the transport once, so the refusals above were the model gate and not an unresolvable host")
}

/// <p>AC4's Gemini twin -- the shared rules hold on this family exactly as they do on the
/// canonical one: a retryable status is tried again after the provider's own honoured hint, a call
/// that raised mid-flight is never tried again, and a refusal carries this family's
/// <code>error.message</code> in <code>detail.providerText</code> and nothing else of the
/// body.</p>
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

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)
    Set tRaised = ..Adapter()
    Do $$$AssertStatusOK(tRaised.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tRaisedResponse, .tRaisedFault, .tRaisedStatus), "a call that raised mid-flight still returns $$$OK")
    Set tRaised = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and is never tried again, however many attempts the settings allow")
    Do $$$AssertEquals(..FaultCode(tRaisedFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "reporting PROVIDER.TRANSPORT")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(400, ..#ERRORBODY)
    Set tRefused = ..Adapter()
    Do $$$AssertStatusOK(tRefused.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tRefusedResponse, .tRefusedFault, .tRefusedStatus), "a refused call returns $$$OK")
    Set tRefused = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "a determinate refusal is not retried")
    Do $$$AssertEquals(..FaultCode(tRefusedFault), ##class(OcuPilot.Api.Error).#PROVIDERREFUSED, "reporting PROVIDER.REFUSED")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tRefusedFault, "detail.providerText"), "the vendor's own words", "with this family's error.message as the provider text")
    Do $$$AssertEquals(..Rendered(tRefusedFault) [ "INVALID_ARGUMENT", 0, "and no other part of the body: " _ ..Rendered(tRefusedFault))
    Do $$$AssertEquals(..Rendered(tRefusedFault) [ ..#PROBEKEY, 0, "and no part of the credential either")
}

/// <p>AC3's other arm -- a <method>OcuPilot.Kernel.Provider.Base.RequestUrl</method> override that
/// answers a well-formed URL on another authority is refused <code>PROVIDER.EGRESS</code> with no
/// socket opened, because the address policy never judged that address (AD-42).</p>
/// <p><b>Driven through <class>OcuPilot.Test.ProviderOriginProbe</class></b>, because no shipped
/// adapter can move the authority: <parameter>OcuPilot.Kernel.Provider.Gemini.MODELPATTERN</parameter>
/// admits no character that could, so every shipped refusal lands on the empty-result arm and this
/// one would read as coverage while never having run.</p>
/// <p>mutation: drop the <code>tOrigin '= tJudged</code> term from
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s guard -- red on the expected
/// <code>PROVIDER.EGRESS</code> code and on the zero-calls assertion, while every other method in
/// this class stays green.</p>
Method TestABuiltUrlOnAnotherAuthorityIsRefused()
{
    Set tRow = ..ShippedRow()
    If '$IsObject(tRow) Quit
    Do ..DirectValues(tRow, .tValues)
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 3)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#REPLY)

    Set tMoved = ##class(OcuPilot.Test.ProviderOriginProbe).%New()
    Set tMoved.SecretClassName = "OcuPilot.Test.SecretProbe"
    Do $$$AssertStatusOK(tMoved.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the refused call still returns $$$OK")
    Set tMoved = ""
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDEREGRESS, "a URL on another authority is refused PROVIDER.EGRESS")
    Do $$$AssertEquals(tResponse.StopReason, "error", "reported through the stop reason")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "with no socket opened, however many attempts the settings allow")
    Do $$$AssertEquals(..Rendered(tFault) [ $Parameter("OcuPilot.Test.ProviderOriginProbe", "MOVEDORIGIN"), 0, "and the address it would have called is not in the refusal: " _ ..Rendered(tFault))
    Do $$$AssertEquals(..Rendered(tFault) [ ..#PROBEKEY, 0, "nor any part of the credential")
}

}
