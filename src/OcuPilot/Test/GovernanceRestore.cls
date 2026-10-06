/// <p>Pins <method>OcuPilot.Test.GovernanceFixture.Restore</method> over a stored policy, the branch
/// every class that snapshots, clears and restores the policy around its tests relies on to put an
/// operator's override back: a stored preset and a disabled key, snapshot and cleared, read back
/// name for name and value for value once restored, and the key is decided disabled again. It pins
/// <method>SetAside</method> and <method>PutBack</method>, the pair the class runner puts around
/// every class, the same way: the store reads default while a policy is set aside, reads back equal
/// once put back, and a copy an earlier run left held is put back before a new set-aside.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It writes only the stored
/// governance policy, which it snapshots before each test and puts back after it, asserting the
/// restore. Run through the class runner, the policy found is the one the runner set aside, which the
/// class takes over from it and leaves stored again.</p>
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
    If $Data(^OcuPilotTestGovernanceAside) {
        Kill tRows
        Merge tRows = ^OcuPilotTestGovernanceAside("rows")
        Kill ^OcuPilotTestGovernanceAside
    }
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

/// <p>A stored read-only preset and a disabled key are set aside: the store reads default, the key
/// is enabled by the baseline, and once put back the store reads back equal and nothing stays
/// held.</p>
Method TestSetAsideReadsDefaultAndPutBackReadsBackEqual()
{
    Kill tSettings
    Set tSettings(..#KEY) = "disabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("read-only", .tSettings)
    Do $$$AssertStatusOK(tSC, "a read-only preset and a disabled key are stored")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    Do $$$AssertStatusOK(tSC, "the store is snapshot")
    Do $$$AssertEquals(##class(OcuPilot.Test.GovernanceFixture).SetAside(), "ok", "the policy is set aside")
    Do $$$AssertEquals(..Decided(), 1, "and the baseline alone decides the key")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tAside)
    Do $$$AssertStatusOK(tSC, "the store is read while the policy is set aside")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tAside), "and holds nothing the baseline would not")
    Do $$$AssertEquals(##class(OcuPilot.Test.GovernanceFixture).PutBack(), "ok", "the policy is put back")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tRows), "and the store reads back equal")
    Do $$$AssertEquals(..Decided(), 0, "the key is decided disabled again")
    Do $$$AssertEquals($Data(^OcuPilotTestGovernanceAside), 0, "and nothing stays held")
    Do $$$AssertEquals(##class(OcuPilot.Test.GovernanceFixture).PutBack(), "ok", "putting back with nothing held is not an error")
}

/// <p>A copy an earlier run left held is put back before a new set-aside, so the policy that was
/// stored first is the one that returns, not whatever the failed run left in the store.</p>
Method TestAHeldLeftCopyIsPutBackBeforeANewSetAside()
{
    Kill tSettings
    Set tSettings(..#KEY) = "disabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("read-only", .tSettings)
    Do $$$AssertStatusOK(tSC, "a read-only preset and a disabled key are stored")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tFirst)
    Do $$$AssertStatusOK(tSC, "the first policy is snapshot")
    Do $$$AssertEquals(##class(OcuPilot.Test.GovernanceFixture).SetAside(), "ok", "the first policy is set aside and never put back")
    Kill tOther
    Set tOther(..#KEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tOther)
    Do $$$AssertStatusOK(tSC, "a different policy is stored over it, as a failed run would leave one")
    Do $$$AssertEquals(##class(OcuPilot.Test.GovernanceFixture).SetAside(), "ok", "a new set-aside succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.GovernanceFixture).PutBack(), "ok", "and its put-back succeeds")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tFirst), "the store reads as the first policy, the one held, not the one stored over it")
    Do $$$AssertEquals(..Decided(), 0, "so the key is decided disabled")
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
