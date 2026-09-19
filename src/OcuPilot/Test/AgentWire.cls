/// <p>AC8 (the Integration AC) and the eight routes over HTTP -- the claim is about what a consumer
/// receives from the shipped router, so every assertion here is made against a real response, not
/// against the state class.</p>
/// <p>Also pins the change record every accepted write produces: the changed-field set with its
/// old and new values, and the credential reference arriving <code>[redacted]</code>. That half is
/// driven <b>in process</b>, through <class>OcuPilot.Test.DefinitionsProbe</class>, because the
/// line an HTTP request produces is emitted inside the web worker's process where a
/// process-private capture cannot reach it. It is the real
/// <method>OcuPilot.Api.Definitions.LogChange</method> that runs, so the computation, the
/// subsystem name and the redaction are all the shipped ones. <b>That a handler emits the record
/// at all</b> is pinned over the wire instead, by writing through a route and reading the
/// console-log page back.</p>
/// <p>Every definition this class creates is named with <parameter>PROBEPREFIX</parameter> and
/// removed in <method>OnAfterOneTest</method>, which then asserts none survives.</p>
Class OcuPilot.Test.AgentWire Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>Clear any definition a previous method left behind, so a create's "this is the first
/// definition" outcome means what it says.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Remove every definition this class created and assert none survives.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>One request to the definitions surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/agent/definitions" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>The eight routes are declared in the shipped router, longest first. The route literals are
/// asserted against <class>OcuPilot.Api.Router</class>'s own <code>UrlMap</code>, so a route
/// renamed or dropped is caught here as well as by the requests below.</p>
/// <p><b>This is the canonical roster</b>: every route the map declares under
/// <code>/agent/definitions</code> is listed, Story 3.3's credential store included, so a route
/// added without a line here is a route this assertion does not cover.</p>
Method TestEveryDefinitionRouteIsDeclaredInTheRouter()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    Do $$$AssertTrue($IsObject(tXData), "the router's UrlMap is readable")
    If '$IsObject(tXData) Quit
    Do tXData.Data.Rewind()
    Set tMap = tXData.Data.Read(32000)
    For tRoute = "<Route Url=""/agent/definitions/:id/default"" Method=""POST""", "<Route Url=""/agent/definitions/:id/credential"" Method=""POST""", "<Route Url=""/agent/definitions/:id/test"" Method=""POST""", "<Route Url=""/agent/definitions/:id"" Method=""GET""", "<Route Url=""/agent/definitions/:id"" Method=""PUT""", "<Route Url=""/agent/definitions/:id"" Method=""DELETE""", "<Route Url=""/agent/definitions"" Method=""GET""", "<Route Url=""/agent/definitions"" Method=""POST""" {
        Do $$$AssertTrue(tMap [ tRoute, "the router declares " _ tRoute)
    }
    Do $$$AssertTrue($Find(tMap, "/agent/definitions/:id/default") < $Find(tMap, """/agent/definitions/:id"""), "the four-segment routes precede the three-segment ones")
    Do $$$AssertTrue($Find(tMap, "/agent/definitions/:id/credential") < $Find(tMap, """/agent/definitions/:id"""), "the credential store among them")
    Do $$$AssertTrue($Find(tMap, "/agent/definitions/:id/test") < $Find(tMap, """/agent/definitions/:id"""), "and Story 3.4's connection test")
    Do $$$AssertTrue($Find(tMap, """/agent/definitions/:id""") < $Find(tMap, """/agent/definitions"" Method=""GET"""), "which precedes the two-segment one")
}

/// <p>AC8, first half -- a create whose body breaks four rules answers <b>one</b> 422 carrying
/// four <code>{field, code, reason}</code> violations in declared order, and writes nothing.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.AgentRules.Validate</method> quit after the first
/// violation -- this goes red, the response carrying one violation instead of four.</p>
Method TestACreateBreakingFourRulesAnswersOneEnvelopeAndWritesNothing()
{
    Set tBefore = ##class(OcuPilot.Test.AgentFixture).ProbeCount()
    Do $$$AssertEquals(tBefore, 0, "no probe definition exists before the refused create")

    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Four"",""provider"":""nosuchprovider"",""maxTokens"":99000,""temperature"":3,""credType"":""env"",""credentialName"":""OcuPilotAnthropic""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused as a validation failure")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.error, "validation_failed", "on the validation_failed slug")
    Do $$$AssertEquals(tAnswer.code, "AGENT.VALIDATION", "with the agent validation code")
    Do $$$AssertTrue($IsObject(tAnswer.detail), "and a detail object")
    If '$IsObject(tAnswer.detail) Quit
    Do $$$AssertEquals(tAnswer.detail.violations.%Size(), 4, "carrying four violations, not one: " _ tAnswer.detail.violations.%ToJSON())
    Do $$$AssertEquals(tAnswer.detail.violations.%ToJSON(), ..ViolationsText($ListBuild($ListBuild("provider", "AGENT.PROVIDER.UNKNOWN"), $ListBuild("maxTokens", "AGENT.MAXTOKENS.RANGE"), $ListBuild("temperature", "AGENT.TEMPERATURE.RANGE"), $ListBuild("envVarName", "AGENT.ENVVAR.REQUIRED"))), "in declared rule order, each naming its field")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), tBefore, "and the refused create wrote nothing")
}

