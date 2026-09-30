/// <p>Pins DW-1638 with real principals (AD-8, AD-53, AD-55): a task's type declares a privilege, and
/// the Task schedule's suspend, resume, run and delete judge it on both callers, as the create and
/// the edit do. A principal holding the screen's two pairs and not the probe purge task's
/// <code>%Ens_PurgeSchedule:USE</code> is refused each on the route and at the agent's mint with
/// the published sentence, and the task is unchanged; a holder of that pair suspends, resumes and
/// deletes it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>TASKVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes two users, two roles and a probe
/// <code>Ens.Util.Tasks.Purge</code> task in <code>HSCUSTOM</code>, scheduled from tomorrow and never
/// run (<class>OcuPilot.Test.TaskEditProbe</class>). Every probe is removed by exact name.</p>
Class OcuPilot.Test.TaskRowWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms its probe task.</p>
Parameter TASKVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

/// <p>The principal holding the code read and the Task schedule's two pairs, and not the purge
/// type's resource.</p>
Parameter NOPAIRUSER = "OcuPilotTaskRowNoPurge";

Parameter NOPAIRROLE = "OcuPilotTaskRowNoPurgeRole";

/// <p>The principal holding the same and <code>%Ens_PurgeSchedule:USE</code>.</p>
Parameter HOLDERUSER = "OcuPilotTaskRowPurge";

Parameter HOLDERROLE = "OcuPilotTaskRowPurgeRole";

/// <p>The probe purge task's name.</p>
Parameter PROBE = "OcuP98RowPurge";

/// <p>The published sentence, as EXPERIENCE.md spells it.</p>
Parameter REFUSAL = "This task type needs a privilege you do not hold.";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskRowWire creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#TASKVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskRowWire creates and deletes a task in this instance's Task Manager and runs on a throwaway container only. " _ ..#TASKVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotRow" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ..RemoveProbe()
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe task, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ..RemoveProbe()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#NOPAIRUSER, ..#HOLDERUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskRowWire left the user " _ tUser))
        }
        For tRole = ..#NOPAIRROLE, ..#HOLDERROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskRowWire left the role " _ tRole))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Each test creates its own probe task.</p>
Method OnBeforeOneTest() As %Status
{
    Quit ..RemoveProbe()
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ..RemoveProbe()
    Do $$$AssertStatusOK(tSC, "the probe task is removed")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit tSC
}

/// <p>AC8 on the route: the principal without the purge type's pair is refused suspend, resume, run
/// and delete with 400 <code>TOOL.ARGUMENTS</code> and the published sentence, and the task is
/// neither suspended, run nor deleted.</p>
/// <p>Mutation (Rule 19): drop the <code>TargetProblem</code> call from
/// <method>OcuPilot.Screen.Tool.TaskResume.ScreenActionDelta</method> -- the suspend and the resume
/// are sent and this goes red.</p>
Method TestTheRouteRefusesACallerWithoutTheTypesPair()
{
    Set tId = ..CreateProbe()
    Do $$$AssertNotEquals(tId, "", "the probe purge task is created")
    If tId = "" Quit
    Set tNext = ##class(OcuPilot.Test.TaskEditProbe).Info(tId, "NextScheduled")
    For tAction = "suspend", "resume", "run", "delete" {
        Set tSC = ..Act(tAction, tId, ..#NOPAIRUSER, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..Problem(tBody), "400 TOOL.ARGUMENTS " _ ..#REFUSAL, "its " _ tAction _ " is refused with the published sentence")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskEditProbe).IdOf(..#PROBE), tId, "the task is still there")
    Do $$$AssertEquals(..Suspended(tId), "false", "not suspended")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskEditProbe).Info(tId, "NextScheduled"), tNext, "and not run")
}

