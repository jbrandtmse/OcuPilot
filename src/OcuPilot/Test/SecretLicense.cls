/// <p>DW-420 -- the third condition of
/// <method>OcuPilot.Kernel.Secret.Ladder.CredentialsRungAvailable</method>: an instance that is not
/// licensed for the feature the predicate asks about cannot reach the credentials rung, with the
/// other two conditions true.</p>
/// <p>The first two conditions are already driven by <class>OcuPilot.Test.SecretAbsentRung</class>
/// and <class>OcuPilot.Test.SecretNotInterop</class>, each overriding one class-name parameter.
/// The license conjunct had no such seam, so it was the one term whose deletion left the suite
/// green. <class>OcuPilot.Test.SecretUnlicensedRung</class> is that seam: one parameter, every
/// method inherited.</p>
/// <p>Needs an instance holding the interoperability feature and not holding
/// <parameter>OcuPilot.Test.SecretUnlicensedRung.INTEROPFEATURE</parameter>; both are read back
/// here rather than assumed, so a license that changes fails naming the feature.</p>
Class OcuPilot.Test.SecretLicense Extends %UnitTest.TestCase
{

/// <p>The shipped ladder, whose predicate this class is about.</p>
Parameter SHIPPEDCLASS = "OcuPilot.Kernel.Secret.Ladder";

/// <p>The one-parameter subclass that moves only the feature index.</p>
Parameter UNLICENSEDCLASS = "OcuPilot.Test.SecretUnlicensedRung";

/// <p>DW-420 -- the two instance facts this class rests on, read back rather than assumed: the
/// shipped feature index is held here and the subclass's is not. A license that changes fails
/// here, naming the feature, instead of turning the assertion below into a tautology.</p>
Method TestTheChosenFeatureIsTheOneThisInstanceDoesNotHold()
{
    Set tShipped = $Parameter(..#SHIPPEDCLASS, "INTEROPFEATURE")
    Set tUnlicensed = $Parameter(..#UNLICENSEDCLASS, "INTEROPFEATURE")
    Do $$$AssertNotEquals(tUnlicensed, tShipped, "the subclass asks about a different feature index (" _ tUnlicensed _ " against " _ tShipped _ ")")
    Do $$$AssertEquals($System.License.GetFeature(tShipped), 1, "this instance is licensed for feature " _ tShipped _ ", the one the shipped predicate asks about")
    Do $$$AssertEquals($System.License.GetFeature(tUnlicensed), 0, "and is not licensed for feature " _ tUnlicensed _ ", the one the subclass asks about")
}

/// <p>DW-420 -- the other two conditions read true against the subclass, so nothing but the
/// license can be what makes the predicate answer 0.</p>
Method TestTheOtherTwoConditionsAreTrueAgainstTheSubclass()
{
    Set tCreds = $Parameter(..#UNLICENSEDCLASS, "CREDSCLASS")
    Set tManager = $Parameter(..#UNLICENSEDCLASS, "ENSEMBLEMGRCLASS")
    Do $$$AssertEquals(tCreds, $Parameter(..#SHIPPEDCLASS, "CREDSCLASS"), "the subclass inherits the shipped credential class")
    Do $$$AssertEquals(tManager, $Parameter(..#SHIPPEDCLASS, "ENSEMBLEMGRCLASS"), "and the shipped interoperability manager class")
    Do $$$AssertEquals(##class(%Dictionary.CompiledClass).%ExistsId(tCreds), 1, "condition 1: " _ tCreds _ " is compiled here")
    Do $$$AssertEquals(##class(%Dictionary.CompiledClass).%ExistsId(tManager), 1, "condition 2a: " _ tManager _ " is compiled here")
    Do $$$AssertEquals(''$ClassMethod(tManager, "IsEnsembleNamespace"), 1, "condition 2b: this namespace is interoperability-enabled")
}

/// <p>DW-420 -- the shipped predicate, evaluated against the unlicensed feature index with
/// conditions 1 and 2 true, answers 0; against the shipped index it answers 1. What produces the 0
/// is the shipped body reading a feature the instance lacks, not a switch.</p>
/// <p>Mutation: delete the license conjunct from
/// <method>OcuPilot.Kernel.Secret.Ladder.CredentialsRungAvailable</method> and recompile the
/// package -> this goes red, because the predicate then answers 1 against the subclass.</p>
Method TestAnUnlicensedInstanceCannotReachTheCredentialsRung()
{
    Do $$$AssertEquals(''$ClassMethod(..#SHIPPEDCLASS, "CredentialsRungAvailable"), 1, "the shipped ladder reaches the credentials rung on this instance")
    Do $$$AssertEquals(''$ClassMethod(..#UNLICENSEDCLASS, "CredentialsRungAvailable"), 0, "and the same body, asking about a feature this instance does not hold, does not")
}

/// <p>DW-420 -- the predicate the assertion above evaluates is the shipped one: the subclass
/// defines no method of its own, so nothing in it could answer instead.</p>
Method TestTheSubclassOverridesNoMethodAtAll()
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).IDKEYOpen(..#UNLICENSEDCLASS, "CredentialsRungAvailable", , .tSC)
    Do $$$AssertTrue($IsObject(tMethod), "the subclass carries a compiled copy of the predicate")
    If '$IsObject(tMethod) Quit
    Do $$$AssertEquals(tMethod.Origin, ..#SHIPPEDCLASS, "whose origin is the shipped ladder, so the body is the shipped one")
}

}