/// <p>AC8, second half -- a sound create answers 201 with the full projection, disabled and
/// carrying the default marker because it is the first definition, and
/// <code>GET /agent/definitions</code> returns it immediately with exactly the six selection
/// keys.</p>
Method TestASoundCreateIsReturnedByTheListImmediately()
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Sound"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 201, "and answers 201 Created")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type")
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tCreated.enabled, 0, "the definition is created disabled")
    Do $$$AssertEquals(tCreated.connectionVerified, 0, "and unverified")
    Do $$$AssertEquals(tCreated.default, 1, "and takes the default marker, being the first definition")
    Do $$$AssertEquals(tCreated.model, "claude-opus-5", "the omitted model takes the provider row's canonical value")
    Do $$$AssertEquals(tCreated.endpointUrl, "https://api.anthropic.com/v1/messages", "and so does the omitted endpoint")
    Do $$$AssertEquals(tCreated.credentialName, "", "the unselected credential reference is stored empty")
    Do $$$AssertEquals(tCreated.readOnly, 1, "a definition is created read-only, which is the safe default Story 3.7 enforces")
    Do $$$AssertEquals(tCreated.retentionDays, 30, "with the settled retention default")
    Do $$$AssertEquals(tCreated.maxIterationsPerTurn, 10, "and the settled per-turn iteration ceiling")
    Do $$$AssertEquals(..KeysOf(tCreated), "id,name,provider,model,endpointUrl,markedLocal,credType,envVarName,credentialName,maxTokens,temperature,maxIterationsPerTurn,systemPromptOverride,readOnly,retentionDays,enabled,connectionVerified,createdAt,updatedAt,default", "the full projection carries exactly these keys, and no key that could hold a credential value")

    Set tSC2 = ..Call("GET", "", "", .tListStatus, .tListBody, .tListHeaders)
    Do $$$AssertStatusOK(tSC2, "the list request completes")
    Do $$$AssertEquals(tListStatus, 200, "and answers")
    Do $$$AssertEquals($ZConvert($Get(tListHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tList = ##class(%DynamicObject).%FromJSON(tListBody)
    Do $$$AssertEquals(tList.definitions.%Size(), 1, "the list returns the definition immediately")
    If tList.definitions.%Size() '= 1 Quit
    Set tEntry = tList.definitions.%Get(0)
    Do $$$AssertEquals(..KeysOf(tEntry), "id,name,provider,model,enabled,default", "carrying exactly the six selection keys and nothing else")
    Do $$$AssertEquals(tEntry.id, tCreated.id, "the same definition the create returned")
    Do $$$AssertEquals(tEntry.default, 1, "listed as the default")
    Do $$$AssertEquals(tEntry.enabled, 0, "and as disabled")

    Do ..Call("PUT", "/" _ tCreated.id, "{""model"":""5""}", .tPutStatus, .tPutBody, .tPutHeaders)
    Do $$$AssertEquals(tPutStatus, 200, "a model that reads as a number is accepted")
    Do ..Call("GET", "", "", .tReStatus, .tReBody, .tReHeaders)
    Set tReEntry = ##class(%DynamicObject).%FromJSON(tReBody).definitions.%Get(0)
    Do $$$AssertEquals(tReEntry.%GetTypeOf("model"), "string", "and the selection projection types it as the full projection does, so a client reading one against the other does not meet a number here and a string there")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tPutBody).%GetTypeOf("model"), "string", "which is the type the full projection gives it")
}

