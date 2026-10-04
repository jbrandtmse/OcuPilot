/// <p>The retention sweep (Story 14.4, AD-37, DW-1122, DW-1240): an entry ages by its own
/// definition's retention, an empty conversation and the ledger by the longest; a turn past its
/// short retention takes its proposals with it while its conversation entry stays; a background SQL
/// run past its retention is swept (Story 19.15); and an account
/// deleted from the instance has its turns abandoned, its preferences and sharing removed and its
/// turn start records aged out, while
/// its transcripts and ledger rows survive and an administrator can still read them.</p>
/// <p><b>It creates and deletes an IRIS user and two agent definitions, so
/// <method>OnBeforeAllTests</method> refuses to run unless <parameter>ARMINGVARIABLE</parameter>
/// reads 1.</b> The sweep is instance-wide, so each method that runs it first counts the rows it
/// would remove that this class did not create, and refuses to sweep when there are any: it never
/// deletes another suite's transcripts or ledger rows. Every row it writes is removed by key.</p>
Class OcuPilot.Test.Retention Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter APIPATH = "/api/ocupilot";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The user every transcript this class writes names, save the deleted account's.</p>
Parameter PROBEUSER = "OcuPilotProbeRetention";

/// <p>A name no account holds, whose settings the principal-gone pass removes.</p>
Parameter GONEUSER = "OcuPilotProbeRetentionGone";

/// <p>A name no account holds, named only by a queued turn.</p>
Parameter GONETURNUSER = "OcuPilotProbeRetentionGoneTurn";

/// <p>A name no account holds, named only by a sharing row.</p>
Parameter GONESHAREUSER = "OcuPilotProbeRetentionGoneShare";

/// <p>The two probe definitions' name prefix.</p>
Parameter DEFINITIONPREFIX = "OcuPilotProbeRetention";

Property PreparedPassword As %String;

/// <p>What this method created, by kind: <code>convo</code>, <code>turn</code>,
/// <code>ledger</code> (turn keys) and <code>definition</code> ids.</p>
Property Created As %String [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.Retention creates and deletes an IRIS user and agent definitions, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.Retention teardown left:" _ tLeft)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tKey = ""
    For {
        Set tKey = $Order(..Created("convo", tKey))
        If tKey = "" Quit
        Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKey)
    }
    For {
        Set tKey = $Order(..Created("turn", tKey))
        If tKey = "" Quit
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey)
    }
    For {
        Set tKey = $Order(..Created("ledger", tKey))
        If tKey = "" Quit
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKey)
    }
    For {
        Set tKey = $Order(..Created("definition", tKey))
        If tKey = "" Quit
        Do ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tKey)
    }
    For tUser = ..#PROBEUSER, ..DeletedUser(), ..#GONEUSER, ..#GONETURNUSER, ..#GONESHAREUSER {
        Do ##class(OcuPilot.Kernel.State.Pref).GuardedDeleteForUser(tUser)
        Do ##class(OcuPilot.Kernel.State.Sharing).GuardedDeleteForUser(tUser)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(tUser)
        Do ##class(OcuPilot.Kernel.State.SqlRun).GuardedForgetUser(tUser)
    }
    Kill ..Created
    Quit $$$OK
}

ClassMethod DeletedUser() As %String
{
    Quit $Parameter(..#FIXTURE, "USERA")
}

/// <p>A probe definition retaining <var>pDays</var> days; its id.</p>
Method NewDefinition(pSuffix As %String, pDays As %Integer) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#DEFINITIONPREFIX _ pSuffix
    Set tRow.Provider = "anthropic"
    Set tRow.Model = "probe"
    Set tRow.RetentionDays = pDays
    If $$$ISERR(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)) Quit ""
    Set tId = tRow.%Id()
    Set ..Created("definition", tId) = ""
    Quit tId
}

/// <p>A conversation of <var>pUser</var>; its key.</p>
Method NewConversation(pUser As %String) As %String
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", pUser, 5, .tStatus, .tConflict)
    If '$IsObject(tConvo) Quit ""
    Set tKey = tConvo.ConvKey
    Set tConvo = ""
    Set ..Created("convo", tKey) = ""
    Quit tKey
}

