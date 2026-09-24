/// <p>The Task schedule's edit tool (AD-4, AD-6, AD-55, FR-53): propose changing one scheduled task.
/// Two callers reach it: Edit task's Save through <class>OcuPilot.Area.Task.TaskSave</class>, and the
/// agent's proposal and confirmation. It writes nothing by itself.</p>
/// <p><b>Its target is the task's numeric id</b> (<code>task:instance:&lt;id&gt;</code>, AD-13), as the
/// delete's is. It merges over a fresh read through <class>OcuPilot.Port.TaskPort</class>, whose
/// <code>PUT</code> omits what the vendor keeps (AD-4's named exception).</p>
/// <p><b>A task's type and namespace are fixed</b>: changing the type replaces every setting, so it
/// stays a delete and a create, and neither is settable here. A supplied <code>Settings</code> is
/// merged member by member over the task's own (<method>MergeUpdate</method>), each change a
/// <code>Settings.&lt;key&gt;</code> row; a task whose type holds a classic-only setting is read
/// without its settings, and a settings argument on it is refused by name (AD-4 as amended,
/// AD-35).</p>
/// <p><b>Running as another account is judged on a change</b>: an edit that keeps the account the task
/// runs as is ordinary, and one that moves it to an account neither stored nor the caller's needs
/// <code>%Admin_Secure:USE</code> and is minted destructive with
/// <parameter>CONSEQUENCERUNSASOTHER</parameter>.</p>
Class OcuPilot.Screen.Tool.TaskUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.schedule.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter DESCRIPTION = "Propose changing one scheduled task in this instance's Task Manager. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the task by the numeric id the task schedule reports for it, and give only the fields to change; every other field keeps what the task holds. A task's type (TaskClass) and namespace cannot be changed. The task type's own settings go in Settings, each as a string, and only the ones to change.";

/// <p>The single-object read the merge is made over.</p>
Parameter READTYPE = "GET";

/// <p>The vendor's edit: <code>Task.CRUD</code>'s <code>PUT</code>, which keeps a key the body
/// omits (measured).</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The port the read and the write go through (AD-52), which withholds a classic-only type's
/// settings and trims the edit's body.</p>
Parameter PORTCLASS = "OcuPilot.Port.TaskPort";

/// <p><code>%Admin_Task:USE</code>, one of the screen's own two pairs (AD-8). A principal holding it
/// and <code>%DB_IRISSYS:READ</code> alone edited a task (measured).</p>
Parameter WRITERESOURCE = "%Admin_Task";

Parameter WRITEPERMISSION = "USE";

/// <p>The fields an edit sets, comma-separated: a create's thirty-four less <code>TaskClass</code> and
/// <code>NameSpace</code> (<method>OcuPilot.Kernel.Proposal.Prohibited.TaskChangeFields</method> names
/// the same thirty-two). <code>OutputDirectory</code> is not among them (AD-21).</p>
Parameter PERMITTEDFIELDS = "Name,RunAsUser,EmailOnCompletion,EmailOnError,EmailOnExpiration,EmailOutput,Expires,ExpiresDays,ExpiresHours,ExpiresMinutes,OpenOutputFile,OutputFilename,OutputFileIsBinary,SuspendOnError,SuspendTerminated,Priority,IsBatch,TimePeriod,TimePeriodEvery,TimePeriodDay,DailyFrequency,DailyFrequencyTime,DailyIncrement,DailyStartTime,DailyEndTime,StartDate,EndDate,RunAfterGUID,MirrorStatus,RescheduleOnStart,Description,Settings";

/// <p>The object argument the tool adds back beside the derived literals: the task type's own
/// settings, classified <code>opaque</code>.</p>
Parameter SETTINGSFIELD = "Settings";

/// <p>The two times the vendor compares by value.</p>
Parameter TIMEFIELDS = "DailyStartTime,DailyEndTime";

/// <p>The consequence a proposal carries when the edit moves the task to run as another account.</p>
Parameter CONSEQUENCERUNSASOTHER = "TASK.RUNSASOTHER";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Task.TaskRules";

ClassMethod Endpoint() As %String
{
    Quit "Task.CRUD"
}

/// <p>The vendor's numeric task id, which the list's rows carry as <code>Id</code>.</p>
ClassMethod IdArgument() As %String
{
    Quit "Id"
}

/// <p>The query parameter <code>Task.CRUD</code> identifies a task by, for the read and the
/// edit.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>The derived <code>ordinary</code> fields this tool admits, and <code>Settings</code>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#SETTINGSFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// change is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>None: a task carries no declared secret, and a type's secret setting is never read or
/// sent.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The derived schema, typed and described from <code>%SYS.TaskSuper</code>'s own documentation
/// (<method>OcuPilot.Screen.Tool.TaskCreate.Described</method>), with <code>Settings</code> added and
/// the task's id described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.TaskCreate).Described(##super(pDescriptor))
    If '$IsObject(tSchema) Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If '$IsObject(tProperties) Quit tSchema
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The task to change, named by the numeric id this instance's own task schedule reports for it. A task the schedule does not report is refused.", "string")
    }
    If tProperties.%GetTypeOf("Name") = "object" {
        Do tProperties.%Get("Name").%Set("description", "A new name for the task: at most 50 characters, the first a letter. A name another task on this instance already has, in any case, is refused.", "string")
    }
    Do tProperties.%Set(..#SETTINGSFIELD, {"type": "object", "description": "The task type's own settings to change, one member per setting name the type declares, each value a string; a setting you omit keeps its value. Each value is checked by the type itself. A task whose type holds a password or list setting has its settings changed only in the classic portal."})
    Quit tSchema
}