/// <p>The remaining four routes over the wire: the single read, the update, the default move and
/// the delete. The update is a <b>merge</b> -- a one-key body changes that field and leaves the
/// rest -- and moving the marker to the second definition clears it from the first.</p>
Method TestReadUpdateSetDefaultAndDeleteOverTheWire()
{
    Set tFirst = ..CreateDefinition("One")
    Set tSecond = ..CreateDefinition("Two")
    If (tFirst = "") || (tSecond = "") Quit
    ; Both enabled before the marker is moved: DW-330 refuses an explicit set-default onto a
    ; definition that is not enabled, and enabling one over the wire would need a provider call
    ; (create, store the key, Test connection, then PUT enabled) -- which no test in this class may
    ; make. The fixture writes the two flags directly instead.
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tFirst, 1, 1), "the first definition is enabled and verified")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tSecond, 1, 1), "and so is the second")

    Set tSC = ..Call("GET", "/" _ tFirst, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the single read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tRead = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tRead.name, ..#PROBEPREFIX _ "One", "returning the definition asked for")
    Do $$$AssertEquals(tRead.default, 1, "which carries the marker, being the first")

    Set tSC = ..Call("PUT", "/" _ tFirst, "{""model"":""claude-sonnet-5""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the update completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tUpdated = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tUpdated.model, "claude-sonnet-5", "the model is changed")
    Do $$$AssertEquals(tUpdated.envVarName, "ANTHROPIC_API_KEY", "and the fields the body omitted are kept, so a PUT merges rather than replaces")
    Do $$$AssertTrue(tUpdated.updatedAt '= "", "the update stamps a timestamp")

    Set tSC = ..Call("POST", "/" _ tSecond _ "/default", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the default move completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).default, 1, "the second definition is now the default")
    Do ..Call("GET", "/" _ tFirst, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).default, 0, "and the first is not")

    Set tSC = ..Call("DELETE", "/" _ tSecond, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the delete completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).deleted, 1, "reporting the deletion")
    Do ..Call("GET", "/" _ tFirst, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).default, 1, "and the marker falls back to the remaining definition")
}

/// <p>An id no definition holds is a named 404 on every route that takes one -- never a 500, and
/// never an empty 200.</p>
Method TestAnUnknownIdAnswers404OnEveryRouteThatTakesOne()
{
    For tCase = "GET|/999999999", "PUT|/999999999", "DELETE|/999999999", "POST|/999999999/default", "POST|/999999999/credential", "POST|/999999999/test" {
        Set tSC = ..Call($Piece(tCase, "|", 1), $Piece(tCase, "|", 2), "", .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tCase _ ": the request completes")
        Do $$$AssertEquals(tStatus, 404, tCase _ ": answers 404")
        Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, tCase _ ": as JSON")
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "AGENT.NOTFOUND", tCase _ ": with the agent not-found code")
    }
}

/// <p>A body that cannot be parsed is a 400 carrying
/// <parameter>OcuPilot.Api.Error.REASONAGENTBADBODY</parameter> and nothing else: the raw
/// <class>%Status</class> is vendor-shaped text and reaches the log only (AD-39).</p>
/// <p>Mutation (Rule 19): re-append
/// <code>_ $System.Status.GetErrorText(pStatus)</code> to
/// <method>OcuPilot.Api.Definitions.RenderBadBody</method>'s reason -- the equality assertion and
/// both vendor-text assertions go red.</p>
Method TestAMalformedBodyAnswers400WithItsWrittenSentenceAlone()
{
    Set tSC = ..Call("POST", "", "{not json", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "and is refused")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.error, "bad_request", "on the bad_request slug")
    Do $$$AssertEquals(tAnswer.code, "AGENT.BADBODY", "with the bad-body code")
    Do $$$AssertEquals(tAnswer.reason, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, "and the written sentence alone: " _ tAnswer.reason)
    Do $$$AssertTrue(tAnswer.reason '[ "<THROW>", "with no vendor exception text: " _ tAnswer.reason)
    Do $$$AssertTrue(tAnswer.reason '[ "%Library", "and no vendor class name: " _ tAnswer.reason)
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), 0, "and nothing was written")
}