/// <p>Append one entry to conversation <var>pKey</var> for turn <var>pTurnKey</var> under
/// definition <var>pDefinitionId</var>.</p>
ClassMethod Append(pKey As %String, pMessage As %String, pDefinitionId As %String = "", pTurnKey As %String = "") As %Status
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate(pKey, "", 5, .tStatus, .tConflict)
    If '$IsObject(tConvo) Quit tStatus
    Set tSC = ##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, pMessage, "completed", "a reply", "", 0, [], 0, ..#LIMITS, pTurnKey, "", "{""route"":""tasks/schedule""}", pDefinitionId)
    Set tConvo = ""
    Quit tSC
}

/// <p>ISO-8601 UTC <var>pDays</var> days before now.</p>
ClassMethod DaysAgo(pDays As %Integer) As %String
{
    Quit ##class(OcuPilot.Kernel.Retention).Iso(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - (pDays * 86400))
}

/// <p>Run <var>pSql</var> with <var>pArgs</var>, by direct SQL, answering its SQLCODE.</p>
ClassMethod Exec(pSql As %String, pArgs...) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pArgs...)
    Quit tRS.%SQLCODE
}

ClassMethod Count(pSql As %String, pArgs...) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pArgs...)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>How many rows the sweep would remove that this class did not create: an entry of another
/// user older than the shortest retention any definition holds, a ledger row of another user older
/// than the longest, and an empty conversation of another user older than the longest. The sweep
/// runs only when this is 0, so it can never delete another suite's rows.</p>
ClassMethod ForeignExpired() As %String
{
    Do ##class(OcuPilot.Kernel.State.Agent).GuardedRetentions(.tById, .tDefault, .tLongest)
    Set tShortest = tDefault
    Set tId = ""
    For {
        Set tId = $Order(tById(tId), 1, tDays)
        If tId = "" Quit
        If tDays < tShortest Set tShortest = tDays
    }
    Set tEntries = ..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry e JOIN OcuPilot_Kernel_State.Convo c ON c.ConvKey = e.ConvoKey WHERE %EXACT(c.UserName) <> ? AND %EXACT(c.UserName) <> ? AND %EXACT(COALESCE(e.AppendedAt, c.CreatedAt)) < ?", ..#PROBEUSER, ..DeletedUser(), ..DaysAgo(tShortest))
    Set tLedger = ..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) <> ? AND %EXACT(UserName) <> ? AND %EXACT(LoggedAt) < ?", ..#PROBEUSER, ..DeletedUser(), ..DaysAgo(tLongest))
    Set tConvos = ..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Convo c WHERE %EXACT(c.UserName) <> ? AND %EXACT(c.UserName) <> ? AND %EXACT(c.CreatedAt) < ?", ..#PROBEUSER, ..DeletedUser(), ..DaysAgo(tLongest))
    If (tEntries = 0) && (tLedger = 0) && (tConvos = 0) Quit ""
    Quit "entries " _ tEntries _ ", ledger rows " _ tLedger _ ", conversations " _ tConvos
}

/// <p>Run the sweep, unless another suite's rows are expired on this instance; answers whether it
/// ran.</p>
Method Sweep() As %Boolean
{
    Set tForeign = ..ForeignExpired()
    Do $$$AssertEquals(tForeign, "", "this instance holds no expired row another suite created, so the sweep removes only this class's own")
    If tForeign '= "" Quit 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Retention).Sweep(..#LIMITS), "the sweep runs")
    Quit 1
}

