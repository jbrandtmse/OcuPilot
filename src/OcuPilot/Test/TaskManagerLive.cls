/// <p>Pins Story 16.11's Task Manager controls against the instance's own Task Manager (AD-6, AD-8,
/// AD-15, AD-51, AD-53, AD-58): suspend and resume through the screen route as the test account and
/// as a principal holding exactly the Task schedule's two pairs, with the banner and
/// <code>bannerRequires</code> the read answers, the wrong verb refused with its published sentence
/// and the vendor's audit rows; the agent's suspend confirmed, marked and read back as
/// <code>nothingSent</code>, and one whose state moved refused at Confirm; the start refused by name
/// for the exact-pairs principal; and a stop followed by the route's start, and another by the
/// agent's confirmed start, after each of which the Task Manager runs as <code>TASKMGR</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s test account, auditing on, a caller holding
/// <code>%All</code>, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>TASKVARIABLE</parameter> reading <code>1</code>: it creates and deletes a user and a
/// role, and suspends, resumes, stops and starts the Task Manager. Every test starts from and leaves
/// a Task Manager running as <code>TASKMGR</code> (<method>Restore</method>, in each teardown).</p>
Class OcuPilot.Test.TaskManagerLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's principal, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms its Task Manager control.</p>
Parameter TASKVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter SUSPEND = "OcuPilot.Screen.Tool.TaskManagerSuspend";

Parameter RESUME = "OcuPilot.Screen.Tool.TaskManagerResume";

Parameter START = "OcuPilot.Screen.Tool.TaskManagerStart";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The principal holding the install namespace's code read and exactly the Task schedule's two
/// pairs.</p>
Parameter EXACTUSER = "OcuPilotTaskMgrExact";

Parameter EXACTROLE = "OcuPilotTaskMgrExactRole";

/// <p>The pair the start declares beyond the screen's own.</p>
Parameter SECUREPAIR = "%Admin_Secure:USE";

/// <p>The process type <code>%SYS.ProcessQuery</code> gives the Task Manager.</p>
Parameter TASKMANAGERJOBTYPE = 36;

/// <p>The seconds a state change is waited for.</p>
Parameter WAITSECONDS = 30;

/// <p>The published sentences, as EXPERIENCE.md spells them.</p>
Parameter RUNNING = "The Task Manager is already running.";

Parameter SUSPENDED = "The Task Manager is already suspended.";

Parameter STOPPED = "The Task Manager is not running. Start it first.";

Parameter SUSPENDEDSTART = "The Task Manager is suspended. Resume it instead.";

Parameter SUSPENDEDBANNER = "taskManagerSuspendedBanner";

Parameter STOPPEDBANNER = "taskManagerStoppedBanner";

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskManagerLive creates a user and a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#TASKVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskManagerLive suspends, stops and starts this instance's Task Manager and runs on a throwaway container only. " _ ..#TASKVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotTM" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ..Restore()
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipal()
}

/// <p>Restore the Task Manager, then remove the principal and its role; a failing status when any
/// survives or the Task Manager is not running as <code>TASKMGR</code>.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ..Restore()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#EXACTUSER) Do ##class(Security.Users).Delete(..#EXACTUSER)
        If ##class(Security.Roles).Exists(..#EXACTROLE) Do ##class(Security.Roles).Delete(..#EXACTROLE)
        If ##class(Security.Users).Exists(..#EXACTUSER) || ##class(Security.Roles).Exists(..#EXACTROLE) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskManagerLive left its principal on the instance"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ..Restore()
}

/// <p>AC9: whatever the test did, the Task Manager is left running as <code>TASKMGR</code> with
/// <code>%All</code>, and the proposals it minted are removed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ..Restore()
    Do $$$AssertStatusOK(tSC, "the Task Manager is restored: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(..RunsAsTaskmgr(), 1, "running as TASKMGR with %All: " _ ..Process())
    Set tRemoveSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tRemoveSC, "the probe proposals and turns are removed")
    Quit tSC
}

