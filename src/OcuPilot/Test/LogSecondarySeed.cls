/// <p>Seeds one entry, carrying a caller's marker, into each of the six secondary log stores
/// (Story 16.8) and removes exactly what it seeded. <class>OcuPilot.Test.LogSecondaryWire</class>
/// and <file>ui/browser/secondary-log-spec.mjs</file> both use it, so the recipes live once.</p>
/// <p><b>It writes the instance's own stores</b> -- a line in <file>SystemMonitor.log</file>, an
/// xDBC error, a background task, an SQL diagnostics result, two interoperability events and, when
/// HSCUSTOM has none, an analytics log file -- so every method refuses unless
/// <parameter>ARMINGVARIABLE</parameter> reads 1, which only <file>scripts/ci-throwaway.sh</file>
/// sets. What it must restore is kept in <code>^OcuPilotSecondarySeed</code> in HSCUSTOM between
/// the seed and the removal, which may run in different processes.</p>
Class OcuPilot.Test.LogSecondarySeed Extends %RegisteredObject
{

/// <p>The variable that arms this class: it writes the manager directory, as
/// <class>OcuPilot.Test.LogOlderFilesWire</class> does.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_LOG_ROTATION";

/// <p>The namespace the per-namespace entries are seeded in.</p>
Parameter NAMESPACE = "HSCUSTOM";

/// <p>The process id the xDBC error is filed under, one no process on a container reaches.</p>
Parameter XDBCPID = 999000001;

/// <p>The background task id the seeded task is filed under.</p>
Parameter TASKID = 999000002;

/// <p>The task name the seeded background task carries.</p>
Parameter TASKNAME = "OcuPilot seeded task";

/// <p>The analytics log's source column for the seeded line.</p>
Parameter ANALYTICSSOURCE = "OcuPilot";

/// <p>A refusal status unless this instance is armed.</p>
ClassMethod Armed() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) = 1 Quit $$$OK
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogSecondarySeed writes the instance's own log stores and runs on a throwaway container only; " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written")
}

/// <p>The text each seeded entry carries: <var>pMarker</var>, then which store it is in.</p>
ClassMethod Text(pMarker As %String, pStore As %String) As %String
{
    Quit pMarker _ " " _ pStore _ " entry"
}

