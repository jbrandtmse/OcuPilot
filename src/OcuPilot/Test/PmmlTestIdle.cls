/// <p>Test-only fixture for Story 24.14 Batch 2's run suites: <class>OcuPilot.Area.Analytics.PmmlTest</class> whose job never enters a statement and ends only when a test releases it, with a cancel
/// that spends two seconds, not ten, and stops after sixty sends. A cancel of such a run can only be bounded by its budget, which a run over a real model cannot show: the vendor's model loop enters
/// the SQL engine for a moment of each row, and the real run's one slow source takes minutes to end. The job sets <code>^IRIS.Temp.OcuPilotPmmlIdle("entered")</code> when its work begins, reads
/// <code>("release")</code> and ends the run <code>ended</code> (<code>canceled</code> when its owner asked) once that node is set or sixty seconds have passed. It changes nothing else.</p>
Class OcuPilot.Test.PmmlTestIdle Extends OcuPilot.Area.Analytics.PmmlTest
{

Parameter CANCELTRIES As %Integer = 60;

Parameter CANCELBUDGET As %Integer = 2;

/// <p>The seconds the job waits for its release before it ends anyway.</p>
Parameter IDLESECONDS As %Integer = 60;

ClassMethod Work(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Set ^IRIS.Temp.OcuPilotPmmlIdle("entered") = 1
    Set tEnd = $ZHorolog + ..#IDLESECONDS
    While ('$Data(^IRIS.Temp.OcuPilotPmmlIdle("release"))) && ($ZHorolog < tEnd) {
        Hang 0.1
    }
    Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEENDED"), "")
}

}
