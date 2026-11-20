/// <p><class>OcuPilot.Port.MonitorPort</class> reading the monitor's transaction rows from nodes of
/// <code>^IRIS.Temp.SysMetrics</code> named for a test rather than the System Monitor's own, so
/// <class>OcuPilot.Test.TransactionsRead</class> runs the port's real <method>TransactionNodes</method> over
/// rows it writes. Nothing else is overridden.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.TransactionsNodeProbe Extends OcuPilot.Port.MonitorPort
{

Parameter TRANSACTIONSNODE = "OcuPilotProbeTransactions";

Parameter REMOTETRANSACTIONSNODE = "OcuPilotProbeECPTransactions";

}