/// <p>AC2 and the Purge row: two entries two days old, one of a definition keeping one day and one
/// of a definition keeping thirty; the first goes and the second stays. A ledger row older than the
/// longest retention goes and one a day younger than it stays (DW-1122); an empty conversation
/// older than the longest goes and one a day younger stays.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Retention.Sweep</method> give every
/// definition the longest retention's cutoff -- the one-day entry stays and this goes red.</p>
Method TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest()
{
    Set tA = ..NewDefinition("A", 1)
    Set tB = ..NewDefinition("B", 30)
    Do $$$AssertTrue((tA '= "") && (tB '= ""), "two probe definitions exist")
    Set tKey = ..NewConversation(..#PROBEUSER)
    Do $$$AssertStatusOK(..Append(tKey, "on A", tA), "an entry of A")
    Do $$$AssertStatusOK(..Append(tKey, "on B", tB), "and one of B")
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Entry SET AppendedAt = ? WHERE %EXACT(ConvoKey) = ?", ..DaysAgo(2), tKey), 0, "both are two days old")

    Do ##class(OcuPilot.Kernel.State.Agent).GuardedRetentions(.tById, .tDefault, .tLongest)
    Do $$$AssertTrue(tLongest >= 30, "the longest retention is at least thirty days: " _ tLongest)
    Set tOld = "probetrretold" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
    Set tNew = "probetrretnew" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
    Set ..Created("ledger", tOld) = ""
    Set ..Created("ledger", tNew) = ""
    Do ##class(OcuPilot.Kernel.Audit.Ledger).RecordToolCall(tOld, ..#PROBEUSER, "", "probe.old", "", {}, "", "", "", "ok", "", ..#LIMITS, 1, "none")
    Do ##class(OcuPilot.Kernel.Audit.Ledger).RecordToolCall(tNew, ..#PROBEUSER, "", "probe.new", "", {}, "", "", "", "ok", "", ..#LIMITS, 1, "none")
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Ledger SET LoggedAt = ? WHERE %EXACT(TurnKey) = ?", ..DaysAgo(tLongest + 2), tOld), 0, "a ledger row older than the longest retention")
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Ledger SET LoggedAt = ? WHERE %EXACT(TurnKey) = ?", ..DaysAgo(tLongest - 1), tNew), 0, "and one older than the shortest retention but not the longest")

    Set tEmptyOld = ..NewConversation(..#PROBEUSER)
    Set tEmptyNew = ..NewConversation(..#PROBEUSER)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Convo SET CreatedAt = ? WHERE %EXACT(ConvKey) = ?", ..DaysAgo(tLongest + 2), tEmptyOld), 0, "an empty conversation older than the longest retention")
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Convo SET CreatedAt = ? WHERE %EXACT(ConvKey) = ?", ..DaysAgo(tLongest - 1), tEmptyNew), 0, "and one older than the shortest retention but not the longest")

    If '..Sweep() Quit
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? AND Message = 'on A'", tKey), 0, "the entry of the one-day definition is removed")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? AND Message = 'on B'", tKey), 1, "and the entry of the thirty-day definition stays")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tOld), 0, "the old ledger row is removed")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tNew), 1, "and the one younger than the longest retention stays")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", tEmptyOld), 0, "the old empty conversation is removed")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", tEmptyNew), 1, "and the one younger than the longest retention stays")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", tKey), 1, "a conversation still holding an entry stays")
}

