/// <p>The Task schedule's create tool (AD-54, AD-55, FR-52): propose creating one scheduled task. Two
/// callers reach it: the New Task wizard's Create task through <class>OcuPilot.Area.Task.TaskSave</class>,
/// and the agent's proposal and confirmation. It writes nothing by itself.</p>
/// <p><b>Its target is the task's name</b> (AD-13, AD-54). The vendor allocates the numeric id on the
/// write and accepts a duplicate name, so the absence read is the list read filtered to the one row
/// whose <code>Name</code> equals the argument, compared without regard to case: a name any task
/// holds refuses the mint, and one taken since the mint refuses the confirm. The confirm answers
/// the allocated id (<method>CreatedId</method>) for the change event (AD-14).</p>
/// <p><b>It sends the complete body</b>, because the vendor's <code>POST</code> requires every key
/// but <code>Settings</code> (measured 400 #40301): each supplied field is a diff row and every
/// other key takes a new task's own value (<method>OcuPilot.Area.Task.TaskRules.Compose</method>).
/// <code>OutputDirectory</code> is never the caller's: it is the manager directory, computed at the
/// write when an output file is named (<method>DerivedFields</method>, AD-21).</p>
/// <p><b>Running as another account is permitted and confirmed</b>: it needs
/// <code>%Admin_Secure:USE</code>, refused on the field before any write for a caller without it,
/// and a holder's proposal is minted destructive with the consequence
/// <parameter>CONSEQUENCERUNSASOTHER</parameter>, its diff naming the account.</p>
Class OcuPilot.Screen.Tool.TaskCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.schedule.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter DESCRIPTION = "Propose creating one scheduled task in this instance's Task Manager. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the task (a letter first, at most 50 characters, a name no task already has), give its task type (TaskClass, a task class in NameSpace) and its schedule; any field you omit takes a new task's own value. The task type's own settings go in Settings, each as a string.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>The vendor's create: <code>Task.CRUD</code>'s <code>POST</code>, which answers 201 with the new
/// id in its <code>Location</code> header.</p>
Parameter WRITETYPE = "POST";

/// <p>The port the read and the write go through (AD-52), which sets the new id on the create's
/// answer.</p>
Parameter PORTCLASS = "OcuPilot.Port.TaskPort";

/// <p>The absence read: the list, filtered by name, holding the one row whose <code>Name</code>
/// equals the argument (AD-51 as amended, the audit-event reset's form).</p>
Parameter READTYPE = "LIST";

Parameter READIDPARAM = "filter";

Parameter READROWKEY = "Name";

/// <p><code>%Admin_Task:USE</code>, the resource the vendor's <code>ResourcesOR()</code> admits for
/// <code>POST</code> and one of the screen's own two pairs (AD-8). A principal holding it and
/// <code>%DB_IRISSYS:READ</code> alone created a task (measured).</p>
Parameter WRITERESOURCE = "%Admin_Task";

Parameter WRITEPERMISSION = "USE";

/// <p>The fields a create sets, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.TaskCreateFields</method> names the same
/// thirty-four). <code>OutputDirectory</code> is not among them (AD-21).</p>
Parameter PERMITTEDFIELDS = "Name,RunAsUser,EmailOnCompletion,EmailOnError,EmailOnExpiration,EmailOutput,Expires,ExpiresDays,ExpiresHours,ExpiresMinutes,OpenOutputFile,OutputFilename,OutputFileIsBinary,SuspendOnError,SuspendTerminated,Priority,TaskClass,IsBatch,NameSpace,TimePeriod,TimePeriodEvery,TimePeriodDay,DailyFrequency,DailyFrequencyTime,DailyIncrement,DailyStartTime,DailyEndTime,StartDate,EndDate,RunAfterGUID,MirrorStatus,RescheduleOnStart,Description,Settings";

/// <p>The object argument the tool adds back beside the derived literals: the chosen type's own
/// settings, classified <code>opaque</code> (<class>OcuPilot.Screen.Tool.Classification</class>).</p>
Parameter SETTINGSFIELD = "Settings";

/// <p>The consequence a proposal carries when the task would run as another account.</p>
Parameter CONSEQUENCERUNSASOTHER = "TASK.RUNSASOTHER";

ClassMethod Endpoint() As %String
{
    Quit "Task.CRUD"
}

