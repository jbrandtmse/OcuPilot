/// <p>Story 3.4's Test connection route: the one bounded provider call it makes, what it answers,
/// and what it records.</p>
/// <p><b>The provider legs run in process</b> through <class>OcuPilot.Test.DefinitionsProbe</class>,
/// whose port seam is <class>OcuPilot.Test.ProviderPortProbe</class> and whose catalog names
/// <class>OcuPilot.Test.ProviderStub</class> as the adapter, so the whole shipped path -- the
/// address judgement, the TLS configuration, the credential resolution, the request the adapter
/// builds, the retry arithmetic and the fault -- runs with <b>no socket opened to any provider</b>.
/// The handler's own gate, 404, validation and rendering are driven over HTTP instead: they are
/// what a consumer receives, and there is no response device in this process to render to.</p>
/// <p><b>Every wire leg refuses before the transport</b>, and each names a code the shipped path
/// can only reach before it -- which is how "no socket was opened" is observable from a process
/// that cannot read the stub's counter. The unresolvable-credential leg asserts the environment
/// variable is unset first, so that is a checked precondition rather than a hope.</p>
/// <p>The 403 is <class>OcuPilot.Test.AgentWireSecurity</class>'s: it needs a real principal
/// holding no OcuPilot administrative resource, which that class builds and tears down, and this
/// route is one entry in its refusal roster.</p>
/// <p>Every definition this class creates is named with <parameter>PROBEPREFIX</parameter> and
/// removed in <method>OnAfterOneTest</method>, which then asserts none survives.</p>
Class OcuPilot.Test.AgentConnection Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>A credential of the shape the <code>probe-local</code> row's prefix requires.</p>
Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>The endpoint every definition here carries. <b>A documentation-reserved literal</b>
/// (RFC 5737 TEST-NET-1): it classifies as an ordinary public address without a name lookup, so
/// no leg depends on this container's resolver, and nothing ever connects to it -- the in-process
/// legs answer from the stub and the wire legs refuse before the transport.</p>
Parameter PUBLICENDPOINT = "https://192.0.2.1/v1/messages";

/// <p>A second reserved literal (RFC 5737 TEST-NET-2), for the leg that edits the endpoint.</p>
Parameter OTHERENDPOINT = "https://198.51.100.7/v1/messages";

/// <p>An RFC-1918 private-network address. AD-42 names the instance, loopback and link-local and
/// nothing else, so this one is <b>not</b> refused -- a local model on the operator's own network
/// is a supported case.</p>
Parameter PRIVATEENDPOINT = "https://10.1.2.3/v1/messages";

/// <p>A loopback endpoint, refused on the shipped provider row, which admits no local address.</p>
Parameter LOOPBACKENDPOINT = "https://127.0.0.1/v1/messages";

/// <p>A name nothing answers for. Write time deliberately does not judge resolvability; the port
/// does.</p>
Parameter UNRESOLVABLEENDPOINT = "https://no-such-host-ocupilot.invalid/v1/messages";

/// <p>The environment variable the unresolvable-credential leg's definition names. Asserted unset
/// before that leg runs rather than assumed.</p>
Parameter UNSETVARIABLE = "OCUPILOT_PROBE_ABSENT_TEST_KEY";

/// <p>The reply text a successful call answers. Distinctive, so "no part of the reply reached the
/// change record" is an assertion about this text and not about a common word.</p>
Parameter REPLYTEXT = "probe-reply-marker ok";

/// <p>A well-formed reply carrying <parameter>REPLYTEXT</parameter>.</p>
Parameter OKBODY = "{""content"":[{""type"":""text"",""text"":""probe-reply-marker ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":2}}";

/// <p>A provider refusal body in the Anthropic error shape, carrying a member
/// (<parameter>RAWMARKER</parameter>) that exists only in the raw body.</p>
Parameter REFUSALBODY = "{""type"":""error"",""error"":{""type"":""authentication_error"",""message"":""invalid x-api-key""},""request_id"":""probe-raw-body-marker""}";

/// <p>The member of <parameter>REFUSALBODY</parameter> that must not reach the envelope.</p>
Parameter RAWMARKER = "probe-raw-body-marker";

/// <p>A retryable answer's body.</p>
Parameter RATELIMITBODY = "{""type"":""error"",""error"":{""type"":""rate_limit_error"",""message"":""slow down""}}";

/// <p>Arm a clean port, a clean stub, a resolvable credential and a clean log capture, and clear
/// any definition a previous method left behind.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSecretClass("OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSslState("present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

/// <p>Leave no switch set for the next method, or the next class, to inherit, and assert no
/// definition this class created survives.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>One stored definition on <class>OcuPilot.Test.CatalogProbe</class>'s local-allowed row,
/// whose <code>adapterClass</code> is the transport stub, and its id -- or <code>""</code>.</p>
Method ProbeDefinition(pSuffix As %String) As %String
{
    Quit ..ProbeDefinitionOn(pSuffix, ..#PUBLICENDPOINT)
}

/// <p><method>ProbeDefinition</method>'s definition carrying <var>pEndpoint</var>.
/// <code>""</code> is a definition stored with no endpoint at all, which the provider rows permit
/// (<code>endpointRequired</code> false) and which
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method> fills in from the row's canonical one at
/// the moment of the call.</p>
Method ProbeDefinitionOn(pSuffix As %String, pEndpoint As %String) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ pSuffix
    Set tRow.Provider = ##class(OcuPilot.Test.CatalogProbe).#LOCALKEY
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = pEndpoint
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": a stored definition is created")
    If $$$ISERR(tSC) Quit ""
    Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

