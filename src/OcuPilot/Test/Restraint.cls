/// <p>The one enforcement point (AD-30, AD-40): what
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> answers for each source, in what precedence,
/// and that it re-reads the stores on every call.</p>
/// <p><b>What this class pins and what it cannot.</b> The turn loop and the confirm transition are
/// Epic 4's and Epic 5's, so the callers do not exist yet. What is falsifiable now is the verdict
/// itself, its no-cache property, and that nothing else in the tree produces a restraint code --
/// the last of those is <file>scripts/check-objectscript.py</file>'s
/// <code>check_restraint_containment</code>, which a second producer reddens in CI.</p>
/// <p>That rule bans a second producer of a restraint <b>code</b>, which is narrower than "one
/// enforcement point": a caller that read the two state classes and decided for itself would name
/// no code and pass it. Nothing here claims otherwise.</p>
/// <p>Every row this class writes is removed in <method>OnAfterOneTest</method>, which then asserts
/// none survives, so a run on the development instance leaves it as it found it.</p>
Class OcuPilot.Test.Restraint Extends %UnitTest.TestCase
{

/// <p>The user the per-user branch is driven for. A weak reference (AD-37): the instance holds no
/// principal of this name, and a hold naming one is a legitimate row.</p>
Parameter PROBEUSER = "OcuPilotProbeHoldUser";

/// <p>A second probe user, so "another user's verdict is unchanged" has a subject.</p>
Parameter OTHERUSER = "OcuPilotProbeHoldOther";

/// <p>The prefix every probe definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the switch row and the holds this class wrote are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no hold survives this class")
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "and no switch row survives it either, so the defaults are in force again")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions)
    Do $$$AssertStatusOK(tSC, "the probe definitions are removed")
    Do $$$AssertEquals(tDefinitions, 0, "and none survives")
    Quit $$$OK
}

/// <p><b>A fresh instance allows</b>: no switch row, no hold, no definition in force, so nothing
/// blocks and the footer line reads the off key.</p>
/// <p>Mutation: seed <parameter>OcuPilot.Kernel.State.Switch.DEFAULTKILLSWITCH</parameter> to 1 --
/// this goes red on <code>blocked</code>.</p>
Method TestAFreshInstanceIsNotRestrained()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "the instance holds no switch row")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 0, "nothing blocks a write")
    Do $$$AssertEquals(tVerdict("code"), "", "so there is no restraint code")
    Do $$$AssertEquals(tVerdict("reason"), "", "and no sentence")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyOff", "and the footer line reads the off key")
    Do $$$AssertEquals(tVerdict("killSwitch"), 0, "the kill switch is off")
    Do $$$AssertEquals(tVerdict("enforcedReadOnly"), 0, "and read-only is not enforced")
}

/// <p><b>Enforced read-only blocks</b>, with its own code and the enforced footer key.</p>
/// <p>Mutation: return <code>0</code> from the <code>enforcedReadOnly</code> arm of
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> -- this goes red on all four assertions.</p>
Method TestEnforcedReadOnlyBlocksWithItsOwnCodeAndFooterKey()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "enforced read-only is turned on")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 1, "a write is blocked")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYENFORCED, "under the enforced code")
    Do $$$AssertEquals(tVerdict("reason"), ##class(OcuPilot.Api.Error).#REASONAGENTREADONLYENFORCED, "carrying that code's written sentence")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyEnforced", "and the footer line reads the enforced key")
    Do $$$AssertEquals(tVerdict("enforcedReadOnly"), 1, "which is the one read-only source that also carries a banner")
    Do $$$AssertEquals(tVerdict("killSwitch"), 0, "the kill switch is a separate source and is off")
}

