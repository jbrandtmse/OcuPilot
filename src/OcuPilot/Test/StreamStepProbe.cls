/// <p>A <class>OcuPilot.Kernel.Agent.StreamStep</class> whose clock is a process-private counter a
/// test sets, so the cadence is exercised with no real time passing.</p>
Class OcuPilot.Test.StreamStepProbe Extends OcuPilot.Kernel.Agent.StreamStep
{

/// <p>Set the clock to <var>pMs</var>.</p>
ClassMethod SetClock(pMs As %Numeric)
{
    Set ^||OcuPilotStreamStepClock = +pMs
}

/// <p>Forget the clock.</p>
ClassMethod ResetClock()
{
    Kill ^||OcuPilotStreamStepClock
}

/// <p>The test's clock.</p>
Method NowMs() As %Numeric
{
    Quit +$Get(^||OcuPilotStreamStepClock)
}

}
