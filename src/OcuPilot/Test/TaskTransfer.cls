/// <p>Pins Story 16.4's port and tools in process (AD-21, AD-27, AD-51, AD-52): the two tools'
/// declarations; the port's gate; an export that writes one task and replaces a file at the name,
/// refuses each location on its field and deletes only a file its own failed call wrote; an import
/// that refuses a file that is not a task export, refuses the whole file for one task that cannot be
/// created wherever it sits, skips a present task, refuses a file whose every task is present and a
/// changed file; the agent's mints; and both scripts.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot compiled, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes probe
/// tasks named <code>OcuP164*</code> and writes files in the <code>OcuP164</code> directory under the
/// first allowed root (<class>OcuPilot.Test.TaskTransferFixture</class>). Every one is removed after
/// each test, and a test fails if any is left.</p>
Class OcuPilot.Test.TaskTransfer Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TASK_CONTROL";

Parameter PORT = "OcuPilot.Test.TaskTransferFixture";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.TaskExport";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.TaskImport";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskTransfer creates and deletes tasks in this instance's Task Manager and writes files under its first allowed directory, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PORT, "RemoveProbes")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PORT, "RemoveProbes")
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Remove every probe task, file and proposal this test made, and assert none is left.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "RemoveProbes"), "every probe task and file is removed")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Probes"), 0, "and no probe task is left")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The export tool: an action write over the transfer port, reading the task and sending no body,
/// composed from <code>root</code> and <code>path</code>, which it requires; its pairs add
/// <code>%Admin_FileSystemAccess:USE</code> to the screen's; it names the classic action page, and its
/// card says a file at the name is replaced.</p>
Method TestTheExportToolIsAnActionWriteOverTheTransferPort()
{
    Set tTool = ..#EXPORTTOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "SendsBody"), "tasks.schedule.export|OcuPilot.Port.TaskTransferPort|TaskTransfer|TASK|EXPORT|0", "an action write over the transfer port")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "SettableFields")) _ "|" _ $ListToString($ClassMethod(tTool, "FingerprintSubject")), "root,path|Name,TaskClass,NameSpace,root,path", "its arguments are the file, and its subject the task and the file")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionValueNames", "export")), "export|root,path", "the Export row action sends the two values")
    Do ..AssertCommon(tTool)
    Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}), "TASK.EXPORT.REPLACES", "its card says a file at the name is replaced")
    Do $$$AssertEquals($ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "ChangeAction"), "0|updated", "it is not destructive")
}

/// <p>The import tool: an action write over the transfer port, reading the import's one target;
/// <code>tasks</code> is settable and never advertised, so the agent's own <code>tasks</code> is
/// refused by the closed schema.</p>
Method TestTheImportToolIsAnActionWriteOverTheTransferPort()
{
    Set tTool = ..#IMPORTTOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "SendsBody"), "tasks.schedule.import|OcuPilot.Port.TaskTransferPort|TaskTransfer|SCHEDULE|IMPORT|0", "an action write over the transfer port")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "SettableFields")) _ "|" _ $ListToString($ClassMethod(tTool, "FingerprintSubject")), "root,path,tasks,runAs|root,path,tasks,runAs", "its arguments and its subject are the file, the reviewed tasks and the accounts they run as")
    Do ..AssertCommon(tTool)
    Set tSchema = $ClassMethod(tTool, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("properties").%GetTypeOf("tasks") _ "|" _ tSchema.%Get("properties").%GetTypeOf("runAs"), "unassigned|unassigned", "tasks and runAs are never advertised")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"Id": "import", "root": "/r/", "path": "t.xml", "tasks": "A (%SYS)"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "so an agent sending one is refused: " _ $Get(tProblem))
    Do $$$AssertEquals($ClassMethod(tTool, "ChangeAction"), "created", "it publishes created tasks")
}

