/// <p>Pins Story 7.5's run tool (AD-51, AD-53, AD-6, AD-27): its declarations, its state diff, a
/// mint and a confirm over a canned <code>INFO</code> answer, and the port's constant
/// <code>RUN</code> body.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%Admin_Task:USE</code> and <code>%DB_IRISSYS:READ</code>. It runs no task: the mint and the
/// confirm go through <class>OcuPilot.Test.ProposalFixture</class>'s port, and every call it makes
/// to the shipped port names a task id no task carries.</p>
Class OcuPilot.Test.TaskRun Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.TaskRun";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.TaskOnDemandList";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

/// <p>A task id no task carries, so a call that reaches the vendor runs nothing.</p>
Parameter ABSENTID = 999999999;

/// <p>An on-demand task at rest: the eight keys <code>RunInfo</code> writes.</p>
Parameter FRESHIDLE = "{""Type"":""User"",""Status"":""1"",""Error"":"""",""LastSchedule"":"""",""LastStarted"":"""",""LastFinished"":"""",""NextScheduled"":"""",""Suspended"":false}";

/// <p>The same task after somebody else requested a run.</p>
Parameter FRESHREQUESTED = "{""Type"":""User"",""Status"":""1"",""Error"":"""",""LastSchedule"":"""",""LastStarted"":"""",""LastFinished"":"""",""NextScheduled"":""2026-09-23 11:10:00"",""Suspended"":false}";

/// <p>The same task suspended.</p>
Parameter FRESHSUSPENDED = "{""Type"":""User"",""Status"":""1"",""Error"":"""",""LastSchedule"":"""",""LastStarted"":"""",""LastFinished"":"""",""NextScheduled"":"""",""Suspended"":true}";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $$$OK
}

