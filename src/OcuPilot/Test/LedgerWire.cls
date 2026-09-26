/// <p>The agent ledger over HTTP (Story 4.9, AD-8, AD-21, AD-24, AD-46), driven by two
/// least-privileged principals whose turns run as real jobs against the armed <code>turnprobe</code>
/// row: what a turn writes, the resources a row records, the store's own cut of an argument string,
/// the route's own envelope and refusals, and
/// an administrator's view of another user's rows gated row by row.</p>
/// <p><b>It creates IRIS users and roles and spawns turn jobs, so <method>OnBeforeAllTests</method>
/// refuses to run unless both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter> read 1.</b> Only <file>scripts/ci-throwaway.sh</file>
/// sets them. Ledger rows outlive their turn by design (AD-37), so this class removes its own rows
/// after every method rather than relying on any sweep.</p>
Class OcuPilot.Test.LedgerWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "ledgerwire-probe";

Parameter APIBASE = "/api/ocupilot";

Parameter LEDGERROUTE = "/agent/ledger";

/// <p>The store this class removes its own rows from.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The one resource the administrative principal holds beyond the shared fixture's set, so the
/// cross-user gate passes for it and fails for the other principal.</p>
Parameter ADMINRESOURCES = "OcuPilotAdmin:U";

/// <p>The resources <code>permissions/users</code> declares, which neither principal holds to begin
/// with -- so a <code>shell.screen.open</code> call against that screen is refused, and the row it
/// writes records exactly those two.</p>
Parameter SCREENRESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R";

/// <p>The route the turns in this class are started from, which every row they write records.</p>
Parameter CONTEXTROUTE = "os-management/processes";

/// <p>The resources <parameter>CONTEXTROUTE</parameter>'s screen requires, in the grant grammar
/// <method>SetReaderResources</method> takes. A turn's <code>llm</code> rows record the pair set of
/// the screen route the turn ran from (Story 5.4, DW-1120), so a cross-user reader sees them only
/// while it holds these too.</p>
Parameter CONTEXTRESOURCES = "%Admin_Operate:U,%Admin_Manage:U,%DB_IRISSYS:R";

/// <p>The screen <code>shell.screen.open</code> is asked for, and whose pairs the refused call's row
/// carries.</p>
Parameter TARGETROUTE = "permissions/users";

