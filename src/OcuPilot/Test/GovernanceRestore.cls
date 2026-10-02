/// <p>Pins <method>OcuPilot.Test.GovernanceFixture.Restore</method> over a stored policy, the branch
/// every class that snapshots, clears and restores the policy around its tests relies on to put an
/// operator's override back: a stored preset and a disabled key, snapshot and cleared, read back
/// name for name and value for value once restored, and the key is decided disabled again.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It writes only the stored
/// governance policy, which it snapshots before each test and puts back after it, asserting the
/// restore.</p>
Class OcuPilot.Test.GovernanceRestore Extends %UnitTest.TestCase
{

/// <p>A write key the baseline enables.</p>
Parameter KEY = "osmgmt.devices.delete";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Kill tRows
    Merge tRows = ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Do $$$AssertStatusOK(tSC, "the policy found before the test is put back")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tRows), "and reads back as it was")
    Quit $$$OK
}

/// <p>A stored read-only preset and a disabled key, snapshot and cleared, come back from the
/// snapshot as they were stored, and the key is decided disabled again.</p>
Method TestRestorePutsAStoredOverrideBack()
{
    Kill tSettings
    Set tSettings(..#KEY) = "disabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("read-only", .tSettings)
    Do $$$AssertStatusOK(tSC, "a read-only preset and a disabled key are stored")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    Do $$$AssertStatusOK(tSC, "the store is snapshot")
    Do $$$AssertEquals($Get(tRows(..#KEY)), "disabled", "holding the disabled key")
    Do $$$AssertEquals(..Decided(), 0, "which the policy decides disabled")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    Do $$$AssertStatusOK(tSC, "the store is cleared")
    Do $$$AssertEquals(..Decided(), 1, "and the baseline enables the key again")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Do $$$AssertStatusOK(tSC, "the snapshot is restored")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tRows), "and the store reads it back name for name and value for value")
    Do $$$AssertEquals(..Decided(), 0, "and the key is decided disabled again")
}

/// <p>Whether the policy decides <parameter>KEY</parameter> enabled for a write: 1 or 0, or -1
/// when it cannot decide.</p>
ClassMethod Decided() As %Integer [ Private ]
{
    Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(..#KEY, "write", .tEnabled, .tSource)
    If $$$ISERR(tSC) Quit -1
    Quit ''tEnabled
}

}
