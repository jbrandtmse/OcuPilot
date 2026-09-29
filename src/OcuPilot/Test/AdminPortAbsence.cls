/// <p>Pins AD-2's rule on a 404 (DW-1814): a read the admin API answers 404 has found an absence,
/// so <class>OcuPilot.Port.AdminPort</class> logs nothing for it and the caller still gets its
/// <code>PORT.NOTFOUND</code> fault; a write answered 404 is still logged at error; and on the
/// instance, a verified delete, whose re-read is answered 404, posts no alert.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, a caller holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the
/// last test creates and deletes a role through the real port and reads the instance's alert counter
/// and <code>alerts.log</code>. The first two read and delete a role no instance holds through
/// <class>OcuPilot.Test.PortFixture</class>, whose log lines are captured rather than written.</p>
Class OcuPilot.Test.AdminPortAbsence Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>A role name no instance holds, and the role the live test creates and deletes.</p>
Parameter PROBEROLE = "OcuPilotAbsenceProbeRole";

/// <p>Seconds to wait for the instance's log monitor, which copies a severe
/// <code>messages.log</code> line to <code>alerts.log</code> on its own cycle (about ten seconds,
/// measured on <code>ocupilot-b-ci</code>).</p>
Parameter LOGMONITORWAIT = 15;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AdminPortAbsence creates and deletes a role and reads the instance's alert state, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..RemoveProbeRole()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbeRole()
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

/// <p>A read of a role no instance holds is 404 <code>PORT.NOTFOUND</code>, and the port logs
/// nothing for it.</p>
/// <p>Mutation: pass <code>0</code> for <var>pRead</var> at <method>OcuPilot.Port.AdminPort.Invoke</method>'s
/// <method>Fail</method> call -> the capture holds the vendor's "does not exist" line and this goes red.</p>
Method TestAReadAnsweredAbsentIsNotLogged()
{
    Set tQuery("name") = ..#PROBEROLE
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Security.Role", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a read of an absent role fails")
    Do $$$AssertEquals(tHttp, 404, "at 404")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "PORT.NOTFOUND", "with the not-found code")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and no line is logged for the absence")
}

/// <p>A write answered 404 is still a logged failure, at error severity, carrying the vendor's
/// text.</p>
/// <p>Mutation: drop the <var>pRead</var> condition from <method>OcuPilot.Port.AdminPort.Fail</method>'s
/// log guard so that every 404 goes unlogged -> the capture is empty and this goes red.</p>
Method TestAWriteAnswered404IsStillLogged()
{
    Set tQuery("name") = ..#PROBEROLE
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Security.Role", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a delete of an absent role fails")
    Do $$$AssertEquals(tHttp, 404, "at 404")
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ "Security.Role failed with HTTP 404", "the failure is logged: " _ tLine)
    Do $$$AssertTrue(tLine [ ..#PROBEROLE, "with the vendor's text naming the role")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), 2, "at error severity")
}

/// <p>A role deleted through the real port is re-read (<parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter>),
/// the re-read is answered 404, and the instance's alert counter does not move, no line
/// <code>alerts.log</code> gains once the log monitor has run is an <code>adminport</code> entry, and a
/// state below Alert stays below it. <code>alerts.log</code> is read by content, because the log
/// monitor also copies severe lines posted before the delete, a fresh instance's among them.</p>
/// <p>Mutation: pass <code>0</code> for <var>pRead</var> at <method>OcuPilot.Port.AdminPort.Invoke</method>'s
/// <method>Fail</method> call -> the re-read's line is posted as an alert and the counter and
/// <code>alerts.log</code> assertions go red.</p>
Method TestAVerifiedDeletePostsNoAlert()
{
    Set tSC = ..CreateProbeRole()
    Do $$$AssertStatusOK(tSC, "the probe role is created")
    If $$$ISERR(tSC) Quit
    Set tAlerts = $SYSTEM.Monitor.Alerts()
    Set tState = $SYSTEM.Monitor.State()
    Set tLines = ..AlertsLogLines()
    Do $$$AssertTrue(tLines >= 0, "alerts.log can be read")
    Set tQuery("name") = ..#PROBEROLE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Role", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is made and its re-read finds the role gone: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertTrue('..ProbeRoleExists(), "the role is gone")
    Do $$$AssertEquals($SYSTEM.Monitor.Alerts(), tAlerts, "the delete and its re-read post no alert")
    Hang ..#LOGMONITORWAIT
    Do $$$AssertEquals(..PortAlertsAfter(tLines), 0, "no line alerts.log gains once the log monitor has run is the port's")
    If tState < 2 Do $$$AssertTrue($SYSTEM.Monitor.State() < 2, "and the instance's state, " _ tState _ " before, has not reached Alert")
}

/// <p>The number of lines in the instance's <code>alerts.log</code>, 0 when there is none.</p>
ClassMethod AlertsLogLines() As %Integer
{
    Set tLines = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFile = ##class(%File).ManagerDirectory() _ "alerts.log"
        Set $NAMESPACE = tOrigNS
        If '##class(%File).Exists(tFile) Quit
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(tFile)
        If $$$ISERR(tSC) Quit
        While 'tStream.AtEnd {
            Do tStream.ReadLine()
            Set tLines = tLines + 1
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tLines = -1
    }
    Quit tLines
}

/// <p>How many of the <code>alerts.log</code> lines after the first <var>pSkip</var> are
/// <class>OcuPilot.Port.AdminPort</class> log entries, -1 when the file cannot be read.</p>
ClassMethod PortAlertsAfter(pSkip As %Integer) As %Integer
{
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFile = ##class(%File).ManagerDirectory() _ "alerts.log"
        Set $NAMESPACE = tOrigNS
        If '##class(%File).Exists(tFile) Quit
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(tFile)
        If $$$ISERR(tSC) {
            Set tFound = -1
            Quit
        }
        Set tLine = 0
        While 'tStream.AtEnd {
            Set tText = tStream.ReadLine()
            Set tLine = tLine + 1
            If (tLine > pSkip) && (tText [ """subsystem"":""adminport""") Set tFound = tFound + 1
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tFound = -1
    }
    Quit tFound
}

ClassMethod CreateProbeRole() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Roles).Exists(..#PROBEROLE) Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, "OcuPilot test probe (AdminPortAbsence)")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

ClassMethod ProbeRoleExists() As %Boolean
{
    Set tExists = 1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(Security.Roles).Exists(..#PROBEROLE)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tExists
}

/// <p>Remove the probe role; a failing status when it survives.</p>
ClassMethod RemoveProbeRole() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(..#PROBEROLE) Do ##class(Security.Roles).Delete(..#PROBEROLE)
        If ##class(Security.Roles).Exists(..#PROBEROLE) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AdminPortAbsence left its probe role on the instance")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
