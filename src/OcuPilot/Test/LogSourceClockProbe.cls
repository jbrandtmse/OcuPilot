/// <p>Fixture: the shipped log source port on an instance whose clock runs <parameter>OFFSET</parameter> seconds
/// east of UTC at every instant, so <method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method> can be driven in process
/// on an instance whose own zone is UTC. Only <method>OffsetAtUtc</method> is replaced.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LogSourceClockProbe Extends OcuPilot.Port.LogSourcePort
{

/// <p>The seconds the probe's local time runs ahead of UTC: two hours.</p>
Parameter OFFSET = 7200;

ClassMethod OffsetAtUtc(pUtcH As %String) As %Integer
{
    Quit ..#OFFSET
}

}
