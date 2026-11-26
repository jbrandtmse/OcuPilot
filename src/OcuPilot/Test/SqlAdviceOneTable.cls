/// <p><class>OcuPilot.Port.SqlAdvice</class> with its table cap lowered to one, so a test can read the advice of a two-table plan cut at the cap through
/// <class>OcuPilot.Test.SqlTuningPortFixture</class>. Everything else is the production advice's.</p>
Class OcuPilot.Test.SqlAdviceOneTable Extends OcuPilot.Port.SqlAdvice
{

Parameter MAXTABLES As INTEGER = 1;

}
