/// <p>What pins the ledger's two local-time conversions (AD-41 and the Dates convention): the
/// audit viewer's criteria, its echo of them and each row's <code>time</code> are the instance's local
/// clock, converted on the instance from the UTC the ledger stores.</p>
/// <p>The instance this suite runs on is on UTC, where both conversions are the identity. The probe
/// (<class>OcuPilot.Test.LedgerClockProbe</class>) runs the shipped read with a fixed two-hour offset, so the
/// window, the row's <code>time</code> and the echoed criteria are each seen to move the right way. A child
/// session in a zone with daylight saving runs the shipped conversions, which is what tells the two <code>-3</code>
/// forms apart: over fixed instants against a clock in that zone, and over a corpus of instants against the
/// vendor's own conversions.</p>
/// <p>It creates no principal. The one row it seeds belongs to a probe user and is removed after each
/// method. The zone legs start a child <code>iris session</code> (<class>OcuPilot.Test.ZoneSession</class>), so they
/// need <code>%System_CallOut:USE</code> and the sign-in without a password that the operating system's user of the
/// instance has in the container.</p>
Class OcuPilot.Test.LedgerClock Extends %UnitTest.TestCase
{

Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

Parameter PROBE = "OcuPilot.Test.LedgerClockProbe";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter SEARCH = "OcuPilot.Test.LedgerSearch";

Parameter USERSUFFIX = "A";

/// <p>UTC instants the shipped converters are compared with the vendor's over, in <parameter>ZONE</parameter>:
/// ordinary days, the two sides of a leap day and a year end, and the days on which a zone's clock changes. Each
/// instant's own clock text is also converted back as a local time, so the last two put the hour
/// <parameter>ZONE</parameter>'s clock skips and the hour it repeats through <code>LocalToUtc</code>.</p>
Parameter CORPUS = "2026-01-15T12:00:00Z,2026-07-15T12:00:00Z,2026-03-29T01:30:00Z,2026-10-25T00:30:00Z,2026-03-08T10:00:00Z,2026-11-01T09:30:00Z,2024-02-29T23:59:59Z,2025-12-31T23:59:59Z,2026-01-01T00:00:00Z,2000-01-01T00:00:00Z,2026-03-08T02:30:00Z,2026-11-01T01:30:00Z";

/// <p>The <code>TZ</code> the zone leg's child runs under: US Eastern, five hours west of Greenwich with daylight saving
/// from the second Sunday of March to the first Sunday of November, which the child reports as 300 minutes west.</p>
Parameter ZONE = "EST5EDT,M3.2.0,M11.1.0";

Parameter ZONEWEST = 300;

/// <p>UTC instants and, in the same order, the local time each reads as in <parameter>ZONE</parameter>: a winter and a
/// summer day, the last second before the clock moves forward and its first second after, and the same pair where it
/// moves back (the repeated hour has no single local reading in the other direction).</p>
Parameter ZONEUTC = "2026-01-15T12:00:00Z,2026-07-15T12:00:00Z,2026-03-08T06:59:59Z,2026-03-08T07:00:00Z,2026-11-01T05:59:59Z,2026-11-01T06:00:00Z";

Parameter ZONELOCAL = "2026-01-15 07:00:00,2026-07-15 08:00:00,2026-03-08 01:59:59,2026-03-08 03:00:00,2026-11-01 01:59:59,2026-11-01 01:00:00";

/// <p>Local times that name one instant in <parameter>ZONE</parameter> and, in the same order, the UTC form each reads as.</p>
Parameter ZONEBACKLOCAL = "2026-01-15 07:00:00,2026-07-15 08:00:00,2026-03-08 01:59:59,2026-03-08 03:00:00,2026-11-01 03:00:00";

Parameter ZONEBACKUTC = "2026-01-15T12:00:00Z,2026-07-15T12:00:00Z,2026-03-08T06:59:59Z,2026-03-08T07:00:00Z,2026-11-01T08:00:00Z";

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
/// the offset helpers replaced. On this UTC instance both are the identity, so the child session
/// <method>TestTheShippedConversionsFollowTheZoneOfTheProcess</method> uses computes both sides in
/// <parameter>ZONE</parameter>, and a control requires that the zone moved at least one instant.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Audit.Ledger.OffsetAtUtc</method> reading
/// <code>$ZDateTime(pUtcH, -3)</code> in place of <code>$ZDateTimeH(pUtcH, -3)</code> -- the <code>LocalFromUtc</code>
/// legs of the instants the zone moves go red.</p>
Method TestTheShippedOffsetIsTheInstancesOwn()
{
    Set tThere = ..ReadInZone(..#ZONE)
    Do $$$AssertEquals(tThere.%Get("error") _ "|" _ tThere.%Get("west"), "|" _ ..#ZONEWEST, "the child ran " _ ..#ZONEWEST _ " minutes west of Greenwich: " _ tThere.%ToJSON())
    If (tThere.%Get("error") '= "") || '$IsObject(tThere.%Get("corpus")) Quit
    Set tCorpus = $ListFromString(..#CORPUS)
    Do $$$AssertEquals(tThere.%Get("corpus").%Size(), $ListLength(tCorpus), "the child compared every instant of the corpus")
    Set tMoved = 0
    Set tIterator = tThere.%Get("corpus").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tUtc = tRow.%Get("utc")
        If tRow.%Get("vendorLocal") '= $Translate($Extract(tUtc, 1, 19), "T", " ") Set tMoved = tMoved + 1
        Do $$$AssertEquals(tRow.%Get("shippedLocal"), tRow.%Get("vendorLocal"), "in that zone the local form of " _ tUtc _ " is the vendor's")
        Do $$$AssertEquals(tRow.%Get("shippedUtc"), tRow.%Get("vendorUtc"), "and the UTC form of the local " _ tRow.%Get("local") _ " is the vendor's")
    }
    Do $$$AssertTrue(tMoved > 0, "control: the zone moved " _ tMoved _ " of the instants, so the comparison is not of two identities")
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

/// <p>The conversions keep their forms: a fractional second on either side is dropped, a value in the other
/// direction's form or short of a field answers <code>""</code>, and a shift that crosses a year end or a leap
/// day lands on the calendar's next day in both directions.</p>
/// <p>Mutation (Rule 19): drop the fractional-second group from the pattern in
/// <method>OcuPilot.Kernel.Audit.Ledger.LocalFromUtc</method> -- the fractional leg goes red.</p>
Method TestTheFormsRefusalsAndCalendarBoundariesAreUnchanged()
{
    Set tProbe = ..#PROBE
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2026-10-21T23:30:00.987Z"), "2026-10-22 01:30:00", "a UTC fractional second is dropped")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalToUtc", "2026-10-22 01:30:00.987"), "2026-10-21T23:30:00Z", "a local fractional second is dropped")
    For tValue = "", "2026-10-21 23:30:00", "2026-10-21T23:30:00", "2026-10-21T23:30Z" {
        Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", tValue), "", "'" _ tValue _ "' is not the ledger's UTC form")
    }
    For tValue = "", "2026-10-22T01:30:00Z", "2026-10-22 01:30", "2026-10-22 01:30:00Z" {
        Do $$$AssertEquals($ClassMethod(tProbe, "LocalToUtc", tValue), "", "'" _ tValue _ "' is not the local form")
    }
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2025-12-31T23:30:00Z"), "2026-01-01 01:30:00", "a UTC year end reads as the next year's first hours")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalToUtc", "2026-01-01 01:30:00"), "2025-12-31T23:30:00Z", "and the local first hours of a year read as the UTC year end")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2024-02-28T23:30:00Z"), "2024-02-29 01:30:00", "the day before a leap day reads as the leap day")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2024-02-29T23:30:00Z"), "2024-03-01 01:30:00", "a leap day's end reads as March 1")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2025-02-28T23:30:00Z"), "2025-03-01 01:30:00", "February's end in a common year reads as March 1")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalToUtc", "2024-03-01 00:30:00"), "2024-02-29T22:30:00Z", "March 1's first hours read as the leap day's end")
}

/// <p>The shipped class's conversions follow the zone of the process that runs them, with daylight saving, in both
/// directions. This process is on UTC, so a child session started with <code>TZ</code> set to <parameter>ZONE</parameter>
/// runs the shipped <method>OcuPilot.Kernel.Audit.Ledger.LocalFromUtc</method> and
/// <method>OcuPilot.Kernel.Audit.Ledger.LocalToUtc</method> over fixed instants, and each answer is compared with the time
/// a clock in that zone shows, written out here and not computed. A process can set <code>$ZTIMEZONE</code> without
/// moving the vendor's <code>-3</code> conversions, which follow the operating system's zone for the process, so the zone
/// is the child's.</p>
/// <p>It needs <code>%System_CallOut:USE</code> and a child <code>iris session</code> that signs in without a password, as the
/// operating system's user of the instance does in the container.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Kernel.Audit.Ledger.OffsetAtUtc</method> reading
/// <code>$ZDateTime(pUtcH, -3)</code> in place of <code>$ZDateTimeH(pUtcH, -3)</code> -- every <code>LocalFromUtc</code> leg
/// goes red; <method>OcuPilot.Kernel.Audit.Ledger.OffsetAtLocal</method> reading <code>$ZDateTimeH(pLocalH, -3)</code> in place
/// of <code>$ZDateTime(pLocalH, -3)</code> -- every <code>LocalToUtc</code> leg goes red.</p>
Method TestTheShippedConversionsFollowTheZoneOfTheProcess()
{
    Set tThere = ..ReadInZone(..#ZONE)
    Do $$$AssertEquals(tThere.%Get("error") _ "|" _ tThere.%Get("west"), "|" _ ..#ZONEWEST, "the child ran " _ ..#ZONEWEST _ " minutes west of Greenwich: " _ tThere.%ToJSON())
    If (tThere.%Get("error") '= "") || '$IsObject(tThere.%Get("from")) || '$IsObject(tThere.%Get("to")) Quit
    Set tUtc = $ListFromString(..#ZONEUTC, ",")
    Set tLocal = $ListFromString(..#ZONELOCAL, ",")
    For tI = 1:1:$ListLength(tUtc) {
        Do $$$AssertEquals(tThere.%Get("from").%Get(tI - 1), $List(tLocal, tI), $List(tUtc, tI) _ " reads as " _ $List(tLocal, tI) _ " on that zone's clock")
    }
    Set tBackLocal = $ListFromString(..#ZONEBACKLOCAL, ",")
    Set tBackUtc = $ListFromString(..#ZONEBACKUTC, ",")
    For tI = 1:1:$ListLength(tBackLocal) {
        Do $$$AssertEquals(tThere.%Get("to").%Get(tI - 1), $List(tBackUtc, tI), $List(tBackLocal, tI) _ " on that zone's clock is " _ $List(tBackUtc, tI))
    }
}

/// <p>Run <method>ZoneChild</method> in a new session, in the caller's namespace, whose environment sets <code>TZ</code> to
/// <var>pZone</var> (<method>OcuPilot.Test.ZoneSession.Signalled</method>), and answer what it signalled, or an object
/// carrying <code>error</code>.</p>
ClassMethod ReadInZone(pZone As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.ZoneSession).Signalled(pZone, "##class(" _ $ClassName() _ ").ZoneChild(" _ $Job _ ")")
}

/// <p>The session <method>ReadInZone</method> starts: signal process <var>pParent</var> with
/// <code>{west, from, to, corpus}</code> -- the zone's minutes west of Greenwich, the shipped <code>LocalFromUtc</code> of
/// each instant in <parameter>ZONEUTC</parameter>, the shipped <code>LocalToUtc</code> of each in
/// <parameter>ZONEBACKLOCAL</parameter>, and for each instant in <parameter>CORPUS</parameter> its clock text as
/// <code>local</code> with the shipped and the vendor's conversion each way -- or <code>{error}</code> when something
/// raised.</p>
ClassMethod ZoneChild(pParent As %Integer)
{
    Try {
        Set tOut = {"west": ($ZTimeZone), "from": [], "to": [], "corpus": []}
        Set tUtc = $ListFromString(..#ZONEUTC, ",")
        For tI = 1:1:$ListLength(tUtc) {
            Do tOut.from.%Push($ClassMethod(..#LEDGER, "LocalFromUtc", $List(tUtc, tI)))
        }
        Set tLocal = $ListFromString(..#ZONEBACKLOCAL, ",")
        For tI = 1:1:$ListLength(tLocal) {
            Do tOut.to.%Push($ClassMethod(..#LEDGER, "LocalToUtc", $List(tLocal, tI)))
        }
        Set tCorpus = $ListFromString(..#CORPUS, ",")
        For tI = 1:1:$ListLength(tCorpus) {
            Set tIso = $List(tCorpus, tI)
            Set tUtcH = $ZDateTimeH($Translate($Extract(tIso, 1, 19), "T", " "), 3)
            Set tClock = $ZDateTime(tUtcH, 3, 1)
            Set tRow = {"utc": (tIso), "local": (tClock)}
            Do tRow.%Set("shippedLocal", $ClassMethod(..#LEDGER, "LocalFromUtc", tIso))
            Do tRow.%Set("vendorLocal", $ZDateTime($ZDateTimeH(tUtcH, -3), 3, 1))
            Do tRow.%Set("shippedUtc", $ClassMethod(..#LEDGER, "LocalToUtc", tClock))
            Do tRow.%Set("vendorUtc", ##class(OcuPilot.Kernel.State.Turn).Timestamp($ZDateTime($ZDateTimeH(tClock, 3), -3)))
            Do tOut.corpus.%Push(tRow)
        }
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>The local clock form <code>YYYY-MM-DD HH:MM:SS</code> of <var>pSeconds</var> whole seconds since the
/// calendar's origin, formatted with no zone conversion, so a test can name the instant it expects
/// without asking the code under test.</p>
ClassMethod LocalAt(pSeconds As %Integer) As %String
{
    Quit $ZDateTime((pSeconds \ 86400) _ "," _ (pSeconds # 86400), 3, 1)
}

}
