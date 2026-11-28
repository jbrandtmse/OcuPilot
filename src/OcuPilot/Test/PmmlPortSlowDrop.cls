/// <p>Test-only fixture for <class>OcuPilot.Test.AnalyticsPmmlRunCancel</class>: <class>OcuPilot.Port.AnalyticsPort</class> whose <method>PmmlDrop</method>, when <code>^IRIS.Temp.OcuPilotPmmlLate("slowDrop")</code>
/// is set, reads the stored state of run <code>^IRIS.Temp.OcuPilotPmmlLate("key")</code> and the rows of the test id before and after a 0.6-second pause, and records both as
/// <code>^IRIS.Temp.OcuPilotPmmlLate("seen")</code>, <code>state/rows|state/rows</code>, so that a test can tell what a poll would read while the rows are being dropped. It then drops them as the port does.</p>
Class OcuPilot.Test.PmmlPortSlowDrop Extends OcuPilot.Port.AnalyticsPort
{

ClassMethod PmmlDrop(pTestId As %Integer)
{
    If $Data(^IRIS.Temp.OcuPilotPmmlLate("slowDrop")) {
        Set tBefore = ..Sample(pTestId)
        Hang 0.6
        Set ^IRIS.Temp.OcuPilotPmmlLate("seen") = tBefore _ "|" _ ..Sample(pTestId)
    }
    Do ##super(pTestId)
}

/// <p>The stored state of the run the test named and the rows of test id <var>pTestId</var>, as <code>state/rows</code>.</p>
ClassMethod Sample(pTestId As %Integer) As %String
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE RunKey = ?", $Get(^IRIS.Temp.OcuPilotPmmlLate("key")))
    Set tState = $Select(tResult.%Next(): tResult.%GetData(1), 1: "absent")
    Quit tState _ "/" _ $ClassMethod("OcuPilot.Test.PmmlProbe", "RowsOf", pTestId)
}

}
