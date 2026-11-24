/// <p>Pins Story 24.17 Batch 2's purges end to end against back-dated probes in <code>USER</code> (AD-6, AD-7, AD-14, AD-15, AD-22, AD-51, AD-53, AD-58, AD-59, AD-62): a person's Purge and the agent's
/// confirmed proposal each remove, through the vendor's own <code>Ens.Purge.PurgeRuleLogsByDate</code> and <code>PurgeBusinessProcessesByDate</code>, the rule log entries and their debug rows, and the
/// completed business processes, dated years before the cut-off, and keep the one made now and the business process still running; the counts read the change. The vendor audits no purge, so
/// OcuPilot's own <code>ConfigChange</code> is the record, naming the namespace, the days, the count deleted and that it completed. The script form renders the switch and the vendor call and runs
/// nothing, and the agent's card is destructive and states its own consequence.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropLogPurgeCase</class> needs.</p>
Class OcuPilot.Test.InteropLogPurgeControl Extends OcuPilot.Test.InteropLogPurgeCase
{

/// <p>Mint the agent's purge of the log <var>pKind</var> for <var>pDays</var>, confirm it over the wire and answer the confirm's status; the proposal is in <var>pProposal</var>, its turn in
/// <var>pTurn</var> (the caller removes it) and the confirmed answer in <var>pConfirmed</var>. The governance keys must be on.</p>
ClassMethod AgentPurge(pKind As %String, pDays As %String, Output pProposal, Output pTurn, Output pConfirmed, Output pReason As %String) As %Integer
{
    Set pConfirmed = ""
    Set tVerdict = ..Mint(pKind, pDays, .pReason, .pProposal, .pTurn)
    If tVerdict '= "minted" Quit -1
    Set tSC = ..Confirm(pProposal.proposalId, .tStatus, .tRaw, .pConfirmed)
    Quit tStatus
}

/// <p>Both tools are declared as the plan says: destructive, behind a governance key that ships off, fingerprinting the days and the namespace, performing the classic page's purge, and the
/// governance baseline lists each key.</p>
/// <p>Mutation (Rule 19): make <class>OcuPilot.Screen.Tool.InteropRuleLogPurge</class>'s <code>FINGERPRINTSUBJECT</code> name <code>Count</code> too -- this goes red.</p>
Method TestBothToolsAreDeclaredDestructiveAndShipOff()
{
    For tKind = "rule", "process" {
        Set tTool = ..Spec(tKind, "tool")
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $Parameter(tTool, "DESTRUCTIVE") _ "|" _ $Parameter(tTool, "WRITETYPE") _ "|" _ $Parameter(tTool, "READTYPE") _ "|" _ $Parameter(tTool, "CONSEQUENCECODE"), ..Spec(tKind, "key") _ "|1|" _ ..Spec(tKind, "write") _ "|" _ ..Spec(tKind, "state") _ "|" _ ..Spec(tKind, "consequence"), tKind _ ": its name, that it is destructive, its write, its fresh read and its consequence")
        Do $$$AssertEquals($Parameter(tTool, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(tTool, "READANSWERS") _ "|" _ $Parameter(tTool, "PRECONDITIONFIELD"), "DaysToKeep,Namespace|Count,DaysToKeep,Namespace|Namespace", tKind _ ": it fingerprints the days and the namespace, not the count, which the log changes by itself")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed(..Spec(tKind, "key"), .tListed) _ "|" _ tListed, "0|1", tKind _ ": its governance key is listed and ships off")
        Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}), ..Spec(tKind, "consequence"), tKind _ ": it states one consequence")
        Do $$$AssertEquals(##class(OcuPilot.Api.InteropError).ReasonFor(..Spec(tKind, "consequence")) '= "", 1, tKind _ ": which has its published sentence")
    }
}

