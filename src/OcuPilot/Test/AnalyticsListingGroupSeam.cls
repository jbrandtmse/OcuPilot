/// <p><class>OcuPilot.Port.AnalyticsPort</class> whose group writes save, compile and delete through <class>OcuPilot.Test.AnalyticsListingGroupAtelier</class>, so a test arms a
/// compile the instance refuses after the write's pre-checks passed. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsListingGroupSeam Extends OcuPilot.Port.AnalyticsPort
{

ClassMethod AtelierPortClass() As %String
{
    Quit "OcuPilot.Test.AnalyticsListingGroupAtelier"
}

}
