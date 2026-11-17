/// <p>The limits class the instance's own rule reads its retention and queued limits from, for each of the two
/// sweeps a reserve makes on every user's behalf: the turn reserve's and the background run reserve's. The
/// state stores read it for a caller who does not hold the administrative resource, in place of the limits class
/// that caller passed (<method>OcuPilot.Kernel.State.Base.InstanceLimitsClass</method>, AD-9), so the two class
/// names are held here, outside <code>Kernel/State</code>, and nowhere else.</p>
Class OcuPilot.Kernel.InstanceLimits Extends %RegisteredObject
{

/// <p>The limits class the turn loop reads (<method>OcuPilot.Kernel.Agent.Loop.LimitsClass</method>).</p>
ClassMethod ForTurns() As %String
{
    Quit ##class(OcuPilot.Kernel.Agent.Loop).LimitsClass()
}

/// <p>The limits class the background runs read (<method>OcuPilot.Kernel.Shell.BackgroundRun.LimitsClass</method>).</p>
ClassMethod ForRuns() As %String
{
    Quit ##class(OcuPilot.Kernel.Shell.BackgroundRun).LimitsClass()
}

}
