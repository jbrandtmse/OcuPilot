/// <p>Pins Story 24.17 Batch 1's managed alert update end to end against probe alerts in <code>USER</code> (AD-6, AD-14, AD-15, AD-22, AD-51, AD-53, AD-58, AD-59, AD-62): a person's Update
/// and the agent's confirmed proposal each leave the alert as the vendor's <code>Ens.Alerting.ManagedAlert</code> reads it (owner, open state, escalation level and next action time as sent),
/// add one history row naming the caller and the reason, and record one OcuPilot <code>ConfigChange</code> that names the changed fields and never the reason. A closed alert is opened
/// again, the next action time is the clock at the write plus the minutes, an update made after the agent's proposal closes it as moved, and the script form renders the guarded update and
/// runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropAlertCase</class> needs.</p>
Class OcuPilot.Test.InteropAlertUpdate Extends OcuPilot.Test.InteropAlertCase
{

/// <p>The user the test account's requests run as.</p>
ClassMethod Caller() As %String
{
    Quit ##class(OcuPilot.Test.Http).GetTestUsername()
}

/// <p>The stamp <var>pStamp</var>, <code>YYYY-MM-DD HH:MM:SS[.fff]</code>, as seconds since the calendar's day 0.</p>
ClassMethod Seconds(pStamp As %String) As %Numeric
{
    Set tH = $ZDateTimeH(pStamp, 3)
    Quit ($Piece(tH, ",", 1) * 86400) + $Piece(tH, ",", 2)
}

/// <p>The screen is declared as the plan places it: the Managed alerts list at side bar 22 with the one row action Update, its history a sub-screen that is never listed, and the tool is not
/// destructive, ships on and fingerprints what it reviewed.</p>
/// <p>Mutation (Rule 19): change the Managed alerts screen's row action id to <code>edit</code> -- this goes red.</p>
Method TestTheUpdateIsDeclaredAsTheRowActionOfTheManagedAlertsScreen()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropManagedAlertList).DeclarationJson(.tList)
    Do $$$AssertStatusOK(tSC, "the list declares JSON")
    If '$IsObject($Get(tList)) Quit
    Do $$$AssertEquals(tList.route _ "|" _ tList.sideBarPosition _ "|" _ tList.entityType _ "|" _ tList.rowActions.%Size() _ "|" _ tList.rowActions.%Get(0).id _ "|" _ tList.toolIdentifier, "interoperability/managed-alerts|22|interop-managed-alert|1|update|interop.managedalerts", "its route, place, entity type, one action and tool identifier")
    Do $$$AssertEquals(tList.classicPage, "EnsPortal.ManagedAlertViewer", "its classic page is the viewer, whose rows it shows")
    Do $$$AssertEquals(tList.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_Alerts"",""permission"":""READ""}]", "its pairs are the classic pages'")
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropManagedAlertHistory).DeclarationJson(.tHistory)
    Do $$$AssertStatusOK(tSC, "the history declares JSON")
    If '$IsObject($Get(tHistory)) Quit
    Do $$$AssertEquals(tHistory.route _ "|" _ tHistory.sideBarPosition _ "|" _ tHistory.entityType _ "|" _ tHistory.rowActions.%Size() _ "|" _ tHistory.parentScope, "interoperability/managed-alerts/history|0||0|interoperability/managed-alerts", "the history is a sub-screen that is never listed, read-only, with no entity type")
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $Parameter(tTool, "DESTRUCTIVE") _ "|" _ $Parameter(tTool, "WRITETYPE") _ "|" _ $Parameter(tTool, "CLASSICPAGES"), "interop.managedalerts.update|0|UPDATEALERT|EnsPortal.ManagedAlerts", "the tool is not destructive and performs the Alerts page's Update")
    Do $$$AssertEquals($Parameter(tTool, "FINGERPRINTSUBJECT"), "CurrentOwner,IsOpen,EscalationLevel,NextActionTime,ActionCount,Namespace,Owner,Open,NextActionMinutes,Reason", "and fingerprints what it reviewed")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed(..#KEY, .tListed) _ "|" _ tListed, "1|1", "its governance key is listed and ships on")
}

