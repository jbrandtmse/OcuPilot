/// <p>Pins Story 16.4 against the instance with real principals (AD-8, AD-15, AD-21, AD-27, AD-29,
/// AD-53): the screen's Export and Import over HTTP as a principal holding exactly the four pairs,
/// round-tripping a task with every stored property kept but its id, the vendor audit rows each writes,
/// and the same file refused the second time; the rules a principal decides refusing the whole file;
/// the agent's export and import through mint and confirm, and a file rewritten after the proposal
/// refused; a principal without <code>%Admin_FileSystemAccess:USE</code> or <code>%Admin_Task:USE</code>
/// refused on both callers; files the vendor's own export writes and reads interchangeable with the
/// tools'; and a task whose start date is past scheduled as the vendor's own import schedules it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving
/// over HTTP, auditing on with <code>%System/%System/ConfigurationChange</code> enabled, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>TASKVARIABLE</parameter> reading <code>1</code>,
/// because it creates and deletes four users and three roles, probe tasks named <code>OcuP164*</code>
/// and files under the first allowed root (<class>OcuPilot.Test.TaskTransferFixture</class>). Every
/// one is removed, and a test fails if any is left.</p>
Class OcuPilot.Test.TaskTransferLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms its probe tasks.</p>
Parameter TASKVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter PROBE = "OcuPilot.Test.TaskTransferFixture";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.TaskExport";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.TaskImport";

/// <p>The principal holding the code read and exactly the tools' four pairs; the one lacking
/// <code>%Admin_FileSystemAccess:USE</code>; the one lacking <code>%Admin_Task:USE</code>; and a
/// disabled account a task may name.</p>
Parameter LEASTUSER = "OcuP164Least";

Parameter NOFILEUSER = "OcuP164NoFile";

Parameter NOTASKUSER = "OcuP164NoTask";

