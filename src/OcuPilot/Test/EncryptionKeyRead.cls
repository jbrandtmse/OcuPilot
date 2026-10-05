/// <p>Pins Story 18.22's two reads (B1; AD-2, AD-36): Database encryption's and Data element encryption's
/// declared reads answer the same rows as <code>security.databaseencryption.read</code> and
/// <code>security.dataelementencryption.read</code>, and the write tools' fresh reads answer the same keys;
/// no answer carries a member beyond a key's identifier, its length and whether it is the default; and the
/// journal's use of a key (<code>JOURNALUSE</code>) answers for a key no journal file needs and refuses an
/// empty id.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It reads only; the instance it runs on
/// holds no active key (every instance here, CI included), so every list reads empty, and after each test
/// the encryption state reads as that test found it.</p>
Class OcuPilot.Test.EncryptionKeyRead Extends %UnitTest.TestCase
{

Parameter DATABASESCREEN = "OcuPilot.Screen.Descriptor.DatabaseEncryption";

Parameter DATAELEMENTSCREEN = "OcuPilot.Screen.Descriptor.DataElementEncryption";

Parameter PORT = "OcuPilot.Port.EncryptionPort";

Parameter PROBE = "OcuPilot.Test.EncryptionKeyProbe";

/// <p>The encryption facts before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "EncryptionFacts").%ToJSON()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tFacts = $ClassMethod(..#PROBE, "EncryptionFacts")
    Do $$$AssertTrue('tFacts.%IsDefined("error") && (..PreparedFacts '[ """error"":"), "the encryption facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts.%ToJSON(), ..PreparedFacts, "no key is activated and no encryption setting moved")
    Quit $$$OK
}

/// <p>B1: each screen's read and its read tool answer the same rows, and the write tools' fresh read the
/// same keys beside its four arguments, empty; on this instance every list is empty.</p>
/// <p>Mutation (Rule 19): Database encryption's read declares <code>GET</code> in place of
/// <code>LIST</code> -- its screen read fails and this goes red.</p>
Method TestEachReadAnswersTheSameRowsOnScreenAndTool()
{
    For tCase = $ListBuild(..#DATABASESCREEN, "security.databaseencryption.read", "DATABASEKEYS"), $ListBuild(..#DATAELEMENTSCREEN, "security.dataelementencryption.read", "DATAELEMENTKEYS") {
        Set tScreen = $List(tCase, 1)
        Kill tCriteria
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(tScreen, 100, .tRead, .tHttp, .tFault, .tCriteria)
        Do $$$AssertStatusOK(tSC, tScreen _ "'s read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
        Set tRows = $Select($IsObject($Get(tRead)): tRead.%Get("rows").%ToJSON(), 1: "none")
        Do $$$AssertEquals(tRows, "[]", tScreen _ " lists no active key on this instance")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($List(tCase, 2), .tTool)
        Do $$$AssertTrue($IsObject($Get(tTool)), $List(tCase, 2) _ " is registered")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, $List(tCase, 2) _ " answers")
        Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tRows, $List(tCase, 2) _ " answers the screen's rows")
        Kill tQuery
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Security.Encryption.Key", $List(tCase, 3), .tQuery, "", .tFresh, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, $List(tCase, 3) _ " answers")
        Do $$$AssertEquals($Select($IsObject($Get(tFresh)): tFresh.%ToJSON(), 1: ""), "{""Keys"":" _ tRows _ ",""root"":"""",""path"":"""",""AdminName"":"""",""KeyId"":""""}", $List(tCase, 3) _ " answers the same keys beside the arguments, empty")
    }
}

/// <p>B1: each read declares only a key's identifier, its length in bits and whether it is the default,
/// and each screen's context the same, over the vendor's own two lists.</p>
Method TestNoReadAnswersKeyMaterial()
{
    Do $$$AssertEquals(..Joined($ClassMethod(..#DATABASESCREEN, "Read").%Get("fields")), "Id,KeyLen,IsDefault", "Database encryption reads three members")
    Do $$$AssertEquals(..Joined($ClassMethod(..#DATAELEMENTSCREEN, "Read").%Get("fields")), "Id", "Data element encryption reads one")
    Do $$$AssertEquals(..Joined($ClassMethod(..#DATABASESCREEN, "Field", "context").%Get("fields")), "Id,KeyLen,IsDefault", "and each screen's context the same")
    Do $$$AssertEquals(..Joined($ClassMethod(..#DATAELEMENTSCREEN, "Field", "context").%Get("fields")), "Id", "for both")
    Do $$$AssertEquals($ClassMethod(..#DATABASESCREEN, "Read").%Get("source").%Get("type") _ " " _ $ClassMethod(..#DATAELEMENTSCREEN, "Read").%Get("source").%Get("type"), "LIST DATAELEMENTLIST", "over the vendor's own two lists")
}

/// <p>DW-2066, AD-27: the journal's use of a key answers <code>InUse</code> false for a key no journal file
/// needs, and an empty id is refused 400 before the vendor.</p>
Method TestTheJournalsUseOfAKeyIsRead()
{
    Kill tQuery
    Set tQuery("id") = "4AA5F70E-C07C-11F1-BFE2-F298FD505142"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Security.Encryption.Key", "JOURNALUSE", .tQuery, "", .tUse, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tUse)): tUse.%ToJSON(), 1: ""), "{""InUse"":false}", "no journal file needs a key that was never active")
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Security.Encryption.Key", "JOURNALUSE", .tQuery, "", .tUse, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 TOOL.ARGUMENTS", "an empty id is refused")
}

/// <p>A dynamic array of strings, comma-joined.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Set tOut = ""
    If '$IsObject(pArray) Quit ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tValue
    }
    Quit tOut
}

}