/// <p>The merge over the fresh read <var>pFresh</var> (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>),
/// with <code>Settings</code> merged member by member over the task's own and one
/// <code>Settings.&lt;key&gt;</code> row per setting that changes, and a time the task already holds,
/// in either spelling, left as it holds it.</p>
/// <p>A settings argument on a task whose read carries no settings -- its type holds a classic-only
/// setting -- and a setting the type does not declare are <var>pProblem</var>, in the rules' own
/// sentence, so a replacing <code>Settings</code> that would drop a secret is never composed (AD-4
/// as amended).</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        ; A time the task holds, sent in the other spelling, is not a change.
        For tI = 1:1:$Length(..#TIMEFIELDS, ",") {
            Set tField = $Piece(..#TIMEFIELDS, ",", tI)
            If (tArgs.%GetTypeOf(tField) '= "string") || (pFresh.%GetTypeOf(tField) '= "string") Continue
            Set tSent = $ClassMethod(..#RULES, "Seconds", tArgs.%Get(tField))
            If (tSent '= "") && (tSent = $ClassMethod(..#RULES, "Seconds", pFresh.%Get(tField))) Do tArgs.%Remove(tField)
        }
        Set tSettingsArg = ""
        If tArgs.%GetTypeOf(..#SETTINGSFIELD) '= "unassigned" {
            Set tSettingsArg = tArgs.%Get(..#SETTINGSFIELD)
            Do tArgs.%Remove(..#SETTINGSFIELD)
        }
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
        If $$$ISERR(tSC) || (pProblem '= "") Quit
        If tSettingsArg = "" Quit
        If '$ListFind(pSettable, ..#SETTINGSFIELD) Quit
        Set tSC = ..MergeSettings(pFresh, tSettingsArg, pPayload, pDiff, .tChanged, .pProblem)
        If $$$ISERR(tSC) || (pProblem '= "") Quit
        If tChanged Set pUnchanged = pUnchanged - 1
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>Merge the settings argument <var>pSupplied</var> member by member over <var>pFresh</var>'s
/// settings into <var>pPayload</var>, appending one row per changed setting to <var>pDiff</var>;
/// <var>pChanged</var> is whether any changed.</p>
ClassMethod MergeSettings(pFresh As %DynamicObject, pSupplied, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pChanged As %Boolean, Output pProblem As %String) As %Status [ Private ]
{
    Set pChanged = 0
    Set pProblem = ""
    Set tRules = ..#RULES
    If pFresh.%GetTypeOf(..#SETTINGSFIELD) '= "object" {
        ; The rules' own refusal: a secret or list setting the read never answers (AD-35).
        Set tSC = $ClassMethod(tRules, "WithheldSettingsCode", pFresh, .tCode)
        If $$$ISERR(tSC) Quit tSC
        Set pProblem = "'" _ ..#SETTINGSFIELD _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        Quit $$$OK
    }
    If '$IsObject(pSupplied) || 'pSupplied.%IsA("%Library.DynamicObject") {
        Set pProblem = "'" _ ..#SETTINGSFIELD _ "' is an object of the task type's own settings"
        Quit $$$OK
    }
    Set tHeld = pFresh.%Get(..#SETTINGSFIELD)
    Set tMerged = ##class(%DynamicAbstractObject).%FromJSON(tHeld.%ToJSON())
    Set tIterator = pSupplied.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tField = ..#SETTINGSFIELD _ "." _ tKey
        If tHeld.%GetTypeOf(tKey) = "unassigned" {
            Set pProblem = "'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#TASKSETTINGUNKNOWN)
            Quit
        }
        Set tAfter = $ClassMethod(tRules, "SettingText", pSupplied, tKey, .tOk)
        If 'tOk {
            Set pProblem = "the setting '" _ tKey _ "' is a single value"
            Quit
        }
        Set tBefore = $ClassMethod(tRules, "SettingText", tHeld, tKey, .tOk)
        If tAfter = tBefore Continue
        Do tMerged.%Set(tKey, tAfter, "string")
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", tBefore, "string")
        Do tRow.%Set("after", tAfter, "string")
        Do pDiff.%Push(tRow)
        Set pChanged = 1
    }
    If pProblem '= "" Quit $$$OK
    If pChanged Do pPayload.%Set(..#SETTINGSFIELD, tMerged)
    Quit $$$OK
}

/// <p>The form's own rules in <code>update</code> mode (<method>OcuPilot.Area.Task.TaskRules.Validate</method>)
/// over the agent's arguments and this tool's own fresh read of <var>pIdValue</var>, each broken rule
/// as its field and published sentence (AD-55). A task the read no longer finds is judged by no rule;
/// the mint has already refused one that was absent when it read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..ReadIdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Quit $$$OK
    Set tSC = $ClassMethod(..#RULES, "Validate", "update", pArgs, .tViolations, 1, tFresh, pIdValue)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(..#RULES, "Problem", .tViolations)
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCERUNSASOTHER</parameter> when the edit moves the task to run as another
/// account (<method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>), and none
/// otherwise.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean, pEffect As %String) As %String
{
    If pPrivileged Quit ..#CONSEQUENCERUNSASOTHER
    Quit ""
}

/// <p>What the caller must hold: the screen's own pairs, which include
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
