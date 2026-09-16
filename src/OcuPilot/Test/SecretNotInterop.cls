/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass whose
/// <parameter>OcuPilot.Kernel.Secret.Ladder.ENSEMBLEMGRCLASS</parameter> names a class that exists
/// and answers <code>IsEnsembleNamespace()</code> 0, so the rung predicate's second condition is
/// false while its first is true.</p>
/// <p><b>It is what makes DW-350's narrowing falsifiable.</b>
/// <class>OcuPilot.Test.SecretAbsentRung</class> falsifies the first condition alone -- the
/// credential class being absent -- so with it as the only probe, deleting the interoperability
/// conditions from <method>OcuPilot.Kernel.Secret.Ladder.CredentialsRungAvailable</method> reddens
/// nothing: on this namespace all three read 1 and the first already answers. This subclass
/// arranges the one state the narrowing exists for, a namespace that can reach the credential class
/// and is not interoperability-enabled, which is where the vendor's
/// <code>SecondarySet</code> succeeds and <code>SecondaryDelete</code> cannot.</p>
/// <p><b>Every other method is inherited</b>, so what answers 0 here is the shipped predicate
/// reading a real answer, not a switch that says "pretend not".</p>
Class OcuPilot.Test.SecretNotInterop Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>A class this instance does compile -- the one below -- whose
/// <method>IsEnsembleNamespace</method> answers 0.</p>
Parameter ENSEMBLEMGRCLASS = "OcuPilot.Test.NotEnsembleNamespace";

}
