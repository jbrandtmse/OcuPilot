/// <p>Pins Story 21.10's audit log export on both callers (AC3, AC6; AD-8, AD-15, AD-21, AD-22, AD-26, AD-53, AD-55)
/// against the real instance: the screen's <code>export</code> action and the agent's mint and confirm each start the
/// vendor's background task, which the Background tasks list shows ending "items exported." with the file written;
/// a file already at the name, a name that climbs out of its directory, a directory that does not exist and a root the
/// instance does not list are each refused before any task starts; the gate names each pair it lacks; and the agent's key
/// ships enabled, so its confirm writes once with one audit marker.</p>
/// <p>Every export is bounded to the records dated before <parameter>BOUNDDAY</parameter>, a day no record of this
/// instance predates, so the class never depends on the size of the audit log or on what earlier runs wrote into it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an allowed directory, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class writes files under the first allowed
/// directory and starts background tasks that write audit records. Every file and directory it makes is named by
/// <method>Directory</method> and removed on every path.</p>
Class OcuPilot.Test.AuditExportWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.AuditPort";

Parameter SEAM = "OcuPilot.Test.AuditExportSeam";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.AuditExport";

Parameter TOOL = "security.auditing.export";

Parameter SCREEN = "security.auditing";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter FIXTURE = "OcuPilot.Test.TaskTransferFixture";

/// <p>The cut-off every export here names: no audit record is dated before it.</p>
Parameter BOUNDDAY = "2000-01-01";

/// <p>The task name the vendor's Background tasks row carries for the export.</p>
Parameter TASKNAME = "Export Audit Log";

