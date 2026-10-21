/// <p>Fixture: the shipped ledger on an instance whose clock runs <parameter>OFFSET</parameter> seconds
/// east of UTC at every instant, so the local-time conversions can be driven in process on an instance
/// whose own zone is UTC. Only <method>OffsetAtUtc</method> and <method>OffsetAtLocal</method> are
/// replaced; the conversions, the bounded read, the criteria echo and the row <code>time</code> are the
/// shipped code.</p>
Class OcuPilot.Test.LedgerClockProbe Extends OcuPilot.Kernel.Audit.Ledger
{

/// <p>The seconds the probe's local time runs ahead of UTC: two hours.</p>
Parameter OFFSET = 7200;

ClassMethod OffsetAtUtc(pUtcH As %String) As %Integer
{
    Quit ..#OFFSET
}

ClassMethod OffsetAtLocal(pLocalH As %String) As %Integer
{
    Quit ..#OFFSET
}

}
