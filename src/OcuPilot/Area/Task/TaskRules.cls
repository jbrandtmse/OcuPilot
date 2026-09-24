/// <p>The New Task wizard's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.TaskCreate</class> applies (<method>Validate</method>), the complete
/// body both callers send (<method>Compose</method>), the form's read (<method>HandleForm</method>)
/// and the step check (<method>HandleCheck</method>).</p>
/// <p><b>The field model is <code>%SYS.TaskSuper</code>'s</b> (AD-3): <code>TimePeriod</code> fixes
/// how <code>TimePeriodEvery</code> and <code>TimePeriodDay</code> are read, and
/// <code>DailyFrequency</code> governs the quadruple <code>DailyFrequencyTime</code>,
/// <code>DailyIncrement</code>, <code>DailyStartTime</code> and <code>DailyEndTime</code>, with the
/// ranges the vendor's own task utility applies. A field the chosen period does not read is
/// ignored and sent as the vendor's initial value (<method>Applied</method>).</p>
/// <p><b>A task type's settings are that type's own values</b> (AD-21 as amended): each is checked by
/// the type's own <code>&lt;setting&gt;IsValid</code>, in the task's namespace, as the vendor's task
/// utility does. A credential-named setting and a collection setting are classic-only.</p>
/// <p><b>The output file is one name, never a path</b> (AD-21): it matches
/// <parameter>OUTPUTFILEPATTERN</parameter>, a literal <code>..</code> is refused, and the tool
/// writes it to the manager directory computed at call time.</p>
Class OcuPilot.Area.Task.TaskRules Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.TaskCreate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskForm";

/// <p>The fields the form marks required.</p>
Parameter REQUIREDFIELDS = "Name,NameSpace,TaskClass,TimePeriod";

Parameter NAMEMAXLENGTH As INTEGER = 50;

Parameter DESCRIPTIONMAXLENGTH As INTEGER = 100;

Parameter OUTPUTFILEMAXLENGTH As INTEGER = 104;

/// <p>The one output file name a caller may give (AD-21's third exception).</p>
Parameter OUTPUTFILEPATTERN = "^[A-Za-z0-9][A-Za-z0-9._-]{0,99}\.txt$";

/// <p>One email address.</p>
Parameter EMAILPATTERN = "^[^@\s,]+@[^@\s,]+$";

/// <p><code>TimePeriod</code>'s display values, logical 0 to 5 in order.</p>
Parameter PERIODS = "Daily,Weekly,Monthly,Monthly Special,Run After,On Demand";

Parameter FREQUENCIES = "Once,Several";

Parameter FREQUENCYTIMES = "Minutes,Hourly";

Parameter PRIORITIES = "Normal,Low,High";

Parameter MIRRORSTATUSES = "Primary,Non-Primary,Any";

/// <p>The boolean fields.</p>
Parameter FLAGS = "EmailOutput,Expires,OpenOutputFile,OutputFileIsBinary,SuspendOnError,SuspendTerminated,IsBatch,RescheduleOnStart";

/// <p>The address-list fields.</p>
Parameter EMAILFIELDS = "EmailOnCompletion,EmailOnError,EmailOnExpiration";

/// <p>The fields read only for periods 0 to 3 (Daily to Monthly Special).</p>
Parameter SCHEDULEDFIELDS = "DailyFrequency,DailyFrequencyTime,DailyIncrement,DailyStartTime,DailyEndTime,StartDate,EndDate,Expires,ExpiresDays,ExpiresHours,ExpiresMinutes";

/// <p>The fields read only when <code>DailyFrequency</code> is Several.</p>
Parameter SEVERALFIELDS = "DailyFrequencyTime,DailyIncrement,DailyEndTime";

/// <p>The fields a create sets, in the wizard's order (<method>OcuPilot.Kernel.Proposal.Prohibited.TaskCreateFields</method>
/// names the same thirty-four).</p>
Parameter FIELDS = "Name,Description,NameSpace,TaskClass,Settings,TimePeriod,TimePeriodEvery,TimePeriodDay,RunAfterGUID,DailyFrequency,DailyFrequencyTime,DailyIncrement,DailyStartTime,DailyEndTime,StartDate,EndDate,Expires,ExpiresDays,ExpiresHours,ExpiresMinutes,RunAsUser,Priority,IsBatch,MirrorStatus,OpenOutputFile,OutputFilename,OutputFileIsBinary,EmailOutput,SuspendOnError,SuspendTerminated,RescheduleOnStart,EmailOnCompletion,EmailOnError,EmailOnExpiration";

/// <p>The class every task type extends.</p>
Parameter TASKCLASSBASE = "%SYS.Task.Definition";

/// <p>The resource running a task as another account needs (<code>%SYS.TaskSuper</code>'s own
/// documentation of <code>RunAsUser</code>, enforced by the instance: measured).</p>
Parameter SECURERESOURCE = "%Admin_Secure";

/// <p>The settings field and the prefix a setting's violation lands under.</p>
Parameter SETTINGS = "Settings";

