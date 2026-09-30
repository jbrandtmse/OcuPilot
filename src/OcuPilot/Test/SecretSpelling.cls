/// <p>Pins DW-1456 (AC7): a name the confirm channel would carry is never one the model is also
/// offered. For every candidate spelling of the X.509 tools' fields,
/// <method>OcuPilot.Screen.Registry.ConfirmChannelProblem</method> admits it as a
/// <code>secretArguments</code> entry only when it is a top-level secret row of those tools, and
/// neither <method>OcuPilot.Screen.Tool.Write.FieldRows</method> nor the tool's input schema offers
/// an admitted name, even with nothing declared. An ordinary field and the array spelling
/// <code>OwnerList[]</code>, which the confirm body never carries, are refused (AD-6).</p>
/// <p><b>What it needs from the environment:</b> the compiled tree only. It reads the X.509 list's
/// declaration and the generated field lists and writes nothing.</p>
Class OcuPilot.Test.SecretSpelling Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter PROBE = "OcuPilot.Test.X509SecretProbe";

/// <p>Every spelling a declaration could use for a field of the X.509 tools' entries: each derived
/// path, each array path without its brackets, and each authored secret.</p>
Parameter CANDIDATES = "Alias,OwnerList,OwnerList[],PeerNames,PeerNames[],CAFile,CertificateFile,PrivateKeyFile,PrivateKeyPassword,Certificate,PrivateKey";

/// <p>The candidates that are a top-level secret row of the X.509 tools' field lists, in
/// <parameter>CANDIDATES</parameter>' order: the only ones a declaration may name.</p>
Parameter SECRETROWS = "PrivateKeyFile,PrivateKeyPassword,Certificate,PrivateKey";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Declare", "")
    Quit $$$OK
}

/// <p>AC7: the validator admits exactly the X.509 tools' top-level secret rows among the
/// candidates, and no name it admits is among the field rows or the schema the model is offered
/// with nothing declared.</p>
/// <p>Mutation: re-admit a settable name in
/// <method>OcuPilot.Screen.Registry.ConfirmChannelProblem</method>'s <code>secretArguments</code>
/// check -> <code>OwnerList</code> is admitted, the admitted set widens, and this goes red; let
/// <method>OcuPilot.Screen.Tool.Write.FieldRows</method> keep a <code>secret</code> row -> an
/// admitted name is offered, and this goes red.</p>
Method TestAnAdmittedSpellingIsNeverOffered()
{
    Do $ClassMethod(..#PROBE, "Declare", "")
    Set tBaseline = $ClassMethod(..#PROBE, "AdmittedNames")
    Do $$$AssertTrue($ListFind(tBaseline, "OwnerList") && $ListFind(tBaseline, "PeerNames"), "with nothing declared the edit's rows advertise both lists: " _ $ListToString(tBaseline))
    Set tSchema = $ClassMethod(..#PROBE, "InputSchema").%Get("properties")
    Set tCandidates = $ListFromString(..#CANDIDATES)
    Set tAdmittedNames = ""
    For tI = 1:1:$ListLength(tCandidates) {
        Set tName = $List(tCandidates, tI)
        If ..ChannelProblem(tName) '= "" Continue
        Set tAdmittedNames = tAdmittedNames _ $ListBuild(tName)
        Set tField = $Select($Extract(tName, *-1, *) = "[]": $Extract(tName, 1, *-2), 1: tName)
        Set tInRows = ''$ListFind(tBaseline, tField)
        Set tInSchema = (tSchema.%GetTypeOf(tField) '= "unassigned")
        Do $$$AssertTrue('tInRows && 'tInSchema, tName _ ": an admitted secret is neither among the field rows (" _ tInRows _ ") nor in the schema (" _ tInSchema _ ") the model is offered")
    }
    Do $$$AssertEquals($ListToString(tAdmittedNames), ..#SECRETROWS, "the validator admits the tools' top-level secret rows and nothing else")
}

/// <p>AC7: <code>OwnerList[]</code> and <code>PeerNames[]</code>, spellings the confirm body never
/// produces, are refused by name, and so are the plain names, which no tool sends as a secret; the
/// shipped declaration is admitted.</p>
Method TestTheArraySpellingIsRefused()
{
    For tName = "OwnerList[]", "PeerNames[]", "OwnerList", "PeerNames" {
        Set tProblem = ..ChannelProblem(tName)
        Do $$$AssertTrue(tProblem [ ("'" _ tName _ "'"), tName _ " is refused by name: " _ tProblem)
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
