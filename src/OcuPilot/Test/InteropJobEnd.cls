/// <p>Ends a probe job and reads back the id the Jobs list gives it as dead (Story 20.23): the premise of the dead-job legs of
/// <class>OcuPilot.Test.InteropJobActions</class>, <class>OcuPilot.Test.InteropJobStop</class> and
/// <class>OcuPilot.Test.InteropRuntimeBounds</class>. It waits for the production's own update after its start and for the Jobs list
/// to show the job alive, terminates its process, and waits for the list to show it dead, and it refuses the premise by name when the
/// production reads Troubled, its update never comes, or the list never shows the job alive or dead.</p>
/// <p>What it needs from the environment: the probe production (<class>OcuPilot.Test.ProductionProbe</class>) running in
/// <code>USER</code>, and the account of the calling process holding the Jobs read.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropJobEnd Extends %RegisteredObject
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

/// <p>The class whose <method>OcuPilot.Test.InteropHostRead.StoredStamp</method> reads one value from <code>USER</code>'s tables.</p>
Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter NAMESPACE = "USER";

/// <p>The production state number of a troubled production.</p>
Parameter TROUBLED = 4;

/// <p>The most quarter-second reads each wait makes: twenty seconds of waiting.</p>
Parameter READS = 80;

/// <p>The most jobs one call terminates: a live job of the host listed in place of a terminated one is terminated in its turn.</p>
Parameter ATTEMPTS = 3;

/// <p>Terminate the process of host <var>pHost</var>'s job and answer the id the Jobs read lists that job under once it reads
/// <code>Dead</code>, which is the id the port refuses as dead; <code>""</code> when it never did. Nothing is terminated before the
/// production's own update after its start has run (<method>StartUpdated</method>), because that update removes every dead row. When
/// the host lists a live job under another id and no <code>Dead</code> row, a replacement job started, and it is terminated in its
/// turn. <var>pWhy</var> is a sentence for the assertion that follows: the premise when it holds, and the step that failed when it
/// does not.</p>
/// <p><var>pAfterTerminate</var> names a class method as <code>Class:Method</code>, called with the first job's process id once its
/// terminate has returned: a seam for a test that makes a replacement happen.</p>
ClassMethod Terminated(pHost As %String, Output pWhy As %String, pAfterTerminate As %String = "") As %String
{
    Set tDead = ""
    Set tFailed = ""
    For tAttempt = 1:1:..#ATTEMPTS {
        If (tAttempt = 1) && '..StartUpdated(.tFailed) Quit
        Set tLive = ..LiveJob(pHost, .tFailed)
        If tLive = "" Quit
        Set tTerminated = $System.Process.Terminate(tLive)
        If tTerminated '= 1 && $Data(^$JOB(tLive)) {
            Set tFailed = "the terminate of job " _ tLive _ " answered " _ tTerminated _ " and the process is still alive"
            Quit
        }
        If tAttempt = 1 && (pAfterTerminate '= "") Do $ClassMethod($Piece(pAfterTerminate, ":", 1), $Piece(pAfterTerminate, ":", 2), tLive)
        Set tDead = ..DeadJob(pHost, tLive, .tReplaced, .tFailed)
        If (tDead '= "") || (tFailed '= "") Quit
        Set tFailed = $Select(tReplaced: "a live job of " _ pHost _ " replaced each terminated one and no Dead row was listed", 1: "no job of " _ pHost _ " read Dead in about 20 seconds after job " _ tLive _ " was terminated")
        If 'tReplaced Quit
    }
    Set pWhy = $Select(tDead '= "": "the job of " _ pHost _ " was terminated and reads Dead", 1: "the job of " _ pHost _ " was not made to read Dead: " _ tFailed)
    Quit tDead
}