/// <p>The tool reads <code>INFO</code>, writes <code>RUN</code> with no body of its own, covers
/// <code>NextScheduled</code> and <code>Suspended</code>, and carries the list's <code>run</code>
/// action; the list keys its rows by <code>Id</code> and declares that one row action; the
/// registry admits the tool.</p>
/// <p>Mutation (Rule 19): drop <code>Suspended</code> from
/// <parameter>OcuPilot.Screen.Tool.TaskRun.FINGERPRINTSUBJECT</parameter> -- the subject
/// assertion goes red, and the registration guard refuses the subject.</p>
Method TestTheToolIsAnActionWriteOverTheOnDemandList()
{
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", "tasks.ondemand.run", .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the run tool by name")
    Do $$$AssertTrue($IsObject(tTool), "and admits it")
    If $IsObject(tTool) {
        Do $$$AssertEquals(tTool.%Get("kind"), "write", "as a write tool")
        Do $$$AssertEquals(tTool.%Get("class"), ..#TOOL, "answered by its own class")
    }
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType"), "INFO", "its fresh read is INFO")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteType"), "RUN", "its write is the vendor's RUN")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "SendsBody"), 0, "and the tool sends no body")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Endpoint"), "Task.CRUD", "over the task endpoint")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "IdArgument"), "Id", "named by the list's own Id")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "IdParam"), "id", "and the vendor's own query parameter")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "FingerprintSubject")), "NextScheduled,Suspended", "its fingerprint covers the two fields the diff is about")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "PreconditionField"), "Suspended", "with Suspended as its precondition")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "StateField"), "NextScheduled", "and NextScheduled as its state row")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(..#TOOL), "", "which the registration guard holds adequate")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ScreenActionIds")), "run", "it carries the list's run action")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ChangeAction"), "updated", "and publishes an update")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Destructive"), 0, "a run is not destructive")

    Do $$$AssertEquals($ClassMethod(..#SCREEN, "IdKind"), "composite", "the list's id is composite")
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""composite"",""parts"":[""Id""]}", "over the one part Id")
    Do $$$AssertEquals(tDeclaration.rowActions.%ToJSON(), "[{""id"":""run"",""selfProtection"":""""}]", "it declares Run and no other row action")
    Do $$$AssertEquals(tDeclaration.entityLabelKey, "proposalEntityTask", "and names its entity's noun")
}

/// <p>AC4: <method>OcuPilot.Screen.Tool.TaskRun.StateDiff</method>'s three arms -- a task at rest
/// answers one <code>NextScheduled</code> row, a suspended task adds the resume, and a read with no
/// readable <code>Suspended</code> is a problem.</p>
/// <p>Mutation (Rule 19): drop the <code>Suspended</code> row from <code>StateDiff</code> -- the
/// suspended arm goes red.</p>
Method TestTheStateDiffAnswersItsThreeArms()
{
    Set tSC = $ClassMethod(..#TOOL, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHIDLE), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a task at rest answers")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""NextScheduled"",""before"":"""",""after"":""now""}]", "and one row: the next run becomes now")

    Set tSC = $ClassMethod(..#TOOL, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHREQUESTED), .tRows, .tProblem)
    Do $$$AssertEquals(tRows.%Get(0).%Get("before"), "2026-09-23 11:10:00", "the row's before is the value read")

    Set tSC = $ClassMethod(..#TOOL, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHSUSPENDED), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a suspended task answers")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""NextScheduled"",""before"":"""",""after"":""now""},{""field"":""Suspended"",""before"":""true"",""after"":""false""}]", "and a second row: the run resumes it")

    For tJson = "{""Type"":""User"",""NextScheduled"":""""}", "{""Suspended"":""maybe"",""NextScheduled"":""""}" {
        Set tSC = $ClassMethod(..#TOOL, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(tJson), .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, "an unreadable state answers: " _ tJson)
        Do $$$AssertTrue(tProblem [ "suspended", "as a problem naming the unread state: " _ tProblem)
        Do $$$AssertEquals(tRows.%Size(), 0, "and no row")
    }
}

/// <p>AC4: a mint over a canned <code>INFO</code> answer reads <code>INFO</code>, writes nothing
/// and carries the diff rows; an unreadable state mints nothing.</p>
Method TestTheMintCarriesTheRowsFromTheInfoRead()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "INFO", "the fresh read is INFO")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "41", "keyed by the vendor's id parameter")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the mint wrote nothing")
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""NextScheduled"",""before"":"""",""after"":""now""},{""field"":""Suspended"",""before"":""true"",""after"":""false""}]", "the card carries the run and the resume")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and nothing is sent unchanged")

    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Type"":""User"",""NextScheduled"":""""}")
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a read with no Suspended is refused")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertTrue($IsObject($Get(tFault)) && ($IsObject(tFault.%Get("detail")) && (tFault.%Get("detail").%Get("problem") [ "suspended")), "whose problem names the unread state")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), tBefore, "and nothing is proposed")
}

/// <p>AC4: a confirm after <code>NextScheduled</code> moved, and one after <code>Suspended</code>
/// moved, is refused <code>PROPOSAL.TARGETCHANGED</code> and nothing reaches the port.</p>
/// <p>Mutation (Rule 19): declare <parameter>OcuPilot.Screen.Tool.TaskRun.FINGERPRINTSUBJECT</parameter>
/// as <code>Suspended</code> alone -- the moved-next-run leg confirms and goes red.</p>
Method TestAConfirmAfterEitherFieldMovedIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    For tCase = $ListBuild(..#FRESHIDLE, ..#FRESHREQUESTED, "NextScheduled"), $ListBuild(..#FRESHIDLE, ..#FRESHSUSPENDED, "Suspended") {
        Do ##class(OcuPilot.Test.ProposalFixture).Arm($List(tCase, 1))
        Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault, tTurn)
        Do $$$AssertStatusOK(tSC, $List(tCase, 3) _ ": the proposal mints: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Continue
        Set tKey = tProposal.%Get("proposalId")
        Do ##class(OcuPilot.Test.ProposalFixture).Arm($List(tCase, 2))
        Set tWrites = ##class(OcuPilot.Test.ProposalFixture).WriteCount()
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 3) _ " moved: the confirm is refused")
        Do $$$AssertEquals(+$Get(tHttp), 409, $List(tCase, 3) _ " moved: at 409")
        Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), $List(tCase, 3) _ " moved: with the moved-target code")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), tWrites, $List(tCase, 3) _ " moved: and nothing reached the port")
    }
}