/// <p>Every rule over <var>pArgs</var> for <var>pMode</var> (<code>create</code>), each broken rule
/// in <var>pViolations</var> (<code>pViolations(n) = $ListBuild(field, code)</code>, count in
/// <code>pViolations</code>). A field the chosen period does not read is not judged.
/// <var>pCheckTaken</var> 0 skips the name look-up, for a caller that has just made it.</p>
ClassMethod Validate(pMode As %String, pArgs As %DynamicObject, Output pViolations, pCheckTaken As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") {
            Do ..Add(.pViolations, "Name", ##class(OcuPilot.Api.Error).#TASKNAMEREQUIRED)
            Quit
        }
        Set tArgs = ..Applied(pArgs)
        Set tDefaults = ..Defaults()

        ; Name.
        Set tName = ..Text(tArgs, "Name", .tNameOk)
        If 'tNameOk || (tName = "") {
            Do ..Add(.pViolations, "Name", ##class(OcuPilot.Api.Error).#TASKNAMEREQUIRED)
        } ElseIf ($Length(tName) > ..#NAMEMAXLENGTH) || '$Match(tName, "^[A-Za-z].*") {
            Do ..Add(.pViolations, "Name", ##class(OcuPilot.Api.Error).#TASKNAMESHAPE)
        } ElseIf (pMode = "create") && pCheckTaken {
            Set tSC = ..NameTaken(tName, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, "Name", ##class(OcuPilot.Api.Error).#TASKNAMETAKEN)
        }

        Set tDescription = ..Text(tArgs, "Description", .tOk)
        If 'tOk Do ..Add(.pViolations, "Description", ##class(OcuPilot.Api.Error).#TASKFIELDSHAPE)
        If tOk && ($Length(tDescription) > ..#DESCRIPTIONMAXLENGTH) Do ..Add(.pViolations, "Description", ##class(OcuPilot.Api.Error).#TASKDESCRIPTIONLENGTH)

        ; NameSpace and the task type, which is read in it.
        Set tNamespace = ..Effective(tArgs, tDefaults, "NameSpace")
        Set tNamespaceOk = ..IsReadable(tNamespace)
        If 'tNamespaceOk Do ..Add(.pViolations, "NameSpace", ##class(OcuPilot.Api.Error).#TASKNAMESPACEUNKNOWN)
        Set tClass = ..Text(tArgs, "TaskClass", .tOk)
        Set tTypeOk = 0
        If 'tOk || (tClass = "") {
            Do ..Add(.pViolations, "TaskClass", ##class(OcuPilot.Api.Error).#TASKTASKCLASSREQUIRED)
        } ElseIf tNamespaceOk {
            Set tSC = ..TypeSettings(tClass, tNamespace, .tSettings, .tClassicOnly, .tKnown)
            If $$$ISERR(tSC) Quit
            If 'tKnown {
                Do ..Add(.pViolations, "TaskClass", ##class(OcuPilot.Api.Error).#TASKTASKCLASSUNKNOWN)
            } ElseIf '..Permitted(tClass, tNamespace) {
                Do ..Add(.pViolations, "TaskClass", ##class(OcuPilot.Api.Error).#TASKTASKCLASSPERMISSION)
            } Else {
                Set tTypeOk = 1
            }
        }
        If tArgs.%GetTypeOf(..#SETTINGS) '= "unassigned" {
            If tArgs.%GetTypeOf(..#SETTINGS) '= "object" {
                Do ..Add(.pViolations, ..#SETTINGS, ##class(OcuPilot.Api.Error).#TASKFIELDSHAPE)
            } ElseIf tTypeOk {
                Set tSC = ..SettingViolations(tClass, tNamespace, tArgs.%Get(..#SETTINGS), .tSettings, .tClassicOnly, .pViolations)
                If $$$ISERR(tSC) Quit
            }
        } ElseIf tTypeOk {
            Set tSC = ..SettingViolations(tClass, tNamespace, {}, .tSettings, .tClassicOnly, .pViolations)
            If $$$ISERR(tSC) Quit
        }

        ; The schedule.
        Set tPeriod = ..Effective(tArgs, tDefaults, "TimePeriod")
        Set tPeriodIndex = ..PeriodIndex(tPeriod)
        If tPeriodIndex < 0 Do ..Add(.pViolations, "TimePeriod", ##class(OcuPilot.Api.Error).#TASKTIMEPERIODVALUE)
        If (tPeriodIndex >= 0) && (tPeriodIndex <= 3) {
            Set tEvery = ..Effective(tArgs, tDefaults, "TimePeriodEvery")
            Set tMax = $Case(tPeriodIndex, 0: 7, 1: 5, : 12)
            If '..InRange(tEvery, 1, tMax) Do ..Add(.pViolations, "TimePeriodEvery", ##class(OcuPilot.Api.Error).#TASKTIMEPERIODEVERYRANGE)
            Set tDay = ..Effective(tArgs, tDefaults, "TimePeriodDay")
            Set tDayOk = 1
            If tPeriodIndex = 1 Set tDayOk = ..IsWeekdaySet(tDay)
            If tPeriodIndex = 2 Set tDayOk = ..InRange(tDay, 1, 31)
            If tPeriodIndex = 3 Set tDayOk = $Match(tDay, "^[1-5]\^[1-7]$")
            If 'tDayOk Do ..Add(.pViolations, "TimePeriodDay", ##class(OcuPilot.Api.Error).#TASKTIMEPERIODDAYVALUE)
            Do ..DailyViolations(tArgs, tDefaults, .pViolations)
        }
        If tPeriodIndex = 4 {
            Set tGuid = ..Text(tArgs, "RunAfterGUID", .tOk)
            Set tKnownGuid = 0
            If tOk && (tGuid '= "") {
                Set tSC = ..RunAfter(.tRows)
                If $$$ISERR(tSC) Quit
                Set tIterator = tRows.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tRow) {
                    If tRow.%Get("guid") = tGuid Set tKnownGuid = 1
                }
            }
            If 'tKnownGuid Do ..Add(.pViolations, "RunAfterGUID", ##class(OcuPilot.Api.Error).#TASKRUNAFTERGUIDUNKNOWN)
        }

        ; Options and notifications.
        Do ..RunAsViolations(tArgs, .pViolations)
        If '$ListFind($ListFromString(..#PRIORITIES), ..Effective(tArgs, tDefaults, "Priority")) Do ..Add(.pViolations, "Priority", ##class(OcuPilot.Api.Error).#TASKPRIORITYVALUE)
        If '$ListFind($ListFromString(..#MIRRORSTATUSES), ..Effective(tArgs, tDefaults, "MirrorStatus")) Do ..Add(.pViolations, "MirrorStatus", ##class(OcuPilot.Api.Error).#TASKMIRRORSTATUSVALUE)
        For tI = 1:1:$Length(..#FLAGS, ",") {
            Set tFlag = $Piece(..#FLAGS, ",", tI)
            If tArgs.%GetTypeOf(tFlag) = "unassigned" Continue
            If ..Flag(tArgs, tFlag) = "" Do ..Add(.pViolations, tFlag, ##class(OcuPilot.Api.Error).#TASKFIELDSHAPE)
        }
        Set tFile = ..Text(tArgs, "OutputFilename", .tOk)
        If 'tOk || ((tFile '= "") && ('$Match(tFile, ..#OUTPUTFILEPATTERN) || (tFile [ ".."))) {
            Do ..Add(.pViolations, "OutputFilename", ##class(OcuPilot.Api.Error).#TASKOUTPUTFILENAMESHAPE)
        }
        For tI = 1:1:$Length(..#EMAILFIELDS, ",") {
            Set tField = $Piece(..#EMAILFIELDS, ",", tI)
            If tArgs.%GetTypeOf(tField) = "unassigned" Continue
            Set tList = ..Addresses(tArgs, tField, .tOk)
            If 'tOk Do ..Add(.pViolations, tField, $Parameter("OcuPilot.Api.Error", "TASK" _ $ZConvert(tField, "U") _ "SHAPE"))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The frequency, date and expiry rules for a period of 0 to 3.</p>
ClassMethod DailyViolations(pArgs As %DynamicObject, pDefaults As %DynamicObject, ByRef pViolations) [ Private ]
{
    Set tFrequency = ..Effective(pArgs, pDefaults, "DailyFrequency")
    Set tFrequencyIndex = $ListFind($ListFromString(..#FREQUENCIES), tFrequency)
    If 'tFrequencyIndex Do ..Add(.pViolations, "DailyFrequency", ##class(OcuPilot.Api.Error).#TASKDAILYFREQUENCYVALUE)
    Set tStart = ..Seconds(..Effective(pArgs, pDefaults, "DailyStartTime"))
    If tStart = "" Do ..Add(.pViolations, "DailyStartTime", ##class(OcuPilot.Api.Error).#TASKDAILYSTARTTIMESHAPE)
    If tFrequencyIndex = 2 {
        Set tUnit = ..Text(pArgs, "DailyFrequencyTime", .tOk)
        Set tUnitIndex = $ListFind($ListFromString(..#FREQUENCYTIMES), tUnit)
        If 'tOk || 'tUnitIndex Do ..Add(.pViolations, "DailyFrequencyTime", ##class(OcuPilot.Api.Error).#TASKDAILYFREQUENCYTIMEREQUIRED)
        Set tIncrement = ..Text(pArgs, "DailyIncrement", .tOk)
        If 'tOk || (tIncrement = "") {
            Do ..Add(.pViolations, "DailyIncrement", ##class(OcuPilot.Api.Error).#TASKDAILYINCREMENTREQUIRED)
        } ElseIf '..InRange(tIncrement, 1, $Select(tUnitIndex = 2: 24, 1: 1440)) {
            Do ..Add(.pViolations, "DailyIncrement", ##class(OcuPilot.Api.Error).#TASKDAILYINCREMENTRANGE)
        }
        Set tEnd = ..Seconds(..Text(pArgs, "DailyEndTime", .tOk))
        If tEnd = "" {
            Do ..Add(.pViolations, "DailyEndTime", ##class(OcuPilot.Api.Error).#TASKDAILYENDTIMESHAPE)
        } ElseIf (tStart '= "") && (tEnd <= tStart) {
            Do ..Add(.pViolations, "DailyEndTime", ##class(OcuPilot.Api.Error).#TASKDAILYENDTIMEORDER)
        }
    }
    Set tStartDateText = ..Effective(pArgs, pDefaults, "StartDate")
    Set tStartDate = ..Day(tStartDateText)
    If tStartDateText = "" {
        Do ..Add(.pViolations, "StartDate", ##class(OcuPilot.Api.Error).#TASKSTARTDATEREQUIRED)
    } ElseIf tStartDate = "" {
        Do ..Add(.pViolations, "StartDate", ##class(OcuPilot.Api.Error).#TASKSTARTDATESHAPE)
    } ElseIf (tStartDate < +$Horolog) || ((tStartDate = +$Horolog) && (tStart '= "") && (tStart <= $Piece($Horolog, ",", 2))) {
        Do ..Add(.pViolations, "StartDate", ##class(OcuPilot.Api.Error).#TASKSTARTDATEPAST)
    }
    Set tEndDateText = ..Text(pArgs, "EndDate", .tOk)
    If 'tOk || ((tEndDateText '= "") && (..Day(tEndDateText) = "")) {
        Do ..Add(.pViolations, "EndDate", ##class(OcuPilot.Api.Error).#TASKENDDATESHAPE)
    } ElseIf (tEndDateText '= "") && (tStartDate '= "") && (..Day(tEndDateText) <= tStartDate) {
        Do ..Add(.pViolations, "EndDate", ##class(OcuPilot.Api.Error).#TASKENDDATEORDER)
    }
    For tCase = $ListBuild("ExpiresDays", 999), $ListBuild("ExpiresHours", 24), $ListBuild("ExpiresMinutes", 60) {
        Set tField = $List(tCase, 1)
        Set tValue = ..Text(pArgs, tField, .tOk)
        If 'tOk || ((tValue '= "") && '..InRange(tValue, 0, $List(tCase, 2))) Do ..Add(.pViolations, tField, $Parameter("OcuPilot.Api.Error", "TASK" _ $ZConvert(tField, "U") _ "RANGE"))
    }
}

/// <p>The <code>RunAsUser</code> rules: blank or the caller's own name passes; any other name needs
/// <parameter>SECURERESOURCE</parameter>:USE before it is read, and must name an existing, enabled
/// account.</p>
ClassMethod RunAsViolations(pArgs As %DynamicObject, ByRef pViolations) [ Private ]
{
    Set tUser = ..Text(pArgs, "RunAsUser", .tOk)
    If 'tOk {
        Do ..Add(.pViolations, "RunAsUser", ##class(OcuPilot.Api.Error).#TASKFIELDSHAPE)
        Quit
    }
    If (tUser = "") || ($ZConvert(tUser, "U") = $ZConvert($Username, "U")) Quit
    If '$System.Security.Check(..#SECURERESOURCE, "USE") {
        Do ..Add(.pViolations, "RunAsUser", ##class(OcuPilot.Api.Error).#TASKRUNASUSERSECURE)
        Quit
    }
    Set tExists = 0
    Set tEnabled = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(Security.Users).Exists(tUser, .tAccount)
        If tExists && $IsObject($Get(tAccount)) Set tEnabled = ''tAccount.Enabled
        Set tAccount = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    If 'tExists {
        Do ..Add(.pViolations, "RunAsUser", ##class(OcuPilot.Api.Error).#TASKRUNASUSERUNKNOWN)
    } ElseIf 'tEnabled {
        Do ..Add(.pViolations, "RunAsUser", ##class(OcuPilot.Api.Error).#TASKRUNASUSERDISABLED)
    }
}

/// <p>The rules over the settings <var>pSupplied</var> for task type <var>pClass</var> in
/// <var>pNamespace</var>: each key a setting the type declares and no classic-only one, each value
/// a scalar the type's own <code>&lt;setting&gt;IsValid</code> accepts, and each required setting
/// non-empty once the type's own default is taken for an omitted one. A refusal lands on
/// <code>Settings.&lt;key&gt;</code>.</p>
ClassMethod SettingViolations(pClass As %String, pNamespace As %String, pSupplied As %DynamicObject, ByRef pSettings, ByRef pClassicOnly, ByRef pViolations) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tIterator = pSupplied.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tField = ..#SETTINGS _ "." _ tKey
        If $Data(pClassicOnly(tKey)) {
            Do ..Add(.pViolations, tField, $Select(pClassicOnly(tKey) = "secret": ##class(OcuPilot.Api.Error).#TASKSETTINGSECRET, 1: ##class(OcuPilot.Api.Error).#TASKSETTINGCLASSICONLY))
            Continue
        }
        If '$Data(pSettings(tKey)) {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#TASKSETTINGUNKNOWN)
            Continue
        }
        Set tText = ..SettingText(pSupplied, tKey, .tOk)
        If 'tOk {
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#TASKSETTINGINVALID)
            Continue
        }
        If tText = "" Continue
        If '..SettingValid(pClass, pNamespace, tKey, tText) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#TASKSETTINGINVALID)
    }
    Set tKey = ""
    For {
        Set tKey = $Order(pSettings(tKey))
        If tKey = "" Quit
        If '$ListGet(pSettings(tKey), 2) Continue
        Set tText = $ListGet(pSettings(tKey), 3)
        If pSupplied.%GetTypeOf(tKey) '= "unassigned" Set tText = ..SettingText(pSupplied, tKey, .tOk)
        If tText = "" Do ..Add(.pViolations, ..#SETTINGS _ "." _ tKey, ##class(OcuPilot.Api.Error).#TASKSETTINGREQUIRED)
    }
    Quit tSC
}

/// <p>Whether task type <var>pClass</var>'s own <code>&lt;pSetting&gt;IsValid</code> accepts
/// <var>pValue</var>, asked in <var>pNamespace</var> on an instance of the type, as the vendor's
/// task utility asks it. A method that cannot be asked refuses.</p>
ClassMethod SettingValid(pClass As %String, pNamespace As %String, pSetting As %String, pValue As %String) As %Boolean
{
    Set tValid = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tObject = $ClassMethod(pClass, "%New")
        Set tStatus = $Method(tObject, pSetting _ "IsValid", pValue)
        Set tValid = $$$ISOK(tStatus)
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValid = 0
    }
    Quit tValid
}

/// <p>The complete body a create sends (AD-4's "complete set", as the vendor's <code>POST</code>
/// requires every key but <code>Settings</code>, measured 400 #40301): <method>Defaults</method>
/// with the period's own fixed values, then every field the caller supplied and the period reads
/// (<method>Applied</method>), typed as the vendor reads it. <var>pDiff</var> is one
/// <code>{field, before, after}</code> per supplied field, and one per supplied setting as
/// <code>Settings.&lt;key&gt;</code>, with <code>before</code> empty (AD-54); <var>pUnchanged</var>
/// is the payload properties no diff row names, a <code>Settings.&lt;key&gt;</code> row naming
/// <code>Settings</code>. <code>OutputDirectory</code> is not composed: the
/// tool derives it at the write (<method>OcuPilot.Screen.Tool.TaskCreate.DerivedFields</method>).</p>
ClassMethod Compose(pArgs As %DynamicObject, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tArgs = ..Applied(pArgs)
        Set tPayload = ..Defaults()
        Set tPeriodIndex = ..PeriodIndex(..Effective(tArgs, tPayload, "TimePeriod"))
        ; The period's own fixed values (TaskSuper doc; the vendor's task utility).
        If tPeriodIndex = 0 Do tPayload.%Set("TimePeriodDay", "", "string")
        If tPeriodIndex = 4 {
            Do tPayload.%Set("TimePeriodEvery", "", "string")
            Do tPayload.%Set("TimePeriodDay", "0", "string")
        }
        If tPeriodIndex = 5 {
            Do tPayload.%Set("TimePeriodEvery", "", "string")
            Do tPayload.%Set("TimePeriodDay", "", "string")
        }
        If tPeriodIndex >= 4 {
            ; Expiry applies to periods 0 to 3 only; the instance stores 0 for an On Demand task
            ; whatever is sent (measured), so the body says what will be stored.
            Do tPayload.%Set("Expires", 0, "boolean")
        }
        If ..Effective(tArgs, tPayload, "DailyFrequency") '= "Several" {
            For tField = "DailyFrequencyTime", "DailyIncrement", "DailyEndTime" {
                Do tPayload.%Set(tField, "", "string")
            }
        }
        Set tFields = $ListFromString(..#FIELDS)
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            If tArgs.%GetTypeOf(tField) = "unassigned" Continue
            If tField = ..#SETTINGS {
                Set tSettings = tArgs.%Get(tField)
                If '$IsObject(tSettings) || 'tSettings.%IsA("%Library.DynamicObject") {
                    Set pProblem = "'Settings' is an object of the task type's own settings"
                    Quit
                }
                Set tComposed = {}
                Set tIterator = tSettings.%GetIterator()
                While tIterator.%GetNext(.tKey, .tValue) {
                    Set tText = ..SettingText(tSettings, tKey, .tOk)
                    If 'tOk {
                        Set pProblem = "the setting '" _ tKey _ "' is a single value"
                        Quit
                    }
                    Do tComposed.%Set(tKey, tText, "string")
                    Do pDiff.%Push(..Row(..#SETTINGS _ "." _ tKey, tText))
                }
                If pProblem '= "" Quit
                Do tPayload.%Set(tField, tComposed)
                Continue
            }
            If $ListFind($ListFromString(..#FLAGS), tField) {
                Set tFlag = ..Flag(tArgs, tField)
                If tFlag = "" {
                    Set pProblem = "'" _ tField _ "' is either true or false"
                    Quit
                }
                Do tPayload.%Set(tField, tFlag, "boolean")
                Do pDiff.%Push(..Row(tField, $Select(tFlag: "true", 1: "false")))
                Continue
            }
            If $ListFind($ListFromString(..#EMAILFIELDS), tField) {
                Set tList = ..Addresses(tArgs, tField, .tOk)
                If 'tOk {
                    Set pProblem = "'" _ tField _ "' is a list of email addresses"
                    Quit
                }
                Do tPayload.%Set(tField, tList)
                Do pDiff.%Push(..Row(tField, ..Joined(tList)))
                Continue
            }
            Set tText = ..Text(tArgs, tField, .tOk)
            If 'tOk {
                Set pProblem = "'" _ tField _ "' is a single value"
                Quit
            }
            If (tField = "DailyStartTime") || (tField = "DailyEndTime") {
                Set tSeconds = ..Seconds(tText)
                If tSeconds '= "" Set tText = $ZTime(tSeconds, 1)
            }
            Do tPayload.%Set(tField, tText, "string")
            Do pDiff.%Push(..Row(tField, tText))
        }
        If pProblem '= "" {
            Set pDiff = []
            Quit
        }
        Kill tNamed
        Set tIterator = pDiff.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tNamed($Piece(tRow.%Get("field"), ".", 1)) = 1
        }
        Set tIterator = tPayload.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '$Data(tNamed(tKey)) Set pUnchanged = pUnchanged + 1
        }
        Set pPayload = tPayload
    } Catch ex {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>A copy of <var>pArgs</var> holding only the fields the chosen period and frequency read: the
/// frequency, date and expiry fields for periods 0 to 3 alone, <code>RunAfterGUID</code> for Run
/// After alone, <code>TimePeriodEvery</code> and <code>TimePeriodDay</code> for neither Run After nor
/// On Demand, and the three Several fields for Several alone.</p>
ClassMethod Applied(pArgs As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pArgs) Quit {}
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Set tPeriodIndex = ..PeriodIndex(..Effective(tArgs, ..Defaults(), "TimePeriod"))
    Kill tDrop
    If tPeriodIndex '= 4 Set tDrop("RunAfterGUID") = ""
    If (tPeriodIndex = 4) || (tPeriodIndex = 5) {
        Set tDrop("TimePeriodEvery") = ""
        Set tDrop("TimePeriodDay") = ""
        For tI = 1:1:$Length(..#SCHEDULEDFIELDS, ",") Set tDrop($Piece(..#SCHEDULEDFIELDS, ",", tI)) = ""
    }
    If tPeriodIndex = 0 Set tDrop("TimePeriodDay") = ""
    If (tArgs.%GetTypeOf("DailyFrequency") = "unassigned") || (..Text(tArgs, "DailyFrequency") '= "Several") {
        For tI = 1:1:$Length(..#SEVERALFIELDS, ",") Set tDrop($Piece(..#SEVERALFIELDS, ",", tI)) = ""
    }
    Set tKey = ""
    For {
        Set tKey = $Order(tDrop(tKey))
        If tKey = "" Quit
        If tArgs.%GetTypeOf(tKey) '= "unassigned" Do tArgs.%Remove(tKey)
    }
    Quit tArgs
}

/// <p>A new <code>%SYS.Task</code>'s own values, spelled as the vendor's <code>GET</code> spells
/// them, for the thirty-three keys a create composes beside <code>Settings</code>: the form's
/// starting values and every field a create does not set. <code>StartDate</code> is tomorrow, the
/// class's own initial value.</p>
ClassMethod Defaults() As %DynamicObject
{
    Set tDefaults = {}
    Set tTask = ##class(%SYS.Task).%New()
    Do tDefaults.%Set("Name", "", "string")
    Do tDefaults.%Set("Description", tTask.Description, "string")
    Do tDefaults.%Set("NameSpace", tTask.NameSpace, "string")
    Do tDefaults.%Set("TaskClass", "", "string")
    Do tDefaults.%Set("TimePeriod", ##class(%SYS.TaskSuper).TimePeriodLogicalToDisplay(tTask.TimePeriod), "string")
    Do tDefaults.%Set("TimePeriodEvery", tTask.TimePeriodEvery _ "", "string")
    Do tDefaults.%Set("TimePeriodDay", tTask.TimePeriodDay _ "", "string")
    Do tDefaults.%Set("RunAfterGUID", tTask.RunAfterGUID, "string")
    Do tDefaults.%Set("DailyFrequency", ##class(%SYS.TaskSuper).DailyFrequencyLogicalToDisplay(tTask.DailyFrequency), "string")
    Do tDefaults.%Set("DailyFrequencyTime", ##class(%SYS.TaskSuper).DailyFrequencyTimeLogicalToDisplay(tTask.DailyFrequencyTime), "string")
    Do tDefaults.%Set("DailyIncrement", tTask.DailyIncrement _ "", "string")
    Do tDefaults.%Set("DailyStartTime", ##class(%SYS.TaskSuper).DailyStartTimeLogicalToDisplay(tTask.DailyStartTime), "string")
    Do tDefaults.%Set("DailyEndTime", ##class(%SYS.TaskSuper).DailyEndTimeLogicalToDisplay(tTask.DailyEndTime), "string")
    Do tDefaults.%Set("StartDate", $Select(tTask.StartDate = "": "", 1: $ZDate(tTask.StartDate, 3)), "string")
    Do tDefaults.%Set("EndDate", $Select(tTask.EndDate = "": "", 1: $ZDate(tTask.EndDate, 3)), "string")
    Do tDefaults.%Set("ExpiresDays", tTask.ExpiresDays _ "", "string")
    Do tDefaults.%Set("ExpiresHours", tTask.ExpiresHours _ "", "string")
    Do tDefaults.%Set("ExpiresMinutes", tTask.ExpiresMinutes _ "", "string")
    Do tDefaults.%Set("RunAsUser", tTask.RunAsUser, "string")
    Do tDefaults.%Set("Priority", ##class(%SYS.TaskSuper).PriorityLogicalToDisplay(tTask.Priority), "string")
    Do tDefaults.%Set("MirrorStatus", ##class(%SYS.TaskSuper).MirrorStatusLogicalToDisplay(tTask.MirrorStatus), "string")
    Do tDefaults.%Set("OutputFilename", tTask.OutputFilename, "string")
    For tI = 1:1:$Length(..#FLAGS, ",") {
        Set tFlag = $Piece(..#FLAGS, ",", tI)
        Do tDefaults.%Set(tFlag, ''$Property(tTask, tFlag), "boolean")
    }
    For tI = 1:1:$Length(..#EMAILFIELDS, ",") {
        Set tField = $Piece(..#EMAILFIELDS, ",", tI)
        Set tList = []
        Set tHeld = $Property(tTask, tField)
        For tJ = 1:1:tHeld.Count() {
            Set tEntry = $ZStrip(tHeld.GetAt(tJ), "<>W")
            If tEntry '= "" Do tList.%Push(tEntry, "string")
        }
        Set tHeld = ""
        Do tDefaults.%Set(tField, tList)
    }
    Set tTask = ""
    Quit tDefaults
}

/// <p>The task types <var>pNamespace</var> compiles, as
/// <code>[{class, name, settings: [{name, label, kind, required, default, options?}], classicOnly: [name]}]</code>
/// in class order: every non-abstract subclass of <parameter>TASKCLASSBASE</parameter>. A setting's
/// <code>kind</code> is <code>boolean</code>, <code>number</code>, <code>select</code> (with
/// <code>options</code> <code>[{value, label}]</code>) or <code>string</code>. A collection or
/// credential-named setting is listed in <code>classicOnly</code> and not in
/// <code>settings</code>.</p>
/// <p><b>Caller contract:</b> <var>pNamespace</var> is one the caller can read
/// (<method>IsReadable</method>); the read switches to it by explicit save and restore (AD-16).</p>
ClassMethod Types(pNamespace As %String, Output pTypes As %DynamicArray) As %Status
{
    Set pTypes = []
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%ResultSet).%New("%Dictionary.ClassDefinitionQuery:SubclassOf")
        Set tSC = tRS.Execute(..#TASKCLASSBASE)
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tClasses = ""
        While tRS.Next() {
            Set tClasses = tClasses _ $ListBuild(tRS.GetData(1))
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
        For tI = 1:1:$ListLength(tClasses) {
            Set tClass = $List(tClasses, tI)
            Set tSC = ..TypeEntry(tClass, pNamespace, .tEntry)
            If $$$ISERR(tSC) Quit
            If $IsObject(tEntry) Do pTypes.%Push(tEntry)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One type's entry for <method>Types</method>, or <var>pEntry</var> <code>""</code> for a class
/// that is abstract, not compiled, or not a task type.</p>
ClassMethod TypeEntry(pClass As %String, pNamespace As %String, Output pEntry As %DynamicObject) As %Status
{
    Set pEntry = ""
    Set tSC = ..TypeSettings(pClass, pNamespace, .tSettings, .tClassicOnly, .tKnown, .tName, .tOrder)
    If $$$ISERR(tSC) || 'tKnown Quit tSC
    Set pEntry = {}
    Do pEntry.%Set("class", pClass, "string")
    Do pEntry.%Set("name", tName, "string")
    Set tList = []
    For tI = 1:1:$ListLength(tOrder) {
        Set tKey = $List(tOrder, tI)
        If '$Data(tSettings(tKey)) Continue
        Set tSetting = {}
        Do tSetting.%Set("name", tKey, "string")
        Do tSetting.%Set("label", $ListGet(tSettings(tKey), 4), "string")
        Do tSetting.%Set("kind", $ListGet(tSettings(tKey), 1), "string")
        Do tSetting.%Set("required", ''$ListGet(tSettings(tKey), 2), "boolean")
        Do tSetting.%Set("default", $ListGet(tSettings(tKey), 3), "string")
        Set tOptions = $ListGet(tSettings(tKey), 5)
        If tOptions '= "" {
            Set tOptionList = []
            For tJ = 1:1:$ListLength(tOptions) Do tOptionList.%Push({"value": ($List($List(tOptions, tJ), 1)), "label": ($List($List(tOptions, tJ), 2))})
            Do tSetting.%Set("options", tOptionList)
        }
        Do tList.%Push(tSetting)
    }
    Do pEntry.%Set("settings", tList)
    Set tClassic = []
    Set tKey = ""
    For {
        Set tKey = $Order(tClassicOnly(tKey))
        If tKey = "" Quit
        Do tClassic.%Push(tKey, "string")
    }
    Do pEntry.%Set("classicOnly", tClassic)
    Quit $$$OK
}

/// <p>Task type <var>pClass</var>'s settings in <var>pNamespace</var>:
/// <code>pSettings(name) = $ListBuild(kind, required, default, label, options)</code>, and
/// <code>pClassicOnly(name) = "secret"|"collection"</code>, with <var>pKnown</var> 0 when the class is
/// not a compiled, non-abstract task type there. A setting is every property that is neither private
/// nor <code>%</code>-named, which is what the vendor's <code>GetSettings</code> serializes.</p>
ClassMethod TypeSettings(pClass As %String, pNamespace As %String, Output pSettings, Output pClassicOnly, Output pKnown As %Boolean, Output pName As %String, Output pOrder As %List) As %Status
{
    Kill pSettings, pClassicOnly
    Set pKnown = 0
    Set pName = ""
    Set pOrder = ""
    Set tSC = $$$OK
    If '$Match(pClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(pClass, 0)
        If '$IsObject(tCompiled) || tCompiled.Abstract || '$ClassMethod(pClass, "%Extends", ..#TASKCLASSBASE) {
            Set tCompiled = ""
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tCompiled = ""
        Set pKnown = 1
        Set pName = $ClassMethod(pClass, "GetTaskName")
        Set tObject = ""
        Try {
            Set tObject = $ClassMethod(pClass, "%New")
        } Catch {
            Set tObject = ""
        }
        ; Object access rather than SQL: a least-privileged caller holds no SQL privilege on the
        ; class dictionary (measured, SQLCODE -99).
        Kill tRaw, tBySequence
        Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(pClass, 0)
        Set tProperties = tCompiled.Properties
        For tP = 1:1:tProperties.Count() {
            Set tProperty = tProperties.GetAt(tP)
            Set tName = tProperty.Name
            If tProperty.Private || ($Extract(tName) = "%") Continue
            Set tDefault = ""
            If $IsObject(tObject) {
                Try {
                    Set tDefault = $Property(tObject, tName)
                    If $IsObject(tDefault) Set tDefault = ""
                } Catch {
                    Set tDefault = ""
                }
            }
            Set tLabel = tName
            Try {
                Set tLocalized = $ClassMethod(pClass, "GetPropertyName", tName)
                If tLocalized '= "" Set tLabel = tLocalized
            } Catch {
            }
            Set tBySequence(+tProperty.SequenceNumber, tName) = $ListBuild(tName, tProperty.Type, ''tProperty.Required, tProperty.Collection, tProperty.Parameters.GetAt("VALUELIST"), tProperty.Parameters.GetAt("DISPLAYLIST"), tDefault, tLabel)
        }
        Set tProperties = ""
        Set tCompiled = ""
        Set tSequence = ""
        For {
            Set tSequence = $Order(tBySequence(tSequence))
            If tSequence = "" Quit
            Set tName = ""
            For {
                Set tName = $Order(tBySequence(tSequence, tName))
                If tName = "" Quit
                Set tRaw($Increment(tRaw)) = tBySequence(tSequence, tName)
            }
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
        ; Back in the caller's namespace, where OcuPilot's own classes are.
        For tI = 1:1:$Get(tRaw) {
            Set tName = $List(tRaw(tI), 1)
            Set pOrder = pOrder _ $ListBuild(tName)
            If $List(tRaw(tI), 4) '= "" {
                Set pClassicOnly(tName) = "collection"
                Continue
            }
            If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName) {
                Set pClassicOnly(tName) = "secret"
                Continue
            }
            Set tType = $List(tRaw(tI), 2)
            Set tKind = "string"
            If tType = "%Library.Boolean" Set tKind = "boolean"
            If $ListFind($ListBuild("%Library.Integer", "%Library.Numeric", "%Library.SmallInt", "%Library.TinyInt", "%Library.BigInt", "%Library.Float", "%Library.Decimal"), tType) Set tKind = "number"
            Set tOptions = ""
            Set tValues = $List(tRaw(tI), 5)
            Set tDisplays = $List(tRaw(tI), 6)
            If tValues '= "" {
                Set tKind = "select"
                Set tDelimiter = $Extract(tValues)
                For tJ = 2:1:$Length(tValues, tDelimiter) {
                    Set tValue = $Piece(tValues, tDelimiter, tJ)
                    Set tDisplay = tValue
                    If tDisplays '= "" Set tDisplay = $Piece(tDisplays, $Extract(tDisplays), tJ)
                    Set tOptions = tOptions _ $ListBuild($ListBuild(tValue, tDisplay))
                }
            }
            Set pSettings(tName) = $ListBuild(tKind, $List(tRaw(tI), 3), $List(tRaw(tI), 7), $List(tRaw(tI), 8), tOptions)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the caller holds the privilege task type <var>pClass</var> declares for creating one
/// (<code>%SYS.Task.Definition.CheckPermission</code>).</p>
ClassMethod Permitted(pClass As %String, pNamespace As %String) As %Boolean [ Private ]
{
    Set tAllowed = 0
    Try {
        Set tAllowed = ##class(%SYS.Task.Definition).CheckPermission(pClass, pNamespace, .tStatus)
    } Catch {
        Set tAllowed = 0
    }
    Quit tAllowed
}

/// <p>The tasks a new one may run after: <code>[{guid, id, name}]</code>, each an existing task
/// the caller's list read answers, with its <code>JobGUID</code> read from <code>%SYS.Task</code> in
/// <code>%SYS</code> (the administration API answers none).</p>
ClassMethod RunAfter(Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTool = ..#CREATETOOL
        Kill tQuery
        Set tSC = $ClassMethod($ClassMethod(tTool, "PortClass"), "Invoke", $ClassMethod(tTool, "Endpoint"), "LIST", .tQuery, "", .tList, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tList)) Quit
        Set $NAMESPACE = "%SYS"
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tId = tRow.%Get("Id")
            If tId = "" Continue
            Set tTask = ##class(%SYS.Task).%OpenId(tId, 0)
            If '$IsObject(tTask) Continue
            Set tGuid = tTask.JobGUID
            Set tTask = ""
            If tGuid = "" Continue
            Do pRows.%Push({"guid": (tGuid), "id": (+tId), "name": (tRow.%Get("Name"))})
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether a task named <var>pName</var> exists, compared without regard to case, through the
/// same read the create's absence check makes (AD-54): the tool's list read filtered to that
/// name.</p>
ClassMethod NameTaken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tTool = ..#CREATETOOL
    Kill tQuery
    Set tQuery($ClassMethod(tTool, "ReadIdParam")) = pName
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadTarget(tTool, $ClassMethod(tTool, "PortClass"), $ClassMethod(tTool, "Endpoint"), .tQuery, pName, .tFresh, .tHttp, .tFault)
    If $$$ISOK(tSC) {
        Set pTaken = 1
        Quit $$$OK
    }
    If +$Get(tHttp) = 404 Quit $$$OK
    Quit tSC
}

/// <p>Whether <var>pNamespace</var> is one the caller can read: the list the shell's
/// <code>/namespaces</code> answers.</p>
ClassMethod IsReadable(pNamespace As %String) As %Boolean
{
    If pNamespace = "" Quit 0
    Set tSC = ##class(OcuPilot.Kernel.Shell.Namespaces).Payload(.tPayload)
    If $$$ISERR(tSC) || '$IsObject($Get(tPayload)) Quit 0
    Set tFound = 0
    Set tIterator = tPayload.%Get("namespaces").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $ZConvert(tEntry.%Get("name"), "U") = $ZConvert(pNamespace, "U") Set tFound = 1
    }
    Quit tFound
}

/// <p>Answer <code>GET /tasks/form?namespace=</code>:
/// <code>{requiredFields, maxLengths, rules, defaults, namespace, types, runAfter}</code>. The
/// namespace is the query's, or the default's when it names none; one the caller cannot read is a
/// 422 on <code>NameSpace</code>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tDefaults = ..Defaults()
        Set tNamespace = $Get(%request.Data("namespace", 1))
        If tNamespace = "" Set tNamespace = tDefaults.%Get("NameSpace")
        If '..IsReadable(tNamespace) {
            Set tSC = ##class(OcuPilot.Area.Task.TaskSave).RenderOne("NameSpace", ##class(OcuPilot.Api.Error).#TASKNAMESPACEUNKNOWN)
            Quit
        }
        Set tTypesSC = ..Types(tNamespace, .tTypes)
        If $$$ISERR(tTypesSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTypesSC))
            Quit
        }
        Set tRunAfterSC = ..RunAfter(.tRunAfter)
        If $$$ISERR(tRunAfterSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tRunAfterSC))
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Set tLengths = {}
        Do tLengths.%Set("Name", ..#NAMEMAXLENGTH, "number")
        Do tLengths.%Set("Description", ..#DESCRIPTIONMAXLENGTH, "number")
        Do tLengths.%Set("OutputFilename", ..#OUTPUTFILEMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("defaults", tDefaults)
        Do tBody.%Set("namespace", tNamespace, "string")
        Do tBody.%Set("types", tTypes)
        Do tBody.%Set("runAfter", tRunAfter)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /tasks/check</code>: <code>{violations}</code> for the values the body holds
/// so far, at 200 whatever they are (AD-39). A body that is not an object is 400.</p>
ClassMethod HandleCheck() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = ""
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tValidSC = ..Validate("create", tBody, .tViolations)
        If $$$ISERR(tValidSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tValidSC))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations))
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>, one per
/// <code>TASK.&lt;FIELD&gt;.&lt;RULE&gt;</code> code that names one field.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).TaskViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tField = ..FieldOf(tCode)
        If tField = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field a <code>TASK.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses, or <code>""</code>
/// for a code that names no one field.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "SETTING" Quit ..#SETTINGS
    Set tFields = $ListFromString(..#FIELDS)
    Set tField = ""
    For tI = 1:1:$ListLength(tFields) {
        If $ZConvert($List(tFields, tI), "U") = tPart {
            Set tField = $List(tFields, tI)
            Quit
        }
    }
    Quit tField
}

/// <p>The violations as one sentence per broken rule, for the agent's refusal.</p>
ClassMethod Problem(ByRef pViolations) As %String
{
    Set tProblem = ""
    For tI = 1:1:$Get(pViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2))
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: " ") _ "'" _ $List(pViolations(tI), 1) _ "': " _ tReason
    }
    Quit tProblem
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: a string as itself, a number in its canonical
/// spelling, absent or null as <code>""</code>; <var>pOk</var> 0 for anything else.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String, Output pOk As %Boolean) As %String
{
    Set pOk = 1
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") Quit ""
    If tType = "string" Quit pObject.%Get(pField)
    If tType = "number" Quit "" _ pObject.%Get(pField)
    Set pOk = 0
    Quit ""
}

/// <p>A setting's value as the text the vendor stores: a string, a number's spelling, or a boolean
/// as <code>1</code> or <code>0</code>; <var>pOk</var> 0 for an object or array.</p>
ClassMethod SettingText(pObject As %DynamicObject, pKey As %String, Output pOk As %Boolean) As %String
{
    Set pOk = 1
    Set tType = pObject.%GetTypeOf(pKey)
    If tType = "boolean" Quit $Select(pObject.%Get(pKey): "1", 1: "0")
    Quit ..Text(pObject, pKey, .pOk)
}

/// <p><var>pField</var>'s value, the supplied one when it carries text and otherwise
/// <var>pDefaults</var>'.</p>
ClassMethod Effective(pArgs As %DynamicObject, pDefaults As %DynamicObject, pField As %String) As %String [ Private ]
{
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(pField) '= "unassigned") {
        Set tText = ..Text(pArgs, pField, .tOk)
        If 'tOk Quit $Char(0)
        Quit tText
    }
    Quit pDefaults.%Get(pField)
}

/// <p><var>pField</var> as a flag: <code>1</code>, <code>0</code>, or <code>""</code> when it is
/// neither a boolean nor one of <code>true</code>, <code>false</code>, <code>1</code> and
/// <code>0</code>.</p>
ClassMethod Flag(pArgs As %DynamicObject, pField As %String) As %String
{
    Set tType = pArgs.%GetTypeOf(pField)
    If tType = "boolean" Quit ''pArgs.%Get(pField)
    If (tType '= "string") && (tType '= "number") Quit ""
    Set tValue = pArgs.%Get(pField)
    If (tValue = "true") || (tValue = "1") Quit 1
    If (tValue = "false") || (tValue = "0") Quit 0
    Quit ""
}

/// <p><var>pField</var>'s addresses as an array of trimmed strings, from an array of strings or one
/// comma-separated string; <var>pOk</var> 0 when any entry is not an address
/// (<parameter>EMAILPATTERN</parameter>).</p>
ClassMethod Addresses(pArgs As %DynamicObject, pField As %String, Output pOk As %Boolean) As %DynamicArray
{
    Set pOk = 1
    Set tList = []
    Set tType = pArgs.%GetTypeOf(pField)
    Set tEntries = ""
    If tType = "array" {
        Set tIterator = pArgs.%Get(pField).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tValue, .tValueType) {
            If tValueType '= "string" Set pOk = 0 Quit
            Set tEntries = tEntries _ $ListBuild(tValue)
        }
    } ElseIf tType = "string" {
        Set tText = pArgs.%Get(pField)
        For tI = 1:1:$Length(tText, ",") Set tEntries = tEntries _ $ListBuild($Piece(tText, ",", tI))
    } ElseIf (tType '= "null") && (tType '= "unassigned") {
        Set pOk = 0
    }
    If 'pOk Quit tList
    For tI = 1:1:$ListLength(tEntries) {
        Set tEntry = $ZStrip($List(tEntries, tI), "<>W")
        If tEntry = "" Continue
        If '$Match(tEntry, ..#EMAILPATTERN) Set pOk = 0 Quit
        Do tList.%Push(tEntry, "string")
    }
    Quit tList
}

/// <p><var>pList</var> joined with a comma and a space, as the diff shows it.</p>
ClassMethod Joined(pList As %DynamicArray) As %String [ Private ]
{
    Set tText = ""
    Set tIterator = pList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tValue
    }
    Quit tText
}

/// <p>One diff row of a create.</p>
ClassMethod Row(pField As %String, pAfter As %String) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", pAfter, "string")
    Quit tRow
}

/// <p><var>pPeriod</var>'s logical value, 0 to 5, or -1 for none of the display values.</p>
ClassMethod PeriodIndex(pPeriod As %String) As %Integer
{
    Quit $ListFind($ListFromString(..#PERIODS), pPeriod) - 1
}

/// <p>Whether <var>pValue</var> is a whole number from <var>pMin</var> to <var>pMax</var>.</p>
ClassMethod InRange(pValue As %String, pMin As %Integer, pMax As %Integer) As %Boolean [ Private ]
{
    If '$Match(pValue, "^[0-9]{1,6}$") Quit 0
    Quit (+pValue >= pMin) && (+pValue <= pMax)
}

/// <p>Whether <var>pDays</var> is a set of week days, one digit each from 1 (Sunday) to 7, with at
/// least one and none twice.</p>
ClassMethod IsWeekdaySet(pDays As %String) As %Boolean [ Private ]
{
    If '$Match(pDays, "^[1-7]{1,7}$") Quit 0
    Set tOnce = 1
    For tI = 1:1:$Length(pDays) {
        If $Length(pDays, $Extract(pDays, tI)) > 2 Set tOnce = 0
    }
    Quit tOnce
}

/// <p><var>pTime</var> (<code>HH:MM</code> or <code>HH:MM:SS</code>) in seconds after midnight, or
/// <code>""</code> when it is neither.</p>
ClassMethod Seconds(pTime As %String) As %String
{
    If '$Match(pTime, "^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$") Quit ""
    Quit ($Piece(pTime, ":", 1) * 3600) + ($Piece(pTime, ":", 2) * 60) + $Piece(pTime, ":", 3)
}

/// <p><var>pDate</var> (<code>YYYY-MM-DD</code>) as a <code>$Horolog</code> day, or <code>""</code>
/// when it is not one.</p>
ClassMethod Day(pDate As %String) As %String
{
    If '$Match(pDate, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") Quit ""
    Set tDay = $ZDateH(pDate, 3, , , , , , , "")
    Quit tDay
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
