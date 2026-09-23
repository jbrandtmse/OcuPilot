/// <p>Subclass of <class>OcuPilot.Api.ScreenAction</class> that points its port seam at
/// <class>OcuPilot.Test.MarkingPort</class> and captures a failed marking observation's log line in
/// <code>^||OcuPilotMarkingAction</code>, so the screen caller's post-write observation runs
/// without a write.</p>
Class OcuPilot.Test.MarkingAction Extends OcuPilot.Api.ScreenAction
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.MarkingPort"
}

ClassMethod LogObserveFailure(pToolClass As %String, pStatus As %Status)
{
    Set ^||OcuPilotMarkingAction($Increment(^||OcuPilotMarkingAction)) = pToolClass
}

/// <p>Run the screen caller's post-write observation for <var>pToolClass</var>.</p>
ClassMethod Observe(pToolClass As %String)
{
    Do ..ObserveMarking(pToolClass)
}

/// <p>How many failed observations were logged since <method>Clear</method>.</p>
ClassMethod Logged() As %Integer
{
    Quit +$Get(^||OcuPilotMarkingAction)
}

ClassMethod Clear()
{
    Kill ^||OcuPilotMarkingAction
}

}