/// <p>AC2, AC6, AD-53: the test account and then the exact-pairs principal each suspend the Task
/// Manager through the route, answered 200 with the update event for <code>task/instance/manager</code>
/// and a read-back of <code>nothingSent</code>; the principal's read then raises the suspended banner
/// over rows that still list, with nothing required for its resume; a second suspend is refused with
/// the published sentence; the resume answers 200 and the banner clears; a second resume is refused
/// with its sentence; another id is refused; and the vendor recorded each change as
/// <code>Modify Task Config.Suspend</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.TaskManagerSuspend.PrivilegePairs</method>
/// add <code>%Admin_Secure:USE</code> -- the exact-pairs principal's suspend is refused 403 and this
/// goes red.</p>
Method TestTheRouteSuspendsAndResumesForBothCallers()
{
    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    For tUser = "", ..#EXACTUSER {
        Set tWho = $Select(tUser = "": "the test account", 1: "the exact-pairs principal")
        Set tSC = ..Act("suspendmanager", "manager", tUser, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus, 200, tWho _ "'s suspend answers 200: " _ ..Shown(tBody))
        If $IsObject(tBody) && $IsObject(tBody.%Get("target")) {
            Do $$$AssertEquals(tBody.%Get("action") _ " " _ tBody.%Get("target").%ToJSON(), "updated {""type"":""task"",""scope"":""instance"",""id"":""manager""}", tWho _ ": publishing the update event for the Task Manager")
            Do $$$AssertEquals(..Verdict(tBody), "nothingSent", tWho _ ": read back as nothing sent (AD-58)")
        }
        Do $$$AssertEquals(..Status(), 2, tWho _ ": the Task Manager is suspended")
        Set tRead = ..Read(tUser)
        Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("banner") _ "|" _ tRead.%Get("bannerRequires"), 1: ""), ..#SUSPENDEDBANNER _ "|", tWho _ ": the read raises the suspended banner, its resume requiring nothing more (AC3)")
        Do $$$AssertTrue($IsObject(tRead) && (tRead.%Get("rows").%Size() > 0), tWho _ ": while the rows still list")
        Set tSC = ..Act("suspendmanager", "manager", tUser, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#SUSPENDED, tWho _ ": a second suspend is refused with the published sentence")
        Set tSC = ..Act("resumemanager", "MANAGER", tUser, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus, 200, tWho _ "'s resume answers 200, the id compared without regard to case: " _ ..Shown(tBody))
        Do $$$AssertEquals(..Status(), 1, tWho _ ": the Task Manager runs")
        Set tRead = ..Read(tUser)
        Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("banner") _ "|" _ tRead.%Get("bannerRequires"), 1: "-"), "|", tWho _ ": and the banner clears")
        Set tSC = ..Act("resumemanager", "manager", tUser, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#RUNNING, tWho _ ": a second resume is refused with its sentence")
    }
    Set tSC = ..Act("suspendmanager", "7", "", .tStatus, .tBody)
    Do $$$AssertTrue((tStatus = 400) && (..Code(tBody) = "TOOL.ARGUMENTS") && (..Problem(tBody) [ "'manager'"), "another id is refused: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Status(), 1, "and nothing is sent")
    Set tAccount = $ZConvert(##class(OcuPilot.Test.Http).GetTestUsername(), "U")
    Set tExact = $ZConvert(..#EXACTUSER, "U")
    Do $$$AssertEquals(..SuspendChanges(tSince, tAccount _ ":1," _ tAccount _ ":0," _ tExact _ ":1," _ tExact _ ":0"), tAccount _ ":1," _ tAccount _ ":0," _ tExact _ ":1," _ tExact _ ":0", "the vendor recorded each suspend and resume as Modify Task Config.Suspend, by its caller (AD-15)")
}

/// <p>AC6, AD-6, AD-15, AD-58: the agent's suspend mints one state row, <code>Running</code> to
/// <code>Suspended</code>, against <code>task/instance/manager</code> with its consequence; its
/// confirm suspends the Task Manager, is marked and reads back <code>nothingSent</code>; the resume
/// does the same the other way; and a suspend minted while running, after an out-of-band suspend, is
/// refused at Confirm because the fingerprint moved.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.TaskManagerSuspend.FINGERPRINTSUBJECT</parameter>
/// -- the registration guard refuses the tools and the mint legs go red.</p>
Method TestTheAgentsSuspendAndResumeAreConfirmed()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#SUSPEND, tTurn, "manager", .tProposal)
    Do $$$AssertStatusOK(tSC, "the suspend mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%ToJSON(), "{""type"":""task"",""scope"":""instance"",""id"":""manager""}", "against the Task Manager")
    Do $$$AssertEquals(..Rows(tProposal), "Status Running Suspended", "one row, Status Running to Suspended")
    Set tStoredSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("consequence")), "TASK.MANAGER.SUSPEND", "carrying the suspend's consequence")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm suspends it: " _ $Get(tCode))
    Do $$$AssertEquals(..Status(), 2, "and the Task Manager is suspended")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ " " _ tResult.%Get("action") _ " " _ ..Verdict(tResult), 1: ""), "1 updated nothingSent", "the write is marked, publishes an update and reads back nothing sent")

    Set tSC = ..Mint(..#RESUME, tTurn, "manager", .tResume)
    Do $$$AssertStatusOK(tSC, "the resume mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..Rows(tResume), "Status Suspended Running", "one row, Status Suspended to Running")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tResume.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm resumes it: " _ $Get(tCode))
    Do $$$AssertEquals(..Status(), 1, "and the Task Manager runs")

    Set tSC = ..Mint(..#SUSPEND, tTurn, "7", .tOther, .tHttp, .tFault)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ $Get(tHttp) _ " " _ ..Code($Get(tFault)), "0 400 TOOL.ARGUMENTS", "a suspend naming another id is refused at the mint")
    Do $$$AssertTrue(..Problem($Get(tFault)) [ "'manager'", "naming the literal id: " _ ..Problem($Get(tFault)))

    Set tSC = ..Mint(..#SUSPEND, tTurn, "manager", .tMoved)
    Do $$$AssertStatusOK(tSC, "a suspend mints while it runs")
    If $$$ISERR(tSC) Quit
    Do ##class(%SYS.Task).SuspendSet(1)
    Do $$$AssertEquals(..Status(), 2, "the Task Manager is suspended out of band")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tMoved.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a moved target")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC5, AD-8 as amended: while the Task Manager runs, the exact-pairs principal's start is refused
/// 403 naming <code>%Admin_Secure:USE</code> on the route, and by the gate the mint and the confirm
/// call, and nothing changes; the test account's start is refused with the published sentence.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Screen.Tool.TaskManagerStart.PrivilegePairs</method>
/// -- the principal's start reaches the state refusal instead and this goes red.</p>
Method TestTheStartIsRefusedWithoutTheSecurePair()
{
    Set tSC = ..Act("startmanager", "manager", ..#EXACTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE " _ ..#SECUREPAIR, "the principal's start is refused naming the pair")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(..#START, "TOOLNAME"), .tTool)
    Do $$$AssertStatusOK(tSC, "the start resolves")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("task", "instance", "manager", .tTargetRef)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tTargetRef, "", "", "{""Id"":""manager""}", ..#EXACTUSER, "", "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tRefused _ " " _ $Get(tGateHttp) _ " " _ $Get(tGateCode) _ " " _ $Select($IsObject($Get(tGateDetail)): tGateDetail.%Get("failedPair"), 1: ""), "1 1 403 AUTH.NOPRIVILEGE " _ ..#SECUREPAIR, "and so is it by the gate the mint and the confirm call")
    Do $$$AssertEquals(..Status(), 1, "nothing changed")
    Set tSC = ..Act("startmanager", "manager", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#RUNNING, "the test account's start of a running Task Manager is refused with the published sentence")
}

/// <p>AC3, AC5, AC9: once its process is terminated the Task Manager reads <code>Not running</code>,
/// the exact-pairs principal's read raises the stopped banner requiring
/// <code>%Admin_Secure:USE</code> while the test account's requires nothing, the principal's start
/// and resume are refused, and the test account's start through the route answers 200, records no
/// <code>Modify Task Config</code> row, and leaves the Task Manager running as <code>TASKMGR</code>
/// with <code>%All</code>. A suspended Task Manager's read requires nothing for the exact-pairs
/// principal's resume.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Read.BannerRequires</method> answer
/// <code>""</code> -- the stopped banner's requirement leg goes red.</p>
Method TestTheStoppedTaskManagerIsStartedAsTaskmgr()
{
    Set tSC = ..Stop()
    Do $$$AssertStatusOK(tSC, "the Task Manager's process is terminated: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..Status(), 0, "and it reads Not running")
    Set tRead = ..Read(..#EXACTUSER)
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("banner") _ "|" _ tRead.%Get("bannerRequires"), 1: ""), ..#STOPPEDBANNER _ "|" _ ..#SECUREPAIR, "the principal's read raises the stopped banner, its start requiring the pair")
    Set tRead = ..Read("")
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("banner") _ "|" _ tRead.%Get("bannerRequires"), 1: ""), ..#STOPPEDBANNER _ "|", "while the test account's requires nothing")
    Set tSC = ..Act("startmanager", "manager", ..#EXACTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE " _ ..#SECUREPAIR, "the principal's start is refused naming the pair")
    Set tSC = ..Act("resumemanager", "manager", ..#EXACTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#STOPPED, "and its resume with the published sentence")
    Set tSC = ..Act("suspendmanager", "manager", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#STOPPED, "the test account's suspend of a stopped Task Manager is refused with the published sentence")
    Do $$$AssertEquals(..Status(), 0, "the Task Manager is still not running")

    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Set tSC = ..Act("startmanager", "manager", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the test account's start answers 200: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Verdict(tBody), "nothingSent", "reading back nothing sent")
    Do $$$AssertEquals(..WaitFor(1), 1, "the Task Manager runs")
    Do $$$AssertEquals(..RunsAsTaskmgr(), 1, "as TASKMGR with %All: " _ ..Process())
    Hang 2
    Do $$$AssertEquals(..SuspendChanges(tSince), "", "and the start recorded no Modify Task Config row")

    Do ##class(%SYS.Task).SuspendSet(1)
    Set tRead = ..Read(..#EXACTUSER)
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("banner") _ "|" _ tRead.%Get("bannerRequires"), 1: ""), ..#SUSPENDEDBANNER _ "|", "a suspended Task Manager's read requires nothing for the principal's resume")
    Set tSC = ..Act("startmanager", "manager", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#SUSPENDEDSTART, "and the test account's start of a suspended one is refused with the sentence that says to resume it")
}

/// <p>AC5, AC6, AD-15, AD-58: with the Task Manager's process terminated, the agent's resume and
/// suspend are refused at the mint with the published sentence; its start mints one state row,
/// <code>Not running</code> to <code>Running</code>, against <code>task/instance/manager</code>, and
/// its confirm starts the Task Manager as <code>TASKMGR</code> with <code>%All</code>, is marked,
/// reads back <code>nothingSent</code> and records no <code>Modify Task Config</code> row; a second
/// start, minted while it runs, is refused.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Screen.Tool.TaskManagerStart.WRITETYPE</parameter>
/// <code>RESUME</code> -- the confirmed start leaves it not running and this goes red.</p>
Method TestTheAgentsStartOfAStoppedTaskManagerIsConfirmed()
{
    Set tSC = ..Stop()
    Do $$$AssertStatusOK(tSC, "the Task Manager's process is terminated: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    For tTool = ..#RESUME, ..#SUSPEND {
        Set tSC = ..Mint(tTool, tTurn, "manager", .tRefused, .tHttp, .tFault)
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ $Get(tHttp) _ " " _ ..Code($Get(tFault)) _ " " _ ..Problem($Get(tFault)), "0 400 TOOL.ARGUMENTS " _ ..#STOPPED, $Parameter(tTool, "TOOLNAME") _ " of a stopped Task Manager is refused at the mint with the published sentence")
    }
    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Set tSC = ..Mint(..#START, tTurn, "manager", .tProposal)
    Do $$$AssertStatusOK(tSC, "the start mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%ToJSON(), "{""type"":""task"",""scope"":""instance"",""id"":""manager""}", "against the Task Manager")
    Do $$$AssertEquals(..Rows(tProposal), "Status Not running Running", "one row, Status Not running to Running")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm starts it: " _ $Get(tCode))
    Do $$$AssertEquals(..WaitFor(1), 1, "the Task Manager runs")
    Do $$$AssertEquals(..RunsAsTaskmgr(), 1, "as TASKMGR with %All: " _ ..Process())
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ " " _ tResult.%Get("action") _ " " _ ..Verdict(tResult), 1: ""), "1 updated nothingSent", "the write is marked, publishes an update and reads back nothing sent")
    Hang 2
    Do $$$AssertEquals(..SuspendChanges(tSince), "", "and the start recorded no Modify Task Config row")
    Set tSC = ..Mint(..#START, tTurn, "manager", .tAgain, .tHttp, .tFault)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ $Get(tHttp) _ " " _ ..Problem($Get(tFault)), "0 400 " _ ..#RUNNING, "a second start, minted while it runs, is refused with the published sentence")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>Mint <var>pToolClass</var>'s proposal for id <var>pId</var> as the caller, in turn
/// <var>pTurn</var>, answering the mint's HTTP status and fault.</p>
Method Mint(pToolClass As %String, pTurn As %String, pId As %String, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tArgs = {}
    Do tArgs.%Set("Id", pId, "string")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#SCREEN, $Parameter(pToolClass, "TOOLNAME"), $Username, "", pTurn, tArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pId, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

/// <p>A proposal's rows as <code>field before after</code>, one row expected.</p>
ClassMethod Rows(pProposal As %DynamicObject) As %String
{
    Set tRows = pProposal.%Get("changed")
    If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit ..Shown(tRows)
    Quit tRows.%Get(0).field _ " " _ tRows.%Get(0).before _ " " _ tRows.%Get(0).after
}

/// <p>One action over the Task schedule's route as <var>pUser</var>, or as the test account when
/// <var>pUser</var> is empty, answering the HTTP status and the parsed envelope.</p>
Method Act(pAction As %String, pId As %String, pUser As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    Set tPassword = ..PreparedPassword
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.schedule/action", pUser, tPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>The Task schedule's read as <var>pUser</var>, or as the test account when it is empty, or
/// <code>""</code> when it did not answer 200.</p>
Method Read(pUser As %String) As %DynamicObject
{
    Set tPassword = ..PreparedPassword
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.schedule/read?maxRows=5", pUser, tPassword, .tStatus, .tRaw, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    Quit tRead
}

/// <p>The Task Manager's status as <code>%SYS.Task.TASKMGRStatus()</code> answers it: 1 running, 2
/// suspended, 0 not running.</p>
ClassMethod Status() As %Integer
{
    Quit +##class(%SYS.Task).TASKMGRStatus()
}

/// <p>Wait up to <parameter>WAITSECONDS</parameter> for <var>pStatus</var>, answering the last status
/// read.</p>
ClassMethod WaitFor(pStatus As %Integer) As %Integer
{
    Set tStatus = ..Status()
    For tI = 1:1:..#WAITSECONDS {
        If tStatus = pStatus Quit
        Hang 1
        Set tStatus = ..Status()
    }
    Quit tStatus
}

/// <p>The Task Manager's process as <code>user|roles</code>, or <code>""</code> for none.</p>
ClassMethod Process() As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT UserName, Roles FROM %SYS.ProcessQuery WHERE JobType = ?", ..#TASKMANAGERJOBTYPE)
        If tResult.%Next() Set tOut = tResult.%Get("UserName") _ "|" _ tResult.%Get("Roles")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tOut = ""
    }
    Quit tOut
}

/// <p>Whether the Task Manager's process runs as <code>TASKMGR</code> holding <code>%All</code>.</p>
ClassMethod RunsAsTaskmgr() As %Boolean
{
    Set tProcess = ..Process()
    Quit ($Piece(tProcess, "|", 1) = "TASKMGR") && ($ListFind($ListFromString($Piece(tProcess, "|", 2)), "%All") > 0)
}

/// <p>Stop the Task Manager by terminating its process from <code>%SYS</code>, never through
/// OcuPilot, and wait for it to read <code>Not running</code>.</p>
ClassMethod Stop() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPid = ""
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Pid FROM %SYS.ProcessQuery WHERE JobType = ?", ..#TASKMANAGERJOBTYPE)
        If tResult.%Next() Set tPid = tResult.%Get("Pid")
        If tPid = "" {
            Set tSC = $$$ERROR($$$GeneralError, "no Task Manager process was found")
        } ElseIf $SYSTEM.Process.Terminate(tPid) '= 1 {
            Set tSC = $$$ERROR($$$GeneralError, "the Task Manager's process " _ tPid _ " was not terminated")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    If ..WaitFor(0) '= 0 Quit $$$ERROR($$$GeneralError, "the Task Manager did not read Not running after its process was terminated")
    Quit $$$OK
}

/// <p>Leave the Task Manager running as <code>TASKMGR</code> (AC9): resume it when suspended, start
/// it from this <code>%All</code> process when it is not running -- after stopping one a caller
/// started as itself -- and wait for it to run. A failing status when it does not.</p>
ClassMethod Restore() As %Status
{
    Set tSC = $$$OK
    Try {
        If (..Status() '= 0) && ($Piece(..Process(), "|", 1) '= "TASKMGR") {
            Set tSC = ..Stop()
            If $$$ISERR(tSC) Quit
        }
        Set tStatus = ..Status()
        If tStatus = 2 Set tSC = ##class(%SYS.Task).SuspendSet(0)
        ; A stopped Task Manager keeps its suspend flag, and a start then comes up suspended
        ; (measured), so the flag is cleared first.
        If tStatus = 0 Set tSC = ##class(%SYS.Task).SuspendSet(0)
        If $$$ISERR(tSC) Quit
        If tStatus = 0 Set tSC = ##class(%SYS.Task).StartTASKMGR()
        If $$$ISERR(tSC) Quit
        If ..WaitFor(1) '= 1 {
            Set tSC = $$$ERROR($$$GeneralError, "the Task Manager did not read Running after it was restored")
            Quit
        }
        If $Piece(..Process(), "|", 1) '= "TASKMGR" Set tSC = $$$ERROR($$$GeneralError, "the Task Manager runs as " _ ..Process() _ ", not TASKMGR")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The vendor's <code>Modify Task Config.Suspend</code> rows since <var>pSince</var> (UTC), oldest
/// first, as <code>USER:new value</code> joined by commas, read on the audit master map with
/// <code>%NOINDEX</code> on the event predicates, since the <code>Event</code> indexes lag by up to
/// a minute (measured; the <class>OcuPilot.Test.DatabaseActions</class> precedent). Where
/// <var>pExpected</var> is given the rows are read again, up to <parameter>WAITSECONDS</parameter>,
/// until they read so.</p>
ClassMethod SuspendChanges(pSince As %String, pExpected As %String = "") As %String
{
    Set tOut = ..SuspendChangesOnce(pSince)
    If pExpected = "" Quit tOut
    For tI = 1:1:..#WAITSECONDS {
        If tOut = pExpected Quit
        Hang 1
        Set tOut = ..SuspendChangesOnce(pSince)
    }
    Quit tOut
}

/// <p>One read of <method>SuspendChanges</method>'s rows.</p>
ClassMethod SuspendChangesOnce(pSince As %String) As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Username, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%System' AND %NOINDEX EventType = '%System' AND %NOINDEX Event = 'ConfigurationChange' AND %NOINDEX Description = 'Modify Task Config.Suspend' ORDER BY UTCTimeStamp", pSince)
        While tResult.%Next() {
            Set tData = $Translate(tResult.%Get("EventData"), $Char(13, 10), "  ")
            Set tNew = $ZStrip($Piece($Piece(tData, "New value:", 2), " ", 1, 2), "<>W")
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $ZConvert(tResult.%Get("Username"), "U") _ ":" _ tNew
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = "error: " _ ex.DisplayString()
    }
    Quit tOut
}

/// <p>The read-back verdict an answer <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Verdict(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("readBack")) Quit ""
    Quit pBody.%Get("readBack").%Get("verdict")
}

/// <p>The code an envelope <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>The problem sentence an envelope <var>pBody</var>'s detail carries, or <code>""</code>.</p>
ClassMethod Problem(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("problem")
}

/// <p>The failed pair an envelope <var>pBody</var>'s detail names, or <code>""</code>.</p>
ClassMethod FailedPair(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("failedPair")
}

/// <p><var>pBody</var> as text for an assertion message.</p>
ClassMethod Shown(pBody) As %String
{
    Quit $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody))
}

/// <p>Create the throwaway role and the account that holds it, then read the grants back.</p>
Method EnsurePrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        If ##class(Security.Users).Exists(..#EXACTUSER) Do ##class(Security.Users).Delete(..#EXACTUSER)
        If ##class(Security.Roles).Exists(..#EXACTROLE) Do ##class(Security.Roles).Delete(..#EXACTROLE)
        Set tSC = ##class(Security.Roles).Create(..#EXACTROLE, "OcuPilot test: the Task schedule's pairs (throwaway)", tCode _ ",%Admin_Task:U,%DB_IRISSYS:R", "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#EXACTUSER, ..#EXACTROLE, ..PreparedPassword, "OcuPilot Task Manager test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.TaskManagerLive; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%Admin_Task", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%DB_IRISSYS", "READ") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#EXACTUSER, "%Admin_Operate", "USE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the exact-pairs principal's grants did not read back as the Task schedule's two pairs alone")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
