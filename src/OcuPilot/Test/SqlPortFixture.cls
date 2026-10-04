/// <p><class>OcuPilot.Port.SqlPort</class> with a short bound, so a test stops a probe statement in
/// seconds rather than at the gateway's bound (<method>BoundSeconds</method>). Everything else is the
/// production port's: its gate, its prepare, its run and its alarm.</p>
Class OcuPilot.Test.SqlPortFixture Extends OcuPilot.Port.SqlPort
{

/// <p>The bound a probe statement is stopped at, in seconds.</p>
Parameter PROBESECONDS As INTEGER = 2;

ClassMethod BoundSeconds() As %Integer
{
    Quit ..#PROBESECONDS
}

}
