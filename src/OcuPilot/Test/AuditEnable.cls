/// <p><b>DW-45</b> (rework iteration 6 review): the enable branch of
/// <method>OcuPilot.Install.Installer.EnsureAuditingEnabled</method> -- AC2's "instance
/// auditing enabled" on an instance that starts with auditing off -- driven in-process
/// through <class>OcuPilot.Test.AuditOff</class>, which reports the setting and records the
/// write without making it. Nothing here installs, uninstalls or changes the instance's
/// auditing. What proves no real write happened is the call count: the live setting each
/// test reads last would say 1 either way, since this image starts with auditing on and
/// the real write would also set 1 (corrected in code review round 3).</p>
Class OcuPilot.Test.AuditEnable Extends %UnitTest.TestCase
{

Method %OnNew(initvalue As %String = "") As %Status
{
    Quit ##super(initvalue)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.AuditOff).Disarm()
    Quit $$$OK
}

/// <p>Auditing reads off: the step must ask for it to be turned on exactly once and
/// report that it did, at <code>warn</code> (an instance-wide posture change).</p>
/// <p>Mutation (Rule 19): make the step's enable branch skip the write
/// (<code>Set tSC = $$$OK</code> in place of the <method>EnableInstanceAuditing</method>
/// call), and the call-count assertion goes red.</p>
Method TestEnableBranchTurnsAuditingOn()
{
    Do ##class(OcuPilot.Test.AuditOff).Arm(##class(OcuPilot.Test.AuditOff).#OFFMODE)
    Kill tReports
    Set tSC = ##class(OcuPilot.Test.AuditOff).DriveEnsureAuditing(.tReports)
    Set tCalls = ##class(OcuPilot.Test.AuditOff).EnableCalls()
    Do ##class(OcuPilot.Test.AuditOff).Disarm()

    Do $$$AssertStatusOK(tSC, "the auditing step succeeds when auditing starts off")
    Do $$$AssertEquals(tCalls, 1, "the auditing step asked for auditing to be turned on, once")
    Do $$$AssertTrue(..Reported(.tReports, "warn", "Enabled instance auditing"), "and reported the change at warn")
    Do $$$AssertTrue('..Reported(.tReports, "info", "already enabled"), "and did not also report it as already enabled")
    Do $$$AssertEquals(..LiveAuditEnabled(), 1, "the shared instance's auditing is still on (this reads 1 whether or not a real write happened -- the call count above is what proves none did)")
}

/// <p>Auditing reads on: nothing is written, and the outcome is reported as its own
/// <code>info</code> line (AC10's two distinct outcomes).</p>
Method TestAlreadyEnabledWritesNothing()
{
    Do ##class(OcuPilot.Test.AuditOff).Arm(##class(OcuPilot.Test.AuditOff).#ONMODE)
    Kill tReports
    Set tSC = ##class(OcuPilot.Test.AuditOff).DriveEnsureAuditing(.tReports)
    Set tCalls = ##class(OcuPilot.Test.AuditOff).EnableCalls()
    Do ##class(OcuPilot.Test.AuditOff).Disarm()

    Do $$$AssertStatusOK(tSC, "the auditing step succeeds when auditing is already on")
    Do $$$AssertEquals(tCalls, 0, "no write when auditing is already on")
    Do $$$AssertTrue(..Reported(.tReports, "info", "Instance auditing already enabled"), "reported as already enabled, at info")
    Do $$$AssertEquals(..LiveAuditEnabled(), 1, "the shared instance's auditing is still on (this reads 1 whether or not a real write happened -- the call count above is what proves none did)")
}

/// <p>The read fails: the step returns the error and writes nothing -- a failed read is
/// never a silent "it is off" that would then write the setting.</p>
Method TestFailedReadNeverWritesTheSetting()
{
    Do ##class(OcuPilot.Test.AuditOff).Arm(##class(OcuPilot.Test.AuditOff).#READFAILSMODE)
    Kill tReports
    Set tSC = ##class(OcuPilot.Test.AuditOff).DriveEnsureAuditing(.tReports)
    Set tCalls = ##class(OcuPilot.Test.AuditOff).EnableCalls()
    Do ##class(OcuPilot.Test.AuditOff).Disarm()

    Do $$$AssertStatusNotOK(tSC, "a failed read fails the step")
    Do $$$AssertEquals(tCalls, 0, "a failed read never leads to a write")
    Do $$$AssertEquals(..LiveAuditEnabled(), 1, "the shared instance's auditing is still on (this reads 1 whether or not a real write happened -- the call count above is what proves none did)")
}

/// <p>Whether <var>pReports</var> carries a report at <var>pLevel</var> whose message
/// contains <var>pText</var>.</p>
Method Reported(ByRef pReports, pLevel As %String, pText As %String) As %Boolean
{
    Set tFound = 0
    Set tN = $Order(pReports(""))
    While tN '= "" {
        If ($Get(pReports(tN, "level")) = pLevel) && ($Get(pReports(tN, "message")) [ pText) Set tFound = 1
        Set tN = $Order(pReports(tN))
    }
    Quit tFound
}

/// <p>The instance's real <code>AuditEnabled</code> setting, read in <code>%SYS</code>;
/// <code>-1</code> when it cannot be read.</p>
Method LiveAuditEnabled() As %Integer
{
    Set tValue = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If $$$ISOK(##class(Security.System).Get("SYSTEM", .tProps)) Set tValue = +$Get(tProps("AuditEnabled"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tValue = -1
    }
    Quit tValue
}

}