/// <p>AC2's kernel half: a confirmed run reaches the port as <code>RUN</code> with the id and
/// <b>no body</b> from the kernel, and the ledger row names no field -- the constant body is the
/// port's alone (AD-27, AD-51).</p>
Method TestTheConfirmedRunCarriesNoBodyFromTheKernel()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHIDLE)
    Set tSC = ..MintFor("41", .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "one write reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "RUN", "as the vendor's RUN")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "41", "carrying the id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), "", "and no body from the kernel")
    Set tMarked = ##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "auditMarked")
    Do $$$AssertTrue((tMarked '= "") && ($Length(tMarked, ",") = 1), "the confirm wrote exactly one write ledger row: '" _ tMarked _ "'")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "fields"), "", "so the ledger row names no field")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AD-27, AD-51: the port holds <code>Task.CRUD</code> <code>RUN</code>'s constant body, a fresh
/// object per call, and nothing for <code>RESUME</code>; a caller body for <code>RUN</code> is
/// refused before the vendor is reached, while an absent one reaches it carrying the constant.</p>
/// <p>Mutation (Rule 19): empty
/// <parameter>OcuPilot.Port.AdminPort.CONSTANTBODIES</parameter> -- the constant assertions go
/// red, and the bodyless call is refused 500 by the object-body guard instead of reaching the
/// vendor.</p>
Method TestThePortSendsRunsConstantBodyAndRefusesACallersBody()
{
    Set tBody = ##class(OcuPilot.Port.AdminPort).ConstantBody("Task.CRUD", "RUN")
    Do $$$AssertTrue($IsObject(tBody), "the port holds a body for Task.CRUD RUN")
    If $IsObject(tBody) {
        Do $$$AssertEquals(tBody.%ToJSON(), "{""RunNow"":true}", "which is the vendor's RunNow")
        Do tBody.%Set("RunNow", 0, "boolean")
        Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).ConstantBody("Task.CRUD", "RUN").%ToJSON(), "{""RunNow"":true}", "and each call answers a fresh copy")
    }
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).ConstantBody("Task.CRUD", "RESUME"), "", "and none for RESUME")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).ConstantBody("Process", "RUN"), "", "and none for another endpoint's type of the same name")

    Kill tQuery
    Set tQuery("id") = ..#ABSENTID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "RUN", .tQuery, {"RunNow": true}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a caller body for RUN is refused")
    Do $$$AssertEquals(+$Get(tHttp), 500, "as a port fault")
    Do $$$AssertTrue($IsObject($Get(tFault)), "the refusal carries a fault")
    If $IsObject($Get(tFault)) Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#INTERNAL, "with the internal code")

    Kill tQuery
    Set tQuery("id") = ..#ABSENTID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "RUN", .tQuery, "{""RunNow"":false}", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a caller body sent as JSON text is refused too")
    Do $$$AssertEquals(+$Get(tHttp), 500, "as the same port fault, not replaced by the constant")

    Kill tQuery
    Set tQuery("id") = ..#ABSENTID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "RUN", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a RUN for a task no task carries fails")
    Do $$$AssertEquals(+$Get(tHttp), 404, "at the vendor's own 404, past the port's body guard")
}

/// <p>Mint one <code>tasks.ondemand.run</code> proposal for <var>pId</var> through
/// <parameter>MINT</parameter>, whose one replaced seam is the port.</p>
Method MintFor(pId As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pTurnKey As %String = "") As %Status
{
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), pId, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pId, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

}
