/// <p><b>AC3</b> -- every branch of <class>OcuPilot.Kernel.Secret.Ladder</class>: the
/// <code>env</code> rung answering in this namespace with the credentials-rung predicate off and
/// with it armed to raise, the <code>creds</code> rung answering <code>""</code> for an empty name
/// and for an unreachable rung, the availability predicate itself, and the real round trip --
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method> then
/// <method>OcuPilot.Kernel.Secret.Ladder.Resolve</method> answering what was stored.</p>
/// <p><b>What it needs from the environment.</b> The round-trip legs need a namespace the
/// credentials rung is reachable from; where it is not, they are skipped and
/// <method>TestTheCredentialsRungRoundTrips</method> reports how many legs ran, so an assertion
/// over nothing is visible as such rather than green. Everything else runs anywhere.</p>
/// <p><b>It creates one credential entry</b>, <parameter>PROBECREDENTIAL</parameter>, and removes it
/// in <method>OnAfterOneTest</method> with an assertion that it is gone.
/// <class>OcuPilot.Test.CredentialFixture</class> is what reaches the entry, and why it reaches it
/// dynamically.</p>
Class OcuPilot.Test.Secret Extends %UnitTest.TestCase
{

/// <p>The credential entry the round trip writes and removes.</p>
Parameter PROBECREDENTIAL = "OcuPilotProbeCredential";

/// <p>A fabricated key. No provider is called and no shape gate is in play here -- the ladder
/// stores and answers whatever it is given.</p>
Parameter PROBEKEY = "probe-ladder-key-0000000000";

/// <p>A second one, so the update-an-existing-entry branch is told apart from the create one.</p>
Parameter SECONDKEY = "probe-ladder-key-1111111111";

/// <p>An environment variable name. Never set on the instance: the probe answers whatever name it
/// is asked for.</p>
Parameter PROBEVARIABLE = "OCUPILOT_PROBE_LADDER_KEY";

/// <p>A credential reference the vendor refuses: 76 characters against the credential entry's
/// <code>SystemName</code> <code>MAXLEN</code> of 50. A definition's own
/// <code>CredentialName</code> holds 128, so this is a reference an operator can store and the
/// credential store will not accept.</p>
Parameter TOOLONGNAME = "OcuPilotProbeCredentialReferenceTheCredentialStoreItselfWillNotAcceptAtAll00";

/// <p>Leave no switch set for the next method, and no credential entry on the instance.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
    If '##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable() Quit $$$OK
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "no credential entry this method created survives it")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#TOOLONGNAME)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#TOOLONGNAME), 0, "and nothing survives under the reference the vendor refuses either")
    Quit $$$OK
}

/// <p><b>AC3's first half</b> -- the <code>env</code> rung answers in any namespace, and consults
/// neither a namespace nor the credentials-rung predicate.</p>
/// <p>The second leg is what makes that an observation: the predicate is armed to <b>raise</b>, so
/// an arm that asked it would not answer at all. An arm that merely ignored a <code>0</code> answer
/// and an arm that never asked are the same reading.</p>
/// <p>Mutation: gate <method>OcuPilot.Kernel.Secret.Ladder.Resolve</method>'s <code>env</code> arm
/// on <method>CredentialsRungAvailable</method> -- the first leg goes red answering
/// <code>""</code>, and the second goes red with the raise escaping.</p>
Method TestTheEnvironmentArmConsultsNoRungPredicate()
{
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)

    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(0)
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretProbe).Resolve("env", ..#PROBEVARIABLE, ""), ..#PROBEKEY, "the env rung answers while the credentials rung reports itself unavailable")

    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable("raise")
    Set tThrew = 0
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(OcuPilot.Test.SecretProbe).Resolve("env", ..#PROBEVARIABLE, "")
    } Catch ex {
        Set tThrew = 1
    }
    Do $$$AssertEquals(tThrew, 0, "the env rung answers without the rung predicate being asked at all -- an armed predicate that was asked would have raised")
    Do $$$AssertEquals(tAnswer, ..#PROBEKEY, "and answers the variable's value")

    ; The probe really does raise when it is asked, so the leg above measured something.
    Set tPredicateThrew = 0
    Try {
        Do ##class(OcuPilot.Test.SecretProbe).CredentialsRungAvailable()
    } Catch predicateEx {
        Set tPredicateThrew = 1
    }
    Do $$$AssertEquals(tPredicateThrew, 1, "the armed predicate raises when it is asked, which is what makes the leg above non-vacuous")
}

/// <p>The <code>env</code> rung with no variable named, and a credential type the ladder does not
/// declare, both answer <code>""</code> rather than reaching a rung.</p>
Method TestAnUnnamedReferenceAndAnUnknownTypeAnswerEmpty()
{
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretProbe).Resolve("env", "", ""), "", "an env definition naming no variable resolves to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretProbe).Resolve("creds", "", ""), "", "a creds definition naming no entry resolves to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretProbe).Resolve("", ..#PROBEVARIABLE, ..#PROBECREDENTIAL), "", "a definition carrying no credential type resolves to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretProbe).Resolve("vault", ..#PROBEVARIABLE, ..#PROBECREDENTIAL), "", "and neither does one naming a rung the ladder does not declare")
}

