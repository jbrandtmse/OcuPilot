/// <p>Pins Story 16.5's Background tasks list, its port and its three control tools over armed
/// answers (AD-5, AD-8, AD-13, AD-27, AD-29, AD-51, AD-52, AD-53, AD-59): what
/// <class>OcuPilot.Screen.Descriptor.BackgroundTaskList</class> and the tools declare, the port's
/// merge of both halves and its gate, the exact composite fresh read, each half's after-state, the
/// fingerprint, the refusal of a portal job with no background task, the one published refusal for
/// every vendor state refusal, the mint's refusal of the composite separator, and the script each
/// half renders.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%All</code>. Every read and control goes through
/// <class>OcuPilot.Test.BackgroundTaskFixture</class>, so no task on the instance is read or
/// touched; the proposals it mints are removed with their turns.</p>
Class OcuPilot.Test.BackgroundTasks Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.BackgroundTaskList";

Parameter PORT = "OcuPilot.Port.BackgroundTaskPort";

Parameter FIXTURE = "OcuPilot.Test.BackgroundTaskFixture";

Parameter MINT = "OcuPilot.Test.BackgroundTaskMintFixture";

Parameter CONFIRM = "OcuPilot.Test.BackgroundTaskConfirm";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The three tools, each <code>&lt;tool&gt;:&lt;class&gt;:&lt;type&gt;:&lt;admin after&gt;:&lt;portal after&gt;</code>.</p>
Parameter TOOLS = "tasks.background.cancel:OcuPilot.Screen.Tool.BackgroundTaskCancel:CANCEL:Canceled:Cancelled,tasks.background.pause:OcuPilot.Screen.Tool.BackgroundTaskPause:PAUSE:Paused:Paused,tasks.background.resume:OcuPilot.Screen.Tool.BackgroundTaskResume:RESUME:Running:Running";

/// <p>An admin API task's GUID with a leading zero, and the same digits without it.</p>
Parameter GUID = "017554710289124756585573";

Parameter GUIDTRIMMED = "17554710289124756585573";

/// <p>The sentence <code>TASK.BACKGROUND.STATE</code> is published with in EXPERIENCE.md's Fixed
/// strings.</p>
Parameter PUBLISHED = "This background task's current state does not allow that.";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).Clear()
    Quit $$$OK
}

