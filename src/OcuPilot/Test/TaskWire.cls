/// <p>Pins the New Task wizard's gate over the wire with real principals (AD-8, AD-29): a caller
/// lacking one of <class>OcuPilot.Screen.Descriptor.TaskForm</class>'s two declared pairs is refused
/// 403 on every <code>/tasks</code> route, naming the pair, and nothing is created; the
/// least-privileged principal the form declares creates a task; and running a task as another
/// account without <code>%Admin_Secure:USE</code> is refused on <code>RunAsUser</code> before any write,
/// which the instance itself also enforces (AC6).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>TASKVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes three users, three roles and probe tasks
/// (<class>OcuPilot.Test.TaskProbe</class>). <method>OnBeforeAllTests</method> refuses anywhere
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
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe tasks, the principals and their roles; a failing status when any
/// survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ##class(OcuPilot.Test.TaskProbe).RemoveAll()
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