/// <p>The most seconds a started export is waited for.</p>
Parameter WAITSECONDS As INTEGER = 90;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditExportWrite writes files under this instance's first allowed directory and starts audit export tasks, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped audit port, so the confirm writes through it.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Do ..RemoveDirectory()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ..RemoveDirectory()
    Do $$$AssertTrue('##class(%File).DirectoryExists(..Absolute()), "the test's directory and every file in it are removed")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ..RemoveDirectory()
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The first allowed directory, as the Allowed directories read lists it.</p>
ClassMethod Root() As %String
{
    Quit $ClassMethod(..#FIXTURE, "FirstRoot")
}

/// <p>The directory this job's exports go in, relative to <method>Root</method>, without a separator.</p>
ClassMethod Directory() As %String
{
    Quit "OcuP2110X" _ $Job
}

/// <p>The directory's absolute path, with its trailing separator.</p>
ClassMethod Absolute() As %String
{
    Quit ##class(%File).NormalizeDirectory(..Root() _ ..Directory())
}

/// <p>Create the directory, answering its absolute path.</p>
ClassMethod MakeDirectory() As %String
{
    Set tDirectory = ..Absolute()
    If '##class(%File).DirectoryExists(tDirectory) Do ##class(%File).CreateDirectoryChain(tDirectory)
    Quit tDirectory
}

/// <p>Remove the directory and everything in it. The directory is named by this job, under the allowed directory.</p>
ClassMethod RemoveDirectory()
{
    If ..Root() = "" Quit
    Set tDirectory = ..Absolute()
    If ##class(%File).DirectoryExists(tDirectory) Do ##class(%File).RemoveDirectoryTree(tDirectory)
}

/// <p>The relative name of <var>pFile</var> in this job's directory.</p>
ClassMethod Name(pFile As %String) As %String
{
    Quit ..Directory() _ "/" _ pFile
}

/// <p>Wait past the second the last export may have started in. The vendor's job list keys its rows by start time to the second and
/// reads the first job of each second only, so two exports started in one second show one row.</p>
ClassMethod Spaced()
{
    Hang 1.1
}

/// <p>The ids of the Background tasks rows of the export task now, as <code>ids(id) = ""</code>.</p>
ClassMethod KnownRows(Output pIds)
{
    Kill pIds
    Kill tQuery
    Set tQuery("maxRows") = 500
    Set tSC = ##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Task") = ..#TASKNAME Set pIds(tRow.%Get("Id")) = ""
    }
}

/// <p>The export row a call started, the newest of the export task's rows that <var>pBefore</var> did not hold, once its
/// details read "items exported." or its status reads ERROR; waits at most <parameter>WAITSECONDS</parameter>. Answers
/// <code>ended</code> for the first, <code>failed</code> for the second, or <code>none</code> or <code>running</code> when
/// nothing ended in time.</p>
ClassMethod EndedRow(ByRef pBefore, Output pDetails As %String) As %String
{
    Set pDetails = ""
    Set tVerdict = "none"
    Set tUntil = $ZHorolog + ..#WAITSECONDS
    For {
        Kill tQuery
        Set tQuery("maxRows") = 500
        Set tSC = ##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISOK(tSC) && $IsObject($Get(tRows)) {
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If (tRow.%Get("Task") '= ..#TASKNAME) || $Data(pBefore(tRow.%Get("Id"))) Continue
                Set pDetails = tRow.%Get("Details")
                Set tVerdict = "running"
                If pDetails [ "items exported." {
                    Set tVerdict = "ended"
                } ElseIf tRow.%Get("Status") [ "ERROR" {
                    Set tVerdict = "failed"
                }
                Quit
            }
        }
        If (tVerdict = "ended") || (tVerdict = "failed") || ($ZHorolog > tUntil) Quit
        Hang 0.25
    }
    Quit tVerdict
}

/// <p>Send the screen action <code>export</code> for <var>pPath</var> under <var>pRoot</var> and the cut-off
/// <var>pBefore</var>; the unparsed envelope is in <var>pAnswer</var> and the parsed one in <var>pParsed</var>, and the
/// answer is the HTTP status.</p>
ClassMethod Act(pRoot As %String, pPath As %String, pBefore As %String, Output pParsed As %DynamicObject) As %Integer
{
    Set tValues = {}
    Do tValues.%Set("ExportRoot", pRoot, "string")
    Do tValues.%Set("ExportPath", pPath, "string")
    Do tValues.%Set("ExportBefore", pBefore, "string")
    Set tBody = {"action": "export", "id": "SYSTEM"}
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set pParsed = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The port's export of <var>pPath</var> under <var>pRoot</var> through <var>pPort</var>, answering
/// <code>http code field</code> of its first violation, or <code>http</code> alone when it started; the answer object is in
/// <var>pResult</var>.</p>
ClassMethod Export(pPort As %String, pRoot As %String, pPath As %String, pBefore As %String, Output pResult) As %String
{
    Kill tQuery
    Set tQuery("ExportRoot") = pRoot
    Set tQuery("ExportPath") = pPath
    Set tQuery("ExportBefore") = pBefore
    Set tSC = $ClassMethod(pPort, "Invoke", "Security.Audit.Record", "EXPORT", .tQuery, "", .pResult, .tHttp, .tFault)
    If $$$ISOK(tSC) Quit +$Get(tHttp)
    Set tViolation = ""
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) && (tFault.%Get("detail").%GetTypeOf("violations") = "array") Set tViolation = tFault.%Get("detail").%Get("violations").%Get(0)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ $Select($IsObject(tViolation): " " _ tViolation.%Get("field"), 1: "")
}

/// <p>The parsed answer's refusal code, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Whether <var>pFile</var> stands and reads as the vendor's export document.</p>
ClassMethod IsExportFile(pFile As %String) As %Boolean
{
    If '##class(%File).Exists(pFile) Quit 0
    Quit ($ClassMethod(..#FIXTURE, "FileText", pFile) [ "<AuditExport")
}

/// <p>AC3, AD-26. Each caller starts the vendor's export task for a new file under the allowed directory, answered as
/// started and never as finished: the screen's action answers 200 <code>updated</code> that continues with an unchecked
/// read-back, and the port's own answer is 202 with the Background tasks row's id. Each row ends "items exported." and
/// the file holds the vendor's export document.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.AuditPort</class>'s <code>VendorStart</code> sends the cut-off as the
/// begin day in place of the end day -> the file never starts and this goes red.</p>
Method TestEachCallerStartsTheExportAndTheFileHoldsIt()
{
    Set tRoot = ..Root()
    Do $$$AssertTrue(tRoot '= "", "the instance lists an allowed directory to export under")
    If tRoot = "" Quit
    Do ..MakeDirectory()
    Kill tBefore
    Do ..Spaced()
    Do ..KnownRows(.tBefore)
    Set tStatus = ..Act(tRoot, ..Name("screen.xml"), ..#BOUNDDAY, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ tAnswer.%Get("action") _ "|" _ tAnswer.%Get("continues") _ "|" _ tAnswer.%Get("readBack").%Get("verdict"), "200|updated|1|unchecked", "the screen's export answers started: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(..EndedRow(.tBefore, .tDetails), "ended", "its Background tasks row ends: " _ tDetails)
    Do $$$AssertTrue($Match(" " _ tDetails, ".* 0 items exported\..*"), "reading 0 items exported. for a day no record predates: " _ tDetails)    Do $$$AssertTrue(..IsExportFile(..Absolute() _ "screen.xml"), "and the file holds the export document")
    Kill tBefore
    Do ..Spaced()
    Do ..KnownRows(.tBefore)
    Set tHttp = ..Export(..#PORT, tRoot, ..Name("port.xml"), ..#BOUNDDAY, .tResult)
    Do $$$AssertEquals(tHttp, 202, "the port answers 202 started")
    Set tId = $Select($IsObject($Get(tResult)): tResult.%Get("id"), 1: "")
    Do $$$AssertEquals($ListGet(##class(OcuPilot.Kernel.EntityId).SplitComposite(tId), 1), ##class(OcuPilot.Port.BackgroundTaskPort).#SOURCEPORTAL, "carrying the Background tasks row's composite id: " _ tId)
    Do $$$AssertEquals(..EndedRow(.tBefore, .tPortDetails), "ended", "whose row ends: " _ tPortDetails)
    Do $$$AssertTrue($Match(" " _ tPortDetails, ".* 0 items exported\..*"), "reading 0 items exported. as well: " _ tPortDetails)
    Do $$$AssertTrue(..IsExportFile(..Absolute() _ "port.xml"), "and the file holds the export document")
    Do $$$AssertEquals(..Export(..#PORT, tRoot, ..Name("port.xml"), ..#BOUNDDAY, .tAgain), "400 PATH.EXISTS ExportPath", "the same name is then refused")
}

/// <p>AC3, AD-21. A file already at the name, a name that climbs out of its directory, a directory the allowed directory
/// does not hold, a root the instance does not list and a cut-off that is no day are each refused before any task starts,
/// on the field they are about, through the port and through the screen's action, and the file that stood is untouched. A
/// name in a directory that exists starts the task.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.AuditPort</class>'s <code>ExportFile</code> passes overwrite as 1 to
/// <code>PathPort.Resolve</code> -> the existing-file leg goes red, because the port starts a task over the file.</p>
Method TestAnExistingFileAndABadNameOrDirectoryAreRefusedBeforeAnyTaskStarts()
{
    Set tRoot = ..Root()
    If tRoot = "" Quit
    Do ..MakeDirectory()
    Set tHeld = ..Absolute() _ "held.xml"
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "WriteFile", tHeld, "held text"), "a file to hold")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    For tPair = "%Admin_Secure", "%DB_IRISSYS", "%DB_IRISAUDIT" Do ##class(OcuPilot.Test.ScreenGate).Hold(tPair, $Case(tPair, "%Admin_Secure": "USE", : "READ"))
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_FileSystemAccess", "USE")
    Do $$$AssertEquals(..Export(..#SEAM, tRoot, ..Name("held.xml"), "", .tResult), "400 PATH.EXISTS ExportPath", "a file already at the name is refused on its path")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "FileText", tHeld), "held text", "and the file is as it was")
    Do $$$AssertEquals(..Export(..#SEAM, tRoot, ..Directory() _ "/../x.xml", "", .tResult), "400 PATH.NAME ExportPath", "a name that climbs is refused on its path")
    Do $$$AssertEquals(..Export(..#SEAM, tRoot, "OcuP2110Missing" _ $Job _ "/x.xml", "", .tResult), "400 AUDIT.EXPORT.DIRECTORY ExportPath", "a directory the allowed directory does not hold is refused on its path")
    Do $$$AssertEquals(..Export(..#SEAM, "/nowhere/OcuP2110/", "x.xml", "", .tResult), "400 PATH.ROOT ExportRoot", "a root the instance does not list is refused on its root")
    Do $$$AssertEquals(..Export(..#SEAM, tRoot, ..Name("day.xml"), "2026-13-45", .tResult), "400 PORT.VALIDATION", "a cut-off that is no day is refused")
    Do $$$AssertEquals(..Export(..#SEAM, tRoot, ..Name("day.xml"), "tomorrow", .tResult), "400 PORT.VALIDATION", "and one that is not written as a day")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no task was started by any of them")
    Do $$$AssertEquals(..Export(..#SEAM, tRoot, ..Name("new.xml"), "", .tResult), 202, "a new name starts the task, with no cut-off meaning every record")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), ..Absolute() _ "new.xml|", "which is the one call, naming the resolved file and no day")
    Do $ClassMethod(..#SEAM, "Reset")
    Set tStatus = ..Act(tRoot, ..Name("held.xml"), ..#BOUNDDAY, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "400|PATH.EXISTS", "the screen's export of the held name is refused 400: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.%Get("detail").%Get("violations").%Get(0).%Get("field"), "ExportPath", "on its path field")
    Set tStatus = ..Act(tRoot, "OcuP2110Missing" _ $Job _ "/x.xml", ..#BOUNDDAY, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "400|AUDIT.EXPORT.DIRECTORY", "and a missing directory")
    Set tStatus = ..Act(tRoot, ..Name("day.xml"), "2999-01-01", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "400|" _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "and a cut-off in the future")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "FileText", tHeld), "held text", "the held file is still as it was")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertEquals(..Called(tRoot, ..Name("held.xml"), ..#BOUNDDAY, .tContent), "refused", "the agent's call naming the held name is refused before a proposal is stored: " _ tContent)
    Do $$$AssertTrue(tContent [ "PATH.EXISTS", "on the port's own code: " _ tContent)
    Do $$$AssertEquals(..Called(tRoot, "OcuP2110Missing" _ $Job _ "/x.xml", ..#BOUNDDAY, .tContent), "refused", "so is a call naming a directory that does not exist: " _ tContent)
    Do $$$AssertTrue(tContent [ "AUDIT.EXPORT.DIRECTORY", "on its own code: " _ tContent)
    Do $$$AssertEquals(..Called(tRoot, ..Name("x.xml"), "soon", .tContent), "refused", "and a cut-off that is no day: " _ tContent)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "FileText", tHeld), "held text", "the held file is still as it was")
}

/// <p>The agent's call of the export for the file <var>pPath</var> under <var>pRoot</var> and the cut-off
/// <var>pBefore</var>, through the shipped dispatch: <code>minted</code> with the proposal's id in
/// <var>pProposalId</var> and the turn's key in <var>pTurnKey</var>, or <code>refused</code>; the tool result's text is in
/// <var>pContent</var>.</p>
ClassMethod Called(pRoot As %String, pPath As %String, pBefore As %String, Output pContent As %String, Output pProposalId As %String, Output pTurnKey As %String) As %String
{
    Set pContent = ""
    Set pProposalId = ""
    Set tInput = {"Name": "SYSTEM", "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("ExportRoot", pRoot, "string")
    Do tInput.%Set("ExportPath", pPath, "string")
    Do tInput.%Set("ExportBefore", pBefore, "string")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_export"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOL), "string")
    Do tUse.%Set("input", tInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set pContent = tResults.%Get(0).%Get("content")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(pContent)
    If $IsObject(tParsed) Set pProposalId = tParsed.%Get("proposalId")
    Quit $Select(pProposalId '= "": "minted", 1: "refused")
}

/// <p>AC3, AD-29, AD-8. The export's gate names each pair it lacks, in order, with 403 <code>PORT.ACCESSDENIED</code> and
/// the pair in <code>detail.failedPair</code>, before the file is resolved or any task starts: the screen's two, the file
/// system pair and the audit database pair the task reads.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISAUDIT:READ</code> from <parameter>OcuPilot.Port.AuditPort.EXPORTPAIRS</parameter>
/// -> the audit database leg goes red.</p>
Method TestTheGateNamesEachPairTheCallerLacks()
{
    Set tRoot = ..Root()
    If tRoot = "" Quit
    Set tPairs = $ListFromString($Parameter(..#PORT, "EXPORTPAIRS"))
    Do $$$AssertEquals($ListToString(tPairs), "%Admin_Secure:USE,%DB_IRISSYS:READ,%DB_IRISAUDIT:READ,%Admin_FileSystemAccess:USE", "the export declares the screen's pairs, the audit database and the file system")
    For tLacking = 1:1:$ListLength(tPairs) {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do $ClassMethod(..#SEAM, "Reset")
        For tI = 1:1:$ListLength(tPairs) {
            If tI = tLacking Continue
            Set tPair = $List(tPairs, tI)
            Do ##class(OcuPilot.Test.ScreenGate).Hold($Piece(tPair, ":", 1), $Piece(tPair, ":", 2))
        }
        Kill tQuery
        Set tQuery("ExportRoot") = tRoot
        Set tQuery("ExportPath") = ..Name("gate.xml")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.Audit.Record", "EXPORT", .tQuery, "", .tResult, .tHttp, .tFault)
        Set tFailed = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("failedPair"), 1: "")
        Do $$$AssertEquals(+$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ tFailed, "403|" _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ "|" _ $List(tPairs, tLacking), "a caller lacking " _ $List(tPairs, tLacking) _ " is refused naming it")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and no task starts")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertTrue($ListFind($ClassMethod(..#TOOLCLASS, "PrivilegePairs"), $ListBuild("%DB_IRISAUDIT", "READ")) > 0, "the tool declares the audit database pair too, so the agent's card and the screen's gate name it")
    Do $$$AssertTrue($ListFind($ClassMethod(..#TOOLCLASS, "PrivilegePairs"), $ListBuild("%Admin_FileSystemAccess", "USE")) > 0, "and the file system pair")
}

/// <p>AC3, AC6. The tool is a bodyless, non-destructive action-style write over <code>Security.Audit.Record</code>
/// <code>EXPORT</code> through the audit port, advertised and enabled by the baseline: a model's call mints a proposal that
/// carries the export's consequence, and its confirm starts the task once, with one write-kind ledger row carrying the audit
/// marker; the token is spent, so a second confirm is refused and starts nothing more. A person's action is not
/// governed (AD-22).</p>
/// <p>Mutation (Rule 19): <code>security.auditing.export</code> set <code>false</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -> the minted assertion goes red.</p>
Method TestTheAgentsConfirmStartsTheExportOnceWithOneAuditMarker()
{
    Set tRoot = ..Root()
    If tRoot = "" Quit
    Do ..MakeDirectory()
    Set tClass = ..#TOOLCLASS
    Do $$$AssertEquals($ClassMethod(tClass, "Advertised"), 1, "the tool is advertised")
    Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType") _ " " _ $ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "Destructive"), "OcuPilot.Port.AuditPort Security.Audit.Record DATABASE EXPORT 0 0", "behind the audit port, bodyless and not destructive")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")) _ " " _ $ListToString($ClassMethod(tClass, "FingerprintSubject")), "ExportRoot,ExportPath,ExportBefore ExportRoot,ExportPath,ExportBefore", "admitting and fingerprinting the file and the day")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard holds adequate")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ " " _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "export")), "export ExportRoot,ExportPath,ExportBefore", "carrying the screen's export action and its three values")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed(..#TOOL, .tListed) _ "|" _ tListed, "1|1", "the baseline lists the key and ships it enabled")
    Do $$$AssertEquals(..Called(tRoot, ..Name("agent.xml"), ..#BOUNDDAY, .tContent, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the baseline lets the call mint a proposal: " _ tContent)
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposalId, .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence")), "0|" _ $Parameter(..#TOOLCLASS, "CONSEQUENCE"), "carrying the export's consequence and no destructive mark")
    Do ..Spaced()
    Kill tBefore
    Do ..KnownRows(.tBefore)
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tResult)), "its confirm is accepted: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("continues"), 1: ""), 1, "and answers that the task continues")
    Do $$$AssertEquals(..EndedRow(.tBefore, .tDetails), "ended", "its Background tasks row ends: " _ tDetails)
    Do $$$AssertTrue($Match(" " _ tDetails, ".* 0 items exported\..*"), "reading 0 items exported. as well: " _ tDetails)
    Do $$$AssertTrue(..IsExportFile(..Absolute() _ "agent.xml"), "the file holds the export document")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow) _ "|" _ $Get(tRow("AuditMarked")), "1|" _ $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "one write-kind ledger row records it, and the agent's audit marker landed on it")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertTrue($$$ISERR(tSC), "a second confirm of the same proposal is refused")
    Kill tAfter
    Do ..KnownRows(.tAfter)
    Set tN = 0
    Set tId = ""
    For {
        Set tId = $Order(tAfter(tId))
        If tId = "" Quit
        If '$Data(tBefore(tId)) Set tN = tN + 1
    }
    Do $$$AssertEquals(tN, 1, "and the second starts no other task: one export row since the confirm")
}

}
