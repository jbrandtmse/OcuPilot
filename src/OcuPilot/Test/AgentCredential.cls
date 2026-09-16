/// <p><b>AC2, AC4's server half and AC5's server half</b> -- <code>POST
/// /agent/definitions/:id/credential</code> over HTTP. The claim is about what a consumer receives
/// from the shipped router, so every status, content type and body below is read off a real
/// response.</p>
/// <p><b>The two assertions the story exists for.</b> Neither the store's own 200 nor any later
/// read of the definition carries any part of the value posted; and a definition that was enabled
/// and verified reads back disabled and unverified, because the key it was verified against is no
/// longer the key behind the reference.</p>
/// <p><b>One refusal cannot be reached over the wire</b> -- the credentials rung is present on this
/// instance, so <code>AGENT.CREDENTIAL.RUNGUNAVAILABLE</code> is driven in process through
/// <class>OcuPilot.Test.DefinitionsProbe</class>'s credential seam against the real
/// <method>OcuPilot.Api.Definitions.CredentialRefusal</method>.</p>
/// <p>Every definition this class creates is named with <parameter>PROBEPREFIX</parameter> and
/// removed in <method>OnAfterOneTest</method>, which then asserts none survives; the credential
/// entry is removed there too.</p>
Class OcuPilot.Test.AgentCredential Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The credential entry the definitions below point at.</p>
Parameter PROBECREDENTIAL = "OcuPilotProbeCredential";

/// <p>A fabricated key of the shape the shipped <code>anthropic</code> row's prefix requires, so it
/// passes the shape gate and is stored. It is not a credential and reaches no provider.</p>
Parameter PROBEKEY = "sk-ant-ocupilotstoredprobe00000000";

/// <p>A fabricated key of the wrong shape for that row, which is what the shape refusal is driven
/// with.</p>
Parameter WRONGSHAPEKEY = "not-an-anthropic-key-at-all";

/// <p>A credential reference the credential store will not accept: 76 characters against
/// <code>SystemName</code>'s <code>MAXLEN</code> of 50.</p>
/// <p>Since DW-344 it is also a reference <b>OcuPilot</b> will not accept: the rule refuses it at
/// write time, which is what the row below pins. It used to be how the store-fails-in-the-vendor
/// row was driven over the wire.</p>
Parameter TOOLONGNAME = "OcuPilotProbeCredentialReferenceTheCredentialStoreItselfWillNotAcceptAtAll00";

/// <p>Clear any definition a previous method left behind.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
    Quit $$$OK
}

/// <p>Remove every definition and the credential entry, and assert neither survives.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "and no credential entry does either")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#TOOLONGNAME)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#TOOLONGNAME), 0, "nor one under the reference the credential store refuses")
    Quit $$$OK
}

/// <p>One request to the definitions surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/agent/definitions" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>The route is declared in the shipped router, beside the other sub-resource route and above
/// every single-segment <code>:id</code> route.</p>
Method TestTheRouteIsDeclaredBesideTheOtherSubResource()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    Do $$$AssertTrue($IsObject(tXData), "the router's UrlMap is readable")
    If '$IsObject(tXData) Quit
    Do tXData.Data.Rewind()
    Set tMap = tXData.Data.Read(32000)
    Do $$$AssertTrue(tMap [ "<Route Url=""/agent/definitions/:id/credential"" Method=""POST""", "the router declares the credential route")
    Do $$$AssertTrue($Find(tMap, "/agent/definitions/:id/credential") < $Find(tMap, """/agent/definitions/:id"""), "and declares it before the three-segment :id routes it would otherwise be swallowed by")
}