/// <p>One test outcome through <class>OcuPilot.Test.DefinitionsProbe</class>, from the inputs
/// <method>OcuPilot.Api.Definitions.HandleTest</method> hands
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>: the stored row's values,
/// <var>pBody</var>'s edits merged over them, the two server-owned flags taken from the row,
/// normalized. Exactly one of <var>pAnswer</var> and <var>pFault</var> comes back set.</p>
/// <p><b>It does not validate</b>: the route's <method>OcuPilot.Kernel.AgentRules.Validate</method>
/// call refuses on a field before <method>ConnectionOutcome</method> is reached at all, so a leg
/// that is about a refusal on a field is a wire leg rather than one of these.</p>
ClassMethod Outcome(pId As %String, pBody As %DynamicObject, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit $$$ERROR($$$GeneralError, "No agent definition with id " _ pId)
    Do ##class(OcuPilot.Test.DefinitionsProbe).ValuesFromRow(tRow, .tStored)
    Set tRow = ""
    Kill tValues
    Merge tValues = tStored
    Do ##class(OcuPilot.Test.DefinitionsProbe).MergeBody(pBody, .tValues, .tPresent)
    Set tValues("connectionVerified") = $Get(tStored("connectionVerified"))
    Set tValues("enabled") = $Get(tStored("enabled"))
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)
    Do ##class(OcuPilot.Test.DefinitionsProbe).ConnectionOutcome(pId, .tValues, .tStored, .pAnswer, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p><code>Enabled|ConnectionVerified</code> for definition <var>pId</var>, read from the stored
/// row.</p>
ClassMethod FlagsOf(pId As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit "unreadable"
    Quit tRow.Enabled _ "|" _ tRow.ConnectionVerified
}

