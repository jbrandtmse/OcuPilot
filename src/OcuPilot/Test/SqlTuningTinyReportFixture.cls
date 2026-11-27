/// <p><class>OcuPilot.Test.SqlTuningPortFixture</class> with a report cap of ten characters, so any generated report is longer than the cap a report to
/// the browser may answer. Everything else is that fixture's.</p>
Class OcuPilot.Test.SqlTuningTinyReportFixture Extends OcuPilot.Test.SqlTuningPortFixture
{

Parameter MAXREPORTCHARACTERS As INTEGER = 10;

}