/// <p><b>A read-only definition blocks</b>, with the definition code and the definition footer key
/// -- Story 3.1 stored <property>OcuPilot.Kernel.State.Agent.ReadOnly</property> and this is what
/// reads it.</p>
/// <p>Mutation: delete the <code>tByDefinition</code> arm from
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> -- this goes red.</p>
Method TestADefinitionMarkedReadOnlyBlocksWithItsOwnCodeAndFooterKey()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "ReadOnly", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a probe definition exists")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Do $$$AssertEquals(''tRow.ReadOnly, 1, "and is read-only, which is the class's own default")
    Set tRow = ""

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 1, "a write is blocked")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYDEFINITION, "under the definition code")
    Do $$$AssertEquals(tVerdict("reason"), ##class(OcuPilot.Api.Error).#REASONAGENTREADONLYDEFINITION, "carrying that code's written sentence")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyByDefinition", "and the footer line reads the by-the-definition key")
    Do $$$AssertEquals(tVerdict("enforcedReadOnly"), 0, "the instance switch is off, so no banner")

    ; The falsifying half: the same definition, not read-only, restrains nothing.
    Do $$$AssertStatusOK(..SetDefinitionReadOnly(tId, 0), "the definition is made writable")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable again")
    Do $$$AssertEquals(tVerdict("blocked"), 0, "and nothing blocks")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyOff", "with the off footer key")
}

/// <p><b>Both read-only sources on: the enforced code and the enforced footer key win</b>, and the
/// verdict blocks once. Precedence is broadest scope first.</p>
/// <p>Mutation: swap the two arms in <method>OcuPilot.Kernel.Restraint.Verdict</method> -- this
/// goes red on the code and on the footer key.</p>
Method TestEnforcedReadOnlyWinsOverTheDefinitionsOwnFlag()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Both", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a read-only probe definition exists")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "and enforced read-only is on as well")

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 1, "the write is blocked once")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYENFORCED, "under the enforced code, not the definition's")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyEnforced", "and one footer key, the enforced one, so the line cannot say two things at once")
}

/// <p><b>The global kill switch blocks every caller</b>, carries the operator's own reason
/// verbatim, and names the everyone audience the published banner's slot resolves to.</p>
/// <p>Mutation: drop <code>killSwitchReason</code> from
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> -- this goes red on the reason the banner
/// renders.</p>
Method TestTheGlobalKillSwitchBlocksEveryCallerAndCarriesTheReason()
{
    Set tReason = "Paused during the quarterly change freeze"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, tReason, 0), "the kill switch is on for everyone")
    For tUser = ..#PROBEUSER, ..#OTHERUSER {
        Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(tUser, "", .tVerdict)
        Do $$$AssertStatusOK(tSC, tUser _ ": the verdict is readable")
        Do $$$AssertEquals(tVerdict("blocked"), 1, tUser _ ": is blocked")
        Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL, tUser _ ": under the global kill-switch code")
        Do $$$AssertEquals(tVerdict("killSwitch"), 1, tUser _ ": with the kill switch reported on")
        Do $$$AssertEquals(tVerdict("killSwitchAudience"), ##class(OcuPilot.Kernel.Restraint).#AUDIENCEEVERYONE, tUser _ ": for everyone")
        Do $$$AssertEquals(tVerdict("killSwitchReason"), tReason, tUser _ ": carrying the operator's reason verbatim")
        Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyOff", tUser _ ": and the footer line still reports the read-only state, which is off")
    }
}

