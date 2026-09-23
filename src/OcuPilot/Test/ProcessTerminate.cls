/// <p>Pins Story 7.8's two terminate tools and their port (AD-51, AD-52, AD-53, AD-6, AD-10): what
/// each tool and both process screens declare, the terminate's state row and its refusals over
/// canned reads, a mint covering <code>StartTimeUTC</code> and refused
/// <code>PROPOSAL.TARGETCHANGED</code> once it moves, <class>OcuPilot.Port.ProcessPort</class>'s
/// guard, and the prohibited set's two process refusals for both tools.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%Admin_Operate:USE</code>, <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code>,
/// on an instance running at least one process of a kind the allow-list does not admit.</p>
/// <p><b>It terminates nothing.</b> The mint and the confirm go through
/// <class>OcuPilot.Test.ProposalFixture</class>'s port; the port legs send a terminate only to a pid
/// no process carries, and to this test's own job after reading that the instance refuses to
/// terminate it; the prohibited set is asked, never applied.</p>
Class OcuPilot.Test.ProcessTerminate Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DETAILS = "OcuPilot.Screen.Descriptor.ProcessDetails";

Parameter TERMINATE = "OcuPilot.Screen.Tool.ProcessTerminate";

Parameter WITHERROR = "OcuPilot.Screen.Tool.ProcessTerminateWithError";

Parameter PORT = "OcuPilot.Port.ProcessPort";

Parameter PROBEPORT = "OcuPilot.Test.ProcessPortProbe";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A pid no process carries.</p>
Parameter ABSENTPID = "999999999";

/// <p>A running process as <code>Process</code>'s <code>GET</code> answers it (the fields the tools
/// and the set read).</p>
Parameter FRESHRUNNING = "{""Pid"":999999999,""State"":""RUN"",""StartTimeUTC"":""2026-09-23 10:00:00"",""JobType"":2,""UserName"":""OcuPilotProbeProcessOwner"",""CommandsExecuted"":1678}";

/// <p>The same process after its state and counters moved.</p>
Parameter FRESHBUSY = "{""Pid"":999999999,""State"":""HANG"",""StartTimeUTC"":""2026-09-23 10:00:00"",""JobType"":2,""UserName"":""OcuPilotProbeProcessOwner"",""CommandsExecuted"":6004249}";

/// <p>A later process that reuses the pid.</p>
Parameter FRESHREPLACED = "{""Pid"":999999999,""State"":""RUN"",""StartTimeUTC"":""2026-09-23 10:05:00"",""JobType"":2,""UserName"":""OcuPilotProbeProcessOwner"",""CommandsExecuted"":12}";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#PROBEPORT, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do $ClassMethod(..#PROBEPORT, "Clear")
    Quit $$$OK
}

