/// <p>The Task schedule's export tool (AD-6, AD-21, AD-51, AD-52, AD-53, Story 16.4): write one task
/// to a server file in the instance's own task export format. Two callers reach it: the list's
/// Export row action through <class>OcuPilot.Api.ScreenAction</class>, with the file as the action's
/// two values (AD-56 (ii)), and the agent's proposal and confirmation.</p>
/// <p><b>The file is named by <code>root</code> and <code>path</code></b>, an allowed directory and a
/// relative name under it (AD-21's sixth case), and nothing else. They travel in the port query
/// (<method>PortQuery</method>); <class>OcuPilot.Port.TaskTransferPort</class> resolves them through
/// <class>OcuPilot.Port.PathPort</class> at the write, and the agent's mint resolves them first
/// (<class>OcuPilot.Screen.Tool.TaskExportMint</class>), so a refusal lands on its field on either
/// path. A file already at the name is replaced (<method>Consequence</method>); a directory, the
/// instance's own files and OcuPilot's served files are refused.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and the port composes the vendor's
/// <code>ExportTasks</code> call from the target and the file. The fresh read is the task with the two
/// arguments; the fingerprint subject is what names the task and the file.</p>
/// <p>IRIS records no audit event for an export (measured with auditing on), so the agent's marker is
/// its only record and a screen export leaves none (AD-15, AD-53). It is not destructive.</p>
Class OcuPilot.Screen.Tool.TaskExport Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.schedule.export";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter DESCRIPTION = "Propose writing one scheduled task to a new file on the server, in the instance's own task export format, so another instance can import it. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. The file holds the task's settings as the instance stores them, and a password setting in it is encoded, not encrypted: say so in the rationale.";

/// <p>The port that resolves the file and calls the vendor (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.TaskTransferPort";

/// <p>The Task schedule's Export row action, whose two values are the file.</p>
Parameter SCREENACTIONS = "export";

Parameter SCREENVALUES = "export=root:path";

/// <p>The fresh read: the task, with the two arguments empty.</p>
Parameter READTYPE = "TASK";

Parameter WRITETYPE = "EXPORT";

/// <p>No body: the port composes the call (<parameter>OcuPilot.Port.TaskTransferPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>What <parameter>READTYPE</parameter> answers of the subject (DW-1475).</p>
Parameter READANSWERS = "Name,TaskClass,NameSpace,Type,root,path";

/// <p>The task and the file the user reviewed. The file is in the subject because the stored
/// payload is narrowed to it, and <method>PortQuery</method> reads it from that payload.</p>
Parameter FINGERPRINTSUBJECT = "Name,TaskClass,NameSpace,root,path";

/// <p>A task whose name the read did not answer is not one to export.</p>
Parameter PRECONDITIONFIELD = "Name";

/// <p>The classic page whose Export this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%cspapp.op.utilsystaskaction";

/// <p>The pair every file consumer declares beyond the Task schedule's own (AD-21).</p>
Parameter WRITERESOURCE = "%Admin_FileSystemAccess";

Parameter WRITEPERMISSION = "USE";

/// <p>The consequence code the proposal carries: a file already at the name is replaced.</p>
Parameter CONSEQUENCE = "TASK.EXPORT.REPLACES";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.TaskTransferPort).#ENDPOINT
}

/// <p>The vendor's numeric task id, which the list's rows carry as <code>Id</code>.</p>
ClassMethod IdArgument() As %String
{
    Quit "Id"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.TaskTransferPort).#IDPARAM
}

/// <p><code>root</code> and <code>path</code>: the tool sends no body, and the two arguments reach
/// the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM)
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the file is resolved
/// (<class>OcuPilot.Screen.Tool.TaskExportMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.TaskExportMint"
}

/// <p>The derived schema with the task described and <code>root</code> and <code>path</code> added,
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The task to export, named by the numeric id this instance's own task schedule reports for it. A task the schedule does not report is refused.", "string")
    }
    Do ..AddFileArguments(tSchema)
    Quit tSchema
}

/// <p>Add <code>root</code> and <code>path</code> to <var>pSchema</var>, both required.</p>
ClassMethod AddFileArguments(pSchema As %DynamicObject)
{
    Set tProperties = pSchema.%Get("properties")
    Do tProperties.%Set(##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM, {"type": "string", "description": "An allowed directory on the server, exactly as this instance's Allowed directories screen lists it. Any other value is refused."})
    Do tProperties.%Set(##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM, {"type": "string", "description": "The file's name relative to root: up to eight names separated by '/', each starting with a letter or digit and holding only letters, digits, dots, underscores and dashes. Never a full path."})
    Do pSchema.%Get("required").%Push(##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM)
    Do pSchema.%Get("required").%Push(##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM)
}

/// <p>The Task schedule's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>,
/// then the custom resource of the <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8,
/// AD-21, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>What is wrong with <var>pArgs</var>' file arguments, or <code>""</code>: <code>root</code> and
/// <code>path</code> are each a non-empty string. Their shape and place are the port's to judge at the
/// resolve, so a refusal lands on its field.</p>
ClassMethod FileProblem(pArgs As %DynamicObject) As %String
{
    If '$IsObject(pArgs) Quit "'root' and 'path' name the file"
    If (pArgs.%GetTypeOf(##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM) '= "string") || (pArgs.%Get(##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM) = "") Quit "'root' names an allowed directory and cannot be empty"
    If (pArgs.%GetTypeOf(##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM) '= "string") || (pArgs.%Get(##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM) = "") Quit "'path' names the file under root and cannot be empty"
    Quit ""
}

/// <p>The agent's file arguments refused by <method>FileProblem</method> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The screen's two values as this tool's arguments, unresolved, so the write's own
/// <code>PATH.*</code> refusal reaches the field it is about (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set pProblem = ..FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The stored payload's file arguments under the port's own query keys, so the confirm's write and
/// the screen's carry the file the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM {
        If pPayload.%GetTypeOf(tField) = "string" Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>No state row: the merge's <code>root</code> and <code>path</code> rows are the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: a file already at the name is
/// replaced.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