/// <p>What both tools share: the pairs, the classic page, the composed and mutating pair, the two
/// required arguments, and a governance key in the baseline -- the export's enabled, the import's
/// disabled.</p>
Method AssertCommon(pTool As %String)
{
    Set tPairs = $ClassMethod(pTool, "PrivilegePairs", , .tResolved)
    Set tSpelled = ""
    For tI = 1:1:$ListLength(tPairs) Set tSpelled = tSpelled _ $Select(tSpelled = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
    Do $$$AssertEquals(tSpelled, "%Admin_Task:USE,%DB_IRISSYS:READ,%Admin_FileSystemAccess:USE", pTool _ ": the screen's pairs and PathPort's")
    Do $$$AssertEquals($Parameter(pTool, "CLASSICPAGES"), "%cspapp.op.utilsystaskaction", pTool _ ": the classic action page")
    Set tPair = $ClassMethod(pTool, "Endpoint") _ "/" _ $ClassMethod(pTool, "WriteType")
    Do $$$AssertTrue($ListFind($ListFromString($Parameter("OcuPilot.Port.TaskTransferPort", "COMPOSEDTYPES")), tPair) && ##class(OcuPilot.Port.AdminPort).IsMutating($ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "WriteType")), pTool _ ": a composed, mutating pair")
    Set tRequired = $ClassMethod(pTool, "InputSchema").%Get("required").%ToJSON()
    Do $$$AssertEquals(tRequired, "[""Id"",""root"",""path""]", pTool _ ": the id and the file are required")
    Set tEnabled = (pTool '= ..#IMPORTTOOL)
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed($Parameter(pTool, "TOOLNAME"), .tListed) _ "|" _ tListed, tEnabled _ "|1", pTool _ ": its key is in the baseline, " _ $Select(tEnabled: "enabled", 1: "disabled"))
}

/// <p>AD-29: a caller the port's gate finds without any one of <parameter>OcuPilot.Port.TaskTransferPort.PAIRS</parameter>
/// is refused 403 naming that pair on every type that reaches a file and on the export mint's check,
/// with no vendor call and no file.</p>
Method TestTheGateRefusesAMissingPairBeforeAnyCall()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Set tPairs = $ListFromString($Parameter("OcuPilot.Port.TaskTransferPort", "PAIRS"))
    Do $$$AssertEquals($ListLength(tPairs), 3, "the port declares three pairs")
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        Do $ClassMethod(..#PORT, "DenyPair", tPair)
        For tType = "EXPORT", "IMPORT", "PREVIEW" {
            Set tSC = ..Call(tType, $Select(tType = "EXPORT": 1, 1: "import"), "OcuP164/gate.xml", "", .tResult, .tHttp, .tFault)
            Do $$$AssertEquals(..Denied(tHttp, tFault), "403 PORT.ACCESSDENIED " _ tPair, tType _ " is refused naming " _ tPair)
        }
        Set tSC = $ClassMethod(..#PORT, "CheckExport", ..Root(), "OcuP164/gate.xml", .tHttp, .tFault)
        Do $$$AssertEquals(..Denied(tHttp, tFault), "403 PORT.ACCESSDENIED " _ tPair, "the export mint's check is refused naming " _ tPair)
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "and no vendor call is made")
    Do $$$AssertTrue('##class(%File).Exists(tDirectory _ "gate.xml"), "and no file is written")
}

/// <p>AC1, AD-21: an export writes the vendor's <code>&lt;Tasks&gt;</code> holding exactly that task, a
/// second export onto the same name replaces the file, and a directory under the name is refused
/// <code>PATH.EXISTS</code> on <code>path</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.TaskTransferPort.Locate</method> passes
/// <code>pOverwrite</code> 0 for an export -- the replace leg answers <code>PATH.EXISTS</code> and goes
/// red.</p>
Method TestAnExportWritesTheTaskAndReplacesAFileAtTheName()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "MakeTask", "Exported", .tId, .tGuid), "a probe task is made")
    Set tSC = ..Call("EXPORT", tId, "OcuP164/one.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the export answers 200: " _ ..Text(tFault))
    If $IsObject($Get(tResult)) Do $$$AssertEquals(tResult.%ToJSON(), "{""root"":""" _ ..Root() _ """,""path"":""OcuP164/one.xml""}", "naming the file as the caller did")
    Set tText = $ClassMethod(..#PORT, "FileText", tDirectory _ "one.xml")
    Do $$$AssertTrue((tText [ "<Tasks>") && ($Length(tText, "<Task>") = 2) && (tText [ "<Name>OcuP164Exported</Name>") && (tText [ ("<JobGUID>" _ tGuid _ "</JobGUID>")), "the file holds the vendor's Tasks with exactly that task: " _ $Extract(tText, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "EXPORT " _ tId _ " " _ tDirectory _ "one.xml", "through one vendor export of that task to the resolved file")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "WriteFile", tDirectory _ "one.xml", "OcuP164 stale"), "the file is overwritten with other text")
    Set tSC = ..Call("EXPORT", tId, "OcuP164/one.xml", "", .tResult, .tHttp, .tFault)
    Set tText = $ClassMethod(..#PORT, "FileText", tDirectory _ "one.xml")
    Do $$$AssertEquals(tHttp, 200, "exporting onto the existing file answers 200: " _ ..Text(tFault))
    Do $$$AssertTrue((tText '[ "OcuP164 stale") && (tText [ "<Name>OcuP164Exported</Name>"), "and the file is replaced by the task's export")
    Do ##class(%File).CreateDirectoryChain(tDirectory _ "adir")
    Set tSC = ..Call("EXPORT", tId, "OcuP164/adir", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "400 PATH.EXISTS path", "a directory under the name is refused on path")
}

/// <p>AC4, the matrix's location rows: a root off the list is refused on <code>root</code>; a missing
/// directory, a name directly in the manager directory and a <code>..</code> on <code>path</code>; a
/// task deleted since it was selected is 404. No vendor call is made and no file is written. The
/// agent's mint answers the port's own refusal on its field.</p>
Method TestAnExportRefusesEachLocationOnItsField()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "MakeTask", "Refused", .tId, .tGuid), "a probe task is made")
    Set tCases = $ListBuild($ListBuild("/nowhere/OcuP164/", "t.xml", "400 PATH.ROOT root"), $ListBuild("", "OcuP164/sub/t.xml", "400 TASK.EXPORT.DIRECTORY path"), $ListBuild("", "OcuP164/../t.xml", "400 PATH.NAME path"))
    ; A name directly in the manager directory is reachable only where the manager directory is a root.
    If ##class(%File).NormalizeDirectory(..Root()) = ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory()) Set tCases = tCases _ $ListBuild($ListBuild("", "OcuP164t.xml", "400 PATH.MANAGER path"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tRoot = $Select($List(tCase, 1) = "": ..Root(), 1: $List(tCase, 1))
        Set tSC = ..Call("EXPORT", tId, $List(tCase, 2), "", .tResult, .tHttp, .tFault, tRoot)
        Do $$$AssertEquals(..Said(tHttp, tFault), $List(tCase, 3), $List(tCase, 2) _ " is refused on its field")
    }
    Set tSC = ..Call("EXPORT", 999999999, "OcuP164/gone.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "a task the instance no longer holds is 404")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "no vendor call is made")
    Do $$$AssertTrue('##class(%File).Exists(tDirectory _ "gone.xml") && '##class(%File).Exists(..Root() _ "OcuP164t.xml"), "and no file is written")
    Set tSC = ..Mint(..#EXPORTTOOL, tId, {"Id": (tId), "root": "/nowhere/OcuP164/", "path": "t.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "400 PATH.ROOT root", "the agent's mint answers the port's refusal on root")
    Set tSC = ..Mint(..#EXPORTTOOL, tId, {"Id": (tId), "root": (..Root()), "path": "OcuP164/sub/t.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "400 TASK.EXPORT.DIRECTORY path", "and a missing directory on path")
}

/// <p>The matrix's served-location row and the overwrite's instance-file refusal (AD-21): with
/// OcuPilot's served directory answered as one under the probe directory, an export to a name in it
/// and an import from a file in it are each refused 400 <code>PATH.SERVED</code> on
/// <code>path</code>; with a database directory answered as another, an export onto a file in it is
/// refused <code>PATH.INSTANCE</code> and the file is left as it was. No vendor call is made.</p>
Method TestTheServedDirectoryAndInstanceFilesAreRefused()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "MakeTask", "Served", .tId, .tGuid), "a probe task is made")
    Do ##class(%File).CreateDirectoryChain(tDirectory _ "served")
    Do ##class(%File).CreateDirectoryChain(tDirectory _ "db")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "WriteFile", tDirectory _ "served/in.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "ServedIn"))])), "a task file stands in the served directory")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "WriteFile", tDirectory _ "db/OcuP164.dat", "OcuP164 database"), "and a file in the database directory")
    Do $ClassMethod(..#PORT, "UsePathPortFixture")
    Do ##class(OcuPilot.Test.PathPortFixture).UseServedDirectory(tDirectory _ "served/")
    Do ##class(OcuPilot.Test.PathPortFixture).UseDatabaseDirectories($ListBuild(tDirectory _ "db/"))
    Set tSC = ..Call("EXPORT", tId, "OcuP164/served/out.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "400 PATH.SERVED path", "an export into the served directory is refused on path")
    Set tSC = ..Call("IMPORT", "import", "OcuP164/served/in.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "400 PATH.SERVED path", "and so is an import from it")
    Set tSC = ..Call("EXPORT", tId, "OcuP164/db/OcuP164.dat", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "400 PATH.INSTANCE path", "an export onto a database directory's file is refused on path")
    Do $$$AssertEquals($ClassMethod(..#PORT, "FileText", tDirectory _ "db/OcuP164.dat"), "OcuP164 database", "and the file is left as it was")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "with no vendor call")
    Do $$$AssertTrue('##class(%File).Exists(tDirectory _ "served/out.xml") && ($ClassMethod(..#PORT, "Probes") = 1), "no file is written and no task is imported")
}

/// <p>One file never yields one task twice: a second task holding a name an earlier task of the file
/// takes is refused 422 <code>TASK.NAME.TAKEN</code> naming it, with no vendor call, and a second task
/// holding an earlier one's <code>JobGUID</code> is counted present and left out of the summary, as
/// the vendor skips it.</p>
Method TestAFileNeverYieldsOneTaskTwice()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "twins.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Twin")), ($ClassMethod(..#PORT, "Entry", "Twin"))]))
    Set tSC = ..Call("IMPORT", "import", "OcuP164/twins.xml", "", .tResult, .tHttp, .tFault)
    Set tNamed = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("task"), 1: "")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ " " _ tNamed, "422 TASK.NAME.TAKEN OcuP164Twin", "a name the file already gives is refused")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "with no vendor import")
    Set tGuid = $System.Util.CreateGUID()
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "shared.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "First", , , , tGuid)), ($ClassMethod(..#PORT, "Entry", "Second", , , , tGuid))]))
    Set tSC = ..Call("PREVIEW", "import", "OcuP164/shared.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ..Text(tFault)), "{""tasks"":""" _ ..Line("First") _ """,""runAs"":""" _ $Username _ """,""count"":2,""present"":1}", "a task GUID the file already gives is counted present")
}

/// <p>AD-21: the reader resolves no external entity, so a file under an allowed root cannot pull
/// another file's text into the reviewed summary or a refusal. The file names an external DTD that
/// declares every element it uses and an entity over a sentinel file, the form the reader would
/// otherwise load and resolve.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.TaskTransferPort.FileTasks</method>'s
/// <code>NullEntityResolver</code> -- the summary carries the sentinel and this goes red.</p>
Method TestAnExternalEntityIsNeverResolved()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "sentinel.txt", "OcuP164Sentinel")
    Set tDtd = ""
    For tElement = "Tasks", "Task", "Name", "RunAsUser", "TaskClass", "NameSpace", "TimePeriod", "JobGUID", "StartDate", "Description" {
        Set tDtd = tDtd _ "<!ELEMENT " _ tElement _ " ANY>"
    }
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "probe.dtd", tDtd _ "<!ENTITY probe SYSTEM ""file://" _ tDirectory _ "sentinel.txt"">")
    Set tText = $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Entity"))])
    Set tText = $Replace(tText, "<Tasks>", "<!DOCTYPE Tasks SYSTEM ""file://" _ tDirectory _ "probe.dtd""><Tasks>")
    Set tText = $Replace(tText, "<Name>OcuP164Entity</Name>", "<Name>OcuP164Entity&probe;</Name>")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "entity.xml", tText)
    Set tSC = ..Call("PREVIEW", "import", "OcuP164/entity.xml", "", .tResult, .tHttp, .tFault)
    Set tSaid = $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ..Text(tFault))
    Do $$$AssertTrue((tSaid '= "") && (tSaid '[ "Sentinel"), "the preview carries none of the entity's file: " _ tSaid)
}

/// <p>A failed vendor export deletes a file it wrote at a name that was free, and leaves a file that
/// stood at the name before the call as the call left it; the fault is the normalized 500.</p>
Method TestAFailedExportDeletesOnlyAFileItWrote()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "MakeTask", "Failed", .tId, .tGuid), "a probe task is made")
    Do $ClassMethod(..#PORT, "FailVendor", "OcuP164 partial")
    Set tSC = ..Call("EXPORT", tId, "OcuP164/new.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "500 INTERNAL", "a failed export is the normalized fault")
    Do $$$AssertTrue('##class(%File).Exists(tDirectory _ "new.xml"), "and the file it wrote at a free name is deleted")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "WriteFile", tDirectory _ "kept.xml", "OcuP164 before"), "a file stands at another name")
    Do $ClassMethod(..#PORT, "FailVendor", "OcuP164 partial")
    Set tSC = ..Call("EXPORT", tId, "OcuP164/kept.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 500, "a failed export onto it is refused")
    Do $$$AssertEquals($ClassMethod(..#PORT, "FileText", tDirectory _ "kept.xml"), "OcuP164 partial", "and the file is left as the call left it")
}

/// <p>The matrix's file rows: no file and a directory are <code>PATH.NOFILE</code> on
/// <code>path</code>, and a name directly in the manager directory <code>PATH.MANAGER</code>;
/// unreadable XML, another root element, a file with no task and a task with no name are 422
/// <code>TASK.IMPORT.FILE</code>. No vendor import is made.</p>
Method TestAnImportRefusesAFileThatIsNotATaskExport()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do ##class(%File).CreateDirectoryChain(tDirectory _ "adir")
    Set tCases = $ListBuild($ListBuild("OcuP164/none.xml", "400 PATH.NOFILE path"), $ListBuild("OcuP164/adir", "400 PATH.NOFILE path"))
    ; A name directly in the manager directory is reachable only where the manager directory is a root.
    If ##class(%File).NormalizeDirectory(..Root()) = ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory()) Set tCases = tCases _ $ListBuild($ListBuild("messages.log", "400 PATH.MANAGER path"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tSC = ..Call("IMPORT", "import", $List(tCase, 1), "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(tHttp, tFault), $List(tCase, 2), $List(tCase, 1) _ " is refused on path")
    }
    Set tEntry = $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Other"))])
    Set tNameless = $Replace($ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Nameless"))]), "<Name>OcuP164Nameless</Name>", "")
    For tCase = $ListBuild("bad.xml", "<Tasks><Task>"), $ListBuild("other.xml", $Replace($Replace(tEntry, "<Tasks>", "<Other>"), "</Tasks>", "</Other>")), $ListBuild("empty.xml", "<?xml version=""1.0""?><Tasks/>"), $ListBuild("nameless.xml", tNameless) {
        Do $$$AssertStatusOK($ClassMethod(..#PORT, "WriteFile", tDirectory _ $List(tCase, 1), $List(tCase, 2)), $List(tCase, 1) _ " is written")
        Set tSC = ..Call("IMPORT", "import", "OcuP164/" _ $List(tCase, 1), "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(tHttp, tFault), "422 TASK.IMPORT.FILE ", $List(tCase, 1) _ " is not a task export")
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "and no vendor import is made")
}

/// <p>AC6: a file of three tasks holding one that cannot be created -- its namespace unknown, its class
/// absent, its account unknown, its name held, its name starting with a digit or 51 characters long
/// -- is refused whole with that rule's code and
/// <code>detail.task</code>, wherever the task sits, and no task is created.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.TaskTransferPort.Examine</method> checks only the first
/// task it would create -- the bad-task-last legs go red and tasks are created.</p>
Method TestOneTaskThatCannotBeCreatedImportsNothing()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Set tTaken = ##class(OcuPilot.Test.TaskProbe).VendorName()
    Do $$$AssertTrue(tTaken '= "", "a vendor task's name is read for the taken-name case")
    Set tCases = $ListBuild($ListBuild("Ns", "OCUP164NONE", "%SYS.Task.PurgeTaskHistory", "", "TASK.NAMESPACE.UNKNOWN"), $ListBuild("Cls", "%SYS", "OcuP164.No.Such", "", "TASK.TASKCLASS.UNKNOWN"), $ListBuild("Run", "%SYS", "%SYS.Task.PurgeTaskHistory", "OcuP164NoSuchUser", "TASK.RUNASUSER.UNKNOWN"), $ListBuild("Taken", "%SYS", "%SYS.Task.PurgeTaskHistory", "", "TASK.NAME.TAKEN"), $ListBuild("Digit", "%SYS", "%SYS.Task.PurgeTaskHistory", "", "TASK.NAME.SHAPE"), $ListBuild("Long", "%SYS", "%SYS.Task.PurgeTaskHistory", "", "TASK.NAME.SHAPE"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tBad = $ClassMethod(..#PORT, "Entry", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        If $List(tCase, 1) = "Taken" Do tBad.%Set("Name", tTaken, "string")
        If $List(tCase, 1) = "Digit" Do tBad.%Set("Name", "1OcuP164Digit", "string")
        If $List(tCase, 1) = "Long" Do tBad.%Set("Name", "OcuP164" _ $Translate($Justify("", 44), " ", "x"), "string")
        For tFirst = 0, 1 {
            Set tTasks = [($ClassMethod(..#PORT, "Entry", "Good1")), ($ClassMethod(..#PORT, "Entry", "Good2"))]
            If tFirst {
                Set tTasks = [(tBad), (tTasks.%Get(0)), (tTasks.%Get(1))]
            } Else {
                Do tTasks.%Push(tBad)
            }
            Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "bad.xml", $ClassMethod(..#PORT, "ExportText", tTasks))
            Set tSC = ..Call("IMPORT", "import", "OcuP164/bad.xml", "", .tResult, .tHttp, .tFault)
            Set tNamed = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("task"), 1: "")
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ " " _ tNamed, "422 " _ $List(tCase, 5) _ " " _ tBad.%Get("Name"), $List(tCase, 5) _ " refuses the file with the task " _ $Select(tFirst: "first", 1: "last"))
            If $IsObject(tFault) Do $$$AssertEquals(tFault.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForTask($List(tCase, 5)), "with the rule's own reason")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "no vendor import is made")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Probes"), 0, "and no task is created")
}

/// <p>AC2's all-present row and the summary's shape: a file of three tasks, one already here by its
/// <code>JobGUID</code>, previews <code>Name (NAMESPACE)</code> of the two to create joined by
/// <code>; </code>; the import creates those two and skips the third; the same file again is 409
/// <code>TASK.IMPORT.PRESENT</code>; and a reviewed summary the file no longer yields is 409
/// <code>TASK.IMPORT.CHANGED</code>, with nothing imported.</p>
/// <p>Mutation (Rule 19): drop the present-task skip from
/// <method>OcuPilot.Port.TaskTransferPort.Examine</method> -- the summary names the present task and
/// this goes red.</p>
Method TestAnImportCreatesTheAbsentTasksAndSkipsThePresent()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "MakeTask", "Here", .tId, .tGuid), "a probe task is made")
    Set tFile = $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Here", "%SYS", "%SYS.Task.PurgeTaskHistory", "", tGuid)), ($ClassMethod(..#PORT, "Entry", "New1")), ($ClassMethod(..#PORT, "Entry", "New2"))])
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "WriteFile", tDirectory _ "three.xml", tFile), "a file of three tasks is written")
    Set tSC = ..Call("PREVIEW", "import", "OcuP164/three.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ..Text(tFault)), "{""tasks"":""" _ ..Line("New1") _ "; " _ ..Line("New2") _ """,""runAs"":""" _ $Username _ """,""count"":3,""present"":1}", "the preview names the two to create")
    Set tSC = ..Call("IMPORT", "import", "OcuP164/three.xml", ..Line("Other"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "409 TASK.IMPORT.CHANGED ", "a reviewed summary the file does not yield is refused")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "with no vendor import")
    Set tSC = ..Call("IMPORT", "import", "OcuP164/three.xml", ..Line("New1") _ "; " _ ..Line("New2"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ..Text(tFault)), "{""imported"":2,""skipped"":1}", "the import creates two and skips one")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Probes", .tIds), 3, "three probe tasks stand")
    Do $$$AssertTrue($Data(tIds("OcuP164New1")) && $Data(tIds("OcuP164New2")), "the two the file added among them")
    Set tSC = ..Call("IMPORT", "import", "OcuP164/three.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "409 TASK.IMPORT.PRESENT ", "the same file again is refused")
    Do $$$AssertEquals($Length($ClassMethod(..#PORT, "Calls"), "|"), 1, "with no second vendor import")
}

/// <p>AC5: the import's mint targets <code>import</code> whatever id is sent and carries
/// <code>root</code>, <code>path</code> and the reviewed <code>tasks</code> on its card; a file that is
/// not a task export is refused with the port's own code.</p>
Method TestTheImportMintCarriesTheReviewedTasks()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "one.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Minted"))]))
    Set tSC = ..Mint(..#IMPORTTOOL, "Anything", {"Id": "Anything", "root": (..Root()), "path": "OcuP164/one.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the import mints: " _ ..Text(tFault))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), "import", "its target is the import's own")
    Kill tRow
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tChange) { Set tRow(tChange.%Get("field")) = tChange.%Get("after") }
    Do $$$AssertEquals($Get(tRow("root")) _ "|" _ $Get(tRow("path")) _ "|" _ $Get(tRow("tasks")), ..Root() _ "|OcuP164/one.xml|" _ ..Line("Minted"), "its card shows root, path and the tasks it will create, each with its class and account")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Probes"), 0, "and nothing is imported")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "bad.xml", "<Tasks><Task>")
    Set tSC = ..Mint(..#IMPORTTOOL, "import", {"Id": "import", "root": (..Root()), "path": "OcuP164/bad.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "422 TASK.IMPORT.FILE ", "a file that is not a task export is refused with the port's own code")
}

/// <p>An import whose file holds a task that runs as another account is minted destructive with
/// <code>TASK.RUNSASOTHER</code>, and its card's <code>tasks</code> row names each task's class and
/// account; a file whose tasks all run as the caller is neither.</p>
/// <p>Mutation (Rule 19): drop the import branch (the <code>runAs</code> list) from the task arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> -- the destructive
/// leg goes red.</p>
Method TestAnImportRunningAsAnotherAccountIsMintedDestructive()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Set tOther = $Select($ZConvert($Username, "U") = "_SYSTEM": "Admin", 1: "_SYSTEM")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "other.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Mine")), ($ClassMethod(..#PORT, "Entry", "Theirs", , , tOther))]))
    Set tSC = ..Mint(..#IMPORTTOOL, "import", {"Id": "import", "root": (..Root()), "path": "OcuP164/other.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the import mints: " _ ..Text(tFault))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.TaskCreate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 TASK.RUNSASOTHER", "destructive, naming its consequence")
    Kill tRow
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tChange) { Set tRow(tChange.%Get("field")) = tChange.%Get("after") }
    Do $$$AssertEquals($Get(tRow("tasks")), ..Line("Mine") _ "; " _ ..Line("Theirs", tOther), "its tasks row names each task's class and account")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "mine.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Mine"))]))
    Set tSC = ..Mint(..#IMPORTTOOL, "import", {"Id": "import", "root": (..Root()), "path": "OcuP164/mine.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a file of the caller's own tasks mints: " _ ..Text(tFault))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.TaskCreate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ "|" _ tConsequence, "0|", "a file of the caller's own tasks is neither destructive nor named")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "case.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Mine", , , $ZConvert($Username, "U")))]))
    Set tSC = ..Mint(..#IMPORTTOOL, "import", {"Id": "import", "root": (..Root()), "path": "OcuP164/case.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a file naming the caller's account in another case mints: " _ ..Text(tFault))
    If '$IsObject($Get(tProposal)) Quit
    Do ##class(OcuPilot.Test.TaskCreate).Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ "|" _ tConsequence, "0|", "the account compare ignores case")
}

/// <p>A file rewritten between its preview and its import, keeping each task's name, is refused
/// <code>TASK.IMPORT.CHANGED</code> when a task's account or its class changed, with no vendor import.</p>
/// <p>Mutation (Rule 19): drop <code>TaskClass</code> or <code>RunAsUser</code> from
/// <method>OcuPilot.Port.TaskTransferPort.Examine</method>'s summary -- the matching leg goes red.</p>
Method TestASameNamedRewriteIsRefusedChanged()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Set tOther = $Select($ZConvert($Username, "U") = "_SYSTEM": "Admin", 1: "_SYSTEM")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "as.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Rewritten"))]))
    Set tSC = ..Call("PREVIEW", "import", "OcuP164/as.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the file previews: " _ ..Text(tFault))
    If tHttp '= 200 Quit
    Set tReviewed = tResult.%Get("tasks")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "as.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Rewritten", , , tOther))]))
    Set tSC = ..Call("IMPORT", "import", "OcuP164/as.xml", tReviewed, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "409 TASK.IMPORT.CHANGED ", "a task now running as another account is refused")
    Do $ClassMethod(..#PORT, "WriteFile", tDirectory _ "as.xml", $ClassMethod(..#PORT, "ExportText", [($ClassMethod(..#PORT, "Entry", "Rewritten", , "%SYS.Task.PurgeJournal"))]))
    Set tSC = ..Call("IMPORT", "import", "OcuP164/as.xml", tReviewed, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tHttp, tFault), "409 TASK.IMPORT.CHANGED ", "a task now of another class is refused")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Calls"), "", "with no vendor import")
}

/// <p>The matrix's password row, AD-35: a task holding a password setting is read, minted and answered
/// with no setting at all, and its export holds the settings as the vendor writes them.</p>
/// <p>Mutation (Rule 19): drop <code>WithholdSettings</code> from the task port's read -- the read carries
/// the password and this goes red.</p>
Method TestAPasswordSettingIsExportedButNeverRead()
{
    Set tDirectory = $ClassMethod(..#PORT, "ProbeDirectory")
    Set tPassword = "OcuP164Pw" _ $Random(100000)
    Do $$$AssertStatusOK($ClassMethod(..#PORT, "MakeSecretTask", "Secret", tPassword, .tId), "a diagnostic report task holding a password is made")
    Kill tQuery
    Set tQuery("id") = tId
    Set tSC = $ClassMethod(..#PORT, "Invoke", "TaskTransfer", "TASK", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tRead)) && (tRead.%GetTypeOf("Settings") = "unassigned") && (tRead.%ToJSON() '[ tPassword), "the task's read carries no setting")
    Set tSC = ..Mint(..#EXPORTTOOL, tId, {"Id": (tId), "root": (..Root()), "path": "OcuP164/secret.xml"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the export mints: " _ ..Text(tFault))
    Do $$$AssertTrue($IsObject($Get(tProposal)) && (tProposal.%ToJSON() '[ tPassword), "and its proposal carries no setting")
    Set tSC = ..Call("EXPORT", tId, "OcuP164/secret.xml", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) && (..Text(tResult) '[ tPassword), "the export answers with no setting")
    Do $$$AssertTrue($ClassMethod(..#PORT, "FileText", tDirectory _ "secret.xml") [ "<Settings>", "and the file holds the settings as the vendor writes them")
}

/// <p>AD-59: both writes render as the vendor's own call on the resolved file in <code>%SYS</code>.</p>
Method TestBothScriptsAreTheVendorCalls()
{
    Kill tQuery
    Set tQuery("id") = "7"
    Set tQuery("root") = "/r/"
    Set tQuery("path") = "a/t.xml"
    Set tExport = ##class(OcuPilot.Port.TaskTransferPort).Snippet("TaskTransfer", "EXPORT", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue(tExport [ "##class(%SYS.Task).ExportTasks($ListBuild(""7""), ""/r/a/t.xml"", ""-d"")", "the export's script: " _ tExport)
    Set tImport = ##class(OcuPilot.Port.TaskTransferPort).Snippet("TaskTransfer", "IMPORT", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue(tImport [ "##class(%SYS.Task).ImportTasks(""/r/a/t.xml"", ""-d"", 0)", "the import's script: " _ tImport)
    Do $$$AssertEquals(##class(OcuPilot.Port.TaskTransferPort).SnippetForm("TaskTransfer", "EXPORT") _ "|" _ ##class(OcuPilot.Port.TaskTransferPort).SnippetForm("TaskTransfer", "IMPORT"), "objectscript|objectscript", "both are ObjectScript")
}

/// <p>The summary entry the import reviews for probe task <var>pSuffix</var>: the name, its
/// namespace, its class and the account it runs as (the caller when <var>pRunAs</var> is empty).</p>
ClassMethod Line(pSuffix As %String, pRunAs As %String = "") As %String
{
    Quit "OcuP164" _ pSuffix _ " (%SYS) %SYS.Task.PurgeTaskHistory as " _ $Select(pRunAs = "": $Username, 1: pRunAs)
}

/// <p>The first allowed root.</p>
ClassMethod Root() As %String
{
    Quit $ClassMethod(..#PORT, "FirstRoot")
}

/// <p>One call of the fixture port's <parameter>OcuPilot.Port.TaskTransferPort.ENDPOINT</parameter>
/// <var>pType</var> for target <var>pId</var> and the file <var>pPath</var> under <var>pRoot</var> (the
/// first root when empty), carrying <var>pTasks</var> when it is not empty.</p>
Method Call(pType As %String, pId As %String, pPath As %String, pTasks As %String, Output pResult, Output pHttp As %Integer, Output pFault As %DynamicObject, pRoot As %String = "") As %Status
{
    Kill tQuery
    Set tQuery("id") = pId
    Set tQuery("root") = $Select(pRoot = "": ..Root(), 1: pRoot)
    Set tQuery("path") = pPath
    If pTasks '= "" Set tQuery("tasks") = pTasks
    Set pResult = ""
    Set pFault = ""
    Quit $ClassMethod(..#PORT, "Invoke", "TaskTransfer", pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>The agent's mint of <var>pTool</var> for <var>pId</var> with <var>pArgs</var>, over a completed
/// turn seeded for the caller.</p>
Method Mint(pTool As %String, pId As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set pFault = ""
    Set pHttp = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod($ClassMethod(pTool, "MintClass"), "Mint", $Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", tTurn, pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p><code>&lt;http&gt; &lt;code&gt; &lt;first violation's field&gt;</code> for a refusal.</p>
ClassMethod Said(pHttp As %Integer, pFault) As %String
{
    If '$IsObject(pFault) Quit pHttp _ "  "
    Set tField = ""
    If $IsObject(pFault.%Get("detail")) && $IsObject(pFault.%Get("detail").%Get("violations")) Set tField = pFault.%Get("detail").%Get("violations").%Get(0).%Get("field")
    Quit pHttp _ " " _ pFault.%Get("code") _ " " _ tField
}

/// <p><code>&lt;http&gt; &lt;code&gt; &lt;failed pair&gt;</code> for a refusal.</p>
ClassMethod Denied(pHttp As %Integer, pFault) As %String
{
    If '$IsObject(pFault) Quit pHttp _ "  "
    Set tDetail = pFault.%Get("detail")
    Quit pHttp _ " " _ pFault.%Get("code") _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

/// <p><var>pFault</var> as JSON, or <code>""</code>.</p>
ClassMethod Text(pFault) As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.%ToJSON()
}

}
