/// <p>Pins DW-1456 (AC7): the registry's confirm-channel validator and the write tool's field rows
/// read one spelling of a secret. For every candidate spelling of the X.509 edit entry's fields,
/// <method>OcuPilot.Screen.Registry.ConfirmChannelProblem</method> admits it as a
/// <code>secretArguments</code> entry exactly when <method>OcuPilot.Screen.Tool.Write.FieldRows</method>,
/// asked with that name declared secret, no longer advertises the field the spelling names -- so a
/// name the channel would carry is never one the model is also offered. The array spelling
/// <code>OwnerList[]</code>, which the confirm body never carries, is refused.</p>
/// <p><b>What it needs from the environment:</b> the compiled tree only. It reads the X.509 list's
/// declaration and the generated field lists and writes nothing.</p>
Class OcuPilot.Test.SecretSpelling Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter PROBE = "OcuPilot.Test.X509SecretProbe";

/// <p>Every spelling a declaration could use for a field of <code>security.x509.update</code>'s
/// entry: each derived path, each array path without its brackets, and each authored secret.</p>
Parameter CANDIDATES = "Alias,OwnerList,OwnerList[],PeerNames,PeerNames[],CAFile,CertificateFile,PrivateKeyFile,PrivateKeyPassword,Certificate,PrivateKey";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Declare", "")
    Quit $$$OK
}

/// <p>AC7: a spelling the validator admits is one the field rows drop, and a spelling the field rows
/// keep advertising is one the validator refuses, for every candidate.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Tool.Write.FieldRows</method> test the declared secrets
/// against the row's raw path (<code>$ListFind(tSecrets, tPath)</code>) -> <code>OwnerList</code> is
/// admitted and still advertised, <code>OwnerList[]</code> refused and dropped, and this goes
/// red.</p>
Method TestTheValidatorAdmitsExactlyTheSpellingsTheFieldRowsDrop()
{
    Do $ClassMethod(..#PROBE, "Declare", "")
    Set tBaseline = $ClassMethod(..#PROBE, "AdmittedNames")
    Do $$$AssertTrue($ListFind(tBaseline, "OwnerList") && $ListFind(tBaseline, "PeerNames"), "with nothing declared the edit's rows advertise both lists: " _ $ListToString(tBaseline))
    Set tCandidates = $ListFromString(..#CANDIDATES)
    For tI = 1:1:$ListLength(tCandidates) {
        Set tName = $List(tCandidates, tI)
        Set tField = $Select($Extract(tName, *-1, *) = "[]": $Extract(tName, 1, *-2), 1: tName)
        Set tAdmitted = (..ChannelProblem(tName) = "")
        Do $ClassMethod(..#PROBE, "Declare", tName)
        Set tDropped = '$ListFind($ClassMethod(..#PROBE, "AdmittedNames"), tField)
        Set tSchema = $ClassMethod(..#PROBE, "InputSchema").%Get("properties")
        Set tOffered = (tSchema.%GetTypeOf(tField) '= "unassigned") && (tField '= $ClassMethod(..#PROBE, "IdArgument"))
        Do $ClassMethod(..#PROBE, "Declare", "")
        Do $$$AssertEquals(tAdmitted, tDropped, tName _ ": admitted by the validator (" _ tAdmitted _ ") exactly when the field rows drop " _ tField _ " (" _ tDropped _ ")")
        If tAdmitted Do $$$AssertTrue('tOffered, tName _ ": and an admitted secret is never offered in the schema")
    }
}

/// <p>AC7: <code>OwnerList[]</code> and <code>PeerNames[]</code>, spellings the confirm body never
/// produces, are refused by name, while the plain names are admitted.</p>
Method TestTheArraySpellingIsRefused()
{
    For tName = "OwnerList[]", "PeerNames[]" {
        Set tProblem = ..ChannelProblem(tName)
        Do $$$AssertTrue(tProblem [ tName, tName _ " is refused by name: " _ tProblem)
    }
    For tName = "OwnerList", "PeerNames" {
        Do $$$AssertEquals(..ChannelProblem(tName), "", tName _ " is admitted")
    }
    Do $$$AssertEquals(..ChannelProblem(""), "", "the shipped declaration itself is admitted")
}

/// <p>The validator's answer for the X.509 list's declaration with <code>secretArguments</code>
/// replaced by <var>pName</var> alone, or by the shipped list when <var>pName</var> is empty.</p>
Method ChannelProblem(pName As %String) As %String
{
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    If $$$ISERR(tSC) Quit "the declaration did not parse"
    If pName '= "" Do tDeclaration.%Set("secretArguments", [(pName)])
    Quit ##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tDeclaration)
}

}
