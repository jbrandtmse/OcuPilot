/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass whose
/// <parameter>OcuPilot.Kernel.Secret.Ladder.CREDSCLASS</parameter> names
/// <class>OcuPilot.Test.FakeCredentialRow</class> -- a class this instance always compiles, so
/// <method>CredentialsRungAvailable</method> answers 1 here and every method below reaches the
/// shipped <method>Credential</method> body against a row a test fully controls.</p>
/// <p><b>Every method is inherited.</b> This subclass changes nothing but which class the
/// <code>creds</code> rung reaches, which is what makes an answer read back through
/// <class>OcuPilot.Test.FakeCredentialRow</class> a measurement of <method>Credential</method>'s
/// own normalization rather than of a substitute for it.</p>
Class OcuPilot.Test.SecretFakeRung Extends OcuPilot.Kernel.Secret.Ladder
{

Parameter CREDSCLASS = "OcuPilot.Test.FakeCredentialRow";

}
