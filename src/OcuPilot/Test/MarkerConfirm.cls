/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Confirm</class> subclass with <b>one</b> seam
/// replaced: the audit emitter is <class>OcuPilot.Test.EventProbe</class>, which captures what a
/// dropped emission reports instead of logging it.</p>
/// <p>Everything else is the shipped code, the port included -- so a confirm through this class is
/// a real write to the instance through <class>OcuPilot.Port.AdminPort</class>, and the payload,
/// the redaction and the <code>$System.Security.Audit</code> call are production's own. The probe
/// replaces only the reporting, which is otherwise unobservable: an unregistered triple produces
/// no row and no console line of its own.</p>
/// <p>It also exposes <method>OcuPilot.Kernel.Proposal.Confirm.FieldNames</method>, which is
/// <code>Private</code>, so the write-time exclusion of a declared secret name can be driven
/// against a declaration no shipped descriptor makes yet
/// (<class>OcuPilot.Test.ConfirmFixture</class> exposes <code>WithSecrets</code> for the same
/// reason).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MarkerConfirm Extends OcuPilot.Kernel.Proposal.Confirm
{

ClassMethod EventClass() As %String
{
    Quit "OcuPilot.Test.EventProbe"
}

/// <p><method>OcuPilot.Kernel.Proposal.Confirm.FieldNames</method> as a test can reach it: the
/// names <var>pBody</var> carries, minus <var>pNames</var>. Nothing but a test calls this.</p>
ClassMethod FieldNamesFor(pBody As %DynamicObject, pNames As %List) As %List
{
    Quit ..FieldNames(pBody, pNames)
}

}
