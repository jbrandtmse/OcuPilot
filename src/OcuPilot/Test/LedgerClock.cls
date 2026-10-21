/// <p>What pins the ledger's two local-time conversions (AD-41 and the Dates convention): the
/// audit viewer's criteria, its echo of them and each row's <code>time</code> are the instance's local
/// clock, converted on the instance from the UTC the ledger stores.</p>
/// <p>The instance this suite runs on is on UTC, where both conversions are the identity. The probe
/// (<class>OcuPilot.Test.LedgerClockProbe</class>) runs the shipped read with a fixed two-hour offset, so the
/// window, the row's <code>time</code> and the echoed criteria are each seen to move the right way. The
/// shipped class's offset is pinned to the vendor's own conversion over a corpus of instants. On a UTC
/// instance this cannot tell which of the two <code>-3</code> forms each offset reads.</p>
/// <p>It creates no principal. The one row it seeds belongs to a probe user and is removed after each
/// method.</p>
Class OcuPilot.Test.LedgerClock Extends %UnitTest.TestCase
{

Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

Parameter PROBE = "OcuPilot.Test.LedgerClockProbe";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter SEARCH = "OcuPilot.Test.LedgerSearch";

Parameter USERSUFFIX = "A";

/// <p>UTC instants the shipped converters are compared with the vendor's over: ordinary days, the
/// two sides of a leap day and a year end, and the days on which a zone's clock changes.</p>
Parameter CORPUS = "2026-01-15T12:00:00Z,2026-07-15T12:00:00Z,2026-03-29T01:30:00Z,2026-10-25T00:30:00Z,2026-03-08T10:00:00Z,2026-11-01T09:30:00Z,2024-02-29T23:59:59Z,2025-12-31T23:59:59Z,2026-01-01T00:00:00Z,2000-01-01T00:00:00Z";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", $ClassMethod(..#SEARCH, "User", ..#USERSUFFIX))
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tUser = $ClassMethod(..#SEARCH, "User", ..#USERSUFFIX)
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", tUser)
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.Ledger", "RowCountFor", tUser), 0, "no ledger row of the probe user survives the method")
    Quit $$$OK
}

/// <p>With the probe's local time two hours ahead of UTC, a UTC instant converts forward by two hours, a
/// local instant converts back by two, the two round-trip, and a value that names no instant answers
/// <code>""</code> in both directions.</p>
/// <p>Mutation (Rule 19): subtract in place of add in <method>OcuPilot.Kernel.Audit.Ledger.LocalFromUtc</method>
/// -- the forward and round-trip legs go red.</p>
Method TestTheConversionsMoveOppositeWays()
{
    Set tProbe = ..#PROBE
    Set tUtc = "2026-10-21T23:30:00Z"
    Set tLocal = "2026-10-22 01:30:00"
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", tUtc), tLocal, "a UTC instant reads two hours later on the local clock")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalToUtc", tLocal), tUtc, "a local instant reads two hours earlier in UTC")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalToUtc", $ClassMethod(tProbe, "LocalFromUtc", tUtc)), tUtc, "the two round-trip")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2026-02-30T00:00:00Z"), "", "a UTC value that names no instant answers nothing")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalToUtc", "2026-02-30 00:00:00"), "", "a local value that names no instant answers nothing")
}

