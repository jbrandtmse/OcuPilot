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
    Do $$$AssertEquals(tKeys, "killSwitch,killSwitchReason,enforcedReadOnly,shareContextByDefault,updatedAt,holds", "the six keys the screen reads")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("killSwitch"), "boolean", "a flag arrives as a JSON boolean")
    Do $$$AssertEquals(tAnswer.killSwitch, 0, "the kill switch is off")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly, 0, "read-only is not enforced")
    Do $$$AssertEquals(tAnswer.shareContextByDefault, 1, "and screen context is shared by default")
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

/// <p><b><code>GET /agent/restraint</code> answers the calling user's own verdict</b>, in the shape
/// the panel renders its banners and its footer line from.</p>
/// <p>It is the one switch route that gates on nothing beyond the router, for the reason
/// <method>OcuPilot.Api.Definitions.HandleList</method> is: the audience for the kill-switch banner
/// is precisely the people who cannot change it.</p>
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
    Do $$$AssertEquals(tKeys, "blocked,code,reason,footerKey,killSwitch,killSwitchAudience,killSwitchReason,enforcedReadOnly", "the eight keys the panel reads")
    Do $$$AssertEquals(tAnswer.blocked, 0, "a clean instance restrains nothing")
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

}
