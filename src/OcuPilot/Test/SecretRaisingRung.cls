/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass whose
/// <parameter>OcuPilot.Kernel.Secret.Ladder.ENSEMBLEMGRCLASS</parameter> names
/// <class>OcuPilot.Test.RaisingEnsembleNamespace</class>, so the rung predicate raises inside its
/// own <code>Try</code> and answers 0 from its <code>Catch</code>.</p>
/// <p><b>Every method is inherited</b>, so what a resolution through this class reports is the
/// shipped ladder reading a predicate that failed -- not a switch that says "pretend", and not
/// <class>OcuPilot.Test.SecretProbe</class>'s raise, which lands outside that <code>Try</code>.</p>
Class OcuPilot.Test.SecretRaisingRung Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>A class whose <method>IsEnsembleNamespace</method> raises.</p>
Parameter ENSEMBLEMGRCLASS = "OcuPilot.Test.RaisingEnsembleNamespace";

}
