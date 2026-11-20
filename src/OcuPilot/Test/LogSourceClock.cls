/// <p>Pins <method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method>'s direction and size (AC6, Story 21.20): on an instance whose
/// local time runs two hours ahead of UTC (<class>OcuPilot.Test.LogSourceClockProbe</class>) a UTC instant reads two hours later, in
/// the port's own form, and the shipped port's offset is the ledger's over the instants <class>OcuPilot.Test.LedgerClock</class>
/// compares. A UTC instance reads the identity either way, which is why the direction is driven through the probe.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. Live-safe: it creates nothing and writes nothing.</p>
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

}
