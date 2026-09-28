/// <p>Pins Story 16.2's Web sessions list and its end tool over canned reads (AD-5, AD-6, AD-8,
/// AD-10, AD-51, AD-53): what <class>OcuPilot.Screen.Descriptor.WebSessionList</class> and
/// <class>OcuPilot.Screen.Tool.WebSessionEnd</class> declare, the card's removal rows, the fresh
/// read's exact-case compare, the fingerprint's subject, and the prohibited set's own-session and
/// preserve-mode arms on both callers.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%All</code>. Every read and write goes through <class>OcuPilot.Test.ProposalFixture</class>'s
/// port, and the daemon wait through <class>OcuPilot.Test.AwaitPort</class>, so no session on the
/// instance is read or ended.</p>
Class OcuPilot.Test.WebSessions Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebSessionList";

Parameter TOOL = "OcuPilot.Screen.Tool.WebSessionEnd";

Parameter TOOLNAME = "webapp.sessions.end";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter FIXTURESET = "OcuPilot.Test.ProhibitedFixture";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter ACTION = "OcuPilot.Test.WebSessionActionFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A session id, mixed case as the instance mints them.</p>
Parameter SESSION = "wSeS5iOnId";

/// <p>An id differing from <parameter>SESSION</parameter> only in case.</p>
Parameter TWIN = "WsEs5IoNiD";

Method OnBeforeOneTest() As %Status
{
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
    Quit $$$OK
}

