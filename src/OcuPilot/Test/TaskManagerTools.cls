/// <p>Pins Story 16.11's three Task Manager tools and the Task schedule's declarations for them
/// (AD-3, AD-5, AD-8, AD-13, AD-22, AD-51): each registers as an action-style write over
/// <code>Task.Manager</code>, fingerprinted over <code>Status</code>, with no field list; each acts
/// from one state and refuses the other two with its published sentence; each refuses any id but the
/// literal <code>manager</code> on both callers' hooks; only the start adds
/// <code>%Admin_Secure:USE</code>; only the suspend carries a consequence; the three keys ship
/// enabled; and the banner's two cases name the resume and the start.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. Every state is a canned read;
/// nothing is sent to the Task Manager.</p>
Class OcuPilot.Test.TaskManagerTools Extends %UnitTest.TestCase
{

Parameter SUSPEND = "OcuPilot.Screen.Tool.TaskManagerSuspend";

Parameter RESUME = "OcuPilot.Screen.Tool.TaskManagerResume";

Parameter START = "OcuPilot.Screen.Tool.TaskManagerStart";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.TaskScheduleList";

/// <p>The four published refusals, as EXPERIENCE.md's Fixed strings spell them.</p>
Parameter RUNNING = "The Task Manager is already running.";

Parameter SUSPENDED = "The Task Manager is already suspended.";

Parameter SUSPENDEDSTART = "The Task Manager is suspended. Resume it instead.";

Parameter STOPPED = "The Task Manager is not running. Start it first.";

/// <p>AD-3, AD-51, AD-52, AC4: each tool is a registered, bodyless, non-destructive write through the
/// admin port, reading <code>Task.Manager</code>'s <code>GET</code> and writing its own type, with
/// <code>Status</code> as its precondition, subject and state row, which the registration guard
/// holds adequate. It admits no settable field and no field row, has no entry of its own in the
/// generated tool field lists, and the endpoint's derived list is empty; the port admits its pair as
/// a bodyless write. Its schema requires the id alone.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.TaskManagerSuspend.SENDSBODY</parameter>
/// to 1 -- the bodyless legs go red.</p>
Method TestEachToolIsAnActionWriteOverTheTaskManager()
{
    Set tToolFields = ..XDataJson("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Set tFieldLists = ..XDataJson("OcuPilot.Screen.Tool.FieldLists", "Lists")
    Do $$$AssertTrue($IsObject(tToolFields) && $IsObject(tFieldLists), "the generated field lists read")
    For tCase = $ListBuild("tasks.schedule.suspendmanager", ..#SUSPEND, "SUSPEND", "suspendmanager"), $ListBuild("tasks.schedule.resumemanager", ..#RESUME, "RESUME", "resumemanager"), $ListBuild("tasks.schedule.startmanager", ..#START, "RUN", "startmanager") {
        Set tName = $List(tCase, 1)
        Set tClass = $List(tCase, 2)
        Set tType = $List(tCase, 3)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)) && (tTool.class = tClass) && (tTool.kind = "write"), tName _ " is registered as a write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType"), "OcuPilot.Port.AdminPort Task.Manager GET " _ tType, tName _ ": reads Task.Manager's GET and writes " _ tType)
        Do $$$AssertEquals($ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "Destructive") _ " " _ $ClassMethod(tClass, "ChangeAction"), "0 0 updated", tName _ ": sends no body, is not destructive and publishes an update")
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), "Id id", tName _ ": its target is the Id argument, sent as id")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")) _ " " _ $ClassMethod(tClass, "PreconditionField") _ " " _ $ClassMethod(tClass, "StateField") _ " " _ $ListToString($ClassMethod(tClass, "ReadAnswers")), "Status Status Status Status", tName _ ": fingerprinted over the Status its precondition reads")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": which the registration guard holds adequate")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, tName _ ": admitting no settable field")
        Set tRowsSC = $ClassMethod(tClass, "FieldRows", .tRows)
        Do $$$AssertEquals($System.Status.IsOK(tRowsSC) _ " " _ +$Get(tRows), "1 0", tName _ ": its field list is empty by derivation")
        Do $$$AssertEquals($Select($IsObject(tToolFields): tToolFields.%GetTypeOf(tName), 1: "-"), "unassigned", tName _ ": no tool field list names it")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), $List(tCase, 4), tName _ ": carrying the screen's " _ $List(tCase, 4))
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "", tName _ ": declaring no classic page beyond the screen's own (AD-44)")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("Task.Manager", tType) && ##class(OcuPilot.Port.AdminPort).IsBodyless("Task.Manager", tType), tName _ ": the port admits Task.Manager/" _ tType _ " as a bodyless write")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Id""]", tName _ ": the schema requires the id alone")
        Do $$$AssertTrue(tSchema.%Get("properties").%Get("Id").%Get("description") [ "'manager'", tName _ ": describing the literal 'manager'")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {}, .tProblem)
        Do $$$AssertStatusNotOK(tSC, tName _ ": a call with no id is refused by the schema")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"Id": "manager", "Status": "Running"}, .tProblem)
        Do $$$AssertStatusNotOK(tSC, tName _ ": and so is a field on a bodyless write")
    }
    Set tList = $Select($IsObject(tFieldLists): tFieldLists.%Get("Task.Manager"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tList): tList.source _ " " _ tList.rows.%Size(), 1: ""), "none 0", "Task.Manager's derived list records no template and no row")
}

