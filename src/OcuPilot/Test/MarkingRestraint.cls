/// <p>Pins the restraint read's marking rule: while the stored fact reads not-marked, the read
/// observes auditing and OcuPilot's marker event with the reader's own privileges and records
/// marked when both read on, so an auditing re-enable made outside OcuPilot clears the banner. A
/// flag that reads off, or a read that fails, leaves the stored fact as it is and writes nothing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It answers the two reads from
/// <class>OcuPilot.Test.MarkingPort</class> and never changes the instance's auditing; it writes
/// and removes the one switch row.</p>
Class OcuPilot.Test.MarkingRestraint Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.MarkingPort).Clear()
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.MarkingPort).Clear()
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do $$$AssertEquals(##class(OcuPilot.Test.SwitchFixture).SwitchRowCount(), 0, "no switch row survives this test")
    Quit tSC
}

/// <p>Record the stored fact <var>pMarked</var>.</p>
ClassMethod StoreFact(pMarked As %Boolean)
{
    Kill tValues
    Set tValues("writesMarked") = ''pMarked
    Do ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues)
}

/// <p>The restraint body's <code>writesMarked</code>, or <code>-1</code> when the body could not be built.</p>
ClassMethod BodyMarked() As %Integer
{
    Set tSC = ##class(OcuPilot.Test.MarkingRestraintFixture).Body($Username, .tBody)
    If $$$ISERR(tSC) || '$IsObject(tBody) Quit -1
    Quit +tBody.%Get("writesMarked")
}

/// <p>Not marked on record, auditing and the marker event both on: the read answers marked and
/// records it.</p>
/// <p>Mutation (Rule 19): remove the observe branch from
/// <method>OcuPilot.Api.Switches.RestraintBody</method> -> this goes red.</p>
Method TestAReEnableMadeOutsideOcuPilotClearsTheFact()
{
    Do ..StoreFact(0)
    Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "1")
    Do $$$AssertEquals(..BodyMarked(), 1, "the body answers writesMarked 1")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 1, "and the fact is recorded marked")
}

/// <p>Auditing off stays not marked.</p>
Method TestAuditingStillOffStaysNotMarked()
{
    Do ..StoreFact(0)
    Do ##class(OcuPilot.Test.MarkingPort).Arm("0", "1")
    Do $$$AssertEquals(..BodyMarked(), 0, "the body answers writesMarked 0")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 0, "and the recorded fact stays 0")
}

/// <p>A read that fails leaves the stored fact and writes nothing.</p>
Method TestAFailedReadLeavesTheFactAlone()
{
    Do ..StoreFact(0)
    Do ##class(OcuPilot.Test.MarkingPort).Arm("fault", "1")
    Do $$$AssertEquals(..BodyMarked(), 0, "the body answers the stored 0")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 0, "and the recorded fact stays 0")
}

/// <p>A fact recorded marked is answered without any observation.</p>
Method TestAMarkedFactIsAnsweredWithoutObserving()
{
    Do ..StoreFact(1)
    Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "1")
    Do $$$AssertEquals(..BodyMarked(), 1, "the body answers the stored 1")
    Do $$$AssertEquals(##class(OcuPilot.Test.MarkingPort).AskedEvent(), "", "and the marker event was never read")
}

}
