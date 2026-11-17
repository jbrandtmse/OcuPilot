/// <p>Pins Story 24.10's term list export, import and copy (AD-21, AD-54, AD-65) against <code>USER</code>, with analytics on through
/// <class>OcuPilot.Test.AnalyticsProbe</class>, lists named with this class's own marker and server files in
/// <class>OcuPilot.Test.ExplorerTransferProbe</class>'s directory. The port legs are the story's matrix through
/// <class>OcuPilot.Test.AnalyticsTermListSeam</class>, which counts the vendor calls: an export to a file and to the browser, the round trip, a
/// local import, a taken name, the shape breaches, a file that changed after its review, a copy, a value write that fails part-way, a path that is
/// refused, the destination's refusals, each transfer's script form and OcuPilot's own audit rows. The route legs drive both callers over HTTP: the
/// person's Export, Import and Copy, and the agent's three proposals, minted and confirmed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics on in
/// <code>USER</code> and writes term lists and files there. It removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsTermListTransfer Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FILES = "OcuPilot.Test.ExplorerTransferProbe";

Parameter EDIT = "OcuPilot.Test.AnalyticsTermListEdit";

Parameter SEAM = "OcuPilot.Test.AnalyticsTermListSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter NAMESPACE = "USER";

/// <p>The prefix of every list this class makes, upper-cased by the vendor.</p>
Parameter MARKER = "OcuProbeTL2410";

Parameter LISTS = "/screens/analytics.termlists/action";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListExport";

Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListImport";