/// <p>AC2: a person's Update and the agent's confirmed proposal each leave the alert as sent: the person assigns an alert to themselves and then closes it; the agent raises another's level
/// by one and sets its next action 60 minutes ahead. Each reads back as sent through the vendor's own class, adds one history row naming the caller and the reason, and records one
/// <code>ConfigChange</code> naming the namespace and the changed fields, never the reason; the vendor records none of its own. The agent's confirm is marked, ledgered once and reads back
/// <code>matches</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformAlertUpdate</method> send every value's bit whether it changed or not -- this goes red.</p>
Method TestAnUpdateFromEitherCallerReadsBackAsSentWithOneHistoryRowEach()
{
    Set tFx = ..#FIXTURE
    Set tCaller = ..Caller()
    Set tPerson = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "for the person")
    Set tAgent = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "for the agent")
    Do $$$AssertTrue((tPerson > 0) && (tAgent > 0), "two probes are stored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act(tPerson, {"Owner": (tCaller), "Reason": "taking it over"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the person's assignment answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "updated|interop-managed-alert|" _ tPerson, "publishing the updated event for the alert")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("readBack")): tAnswer.readBack.verdict, 1: ""), ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "whose read-back matches")
    Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tPerson), tCaller _ "|1|0|1", "the alert is assigned to the caller, still open, with one history row")
    Do $$$AssertEquals($ClassMethod(tFx, "Action", ..#SOURCE, tPerson, 1), tCaller _ "|1|taking it over", "naming the caller, the assign action and the reason")
    Do $$$AssertEquals(..OwnRows(tSince, tPerson, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData [ """CurrentOwner"":""" _ tCaller _ """") && (tData [ """completed"":true") && (tData '[ "taking it over"), "naming the namespace, the changed field and that it completed, and never the reason: " _ tData)
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropArchiveCase).VendorRows(tSince, "ManagedAlert"), 0, "and the vendor records none")
    Set tClose = ..Act(tPerson, {"Open": "0", "Reason": "resolved"}, .tClosed)
    Do $$$AssertEquals(tClose, "200 ", "closing it answers 200")
    Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tPerson), tCaller _ "|0|0|2", "the alert is closed with a second history row")
    Do $$$AssertEquals($ClassMethod(tFx, "Action", ..#SOURCE, tPerson, 2), tCaller _ "|2|resolved", "which names the close action and its reason")
    Do $$$AssertEquals(..OwnRows(tSince, tPerson, .tData2, 2), 2, "and a second ConfigChange")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBeforeAt = $ZDateTime($ZTimeStamp, 3, , 3)
    Do $$$AssertEquals(..Mint(tAgent, {"EscalationLevel": 1, "NextActionMinutes": 60, "Reason": "the agent raises it"}, .tReason, .tProposal, .tTurn), "minted", "the agent's update mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Try {
        Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-managed-alert|" _ ..#SOURCE _ "|" _ tAgent, "the target is the alert")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.ALERT.UPDATE|0", "its consequence says what an update saves, and it is not destructive")
        Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tAgent), "|1|0|0", "nothing is changed by the mint")
        Set tSC = ..Confirm(tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
        Do $$$AssertEquals(tConfirmStatus, 200, "the proposal confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("auditMarked") _ "|" _ tConfirmed.action, 1: ""), "1|updated", "marked (AD-15)")
        Do $$$AssertEquals($Select($IsObject(tConfirmed) && $IsObject(tConfirmed.%Get("readBack")): tConfirmed.readBack.verdict, 1: ""), ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "and reads back as sent")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropItemControl).LedgerCount(tTurn, ..#KEY), 1, "the confirmed write is in the ledger once")
        Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tAgent), "|1|1|1", "the level is one up, with one history row")
        Set tAfterAt = $ZDateTime($ZTimeStamp, 3, , 3)
        Set tNext = $ClassMethod(tFx, "NextTime", ..#SOURCE, tAgent)
        Do $$$AssertTrue((tNext '= "") && (..Seconds(tNext) '< (..Seconds(tBeforeAt) + 3600)) && (..Seconds(tNext) '> (..Seconds(tAfterAt) + 3600)), "the next action time is the clock at the write plus 60 minutes: " _ tNext)
        Do $$$AssertEquals($ClassMethod(tFx, "Action", ..#SOURCE, tAgent, 1), ##class(OcuPilot.Test.Http).GetTestUsername() _ "|12|the agent raises it", "its row names the caller, both changed bits and the reason")
        Do $$$AssertEquals(..OwnRows(tSince, tAgent, .tAgentData), 1, "OcuPilot records one ConfigChange for the agent's update")
        Do $$$AssertTrue((tAgentData [ """EscalationLevel"":1") && (tAgentData [ """NextActionTime"":") && (tAgentData '[ "the agent raises it"), "naming the level and the next action time, not the reason: " _ tAgentData)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC2: a closed alert is opened again by an update of its open state, and the history says so; the vendor words that row <code>Close</code>, which is its own text for the open-state action.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformAlertUpdate</method> send the open bit only when the alert is open -- this goes red.</p>
Method TestAClosedAlertIsOpenedAgain()
{
    Set tFx = ..#FIXTURE
    Set tId = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 0, 0, "closed")
    Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tId), "|0|0|0", "the probe is closed")
    Set tText = ..Act(tId, {"Open": "1", "Reason": "it came back"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the reopening answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tId), "|1|0|1", "the alert is open again with one history row")
    Do $$$AssertEquals($ClassMethod(tFx, "Action", ..#SOURCE, tId, 1), ..Caller() _ "|2|it came back", "the row is the open-state action and its reason")
    Kill tQuery
    Set tQuery("alert") = tId
    Do ..Verdict("ManagedAlertActions", "LIST", .tHistory, .tFault, .tQuery)
    Do $$$AssertEquals($Select($IsObject($Get(tHistory)) && tHistory.%Size(): tHistory.%Get(0).Action _ "|" _ tHistory.%Get(0).NewValues, 1: ""), "Close|IsOpen: 1", "and the history reads it in the vendor's words")
}

/// <p>AC2: an update made after the agent's proposal closes the confirm as moved, and nothing is saved by it: the proposal's fingerprint covers the number of history rows, so any update does.</p>
/// <p>Mutation (Rule 19): drop <code>ActionCount</code> from <parameter>OcuPilot.Screen.Tool.InteropManagedAlertUpdate.FINGERPRINTSUBJECT</parameter> and from the fields it names -- this goes red.</p>
Method TestAnUpdateAfterTheMintClosesTheConfirmTargetChanged()
{
    Set tFx = ..#FIXTURE
    Set tId = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "to be moved")
    Do $$$AssertEquals(..Mint(tId, {"EscalationLevel": 1, "Reason": "raise it"}, .tReason, .tProposal, .tTurn), "minted", "the agent's update mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Kill tValues
    Set tValues("EscalationLevel") = 1
    Do $$$AssertStatusOK($ClassMethod(tFx, "Touch", ..#SOURCE, tId, 4, .tValues, "somebody else"), "another update is made after the mint")
    Set tSC = ..Confirm(tProposal.proposalId, .tConfirmStatus, .tRaw, .tConfirmed)
    Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tConfirmStatus), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tId), "|1|1|1", "and the alert holds the other update alone")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC6: the script form of the update names the namespace, finds the alert, guards the administration pair, the owner, the level step and a change of nothing each in one line, sets only the
/// values that differ with the bits the vendor reads, and calls <code>UpdateManagedAlert</code>; it runs nothing. A bad id or a value outside its shape renders no draft.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AlertSnippet</method> skip the shape check of the reason -- the 501 character leg goes red.</p>
Method TestTheScriptFormRendersTheGuardedUpdateAndRunsNothing()
{
    Set tFx = ..#FIXTURE
    Set tId = $ClassMethod(tFx, "Probe", ..#SOURCE, "", 1, 0, "for the draft")
    Kill tScript
    Set tScript("namespace") = ..#SOURCE
    Set tScript("id") = tId
    Set tScript("alertowner") = "irisowner"
    Set tScript("alertopen") = 0
    Set tScript("alertlevel") = 1
    Set tScript("alertminutes") = 90
    Set tScript("alertreason") = "it is ""done"""
    Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "UPDATEALERT", .tScript, "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step is rendered")
    Set tText = ..StepText(tSteps)
    Do $$$AssertTrue(tText [ "Set $NAMESPACE = ""USER""", "it names the namespace: " _ tText)
    For tKind = "id", "owner", "level" {
        Do $$$AssertTrue(tText [ $ClassMethod(..#PORT, "AlertProblem", tKind), tKind _ " is a guard line: " _ tText)
    }
    Do $$$AssertTrue(tText [ ##class(OcuPilot.Api.InteropError).#REASONALERTUNCHANGED, "a change of nothing is a guard line: " _ tText)
    Do $$$AssertTrue(tText [ "%Ens_AlertAdministration", "so is the administration pair: " _ tText)
    Do $$$AssertTrue((tText [ "tBits = tBits + 1") && (tText [ "tBits = tBits + 2") && (tText [ "tBits = tBits + 4") && (tText [ "tBits = tBits + 8") && (tText [ "DATEADD(""mi"", 90"), "it sets each value with its own bit and the minutes from now: " _ tText)
    Do $$$AssertTrue(tText [ "UpdateManagedAlert(tId, tBits, .tNew, ""it is """"done"""""")", "and calls the vendor's update with the reason as a string literal: " _ tText)
    Do $$$AssertEquals($ClassMethod(tFx, "State", ..#SOURCE, tId), "|1|0|0", "the draft changed nothing")
    Kill tBad
    Set tBad(1) = $ListBuild("id", "12x")
    Set tBad(2) = $ListBuild("alertlevel", "-1")
    Set tBad(3) = $ListBuild("alertminutes", "0")
    Set tBad(4) = $ListBuild("alertminutes", "20161")
    Set tBad(5) = $ListBuild("alertreason", "tab" _ $Char(9) _ "here")
    Set tBad(6) = $ListBuild("alertreason", $Translate($Justify("", 501), " ", "x"))
    Set tBad(7) = $ListBuild("alertreason", "")
    Set tBad(8) = $ListBuild("alertopen", "2")
    Set tBad(9) = $ListBuild("alertowner", "a" _ $Char(10) _ "b")
    For tI = 1:1:9 {
        Kill tQuery
        Merge tQuery = tScript
        Set tQuery($List(tBad(tI), 1)) = $List(tBad(tI), 2)
        Set tBadSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "UPDATEALERT", .tQuery, "")
        Do $$$AssertEquals(tBadSteps.%Size(), 0, "a bad value renders no draft: " _ $List(tBad(tI), 1) _ " " _ $Extract($List(tBad(tI), 2), 1, 20))
    }
    Set tScript("alertlevel") = 5
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "UPDATEALERT", .tScript, "").%Size(), 1, "a level that is far from the current one is a shape the script form accepts and its guard refuses when it runs")
}

}
