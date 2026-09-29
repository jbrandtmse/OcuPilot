/// <p>The Task schedule's export and import port (AD-27's Story 16.4 case, AD-29, AD-51, AD-52): one
/// task written to a server file, and every task in a server file created, through the vendor's own
/// <parameter>TASKCLASS</parameter> <code>ExportTasks</code> and <code>ImportTasks</code> in
/// <code>%SYS</code> (AD-16), which is what the classic <code>%cspapp.op.utilsystaskaction</code>
/// calls. It is <class>OcuPilot.Port.TaskPort</class> with one pseudo-endpoint,
/// <parameter>ENDPOINT</parameter>, carried out here; every other call is the task port's own.</p>
/// <p><b>The file is never a caller's path</b> (AD-21's sixth case). Every type that reaches a file
/// takes <code>root</code> and <code>path</code> in the query and resolves them through
/// <method>PathPortClass</method>'s <code>Resolve</code> (<method>Locate</method>): an export as an
/// overwriting <code>file</code> (<parameter>EXPORTOVERWRITES</parameter>, a constant), an import as a
/// <code>source</code>. The resolved path reaches the vendor call alone.</p>
/// <p><b>Its own gate comes first</b> (AD-29): <parameter>PAIRS</parameter>, checked in order in the
/// calling process before any read or vendor call; a caller missing one is refused 403
/// <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code>. PathPort's gate still runs
/// inside <code>Resolve</code>.</p>
/// <p><b>An import is refused whole or made whole</b>. The vendor keeps the tasks it created before a
/// failure, so <method>Examine</method> reads the file's tasks through <class>%XML.Reader</class>
/// correlated to <parameter>TASKCLASS</parameter>, saving nothing and never reading a task's settings,
/// and refuses the file when any task it would create breaks one of the create's rules. A task whose
/// <code>JobGUID</code> is already on the instance is skipped, as the vendor skips it.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.TaskTransferFixture</class>):
/// <method>PathPortClass</method>, <method>VendorExport</method> and <method>VendorImport</method>,
/// with the admin port's own <method>HoldsPair</method> and <method>LogFault</method>. Production
/// overrides none of them. The vendor seams are private, so <method>Invoke</method>, behind the gate,
/// is the only way in.</p>
Class OcuPilot.Port.TaskTransferPort Extends OcuPilot.Port.TaskPort
{

/// <p>The pseudo-endpoint this port carries out itself.</p>
Parameter ENDPOINT = "TaskTransfer";

/// <p>The port's own pair set, checked in this order before any read or vendor call (AD-29): the
/// Task schedule's two pairs and PathPort's.</p>
Parameter PAIRS = "%Admin_Task:USE,%DB_IRISSYS:READ,%Admin_FileSystemAccess:USE";

/// <p>The one id an import targets (AD-13), compared without regard to case.</p>
Parameter IMPORTID = "import";

/// <p>The read types: a task with the export's two arguments, the import's target, and a file's
/// tasks.</p>
Parameter TASKTYPE = "TASK";

Parameter SCHEDULETYPE = "SCHEDULE";

Parameter PREVIEWTYPE = "PREVIEW";

/// <p>The write types.</p>
Parameter EXPORTTYPE = "EXPORT";

Parameter IMPORTTYPE = "IMPORT";

/// <p>The <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pairs whose vendor call this
/// port composes from the tools' declared arguments (AD-51).</p>
Parameter COMPOSEDTYPES = "TaskTransfer/EXPORT,TaskTransfer/IMPORT";

/// <p>The query parameters the target, the two file arguments and the reviewed tasks travel
/// under.</p>
Parameter IDPARAM = "id";

Parameter ROOTPARAM = "root";

Parameter PATHPARAM = "path";

Parameter TASKSPARAM = "tasks";

/// <p>Whether the export replaces a file already at its name: declared by the export itself, never a
/// caller value (AD-21).</p>
Parameter EXPORTOVERWRITES As BOOLEAN = 1;

/// <p>The vendor class the export, the import and the file's tasks are read through.</p>
Parameter TASKCLASS = "%SYS.Task";

/// <p>The class every task type extends.</p>
Parameter DEFINITIONCLASS = "%SYS.Task.Definition";

/// <p>The export file's root element, and the element each task is.</p>
Parameter ROOTELEMENT = "Tasks";

Parameter TASKELEMENT = "Task";

/// <p>The vendor's own qualifiers: no display output.</p>
Parameter QSPEC = "-d";

/// <p>The resource running a task as another account needs, as the vendor's own check reads it.</p>
Parameter SECURERESOURCE = "%Admin_Secure";

/// <p>The separator between two tasks in the reviewed summary.</p>
Parameter SUMMARYSEPARATOR = "; ";

/// <p>The admin port's call, except for <parameter>ENDPOINT</parameter>:
/// <parameter>TASKTYPE</parameter> answers the task port's <code>Task.CRUD</code> <code>GET</code> for
/// <parameter>IDPARAM</parameter> with <code>root</code> and <code>path</code> added empty;
/// <parameter>SCHEDULETYPE</parameter> answers <code>{root, path, tasks}</code> empty for
/// <parameter>IMPORTID</parameter> and 404 for any other id; <parameter>PREVIEWTYPE</parameter> answers
/// <code>{tasks, count, present}</code> for the file <code>root</code> and <code>path</code> name;
/// <parameter>EXPORTTYPE</parameter> and <parameter>IMPORTTYPE</parameter> are
/// <method>Export</method> and <method>Import</method>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. <parameter>ENDPOINT</parameter> takes no body;
/// any other type is 501 <code>PORT.NOTIMPLEMENTED</code>. Must not be called from an escalated frame
/// (AD-9); the caller's namespace is unchanged on return (AD-16).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..GateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and its call is composed by the port", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
            Quit
        }
        Set tId = $Get(pQuery(..#IDPARAM))
        Set tRoot = $Get(pQuery(..#ROOTPARAM))
        Set tPath = $Get(pQuery(..#PATHPARAM))
        If pType = ..#TASKTYPE {
            Set tSC = ..ReadTask(tId, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#SCHEDULETYPE {
            If $ZConvert(tId, "L") '= ..#IMPORTID {
                Set tSC = ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
                Quit
            }
            Set pResult = {}
            Do pResult.%Set(..#ROOTPARAM, "", "string")
            Do pResult.%Set(..#PATHPARAM, "", "string")
            Do pResult.%Set(..#TASKSPARAM, "", "string")
            Set pHttpStatus = 200
            Quit
        }
        If pType = ..#PREVIEWTYPE {
            Set tSC = ..Locate(..#IMPORTTYPE, tRoot, tPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set tSC = ..Examine(tResolved, .tExamined, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set pResult = {}
            Do pResult.%Set(..#TASKSPARAM, tExamined.%Get("summary"), "string")
            Do pResult.%Set("count", tExamined.%Get("count"), "number")
            Do pResult.%Set("present", tExamined.%Get("present"), "number")
            Set pHttpStatus = 200
            Quit
        }
        If pType = ..#EXPORTTYPE {
            Set tSC = ..Export(tId, tRoot, tPath, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#IMPORTTYPE {
            Set tSC = ..Import(tRoot, tPath, $Get(pQuery(..#TASKSPARAM)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <parameter>PAIRS</parameter>, checked in order
/// through <method>OcuPilot.Port.AdminPort.HoldsPair</method>. <var>pFailedPair</var> names the first it
/// lacks, or is <code>""</code>.</p>
ClassMethod Gate(Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tPairs = $ListFromString(..#PAIRS)
    For tI = 1:1:$ListLength(tPairs) {
        If ..HoldsPair($List(tPairs, tI)) Continue
        Set pFailedPair = $List(tPairs, tI)
        Quit
    }
    Quit (pFailedPair = "")
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved and checked exactly as
/// <method>Export</method> checks it before its vendor call, for a mint that must refuse what the
/// write would: the gate, <method>Locate</method>, and <code>TASK.EXPORT.DIRECTORY</code> on
/// <code>path</code> when the name's parent directory does not exist. Nothing is written.</p>
ClassMethod CheckExport(pRoot As %String, pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..GateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail(..#ENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The class <method>Locate</method> resolves through. Overridable so a fixture can observe the
/// resolve; production never overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p>Resolve <var>pRoot</var> and <var>pPath</var> for write type <var>pType</var> through
/// <method>PathPortClass</method> (AD-21): <parameter>EXPORTTYPE</parameter> as a <code>file</code>
/// with <parameter>EXPORTOVERWRITES</parameter>, <parameter>IMPORTTYPE</parameter> as a
/// <code>source</code>, each refusal on the <code>root</code> or <code>path</code> field. On success
/// <var>pResolved</var> is the path and <var>pAbsent</var> whether no file stood at it.</p>
ClassMethod Locate(pType As %String, pRoot As %String, pPath As %String, Output pResolved As %String, Output pAbsent As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResolved = ""
    Set pAbsent = 0
    Set tPathPort = ..PathPortClass()
    If pType = ..#EXPORTTYPE {
        Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDFILE"), ..#ROOTPARAM, ..#PATHPARAM, .pResolved, .pHttpStatus, .pFault, ..#EXPORTOVERWRITES)
    } Else {
        Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDSOURCE"), ..#ROOTPARAM, ..#PATHPARAM, .pResolved, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) {
        Set pResolved = ""
        Quit tSC
    }
    Set pAbsent = '##class(%File).Exists(pResolved)
    Quit tSC
}

/// <p>The export's file: <method>Locate</method>, then <code>TASK.EXPORT.DIRECTORY</code>, 400 with one
/// violation on <code>path</code>, when the resolved name's directory does not exist. A directory is
/// never created.</p>
ClassMethod ExportFile(pRoot As %String, pPath As %String, Output pResolved As %String, Output pAbsent As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Locate(..#EXPORTTYPE, pRoot, pPath, .pResolved, .pAbsent, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Quit ..Violation(##class(OcuPilot.Api.Error).#TASKEXPORTDIRECTORY, ##class(OcuPilot.Api.Error).#REASONTASKEXPORTDIRECTORY, ..#PATHPARAM, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The task <var>pId</var> names, as the task port's <code>Task.CRUD</code> <code>GET</code> answers
/// it, with <code>root</code> and <code>path</code> added empty. An id that is not a task id is
/// 404.</p>
ClassMethod ReadTask(pId As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$Match(pId, "^[1-9][0-9]{0,18}$") Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Kill tQuery
    Set tQuery(..#IDPARAM) = pId
    ; Another endpoint, so Invoke hands it to the task port's own call.
    Set tSC = ..Invoke(..#TASKENDPOINT, ..#COMPLETEDTYPE, .tQuery, "", .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pResult) || 'pResult.%IsA("%Library.DynamicObject") {
        Set pResult = ""
        Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    }
    Do pResult.%Set(..#ROOTPARAM, "", "string")
    Do pResult.%Set(..#PATHPARAM, "", "string")
    Quit tSC
}

/// <p>Write task <var>pId</var> to the file <var>pRoot</var> and <var>pPath</var> name, and answer
/// <code>{root, path}</code> at 200. In order: the file is resolved and its directory checked
/// (<method>ExportFile</method>); a task the instance no longer holds is 404; then
/// <method>VendorExport</method>. When the vendor call fails and no file stood at the name when it was
/// resolved, a file now standing there is the call's own and is deleted; the fault is normalized
/// (AD-39) and the vendor's text is logged alone.</p>
ClassMethod Export(pId As %String, pRoot As %String, pPath As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadTask(pId, .tTask, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tTask = ""
    Set pHttpStatus = 0
    Set tVendorSC = $$$OK
    Try {
        Set tVendorSC = ..VendorExport($ListBuild(+pId), tResolved)
    } Catch ex {
        Set tVendorSC = ex.AsStatus()
    }
    If $$$ISERR(tVendorSC) {
        If tAbsent && ##class(%File).Exists(tResolved) Do ##class(%File).Delete(tResolved)
        Quit ..Fail(..#ENDPOINT, 500, tVendorSC, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set(..#ROOTPARAM, pRoot, "string")
    Do pResult.%Set(..#PATHPARAM, pPath, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Create every task the file <var>pRoot</var> and <var>pPath</var> name holds that this instance
/// does not, and answer <code>{imported, skipped}</code> at 200, counted by <code>JobGUID</code> once
/// the vendor call returns. In order: the file is resolved as a source; <method>Examine</method> refuses
/// a file that is not a task export or holds a task that cannot be created, and a file whose every task
/// is present; a non-empty <var>pReviewed</var> that differs from the summary read now is 409
/// <code>TASK.IMPORT.CHANGED</code>; then <method>VendorImport</method>.</p>
ClassMethod Import(pRoot As %String, pPath As %String, pReviewed As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..Locate(..#IMPORTTYPE, pRoot, pPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Examine(tResolved, .tExamined, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If (pReviewed '= "") && (pReviewed '= tExamined.%Get("summary")) {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#TASKIMPORTCHANGED, ##class(OcuPilot.Api.Error).#REASONTASKIMPORTCHANGED, .pHttpStatus, .pFault)
    }
    Set pHttpStatus = 0
    Set tVendorSC = $$$OK
    Try {
        Set tVendorSC = ..VendorImport(tResolved)
    } Catch ex {
        Set tVendorSC = ex.AsStatus()
    }
    If $$$ISERR(tVendorSC) Quit ..Fail(..#ENDPOINT, 500, tVendorSC, .pHttpStatus, .pFault)
    Set tSC = ..Held(.tGuids, .tNames)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    Set tImported = 0
    Set tIterator = tExamined.%Get("absent").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tGuid) {
        If (tGuid = "") || $Data(tGuids(tGuid)) Set tImported = tImported + 1
    }
    Set pResult = {}
    Do pResult.%Set("imported", tImported, "number")
    Do pResult.%Set("skipped", tExamined.%Get("present"), "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>What the task export at <var>pFile</var> would do, in <var>pExamined</var>:
/// <code>{summary, count, present, absent}</code> -- the reviewed summary, <code>Name (NAMESPACE)</code>
/// of each task the import would create in file order joined by
/// <parameter>SUMMARYSEPARATOR</parameter>; the file's task count; how many the vendor will skip as
/// already present by <code>JobGUID</code>, on this instance or earlier in the file; and the
/// <code>JobGUID</code> of each task it would create.</p>
/// <p>Refused, before any vendor write: 422 <code>TASK.IMPORT.FILE</code> for a file
/// <method>FileTasks</method> cannot read as a task export; for the first task it would create that
/// breaks a rule, 422 with that rule's code and reason and <code>detail.task</code> naming it
/// (<method>TaskProblem</method>); and 409 <code>TASK.IMPORT.PRESENT</code> when every task is
/// present.</p>
ClassMethod Examine(pFile As %String, Output pExamined As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pExamined = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..FileTasks(pFile, .tTasks, .tReadable)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If 'tReadable || (tTasks.%Size() = 0) {
        Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#TASKIMPORTFILE, ##class(OcuPilot.Api.Error).#REASONTASKIMPORTFILE, .pHttpStatus, .pFault)
    }
    Set tSC = ..Held(.tGuids, .tNames)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    Set tSummary = ""
    Set tPresent = 0
    Set tAbsent = []
    Set tIterator = tTasks.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTask) {
        Set tGuid = tTask.%Get("JobGUID")
        If (tGuid '= "") && $Data(tGuids(tGuid)) {
            Set tPresent = tPresent + 1
            Continue
        }
        Set tCode = ..TaskProblem(tTask, .tNames)
        If tCode '= "" {
            Set tDetail = {}
            Do tDetail.%Set("task", tTask.%Get("Name"), "string")
            Quit
        }
        ; A later task of the same file holding this name is refused, and one holding this GUID
        ; skipped, as though the instance held it: the vendor imports in file order.
        Set tNames($ZConvert(tTask.%Get("Name"), "U")) = ""
        If tGuid '= "" Set tGuids(tGuid) = ""
        Do tAbsent.%Push(tGuid, "string")
        Set tSummary = tSummary _ $Select(tSummary = "": "", 1: ..#SUMMARYSEPARATOR) _ tTask.%Get("Name") _ " (" _ tTask.%Get("NameSpace") _ ")"
    }
    If $Get(tCode) '= "" {
        Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tCode, ##class(OcuPilot.Api.Error).ReasonForTask(tCode), .pHttpStatus, .pFault, tDetail)
    }
    If tPresent = tTasks.%Size() {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#TASKIMPORTPRESENT, ##class(OcuPilot.Api.Error).#REASONTASKIMPORTPRESENT, .pHttpStatus, .pFault)
    }
    Set pExamined = {}
    Do pExamined.%Set("summary", tSummary, "string")
    Do pExamined.%Set("count", tTasks.%Size(), "number")
    Do pExamined.%Set("present", tPresent, "number")
    Do pExamined.%Set("absent", tAbsent)
    Quit $$$OK
}

/// <p>The tasks the export at <var>pFile</var> holds, in file order, each
/// <code>{Name, NameSpace, TaskClass, RunAsUser, JobGUID}</code>, read in <code>%SYS</code> (AD-16)
/// through <class>%XML.Reader</class> correlated to <parameter>TASKCLASS</parameter>, with external
/// entities resolved to nothing. Nothing is saved and no task's settings are read.
/// <var>pReadable</var> is 0 for a file that does not parse, whose root element is not
/// <parameter>ROOTELEMENT</parameter>, whose tasks do not import, or one of whose tasks has no name.
/// The returned status is an error only when the read could not be made.</p>
ClassMethod FileTasks(pFile As %String, Output pTasks As %DynamicArray, Output pReadable As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pTasks = []
    Set pReadable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tReader = ##class(%XML.Reader).%New()
        Set tReader.EntityResolver = ##class(%XML.SAX.NullEntityResolver).%New()
        Set tOpenSC = tReader.OpenFile(pFile)
        If $$$ISOK(tOpenSC) && $IsObject(tReader.Document) {
            Set tRoot = tReader.Document.GetDocumentElement()
            If $IsObject(tRoot) && (tRoot.LocalName = ..#ROOTELEMENT) {
                Do tReader.Correlate(..#TASKELEMENT, ..#TASKCLASS)
                Set tNextSC = $$$OK
                Set tNameless = 0
                While tReader.Next(.tObject, .tNextSC) {
                    Set tTask = {}
                    For tField = "Name", "NameSpace", "TaskClass", "RunAsUser", "JobGUID" {
                        Do tTask.%Set(tField, $Property(tObject, tField) _ "", "string")
                    }
                    Set tObject = ""
                    If tTask.%Get("Name") = "" Set tNameless = 1
                    Do pTasks.%Push(tTask)
                }
                Set pReadable = $$$ISOK(tNextSC) && 'tNameless
            }
            Set tRoot = ""
        }
        Do tReader.Close()
        Set tReader = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tObject = ""
        Set tReader = ""
        Set pTasks = []
        Set pReadable = 0
        Set tSC = ex.AsStatus()
    }
    If 'pReadable Set pTasks = []
    Quit tSC
}

/// <p>The tasks this instance holds, as <code>pGuids(JobGUID) = id</code> and
/// <code>pNames(NAME) = ""</code> with each name in upper case, read in <code>%SYS</code> (AD-16) from
/// <parameter>TASKCLASS</parameter>'s own table with <code>%ExecDirectNoPriv</code>: the read rests on
/// this port's gate and on the <code>%DB_IRISSYS:READ</code> IRIS enforces on the globals, not on SQL
/// grants (AD-29). A failed statement is an error, never an empty answer.</p>
ClassMethod Held(Output pGuids, Output pNames) As %Status
{
    Kill pGuids, pNames
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, "SELECT %ID, Name, JobGUID FROM %SYS.Task")
        If '$IsObject(tResult) {
            Set tSC = $$$ERROR($$$GeneralError, "the task table answered no result")
        } ElseIf tResult.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message)
        } Else {
            While tResult.%Next(.tNextSC) {
                Set tGuid = tResult.%GetData(3)
                If tGuid '= "" Set pGuids(tGuid) = tResult.%GetData(1)
                Set tName = tResult.%GetData(2)
                If tName '= "" Set pNames($ZConvert(tName, "U")) = ""
            }
            If $$$ISERR($Get(tNextSC, $$$OK)) Set tSC = tNextSC
        }
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Kill pGuids, pNames
    Quit tSC
}

/// <p>The code of the first create rule task <var>pTask</var> breaks, or <code>""</code>, in the
/// create's own order: its namespace is not one the caller can read (<method>Readable</method>); its
/// class is not a task type there (<method>IsTaskType</method>); the caller lacks the privilege the
/// type declares (<code>CheckPermission</code>); it runs as another account and the caller lacks
/// <parameter>SECURERESOURCE</parameter>:USE, or as an account that is unknown or disabled; its name
/// is one <var>pNames</var> holds, compared without regard to case.</p>
ClassMethod TaskProblem(pTask As %DynamicObject, ByRef pNames) As %String
{
    Set tNamespace = pTask.%Get("NameSpace")
    Set tClass = pTask.%Get("TaskClass")
    If '..Readable(tNamespace) Quit ##class(OcuPilot.Api.Error).#TASKNAMESPACEUNKNOWN
    If '..IsTaskType(tClass, tNamespace) Quit ##class(OcuPilot.Api.Error).#TASKTASKCLASSUNKNOWN
    Set tPermitted = 0
    Try {
        Set tPermitted = $ClassMethod(..#DEFINITIONCLASS, "CheckPermission", tClass, tNamespace, .tPermissionSC)
    } Catch {
        Set tPermitted = 0
    }
    If 'tPermitted Quit ##class(OcuPilot.Api.Error).#TASKTASKCLASSPERMISSION
    Set tCode = ..RunAsProblem(pTask.%Get("RunAsUser"))
    If tCode '= "" Quit tCode
    If $Data(pNames($ZConvert(pTask.%Get("Name"), "U"))) Quit ##class(OcuPilot.Api.Error).#TASKNAMETAKEN
    Quit ""
}

/// <p>Whether <var>pNamespace</var> exists and the caller holds <code>READ</code> on the resource of its
/// default global database, as <code>%SYS.Namespace</code> reports it without connecting to a remote
/// database. A namespace whose database names no resource is not readable.</p>
ClassMethod Readable(pNamespace As %String) As %Boolean
{
    If (pNamespace = "") || ($Extract(pNamespace) = "^") Quit 0
    Set tReadable = 0
    Try {
        If '##class(%SYS.Namespace).Exists(pNamespace) Quit
        Kill tInfo
        Do ##class(%SYS.Namespace).GetAllNSInfo(pNamespace, .tInfo, 1)
        Set tResource = $Get(tInfo("GlobalDB", "Resource"))
        If tResource = "" Quit
        Set tReadable = ''$System.Security.Check(tResource, "READ")
    } Catch {
        Set tReadable = 0
    }
    Quit tReadable
}

/// <p>Whether <var>pClass</var> is a compiled, non-abstract class extending
/// <parameter>DEFINITIONCLASS</parameter> in <var>pNamespace</var>, asked there by explicit save and
/// restore (AD-16).</p>
ClassMethod IsTaskType(pClass As %String, pNamespace As %String) As %Boolean
{
    If '$Match(pClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit 0
    Set tKnown = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(pClass, 0)
        If $IsObject(tCompiled) && 'tCompiled.Abstract Set tKnown = ''$ClassMethod(pClass, "%Extends", ..#DEFINITIONCLASS)
        Set tCompiled = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tKnown = 0
    }
    Quit tKnown
}

/// <p>The <code>RunAsUser</code> rule's code for <var>pUser</var>, or <code>""</code>: blank or the
/// caller's own name passes; any other name needs <parameter>SECURERESOURCE</parameter>:USE before it
/// is read, and must name an existing, enabled account, read in <code>%SYS</code> (AD-16).</p>
ClassMethod RunAsProblem(pUser As %String) As %String
{
    If (pUser = "") || ($ZConvert(pUser, "U") = $ZConvert($Username, "U")) Quit ""
    If '$System.Security.Check(..#SECURERESOURCE, "USE") Quit ##class(OcuPilot.Api.Error).#TASKRUNASUSERSECURE
    Set tExists = 0
    Set tEnabled = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(Security.Users).Exists(pUser, .tAccount)
        If tExists && $IsObject($Get(tAccount)) Set tEnabled = ''tAccount.Enabled
        Set tAccount = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    If 'tExists Quit ##class(OcuPilot.Api.Error).#TASKRUNASUSERUNKNOWN
    If 'tEnabled Quit ##class(OcuPilot.Api.Error).#TASKRUNASUSERDISABLED
    Quit ""
}

/// <p>The vendor's export of the tasks <var>pIds</var> names to <var>pFile</var>, in
/// <code>%SYS</code> (AD-16), with <parameter>QSPEC</parameter>. Overridable so a fixture can observe
/// or deny the call; production never overrides it.</p>
ClassMethod VendorExport(pIds As %List, pFile As %String) As %Status [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#TASKCLASS, "ExportTasks", pIds, pFile, ..#QSPEC)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The vendor's import of <var>pFile</var>, in <code>%SYS</code> (AD-16), with
/// <parameter>QSPEC</parameter> and a past start date recomputed forward. Overridable so a fixture can
/// observe or deny the call; production never overrides it.</p>
ClassMethod VendorImport(pFile As %String) As %Status [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#TASKCLASS, "ImportTasks", pFile, ..#QSPEC, 0)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The 403 the gate answers: the admin port's own mapping of 403, with the pair in
/// <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>A 400 refusal on one field, as <var>pCode</var> with its sentence, carried again as that field's
/// one violation (AD-39).</p>
ClassMethod Violation(pCode As %String, pReason As %String, pField As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", pReason, "string")
    Set tDetail = {}
    Do tDetail.%Set("violations", [(tViolation)])
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, pCode, pReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for
/// <parameter>ENDPOINT</parameter>, the task port's answer otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint = ..#ENDPOINT Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): <parameter>EXPORTTYPE</parameter> is the
/// vendor's <code>ExportTasks</code> of the target to the file <code>root</code> and <code>path</code>
/// name, and <parameter>IMPORTTYPE</parameter> its <code>ImportTasks</code> of that file, each in
/// <code>%SYS</code>; a read type writes nothing and answers no step. Every other endpoint is the task
/// port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tFile = ..Literal($Get(pQuery(..#ROOTPARAM)) _ $Get(pQuery(..#PATHPARAM)))
    If pType = ..#EXPORTTYPE {
        Set tLines = $ListBuild("Set tSC = ##class(" _ ..#TASKCLASS _ ").ExportTasks($ListBuild(" _ ..Literal($Get(pQuery(..#IDPARAM))) _ "), " _ tFile _ ", " _ ..Literal(..#QSPEC) _ ")", "Do $System.Status.DisplayError(tSC)")
        Quit [(..ObjectScriptStep(tLines))]
    }
    If pType = ..#IMPORTTYPE {
        Set tLines = $ListBuild("Set tSC = ##class(" _ ..#TASKCLASS _ ").ImportTasks(" _ tFile _ ", " _ ..Literal(..#QSPEC) _ ", 0)", "Do $System.Status.DisplayError(tSC)")
        Quit [(..ObjectScriptStep(tLines))]
    }
    Quit []
}

}
