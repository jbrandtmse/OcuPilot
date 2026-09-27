/// <p>Pins Story 14.5, the per-user read-only toggle (AD-30, AD-50): the user's own choice is the
/// fourth source <method>OcuPilot.Kernel.Restraint.Verdict</method> reads, in the precedence the
/// published footer row lists (kill switch, enforced, for you, by the definition), re-read on every
/// call; and <code>PUT /agent/restraint</code> stores only the caller's own choice, refuses any
/// other body, and answers the same body as <code>GET</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and reachable over HTTP as the
/// suite's own account (<class>OcuPilot.Test.Http</class>). No arming variable applies: it creates
/// no principal. The verdict legs drive two probe user names the instance need not hold (AD-37).</p>
/// <p>Every row it writes -- the switch row, holds, probe definitions and the read-only rows of the
/// two probe users and the suite's own account -- is removed in <method>OnAfterOneTest</method>,
/// which then asserts none survives.</p>
Class OcuPilot.Test.ReadOnlyForYou Extends %UnitTest.TestCase
{

/// <p>The user the verdict legs turn read-only on for.</p>
Parameter PROBEUSER = "OcuPilotProbeForYouUser";

/// <p>A second probe user, so "another user is unchanged" has a subject.</p>
Parameter OTHERUSER = "OcuPilotProbeForYouOther";

/// <p>The prefix <class>OcuPilot.Test.AgentFixture</class> removes probe definitions by.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions)
    For tUser = ..#PROBEUSER, ..#OTHERUSER, ##class(OcuPilot.Test.Http).GetTestUsername() {
        Do ..Remove(tUser)
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the switch row and the holds this class wrote are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no hold survives this class")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions)
    Do $$$AssertStatusOK(tSC, "the probe definitions are removed")
    Do $$$AssertEquals(tDefinitions, 0, "and none survives")
    For tUser = ..#PROBEUSER, ..#OTHERUSER, ##class(OcuPilot.Test.Http).GetTestUsername() {
        Do $$$AssertStatusOK(..Remove(tUser), tUser _ ": the read-only row is removed")
        Do $$$AssertEquals(..Stored(tUser), "", tUser _ ": and none survives")
    }
    Quit $$$OK
}

/// <p>Remove <var>pUser</var>'s read-only row, by its exact key.</p>
ClassMethod Remove(pUser As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Pref).GuardedRemove(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDRESTRAINT, ##class(OcuPilot.Kernel.State.Pref).#RESTRAINTREADONLY)
}

/// <p>Store <var>pValue</var> as <var>pUser</var>'s read-only row, as the route does.</p>
ClassMethod Store(pUser As %String, pValue As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDRESTRAINT, ##class(OcuPilot.Kernel.State.Pref).#RESTRAINTREADONLY, pValue)
}

/// <p>What <var>pUser</var>'s read-only row holds, or <code>""</code> for none.</p>
ClassMethod Stored(pUser As %String) As %String
{
    Do ##class(OcuPilot.Kernel.State.Pref).GuardedValue(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDRESTRAINT, ##class(OcuPilot.Kernel.State.Pref).#RESTRAINTREADONLY, .tValue)
    Quit tValue
}

/// <p>One request to the API as the suite's own account.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pText, .tHeaders, pBody, "application/json")
}

/// <p>A probe definition made read-only, its id in <var>pId</var>.</p>
Method ReadOnlyDefinition(pSuffix As %String, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ pSuffix, 0, 0, .tRow)
    If $$$ISERR(tSC) Quit tSC
    Set pId = tRow.%Id()
    Set tRow = ""
    Quit ##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(pId, 1)
}