/// <p>1 once the current production's own update after its newest start has run: the vendor's schedule handler logs
/// <code>is up-to-date.</code> or <code>updated.</code> for it in <code>USER</code>'s event log after the <code>started.</code> line,
/// and when it runs after a job has died it removes the dead row. Waits twenty seconds at most; 1 at once when no production is
/// current, none was logged as started, or it reads Troubled (<method>LiveJob</method> names that). 0, with <var>pWhy</var>, when the
/// update was not logged.</p>
ClassMethod StartUpdated(Output pWhy As %String) As %Boolean [ Private ]
{
    Set pWhy = ""
    Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
    If (tCurrent = "") || (tState = ..#TROUBLED) Quit 1
    Set tStarted = +$ClassMethod(..#READ, "StoredStamp", "SELECT MAX(ID) FROM Ens_Util.Log WHERE Text = ?", "Production '" _ tCurrent _ "' started.")
    If tStarted = 0 Quit 1
    Set tUpdated = 0
    For tTry = 1:1:..#READS {
        Set tUpdated = $ClassMethod(..#READ, "StoredStamp", "SELECT MAX(ID) FROM Ens_Util.Log WHERE ID > ? AND ConfigName = 'Ens.ScheduleHandler' AND (Text LIKE '% is up-to-date.' OR Text LIKE '% updated.')", tStarted) > 0
        If tUpdated Quit
        Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
        If tState = ..#TROUBLED Quit
        Hang 0.25
    }
    If tUpdated || (tState = ..#TROUBLED) Quit 1
    Set pWhy = "the production " _ tCurrent _ " was started at event-log row " _ tStarted _ " and its schedule handler logged no update after it in about 20 seconds"
    Quit 0
}

/// <p>The jobs of host <var>pHost</var> in the Jobs list the port answers, as <var>pRows</var>(n) = the list's row object, and how
/// many there are.</p>
ClassMethod HostRows(pHost As %String, Output pRows) As %Integer
{
    Kill pRows
    Set tCount = 0
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Jobs", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If '$IsObject($Get(tRows)) Quit 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Host = pHost {
            Set tCount = tCount + 1
            Set pRows(tCount) = tRow
        }
    }
    Quit tCount
}

/// <p>The process id of a job of host <var>pHost</var> that the Jobs list shows alive, waiting twenty seconds at most; <code>""</code>
/// when it shows none, with <var>pWhy</var> naming the production's state: a production that reads Troubled ends the wait at once.</p>
ClassMethod LiveJob(pHost As %String, Output pWhy As %String) As %String [ Private ]
{
    Set pWhy = ""
    Set tLive = ""
    For tTry = 1:1:..#READS {
        Set tCount = ..HostRows(pHost, .tRows)
        For tI = 1:1:tCount {
            If 'tRows(tI).Dead Set tLive = tRows(tI).Job
            If tLive '= "" Quit
        }
        If tLive '= "" Quit
        Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
        If tState = ..#TROUBLED {
            Set pWhy = "the production " _ tCurrent _ " reads Troubled and lists no live job of " _ pHost
            Quit
        }
        Hang 0.25
    }
    If tLive = "" && (pWhy = "") {
        Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
        Set pWhy = "no live job of " _ pHost _ " was listed in about 20 seconds; " _ $Select(tCurrent '= "": "the production " _ tCurrent _ " reads state " _ tState, 1: "no production is current")
    }
    Quit tLive
}

/// <p>The id the Jobs list gives host <var>pHost</var>'s job once the process <var>pOriginal</var> is gone and the job reads
/// <code>Dead</code>, waiting twenty seconds at most. The vendor's monitor renames a dead job's id to a ghost id on its next pass, so a
/// ghost id is answered when it comes and the original id only when no rename comes. <code>""</code> when no job reads Dead;
/// <var>pReplaced</var> is 1 when the list showed a live job of the host under another id and no <code>Dead</code> row, and
/// <var>pWhy</var> names a production that reads Troubled, which ends the wait at once.</p>
ClassMethod DeadJob(pHost As %String, pOriginal As %String, Output pReplaced As %Boolean, Output pWhy As %String) As %String [ Private ]
{
    Set pReplaced = 0
    Set pWhy = ""
    Set tGhost = ""
    Set tOwn = 0
    For tTry = 1:1:..#READS {
        Hang 0.25
        Set tCount = ..HostRows(pHost, .tRows)
        Set tGhost = ""
        Set tOwn = 0
        Set tLive = ""
        For tI = 1:1:tCount {
            Set tJob = tRows(tI).Job
            If 'tRows(tI).Dead {
                If tJob '= pOriginal Set tLive = tJob
            } ElseIf tJob = pOriginal {
                Set tOwn = 1
            } Else {
                Set tGhost = tJob
            }
        }
        If tGhost '= "" Quit
        If tLive '= "" && 'tOwn {
            Set pReplaced = 1
            Quit
        }
        Set tCurrent = $ClassMethod(..#PROBE, "Current", .tState)
        If tState = ..#TROUBLED {
            Set pWhy = "the production " _ tCurrent _ " reads Troubled after job " _ pOriginal _ " of " _ pHost _ " was terminated"
            Quit
        }
    }
    If tGhost '= "" Quit tGhost
    If tOwn && (pWhy = "") Quit pOriginal
    Quit ""
}

}