/// <p><b>AC2 and AC5's server half</b> -- a store succeeds, returns nothing of the key, and leaves
/// the definition disabled and unverified.</p>
/// <p>The definition is enabled and verified first through
/// <class>OcuPilot.Test.AgentFixture</class>, because the API refuses an enable while a definition
/// is unverified and only Story 3.4 verifies one -- and because asserting "reads back 0" on a
/// definition that was already 0 would be an assertion about nothing.</p>
/// <p>Mutation: drop the <method>OcuPilot.Kernel.State.Agent.GuardedClearVerification</method> call
/// from <method>OcuPilot.Api.Definitions.HandleStoreCredential</method> -- the two flag assertions
/// go red, reading 1. Mutation: echo the stored value into the 200 body -- the body assertion goes
/// red.</p>
Method TestAStoreSucceedsCarriesNoValueBackAndDisablesTheDefinition()
{
    Set tId = ..CreateCredsDefinition("Store")
    If tId = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified before the store")

    Set tSC = ..Call("POST", "/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the store request completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type: " _ $Get(tHeaders("CONTENT-TYPE")))
    If tStatus '= 200 Quit
    Set tStored = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tStored.stored, 1, "reporting the store")
    Do $$$AssertEquals(..KeysOf(tStored), "stored", "and carrying exactly that one key, so there is nothing for a value to ride in")
    Do $$$AssertEquals(tBody [ ..#PROBEKEY, 0, "the response carries no part of the value: " _ tBody)

    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 1, "the credential entry now exists")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#PROBECREDENTIAL), ..#PROBEKEY, "and the ladder resolves the definition's reference to what was posted")

    Set tReadSC = ..Call("GET", "/" _ tId, "", .tReadStatus, .tReadBody, .tReadHeaders)
    Do $$$AssertStatusOK(tReadSC, "the definition reads back")
    Do $$$AssertEquals(tReadStatus, 200, "and answers: " _ tReadBody)
    Do $$$AssertEquals($ZConvert($Get(tReadHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tReadStatus '= 200 Quit
    Set tRead = ##class(%DynamicObject).%FromJSON(tReadBody)
    Do $$$AssertEquals(tReadBody [ ..#PROBEKEY, 0, "the full projection carries no part of the stored value: " _ tReadBody)
    Do $$$AssertEquals(tRead.credentialName, ..#PROBECREDENTIAL, "it carries the reference, which is what the schema stores")
    Do $$$AssertEquals(tRead.enabled, 0, "the store disabled the definition, so Test connection must pass again")
    Do $$$AssertEquals(tRead.connectionVerified, 0, "and cleared its verification")

    Set tListSC = ..Call("GET", "", "", .tListStatus, .tListBody, .tListHeaders)
    Do $$$AssertStatusOK(tListSC, "the list reads back")
    Do $$$AssertEquals(tListStatus, 200, "and answers")
    Do $$$AssertEquals($ZConvert($Get(tListHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertTrue($IsObject(##class(%DynamicObject).%FromJSON(tListBody).definitions), "with a definitions array")
    Do $$$AssertEquals(tListBody [ ..#PROBEKEY, 0, "and the selection projection carries no part of the stored value either")
}

/// <p><b>AC4's server half</b> -- a key of the wrong shape for the definition's provider is refused
/// on <code>apiKey</code>, and <b>nothing is written</b>: the credential entry does not exist
/// afterwards.</p>
/// <p>Mutation: move the shape check after
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method> -- the "nothing was written" assertion goes
/// red, the entry existing afterwards.</p>
Method TestABadlyShapedKeyIsRefusedAndWritesNothing()
{
    Set tId = ..CreateCredsDefinition("Shape")
    If tId = "" Quit

    Set tSC = ..Call("POST", "/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#WRONGSHAPEKEY), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the store request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus '= 422 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.error, "validation_failed", "on the validation_failed slug")
    Do $$$AssertEquals(..ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("apiKey", "AGENT.KEY.SHAPE", ##class(OcuPilot.Api.Error).#REASONAGENTKEYSHAPE _ ": keys for this provider begin with sk-ant-."))), "with one violation on the apiKey field, whose own sentence states the prefix so the form can render it there")
    Do $$$AssertTrue(tAnswer.reason [ "sk-ant-", "and a reason stating the prefix a key for this provider begins with: " _ tAnswer.reason)
    Do $$$AssertEquals(tBody [ ..#WRONGSHAPEKEY, 0, "and never the value posted: " _ tBody)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "nothing was written")
}

/// <p>The two refusals that are about the request rather than the key: a body naming no
/// <code>apiKey</code>, or naming one that is not a JSON string.</p>
Method TestAMissingOrNonStringKeyIsRefusedAsRequired()
{
    Set tId = ..CreateCredsDefinition("Required")
    If tId = "" Quit

    For tCase = "{}", "{""apiKey"":42}", "{""apiKey"":null}", "{""apiKey"":""""}", "" {
        Set tSC = ..Call("POST", "/" _ tId _ "/credential", tCase, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "'" _ tCase _ "': the request completes")
        Do $$$AssertEquals(tStatus, 422, "'" _ tCase _ "': is refused: " _ tBody)
        Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "'" _ tCase _ "': as JSON")
        If tStatus '= 422 Continue
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "AGENT.VALIDATION", "'" _ tCase _ "': on the agent validation code")
        Do $$$AssertEquals(..ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("apiKey", "AGENT.CREDENTIAL.REQUIRED"))), "'" _ tCase _ "': with one violation on the apiKey field")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "and none of them wrote anything")
}

/// <p>A definition whose secret comes from an environment variable is refused with a named code
/// rather than failing obscurely: <class>%SYSTEM.Util</class> publishes
/// <method>GetEnviron</method> and no setter, so that rung's store is the operating system and the
/// operator owns it.</p>
Method TestAnEnvironmentDefinitionIsRefusedAsUnwritable()
{
    Set tId = ..CreateEnvDefinition("Env")
    If tId = "" Quit

    Set tSC = ..Call("POST", "/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the store request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus '= 422 Quit
    Do $$$AssertTrue($IsObject(##class(%DynamicObject).%FromJSON(tBody).detail), "carrying a detail object")
    Do $$$AssertEquals(..ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("apiKey", "AGENT.CREDENTIAL.ENVUNWRITABLE"))), "with one violation on the apiKey field")
    Do $$$AssertEquals(tBody [ ..#PROBEKEY, 0, "and the refusal carries no part of the value posted")
}

/// <p>An id no definition holds is a named 404 -- and it answers <b>before the body is read</b>, so
/// a key posted at an identifier that does not exist is never looked at.</p>
Method TestAnUnknownIdAnswers404()
{
    Set tSC = ..Call("POST", "/999999999/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 404, "and answers 404: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "AGENT.NOTFOUND", "with the agent not-found code")
    Do $$$AssertEquals(tBody [ ..#PROBEKEY, 0, "and carries no part of the value posted")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "and wrote nothing")
}

/// <p>The one refusal no request can reach on this instance: the credentials rung being
/// unreachable. Driven through <class>OcuPilot.Test.DefinitionsProbe</class>'s credential seam
/// against the <b>real</b> <method>OcuPilot.Api.Definitions.CredentialRefusal</method>, so what is
/// exercised is the shipped order of the four refusals and not a copy of it.</p>
/// <p>The order is the assertion as much as the code is: with the rung reported unavailable a
/// well-formed key still answers <code>AGENT.CREDENTIAL.RUNGUNAVAILABLE</code> rather than the shape
/// refusal, because the shape check is last -- it needs a value <i>and</i> a reachable store.</p>
Method TestAnUnreachableRungIsRefusedBeforeTheShapeCheck()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Rung", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a definition is arranged")
    If $$$ISERR(tSC) Quit
    Set tRow.CredType = "creds"
    Set tRow.EnvVarName = ""
    Set tRow.CredentialName = ..#PROBECREDENTIAL
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot), "and pointed at the credentials rung")

    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(0)
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredentialRefusal(tRow, ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY)), "AGENT.CREDENTIAL.RUNGUNAVAILABLE", "a well-shaped key is refused because the rung is unreachable")
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredentialRefusal(tRow, ##class(OcuPilot.Test.CredentialFixture).Payload(..#WRONGSHAPEKEY)), "AGENT.CREDENTIAL.RUNGUNAVAILABLE", "and so is a badly shaped one, the shape check being last")

    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(1)
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredentialRefusal(tRow, ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY)), "", "with the rung reachable the same well-shaped key is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredentialRefusal(tRow, ##class(OcuPilot.Test.CredentialFixture).Payload(..#WRONGSHAPEKEY)), "AGENT.KEY.SHAPE", "and the badly shaped one earns the shape refusal instead")

    ; The shipped class, with no seam replaced at all, so the two legs above are read against the
    ; judgement production actually makes rather than only against the probe's.
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).CredentialRefusal(tRow, ##class(OcuPilot.Test.CredentialFixture).Payload(..#WRONGSHAPEKEY)), "AGENT.KEY.SHAPE", "the shipped handler refuses the badly shaped key on this instance's own rung")
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).CredentialRefusal(tRow, ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY)), "", "and accepts the well-shaped one")
    Set tRow = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "and none of the four judgements wrote anything")
}

/// <p><b>The change record the handler emits for a store</b>, read back from the console log over
/// the wire -- the seam that writes both the log line and the audit row. The record is the
/// only trace a credential store leaves, and <class>OcuPilot.Test.AgentWire</class>'s own wire loop
/// covers the four verbs that existed before this route.</p>
/// <p><b>It carries <code>securityChange</code> true.</b> A store changes no field
/// <method>OcuPilot.Api.Definitions.SecurityFieldNames</method> lists, so the change set alone would
/// classify the one write that puts a secret on the instance as an ordinary edit; the verb is what
/// classifies it (AD-42).</p>
/// <p>Mutation: delete the <method>OcuPilot.Api.Definitions.LogChange</method> call from
/// <method>HandleStoreCredential</method> -- the record is not in the log and this goes red.
/// Mutation: classify the verb through the change set alone -- the
/// <code>securityChange</code> assertion goes red reading false.</p>
Method TestTheStoreEmitsItsChangeRecordFromTheHandler()
{
    Set tId = ..CreateCredsDefinition("Record")
    If tId = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified, so the store has a transition to record")

    Set tSC = ..Call("POST", "/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the store request completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted: " _ tBody)
    If tStatus '= 200 Quit

    Set tPageSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIBASE _ "/logs/messages", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tPageStatus, .tPageBody, .tPageHeaders)
    Do $$$AssertStatusOK(tPageSC, "the console-log page request completes")
    Do $$$AssertEquals(tPageStatus, 200, "and answers")
    Do $$$AssertEquals($ZConvert($Get(tPageHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tPageStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tPageBody)
    Do $$$AssertTrue(tPage.lines.%Size() > 0, "the log page carries lines: " _ tPage.lines.%Size())

    Set tFound = ""
    Set tIterator = tPage.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If tLine '[ """subsystem"":""agent-definition""" Continue
        If tLine '[ ("""id"":""" _ tId _ """") Continue
        If tLine [ """msg"":""credential""" Set tFound = tLine
    }
    Do $$$AssertNotEquals(tFound, "", "the handler's own change record for the credential store of definition " _ tId _ " is in the console log, under the agent-definition subsystem")
    If tFound = "" Quit
    Do $$$AssertTrue(tFound [ """securityChange"":true", "classified as a security change, which is what selects the audit row's event name: " _ tFound)
    Do $$$AssertEquals(tFound [ ..#PROBEKEY, 0, "and carrying no part of the value posted")
}

/// <p><b>DW-344</b> -- the reference that used to reach the credential store and fail there is now
/// refused at <b>write</b> time, on its own field, and the definition is never created.</p>
/// <p>This method asserted the opposite until Story 3.5: a definition's <code>credentialName</code>
/// holds 128 characters and the credential entry's <code>SystemName</code> holds 50, so an operator
/// could save a reference the store would not accept and meet a 500 at the moment they stored a
/// key. The rule closes that gap, so the 500 is no longer reachable from this route and what is
/// pinned here is the refusal that replaced it.</p>
/// <p>The 500 path itself has not gone: <method>OcuPilot.Api.Definitions.HandleStoreCredential</method>
/// still renders <method>OcuPilot.Api.Error.RenderInternal</method> for a store that fails, and
/// <method>OcuPilot.Test.Secret.TestAVendorRefusalNamesTheReferenceAndLogsCodesOnly</method> drives
/// it in process, where a refusal can be arranged without a definition the rules refuse.</p>
/// <p>Mutation: remove the length arm from
/// <method>OcuPilot.Kernel.AgentRules.Validate</method> -- this goes red at 201, the create
/// succeeding again.</p>
Method TestAnOverLongCredentialReferenceIsRefusedAtWriteTime()
{
    Do $$$AssertTrue($Length(..#TOOLONGNAME) > ##class(OcuPilot.Kernel.AgentRules).#MAXCREDENTIALNAMELENGTH, "the reference is longer than the credential store accepts, which is the precondition this leg needs")
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ "Vendor"",""provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ ..#TOOLONGNAME _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused before any definition exists to store a key against: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus '= 422 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, "AGENT.VALIDATION", "under the one envelope code every field-level refusal arrives with")
    Do $$$AssertEquals(..ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("credentialName", "AGENT.CREDNAME.LENGTH", ##class(OcuPilot.Api.Error).#REASONAGENTCREDNAMELENGTH _ ": use " _ ##class(OcuPilot.Kernel.AgentRules).#MAXCREDENTIALNAMELENGTH _ " characters or fewer."))), "with one violation on credentialName whose sentence states the bound")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), 0, "and nothing was created")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#TOOLONGNAME), 0, "nor written under that reference")
}

/// <p>The <code>detail.violations</code> array of a refusal body, as JSON, or a note saying what
/// was there instead.</p>
ClassMethod ViolationsOf(pBody As %String) As %String
{
    Set tAnswer = ##class(%DynamicObject).%FromJSON(pBody)
    If '$IsObject(tAnswer.detail) Quit "no detail object: " _ pBody
    If '$IsObject(tAnswer.detail.violations) Quit "no violations array: " _ pBody
    Quit tAnswer.detail.violations.%ToJSON()
}

/// <p>Create one probe definition on the credentials rung over the wire and return its id, or
/// <code>""</code>. <var>pCredentialName</var> defaults to <parameter>PROBECREDENTIAL</parameter>
/// and is overridable for a caller that needs a reference of its own; since DW-344 a reference the
/// credential store would refuse is refused by the rules here, so no caller overrides it today.</p>
Method CreateCredsDefinition(pSuffix As %String, pCredentialName As %String = {..#PROBECREDENTIAL}) As %String
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ pSuffix _ """,""provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ pCredentialName _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created (" _ tBody _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody).id
}

/// <p>Create one probe definition on the environment rung over the wire and return its id, or
/// <code>""</code>.</p>
Method CreateEnvDefinition(pSuffix As %String) As %String
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