/// <p>AD-5, AD-8: the list is the Tasks area's fifth screen over the port's own source, keyed by
/// source and id, declaring <code>%Admin_Operate:USE</code> as its own pair beside the database
/// read, and carrying three row actions no rule protects; its read tool is registered.</p>
/// <p>Mutation (Rule 19): drop <code>ownPrivileges</code> from the descriptor -- the registry
/// refuses the area coverage and the own-pair legs go red.</p>
Method TestTheDescriptorDeclaresTheListItsPairsAndItsActions()
{
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.route _ " " _ tDeclaration.area _ " " _ tDeclaration.sideBarPosition _ " " _ tDeclaration.toolIdentifier, "tasks/background tasks 5 tasks.background", "the fifth Tasks entry, reading as tasks.background")
    Do $$$AssertEquals(tDeclaration.entityType _ " " _ tDeclaration.scope _ " " _ tDeclaration.id.%ToJSON(), "background-task instance {""kind"":""composite"",""parts"":[""Source"",""Id""]}", "an instance-scoped background task keyed by its source and id")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "requiring the control pair and the database read")
    Do $$$AssertEquals($Select($IsObject(tDeclaration.ownPrivileges): tDeclaration.ownPrivileges.%ToJSON(), 1: ""), "[{""resource"":""%Admin_Operate"",""permission"":""USE""}]", "the first of which is the screen's own, beyond the area's")
    Do $$$AssertEquals(tDeclaration.rowActions.%ToJSON(), "[{""id"":""cancel"",""selfProtection"":""""},{""id"":""pause"",""selfProtection"":""""},{""id"":""resume"",""selfProtection"":""""}]", "three row actions, none self-protected")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""background"",""endpoint"":""BackgroundTask"",""type"":""LIST""}", "read through the background task port")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Source"",""Id"",""Task"",""Namespace"",""Status"",""Details"",""ErrorCount"",""StartTime""]", "declaring the eight fields")
    Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), "all of them as context, none secret")
    Do $$$AssertEquals(tDeclaration.read.sort.default _ " " _ tDeclaration.read.sort.direction, "StartTime desc", "newest start first")
    Do $$$AssertEquals(tDeclaration.table.columns.%Get(0).field _ " " _ tDeclaration.table.columns.%Get(0).kind _ " " _ tDeclaration.table.columns.%Get(2).field _ " " _ tDeclaration.table.columns.%Get(2).kind, "Task name Status status", "the task as the name column and a status column")
    Do $$$AssertEquals(tDeclaration.classicPage, "%CSP.UI.Portal.BackgroundTaskList", "replacing the classic Background Tasks page")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "carrying three suggested prompts")
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("tasks", $ClassMethod(..#SCREEN, "PrivilegePairs"), $ClassMethod(..#SCREEN, "OwnPrivilegePairs")), "", "the area covers every pair but the screen's own")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("tasks", $ClassMethod(..#SCREEN, "PrivilegePairs")), "", "and %Admin_Operate:USE is not the area's, so the screen alone gates on it")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("tasks.background.read", .tRead)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tRead) && (tRead.kind = "read") && (tRead.descriptor = ..#SCREEN), "its read tool is registered")
}

/// <p>AD-51, AD-52, AD-8: each tool is a bodyless, non-destructive action write through the port,
/// fingerprinted over <code>Status</code>, requiring the screen's own pairs and nothing more, taking
/// the source as an enum and the id as a string, carrying its row action, and governed by a key
/// that ships enabled. The port admits each pair bodyless and issues <code>AsyncResult</code>'s.</p>
Method TestTheToolsAreActionWritesOverTheScreensOwnPairs()
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tEntry = $Piece(..#TOOLS, ",", tI)
        Set tName = $Piece(tEntry, ":", 1)
        Set tClass = $Piece(tEntry, ":", 2)
        Set tType = $Piece(tEntry, ":", 3)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tTool) && (tTool.class = tClass) && (tTool.kind = "write"), tName _ " is registered as a write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType") _ " " _ $ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "Destructive"), ..#PORT _ " LIST " _ tType _ " 0 0", tName _ ": a bodyless, non-destructive " _ tType _ " through the port, read from its list")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "IdParam") _ " " _ $ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "MintClass"), "BackgroundTask id id OcuPilot.Screen.Tool.BackgroundTaskMint", tName _ ": addressing the composite id, minted by the joining mint")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")) _ " " _ $ClassMethod(tClass, "PreconditionField"), "Status Status", tName _ ": fingerprinted over the status its precondition reads")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": which the registration guard holds adequate")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, tName _ ": admitting no settable field")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), $ZConvert(tType, "L"), tName _ ": carrying its row action")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PrivilegePairs")), $ListToString($ClassMethod(..#SCREEN, "PrivilegePairs")), tName _ ": requiring the screen's own pairs and nothing more")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Do $$$AssertEquals(##class(OcuPilot.Test.DeviceCreate).Keys(tSchema.%Get("properties")) _ " " _ tSchema.%Get("required").%ToJSON(), "expectedImpact,id,rationale,reverse,source [""id"",""source""]", tName _ ": the schema is the id, the source and the agent's own words")
        Do $$$AssertEquals(tSchema.%Get("properties").%Get("source").%Get("enum").%ToJSON(), "[""Management Portal"",""Admin API""]", tName _ ": the source is one of the two words")
        Do $$$AssertTrue(tSchema.%Get("properties").%Get("id").%Get("description") [ "leading zeros included", tName _ ": whose id description asks for it as a string, leading zeros included")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("BackgroundTask", tType) && ##class(OcuPilot.Port.AdminPort).IsBodyless("BackgroundTask", tType), tName _ ": the port admits the pair as a bodyless write")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("AsyncResult", tType) && ##class(OcuPilot.Port.AdminPort).IsBodyless("AsyncResult", tType) && ($ListFind($ListFromString($Parameter(..#PORT, "DELEGATEDTYPES")), "AsyncResult/" _ tType) > 0), tName _ ": and the admin half's AsyncResult pair it delegates")
        Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tKeys) && (tKeys.%GetTypeOf(tName) = "boolean") && tKeys.%Get(tName), tName _ ": its governance key ships enabled")
    }
}

/// <p>AD-27, AD-36: the list merges both halves newest start first, each row naming its source; an
/// admin row maps <code>GUID</code>, <code>TaskName</code>, <code>State</code>,
/// <code>FailureReason</code> and <code>TimeStarted</code> and answers no namespace or error count;
/// a portal row's background task id is never answered; the cap applies to the merged rows. A
/// caller missing a pair is refused by name before either half is read.</p>
/// <p>Mutation (Rule 19): skip the admin half in
/// <method>OcuPilot.Port.BackgroundTaskPort.Rows</method> -- the merge legs go red.</p>
Method TestTheListMergesBothHalvesNewestFirst()
{
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4242", "Paused", "7", "2026-09-28 12:00:05"), ..PortalRow("4243", "Done", "", "2026-09-28 11:00:00")))
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmAdmin(..Rows(..AdminRow(..#GUID, "Running", "2026-09-28 12:30:00")))
    Kill tQuery
    Set tQuery("maxRows") = 5
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "BackgroundTask", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list answers")
    If $$$ISERR(tSC) Quit
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: "|") _ tRow.%Get("Source") _ "/" _ tRow.%Get("Id") _ "/" _ tRow.%Get("Status") _ "/" _ tRow.%Get("Namespace") _ "/" _ tRow.%Get("ErrorCount")
    }
    Do $$$AssertEquals(tText, "Admin API/" _ ..#GUID _ "/Running//|Management Portal/4242/Paused/%SYS/1|Management Portal/4243/Done/%SYS/1", "both halves, newest start first, the admin row's namespace and error count empty")
    Set tAdmin = tRows.%Get(0)
    Do $$$AssertEquals(tAdmin.%GetTypeOf("Id") _ " " _ tAdmin.%Get("Task") _ " " _ tAdmin.%Get("Details") _ " " _ tAdmin.%Get("StartTime"), "string POST /v2/database-dir/compact the probe's reason 2026-09-28 12:30:00", "the admin row's GUID a string, its task name, failure reason and start")
    Do $$$AssertEquals(##class(OcuPilot.Test.DeviceCreate).Keys(tRows.%Get(1)), "Details,ErrorCount,Id,Namespace,Source,StartTime,Status,Task", "a portal row answers the declared fields and no background task id")
    Set tQuery("maxRows") = 2
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "BackgroundTask", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size() _ " " _ tRows.%Get(1).%Get("Id"), 1: ""), "2 4242", "the cap applies to the merged rows, keeping the newest")

    For tPair = "%Admin_Operate:USE", "%DB_IRISSYS:READ" {
        Do ##class(OcuPilot.Test.BackgroundTaskFixture).Clear()
        Do ##class(OcuPilot.Test.BackgroundTaskFixture).DenyPair(tPair)
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "BackgroundTask", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " " _ tPair, "a caller missing " _ tPair _ " is refused naming it")
        Do $$$AssertEquals(##class(OcuPilot.Test.BackgroundTaskFixture).Reads(), 0, "before either half is read")
    }
}

/// <p>AD-13: the mint refuses a <code>source</code> or <code>id</code> carrying the composite
/// separator, U+0001, with 400 <code>TOOL.ARGUMENTS</code> before either half is read, so one
/// argument cannot stand for two parts.</p>
/// <p>Mutation (Rule 19): delete the separator refusal from
/// <method>OcuPilot.Screen.Tool.BackgroundTaskMint.Mint</method> -- the three-part id reads as absent,
/// the refusal names no separator, and this goes red.</p>
Method TestTheMintRefusesTheSeparatorInAnArgument()
{
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4242", "Running", "7", "2026-09-28 12:00:05")))
    For tCase = $ListBuild("Management Portal" _ $Char(1) _ "4242", "4242"), $ListBuild("Management Portal", "42" _ $Char(1) _ "42") {
        Set tSC = ..MintFor("tasks.background.pause", $List(tCase, 1), $List(tCase, 2), "", .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1 400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "an argument carrying the separator is refused as the arguments' fault")
        Set tProblem = $Select($IsObject($Get(tFault)) && $IsObject(tFault.detail): tFault.detail.problem, 1: "")
        Do $$$AssertTrue(tProblem [ "U+0001", "naming the separator, not a target the list lacks: " _ tProblem)
        Do $$$AssertEquals(##class(OcuPilot.Test.BackgroundTaskFixture).Reads(), 0, "before either half is read")
    }
}

/// <p>AD-13: the fresh read answers the one row whose source and id equal the composite id's parts
/// exactly -- a GUID's leading zero included -- and 404 otherwise; the source is part of the
/// key.</p>
/// <p>Mutation (Rule 19): compare the id numerically in
/// <method>OcuPilot.Port.BackgroundTaskPort.Find</method> (<code>+Id = +tId</code>) -- the trimmed
/// GUID leg goes red.</p>
Method TestTheFreshReadComparesTheCompositeIdExactly()
{
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4242", "Paused", "7", "2026-09-28 12:00:05")))
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmAdmin(..Rows(..AdminRow(..#GUID, "Running", "2026-09-28 12:30:00")))
    For tCase = $ListBuild("Admin API", ..#GUID, 1), $ListBuild("Admin API", ..#GUIDTRIMMED, 0), $ListBuild("Management Portal", "4242", 1), $ListBuild("Admin API", "4242", 0), $ListBuild("Management Portal", ..#GUID, 0), $ListBuild("Nowhere", "4242", 0) {
        Set tKey = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild($List(tCase, 1), $List(tCase, 2)))
        Kill tQuery
        Set tQuery("id") = tKey
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadTarget("OcuPilot.Screen.Tool.BackgroundTaskPause", ..#FIXTURE, "BackgroundTask", .tQuery, tKey, .tFresh, .tHttp, .tFault)
        If $List(tCase, 3) {
            Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tFresh) && (tFresh.Source = $List(tCase, 1)) && (tFresh.Id = $List(tCase, 2)), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " reads its own row")
        } Else {
            Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1 404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is absent")
        }
    }
}

/// <p>AD-51: each tool's one card row is <code>Status</code> moving to its own after-state, spelled
/// as each half spells it; a row naming no source, or reading no status, is a problem. The state
/// itself is not judged here.</p>
Method TestTheStateDiffSpellsEachHalfsOwnState()
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tEntry = $Piece(..#TOOLS, ",", tI)
        Set tClass = $Piece(tEntry, ":", 2)
        For tHalf = $ListBuild("Admin API", $Piece(tEntry, ":", 4)), $ListBuild("Management Portal", $Piece(tEntry, ":", 5)) {
            Set tRow = {"Status": "Done"}
            Do tRow.%Set("Source", $List(tHalf, 1), "string")
            Set tSC = $ClassMethod(tClass, "StateDiff", tRow, .tRows, .tProblem)
            Do $$$AssertEquals($Select($$$ISOK(tSC) && (tProblem = "") && (tRows.%Size() = 1): tRows.%Get(0).%ToJSON(), 1: tProblem), "{""field"":""Status"",""before"":""Done"",""after"":""" _ $List(tHalf, 2) _ """}", $Piece(tEntry, ":", 1) _ " on a " _ $List(tHalf, 1) _ " row")
        }
        Set tSC = $ClassMethod(tClass, "StateDiff", {"Source": "Elsewhere", "Status": "Running"}, .tRows, .tProblem)
        Do $$$AssertTrue((tProblem '= "") && (tRows.%Size() = 0), "a row naming no known source is a problem: " _ tProblem)
        Set tSC = $ClassMethod(tClass, "StateDiff", {"Source": "Admin API"}, .tRows, .tProblem)
        Do $$$AssertTrue((tProblem '= "") && (tRows.%Size() = 0), "and so is a row reading no status: " _ tProblem)
    }
}

/// <p>AD-6, AD-51: the mint reads the row and writes nothing; a confirm after the row's status moved
/// is refused <code>PROPOSAL.TARGETCHANGED</code> with nothing sent, while one after only its details
/// moved sends one control naming the row's background task.</p>
/// <p>Mutation (Rule 19): add <code>Details</code> to
/// <parameter>OcuPilot.Screen.Tool.BackgroundTaskCancel.FINGERPRINTSUBJECT</parameter> -- the
/// moved-details confirm is refused and goes red.</p>
Method TestTheFingerprintRefusesAMovedStatus()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4242", "Running", "7", "2026-09-28 12:00:05")))
    Set tSC = ..MintFor("tasks.background.pause", "Management Portal", "4242", tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the pause mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Status"",""before"":""Running"",""after"":""Paused""}]", "the card shows the status moving to Paused")
    Do $$$AssertEquals(##class(OcuPilot.Test.BackgroundTaskFixture).Calls(), "", "and the mint sent nothing")

    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4242", "Paused", "7", "2026-09-28 12:00:05")))
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "a task whose status moved is refused as the target having changed")
    Do $$$AssertEquals(##class(OcuPilot.Test.BackgroundTaskFixture).Calls(), "", "and nothing reached the vendor")

    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4242", "Running", "7", "2026-09-28 12:00:05")))
    Set tSC = ..MintFor("tasks.background.pause", "Management Portal", "4242", tTurn, .tSecond)
    Do $$$AssertStatusOK(tSC, "a second pause mints")
    If $$$ISERR(tSC) Quit
    Set tMoved = ..PortalRow("4242", "Running", "7", "2026-09-28 12:00:05")
    Do tMoved.%Set("Details", "OCUBGSEED 40%", "string")
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(tMoved))
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tSecond.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "a task whose details alone moved is still the one reviewed (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.BackgroundTaskFixture).Calls(), "PORTAL PAUSE 7", "one pause reached the job's background task")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>A portal job with no background task -- a compile, say -- is refused
/// <code>TASK.BACKGROUND.STATE</code> before any vendor call, as is one whose background task no
/// longer opens; an admin control goes to <code>AsyncResult</code> with the GUID alone.</p>
/// <p>Mutation (Rule 19): drop the empty-id refusal from
/// <method>OcuPilot.Port.BackgroundTaskPort.Control</method> -- the vendor is reached and the
/// sends-nothing leg goes red.</p>
Method TestAPortalJobWithNoBackgroundTaskSendsNothing()
{
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4243", "Running", "", "2026-09-28 11:00:00"), ..PortalRow("4242", "Paused", "7", "2026-09-28 12:00:05")))
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmAdmin(..Rows(..AdminRow(..#GUID, "Running", "2026-09-28 12:30:00")))
    Do ..Control("PAUSE", "Management Portal", "4243", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "409 TASK.BACKGROUND.STATE", "a job with no background task is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.BackgroundTaskFixture).Calls(), "", "and nothing reached the vendor")
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortalAnswer("absent")
    Do ..Control("RESUME", "Management Portal", "4242", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "409 TASK.BACKGROUND.STATE", "and so is one whose background task no longer opens")
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortalAnswer(0)
    Do ..Control("CANCEL", "Admin API", ..#GUID, .tHttp, .tFault)
    Do ..Control("CANCEL", "Management Portal", "04242", .tHttp2, .tFault2)
    Do $$$AssertEquals(tHttp _ " " _ tHttp2 _ " " _ ##class(OcuPilot.Test.BackgroundTaskFixture).Calls(), "200 404 PORTAL RESUME 7|ADMIN CANCEL " _ ..#GUID, "an admin cancel names the GUID, and a job number is read exactly")
}

/// <p>The one published refusal: the portal's errors 9502 (a request the task takes none of, such as
/// a defragment's pause), 9503 (its state) and 9505 (no longer running), and the admin API's 409, all
/// answer 409 <code>TASK.BACKGROUND.STATE</code>, whose reason is the sentence EXPERIENCE.md
/// publishes; any other vendor failure is the generic internal fault.</p>
/// <p>Mutation (Rule 19): drop 9502 from
/// <parameter>OcuPilot.Port.BackgroundTaskPort.PORTALSTATECODES</parameter> -- the 9502 leg answers
/// 500 and goes red.</p>
Method TestEveryVendorStateRefusalIsTheOnePublishedCode()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).#REASONTASKBACKGROUNDSTATE, ..#PUBLISHED, "the kernel's reason is the published sentence")
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortal(..Rows(..PortalRow("4242", "Done", "7", "2026-09-28 12:00:05")))
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmAdmin(..Rows(..AdminRow(..#GUID, "Paused", "2026-09-28 12:30:00")))
    For tCode = 9502, 9503, 9505 {
        Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortalAnswer(tCode)
        Do ..Control("PAUSE", "Management Portal", "4242", .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.error _ " " _ tFault.reason, 1: ""), "409 TASK.BACKGROUND.STATE conflict " _ ..#PUBLISHED, "the portal's " _ tCode _ " is the published refusal")
    }
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmAdminAnswer(409)
    Do ..Control("CANCEL", "Admin API", ..#GUID, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "409 TASK.BACKGROUND.STATE " _ ..#PUBLISHED, "and so is the admin API's 409")
    Do ##class(OcuPilot.Test.BackgroundTaskFixture).ArmPortalAnswer(9509)
    Do ..Control("PAUSE", "Management Portal", "4242", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "while any other vendor failure is the internal fault")
}

/// <p>AD-59: an admin API row's script is the admin port's <code>AsyncResult</code> call naming the
/// GUID alone; a portal row's is the documented class's method on the job's background task, refused
/// with the published sentence when it has none.</p>
/// <p>Mutation (Rule 19): render every row through the admin branch in
/// <method>OcuPilot.Port.BackgroundTaskPort.Snippet</method> -- the portal leg goes red.</p>
Method TestTheScriptRendersBothBranches()
{
    Set tContext = {"origin": "https://draft.example:52773", "user": "OcuPilotDraftProbeUser"}
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Admin API", ..#GUID))
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "BackgroundTask", "PAUSE", .tQuery, "", tContext)
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).%Get("kind"), 1: tSteps.%ToJSON()), "rest", "an admin row renders one REST step")
    Do $$$AssertTrue($IsObject(tSteps.%Get(0)) && (tSteps.%Get(0).%Get("text") [ ("/api/admin/v2/async-result/pause?id=" _ ..#GUID _ "'")), "posting the GUID alone to AsyncResult's pause: " _ $Select($IsObject(tSteps.%Get(0)): tSteps.%Get(0).%Get("text"), 1: ""))
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Management Portal", "4242"))
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "BackgroundTask", "CANCEL", .tQuery, "", tContext)
    Set tText = $Select($IsObject(tSteps.%Get(0)): tSteps.%Get(0).%Get("text"), 1: "")
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).%Get("kind"), 1: tSteps.%ToJSON()), "objectscript", "a portal row renders one ObjectScript step")
    Do $$$AssertTrue((tText [ "MgtPortalTask(""4242"", ""SysBGTaskId"")") && (tText [ "##class(%SYS.BackgroundTask).%OpenId(tTaskId)") && (tText [ "tTask.Cancel()") && (tText [ ..#PUBLISHED), "reading the job's background task and canceling it, or refusing as the port does: " _ tText)
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "BackgroundTask", "RESUME") _ " " _ $ClassMethod(..#PORT, "SnippetForm", "AsyncResult", "RESUME"), "objectscript rest", "and each type has a script form")
}

/// <p>One control of type <var>pType</var> on the row <var>pSource</var>/<var>pId</var> names,
/// through the fixture port.</p>
Method Control(pType As %String, pSource As %String, pId As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject)
{
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pSource, pId))
    Do $ClassMethod(..#FIXTURE, "Invoke", "BackgroundTask", pType, .tQuery, "", .tResult, .pHttpStatus, .pFault)
}

/// <p>Mint tool <var>pToolName</var> on the row <var>pSource</var>/<var>pId</var> through
/// <parameter>MINT</parameter>, whose one replaced seam is the port, with its HTTP status and
/// fault.</p>
Method MintFor(pToolName As %String, pSource As %String, pId As %String, pTurnKey As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pToolName, .tTool)
    If $$$ISERR(tSC) Quit tSC
    Set tClass = tTool.class
    Set tArgs = {}
    Do tArgs.%Set("source", pSource, "string")
    Do tArgs.%Set("id", pId, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, pToolName, $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pId, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), tClass)
}

/// <p>One portal row as the port's portal half answers it.</p>
ClassMethod PortalRow(pId As %String, pStatus As %String, pTaskId As %String, pStart As %String) As %DynamicObject
{
    Set tRow = {"Source": "Management Portal", "Task": "Compact DB Space", "Namespace": "%SYS", "Details": "OCUBGSEED", "ErrorCount": "1"}
    Do tRow.%Set("Id", pId, "string")
    Do tRow.%Set("Status", pStatus, "string")
    Do tRow.%Set("SysBGTaskId", pTaskId, "string")
    Do tRow.%Set("StartTime", pStart, "string")
    Quit tRow
}

/// <p>One async task row as the vendor's <code>AsyncResult</code> <code>LIST</code> answers it.</p>
ClassMethod AdminRow(pGuid As %String, pState As %String, pStart As %String) As %DynamicObject
{
    Set tRow = {"TaskName": "POST /v2/database-dir/compact", "FailureReason": "the probe's reason", "TimeQueued": "2026-09-28 12:29:59", "TimeFinished": ""}
    Do tRow.%Set("GUID", pGuid, "string")
    Do tRow.%Set("State", pState, "string")
    Do tRow.%Set("TimeStarted", pStart, "string")
    Quit tRow
}

/// <p>The rows given, as the JSON array text the fixture answers.</p>
ClassMethod Rows(pFirst As %DynamicObject, pSecond As %DynamicObject = "") As %String
{
    Set tRows = []
    Do tRows.%Push(pFirst)
    If $IsObject(pSecond) Do tRows.%Push(pSecond)
    Quit tRows.%ToJSON()
}

}
