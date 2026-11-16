/// <p>AD-9's open writes stay inside the instance's own rule: a turn reserve and a background run reserve sweep other
/// users' expired rows, a reserve ends other users' lost runs, and an abandon marks a named user's turns, and none of
/// them lets the caller decide what is written to another user's row. A real principal holding
/// <code>%Development:USE</code> and the install namespace's code read, and no <code>OcuPilotAdmin</code>, reserves with
/// a limits class that names no retention or queued limit, and while holding another user's row in memory with an edited
/// end time or an edited field; another user's just-ended turn and run, queued run and stored fields are as they were.
/// The same reserve still sweeps another user's genuinely expired turn and run and ends another user's lost run, and an
/// administrator's own sweep keeps the limits class it is given.</p>
/// <p>The calls run in a child process logged in as the principal (<class>OcuPilot.Test.PrefStateWriteProbe</class>);
/// the stored rows are seeded and read back here by SQL, as the suite's own <code>%All</code> identity.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes a user and a role
/// and writes turns and runs. <method>OnBeforeAllTests</method> refuses anywhere it does not. Every test removes the rows
/// it created, by the names only this class uses, and asserts the removal.</p>
Class OcuPilot.Test.ReserveSweepWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.PrefStateWriteProbe";

/// <p>The principal holding <code>%Development:USE</code> and the code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotSweepDev";

Parameter DEVROLE = "OcuPilotSweepDevRole";

/// <p>The user name whose turns and runs the developer attacks, and a second one whose turn a held key is aimed at. No
/// account has either.</p>
Parameter VICTIM = "OcuPilotSweepVictim";

Parameter BYSTANDER = "OcuPilotSweepBystander";

/// <p>The limits class the instance reads its own limits from.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A class that names no <code>RETENTIONSECONDS</code> or <code>QUEUEDSECONDS</code>.</p>
Parameter NOLIMITS = "OcuPilot.Kernel.Utils";

/// <p>A limits class a caller could pass: its retention is one second.</p>
Parameter SHORTLIMITS = "OcuPilot.Test.ReserveSweepWrite";

Parameter RETENTIONSECONDS As %Integer = 1;

Parameter QUEUEDSECONDS As %Integer = 1;

/// <p>A timestamp no live row carries: a row aged to it is past every retention.</p>
Parameter OLD = "2000-01-01T00:00:00Z";

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ReserveSweepWrite creates and deletes a user and a role and writes OcuPilot's stores on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotSweep" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(..PreparedPassword, ..Principals())
}

/// <p>Remove the principal and its role; a failing status when either survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Principals(), "OcuPilot.Test.ReserveSweepWrite")
}

/// <p>The developer, as <method>OcuPilot.Test.AdminStateWrite.EnsurePrincipals</method> takes it.</p>
ClassMethod Principals() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U", 0))
}

Method OnBeforeOneTest() As %Status
{
    Quit ..RemoveOwnRows()
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the turns, runs, proposals and start records this test created are removed")
    Do $$$AssertEquals(..LeftOver(), 0, "and none of them survives")
    Quit $$$OK
}