/// <p>The query parameter the write carries the name under; the vendor's <code>POST</code> reads
/// none, and the read's is <parameter>READIDPARAM</parameter>.</p>
ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>The derived <code>ordinary</code> fields this tool admits, and <code>Settings</code>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#SETTINGSFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>None: a task carries no declared secret.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The derived schema, typed and described from <code>%SYS.TaskSuper</code>'s own documentation
/// (<method>Described</method>), with <code>Settings</code> added and the name and task type
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ..Described(##super(pDescriptor))
    If '$IsObject(tSchema) Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If '$IsObject(tProperties) Quit tSchema
    Do tProperties.%Set(..#SETTINGSFIELD, {"type": "object", "description": "The task type's own settings, one member per setting name the type declares, each value a string; a setting you omit takes the type's own default. Each value is checked by the type itself. A setting the type uses as a location is shown to the user on the proposal."})
    If tProperties.%GetTypeOf("TaskClass") = "object" Do tSchema.%Get("required").%Push("TaskClass")
    Quit tSchema
}

/// <p><var>pSchema</var> with each field's JSON type, its vocabulary and its description, taken from
/// <code>%SYS.TaskSuper</code>'s property documentation (AD-3's semantic half). The three expiry
/// offsets carry no vendor description, so theirs are authored from the vendor's task utility's own
/// prompts and bounds.</p>
ClassMethod Described(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("Name") = "object" {
        Do tProperties.%Get("Name").%Set("description", "Name of the task: at most 50 characters, the first a letter. A name any task on this instance already has, in any case, is refused, so check the task schedule first.", "string")
    }
    Do ..Typed(tProperties, "Description", "string", "", "Description of the task, at most 100 characters.")
    Do ..Typed(tProperties, "NameSpace", "string", "", "Namespace to run the task in (the vendor's default is %SYS); one you can read.")
    Do ..Typed(tProperties, "TaskClass", "string", "", "The task type: a class in NameSpace which inherits from %SYS.Task.Definition, such as %SYS.Task.PurgeTaskHistory.")
    Do ..Typed(tProperties, "TimePeriod", "string", ["Daily", "Weekly", "Monthly", "Monthly Special", "Run After", "On Demand"], "Time period to run the task. It governs how TimePeriodEvery and TimePeriodDay are read: Daily every 1-7 days; Weekly every 1-5 weeks on TimePeriodDay's days; Monthly every 1-12 months on TimePeriodDay's day of the month; Monthly Special every 1-12 months on TimePeriodDay's week^day; Run After when RunAfterGUID's task completes; On Demand only when run.")
    Do ..Typed(tProperties, "TimePeriodEvery", "integer", "", "How many days (Daily, 1-7), weeks (Weekly, 1-5) or months (Monthly and Monthly Special, 1-12) apart the runs are. Not read for Run After or On Demand.")
    Do ..Typed(tProperties, "TimePeriodDay", "string", "", "For Weekly, the days to run on as digits 1-7 (1 is Sunday), for example 24 for Monday and Wednesday; for Monthly, the day of the month 1-31 (31 is the last day); for Monthly Special, week^day with week 1-5 (5 is the last) and day 1-7. Not read for Daily, Run After or On Demand.")
    Do ..Typed(tProperties, "RunAfterGUID", "string", "", "For Run After only: the JobGUID of the task this one runs after, which the user supplies.")
    Do ..Typed(tProperties, "DailyFrequency", "string", ["Once", "Several"], "How often each day to run the task: Once at DailyStartTime, or Several every DailyIncrement DailyFrequencyTime units from DailyStartTime to DailyEndTime. For Daily to Monthly Special only.")
    Do ..Typed(tProperties, "DailyFrequencyTime", "string", ["Minutes", "Hourly"], "For Several: whether DailyIncrement counts minutes or hours. Required with Several.")
    Do ..Typed(tProperties, "DailyIncrement", "integer", "", "For Several: the interval between runs, 1-1440 minutes or 1-24 hours. Required with Several.")
    Do ..Typed(tProperties, "DailyStartTime", "string", "", "Time of day of the (first) run, HH:MM in the instance's local time.")
    Do ..Typed(tProperties, "DailyEndTime", "string", "", "For Several: time of day of the last run, HH:MM, later than DailyStartTime.")
    Do ..Typed(tProperties, "StartDate", "string", "", "Date to schedule the task first, YYYY-MM-DD; with DailyStartTime it must be later than now. The vendor's default is tomorrow.")
    Do ..Typed(tProperties, "EndDate", "string", "", "Date to stop scheduling the task, YYYY-MM-DD, later than StartDate; empty never stops.")
    Do ..Typed(tProperties, "Expires", "boolean", "", "Whether a run expires: one not started by the next submit time, or by the offsets below, is not run. For Daily to Monthly Special only.")
    Do ..Typed(tProperties, "ExpiresDays", "integer", "", "Expiry offset in days, 0-999; 0 or omitted is none.")
    Do ..Typed(tProperties, "ExpiresHours", "integer", "", "Expiry offset in hours, 0-24; 0 or omitted is none.")
    Do ..Typed(tProperties, "ExpiresMinutes", "integer", "", "Expiry offset in minutes, 0-60; 0 or omitted is none.")
    Do ..Typed(tProperties, "RunAsUser", "string", "", "Username of the account to run as; omitted runs as you. Another account needs %Admin_Secure:Use, must exist and be enabled, and is confirmed as a destructive change because the task runs with that account's privileges.")
    Do ..Typed(tProperties, "Priority", "string", ["Normal", "Low", "High"], "Background job priority.")
    Do ..Typed(tProperties, "IsBatch", "boolean", "", "Batch mode restricts the job to a small section of the buffer pool.")
    Do ..Typed(tProperties, "MirrorStatus", "string", ["Primary", "Non-Primary", "Any"], "Which mirror members run the task: only the primary (the default), only a non-primary, or any. Ignored when the instance is not a mirror member.")
    Do ..Typed(tProperties, "OpenOutputFile", "boolean", "", "Whether the task's output is directed to its output file, which OcuPilot opens.")
    Do ..Typed(tProperties, "OutputFilename", "string", "", "One file name, never a path: a letter or digit first, then letters, digits, dots, dashes or underscores, ending in .txt. It is written to the instance's manager directory.")
    Do ..Typed(tProperties, "OutputFileIsBinary", "boolean", "", "When emailing the output file, whether it is sent as binary.")
    Do ..Typed(tProperties, "EmailOutput", "boolean", "", "Whether the output file is emailed to EmailOnCompletion's addresses.")
    Do ..Typed(tProperties, "SuspendOnError", "boolean", "", "Whether to suspend the task if a run returns an error; otherwise it is rescheduled for its next run.")
    Do ..Typed(tProperties, "SuspendTerminated", "boolean", "", "Whether to suspend the task if a system shutdown terminated it; otherwise it is rescheduled at startup.")
    Do ..Typed(tProperties, "RescheduleOnStart", "boolean", "", "Whether a run pending when the instance starts is rescheduled for its next time rather than run.")
    For tCase = $ListBuild("EmailOnCompletion", "Email addresses to send a completion notification to."), $ListBuild("EmailOnError", "Email addresses to send an error notification to."), $ListBuild("EmailOnExpiration", "Email addresses to send a notification to if the run expires.") {
        Set tField = $List(tCase, 1)
        If tProperties.%GetTypeOf(tField) '= "object" Continue
        Do tProperties.%Set(tField, {"type": "array", "items": {"type": "string"}, "description": ($List(tCase, 2) _ " Each like name@example.com.")})
    }
    Quit pSchema
}

/// <p>Set <var>pField</var>'s schema in <var>pProperties</var> to <var>pType</var>, with
/// <var>pEnum</var> when it is an array and <var>pDescription</var>. A field the schema does not
/// carry is left alone.</p>
ClassMethod Typed(pProperties As %DynamicObject, pField As %String, pType As %String, pEnum, pDescription As %String) [ Private ]
{
    If pProperties.%GetTypeOf(pField) '= "object" Quit
    Set tProperty = {}
    Do tProperty.%Set("type", pType, "string")
    If $IsObject(pEnum) Do tProperty.%Set("enum", pEnum)
    Do tProperty.%Set("description", pDescription, "string")
    Do pProperties.%Set(pField, tProperty)
}

/// <p>The complete body (<method>OcuPilot.Area.Task.TaskRules.Compose</method>).</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.Task.TaskRules).Compose(pArgs, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The form's own rules over the agent's arguments
/// (<method>OcuPilot.Area.Task.TaskRules.Validate</method>, create mode), each broken rule as its
/// field and published sentence (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Do tArgs.%Set("Name", pIdValue, "string")
    Set tSC = ##class(OcuPilot.Area.Task.TaskRules).Validate("create", tArgs, .tViolations, 0)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ##class(OcuPilot.Area.Task.TaskRules).Problem(.tViolations)
    Quit $$$OK
}

/// <p>The output directory, derived at the write (AD-21): the manager directory when the body names
/// an output file, and empty otherwise. Computed on each call, never cached.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Set tFile = ""
    If pPayload.%GetTypeOf("OutputFilename") = "string" Set tFile = pPayload.%Get("OutputFilename")
    Do pPayload.%Set("OutputDirectory", $Select(tFile '= "": $System.Util.ManagerDirectory(), 1: ""), "string")
}

/// <p>The new task's id, which <class>OcuPilot.Port.TaskPort</class> sets on the create's
/// answer.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Id") '= "number" Quit ""
    Quit "" _ pWritten.%Get("Id")
}

/// <p><parameter>CONSEQUENCERUNSASOTHER</parameter> when the write runs the task as another account
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>), and none
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