/// <p>AC6, AD-39, AD-51: every tool-and-state pair. Each tool answers one state row from the state it
/// acts from, and refuses each other state with its published sentence; a <code>Status</code> that is
/// absent, not a string, or none of the vendor's three words is refused with an unpublished problem.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.TaskManagerSuspend.StateDiff</method>
/// accept <code>Suspended</code> for the suspend -- the suspend's Suspended leg goes red.</p>
Method TestEachToolActsFromOneStateAndRefusesTheOthers()
{
    Set tMatrix = $ListBuild(
        $ListBuild(..#SUSPEND, "Running", "Status Running Suspended"),
        $ListBuild(..#SUSPEND, "Suspended", ..#SUSPENDED),
        $ListBuild(..#SUSPEND, "Not running", ..#STOPPED),
        $ListBuild(..#RESUME, "Running", ..#RUNNING),
        $ListBuild(..#RESUME, "Suspended", "Status Suspended Running"),
        $ListBuild(..#RESUME, "Not running", ..#STOPPED),
        $ListBuild(..#START, "Running", ..#RUNNING),
        $ListBuild(..#START, "Suspended", ..#SUSPENDEDSTART),
        $ListBuild(..#START, "Not running", "Status Not running Running"))
    For tI = 1:1:$ListLength(tMatrix) {
        Set tCase = $List(tMatrix, tI)
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "StateDiff", {"Status": ($List(tCase, 2))}, .tRows, .tProblem)
        Set tSeen = tProblem
        If tProblem = "" Set tSeen = $Select(tRows.%Size() = 1: tRows.%Get(0).field _ " " _ tRows.%Get(0).before _ " " _ tRows.%Get(0).after, 1: "rows " _ tRows.%ToJSON())
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tSeen, "1 " _ $List(tCase, 3), $Parameter(tClass, "TOOLNAME") _ " at " _ $List(tCase, 2))
    }
    For tClass = ..#SUSPEND, ..#RESUME, ..#START {
        For tFresh = {}, {"Status": 1}, {"Status": null}, {"Status": "Paused"}, "" {
            Set tSC = $ClassMethod(tClass, "StateDiff", tFresh, .tRows, .tProblem)
            Set tShown = $Select($IsObject(tFresh): tFresh.%ToJSON(), 1: "no read")
            Do $$$AssertTrue($$$ISOK(tSC) && (tProblem '= "") && (tRows.%Size() = 0), $Parameter(tClass, "TOOLNAME") _ " refuses " _ tShown)
            Do $$$AssertEquals($ListFind($ListBuild(..#RUNNING, ..#SUSPENDED, ..#SUSPENDEDSTART, ..#STOPPED), tProblem), 0, "with an unpublished problem: " _ tProblem)
        }
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.TaskManagerSuspend).#RUNNINGREASON _ "|" _ ##class(OcuPilot.Screen.Tool.TaskManagerSuspend).#SUSPENDEDREASON _ "|" _ ##class(OcuPilot.Screen.Tool.TaskManagerSuspend).#SUSPENDEDSTARTREASON _ "|" _ ##class(OcuPilot.Screen.Tool.TaskManagerSuspend).#STOPPEDREASON, ..#RUNNING _ "|" _ ..#SUSPENDED _ "|" _ ..#SUSPENDEDSTART _ "|" _ ..#STOPPED, "the four reasons are the published sentences")
}

/// <p>AD-13, AD-55, AD-56 (ii): the agent's mint (<method>ArgumentProblem</method>) and the screen's
/// route (<method>ScreenActionDelta</method>) each refuse any id but <code>manager</code>, compared
/// without regard to case, and the route's arguments stay empty.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.TaskManagerSuspend.IdProblem</method>
/// answer <code>""</code> -- every refusal leg goes red.</p>
Method TestEachToolRefusesAnyIdButTheManager()
{
    For tClass = ..#SUSPEND, ..#RESUME, ..#START {
        Set tName = $Parameter(tClass, "TOOLNAME")
        For tId = "manager", "Manager", "MANAGER" {
            Set tSC = $ClassMethod(tClass, "ArgumentProblem", tId, {"Id": (tId)}, .tProblem)
            Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tProblem, "1 ", tName _ ": the mint admits '" _ tId _ "'")
            Set tSC = $ClassMethod(tClass, "ScreenActionDelta", $ListGet($ClassMethod(tClass, "ScreenActionIds"), 1), {"Id": (tId)}, {"Status": "Running"}, .tArgs, .tProblem)
            Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tProblem _ " " _ $Select($IsObject($Get(tArgs)): tArgs.%ToJSON(), 1: ""), "1  {}", tName _ ": the route admits '" _ tId _ "', sending no argument")
        }
        For tId = "7", "", "managers", "import" {
            Set tSC = $ClassMethod(tClass, "ArgumentProblem", tId, {"Id": (tId)}, .tProblem)
            Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "'manager'"), tName _ ": the mint refuses '" _ tId _ "': " _ tProblem)
            Set tSC = $ClassMethod(tClass, "ScreenActionDelta", $ListGet($ClassMethod(tClass, "ScreenActionIds"), 1), {"Id": (tId)}, {"Status": "Running"}, .tArgs, .tProblem)
            Do $$$AssertTrue($$$ISOK(tSC) && (tProblem [ "'manager'"), tName _ ": the route refuses '" _ tId _ "': " _ tProblem)
        }
    }
}

/// <p>AD-8 as amended: the suspend and the resume require exactly the screen's pairs, and the start
/// adds <code>%Admin_Secure:USE</code> once, last. AD-15: only the suspend's proposal carries a
/// consequence.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Screen.Tool.TaskManagerStart.PrivilegePairs</method>
/// -- the start's pair leg goes red.</p>
Method TestOnlyTheStartAddsThePairAndOnlyTheSuspendWarns()
{
    Set tScreen = ..Pairs(##class(OcuPilot.Screen.Gate).RequiredPairs(..#SCREEN, .tResolved))
    Do $$$AssertEquals(tScreen, "%Admin_Task:USE,%DB_IRISSYS:READ", "the screen's own pairs")
    Do $$$AssertEquals(..Pairs($ClassMethod(..#SUSPEND, "PrivilegePairs", "", .tResolved)), tScreen, "the suspend requires exactly them")
    Do $$$AssertEquals(..Pairs($ClassMethod(..#RESUME, "PrivilegePairs", "", .tResolved)), tScreen, "and so does the resume")
    Do $$$AssertEquals(..Pairs($ClassMethod(..#START, "PrivilegePairs", "", .tResolved)), tScreen _ ",%Admin_Secure:USE", "the start adds %Admin_Secure:USE")
    Do $$$AssertEquals($ClassMethod(..#SUSPEND, "Consequence", {"Status": "Running"}, 0, ""), "TASK.MANAGER.SUSPEND", "the suspend carries its consequence")
    Do $$$AssertEquals($ClassMethod(..#RESUME, "Consequence", {"Status": "Suspended"}, 0, "") _ "|" _ $ClassMethod(..#START, "Consequence", {"Status": "Not running"}, 0, ""), "|", "the resume and the start carry none")
}

/// <p>AD-22: each tool's key is in the baseline, enabled.</p>
Method TestTheThreeKeysShipEnabled()
{
    For tKey = "tasks.schedule.suspendmanager", "tasks.schedule.resumemanager", "tasks.schedule.startmanager" {
        Set tSeed = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        Do $$$AssertEquals(tListed _ " " _ tSeed, "1 1", tKey _ " is listed, enabled")
    }
}

/// <p>AD-5 as amended: the Task schedule declares the three actions as row actions, and its banner's
/// suspended case offers the resume while its stopped case offers the start, which the registry
/// admits. The screen keeps a fourth prompt in the Scheduling group.</p>
/// <p>Mutation (Rule 19): drop the <code>action</code> from the stopped case -- the banner leg goes
/// red.</p>
Method TestTheBannerOffersTheResumeAndTheStart()
{
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Set tIds = ""
    Set tIterator = tDeclaration.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tIds = tIds _ $ListBuild(tAction.id)
    }
    For tId = "suspendmanager", "resumemanager", "startmanager" {
        Do $$$AssertTrue($ListFind(tIds, tId) > 0, tId _ " is one of the screen's row actions")
    }
    Set tCases = ""
    Set tIterator = tDeclaration.banner.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tCases = tCases _ $Select(tCases = "": "", 1: ",") _ tCase.equals _ "=" _ tCase.%Get("action")
    }
    Do $$$AssertEquals(tCases, "Suspended=resumemanager,Not running=startmanager", "the suspended case offers the resume and the stopped case the start")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), "", "which the registry admits")
    Set tLast = tDeclaration.suggestedPrompts.%Get(tDeclaration.suggestedPrompts.%Size() - 1)
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size() _ " " _ tLast.groupKey _ " " _ tLast.textKey, "4 taskPromptGroupSchedule taskScheduleListPrompt4", "and a fourth prompt in the Scheduling group")
}

/// <p><var>pPairs</var> as comma-separated <code>resource:permission</code>.</p>
ClassMethod Pairs(pPairs As %List) As %String
{
    Set tOut = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List($List(pPairs, tI), 1) _ ":" _ $List($List(pPairs, tI), 2)
    }
    Quit tOut
}

/// <p>XData block <var>pBlock</var> of <var>pClass</var> as JSON, or <code>""</code>.</p>
ClassMethod XDataJson(pClass As %String, pBlock As %String) As %DynamicAbstractObject
{
    Set tJson = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClass, pBlock, , .tSC)
        If '$IsObject(tXData) Quit
        Do tXData.Data.Rewind()
        Set tJson = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    } Catch {
        Set tJson = ""
    }
    Quit tJson
}

}