/// <p>AC2: a person's Purge and the agent's confirmed proposal each delete the back-dated rule log entries and their debug rows and keep the one made now, and the counts read the change. Each records
/// one <code>ConfigChange</code> naming the namespace, the days, the count deleted and that the purge completed; the agent's card is destructive and states the consequence, nothing is deleted by
/// the mint, and its confirm is marked and ledgered once.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformLogPurge</method> pass <code>0</code> days to the vendor -- the kept-current-entry leg goes red.</p>
Method TestARuleLogPurgeFromEitherCallerDeletesTheOldEntriesAndTheirDebugRows()
{
    Set tFx = ..#FIXTURE
    Set tOldError = ..Probe("rule", ..#SOURCE, 7300, 1, 1)
    Set tOldPlain = ..Probe("rule", ..#SOURCE, 7300, 0, 0)
    Set tNew = ..Probe("rule", ..#SOURCE, 0, 0, 1)
    Do $$$AssertTrue((tOldError > 0) && (tOldPlain > 0) && (tNew > 0) && ($ClassMethod(tFx, "DebugRows", ..#SOURCE, tOldError) > 0) && ($ClassMethod(tFx, "DebugRows", ..#SOURCE, tNew) > 0), "two old entries and one made now are stored, two with a debug row")
    Set tBefore = ..Rows("rule")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act("rule", 3650, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's Purge answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "updated|interop-rule-log", "publishing the updated event for the rule log")
    Do $$$AssertEquals(..Exists("rule", ..#SOURCE, tOldError) _ ..Exists("rule", ..#SOURCE, tOldPlain) _ ..Exists("rule", ..#SOURCE, tNew), "001", "the old entries are gone and the one made now stays")
    Do $$$AssertEquals($ClassMethod(tFx, "DebugRows", ..#SOURCE, tOldError), 0, "the old entry's debug row went with it")
    Do $$$AssertEquals($ClassMethod(tFx, "DebugRows", ..#SOURCE, tNew), 1, "and the current entry's debug row stays")
    Do $$$AssertEquals(..Rows("rule"), tBefore - 2, "the log's count fell by the two deleted")
    Kill tQuery
    Do ..Verdict("rule", "state", .tState, .tFault, .tQuery)
    Do $$$AssertEquals(tState.Count, ..Rows("rule"), "and the state read says so")
    Do $$$AssertEquals(..OwnRows("rule", tSince, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData [ """daysToKeep"":3650") && (tData [ """deleted"":2") && (tData [ """completed"":true"), "naming the namespace, the days, the count deleted and that it completed: " _ tData)
    Do $ClassMethod(tFx, "DropProbes")
    Set tOldError = ..Probe("rule", ..#SOURCE, 7300, 1, 1)
    Set tOldPlain = ..Probe("rule", ..#SOURCE, 7300, 0, 0)
    Set tNew = ..Probe("rule", ..#SOURCE, 0, 0, 1)
    Do $$$AssertTrue((tOldError > 0) && (tOldPlain > 0) && (tNew > 0), "the probes are stored again, from nothing, for the agent's purge")
    Set tSC = ..EnableKeys(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the purges' governance keys are turned on")
    Try {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $$$AssertEquals(..Mint("rule", 3650, .tReason, .tProposal, .tTurn), "minted", "the agent's purge mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-rule-log|USER|USER", "the target is the namespace's log")
        Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""DaysToKeep"",""before"":"""",""after"":""3650""}]", "its card shows the days it will keep")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.RULELOG.PURGE|1", "its consequence says what a purge deletes, and it is destructive")
        Do $$$AssertEquals(..Exists("rule", ..#SOURCE, tOldError) _ ..Exists("rule", ..#SOURCE, tOldPlain), "11", "nothing is deleted by the mint")
        Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals(tStatus, 200, "the proposal confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action, 1: ""), "1|updated", "marked (AD-15)")
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "interop.rulelog.purge"), 1, "the confirmed write is in the ledger once")
        Do $$$AssertEquals(..Exists("rule", ..#SOURCE, tOldError) _ ..Exists("rule", ..#SOURCE, tOldPlain) _ ..Exists("rule", ..#SOURCE, tNew), "001", "the old entries are gone and the one made now stays")
        Do $$$AssertEquals(..OwnRows("rule", tSince, .tAgentData), 1, "OcuPilot records one ConfigChange for the agent's purge")
        Do $$$AssertTrue((tAgentData [ """daysToKeep"":3650") && (tAgentData [ """deleted"":2") && (tAgentData [ """completed"":true"), "naming the days, the count and that it completed: " _ tAgentData)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2: a person's Purge and the agent's confirmed proposal each delete the back-dated completed business process and keep both the one made now and the old one still running (the vendor's
/// integrity, which is always kept), and the counts read the change; each records one <code>ConfigChange</code>. The card is destructive and states the business process consequence.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.VendorLogPurge</method> pass integrity <code>0</code> to the vendor -- the old running business process goes and this goes red.</p>
Method TestABusinessProcessPurgeFromEitherCallerKeepsTheRunningOneAndTheCurrentOne()
{
    Set tFx = ..#FIXTURE
    Set tOldDone = ..Probe("process", ..#SOURCE, 7300, 1)
    Set tOldRunning = ..Probe("process", ..#SOURCE, 7300, 0)
    Set tNewDone = ..Probe("process", ..#SOURCE, 0, 1)
    Do $$$AssertTrue((tOldDone > 0) && (tOldRunning > 0) && (tNewDone > 0), "an old completed, an old running and a current completed business process are stored")
    Set tBefore = ..Rows("process")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act("process", 3650, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's Purge answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "updated|interop-process-log", "publishing the updated event for the business process log")
    Do $$$AssertEquals(..Exists("process", ..#SOURCE, tOldDone) _ ..Exists("process", ..#SOURCE, tOldRunning) _ ..Exists("process", ..#SOURCE, tNewDone), "011", "only the old completed one is gone: the running one and the current one stay")
    Do $$$AssertEquals(..Rows("process"), tBefore - 1, "the count fell by the one deleted")
    Do $$$AssertEquals(..OwnRows("process", tSince, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData [ """daysToKeep"":3650") && (tData [ """deleted"":1") && (tData [ """completed"":true"), "naming the namespace, the days, the count deleted and that it completed: " _ tData)
    Do $ClassMethod(tFx, "DropProbes")
    Set tOldDone = ..Probe("process", ..#SOURCE, 7300, 1)
    Set tOldRunning = ..Probe("process", ..#SOURCE, 7300, 0)
    Set tNewDone = ..Probe("process", ..#SOURCE, 0, 1)
    Set tSC = ..EnableKeys(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the purges' governance keys are turned on")
    Try {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $$$AssertEquals(..Mint("process", 3650, .tReason, .tProposal, .tTurn), "minted", "the agent's purge mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-process-log|USER|USER", "the target is the namespace's log")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.PROCESSLOG.PURGE|1", "its consequence is the business process one, and it is destructive")
        Do $$$AssertEquals(..Exists("process", ..#SOURCE, tOldDone), 1, "nothing is deleted by the mint")
        Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals(tStatus, 200, "the proposal confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "interop.processlog.purge"), 1, "the confirmed write is in the ledger once")
        Do $$$AssertEquals(..Exists("process", ..#SOURCE, tOldDone) _ ..Exists("process", ..#SOURCE, tOldRunning) _ ..Exists("process", ..#SOURCE, tNewDone), "011", "only the old completed one is gone")
        Do $$$AssertEquals(..OwnRows("process", tSince, .tAgentData), 1, "OcuPilot records one ConfigChange for the agent's purge")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC2: the person's Purge is not behind the agent's governance key, which ships off: with both keys off the agent's proposal is refused at its confirm and deletes nothing, and the person's
/// Purge runs.</p>
/// <p>Mutation (Rule 19): list <code>interop.rulelog.purge</code> as <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -- the confirm is not refused and this goes red.</p>
Method TestTheAgentsKeyShipsOffAndThePersonsPurgeIsNotBehindIt()
{
    For tKind = "rule", "process" {
        Set tOld = ..Probe(tKind, ..#SOURCE, 7300, 1)
        Set tVerdict = ..Mint(tKind, 3650, .tReason, .tProposal, .tTurn)
        Do $$$AssertEquals(tVerdict, "minted", tKind _ ": the agent's purge mints: " _ tReason)
        If $IsObject($Get(tProposal)) {
            Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tConfirmed)
            Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: ""), "403 GOVERNANCE.DISABLED", tKind _ ": its confirm is refused while the key is off: " _ $Extract($Get(tRaw), 1, 300))
        }
        Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tOld), 1, tKind _ ": and nothing was deleted")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        Do $$$AssertEquals(..Act(tKind, 3650, .tAnswer), "200 ", tKind _ ": the person's Purge runs: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
        Do $$$AssertEquals(..Exists(tKind, ..#SOURCE, tOld), 0, tKind _ ": and deletes the old probe")
    }
}

/// <p>AC7: the script form of each purge names the namespace and calls the vendor's purge with the days the draft carries, with integrity kept for business processes, and runs nothing; days past the
/// instance's calendar are the calendar's own count as the port passes them; days or a namespace the port would refuse render no script.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.LogPurgeSnippet</method> render the call with integrity <code>0</code> -- this goes red.</p>
Method TestTheScriptFormRendersTheVendorCallAndRunsNothing()
{
    Set tOldRule = ..Probe("rule", ..#SOURCE, 7300, 1)
    Set tOldProcess = ..Probe("process", ..#SOURCE, 7300, 1)
    Set tCalls("rule") = "##class(Ens.Purge).PurgeRuleLogsByDate(@, .tDeleted)"
    Set tCalls("process") = "##class(Ens.Purge).PurgeBusinessProcessesByDate(@, .tDeleted, 1)"
    For tKind = "rule", "process" {
        Kill tScript
        Set tScript("namespace") = ..#SOURCE
        Set tScript("id") = ..#SOURCE
        Set tScript("days") = "3650"
        Set tType = ..Spec(tKind, "write")
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..Spec(tKind, "endpoint"), tType, .tScript, "")
        Do $$$AssertEquals(tSteps.%Size(), 1, tKind _ ": one step is rendered")
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue(tText [ "Set $NAMESPACE = ""USER""", tKind _ ": it names the namespace: " _ tText)
        Do $$$AssertTrue(tText [ $Replace(tCalls(tKind), "@", "3650"), tKind _ ": and calls the vendor's purge with the days: " _ tText)
        Set tScript("days") = "99999"
        Set tPast = $ClassMethod(..#PORT, "Snippet", ..Spec(tKind, "endpoint"), tType, .tScript, "")
        Set tText = $Select(tPast.%Size() = 1: tPast.%Get(0).text, 1: "")
        Do $$$AssertTrue(tText [ $Replace(tCalls(tKind), "@", "+$Horolog - 2"), tKind _ ": days past the instance's calendar are the calendar's own count: " _ tText)
        For tDays = "-1", "1.5", "100000", "x", "" {
            Set tScript("days") = tDays
            Set tNone = $ClassMethod(..#PORT, "Snippet", ..Spec(tKind, "endpoint"), tType, .tScript, "")
            Do $$$AssertEquals(tNone.%Size(), 0, tKind _ ": days '" _ tDays _ "' render no script")
        }
        Set tScript("days") = "3650"
        Set tScript("namespace") = "US ER"""
        Set tNoNamespace = $ClassMethod(..#PORT, "Snippet", ..Spec(tKind, "endpoint"), tType, .tScript, "")
        Do $$$AssertEquals(tNoNamespace.%Size(), 0, tKind _ ": a namespace of no shape renders no script")
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", ..Spec(tKind, "endpoint"), ..Spec(tKind, "state")), "", tKind _ ": the read has no script form")
    }
    Do $$$AssertEquals(..Exists("rule", ..#SOURCE, tOldRule) _ ..Exists("process", ..#SOURCE, tOldProcess), "11", "no draft deleted a probe")
}

}
