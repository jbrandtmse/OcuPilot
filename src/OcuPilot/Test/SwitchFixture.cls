/// <p>Shared instance-state helper for the switches suite: put the instance into a named switch
/// state, hold a user, count what is left, and remove everything this suite wrote.</p>
/// <p><b>The switch row and the holds are rows in the <code>OCUPILOT</code> protected database and
/// nothing else removes them</b> -- no install step, no uninstall, no purge task. So each test class
/// owns its own cleanup and the residue check is an assertion rather than a hope. Every hold this
/// suite creates names a user starting with <parameter>PROBEPREFIX</parameter>, so teardown finds
/// them all without remembering ids.</p>
/// <p><b>It creates no IRIS principal.</b> A hold's user is a weak reference (AD-37), so a name the
/// instance does not hold is a legitimate row -- which is what lets the "no longer present"
/// rendering be tested without touching the instance's own security.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SwitchFixture Extends %RegisteredObject
{

/// <p>The prefix every probe hold's user name starts with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeHold";

/// <p>A probe user name the instance certainly does not hold, for the weak-reference case.</p>
Parameter GHOSTUSER = "OcuPilotProbeHoldGhost";

/// <p>Put the instance's one switch row into the state the caller names.</p>
ClassMethod SetSwitches(pKillSwitch As %Boolean, pReason As %String, pEnforcedReadOnly As %Boolean) As %Status
{
    Set tValues("killSwitch") = ''pKillSwitch
    Set tValues("killSwitchReason") = pReason
    Set tValues("enforcedReadOnly") = ''pEnforcedReadOnly
    Quit ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues)
}

/// <p>Hold <var>pUserName</var> with <var>pReason</var>, through the production create path.</p>
ClassMethod Hold(pUserName As %String, pReason As %String, Output pId As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Hold).GuardedCreate(pUserName, pReason, .pId)
}

/// <p>How many switch rows the instance holds, or <code>-1</code> when the count could not be
/// read. Read by SQL rather than through the guarded read, deliberately: the suite runs as an
/// account holding <code>%All</code>, so this reads the stored rows without going through the code
/// it is checking up on.</p>
ClassMethod SwitchRowCount() As %Integer
{
    Quit ..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SwitchState")
}

/// <p>How many probe holds the instance still holds, or <code>-1</code> when the count could not be
/// read.</p>
ClassMethod ProbeHoldCount() As %Integer
{
    Set tResult = -1
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Hold WHERE UserName %STARTSWITH ?", ..#PROBEPREFIX)
        If tRS.%SQLCODE < 0 Quit
        If 'tRS.%Next() Quit
        Set tResult = tRS.%GetData(1)
    } Catch ex {
        Set tResult = -1
    }
    Quit tResult
}

/// <p>How many holds of any kind the instance carries.</p>
ClassMethod HoldCount() As %Integer
{
    Quit ..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Hold")
}

/// <p>Remove every switch row and every hold this suite could have written, and report how many
/// holds survive in <var>pRemaining</var>. <code>-1</code> is a failure, never a clean
/// instance.</p>
/// <p>It removes <b>every</b> hold rather than only the probe-prefixed ones, because a test that
/// holds the suite's own account names it by its real name; the instance carries none of its own
/// (nothing else writes one), and leaving one behind would switch the agent off for a real user.</p>
ClassMethod Reset(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = -1
    Set tSC = ##class(OcuPilot.Kernel.State.Hold).DeleteAllGuarded()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Switch).DeleteGuarded()
    If $$$ISERR(tSC) Quit tSC
    Set pRemaining = ..HoldCount()
    Quit $$$OK
}

/// <p>The first column of <var>pSql</var>'s first row as a number, or <code>-1</code>.</p>
ClassMethod Count(pSql As %String) As %Integer [ Private ]
{
    Set tResult = -1
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql)
        If tRS.%SQLCODE < 0 Quit
        If 'tRS.%Next() Quit
        Set tResult = tRS.%GetData(1)
    } Catch ex {
        Set tResult = -1
    }
    Quit tResult
}

}
