/// <p>Pins Story 9.7's screen routes over the wire (AD-12, AD-39, AD-55): the form read's shape --
/// the task types and their settings, the defaults, the tasks to run after --, the step check, a
/// create answered 201 <code>{id, name}</code> whose whole stored task reads back, the Matrix's
/// refusals with nothing sent, and the vendor's save-time codes landing on their fields.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the test
/// principal holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates probe tasks (<class>OcuPilot.Test.TaskProbe</class>), each
/// removed by id after its exact name is read back. <method>OnBeforeAllTests</method> refuses
/// anywhere it does not.</p>
Class OcuPilot.Test.TaskSave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter PURGE = "%SYS.Task.PurgeTaskHistory";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskSave creates and deletes tasks in this instance's Task Manager and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ##class(OcuPilot.Test.TaskProbe).RemoveAll()
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.TaskProbe).RemoveAll()
}

/// <p>The form read answers every key, a namespace's task types with their settings and defaults,
/// the vendor's own starting values with tomorrow's start, and the tasks a new one may run after;
/// a namespace the caller cannot read is a 422 on <code>NameSpace</code>.</p>
Method TestTheFormReadAnswersTypesDefaultsAndRunAfter()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/tasks/form?namespace=%25SYS", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    If '$IsObject($Get(tAnswer)) Quit
    For tKey = "requiredFields", "maxLengths", "rules", "defaults", "namespace", "types", "runAfter" {
        Do $$$AssertNotEquals(tAnswer.%GetTypeOf(tKey), "unassigned", "it answers " _ tKey)
    }
    Do $$$AssertEquals(tAnswer.%Get("namespace"), "%SYS", "for the namespace asked")
    Do $$$AssertEquals(tAnswer.%Get("requiredFields").%ToJSON(), "[""Name"",""NameSpace"",""TaskClass"",""TimePeriod""]", "marking the four the form requires")
    Do $$$AssertEquals(tAnswer.%Get("defaults").%Get("StartDate"), $ZDate(+$Horolog + 1, 3), "a new task starts tomorrow")
    Do $$$AssertEquals(tAnswer.%Get("defaults").%Get("TimePeriod") _ " " _ tAnswer.%Get("defaults").%Get("Priority") _ " " _ tAnswer.%Get("defaults").%Get("MirrorStatus"), "Daily Normal Primary", "with the class's own display values")
    Set tPurge = ""
    Set tIterator = tAnswer.%Get("types").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tType) {
        If tType.%Get("class") = ..#PURGE Set tPurge = tType
    }
    Do $$$AssertTrue($IsObject(tPurge), "the types include " _ ..#PURGE)
    If $IsObject(tPurge) {
        Do $$$AssertEquals(tPurge.%Get("settings").%Size(), 1, "whose one setting is listed")
        Set tSetting = tPurge.%Get("settings").%Get(0)
        Do $$$AssertEquals(tSetting.%Get("name") _ " " _ tSetting.%Get("kind"), "KeepDays number", "a number named KeepDays")
    }
    Do $$$AssertTrue(tAnswer.%Get("runAfter").%Size() > 0, "the tasks to run after are listed")
    If tAnswer.%Get("runAfter").%Size() > 0 {
        Set tRow = tAnswer.%Get("runAfter").%Get(0)
        Do $$$AssertTrue((tRow.%Get("guid") '= "") && (tRow.%GetTypeOf("id") = "number") && (tRow.%Get("name") '= ""), "each as {guid, id, name}")
    }
    Do $$$AssertTrue(tAnswer.%Get("rules").%Size() > 0, "the rules are listed")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/tasks/form?namespace=NOSUCHNAMESPACE", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 422, "a namespace the caller cannot read is refused")
    If $IsObject($Get(tAnswer)) Do $$$AssertEquals(..FirstPair(tAnswer), "NameSpace:TASK.NAMESPACE.UNKNOWN", "on NameSpace")
}

