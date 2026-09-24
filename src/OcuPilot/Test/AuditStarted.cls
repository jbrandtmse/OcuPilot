/// <p>Pins a queued audit copy still running at the port's bound (AD-26, AD-15, AD-41): through
/// <class>OcuPilot.Test.AuditStartedPort</class>, whose vendor task is never terminal at the bound,
/// the audit port answers that the copy has started, the agent's confirm marks it, finalizes its
/// ledger row applied and answers <code>continues</code>, the screen route answers
/// <code>continues</code>, and the vendor's worker then finishes the copy; a copy the vendor fails keeps its
/// error.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, auditing on, a
/// <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>: it
/// copies the instance's audit database into <code>USER</code> and empties <code>USER</code>'s audit
/// globals before and after each method.</p>
Class OcuPilot.Test.AuditStarted Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "security.auditing.copy";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.AuditCopy";

Parameter PORT = "OcuPilot.Test.AuditStartedPort";

Parameter COPY = "OcuPilot.Test.AuditCopy";

Parameter TARGETNS = "USER";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditStarted copies this instance's audit database into USER, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was copied. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#PORT, "Clear")
    Quit $ClassMethod(..#COPY, "EmptyTarget")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $ClassMethod(..#PORT, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#COPY, "EmptyTarget"), "USER's audit globals are emptied")
    Quit $$$OK
}

/// <p>The copy the vendor's worker was still running at the bound finishes, and <code>USER</code>
/// then holds at least <var>pBefore</var> records.</p>
Method AssertTheWorkerFinishes(pBefore As %Integer)
{
    Set tGuid = $ClassMethod(..#PORT, "LastTask")
    Do $$$AssertNotEquals(tGuid, "", "the port polled a queued task")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Settle", tGuid), "Finished", "the vendor's worker finishes the copy after the port stopped waiting")
    Set tCopied = $ClassMethod(..#COPY, "Count", ..#TARGETNS)
    Do $$$AssertTrue(tCopied >= pBefore, "USER holds every record the instance held at the start: " _ tCopied _ " against " _ pBefore)
}

/// <p>AD-26, AD-15, AD-41 on the agent's caller: a confirmed copy still running at the bound is
/// answered 200 <code>confirmed</code> with <code>continues</code>, carries one agent-write marker
/// naming the proposal, and its ledger row is finalized <code>ok</code> and marked, never
/// <code>error</code>.</p>
/// <p>Mutation (Rule 19): remove the started branch from
/// <method>OcuPilot.Port.AuditPort.Invoke</method> -> the confirm answers 503
/// <code>PORT.TIMEOUT</code>, no marker is written and the row reads <code>error</code>, and this
/// goes red.</p>
Method TestAnAgentCopyStillRunningAtTheBoundIsAppliedAndMarked()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": "SYSTEM", "CopyNamespace": (..#TARGETNS)}, 0, .tProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the copy is minted: " _ $System.Status.GetErrorText(tSC))
    If '$IsObject($Get(tProposal)) Quit
    Set tProposalId = tProposal.%Get("proposalId")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = $ClassMethod(..#COPY, "Count", "%SYS")
    Do $$$AssertTrue(tBefore > 0, "the instance's audit database holds records to copy (" _ tBefore _ ")")
    Set tSC = ##class(OcuPilot.Test.AuditStartedConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds: " _ $Get(tCode))
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tResult)): tResult.%Get("state") _ " " _ tResult.%Get("continues") _ " " _ tResult.%Get("auditMarked"), 1: ""), "200 confirmed 1 1", "answered confirmed, continuing on the instance, and marked")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposalId _ """", .tData), 1, "the audit database carries one agent-write marker naming this proposal (AD-15)")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row on the proposal's turn")
    Do $$$AssertEquals($Get(tRow("Status")) _ " " _ $Get(tRow("AuditMarked")), "ok " _ $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "finalized applied and marked, not error (AD-41)")
    Do ..AssertTheWorkerFinishes(tBefore)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>AD-26, AD-53 on the screen's caller: a copy still running at the bound is answered
/// <code>updated</code> on the auditing configuration with <code>continues</code>, and emits no
/// agent-write marker.</p>
/// <p>Mutation (Rule 19): drop the <code>continues</code> line from
/// <method>OcuPilot.Api.ScreenAction.Run</method> -> this goes red.</p>
Method TestTheScreenRouteAnswersThatACopyStillRunningContinues()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = $ClassMethod(..#COPY, "Count", "%SYS")
    Do $$$AssertTrue(tBefore > 0, "the instance's audit database holds records to copy (" _ tBefore _ ")")
    Set tSC = ##class(OcuPilot.Test.AuditStartedAction).Copy(..#TARGETNS, .tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the screen route runs")
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch { Set tBody = "" }
    Do $$$AssertEquals(tStatus, 200, "answered 200: " _ $Get(tAnswer))
    Do $$$AssertEquals($Select($IsObject(tBody) && (tBody.%GetTypeOf("target") = "object"): tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("type") _ " " _ tBody.%Get("continues"), 1: ""), "updated auditing-configuration 1", "publishing updated, and continuing on the instance")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOL, .tData), 0, "the screen path emits no agent-write marker (AD-53)")
    Do ..AssertTheWorkerFinishes(tBefore)
}

/// <p>AD-26: only the bound makes a queued write started. A copy the vendor's worker fails -- into
/// a namespace that does not exist, sent to the shipped audit port past the tool's own check --
/// keeps its error: not OK, not answered <code>STARTEDHTTP</code>, and its fault is not the bound's.</p>
/// <p>Mutation (Rule 19): drop the <code>PORT.TIMEOUT</code> test from the started branch of
/// <method>OcuPilot.Port.AuditPort.Invoke</method> -> the failure is answered as started and this
/// goes red.</p>
Method TestAQueuedWriteTheVendorFailsKeepsItsError()
{
    Kill tQuery
    Set tQuery("CopyNamespace") = "NOSUCHNS"
    Set tSC = ##class(OcuPilot.Port.AuditPort).Invoke("Security.Audit.Record", "COPY", .tQuery, "", .tResult, .tHttp, .tFault)
    Set tCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    Do $$$AssertTrue($$$ISERR(tSC), "the vendor's failed copy is an error, not a success")
    Do $$$AssertNotEquals(+$Get(tHttp), $Parameter("OcuPilot.Port.AuditPort", "STARTEDHTTP"), "and is not answered as started")
    Do $$$AssertTrue((tCode '= "") && (tCode '= ##class(OcuPilot.Api.Error).#PORTTIMEOUT), "its fault is the vendor's failure, not the bound's: " _ tCode)
}

}