/// <p>AC1, AC3, AC5: both tools are destructive bodyless <code>TERMINATE</code> writes over the
/// processes list, fingerprinted over <code>Pid,StartTimeUTC</code>, each carrying one screen
/// action; the second differs only in its name, action, port, after-value and port query; each
/// description says OcuPilot's own and system processes are refused; and both process screens
/// declare the four actions, none self-protected.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.ProcessTerminateWithError.PORTCLASS</parameter>
/// -- the port assertion goes red.</p>
Method TestTheTwoToolsAndBothScreensDeclareTheTerminate()
{
    For tClass = ..#TERMINATE, ..#WITHERROR {
        Do $$$AssertEquals($ClassMethod(tClass, "WriteType"), "TERMINATE", tClass _ " issues the vendor's TERMINATE")
        Do $$$AssertEquals($ClassMethod(tClass, "ReadType"), "GET", "after reading the process's GET")
        Do $$$AssertEquals($ClassMethod(tClass, "SendsBody"), 0, "with no body")
        Do $$$AssertEquals($ClassMethod(tClass, "Destructive"), 1, "and is destructive")
        Do $$$AssertEquals($ClassMethod(tClass, "ChangeAction"), "deleted", "publishing a removal")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "Pid,StartTimeUTC", "fingerprinted over the pid and when it started")
        Do $$$AssertEquals($ClassMethod(tClass, "PreconditionField"), "StartTimeUTC", "which is what the precondition reads")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "and the registration guard holds adequate")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, "admitting no settable field")
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), ..#SCREEN, "over the processes list")
        Set tDescription = $Parameter(tClass, "DESCRIPTION")
        Do $$$AssertTrue(tDescription [ "an IRIS system process are both refused", "its description says a system process is refused: " _ tDescription)
        Do $$$AssertTrue(tDescription [ "OcuPilot is itself running in", "and so is OcuPilot's own")
    }
    Do $$$AssertEquals($Parameter(..#TERMINATE, "TOOLNAME"), "osmgmt.processes.terminate", "the terminate is named for the list")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TERMINATE, "ScreenActionIds")), "terminate", "and carries its terminate")
    Do $$$AssertEquals($ClassMethod(..#TERMINATE, "PortClass"), "OcuPilot.Port.AdminPort", "through the admin port")
    Do $$$AssertEquals($Parameter(..#TERMINATE, "STATEAFTER"), "Terminated", "ending Terminated")
    Do $$$AssertEquals($Parameter(..#WITHERROR, "TOOLNAME"), "osmgmt.processes.terminatewitherror", "the flagged terminate has its own name")
    Do $$$AssertEquals($ListToString($ClassMethod(..#WITHERROR, "ScreenActionIds")), "terminate-with-error", "and carries the dialog's flag")
    Do $$$AssertEquals($ClassMethod(..#WITHERROR, "PortClass"), ..#PORT, "through the process port")
    Do $$$AssertEquals($Parameter(..#WITHERROR, "STATEAFTER"), "Terminated, with a <RESJOB> error logged", "ending with the error logged")
    Do $$$AssertTrue($Parameter(..#WITHERROR, "DESCRIPTION") [ "application error log", "and its description names the error log")

    Kill tQuery
    Set tQuery("id") = ..#ABSENTPID
    Do $ClassMethod(..#TERMINATE, "PortQuery", {}, .tQuery)
    Do $$$AssertEquals($Order(tQuery("id")), "", "the plain terminate adds nothing to the port's query")
    Kill tQuery
    Set tQuery("id") = ..#ABSENTPID
    Do $ClassMethod(..#WITHERROR, "PortQuery", "", .tQuery)
    Do $$$AssertEquals($Get(tQuery($Parameter(..#PORT, "SENDERRORPARAM"))), 1, "while the flagged one asks its port for the flag, whatever the payload")
    Do $$$AssertEquals($Get(tQuery("id")), ..#ABSENTPID, "and leaves the identifying entry alone")

    Set tDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(..#WITHERROR)
    Do $$$AssertTrue($IsObject(tDefinition), "the flagged terminate is defined")
    If $IsObject(tDefinition) {
        Do $$$AssertEquals(tDefinition.Super, ..#TERMINATE, "as the terminate's subclass")
        Set tOwn = ""
        For tI = 1:1:tDefinition.Parameters.Count() {
            Set tOwn = tOwn _ $ListBuild(tDefinition.Parameters.GetAt(tI).Name)
        }
        Do $$$AssertEquals($ListLength(tOwn), 5, "declaring five parameters of its own: " _ $ListToString(tOwn))
        For tName = "TOOLNAME", "DESCRIPTION", "SCREENACTIONS", "PORTCLASS", "STATEAFTER" {
            Do $$$AssertTrue($ListFind(tOwn, tName) > 0, "among them " _ tName)
        }
        Do $$$AssertEquals(tDefinition.Methods.Count(), 1, "and one method, its port query")
    }

    Set tActions = "[{""id"":""suspend"",""selfProtection"":""""},{""id"":""resume"",""selfProtection"":""""},{""id"":""terminate"",""selfProtection"":""""},{""id"":""terminate-with-error"",""selfProtection"":""""}]"
    For tScreen = ..#SCREEN, ..#DETAILS {
        Set tSC = $ClassMethod(tScreen, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tScreen _ "'s declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(tDeclaration.rowActions.%ToJSON(), tActions, tScreen _ " declares Suspend, Resume, Terminate and the flag, none self-protected")
        Do $$$AssertEquals(tDeclaration.table.emptyAgentKey, "processListEmptyAgent", "its empty state invites the agent")
        Do $$$AssertEquals(tDeclaration.table.emptyNextKey, "", "and names no read-only next step")
    }
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    If $$$ISOK(tSC) Do $$$AssertEquals(tDeclaration.entityLabelKey, "proposalEntityProcess", "the list names its entity's noun")
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "and the registry validates every descriptor: " _ $Get(tProblem))
}

/// <p>AC5: <method>OcuPilot.Screen.Tool.ProcessTerminate.StateDiff</method> answers one row from
/// the state the instance reports to <code>Terminated</code>, the flagged one to its own
/// after-value, and a read with no <code>State</code> or no <code>StartTimeUTC</code> is a
/// problem.</p>
/// <p>Mutation (Rule 19): drop the absent-<code>StartTimeUTC</code> refusal -- the fail-closed leg
/// goes red.</p>
Method TestTheStateDiffNamesTheStateAndRefusesAnUnreadProcess()
{
    Set tSC = $ClassMethod(..#TERMINATE, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHRUNNING), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a running process answers")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""State"",""before"":""RUN"",""after"":""Terminated""}]", "and one row: the state it reads, then Terminated")

    Set tSC = $ClassMethod(..#WITHERROR, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHBUSY), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "the flagged terminate answers")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""State"",""before"":""HANG"",""after"":""Terminated, with a <RESJOB> error logged""}]", "with its own after-value")

    For tField = "State", "StartTimeUTC" {
        Set tRead = ##class(%DynamicAbstractObject).%FromJSON(..#FRESHRUNNING)
        Do tRead.%Remove(tField)
        Set tSC = $ClassMethod(..#TERMINATE, "StateDiff", tRead, .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, "a read with no " _ tField _ " answers")
        Do $$$AssertNotEquals(tProblem, "", "as a problem: " _ tProblem)
        Do $$$AssertEquals(tRows.%Size(), 0, "and no row")
    }
}

/// <p>AC5, AD-51: a terminate mint over a canned <code>GET</code> writes nothing and carries the
/// state row; a confirm after the pid was reused by a later process -- a new
/// <code>StartTimeUTC</code> -- is refused <code>PROPOSAL.TARGETCHANGED</code> with nothing sent,
/// while one whose state and counters alone moved sends a bodyless <code>TERMINATE</code> to the
/// fixture's port.</p>
/// <p>Mutation (Rule 19): drop <code>StartTimeUTC</code> from
/// <parameter>OcuPilot.Screen.Tool.ProcessTerminate.FINGERPRINTSUBJECT</parameter> -- the replaced
/// process's confirm succeeds and goes red.</p>
Method TestAMintCoversTheStartAndAReplacedProcessIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#TERMINATE, ..#ABSENTPID, .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "GET", "the fresh read is GET")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the mint wrote nothing")
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""State"",""before"":""RUN"",""after"":""Terminated""}]", "the card carries the terminate")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.%Get("proposalId"), "Destructive"), 1, "and the stored row is destructive")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHREPLACED)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "a confirm against a later process under the same pid is refused")
    Do $$$AssertEquals(+$Get(tHttp), 409, "at 409")
    Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "with the moved-target code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#TERMINATE, ..#ABSENTPID, .tSecond, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "a second proposal mints")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHBUSY)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tSecond.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "a process whose state and counters moved is still the one reviewed (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "one write reached the fixture's port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "TERMINATE", "as the vendor's terminate")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), ..#ABSENTPID, "carrying the pid")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), "", "and no body")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AD-52: <class>OcuPilot.Port.ProcessPort</class> repeats the vendor endpoint's guard before
/// <code>SYS.Process.Terminate(1)</code> -- 404 for a pid no process carries or a value that is not
/// a pid, and 409 for a process the instance will not terminate, which this test's own job is --
/// and the job is still running afterwards.</p>
/// <p>Mutation (Rule 19): make the <code>CanBeTerminated</code> refusal in
/// <method>OcuPilot.Port.ProcessPort.TerminateWithError</method> answer 500 -- the flagged 409 leg
/// goes red. (Removing the check instead would send a real terminate to this job.)</p>
Method TestTheProcessPortRepeatsTheVendorsGuardAndTerminatesNothing()
{
    Set tFlag = $Parameter(..#PORT, "SENDERRORPARAM")
    For tPid = ..#ABSENTPID, "notapid" {
        Kill tQuery
        Set tQuery("id") = tPid
        Set tQuery(tFlag) = 1
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Process", "TERMINATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "a terminate of '" _ tPid _ "' fails")
        Do $$$AssertEquals(+$Get(tHttp), 404, "at 404")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "as the admin port's own not-found code")
    }
    Kill tQuery
    Set tQuery("id") = ..#ABSENTPID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Process", "TERMINATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "which is what the vendor's own terminate answers for that pid")

    ; The 409 leg is asked of this job only once the instance has said it will not terminate it, so
    ; a build on which it would cannot end the test.
    Set tCanTerminate = ..CanBeTerminated($Job)
    Do $$$AssertEquals(tCanTerminate, 0, "the instance will not terminate the caller's own job")
    If tCanTerminate '= 0 Quit
    Kill tQuery
    Set tQuery("id") = $Job
    Set tQuery(tFlag) = 1
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Process", "TERMINATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "so the flagged terminate of this job is refused")
    Do $$$AssertEquals(+$Get(tHttp), 409, "at 409")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTCONFLICT, "as the admin port's own conflict code")
    Kill tQuery
    Set tQuery("id") = $Job
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Process", "TERMINATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 409, "and so is the unflagged one, which is the vendor's own guard")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTCONFLICT, "with the same conflict code")
    Do $$$AssertEquals(..CanBeTerminated($Job), 0, "and this job is still running")
}

/// <p>AD-52: the port's own gate. A caller that does not hold
/// <parameter>OcuPilot.Port.ProcessPort.GATERESOURCE</parameter> at <code>USE</code> is refused 403
/// before the process is looked up, so even a pid no process carries answers 403, not 404.</p>
/// <p>Mutation (Rule 19): remove the <code>HoldsResource</code> check from
/// <method>OcuPilot.Port.ProcessPort.TerminateWithError</method> -- the leg reads 404 and goes
/// red.</p>
Method TestTheProcessPortRefusesACallerShortOfItsGate()
{
    Do $ClassMethod(..#PROBEPORT, "Deny")
    Kill tQuery
    Set tQuery("id") = ..#ABSENTPID
    Set tQuery($Parameter(..#PORT, "SENDERRORPARAM")) = 1
    Set tSC = $ClassMethod(..#PROBEPORT, "Invoke", "Process", "TERMINATE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a flagged terminate by a caller short of the gate fails")
    Do $$$AssertEquals(+$Get(tHttp), 403, "at 403, before the process is looked up")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, "as the admin port's own access-denied code")
}

/// <p>A process that ends before the Terminate is confirmed: the screen route answers the port's
/// not-found for either action, sending no terminate, because the fresh read of a pid no process
/// carries fails first.</p>
Method TestAGonePidIsTheRoutesNotFound()
{
    For tAction = "terminate", "terminate-with-error" {
        Set tSC = ##class(OcuPilot.Test.ProcessControl).ActOn(tAction, ..#ABSENTPID, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody)
        Do $$$AssertStatusOK(tSC, tAction _ ": the screen action request completes")
        Do $$$AssertEquals(tStatus, 404, tAction _ ": and is answered 404: " _ tBody)
        If tStatus '= 404 Continue
        Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Api.Error).#PORTNOTFOUND, tAction _ ": with the port's not-found code")
        Do $$$AssertNotEquals(tEnvelope.%Get("reason"), "", tAction _ ": and a sentence to show")
    }
}

/// <p>AD-52: the port removes its own query parameter before the admin port's sequence, so the
/// vendor endpoint never sees it, and leaves the caller's query unchanged.</p>
/// <p>Mutation (Rule 19): drop the <code>Kill</code> of the parameter in
/// <method>OcuPilot.Port.ProcessPort.Invoke</method> -- the recorded names go red.</p>
Method TestThePortRemovesItsOwnParameterBeforeTheAdminPort()
{
    Set tFlag = $Parameter(..#PORT, "SENDERRORPARAM")
    Kill tQuery
    Set tQuery("id") = $Job
    Set tQuery(tFlag) = 1
    Set tSC = $ClassMethod(..#PROBEPORT, "Invoke", "Process", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a GET carrying the flag answers: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%Get("Pid"), 1: ""), $Job, "the process asked about")
    Do $$$AssertEquals($ClassMethod(..#PROBEPORT, "RecordedParams"), "id", "and the vendor endpoint was handed the id alone")
    Do $$$AssertEquals($Get(tQuery(tFlag)), 1, "while the caller's own query still carries the flag")
}

/// <p>AC2, AC3, AD-10: both tools reach the prohibited set's <code>process</code> arm by entity type,
/// through the shipped entry point that reads the target itself: the caller's own job is
/// <code>PROHIBITED.OCUPILOTPROCESS</code> and a process of a kind the allow-list does not admit is
/// <code>PROHIBITED.SYSTEMPROCESS</code>. The set is asked and answers; nothing is applied.</p>
/// <p>Mutation (Rule 19): remove either refusing arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Process</method> -- the matching legs go red.</p>
Method TestTheSetRefusesBothToolsForOurOwnJobAndASystemProcess()
{
    Set tSystemPid = ##class(OcuPilot.Test.ProcessControl).SystemPid()
    Do $$$AssertNotEquals(tSystemPid, "", "this instance runs a process of a kind the allow-list does not admit")
    For tClass = ..#TERMINATE, ..#WITHERROR {
        Set tTool = $Parameter(tClass, "TOOLNAME")
        Set tDiff = "[{""field"":""State"",""before"":""RUN"",""after"":""" _ $Parameter(tClass, "STATEAFTER") _ """}]"
        For tCase = $ListBuild($Job, "OCUPILOTPROCESS"), $ListBuild(tSystemPid, "SYSTEMPROCESS") {
            Set tPid = $List(tCase, 1)
            If tPid = "" Continue
            Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("process", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, tPid, .tRef)
            Do $$$AssertStatusOK(tSC, "the reference to pid " _ tPid _ " builds")
            If $$$ISERR(tSC) Continue
            Set tFresh = ##class(OcuPilot.Test.ProcessControl).FreshRead(tPid)
            Do $$$AssertTrue($IsObject(tFresh), "pid " _ tPid _ " reads fresh")
            If '$IsObject(tFresh) Continue
            Set tSC = $ClassMethod(..#SET, "Prohibits", tTool, tRef, tFresh.%ToJSON(), tDiff, .tProhibits, .tCode)
            Do $$$AssertStatusOK(tSC, "the set answers " _ tTool _ " for pid " _ tPid _ ": " _ $System.Status.GetErrorText(tSC))
            Do $$$AssertEquals(tProhibits, 1, tTool _ " of pid " _ tPid _ " is refused")
            Do $$$AssertEquals($Get(tCode), $Parameter(..#SET, $List(tCase, 2)), "as " _ $List(tCase, 2))
        }
    }
    Do $$$AssertEquals(..CanBeTerminated($Job), 0, "and asking terminated nothing: this job is still running")
}

/// <p>Mint one proposal of <var>pTool</var> for <var>pId</var> through <parameter>MINT</parameter>,
/// whose one replaced seam is the port.</p>
Method MintFor(pTool As %String, pId As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pTurnKey As %String = "") As %Status
{
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>Process <var>pPid</var>'s <code>CanBeTerminated</code> as <code>SYS.Process</code> holds it,
/// or <code>-1</code> when the instance carries no such process.</p>
ClassMethod CanBeTerminated(pPid As %String) As %Integer
{
    Set tCan = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProcess = ##class(SYS.Process).%OpenId(pPid)
        If $IsObject(tProcess) Set tCan = +tProcess.CanBeTerminated
        Set tProcess = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCan = -1
    }
    Quit tCan
}

}
