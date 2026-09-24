/// <p>Pins the New Task wizard's gate over the wire with real principals (AD-8, AD-29): a caller
/// lacking one of <class>OcuPilot.Screen.Descriptor.TaskForm</class>'s two declared pairs is refused
/// 403 on every <code>/tasks</code> route, naming the pair, and nothing is created; the
/// least-privileged principal the form declares creates a task; and running a task as another
/// account without <code>%Admin_Secure:USE</code> is refused on <code>RunAsUser</code> before any write,
/// which the instance itself also enforces (AC6). Edit task's two routes (Story 9.8) refuse the same
/// callers, and the least-privileged principal edits a task that runs as another account while it
/// leaves the account alone and is refused on <code>RunAsUser</code> when it moves it, on both
/// callers (AC5), and is refused editing a task whose type declares a privilege it does not hold.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>TASKVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes three users, three roles and probe tasks
/// (<class>OcuPilot.Test.TaskProbe</class>, <class>OcuPilot.Test.TaskEditProbe</class>). <method>OnBeforeAllTests</method> refuses anywhere
/// either does not; every probe is removed by exact name.</p>
Class OcuPilot.Test.TaskWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms its probe tasks.</p>
Parameter TASKVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

/// <p>The principal holding the code read, <code>%DB_IRISSYS:R</code> and
/// <code>%Admin_Operate:U</code>, and not <code>%Admin_Task</code>.</p>
Parameter NOTASKUSER = "OcuPilotWireTaskNoTask";

Parameter NOTASKROLE = "OcuPilotWireTaskNoTaskRole";

/// <p>The principal holding the code read and <code>%Admin_Task:U</code>, and not
/// <code>%DB_IRISSYS</code>.</p>
Parameter NOSYSREADUSER = "OcuPilotWireTaskNoSysRead";

Parameter NOSYSREADROLE = "OcuPilotWireTaskNoSysReadRole";

/// <p>The least-privileged principal the form declares: the code read, <code>%Admin_Task:U</code>
/// and <code>%DB_IRISSYS:R</code>, and not <code>%Admin_Secure</code>.</p>
Parameter LEASTUSER = "OcuPilotWireTaskLeast";

Parameter LEASTROLE = "OcuPilotWireTaskLeastRole";

/// <p>The throwaway principals' password, generated for the run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskWire creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#TASKVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskWire creates and deletes tasks in this instance's Task Manager and runs on a throwaway container only. " _ ..#TASKVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotTask" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.TaskProbe).RemoveAll()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.TaskEditProbe).RemoveAll()
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe tasks, the principals and their roles; a failing status when any
/// survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ##class(OcuPilot.Test.TaskProbe).RemoveAll()
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.TaskEditProbe).RemoveAll())
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#NOTASKUSER, ..#NOSYSREADUSER, ..#LEASTUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskWire left the user " _ tUser))
        }
        For tRole = ..#NOTASKROLE, ..#NOSYSREADROLE, ..#LEASTROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskWire left the role " _ tRole))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>AD-8 with real principals: each caller lacking one declared pair is refused 403
/// <code>AUTH.NOPRIVILEGE</code> on the form read, the check and the create, naming that pair,
/// before anything is read or written; nothing is created.</p>
/// <p>Mutation (Rule 19): delete the <code>Gate</code> call from
/// <method>OcuPilot.Area.Task.TaskRules.HandleCheck</method> -> the check passes the gate and this goes
/// red.</p>
Method TestACallerLackingAPairIsRefusedOnEveryRoute()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tCreate = ##class(OcuPilot.Test.TaskSave).Weekly("OcuP97Wire").%ToJSON()
    Set tRoutes = $ListBuild($ListBuild("GET", "/tasks/form", ""), $ListBuild("POST", "/tasks/check", tCreate), $ListBuild("POST", "/tasks", tCreate))
    For tCaller = $ListBuild(..#NOTASKUSER, "%Admin_Task:USE"), $ListBuild(..#NOSYSREADUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCaller, 1)
        For tI = 1:1:$ListLength(tRoutes) {
            Set tMethod = $List($List(tRoutes, tI), 1)
            Set tPath = tBase _ $List($List(tRoutes, tI), 2)
            Set tBody = $List($List(tRoutes, tI), 3)
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, tUser, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, tBody, $Select(tBody = "": "", 1: "application/json"))
            Set tLabel = tUser _ " " _ tMethod _ " " _ tPath
            Do $$$AssertEquals(tStatus, 403, tLabel _ ": is refused")
            Set tRefusal = ""
            Try { Set tRefusal = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
            Set tSeen = $Select($IsObject(tRefusal): tRefusal.%Get("code") _ " " _ $Select($IsObject(tRefusal.%Get("detail")): tRefusal.%Get("detail").%Get("failedPair"), 1: ""), 1: "")
            Do $$$AssertEquals(tSeen, "AUTH.NOPRIVILEGE " _ $List(tCaller, 2), tLabel _ ": naming " _ $List(tCaller, 2) _ ", read " _ tSeen)
        }
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97Wire"), "", "and nothing was created")
}