/// <p>Seed one entry carrying <var>pMarker</var> into each store. A store that fails leaves what
/// was already seeded recorded, so <method>Remove</method> still undoes it.</p>
ClassMethod Seed(pMarker As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill ^OcuPilotSecondarySeed
        Set ^OcuPilotSecondarySeed("marker") = pMarker

        Set tMonitorText = ..Text(pMarker, "systemmonitor")
        Set $NAMESPACE = "%SYS"
        Set tMonitor = ##class(%SYS.Monitor.SampleSubscriber).%New()
        Set tSC = tMonitor.LogMsg(tMonitorText)
        Set tMonitor = ""
        Set $NAMESPACE = ..#NAMESPACE
        If $$$ISERR(tSC) Quit
        Set ^OcuPilotSecondarySeed("monitor") = 1

        Set tNow = $ZDateTime($Horolog, 3)
        Set tError = tNow _ " [SQLCODE: <-400>:<Fatal error occurred>]" _ $Char(13, 10) _ "[Location: <Prepare>]" _ $Char(13, 10) _ "[%msg: <" _ ..Text(pMarker, "xdbc") _ ">]"
        Set ^|$$GetCacheDatabase^%SYS.SQLSRV()|%sqlcq(..#NAMESPACE, "LastError", ..#XDBCPID) = tError
        Set ^OcuPilotSecondarySeed("xdbc") = 1

        Set tTask = $Name(^|"%SYS"|IRIS.Temp.MgtPortalTask(..#TASKID))
        Set @tTask@("Task") = ..#TASKNAME
        Set @tTask@("Status") = "ERROR"
        Set @tTask@("StartTime") = tNow
        Set @tTask@("NS") = ..#NAMESPACE
        Set @tTask@("Details") = ..Text(pMarker, "taskerrors")
        Set @tTask@("ErrorLog") = 1
        Set @tTask@("ErrorLog", 1) = $ListBuild("ERROR", -400, ..Text(pMarker, "taskerrors"), 1)
        Set ^OcuPilotSecondarySeed("task") = 1

        Set ^OcuPilotSecondarySeed("diagEmpty") = '$Data(^IRIS.sql.diag.result.1)
        Set tDiag = ##class(%SQL.Diag.Result).addDiagResult(0)
        Set ^OcuPilotSecondarySeed("diag") = tDiag
        Set tStatement = "LOAD DATA FROM FILE '/nonexistent/ocupilot-seed.csv' INTO OcuPilotSeed.Probe"
        Do ##class(%SQL.Diag.Result).updateStatement(tDiag, .tStatement)
        Do ##class(%SQL.Diag.Result).addDiagMessage(tDiag, "OcuPilot", -400, ..Text(pMarker, "sqldiagnostics"), 3)
        Do ##class(%SQL.Diag.Result).updateResult(tDiag, 0, -400)

        Set ^OcuPilotSecondarySeed("eventEmpty") = '$Data(^Ens.Util.LogD)
        For tType = 2, 3 {
            Merge ^OcuPilotSecondarySeed("eventMonitor", tType) = ^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType)
            Set ^OcuPilotSecondarySeed("eventMonitorHeld", tType) = ''$Data(^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType))
        }
        ; Two events, a warning then the error, so the event log viewer holds more than one row.
        Do ##class(Ens.Util.Log).LogWarning("OcuPilot.Test.LogSecondarySeed", "Seed", pMarker _ " eventlog warning")
        Set ^OcuPilotSecondarySeed("event", 1) = $Order(^Ens.Util.LogD(""), -1)
        Do ##class(Ens.Util.Log).LogError("OcuPilot.Test.LogSecondarySeed", "Seed", ..Text(pMarker, "eventlog"))
        Set ^OcuPilotSecondarySeed("event", 2) = $Order(^Ens.Util.LogD(""), -1)
        Set ^OcuPilotSecondarySeed("event") = 1

        If '##class(%File).Exists(##class(%DeepSee.Utils).%GetLogFileName()) {
            Set tSC = ##class(%DeepSee.Utils).%WriteToLog(..#ANALYTICSSOURCE, ..Text(pMarker, "analytics"))
            If $$$ISERR(tSC) Quit
            Set ^OcuPilotSecondarySeed("analytics") = 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove what <method>Seed</method> recorded, restore what it displaced, and return an error
/// naming any store <method>Left</method> still finds the marker in.</p>
ClassMethod Remove() As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tMarker = $Get(^OcuPilotSecondarySeed("marker"))
        If tMarker = "" Quit

        If $Get(^OcuPilotSecondarySeed("monitor")) {
            Set tSC = ..DropLines(##class(%File).NormalizeFilename("SystemMonitor.log", $System.Util.ManagerDirectory()), tMarker)
            If $$$ISERR(tSC) Quit
        }
        If $Get(^OcuPilotSecondarySeed("xdbc")) Do KillLastErrorOne^%SYS.SQLSRV(..#XDBCPID)
        If $Get(^OcuPilotSecondarySeed("task")) Kill ^|"%SYS"|IRIS.Temp.MgtPortalTask(..#TASKID)

        Set tDiag = $Get(^OcuPilotSecondarySeed("diag"))
        If tDiag '= "" {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %SQL_Diag.Message WHERE diagResult = ?", tDiag)
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %SQL_Diag.Result WHERE ID = ?", tDiag)
            If $Get(^OcuPilotSecondarySeed("diagEmpty")) {
                Kill ^IRIS.sql.diag.result.1, ^IRIS.sql.diag.message.1, ^IRIS.sql.diag.message.2, ^IRIS.sql.diag.message.3
            }
        }

        If $Get(^OcuPilotSecondarySeed("event")) {
            For tAt = 1, 2 {
                Set tEvent = $Get(^OcuPilotSecondarySeed("event", tAt))
                If tEvent '= "" Do ##class(Ens.Util.Log).%DeleteId(tEvent)
            }
            If $Get(^OcuPilotSecondarySeed("eventEmpty")) Kill ^Ens.Util.LogD, ^Ens.Util.LogI
            For tType = 2, 3 {
                Kill ^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType)
                If $Get(^OcuPilotSecondarySeed("eventMonitorHeld", tType)) Merge ^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType) = ^OcuPilotSecondarySeed("eventMonitor", tType)
            }
        }

        If $Get(^OcuPilotSecondarySeed("analytics")) {
            Set tSC = ##class(%DeepSee.Utils).%KillLogFile()
            If $$$ISERR(tSC) Quit
        }
        Kill ^OcuPilotSecondarySeed
        Set $NAMESPACE = tOrigNS
        Set tLeft = ..Left(tMarker)
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "the seeded marker is still in: " _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The stores that still hold <var>pMarker</var>, comma-separated, read back directly.</p>
ClassMethod Left(pMarker As %String) As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ..FileHolds(##class(%File).NormalizeFilename("SystemMonitor.log", $System.Util.ManagerDirectory()), pMarker) Set tLeft = tLeft _ ",systemmonitor"
        If $Get(^|$$GetCacheDatabase^%SYS.SQLSRV()|%sqlcq(..#NAMESPACE, "LastError", ..#XDBCPID)) [ pMarker Set tLeft = tLeft _ ",xdbc"
        If $Data(^|"%SYS"|IRIS.Temp.MgtPortalTask(..#TASKID)) Set tLeft = tLeft _ ",taskerrors"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SQL_Diag.Message WHERE message %STARTSWITH ?", pMarker)
        If tResult.%Next() && (+tResult.%GetData(1) > 0) Set tLeft = tLeft _ ",sqldiagnostics"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens_Util.Log WHERE Text %STARTSWITH ?", pMarker)
        If tResult.%Next() && (+tResult.%GetData(1) > 0) Set tLeft = tLeft _ ",eventlog"
        If ..FileHolds(##class(%DeepSee.Utils).%GetLogFileName(), pMarker) Set tLeft = tLeft _ ",analytics"
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = tLeft _ ",unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit $Extract(tLeft, 2, *)
}

/// <p>Whether file <var>pPath</var> exists and holds <var>pMarker</var>.</p>
ClassMethod FileHolds(pPath As %String, pMarker As %String) As %Boolean
{
    If '##class(%File).Exists(pPath) Quit 0
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISERR(tStream.LinkToFile(pPath)) Quit 0
    Set tHolds = 0
    While 'tStream.AtEnd {
        If tStream.ReadLine() [ pMarker {
            Set tHolds = 1
            Quit
        }
    }
    Quit tHolds
}

/// <p>Rewrite file <var>pPath</var> without the lines that carry <var>pMarker</var>, so only the
/// seeded line goes and anything the System Monitor appended since stays.</p>
ClassMethod DropLines(pPath As %String, pMarker As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tIn = ##class(%Stream.FileCharacter).%New()
        Set tSC = tIn.LinkToFile(pPath)
        If $$$ISERR(tSC) Quit
        Set tKept = ""
        Set tDropped = 0
        While 'tIn.AtEnd {
            Set tLine = tIn.ReadLine(, .tSC, .tEol)
            If $$$ISERR(tSC) Quit
            If tLine [ pMarker {
                Set tDropped = 1
                Continue
            }
            Set tKept = tKept _ tLine _ $Select(tEol: $Char(10), 1: "")
        }
        If $$$ISERR(tSC) Quit
        Set tIn = ""
        If 'tDropped Quit
        Set tOut = ##class(%Stream.FileCharacter).%New()
        Set tSC = tOut.LinkToFile(pPath)
        If $$$ISERR(tSC) Quit
        Do tOut.Clear()
        Set tSC = tOut.Write(tKept)
        If $$$ISERR(tSC) Quit
        Set tSC = tOut.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