/// <p>The shipped class's two conversions answer exactly what the vendor's <code>-3</code> forms of
/// <code>$ZDateTimeH</code> and <code>$ZDateTime</code> give, over <parameter>CORPUS</parameter>: the formulas
/// the offset helpers replaced.</p>
Method TestTheShippedOffsetIsTheInstancesOwn()
{
    Set tLedger = ..#LEDGER
    Set tCorpus = $ListFromString(..#CORPUS)
    For tI = 1:1:$ListLength(tCorpus) {
        Set tUtc = $List(tCorpus, tI)
        Set tUtcH = $ZDateTimeH($Translate($Extract(tUtc, 1, 19), "T", " "), 3)
        Do $$$AssertEquals($ClassMethod(tLedger, "LocalFromUtc", tUtc), $ZDateTime($ZDateTimeH(tUtcH, -3), 3, 1), "the local form of " _ tUtc _ " is the vendor's")
        Set tLocal = $ZDateTime(tUtcH, 3, 1)
        Set tLocalH = $ZDateTimeH(tLocal, 3)
        Do $$$AssertEquals($ClassMethod(tLedger, "LocalToUtc", tLocal), ##class(OcuPilot.Kernel.State.Turn).Timestamp($ZDateTime(tLocalH, -3)), "the UTC form of the local " _ tLocal _ " is the vendor's")
    }
}

/// <p>The read converts its criteria, its echo of them and each row's <code>time</code> one way. A row is
/// seeded, and read through the probe inside a local window five minutes either side of now: the row is in the
/// view, its <code>time</code> is its <code>loggedAt</code> plus two hours, and <code>criteria.begin</code> and
/// <code>criteria.end</code> are the values sent.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> converting its
/// <code>pBegin</code> with <method>OcuPilot.Kernel.Audit.Ledger.LocalFromUtc</method> -- the window leg goes red;
/// <method>OcuPilot.Kernel.Audit.Ledger.AppliedCriteria</method> converting <code>begin</code> with
/// <method>OcuPilot.Kernel.Audit.Ledger.LocalToUtc</method> -- the echo leg goes red.</p>
Method TestTheReadConvertsItsCriteriaAndRowsTheOneWay()
{
    Set tProbe = ..#PROBE
    Set tUser = $ClassMethod(..#SEARCH, "User", ..#USERSUFFIX)
    Set tKey = $ClassMethod(..#SEARCH, "Seed", tUser, $ClassMethod(..#SEARCH, "ProbeRoute"), "OcuPilotProbeLedgerClockResource")
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set tOffset = $Parameter(tProbe, "OFFSET")
    Set tBegin = ..LocalAt(tNow + tOffset - 300)
    Set tEnd = ..LocalAt(tNow + tOffset + 300)
    Set tSC = $ClassMethod(tProbe, "ViewForUser", tUser, "", "", "", +$Parameter(..#LIMITS, "LEDGERVIEWMAXROWS"), .tView, .tFault, 0, "", tBegin, tEnd)
    Do $$$AssertStatusOK(tSC, "the windowed read answers")
    Do $$$AssertTrue($IsObject($Get(tView)), "with a view: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tView)) Quit

    Set tRow = ""
    Set tIterator = tView.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCandidate) {
        If tCandidate.turnKey = tKey Set tRow = tCandidate
    }
    Do $$$AssertTrue($IsObject(tRow), "the seeded row is inside the local window")
    If $IsObject(tRow) {
        Set tLoggedAt = ##class(OcuPilot.Kernel.State.Turn).SecondsOf(tRow.loggedAt)
        Do $$$AssertEquals(tRow.time, ..LocalAt(tLoggedAt + tOffset), "its time is its loggedAt " _ tRow.loggedAt _ " plus two hours")
    }
    Do $$$AssertEquals(tView.criteria.begin, tBegin, "the echoed begin is the begin sent")
    Do $$$AssertEquals(tView.criteria.end, tEnd, "the echoed end is the end sent")
}

/// <p>A read that sends no begin echoes the window's own start in local time: the default window's hours
/// before now, plus the probe's two hours, and no end.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Audit.Ledger.AppliedCriteria</method> converting the default
/// begin with <method>OcuPilot.Kernel.Audit.Ledger.LocalToUtc</method> -- this goes red.</p>
Method TestTheDefaultWindowsBeginIsEchoedInLocalTime()
{
    Set tProbe = ..#PROBE
    Set tUser = $ClassMethod(..#SEARCH, "User", ..#USERSUFFIX)
    Set tOffset = $Parameter(tProbe, "OFFSET")
    Set tHours = +$Parameter("OcuPilot.Kernel.State.Base", "BOUNDEDDEFAULTHOURS")
    Set tBefore = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set tSC = $ClassMethod(tProbe, "ViewForUser", tUser, "", 0, "", +$Parameter(..#LIMITS, "LEDGERVIEWMAXROWS"), .tView, .tFault)
    Set tAfter = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Do $$$AssertStatusOK(tSC, "the default-window read answers")
    Do $$$AssertTrue($IsObject($Get(tView)), "with a view: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tView)) Quit

    Set tBegin = tView.criteria.begin
    Set tBeginSeconds = $Select($Match(tBegin, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"): ##class(OcuPilot.Kernel.State.Turn).NowSeconds($ZDateTimeH(tBegin, 3)), 1: "")
    Do $$$AssertNotEquals(tBeginSeconds, "", "the echoed begin is a local time: " _ tBegin)
    If tBeginSeconds = "" Quit
    Set tLow = tBefore - (tHours * 3600) + tOffset
    Set tHigh = tAfter - (tHours * 3600) + tOffset
    Do $$$AssertTrue((tBeginSeconds >= tLow) && (tBeginSeconds <= tHigh), "the echoed begin " _ tBegin _ " is the default window's start plus two hours")
    Do $$$AssertEquals(tView.criteria.end, "", "and no end is echoed")
}

/// <p>The local clock form <code>YYYY-MM-DD HH:MM:SS</code> of <var>pSeconds</var> whole seconds since the
/// calendar's origin, formatted with no zone conversion, so a test can name the instant it expects
/// without asking the code under test.</p>
ClassMethod LocalAt(pSeconds As %Integer) As %String
{
    Quit $ZDateTime((pSeconds \ 86400) _ "," _ (pSeconds # 86400), 3, 1)
}

}
