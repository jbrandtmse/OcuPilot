/// <p>DW-1305 and DW-1321 together: <property>OcuPilot.Kernel.State.Ledger.PairsSense</property>
/// records <b>which claim</b> a row's <code>RequiredPairs</code> makes, so an honestly-empty
/// requirement can be told from one nobody read.</p>
/// <p>One column carried three meanings -- what a dispatcher checked, what a refusal knew the tool
/// declares, and what a turn's screen route requires -- and an empty set could mean any of them or
/// none. Every empty set was therefore withheld from every cross-user reader, including the rows
/// every turn from Home writes, whose requirement genuinely is nothing. The sense column is what
/// separates the two, and <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> releases an
/// empty set under <code>none</code> alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state, an account holding
/// <code>%All</code>, and nothing else. It spawns nothing, creates no principal and touches no
/// registration. Every row it writes names <parameter>PROBEUSER</parameter>, which
/// <method>OnAfterOneTest</method> asserts none of survives, or <code>$USERNAME</code> -- and the
/// latter are removed by their own turn key at the leg that wrote them, never by sweeping the
/// running account (<method>Clear</method>).</p>
Class OcuPilot.Test.LedgerSense Extends %UnitTest.TestCase
{

/// <p>The store whose column is under test.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The ledger's public face: the writers, the reader and the sense vocabulary.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

/// <p>The reader whose per-row gate is driven in process.</p>
Parameter GATEPROBE = "OcuPilot.Test.LedgerGateProbe";

/// <p>The shipped bounds.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The descriptor that declares an empty privilege set on purpose -- the row population DW-1305
/// is about.</p>
Parameter HOMEDESCRIPTOR = "OcuPilot.Screen.Descriptor.Home";

/// <p>The user every probe row records -- its own, so the teardown cannot reach a sibling's.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnLedgerSense";

/// <p>The cross-user reader. Never created as an account: the rows record it as text, and the gate
/// it meets is <class>OcuPilot.Test.LedgerGate</class>'s.</p>
Parameter READER = "OcuPilotProbeLedgerSenseReader";

/// <p>The dispatcher whose registry resolves a <b>client-fulfilled</b> tool, so
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> has one to resolve.</p>
Parameter CLIENTDISPATCH = "OcuPilot.Test.LedgerClientDispatchProbe";

/// <p>That tool's wire name, as <class>OcuPilot.Test.LedgerClientRows</class> spells it.</p>
Parameter CLIENTWIRE = "probe_ledger_clientread";

/// <p>The shipped loop over that dispatcher, which is what actually writes the row.</p>
Parameter CLIENTLOOP = "OcuPilot.Test.LedgerClientLoopProbe";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowCountFor(..#PROBEUSER), 0, "no probe ledger row survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining), "the probe turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Remove what this class wrote. <parameter>PROBEUSER</parameter> is a name no other class uses,
/// so deleting that account's rows whole reaches nothing else. The rows a leg writes under
/// <code>$USERNAME</code> are deleted <b>by turn key</b> at the leg that wrote them: the running
/// account on a development instance is the operator's, and
/// <code>GuardedDeleteForUser($Username)</code> is an unscoped
/// <code>DELETE ... WHERE UserName = ?</code> that would take every real ledger row that account
/// owns with it.</p>
Method Clear()
{
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
}

/// <p>A turn key no other class and no other call uses.</p>
ClassMethod NewTurnKey() As %String
{
    Quit "sense-" _ $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p>Home's own route, which is the route a turn started from Home carries, with
/// <var>pPairs</var> the pair set its descriptor declares and <var>pResolves</var> 1 when the
/// registry maps that route back to Home. Derived from the registry rather than written down --
/// and the route itself is the <b>empty string</b>, because Home is the root, which is exactly
/// why the writer must ask the registry rather than treat <code>""</code> as "no route".</p>
ClassMethod HomeRoute(Output pPairs As %List, Output pResolves As %Boolean) As %String
{
    Set pResolves = 0
    Set pPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#HOMEDESCRIPTOR, .tResolved)
    If 'tResolved Quit ""
    Set tRoute = $ClassMethod(..#HOMEDESCRIPTOR, "Route")
    Set pResolves = (##class(OcuPilot.Screen.Registry).DescriptorForRoute(tRoute) = ..#HOMEDESCRIPTOR)
    Quit tRoute
}

/// <p>The one row <var>pTurnKey</var> holds as <var>pUser</var> reads their own, or
/// <code>$$$NULLOREF</code>. Asserted to be exactly one, so a method reading a field off it is
/// never reading off a row it did not mean.</p>
Method OwnRow(pUser As %String, pTurnKey As %String) As %DynamicObject
{
    Set tSC = $ClassMethod(..#LEDGER, "ViewForUser", pUser, "", 0, pTurnKey, 10, .tView, .tFault)
    Do $$$AssertStatusOK(tSC, "the owner's read resolves")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    If '$IsObject(tView) Quit $$$NULLOREF
    Do $$$AssertEquals(tView.rowsSent, 1, "exactly one row was written: " _ tView.%ToJSON())
    If tView.rowsSent '= 1 Quit $$$NULLOREF
    Quit tView.rows.%Get(0)
}

/// <p>How many of <var>pTurnKey</var>'s rows a cross-user reader holding the administrative pair
/// and nothing else is given, with the withheld count in <var>pWithheld</var>. <var>pOwner</var>
/// defaults to <parameter>PROBEUSER</parameter>; the two governance-refusal legs below pass
/// <code>$Username</code>, whose turn they drive directly rather than through the mismatch this
/// class's cheapest refusal uses.</p>
Method CrossUserRows(pTurnKey As %String, Output pWithheld As %Integer, pOwner As %String = {..#PROBEUSER}) As %Integer
{
    Set pWithheld = -1
    Set tSC = $ClassMethod(..#GATEPROBE, "ViewForUser", ..#READER, pOwner, 0, pTurnKey, 10, .tView, .tFault)
    Do $$$AssertStatusOK(tSC, "the cross-user read resolves")
    Do $$$AssertEquals($IsObject(tFault), 0, "and is not refused at the cross-user gate")
    If '$IsObject(tView) Quit -1
    Set pWithheld = tView.rowsWithheld
    Quit tView.rowsSent
}

/// <p><b>DW-1305.</b> A row whose writer resolved its pairs and found none records
/// <code>none</code>, and is readable by a cross-user reader holding the ledger's own
/// administrative pair. This is the population the old column could not express: every turn
/// started from Home writes provider rows whose requirement genuinely is nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> read
/// <code>none</code> as withheld -- delete its <code>SenseNone</code> arm -- and the release
/// assertion goes red.</p>
Method TestARowThatNeedsNoPrivilegeIsReadableCrossUser()
{
    Set tRoute = ..HomeRoute(.tHomePairs, .tResolves)
    Do $$$AssertEquals(tResolves, 1, "Home's route resolves back to its own descriptor")
    Do $$$AssertEquals($ListLength(tHomePairs), 0, "and Home declares an empty privilege set, which is the case DW-1305 is about")
    ; An unknown route resolves to no descriptor at all, which is what keeps the release below a
    ; statement about a declared-empty requirement rather than about anything the registry cannot
    ; place.
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("no/such/route"), "", "while a route the registry does not carry resolves to nothing")
    If 'tResolves Quit

    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordProviderCall", tKey, ..#PROBEUSER, tRoute, "anthropic", "probe-model", 1, 10, 20, "ok", "", 200, ..#LIMITS), "a provider row is recorded for a turn started from Home")

    Set tRow = ..OwnRow(..#PROBEUSER, tKey)
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.kind, "llm", "an llm row")
    Do $$$AssertEquals(tRow.requiredPairs, "", "recording no requirement")
    Do $$$AssertEquals(tRow.pairsSense, $ClassMethod(..#LEDGER, "SenseNone"), "under the sense that says the writer resolved it and there was none")

    Do $$$AssertEquals(..CrossUserRows(tKey, .tWithheld), 1, "and the row is released to a cross-user reader")
    Do $$$AssertEquals(tWithheld, 0, "with nothing withheld")
}

/// <p><b>DW-1321.</b> A row stored before this column existed reads <code>""</code> and is still
/// withheld, which is exactly what it already got -- no pre-existing row is reinterpreted.</p>
/// <p>Mutation (Rule 19): make <method>ViewForUser</method>'s new arm read <code>""</code> as
/// <code>none</code> -- compare against <code>SenseNone()</code> with a default -- and this goes
/// red, releasing every legacy row to every administrator.</p>
Method TestALegacyRowIsStillWithheld()
{
    Set tKey = ..NewTurnKey()
    ; The shape every pre-DW-1305 row was stored in: no pairs, and no sense to say why.
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, ..#PROBEUSER, "", "probe.legacy.read", "", {}, "", "", "", "ok", "", ..#LIMITS, 1), "a legacy-shaped row is stored")

    Set tRow = ..OwnRow(..#PROBEUSER, tKey)
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.requiredPairs, "", "recording no requirement")
    Do $$$AssertEquals(tRow.pairsSense, "", "and no sense at all, which is what a legacy row holds")

    Do $$$AssertEquals(..CrossUserRows(tKey, .tWithheld), 0, "the row is withheld from a cross-user reader")
    Do $$$AssertEquals(tWithheld, 1, "and counted as withheld")
}

/// <p><b>DW-1321.</b> An empty set under any sense but <code>none</code> stays withheld: the
/// writer could not say what the call required, which is not the same as the call requiring
/// nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Audit.Ledger.SenseFor</method> ignore its
/// <var>pResolved</var> argument and always answer <method>SenseNone</method> -- every empty set
/// is released and this goes red on all three.</p>
Method TestAnEmptySetUnderEveryOtherSenseIsWithheld()
{
    Set tSenses = $ListBuild($ClassMethod(..#LEDGER, "SenseChecked"), $ClassMethod(..#LEDGER, "SenseDeclared"), $ClassMethod(..#LEDGER, "SenseRoute"))
    For tI = 1:1:$ListLength(tSenses) {
        Set tSense = $List(tSenses, tI)
        Set tKey = ..NewTurnKey()
        Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, ..#PROBEUSER, "", "probe.sense.read", "", {}, "", "", "", "ok", "", ..#LIMITS, 1, tSense), "a row is stored under the sense " _ tSense)
        Set tRow = ..OwnRow(..#PROBEUSER, tKey)
        If '$IsObject(tRow) Quit
        Do $$$AssertEquals(tRow.pairsSense, tSense, "carrying that sense on the wire")
        Do $$$AssertEquals(..CrossUserRows(tKey, .tWithheld), 0, "and is withheld cross-user under " _ tSense)
        Do $$$AssertEquals(tWithheld, 1, "counted as withheld under " _ tSense)
    }

    ; The rule itself, at the one place every writer asks it.
    Set tPair = $ListBuild($ListBuild("%Admin_Operate", "USE"))
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "SenseFor", $ClassMethod(..#LEDGER, "SenseChecked"), "", 1), $ClassMethod(..#LEDGER, "SenseNone"), "a writer that resolved its pairs and found none records none")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "SenseFor", $ClassMethod(..#LEDGER, "SenseChecked"), "", 0), $ClassMethod(..#LEDGER, "SenseChecked"), "one that could not read them keeps its own sense, and its empty set stays withheld")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "SenseFor", $ClassMethod(..#LEDGER, "SenseRoute"), tPair, 1), $ClassMethod(..#LEDGER, "SenseRoute"), "and a non-empty set keeps its writer's sense whatever happened")
}

/// <p><b>DW-1321.</b> The three writers record three different senses, each from the writer's own
/// path rather than from an argument a test chose.</p>
/// <p>The confirm's own <code>checked</code> row is
/// <class>OcuPilot.Test.AuditMarker</class>'s, because it needs a real confirmed write.</p>
/// <p>Mutation (Rule 19): pass <method>SenseChecked</method> at
/// <method>OcuPilot.Kernel.Agent.Loop.RecordRefusedRow</method> in place of
/// <method>SenseDeclared</method> -- the refusal leg goes red.</p>
Method TestEachWriterRecordsItsOwnSense()
{
    ; The dispatcher, which checks what it records.
    Set tDispatched = ..NewTurnKey()
    Do $$$AssertEquals(..DispatchedSense(tDispatched), $ClassMethod(..#LEDGER, "SenseChecked"), "a dispatched call records the sense of a check that was made")

    ; The provider writer on a screen route that declares a pair: what the route requires.
    Set tRoute = ##class(OcuPilot.Test.LedgerEmptyPairs).RoutedScreen(.tExpected)
    Do $$$AssertNotEquals(tRoute, "", "the registry declares a screen whose route requires at least one pair")
    If tRoute '= "" {
        Set tRouted = ..NewTurnKey()
        Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordProviderCall", tRouted, ..#PROBEUSER, tRoute, "anthropic", "probe-model", 1, 1, 1, "ok", "", 200, ..#LIMITS), "a provider row is recorded for a routed turn")
        Set tRoutedRow = ..OwnRow(..#PROBEUSER, tRouted)
        If $IsObject(tRoutedRow) {
            Do $$$AssertEquals(tRoutedRow.requiredPairs, tExpected, "carrying what the route declares")
            Do $$$AssertEquals(tRoutedRow.pairsSense, $ClassMethod(..#LEDGER, "SenseRoute"), "under the route sense")
        }
    }

    ; A refusal caught before dispatch, which knows only what the tool declares.
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")
    Set tUses = []
    Set tBlock = {"id": "toolu_sense"}
    Do tBlock.%Set("name", "probe_ledger_read", "string")
    Do tBlock.%Set("input", {"Name": "probe"})
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerLoopStopProbe", "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users"), "the call is answered")
    Set tRefusedRow = ..OwnRow(tUser, tKey)
    If $IsObject(tRefusedRow) {
        Do $$$AssertEquals(tRefusedRow.status, "stopped", "the boundary's own status")
        Do $$$AssertEquals(tRefusedRow.pairsSense, $ClassMethod(..#LEDGER, "SenseDeclared"), "under the declared sense: nothing was checked, and what it records is what the tool declares")
    }
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p><b>DW-1305, the client-fulfilled writer.</b> <method>ResolveClientCall</method> answers the
/// secret-argument question <b>before</b> it reads a privilege pair, and three refusals return in
/// between -- a user mismatch, a governance-gate error and a tool denial. So the row's sense must
/// come from <var>pPairsResolved</var>, which is 1 only once the pairs have been read, and never
/// from <var>pSecretDeclared</var>, which is already 1 on all three.</p>
/// <p>The user-mismatch branch is the cheapest of the three to drive, and it is the whole point:
/// the tool resolved, so a sense taken from the secret flag would read <code>none</code> on an
/// empty set and release the row to every cross-user reader -- the DW-1120 failure this column
/// exists to prevent, on the one path that could still reach it.</p>
/// <p>Mutation (Rule 19): pass <var>pClassified</var> in place of <var>pPairsResolved</var> at
/// <method>OcuPilot.Kernel.Agent.Loop.RecordClientRow</method>'s <method>SenseFor</method> call --
/// the recorded sense becomes <code>none</code>, the row is released, and this goes red on the
/// sense and on the withheld count.</p>
Method TestAClientCallRefusedBeforeItsPairsWereReadIsNotNone()
{
    Set tUser = ..#PROBEUSER
    ; The refusal this drives is the user mismatch, which is the cheapest of the three that return
    ; before a pair is read -- and the loop runs as this process, so the two really do differ.
    Do $$$AssertNotEquals(tUser, $Username, "the turn's user is not the process's, or the branch below never fires")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tBlock = {"id": "toolu_clientsense"}
    Do tBlock.%Set("name", ..#CLIENTWIRE, "string")
    Do tBlock.%Set("input", {"Name": "probe"})
    Set tUses = []
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do $$$AssertStatusOK($ClassMethod(..#CLIENTLOOP, "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users"), "the client call is answered")

    Set tRow = ..OwnRow(tUser, tKey)
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.requiredPairs, "", "the row records no requirement, because nothing read one")
        Do $$$AssertEquals(tRow.pairsSense, $ClassMethod(..#LEDGER, "SenseChecked"), "under checked rather than none: the tool resolved, but the refusal returned before any pair was read")
    }
    ; The property that matters: such a row stays withheld from a cross-user reader, exactly as it
    ; did before the sense column existed.
    Do $$$AssertEquals(..CrossUserRows(tKey, .tWithheld), 0, "and it is withheld cross-user")
    Do $$$AssertEquals(tWithheld, 1, "counted as withheld")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p><b>DW-1381, the governance-gate-error branch.</b> The user-mismatch leg above is the
/// cheapest of the three refusals <method>ResolveClientCall</method> returns before it reads a
/// privilege pair, but the review pass's fix threads <var>pPairsResolved</var> through all four
/// <method>OcuPilot.Kernel.Agent.Loop.RecordClientRow</method> call sites uniformly, and only that
/// one leg carried its own assertion. This drives the second: the governance gate itself answers
/// with an error status, which <method>ResolveClientCall</method> reads the same way as
/// <code>TOOL.UNAVAILABLE</code> -- refused before <var>pPairsResolved</var> is ever set. The
/// turn's owner is <code>$USERNAME</code> itself here, not <parameter>PROBEUSER</parameter>, so
/// the call reaches the gate rather than refusing on identity first.</p>
/// <p>Mutation (Rule 19): pass <var>pClassified</var> in place of <var>pPairsResolved</var> at
/// <method>Loop.RecordClientRow</method>'s <method>SenseFor</method> call -- the same production
/// change <method>TestAClientCallRefusedBeforeItsPairsWereReadIsNotNone</method> pins -- and this
/// goes red on the sense and on the cross-user release, because this branch also carries
/// <var>pSecretDeclared</var> 1 with no pair ever read.</p>
Method TestAGovernanceGateErrorRefusedBeforeItsPairsWereReadIsNotNone()
{
    Set tUser = $Username
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tBlock = {"id": "toolu_gateerror"}
    Do tBlock.%Set("name", ..#CLIENTWIRE, "string")
    Do tBlock.%Set("input", {"Name": "probe"})
    Set tUses = []
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do ##class(OcuPilot.Test.LedgerClientDispatchProbe).FailGate()
    Set tSC = $ClassMethod(..#CLIENTLOOP, "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users")
    Do ##class(OcuPilot.Test.LedgerClientDispatchProbe).ClearGate()
    Do $$$AssertStatusOK(tSC, "the client call is answered even though the gate failed")

    Set tRow = ..OwnRow(tUser, tKey)
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.requiredPairs, "", "the row records no requirement, because nothing read one")
        Do $$$AssertEquals(tRow.pairsSense, $ClassMethod(..#LEDGER, "SenseChecked"), "under checked rather than none: the gate refused before any pair was read")
    }
    Do $$$AssertEquals(..CrossUserRows(tKey, .tWithheld, tUser), 0, "and it is withheld cross-user")
    Do $$$AssertEquals(tWithheld, 1, "counted as withheld")
    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining, tUser), "the probe turn run under the process account is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
}

/// <p><b>DW-1381, the tool-denied branch.</b> The third refusal
/// <method>ResolveClientCall</method> returns before it reads a privilege pair: the gate decides
/// and denies. Same shape and same reason as the governance-gate-error leg above -- only the
/// gate's own answer differs.</p>
/// <p>Mutation (Rule 19): pass <var>pClassified</var> in place of <var>pPairsResolved</var> at
/// <method>Loop.RecordClientRow</method>'s <method>SenseFor</method> call -- the same production
/// change the two legs above pin -- and this goes red on the sense and on the cross-user
/// release.</p>
Method TestAToolDeniedRefusedBeforeItsPairsWereReadIsNotNone()
{
    Set tUser = $Username
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tBlock = {"id": "toolu_tooldenied"}
    Do tBlock.%Set("name", ..#CLIENTWIRE, "string")
    Do tBlock.%Set("input", {"Name": "probe"})
    Set tUses = []
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do ##class(OcuPilot.Test.LedgerClientDispatchProbe).DenyGate("AGENT.PROBEDENIED")
    Set tSC = $ClassMethod(..#CLIENTLOOP, "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users")
    Do ##class(OcuPilot.Test.LedgerClientDispatchProbe).ClearGate()
    Do $$$AssertStatusOK(tSC, "the client call is answered even though the gate denied")

    Set tRow = ..OwnRow(tUser, tKey)
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.requiredPairs, "", "the row records no requirement, because nothing read one")
        Do $$$AssertEquals(tRow.pairsSense, $ClassMethod(..#LEDGER, "SenseChecked"), "under checked rather than none: the gate denied before any pair was read")
    }
    Do $$$AssertEquals(..CrossUserRows(tKey, .tWithheld, tUser), 0, "and it is withheld cross-user")
    Do $$$AssertEquals(tWithheld, 1, "counted as withheld")
    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining, tUser), "the probe turn run under the process account is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
}

/// <p><b>The refusal between the two halves of the requirement.</b>
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> reads a tool's declared pairs
/// first and the pairs its arguments add second, and a call whose arguments fail validation is
/// refused in between. A tool that declares no static pair -- which
/// <class>OcuPilot.Screen.Tool.Navigate</class>, the one shipped client-fulfilled tool, does not,
/// resolving its whole requirement per call -- therefore has an empty union at that point with
/// nothing read about what the call actually required. The row must stay <code>checked</code> and
/// withheld, not <code>none</code> and released (DW-1120, DW-1305).</p>
/// <p>Mutation (Rule 19): move <code>Set pPairsResolved = 1</code> back above
/// <code>MissingPair(pUser, tPairs)</code> in <method>ResolveClientCall</method> -- where it sat
/// before this review -- and this goes red on the recorded sense <b>and</b> on the cross-user
/// release, which is the defect itself.</p>
Method TestACallRefusedBetweenTheTwoHalvesOfItsRequirementIsNotNone()
{
    Set tUser = $Username
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    ; additionalProperties is false on the probe tool's input schema, so this is refused by
    ; ValidateArguments -- after the declared pairs were read and before the argument pairs are.
    Set tBlock = {"id": "toolu_badargs"}
    Do tBlock.%Set("name", ..#CLIENTWIRE, "string")
    Do tBlock.%Set("input", {"NotADeclaredArgument": "x"})
    Set tUses = []
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Set tSC = $ClassMethod(..#CLIENTLOOP, "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users")
    Do $$$AssertStatusOK(tSC, "the client call is answered as an ordinary refusal")

    Set tRow = ..OwnRow(tUser, tKey)
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.requiredPairs, "", "the row records no requirement, because the half that would have carried one was never read")
        Do $$$AssertEquals(tRow.pairsSense, $ClassMethod(..#LEDGER, "SenseChecked"), "under checked rather than none: a declared set that is empty is not the whole requirement")
    }
    Do $$$AssertEquals(..CrossUserRows(tKey, .tWithheld, tUser), 0, "and it is withheld cross-user")
    Do $$$AssertEquals(tWithheld, 1, "counted as withheld")
    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining, tUser), "the probe turn run under the process account is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
}

/// <p>The sense the shipped dispatcher wrote for one answered call on <var>pTurnKey</var>, read
/// back through the view. The shape <method>OcuPilot.Test.LedgerPairs.DispatchedPairs</method>
/// established; the row names <code>$USERNAME</code>, which the teardown removes.</p>
ClassMethod DispatchedSense(pTurnKey As %String) As %String
{
    Set tOut = ""
    Try {
        Set tUse = {"id": "toolu_sense"}
        Do tUse.%Set("name", "probe_ledger_read", "string")
        Do tUse.%Set("input", {"Name": "probe"})
        Set tUses = []
        Do tUses.%Push(tUse)
        Set tSC = $ClassMethod("OcuPilot.Test.LedgerDispatchProbe", "Answer", pTurnKey, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "probe/route")
        If $$$ISERR(tSC) {
            Set tOut = "the dispatcher failed: " _ $System.Status.GetErrorText(tSC)
            Quit
        }
        Set tViewSC = $ClassMethod(..#LEDGER, "ViewForUser", $Username, "", 0, pTurnKey, 10, .tView, .tFault)
        If $$$ISERR(tViewSC) || $IsObject(tFault) || '$IsObject(tView) {
            Set tOut = "the view did not read"
            Quit
        }
        If tView.rowsSent '= 1 {
            Set tOut = "the call wrote " _ tView.rowsSent _ " rows: " _ tView.%ToJSON()
            Quit
        }
        Set tOut = tView.rows.%Get(0).pairsSense
    } Catch ex {
        Set tOut = "the read raised: " _ ex.DisplayString()
    }
    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", pTurnKey)
    Quit tOut
}

}