/// <p>AD-29 and AC6: the least-privileged principal creates a task over the wire, running as
/// itself; asking to run as another account is refused 422 <code>TASK.RUNASUSER.SECURE</code> with
/// nothing sent; and the instance's own endpoint, asked directly by the same principal, refuses the
/// same task too -- the enforcement is the instance's as well as OcuPilot's.</p>
/// <p>Mutation (Rule 19): drop the <code>%Admin_Secure</code> check from
/// <method>OcuPilot.Area.Task.TaskRules.RunAsViolations</method> -- the vendor then refuses on the
/// field with its own code, and the <code>SECURE</code> leg goes red.</p>
Method TestTheLeastPrivilegedPrincipalCreatesAndCannotRunAsAnother()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/tasks/form", ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders)
    Set tForm = ""
    Try { Set tForm = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
    Do $$$AssertEquals(tStatus, 200, "the least-privileged principal reads the form: " _ $Extract($Get(tAnswer), 1, 200))
    Do $$$AssertTrue($IsObject(tForm) && (tForm.%Get("types").%Size() > 0) && (tForm.%Get("runAfter").%Size() > 0), "with its types and the tasks to run after")
    Set tBody = ##class(OcuPilot.Test.TaskSave).Weekly("OcuP97Least")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/tasks", ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the least-privileged principal creates a task: " _ $Extract($Get(tAnswer), 1, 300))
    Set tId = ##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97Least")
    Set tStored = ##class(OcuPilot.Test.TaskProbe).Stored(tId)
    Do $$$AssertTrue($IsObject(tStored), "the created task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("RunAsUser"), ..#LEASTUSER, "running as itself")
    Do ##class(OcuPilot.Test.TaskProbe).Remove(tId)

    Set tOther = ##class(OcuPilot.Test.TaskSave).Weekly("OcuP97RunAsOther")
    Do tOther.%Set("RunAsUser", "_SYSTEM", "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/tasks", ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, tOther.%ToJSON(), "application/json")
    Set tPair = ""
    Try {
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tAnswer)
        Set tPair = ##class(OcuPilot.Test.TaskSave).FirstPair(tRefusal)
    } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tPair, "422 RunAsUser:TASK.RUNASUSER.SECURE", "running as another account is refused on the field")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97RunAsOther"), "", "and nothing was created")

    ; The instance's own enforcement: the vendor endpoint, asked directly by the same principal.
    Set tSC = ##class(OcuPilot.Area.Task.TaskRules).Compose(tOther, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do ##class(OcuPilot.Screen.Tool.TaskCreate).DerivedFields(tPayload)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/admin/v2/task", ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, tPayload.%ToJSON(), "application/json")
    Do $$$AssertTrue((tStatus >= 400), "the instance refuses it too (HTTP " _ tStatus _ ")")
    Do $$$AssertTrue($Get(tAnswer) [ "7405", "with its own code 7405: " _ $Extract($Get(tAnswer), 1, 200))
    Set tLeaked = ##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97RunAsOther")
    Do $$$AssertEquals(tLeaked, "", "and saves nothing")
    Do ##class(OcuPilot.Test.TaskProbe).Remove(tLeaked)
}