/// <p>A developer reserves a turn with a limits class that names no retention: another user's turn that ended a moment
/// ago is still there, and so is its proposal. The retention the reserve sweeps by is the instance's own.</p>
/// <p>Mutation (Rule 19): the limits class a non-administrator passes is used as given, in
/// <code>Turn.SweepAnyCaller</code> -> this goes red alone.</p>
Method TestAReserveWithNoRetentionLimitKeepsAnotherUsersEndedTurn()
{
    Do ..SeedTurn(..#VICTIM, "completed", .tFresh)
    Set tRun = ..Reserve("Turn.ReserveWith", {"limits": (..#NOLIMITS)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tFresh), 1, "another user's turn that ended a moment ago is kept")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCountForTurn(tFresh), 1, "with its proposal")
}

/// <p>A developer holds another user's just-ended turn in memory, with its end time put far back, and reserves with the
/// instance's own limits class: the turn is still there and its stored end time is as it was. The sweep reads each row's
/// state and end time from storage.</p>
/// <p>Mutation (Rule 19): the sweep reads each end time from the opened row, which a caller may hold, instead of by SQL
/// -> this goes red alone.</p>
Method TestAReserveHoldingAnotherUsersTurnKeepsIt()
{
    Do ..SeedTurn(..#VICTIM, "completed", .tFresh)
    Set tEndedBefore = ..Stored("SELECT EndedAt FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ tFresh _ "'")
    Set tId = ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ tFresh _ "'")
    Set tRun = ..Reserve("Turn.ReserveWith", {"limits": (..#LIMITS), "id": (tId), "heldField": "EndedAt", "heldValue": (..#OLD)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tFresh), 1, "the held turn is kept")
    Do $$$AssertEquals(..Stored("SELECT EndedAt FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ tFresh _ "'"), tEndedBefore, "and its stored end time is unchanged")
}

/// <p>A developer's reserve still sweeps another user's genuinely expired turn, with its proposal, and leaves a turn that
/// has not ended however old its stored end time reads.</p>
/// <p>Mutation (Rule 19): <code>Turn.GuardedReserve</code> calls no sweep -> this goes red alone; the sweep's delete
/// leaves the turn's proposal -> its proposal assertion goes red alone.</p>
Method TestAReserveStillSweepsAnotherUsersExpiredTurn()
{
    Do ..SeedTurn(..#VICTIM, "completed", .tOld)
    Do ..SeedTurn(..#VICTIM, "completed", .tFresh)
    Do ..SeedTurn(..#BYSTANDER, "running", .tLive)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Turn SET EndedAt = ? WHERE %EXACT(TurnKey) = ? OR %EXACT(TurnKey) = ?", ..#OLD, tOld, tLive), 0, "one turn ended long ago and a running turn carries an old end time")
    Set tRun = ..Reserve("Turn.ReserveWith", {"limits": (..#LIMITS)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertTrue(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("sweepOk"), "and the sweep reports success")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tOld), 0, "the expired turn is swept")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCountForTurn(tOld), 0, "with its proposal")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tFresh), 1, "a turn that ended a moment ago is kept")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tLive), 1, "and so is a running turn")
}

/// <p>An administrator's sweep keeps the limits class it is given: the suite's own identity, which holds
/// <code>%All</code>, sweeps with a one-second retention and a turn and a run that ended a few seconds ago are
/// deleted.</p>
/// <p>Mutation (Rule 19): the instance's limits class is used for an administrator too -> this goes red alone.</p>
Method TestAnAdministratorsSweepKeepsTheLimitsClassItIsGiven()
{
    Do ..SeedTurn(..#VICTIM, "completed", .tTurn)
    Do ..SeedRun(..#VICTIM, "sql", "ended", 5, .tRunKey)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Turn SET EndedAt = ? WHERE %EXACT(TurnKey) = ?", ..Ago(5), tTurn), 0, "the turn ended a few seconds ago")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedSweep(..#SHORTLIMITS), "the turn sweep answers")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.SqlRun).GuardedSweep(..#SHORTLIMITS), "and the run sweep")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tTurn), 0, "the turn is swept by the given retention")
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tRunKey _ "'"), 0, "and the run")
}

/// <p>A developer reserves a run with a limits class that names no retention: another user's run that ended a few
/// seconds ago is still there.</p>
/// <p>Mutation (Rule 19): the limits class a non-administrator passes is used as given, in
/// <code>SqlRun.SweepAnyCaller</code> -> this and the queued-limit test go red.</p>
Method TestARunReserveWithNoRetentionLimitKeepsAnotherUsersEndedRun()
{
    Do ..SeedRun(..#VICTIM, "sql", "ended", 5, .tKey)
    Set tRun = ..Reserve("SqlRun.ReserveWith", {"limits": (..#NOLIMITS)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), 1, "another user's run that ended a few seconds ago is kept")
}

/// <p>A developer holds another user's just-ended run in memory, with its end time put far back, and reserves with the
/// instance's own limits class: the run is still there and its stored end time is as it was.</p>
/// <p>Mutation (Rule 19): the run sweep reads each end time from the opened row instead of by SQL -> this goes red
/// alone.</p>
Method TestARunReserveHoldingAnotherUsersRunKeepsIt()
{
    Do ..SeedRun(..#VICTIM, "sql", "ended", 5, .tKey)
    Set tEndedBefore = ..Stored("SELECT EndedAt FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'")
    Set tId = ..Stored("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'")
    Set tRun = ..Reserve("SqlRun.ReserveWith", {"limits": (..#LIMITS), "id": (tId), "heldField": "EndedAt", "heldValue": (..#OLD)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), 1, "the held run is kept")
    Do $$$AssertEquals(..Stored("SELECT EndedAt FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), tEndedBefore, "and its stored end time is unchanged")
}

/// <p>A developer's run reserve still sweeps another user's genuinely expired run.</p>
/// <p>Mutation (Rule 19): <code>SqlRun.GuardedReserve</code> calls no sweep -> this goes red alone.</p>
Method TestARunReserveStillSweepsAnotherUsersExpiredRun()
{
    Do ..SeedRun(..#VICTIM, "sql", "ended", 0, .tOld)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET EndedAt = ? WHERE %EXACT(RunKey) = ?", ..#OLD, tOld), 0, "the run ended long ago")
    Set tRun = ..Reserve("SqlRun.ReserveWith", {"limits": (..#LIMITS)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tOld _ "'"), 0, "the expired run is swept")
}

/// <p>A developer reserves a run with a limits class that names no queued limit: another user's run that was queued a few
/// seconds ago is still queued. The queued limit a reserve ends lost runs by is the instance's own.</p>
/// <p>Mutation (Rule 19): the limits class a non-administrator passes is used as given, in
/// <code>SqlRun.GuardedReserve</code>'s own reconcile -> this goes red alone.</p>
Method TestARunReserveWithNoQueuedLimitKeepsAnotherUsersQueuedRun()
{
    Do ..SeedRun(..#VICTIM, "sql", "queued", 3, .tKey)
    Set tRun = ..Reserve("SqlRun.ReserveWith", {"limits": (..#NOLIMITS)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..Stored("SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), "queued", "another user's run that was queued a few seconds ago stays queued")
}

/// <p>A developer's run reserve still ends another user's lost runs, a running one whose job is gone and a queued one past
/// the instance's queued limit, and leaves its owner, kind, namespace and key as they were.</p>
/// <p>Mutation (Rule 19): <code>SqlRun.Reconcile</code> suspects only a queued row -> this and the held-edit test go
/// red.</p>
Method TestARunReserveStillEndsAnotherUsersLostRuns()
{
    Do ..ReserveRun(..#VICTIM, "sql", .tRunning)
    Do ..ReserveRun(..#VICTIM, "mdx", .tQueued)
    Do ..SetRun(tRunning, "running", 30)
    Do ..SetRun(tQueued, "queued", 60)
    Set tRun = ..Reserve("SqlRun.ReserveWith", {"limits": (..#LIMITS)})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    For tKey = tRunning, tQueued {
        Do $$$AssertEquals(..Stored("SELECT State || '|' || UserName FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), "failed|" _ ..#VICTIM, "a lost run of another user is ended failed and keeps its owner")
        Do $$$AssertNotEquals(..Stored("SELECT EndedAt FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), "", "with an end time")
    }
}

/// <p>A developer holds another user's lost run in memory with its namespace edited and reserves: the run is ended
/// <code>failed</code> and the edit is not stored.</p>
/// <p>Mutation (Rule 19): <code>SqlRun.Reconcile</code> saves the opened row instead of updating by SQL -> this goes
/// red alone.</p>
Method TestARunReserveStoresNoEditFromAHeldLostRun()
{
    Do ..SeedRun(..#VICTIM, "sql", "running", 30, .tKey)
    Set tBefore = ..Stored("SELECT Namespace || '|' || UserName || '|' || Kind FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'")
    Set tId = ..Stored("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'")
    Set tRun = ..Reserve("SqlRun.ReserveWith", {"limits": (..#LIMITS), "id": (tId), "heldField": "Namespace", "heldValue": "HELD"})
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.ReserveWith ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..Stored("SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), "failed", "the lost run is ended")
    Do $$$AssertEquals(..Stored("SELECT Namespace || '|' || UserName || '|' || Kind FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), tBefore, "and the held edit is not stored")
}

/// <p>A developer holds a victim's running turn in memory with its key set to a bystander's running turn and abandons the
/// victim's turns: the abandon signal is on the victim's turn and not on the bystander's.</p>
/// <p>Mutation (Rule 19): <code>Turn.GuardedAbandonForUser</code> reads each key from the opened row instead of by SQL
/// -> this goes red alone.</p>
Method TestAnAbandonIgnoresAHeldKey()
{
    Do ..SeedTurn(..#VICTIM, "running", .tVictim)
    Do ..SeedTurn(..#BYSTANDER, "running", .tBystander)
    Set tId = ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ tVictim _ "'")
    Set tRun = ..Reserve("Turn.HeldAbandon", {"id": (tId), "heldKey": (tBystander)}, ..#VICTIM)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.HeldAbandon ok=1 code=", "the abandon is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("count"), 1, "it names the victim's one running turn")
    Do $$$AssertEquals($Get(^OcuPilotTurnSignal(tVictim, "abandon")), 1, "the victim's turn carries the abandon signal")
    Do $$$AssertEquals($Get(^OcuPilotTurnSignal(tBystander, "abandon")), "", "and the bystander's turn does not")
}

/// <p>Run the plan step <var>pKind</var> with the fields <var>pFields</var> as the developer, naming <var>pUser</var> (the
/// developer by default), and answer what the child signalled.</p>
Method Reserve(pKind As %String, pFields As %DynamicObject, pUser As %String = {..#DEVUSER}) As %DynamicObject
{
    Do pFields.%Set("kind", pKind)
    Do pFields.%Set("user", pUser)
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(pFields)], ..#PROBE)
    Do $$$AssertEquals($Select(tRun.%IsDefined("error"): tRun.%Get("error"), 1: tRun.%Get("username") _ " " _ tRun.%Get("loggedIn")), ..#DEVUSER _ " 1", "the child process ran as " _ ..#DEVUSER)
    Do $$$AssertEquals(''tRun.%Get("holdsAdmin"), 0, "who does not hold OcuPilotAdmin:USE; roles " _ tRun.%Get("roles"))
    Do $$$AssertTrue(("," _ tRun.%Get("roles") _ ",") '[ ",%All,", "and does not hold %All")
    Quit tRun
}

/// <p>Store, as the suite's own identity, a turn of <var>pUser</var> in <var>pState</var> that ended now, with a proposal
/// minted on it. <var>pKey</var> is its key.</p>
Method SeedTurn(pUser As %String, pState As %String, Output pKey As %String)
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, pState, .pKey)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(pUser, "", pKey, "", .tProposal)
    Do $$$AssertStatusOK(tSC, "a " _ pState _ " turn of " _ pUser _ " is stored with a proposal")
}

/// <p>Store, as the suite's own identity, a run of <var>pUser</var> and kind <var>pKind</var> in <var>pState</var>
/// (<method>SetRun</method>). <var>pKey</var> is its key.</p>
Method SeedRun(pUser As %String, pKind As %String, pState As %String, pSecondsAgo As %Integer, Output pKey As %String)
{
    Do ..ReserveRun(pUser, pKind, .pKey)
    If pKey '= "" Do ..SetRun(pKey, pState, pSecondsAgo)
}

/// <p>Reserve a queued run of <var>pUser</var> and kind <var>pKind</var>, as the suite's own identity. A test that
/// stores several runs reserves them all before it sets any, because each reserve ends the lost runs it finds.</p>
Method ReserveRun(pUser As %String, pKind As %String, Output pKey As %String)
{
    Set tSC = ##class(OcuPilot.Kernel.State.SqlRun).GuardedReserve(pUser, $NAMESPACE, 100, ..#LIMITS, .pKey, .tBusy, .tFull, .tSweep, pKind)
    Do $$$AssertTrue($$$ISOK(tSC) && (pKey '= ""), "a " _ pKind _ " run of " _ pUser _ " is reserved")
}

/// <p>Put run <var>pKey</var> in <var>pState</var> -- <code>queued</code>, <code>running</code> with no job holding its
/// lock, or <code>ended</code> -- with its queued, started and ended times <var>pSecondsAgo</var> seconds back.</p>
Method SetRun(pKey As %String, pState As %String, pSecondsAgo As %Integer)
{
    Set tAgo = ..Ago(pSecondsAgo)
    If pState = "ended" {
        Set tCode = ..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET State = 'ended', QueuedAt = ?, EndedAt = ? WHERE %EXACT(RunKey) = ?", tAgo, tAgo, pKey)
    } ElseIf pState = "running" {
        Set tCode = ..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET State = 'running', JobId = '999999', QueuedAt = ?, StartedAt = ? WHERE %EXACT(RunKey) = ?", tAgo, tAgo, pKey)
    } Else {
        Set tCode = ..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET QueuedAt = ? WHERE %EXACT(RunKey) = ?", tAgo, pKey)
    }
    Do $$$AssertEquals(tCode, 0, "the run is " _ pState)
}

/// <p>The ISO timestamp <var>pSeconds</var> seconds before now.</p>
ClassMethod Ago(pSeconds As %Integer) As %String
{
    Set tSeconds = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() - pSeconds
    Quit ##class(OcuPilot.Kernel.State.Turn).Timestamp((tSeconds \ 86400) _ "," _ (tSeconds # 86400))
}

/// <p>Run <var>pSql</var> with <var>pArgs</var>, answering its SQLCODE.</p>
ClassMethod Exec(pSql As %String, pArgs...) As %Integer
{
    Quit ##class(%SQL.Statement).%ExecDirect(, pSql, pArgs...).%SQLCODE
}

/// <p>The first column of the first row <var>pSql</var> answers, or <code>""</code>.</p>
ClassMethod Stored(pSql As %String) As %String
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).Stored(pSql)
}

/// <p>Remove every turn, proposal, run and start record of the three names this class owns.</p>
Method RemoveOwnRows() As %Status
{
    Set tSC = $$$OK
    For tUser = ..#VICTIM, ..#DEVUSER, ..#BYSTANDER {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TurnKey FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(UserName) = ?", tUser)
        While tRS.%Next() {
            Set tKeys($Increment(tKeys)) = tRS.%GetData(1)
        }
        For tI = 1:1:+$Get(tKeys) {
            Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKeys(tI)))
        }
        Kill tKeys
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Turn).GuardedForgetStarts(tUser))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser(tUser))
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", tUser)
        If tRS.%SQLCODE < 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the runs could not be removed: SQLCODE " _ tRS.%SQLCODE))
    }
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining))
    Quit tSC
}

/// <p>How many turns, proposals and runs of the three names this class owns survive; the sum is 0 once
/// <method>RemoveOwnRows</method> has run.</p>
ClassMethod LeftOver() As %Integer
{
    Set tCount = 0
    For tTable = "Turn", "Proposal", "SqlRun" {
        Set tCount = tCount + ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State." _ tTable _ " WHERE UserName IN ('" _ ..#VICTIM _ "', '" _ ..#DEVUSER _ "', '" _ ..#BYSTANDER _ "')")
    }
    Quit tCount
}

}