/// <p>The canonical pair string <parameter>TARGETROUTE</parameter>'s screen requires, sorted the way
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> sorts it.</p>
Parameter TARGETPAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerWire creates IRIS users and roles and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerWire runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..Subject(), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..Reader(), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"), ..#ADMINRESOURCES)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Do ..ClearRows()
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerWire teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Do ..ClearRows()
    Do ..SetReaderResources(..#ADMINRESOURCES)
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do ..ClearRows()
    Do $$$AssertEquals(..RowCount(), 0, "and no probe ledger row survives it either")
    Do ..SetReaderResources(..#ADMINRESOURCES)
    Quit $$$OK
}

/// <p>The principal whose turns write the rows.</p>
ClassMethod Subject() As %String
{
    Quit $Parameter(..#FIXTURE, "USERA")
}

/// <p>The principal that reads them, which holds the OcuPilot administrative resource.</p>
ClassMethod Reader() As %String
{
    Quit $Parameter(..#FIXTURE, "USERB")
}

/// <p>Remove every ledger row either principal wrote. Ledger rows outlive their turn (AD-37), so
/// nothing else removes them.</p>
ClassMethod ClearRows()
{
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..Subject())
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..Reader())
}

/// <p>How many ledger rows either principal holds, by direct SQL.</p>
ClassMethod RowCount() As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = ? OR %EXACT(UserName) = ?", ..Subject(), ..Reader())
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>Give the reader's second role exactly <var>pResources</var>, so what it holds beyond the
/// shared role can be changed between two reads without touching the other principal.</p>
ClassMethod SetReaderResources(pResources As %String) As %Status
{
    Set tSC = $$$OK
    Set tRole = $Parameter(..#FIXTURE, "SECONDROLE")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Resources") = pResources
        Set tProps("GrantedRoles") = ""
        Set tSC = ##class(Security.Roles).Modify(tRole, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>One request as <var>pUser</var>; both principals share one password.</p>
Method CallAs(pMethod As %String, pPath As %String, pUser As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, pUser, ..PreparedPassword, .pStatus, .pText, .pHeaders, pBody, "application/json")
}

/// <p>The wire <code>context</code> object every turn here is started from, so each row it writes
/// records a screen-context route.</p>
ClassMethod Context() As %DynamicObject
{
    Set tContext = {"view": {"rows": []}}
    Do tContext.%Set("route", ..#CONTEXTROUTE, "string")
    Do tContext.%Set("namespace", $Namespace, "string")
    Quit tContext
}

/// <p>Start a turn as the subject principal, carrying the screen context; the turn id when the start
/// answered 202.</p>
Method Start(pMessage As %String, Output pStatus As %Integer, Output pText As %String) As %String
{
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", ..Subject(), ..PreparedPassword, .tConvStatus, .tConvText)
    Do ..CallAs("POST", "/turn", ..Subject(), $ClassMethod(..#FIXTURE, "StartBody", pMessage, tConvId, ..Context()), .pStatus, .pText, .tHeaders)
    If pStatus '= 202 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(pText).turnId
}

/// <p>The ledger view <var>pUser</var> reads for <var>pQuery</var> (the query string after the
/// route), parsed; <code>""</code> when the read did not answer 200.</p>
Method Read(pUser As %String, pQuery As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %DynamicObject
{
    Do ..CallAs("GET", ..#LEDGERROUTE _ pQuery, pUser, "", .pStatus, .pText, .pHeaders)
    If pStatus '= 200 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(pText)
}

/// <p>The first row of <var>pView</var> whose <code>kind</code> is <var>pKind</var>, or
/// <code>""</code>.</p>
ClassMethod RowOfKind(pView As %DynamicObject, pKind As %String) As %DynamicObject
{
    If '$IsObject(pView) Quit ""
    Set tIterator = pView.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = pKind Quit
        Set tRow = ""
    }
    Quit $Select($IsObject($Get(tRow)): tRow, 1: "")
}

/// <p>AC1 -- a turn that makes provider calls and answers one tool call writes an <code>llm</code>
/// row carrying the provider key, the model and non-zero token figures, and a <code>tool</code> row
/// carrying the canonical tool name, the screen-context route, the redacted arguments and
/// <code>status</code> <code>ok</code>; each with the caller's own name and an ISO-8601 UTC
/// <code>loggedAt</code>.</p>
/// <p>Mutation (Rule 19): delete the <method>RecordLedger</method> call at
/// <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method>'s common exit -- the <code>tool</code>
/// row is absent and this goes red while the <code>llm</code> assertions stay green. For the turn
/// row's own route: pass <code>""</code> in place of
/// <method>OcuPilot.Kernel.Agent.Loop.ContextRoute</method>'s answer at
/// <method>OcuPilot.Kernel.Agent.Job.Run</method>'s <code>GuardedBegin</code> call -- the last
/// assertion goes red while every ledger assertion stays green, because the loop derives the
/// route for its rows itself.</p>
Method TestATurnWritesOneProviderRowAndOneToolRow()
{
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("shell_instance_read"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start("write a ledger row", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tStatus '= 202 Quit
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, ..Subject(), ..PreparedPassword, 30, .tTurnView), "completed", "the turn completes")

    Set tView = ..Read(..Subject(), "?turnKey=" _ tId, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner reads its own rows: " _ tText)
    If tStatus '= 200 Quit

    Set tLlm = ..RowOfKind(tView, "llm")
    Do $$$AssertTrue($IsObject(tLlm), "an llm row was written: " _ tText)
    If $IsObject(tLlm) {
        Do $$$AssertEquals(tLlm.name, "turnprobe", "carrying the provider key")
        Do $$$AssertEquals(tLlm.model, ..#TAG, "and the model")
        Do $$$AssertTrue((tLlm.requestTokens > 0) && (tLlm.responseTokens > 0), "and non-zero token figures: " _ tLlm.requestTokens _ "/" _ tLlm.responseTokens)
        Do $$$AssertEquals(tLlm.status, "ok", "and its outcome")
        Do $$$AssertEquals(tLlm.user, ..Subject(), "recorded against the caller")
        Do $$$AssertTrue($Match(tLlm.loggedAt, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"), "with an ISO-8601 UTC stamp: " _ tLlm.loggedAt)
        Do $$$AssertEquals(tLlm.route, ..#CONTEXTROUTE, "and the screen it was started from")
    }

    Set tTool = ..RowOfKind(tView, "tool")
    Do $$$AssertTrue($IsObject(tTool), "a tool row was written: " _ tText)
    If $IsObject(tTool) {
        Do $$$AssertEquals(tTool.name, "shell.instance.read", "carrying the canonical tool name")
        Do $$$AssertEquals(tTool.status, "ok", "and the call's outcome")
        Do $$$AssertEquals(tTool.route, ..#CONTEXTROUTE, "and the screen-context route")
        Do $$$AssertEquals(tTool.arguments, "{}", "and the call's own redacted arguments")
        Do $$$AssertEquals(tTool.turnKey, tId, "against the turn that made it")
    }

    ; The turn row's own copy of the route, written by the job at GuardedBegin so the turn says
    ; which screen it ran from once its progress has been swept. Only a real job reaches that
    ; writer, so only a wire test can observe it.
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tId, "ContextRoute"), ..#CONTEXTROUTE, "and the turn row records the screen the job began it from")
}

/// <p>AC2 -- a row records the resources the tool required, declared and argument-derived together.
/// <code>shell.screen.open</code> declares no static pair at all and resolves its target screen's
/// per call, so a row that carried only the declared half would carry nothing for it.</p>
/// <p>Mutation (Rule 19): pass <code>""</code> in place of <var>pCallPairs</var> at
/// <method>OcuPilot.Kernel.Agent.Loop.RecordClientRow</method>'s call site -- the row's
/// <code>requiredPairs</code> is empty and this goes red.</p>
Method TestARowCarriesTheResourceTheToolRequired()
{
    Set tId = ..StartNavigationTurn(.tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tStatus '= 202 Quit
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, ..Subject(), ..PreparedPassword, 30, .tTurnView), "completed", "the turn completes")

    Set tView = ..Read(..Subject(), "?turnKey=" _ tId, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner reads its own rows: " _ tText)
    If tStatus '= 200 Quit
    Set tTool = ..RowOfKind(tView, "tool")
    Do $$$AssertTrue($IsObject(tTool), "a tool row was written: " _ tText)
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.name, "shell.screen.open", "for the client-fulfilled navigation tool")
    Do $$$AssertEquals(tTool.requiredPairs, ..#TARGETPAIRS, "carrying the target screen's own pairs, which are argument-derived only")
    Do $$$AssertEquals(tTool.code, "AUTH.NOPRIVILEGE", "and the code the caller was refused with")
}

/// <p>AC6 -- an administrator's view of another user's rows is gated by the resources recorded on
/// each row. The reader holds <code>OcuPilotAdmin:USE</code> and not the row's own resources, so the
/// row is absent and counted; granting them makes it appear. A caller without the administrative
/// resource asking for another user is refused, naming the pair; and a caller always sees their
/// own rows.</p>
/// <p>Mutation (Rule 19): remove the per-row
/// <method>OcuPilot.Screen.Gate.EvaluateRequired</method> branch from
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- the withheld row appears in the
/// first read and this goes red.</p>
Method TestARowIsWithheldFromAnAdministratorWhoLacksItsResource()
{
    Set tId = ..StartNavigationTurn(.tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tStatus '= 202 Quit
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, ..Subject(), ..PreparedPassword, 30, .tTurnView), "completed", "the turn completes")

    ; The owner sees their own row, ungated (AD-46).
    Set tOwn = ..Read(..Subject(), "?turnKey=" _ tId, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner's own read answers: " _ tText)
    Do $$$AssertTrue($IsObject(..RowOfKind(tOwn, "tool")), "and carries the row")
    Do $$$AssertEquals($Select($IsObject(tOwn): tOwn.rowsWithheld, 1: -1), 0, "withholding nothing")

    ; The administrator holds the administrative resource and not the row's own.
    Set tView = ..Read(..Reader(), "?user=" _ ..Subject() _ "&turnKey=" _ tId, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the administrator's cross-user read answers: " _ tText)
    If tStatus '= 200 Quit
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals($IsObject(..RowOfKind(tView, "tool")), 0, "the row whose resources it does not hold is absent: " _ tText)
    Do $$$AssertTrue(tView.rowsWithheld > 0, "and is counted as withheld")
    Do $$$AssertEquals(tText [ ..#TARGETROUTE, 0, "with nothing of that row on the wire")

    ; Granting them makes it appear. The context route's resources are granted with them: since
    ; Story 5.4 an llm row records the pair set of the screen the turn ran from (DW-1120), so a
    ; reader short of those would still be withholding one row here, and "withholding nothing"
    ; below would be a claim about the tool row alone.
    Do $$$AssertStatusOK(..SetReaderResources(..#ADMINRESOURCES _ "," _ ..#SCREENRESOURCES _ "," _ ..#CONTEXTRESOURCES), "the administrator is granted the row's own resources")
    Set tGranted = ..Read(..Reader(), "?user=" _ ..Subject() _ "&turnKey=" _ tId, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the same read answers: " _ tText)
    Do $$$AssertTrue($IsObject(..RowOfKind(tGranted, "tool")), "and the row now appears")
    Do $$$AssertEquals($Select($IsObject(tGranted): tGranted.rowsWithheld, 1: -1), 0, "withholding nothing")

    ; A caller without the administrative resource may not ask for another user at all.
    Do ..CallAs("GET", ..#LEDGERROUTE _ "?user=" _ ..Reader(), ..Subject(), "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 403, "a caller holding no OcuPilot administrative resource is refused: " _ tText)
    If tStatus = 403 {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        Do $$$AssertEquals(tAnswer.error _ "|" _ tAnswer.code _ "|" _ tAnswer.detail.failedPair, "forbidden|AUTH.NOPRIVILEGE|OcuPilotAdmin:USE", "naming the pair that failed")
    }
}

/// <p>AC8 (Integration, Rule 1) -- consumer <class>OcuPilot.Api.Ledger</class> reads from
/// <class>OcuPilot.Kernel.Audit.Ledger</class>: a real least-privileged principal calls
/// <code>GET /api/ocupilot/agent/ledger</code> over the wire after a turnprobe turn and receives
/// that turn's rows, with the declared body shape; and each of the three malformed parameters is one
/// envelope carrying its own <code>LEDGER.*</code> code.</p>
/// <p>Mutation (Rule 19): remove the <code>GET /agent/ledger</code> row from
/// <method>OcuPilot.Api.Router</method>'s <code>UrlMap</code> -- every request here answers 404
/// <code>ROUTE.NOTFOUND</code> and this goes red.</p>
Method TestTheRouteReturnsTheTurnsRowsOverTheWire()
{
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start("over the wire", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tStatus '= 202 Quit
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, ..Subject(), ..PreparedPassword, 30, .tTurnView), "completed", "the turn completes")

    Do ..CallAs("GET", ..#LEDGERROUTE _ "?turnKey=" _ tId, ..Subject(), "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the route answers: " _ tText)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(..KeysOf(tView), "rows,rowsSent,truncated,rowsWithheld,rowsDropped,windowHours", "with the declared keys")
    Do $$$AssertTrue(tView.rowsSent > 0, "and that turn's rows")
    Do $$$AssertEquals(tView.rows.%Size(), tView.rowsSent, "counted as it sent them")
    ; `pairsSense` says what claim `requiredPairs` makes and `auditMarked` is a confirmed write's
    ; own marker outcome, both added by Story 5.6 (DW-1321, AD-15).
    Do $$$AssertEquals(..KeysOf(tView.rows.%Get(0)), "ledgerId,user,loggedAt,turnKey,seq,kind,name,model,route,target,arguments,argumentsTruncated,status,code,requestTokens,responseTokens,requiredPairs,requiredPairsTruncated,pairsSense,auditMarked", "each row carrying the declared keys")
    Do $$$AssertEquals(tView.rows.%Get(0).turnKey, tId, "for the turn that was asked for")

    For tCase = "?windowHours=9999|400|LEDGER.WINDOW.INVALID", "?windowHours=x|400|LEDGER.WINDOW.INVALID", "?maxRows=0|400|LEDGER.MAXROWS.INVALID", "?maxRows=99999|400|LEDGER.MAXROWS.INVALID", "?user=bad!name|400|LEDGER.USER.INVALID" {
        Do ..CallAs("GET", ..#LEDGERROUTE _ $Piece(tCase, "|", 1), ..Subject(), "", .tStatus, .tText, .tHeaders)
        Do $$$AssertEquals(tStatus, $Piece(tCase, "|", 2), $Piece(tCase, "|", 1) _ ": refused " _ $Extract(tText, 1, 200))
        If tStatus '= $Piece(tCase, "|", 2) Continue
        Set tAnswer = ""
        Try {
            Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        } Catch {
            Set tAnswer = ""
        }
        Do $$$AssertTrue($IsObject(tAnswer), $Piece(tCase, "|", 1) _ ": answering one JSON envelope: " _ $Extract(tText, 1, 200))
        If '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.code, $Piece(tCase, "|", 3), $Piece(tCase, "|", 1) _ ": with its own code")
        Do $$$AssertTrue(tAnswer.reason '= "", $Piece(tCase, "|", 1) _ ": and a written sentence")
        Do $$$AssertEquals(tText [ "}{", 0, $Piece(tCase, "|", 1) _ ": in exactly one envelope")
    }
}

/// <p>AC1's error leg -- a provider call that failed writes its <code>llm</code> row all the same,
/// with <code>status</code> <code>error</code> and the fault's own machine code.
/// <method>TestATurnWritesOneProviderRowAndOneToolRow</method> asserts <code>ok</code> only, so the
/// branch that records a failure was unasserted: a turn whose provider never answered would leave
/// the ledger claiming it had.</p>
/// <p>Scripted HTTP 500, which <class>OcuPilot.Kernel.Provider.Retry</class> treats as retryable, so
/// the row records <code>PROVIDER.UNAVAILABLE</code> -- the code a retryable status on every attempt
/// produces (<class>OcuPilot.Test.TurnProviderFault</class> pins that mapping; this pins the row).
/// The wait is the sixty seconds that class uses, because the attempts spend real backoff.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Agent.Loop.RecordProviderRow</method>'s
/// status leg answer <code>"ok"</code> unconditionally -- this goes red and
/// <method>TestATurnWritesOneProviderRowAndOneToolRow</method> stays green.</p>
Method TestAFailedProviderCallWritesAnErrorRowWithItsCode()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, "", 500), "a provider failure is scripted")
    Set tId = ..Start("fail the provider call", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tStatus '= 202 Quit
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, ..Subject(), ..PreparedPassword, 60, .tTurnView), "failed", "the turn ends failed")

    Set tView = ..Read(..Subject(), "?turnKey=" _ tId, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner reads its own rows: " _ tText)
    If tStatus '= 200 Quit
    Set tLlm = ..RowOfKind(tView, "llm")
    Do $$$AssertTrue($IsObject(tLlm), "an llm row was written for the failed call: " _ tText)
    If '$IsObject(tLlm) Quit
    Do $$$AssertEquals(tLlm.status, "error", "carrying the failed outcome")
    Do $$$AssertEquals(tLlm.code, ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE, "and the fault's own machine code")
    Do $$$AssertEquals(tLlm.name, "turnprobe", "against the provider key it called")
    Do $$$AssertEquals(tLlm.user, ..Subject(), "recorded against the caller")
}

/// <p>A row whose argument string reaches the store longer than <code>LEDGERROWMAXLENGTH</code> is
/// cut there and reads <code>argumentsTruncated</code> 1 though its writer reported no cut; one of
/// exactly that length is kept whole and reads 0; a short string reads the writer's own answer, 0
/// or 1. Written through
/// <method>OcuPilot.Kernel.State.Ledger.GuardedAppend</method> under
/// <class>OcuPilot.Test.LedgerLimits</class>'s narrowed bound, one turn key per case, and read back
/// over the route by the owner.</p>
/// <p>Mutation (Rule 19): set <property>ArgumentsTruncated</property> from
/// <var>pArgumentsTruncated</var> alone in <method>OcuPilot.Kernel.State.Ledger.GuardedAppend</method>
/// -- the long-string case goes red. Compare the length with <code>&gt;=</code> -- the exact-length
/// case goes red.</p>
Method TestAnArgumentStringTheStoreCutsIsMarkedTruncated()
{
    Set tLimits = "OcuPilot.Test.LedgerLimits"
    Set tMax = +$Parameter(tLimits, "LEDGERROWMAXLENGTH")
    Set tLong = $Translate($Justify("", tMax + 12), " ", "a")
    Set tExact = $Translate($Justify("", tMax), " ", "a")
    For tCase = "long|0|1", "exact|0|0", "short|0|0", "short|1|1" {
        Set tKey = "ledgerwirecut" _ $Translate($System.Util.CreateGUID(), "-", "")
        Set tArguments = $Case($Piece(tCase, "|", 1), "long": tLong, "exact": tExact, : "{}")
        Set tSC = $ClassMethod(..#STORE, "GuardedAppend", tKey, ..Subject(), ..#CONTEXTROUTE, $Parameter(..#STORE, "KINDTOOL"), "probe.ledger.read", "", "", tArguments, $Piece(tCase, "|", 2), "ok", "", 0, 0, "", tLimits, .tSeq, .tStored)
        Do $$$AssertStatusOK(tSC, tCase _ ": the row is appended")
        Do $$$AssertEquals(tStored, 1, tCase _ ": and stored")
        Set tView = ..Read(..Subject(), "?turnKey=" _ tKey, .tStatus, .tText, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tCase _ ": the owner reads it: " _ $Extract(tText, 1, 200))
        Set tRow = ..RowOfKind(tView, $Parameter(..#STORE, "KINDTOOL"))
        Do $$$AssertTrue($IsObject(tRow), tCase _ ": the row is in the view")
        If '$IsObject(tRow) Continue
        Do $$$AssertEquals(tRow.argumentsTruncated, $Piece(tCase, "|", 3), tCase _ ": argumentsTruncated reads " _ $Piece(tCase, "|", 3))
        If $Piece(tCase, "|", 1) '= "short" Do $$$AssertEquals($Length(tRow.arguments), tMax, tCase _ ": at the bound")
    }
}

/// <p>Start a turn whose model asks the browser to open <parameter>TARGETROUTE</parameter>, a screen
/// neither principal may open -- refused by the dispatcher's argument-pair check before any
/// announcement exists, which is what makes the row's recorded requirement observable without a
/// browser.</p>
Method StartNavigationTurn(Output pStatus As %Integer, Output pText As %String) As %String
{
    Set tCalls = []
    Set tCall = {"id": "toolu_nav"}
    Do tCall.%Set("name", "shell_screen_open", "string")
    Set tInput = {}
    Do tInput.%Set("route", ..#TARGETROUTE, "string")
    Do tCall.%Set("input", tInput)
    Do tCalls.%Push(tCall)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Quit ..Start("open a screen I may not open", .pStatus, .pText)
}

/// <p>The keys of <var>pObject</var>, comma-separated in order.</p>
ClassMethod KeysOf(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    If '$IsObject(pObject) Quit ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

}
