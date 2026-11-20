/// <p>Test-only fixture for <class>OcuPilot.Test.AnalyticsPmmlRunCancel</class>: <class>OcuPilot.Test.PmmlTestIdle</class> whose supervisor can be held at two points until a test releases it, so that a cancel
/// arrives at a moment the supervisor cannot yet read it. When <code>^IRIS.Temp.OcuPilotPmmlLate("hold", point)</code> is set, the supervisor sets <code>("at", point)</code> on reaching the point, <code>event</code>
/// (before it creates the run's event resource) or <code>wait</code> (after it has spawned the child and before it waits on the event), and continues once <code>("go", point)</code> is set or thirty seconds have passed.
/// Its port is <class>OcuPilot.Test.PmmlPortSlowDrop</class>. With no node set it behaves as the idle fixture.</p>
Class OcuPilot.Test.PmmlTestLate Extends OcuPilot.Test.PmmlTestIdle
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.PmmlPortSlowDrop"
}

ClassMethod EnsureEvent(pEvent As %String) As %Boolean [ Private ]
{
    Do ..HoldAt("event")
    Quit ##super(pEvent)
}

ClassMethod Await(pKey As %String, pEvent As %String, pChild As %Integer, pSeconds As %Numeric) As %String [ Private ]
{
    Do ..HoldAt("wait")
    Quit ##super(pKey, pEvent, pChild, pSeconds)
}

/// <p>Hold at <var>pPoint</var> when a test asked for it (see the class).</p>
ClassMethod HoldAt(pPoint As %String) [ Private ]
{
    If '$Data(^IRIS.Temp.OcuPilotPmmlLate("hold", pPoint)) Quit
    Set ^IRIS.Temp.OcuPilotPmmlLate("at", pPoint) = 1
    Set tEnd = $ZHorolog + 30
    While ('$Data(^IRIS.Temp.OcuPilotPmmlLate("go", pPoint))) && ($ZHorolog < tEnd) {
        Hang 0.05
    }
}

}