/// <p><b>A per-user hold blocks that user alone</b>, with the per-user code and that hold's own
/// reason; another user's verdict is unchanged.</p>
/// <p>Mutation: ignore <var>pUserName</var> in
/// <method>OcuPilot.Kernel.State.Hold.GuardedForUser</method> -- this goes red on the other user's
/// verdict, where a test of the held user alone would stay green.</p>
Method TestAPerUserHoldBlocksThatUserAlone()
{
    Set tReason = "Switched off while the account is reviewed"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(..#PROBEUSER, tReason, .tId), "the probe user is held")

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertStatusOK(tSC, "the held user's verdict is readable")
    Do $$$AssertEquals(tVerdict("blocked"), 1, "and blocks")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHUSER, "under the per-user kill-switch code")
    Do $$$AssertEquals(tVerdict("killSwitchAudience"), ##class(OcuPilot.Kernel.Restraint).#AUDIENCEYOU, "for that user")
    Do $$$AssertEquals(tVerdict("killSwitchReason"), tReason, "carrying the hold's own reason")

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#OTHERUSER, "", .tOther)
    Do $$$AssertStatusOK(tSC, "another user's verdict is readable")
    Do $$$AssertEquals(tOther("blocked"), 0, "and is unchanged")
    Do $$$AssertEquals(tOther("killSwitch"), 0, "with no kill switch of their own")
}

/// <p><b>The global kill switch outranks a per-user hold</b>: one code comes back, and it is the
/// broader one.</p>
Method TestTheGlobalKillSwitchOutranksAPerUserHold()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold(..#PROBEUSER, "held for this user", .tId), "the probe user is held")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "off for everyone", 0), "and the switch is on for everyone as well")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL, "the broader code wins")
    Do $$$AssertEquals(tVerdict("killSwitchAudience"), ##class(OcuPilot.Kernel.Restraint).#AUDIENCEEVERYONE, "and the audience is everyone")
    Do $$$AssertEquals(tVerdict("killSwitchReason"), "off for everyone", "carrying the instance-wide reason rather than the hold's")
}

/// <p><b>The kill switch outranks read-only</b>: a switched-off agent does not read either, so its
/// code is the one that comes back -- while the footer line still reports the read-only state,
/// which is a different question.</p>
Method TestTheKillSwitchOutranksReadOnly()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "off for everyone", 1), "the kill switch and enforced read-only are both on")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tVerdict)
    Do $$$AssertStatusOK(tSC, "the verdict is readable")
    Do $$$AssertEquals(tVerdict("code"), ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL, "the kill switch is the reason reported")
    Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyEnforced", "and the footer line still answers the read-only question")
    Do $$$AssertEquals(tVerdict("enforcedReadOnly"), 1, "so the enforced banner still appears beside the kill-switch one")
}

/// <p><b>Nothing is cached for the length of a process</b> (AD-30). The store is flipped between
/// two <method>Verdict</method> calls in <b>one</b> process and the second answers the new state.
/// </p>
/// <p>This is the falsifying test for the whole no-cache clause: a memo, a process-private cache or
/// an OREF held across the return would make the second call answer the first call's state -- which
/// is exactly what <method>%OpenId</method> does for an object still in memory
/// (<file>.claude/rules/objectscript-basics.md</file>).</p>
/// <p>Mutation: hold the switch row in a process-private global between calls -- this goes red on
/// the second and third reads.</p>
Method TestTheVerdictIsNeverCachedWithinOneProcess()
{
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tFirst)
    Do $$$AssertStatusOK(tSC, "the first verdict is readable")
    Do $$$AssertEquals(tFirst("blocked"), 0, "and nothing blocks yet")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "flipped mid-process", 0), "the store is flipped between the two calls")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tSecond)
    Do $$$AssertStatusOK(tSC, "the second verdict is readable")
    Do $$$AssertEquals(tSecond("blocked"), 1, "and answers the new state, so nothing was cached")
    Do $$$AssertEquals(tSecond("killSwitchReason"), "flipped mid-process", "including the reason written a moment ago")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "flipped mid-process", 0), "and flipped back")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, "", .tThird)
    Do $$$AssertStatusOK(tSC, "the third verdict is readable")
    Do $$$AssertEquals(tThird("blocked"), 0, "which answers the state again rather than a remembered refusal")
}

/// <p><b>The definition's flag is re-read too</b>, which is the source most exposed to the stale-OREF
/// trap: the verdict opens the row and drops every reference before it returns.</p>
Method TestTheDefinitionsFlagIsReReadWithinOneProcess()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Flip", 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a read-only probe definition exists")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tFirst)
    Do $$$AssertStatusOK(tSC, "the first verdict is readable")
    Do $$$AssertEquals(tFirst("blocked"), 1, "and blocks on the definition's flag")

    Do $$$AssertStatusOK(..SetDefinitionReadOnly(tId, 0), "the flag is cleared between the two calls")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tSecond)
    Do $$$AssertStatusOK(tSC, "the second verdict is readable")
    Do $$$AssertEquals(tSecond("blocked"), 0, "and answers the stored row rather than the copy still in memory")
}

/// <p><b>An id no definition holds contributes no read-only source</b> -- a turn with nothing in
/// force is the configuration-empty state, not a restrained one -- and neither does
/// <code>""</code>.</p>
Method TestAnAbsentDefinitionRestrainsNothing()
{
    For tId = "", "999999999" {
        Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tVerdict)
        Do $$$AssertStatusOK(tSC, "'" _ tId _ "': the verdict is readable")
        Do $$$AssertEquals(tVerdict("blocked"), 0, "'" _ tId _ "': and nothing blocks")
        Do $$$AssertEquals(tVerdict("footerKey"), "statusReadOnlyOff", "'" _ tId _ "': with the off footer key")
    }
}