/// <p>AC6's agent half: the least-privileged principal's own mint of
/// <code>tasks.schedule.create</code> running as another account is refused on
/// <code>RunAsUser</code> with <code>TASK.RUNASUSER.SECURE</code>, in a process logged in as that
/// principal (<method>MintAs</method>), and no proposal's task is created.</p>
Method TestTheAgentsMintRefusesTheLeastPrincipalRunningAsAnother()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#LEASTUSER, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a turn is seeded for the principal")
    If $$$ISERR(tSC) Quit
    Set tArgs = {"Name": "OcuP97AgentOther", "TaskClass": "%SYS.Task.PurgeTaskHistory", "NameSpace": "%SYS", "TimePeriod": "On Demand", "RunAsUser": "_SYSTEM"}
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.TaskWire).MintAs($Job, ..#LEASTUSER, tTurnKey, tArgs.%ToJSON())::10
        If '$Test {
            Do tOut.%Set("error", "the principal's process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the principal's process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertEquals(tOut.%Get("error"), "", "the principal's mint ran")
    Do $$$AssertEquals(tOut.%Get("username"), ..#LEASTUSER, "as the principal")
    Do $$$AssertEquals(tOut.%Get("http"), 400, "the mint is refused")
    Do $$$AssertTrue(tOut.%Get("problem") [ ("'RunAsUser': " _ ##class(OcuPilot.Api.Error).#REASONTASKRUNASUSERSECURE), "on RunAsUser, needing %Admin_Secure: " _ tOut.%Get("problem"))
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97AgentOther"), "", "and nothing was created")
}

/// <p>Story 9.8, AD-8: each caller lacking one declared pair is refused 403
/// <code>AUTH.NOPRIVILEGE</code> on Edit task's form read and Save, naming that pair, and the task is
/// unchanged.</p>
/// <p>Mutation (Rule 19): delete the <code>Gate</code> call from
/// <method>OcuPilot.Area.Task.TaskSave.HandleUpdate</method> -- the Save is refused by the instance
/// instead, naming no pair, and this goes red.</p>
Method TestTheEditRoutesRefuseACallerLackingAPair()
{
    Set tSC = ##class(OcuPilot.Test.TaskEditProbe).Create(##class(OcuPilot.Test.TaskEditProbe).Ac7("OcuP98Wire"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tRoutes = $ListBuild($ListBuild("GET", "/tasks/form?id=" _ tId, ""), $ListBuild("PUT", "/tasks/" _ tId, "{""Description"":""refused""}"))
    For tCaller = $ListBuild(..#NOTASKUSER, "%Admin_Task:USE"), $ListBuild(..#NOSYSREADUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCaller, 1)
        For tI = 1:1:$ListLength(tRoutes) {
            Set tMethod = $List($List(tRoutes, tI), 1)
            Set tPath = tBase _ $List($List(tRoutes, tI), 2)
            Set tBody = $List($List(tRoutes, tI), 3)
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, tUser, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, tBody, $Select(tBody = "": "", 1: "application/json"))
            Set tRefusal = ""
            Try { Set tRefusal = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
            Set tSeen = $Select($IsObject(tRefusal): tRefusal.%Get("code") _ " " _ $Select($IsObject(tRefusal.%Get("detail")): tRefusal.%Get("detail").%Get("failedPair"), 1: ""), 1: "")
            Do $$$AssertEquals(tStatus _ " " _ tSeen, "403 AUTH.NOPRIVILEGE " _ $List(tCaller, 2), tUser _ " " _ tMethod _ " " _ tPath _ ": is refused naming the pair")
        }
    }
    Set tStored = ##class(OcuPilot.Test.TaskEditProbe).Stored(tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Description"), "OcuPilot edit probe", "and the task is unchanged")
    Do ##class(OcuPilot.Test.TaskEditProbe).Remove(tId)
}

/// <p>AC5 with a real principal lacking <code>%Admin_Secure:USE</code>: it edits the Description of a
/// task that runs as <code>_SYSTEM</code> over the wire, and its agent proposal of the same edit is not
/// destructive; moving a task it runs as itself to <code>_SYSTEM</code> is refused on
/// <code>RunAsUser</code> with <code>TASK.RUNASUSER.SECURE</code> by the Save and by the agent's mint,
/// and nothing is sent.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Task.TaskRules.ValidateUpdate</method> judge every
/// rule whatever changed -- the Description edit is refused on RunAsUser and this goes red.</p>
Method TestTheLeastPrincipalEditsButCannotMoveRunAs()
{
    Set tArgs = ##class(OcuPilot.Test.TaskEditProbe).Ac7("OcuP98AsSystem")
    Do tArgs.%Set("RunAsUser", "_SYSTEM", "string")
    Set tSC = ##class(OcuPilot.Test.TaskEditProbe).Create(tArgs, .tSystemId)
    Do $$$AssertStatusOK(tSC, "a probe task running as _SYSTEM is created")
    If $$$ISERR(tSC) Quit
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ "/tasks/" _ tSystemId, ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, "{""Description"":""least edit""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the least-privileged principal edits it: " _ $Extract($Get(tAnswer), 1, 300))
    Set tStored = ##class(OcuPilot.Test.TaskEditProbe).Stored(tSystemId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Description") _ " " _ tStored.%Get("RunAsUser"), "least edit _SYSTEM", "and the task still runs as _SYSTEM")
    Set tOut = ..AgentMint({"Id": (tSystemId), "Description": "least agent edit"})
    Do $$$AssertEquals(tOut.%Get("error") _ tOut.%Get("username") _ " " _ tOut.%Get("http") _ " " _ tOut.%Get("destructive"), ..#LEASTUSER _ " 200 0", "its agent's proposal of the edit is minted, and not destructive: " _ tOut.%Get("problem"))

    Set tBody = ##class(OcuPilot.Test.TaskEditProbe).Ac7("OcuP98AsLeast")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/tasks", ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the principal creates a task running as itself: " _ $Extract($Get(tAnswer), 1, 300))
    Set tOwnId = ##class(OcuPilot.Test.TaskEditProbe).IdOf("OcuP98AsLeast")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ "/tasks/" _ tOwnId, ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, "{""RunAsUser"":""_SYSTEM""}", "application/json")
    Set tPair = ""
    Try { Set tPair = ##class(OcuPilot.Test.TaskSave).FirstPair(##class(%DynamicObject).%FromJSON(tAnswer)) } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tPair, "422 RunAsUser:TASK.RUNASUSER.SECURE", "moving it to _SYSTEM is refused on the field")
    Set tStored = ##class(OcuPilot.Test.TaskEditProbe).Stored(tOwnId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("RunAsUser"), ..#LEASTUSER, "and nothing is sent")
    Set tOut = ..AgentMint({"Id": (tOwnId), "RunAsUser": "_SYSTEM"})
    Do $$$AssertEquals(tOut.%Get("http"), 400, "the agent's mint is refused too")
    Do $$$AssertTrue(tOut.%Get("problem") [ ("'RunAsUser': " _ ##class(OcuPilot.Api.Error).#REASONTASKRUNASUSERSECURE), "on RunAsUser: " _ tOut.%Get("problem"))
    Do ##class(OcuPilot.Test.TaskEditProbe).Remove(tSystemId)
    Do ##class(OcuPilot.Test.TaskEditProbe).Remove(tOwnId)
}

/// <p>A task type's declared privilege holds on an edit as on a create: the least-privileged
/// principal, who does not hold <code>%Ens_PurgeSchedule:USE</code>, is refused
/// <code>TASK.TASKCLASS.PERMISSION</code> on <code>TaskClass</code> when it edits an
/// <code>Ens.Util.Tasks.Purge</code> task, by the Save and by the agent's mint, and nothing is
/// sent.</p>
/// <p>Mutation (Rule 19): delete the <code>Permitted</code> line of
/// <method>OcuPilot.Area.Task.TaskRules.ValidateUpdate</method> -- the Save answers 200 and this goes
/// red.</p>
Method TestTheLeastPrincipalCannotEditATypeItsPrivilegeGuards()
{
    Set tArgs = ##class(OcuPilot.Test.TaskEditProbe).Ac7("OcuP98EnsPurge")
    Do tArgs.%Set("TaskClass", "Ens.Util.Tasks.Purge", "string")
    Do tArgs.%Set("NameSpace", "HSCUSTOM", "string")
    Do tArgs.%Set("Settings", {"TypesToPurge": "events"})
    Set tSC = ##class(OcuPilot.Test.TaskEditProbe).Create(tArgs, .tId)
    Do $$$AssertStatusOK(tSC, "a probe purge task is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/tasks/" _ tId, ..#LEASTUSER, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, "{""Description"":""least edit""}", "application/json")
    Set tPair = ""
    Try { Set tPair = ##class(OcuPilot.Test.TaskSave).FirstPair(##class(%DynamicObject).%FromJSON(tAnswer)) } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tPair, "422 TaskClass:TASK.TASKCLASS.PERMISSION", "the Save is refused on the type: " _ $Extract($Get(tAnswer), 1, 300))
    Set tStored = ##class(OcuPilot.Test.TaskEditProbe).Stored(tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Description"), "OcuPilot edit probe", "and nothing is sent")
    Set tOut = ..AgentMint({"Id": (tId), "Description": "least agent edit"})
    Do $$$AssertEquals(tOut.%Get("http"), 400, "the agent's mint is refused too")
    Do $$$AssertTrue(tOut.%Get("problem") [ ("'TaskClass': " _ ##class(OcuPilot.Api.Error).#REASONTASKTASKCLASSPERMISSION), "on TaskClass: " _ tOut.%Get("problem"))
    Do ##class(OcuPilot.Test.TaskEditProbe).Remove(tId)
}

/// <p>The least-privileged principal's own mint of the edit <var>pArgs</var>, in a process logged in
/// as it (<method>MintAs</method>), as <code>{username, http, problem, destructive}</code> or
/// <code>{error}</code>.</p>
Method AgentMint(pArgs As %DynamicObject) As %DynamicObject
{
    Set tOut = {}
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#LEASTUSER, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit {"error": "no turn was seeded"}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.TaskWire).MintAs($Job, ..#LEASTUSER, tTurnKey, pArgs.%ToJSON(), "OcuPilot.Screen.Tool.TaskUpdate")::10
        If '$Test {
            Do tOut.%Set("error", "the principal's process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the principal's process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit tOut
}

/// <p>Log in as <var>pUser</var>, mint <var>pTool</var>'s proposal of <var>pArgs</var> (JSON) under
/// turn <var>pTurnKey</var>, and signal <code>{username, http, problem, destructive}</code>, or
/// <code>{error}</code>, to process <var>pParent</var>.</p>
ClassMethod MintAs(pParent As %Integer, pUser As %String, pTurnKey As %String, pArgs As %String, pTool As %String = "OcuPilot.Screen.Tool.TaskCreate")
{
    Set tOut = {}
    Try {
        If '$SYSTEM.Security.Login(pUser) {
            Do tOut.%Set("error", "the login as " _ pUser _ " failed")
            Quit
        }
        Do tOut.%Set("username", $Username, "string")
        Set tArgs = ##class(%DynamicObject).%FromJSON(pArgs)
        Set tTool = pTool
        Set tSC = ##class(OcuPilot.Test.ProposalMint).Mint("OcuPilot.Screen.Descriptor.TaskScheduleList", $Parameter(tTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), "" _ tArgs.%Get($ClassMethod(tTool, "IdArgument")), $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
        Do tOut.%Set("http", +$Get(tHttp), "number")
        If $IsObject($Get(tProposal)) {
            Set tStoredSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
            Do tOut.%Set("destructive", +$Get(tValues("destructive")), "number")
        }
        Set tProblem = ""
        If $IsObject($Get(tFault)) Set tProblem = $Select(tFault.%GetTypeOf("detail") = "object": tFault.%Get("detail").%Get("problem"), 1: tFault.%Get("reason"))
        Do tOut.%Set("problem", tProblem, "string")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Create the three throwaway roles and the accounts that hold them, then read the grants
/// back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCodeRead = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set tCases = $ListBuild($ListBuild(..#NOTASKROLE, ..#NOTASKUSER, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Operate:U"))
        Set tCases = tCases _ $ListBuild($ListBuild(..#NOSYSREADROLE, ..#NOSYSREADUSER, tCodeRead _ ",%Admin_Task:U"))
        Set tCases = tCases _ $ListBuild($ListBuild(..#LEASTROLE, ..#LEASTUSER, tCodeRead _ ",%Admin_Task:U,%DB_IRISSYS:R"))
        For tI = 1:1:$ListLength(tCases) {
            Set tCase = $List(tCases, tI)
            Set tRole = $List(tCase, 1)
            Set tUser = $List(tCase, 2)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the New Task wizard's pairs (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot task wire test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.TaskWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NOTASKUSER, "%Admin_Task", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#NOSYSREADUSER, "%DB_IRISSYS", "READ") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "a principal lacking a pair did not read back as lacking it")
            Quit
        }
        If ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Task", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%DB_IRISSYS", "READ") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the least-privileged principal did not read back as the form's two pairs alone")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
