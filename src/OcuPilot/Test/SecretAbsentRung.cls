/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass whose
/// <parameter>OcuPilot.Kernel.Secret.Ladder.CREDSCLASS</parameter> names a class this instance
/// never compiles, so the credentials rung is genuinely unreachable from it.</p>
/// <p>It exists because the availability predicate cannot be falsified on an instance that has the
/// rung: <method>OcuPilot.Kernel.Secret.Ladder.CredentialsRungAvailable</method> answers 1 there
/// whatever it does, and a switch that merely says "pretend not" tests the switch. This subclass
/// changes nothing but the name, so what answers 0 here is the shipped predicate reading a class
/// that is absent -- which is the edition this story's dynamic dispatch exists for.</p>
/// <p><b>Every method is inherited.</b> A <code>creds</code> resolution through this class must
/// answer <code>""</code> and raise nothing, which is also the proof that
/// <parameter>OcuPilot.Kernel.Secret.Ladder.CREDSCLASS</parameter> is reached by dispatch and never
/// by a literal <code>##class</code>: a literal would not have compiled.</p>
Class OcuPilot.Test.SecretAbsentRung Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>A class name this instance never compiles. Nothing here needs it to exist -- that is the
/// point of it.</p>
Parameter CREDSCLASS = "OcuPilot.Test.NoSuchCredentialsClassAtAll";

}
