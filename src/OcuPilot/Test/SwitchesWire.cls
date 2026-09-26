/// <p>The five switch routes over HTTP -- status, content type and body shape (Conventions, Tests)
/// -- through the shipped router rather than by calling the handler in process.</p>
/// <p><b>The caller is the suite's own privileged account</b>, so these assert what an
/// administrator is served. The refusals a principal holding no OcuPilot administrative resource
/// meets are <class>OcuPilot.Test.AgentWireSecurity</class>'s, which creates a real principal and
/// runs only where <code>OCUPILOT_ALLOW_PRINCIPALS</code> arms it.</p>
/// <p>Every row this class writes is removed in <method>OnAfterOneTest</method>, which then asserts
/// none survives, so a run on the development instance leaves it as it found it -- including any
/// hold on the suite's own account, which would otherwise switch the agent off for a real user.</p>
Class OcuPilot.Test.SwitchesWire Extends %UnitTest.TestCase
{

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The prefix every probe hold's user name starts with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeHold";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the switch row and the holds this class wrote are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no hold survives this class")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and no switch row survives it either")
    Quit $$$OK
}

/// <p><b>DW-388's integration acceptance criterion</b> -- a switches save whose row moved after
/// this request read it is refused 409 with <code>STATE.CONFLICT</code>, through the one envelope
/// and the one error writer (AD-12, AD-39), and the other writer's values survive.</p>
/// <p><b>It runs through <class>OcuPilot.Test.Dispatch</class> and not over a socket.</b> The body
/// carries no <code>rowVersion</code>, so the window the conditional write closes opens and closes
/// inside one request -- a handler that reads, does work, then writes -- and the second writer has
/// to be inside the request, which is what <class>OcuPilot.Test.SwitchesStaleProbe</class> is;
/// everything under it, including the real <code>%CSP.REST</code> dispatch, the real status and
/// the real envelope, is the shipped path. A body that carries the version the screen read is
/// <method>TestASaveCarryingAStaleVersionIsRefusedUntilReloaded</method>'s, over a real
/// socket.</p>
/// <p>Mutation: drop <code>AND COALESCE(RowVersion, 0) = ?</code> from
/// <method>OcuPilot.Kernel.State.Base.GuardedSaveIfCurrent</method>, or stop passing the version
/// read in <method>OcuPilot.Api.Switches.HandleUpdate</method> -- this answers 200 and goes
/// red.</p>
Method TestASwitchesSaveWhoseRowMovedIsRefusedWithAConflict()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-switches-stale", "PUT", , .tBody, .tStatus, , , "{""enforcedReadOnly"":true}")
    Do $$$AssertStatusOK(tSC, "the dispatch completes")
    Do $$$AssertEquals(tStatus, 409, "and the save is refused as a conflict: " _ tBody)
    If tStatus '= 409 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.error, ##class(OcuPilot.Api.Error).#CONFLICT, "under the conflict slug")
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#STATECONFLICT, "with the stable machine code a stale save carries")
    Do $$$AssertEquals(tAnswer.reason, ##class(OcuPilot.Api.Error).#REASONSTATECONFLICT, "and that code's server-authored reason, which the client replaces with its own published sentence")
    Do $$$AssertEquals(tBody [ "}{", 0, "exactly one envelope was written: " _ tBody)

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tNow), "the switches read back")
    Do $$$AssertEquals(tNow("killSwitchReason"), ##class(OcuPilot.Test.SwitchesStaleProbe).#OTHERREASON, "the other writer's values survived")
    Do $$$AssertEquals(tNow("enforcedReadOnly"), 0, "and the refused save was not taken -- read-only is not enforced")
}

/// <p>One request to the agent surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p><b><code>GET /agent/switches</code> answers the defaults on a clean instance</b>, with the
/// holds array empty and no row written by the read.</p>
Method TestTheSwitchesReadAnswersTheDefaultsOnACleanInstance()
{
    Set tSC = ..Call("GET", "/agent/switches", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tKeys = ""
    Set tIterator = tAnswer.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "killSwitch,killSwitchReason,enforcedReadOnly,shareContextByDefault,contextRowCap,updatedAt,rowVersion,holds", "the eight keys the screen reads")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("rowVersion"), "number", "the row version arrives as a JSON number")
    Do $$$AssertEquals(tAnswer.rowVersion, 0, "and is 0 while the instance holds no row")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("killSwitch"), "boolean", "a flag arrives as a JSON boolean")
    Do $$$AssertEquals(tAnswer.killSwitch, 0, "the kill switch is off")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly, 0, "read-only is not enforced")
    Do $$$AssertEquals(tAnswer.shareContextByDefault, 1, "and screen context is shared by default")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("contextRowCap"), "number", "the row cap arrives as a JSON number")
    Do $$$AssertEquals(tAnswer.contextRowCap, 200, "at the default")
    Do $$$AssertTrue($IsObject(tAnswer.holds), "the holds arrive as an array")
    Do $$$AssertEquals(tAnswer.holds.%Size(), 0, "which is empty")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and the read wrote no row")
}

