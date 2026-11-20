/// <p>Pins <method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method>'s direction and size (AC6, Story 21.20): on an instance whose
/// local time runs two hours ahead of UTC (<class>OcuPilot.Test.LogSourceClockProbe</class>) a UTC instant reads two hours later, in
/// the port's own form, and the shipped port's offset is the ledger's over the instants <class>OcuPilot.Test.LedgerClock</class>
/// compares. A UTC instance reads the identity either way, which is why the direction is driven through the probe, and the shipped
/// port is also read in a child session of another zone.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries, and what <class>OcuPilot.Test.ZoneSession</class> needs
/// for its child session. Live-safe: it creates nothing and writes nothing.</p>
Class OcuPilot.Test.LogSourceClock Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.LogSourceClockProbe";

Parameter PORT = "OcuPilot.Port.LogSourcePort";

Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

/// <p>With the probe's local time two hours ahead of UTC, a UTC instant converts forward by two hours, across a day boundary and
/// with a fractional second kept to the millisecond, and a value that is not an instant answers <code>""</code>.</p>
/// <p>Mutation (Rule 19): subtract in place of add in <method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method> -- the forward legs
/// go red.</p>
Method TestAUtcInstantReadsTwoHoursLaterOnTheLocalClock()
{
    Set tProbe = ..#PROBE
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2026-03-01 10:00:00"), "2026-03-01T12:00:00.000", "a UTC instant reads two hours later")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2026-10-21 23:30:00.5"), "2026-10-22T01:30:00.500", "across midnight, with its fraction kept to the millisecond")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "2026-02-30 00:00:00"), "", "a value that names no instant answers nothing")
    Do $$$AssertEquals($ClassMethod(tProbe, "LocalFromUtc", "not a time"), "", "and so does a value that is not the form")
}

/// <p>The shipped port's offset is the ledger's at every instant of the ledger clock's corpus, and the shipped conversion is the
/// ledger's with the port's own form.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.OffsetAtUtc</method> answering <code>1</code> -- this goes red on the first
/// instant.</p>
Method TestTheShippedOffsetIsTheLedgers()
{
    Set tCorpus = $ListFromString($Parameter("OcuPilot.Test.LedgerClock", "CORPUS"))
    Do $$$AssertTrue($ListLength(tCorpus) > 0, "the ledger clock's corpus is not empty")
    For tI = 1:1:$ListLength(tCorpus) {
        Set tUtc = $List(tCorpus, tI)
        Set tUtcH = $ZDateTimeH($Translate($Extract(tUtc, 1, 19), "T", " "), 3)
        Do $$$AssertEquals($ClassMethod(..#PORT, "OffsetAtUtc", tUtcH), $ClassMethod(..#LEDGER, "OffsetAtUtc", tUtcH), "the offset at " _ tUtc _ " is the ledger's")
        Set tLedger = $ClassMethod(..#LEDGER, "LocalFromUtc", tUtc)
        Do $$$AssertEquals($ClassMethod(..#PORT, "LocalFromUtc", $Translate($Extract(tUtc, 1, 19), "T", " ")), $Extract(tLedger, 1, 10) _ "T" _ $Extract(tLedger, 12, 19) _ ".000", "and so is the local instant of " _ tUtc)
    }
}

/// <p>In a child session whose zone is <class>OcuPilot.Test.LedgerClock</class>'s US Eastern zone, the shipped port reads each of
/// that class's UTC instants as the local time it names there, on both sides of each clock change, so the shipped offset's sign
/// and size are checked where they are not zero.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.OffsetAtUtc</method> answering <code>0</code> -- every instant goes
/// red.</p>
Method TestTheShippedPortReadsTheZonesLocalClock()
{
    Set tClock = "OcuPilot.Test.LedgerClock"
    Set tThere = ##class(OcuPilot.Test.ZoneSession).Signalled($Parameter(tClock, "ZONE"), "##class(" _ $ClassName() _ ").ZoneChild(" _ $Job _ ")")
    Do $$$AssertEquals(tThere.%Get("error") _ "|" _ tThere.%Get("west"), "|" _ $Parameter(tClock, "ZONEWEST"), "the child ran " _ $Parameter(tClock, "ZONEWEST") _ " minutes west of Greenwich: " _ tThere.%ToJSON())
    If (tThere.%Get("error") '= "") || '$IsObject(tThere.%Get("from")) Quit
    Set tUtc = $ListFromString($Parameter(tClock, "ZONEUTC"), ",")
    Set tLocal = $ListFromString($Parameter(tClock, "ZONELOCAL"), ",")
    Do $$$AssertEquals(tThere.%Get("from").%Size(), $ListLength(tUtc), "the child converted every instant")
    For tI = 1:1:$ListLength(tUtc) {
        Do $$$AssertEquals(tThere.%Get("from").%Get(tI - 1), $Translate($List(tLocal, tI), " ", "T") _ ".000", $List(tUtc, tI) _ " reads as " _ $List(tLocal, tI) _ " on that zone's clock")
    }
}

/// <p>The child session <method>TestTheShippedPortReadsTheZonesLocalClock</method> starts: the shipped port's
/// <method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method> of each of <class>OcuPilot.Test.LedgerClock</class>'s zone instants,
/// signalled to process <var>pParent</var> as <code>{west, from}</code>, or <code>{error}</code>.</p>
ClassMethod ZoneChild(pParent As %Integer)
{
    Try {
        Set tOut = {"west": ($ZTimeZone), "from": []}
        Set tUtc = $ListFromString($Parameter("OcuPilot.Test.LedgerClock", "ZONEUTC"), ",")
        For tI = 1:1:$ListLength(tUtc) {
            Do tOut.from.%Push($ClassMethod(..#PORT, "LocalFromUtc", $Translate($Extract($List(tUtc, tI), 1, 19), "T", " ")))
        }
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