Parameter COPYTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListCopy";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListTransfer turns analytics on in USER and writes term lists and files there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the lists and the directory; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ..Sweep()
    Set tSC = $ClassMethod(..#FILES, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListTransfer left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && (..Marked() '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListTransfer left term lists in USER: " _ ..Marked())
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ..Sweep()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $ClassMethod(..#FILES, "MakeDirectory")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Sweep()
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "RemoveDirectory"), "the probe directory is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Kill every list this class marked in <code>USER</code>.</p>
ClassMethod Sweep()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tId = $Order(^DeepSee.TermList(""))
        While tId '= "" {
            Set tNext = $Order(^DeepSee.TermList(tId))
            If $Extract(tId, 1, $Length(..#MARKER)) = $ZConvert(..#MARKER, "U") Do ##class(%DeepSee.TermList).%DeleteTermList(tId)
            Set tId = tNext
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>The lists this class marked that remain in <code>USER</code>, comma-separated.</p>
ClassMethod Marked() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tNames = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tId = $Order(^DeepSee.TermList(""))
        While tId '= "" {
            If $Extract(tId, 1, $Length(..#MARKER)) = $ZConvert(..#MARKER, "U") Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tId
            Set tId = $Order(^DeepSee.TermList(tId))
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>Every node of the marked lists, as one string, so that "nothing was written" is a comparison.</p>
ClassMethod Snapshot() As %String
{
    Quit $ClassMethod(..#EDIT, "Snapshot")
}

/// <p>The call <var>pType</var> on the term lists for <var>pId</var> through the seam port, with the query members of <var>pExtra</var> added, as
/// <code>&lt;http&gt; &lt;code&gt;</code>; the answer is in <var>pResult</var>, the fault in <var>pFault</var>. <var>pAction</var> composes a read for that write.</p>
ClassMethod T(pType As %String, pId As %String, pExtra As %DynamicObject, Output pResult, Output pFault, pAction As %String = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    If $IsObject(pExtra) {
        Set tIterator = pExtra.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tQuery(tKey) = tValue
        }
    }
    Set pResult = ""
    Set pFault = ""
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "TermLists", pType, .tQuery, "", .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>The list <var>pName</var>, which holds the field <code>Region</code>, with keys that hold a comma, a double quote and an accented
/// letter, as the arrangement of a leg.</p>
ClassMethod Arrange(pName As %String)
{
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "ADD", pName, {"Caption": ("Cap, " _ $Char(34) _ "q" _ $Char(34)), "Description": "Desc", "Pattern": "*", "SubjectArea": "Sales", "Fields": ["Region", "Note"], "HideValue": false}, .tRes, .tFault)
    For tCase = $ListBuild("a,b", "v1", "West", "n1"), $ListBuild("q""k", "v2", "", "n2"), $ListBuild("plain", "v3", "East", ""), $ListBuild("u" _ $Char(233), "x" _ $Char(233), "", "") {
        Do $ClassMethod(..#EDIT, "Call", "TermListEntries", "ENTRYADD", $ClassMethod(..#EDIT, "Entry", pName, $List(tCase, 1)), {"Value": ($List(tCase, 2)), "FieldValues": [{"Field": "Region", "Value": ($List(tCase, 3))}, {"Field": "Note", "Value": ($List(tCase, 4))}]}, .tRes, .tFault)
    }
}

/// <p>The list <var>pName</var> as the vendor's <code>%ToObj</code> reads it: the header, then each key with its value and field values, as one
/// string; <code>""</code> when it is not held. The stamp is left out.</p>
ClassMethod Dump(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tObject = ##class(%DeepSee.TermList).%ToObj(pName)
        If $IsObject(tObject) {
            Set tText = tObject.caption _ "|" _ tObject.description _ "|" _ tObject.pattern _ "|" _ tObject.subjectArea _ "|" _ tObject.fieldListString
            For tAt = 1:1:tObject.keyList.Count() {
                Set tKey = tObject.keyList.GetAt(tAt)
                Set tText = tText _ "~" _ tKey
                For tField = 1:1:tObject.fieldList.Count() {
                    Set tText = tText _ "^" _ tObject.valueList.GetAt(tKey _ "^" _ $ZConvert(tObject.fieldList.GetAt(tField), "U"))
                }
                Set tText = tText _ "^" _ tObject.valueList.GetAt(tKey _ "^VALUE")
            }
        }
    } Catch ex {
        Set tText = "unreadable " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>The hide-value node of <var>pName</var> in <code>USER</code>.</p>
ClassMethod HideNode(pName As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tNode = $Get(^DeepSee.TermList($ZConvert(pName, "U"), "hideValue"))
    Set $NAMESPACE = tOrigNS
    Quit tNode
}

/// <p>The server file <var>pName</var> as the query members that name it.</p>
ClassMethod FileQuery(pName As %String) As %DynamicObject
{
    Quit {"root": ($ClassMethod(..#FILES, "Root")), "path": ($ClassMethod(..#FILES, "RelativeName", pName))}
}

/// <p>The lines of <var>pText</var>, as an array.</p>
ClassMethod LinesOf(pText As %String) As %DynamicArray
{
    Quit ##class(OcuPilot.Port.AtelierPort).Lines(pText)
}

/// <p>The reviewed digest of the import the query <var>pExtra</var> names, from the port's read.</p>
ClassMethod DigestOf(pExtra As %DynamicObject) As %String
{
    Set tStatus = ..T("IMPORTFILE", "import", pExtra, .tRead, .tFault, "IMPORT")
    If $IsObject(tRead) Quit tRead.Digest
    Quit ""
}

/// <p>A person's route <var>pPath</var> with <var>pBody</var>: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod Post(pPath As %String, pBody As %DynamicObject, Output pAnswer) As %Integer
{
    Do $ClassMethod(..#CONTROL, "CallWide", "POST", pPath, pBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>The person's screen action <var>pAction</var> on <var>pId</var> with the values <var>pValues</var>.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject, Output pAnswer) As %Integer
{
    Set tBody = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Quit ..Post(..#LISTS, tBody, .pAnswer)
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var> as the HTTP account: the proposal in <var>pProposal</var>, the turn in <var>pTurn</var>.</p>
Method Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pTurn As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, $Parameter(pTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>Confirm <var>pProposal</var> over HTTP: the answer in <var>pAnswer</var>, the status returned.</p>
ClassMethod Confirm(pProposal, Output pAnswer, Output pRaw) As %Integer
{
    Do $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer)
    Quit tStatus
}

/// <p>The count of <code>ConfigChange</code> rows of the list <var>pId</var> with the verb <var>pVerb</var> since <var>pSince</var>.</p>
ClassMethod Rows(pSince As %String, pId As %String, pVerb As %String) As %Integer
{
    Quit $ClassMethod(..#QUEUES, "AuditRows", pSince, "term-list", pId, pVerb, .tData)
}

/// <p>AC1: an export writes the vendor's CSV to a server file, and, with no file, answers its lines to the browser, which equal the file's. The
/// answers carry the file or the lines and nothing else; the file holds the header, the fields and every key, whose comma, double quote and accented
/// letter are the vendor's own quoting.</p>
/// <p>Mutation (Rule 19): skip the file in <method>OcuPilot.Port.AnalyticsPort.VendorTermListExport</method> (export through the capture whatever
/// the file) -- the file leg goes red.</p>
Method TestAnExportWritesTheVendorsCsvToAFileAndToTheBrowser()
{
    Set tName = ..#MARKER _ "Export"
    Do ..Arrange(tName)
    Set tFile = ..FileQuery("a.csv")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("EXPORT", tName, tFile, .tRes, .tFault), "200 ", "the export to a file answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Name _ "|" _ tRes.Namespace _ "|" _ tRes.root _ "|" _ tRes.path _ "|" _ tRes.%GetTypeOf("lines"), tName _ "|USER|" _ tFile.root _ "|" _ tFile.path _ "|unassigned", "its answer names the file and holds no lines")
    Set tText = $ClassMethod(..#FILES, "ReadFile", "a.csv")
    Do $$$AssertTrue($Extract(tText, 1, 7) = "%%NAME,", "the file starts with the vendor's name line")
    Set tQuote = $Char(34)
    Do $$$AssertTrue((tText [ (tQuote _ "a,b" _ tQuote _ ",v1,West,n1")) && (tText [ (tQuote _ "q" _ tQuote _ tQuote _ "k" _ tQuote _ ",v2,,n2")) && (tText [ ("u" _ $Char(233) _ ",x" _ $Char(233))), "and holds each key with the vendor's quoting and the accented letter")
    Do $$$AssertEquals(..T("EXPORT", tName, "", .tBrowser, .tFault), "200 ", "the export to the browser answers 200")
    If $IsObject(tBrowser) {
        Do $$$AssertEquals(tBrowser.%GetTypeOf("root") _ "|" _ tBrowser.%GetTypeOf("lines"), "unassigned|array", "its answer holds lines and no file")
        Do $$$AssertEquals(tBrowser.lines.%ToJSON(), ..LinesOf(tText).%ToJSON(), "and the lines are the file's lines")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 2, "each export made one vendor call")
}

/// <p>AC1: an export to the browser past the text bound is refused <code>TOOLARGE</code>, and one to a file is not.</p>
/// <p>Mutation (Rule 19): drop the bound in <method>OcuPilot.Port.AnalyticsPort.VendorTermListExport</method> -- the refusal leg goes red.</p>
Method TestAnExportToTheBrowserPastTheTextBoundIsRefused()
{
    Set tName = ..#MARKER _ "Large"
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "ADD", tName, {"Caption": "Big"}, .tRes, .tFault)
    Set tValue = $Translate($Justify("", 32000), " ", "x")
    For tAt = 1:1:100 {
        Do $ClassMethod(..#EDIT, "Call", "TermListEntries", "ENTRYADD", $ClassMethod(..#EDIT, "Entry", tName, "K" _ tAt), {"Value": (tValue)}, .tRes, .tFault)
    }
    Do $$$AssertEquals(..T("EXPORT", tName, "", .tBrowser, .tFault), "409 ANALYTICS.TERMLIST.TOOLARGE", "the browser's export past 3,000,000 characters is refused")
    Do $$$AssertEquals(..T("EXPORT", tName, ..FileQuery("big.csv"), .tFileRes, .tFault), "200 ", "the same list exports to a file")
}

/// <p>AC2: export a list, delete it and import the export from the server file: the vendor's <code>%ToObj</code> reads every header value, field
/// and value of the original. The hide-value flag the vendor's export does not carry is not set.</p>
/// <p>Mutation (Rule 19): drop record <code>f + 2</code> of an entry in <method>OcuPilot.Port.AnalyticsPort.TermListParse</method> -- the round trip goes red.</p>
Method TestAnExportImportsBackAsTheSameList()
{
    Set tName = ..#MARKER _ "Round"
    Do ..Arrange(tName)
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "UPDATE", tName, {"HideValue": true}, .tRes, .tFault)
    Set tFile = ..FileQuery("round.csv")
    Do $$$AssertEquals(..T("EXPORT", tName, tFile, .tRes, .tFault), "200 ", "the list exports")
    Set tBefore = ..Dump(tName)
    Do $$$AssertTrue(tBefore [ "~a,b^West^n1^v1", "the original reads as arranged: " _ tBefore)
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Call", "TermLists", "DELETE", tName, {}, .tRes, .tFault), "200 ", "the list is deleted")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", tFile, .tRead, .tFault, "IMPORT"), "200 ", "the import's read answers: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Name _ "|" _ tRead.FileEntries _ "|" _ tRead.Present, tName _ "|4|0", "it names the list the file holds, its four keys, and that the name is free")
    Do tFile.%Set("digest", tRead.Digest)
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "200 ", "the import answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Name _ "|" _ tRes.Namespace, tName _ "|USER", "its answer is the list read again")
    Do $$$AssertEquals(..Dump(tName), tBefore, "the vendor reads every header value, field and value of the original")
    Do $$$AssertEquals(..HideNode(tName), "", "except the hide-value flag, which the vendor's export does not carry")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", tFile, .tAgain, .tFault, "IMPORT"), "409 ANALYTICS.TERMLIST.TAKEN", "and a second import's read finds the name taken")
}

/// <p>AC2: a local file's text imports as a file this browser read; the list is created and its entries read; a text with a line break after a
/// carriage return and a byte order mark reads as the vendor's export does.</p>
Method TestALocalImportCreatesTheList()
{
    Set tName = ..#MARKER _ "Local"
    Set tText = $Char(65279) _ "%%NAME," _ tName _ $Char(13, 10) _ "%%CAPTION,From a file" _ $Char(13, 10) _ "%%FIELDLIST,Region" _ $Char(13, 10) _ "%%HIDEVALUE,1" _ $Char(13, 10) _ "k1,v1,West" _ $Char(13, 10) _ $Char(13, 10) _ $Char(34) _ "k,2" _ $Char(34) _ "," _ $Char(34) _ "v" _ $Char(34) _ $Char(34) _ "2" _ $Char(34) _ "," _ $Char(13, 10)
    Set tExtra = {"fileName": "local.csv", "content": (tText)}
    Do tExtra.%Set("digest", ..DigestOf(tExtra))
    Do $$$AssertEquals(..T("IMPORT", "import", tExtra, .tRes, .tFault), "200 ", "the local import answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Dump(tName), "From a file||||Region~k,2^^v" _ $Char(34) _ "2~k1^West^v1", "the list holds the header and both entries, quoting read as the vendor reads it, in the vendor's key order")
    Do $$$AssertEquals(..HideNode(tName), 1, "and the file's hide-value flag is read when it carries one")
    Do $$$AssertEquals(..Marked(), $ZConvert(tName, "U"), "and nothing else was created")
}

/// <p>AC4: an import or a copy to a name held in another letter case is refused <code>TAKEN</code>, before any vendor call, whatever its caller sends.</p>
/// <p>Mutation (Rule 19): skip the held check in <method>OcuPilot.Port.AnalyticsPort.CreateRefusal</method> -- the taken legs go red.</p>
Method TestATakenNameIsRefusedBeforeTheVendor()
{
    Set tName = ..#MARKER _ "Taken"
    Do ..Arrange(tName)
    Set tText = "%%NAME," _ $ZConvert(tName, "L") _ $Char(10) _ "k1,v1" _ $Char(10)
    Set tExtra = {"fileName": "taken.csv", "content": (tText)}
    Do tExtra.%Set("digest", ..TextDigest(tText))
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("IMPORT", "import", tExtra, .tRes, .tFault), "409 ANALYTICS.TERMLIST.TAKEN", "an import of a name held in another case is refused")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", tExtra, .tRead, .tFault, "IMPORT"), "409 ANALYTICS.TERMLIST.TAKEN", "and its read composed for the import is too")
    Do $$$AssertEquals(..T("COPY", tName, {"newName": ($ZConvert(tName, "L"))}, .tRes, .tFault), "409 ANALYTICS.TERMLIST.TAKEN", "a copy onto the source itself is refused")
    Do $$$AssertEquals(..T("COPYTARGET", tName, {"newName": (tName _ "x")}, .tRead, .tFault, "COPY"), "200 ", "a copy's read for a free name answers")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.Name _ "|" _ tRead.Entries _ "|" _ tRead.NewName _ "|" _ tRead.Present, tName _ "|4|" _ tName _ "x|0", "naming the source, its entries and the free name")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing was written")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "with no vendor call")
}

/// <p>The SHA-256 the port gives <var>pText</var>.</p>
ClassMethod TextDigest(pText As %String) As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).TextDigest(pText)
}

/// <p>AC4: a file with no <code>%%NAME</code> or no entry is refused <code>IMPORTSHAPE</code>, and a key holding <code>^</code> and a value of 32,001
/// characters are refused 422 naming their rule, each before any vendor call; a copy to a name the rules refuse is too.</p>
/// <p>Mutation (Rule 19): admit <code>^</code> in a key in <method>OcuPilot.Port.AnalyticsPort.NameShaped</method> -- the key leg goes red.</p>
Method TestShapeBreachesNeverReachTheVendor()
{
    Set tName = ..#MARKER _ "Shape"
    Do ..Arrange(tName)
    Set tBefore = ..Snapshot()
    Do $ClassMethod(..#SEAM, "Reset")
    For tCase = $ListBuild("no name", "k1,v1" _ $Char(10), "409 ANALYTICS.TERMLIST.IMPORTSHAPE"), $ListBuild("no entry", "%%NAME," _ tName _ "X" _ $Char(10), "409 ANALYTICS.TERMLIST.IMPORTSHAPE"), $ListBuild("caret key", "%%NAME," _ tName _ "X" _ $Char(10) _ "a^b,v1" _ $Char(10), "422 ANALYTICS.TERMLIST.KEY"), $ListBuild("long value", "%%NAME," _ tName _ "X" _ $Char(10) _ "k1," _ $Translate($Justify("", 32001), " ", "x") _ $Char(10), "422 ANALYTICS.TERMLIST.VALUE"), $ListBuild("value field", "%%NAME," _ tName _ "X" _ $Char(10) _ "%%FIELDLIST,value" _ $Char(10) _ "k1,v1" _ $Char(10), "422 ANALYTICS.TERMLIST.FIELD") {
        Set tExtra = {"fileName": "shape.csv", "content": ($List(tCase, 2))}
        Do tExtra.%Set("digest", ..TextDigest($List(tCase, 2)))
        Do $$$AssertEquals(..T("IMPORT", "import", tExtra, .tRes, .tFault), $List(tCase, 3), $List(tCase, 1) _ " is refused")
        Do $$$AssertEquals(..T("IMPORTFILE", "import", tExtra, .tRead, .tFault, "IMPORT"), $List(tCase, 3), $List(tCase, 1) _ " is refused by the read composed for the import")
    }
    Set tOdd = "%%NAME," _ tName _ "X" _ $Char(10) _ "k1,v1" _ $Char(10) _ ",orphan" _ $Char(10) _ "k1,v2" _ $Char(10)
    Set tExtra = {"fileName": "odd.csv", "content": (tOdd)}
    Do tExtra.%Set("digest", ..TextDigest(tOdd))
    Do $$$AssertEquals(..T("IMPORTFILE", "import", tExtra, .tRead, .tFault, "IMPORT"), "200 ", "a file with a repeated key and a line with no key is read")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.FileEntries, 1, "the repeated key counts once and the keyless line is skipped")
    Set tLongKey = "%%NAME," _ tName _ "X" _ $Char(10) _ $Translate($Justify("", 256), " ", "k") _ ",v1" _ $Char(10)
    Do $$$AssertEquals(..T("IMPORT", "import", {"fileName": "key.csv", "content": (tLongKey), "digest": (..TextDigest(tLongKey))}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.KEY", "a key over 255 characters is refused")
    Set tBig = $Translate($Justify("", 3000001), " ", "x")
    Do $$$AssertEquals(..T("IMPORT", "import", {"fileName": "big.csv", "content": (tBig)}, .tRes, .tFault), "409 ANALYTICS.TERMLIST.TOOLARGE", "a local text past the bound is refused")
    Do $$$AssertEquals($Extract(..T("IMPORT", "import", {"fileName": "a/b.csv", "content": (tOdd)}, .tRes, .tFault), 1, 3), "400", "a local file name with a slash is refused")
    Set tNamed = "%%NAME,Other" _ $Char(10) _ "k1,v1" _ $Char(10)
    Do $$$AssertEquals(..T("IMPORT", tName, {"fileName": "n.csv", "content": (tNamed)}, .tRes, .tFault), "409 ANALYTICS.TERMLIST.IMPORTSHAPE", "a file that holds another list than the one named is refused")
    Do $$$AssertEquals(..T("COPY", tName, {"newName": ""}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.NAME", "a copy to an empty name is refused")
    Do $$$AssertEquals(..T("COPY", tName, {"newName": ($Justify("", 256))}, .tRes, .tFault), "422 ANALYTICS.TERMLIST.NAME", "and to a name over 255 characters")
    Do $$$AssertEquals(..T("COPY", tName _ "Gone", {"newName": (tName _ "Y")}, .tRes, .tFault), "404 ANALYTICS.TERMLIST.ABSENT", "and a source that is not held is refused")
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "and no vendor call was made")
}

/// <p>AC4: the server file is rewritten between the review and the write, so the write is refused <code>IMPORTCHANGED</code> and nothing is
/// created; a write that sends no reviewed digest is refused the same way.</p>
/// <p>Mutation (Rule 19): skip the digest comparison in <method>OcuPilot.Port.AnalyticsPort.PerformImport</method> -- the changed leg goes red.</p>
Method TestAFileChangedAfterItsReviewWritesNothing()
{
    Set tName = ..#MARKER _ "Changed"
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "c.csv", "%%NAME," _ tName _ $Char(10) _ "k1,v1" _ $Char(10)), "the file is written")
    Set tFile = ..FileQuery("c.csv")
    Do tFile.%Set("digest", ..DigestOf(tFile))
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "c.csv", "%%NAME," _ tName _ $Char(10) _ "k1,v1" _ $Char(10) _ "k2,v2" _ $Char(10)), "the file is rewritten")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "409 ANALYTICS.TERMLIST.IMPORTCHANGED", "the write is refused")
    Do tFile.%Remove("digest")
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "409 ANALYTICS.TERMLIST.IMPORTCHANGED", "and so is one that names no reviewed file")
    Do $$$AssertEquals(..Marked() _ "|" _ $ClassMethod(..#SEAM, "Calls"), "|0", "nothing was created and no vendor call was made")
}

/// <p>AC3: a copy is the source's header and every entry under the new name, with a stamp of its own; the source is unchanged.</p>
/// <p>Mutation (Rule 19): skip the field values in <method>OcuPilot.Port.AnalyticsPort.WriteWholeList</method> -- the copy leg goes red.</p>
Method TestACopyEqualsItsSourceExceptItsNameAndStamp()
{
    Set tName = ..#MARKER _ "Source"
    Do ..Arrange(tName)
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "UPDATE", tName, {"HideValue": true}, .tRes, .tFault)
    Set tSource = ..Dump(tName)
    Do $$$AssertEquals(..T("COPY", tName, {"newName": (tName _ "Copy")}, .tRes, .tFault), "200 ", "the copy answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tRes) Do $$$AssertEquals(tRes.Name _ "|" _ tRes.Namespace _ "|" _ tRes.HideValue, tName _ "Copy|USER|1", "its answer is the new list read again, its hide-value flag copied")
    Do $$$AssertEquals(..Dump(tName _ "Copy"), tSource, "the new list equals the source")
    Do $$$AssertEquals(..Dump(tName), tSource, "and the source is unchanged")
    Do $$$AssertEquals(..HideNode(tName _ "Copy"), 1, "the hide-value node is copied")
}

/// <p>AC5: the seam fails the third value write of an import and of a copy: no list is created, the write fails and no audit row is made.</p>
/// <p>Mutation (Rule 19): remove the <code>TROLLBACK</code> from <method>OcuPilot.Port.AnalyticsPort.WriteWholeList</method> -- both legs go red.</p>
Method TestAFailedValueWriteRollsAnImportAndACopyBack()
{
    Set tName = ..#MARKER _ "Fail"
    Do ..Arrange(tName)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Snapshot()
    Set tText = "%%NAME," _ tName _ "I" _ $Char(10) _ "k1,v1" _ $Char(10) _ "k2,v2" _ $Char(10) _ "k3,v3" _ $Char(10)
    Set tExtra = {"fileName": "fail.csv", "content": (tText)}
    Do tExtra.%Set("digest", ..TextDigest(tText))
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "failthird")
    Do $$$AssertEquals($Extract(..T("IMPORT", "import", tExtra, .tRes, .tFault), 1, 3), "500", "the import answers its failure")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "failthird")
    Do $$$AssertEquals($Extract(..T("COPY", tName, {"newName": (tName _ "C")}, .tRes, .tFault), 1, 3), "500", "so does the copy")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no list was created")
    Do $$$AssertEquals($TLevel, 0, "and no transaction is left open")
    Do $$$AssertEquals(..Rows(tSince, tName _ "C", "analytics.termlists.copy") + ..Rows(tSince, tName _ "I", "analytics.termlists.import"), 0, "and nothing was audited")
}

/// <p>AC4: a <code>root</code> that is not allowed and a <code>path</code> with <code>..</code> are refused by PathPort on their field, an export's
/// before the vendor call and an import's before the file is read; a directory that does not exist is refused.</p>
Method TestAPathThatIsNotAllowedIsRefusedOnItsField()
{
    Set tName = ..#MARKER _ "Path"
    Do ..Arrange(tName)
    Do $ClassMethod(..#SEAM, "Reset")
    Set tRoot = $ClassMethod(..#FILES, "Root")
    Do $$$AssertEquals($Extract(..T("EXPORT", tName, {"root": "/nowhere/", "path": "a.csv"}, .tRes, .tFault), 1, 9), "400 PATH.", "an export to a root that is not allowed is refused by PathPort")
    If $IsObject(tFault) && $IsObject(tFault.detail) && $IsObject(tFault.detail.violations) Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "root", "on the root")
    Do $$$AssertEquals($Extract(..T("EXPORT", tName, {"root": (tRoot), "path": "../a.csv"}, .tRes, .tFault), 1, 9), "400 PATH.", "an export to a path with .. is refused")
    If $IsObject(tFault) && $IsObject(tFault.detail) && $IsObject(tFault.detail.violations) Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "path", "on the path")
    Do $$$AssertEquals(..T("EXPORT", tName, {"root": (tRoot), "path": "NoSuchDirectory/a.csv"}, .tRes, .tFault), "409 EXPLORER.EXPORT.DIRECTORY", "an export into a directory that does not exist is refused")
    Do $$$AssertEquals($Extract(..T("IMPORT", "import", {"root": "/nowhere/", "path": "a.csv"}, .tRes, .tFault), 1, 9), "400 PATH.", "an import from a root that is not allowed is refused")
    Do $$$AssertEquals($Extract(..T("IMPORTFILE", "import", {"root": (tRoot), "path": "../a.csv"}, .tRes, .tFault), 1, 9), "400 PATH.", "and from a path with ..")
    Do $$$AssertEquals($Extract(..T("IMPORT", "import", {"root": (tRoot)}, .tRes, .tFault), 1, 4), "400 ", "a server file with no path is refused")
    Do $$$AssertEquals(..T("IMPORT", "import", {"root": (tRoot), "path": "a.csv", "fileName": "a.csv", "content": "x"}, .tRes, .tFault), "400 PORT.VALIDATION", "and both a server file and a local one")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "no vendor call was made")
}

/// <p>AC4: a database that is read-only or not journaled refuses an import and a copy before any vendor call, and does not refuse an export, which
/// reads only.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AnalyticsPort.AdmitTermList</method>'s journal check -- the not-journaled legs go red.</p>
Method TestTheDestinationRefusesAnImportAndACopyButNotAnExport()
{
    Set tName = ..#MARKER _ "Dest"
    Do ..Arrange(tName)
    Set tText = "%%NAME," _ tName _ "N" _ $Char(10) _ "k1,v1" _ $Char(10)
    Set tExtra = {"fileName": "d.csv", "content": (tText)}
    Do tExtra.%Set("digest", ..TextDigest(tText))
    Set tBefore = ..Snapshot()
    For tMode = "readonly", "nonjournaled" {
        Set tCode = $Select(tMode = "readonly": "409 ANALYTICS.TERMLIST.READONLY", 1: "409 ANALYTICS.TERMLIST.NOTJOURNALED")
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Arm", tMode)
        Do $$$AssertEquals(..T("IMPORT", "import", tExtra, .tRes, .tFault), tCode, tMode _ ": the import is refused")
        Do $$$AssertEquals(..T("IMPORTFILE", "import", tExtra, .tRes, .tFault, "IMPORT"), tCode, tMode _ ": and so is its read composed for the import")
        Do $$$AssertEquals(..T("COPY", tName, {"newName": (tName _ "N")}, .tRes, .tFault), tCode, tMode _ ": the copy is refused")
        Do $$$AssertEquals(..T("COPYTARGET", tName, {"newName": (tName _ "N")}, .tRes, .tFault, "COPY"), tCode, tMode _ ": and so is its read")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, tMode _ ": no vendor call was made")
        Do $$$AssertEquals(..T("EXPORT", tName, "", .tRes, .tFault), "200 ", tMode _ ": the export reads only and is not refused")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing was written")
}

/// <p>AC7: each transfer's script form, run in <code>USER</code>, makes the change the write makes: a copy and an import create the list, an export
/// writes the file, and a script whose name is taken or whose file is no export only sets the refusal. The scripts run one line at a time.</p>
/// <p>Mutation (Rule 19): drop the value write of a field in <method>OcuPilot.Port.AnalyticsPort.WholeListSnippet</method> -- the copy and import legs go red.</p>
Method TestEachTransfersScriptFormMakesTheSameChange()
{
    Set tName = ..#MARKER _ "Script"
    Do ..Arrange(tName)
    Set tSource = ..Dump(tName)
    Do $$$AssertEquals(##class(OcuPilot.Port.AnalyticsPort).SnippetForm("TermLists", "COPY"), "objectscript", "a copy has a script form")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tName
    Set tQuery("newName") = tName _ "Cp"
    Set tSteps = ##class(OcuPilot.Port.AnalyticsPort).Snippet("TermLists", "COPY", .tQuery)
    Do $$$AssertEquals(..RunScript(tSteps), 1, "the copy's script runs")
    Do $$$AssertEquals(..Dump(tName _ "Cp"), tSource, "and creates the list the copy creates")
    Do $$$AssertEquals(..RunScript(##class(OcuPilot.Port.AnalyticsPort).Snippet("TermLists", "COPY", .tQuery)), 0, "a second run is refused: the name is taken")
    Do $$$AssertTrue(..Dump(tName _ "Cp") = tSource, "and leaves the list as it was")
    Set tFile = ..FileQuery("script.csv")
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "DELETE", tName _ "Cp", {}, .tRes, .tFault)
    Do $$$AssertEquals(..T("EXPORT", tName, tFile, .tRes, .tFault), "200 ", "the list exports")
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "DELETE", tName, {}, .tRes, .tFault)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "import"
    Set tQuery("root") = tFile.root
    Set tQuery("path") = tFile.path
    Do $$$AssertEquals(..RunScript(##class(OcuPilot.Port.AnalyticsPort).Snippet("TermLists", "IMPORT", .tQuery)), 1, "the import's script runs")
    Do $$$AssertEquals(..Dump(tName), tSource, "and creates the list the file holds")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tName
    Set tQuery("root") = tFile.root
    Set tQuery("path") = $ClassMethod(..#FILES, "RelativeName", "out.csv")
    Set tSteps = ##class(OcuPilot.Port.AnalyticsPort).Snippet("TermLists", "EXPORT", .tQuery)
    Set tText = tSteps.%Get(0).text
    Do $$$AssertTrue(tText [ "%ExportCSV(", "the export's script is the vendor's call")
    Set tQuery("path") = ""
    Do $$$AssertTrue(##class(OcuPilot.Port.AnalyticsPort).Snippet("TermLists", "EXPORT", .tQuery).%Get(0).text [ (", " _ $Char(34, 34) _ ", 0)"), "and with no file it writes to the current device")
}

/// <p>Run the script steps <var>pSteps</var> in <code>USER</code>, one line at a time, rolling back a transaction a failed script left open; 1 when
/// the script's own <code>tSC</code> reads OK at the end. The script's variables are public, so they are read by indirection.</p>
ClassMethod RunScript(pSteps As %DynamicArray) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tLevel = $TLevel
    XECUTE "Kill tSC"
    Try {
        Set tText = pSteps.%Get(0).text
        For tAt = 1:1:$Length(tText, $Char(10)) {
            Set tLine = $Piece(tText, $Char(10), tAt)
            If tLine '= "" XECUTE tLine
        }
    } Catch {
    }
    While $TLevel > tLevel {
        TROLLBACK 1
    }
    Set $NAMESPACE = tOrigNS
    Quit ''$System.Status.IsOK($Get(@"tSC"))
}

/// <p>AC7: each transfer leaves one <code>ConfigChange</code> row of OcuPilot's own, naming its tool and the list, and never a value.</p>
/// <p>Mutation (Rule 19): drop the <code>AuditWrite</code> of <method>OcuPilot.Port.AnalyticsPort.PerformExport</method> -- the export leg goes red.</p>
Method TestEachTransferIsAudited()
{
    Set tName = ..#MARKER _ "Audit"
    Do ..Arrange(tName)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..T("EXPORT", tName, ..FileQuery("audit.csv"), .tRes, .tFault), "200 ", "the export runs")
    Do $$$AssertEquals(..T("COPY", tName, {"newName": (tName _ "C")}, .tRes, .tFault), "200 ", "the copy runs")
    Set tText = "%%NAME," _ tName _ "I" _ $Char(10) _ "k1,v1" _ $Char(10)
    Set tExtra = {"fileName": "a.csv", "content": (tText)}
    Do tExtra.%Set("digest", ..TextDigest(tText))
    Do $$$AssertEquals(..T("IMPORT", "import", tExtra, .tRes, .tFault), "200 ", "the import runs")
    Do $$$AssertEquals(..Rows(tSince, tName, "analytics.termlists.export"), 1, "one audit row names the export")
    Do $$$AssertEquals(..Rows(tSince, tName _ "C", "analytics.termlists.copy"), 1, "one audit row names the copy and its new list")
    Do $$$AssertEquals(..Rows(tSince, tName _ "I", "analytics.termlists.import"), 1, "one audit row names the import and the list it created")
}

/// <p>AC1, AC2, AC3, AC5: the person's Export (a server file and this browser), Import (a local file) and Copy term list are screen actions; each
/// answers the AD-14 action and leaves one audit row and no agent marker, the export carrying only the file or the lines and the import and copy a
/// created list. The vendor reads each result.</p>
/// <p>Mutation (Rule 19): send the export's output lines nowhere in <method>OcuPilot.Screen.Tool.AnalyticsTermListExport.WriteOutput</method> -- the
/// browser leg goes red.</p>
Method TestThePersonsExportImportAndCopy()
{
    Set tName = ..#MARKER _ "Person"
    Do ..Arrange(tName)
    Set tSource = ..Dump(tName)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tFile = ..FileQuery("person.csv")
    Do $$$AssertEquals(..Act("export", tName, tFile, .tAnswer), 200, "Export to a server file answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")), "the export answers an output")
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.output.root _ "|" _ tAnswer.output.path _ "|" _ tAnswer.output.%GetTypeOf("lines"), "updated|" _ tFile.root _ "|" _ tFile.path _ "|unassigned", "naming the file and nothing else")
    Do $$$AssertEquals(..Act("export-browser", tName, "", .tBrowser), 200, "Export to this browser answers 200")
    Do $$$AssertTrue($IsObject(tBrowser) && $IsObject(tBrowser.%Get("output")), "the browser export answers an output")
    If $IsObject(tBrowser) && $IsObject(tBrowser.%Get("output")) {
        Do $$$AssertEquals(tBrowser.output.lines.%ToJSON(), ..LinesOf($ClassMethod(..#FILES, "ReadFile", "person.csv")).%ToJSON(), "its output is the CSV lines, which are the file's")
    }
    Set tText = $ClassMethod(..#FILES, "ReadFile", "person.csv")
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "DELETE", tName, {}, .tRes, .tFault)
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "person.csv", "content": (tText)}, .tImport), 200, "Import of a local file answers 200: " _ $Select($IsObject(tImport): $Extract(tImport.%ToJSON(), 1, 300), 1: tImport))
    If $IsObject(tImport) Do $$$AssertEquals(tImport.action _ "|" _ tImport.target.id _ "|" _ tImport.readBack.verdict, "created|import|nothingSent", "created, on the import target the person named, with a read-back that finds the list")
    Do $$$AssertEquals(..Dump(tName), tSource, "the vendor reads the list as it was")
    Do $$$AssertEquals(..Act("copy", tName, {"NewName": (tName _ "Copy")}, .tCopy), 200, "Copy term list answers 200: " _ $Select($IsObject(tCopy): $Extract(tCopy.%ToJSON(), 1, 300), 1: tCopy))
    If $IsObject(tCopy) Do $$$AssertEquals(tCopy.action _ "|" _ tCopy.target.id, "created|" _ tName, "created, on the source the person named")
    Do $$$AssertEquals(..Dump(tName _ "Copy"), tSource, "the copy equals the source")
    Do $$$AssertEquals(..Act("copy", tName, {"NewName": (tName _ "Copy")}, .tTaken), 409, "a second copy to the same name is refused 409")
    Do $$$AssertEquals(..Act("import-local", "import", {"fileName": "person.csv", "content": (tText)}, .tAgain), 409, "and so is a second import")
    Do $$$AssertEquals(..Rows(tSince, tName, "analytics.termlists.export"), 2, "the two exports are audited")
    Do $$$AssertEquals(..Rows(tSince, tName, "analytics.termlists.import") + ..Rows(tSince, tName _ "Copy", "analytics.termlists.copy"), 2, "and the import and the copy, once each")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tName, .tMarker), 0, "and no agent marker is emitted for a person's action")
}

/// <p>AC1, AC2, AC3, AC6, AC7: the agent's export, import and copy proposals are minted and confirmed: each leaves one audit row, the agent marker and
/// one ledger row; the export's card names the replaced file; an import reads back from the file the export wrote; and the entries the import created
/// are answered by the Entries screen's read and by the agent's read tool.</p>
/// <p>Mutation (Rule 19): drop the field values of the entry rows of <method>OcuPilot.Port.AnalyticsPort.EntryRow</method> -- the integration leg goes red.</p>
Method TestTheAgentsThreeProposalsConfirmAndTheImportedEntriesRead()
{
    Set tName = ..#MARKER _ "Agent"
    Do ..Arrange(tName)
    Set tSource = ..Dump(tName)
    Set tFile = ..FileQuery("agent.csv")
    Do ..Mint(..#EXPORTTOOL, {"Name": (tName), "root": (tFile.root), "path": (tFile.path)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "EXPLORER.EXPORT.REPLACES|0", "the export's card names the file it replaces and is not destructive")
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the export confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")), "the confirmed export answers an output")
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")) Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.output.path, "1|" _ tFile.path, "marked, and the answer names the file")
    Do $$$AssertEquals(..Rows(tSince, tName, "analytics.termlists.export"), 1, "one audit row names the export")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tProposal.proposalId, .tMarker, "analytics.termlists.export"), 1, "the agent marker carries the proposal id")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "analytics.termlists.export"), 1, "one ledger row")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $ClassMethod(..#EDIT, "Call", "TermLists", "DELETE", tName, {}, .tRes, .tFault)

    Do ..Mint(..#IMPORTTOOL, {"Name": (tName), "root": (tFile.root), "path": (tFile.path)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the import confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.createdId, "1|created|" _ tName, "marked, created, naming the list")
    Do $$$AssertEquals(..Dump(tName), tSource, "the vendor reads the list as the export wrote it")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tProposal.proposalId, .tMarker, "analytics.termlists.import"), 1, "the agent marker carries the import's proposal id")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "analytics.termlists.import"), 1, "one ledger row")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.termlistentries/read?termlist=" _ tName, "", .tHttp, .tRead)
    Do $$$AssertEquals(tHttp, 200, "the Entries screen reads the imported list")
    If $IsObject(tRead) && $IsObject(tRead.%Get("rows")) Do $$$AssertEquals(tRead.rows.%Get(0).Key _ "|" _ tRead.rows.%Get(0).Fields, "a,b|Region: West; Note: n1", "its first row carries the fields joined")
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.termlistentries.read", {"termlist": (tName)}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Do $$$AssertEquals(tLeg.%Get("http"), 200, "and the agent's read tool answers")
    If $IsObject(tLeg.%Get("rows")) Do $$$AssertEquals(tLeg.rows.%Get(0).Key _ "|" _ tLeg.rows.%Get(0).Fields, "a,b|Region: West; Note: n1", "with the same row")

    Do ..Mint(..#COPYTOOL, {"Name": (tName), "NewName": (tName _ "Copy")}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the copy confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.createdId, "1|created|" _ tName _ "Copy", "marked, created, naming the new list")
    Do $$$AssertEquals(..Dump(tName _ "Copy"), tSource, "the copy equals the source")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "analytics.termlists.copy"), 1, "one ledger row")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>The mint of <var>pTool</var> with <var>pArgs</var> is refused with no proposal, and, when <var>pCode</var> is not empty, with a fault whose
/// code starts with it.</p>
Method MintRefused(pTool As %String, pArgs As %DynamicObject, pCode As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusNotOK(tSC, $Parameter(pTool, "TOOLNAME") _ " is refused at the mint")
    Do $$$AssertTrue(('$IsObject($Get(tProposal))) && (+$Get(tHttp) >= 400), "with no proposal and a refusal status: " _ $Get(tHttp))
    If pCode '= "" Do $$$AssertTrue($IsObject($Get(tFault)) && ($Extract(tFault.%Get("code"), 1, $Length(pCode)) = pCode), "naming " _ pCode _ ": " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>AC4: the agent's mint refuses a taken name, a file that is not allowed and a file that holds another list, each before anything is stored, and
/// a confirm of an import whose file changed after the mint is refused as moved; nothing is written.</p>
Method TestTheAgentsMintRefusesWhatTheWriteWouldRefuse()
{
    Set tName = ..#MARKER _ "Refuse"
    Do ..Arrange(tName)
    Set tFile = ..FileQuery("refuse.csv")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "refuse.csv", "%%NAME," _ tName _ $Char(10) _ "k1,v1" _ $Char(10)), "the file is written")
    Set tBefore = ..Snapshot()
    Do ..MintRefused(..#IMPORTTOOL, {"Name": (tName), "root": (tFile.root), "path": (tFile.path)}, "ANALYTICS.TERMLIST.TAKEN")
    Do ..MintRefused(..#IMPORTTOOL, {"Name": "Other", "root": (tFile.root), "path": (tFile.path)}, "ANALYTICS.TERMLIST.IMPORTSHAPE")
    Do ..MintRefused(..#IMPORTTOOL, {"Name": (tName), "root": "/nowhere/", "path": "a.csv"}, "PATH.")
    Do ..MintRefused(..#EXPORTTOOL, {"Name": (tName), "root": "/nowhere/", "path": "a.csv"}, "PATH.")
    Do ..MintRefused(..#EXPORTTOOL, {"Name": (tName _ "Gone"), "root": (tFile.root), "path": (tFile.path)}, "")
    Do ..MintRefused(..#COPYTOOL, {"Name": (tName), "NewName": (tName)}, "ANALYTICS.TERMLIST.TAKEN")
    Do ..MintRefused(..#COPYTOOL, {"Name": (tName), "NewName": ""}, "ANALYTICS.TERMLIST.NAME")
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Set tFile2 = ..FileQuery("moved.csv")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "moved.csv", "%%NAME," _ tName _ "M" _ $Char(10) _ "k1,v1" _ $Char(10)), "a second file is written")
    Do ..Mint(..#IMPORTTOOL, {"Name": (tName _ "M"), "root": (tFile2.root), "path": (tFile2.path)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "moved.csv", "%%NAME," _ tName _ "M" _ $Char(10) _ "k1,v1" _ $Char(10) _ "k2,v2" _ $Char(10)), "the file is rewritten after the mint")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertTrue(tStatus >= 400, "the confirm is refused: " _ tStatus _ " " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..Dump(tName _ "M"), "", "and nothing was imported")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