/// <p>The Reload row (DW-1240): a turn that ended more than its retention ago is swept with its
/// proposals, so the restored conversation carries none for it, while the conversation entry that
/// records the turn stays.</p>
/// <p>Mutation (Rule 19): drop the proposal cascade from
/// <method>OcuPilot.Kernel.State.Turn.GuardedDelete</method> -- the proposal survives and this goes
/// red.</p>
Method TestATurnPastRetentionTakesItsProposalsAndLeavesItsEntry()
{
    Set tKey = ..NewConversation(..#PROBEUSER)
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve(..#PROBEUSER, "", "TURN.UNAVAILABLE", ..#LIMITS, .tTurn, .tBusy, .tSweep)
    Do $$$AssertStatusOK(tSC, "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and not refused as busy")
    Set ..Created("turn", tTurn) = ""
    Set tEnded = ##class(OcuPilot.Kernel.Retention).Iso(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Parameter(..#LIMITS, "RETENTIONSECONDS") - 60)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Turn SET State = 'completed', EndedAt = ? WHERE %EXACT(TurnKey) = ?", tEnded, tTurn), 0, "and ended before its retention")
    Kill tValues
    Set tValues("user") = ..#PROBEUSER
    Set tValues("convKey") = tKey
    Set tValues("turnKey") = tTurn
    Set tValues("toolName") = "tasks.schedule.run"
    Do ##class(OcuPilot.Kernel.EntityRef).Key("task", "instance", "OcuPilotProbeRetention", .tRef)
    Set tValues("targetRef") = tRef
    Set tValues("diff") = "[]"
    Set tValues("payload") = "{}"
    Set tValues("arguments") = "{}"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedMint(.tValues, ..#LIMITS, .tProposal, .tToken, .tExpires), "the turn minted a proposal")
    Do $$$AssertStatusOK(..Append(tKey, "run it", "", tTurn), "and its entry is appended")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForConvo(tKey, ..#PROBEUSER, .tBefore)
    Do $$$AssertEquals($Data(tBefore(tTurn)), 1, "a restore carries the proposal before the sweep")

    If '..Sweep() Quit
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedCountForTurn(tTurn, .tLeft)
    Do $$$AssertEquals(tLeft, 0, "the proposal is swept with its turn")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForConvo(tKey, ..#PROBEUSER, .tAfter)
    Do $$$AssertEquals($Data(tAfter(tTurn)), 0, "so a restore carries none for it")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedRows(tKey, .tRows), "the conversation reads")
    Do $$$AssertEquals(tRows.%Size(), 1, "and its entry is intact")
}

/// <p>Story 19.15: a background SQL run that ended past its retention is swept, and one that ended
/// inside it stays.</p>
/// <p>Mutation (Rule 19): remove the background run step from
/// <method>OcuPilot.Kernel.Retention.Sweep</method> -- the expired run stays and this goes red.</p>
Method TestABackgroundRunPastRetentionIsSwept()
{
    Set tStore = "OcuPilot.Kernel.State.SqlRun"
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedReserve", ..#PROBEUSER, "USER", 1000, ..#LIMITS, .tOld, .tBusy, .tFull, .tSweep), "a run is reserved")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedReserve", ..#GONEUSER, "USER", 1000, ..#LIMITS, .tNew, .tBusy, .tFull, .tSweep), "and another owner's")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedFinish", tOld, "ended", "{""outcome"":""done""}"), "the first ends")
    Do $$$AssertStatusOK($ClassMethod(tStore, "GuardedFinish", tNew, "ended", "{""outcome"":""done""}"), "and the second")
    Set tEnded = ##class(OcuPilot.Kernel.Retention).Iso(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Parameter(..#LIMITS, "RETENTIONSECONDS") - 60)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET EndedAt = ? WHERE %EXACT(RunKey) = ?", tEnded, tOld), 0, "the first ended before its retention")
    If '..Sweep() Quit
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ?", tOld), 0, "the expired run is swept")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ?", tNew), 1, "and the one inside its retention stays")
}

/// <p>AC5 and the Deleted-user row: a user with a transcript, a ledger row, preferences, a sharing
/// choice and a queued turn is deleted from the instance. The instance's own answer is measured
/// first -- the account's flag is not read while the escalation is in effect, and its token is
/// refused <code>401 AUTH.DISABLED</code> -- then the sweep abandons the turn and removes the
/// preferences and the sharing choice, while the transcript and the ledger row survive and an
/// administrator's gate still releases them.</p>
/// <p>Mutation (Rule 19): add <method>OcuPilot.Kernel.State.Convo.GuardedDelete</method> of the
/// user's conversations to <method>OcuPilot.Kernel.Retention.SweepGonePrincipals</method> -- the
/// transcript is gone and this goes red.</p>
Method TestADeletedUsersSettingsGoAndTheirTranscriptsStay()
{
    Set tUser = ..DeletedUser()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources")), "a probe account exists")
    Set tLogin = {}
    Do tLogin.%Set("user", tUser)
    Do tLogin.%Set("password", ..PreparedPassword)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIPATH _ "/login", "", "", .tStatus, .tRaw, .tHeaders, tLogin.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "it signs in")
    Set tAccess = $Select(tStatus = 200: ##class(%DynamicObject).%FromJSON(tRaw).%Get("access_token"), 1: "")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Test.Disabled).GetAs("/navigation", tAccess), "|", 1), 200, "and its token is served")

    Set tKey = ..NewConversation(tUser)
    Set tTurnKey = "probetrretdel" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
    Do $$$AssertStatusOK(..Append(tKey, "a question", "", tTurnKey), "it holds a transcript")
    Do ##class(OcuPilot.Kernel.Audit.Ledger).RecordToolCall(tTurnKey, tUser, "tasks/schedule", "tasks.schedule.read", "", {}, $ListBuild($ListBuild("%Admin_Operate", "USE")), "", "", "ok", "", ..#LIMITS, 1, "checked")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(tUser, "shell", "theme", "dark"), "a preference")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser(tUser, 0), "a sharing choice")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "", "TURN.UNAVAILABLE", ..#LIMITS, .tTurn, .tBusy, .tSweep), "and a queued turn")
    Set ..Created("turn", tTurn) = ""

    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "DeletePrincipal", tUser), "the account is deleted")
    Set tEnabled = ##class(OcuPilot.Kernel.State.Base).GuardedUserEnabled(tUser, .tKnown, .tUnavailable)
    Do $$$AssertEquals(tKnown _ "|" _ tUnavailable, "0|0", "the identity read finds no such account while its escalation is in effect")
    Do $$$AssertEquals(##class(OcuPilot.Test.Disabled).GetAs("/navigation", tAccess), "401|" _ ##class(OcuPilot.Kernel.Identity).#AUTHDISABLED, "and the deleted account's token is refused")

    If '..Sweep() Quit
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(tTurn, .tStop, .tAbandon, .tRenewed)
    Do $$$AssertEquals(tAbandon, 1, "its turn is asked to abandon")
    Do ##class(OcuPilot.Kernel.State.Pref).GuardedUsers(.tPrefUsers)
    Do $$$AssertEquals($Data(tPrefUsers(tUser)), 0, "its preferences are removed")
    Do ##class(OcuPilot.Kernel.State.Sharing).GuardedForUser(tUser, .tFound, .tShare)
    Do $$$AssertEquals(tFound, 0, "and its sharing choice")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedRows(tKey, .tRows, 1), "its transcript reads")
    Do $$$AssertEquals(tRows.%Size(), 1, "and survives")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tTurnKey), 1, "and so does its ledger row")
    Set ..Created("ledger", tTurnKey) = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Ledger).GateTurns($Username, tUser, tKey, $ListBuild(tTurnKey), .tReleased, .tFailed, .tFault), "an administrator's gate runs over it")
    Do $$$AssertEquals(tReleased, 1, "and releases it")
    Do $$$AssertEquals($IsObject(tFault), 0, "without a fault")
}

