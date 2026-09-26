/// <p>DW-1120, both halves (Story 5.4, AC8): an <b>empty requirement is never held</b> where it was
/// not declared, and the one place it is declared -- a screen that never gates -- is still
/// admitted.</p>
/// <p>The two questions are two entry points on <class>OcuPilot.Screen.Gate</class>.
/// <method>EvaluatePairs</method> asks whether a screen's declared requirement is met, and
/// <class>OcuPilot.Screen.Descriptor.Home</class> declares <code>"privileges": []</code>
/// deliberately; inverting that would lock every account out of Home.
/// <method>EvaluateRequired</method> asks whether a requirement was named at all, which is what the
/// ledger's per-row gate and every port's declared <code>Parameter</code> need.</p>
/// <p><b>DW-1305 changed what "empty" means here.</b> When these methods were written, every empty
/// recorded requirement was withheld from every cross-user reader, because the column could not
/// say whether the writer had resolved the pairs and found none or had never read them at all.
/// <property>OcuPilot.Kernel.State.Ledger.PairsSense</property> now records that, and an empty set
/// under <code>none</code> is released. The two methods below therefore assert the narrower claim
/// they always meant: a requirement <b>nobody read</b> is withheld. The released case and the
/// sense column itself are <class>OcuPilot.Test.LedgerSense</class>'s.</p>
/// <p><b>Live-safe.</b> It spawns nothing, creates no principal and touches no registration. Every
/// row it writes names <parameter>PROBEUSER</parameter>, and <method>OnAfterOneTest</method>
/// asserts none survives.</p>
Class OcuPilot.Test.LedgerEmptyPairs Extends %UnitTest.TestCase
{

/// <p>The gate under test.</p>
Parameter GATE = "OcuPilot.Screen.Gate";

/// <p>The ledger's public face, and the fixture whose per-row gate a test drives.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

Parameter GATEPROBE = "OcuPilot.Test.LedgerGateProbe";

/// <p>The store rows are written to.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The shipped bounds.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The descriptor that declares an empty privilege set on purpose.</p>
Parameter HOMEDESCRIPTOR = "OcuPilot.Screen.Descriptor.Home";

/// <p>The user every probe row records -- its own, so the teardown's sweep cannot reach a
/// sibling's rows.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnLedgerEmpty";

/// <p>The cross-user reader. Never created as an account: the rows record it as text, and the
/// gate a cross-user read meets is driven through <class>OcuPilot.Test.LedgerGate</class>.</p>
Parameter READER = "OcuPilotProbeLedgerEmptyReader";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowCountFor(..#PROBEUSER), 0, "no probe ledger row survives the method")
    Quit $$$OK
}

Method Clear()
{
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
}

/// <p>A turn key no other class and no other call uses.</p>
ClassMethod NewTurnKey() As %String
{
    Quit "emptypairs-" _ $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p><b>AC8</b> -- an empty or unreadable requirement is never held by
/// <method>EvaluateRequired</method>, while a set that is held still is.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.EvaluateRequired</method>'s empty-list
/// branch return 1 -> this goes red.</p>
Method TestAnEmptyRequirementIsNeverHeld()
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")

    Set tFailed = "sentinel"
    Do $$$AssertEquals(##class(OcuPilot.Test.ScreenGate).EvaluateRequired("", .tFailed), 0, "an empty requirement is not held")
    Do $$$AssertEquals(tFailed, "", "and names no pair, because there is none to name")
    Do $$$AssertEquals(##class(OcuPilot.Test.ScreenGate).EvaluateRequired("not a list", .tFailed2), 0, "nor is one that is not a list at all")

    Set tHeld = $ListBuild($ListBuild("%Admin_Operate", "USE"))
    Do $$$AssertEquals(##class(OcuPilot.Test.ScreenGate).EvaluateRequired(tHeld, .tFailed3), 1, "a named requirement the caller holds is held")
    Do $$$AssertEquals(tFailed3, "", "with no failed pair")

    Set tNotHeld = $ListBuild($ListBuild("%Admin_Secure", "USE"))
    Do $$$AssertEquals(##class(OcuPilot.Test.ScreenGate).EvaluateRequired(tNotHeld, .tFailed4), 0, "one it does not hold is refused")
    Do $$$AssertEquals(tFailed4, "%Admin_Secure:USE", "naming the pair that failed")

    ; The other entry point is unchanged: a DECLARED empty set is still satisfied by everyone.
    Do $$$AssertEquals(##class(OcuPilot.Test.ScreenGate).EvaluatePairs("", .tFailed5), 1, "EvaluatePairs still holds a declared-empty set")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

/// <p><b>AC8</b> -- Home, whose descriptor declares an empty privilege set, is still admitted. The
/// falsifier for the affordance this story deliberately preserves.</p>
/// <p>Mutation (Rule 19): point <method>OcuPilot.Screen.Gate.Evaluate</method> at
/// <method>EvaluateRequired</method> -> this goes red.</p>
Method TestHomeIsStillAdmitted()
{
    Set tPairs = $ClassMethod(..#GATE, "RequiredPairs", ..#HOMEDESCRIPTOR, .tResolved)
    Do $$$AssertEquals(tResolved, 1, "Home's requirement is readable")
    Do $$$AssertEquals($ListLength(tPairs), 0, "and is empty, which is how a screen that never gates is expressed")

    Set tFailed = "sentinel"
    Do $$$AssertEquals($ClassMethod(..#GATE, "Evaluate", ..#HOMEDESCRIPTOR, .tFailed), 1, "so Home is admitted")
    Do $$$AssertEquals(tFailed, "", "with no pair named")
}

/// <p><b>AC8</b> (DW-1120), as DW-1305 narrowed it -- a stored row whose requirement <b>nobody
/// read</b> is withheld from a cross-user reader holding the OcuPilot administrative pair, and is
/// visible to its owner.</p>
/// <p>The row below carries no sense, which is what a writer that could not read the requirement
/// records and what every row stored before that column existed holds. A row whose writer resolved
/// the pairs and found none is a different fact and is released;
/// <method>OcuPilot.Test.LedgerSense.TestARowThatNeedsNoPrivilegeIsReadableCrossUser</method> is
/// that half.</p>
/// <p>Mutation (Rule 19): point <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s per-row
/// gate back at <method>EvaluatePairs</method> -> the withheld row is released and this goes
/// red.</p>
Method TestARowWithNoRecordedRequirementIsWithheldCrossUser()
{
    Set tKey = ..NewTurnKey()
    ; Recorded through the shipped tool recorder with both pair halves empty and no sense, which is
    ; the shape every pre-DW-1120 llm and pre-dispatch refusal row was stored in.
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, ..#PROBEUSER, "", "probe.empty.read", "", {}, "", "", "", "ok", "", ..#LIMITS, 1), "a row with no recorded requirement is stored")

    ; The owner's own read is never gated on the row's requirement (AD-46).
    Do $$$AssertStatusOK($ClassMethod(..#GATEPROBE, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tOwn, .tOwnFault), "the owner's read resolves")
    Do $$$AssertEquals($IsObject(tOwnFault), 0, "with no fault")
    Do $$$AssertEquals(tOwn.rowsSent, 1, "and the owner sees their own row: " _ tOwn.%ToJSON())

    ; The cross-user reader holds the administrative pair and nothing else, which is DW-1120's
    ; exact case: an empty recorded requirement must not read as "requires nothing".
    Do $$$AssertStatusOK($ClassMethod(..#GATEPROBE, "ViewForUser", ..#READER, ..#PROBEUSER, 0, tKey, 10, .tView, .tFault), "the cross-user read resolves")
    Do $$$AssertEquals($IsObject(tFault), 0, "and is not refused at the cross-user gate")
    Do $$$AssertEquals(tView.rowsSent, 0, "the row is withheld: " _ tView.%ToJSON())
    Do $$$AssertEquals(tView.rowsWithheld, 1, "and counted as withheld")
    Do $$$AssertEquals(tOwn.rows.%Get(0).pairsSense, "", "because the row states no sense, which is what 'nobody read it' looks like (DW-1305)")

    ; A row that DOES record a requirement the reader holds is still released, so the assertion
    ; above is about the empty requirement and not about the gate refusing everything.
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Operate", "USE")
    Set tPairs = $ListBuild($ListBuild("%Admin_Operate", "USE"))
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, ..#PROBEUSER, "", "probe.named.read", "", {}, tPairs, "", "", "ok", "", ..#LIMITS, 1), "a row that names its requirement is stored")
    Do $$$AssertStatusOK($ClassMethod(..#GATEPROBE, "ViewForUser", ..#READER, ..#PROBEUSER, 0, tKey, 10, .tView2, .tFault2), "the second cross-user read resolves")
    Do $$$AssertEquals(tView2.rowsSent, 1, "the named row is released: " _ tView2.%ToJSON())
    Do $$$AssertEquals(tView2.rowsWithheld, 1, "and the empty one is still withheld")
}

/// <p><b>AC8</b> -- the provider-call writer records the requirement the turn carries: the pair set
/// of the screen route it ran from, and, for a turn whose route declares none, an empty set under
/// the <code>none</code> sense (DW-1305).</p>
/// <p><b>A turn with no screen context carries the empty route, and the empty route is Home's.</b>
/// <class>OcuPilot.Screen.Descriptor.Home</class> declares <code>Route()</code> as <code>""</code>
/// because Home is the root, so the registry maps that value to Home and the writer records what
/// Home requires, which is nothing. That row is therefore readable cross-user, where before
/// DW-1305 every empty set was withheld. A route the registry cannot place is the case that stays
/// withheld, and <class>OcuPilot.Test.LedgerSense</class> holds both halves.</p>
/// <p>Mutation (Rule 19): pass <code>""</code> for the pair set in
/// <method>OcuPilot.Kernel.Audit.Ledger.RecordProviderCall</method> again -> the routed row records
/// nothing and this goes red.</p>
Method TestTheProviderWriterRecordsTheTurnsRequirement()
{
    Set tRoute = ..RoutedScreen(.tExpected)
    Do $$$AssertNotEquals(tRoute, "", "the registry declares a screen whose route requires at least one pair")
    If tRoute = "" Quit

    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordProviderCall", tKey, ..#PROBEUSER, tRoute, "anthropic", "probe-model", 1, 10, 20, "ok", "", 200, ..#LIMITS), "a provider row is recorded for a turn with a screen route")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the owner's read resolves")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.kind, "llm", "an llm row")
        Do $$$AssertEquals(tRow.requiredPairs, tExpected, "carrying the pair set the screen route declares")
        Do $$$AssertEquals(tRow.pairsSense, $ClassMethod(..#LEDGER, "SenseRoute"), "under the sense that says so")
    }

    Set tKey2 = ..NewTurnKey()
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordProviderCall", tKey2, ..#PROBEUSER, "", "anthropic", "probe-model", 1, 10, 20, "ok", "", 200, ..#LIMITS), "a provider row is recorded for a turn with no screen context")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey2, 10, .tView2, .tFault2), "that owner's read resolves too")
    Do $$$AssertEquals(tView2.rowsSent, 1, "one row for the turn with no screen context: " _ tView2.%ToJSON())
    If tView2.rowsSent = 1 {
        Do $$$AssertEquals(tView2.rows.%Get(0).requiredPairs, "", "which records nothing")
        ; Under `none`: the empty route is Home's own, the registry resolves it, and what Home
        ; requires is nothing -- a requirement that was read, not one nobody read (DW-1305).
        Do $$$AssertEquals(tView2.rows.%Get(0).pairsSense, $ClassMethod(..#LEDGER, "SenseNone"), "under the none sense, because the route resolved and declared nothing")
    }
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#GATEPROBE, "ViewForUser", ..#READER, ..#PROBEUSER, 0, tKey2, 10, .tCross2, .tCrossFault2), "a cross-user read of that row resolves")
    Do $$$AssertEquals(tCross2.rowsSent, 1, "and it is released, holding the ledger's admin pair alone")
    Do $$$AssertEquals(tCross2.rowsWithheld, 0, "with nothing withheld")
}

/// <p>The route of the first declared screen whose requirement is non-empty, with that
/// requirement's canonical string in <var>pExpected</var>. Derived from the registry rather than
/// written down, so a renamed screen does not turn this into a test of a literal.</p>
ClassMethod RoutedScreen(Output pExpected As %String) As %String
{
    Set pExpected = ""
    Set tRoute = ""
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    If $$$ISERR(tSC) Quit ""
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
        If 'tResolved || ($ListLength(tPairs) = 0) Continue
        Set tCandidate = $ClassMethod(tClass, "Route")
        If tCandidate = "" Continue
        ; The route has to resolve back to this descriptor, which is what the writer does.
        If ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tCandidate) '= tClass Continue
        Set tRoute = tCandidate
        Set pExpected = ##class(OcuPilot.Kernel.Audit.Ledger).PairsToString(tPairs, .tCut)
        Quit
    }
    Quit tRoute
}

}
