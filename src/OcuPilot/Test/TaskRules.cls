/// <p>Pins Story 9.7's rules (<class>OcuPilot.Area.Task.TaskRules</class>, AD-39): how each
/// <code>TimePeriod</code> reads <code>TimePeriodEvery</code> and <code>TimePeriodDay</code>, the
/// <code>DailyFrequency</code> quadruple, the dates and a past start, names and taken names, a task
/// type's settings through its own <code>IsValid</code>, the expiry facts the instance stores, the
/// output file's one-name rule (AD-21) and <code>RunAsUser</code> for a holder.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because its expiry legs create
/// probe tasks (<class>OcuPilot.Test.TaskProbe</class>), each removed by id after its exact name is
/// read back. <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.TaskRules Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter RULES = "OcuPilot.Area.Task.TaskRules";

Parameter PURGE = "%SYS.Task.PurgeTaskHistory";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskRules creates and deletes tasks in this instance's Task Manager and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ##class(OcuPilot.Test.TaskProbe).RemoveAll()
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.TaskProbe).RemoveAll()
}

/// <p>AC3: each period 0-5 reads <code>TimePeriodEvery</code> and <code>TimePeriodDay</code> as its
/// row says, accepting the row's bounds and refusing a value outside them on its field; Run After
/// and On Demand read neither.</p>
/// <p>Mutation (Rule 19): widen Weekly's <code>TimePeriodEvery</code> to 1-7 in
/// <method>OcuPilot.Area.Task.TaskRules.Validate</method> -- the Weekly 6 leg goes red.</p>
Method TestEachPeriodReadsEveryAndDayAsItsRowSays()
{
    Set tCases = $ListBuild($ListBuild("Daily", "7", "", ""), $ListBuild("Daily", "8", "", "TimePeriodEvery"), $ListBuild("Daily", "0", "", "TimePeriodEvery"))
    Set tCases = tCases _ $ListBuild($ListBuild("Weekly", "5", "24", ""), $ListBuild("Weekly", "6", "24", "TimePeriodEvery"), $ListBuild("Weekly", "1", "", "TimePeriodDay"), $ListBuild("Weekly", "1", "8", "TimePeriodDay"), $ListBuild("Weekly", "1", "22", "TimePeriodDay"))
    Set tCases = tCases _ $ListBuild($ListBuild("Monthly", "12", "31", ""), $ListBuild("Monthly", "13", "1", "TimePeriodEvery"), $ListBuild("Monthly", "1", "32", "TimePeriodDay"))
    Set tCases = tCases _ $ListBuild($ListBuild("Monthly Special", "12", "5^7", ""), $ListBuild("Monthly Special", "1", "6^1", "TimePeriodDay"), $ListBuild("Monthly Special", "1", "3", "TimePeriodDay"))
    Set tCases = tCases _ $ListBuild($ListBuild("On Demand", "99", "zz", ""))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tArgs = ..Valid()
        Do tArgs.%Set("TimePeriod", $List(tCase, 1), "string")
        Do tArgs.%Set("TimePeriodEvery", $List(tCase, 2), "string")
        Do tArgs.%Set("TimePeriodDay", $List(tCase, 3), "string")
        Set tFields = ..Fields(tArgs)
        Set tLabel = $List(tCase, 1) _ " every " _ $List(tCase, 2) _ " day " _ $List(tCase, 3)
        If $List(tCase, 4) = "" {
            Do $$$AssertEquals(tFields, "", tLabel _ " is accepted")
        } Else {
            Do $$$AssertEquals(tFields, $List(tCase, 4), tLabel _ " is refused on " _ $List(tCase, 4))
        }
    }
    Set tArgs = ..Valid()
    Do tArgs.%Set("TimePeriod", "Run After", "string")
    Do $$$AssertEquals(..Fields(tArgs), "RunAfterGUID", "Run After needs a task to run after")
    Do tArgs.%Set("RunAfterGUID", "not-a-guid", "string")
    Do $$$AssertEquals(..Fields(tArgs), "RunAfterGUID", "and one the instance holds")
    Set tSC = $ClassMethod(..#RULES, "RunAfter", .tRows)
    Do $$$AssertStatusOK(tSC, "the tasks to run after are read")
    Do $$$AssertTrue($$$ISOK(tSC) && (tRows.%Size() > 0), "and there is one to follow")
    If $$$ISOK(tSC) && (tRows.%Size() > 0) {
        Do tArgs.%Set("RunAfterGUID", tRows.%Get(0).%Get("guid"), "string")
        Do $$$AssertEquals(..Fields(tArgs), "", "an existing task's JobGUID is accepted")
    }
    Set tArgs = ..Valid()
    Do tArgs.%Set("TimePeriod", "Hourly", "string")
    Do $$$AssertEquals(..Fields(tArgs), "TimePeriod", "a period outside the six is refused")
}

