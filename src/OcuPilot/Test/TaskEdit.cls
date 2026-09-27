/// <p>Pins Edit task's screen routes over the wire (AD-4, AD-12, AD-39, AD-55): the form read of one
/// task (<code>GET /tasks/form?id=</code>) and the Save (<code>PUT /tasks/:id</code>) through the
/// Matrix's rows -- a two-field save whose every other field reads back, a start already past, a
/// taken name, the output file's rules, an undeclared key and an absent task -- and
/// <class>OcuPilot.Port.TaskPort</class>'s <code>PUT</code> omissions.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the test principal
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// it creates and edits probe tasks (<class>OcuPilot.Test.TaskEditProbe</class>), each removed by id
/// after its exact name is read back. <method>OnBeforeAllTests</method> refuses anywhere it does
/// not.</p>
Class OcuPilot.Test.TaskEdit Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter PROBE = "OcuPilot.Test.TaskEditProbe";

/// <p>The Save's route, whose <code>:id</code> each request replaces with a probe task's id.</p>
Parameter EDITPATH = "/tasks/:id";

/// <p>The secret the secret-bearing probe holds, compared in process and never written out.</p>
Parameter PROBESECRET = "ocup98-wire-not-a-real-secret";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskEdit creates, edits and deletes tasks in this instance's Task Manager and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>The form read of one task answers the edit tool's fresh read with its id, the task's namespace
/// and its types; a type holding a secret setting is answered with no settings and
/// <code>settingsClassicOnly</code> (AD-35); and an absent or non-numeric id is 404
/// <code>TASK.ABSENT</code>.</p>
Method TestTheFormReadAnswersOneTask()
{
    Set tSC = $ClassMethod(..#PROBE, "Create", $ClassMethod(..#PROBE, "Ac7", "OcuP98Form"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/tasks/form?id=" _ tId, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    If $IsObject($Get(tAnswer)) {
        Set tTask = tAnswer.%Get("task")
        Do $$$AssertTrue($IsObject(tTask), "with the task")
        If $IsObject(tTask) {
            Do $$$AssertEquals(tTask.%Get("Id"), +tId, "carrying its id")
            Do $$$AssertEquals(tTask.%Get("Name") _ " " _ tTask.%Get("Priority") _ " " _ tTask.%Get("MirrorStatus") _ " " _ tTask.%Get("OutputFilename"), "OcuP98Form Low Any ocup98edit.txt", "and its stored values")
            Do $$$AssertEquals(tTask.%Get("Settings").%ToJSON(), "{""KeepDays"":""30""}", "and its settings")
        }
        Do $$$AssertEquals(tAnswer.%Get("settingsClassicOnly"), 0, "whose settings are drawn")
        Do $$$AssertEquals(tAnswer.%Get("namespace"), "%SYS", "in the task's namespace")
        Do $$$AssertTrue(tAnswer.%Get("types").%Size() > 0, "whose types are listed")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/tasks/form?id=" _ tId, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 TASK.ABSENT", "a deleted task is absent")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/tasks/form?id=abc", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 404, "and so is an id that is not a number")

    Set tSC = $ClassMethod(..#PROBE, "CreateSecret", "OcuP98FormSecret", ..#PROBESECRET, .tId)
    Do $$$AssertStatusOK(tSC, "the secret-bearing probe is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/tasks/form?id=" _ tId, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its form read answers")
    Do $$$AssertTrue($Get(tText) '[ ..#PROBESECRET, "and never carries the secret")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tText) } Catch {}
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.%Get("task").%GetTypeOf("Settings") _ " " _ tAnswer.%Get("settingsClassicOnly"), "unassigned 1", "its task carries no settings and says they are classic-only")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>Matrix "Secret-bearing type", AC4's refused leg on the Save itself: a <code>Settings</code>
/// change sent to <code>PUT /tasks/:id</code> for a <code>%SYS.Task.DiagnosticReport</code> probe
/// is refused <code>422 Settings:TASK.SETTING.SECRET</code> by the wire route -- Gate, body read, id
/// decode and the JSON envelope included, not only the rule call a direct class-method test can
/// reach -- before any port call; the refusal never carries the secret and the stored secret is
/// unchanged (compared in process). A Save of another field on the same task still writes, and the
/// secret still survives it.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Area.Task.TaskRules.WithheldSettingsCode</method>,
/// make the <code>secret</code> arm of the kind loop <code>If 0</code> -- the code answered over the
/// wire drops to <code>TASK.SETTING.CLASSICONLY</code> and this goes red.</p>
Method TestASecretBearingTypesSettingsChangeIsRefusedBySaveOverTheWire()
{
    Set tSC = $ClassMethod(..#PROBE, "CreateSecret", "OcuP98SaveSecret", ..#PROBESECRET, .tId)
    Do $$$AssertStatusOK(tSC, "the secret-bearing probe is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Settings"":{""SMTPUser"":""ocup98other""}}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 Settings:TASK.SETTING.SECRET", "the Save refuses the settings change by name, over the wire, before any port call")
    Do $$$AssertTrue($Select($IsObject($Get(tAnswer)): (tAnswer.%ToJSON() '[ ..#PROBESECRET), 1: 0), "and the refusal never carries the secret")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretHeld", tId, ..#PROBESECRET), "the stored secret is unchanged")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Description"":""save still writes""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a Save of another field still writes: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretHeld", tId, ..#PROBESECRET), "and the stored secret survives it")
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>Matrix "Two-field save" and AC2 on the screen's path: a Save of Description and
/// DailyIncrement answers 200 <code>{id, name}</code>, those two change, and every other field --
/// the settings among them -- reads back from the instance as it was; a Save of one setting keeps
/// the type's others.</p>
/// <p>Mutation (Rule 19): merge a sent <code>Settings</code> wholesale in
/// <method>OcuPilot.Screen.Tool.TaskUpdate.MergeUpdate</method> -- a Save of one setting then resets
/// the others, and their read-back goes red.</p>
Method TestATwoFieldSaveKeepsEveryOtherField()
{
    Set tSC = $ClassMethod(..#PROBE, "Create", $ClassMethod(..#PROBE, "Ac7", "OcuP98Two"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tId)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Description"":""two fields"",""DailyIncrement"":15}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Save answers 200")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("readBack") = "object"): tAnswer.%Get("readBack").%Get("verdict") _ " " _ tAnswer.%Get("readBack").%Get("written").%ToJSON(), 1: ""), "matches []", "carrying the Save's read-back, which holds what was sent (AD-58): " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    If $IsObject($Get(tAnswer)) Do tAnswer.%Remove("readBack")
    If $IsObject($Get(tAnswer)) Do $$$AssertEquals(tAnswer.%ToJSON(), "{""id"":" _ tId _ ",""name"":""OcuP98Two""}", "with the task's id and name beside it")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tAfter), "the task reads back")
    If '$IsObject(tAfter) Quit
    Do $$$AssertEquals(tAfter.%Get("Description") _ " " _ tAfter.%Get("DailyIncrement"), "two fields 15", "the two fields changed")
    Set tIterator = tBefore.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind($ListBuild("Description", "DailyIncrement"), tKey) Continue
        Do $$$AssertEquals(tAfter.%Get(tKey), tValue, tKey _ " reads back as it was")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)

    ; A type with three settings: a Save of one keeps the other two.
    Set tArgs = {"Name": "OcuP98Settings", "TaskClass": "%SYS.Task.IntegrityCheck", "NameSpace": "%SYS", "Settings": {"Filename": "ocup98check.log", "KeepDays": "5"}, "TimePeriod": "On Demand"}
    Set tSC = $ClassMethod(..#PROBE, "Create", tArgs, .tId)
    Do $$$AssertStatusOK(tSC, "a probe task with three settings is created")
    If $$$ISERR(tSC) Quit
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tId)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Settings"":{""KeepDays"":""7""}}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a Save of one setting answers 200")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tId)
    If $IsObject(tAfter) && $IsObject(tBefore) {
        Do $$$AssertEquals(tAfter.%Get("Settings.KeepDays"), 7, "that setting changed")
        Do $$$AssertEquals(tAfter.%Get("Settings.Filename") _ " " _ tAfter.%Get("Settings.Directory"), tBefore.%Get("Settings.Filename") _ " " _ tBefore.%Get("Settings.Directory"), "and the other two held")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>Matrix "Past start" and "Time on a past start": on a task, run once a day, whose stored start
/// has passed, a Save of Description writes, the unchanged time left out of the body (AD-4's named
/// exception);
/// a Save of DailyStartTime or of the period is refused on StartDate with
/// <code>TASK.STARTDATE.PAST</code> and nothing is sent.</p>
/// <p>Mutation (Rule 19): drop the <code>DailyStartTime</code> omission from
/// <method>OcuPilot.Port.TaskPort.Trimmed</method> -- the vendor then answers 409 #7432 and the first
/// leg goes red.</p>
Method TestAStartAlreadyPastIsSentBackAsHeld()
{
    ; Once a day: the vendor re-checks a re-sent time against the clock for this shape (measured).
    Set tArgs = {"Name": "OcuP98Past", "Description": "OcuPilot edit probe", "TaskClass": "%SYS.Task.PurgeTaskHistory", "NameSpace": "%SYS", "Settings": {"KeepDays": "30"}, "TimePeriod": "Daily", "TimePeriodEvery": "1", "DailyFrequency": "Once", "DailyStartTime": "03:00", "StartDate": ($ZDate(+$Horolog + 1, 3))}
    Set tSC = $ClassMethod(..#PROBE, "Create", tArgs, .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StartInThePast", tId), "its stored start is moved into the past")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Description"":""past start""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a Save of Description writes: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tStored = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Description"), "past start", "and is stored")
    ; The vendor re-checks the start when the period changes (measured: 7432), so the start rule
    ; reads the period and refuses first.
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""TimePeriod"":""Weekly"",""TimePeriodDay"":""2""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 StartDate:TASK.STARTDATE.PAST", "a Save of the period is refused on the start")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""DailyStartTime"":""02:00""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 StartDate:TASK.STARTDATE.PAST", "a Save of the time is refused on the start")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tAfter), "the task reads back")
    If $IsObject(tAfter) && $IsObject(tStored) Do $$$AssertEquals(tAfter.%Get("DailyStartTime"), tStored.%Get("DailyStartTime"), "and nothing is sent")
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>Matrix "Rename taken": a rename to a name another task holds, in any case, is refused on Name
/// with <code>TASK.NAME.TAKEN</code>; the task's own name in another case is not a conflict.</p>
/// <p>Mutation (Rule 19): drop the <var>pExceptId</var> exclusion from
/// <method>OcuPilot.Area.Task.TaskRules.NameTaken</method> -- the own-name leg goes red.</p>
Method TestARenameToATakenNameIsRefused()
{
    Set tSC = $ClassMethod(..#PROBE, "Create", $ClassMethod(..#PROBE, "Ac7", "OcuP98Rename"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tVendor = $ClassMethod(..#PROBE, "VendorName")
    Do $$$AssertNotEquals(tVendor, "", "the instance holds a task to collide with")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, {"Name": ($ZConvert(tVendor, "L"))}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 Name:TASK.NAME.TAKEN", "a taken name is refused")
    ; The probe prefix keeps its case, so the renamed task is still found and removed by exact name.
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Name"":""OcuP98RENAME""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the task's own name in another case is not a conflict")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Name"), "OcuP98RENAME", "and is stored")
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>The output file on an edit (AD-21): a changed name follows the one-name pattern and saves in
/// the manager directory, and a task
/// writing to a directory that is neither empty nor the manager directory refuses a change with
/// <code>TASK.OUTPUTFILENAME.CLASSICONLY</code>; a key the tool does not admit -- the task's type
/// among them -- is 400, a setting the type refuses or does not declare is 422, and an absent task
/// is 404 <code>TASK.ABSENT</code>.</p>
Method TestTheEditsOwnRefusals()
{
    Set tSC = $ClassMethod(..#PROBE, "Create", $ClassMethod(..#PROBE, "Ac7", "OcuP98Refuse"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""OutputFilename"":""../escape.txt""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 OutputFilename:TASK.OUTPUTFILENAME.SHAPE", "a path is refused")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""TaskClass"":""%SYS.Task.IntegrityCheck""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "the task's type is not the edit's to change")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Settings"":{""KeepDays"":""abc""}}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 Settings.KeepDays:TASK.SETTING.INVALID", "a setting its type refuses is refused")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Settings"":{""Nope"":""1""}}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 Settings.Nope:TASK.SETTING.UNKNOWN", "and so is one its type does not declare")
    ; A task writing to the manager directory, as every wizard-created task does, takes a new name.
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tId)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""OutputFilename"":""other.txt""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a new output file name in the manager directory saves: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tStored = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tStored) && $IsObject(tBefore), "the task reads back")
    If $IsObject(tStored) && $IsObject(tBefore) Do $$$AssertEquals(tStored.%Get("OutputDirectory") _ " " _ tStored.%Get("OutputFilename"), tBefore.%Get("OutputDirectory") _ " other.txt", "and is stored in the same directory")
    Do $$$AssertStatusOK(..MoveOutputDirectory(tId, "/tmp/"), "the task's output directory is moved elsewhere, as the classic wizard can")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""OutputFilename"":""third.txt""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.TaskSave).FirstPair($Get(tAnswer)), "422 OutputFilename:TASK.OUTPUTFILENAME.CLASSICONLY", "a change there is the classic portal's")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Description"":""the directory stays""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "while another field still saves")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("OutputDirectory") _ " " _ tStored.%Get("OutputFilename"), "/tmp/ other.txt", "and leaves the file where it is")
    Do $ClassMethod(..#PROBE, "Remove", tId)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/tasks/" _ tId, .tStatus, .tAnswer, "{""Description"":""gone""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code") _ " " _ tAnswer.%Get("reason"), 1: ""), "404 TASK.ABSENT This task no longer exists.", "a deleted task is absent")
}

/// <p>AD-4's named exception, at the port: a <code>PUT</code> body loses <code>Type</code>, a time
/// equal to the stored one in either spelling, and a <code>Settings</code> equal to the stored one;
/// a changed time and changed settings are kept.</p>
/// <p>Mutation (Rule 19): drop the <code>Type</code> removal from
/// <method>OcuPilot.Port.TaskPort.Trimmed</method> -- the first leg goes red.</p>
Method TestThePortOmitsWhatTheVendorKeeps()
{
    Set tStored = {"DailyStartTime": "01:00:00", "DailyEndTime": "05:00:00", "Settings": {"KeepDays": "30"}, "Type": "User"}
    Set tBody = {"Description": "x", "DailyStartTime": "01:00", "DailyEndTime": "05:00:00", "Settings": {"KeepDays": 30}, "Type": "User"}
    Set tTrimmed = ##class(OcuPilot.Port.TaskPort).Trimmed(tBody, tStored)
    Do $$$AssertEquals(tTrimmed.%ToJSON(), "{""Description"":""x""}", "the unchanged times and settings and the port's own Type are omitted")
    Set tBody = {"DailyStartTime": "02:00", "DailyEndTime": "05:00", "Settings": {"KeepDays": "31"}}
    Set tTrimmed = ##class(OcuPilot.Port.TaskPort).Trimmed(tBody, tStored)
    Do $$$AssertEquals(tTrimmed.%ToJSON(), "{""DailyStartTime"":""02:00"",""Settings"":{""KeepDays"":""31""}}", "a changed time and changed settings are sent")
}

/// <p>AD-12: the edit's two routes answer one JSON envelope, as <code>application/json</code>, at the
/// status their input earns.</p>
Method TestEachEditRouteAnswersOneJsonEnvelope()
{
    Set tSC = $ClassMethod(..#PROBE, "Create", $ClassMethod(..#PROBE, "Ac7", "OcuP98Envelope"), .tId)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tEdit = $Replace(..#EDITPATH, ":id", tId)
    For tCase = $ListBuild("GET", "/tasks/form?id=" _ tId, "", 200), $ListBuild("PUT", tEdit, "{""Description"":""envelope""}", 200), $ListBuild("PUT", tEdit, "{""Name"":""""}", 422), $ListBuild("PUT", $Replace(..#EDITPATH, ":id", 0), "{}", 404) {
        Set tMethod = $List(tCase, 1)
        Set tPath = tBase _ $List(tCase, 2)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders, $List(tCase, 3), $Select($List(tCase, 3) '= "": "application/json", 1: ""))
        Do $$$AssertEquals(tStatus, $List(tCase, 4), tMethod _ " " _ tPath _ ": answers " _ $List(tCase, 4))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tMethod _ " " _ tPath _ ": as application/json")
        Set tParsed = ""
        Try { Set tParsed = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
        Do $$$AssertTrue($IsObject(tParsed) && ($Get(tBody) '[ "}{"), tMethod _ " " _ tPath _ ": one JSON object")
    }
    Do $ClassMethod(..#PROBE, "Remove", tId)
}

/// <p>Set probe task <var>pId</var>'s output directory to <var>pDirectory</var> directly, as the classic
/// wizard can and OcuPilot never does.</p>
ClassMethod MoveOutputDirectory(pId As %String, pDirectory As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId, 4)
        If '$IsObject(tTask) || ($Extract(tTask.Name, 1, 6) '= "OcuP98") {
            Set tTask = ""
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "not a probe task")
            Quit
        }
        Set tTask.OutputDirectory = pDirectory
        Set tSC = tTask.%Save()
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