/// <p><b><code>PUT /agent/switches</code> writes and answers the stored truth</b>, and a body that
/// names one field leaves the others alone.</p>
/// <p>Mutation: answer the request's own values in
/// <method>OcuPilot.Api.Switches.HandleUpdate</method> rather than re-reading -- this stays green
/// here and reddens the merge assertion below, which is why both are in one test.</p>
Method TestTheSwitchesUpdateWritesAndAnswersTheStoredTruth()
{
    Set tSC = ..Call("PUT", "/agent/switches", "{""killSwitch"":true,""killSwitchReason"":""Paused for the change freeze"",""enforcedReadOnly"":true}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.killSwitch, 1, "the kill switch is on")
    Do $$$AssertEquals(tAnswer.killSwitchReason, "Paused for the change freeze", "with the reason verbatim")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly, 1, "and read-only is enforced")
    Do $$$AssertNotEquals(tAnswer.updatedAt, "", "and the answer carries the stamp the write made")

    Set tSC = ..Call("PUT", "/agent/switches", "{""killSwitch"":false}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "a one-key body completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.killSwitch, 0, "turning the kill switch off")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly, 1, "and leaving enforced read-only alone (AD-4)")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 1, "with one row written, not two")
}

/// <p>A save carrying the version the screen read is refused <code>STATE.CONFLICT</code> once
/// another writer has moved the row, and pressing Save again with the same version is refused
/// again; a read hands back the current version, and a save carrying it is taken, as is the next
/// one carrying the version that answer carried. A body with no <code>rowVersion</code> saves as it
/// always has.</p>
/// <p>Mutation: have <method>OcuPilot.Api.Switches.HandleUpdate</method> ignore the body's
/// <code>rowVersion</code> -- the two stale saves answer 200 and this goes red.</p>
Method TestASaveCarryingAStaleVersionIsRefusedUntilReloaded()
{
    Do ..Call("GET", "/agent/switches", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the switches read: " _ tBody)
    Set tRead = ##class(%DynamicObject).%FromJSON(tBody).rowVersion
    Do ..Call("PUT", "/agent/switches", "{""killSwitchReason"":""first"",""rowVersion"":" _ tRead _ "}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a save carrying the version read is taken: " _ tBody)
    Set tHeld = ##class(%DynamicObject).%FromJSON(tBody).rowVersion
    Do $$$AssertTrue(tHeld > tRead, "and answers the version the save wrote: " _ tHeld)

    Do ..Call("PUT", "/agent/switches", "{""killSwitchReason"":""other""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "another writer's save with no rowVersion is taken as it always was: " _ tBody)

    For tAttempt = 1, 2 {
        Do ..Call("PUT", "/agent/switches", "{""killSwitchReason"":""stale"",""rowVersion"":" _ tHeld _ "}", .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 409, "save " _ tAttempt _ " with the version this screen held is refused: " _ tBody)
        If tStatus = 409 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, ##class(OcuPilot.Api.Error).#STATECONFLICT, "as a stale save")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tNow), "the switches read back")
    Do $$$AssertEquals(tNow("killSwitchReason"), "other", "and the other writer's reason survived both")

    Do ..Call("GET", "/agent/switches", "", .tStatus, .tBody, .tHeaders)
    Set tReloaded = ##class(%DynamicObject).%FromJSON(tBody).rowVersion
    Do ..Call("PUT", "/agent/switches", "{""killSwitchReason"":""after reload"",""rowVersion"":" _ tReloaded _ "}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "a save carrying the reloaded version is taken: " _ tBody)
    Set tAnswered = ##class(%DynamicObject).%FromJSON(tBody).rowVersion
    Do ..Call("PUT", "/agent/switches", "{""killSwitchReason"":""answered"",""rowVersion"":" _ tAnswered _ "}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "and so is the next, carrying the version that answer carried: " _ tBody)
}

/// <p><b>A flag sent as anything but a JSON boolean, and a reason sent as anything but a JSON
/// string, are ignored</b> -- the merge's typing guard, whose failure direction on
/// <code>killSwitch</code> is the permissive one.</p>
/// <p><code>+"true"</code> is 0 in ObjectScript, so a quoted flag reaching the column would store
/// 0 whatever the caller meant: a request meaning "switch the agent off" would answer 200 and
/// leave the agent on. A reason that is not a string would reach the published banner as the
/// operator's words.</p>
/// <p>Mutation: delete either <code>Continue</code> guard from
/// <method>OcuPilot.Api.Switches.MergeBody</method> -- this goes red on the flag or on the reason,
/// where every other test here stays green because all of them send well-typed JSON.</p>
Method TestABadlyTypedFieldIsIgnoredRatherThanCoerced()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "the stored reason", 1), "the instance starts with read-only enforced and the agent on")

    Set tSC = ..Call("PUT", "/agent/switches", "{""killSwitch"":""true"",""killSwitchReason"":42,""enforcedReadOnly"":""false""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.killSwitch, 0, "the quoted flag was ignored rather than coerced to 0 by a column write")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly, 1, "and so was the other one, which therefore keeps its stored value")
    Do $$$AssertEquals(tAnswer.killSwitchReason, "the stored reason", "the reason is the stored one, not the number the body carried")

    ; The same body, correctly typed, does move the switches -- so the assertions above are about
    ; the guard rather than about a route that ignores its body.
    Set tSC = ..Call("PUT", "/agent/switches", "{""killSwitch"":true,""killSwitchReason"":""Paused for the change freeze"",""enforcedReadOnly"":false}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the well-typed request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.killSwitch, 1, "the kill switch is on")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly, 0, "and enforced read-only is off")
    Do $$$AssertEquals(tAnswer.killSwitchReason, "Paused for the change freeze", "with the reason verbatim")
}

/// <p><b>A reason longer than the column holds is refused on its field whichever way the switch is
/// set</b>, rather than reaching <method>%Save</method> and answering 500.</p>
/// <p>Mutation: move the length test back inside the <code>killSwitch</code> branch of
/// <method>OcuPilot.Kernel.SwitchRules.ValidateSwitches</method> -- the switch-off case below goes
/// red with a 500 where a 422 is expected.</p>
Method TestAnOverLongReasonIsRefusedOnItsFieldRatherThanAtTheColumn()
{
    Set tLong = ""
    For tI = 1:1:53 { Set tLong = tLong _ "0123456789" }
    Do $$$AssertTrue($Length(tLong) > 512, "the probe reason is longer than the column holds (" _ $Length(tLong) _ ")")

    For tFlag = "false", "true" {
        Set tSC = ..Call("PUT", "/agent/switches", "{""killSwitch"":" _ tFlag _ ",""killSwitchReason"":""" _ tLong _ """}", .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "killSwitch " _ tFlag _ ": the request completes")
        Do $$$AssertEquals(tStatus, 422, "killSwitch " _ tFlag _ ": is refused as a validation failure rather than failing at the column: " _ $Extract(tBody, 1, 200))
        If tStatus '= 422 Continue
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.detail.violations.%Size(), 1, "killSwitch " _ tFlag _ ": with one violation")
        Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).field, "killSwitchReason", "killSwitch " _ tFlag _ ": on the reason field")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and neither refused write wrote a row")
}

/// <p><b>The kill switch may not be turned on without a reason</b>: 422, one envelope, one
/// violation on the field the operator can act on (AD-39).</p>
/// <p>Mutation: delete the <code>killSwitch</code> guard from
/// <method>OcuPilot.Kernel.SwitchRules.ValidateSwitches</method> -- this goes red on the status
/// and on the residue check.</p>
Method TestTheKillSwitchIsRefusedWithoutAReason()
{
    Set tSC = ..Call("PUT", "/agent/switches", "{""killSwitch"":true}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused as a validation failure: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, "AGENT.VALIDATION", "under the one envelope code every field-level refusal arrives with")
    Do $$$AssertTrue($IsObject(tAnswer.detail), "carrying a detail object")
    If '$IsObject(tAnswer.detail) Quit
    Do $$$AssertEquals(tAnswer.detail.violations.%Size(), 1, "with exactly one violation")
    Set tFirst = tAnswer.detail.violations.%Get(0)
    Do $$$AssertEquals(tFirst.field, "killSwitchReason", "on the reason field")
    Do $$$AssertEquals(tFirst.code, ##class(OcuPilot.Api.Error).#AGENTSWITCHREASONREQUIRED, "with its own machine code")
    Do $$$AssertEquals(tFirst.reason, ##class(OcuPilot.Api.Error).#REASONAGENTSWITCHREASONREQUIRED, "and the published sentence a form renders on that field")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and the refused write wrote nothing")
}

/// <p><b>A hold is created, listed and removed over the wire</b>, and a row naming a user the
/// instance no longer holds carries <code>present</code> false rather than failing the read
/// (AD-37).</p>
Method TestAHoldIsCreatedListedAndRemoved()
{
    Set tGhost = ##class(OcuPilot.Test.SwitchFixture).#GHOSTUSER
    Set tSC = ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tGhost _ """,""reason"":""Switched off while the account is reviewed""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create completes")
    Do $$$AssertEquals(tStatus, 201, "and answers 201: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type")
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertNotEquals(tCreated.id, "", "carrying the new row's id")
    Do $$$AssertEquals(tCreated.userName, tGhost, "the user it names")
    Do $$$AssertEquals(tCreated.present, 0, "and that the instance holds no such user (AD-37)")

    Set tSC = ..Call("GET", "/agent/switches", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.holds.%Size(), 1, "carrying the one hold")
    Set tRow = tAnswer.holds.%Get(0)
    Set tKeys = ""
    Set tIterator = tRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "id,userName,reason,present", "with the four keys the screen renders a row from")
    Do $$$AssertEquals(tRow.reason, "Switched off while the account is reviewed", "and the reason verbatim")

    Set tSC = ..Call("DELETE", "/agent/switches/holds/" _ tCreated.id, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the delete completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tDeleted = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tDeleted.deleted, 1, "reporting the row gone")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).HoldCount(), 0, "and the instance holds none")
}

/// <p><b>A hold naming a user the instance still holds carries <code>present</code> true</b>, which
/// is the other half of the weak-reference rendering and what makes the false above evidence rather
/// than a constant.</p>
Method TestAHoldOnAUserTheInstanceHoldsIsMarkedPresent()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tUser _ """,""reason"":""Switched off for this test""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create completes")
    Do $$$AssertEquals(tStatus, 201, "and answers 201: " _ tBody)
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tCreated.present, 1, "and the user resolves on this instance")
}

/// <p><b>A repeat hold on the same user is refused on its own field</b> rather than reaching the
/// unique index, and writes nothing.</p>
Method TestARepeatHoldIsRefusedOnItsOwnField()
{
    Set tGhost = ##class(OcuPilot.Test.SwitchFixture).#GHOSTUSER
    Set tSC = ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tGhost _ """,""reason"":""first""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the first create completes")
    Do $$$AssertEquals(tStatus, 201, "and answers 201: " _ tBody)

    Set tSC = ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tGhost _ """,""reason"":""second""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the second create completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tFirst = $Select($IsObject(tAnswer.detail): tAnswer.detail.violations.%Get(0), 1: "")
    Do $$$AssertTrue($IsObject(tFirst), "carrying a violation")
    If '$IsObject(tFirst) Quit
    Do $$$AssertEquals(tFirst.field, "userName", "on the user field")
    Do $$$AssertEquals(tFirst.code, ##class(OcuPilot.Api.Error).#AGENTHOLDDUPLICATE, "under the duplicate code")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).HoldCount(), 1, "and the refused create wrote nothing")
}

/// <p><b>A hold with neither a user nor a reason is refused twice in one envelope</b>, which is the
/// accumulate-every-violation contract (AD-39).</p>
Method TestAHoldWithNoUserAndNoReasonIsRefusedInOneEnvelope()
{
    Set tSC = ..Call("POST", "/agent/switches/holds", "{}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue($IsObject(tAnswer.detail), "carrying a detail object")
    If '$IsObject(tAnswer.detail) Quit
    Do $$$AssertEquals(tAnswer.detail.violations.%Size(), 2, "with both violations in one response, never two responses")
    Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).code, ##class(OcuPilot.Api.Error).#AGENTHOLDUSERREQUIRED, "the user rule first")
    Do $$$AssertEquals(tAnswer.detail.violations.%Get(1).code, ##class(OcuPilot.Api.Error).#AGENTHOLDREASONREQUIRED, "then the reason rule")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).HoldCount(), 0, "and nothing was written")
}

/// <p><b>Deleting a hold no row holds is a 404 naming its own code</b>, never an empty 200.</p>
Method TestDeletingAnAbsentHoldIsANamedNotFound()
{
    Set tSC = ..Call("DELETE", "/agent/switches/holds/999999999", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the delete completes")
    Do $$$AssertEquals(tStatus, 404, "and is refused: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#AGENTHOLDNOTFOUND, "under its own machine code")
    Do $$$AssertEquals(tAnswer.error, "not_found", "on the not-found slug")
}

/// <p><b>Story 5.6, AD-15/AD-17.</b> Recording the marking observation that is <b>already</b> the
/// answer writes no row at all.</p>
/// <p>That is not a micro-optimisation. <class>OcuPilot.Kernel.State.Switch</class> is a store whose
/// defaults are parameters, so an instance nobody has configured holds no row -- and the absence of
/// that row is exactly what
/// <method>OcuPilot.Install.Smoke.CheckAgentSwitches</method> reads to tell an install that wrote no
/// switches from one that did. Install records this fact on every container start, and the executor
/// records it on every confirmed write, so a method that wrote unconditionally would destroy that
/// signal permanently on the first start.</p>
/// <p>Mutation (Rule 19): delete the <code>If ..WritesMarked() = ''pMarked Quit</code> guard from
/// <method>OcuPilot.Kernel.Audit.Event.RecordMarking</method> -- the "writes no row" assertion goes
/// red while the changed-value control below stays green.</p>
Method TestRecordingTheMarkingFactAlreadyHeldWritesNoRow()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "the fixture left no switch row")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 1, "so the fact reads its default")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Event).RecordMarking(1), "recording the value already held succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and writes no row")

    ; The control: a value that differs does write one, so the assertion above is about the guard
    ; rather than about a method that never writes anything.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Event).RecordMarking(0), "recording a changed value succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 1, "and writes the row")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 0, "carrying the new observation")
}

/// <p><b>Story 5.6, AD-15.</b> The marking fact travels <code>GET /agent/restraint</code> in
/// <b>both</b> directions. <method>TestTheRestraintReadAnswersTheCallersOwnVerdict</method> asserts
/// the healthy arm, which is the one a clean instance answers; this one writes the recorded fact 0
/// and reads the route back, because the panel renders only the <b>false</b> arm and a fact that
/// could never arrive false would leave the banner unreachable with every gate green.</p>
/// <p>Mutation (Rule 19): hard-code <code>1</code> in
/// <method>OcuPilot.Api.Switches.HandleRestraint</method>'s <code>writesMarked</code> line -- this
/// goes red while <method>TestTheRestraintReadAnswersTheCallersOwnVerdict</method> stays green.</p>
Method TestTheRestraintReadCarriesARecordedNotMarkingFact()
{
    Kill tValues
    Set tValues("writesMarked") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), "the observed marking fact is recorded 0")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 0, "and reads back 0 through the emitter's own accessor")

    Set tSC = ..Call("GET", "/agent/restraint", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the restraint read runs")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.%GetTypeOf("writesMarked"), "boolean", "the fact arrives as a JSON boolean")
    Do $$$AssertEquals(tAnswer.writesMarked, 0, "carrying the recorded 0, which is the only arm the panel renders")
    ; Marking is not a restraint (AD-30): nothing else about the verdict moves.
    Do $$$AssertEquals(tAnswer.blocked, 0, "and the verdict itself is unchanged")
    Do $$$AssertEquals(tAnswer.killSwitch, 0, "with the kill switch still off")
}

/// <p><b><code>GET /agent/restraint</code> answers the calling user's own verdict</b>, in the shape
/// the panel renders its banners and its footer line from.</p>
/// <p>It is the one switch route that gates on nothing beyond the router, for the reason
/// <method>OcuPilot.Api.Definitions.HandleList</method> is: the audience for the kill-switch banner
/// is precisely the people who cannot change it -- and, since Story 5.6, for the audience of the
/// not-marked banner, which is every user whose writes are the ones not being marked.</p>
Method TestTheRestraintReadAnswersTheCallersOwnVerdict()
{
    Set tSC = ..Call("GET", "/agent/restraint", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tKeys = ""
    Set tIterator = tAnswer.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    ; `writesMarked` is Story 5.6's and is not part of the verdict: marking is not a restraint
    ; (AD-30), and only its false arm is ever rendered (AD-15).
    Do $$$AssertEquals(tKeys, "blocked,code,reason,footerKey,killSwitch,killSwitchAudience,killSwitchReason,enforcedReadOnly,writesMarked", "the nine keys the panel reads")
    Do $$$AssertEquals(tAnswer.blocked, 0, "a clean instance restrains nothing")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("writesMarked"), "boolean", "and marking arrives as a JSON boolean")
    Do $$$AssertEquals(tAnswer.writesMarked, 1, "which an installed instance answers true, so no banner is drawn over a healthy one")
    Do $$$AssertEquals(tAnswer.footerKey, "statusReadOnlyOff", "and the footer line reads the off key")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("killSwitch"), "boolean", "a flag arrives as a JSON boolean")
    Do $$$AssertEquals(tAnswer.killSwitchAudience, "", "with no audience to name")
}

/// <p><b>The restraint read reports the instance-wide kill switch with its reason</b>, which is what
/// fills the published banner's <code>&lt;reason&gt;</code> slot.</p>
Method TestTheRestraintReadReportsTheGlobalKillSwitch()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "Paused for the change freeze", 1), "the kill switch and enforced read-only are on")
    Set tSC = ..Call("GET", "/agent/restraint", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.blocked, 1, "a write is blocked")
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL, "under the global kill-switch code")
    Do $$$AssertEquals(tAnswer.killSwitch, 1, "the kill switch is reported on")
    Do $$$AssertEquals(tAnswer.killSwitchAudience, "everyone", "for everyone")
    Do $$$AssertEquals(tAnswer.killSwitchReason, "Paused for the change freeze", "with the operator's reason verbatim")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly, 1, "and enforced read-only is reported separately, because it carries its own banner")
    Do $$$AssertEquals(tAnswer.footerKey, "statusReadOnlyEnforced", "with the enforced footer key")
}

/// <p><b>The restraint read reports a hold on the caller alone</b>, with the you audience the
/// published banner's slot resolves to and that hold's own reason.</p>
Method TestTheRestraintReadReportsAHoldOnTheCaller()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(tUser, "Switched off for this test", .tId), "the caller is held")
    Set tSC = ..Call("GET", "/agent/restraint", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.blocked, 1, "a write is blocked")
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHUSER, "under the per-user code")
    Do $$$AssertEquals(tAnswer.killSwitchAudience, "you", "for that user alone")
    Do $$$AssertEquals(tAnswer.killSwitchReason, "Switched off for this test", "with the hold's own reason")
    Do $$$AssertEquals(tAnswer.footerKey, "statusReadOnlyOff", "and the footer line still reports the read-only state, which is off")
}

/// <p><b>The change record each accepted write produces through the shipped handler</b>, read back
/// from the console log over the wire: the three write verbs are driven over HTTP and
/// <code>GET /logs/messages</code> must carry a line for each, under the
/// <code>agent-switch</code> subsystem.</p>
/// <p><b>This is what makes the three <method>OcuPilot.Api.Switches.LogChange</method> call sites
/// falsifiable.</b> <method>OcuPilot.Test.SwitchState.TestASwitchWriteRecordsTheFieldsThatMoved</method>
/// exercises the record's shape, but it calls <method>LogChange</method> itself -- so deleting the
/// call from any handler would leave it green, which is the gap
/// <method>OcuPilot.Test.AgentWire.TestAnAcceptedWriteEmitsItsChangeRecordFromTheHandler</method>
/// closes for the definition routes. Here the only thing that puts a line in the log is the
/// handler.</p>
/// <p>Mutation: delete the <method>LogChange</method> line from
/// <method>OcuPilot.Api.Switches.HandleUpdate</method>,
/// <method>HandleHoldCreate</method> or <method>HandleHoldDelete</method> -- this goes red naming
/// the verb whose record is missing.</p>
Method TestAnAcceptedWriteEmitsItsChangeRecordFromTheHandler()
{
    ; A marker unique to this run, written into the operator text each verb carries. The console
    ; log is instance-wide and keeps earlier runs' lines, so a record matched on its verb alone
    ; could be satisfied by a line this run did not emit -- which is the same false green the
    ; in-process leg already has.
    Set tMarker = "OcuPilotProbeRecord" _ $Translate($System.Util.CreateGUID(), "-", "")
    Set tGhost = ##class(OcuPilot.Test.SwitchFixture).#GHOSTUSER
    Do ..Call("PUT", "/agent/switches", "{""killSwitch"":true,""killSwitchReason"":""" _ tMarker _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the switch write the record is expected for is accepted: " _ tBody)
    Do ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tGhost _ """,""reason"":""" _ tMarker _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "and the hold: " _ tBody)
    If tStatus '= 201 Quit
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do ..Call("DELETE", "/agent/switches/holds/" _ tCreated.id, "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "and the release: " _ tBody)

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIBASE _ "/logs/messages", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the console-log page request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers: " _ $Extract(tBody, 1, 200))
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tPage.lines.%Size() > 0, "the log page carries lines: " _ tPage.lines.%Size())

    Kill tFound
    Set tIterator = tPage.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If tLine '[ """subsystem"":""agent-switch""" Continue
        If tLine '[ tMarker Continue
        For tVerb = "switches", "hold", "release" {
            If tLine [ ("""msg"":""" _ tVerb _ """") Set tFound(tVerb) = tLine
        }
    }
    For tVerb = "switches", "hold", "release" {
        Do $$$AssertTrue($Data(tFound(tVerb)), "this run's own change record for the " _ tVerb _ " is in the console log, under the agent-switch subsystem")
    }
    If $Data(tFound("switches")) Do $$$AssertTrue(tFound("switches") [ """killSwitch""", "the switch record names the flag that moved beside the reason: " _ tFound("switches"))
    If $Data(tFound("hold")) Do $$$AssertTrue(tFound("hold") [ tGhost, "the hold record names the user it is about: " _ tFound("hold"))
    If $Data(tFound("release")) Do $$$AssertTrue(tFound("release") [ """securityChange"":true", "and the release record classifies itself as a security change: " _ tFound("release"))
}

/// <p><b>A hold field longer than its column holds is refused on that field</b> rather than
/// reaching <method>%Save</method> and answering 500 -- the same contract
/// <method>TestAnOverLongReasonIsRefusedOnItsFieldRatherThanAtTheColumn</method> holds for the
/// instance switches, on the route that got the same rule and none of the test.</p>
/// <p>Mutation: drop the <code>MAXREASONLENGTH</code> half of the reason test, or the
/// <code>MAXUSERNAMELENGTH</code> half of the user test, from
/// <method>OcuPilot.Kernel.SwitchRules.ValidateHold</method> -- the matching case below answers 500
/// where a 422 is expected.</p>
Method TestAnOverLongHoldFieldIsRefusedOnItsFieldRatherThanAtTheColumn()
{
    Set tGhost = ##class(OcuPilot.Test.SwitchFixture).#GHOSTUSER
    Set tLongReason = ""
    For tI = 1:1:53 { Set tLongReason = tLongReason _ "0123456789" }
    Do $$$AssertTrue($Length(tLongReason) > 512, "the probe reason is longer than the column holds (" _ $Length(tLongReason) _ ")")
    Set tLongUser = ""
    For tI = 1:1:17 { Set tLongUser = tLongUser _ "0123456789" }
    Do $$$AssertTrue($Length(tLongUser) > 160, "and the probe user name is longer than its column holds (" _ $Length(tLongUser) _ ")")

    Do ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tGhost _ """,""reason"":""" _ tLongReason _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 422, "an over-long reason is refused as a validation failure: " _ $Extract(tBody, 1, 200))
    If tStatus = 422 {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.detail.violations.%Size(), 1, "with one violation")
        Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).field, "reason", "on the reason field")
    }

    Do ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tLongUser _ """,""reason"":""Switched off while the account is reviewed""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 422, "an over-long user name is refused too: " _ $Extract(tBody, 1, 200))
    If tStatus = 422 {
        Set tUserAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tUserAnswer.detail.violations.%Size(), 1, "with one violation")
        Do $$$AssertEquals(tUserAnswer.detail.violations.%Get(0).field, "userName", "on the user field")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).HoldCount(), 0, "and neither refused create wrote a row")
}

/// <p><b>A user name pasted with surrounding whitespace is held as the user it names</b>, not as a
/// row that never matches one. <method>OcuPilot.Kernel.State.Hold.GuardedForUser</method> matches
/// the stored name against <code>$Username</code>, so an untrimmed row would be a kill switch that
/// silently does nothing.</p>
/// <p>Mutation: drop the <code>$ZStrip</code> from
/// <method>OcuPilot.Api.Switches.HandleHoldCreate</method> -- the projected name keeps its spaces
/// and the duplicate below is accepted as a second row.</p>
Method TestAHoldsUserNameIsStrippedBeforeAnythingReadsIt()
{
    Set tGhost = ##class(OcuPilot.Test.SwitchFixture).#GHOSTUSER
    Do ..Call("POST", "/agent/switches/holds", "{""userName"":""  " _ tGhost _ "  "",""reason"":""Switched off while the account is reviewed""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "the padded create is accepted: " _ tBody)
    If tStatus '= 201 Quit
    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tCreated.userName, tGhost, "and the row names the user without the padding")

    Do ..Call("POST", "/agent/switches/holds", "{""userName"":""" _ tGhost _ """,""reason"":""second""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 422, "so the unpadded repeat is the same user and is refused: " _ $Extract(tBody, 1, 200))
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).HoldCount(), 1, "and the instance holds one row, not two")
}

/// <p>Every switch route is declared in the shipped router, and its response carries nothing about
/// the instance beyond what the screen renders.</p>
Method TestTheSwitchRoutesAreDeclaredInTheShippedRouter()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    Do $$$AssertTrue($IsObject(tXData), "the router's UrlMap is readable")
    If '$IsObject(tXData) Quit
    Do tXData.Data.Rewind()
    Set tMap = tXData.Data.Read(32000)
    For tRoute = "<Route Url=""/agent/switches/holds/:id"" Method=""DELETE"" Call=""AgentSwitchHoldDelete""/>", "<Route Url=""/agent/switches/holds"" Method=""POST"" Call=""AgentSwitchHoldCreate""/>", "<Route Url=""/agent/switches"" Method=""GET"" Call=""AgentSwitchesRead""/>", "<Route Url=""/agent/switches"" Method=""PUT"" Call=""AgentSwitchesUpdate""/>", "<Route Url=""/agent/restraint"" Method=""GET"" Call=""AgentRestraint""/>" {
        Do $$$AssertTrue(tMap [ tRoute, "the router declares " _ tRoute)
    }
}

/// <p><b>The context row cap is a whole number from 1 to 1,000</b> (Story 4.4, AD-24): <code>0</code>,
/// <code>1,001</code>, a boolean and any string, numeric or not, are each refused on the field
/// <code>contextRowCap</code> with <code>AGENT.SWITCH.CONTEXTROWCAP</code>, and nothing is written;
/// <code>500</code> is accepted and reads back.</p>
/// <p>Mutation: widen the range check in <method>OcuPilot.Kernel.SwitchRules.ValidateSwitches</method>
/// -- one of the three refused values goes green where 422 is expected.</p>
Method TestTheContextRowCapValidatesItsRange()
{
    For tCase = 0, 1001 {
        Set tSC = ..Call("PUT", "/agent/switches", "{""contextRowCap"":" _ tCase _ "}", .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tCase _ ": the request completes")
        Do $$$AssertEquals(tStatus, 422, tCase _ ": is refused as a validation failure: " _ tBody)
        If tStatus '= 422 Continue
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.detail.violations.%Size(), 1, tCase _ ": with one violation")
        Set tFirst = tAnswer.detail.violations.%Get(0)
        Do $$$AssertEquals(tFirst.field, "contextRowCap", tCase _ ": on its own field")
        Do $$$AssertEquals(tFirst.code, ##class(OcuPilot.Api.Error).#AGENTSWITCHCONTEXTROWCAP, tCase _ ": with its own machine code")
    }

    Set tSC = ..Call("PUT", "/agent/switches", "{""contextRowCap"":""x""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "a non-numeric string completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).code, ##class(OcuPilot.Api.Error).#AGENTSWITCHCONTEXTROWCAP, "the string is refused, not silently kept")

    ; A JSON boolean reads back as 1 or 0, the same as the JSON numbers 1 and 0 -- refused here
    ; specifically so it cannot pass as a plausible row cap.
    Set tSC = ..Call("PUT", "/agent/switches", "{""contextRowCap"":true}", .tBoolStatus, .tBoolBody, .tBoolHeaders)
    Do $$$AssertStatusOK(tSC, "a boolean completes")
    Do $$$AssertEquals(tBoolStatus, 422, "and is refused: " _ tBoolBody)
    Set tBoolAnswer = ##class(%DynamicObject).%FromJSON(tBoolBody)
    Do $$$AssertEquals(tBoolAnswer.detail.violations.%Get(0).code, ##class(OcuPilot.Api.Error).#AGENTSWITCHCONTEXTROWCAP, "the boolean is refused, not accepted as 1")

    ; A numeric string is not a JSON number (AD-4).
    Set tSC = ..Call("PUT", "/agent/switches", "{""contextRowCap"":""500""}", .tStrStatus, .tStrBody, .tStrHeaders)
    Do $$$AssertStatusOK(tSC, "a numeric string completes")
    Do $$$AssertEquals(tStrStatus, 422, "and is refused, not stored as 500: " _ tStrBody)

    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "none of the five refused writes wrote a row")

    Set tSC = ..Call("PUT", "/agent/switches", "{""contextRowCap"":500}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "a value in range completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.contextRowCap, 500, "and reads back as a number")
}

}