/// <p>The change record an accepted write produces -- the seam that writes both the log line and
/// the audit row. Each changed
/// field carries its old and new value, and the credential reference arrives
/// <code>[redacted]</code>, because <parameter>OcuPilot.Kernel.Audit.Log.CREDENTIALEXACTNAMES</parameter>
/// lists <code>credentialname</code> and the record is keyed by field name.</p>
/// <p>The redaction is the desired behaviour, not an obstacle: an audit trail of definition
/// changes is read on OcuPilot's own log screens and by the agent (AD-35, AD-46), so the field
/// that names where a secret comes from is masked there while the definition's own projection
/// still carries it.</p>
Method TestTheChangeRecordCarriesOldAndNewAndRedactsTheCredentialReference()
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Kill tBefore, tAfter
    Set tBefore("model") = "claude-opus-5"
    Set tBefore("credentialName") = "OcuPilotAnthropic"
    Set tBefore("enabled") = 1
    Set tAfter("model") = "claude-sonnet-5"
    Set tAfter("credentialName") = "OcuPilotOther"
    Set tAfter("enabled") = 1

    Set tChanges = ##class(OcuPilot.Api.Definitions).ChangeSet(.tBefore, .tAfter)
    Do $$$AssertEquals(tChanges.%ToJSON(), "{""model"":{""old"":""claude-opus-5"",""new"":""claude-sonnet-5""},""credentialName"":{""old"":""OcuPilotAnthropic"",""new"":""OcuPilotOther""}}", "the changed-field set carries each changed field with its old and new value, and nothing unchanged")

    Do ##class(OcuPilot.Test.DefinitionsProbe).LogChange("update", "4242", .tBefore, .tAfter)
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine '= "", "the change record reached the log seam")
    Do $$$AssertTrue(tLine [ """subsystem"":""agent-definition""", "under the agent-definition subsystem: " _ tLine)
    Do $$$AssertTrue(tLine [ """msg"":""update""", "naming the verb")
    Do $$$AssertTrue(tLine [ """id"":""4242""", "and the definition it is about")
    Do $$$AssertTrue(tLine [ """model"":{""old"":""claude-opus-5"",""new"":""claude-sonnet-5""}", "the model change is carried in full")
    Do $$$AssertTrue(tLine [ """credentialName"":""[redacted]""", "and the credential reference is redacted by name: " _ tLine)
    Do $$$AssertEquals(tLine [ "OcuPilotAnthropic", 0, "so the old credential reference does not reach the log")
    Do $$$AssertEquals(tLine [ "OcuPilotOther", 0, "and neither does the new one")
    Do $$$AssertTrue(tLine [ """securityChange"":true", "and the record classifies itself as a security change, the credential reference being one: " _ tLine)

    ; The other direction. Without it, "carries securityChange" would be satisfied by a classifier
    ; that answered 1 for everything -- which is also what the conservative Catch answers, so a
    ; classification that could never be computed would read as a passing one.
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Kill tPlainBefore, tPlainAfter
    Set tPlainBefore("model") = "claude-opus-5"
    Set tPlainAfter("model") = "claude-sonnet-5"
    Do ##class(OcuPilot.Test.DefinitionsProbe).LogChange("update", "4243", .tPlainBefore, .tPlainAfter)
    Set tPlainLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tPlainLine [ """securityChange"":false", "while a model-only change is not classified as one: " _ tPlainLine)
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p><b>AC4's field half over the wire</b> -- the surface the matrix states it at: a create whose
/// endpoint resolves to loopback, on a provider whose catalog row forbids a local address, answers
/// <b>one</b> 422 carrying the address violation on <code>endpointUrl</code>, the local-unsupported
/// violation on <code>markedLocal</code>, and every unrelated violation beside them, in one round
/// trip.</p>
/// <p>It is also the only test that sends <code>markedLocal</code> over the wire at all, so it is
/// what pins the field as writable through <method>OcuPilot.Api.Definitions.Fields</method>.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.AgentRules.Validate</method> quit after the first
/// violation -- this goes red, the response carrying one violation instead of three.</p>
Method TestACreateNamingARefusedAddressAnswersOneEnvelopeWithEveryViolation()
{
    Set tBefore = ##class(OcuPilot.Test.AgentFixture).ProbeCount()
    Do $$$AssertEquals(tBefore, 0, "no probe definition exists before the refused create")

    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Local"",""provider"":""anthropic"",""endpointUrl"":""https://127.0.0.1/v1"",""markedLocal"":true,""maxTokens"":99000,""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused as a validation failure: " _ tBody)
    Set tViolations = ..ViolationsOf(tBody)
    Do $$$AssertTrue(tViolations [ """field"":""endpointUrl"",""code"":""AGENT.ENDPOINT.ADDRESS""", "the loopback endpoint is refused on its own field: " _ tViolations)
    Do $$$AssertTrue(tViolations [ """field"":""markedLocal"",""code"":""AGENT.LOCAL.UNSUPPORTED""", "the local escape is refused on its own field, the shipped row not allowing one: " _ tViolations)
    Do $$$AssertTrue(tViolations [ """field"":""maxTokens""", "and an unrelated violation rides in the same envelope rather than waiting for a second round trip: " _ tViolations)
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), tBefore, "and the refused create wrote nothing")

    ; Link-local has no escape at all, so marking the definition local buys nothing here either.
    Set tSC2 = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Meta"",""provider"":""anthropic"",""endpointUrl"":""https://169.254.169.254/latest/meta-data"",""markedLocal"":true,""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the second create request completes")
    Do $$$AssertEquals(tStatus2, 422, "and is refused too: " _ tBody2)
    Set tViolations2 = ..ViolationsOf(tBody2)
    Do $$$AssertTrue(tViolations2 [ """field"":""endpointUrl"",""code"":""AGENT.ENDPOINT.LINKLOCAL""", "the metadata range is told apart from every other refused address: " _ tViolations2)
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), tBefore, "and it wrote nothing either")
}

/// <p>The change record an accepted write produces <b>through the shipped handler</b>, read back
/// from the console log over the wire: a create over HTTP is followed by
/// <code>GET /api/ocupilot/logs/messages</code>, whose tail must carry the line the handler
/// emitted, under the agent-definition subsystem, naming the verb and the definition it is
/// about.</p>
/// <p><b>This is what makes all four <method>OcuPilot.Api.Definitions.LogChange</method> call
/// sites falsifiable</b>, so each of the four verbs is driven over HTTP and looked for by name.
/// The in-process leg above exercises the record's shape and its redaction, but it calls
/// <method>LogChange</method> itself -- so deleting the call from any handler would leave it
/// green. Here the only thing that puts a line in the log is the handler.</p>
/// <p>The verbs are driven on one definition, with a second definition created first so the
/// set-default is a real move of the marker rather than a re-assertion of it.</p>
/// <p>Mutation: delete the <method>LogChange</method> line from
/// <method>OcuPilot.Api.Definitions.HandleCreate</method>,
/// <method>HandleUpdate</method>, <method>HandleDelete</method> or
/// <method>HandleSetDefault</method> -- this goes red naming the verb whose record is missing.</p>
Method TestAnAcceptedWriteEmitsItsChangeRecordFromTheHandler()
{
    Set tHolder = ..CreateDefinition("LogHolder")
    Set tId = ..CreateDefinition("Logged")
    If (tHolder = "") || (tId = "") Quit
    ; Both enabled, so the set-default is accepted at all: DW-330 refuses one onto a definition
    ; that is not enabled, and enabling one over the wire would need a provider call this class
    ; may not make.
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tHolder, 1, 1), "the marker holder is enabled and verified")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "and so is the definition the records are expected for")

    Do ..Call("PUT", "/" _ tId, "{""model"":""claude-sonnet-5""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the update the record is expected for is accepted")
    Do ..Call("POST", "/" _ tId _ "/default", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "and the default move")
    Do ..Call("DELETE", "/" _ tId, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "and the delete")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIBASE _ "/logs/messages", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the console-log page request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tPage.lines.%Size() > 0, "the log page carries lines: " _ tPage.lines.%Size())

    Kill tFound
    Set tIterator = tPage.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If tLine '[ """subsystem"":""agent-definition""" Continue
        If tLine '[ ("""id"":""" _ tId _ """") Continue
        For tVerb = "create", "update", "default", "delete" {
            If tLine [ ("""msg"":""" _ tVerb _ """") Set tFound(tVerb) = tLine
        }
    }
    For tVerb = "create", "update", "default", "delete" {
        Do $$$AssertTrue($Data(tFound(tVerb)), "the handler's own change record for the " _ tVerb _ " of definition " _ tId _ " is in the console log, under the agent-definition subsystem")
    }
    If $Data(tFound("create")) Do $$$AssertTrue(tFound("create") [ """name""", "the create record carries the changed-field set: " _ tFound("create"))
    If $Data(tFound("update")) Do $$$AssertTrue(tFound("update") [ """model""", "the update record names the field that changed: " _ tFound("update"))
    If $Data(tFound("default")) Do $$$AssertTrue(tFound("default") [ """default""", "the default record names the marker move: " _ tFound("default"))
}

/// <p>AC5 <b>at the tier a client can reach</b>: a <code>PUT</code> that changes the endpoint of
/// an enabled, verified definition answers a projection whose <code>enabled</code> and
/// <code>connectionVerified</code> are both 0, and a <code>PUT</code> that changes only the model
/// leaves both at 1.</p>
/// <p>The state class's own legs are <class>OcuPilot.Test.AgentState</class>'s. What this adds is
/// the handler's half of the contract: it must snapshot the security fields <b>before</b> it
/// applies the body, and a snapshot taken afterwards would compare the new values against
/// themselves and disable nothing.</p>
/// <p>The definition is arranged through <class>OcuPilot.Test.AgentFixture</class>, because the
/// API refuses an enable while a definition is unverified and only Story 3.4 verifies one.</p>
Method TestASecurityChangeOverTheWireDisablesAndAModelChangeDoesNot()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Live", 1, 1, .tRow)
    Do $$$AssertStatusOK(tSC, "an enabled, verified definition is arranged")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""

    Set tSC = ..Call("PUT", "/" _ tId, "{""endpointUrl"":""https://other.example.com/v1""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the endpoint change completes")
    Do $$$AssertEquals(tStatus, 200, "and answers: " _ tBody)
    If tStatus '= 200 Quit
    Set tAfter = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAfter.endpointUrl, "https://other.example.com/v1", "the endpoint is changed")
    Do $$$AssertEquals(tAfter.enabled, 0, "and the definition is disabled by it")
    Do $$$AssertEquals(tAfter.connectionVerified, 0, "and its verification cleared")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified again")
    Set tSC = ..Call("PUT", "/" _ tId, "{""model"":""claude-sonnet-5""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the model change completes")
    Do $$$AssertEquals(tStatus, 200, "and answers: " _ tBody)
    If tStatus '= 200 Quit
    Set tModelChanged = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tModelChanged.model, "claude-sonnet-5", "the model is changed")
    Do $$$AssertEquals(tModelChanged.enabled, 1, "and the definition stays enabled")
    Do $$$AssertEquals(tModelChanged.connectionVerified, 1, "and stays verified")
}

/// <p>The provider row's canonical values fill only the keys the body omitted. Driven through
/// <class>OcuPilot.Test.DefinitionsProbe</class>'s catalog seam against
/// <class>OcuPilot.Test.CatalogProbe</class>'s row, whose maximum tokens and temperature are
/// 8000 and 1: against the shipped row both equal the state class's own
/// <code>InitialExpression</code>, so those two fallbacks could be deleted from
/// <method>OcuPilot.Api.Definitions.CatalogDefaults</method> without moving an assertion.</p>
/// <p>Mutation: delete the <code>maxTokens</code> or <code>temperature</code> entry from that
/// list -- the value stays at the class default and this goes red.</p>
Method TestTheCatalogFallbackFillsOnlyTheKeysTheBodyOmitted()
{
    Kill tValues, tPresent
    Set tValues("provider") = ##class(OcuPilot.Test.CatalogProbe).#PROBEKEY
    Set tValues("model") = "an-explicitly-chosen-model"
    Set tValues("maxTokens") = 32000
    Set tValues("temperature") = 0
    Set tPresent("model") = 1
    Do ##class(OcuPilot.Test.DefinitionsProbe).ApplyCatalogDefaults(.tValues, .tPresent)
    Do $$$AssertEquals(tValues("maxTokens"), 8000, "the omitted maximum tokens takes the provider row's canonical value, not the class default")
    Do $$$AssertEquals(tValues("temperature"), 1, "and so does the omitted temperature")
    Do $$$AssertEquals(tValues("model"), "an-explicitly-chosen-model", "while the key the body supplied is left alone")

    Kill tUnknown
    Set tUnknown("provider") = "no-such-provider"
    Set tUnknown("maxTokens") = 32000
    Do ##class(OcuPilot.Test.DefinitionsProbe).ApplyCatalogDefaults(.tUnknown, .tNone)
    Do $$$AssertEquals(tUnknown("maxTokens"), 32000, "a provider with no row changes nothing -- rule 2 is what refuses it")
}

/// <p>Two matrix rows phrased as HTTP outcomes rather than as validator calls: enabling an
/// unverified definition, and a name an existing definition already holds. Both are 422s carrying
/// one violation on the field the caller sent.</p>
Method TestAFailingUpdateAndADuplicateNameAreRefusedOverTheWire()
{
    Set tId = ..CreateDefinition("Unverified")
    If tId = "" Quit

    Set tSC = ..Call("PUT", "/" _ tId, "{""enabled"":true}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the enable request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused, the definition being unverified: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(..ViolationsOf(tBody), ..ViolationsText($ListBuild($ListBuild("enabled", "AGENT.ENABLE.UNVERIFIED"))), "with one violation on the enabled field")

    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Unverified"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the duplicate create completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused rather than failing on the unique index: " _ tBody)
    Do $$$AssertEquals(..ViolationsOf(tBody), ..ViolationsText($ListBuild($ListBuild("name", "AGENT.NAME.DUPLICATE"))), "with one violation on the name field")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), 1, "and no second definition was written")
}

/// <p><b>DW-330</b> -- an explicit set-default onto a definition that is not enabled is refused
/// with <code>AGENT.DEFAULT.DISABLED</code> on the field <code>default</code>, and the marker does
/// not move. The marker names the definition in force, and a disabled one is not in force.</p>
/// <p>Mutation: remove the guard from <method>OcuPilot.Api.Definitions.HandleSetDefault</method> --
/// this goes red at 500, the state layer's own refusal arriving as an internal error; remove the
/// guard from <method>OcuPilot.Kernel.State.Agent.SetDefaultGuarded</method> as well and it goes
/// red at 200 with the marker moved, which is what shows the two checks are independent rather
/// than one written twice.</p>
Method TestAnExplicitSetDefaultOntoADisabledDefinitionIsRefused()
{
    Set tEnabled = ..CreateDefinition("MarkerHolder")
    Set tDisabled = ..CreateDefinition("MarkerRefused")
    If (tEnabled = "") || (tDisabled = "") Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tEnabled, 1, 1), "the first definition is enabled and verified, and holds the marker")

    Set tSC = ..Call("POST", "/" _ tDisabled _ "/default", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the set-default request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused, the definition not being enabled: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(..ViolationsOf(tBody), ..ViolationsText($ListBuild($ListBuild("default", "AGENT.DEFAULT.DISABLED"))), "with one violation on the default field")

    Do ..Call("GET", "/" _ tEnabled, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).default, 1, "the enabled definition still carries the marker")
    Do ..Call("GET", "/" _ tDisabled, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).default, 0, "and the refused one did not take it")
}

/// <p>A key sent as <code>""</code> is an explicit empty value, which is the contract the class
/// header publishes: the catalog does not backfill it on a create, and an update takes it
/// verbatim rather than reading it as an omission.</p>
Method TestAnEmptyStringIsAnExplicitValueAndNotAnOmission()
{
    Set tId = ..CreateDefinition("Explicit")
    If tId = "" Quit
    Set tSC = ..Call("PUT", "/" _ tId, "{""endpointUrl"":""""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the update completes")
    Do $$$AssertEquals(tStatus, 200, "and answers: " _ tBody)
    If tStatus '= 200 Quit
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).endpointUrl, "", "the endpoint is cleared rather than left at its stored value")
    Do ..Call("GET", "/" _ tId, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).endpointUrl, "", "and a re-read shows it cleared")

    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Blank"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY"",""endpointUrl"":""""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create completes")
    Do $$$AssertEquals(tStatus, 201, "and is accepted: " _ tBody)
    If tStatus '= 201 Quit
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).endpointUrl, "", "an endpoint sent as an empty string is not backfilled from the catalog")
}

/// <p>A fractional temperature round trips: <property>OcuPilot.Kernel.State.Agent.Temperature</property>
/// is <code>%Numeric(SCALE = 2)</code> while the range rule admits more precision, so a value
/// with three decimals is stored rounded -- and what the create answers is what a later read
/// gives, rather than the value as sent.</p>
Method TestAFractionalTemperatureRoundTrips()
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Temp"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY"",""temperature"":0.755}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create completes")
    Do $$$AssertEquals(tStatus, 201, "and is accepted: " _ tBody)
    If tStatus '= 201 Quit
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tCreated.temperature, 0.76, "the create answers the value as the column stores it, rounded to two decimals: " _ tCreated.temperature)

    Do ..Call("GET", "/" _ tCreated.id, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the re-read answers")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).temperature, tCreated.temperature, "with the same temperature the create did, so the create's projection is not the value as sent")
}

/// <p>A body whose shape is not a map of scalar fields is refused rather than stored. A
/// <b>top-level array</b> answers <method>%IsDefined</method> for every key with its element 0,
/// which would set every writable field to the same value; a field whose value is an
/// <b>object</b> arrives as an OREF that stringifies to
/// <code>&lt;n&gt;@%Library.DynamicObject</code> -- twenty-seven characters that pass the name
/// rule; and a <b>flag sent as a quoted string</b> is not a JSON boolean, so it is ignored rather
/// than coerced -- <code>+"true"</code> and <code>+"false"</code> are both 0, and 0 on
/// <code>readOnly</code> is the permissive answer.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Definitions.BodyIsReadable</method> answer 1
/// unconditionally, and the array leg answers 201; drop the object/array skip in
/// <method>OcuPilot.Api.Definitions.MergeBody</method>, and the object leg answers 201 with an
/// OREF for a name.</p>
Method TestABodyThatIsNotAMapOfScalarsIsRefused()
{
    Set tSC = ..Call("POST", "", "[""x"",""y""]", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the array-bodied create completes")
    Do $$$AssertEquals(tStatus, 400, "and is refused as a bad body: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "AGENT.BADBODY", "with the bad-body code")

    Set tSC = ..Call("POST", "", "{""name"":{""a"":1},""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the object-valued field create completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused: the field is skipped, so the name is missing rather than an OREF: " _ tBody)
    Do $$$AssertEquals(..ViolationsOf(tBody), ..ViolationsText($ListBuild($ListBuild("name", "AGENT.NAME.REQUIRED"))), "with one violation on the name field")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), 0, "and neither body wrote a definition")

    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Quoted"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY"",""readOnly"":""false""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the quoted-flag create completes")
    Do $$$AssertEquals(tStatus, 201, "and is accepted: " _ tBody)
    If tStatus '= 201 Quit
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).readOnly, 1, "with the flag left at its safe default, because a quoted flag is not a JSON boolean and +""false"" is 0 whatever the caller meant")
}

/// <p>The unverified risk the follow-up review named: <method>OcuPilot.Api.Definitions.BodyIsReadable</method>
/// deliberately admits an <b>absent</b> body -- distinct from a body that parsed but is not an
/// object, which the array/object leg above already refuses -- so a create with no body falls to
/// the rules and an update with no body changes nothing (DW-24). Neither half had a test of its
/// own; the array/object leg never sends a request with no body at all.</p>
/// <p>Sending <code>pBody</code> as <code>""</code> to <class>OcuPilot.Test.Http</class>'s
/// <method>AbsoluteRequest</method> reproduces a genuinely bodyless request: its own guard
/// (<code>If pRequestBody '= ""</code>) skips both <code>EntityBody.Write</code> and
/// <code>ContentType</code>, so no stream and no content-type header are sent -- exactly what
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> reads as "no body" rather than as a
/// zero-length one.</p>
/// <p>Mutation: change <method>BodyIsReadable</method>'s first line to
/// <code>If '$IsObject(pBody) Quit 0</code> (refusing an absent body the same way the array/object
/// leg refuses a wrongly-shaped one) -- the direct assertion below goes red, and so does the
/// bodyless create, which then answers 400 <code>AGENT.BADBODY</code> instead of 422.</p>
Method TestAnAbsentBodyIsAdmittedFallsToTheRulesOnCreateAndChangesNothingOnUpdate()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).BodyIsReadable(""), 1, "BodyIsReadable admits an absent body, distinct from a body that parsed but is not an object")

    Set tBefore = ##class(OcuPilot.Test.AgentFixture).ProbeCount()
    Set tSC = ..Call("POST", "", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the bodyless create request completes")
    Do $$$AssertEquals(tStatus, 422, "an absent body falls to the rules rather than being refused as a bad body: " _ tBody)
    Do $$$AssertEquals(..ViolationsOf(tBody), ..ViolationsText($ListBuild($ListBuild("name", "AGENT.NAME.REQUIRED"), $ListBuild("provider", "AGENT.PROVIDER.UNKNOWN"), $ListBuild("credType", "AGENT.CREDTYPE.UNKNOWN"))), "naming exactly the fields an entirely empty submission violates")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), tBefore, "and writes nothing")

    Set tId = ..CreateDefinition("Bodyless")
    If tId = "" Quit
    Do ..Call("GET", "/" _ tId, "", .tGetStatus, .tGetBody, .tGetHeaders)
    Do $$$AssertEquals(tGetStatus, 200, "the arranged definition reads back")
    Set tBeforeUpdate = ##class(%DynamicObject).%FromJSON(tGetBody)

    Set tSC = ..Call("PUT", "/" _ tId, "", .tPutStatus, .tPutBody, .tPutHeaders)
    Do $$$AssertStatusOK(tSC, "the bodyless update request completes")
    Do $$$AssertEquals(tPutStatus, 200, "and is accepted -- an absent body names no field to change: " _ tPutBody)
    If tPutStatus '= 200 Quit
    Set tAfterUpdate = ##class(%DynamicObject).%FromJSON(tPutBody)
    Do $$$AssertEquals(tAfterUpdate.name, tBeforeUpdate.name, "the name is unchanged")
    Do $$$AssertEquals(tAfterUpdate.provider, tBeforeUpdate.provider, "the provider is unchanged")
    Do $$$AssertEquals(tAfterUpdate.model, tBeforeUpdate.model, "the model is unchanged")
    Do $$$AssertEquals(tAfterUpdate.envVarName, tBeforeUpdate.envVarName, "the credential reference is unchanged")
    Do $$$AssertEquals(tAfterUpdate.enabled, tBeforeUpdate.enabled, "and the security-relevant flags are untouched by an update naming no field")
    Do $$$AssertEquals(tAfterUpdate.connectionVerified, tBeforeUpdate.connectionVerified, "including verification")
}

/// <p>The JSON one <code>{field, code, reason}</code> violation arrives as (AD-39), with the
/// sentence resolved from <method>OcuPilot.Api.Error.ReasonForViolation</method> unless the caller
/// states one.</p>
/// <p><b>Composed rather than transcribed</b>, and deliberately: what the assertions below are
/// about is which field each refusal lands on and in what order, and a copy of every sentence
/// spelled out at each call site would make those assertions fail on a reworded reason -- which
/// AD-12 says may be reworded freely. That every code <i>has</i> a sentence, and that the
/// published one reaches the wire, is pinned separately in
/// <class>OcuPilot.Test.AgentViolation</class>.</p>
ClassMethod ViolationText(pField As %String, pCode As %String, pReason As %String = "") As %String
{
    Set tEntry = {}
    Do tEntry.%Set("field", pField)
    Do tEntry.%Set("code", pCode, "string")
    Do tEntry.%Set("reason", $Select(pReason = "": ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), 1: pReason), "string")
    Quit tEntry.%ToJSON()
}

/// <p>The JSON a whole <code>detail.violations</code> array arrives as, from
/// <code>$ListBuild($ListBuild(field, code), ...)</code> in the order they are reported.</p>
ClassMethod ViolationsText(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tText = tText _ $Select(tI = 1: "", 1: ",") _ ..ViolationText($List(tPair, 1), $List(tPair, 2), $ListGet(tPair, 3))
    }
    Quit "[" _ tText _ "]"
}

/// <p>The <code>detail.violations</code> array of a refusal body, as JSON, or a note saying what
/// was there instead -- so a violation assertion reads as one line and a body of another shape
/// fails with what it actually was.</p>
ClassMethod ViolationsOf(pBody As %String) As %String
{
    Set tAnswer = ##class(%DynamicObject).%FromJSON(pBody)
    If '$IsObject(tAnswer.detail) Quit "no detail object: " _ pBody
    If '$IsObject(tAnswer.detail.violations) Quit "no violations array: " _ pBody
    Quit tAnswer.detail.violations.%ToJSON()
}

/// <p>Create one probe definition over the wire and return its id, or <code>""</code>.</p>
Method CreateDefinition(pSuffix As %String) As %String
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ pSuffix _ """,""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created (" _ tBody _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody).id
}

/// <p><var>pObject</var>'s keys, in order, comma-separated -- so a projection can be asserted for
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