/// <p>The Purge row's error column: a step that throws is logged, the sweep answers a failed
/// status, and the steps after it still run -- here the first step is given a bounds class that
/// does not exist, and the principal-gone pass still removes the settings of a name no account
/// holds.</p>
/// <p>Mutation (Rule 19): remove the <code>Try</code> around the first step of
/// <method>OcuPilot.Kernel.Retention.Sweep</method> -- the sweep throws and this goes red.</p>
Method TestAFailingStepIsLoggedAndTheLaterStepsStillRun()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#GONEUSER, "shell", "theme", "dark"), "a name no account holds has a preference")
    Set tForeign = ..ForeignExpired()
    Do $$$AssertEquals(tForeign, "", "this instance holds no expired row another suite created, so the sweep removes only this class's own")
    If tForeign '= "" Quit
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Retention).Sweep("OcuPilot.Test.NoSuchLimitsClass")
        Set tThrew = 0
    } Catch ex {
        Set tThrew = 1
    }
    Do $$$AssertEquals(tThrew, 0, "a step that throws does not end the sweep")
    Do $$$AssertStatusNotOK(tSC, "and the sweep answers the failure")
    Do ##class(OcuPilot.Kernel.State.Pref).GuardedUsers(.tUsers)
    Do $$$AssertEquals($Data(tUsers(..#GONEUSER)), 0, "while the principal-gone pass after it still ran")
}

/// <p>A deleted account's turn start records (AD-37, Story 14.6): the sweep removes each record
/// past the turns-an-hour window, and one inside it stays until it ages out.</p>
/// <p>Mutation (Rule 19): drop the start-record step from
/// <method>OcuPilot.Kernel.Retention.Sweep</method> -- the old record stays and this goes red.</p>
Method TestADeletedAccountsStartRecordsAgeOut()
{
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedForgetStarts(..#GONEUSER)
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set ^OcuPilotTurnStarts(..#GONEUSER, tNow - 4000, "old") = ""
    Set ^OcuPilotTurnStarts(..#GONEUSER, tNow - 10, "fresh") = ""
    If ..Sweep() {
        Do $$$AssertEquals($Data(^OcuPilotTurnStarts(..#GONEUSER, tNow - 4000)), 0, "the record past the window is removed")
        Do $$$AssertEquals($Data(^OcuPilotTurnStarts(..#GONEUSER, tNow - 10, "fresh")), 1, "and the one inside it stays")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedForgetStarts(..#GONEUSER), "the probe's records are removed")
}

/// <p>The Storage row's fallbacks: an entry stored before its time and definition were kept ages
/// by its conversation's <code>CreatedAt</code> and the default definition's retention, and an entry
/// naming a definition that has gone ages by the default too; a recent entry of that gone
/// definition stays.</p>
/// <p>Mutation (Rule 19): drop the <code>CreatedAt</code> fallback from
/// <method>OcuPilot.Kernel.State.Entry.GuardedPurge</method> -- the older entry stays and this goes
/// red.</p>
Method TestAnOlderEntryAgesByItsConversationAndTheDefault()
{
    Do ##class(OcuPilot.Kernel.State.Agent).GuardedRetentions(.tById, .tDefault, .tLongest)
    Set tKey = ..NewConversation(..#PROBEUSER)
    Do $$$AssertStatusOK(..Append(tKey, "legacy"), "an entry is appended")
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Entry SET AppendedAt = NULL, DefinitionId = NULL WHERE %EXACT(ConvoKey) = ? AND Message = 'legacy'", tKey), 0, "and made to look older than the columns")
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Convo SET CreatedAt = ? WHERE %EXACT(ConvKey) = ?", ..DaysAgo(tDefault + 2), tKey), 0, "in a conversation older than the default retention")
    Do $$$AssertStatusOK(..Append(tKey, "gone definition", "0"), "an entry of a definition that no longer exists")
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Entry SET AppendedAt = ? WHERE %EXACT(ConvoKey) = ? AND Message = 'gone definition'", ..DaysAgo(tDefault + 2), tKey), 0, "older than the default retention")
    Do $$$AssertStatusOK(..Append(tKey, "fresh", "0"), "and a recent one of the same definition")

    If '..Sweep() Quit
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? AND Message = 'legacy'", tKey), 0, "the older entry ages by its conversation's start and is removed")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? AND Message = 'gone definition'", tKey), 0, "the gone definition's old entry ages by the default and is removed")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? AND Message = 'fresh'", tKey), 1, "and its recent one stays")
}

/// <p>The principal-gone pass finds a gone account through each store that names it: one named
/// only by a queued turn has the turn asked to abandon, and one named only by a sharing row has the
/// row removed.</p>
/// <p>Mutation (Rule 19): drop <code>Turn:GuardedLiveUsers</code> from
/// <method>OcuPilot.Kernel.Retention.SweepGonePrincipals</method>'s sources -- the turn is not asked
/// to abandon and this goes red.</p>
Method TestEachStoreNamesAGoneAccountToThePass()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(..#GONETURNUSER, "", "TURN.UNAVAILABLE", ..#LIMITS, .tTurn, .tBusy, .tSweep), "a name no account holds has a queued turn")
    Set ..Created("turn", tTurn) = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser(..#GONESHAREUSER, 0), "and another has a sharing choice")

    If '..Sweep() Quit
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(tTurn, .tStop, .tAbandon, .tRenewed)
    Do $$$AssertEquals(tAbandon, 1, "the turn's owner is found through the turn and its turn is asked to abandon")
    Do ##class(OcuPilot.Kernel.State.Sharing).GuardedForUser(..#GONESHAREUSER, .tFound, .tShare)
    Do $$$AssertEquals(tFound, 0, "and the sharing row's owner is found through it and the row is removed")
}

/// <p>The Deleted-user row's error column: while the identity read is unavailable, the
/// principal-gone pass removes nothing -- a name no account holds keeps its preference.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Retention.IsGone</method> answer 1 when
/// <code>GuardedUserAbsent</code> reports the read unavailable -- the preference is removed and this
/// goes red.</p>
Method TestAnUnreadableIdentityRemovesNothing()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(..#GONEUSER, "shell", "theme", "dark"), "a name no account holds has a preference")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.RetentionIdentityDown).SweepGonePrincipals(), "the pass runs over an unavailable identity read")
    Do ##class(OcuPilot.Kernel.State.Pref).GuardedUsers(.tUsers)
    Do $$$AssertEquals($Data(tUsers(..#GONEUSER)), 1, "and removes nothing")
}

/// <p>Only an account the instance answers does not exist reads as absent: a name no account holds
/// does, while an account that exists -- whatever the spelling -- and an empty name do not.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.Base.GuardedUserAbsent</method>
/// answer absent without asking the instance -- the existing account's leg goes red.</p>
Method TestOnlyAnAccountTheInstanceDoesNotHoldIsAbsent()
{
    Set tBase = "OcuPilot.Kernel.State.Base"
    Do $$$AssertEquals($ClassMethod(tBase, "GuardedUserAbsent", ..#GONEUSER, .tUnavailable), 1, "a name no account holds is absent")
    Do $$$AssertEquals(tUnavailable, 0, "read with the escalation in effect")
    Do $$$AssertEquals($ClassMethod(tBase, "GuardedUserAbsent", "_SYSTEM", .tUnavailable), 0, "an account the instance holds is not")
    Do $$$AssertEquals($ClassMethod(tBase, "GuardedUserAbsent", "_system", .tUnavailable), 0, "under any spelling")
    Do $$$AssertEquals($ClassMethod(tBase, "GuardedUserAbsent", "", .tUnavailable), 0, "and an empty name is never absent")
}

}