Parameter DISABLEDUSER = "OcuP164Disabled";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskTransferLive creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#TASKVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskTransferLive creates and deletes tasks in this instance's Task Manager and runs on a throwaway container only. " _ ..#TASKVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP164Xfer" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemoveProbes")
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probes, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveProbes")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#LEASTUSER, ..#NOFILEUSER, ..#NOTASKUSER, ..#DISABLEDUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskTransferLive left the principal or role of " _ tUser))
        }
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
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveProbes"), "every probe task and file is removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Probes"), 0, "and no probe task is left")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AC1, AC2, AC9, AD-15: as the four-pair principal, the screen's Export writes the task and no audit
/// row, and the screen's Import of that file, once the task is deleted, recreates it with every stored
/// property but its id, writing one <code>ConfigurationChange</code> "Create Task" row; the same file
/// again is 409 <code>TASK.IMPORT.PRESENT</code> with nothing added.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.TaskTransferPort.Export</method> passes
/// <code>$ListBuild()</code> to the vendor -- the file holds no task and this goes red.</p>
Method TestTheScreenRoundTripKeepsEveryStoredProperty()
{
    Set tDirectory = $ClassMethod(..#PROBE, "ProbeDirectory")
    Do $$$AssertStatusOK(..MakeScheduled("Round", .tId), "a probe task with a distinctive schedule is made")
    Set tBefore = ..Stored(tId)
    Set tName = tBefore.%Get("Name")
    Set tSince = ..Now()
    Do ..Act("export", tId, "OcuP164/round.xml", ..#LEASTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen's Export answers 200: " _ ..Json(tBody))
    Set tText = $ClassMethod(..#PROBE, "FileText", tDirectory _ "round.xml")
    Do $$$AssertTrue(($Length(tText, "<Task>") = 2) && (tText [ ("<Name>" _ tName _ "</Name>")), "the file holds exactly that task")
    Do $$$AssertEquals(..AuditRows(tSince, tName), 0, "and the export wrote no audit row naming it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTask", tId), "the task is deleted")
    Set tSince = ..Now()
    Do ..Act("import", "import", "OcuP164/round.xml", ..#LEASTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen's Import answers 200: " _ ..Json(tBody))
    If $IsObject(tBody) Do $$$AssertEquals(tBody.%Get("action"), "created", "publishing created")
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Set tNewId = $Get(tIds(tName))
    Do $$$AssertTrue((tNewId '= "") && (tNewId '= tId), "the task is listed again, under a new id")
    If tNewId '= "" Do $$$AssertEquals(..Stored(tNewId).%ToJSON(), tBefore.%ToJSON(), "and every stored property equals the exported one's")
    Do $$$AssertEquals(..AuditRows(tSince, "Create Task " _ tName, "ConfigurationChange"), 1, "the import wrote one Create Task row for it")
    Do ..Act("import", "import", "OcuP164/round.xml", ..#LEASTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "409 TASK.IMPORT.PRESENT", "importing the same file again is refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Probes"), 1, "with nothing added")
}

/// <p>AC6, the rows a principal decides: as the four-pair principal, a file holding a task that runs as
/// another account is refused <code>TASK.RUNASUSER.SECURE</code>, one whose type needs a privilege
/// the principal lacks <code>TASK.TASKCLASS.PERMISSION</code>, and one in a namespace whose database
/// the principal cannot read (<code>USER</code>) <code>TASK.NAMESPACE.UNKNOWN</code>; a task naming a
/// disabled account is refused <code>TASK.RUNASUSER.DISABLED</code>. Each names the task and imports
/// nothing.</p>
Method TestTheRulesAPrincipalDecidesRefuseTheWholeFile()
{
    Set tDirectory = $ClassMethod(..#PROBE, "ProbeDirectory")
    Set tGood = $ClassMethod(..#PROBE, "Entry", "Good", "%SYS", "%SYS.Task.PurgeTaskHistory", ..#LEASTUSER)
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tReadsUser = ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%DB_USER", "READ") = 1)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue('tReadsUser, "the four-pair principal cannot read USER's database")
    For tCase = $ListBuild("Secure", "%SYS", "%SYS.Task.PurgeTaskHistory", "_SYSTEM", "TASK.RUNASUSER.SECURE"), $ListBuild("Permission", "HSCUSTOM", "Ens.Util.Tasks.Purge", ..#LEASTUSER, "TASK.TASKCLASS.PERMISSION"), $ListBuild("Unreadable", "USER", "%SYS.Task.PurgeTaskHistory", ..#LEASTUSER, "TASK.NAMESPACE.UNKNOWN") {
        Set tBad = $ClassMethod(..#PROBE, "Entry", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        Do $ClassMethod(..#PROBE, "WriteFile", tDirectory _ "rule.xml", $ClassMethod(..#PROBE, "ExportText", [(tGood), (tBad)]))
        Do ..Act("import", "import", "OcuP164/rule.xml", ..#LEASTUSER, .tStatus, .tBody)
        Set tTask = $Select($IsObject(tBody) && $IsObject(tBody.%Get("detail")): tBody.%Get("detail").%Get("task"), 1: "")
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ tTask, "422 " _ $List(tCase, 5) _ " " _ tBad.%Get("Name"), $List(tCase, 5) _ " refuses the file naming the task: " _ ..Json(tBody))
    }
    Set tBad = $ClassMethod(..#PROBE, "Entry", "Disabled", "%SYS", "%SYS.Task.PurgeTaskHistory", ..#DISABLEDUSER)
    Do $ClassMethod(..#PROBE, "WriteFile", tDirectory _ "rule.xml", $ClassMethod(..#PROBE, "ExportText", [(tBad)]))
    Kill tQuery
    Set tQuery("id") = "import"
    Set tQuery("root") = $ClassMethod(..#PROBE, "FirstRoot")
    Set tQuery("path") = "OcuP164/rule.xml"
    Set tSC = ##class(OcuPilot.Port.TaskTransferPort).Invoke("TaskTransfer", "IMPORT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..Code(tFault), "422 TASK.RUNASUSER.DISABLED", "a task naming a disabled account is refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Probes"), 0, "and nothing is imported")
}

/// <p>AC5: the agent's export mints and confirms, writing the file, and its import, once the task is
/// deleted, recreates it; an import whose file is rewritten between the mint and the confirm is refused
/// 409 <code>TASK.IMPORT.CHANGED</code> and imports nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.TaskTransferPort.Import</method>'s reviewed-tasks
/// comparison becomes <code>If 0</code> -- the rewritten file's task is created and this goes red.</p>
Method TestTheAgentExportsAndImportsThroughConfirm()
{
    Set tDirectory = $ClassMethod(..#PROBE, "ProbeDirectory")
    Set tRoot = $ClassMethod(..#PROBE, "FirstRoot")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTask", "Agent", .tId, .tGuid), "a probe task is made")
    Set tSC = ..MintAs($Username, ..#EXPORTTOOL, tId, {"Id": (tId), "root": (tRoot), "path": "OcuP164/agent.xml"}, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "the export mints")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and its confirm writes the file: " _ $Get(tCode))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "FileText", tDirectory _ "agent.xml") [ "<Name>OcuP164Agent</Name>", "the file holds the task")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTask", tId), "the task is deleted")
    Set tSC = ..MintAs($Username, ..#IMPORTTOOL, "import", {"Id": "import", "root": (tRoot), "path": "OcuP164/agent.xml"}, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "the import mints")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and its confirm imports: " _ $Get(tCode))
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Do $$$AssertTrue($Data(tIds("OcuP164Agent")), "the task is listed again")
    Do $ClassMethod(..#PROBE, "WriteFile", tDirectory _ "changed.xml", $ClassMethod(..#PROBE, "ExportText", [($ClassMethod(..#PROBE, "Entry", "Reviewed"))]))
    Set tSC = ..MintAs($Username, ..#IMPORTTOOL, "import", {"Id": "import", "root": (tRoot), "path": "OcuP164/changed.xml"}, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "an import of another file mints")
    Do $ClassMethod(..#PROBE, "WriteFile", tDirectory _ "changed.xml", $ClassMethod(..#PROBE, "ExportText", [($ClassMethod(..#PROBE, "Entry", "Swapped"))]))
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode), "409 TASK.IMPORT.CHANGED", "a file rewritten after the proposal is refused")
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Do $$$AssertTrue('$Data(tIds("OcuP164Swapped")) && '$Data(tIds("OcuP164Reviewed")), "and nothing is imported")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC7: a principal without <code>%Admin_FileSystemAccess:USE</code>, or without
/// <code>%Admin_Task:USE</code>, is refused 403 <code>AUTH.NOPRIVILEGE</code> naming the pair on the
/// screen's Export and Import; the agent's export minted for the first is refused at its confirm, and no
/// file is written.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_FileSystemAccess:USE</code> from both tools'
/// <code>PrivilegePairs</code> and from the port's <parameter>OcuPilot.Port.TaskTransferPort.PAIRS</parameter>
/// -- the screen legs reach PathPort's own gate and answer 403 <code>PORT.ACCESSDENIED</code>, and this
/// goes red.</p>
Method TestAPrincipalWithoutAPairIsRefusedOnBothCallers()
{
    Set tDirectory = $ClassMethod(..#PROBE, "ProbeDirectory")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTask", "Denied", .tId, .tGuid), "a probe task is made")
    Do $ClassMethod(..#PROBE, "WriteFile", tDirectory _ "in.xml", $ClassMethod(..#PROBE, "ExportText", [($ClassMethod(..#PROBE, "Entry", "DeniedIn"))]))
    For tCase = $ListBuild(..#NOFILEUSER, "%Admin_FileSystemAccess:USE"), $ListBuild(..#NOTASKUSER, "%Admin_Task:USE") {
        Do ..Act("export", tId, "OcuP164/denied.xml", $List(tCase, 1), .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2), $List(tCase, 1) _ "'s Export is refused naming the pair")
        Do ..Act("import", "import", "OcuP164/in.xml", $List(tCase, 1), .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2), $List(tCase, 1) _ "'s Import is refused naming the pair")
    }
    Set tSC = ..MintAs(..#NOFILEUSER, ..#EXPORTTOOL, tId, {"Id": (tId), "root": ($ClassMethod(..#PROBE, "FirstRoot")), "path": "OcuP164/denied.xml"}, .tProposal, .tTurn)
    Do $$$AssertStatusOK(tSC, "an export is minted for the principal without the file pair")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), "", ..#NOFILEUSER, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode) _ " " _ $Select($IsObject($Get(tDetail)): tDetail.%Get("failedPair"), 1: ""), "403 AUTH.NOPRIVILEGE %Admin_FileSystemAccess:USE", "and its confirm is refused naming the pair")
    Do $$$AssertTrue('##class(%File).Exists(tDirectory _ "denied.xml"), "no file is written")
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Do $$$AssertTrue('$Data(tIds("OcuP164DeniedIn")), "and no task is imported")
}

/// <p>AC3: a file the vendor's own <code>ExportTasks</code> writes imports through the screen's Import,
/// and a file the screen's Export writes imports through the vendor's own <code>ImportTasks</code>.</p>
Method TestVendorFilesAndToolFilesAreInterchangeable()
{
    Set tDirectory = $ClassMethod(..#PROBE, "ProbeDirectory")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTask", "Vendor", .tId, .tGuid, ..#LEASTUSER), "a probe task is made")
    Do $$$AssertStatusOK(..VendorCall("ExportTasks", $ListBuild(tId), tDirectory _ "vendor.xml"), "the vendor exports it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTask", tId), "the task is deleted")
    Do ..Act("import", "import", "OcuP164/vendor.xml", ..#LEASTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the vendor's file imports through the screen: " _ ..Json(tBody))
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Set tNewId = $Get(tIds("OcuP164Vendor"))
    Do $$$AssertTrue(tNewId '= "", "the task is listed again")
    Do ..Act("export", tNewId, "OcuP164/tool.xml", ..#LEASTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen exports it again: " _ ..Json(tBody))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTask", tNewId), "the task is deleted again")
    Do $$$AssertStatusOK(..VendorCall("ImportTasks", "", tDirectory _ "tool.xml"), "the vendor imports the tool's file")
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Do $$$AssertTrue($Data(tIds("OcuP164Vendor")), "and the task is listed again")
}

/// <p>AD-27: the import passes the vendor's <code>runPastTasksTomorrow</code> 0. A task whose start date
/// is past, imported through the screen, is scheduled exactly as the vendor's own
/// <code>ImportTasks</code> with 0 schedules the same file, its next run recomputed forward.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.TaskTransferPort.VendorImport</method> passes 1 -- the
/// next run keeps the exported one and this goes red.</p>
Method TestAPastStartTaskIsScheduledAsTheVendorSchedulesIt()
{
    Set tDirectory = $ClassMethod(..#PROBE, "ProbeDirectory")
    Do $$$AssertStatusOK(..MakeScheduled("Past", .tId, -10), "a probe task that started ten days ago is made")
    Do $$$AssertStatusOK(..VendorCall("ExportTasks", $ListBuild(tId), tDirectory _ "past.xml"), "the vendor exports it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTask", tId), "the task is deleted")
    Do ..Act("import", "import", "OcuP164/past.xml", ..#LEASTUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen imports it: " _ ..Json(tBody))
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Set tTool = ..Schedule($Get(tIds("OcuP164Past")))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTask", $Get(tIds("OcuP164Past"))), "the imported task is deleted")
    Do $$$AssertStatusOK(..VendorCall("ImportTasks", "", tDirectory _ "past.xml"), "the vendor imports the same file with 0")
    Do $ClassMethod(..#PROBE, "Probes", .tIds)
    Set tVendor = ..Schedule($Get(tIds("OcuP164Past")))
    Do $$$AssertTrue($Length(tTool, "|") = 3, "the imported task's schedule is read: " _ tTool)
    Do $$$AssertEquals(tTool, tVendor, "the screen's import schedules it as the vendor's own import with 0")
}

/// <p>Task <var>pId</var>'s next run and last schedule as stored,
/// <code>DayNextScheduled|TimeNextScheduled|LastSchedule</code>, or <code>""</code> when it is not read.</p>
Method Schedule(pId As %String) As %String
{
    If pId = "" Quit ""
    Set tStored = ..Stored(pId)
    If tStored.%Get("DayNextScheduled") = "" Quit ""
    Quit tStored.%Get("DayNextScheduled") _ "|" _ tStored.%Get("TimeNextScheduled") _ "|" _ tStored.%Get("LastSchedule")
}

/// <p>A probe task named <code>OcuP164</code> and <var>pSuffix</var> run as the four-pair principal every
/// third day from <var>pStartDays</var> days from today, several times an hour from 01:00 to 02:00,
/// every 45 minutes.</p>
Method MakeScheduled(pSuffix As %String, Output pId As %String, pStartDays As %Integer = 2) As %Status
{
    Set pId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%New()
        Set tTask.Name = "OcuP164" _ pSuffix
        Set tTask.NameSpace = "%SYS"
        Set tTask.TaskClass = "%SYS.Task.PurgeTaskHistory"
        Set tTask.TimePeriod = 0
        Set tTask.TimePeriodEvery = 3
        Set tTask.DailyFrequency = 1
        Set tTask.DailyFrequencyTime = 0
        Set tTask.DailyIncrement = 45
        Set tTask.DailyStartTime = 3600
        Set tTask.DailyEndTime = 7200
        Set tTask.StartDate = +$Horolog + pStartDays
        Set tTask.RunAsUser = ..#LEASTUSER
        Set tTask.Description = "OcuPilot Story 16.4 round trip"
        Set tSC = tTask.%Save()
        If $$$ISOK(tSC) Set pId = tTask.%Id()
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Task <var>pId</var>'s every stored property but its id, as the instance holds them: each
/// non-transient, non-calculated property of <code>%SYS.Task</code>, a list as its members joined by
/// commas.</p>
Method Stored(pId As %String) As %DynamicObject
{
    Set tStored = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId, 0)
        Set tClass = ##class(%Dictionary.CompiledClass).%OpenId("%SYS.Task", 0)
        For tI = 1:1:tClass.Properties.Count() {
            Set tProperty = tClass.Properties.GetAt(tI)
            If tProperty.Transient || tProperty.Calculated || tProperty.MultiDimensional || ($Extract(tProperty.Name) = "%") Continue
            Set tValue = $Property(tTask, tProperty.Name)
            If $IsObject(tValue) {
                Set tText = ""
                For tJ = 1:1:tValue.Count() Set tText = tText _ $Select(tJ = 1: "", 1: ",") _ tValue.GetAt(tJ)
                Set tValue = tText
            }
            Do tStored.%Set(tProperty.Name, tValue _ "", "string")
        }
        Set tTask = ""
        Set tClass = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStored = {}
    }
    Quit tStored
}

/// <p>The vendor's own <var>pMethod</var> of <code>%SYS.Task</code> in <code>%SYS</code>: an export of
/// <var>pIds</var> to <var>pFile</var>, or an import of <var>pFile</var>.</p>
ClassMethod VendorCall(pMethod As %String, pIds As %List, pFile As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pMethod = "ExportTasks" {
            Set tSC = ##class(%SYS.Task).ExportTasks(pIds, pFile, "-d")
        } Else {
            Set tSC = ##class(%SYS.Task).ImportTasks(pFile, "-d", 0)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many audit rows since <var>pSince</var> carry <var>pText</var> in their description, of event
/// <var>pEvent</var> when it is given, read in <code>%SYS</code>; a short wait lets a row the vendor is
/// writing land.</p>
ClassMethod AuditRows(pSince As %String, pText As %String, pEvent As %String = "") As %Integer
{
    Hang 1
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        ; The event is compared here rather than in the WHERE clause: this build's audit table answers
        ; no row for a predicate on its event columns beside one on the description (measured).
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventSource, EventType, Event FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND Description [ ?", pSince, pText)
        Set tCount = 0
        While tRS.%Next() {
            If (pEvent = "") || ((tRS.%GetData(1) = "%System") && (tRS.%GetData(2) = "%System") && (tRS.%GetData(3) = pEvent)) Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The instance's UTC time, as the audit database's own timestamps spell it.</p>
ClassMethod Now() As %String
{
    Quit $ZDateTime($ZTimeStamp, 3, 1, 3)
}

/// <p>One screen action over Task schedule's route: <var>pAction</var> on <var>pId</var> with the file
/// <var>pPath</var> under the first root, as <var>pUser</var>; the HTTP status and the parsed
/// envelope.</p>
Method Act(pAction As %String, pId As %String, pPath As %String, pUser As %String, Output pStatus As %Integer, Output pBody)
{
    Set pBody = ""
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Set tValues = {}
    Do tValues.%Set("root", $ClassMethod(..#PROBE, "FirstRoot"), "string")
    Do tValues.%Set("path", pPath, "string")
    Do tRequest.%Set("values", tValues)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.schedule/action", pUser, ..PreparedPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
}

/// <p>The agent's mint of <var>pTool</var> for <var>pId</var> with <var>pArgs</var>, as <var>pUser</var>,
/// over a completed turn seeded for that user.</p>
Method MintAs(pUser As %String, pTool As %String, pId As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pTurn As %String) As %Status
{
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .pTurn)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod($ClassMethod(pTool, "MintClass"), "Mint", $Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), pUser, "", pTurn, pArgs, "OcuPilot.Kernel.Agent.Limits", .pProposal, .tHttp, .tFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>The code an envelope or fault <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>The failed pair an envelope <var>pBody</var> names, or <code>""</code>.</p>
ClassMethod FailedPair(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("failedPair")
}

/// <p><var>pBody</var> as text.</p>
ClassMethod Json(pBody) As %String
{
    If $IsObject(pBody) Quit pBody.%ToJSON()
    Quit $Get(pBody)
}

/// <p>Create the four principals, each with a role of its own: the least-privileged one holding the
/// code read and the tools' four pairs, one without the file pair, one without the Task Manager pair,
/// and a disabled account; then read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tCode = ##class(OcuPilot.Test.ClassicPageGate).CodeRead()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCases = $ListBuild($ListBuild(..#LEASTUSER, tCode _ ",%Admin_Task:U,%DB_IRISSYS:R,%Admin_FileSystemAccess:U", 1), $ListBuild(..#NOFILEUSER, tCode _ ",%Admin_Task:U,%DB_IRISSYS:R", 1), $ListBuild(..#NOTASKUSER, tCode _ ",%DB_IRISSYS:R,%Admin_FileSystemAccess:U", 1), $ListBuild(..#DISABLEDUSER, tCode, 0))
        For tI = 1:1:$ListLength(tCases) {
            Set tCase = $List(tCases, tI)
            Set tUser = $List(tCase, 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            Set tSC = ##class(Security.Roles).Create(tUser _ "Role", "OcuPilot test: task export and import (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tUser _ "Role", ..PreparedPassword, "OcuPilot task transfer test principal (throwaway)", "", "", "", 0, $List(tCase, 3), "Created by OcuPilot.Test.TaskTransferLive; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISOK(tSC) {
            If ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_FileSystemAccess", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Task", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%DB_IRISSYS", "WRITE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#NOFILEUSER, "%Admin_FileSystemAccess", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#NOTASKUSER, "%Admin_Task", "USE") = 1) {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principals' grants did not read back as declared")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