/// <p>AC1's server half: the step check answers every violation of the values so far at 200, and
/// none for a valid set.</p>
/// <p>Mutation (Rule 19): answer an empty array from
/// <method>OcuPilot.Area.Task.TaskRules.HandleCheck</method> -- the Name leg goes red.</p>
Method TestTheCheckAnswersTheViolationsSoFar()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/tasks/check", .tStatus, .tAnswer, "{""Name"":""""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the check answers 200")
    If '$IsObject($Get(tAnswer)) Quit
    Set tNameCode = ""
    Set tIterator = tAnswer.%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("field") = "Name" Set tNameCode = tRow.%Get("code") _ "|" _ tRow.%Get("reason")
    }
    Do $$$AssertEquals(tNameCode, "TASK.NAME.REQUIRED|" _ ##class(OcuPilot.Api.Error).#REASONTASKNAMEREQUIRED, "an empty name is refused with its sentence")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/tasks/check", .tStatus, .tAnswer, ..Weekly("OcuP97Check").%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("violations").%ToJSON(), 1: ""), "200 []", "a valid set earns none")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97Check"), "", "and the check creates nothing")
}

/// <p>The Matrix's Create weekly row and AC7: <code>POST /tasks</code> answers 201
/// <code>{id, name}</code>; the stored task reads back with every value the wizard set -- schedule,
/// setting, priority, output file under the manager directory, suspend-on-error, reschedule after a
/// restart and the addresses -- and the schedule list's read answers it.</p>
/// <p>Mutation (Rule 19): drop the <code>Several</code> fields from
/// <method>OcuPilot.Area.Task.TaskRules.Applied</method>'s kept set -- the stored quadruple goes
/// red.</p>
Method TestACreateAnswersItsIdAndReadsBackWhole()
{
    Set tBody = ..Weekly("OcuP97W")
    Do tBody.%Set("Priority", "Low", "string")
    Do tBody.%Set("OpenOutputFile", 1, "boolean")
    Do tBody.%Set("OutputFilename", "ocup97w.txt", "string")
    Do tBody.%Set("OutputFileIsBinary", 0, "boolean")
    Do tBody.%Set("SuspendOnError", 1, "boolean")
    Do tBody.%Set("RescheduleOnStart", 1, "boolean")
    Do tBody.%Set("EmailOnCompletion", ["ops@example.com"])
    Do tBody.%Set("EmailOnError", ["ops@example.com", "dev@example.com"])
    Do tBody.%Set("EmailOnExpiration", ["dev@example.com"])
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/tasks", .tStatus, .tAnswer, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the create answers 201")
    If '$IsObject($Get(tAnswer)) || (tStatus '= 201) Quit
    Set tId = tAnswer.%Get("id")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("id") _ " " _ tAnswer.%Get("name"), "number OcuP97W", "with the new id and the name")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97W"), tId, "which is the stored task's")
    Set tStored = ##class(OcuPilot.Test.TaskProbe).Stored(tId)
    Do $$$AssertTrue($IsObject(tStored), "the task reads back")
    If $IsObject(tStored) {
        Do $$$AssertEquals(tStored.%Get("TaskClass") _ "|" _ tStored.%Get("NameSpace") _ "|" _ tStored.%Get("Settings.KeepDays"), ..#PURGE _ "|%SYS|30", "its type, namespace and setting")
        Do $$$AssertEquals(tStored.%Get("TimePeriod") _ "|" _ tStored.%Get("TimePeriodEvery") _ "|" _ tStored.%Get("TimePeriodDay"), "1|1|24", "weekly, every week, Monday and Wednesday")
        Do $$$AssertEquals(tStored.%Get("DailyFrequency") _ "|" _ tStored.%Get("DailyFrequencyTime") _ "|" _ tStored.%Get("DailyIncrement") _ "|" _ tStored.%Get("DailyStartTime") _ "|" _ tStored.%Get("DailyEndTime"), "1|0|30|3600|18000", "several times, every 30 minutes, 01:00 to 05:00")
        Do $$$AssertEquals(tStored.%Get("StartDate"), (+$Horolog + 1) _ "", "from tomorrow")
        Do $$$AssertEquals(tStored.%Get("Priority") _ "|" _ tStored.%Get("SuspendOnError") _ "|" _ tStored.%Get("RescheduleOnStart"), "1|1|1", "low priority, suspended on an error, rescheduled after a restart")
        Do $$$AssertEquals(tStored.%Get("OpenOutputFile") _ "|" _ tStored.%Get("OutputDirectory") _ "|" _ tStored.%Get("OutputFilename") _ "|" _ tStored.%Get("OutputFileIsBinary"), "1|" _ $System.Util.ManagerDirectory() _ "|ocup97w.txt|0", "its output file, in the manager directory")
        Do $$$AssertEquals(tStored.%Get("EmailOnCompletion") _ "|" _ tStored.%Get("EmailOnError") _ "|" _ tStored.%Get("EmailOnExpiration"), "ops@example.com|ops@example.com,dev@example.com|dev@example.com", "and its three address lists")
        Do $$$AssertEquals(tStored.%Get("RunAsUser"), ##class(OcuPilot.Test.Http).GetTestUsername(), "running as the caller")
    }
    Kill tQuery
    Set tQuery("filter") = "OcuP97W"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    Set tListed = 0
    If $IsObject($Get(tList)) {
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("Id") = tId Set tListed = 1
        }
    }
    Do $$$AssertTrue(tListed, "and the schedule list's read answers it")
    Do ##class(OcuPilot.Test.TaskProbe).Remove(tId)
}

/// <p>The Matrix's refusals over the wire: a name another task holds in any case is 422
/// <code>TASK.NAME.TAKEN</code>; Several without an increment, a past start and a setting under its
/// type's bound are 422 on their fields; an undeclared key is 400
/// <code>PORT.FIELD.UNEXPECTED</code>. None of them creates anything.</p>
Method TestTheMatrixRefusalsSendNothing()
{
    Set tBefore = $ListLength(##class(OcuPilot.Test.TaskProbe).Probes())
    Set tVendor = ##class(OcuPilot.Test.TaskProbe).VendorName()
    Set tTaken = ..Weekly($ZConvert(tVendor, "U"))
    Set tSeveral = ..Weekly("OcuP97Several")
    Do tSeveral.%Remove("DailyIncrement")
    Set tPast = ..Weekly("OcuP97Past")
    Do tPast.%Set("TimePeriod", "Daily", "string")
    Do tPast.%Set("DailyFrequency", "Once", "string")
    Do tPast.%Set("StartDate", $ZDate(+$Horolog, 3), "string")
    Do tPast.%Set("DailyStartTime", "00:00", "string")
    Set tSetting = ..Weekly("OcuP97Setting")
    Do tSetting.%Set("Settings", {"KeepDays": "0"})
    Set tExtra = ..Weekly("OcuP97Extra")
    Do tExtra.%Set("OutputDirectory", "/tmp/", "string")
    ; Objects kept in an array, never in a $List, which would lose them.
    Set tBodies(1) = tTaken, tBodies(2) = tSeveral, tBodies(3) = tPast, tBodies(4) = tSetting, tBodies(5) = tExtra
    Set tCases = $ListBuild($ListBuild(1, 422, "Name:TASK.NAME.TAKEN"), $ListBuild(2, 422, "DailyIncrement:TASK.DAILYINCREMENT.REQUIRED"), $ListBuild(3, 422, "StartDate:TASK.STARTDATE.PAST"), $ListBuild(4, 422, "Settings.KeepDays:TASK.SETTING.INVALID"), $ListBuild(5, 400, "OutputDirectory:PORT.FIELD.UNEXPECTED"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tBody = tBodies($List(tCase, 1))
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/tasks", .tStatus, .tAnswer, tBody.%ToJSON(), "application/json")
        Set tLabel = tBody.%Get("Name")
        Do $$$AssertEquals(tStatus, $List(tCase, 2), tLabel _ " is refused " _ $List(tCase, 2))
        If $IsObject($Get(tAnswer)) Do $$$AssertEquals(..FirstPair(tAnswer), $List(tCase, 3), tLabel _ " on " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Test.TaskProbe).Probes()), tBefore, "and nothing was created")
}

/// <p>A vendor refusal the rules cannot see lands on its field (AD-39,
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>): a body with a zero increment and
/// one starting today at 00:00, sent straight to the port, answer on <code>DailyIncrement</code> (7404)
/// and <code>StartDate</code> (7432) with OcuPilot's own sentence and no vendor text.</p>
/// <p>Mutation (Rule 19): drop the <code>Task.CRUD:7404</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -- the increment leg goes red.</p>
Method TestTheVendorsCodesLandOnTheirFields()
{
    Set tIncrement = ..Weekly("OcuP97Vendor")
    Do tIncrement.%Set("DailyIncrement", "0", "string")
    Set tToday = ..Weekly("OcuP97Vendor")
    Do tToday.%Set("TimePeriod", "Daily", "string")
    Do tToday.%Set("DailyFrequency", "Once", "string")
    Do tToday.%Set("DailyStartTime", "00:00", "string")
    Do tToday.%Set("StartDate", $ZDate(+$Horolog, 3), "string")
    Set tBodies(1) = tIncrement, tBodies(2) = tToday
    Set tCases = $ListBuild($ListBuild(1, "DailyIncrement:TASK.DAILYINCREMENT.REFUSED"), $ListBuild(2, "StartDate:TASK.STARTDATE.REFUSED"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tSC = ##class(OcuPilot.Area.Task.TaskRules).Compose(tBodies($List(tCase, 1)), .tPayload, .tDiff, .tUnchanged, .tProblem)
        Do ##class(OcuPilot.Screen.Tool.TaskCreate).DerivedFields(tPayload)
        Kill tQuery
        Set tSC = ##class(OcuPilot.Port.TaskPort).Invoke("Task.CRUD", "POST", .tQuery, tPayload, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 2) _ ": the vendor refuses the save")
        Set tPair = ""
        If $IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object") && $IsObject(tFault.%Get("detail").%Get("violations")) {
            Set tIterator = tFault.%Get("detail").%Get("violations").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If $Piece(tRow.%Get("code"), ".", 1) = "TASK" Set tPair = tRow.%Get("field") _ ":" _ tRow.%Get("code")
            }
        }
        Do $$$AssertEquals(tPair, $List(tCase, 2), "and the refusal lands on its field")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%ToJSON() '[ "ERROR #"), "carrying no vendor text")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskProbe).IdOf("OcuP97Vendor"), "", "and nothing was created")
}

/// <p>AD-12: each <code>/tasks</code> route answers one JSON envelope, as
/// <code>application/json</code>, at the status its input earns.</p>
Method TestEachRouteAnswersOneJsonEnvelope()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    For tCase = $ListBuild("GET", "/tasks/form", "", 200), $ListBuild("POST", "/tasks/check", "{}", 200), $ListBuild("POST", "/tasks", "{""Name"":""""}", 422) {
        Set tMethod = $List(tCase, 1)
        Set tPath = tBase _ $List(tCase, 2)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders, $List(tCase, 3), $Select($List(tCase, 3) '= "": "application/json", 1: ""))
        Do $$$AssertEquals(tStatus, $List(tCase, 4), tMethod _ " " _ tPath _ ": answers " _ $List(tCase, 4))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tMethod _ " " _ tPath _ ": as application/json")
        Set tParsed = ""
        Try { Set tParsed = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
        Do $$$AssertTrue($IsObject(tParsed) && ($Get(tBody) '[ "}{"), tMethod _ " " _ tPath _ ": one JSON object")
    }
}

/// <p>A valid weekly create named <var>pName</var>: <parameter>PURGE</parameter> keeping 30 days, on
/// Monday and Wednesday, every 30 minutes from 01:00 to 05:00, from tomorrow.</p>
ClassMethod Weekly(pName As %String) As %DynamicObject
{
    Quit {"Name": (pName), "Description": "OcuPilot task create probe", "NameSpace": "%SYS", "TaskClass": (..#PURGE), "Settings": {"KeepDays": "30"}, "TimePeriod": "Weekly", "TimePeriodEvery": "1", "TimePeriodDay": "24", "DailyFrequency": "Several", "DailyFrequencyTime": "Minutes", "DailyIncrement": "30", "DailyStartTime": "01:00", "DailyEndTime": "05:00", "StartDate": ($ZDate(+$Horolog + 1, 3))}
}

/// <p>The first violation an envelope carries, as <code>field:code</code>, or <code>""</code>.</p>
ClassMethod FirstPair(pAnswer As %DynamicObject) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("detail") '= "object") Quit ""
    Set tRows = pAnswer.%Get("detail").%Get("violations")
    If '$IsObject(tRows) || (tRows.%Size() = 0) Quit ""
    Quit tRows.%Get(0).%Get("field") _ ":" _ tRows.%Get(0).%Get("code")
}

}
