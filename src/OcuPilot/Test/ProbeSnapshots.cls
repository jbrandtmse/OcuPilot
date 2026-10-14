/// <p>Pins that the five test probes whose <code>Snapshot</code> a class compares before and after it ran
/// (<class>OcuPilot.Test.EcpProbe</class>, <class>OcuPilot.Test.EncryptionProbe</class>,
/// <class>OcuPilot.Test.JournalProbe</class>, <class>OcuPilot.Test.LicenseProbe</class> and
/// <class>OcuPilot.Test.RemoteDatabaseProbe</class>) hold no monitor state (Story 18.47, DW-2149): any process's
/// severity-2 log line raises <code>$SYSTEM.Monitor.State()</code> some seconds later, so a snapshot that carried it
/// would redden an unrelated class's after-check.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and an account holding <code>%All</code>. It is
/// read-only: each snapshot only reads, and nothing is created, changed or removed.</p>
Class OcuPilot.Test.ProbeSnapshots Extends %UnitTest.TestCase
{

/// <p>The probes, comma-separated, by class name.</p>
Parameter PROBES = "OcuPilot.Test.EcpProbe,OcuPilot.Test.EncryptionProbe,OcuPilot.Test.JournalProbe,OcuPilot.Test.LicenseProbe,OcuPilot.Test.RemoteDatabaseProbe";

/// <p>Each probe's snapshot reads something, and none of its lines is the monitor state.</p>
/// <p>Mutation (Rule 19): restore <code>Set tLines("monitor|" _ $SYSTEM.Monitor.State()) = ""</code> to one probe's
/// <code>Snapshot</code> -- that probe's leg goes red.</p>
Method TestNoSnapshotHoldsTheMonitorState()
{
    For tI = 1:1:$Length(..#PROBES, ",") {
        Set tProbe = $Piece(..#PROBES, ",", tI)
        Set tSnapshot = $ClassMethod(tProbe, "Snapshot")
        Do $$$AssertTrue($IsObject(tSnapshot) && (tSnapshot.%Size() > 0), tProbe _ ": the snapshot reads something")
        If '$IsObject(tSnapshot) Continue
        Set tMonitor = 0
        Set tIterator = tSnapshot.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            If $Extract(tLine, 1, 8) = "monitor|" Set tMonitor = tMonitor + 1
        }
        Do $$$AssertEquals(tMonitor, 0, tProbe _ ": and none of its lines is the monitor state")
    }
}

}
