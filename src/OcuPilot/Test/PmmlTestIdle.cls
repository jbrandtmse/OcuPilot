/// <p>Test-only fixture for Story 24.14's run suites: <class>OcuPilot.Area.Analytics.PmmlTest</class> whose child never enters a statement and ends only when a test releases it, so a cancel of
/// it is a cancel of a run in no SQL statement. The child sets <code>^IRIS.Temp.OcuPilotPmmlIdle("child")</code> to its process id and <code>("entered")</code> when its body begins, reads
/// <code>("release")</code> and ends the run <code>ended</code> (<code>canceled</code> when its owner asked) once that node is set or sixty seconds have passed. It changes nothing else.
/// <method>Bystander</method> is a second idle process, released by <code>("bystander")</code>, for a test to show that a cancel ends only the run's own child.</p>
Class OcuPilot.Test.PmmlTestIdle Extends OcuPilot.Area.Analytics.PmmlTest
{

/// <p>The seconds the child waits for its release before it ends anyway.</p>
Parameter IDLESECONDS As %Integer = 60;

ClassMethod ChildWork(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Set ^IRIS.Temp.OcuPilotPmmlIdle("child") = $Job
    Set ^IRIS.Temp.OcuPilotPmmlIdle("entered") = 1
    Set tEnd = $ZHorolog + ..#IDLESECONDS
    While ('$Data(^IRIS.Temp.OcuPilotPmmlIdle("release"))) && ($ZHorolog < tEnd) {
        Hang 0.1
    }
    Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEENDED"), "")
}

/// <p>An idle process that holds no run: it ends when <code>^IRIS.Temp.OcuPilotPmmlIdle("bystander")</code> is set, or after <parameter>IDLESECONDS</parameter> seconds.</p>
ClassMethod Bystander()
{
    Set tEnd = $ZHorolog + ..#IDLESECONDS
    While ('$Data(^IRIS.Temp.OcuPilotPmmlIdle("bystander"))) && ($ZHorolog < tEnd) {
        Hang 0.1
    }
}

}