/// <p><b><method>Resolved</method> resolves the definition in force and calls
/// <method>Verdict</method></b>; it derives no part of the verdict itself. With an enabled,
/// marked definition that is read-only, it answers what <method>Verdict</method> answers for that
/// id.</p>
Method TestResolvedAnswersTheVerdictForTheDefinitionInForce()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "InForce", 1, 1, .tRow)
    Do $$$AssertStatusOK(tSC, "an enabled probe definition exists")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tDefault)
    Do $$$AssertStatusOK(tSC, "the default resolves")
    Do $$$AssertEquals(tDefault, tId, "to the definition just created, which is the only one")

    Set tSC = ##class(OcuPilot.Kernel.Restraint).Resolved(..#PROBEUSER, .tResolved)
    Do $$$AssertStatusOK(tSC, "the resolved verdict is readable")
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict(..#PROBEUSER, tId, .tDirect)
    Do $$$AssertStatusOK(tSC, "and so is the direct one")
    For tKey = "blocked", "code", "footerKey", "killSwitch", "enforcedReadOnly" {
        Do $$$AssertEquals(tResolved(tKey), tDirect(tKey), tKey _ " agrees between Resolved and Verdict")
    }
    Do $$$AssertEquals(tResolved("code"), ##class(OcuPilot.Api.Error).#AGENTREADONLYDEFINITION, "and the definition in force is read-only, which is the class's own default")
}

/// <p><b>Every restraint code carries a written sentence</b>, and an undeclared one carries none --
/// the same assertion <class>OcuPilot.Test.AgentViolation</class> makes for the field-level codes,
/// because a code with no sentence behind it reaches a tool result as a blank line.</p>
Method TestEveryRestraintCodeHasAWrittenSentence()
{
    Set tCodes = ##class(OcuPilot.Api.Error).RestraintCodes()
    Do $$$AssertEquals($ListLength(tCodes), 4, "the vocabulary holds four restraint codes; adding one is a deliberate edit in OcuPilot.Api.Error")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForRestraint(tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertTrue($Length(tReason) > 10, tCode _ "'s sentence says something: '" _ tReason _ "'")
        Do $$$AssertTrue(tReason '[ "!", tCode _ "'s sentence carries no exclamation mark (Voice and Tone)")
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), tCode _ " is a well-formed machine code (AD-39)")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForRestraint("AGENT.NO.SUCH.CODE"), "", "and a code the vocabulary does not hold carries none")
}

/// <p><b>The three footer keys are the published ones</b> the client renders, and they are the only
/// values <method>Verdict</method> can answer with. The fourth,
/// <code>statusReadOnlyForYou</code>, is Story 10.4's and is deliberately not answered yet.</p>
/// <p>The client half is <file>ui/tools/agent-status.test.mjs</file>, which asserts each of these
/// exists in <file>ui/src/app/core/strings.ts</file>. Both ends are pinned, so a key renamed on
/// either side reddens.</p>
Method TestTheFooterKeysAreTheThreePublishedOnes()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Restraint).#FOOTERKEYOFF, "statusReadOnlyOff", "the off key")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Restraint).#FOOTERKEYENFORCED, "statusReadOnlyEnforced", "the enforced key")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Restraint).#FOOTERKEYDEFINITION, "statusReadOnlyByDefinition", "and the by-the-definition key")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Restraint).#AUDIENCEEVERYONE, "everyone", "the everyone audience, which resolves the published banner's slot")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Restraint).#AUDIENCEYOU, "you", "and the you audience")
}

/// <p>Set definition <var>pId</var>'s read-only flag directly, through the production update path
/// with the security snapshot taken first so no field appears changed.</p>
ClassMethod SetDefinitionReadOnly(pId As %String, pReadOnly As %Boolean) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit $$$ERROR($$$GeneralError, "No agent definition with id " _ pId)
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set tRow.ReadOnly = pReadOnly
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    Quit tSC
}

}