/// <p><b>No row restrains nothing</b>: the verdict is unblocked, reports the choice off, and the
/// footer reads the off key. A value other than <code>1</code> reads as off too.</p>
Method TestNoRowIsOff()
{
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 0, "nothing blocks")
    Do $$$AssertEquals(tVerdict("readOnlyForYou"), 0, "the choice reads off")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyOff", "and the footer reads the off key")
    For tValue = "0", "true", "yes" {
        Do $$$AssertStatusOK(..Store(..#PROBEUSER, tValue), "'" _ tValue _ "' is stored")
        Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
        Do $$$AssertEquals(tVerdict("blocked") _ "|" _ tVerdict("readOnlyForYou"), "0|0", "'" _ tValue _ "' reads as off")
    }
}

/// <p><b>AC1: the choice on blocks that user alone</b>, under its own code and footer key.</p>
/// <p>Mutation: delete the for-you branch in <method>OcuPilot.Kernel.Restraint.Verdict</method> --
/// this goes red.</p>
Method TestOnBlocksThatUserAlone()
{
    Do $$$AssertStatusOK(..Store(..#PROBEUSER, "1"), "the probe user turns read-only on")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 1, "a write is blocked")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYUSER, "under the per-user read-only code")
    Do $$$AssertEquals(tVerdict("reason"), ##class(OcuPilot.Api.Error).#REASONAGENTREADONLYUSER, "carrying that code's sentence")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyForYou", "and the footer reads the for-you key")
    Do $$$AssertEquals(tVerdict("readOnlyForYou"), 1, "reporting the choice on")
    Do $$$AssertEquals(tVerdict("enforcedReadOnly") _ "|" _ tVerdict("killSwitch"), "0|0", "with no other source on")

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#OTHERUSER, "", .tOther)
    Do $$$AssertStatusOK(tSC, "another user's verdict is readable")
    Do $$$AssertEquals(tOther("blocked") _ "|" _ tOther("readOnlyForYou") _ "|" _ tOther("footerKey"), "0|0|statusReadOnlyOff", "and is unchanged")
}

/// <p><b>AC2: enforced read-only wins</b> over the choice on and over the choice off: the enforced
/// code and footer key, <code>enforcedReadOnly</code> still reported.</p>
/// <p>Mutation: let a stored <code>0</code> clear <code>enforcedReadOnly</code> in
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> -- the off arm goes red.</p>
Method TestEnforcedWins()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "enforced read-only is on")
    For tValue = "1", "0" {
        Do $$$AssertStatusOK(..Store(..#PROBEUSER, tValue), tValue _ ": the choice is stored")
        Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
        Do $$$AssertStatusOK(tSC, tValue _ ": the verdict is readable")
        Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYENFORCED, tValue _ ": the enforced code wins")
        Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyEnforced", tValue _ ": with the enforced footer key")
        Do $$$AssertEquals(tVerdict("enforcedReadOnly"), 1, tValue _ ": and the switch reported on")
        Do $$$AssertEquals(tVerdict("readOnlyForYou"), +tValue, tValue _ ": the stored choice still reported as stored")
    }
}

/// <p><b>The choice wins over a read-only definition</b>, and turning it off hands the verdict
/// back to the definition.</p>
Method TestForYouWinsOverTheDefinition()
{
    Set tSC = ..ReadOnlyDefinition("ForYou", .tId)
    Do $$$AssertStatusOK(tSC, "a read-only probe definition exists")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK(..Store(..#PROBEUSER, "1"), "the probe user turns read-only on")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYUSER, "the per-user code wins over the definition's")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyForYou", "with the for-you footer key")

    Do $$$AssertStatusOK(..Store(..#PROBEUSER, "0"), "the probe user turns it off")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tVerdict)
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYDEFINITION, "and the definition's code applies again")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyByDefinition", "with its footer key")
}

/// <p><b>The kill switch outranks the choice</b>, for everyone and for the one user alike.</p>
Method TestTheKillSwitchOutranksIt()
{
    Do $$$AssertStatusOK(..Store(..#PROBEUSER, "1"), "the probe user turns read-only on")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(..#PROBEUSER, "held while read-only for you is on", .tHoldId), "and is held")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHUSER, "the hold's code wins")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyForYou", "while the footer still answers the read-only question")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "off for everyone", 0), "the kill switch is on for everyone")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL, "and the global code wins over both")
}

/// <p><b>AC3: nothing is cached within one process</b>: the row is set, cleared and set again
/// between verdicts, and each verdict answers the stored row.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.State.Pref.GuardedValue</method> answer a
/// process-private memo -- the second verdict goes red.</p>
Method TestTheChoiceIsNeverCachedWithinOneProcess()
{
    Do $$$AssertStatusOK(..Store(..#PROBEUSER, "1"), "the choice is set")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tFirst)
    Do $$$AssertEquals(tFirst("blocked"), 1, "the first verdict blocks")
    Do $$$AssertStatusOK(..Remove(..#PROBEUSER), "the row is cleared")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tSecond)
    Do $$$AssertEquals(tSecond("blocked") _ "|" _ tSecond("readOnlyForYou"), "0|0", "the second answers the cleared row")
    Do $$$AssertStatusOK(..Store(..#PROBEUSER, "1"), "the choice is set again")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tThird)
    Do $$$AssertEquals(tThird("blocked"), 1, "and the third answers it again")
}

/// <p><b>AC3 over HTTP: <code>PUT</code> stores, and a separate <code>GET</code> reads it
/// back</b>, as the ten-key body the panel reads; <code>PUT false</code> turns it off.</p>
/// <p>Mutation: drop the <code>GuardedSetValue</code> call from
/// <method>OcuPilot.Api.Switches.HandleRestraintUpdate</method> -- the stored row and the answer
/// go red.</p>
Method TestPutStoresAndGetReadsItBack()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $$$AssertEquals(..Stored(tUser), "", "the suite's account holds no row")
    Do ..Call("GET", "/agent/restraint", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "the read answers: " _ tText)
    If tStatus '= 200 Quit
    Set tBefore = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tBefore.%GetTypeOf("readOnlyForYou") _ "|" _ tBefore.readOnlyForYou, "boolean|0", "a user with no row reads off")

    Do ..Call("PUT", "/agent/restraint", "{""readOnly"":true}", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "the write answers 200: " _ tText)
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Set tKeys = ""
    Set tIterator = tAnswer.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "blocked,code,reason,footerKey,killSwitch,killSwitchAudience,killSwitchReason,enforcedReadOnly,readOnlyForYou,writesMarked", "the body GET answers")
    Do $$$AssertEquals(tAnswer.readOnlyForYou _ "|" _ tAnswer.blocked, "1|1", "the choice is on and blocks")
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#AGENTREADONLYUSER, "under the per-user code")
    Do $$$AssertEquals(tAnswer.footerKey, "statusReadOnlyForYou", "with the for-you footer key")
    Do $$$AssertEquals(..Stored(tUser), "1", "the instance stores it")

    Do ..Call("GET", "/agent/restraint", "", .tStatus, .tText)
    Set tRead = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tRead.readOnlyForYou _ "|" _ tRead.footerKey, "1|statusReadOnlyForYou", "a separate read answers it on")

    Do ..Call("PUT", "/agent/restraint", "{""readOnly"":false}", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "turning it off answers 200: " _ tText)
    Set tOff = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tOff.readOnlyForYou _ "|" _ tOff.blocked _ "|" _ tOff.footerKey, "0|0|statusReadOnlyOff", "and answers it off")
    Do $$$AssertEquals(..Stored(tUser), "0", "stored as 0")
}

/// <p><b>Any body but exactly <code>{readOnly: boolean}</code> is refused</b> 422
/// <code>AGENT.RESTRAINT.BODY</code>, and nothing is written.</p>
/// <p>Mutation: drop the extra-member check in
/// <method>OcuPilot.Api.Switches.HandleRestraintUpdate</method> -- the extra-member case answers
/// 200 and goes red.</p>
Method TestABadBodyIsRefusedAndNothingIsWritten()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    For tBody = "{}", "{""readOnly"":""yes""}", "{""readOnly"":true,""extra"":1}", "not json" {
        Do ..Call("PUT", "/agent/restraint", tBody, .tStatus, .tText)
        Do $$$AssertEquals(tStatus, 422, tBody _ ": is refused: " _ tText)
        If tStatus '= 422 Continue
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        Do $$$AssertEquals(tAnswer.error, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tBody _ ": under the validation slug")
        Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#AGENTRESTRAINTBODY, tBody _ ": with the body code")
        Do $$$AssertEquals(..Stored(tUser), "", tBody _ ": and nothing was written")
    }
}

/// <p><b>AC2 over HTTP: <code>PUT false</code> while enforced read-only is on</b> is stored, and
/// the answered verdict stays enforced.</p>
Method TestPutFalseUnderEnforcedStaysEnforced()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "enforced read-only is on")
    Do ..Call("PUT", "/agent/restraint", "{""readOnly"":false}", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "the write answers 200: " _ tText)
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#AGENTREADONLYENFORCED, "the verdict stays enforced")
    Do $$$AssertEquals(tAnswer.footerKey, "statusReadOnlyEnforced", "with the enforced footer key")
    Do $$$AssertEquals(tAnswer.enforcedReadOnly _ "|" _ tAnswer.readOnlyForYou, "1|0", "the switch on and the choice off")
    Do $$$AssertEquals(..Stored(##class(OcuPilot.Test.Http).GetTestUsername()), "0", "and the choice was stored")
}

/// <p><b>The preferences route neither writes nor lists the kind</b>: a <code>set</code> naming it
/// is refused as an unknown kind, and a stored row does not appear in
/// <code>GET /account/preferences</code>.</p>
Method TestThePreferencesRouteRefusesAndHidesTheKind()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ..Call("POST", "/account/preferences", "{""kind"":""restraint"",""action"":""set"",""name"":""readOnly"",""value"":""1""}", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 422, "the preferences route refuses the kind: " _ tText)
    If tStatus = 422 {
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).code, ##class(OcuPilot.Api.Error).#PREFERENCESBODY, "as a body it does not accept")
    }
    Do $$$AssertEquals(..Stored(tUser), "", "and nothing was written")

    Do $$$AssertStatusOK(..Store(tUser, "1"), "a row is stored")
    Do ..Call("GET", "/account/preferences", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "the preferences read answers: " _ $Extract(tText, 1, 200))
    Do $$$AssertEquals(tText [ "restraint", 0, "and never names the kind")
    Do $$$AssertEquals(tText [ """readOnly""", 0, "or the choice")
}

}
