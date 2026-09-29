/// <p>Test-only <class>OcuPilot.Test.ConfirmFixture</class> subclass whose one further seam is the
/// port the Background tasks tools declare: <method>PortClassOf</method> answers
/// <class>OcuPilot.Test.BackgroundTaskFixture</class>, so the confirm's re-read and write go through
/// the shipped background task port with its answers armed and its calls recorded. Everything else
/// is the shipped confirm.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.BackgroundTaskConfirm Extends OcuPilot.Test.ConfirmFixture
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit "OcuPilot.Test.BackgroundTaskFixture"
}

}