/// <p>AC8 at the agent's mint: the same principal's proposal of each of the four tools is refused
/// 400 with the published sentence, in a process logged in as it, and nothing is sent.</p>
/// <p>Mutation (Rule 19): drop the <code>TargetProblem</code> call from
/// <method>OcuPilot.Screen.Tool.TaskDelete.ArgumentProblem</method> -- the delete mints and this goes
/// red.</p>
Method TestTheMintRefusesACallerWithoutTheTypesPair()
{
    Set tId = ..CreateProbe()
    Do $$$AssertNotEquals(tId, "", "the probe purge task is created")
    If tId = "" Quit
    For tTool = "OcuPilot.Screen.Tool.TaskSuspend", "OcuPilot.Screen.Tool.TaskResume", "OcuPilot.Screen.Tool.TaskScheduleRun", "OcuPilot.Screen.Tool.TaskDelete" {
        Set tOut = ..AgentMint(..#NOPAIRUSER, tTool, tId)
        Do $$$AssertEquals(tOut.%Get("error") _ tOut.%Get("username") _ " " _ tOut.%Get("http") _ " " _ tOut.%Get("problem"), ..#NOPAIRUSER _ " 400 " _ ..#REFUSAL, $Parameter(tTool, "TOOLNAME") _ "'s mint is refused with the published sentence")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskEditProbe).IdOf(..#PROBE), tId, "the task is still there")
    Do $$$AssertEquals(..Suspended(tId), "false", "and not suspended")
}

/// <p>AC8's other half: a holder of <code>%Ens_PurgeSchedule:USE</code> with the screen's pairs
/// suspends, resumes and deletes the probe through the route; the probe is never run.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Task.TaskRules.TargetProblem</method> refuse
/// every task -- the holder's suspend is refused and this goes red.</p>
Method TestAHolderOfTheTypesPairActsOnIt()
{
    Set tId = ..CreateProbe()
    Do $$$AssertNotEquals(tId, "", "the probe purge task is created")
    If tId = "" Quit
    Set tSC = ..Act("suspend", tId, ..#HOLDERUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the holder suspends it: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Suspended(tId), "true", "and it reads suspended")
    Set tSC = ..Act("resume", tId, ..#HOLDERUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the holder resumes it: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Suspended(tId), "false", "and it reads resumed")
    Set tSC = ..Act("delete", tId, ..#HOLDERUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the holder deletes it: " _ ..Shown(tBody))
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskEditProbe).IdOf(..#PROBE), "", "and it is gone")
}

/// <p>The probe purge task, created through the wizard's own Save: <code>Ens.Util.Tasks.Purge</code>
/// in <code>HSCUSTOM</code>, purging events, scheduled from tomorrow. Its id, or <code>""</code>.</p>
Method CreateProbe() As %String
{
    Set tArgs = ##class(OcuPilot.Test.TaskEditProbe).Ac7(..#PROBE)
    Do tArgs.%Set("TaskClass", "Ens.Util.Tasks.Purge", "string")
    Do tArgs.%Set("NameSpace", "HSCUSTOM", "string")
    Do tArgs.%Set("Settings", {"TypesToPurge": "events"})
    Set tSC = ##class(OcuPilot.Test.TaskEditProbe).Create(tArgs, .tId)
    If $$$ISERR(tSC) Quit ""
    Quit tId
}

/// <p>Remove the probe task by its exact name, when it is there.</p>
ClassMethod RemoveProbe() As %Status
{
    Set tId = ##class(OcuPilot.Test.TaskEditProbe).IdOf(..#PROBE)
    If tId = "" Quit $$$OK
    Quit ##class(OcuPilot.Test.TaskEditProbe).Remove(tId)
}

/// <p>Task <var>pId</var>'s <code>Suspended</code> as its <code>INFO</code> answers it, as text.</p>
ClassMethod Suspended(pId As %String) As %String
{
    Set tValue = ##class(OcuPilot.Test.TaskEditProbe).Info(pId, "Suspended")
    Quit $Select(tValue = 1: "true", tValue = 0: "false", 1: tValue)
}

/// <p><var>pUser</var>'s own mint of <var>pTool</var> for task <var>pId</var>, in a process logged
/// in as it (<method>OcuPilot.Test.TaskWire.MintAs</method>), as <code>{username, http, problem}</code>
/// or <code>{error}</code>.</p>
Method AgentMint(pUser As %String, pTool As %String, pId As %String) As %DynamicObject
{
    Set tOut = {}
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit {"error": "no turn was seeded"}
    Set tArgs = {}
    Do tArgs.%Set("Id", pId, "string")
    Set tArgsJson = tArgs.%ToJSON()
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.TaskWire).MintAs($Job, pUser, tTurnKey, tArgsJson, pTool)::10
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

/// <p>One Task schedule row action over the route as <var>pUser</var>, answering the HTTP status and
/// the parsed envelope.</p>
Method Act(pAction As %String, pId As %String, pUser As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.schedule/action", pUser, ..PreparedPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
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

/// <p><var>pBody</var> as text for an assertion message.</p>
ClassMethod Shown(pBody) As %String
{
    Quit $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody))
}

/// <p>Create the two throwaway roles and the accounts that hold them, then read the grants
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
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tCase = $ListBuild(..#NOPAIRUSER, ..#NOPAIRROLE, tCode _ ",%Admin_Task:U,%DB_IRISSYS:R"), $ListBuild(..#HOLDERUSER, ..#HOLDERROLE, tCode _ ",%Admin_Task:U,%DB_IRISSYS:R,%Ens_PurgeSchedule:U") {
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: a task type's privilege (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot task row test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.TaskRowWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NOPAIRUSER, "%Ens_PurgeSchedule", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#HOLDERUSER, "%Ens_PurgeSchedule", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#NOPAIRUSER, "%Admin_Task", "USE") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the principals' grants did not read back as declared")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
