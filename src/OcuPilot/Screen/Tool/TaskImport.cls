/// <p>The Task schedule's import tool (AD-6, AD-21, AD-51, AD-52, AD-53, Story 16.4): create every task
/// a server task export file holds that this instance does not. Two callers reach it: Task schedule's
/// screen-level Import through <class>OcuPilot.Api.ScreenAction</class>, with the file as the action's
/// two values (AD-56 (ii)), and the agent's proposal and confirmation.</p>
/// <p><b>The target is the literal <parameter>OcuPilot.Port.TaskTransferPort.IMPORTID</parameter></b> on
/// the <code>task</code> type, whatever the caller sends, and the file is two arguments,
/// <code>root</code> and <code>path</code> (AD-21's sixth case), resolved as a source at the write. A
/// file whose tasks cannot all be created is refused whole; a task already on the instance, by its
/// <code>JobGUID</code>, is skipped, as the vendor skips it.</p>
/// <p><b>The reviewed <code>tasks</code></b> is the agent's alone: its mint reads the file and stores
/// the tasks the import will create (<class>OcuPilot.Screen.Tool.TaskImportMint</class>), and the port
/// refuses the write <code>TASK.IMPORT.CHANGED</code> when the file no longer yields them. The input
/// schema never advertises it, so the agent cannot send one. The screen's payload holds it empty, and
/// nothing is compared.</p>
/// <p>IRIS records <code>%System/%System/ConfigurationChange</code> for each task the import creates.
/// It is not destructive.</p>
Class OcuPilot.Screen.Tool.TaskImport Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.schedule.import";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter DESCRIPTION = "Propose importing every task in a task export file on the server, named by `root` and `path` as for export. Send the literal 'import' as the id. A task already on this instance, with the same task GUID, is skipped. The whole file is refused, and nothing imported, when any task in it cannot be created here.";

/// <p>The port that resolves the file, reads its tasks and calls the vendor (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.TaskTransferPort";

/// <p>Task schedule's Import, whose two values are the file.</p>
Parameter SCREENACTIONS = "import";

Parameter SCREENVALUES = "import=root:path";

/// <p>The fresh read: the import's target, with the three arguments empty.</p>
Parameter READTYPE = "SCHEDULE";

Parameter WRITETYPE = "IMPORT";

/// <p>No body: the port composes the call (<parameter>OcuPilot.Port.TaskTransferPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>Tasks are created, so a screen showing them re-reads (AD-14).</p>
Parameter CHANGEACTION = "created";

/// <p>What <parameter>READTYPE</parameter> answers (DW-1475).</p>
Parameter READANSWERS = "root,path,tasks";

/// <p>The file and the tasks the user reviewed. They are the subject because the stored payload is
/// narrowed to it, and <method>PortQuery</method> reads them from that payload.</p>
Parameter FINGERPRINTSUBJECT = "root,path,tasks";

Parameter PRECONDITIONFIELD = "path";

/// <p>The classic page whose Import this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%cspapp.op.utilsystaskaction";

/// <p>The pair every file consumer declares beyond the Task schedule's own (AD-21).</p>
Parameter WRITERESOURCE = "%Admin_FileSystemAccess";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.TaskTransferPort).#ENDPOINT
}

ClassMethod IdArgument() As %String
{
    Quit "Id"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.TaskTransferPort).#IDPARAM
}

/// <p><code>root</code>, <code>path</code> and <code>tasks</code>: the tool sends no body, and the
/// three reach the port through <method>PortQuery</method>. Only the first two are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM, ##class(OcuPilot.Port.TaskTransferPort).#TASKSPARAM)
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the file's tasks are
/// read (<class>OcuPilot.Screen.Tool.TaskImportMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.TaskImportMint"
}

/// <p>The derived schema with the literal id described and <code>root</code> and <code>path</code>
/// added, required. <code>tasks</code> is never advertised, so the closed schema refuses it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "Send the literal 'import': an import names the file by root and path, not by a task.", "string")
    }
    Do ##class(OcuPilot.Screen.Tool.TaskExport).AddFileArguments(tSchema)
    Quit tSchema
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

/// <p>The agent's file arguments refused by
/// <method>OcuPilot.Screen.Tool.TaskExport.FileProblem</method> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The screen's two values as this tool's arguments, unresolved, so the write's own
/// <code>PATH.*</code> refusal reaches the field it is about (AD-56 (ii)). No <code>tasks</code> is
/// sent, so the write compares none.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set pProblem = ##class(OcuPilot.Screen.Tool.TaskExport).FileProblem(pArgs)
    Quit $$$OK
}

/// <p>The stored payload's file arguments and reviewed <code>tasks</code> under the port's own query
/// keys, so the confirm's write and the screen's carry what the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.TaskTransferPort).#ROOTPARAM, ##class(OcuPilot.Port.TaskTransferPort).#PATHPARAM, ##class(OcuPilot.Port.TaskTransferPort).#TASKSPARAM {
        If pPayload.%GetTypeOf(tField) = "string" Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>No state row: the merge's <code>root</code>, <code>path</code> and <code>tasks</code> rows are the
/// card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

}