/// <p>AD-5, AD-8: the list is the Web applications area's third screen over the vendor's
/// <code>WebSession</code> <code>LIST</code>, keyed by <code>ID</code>, its process cell linking to
/// Process details, declaring <code>%Admin_Operate:USE</code> as its own pair beside the database
/// read, and carrying one self-protected End session row action; its read tool is registered.</p>
/// <p>Mutation (Rule 19): drop <code>ownPrivileges</code> from the descriptor -- the registry refuses
/// the area coverage and the own-pair leg goes red.</p>
Method TestTheDescriptorDeclaresTheListItsPairsAndItsRowAction()
{
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.route _ " " _ tDeclaration.area _ " " _ tDeclaration.sideBarPosition _ " " _ tDeclaration.toolIdentifier, "web-applications/sessions web-applications 3 webapp.sessions", "the third Web applications entry, reading as webapp.sessions")
    Do $$$AssertEquals(tDeclaration.entityType _ " " _ tDeclaration.scope _ " " _ tDeclaration.id.%ToJSON(), "web-session instance {""kind"":""composite"",""parts"":[""ID""]}", "an instance-scoped web session keyed by its ID")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "requiring the endpoint's own pair and the database read")
    Do $$$AssertEquals(tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""}]", "the first of which is the screen's own, beyond the area's")
    Do $$$AssertEquals(tDeclaration.rowActions.%ToJSON(), "[{""id"":""end"",""selfProtection"":""ocupilot-session""}]", "one row action, explained by the own-session rule")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""WebSession"",""type"":""LIST""}", "read through the vendor's list")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""ID"",""Username"",""Application"",""SesProcessId"",""Timeout"",""Preserve""]", "declaring the list's six fields")
    Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), "[""ID"",""Username"",""Application"",""SesProcessId"",""Timeout""]", "and five of them as context")
    Do $$$AssertEquals(tDeclaration.read.sort.default _ " " _ tDeclaration.read.sort.direction, "Application asc", "sorted by application")
    Do $$$AssertEquals(tDeclaration.rowTarget.%ToJSON(), "{""route"":""os-management/processes/details"",""field"":""SesProcessId""}", "the process cell links to Process details")
    Do $$$AssertEquals(tDeclaration.table.columns.%Get(0).field _ " " _ tDeclaration.table.columns.%Get(0).kind, "SesProcessId name", "which is the name column")
    Do $$$AssertEquals(tDeclaration.classicPage, "%CSP.UI.Portal.CSPSessions", "replacing the classic Web Sessions page")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "carrying three suggested prompts")
    Do $$$AssertTrue($ListFind($ListFromString($Parameter("OcuPilot.Screen.Registry", "SELFPROTECTIONRULES")), "ocupilot-session") > 0, "the rule is one the registry declares")
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("web-applications", $ClassMethod(..#SCREEN, "PrivilegePairs"), $ClassMethod(..#SCREEN, "OwnPrivilegePairs")), "", "the area covers every pair but the screen's own")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("web-applications", $ClassMethod(..#SCREEN, "PrivilegePairs")), "", "and %Admin_Operate:USE is not the area's, so the screen alone gates on it")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("webapp.sessions.read", .tRead)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tRead) && (tRead.kind = "read") && (tRead.descriptor = ..#SCREEN), "its read tool is registered")
}

/// <p>AD-51, AD-8: a destructive, bodyless <code>DELETE</code> read through the list filtered by
/// <code>ID</code> exactly, fingerprinted over <code>Username,Application,Preserve,SesProcessId</code>
/// with <code>Application</code> as the precondition, requiring the list's pairs and
/// <code>%DB_IRISSYS:WRITE</code>, carrying the End session action, and governed by a baseline key
/// that ships enabled. The port admits the pair bodyless and waits for the daemon.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.WebSessionEnd.PrivilegePairs</method>
/// answer the list's pairs alone -- the pair leg goes red, as does
/// <class>OcuPilot.Test.WebSessionsLive</class>'s least-privilege leg.</p>
Method TestTheToolIsADestructiveActionWriteOverTheListsPairsAndTheWritePair()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOLNAME, .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tTool) && (tTool.class = ..#TOOL) && (tTool.kind = "write"), "the tool is registered as a write")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "ReadRowKey") _ " " _ $ClassMethod(..#TOOL, "ReadRowKeyExact"), "LIST ID 1", "its fresh read is the list's row whose ID matches exactly")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody") _ " " _ $ClassMethod(..#TOOL, "ChangeAction") _ " " _ $ClassMethod(..#TOOL, "Destructive"), "DELETE 0 deleted 1", "a bodyless, destructive delete publishing deleted")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Endpoint") _ " " _ $ClassMethod(..#TOOL, "IdParam") _ " " _ $ClassMethod(..#TOOL, "IdArgument"), "WebSession id ID", "addressing the vendor's id parameter")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "FingerprintSubject")), "Username,Application,Preserve,SesProcessId", "fingerprinted over what the user reviewed, Timeout left out")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "PreconditionField"), "Application", "with the application as its precondition")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(..#TOOL), "", "which the registration guard holds adequate")
    Do $$$AssertEquals($ListLength($ClassMethod(..#TOOL, "SettableFields")), 0, "admitting no settable field")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ScreenActionIds")), "end", "carrying the list's End session")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "PrivilegePairs")), $ListToString($ClassMethod(..#SCREEN, "PrivilegePairs") _ $ListBuild($ListBuild("%DB_IRISSYS", "WRITE"))), "requiring the list's own pairs and the system database write")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(##class(OcuPilot.Test.DeviceCreate).Keys(tSchema.%Get("properties")), "ID,expectedImpact,rationale,reverse", "the schema is the session's ID and the agent's own words")
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""ID""]", "requiring the ID")
    Do $$$AssertTrue(tSchema.%Get("properties").%Get("ID").%Get("description") [ "case included", "whose description asks for it exactly, case included")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("WebSession", "DELETE") && ##class(OcuPilot.Port.AdminPort).IsBodyless("WebSession", "DELETE"), "the port admits the pair as a bodyless write")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).AwaitedDeleteKey("WebSession", "DELETE"), "id:ID", "and waits for the row the id names")
    Do $$$AssertEquals($Parameter("OcuPilot.Port.AdminPort", "AWAITEDDELETEMS") _ "/" _ $Parameter("OcuPilot.Port.AdminPort", "AWAITEDDELETEPOLLMS"), "10000/250", "for at most ten seconds, every quarter second")
    Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tKeys) && (tKeys.%GetTypeOf(..#TOOLNAME) = "boolean") && tKeys.%Get(..#TOOLNAME), "its governance key ships enabled")
}

/// <p>The card's rows: the session's user, application, process and expiry as the fresh row
/// reads them, each removed; a row with no application is not one to end.</p>
/// <p>Mutation (Rule 19): drop the absent-<code>Application</code> refusal from
/// <method>OcuPilot.Screen.Tool.WebSessionEnd.StateDiff</method> -- the fail-closed leg goes red.</p>
Method TestTheStateDiffListsTheSessionAsRemoved()
{
    Set tSC = $ClassMethod(..#TOOL, "StateDiff", ..Row(..#SESSION, "/api/atelier/"), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a session answers")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Do $$$AssertEquals(..RowsText(tRows), "Username=OcuPilotProbeSessionUser!|Application=/api/atelier/!|SesProcessId=!|Timeout=2026-09-28 16:00:00!", "one removal row each for the user, application, process and expiry")
    Set tRow = ..Row(..#SESSION, "/api/atelier/")
    Do tRow.%Remove("Application")
    Set tSC = $ClassMethod(..#TOOL, "StateDiff", tRow, .tRows, .tProblem)
    Do $$$AssertNotEquals(tProblem, "", "a row with no application is a problem: " _ tProblem)
    Do $$$AssertEquals(tRows.%Size(), 0, "and answers no row")
}

/// <p>The fresh read compares the ID exactly: a case twin reads 404, and of two sessions whose ids
/// differ only in case each id finds its own. A tool that does not declare the exact compare still
/// folds case.</p>
/// <p>Mutation (Rule 19): restore <method>OcuPilot.Kernel.Proposal.Operation.ReadTarget</method>'s
/// case fold for this tool (set <parameter>OcuPilot.Screen.Tool.WebSessionEnd.READROWKEYEXACT</parameter>
/// to 0) -- the case-twin legs go red.</p>
Method TestTheFreshReadComparesTheIdExactly()
{
    Set tPort = "OcuPilot.Test.ProposalFixture"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/atelier/")))
    Kill tQuery
    Set tQuery("id") = ..#SESSION
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadTarget(..#TOOL, tPort, "WebSession", .tQuery, ..#SESSION, .tFresh, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tFresh) && (tFresh.ID = ..#SESSION), "the session reads by its own ID")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadTarget(..#TOOL, tPort, "WebSession", .tQuery, ..#TWIN, .tFresh, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1 404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "an ID differing only in case is absent")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/atelier/"), ..Row(..#TWIN, "/csp/sys/")))
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadTarget(..#TOOL, tPort, "WebSession", .tQuery, ..#TWIN, .tFresh, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tFresh) && (tFresh.Application = "/csp/sys/"), "of two case twins, the second ID finds its own row, not the first")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm("[{""EventName"":""%System/%Login/Login"",""Enabled"":true}]")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).ReadTarget("OcuPilot.Screen.Tool.AuditEventReset", tPort, "Security.Audit.Event", .tQuery, "%SYSTEM/%LOGIN/LOGIN", .tFresh, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tFresh), "a tool that declares no exact compare still finds its row without regard to case")
}

/// <p>AD-6, AD-51: the mint reads the list and writes nothing; a confirm after the session's
/// application moved is refused <code>PROPOSAL.TARGETCHANGED</code> with nothing sent, while one after
/// only its expiry moved sends one bodyless <code>DELETE</code> naming the session.</p>
/// <p>Mutation (Rule 19): add <code>Timeout</code> to
/// <parameter>OcuPilot.Screen.Tool.WebSessionEnd.FINGERPRINTSUBJECT</parameter> -- the moved-expiry
/// confirm is refused and goes red.</p>
Method TestTheFingerprintCoversTheApplicationAndNotTheExpiry()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#FIXTURESET)
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/atelier/")))
    Set tSC = ..MintFor(..#SESSION, .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the end mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType() _ " " _ ##class(OcuPilot.Test.ProposalFixture).WriteCount(), "LIST 0", "the mint read the list and wrote nothing")
    Do $$$AssertEquals(..RowsText(tProposal.%Get("changed")), "Username=OcuPilotProbeSessionUser!|Application=/api/atelier/!|SesProcessId=!|Timeout=2026-09-28 16:00:00!", "the card lists the session as removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.%Get("proposalId"), "Destructive"), 1, "and the stored row is destructive")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/csp/sys/")))
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "a session whose application moved is refused as the target having changed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reached the port")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/atelier/")))
    Set tSC = ..MintFor(..#SESSION, .tSecond, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "a second end mints")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/atelier/", "2026-09-28 17:30:00")))
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tSecond.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "a session whose expiry alone moved is still the one reviewed (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastType() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastQuery("id") _ " [" _ ##class(OcuPilot.Test.ProposalFixture).LastWriteBody() _ "]", "1 DELETE " _ ..#SESSION _ " []", "one bodyless DELETE reached the port, naming the session")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AD-10 as amended 2026-09-28: a session under an application OcuPilot is served through --
/// each spelling the instance resolves to one -- is refused <code>PROHIBITED.OCUPILOTSESSION</code>,
/// as is the session the serving request runs in, a row that names no application and any row
/// when the roster cannot be read; a session under any other application may be ended, the vendor's
/// <code>AllowEndSession</code> false notwithstanding. The reason is the published sentence, and the
/// Guardrails page lists the code with it.</p>
/// <p>Mutation (Rule 19): drop the <code>WebSession</code> branch's
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotSession</method> refusal -- every refused
/// leg goes red; answer 0 on a roster fault there -- the roster leg goes red.</p>
Method TestTheSetRefusesASessionOcuPilotIsRunningIn()
{
    Set tCode = $Parameter(..#SET, "OCUPILOTSESSION")
    For tCase = $ListBuild("/api/ocupilot/", 1), $ListBuild("/API/OcuPilot", 1), $ListBuild("/ocupilot/", 1), $ListBuild("/api/ocupilot/readiness", 1), $ListBuild("/api/atelier/", 0), $ListBuild("/csp/sys/", 0), $ListBuild("", 1) {
        Set tApplication = $List(tCase, 1)
        Set tRow = ..Row(..#SESSION, tApplication)
        If tApplication = "" Do tRow.%Remove("Application")
        ; The vendor answers AllowEndSession false for /csp/sys/, and no refusal keys off it.
        If tApplication = "/csp/sys/" Do tRow.%Set("AllowEndSession", 0, "boolean")
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(tRow))
        Set tSC = ..Ask(..#SESSION, .tProhibits, .tAnswered)
        Do $$$AssertStatusOK(tSC, "the set answers for '" _ tApplication _ "': " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals(tProhibits _ " " _ tAnswered, $Select($List(tCase, 2): "1 " _ tCode, 1: "0 "), "a session under '" _ tApplication _ "' is " _ $Select($List(tCase, 2): "refused as OcuPilot's own", 1: "permitted"))
    }
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/atelier/")))
    New %session
    Set %session = {"SessionId": (..#SESSION)}
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).ServingSessionId(), ..#SESSION, "the serving request's own session id is read")
    Set tSC = ..Ask(..#SESSION, .tProhibits, .tAnswered)
    Do $$$AssertEquals(tProhibits _ " " _ tAnswered, "1 " _ tCode, "and the session the request runs in is refused, whatever its application")
    Set %session = {"SessionId": (..#TWIN)}
    Set tSC = ..Ask(..#SESSION, .tProhibits, .tAnswered)
    Do $$$AssertEquals(tProhibits _ " " _ tAnswered, "0 ", "while a request in its case twin is not running in it")
    Kill %session
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotSession(""), 1, "a read that is not a row fails closed")
    Do $$$AssertEquals(##class(OcuPilot.Test.RosterFaultSet).IsOcuPilotSession(..Row(..#SESSION, "/api/atelier/")), 1, "and so does any row when the roster cannot be read")

    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), $Parameter(..#SET, "OCUPILOTSESSIONREASON"), "the reason is the published sentence")
    Set tSC = ##class(OcuPilot.Kernel.Shell.Guardrails).Read(.tAnswer)
    Do $$$AssertStatusOK(tSC, "the Guardrails page reads")
    Set tListed = 0
    If $IsObject($Get(tAnswer)) {
        Set tIterator = tAnswer.%Get("prohibited").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If (tEntry.code = tCode) && (tEntry.reason = $Parameter(..#SET, "OCUPILOTSESSIONREASON")) Set tListed = 1
        }
    }
    Do $$$AssertEquals(tListed, 1, "and lists the code with that sentence")
}

/// <p>AD-53: both callers are refused for a session OcuPilot is running in -- the screen's End
/// session over the route and the agent's confirm -- with the code and its sentence and nothing
/// sent; the route ends a session under any other application with one bodyless DELETE, and a row
/// still listed after it reads back present.</p>
/// <p>Mutation (Rule 19): drop the <code>web-session</code> test from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>'s dispatch, so the type is
/// refused as uncovered -- the permitted route leg goes red.</p>
Method TestBothCallersAreRefusedForOcuPilotsOwnSession()
{
    Set tCode = $Parameter(..#SET, "OCUPILOTSESSION")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/ocupilot/")))
    Set tSC = $ClassMethod(..#ACTION, "Act", "webapp.sessions", {"action": "end", "id": (..#SESSION)}, .tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the route answers")
    Set tEnvelope = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tEnvelope.%Get("code"), "403 " _ tCode, "the screen's End session is refused as OcuPilot's own: " _ tAnswer)
    Do $$$AssertEquals(tEnvelope.%Get("reason"), $Parameter(..#SET, "OCUPILOTSESSIONREASON"), "with the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is sent")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#FIXTURESET)
    Set tSC = ..MintFor(..#SESSION, .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's end mints")
    If $$$ISOK(tSC) {
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tConfirmCode, .tDetail)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tConfirmCode), "403 " _ tCode, "and its confirm is refused as OcuPilot's own")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with nothing sent")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Row(..#SESSION, "/api/atelier/")))
    Set tSC = $ClassMethod(..#ACTION, "Act", "webapp.sessions", {"action": "end", "id": (..#SESSION)}, .tAnswer, .tStatus)
    Set tEnvelope = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tEnvelope.%Get("action"), "200 deleted", "a session under another application is ended: " _ tAnswer)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastType() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "1 DELETE " _ ..#SESSION, "by one DELETE naming it")
    ; The fixture's list still carries the row, as it would past a slow daemon's bound (AD-58).
    Set tVerdict = ""
    If $IsObject(tEnvelope.%Get("readBack")) Set tVerdict = tEnvelope.%Get("readBack").%Get("verdict")
    Do $$$AssertEquals(tVerdict, $Parameter("OcuPilot.Kernel.Proposal.ReadBack", "PRESENT"), "and a session still listed after the write reads back present, the write standing as made")
}

/// <p>AD-10 as amended 2026-09-28, AD-53: a preserve-mode session whose own process runs is refused
/// <code>PROHIBITED.PRESERVEDSESSION</code> on both callers with nothing sent -- after the
/// own-session arm, whose code a preserve-mode session under OcuPilot's own application still
/// earns. One whose process has ended, or that names none, may be ended, and so may a session under
/// <code>/csp/sys/</code> with <code>Preserve</code> 0, the vendor's <code>AllowEndSession</code>
/// false notwithstanding. The reason is the published sentence, and the Guardrails page lists the
/// code with it. The running process is this test's own job; the ended one is a pid no process runs
/// under (<method>EndedPid</method>).</p>
/// <p>Mutation (Rule 19): drop the <code>WebSession</code> branch's
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsPreservedSession</method> refusal -- the refused set,
/// route and confirm legs go red; answer 1 in place of its running-process test -- the ended-process
/// set and route legs go red.</p>
Method TestAPreserveModeSessionIsRefusedWhileItsProcessRuns()
{
    Set tCode = $Parameter(..#SET, "PRESERVEDSESSION")
    Set tReason = $Parameter(..#SET, "PRESERVEDSESSIONREASON")
    Set tEnded = ..EndedPid()
    For tForm = "number", "boolean" {
        Set tRow = ..Preserved(..#SESSION, "/api/atelier/", $Job)
        Do tRow.%Set("Preserve", 1, tForm)
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(tRow))
        Set tSC = ..Ask(..#SESSION, .tProhibits, .tAnswered)
        Do $$$AssertEquals(tProhibits _ " " _ tAnswered, "1 " _ tCode, "a session whose Preserve reads 1 as a " _ tForm _ " and whose process runs is refused as preserve-mode")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Preserved(..#SESSION, "/api/ocupilot/", $Job)))
    Set tSC = ..Ask(..#SESSION, .tProhibits, .tAnswered)
    Do $$$AssertEquals(tProhibits _ " " _ tAnswered, "1 " _ $Parameter(..#SET, "OCUPILOTSESSION"), "and one under OcuPilot's own application is refused as OcuPilot's own first")
    For tPid = tEnded, "" {
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Preserved(..#SESSION, "/api/atelier/", tPid)))
        Set tSC = ..Ask(..#SESSION, .tProhibits, .tAnswered)
        Do $$$AssertStatusOK(tSC, "the set answers for a process that " _ $Select(tPid = "": "is not named", 1: "has ended"))
        Do $$$AssertEquals(tProhibits _ " " _ tAnswered, "0 ", "a preserve-mode session whose process " _ $Select(tPid = "": "is not named", 1: "has ended") _ " may be ended")
    }

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Preserved(..#SESSION, "/api/atelier/", $Job)))
    Set tSC = $ClassMethod(..#ACTION, "Act", "webapp.sessions", {"action": "end", "id": (..#SESSION)}, .tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the route answers")
    Set tEnvelope = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tEnvelope.%Get("code"), "403 " _ tCode, "the screen's End session is refused as preserve-mode: " _ tAnswer)
    Do $$$AssertEquals(tEnvelope.%Get("reason"), tReason, "with the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is sent")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited(..#FIXTURESET)
    Set tSC = ..MintFor(..#SESSION, .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's end mints")
    If $$$ISOK(tSC) {
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tConfirmCode, .tDetail)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tConfirmCode), "403 " _ tCode, "and its confirm is refused as preserve-mode")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with nothing sent")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tRow = ..Row(..#SESSION, "/csp/sys/")
    Do tRow.%Set("AllowEndSession", 0, "boolean")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(tRow))
    Set tSC = $ClassMethod(..#ACTION, "Act", "webapp.sessions", {"action": "end", "id": (..#SESSION)}, .tAnswer, .tStatus)
    Set tEnvelope = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tEnvelope.%Get("action"), "200 deleted", "a /csp/sys/ session with Preserve 0 is still ended: " _ tAnswer)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastType() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "1 DELETE " _ ..#SESSION, "by one DELETE naming it")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Rows(..Preserved(..#SESSION, "/api/atelier/", tEnded)))
    Set tSC = $ClassMethod(..#ACTION, "Act", "webapp.sessions", {"action": "end", "id": (..#SESSION)}, .tAnswer, .tStatus)
    Set tEnvelope = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tEnvelope.%Get("action"), "200 deleted", "and so is a preserve-mode session whose process has ended: " _ tAnswer)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastType() _ " " _ ##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "2 DELETE " _ ..#SESSION, "by one more DELETE naming it")

    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), tReason, "the reason is the published sentence")
    Set tSC = ##class(OcuPilot.Kernel.Shell.Guardrails).Read(.tAnswer)
    Do $$$AssertStatusOK(tSC, "the Guardrails page reads")
    Set tListed = 0
    If $IsObject($Get(tAnswer)) {
        Set tIterator = tAnswer.%Get("prohibited").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If (tEntry.code = tCode) && (tEntry.reason = tReason) Set tListed = 1
        }
    }
    Do $$$AssertEquals(tListed, 1, "and lists the code with that sentence")
}

/// <p>AD-26, AD-58: the port's wait for the daemon never fails the write. A row still listed is
/// re-read until the bound passes and then left, the fact logged without the session id; a row
/// already gone, or a list that cannot be read, ends the wait at the first read.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AdminPort.AwaitGone</method> read the list
/// once and return -- the still-listed leg's poll and bound assertions go red.</p>
Method TestTheWaitForTheDaemonIsBoundedAndNeverFailsTheWrite()
{
    Set tPort = "OcuPilot.Test.AwaitPort"
    Set tBound = $Parameter(tPort, "AWAITEDDELETEMS") / 1000
    Kill tQuery
    Set tQuery("id") = ..#SESSION
    Do $ClassMethod(tPort, "Arm", ..Rows(..Row(..#SESSION, "/api/atelier/")))
    Set tStart = $ZHorolog
    Do $ClassMethod(tPort, "Await", "WebSession", "DELETE", .tQuery)
    Set tElapsed = $ZHorolog - tStart
    Do $$$AssertTrue((tElapsed >= tBound) && (tElapsed < (tBound + 1)), "a session still listed is awaited to the bound and no longer: " _ tElapsed _ " s")
    Do $$$AssertTrue($ClassMethod(tPort, "Lists") > 1, "re-reading the list meanwhile: " _ $ClassMethod(tPort, "Lists") _ " reads")
    Set tLogged = $ClassMethod(tPort, "Logged")
    Do $$$AssertTrue((tLogged [ "still listed") && '(tLogged [ ..#SESSION), "the bound is logged, and the log line carries no session id: " _ tLogged)

    Do $ClassMethod(tPort, "Arm", ..Rows(..Row(..#TWIN, "/api/atelier/")))
    Do $ClassMethod(tPort, "Await", "WebSession", "DELETE", .tQuery)
    Do $$$AssertEquals($ClassMethod(tPort, "Lists") _ " [" _ $ClassMethod(tPort, "Logged") _ "]", "1 []", "a row gone at the first read, its case twin notwithstanding, ends the wait with nothing logged")

    Do $ClassMethod(tPort, "Arm", "")
    Do $ClassMethod(tPort, "Await", "WebSession", "DELETE", .tQuery)
    Do $$$AssertEquals($ClassMethod(tPort, "Lists") _ " [" _ $ClassMethod(tPort, "Logged") _ "]", "1 []", "and a list that cannot be read leaves the vendor's answer standing")
}

/// <p>Ask the shipped predicates, through <parameter>FIXTURESET</parameter>'s port, whether ending
/// session <var>pId</var> is prohibited.</p>
Method Ask(pId As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-session", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, pId, .tRef)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURESET, "Prohibits", ..#TOOLNAME, tRef, "{}", "[{""field"":""Username"",""before"":""OcuPilotProbeSessionUser"",""after"":"""",""removed"":true}]", .pProhibits, .pCode)
}

/// <p>Mint one end of session <var>pId</var> through <parameter>MINT</parameter>, whose one replaced
/// seam is the port.</p>
Method MintFor(pId As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pTurnKey As %String) As %Status
{
    Set tArgs = {}
    Do tArgs.%Set("ID", pId, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#TOOLNAME, $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pId, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>One session row as the vendor's <code>LIST</code> answers it.</p>
ClassMethod Row(pId As %String, pApplication As %String, pTimeout As %String = "2026-09-28 16:00:00") As %DynamicObject
{
    Set tRow = {"Username": "OcuPilotProbeSessionUser", "Preserve": 0, "LicenseId": "OcuPilotProbeSessionUser@127.0.0.1", "SesProcessId": "", "AllowEndSession": true}
    Do tRow.%Set("ID", pId, "string")
    Do tRow.%Set("Application", pApplication, "string")
    Do tRow.%Set("Timeout", pTimeout, "string")
    Quit tRow
}

/// <p>One preserve-mode session row as the vendor's <code>LIST</code> answers it: its own process
/// <var>pPid</var> named, and <code>AllowEndSession</code> false.</p>
ClassMethod Preserved(pId As %String, pApplication As %String, pPid As %String) As %DynamicObject
{
    Set tRow = ..Row(pId, pApplication)
    Do tRow.%Set("Preserve", 1, "number")
    Do tRow.%Set("SesProcessId", pPid, "string")
    Do tRow.%Set("AllowEndSession", 0, "boolean")
    Quit tRow
}

/// <p>A process id no process on this instance runs under now, counting down from the largest a
/// Linux host assigns.</p>
ClassMethod EndedPid() As %String
{
    Set tPid = 4194303
    While $Data(^$JOB(tPid)) {
        Set tPid = tPid - 1
    }
    Quit tPid
}

/// <p>The rows given, as the JSON array text the fixture's port answers.</p>
ClassMethod Rows(pFirst As %DynamicObject, pSecond As %DynamicObject = "") As %String
{
    Set tRows = []
    Do tRows.%Push(pFirst)
    If $IsObject(pSecond) Do tRows.%Push(pSecond)
    Quit tRows.%ToJSON()
}

/// <p>Diff rows <var>pRows</var> as <code>field=before</code> joined with <code>|</code>, each
/// removed row marked <code>!</code>.</p>
ClassMethod RowsText(pRows As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: "|") _ tRow.%Get("field") _ "=" _ tRow.%Get("before") _ $Select(tRow.%Get("removed"): "!", 1: "")
    }
    Quit tText
}

/// <p><var>pText</var> parsed, or an empty object.</p>
ClassMethod Parsed(pText As %String) As %DynamicObject
{
    Set tObject = {}
    Try { Set tObject = ##class(%DynamicObject).%FromJSON(pText) } Catch {}
    Quit tObject
}

}