/// <p><b>AC1 and AC2's server half</b> -- a test of the stored values makes exactly one transport
/// call carrying the test budget, answers the six keys the route publishes, and records
/// verification on the row.</p>
/// <p>Mutation: drop the <code>maxTokens</code> override in
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> -- the recorded body's
/// <code>max_tokens</code> assertion goes red at the definition's own 4000. Second mutation: set
/// <method>OcuPilot.Kernel.Provider.Base.NewRequest</method>'s <code>Timeout</code> to a literal 5
/// -- the recorded-timeout assertion goes red, which is AC2's ten-second half made falsifiable:
/// OcuPilot's own budget is the instance's resolved setting and cannot be what misses it. Third
/// mutation: clear <code>tSettings("sslConfiguration")</code> on <method>Dispatch</method>'s HTTPS
/// branch -- the recorded-configuration assertion goes red, which is AC1's TLS clause.</p>
Method TestATestOfTheStoredValuesAnswersAndRecordsVerification()
{
    Set tId = ..ProbeDefinition("Stored")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)

    Set tRunSC = ..Outcome(tId, "", .tAnswer, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tRunSC, "the test runs")
    Do $$$AssertTrue('$IsObject(tFault), "and answers no fault")
    Do $$$AssertTrue($IsObject(tAnswer), "with an answer body")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(..KeysOf(tAnswer), "connected,reply,replyTruncated,latencyMs,connectionVerified,testedAsStored", "carrying exactly these keys: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.connected, 1, "the provider answered")
    Do $$$AssertEquals(tAnswer.reply, ..#REPLYTEXT, "the reply is returned")
    Do $$$AssertEquals(tAnswer.replyTruncated, 0, "uncut, being inside the bound")
    Do $$$AssertEquals(tAnswer.testedAsStored, 1, "the values tested were the stored ones")
    Do $$$AssertEquals(tAnswer.connectionVerified, 1, "so the definition reads back verified")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("latencyMs"), "number", "and the measured latency is a number: " _ tAnswer.latencyMs)
    Do $$$AssertEquals(..FlagsOf(tId), "0|1", "the stored row is verified and still disabled -- enabling is the operator's own next act")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "exactly one transport call was made")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), "stub", "through the adapter the catalog row names")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "", "with no backoff wait taken")
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body"))
    Do $$$AssertTrue($IsObject(tSent), "the recorded request body parses")
    If '$IsObject(tSent) Quit
    Do $$$AssertEquals(+tSent."max_tokens", ##class(OcuPilot.Api.Definitions).#TESTMAXTOKENS, "carrying the test budget rather than the definition's own 4000: " _ tSent.%ToJSON())
    Do $$$AssertEquals(tSent.model, "probe-local-model-1", "and the definition's own model")
    Do $$$AssertEquals(tSent.%IsDefined("tools"), 0, "no tools are advertised")
    Do $$$AssertEquals(tSent.%IsDefined("system"), 0, "and no system prompt is sent")
    Do $$$AssertEquals(tSent.messages.%Size(), 1, "one message is sent")
    Do $$$AssertEquals(tSent.messages.%Get(0).content, ##class(OcuPilot.Api.Definitions).#TESTPROMPT, "which is the build-time prompt, composed from nothing read at runtime")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).Resolve(.tSettings), "the instance's outbound settings resolve")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("timeout"), tSettings("timeoutSeconds"), "and the request carried the resolved timeout, not a shorter budget of this route's own")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("sslConfiguration"), tSettings("sslConfiguration"), "and the instance's own TLS configuration, which is AC1's other named half of the path a turn takes")

    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ """msg"":""test""", "the change record names the test verb: " _ tLine)
    Do $$$AssertTrue(tLine [ """connectionVerified"":{""old"":""0"",""new"":""1""}", "and the flag it set")
    Do $$$AssertEquals(tLine [ ..#REPLYTEXT, 0, "and carries no part of the provider's reply, which is model output")
}

/// <p>A test with edits reports its result either way, and writes the row <b>only</b> when no
/// security field was edited: verification is a property of the stored row, and Story 3.1 already
/// decided that changing the model or the tuning does not invalidate one.</p>
/// <p>The third leg is the ordering: a definition stored with no endpoint at all is one the port
/// fills the catalog row's canonical endpoint into, so the comparison has to be made <b>before</b>
/// the call or the instance's own backfill reads as an edit and that definition can never be
/// verified.</p>
/// <p>Mutation: compare every field rather than
/// <method>OcuPilot.Api.Definitions.SecurityFieldNames</method>'s -- the model leg goes red at
/// <code>testedAsStored</code> 0. Drop the comparison entirely and the endpoint leg goes red, the
/// row having been written against values it does not hold. Move the comparison below
/// <method>InvokeDraft</method> in <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> --
/// the third leg goes red at <code>testedAsStored</code> 0 and flags <code>0|0</code>.</p>
Method TestOnlyASecurityEditStopsTheRowBeingWritten()
{
    Set tModelId = ..ProbeDefinition("ModelEdit")
    Set tEndpointId = ..ProbeDefinition("EndpointEdit")
    If (tModelId = "") || (tEndpointId = "") Quit

    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tModelEdit = {"model":"probe-local-model-2"}
    Set tModelSC = ..Outcome(tModelId, tModelEdit, .tModel, .tModelStatus, .tModelFault)
    Do $$$AssertStatusOK(tModelSC, "a test with the model edited runs")
    Do $$$AssertTrue('$IsObject(tModelFault), "and answers no fault")
    If '$IsObject(tModel) Quit
    Do $$$AssertEquals(tModel.testedAsStored, 1, "the model is not a security field, so the verification still stands for the stored row")
    Do $$$AssertEquals(tModel.connectionVerified, 1, "which is recorded")
    Do $$$AssertEquals(..FlagsOf(tModelId), "0|1", "on the row")
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body"))
    Do $$$AssertEquals($Select($IsObject(tSent): tSent.model, 1: ""), "probe-local-model-2", "and the edited model really was what was sent")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tEndpointEdit = {"endpointUrl":(..#OTHERENDPOINT)}
    Set tEditSC = ..Outcome(tEndpointId, tEndpointEdit, .tEdit, .tEditStatus, .tEditFault)
    Do $$$AssertStatusOK(tEditSC, "a test with the endpoint edited runs")
    Do $$$AssertTrue('$IsObject(tEditFault), "and answers no fault either")
    If '$IsObject(tEdit) Quit
    Do $$$AssertEquals(tEdit.connected, 1, "the call is still made and its result reported")
    Do $$$AssertEquals(tEdit.testedAsStored, 0, "but the values tested were not the stored ones")
    Do $$$AssertEquals(tEdit.connectionVerified, 0, "so nothing was recorded")
    Do $$$AssertEquals(..FlagsOf(tEndpointId), "0|0", "and the stored row is unwritten")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url"), ..#OTHERENDPOINT, "the call went to the edited endpoint, which is what makes it a test of the edit")

    ; A definition stored with no endpoint at all: the port fills the row's canonical one in
    ; before the call, so the comparison has to have been made before the call or the instance's
    ; own backfill would read as an edit the operator never made.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do $$$AssertTrue(##class(OcuPilot.Test.CatalogProbe).Row(##class(OcuPilot.Test.CatalogProbe).#LOCALKEY, .tCatalogRow), "the provider row this definition names is readable")
    Set tBlankId = ..ProbeDefinitionOn("NoEndpoint", "")
    If tBlankId = "" Quit
    Set tBlankSC = ..Outcome(tBlankId, "", .tBlank, .tBlankStatus, .tBlankFault)
    Do $$$AssertStatusOK(tBlankSC, "a test of a definition stored with no endpoint runs")
    Do $$$AssertTrue('$IsObject(tBlankFault), "and answers no fault: " _ $Select($IsObject(tBlankFault): tBlankFault.%ToJSON(), 1: ""))
    If '$IsObject(tBlank) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url"), tCatalogRow.defaultEndpoint, "the call went to the row's canonical endpoint")
    Do $$$AssertEquals(tBlank.testedAsStored, 1, "which the port filled in after the comparison, so it is not read as an edit")
    Do $$$AssertEquals(..FlagsOf(tBlankId), "0|1", "and the row is recorded verified rather than left permanently unverifiable")
}

/// <p><b>AC3's server half</b> -- a provider refusal answers the shipped envelope carrying the
/// provider's own <code>error.message</code> in <code>detail.providerText</code> and nothing else
/// of the body, and changes no flag.</p>
/// <p>Mutation: put the raw body into <code>detail.providerText</code> instead of
/// <method>OcuPilot.Kernel.Provider.Anthropic.ProviderMessage</method>'s result -- the
/// raw-marker assertion goes red.</p>
Method TestAProviderRefusalCarriesItsOwnMessageAndNothingElseOfTheBody()
{
    Set tId = ..ProbeDefinition("Refused")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, ..#REFUSALBODY)

    Set tRunSC = ..Outcome(tId, "", .tAnswer, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tRunSC, "the test runs")
    Do $$$AssertTrue('$IsObject(tAnswer), "and produces no answer body")
    Do $$$AssertTrue($IsObject(tFault), "but a fault")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tHttpStatus, 502, "answered as a gateway failure")
    Do $$$AssertEquals(tFault.error, "unavailable", "on the unavailable slug")
    Do $$$AssertEquals(tFault.code, "PROVIDER.REFUSED", "with the refusal code")
    Do $$$AssertEquals($Select($IsObject(tFault.detail): tFault.detail.providerText, 1: ""), "invalid x-api-key", "carrying the provider's own error.message: " _ tFault.%ToJSON())
    Do $$$AssertEquals(tFault.%ToJSON() [ ..#RAWMARKER, 0, "and no other member of the raw body, which goes to the log alone")
    Do $$$AssertEquals(tFault.%ToJSON() [ "authentication", 0, "not even the vendor's own error type")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and no flag changed")
}

/// <p><b>AC2's bound</b> -- a reply longer than the declared maximum is cut on the instance, and
/// the answer says it was cut, so no client can render more.</p>
/// <p>Mutation: stop cutting the reply in
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> -- both assertions go red.</p>
Method TestALongReplyIsCutAtTheDeclaredBound()
{
    Set tId = ..ProbeDefinition("Long")
    If tId = "" Quit
    Set tLong = $Translate($Justify("", ##class(OcuPilot.Api.Definitions).#TESTREPLYMAX * 2), " ", "x")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""" _ tLong _ """}],""stop_reason"":""end_turn""}")

    Set tRunSC = ..Outcome(tId, "", .tAnswer, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tRunSC, "the test runs")
    Do $$$AssertTrue($IsObject(tAnswer), "and answers")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals($Length(tAnswer.reply), ##class(OcuPilot.Api.Definitions).#TESTREPLYMAX, "the reply is cut to the declared bound: " _ $Length(tAnswer.reply))
    Do $$$AssertEquals(tAnswer.reply, $Extract(tLong, 1, ##class(OcuPilot.Api.Definitions).#TESTREPLYMAX), "at its first characters")
    Do $$$AssertEquals(tAnswer.replyTruncated, 1, "and the answer says it was cut")
}

/// <p><b>AC1's bolded "one"</b> -- a retryable status makes exactly one transport call and takes
/// no backoff wait, rather than the instance's three attempts with two honoured
/// <code>Retry-After</code> waits: a 429 already answers the question the operator asked, and they
/// are holding focus on a button while it runs.</p>
/// <p>Mutation: ignore <code>pValues("maxAttempts")</code> in
/// <method>OcuPilot.Port.ProviderPort.Dispatch</method> -- this goes red at three calls with a
/// non-empty wait list.</p>
Method TestARetryableStatusMakesOneCallAndTakesNoBackoff()
{
    Set tId = ..ProbeDefinition("Retryable")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, ..#RATELIMITBODY, "30")

    Set tRunSC = ..Outcome(tId, "", .tAnswer, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tRunSC, "the test runs")
    Do $$$AssertTrue($IsObject(tFault), "and answers a fault")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.code, "PROVIDER.UNAVAILABLE", "the provider did not serve this call")
    Do $$$AssertEquals(tHttpStatus, 502, "answered as a gateway failure")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "exactly one transport call was made, not the instance's three")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "", "and no backoff wait was taken")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and no flag changed")
}

/// <p><b>Integration AC</b> -- an id no definition holds is a named 404, answered <b>before the
/// body is read</b>: the body here carries a link-local endpoint that would otherwise be a 422, so
/// the status names which check ran first.</p>
Method TestAnUnknownIdIsRefusedBeforeTheBodyIsRead()
{
    Set tSC = ..Call("POST", "/999999999/test", "{""endpointUrl"":""https://169.254.169.254/latest/meta-data""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 404, "and answers 404 rather than the body's own 422: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "AGENT.NOTFOUND", "with the agent not-found code")
}

/// <p><b>AC4 and the Integration AC</b> -- a link-local endpoint in the body is refused on its own
/// field before any call, with no escape: that range is where a cloud instance's metadata service
/// lives, and the route applies the same <class>OcuPilot.Kernel.Egress</class> judgement the write
/// gate does.</p>
/// <p>Mutation: skip <method>OcuPilot.Kernel.AgentRules.Validate</method> in
/// <method>OcuPilot.Api.Definitions.HandleTest</method> -- this goes red, the port's own
/// <code>PROVIDER.EGRESS</code> answering 502 instead of the 422 on the field.</p>
Method TestALinkLocalEndpointInTheBodyIsRefusedOnItsField()
{
    Set tId = ..WireDefinition("Meta")
    If tId = "" Quit
    Set tSC = ..Call("POST", "/" _ tId _ "/test", "{""endpointUrl"":""https://169.254.169.254/latest/meta-data""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused as a validation failure: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentWire).ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("endpointUrl", "AGENT.ENDPOINT.LINKLOCAL"))), "with one violation on the endpoint field")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and no flag changed")
}

/// <p><b>AC4's second clause</b> -- a private-network endpoint is <b>attempted</b>. AD-42 names the
/// instance, loopback and link-local and nothing else, so RFC-1918 is not a refused range: a local
/// model on the operator's own network is a supported case, and this container's own address is
/// itself private.</p>
/// <p>Both halves of "attempted", because either alone would pass against a rule that refused at
/// the other end: the write gate accepts the address over the wire, and the call reaches the
/// transport seam carrying it. The call half runs in process against the stub -- nothing here opens
/// a socket, and the definition is not marked local, so the catalog row's local escape is closed
/// and the <code>public</code> classification is the only thing letting it through.</p>
/// <p>Mutation: refuse <code>10.0.0.0/8</code> in
/// <method>OcuPilot.Kernel.Egress.KindOf</method> -- both halves go red, the create answering 422
/// and the call answering <code>PROVIDER.EGRESS</code> with the stub never entered.</p>
Method TestAPrivateNetworkEndpointIsAttempted()
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Private"",""provider"":""anthropic"",""endpointUrl"":""" _ ..#PRIVATEENDPOINT _ """,""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 201, "a private-network endpoint is accepted at write time rather than refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus = 201 {
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).endpointUrl, ..#PRIVATEENDPOINT, "and stored verbatim")
    }

    Set tId = ..ProbeDefinition("PrivateCall")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tEdit = {"endpointUrl":(..#PRIVATEENDPOINT)}
    Set tRunSC = ..Outcome(tId, tEdit, .tAnswer, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tRunSC, "the test runs")
    Do $$$AssertTrue('$IsObject(tFault), "and the address policy refuses nothing: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the call reached the transport")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url"), ..#PRIVATEENDPOINT, "carrying the private-network endpoint")
}

/// <p><b>AC4's third clause</b> -- a loopback endpoint is refused on its own field, because the
/// shipped provider row admits no local address. The escape is the catalog row's
/// <code>allowsLocal</code> column <b>and</b> the definition's own marked-local flag, and this
/// definition has neither.</p>
/// <p>Told apart from the link-local leg by its code: link-local has no escape at all, while this
/// one is a refusal a catalog row could open.</p>
/// <p>Mutation: skip <method>OcuPilot.Kernel.AgentRules.Validate</method> in
/// <method>OcuPilot.Api.Definitions.HandleTest</method> -- this goes red with the port's own
/// <code>PROVIDER.EGRESS</code> 502 instead of the 422 on the field.</p>
Method TestALoopbackEndpointInTheBodyIsRefusedOnItsField()
{
    Set tId = ..WireDefinition("Loop")
    If tId = "" Quit
    Set tSC = ..Call("POST", "/" _ tId _ "/test", "{""endpointUrl"":""" _ ..#LOOPBACKENDPOINT _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused as a validation failure: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentWire).ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("endpointUrl", "AGENT.ENDPOINT.ADDRESS"))), "with one violation on the endpoint field, told apart from the link-local code by the escape a catalog row could open")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and no flag changed")
}

/// <p>An endpoint that resolves to <b>nothing</b> is accepted by the route and refused by the port:
/// whether a name resolves is a property of the instance's resolver at that instant rather than of
/// the value the operator typed, so <method>OcuPilot.Kernel.AgentRules.AddressViolation</method>
/// deliberately does not judge it and <method>OcuPilot.Port.ProviderPort.Dispatch</method> does.</p>
/// <p>The status is what tells the two apart: a 422 would mean write time refused it, and the 502
/// <method>OcuPilot.Kernel.Provider.Base.HttpFor</method> answers for
/// <code>PROVIDER.EGRESS</code> means the route accepted it and the call was refused. No socket is
/// opened either way -- the port refuses before it resolves an adapter.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.AgentRules.AddressViolation</method> refuse
/// <code>unresolvable</code> as well -- this goes red at 422.</p>
Method TestAnUnresolvableEndpointIsAcceptedByTheRouteAndRefusedByThePort()
{
    ; Checked, not assumed: this leg goes through the shipped adapter, so a resolver that answered
    ; for the name would classify it public and the call would open a real socket. RFC 6761 reserves
    ; .invalid precisely so nothing answers, and this is where that is confirmed on this instance.
    Do ##class(OcuPilot.Kernel.Egress).Classify(##class(OcuPilot.Kernel.Egress).HostOf(..#UNRESOLVABLEENDPOINT), .tKind, .tAddress)
    Do $$$AssertEquals(tKind, ##class(OcuPilot.Kernel.Egress).#KINDUNRESOLVABLE, "the endpoint this leg names resolves to nothing on this instance, so no socket can be opened to it")
    If tKind '= ##class(OcuPilot.Kernel.Egress).#KINDUNRESOLVABLE Quit
    Set tId = ..WireDefinition("NoHost")
    If tId = "" Quit
    Set tSC = ..Call("POST", "/" _ tId _ "/test", "{""endpointUrl"":""" _ ..#UNRESOLVABLEENDPOINT _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 502, "the route accepted the endpoint and the port refused the call: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.error, "unavailable", "on the unavailable slug")
    Do $$$AssertEquals(tAnswer.code, "PROVIDER.EGRESS", "with the call-time address code rather than the write-time violation")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and no flag changed")
}

/// <p>Whether this instance carries the SSL configuration OcuPilot's provider calls are made
/// through, reported as a named skip when it does not (DW-365).</p>
/// <p><b>Why the two credential-refusal legs below need this.</b> Both assert 503 with
/// <code>PROVIDER.CREDENTIAL</code>, and on an instance where the configuration is absent the port
/// refuses one step earlier with <code>PROVIDER.TLS</code> -- also 503. The status assertion
/// therefore passes and only the code assertion fails, which reads as "the credential rung is
/// broken" when what is actually missing is the install's own TLS step. Asking first turns that
/// into a stated skip.</p>
/// <p><b>It never creates one.</b> A test that created the configuration would be asserting
/// against state it had just arranged, and an SSL configuration is instance security an operator
/// owns (AD-32): install creates it, and a run on an instance that has not installed says so.</p>
ClassMethod ProviderTlsPresent(Output pReason As %String) As %Boolean
{
    Set pReason = ""
    Set tName = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(Security.SSLConfigs).Exists(tName)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    If 'tExists Set pReason = "skipped: this instance carries no '" _ tName _ "' SSL configuration, so the port refuses with PROVIDER.TLS before it reaches the credential rung (DW-365); run the installer first"
    Quit tExists
}

/// <p><b>Integration AC</b> -- a definition whose credential reference resolves to nothing is
/// refused 503 with <code>PROVIDER.CREDENTIAL</code>, which the shipped path can only reach
/// <b>before</b> the transport, and <b>no flag is cleared</b>: flagging an unresolved credential is
/// <method>OcuPilot.Port.ProviderPort.Invoke</method>'s alone, and testing a disabled definition is
/// how an operator re-enables one.</p>
/// <p>That the variable is unset is asserted first, so "no key could have been sent" is a checked
/// precondition rather than a hope. <b>The definition is enabled and verified first</b>, for the
/// same reason: "no flag was cleared" read off a row that was already <code>0|0</code> is an
/// assertion about nothing, and clearing is the direction this leg exists to refuse.</p>
/// <p>Mutation: clear the definition's verification on the fault path of
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> -- this goes red, the row reading
/// <code>0|0</code>.</p>
Method TestAnUnresolvableCredentialIsRefusedBeforeTheTransport()
{
    ; DW-365: PROVIDER.TLS is also a 503, so without this the code assertion below would be the
    ; only thing that failed and would name the wrong cause.
    If '..ProviderTlsPresent(.tSkip) {
        Do $$$AssertTrue(1, tSkip)
        Quit
    }
    Do $$$AssertEquals($System.Util.GetEnviron(..#UNSETVARIABLE), "", "the environment variable this definition names is genuinely unset on this instance")
    Set tId = ..WireDefinition("NoKey", ..#UNSETVARIABLE)
    If tId = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified before the refused test")
    Do $$$AssertEquals(..FlagsOf(tId), "1|1", "and reads back that way, so 'no flag was cleared' is an assertion about something")

    Set tSC = ..Call("POST", "/" _ tId _ "/test", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 503, "and answers 503: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, "PROVIDER.CREDENTIAL", "with the credential code, which is reached before any socket is opened")
    Do $$$AssertTrue(tAnswer.reason [ ..#UNSETVARIABLE, "naming the reference rather than a value: " _ tAnswer.reason)
    Do $$$AssertEquals(..FlagsOf(tId), "1|1", "and no flag was cleared -- flagging an unresolved reference is the stored entry's alone")
}

/// <p><b>A body carrying <code>enabled</code> does not refuse the test.</b> The route never writes
/// <property>OcuPilot.Kernel.State.Agent.Enabled</property>, so it takes the field from the row the
/// way it takes <code>connectionVerified</code>: left merged, a form that posts its whole state
/// with Enable already ticked would meet <code>AGENT.ENABLE.UNVERIFIED</code> before any call, on
/// the one flow Test connection exists to unblock -- a definition is unverified until it passes.</p>
/// <p>Observed through a definition whose credential resolves to nothing, so the call is refused
/// <b>after</b> validation and before the transport: the status is what says which check answered.
/// The row's own flags are read back, so "the route never writes Enabled" is asserted too.</p>
/// <p>Mutation: drop the <code>enabled</code> line from
/// <method>OcuPilot.Api.Definitions.HandleTest</method> -- this goes red at 422
/// <code>AGENT.VALIDATION</code> instead of 503.</p>
Method TestABodyCarryingEnabledDoesNotRefuseTheTest()
{
    ; DW-365, as above: this leg reads the credential code to say which check answered.
    If '..ProviderTlsPresent(.tSkip) {
        Do $$$AssertTrue(1, tSkip)
        Quit
    }
    Do $$$AssertEquals($System.Util.GetEnviron(..#UNSETVARIABLE), "", "the environment variable this definition names is genuinely unset on this instance")
    Set tId = ..WireDefinition("Ticked", ..#UNSETVARIABLE)
    If tId = "" Quit
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "the definition is disabled and unverified, which is what makes the enable rule applicable")

    Set tSC = ..Call("POST", "/" _ tId _ "/test", "{""enabled"":true}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 503, "the body's enabled flag did not refuse the test; the call was made and the credential refused it: " _ tBody)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "PROVIDER.CREDENTIAL", "with the credential code rather than a validation failure")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and the route wrote neither flag")
}

/// <p><b>DW-360</b> -- the route's 200 answer, produced by the literal, inherited
/// <method>OcuPilot.Api.Definitions.HandleTest</method> body rather than by
/// <method>Outcome</method>'s own reimplemented arrangement. Driven through
/// <class>OcuPilot.Test.RouterFixture</class>'s <code>/agent-definitions/:id/test</code> route,
/// which dispatches to <class>OcuPilot.Test.DefinitionsProbe</class>'s inherited
/// <method>HandleTest</method> -- the probe declares no <method>HandleTest</method> of its own, so
/// what runs is compiled from <method>OcuPilot.Api.Definitions.HandleTest</method>'s source; a
/// mutation of that source reaches this leg only once the probe is recompiled too, which is why
/// the spec's mutation protocol recompiles the whole tree -- with
/// <class>OcuPilot.Test.Dispatch</class> supplying the <code>%CSP.Request</code> /
/// <code>%CSP.Response</code> stubs and capturing the device, the same shape
/// <method>OcuPilot.Test.RouterFixture.InstanceFaultRoute</method> uses for DW-120.</p>
/// <p>The definition names <code>anthropic</code> rather than the probe catalog's own key:
/// <method>OcuPilot.Kernel.AgentRules.Validate</method>, which <method>HandleTest</method> calls
/// by hard class name, reads the real, unsubclassed
/// <class>OcuPilot.Kernel.Provider.Catalog</class> and refuses every other key. Reaching a stub
/// adapter anyway is <class>OcuPilot.Test.CatalogAnthropicStub</class>, switched in by
/// <method>HandlerDefinition</method> and reset on every <method>OnAfterOneTest</method>.</p>
/// <p>Mutation: delete <code>Api.Response.JSON(tAnswer)</code> from
/// <method>OcuPilot.Api.Definitions.HandleTest</method> -- this goes red, the captured body
/// staying empty and the status staying 0.</p>
Method TestTheShippedHandlerAnswersTheSuccessBodyOverTheWire()
{
    Set tId = ..HandlerDefinition("Handler200")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions/" _ tId _ "/test", "POST", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch through the shipped, inherited HandleTest completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200 through Api.Response.JSON: " _ tBody)
    Do $$$AssertTrue(tBody '= "", "with a non-empty captured body")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue($IsObject(tAnswer), "which parses as JSON")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(..KeysOf(tAnswer), "connected,reply,replyTruncated,latencyMs,connectionVerified,testedAsStored", "carrying exactly the route's six keys: " _ tBody)
    Do $$$AssertEquals(tAnswer.connected, 1, "the provider answered")
    Do $$$AssertEquals(tAnswer.testedAsStored, 1, "the values tested were the stored ones")
    Do $$$AssertEquals(tAnswer.connectionVerified, 1, "so the definition reads back verified")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), "stub", "through the switched-in stub adapter -- no socket was opened")
    Do $$$AssertEquals(..FlagsOf(tId), "0|1", "on the row -- the handler's own write, not Outcome()'s reimplemented one")
}

/// <p><b>AC3 at the wire</b> -- the provider's own <code>error.message</code> reaches a client in
/// <code>detail.providerText</code>, and no other member of the refusal body does.</p>
/// <p>Asserted on the <b>rendered</b> envelope rather than on the fault object
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> hands back, because
/// <method>OcuPilot.Api.Error.Render</method> takes its detail as an optional argument and omits
/// the key silently when none is supplied: a call site that stopped passing it would leave every
/// in-process assertion green while the one text Story 3.5's failure sentence is built from
/// stopped leaving the instance.</p>
/// <p>Mutation: drop the <code>tFault.detail</code> argument from
/// <method>OcuPilot.Api.Definitions.HandleTest</method>'s <method>Api.Error.Render</method> call
/// -- this goes red, the captured envelope carrying no <code>detail</code> at all.</p>
Method TestTheShippedHandlerRendersTheProviderTextOverTheWire()
{
    Set tId = ..HandlerDefinition("Handler502")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, ..#REFUSALBODY)

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions/" _ tId _ "/test", "POST", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch through the shipped, inherited HandleTest completes")
    Do $$$AssertEquals(tStatus, 502, "and answers the gateway failure: " _ tBody)
    Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue($IsObject(tEnvelope), "the captured envelope parses as JSON")
    If '$IsObject(tEnvelope) Quit
    Do $$$AssertEquals(tEnvelope.code, "PROVIDER.REFUSED", "with the refusal code")
    Do $$$AssertEquals($Select($IsObject(tEnvelope.detail): tEnvelope.detail.providerText, 1: ""), "invalid x-api-key", "carrying the provider's own error.message through the render, not only through the fault: " _ tBody)
    Do $$$AssertEquals(tBody [ ..#RAWMARKER, 0, "and no other member of the raw body, which goes to the log alone")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and no flag changed")
}

/// <p>A body that parsed but is not a JSON object is refused 400 on its own stage, before any
/// call. A top-level array answers <method>%IsDefined</method> for every key with its element 0,
/// so without the guard <method>OcuPilot.Api.Definitions.MergeBody</method> would write that one
/// element over every writable field and the caller would be told which of them the validator
/// disliked.</p>
/// <p>Mutation: delete the <method>OcuPilot.Api.Definitions.BodyIsReadable</method> branch from
/// <method>OcuPilot.Api.Definitions.HandleTest</method> -- this goes red at 422, the violations
/// naming fields the caller never sent.</p>
Method TestABodyThatIsNotAnObjectIsRefusedBeforeAnyCall()
{
    Set tId = ..WireDefinition("BadBody")
    If tId = "" Quit
    Set tSC = ..Call("POST", "/" _ tId _ "/test", "[""x"",""y""]", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "and is refused as an unreadable body rather than validated field by field: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "AGENT.BADBODY", "with the bad-body code")
    Do $$$AssertEquals(..FlagsOf(tId), "0|0", "and no flag changed")
}

/// <p>The arrangement both fixture-route legs need: a stored definition naming the real
/// <code>anthropic</code> key -- the only one
/// <method>OcuPilot.Kernel.AgentRules.Validate</method> accepts, since it reads the real,
/// unsubclassed <class>OcuPilot.Kernel.Provider.Catalog</class> by hard class name -- with
/// <class>OcuPilot.Test.CatalogAnthropicStub</class> switched in so that row's adapter is the
/// transport stub and no socket is opened. Answers the id, or <code>""</code>.</p>
/// <p>The switch is a process-private global and
/// <method>OcuPilot.Test.ProviderPortProbe.Reset</method> clears it before and after every
/// method, so no other method, class or process can see it.</p>
Method HandlerDefinition(pSuffix As %String) As %String
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetCatalogClass("OcuPilot.Test.CatalogAnthropicStub")
    ; The row's keyPrefix is untouched by the stub swap -- still the real "sk-ant-" -- so the
    ; resolved credential must be shaped like one or the shape gate refuses before the stub is
    ; ever reached.
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("sk-ant-" _ ..#PROBEKEY)
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ pSuffix
    Set tRow.Provider = "anthropic"
    Set tRow.Model = "claude-opus-5"
    Set tRow.EndpointUrl = ..#PUBLICENDPOINT
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tCreateSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tCreateSC, pSuffix _ ": a stored definition naming the real provider key is created")
    If $$$ISERR(tCreateSC) Quit ""
    Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

/// <p><b>DW-361</b> -- "the provider answered and the flag could not be written" answers 500 with
/// no answer body, rather than reporting <code>connected: true, connectionVerified: 1</code> for
/// a state that was never recorded.</p>
/// <p>Forced by a genuine race rather than a new seam: the row is removed between the read that
/// captures <var>tStored</var> -- the same arrangement <method>Outcome</method> makes -- and the
/// call into <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>, so
/// <method>OcuPilot.Kernel.State.Agent.GuardedSetVerification</method>, which opens the row
/// fresh, fails on a row that is genuinely gone.</p>
/// <p>Mutation: stop returning on <code>tWriteSC</code>'s failure in
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> (swallow it instead of building
/// the fault) -- this goes red, answering an object carrying <code>connected: true</code> and
/// <code>connectionVerified: 1</code> for a row that no longer exists.</p>
Method TestTheVerificationWriteFailingAnswersFiveHundredAndNoAnswerBody()
{
    Set tId = ..ProbeDefinition("WriteRace")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)

    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow)
    Do $$$AssertStatusOK(tOpenSC, "the row opens")
    Do ##class(OcuPilot.Test.DefinitionsProbe).ValuesFromRow(tRow, .tStored)
    Set tRow = ""
    Kill tValues
    Merge tValues = tStored
    Set tValues("connectionVerified") = $Get(tStored("connectionVerified"))
    Set tValues("enabled") = $Get(tStored("enabled"))
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)

    Set tDeleteSC = ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tId)
    Do $$$AssertStatusOK(tDeleteSC, "the row is deleted between the read and the verification write, standing in for the race")

    Do ##class(OcuPilot.Test.DefinitionsProbe).ConnectionOutcome(tId, .tValues, .tStored, .tAnswer, .tHttpStatus, .tFault)
    Do $$$AssertTrue('$IsObject(tAnswer), "no answer body is produced -- the operator is not told the connection works")
    Do $$$AssertTrue($IsObject(tFault), "a fault is, instead")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tHttpStatus, 500, "reported as a server error, not a gateway failure")
    Do $$$AssertEquals(tFault.code, "INTERNAL", "with the internal code")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedExistsId(tId, .tStillGone), "the existence check itself succeeds")
    Do $$$AssertEquals(tStillGone, 0, "and the row really is gone, so a 200 here would have reported success for nothing")
}

/// <p>One request to the definitions surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/agent/definitions" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>Create one definition over the wire on the <b>shipped</b> provider row -- the wire legs go
/// through the production handler and the production port -- and return its id, or
/// <code>""</code>.</p>
Method WireDefinition(pSuffix As %String, pEnvVar As %String = "ANTHROPIC_API_KEY") As %String
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ pSuffix _ """,""provider"":""anthropic"",""endpointUrl"":""" _ ..#PUBLICENDPOINT _ """,""credType"":""env"",""envVarName"":""" _ pEnvVar _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created (" _ tBody _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody).id
}

/// <p><var>pObject</var>'s keys, in order, comma-separated -- so an answer can be asserted for
/// what it does <b>not</b> carry as well as for what it does.</p>
ClassMethod KeysOf(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

}