/// <p><b>AC3's second half</b> -- the availability predicate answers for the class it names, and a
/// <code>creds</code> resolution through a class this instance does not hold answers
/// <code>""</code> and raises nothing.</p>
/// <p><b>The unreachable answer is measured, not simulated.</b>
/// <class>OcuPilot.Test.SecretAbsentRung</class> changes the class name and nothing else, so what
/// answers 0 is the shipped predicate reading an absent class -- and that the class compiles at all
/// is the proof that the rung is reached by dispatch rather than by a literal
/// <code>##class</code>.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Secret.Ladder.CredentialsRungAvailable</method> answer
/// 1 unconditionally -- the absent-class legs below go red.</p>
Method TestTheRungPredicateReadsTheClassItNames()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretAbsentRung).CredentialsRungAvailable(), 0, "a ladder naming a class this instance does not compile reports its rung unavailable")
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretAbsentRung).Resolve("creds", "", ..#PROBECREDENTIAL), "", "and a creds resolution through it answers nothing rather than raising")
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretAbsentRung).Credential(..#PROBECREDENTIAL), "", "asked for the entry directly, it answers nothing too")

    Set tStoreSC = ##class(OcuPilot.Test.SecretAbsentRung).Store(..#PROBECREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY), "apiKey")
    Do $$$AssertStatusNotOK(tStoreSC, "a store through an unreachable rung is refused")
    Set tText = $System.Status.GetErrorText(tStoreSC)
    Do $$$AssertTrue(tText [ ..#PROBECREDENTIAL, "naming the reference: " _ tText)
    Do $$$AssertEquals(tText [ ..#PROBEKEY, 0, "and never the value")
}

/// <p><b>AC3's round trip</b> -- a key stored through
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method> is what
/// <method>OcuPilot.Kernel.Secret.Ladder.Resolve</method> answers for the same reference, a second
/// store over the same reference replaces it, and an entry this instance does not hold resolves to
/// <code>""</code>.</p>
/// <p>Runs only where the credentials rung is reachable, and asserts how many legs ran, so a skip
/// reads as a skip.</p>
Method TestTheCredentialsRungRoundTrips()
{
    If '##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable() {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#PROBECREDENTIAL), "", "the credentials rung is not reachable from " _ $Namespace _ ", so a creds reference resolves to nothing and the round-trip legs are skipped -- nothing was written")
        Quit
    }
    Set tLegs = 0
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#PROBECREDENTIAL), "", "an entry this instance does not hold resolves to nothing")
    Set tLegs = tLegs + 1

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#PROBECREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY), "apiKey"), "the key is stored on the credentials rung")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 1, "the credential entry now exists")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#PROBECREDENTIAL), ..#PROBEKEY, "and the ladder answers what was stored")
    Set tLegs = tLegs + 1

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#PROBECREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#SECONDKEY), "apiKey"), "a second store over the same reference is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#PROBECREDENTIAL), ..#SECONDKEY, "and replaces the value rather than adding an entry")
    Set tLegs = tLegs + 1

    Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("env", ..#PROBEVARIABLE, ..#PROBECREDENTIAL), "", "an env definition does not fall back to the credentials entry its sibling field names")
    Set tLegs = tLegs + 1

    Do $$$AssertEquals(tLegs, 4, "every round-trip leg ran, so the assertions above were made about a reachable store")
}

/// <p>The fixture's copy of the request body's one member name is the production parameter's, held
/// equal here rather than left to agree by eye -- every call site in this suite passes that member
/// name to <method>OcuPilot.Kernel.Secret.Ladder.Store</method>, and a rename would otherwise leave
/// all of them silently wrong and the suite green.</p>
Method TestTheFixtureKeyFieldIsTheProductionOne()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).#KEYFIELD, ##class(OcuPilot.Api.Definitions).#KEYFIELD, "the fixture builds its body with the member the handler reads")
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).#KEYFIELD, "apiKey", "which is the member the wire contract publishes")
}

/// <p>A store that names no reference is refused, and refused before anything is written.</p>
Method TestAStoreNamingNoReferenceIsRefused()
{
    Set tSC = ##class(OcuPilot.Kernel.Secret.Ladder).Store("", ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY), "apiKey")
    Do $$$AssertStatusNotOK(tSC, "a store naming no credential reference is refused")
    Do $$$AssertEquals($System.Status.GetErrorText(tSC) [ ..#PROBEKEY, 0, "and the refusal names no part of the value")
}

/// <p><b>A real vendor refusal</b> -- the status OcuPilot answers names the reference alone, and
/// what reaches the log is the vendor status's error <b>codes</b> and none of its text (AD-35,
/// AD-39).</p>
/// <p>The refusal is the vendor's own, not a simulation: <code>SystemName</code> is the credential
/// entry's <code>IdKey</code> and carries <code>MAXLEN</code> 50, so a longer reference is refused
/// by <method>%Save</method> on this build. A definition's own <code>CredentialName</code> holds
/// 128, which is what makes the same failure reachable over the wire
/// (<method>OcuPilot.Test.AgentCredential.TestAVendorRefusalAnswers500AndCarriesNoValue</method>).</p>
/// <p>Driven through <class>OcuPilot.Test.SecretProbe</class> so the log seam is captured; every
/// other method of the ladder on that path is the shipped one.</p>
/// <p>Mutation: build <method>OcuPilot.Kernel.Secret.Ladder.LogReason</method> from
/// <code>$System.Status.GetErrorText</code> instead of <code>GetErrorCodes</code> -- the "none of
/// the vendor's own sentence" assertion goes red. The probe captures that method's own answer, so
/// the mutation is read on the shipped composition rather than on a copy of it.</p>
Method TestAVendorRefusalNamesTheReferenceAndLogsCodesOnly()
{
    If '##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable() {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#TOOLONGNAME), "", "the credentials rung is not reachable from " _ $Namespace _ ", so this leg is skipped and nothing was written")
        Quit
    }
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
    Do $$$AssertTrue($Length(..#TOOLONGNAME) > 50, "the reference is longer than the credential entry's own IdKey holds, which is what the vendor refuses: " _ $Length(..#TOOLONGNAME))

    Set tSC = ##class(OcuPilot.Test.SecretProbe).Store(..#TOOLONGNAME, ##class(OcuPilot.Test.CredentialFixture).Payload(..#PROBEKEY), "apiKey")
    Do $$$AssertStatusNotOK(tSC, "the vendor refuses the write and the ladder reports it")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ ..#TOOLONGNAME, "the status names the reference: " _ tText)
    Do $$$AssertEquals(tText [ ..#PROBEKEY, 0, "and no part of the value")
    Do $$$AssertEquals(tText [ "MAXLEN", 0, "and none of the vendor's own text, which is written about a credential write: " _ tText)

    Do $$$AssertNotEquals(##class(OcuPilot.Test.SecretProbe).CapturedLog("logMessage"), "", "the refusal reached the log seam, so the assertions below read a line rather than nothing")
    Set tLogged = ##class(OcuPilot.Test.SecretProbe).CapturedLog("logReason")
    Do $$$AssertTrue(tLogged [ "7201", "the logged line carries the vendor status's error code: " _ tLogged)
    Do $$$AssertEquals(tLogged [ "MAXLEN", 0, "and none of the vendor's own sentence, which names the field it refused")
    Do $$$AssertEquals(tLogged [ ..#PROBEKEY, 0, "and no part of the value")

    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#TOOLONGNAME), 0, "and nothing was written under that reference")
    ; DW-346's residual: the vendor's PasswordSet writes the value into its own secondary
    ; password store, ^Ens.SecondaryData.Password, before %Save is ever attempted -- so "nothing
    ; was written" above is narrower than it reads unless that store is checked too. Read
    ; directly rather than through the vendor's own accessor, which resolves it through the row
    ; this suite has already shown does not exist.
    Do $$$AssertEquals($Get(^Ens.SecondaryData.Password(..#TOOLONGNAME)), "", "and the refused save left no orphan in the vendor's own secondary password store either")
    Do ##class(OcuPilot.Test.SecretProbe).Clear()
}

/// <p><b>AC3</b> -- <method>OcuPilot.Kernel.Secret.Ladder.Credential</method> normalizes the
/// <code>$Char(0)</code> sentinel to <code>""</code> rather than answering it as a one-character
/// key, driven through <class>OcuPilot.Test.SecretFakeRung</class> so the row's
/// <code>Password</code> is exactly the sentinel with no vendor mechanism able to produce or
/// launder it -- the shape a real <code>Ens.Config.Credentials</code> row reads back as after a
/// SQL <code>UPDATE</code> sets its column to <code>''</code>, which this suite has no sanctioned
/// way to force on the vendor's own table.</p>
/// <p>Mutation: delete the <code>If $Property(tRow, "Password") = $Char(0) Return ""</code> guard
/// from <method>OcuPilot.Kernel.Secret.Ladder.Credential</method> -- the sentinel leg goes red,
/// answering the one-character sentinel instead of <code>""</code>.</p>
Method TestCredentialNormalizesTheCharZeroSentinel()
{
    Do ##class(OcuPilot.Test.FakeCredentialRow).Clear()
    Do ##class(OcuPilot.Test.FakeCredentialRow).SetPassword("probe", $Char(0))
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretFakeRung).Credential("probe"), "", "a Password reading back as the $Char(0) sentinel resolves to unresolved, not a one-character key")

    Do ##class(OcuPilot.Test.FakeCredentialRow).SetPassword("probe", ..#PROBEKEY)
    Do $$$AssertEquals(##class(OcuPilot.Test.SecretFakeRung).Credential("probe"), ..#PROBEKEY, "while an ordinary value still resolves, so the guard above is not answering empty for everything")
    Do ##class(OcuPilot.Test.FakeCredentialRow).Clear()
}

}