/// <p>AC4: Several needs its unit and its increment, in range for the unit, and a last time later
/// than the first; Once reads only the start time, and the body sends no Several field.</p>
/// <p>Mutation (Rule 19): drop the <code>TASK.DAILYINCREMENT.REQUIRED</code> rule from
/// <method>OcuPilot.Area.Task.TaskRules.DailyViolations</method> -- the missing-increment leg goes
/// red.</p>
Method TestTheDailyQuadruple()
{
    Set tArgs = ..Valid()
    Do tArgs.%Set("DailyFrequency", "Several", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.DAILYFREQUENCYTIME.REQUIRED,TASK.DAILYINCREMENT.REQUIRED,TASK.DAILYENDTIME.SHAPE", "Several with none of its three is refused on each")
    Do tArgs.%Set("DailyFrequencyTime", "Minutes", "string")
    Do tArgs.%Set("DailyEndTime", "05:00", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.DAILYINCREMENT.REQUIRED", "Several without an increment is refused on it")
    Do tArgs.%Set("DailyIncrement", "1441", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.DAILYINCREMENT.RANGE", "1441 minutes is out of range")
    Do tArgs.%Set("DailyIncrement", "1440", "string")
    Do $$$AssertEquals(..Codes(tArgs), "", "1440 minutes is in range")
    Do tArgs.%Set("DailyFrequencyTime", "Hourly", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.DAILYINCREMENT.RANGE", "1440 hours is not")
    Do tArgs.%Set("DailyIncrement", "24", "string")
    Do tArgs.%Set("DailyStartTime", "06:00", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.DAILYENDTIME.ORDER", "a last time before the first is refused")

    Set tOnce = ..Valid()
    Do tOnce.%Set("DailyFrequencyTime", "Minutes", "string")
    Do tOnce.%Set("DailyIncrement", "0", "string")
    Do tOnce.%Set("DailyEndTime", "bad", "string")
    Do $$$AssertEquals(..Codes(tOnce), "", "Once does not read the three Several fields")
    Set tSC = $ClassMethod(..#RULES, "Compose", tOnce, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the Once body composes")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tPayload.%Get("DailyFrequencyTime") _ "|" _ tPayload.%Get("DailyIncrement") _ "|" _ tPayload.%Get("DailyEndTime"), "||", "and sends none of them")
    Do $$$AssertEquals(tPayload.%Get("DailyStartTime"), "02:30:00", "only its start time")
}

/// <p>The dates: a first run today at 00:00 is in the past on the instance's clock, tomorrow is
/// not, a malformed date is refused, and an end date must follow the start.</p>
Method TestDatesAndAPastStart()
{
    Set tArgs = ..Valid()
    Do tArgs.%Set("StartDate", $ZDate(+$Horolog, 3), "string")
    Do tArgs.%Set("DailyStartTime", "00:00", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.STARTDATE.PAST", "today at 00:00 is refused as past")
    Do tArgs.%Set("StartDate", $ZDate(+$Horolog + 1, 3), "string")
    Do $$$AssertEquals(..Codes(tArgs), "", "tomorrow at 00:00 is not")
    Do tArgs.%Set("StartDate", "2026-02-30", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.STARTDATE.SHAPE", "an impossible date is refused")
    Do tArgs.%Set("StartDate", $ZDate(+$Horolog + 2, 3), "string")
    Do tArgs.%Set("EndDate", $ZDate(+$Horolog + 1, 3), "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.ENDDATE.ORDER", "an end before the start is refused")
    Do tArgs.%Set("EndDate", $ZDate(+$Horolog + 3, 3), "string")
    Do $$$AssertEquals(..Codes(tArgs), "", "and one after it accepted")
}

/// <p>Names: required, at most 50 characters with a letter first, and not any task's name,
/// compared without regard to case.</p>
Method TestNamesAndTakenNames()
{
    For tCase = $ListBuild("", "TASK.NAME.REQUIRED"), $ListBuild("9Lives", "TASK.NAME.SHAPE"), $ListBuild("OcuP97" _ $Translate($Justify("", 45), " ", "x"), "TASK.NAME.SHAPE"), $ListBuild("OcuP97Fresh", "") {
        Set tArgs = ..Valid()
        Do tArgs.%Set("Name", $List(tCase, 1), "string")
        Do $$$AssertEquals(..Codes(tArgs), $List(tCase, 2), "'" _ $List(tCase, 1) _ "'")
    }
    Set tVendor = ##class(OcuPilot.Test.TaskProbe).VendorName()
    Do $$$AssertNotEquals(tVendor, "", "the instance holds a task to collide with")
    Set tArgs = ..Valid()
    Do tArgs.%Set("Name", $ZConvert(tVendor, "L"), "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.NAME.TAKEN", "another task's name in another case is taken")
    Do tArgs.%Set("Description", $Translate($Justify("", 101), " ", "d"), "string")
    Do tArgs.%Set("Name", "OcuP97Fresh", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.DESCRIPTION.LENGTH", "a description over 100 characters is refused, not truncated")
}

/// <p>A task type's settings: each checked by the type's own <code>IsValid</code> in its
/// namespace, a key the type does not declare refused, and a type the namespace does not compile
/// refused on <code>TaskClass</code>.</p>
Method TestSettingsThroughTheTypesOwnIsValid()
{
    Set tArgs = ..Valid()
    Do tArgs.%Set("Settings", {"KeepDays": "0"})
    Do $$$AssertEquals(..Pairs(tArgs), "Settings.KeepDays:TASK.SETTING.INVALID", "KeepDays 0 is under the type's own MINVAL")
    Do tArgs.%Set("Settings", {"KeepDays": "30", "Nope": "1"})
    Do $$$AssertEquals(..Pairs(tArgs), "Settings.Nope:TASK.SETTING.UNKNOWN", "a setting the type does not declare is refused")
    Do tArgs.%Set("Settings", {"KeepDays": 30})
    Do $$$AssertEquals(..Pairs(tArgs), "", "a number is read as its spelling")
    Do tArgs.%Set("TaskClass", "OcuPilot.Area.Task.TaskRules", "string")
    Do $$$AssertEquals(..Pairs(tArgs), "TaskClass:TASK.TASKCLASS.UNKNOWN", "a class that is no task type is refused")
    Do tArgs.%Set("TaskClass", "", "string")
    Do $$$AssertEquals(..Pairs(tArgs), "TaskClass:TASK.TASKCLASS.REQUIRED", "and no type at all")
    Set tArgs = ..Valid()
    Do tArgs.%Set("NameSpace", "NOSUCHNAMESPACE", "string")
    Do $$$AssertEquals(..Pairs(tArgs), "NameSpace:TASK.NAMESPACE.UNKNOWN", "a namespace the caller cannot read is refused")
}

/// <p>AC5: what the instance stores. An On Demand task stores <code>Expires</code> 0, and the body
/// says so; a Daily task keeps <code>Expires</code> and its offsets; a non-number offset is refused
/// before any call.</p>
/// <p>Mutation (Rule 19): drop the On Demand <code>Expires</code> alignment from
/// <method>OcuPilot.Area.Task.TaskRules.Compose</method> -- the composed-body leg goes red.</p>
Method TestTheExpiryFactsTheInstanceStores()
{
    Set tArgs = ..Valid()
    Do tArgs.%Set("ExpiresDays", "abc", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.EXPIRESDAYS.RANGE", "a non-number is refused before the call")
    Do tArgs.%Set("ExpiresDays", "1000", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.EXPIRESDAYS.RANGE", "and 1000 days, which the vendor's utility bounds at 999")

    Set tDemand = ..Valid()
    Do tDemand.%Set("Name", "OcuP97Demand", "string")
    Do tDemand.%Set("TimePeriod", "On Demand", "string")
    Do tDemand.%Set("Expires", 1, "boolean")
    Do tDemand.%Set("ExpiresMinutes", "30", "string")
    Set tSC = $ClassMethod(..#RULES, "Compose", tDemand, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the On Demand body composes")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tPayload.%Get("Expires") _ "|" _ tPayload.%Get("ExpiresMinutes"), "0|", "an On Demand body sends no expiry")
    Set tId = ..Created(tDemand)
    Do $$$AssertNotEquals(tId, "", "the On Demand task is created")
    Set tStored = ##class(OcuPilot.Test.TaskProbe).Stored(tId)
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Expires"), "0", "and the instance stores Expires 0")
    Do ##class(OcuPilot.Test.TaskProbe).Remove(tId)

    Set tDaily = ..Valid()
    Do tDaily.%Set("Name", "OcuP97Daily", "string")
    Do tDaily.%Set("Expires", 1, "boolean")
    Do tDaily.%Set("ExpiresMinutes", "30", "string")
    Set tId = ..Created(tDaily)
    Do $$$AssertNotEquals(tId, "", "the Daily task is created")
    Set tStored = ##class(OcuPilot.Test.TaskProbe).Stored(tId)
    If $IsObject(tStored) Do $$$AssertEquals(tStored.%Get("Expires") _ "|" _ tStored.%Get("ExpiresMinutes"), "1|30", "a Daily task keeps Expires and its offset")
    Do ##class(OcuPilot.Test.TaskProbe).Remove(tId)
}

/// <p>AD-21's third exception: the output file is one name ending in <code>.txt</code>, never a
/// path, and a literal <code>..</code> is refused.</p>
/// <p>Mutation (Rule 19): drop the <parameter>OcuPilot.Area.Task.TaskRules.OUTPUTFILEPATTERN</parameter>
/// match from <method>OcuPilot.Area.Task.TaskRules.Validate</method> -- the path legs go red.</p>
Method TestTheOutputFileIsOneNameNeverAPath()
{
    For tCase = $ListBuild("run.txt", ""), $ListBuild("Run_01-a.txt", ""), $ListBuild("../run.txt", "TASK.OUTPUTFILENAME.SHAPE"), $ListBuild("/tmp/run.txt", "TASK.OUTPUTFILENAME.SHAPE"), $ListBuild("sub/run.txt", "TASK.OUTPUTFILENAME.SHAPE"), $ListBuild("run..txt", "TASK.OUTPUTFILENAME.SHAPE"), $ListBuild("run.log", "TASK.OUTPUTFILENAME.SHAPE"), $ListBuild(".run.txt", "TASK.OUTPUTFILENAME.SHAPE"), $ListBuild("C:\run.txt", "TASK.OUTPUTFILENAME.SHAPE") {
        Set tArgs = ..Valid()
        Do tArgs.%Set("OutputFilename", $List(tCase, 1), "string")
        Do $$$AssertEquals(..Codes(tArgs), $List(tCase, 2), "'" _ $List(tCase, 1) _ "'")
    }
    Set tArgs = ..Valid()
    Do tArgs.%Set("OutputFilename", "run.txt", "string")
    Set tSC = $ClassMethod(..#RULES, "Compose", tArgs, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tPayload.%GetTypeOf("OutputDirectory"), "unassigned", "the composed body carries no directory")
    Do ##class(OcuPilot.Screen.Tool.TaskCreate).DerivedFields(tPayload)
    Do $$$AssertEquals(tPayload.%Get("OutputDirectory"), $System.Util.ManagerDirectory(), "the tool writes it to the manager directory at the write")
}

/// <p>The options: a known priority and mirror status, flags that are flags, addresses that are
/// addresses, and <code>RunAsUser</code> -- blank or the caller's own passes, and for a holder of
/// <code>%Admin_Secure:USE</code> another name must be an existing account.</p>
Method TestTheOptionsAndNotifications()
{
    For tCase = $ListBuild("Priority", "Urgent", "TASK.PRIORITY.VALUE"), $ListBuild("MirrorStatus", "Backup", "TASK.MIRRORSTATUS.VALUE"), $ListBuild("SuspendOnError", "maybe", "TASK.FIELD.SHAPE"), $ListBuild("EmailOnError", "ops@example.com, not-an-address", "TASK.EMAILONERROR.SHAPE"), $ListBuild("EmailOnError", "ops@example.com, dev@example.com", ""), $ListBuild("RunAsUser", "OcuP97NoSuchAccount", "TASK.RUNASUSER.UNKNOWN"), $ListBuild("RunAsUser", $ZConvert($Username, "L"), "") {
        Set tArgs = ..Valid()
        Do tArgs.%Set($List(tCase, 1), $List(tCase, 2), "string")
        Do $$$AssertEquals(..Codes(tArgs), $List(tCase, 3), $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "'")
    }
    ; IAM is one of the instance's own accounts, disabled as installed.
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tDisabled = ##class(Security.Users).Exists("IAM", .tAccount) && $IsObject($Get(tAccount)) && 'tAccount.Enabled
    Set tAccount = ""
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tDisabled, "the instance holds the disabled account IAM")
    Set tArgs = ..Valid()
    Do tArgs.%Set("RunAsUser", "IAM", "string")
    Do $$$AssertEquals(..Codes(tArgs), "TASK.RUNASUSER.DISABLED", "a disabled account is refused")
}

/// <p>A list setting is classic-only: <code>HS.Registry.Document.Archive.Task</code>'s
/// <code>SourceIDS</code>, a collection, is refused <code>TASK.SETTING.CLASSICONLY</code> on its
/// field.</p>
Method TestAListSettingIsClassicOnly()
{
    Set tArgs = ..Valid()
    Do tArgs.%Set("NameSpace", ##class(OcuPilot.Install.Installer).ResolveNamespace(), "string")
    Do tArgs.%Set("TaskClass", "HS.Registry.Document.Archive.Task", "string")
    Do tArgs.%Set("Settings", {"SourceIDS": "1"})
    Do $$$AssertTrue(("," _ ..Pairs(tArgs) _ ",") [ ",Settings.SourceIDS:TASK.SETTING.CLASSICONLY,", "a list setting is refused as classic-only: " _ ..Pairs(tArgs))
    Set tSC = $ClassMethod(..#RULES, "WithheldSettingsCode", {"TaskClass": "HS.Registry.Document.Archive.Task", "NameSpace": (##class(OcuPilot.Install.Installer).ResolveNamespace())}, .tCode)
    Do $$$AssertEquals(tCode, "TASK.SETTING.CLASSICONLY", "and a settings change on such a task, whose read carries none, is refused as classic-only")
}

/// <p>DW-1631, the New Task wizard's side of the one classifier: a setting typed
/// <code>%SYS.Task.Password</code> (Diagnostic Report's <code>SMTPPass</code>) is classic-only and
/// secret, so the form read never draws it, the create refuses it by name, and an edit's settings
/// change on such a task is refused <code>TASK.SETTING.SECRET</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>%SYS.Task.Password</code> arm of
/// <method>OcuPilot.Port.TaskPort.ClassicOnlyKind</method> -- <code>SMTPPass</code> is ordinary again
/// and this goes red.</p>
Method TestASecretTypedSettingIsClassicOnly()
{
    Set tSC = $ClassMethod(..#RULES, "TypeSettings", "%SYS.Task.DiagnosticReport", "%SYS", .tSettings, .tClassicOnly, .tKnown)
    Do $$$AssertStatusOK(tSC, "the type's settings are read")
    Do $$$AssertEquals($Get(tClassicOnly("SMTPPass")) _ " " _ $Data(tSettings("SMTPPass")), "secret 0", "SMTPPass is classic-only and secret, never an ordinary setting")
    Set tArgs = ..Valid()
    Do tArgs.%Set("TaskClass", "%SYS.Task.DiagnosticReport", "string")
    Do tArgs.%Set("Settings", {"SMTPPass": "x"})
    Do $$$AssertTrue(("," _ ..Pairs(tArgs) _ ",") [ ",Settings.SMTPPass:TASK.SETTING.SECRET,", "a create sending it is refused by name: " _ ..Pairs(tArgs))
    Set tSC = $ClassMethod(..#RULES, "WithheldSettingsCode", {"TaskClass": "%SYS.Task.DiagnosticReport", "NameSpace": "%SYS"}, .tCode)
    Do $$$AssertEquals(tCode, "TASK.SETTING.SECRET", "and an edit's settings change on such a task is refused as secret")
}

/// <p>Story 9.8, AD-35: a task whose type cannot be classified is read without its settings, and a
/// settings change on one is refused by name as secret rather than failing.</p>
/// <p>Mutation (Rule 19): drop <code>'$Get(tRead)</code> from
/// <method>OcuPilot.Port.TaskPort.WithholdSettings</method> -- the first leg goes red.</p>
Method TestAnUnclassifiableTypeIsWithheld()
{
    Set tTask = {"TaskClass": "OcuP98.No.Such.Type", "NameSpace": "HSCUSTOM", "Settings": {"SMTPPass": "x"}}
    Do ##class(OcuPilot.Port.TaskPort).WithholdSettings(tTask)
    Do $$$AssertEquals(tTask.%GetTypeOf("Settings"), "unassigned", "a type not compiled in the task's namespace is read without its settings")
    Set tKept = {"TaskClass": (..#PURGE), "NameSpace": "%SYS", "Settings": {"KeepDays": "30"}}
    Do ##class(OcuPilot.Port.TaskPort).WithholdSettings(tKept)
    Do $$$AssertEquals(tKept.%GetTypeOf("Settings"), "object", "a type read with no classic-only setting keeps them")
    Set tSC = $ClassMethod(..#RULES, "WithheldSettingsCode", {"TaskClass": "%SYS.Task.DiagnosticReport", "NameSpace": "OCUP98NOSUCHNAMESPACE"}, .tCode)
    Do $$$AssertStatusOK(tSC, "a type that cannot be classified is no error")
    Do $$$AssertEquals($Get(tCode), "TASK.SETTING.SECRET", "and a settings change on it is refused as secret")
}

/// <p>Story 9.8: an edit compares a field as the instance holds it -- an account name without
/// regard to case -- so re-sending the account a task runs as in another case changes nothing.</p>
Method TestAnEditComparesTheAccountWithoutCase()
{
    Set tChanged = $ClassMethod(..#RULES, "Changed", {"RunAsUser": "_system", "Description": "x"}, {"RunAsUser": "_SYSTEM", "Description": "y"})
    Do $$$AssertEquals(tChanged.%ToJSON(), "{""Description"":""x""}", "the account in another case is no change")
}

/// <p>A valid Daily create of <parameter>PURGE</parameter>, once at 02:30 from tomorrow.</p>
ClassMethod Valid() As %DynamicObject
{
    Quit {"Name": "OcuP97Rule", "TaskClass": (..#PURGE), "NameSpace": "%SYS", "Settings": {"KeepDays": "30"}, "TimePeriod": "Daily", "TimePeriodEvery": "1", "DailyFrequency": "Once", "DailyStartTime": "02:30", "StartDate": ($ZDate(+$Horolog + 1, 3))}
}

/// <p>The violations <var>pArgs</var> earns, as comma-separated codes.</p>
ClassMethod Codes(pArgs As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#RULES, "Validate", "create", pArgs, .tViolations)
    If $$$ISERR(tSC) Quit "error: " _ $System.Status.GetErrorText(tSC)
    Set tOut = ""
    For tI = 1:1:tViolations Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(tViolations(tI), 2)
    Quit tOut
}

/// <p>The fields <var>pArgs</var>' violations land on, comma-separated.</p>
ClassMethod Fields(pArgs As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#RULES, "Validate", "create", pArgs, .tViolations)
    If $$$ISERR(tSC) Quit "error: " _ $System.Status.GetErrorText(tSC)
    Set tOut = ""
    For tI = 1:1:tViolations Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(tViolations(tI), 1)
    Quit tOut
}

/// <p>The violations as <code>field:code</code>, comma-separated.</p>
ClassMethod Pairs(pArgs As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#RULES, "Validate", "create", pArgs, .tViolations)
    If $$$ISERR(tSC) Quit "error: " _ $System.Status.GetErrorText(tSC)
    Set tOut = ""
    For tI = 1:1:tViolations Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(tViolations(tI), 1) _ ":" _ $List(tViolations(tI), 2)
    Quit tOut
}

/// <p>Create <var>pArgs</var> through the screen's Save and answer the new id, or <code>""</code>.</p>
ClassMethod Created(pArgs As %DynamicObject) As %String
{
    Set tSC = ##class(OcuPilot.Area.Task.TaskSave).Create(pArgs, .tHttp, .tFault, .tViolations, .tId)
    If $$$ISERR(tSC) || ($Get(tViolations) > 0) Quit ""
    Quit tId
}

}
