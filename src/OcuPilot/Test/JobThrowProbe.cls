/// <p>Test-only <class>OcuPilot.Kernel.Agent.Job</class> subclass whose loop is
/// <class>OcuPilot.Test.LoopThrowProbe</class>, so <method>Run</method>'s catch path can be driven
/// in process (<class>OcuPilot.Test.TurnTools</class>). Spawns nothing.</p>
Class OcuPilot.Test.JobThrowProbe Extends OcuPilot.Kernel.Agent.Job
{

ClassMethod LoopClass() As %String
{
    Quit "OcuPilot.Test.LoopThrowProbe"
}

}
