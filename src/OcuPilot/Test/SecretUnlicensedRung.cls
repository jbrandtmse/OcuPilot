/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass whose
/// <parameter>OcuPilot.Kernel.Secret.Ladder.INTEROPFEATURE</parameter> names a license feature this
/// instance does not hold, so <method>CredentialsRungAvailable</method>'s third condition is the
/// only one that reads false.</p>
/// <p><b>Every method is inherited.</b> This subclass changes nothing but which feature index the
/// shipped predicate asks about, which is what makes a 0 from it a measurement of the shipped
/// predicate reading an unlicensed feature rather than of a switch. It is not a
/// <class>%UnitTest.TestCase</class>, because a test case cannot also extend the ladder;
/// <class>OcuPilot.Test.SecretLicense</class> is what asserts against it.</p>
/// <p>6 is TrakCare (<class>%SYSTEM.License</class>'s feature table). The assertions do not trust
/// that: <class>OcuPilot.Test.SecretLicense</class> reads the feature back and fails naming it if
/// this instance ever does hold it.</p>
Class OcuPilot.Test.SecretUnlicensedRung Extends OcuPilot.Kernel.Secret.Ladder
{

Parameter INTEROPFEATURE = 6;

}
