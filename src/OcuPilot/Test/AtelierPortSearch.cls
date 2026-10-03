/// <p>Pins the source code API port's search (AD-61 rules 2 and 7, AD-36): live, the rows a search of
/// <class>OcuPilot.Test.ExplorerFindProbe</class>'s documents answers -- their shapes, case, scope, a
/// pattern's metacharacters read as text, and the row cap with the read reporting the cut; through
/// <class>OcuPilot.Test.AtelierPortFixture</class>'s canned route, exactly the parameters sent, the
/// answer flattened and cut, every malformed argument refused before any route, and an instance too
/// old for the search route refused.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in the install namespace and a
/// <code>USER</code> namespace, where the live legs create the probe documents and remove them after
/// each test, failing if any is left.</p>
Class OcuPilot.Test.AtelierPortSearch Extends %UnitTest.TestCase
{

/// <p>The namespace the probe documents are created in.</p>
Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerFindProbe";

/// <p>A search answer as the route builds it: a class's description, member and parameter matches
/// and a routine's line carried as text.</p>
Parameter SEARCHANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":[{""doc"":""Probe.Alpha.cls"",""matches"":[{""attr"":""Description"",""attrline"":1,""text"":""a description""},{""member"":""Run"",""line"":12,""text"":""a line""},{""member"":""Marked"",""text"":""a parameter""}]},{""doc"":""Probe.Beta.mac"",""matches"":[{""line"":""175"",""text"":""a routine line""}]}]}";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>Create the probe documents, asserting they are made.</p>
Method MakeProbes() As %Boolean
{
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#PROBENAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe documents are created in " _ ..#PROBENAMESPACE)
    Quit $$$ISOK(tSC)
}

/// <p>The live port's search of <var>pText</var> in the probe namespace, its rows as
/// <code>Document|Member|Line|Attribute|Text</code> joined by <code>;</code>, or the fault's code;
/// <var>pCount</var> is how many rows it answered. <var>pScope</var> and <var>pCase</var> are sent
/// where they are not empty.</p>
ClassMethod Search(pText As %String, pScope As %String = "", pCase As %String = "", Output pHttp As %Integer, Output pCount As %Integer) As %String
{
    Set pCount = 0
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("text") = pText
    If pScope '= "" Set tQuery("scope") = pScope
    If pCase '= "" Set tQuery("case") = pCase
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Search", "LIST", .tQuery, "", .tRows, .pHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select($IsObject(tFault): tFault.code, 1: "?")
    Set pCount = tRows.%Size()
    Quit ..RowsText(tRows)
}

/// <p><var>pRows</var> as <code>Document|Member|Line|Attribute|Text</code> joined by
/// <code>;</code>, a <code>null</code> line spelled <code>null</code>.</p>
ClassMethod RowsText(pRows As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tLine = $Select(tRow.%GetTypeOf("Line") = "null": "null", 1: tRow.%Get("Line"))
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.%Get("Document") _ "|" _ tRow.%Get("Member") _ "|" _ tLine _ "|" _ tRow.%Get("Attribute") _ "|" _ tRow.%Get("Text")
    }
    Quit tText
}

/// <p>AC1: a search of the needle across classes and routines answers one row per match in the
/// instance's order, each carrying its document, member, line and attribute as the instance
/// answers them: a description by its attribute and line, a method's line by its member and line, a
/// parameter by its member alone, and a routine's line by its line; and a lower-case line, since the
/// search opens without matching case.</p>
/// <p>Mutation (Rule 19): drop <code>Member</code> from <method>OcuPilot.Port.AtelierPort.SearchRows</method>'s
/// row -&gt; this goes red.</p>
Method TestSearchRowsCarryTheInstancesShapes()
{
    If '..MakeProbes() Quit
    Set tNeedle = $Parameter(..#PROBE, "NEEDLE")
    Set tRows = ..Search(tNeedle, "", "", .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the search answers")
    Do $$$AssertEquals(tRows, "OcuProbe194.Parent.cls||1|Description|" _ tNeedle _ " in a description;OcuProbe194.Parent.cls|Probe|1||; " _ tNeedle _ " in a method;OcuProbe194.Parent.cls|Marked|null||" _ tNeedle _ " in a parameter;OcuProbe194Mac.mac||3||; " _ tNeedle _ " in a routine;OcuProbe194Mac.mac||4||; " _ $ZConvert(tNeedle, "L") _ " in lower case", "one row per match, in the instance's order and shapes")
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("text") = tNeedle
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Search", "LIST", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && (tAnswer.%Size() > 0): tAnswer.%Get(0).%ToJSON(), 1: ""), "{""Order"":1,""Document"":""OcuProbe194.Parent.cls"",""Member"":"""",""Line"":1,""Attribute"":""Description"",""Text"":""" _ tNeedle _ " in a description""}", "a row is exactly Order, Document, Member, Line, Attribute and Text")
}

/// <p>Matrix: matching case drops the lower-case line; a scope of classes or routines searches those
/// documents alone.</p>
Method TestCaseAndScopeNarrowTheSearch()
{
    If '..MakeProbes() Quit
    Set tNeedle = $Parameter(..#PROBE, "NEEDLE")
    Set tRows = ..Search(tNeedle, "", "yes", .tHttp, .tCount)
    Do $$$AssertEquals(tCount _ " " _ (tRows [ $ZConvert(tNeedle, "L")), "4 0", "matching case keeps the four lines in its case and drops the lower-case one")
    Set tRows = ..Search(tNeedle, "classes", "", .tHttp, .tCount)
    Do $$$AssertEquals(tCount _ " " _ (tRows [ ".mac|"), "3 0", "classes searches the classes alone")
    Set tRows = ..Search(tNeedle, "routines", "", .tHttp, .tCount)
    Do $$$AssertEquals(tCount _ " " _ (tRows [ ".cls|"), "2 0", "routines searches the routines alone")
}

/// <p>AC3: the text is searched as plain text, so a pattern's metacharacters match only themselves:
/// a needle with a dot for one of its letters, between <code>.*</code> and <code>.*</code>, finds
/// nothing, where the vendor's pattern search would match each probe line.</p>
/// <p>Mutation (Rule 19): send <code>regex</code> as 1 in
/// <method>OcuPilot.Port.AtelierPort.SearchRows</method> -&gt; the dot matches and this goes red.</p>
Method TestAMetacharacterIsText()
{
    If '..MakeProbes() Quit
    Set tNeedle = $Parameter(..#PROBE, "NEEDLE")
    Set tRows = ..Search(".*" _ $Replace(tNeedle, "Pr", "P.") _ ".*", "", "", .tHttp)
    Do $$$AssertEquals(tHttp _ " [" _ tRows _ "]", "200 []", "a needle carrying metacharacters finds nothing")
}

/// <p>AC2: through the read executor at a cap of two, three class matches read as exactly two rows
/// with the cut reported, because the instance was asked for three.</p>
/// <p>Mutation (Rule 19): send <code>max</code> as the row cap less one in
/// <method>OcuPilot.Port.AtelierPort.SearchRows</method> -&gt; the read reports no cut and this goes
/// red.</p>
Method TestTheCapIsReportedThroughTheRead()
{
    If '..MakeProbes() Quit
    Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
    Kill tCriteria
    Set tCriteria("text") = $Parameter(..#PROBE, "NEEDLE")
    Set tCriteria("scope") = "classes"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.ExplorerSearch", 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the search reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.rows.%Size() _ " " _ tResult.truncated, "2 1", "exactly the cap in rows, and the cut reported")
    Do $$$AssertEquals(tResult.criteria.%ToJSON(), "{""text"":""" _ $Parameter(..#PROBE, "NEEDLE") _ """,""scope"":""classes"",""case"":""no""}", "with the criteria it applied")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.ExplorerSearch", 3, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tResult.rows.%Size() _ " " _ tResult.truncated, "3 0", "and at a cap of three, all three uncut")
}

/// <p>AC3: the route is sent exactly the text as <code>query</code>, the scope's declared documents,
/// <code>regex=0</code>, the case, <code>sys=0</code>, <code>gen=0</code> and the row cap as
/// <code>max</code> -- no <code>word</code>, no <code>wild</code>, and none of the text in
/// <code>documents</code> -- and its answer is flattened in order, a routine's text line read as a
/// number, and cut at the cap.</p>
/// <p>Mutation (Rule 19): build <code>documents</code> from the text in
/// <method>OcuPilot.Port.AtelierPort.SearchRows</method> -&gt; the parameters assertion goes red.</p>
Method TestTheSearchSendsExactlyItsParameters()
{
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Search", "200 OK", ..#SEARCHANSWER)
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("text") = "a.b[1=0]*"
    Set tQuery("scope") = "routines"
    Set tQuery("case") = "yes"
    Set tQuery("maxRows") = 7
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Search", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the search answers")
    Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount() _ " " _ tCall.method _ " " _ tCall.arg _ " " _ tCall.params.%ToJSON(), "1 Search  {""case"":1,""documents"":""*.mac,*.int,*.inc,*.bas,*.mvi,*.mvb"",""gen"":0,""max"":7,""query"":""a.b[1=0]*"",""regex"":0,""sys"":0}", "one call, sent exactly the declared parameters")
    Do $$$AssertEquals(tCall.body _ "|" _ tCall.contentType, "|", "and no body")
    Do $$$AssertEquals(..RowsText(tRows), "Probe.Alpha.cls||1|Description|a description;Probe.Alpha.cls|Run|12||a line;Probe.Alpha.cls|Marked|null||a parameter;Probe.Beta.mac||175||a routine line", "the answer flattened in order")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Search", "200 OK", ..#SEARCHANSWER)
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("text") = "needle"
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Search", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
    Do $$$AssertEquals(tCall.params.%ToJSON(), "{""case"":0,""documents"":""*.cls,*.mac,*.int,*.inc,*.bas,*.mvi,*.mvb"",""gen"":0,""max"":200,""query"":""needle"",""regex"":0,""sys"":0}", "an omitted scope, case and cap send all documents, no case and 200")

    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Search", "200 OK", ..#SEARCHANSWER)
    Set tQuery("maxRows") = 2
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Search", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tRows.%Size() _ " " _ tRows.%Get(1).Order, "2 2", "an answer above the cap is cut at it")
}

/// <p>Matrix: an empty text, one above 256 characters or holding a control character, and a scope
/// or case outside its options, are each refused 400 <code>PORT.VALIDATION</code> with its own
/// reason before any route; a text of exactly 256 characters is searched.</p>
Method TestMalformedSearchArgumentsAreRefusedBeforeAnyRoute()
{
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    Set tPort = "OcuPilot.Port.AtelierPort"
    For tCase = $ListBuild("text", "", $Parameter(tPort, "REASONSEARCHTEXT")), $ListBuild("text", $Translate($Justify("", 257), " ", "a"), $Parameter(tPort, "REASONSEARCHTEXT")), $ListBuild("text", "a" _ $Char(9) _ "b", $Parameter(tPort, "REASONSEARCHTEXT")), $ListBuild("scope", "files", $Parameter(tPort, "REASONSEARCHSCOPE")), $ListBuild("case", "maybe", $Parameter(tPort, "REASONSEARCHCASE")) {
        Kill tQuery
        Set tQuery("namespace") = $Namespace
        Set tQuery("text") = "needle"
        Set tQuery($List(tCase, 1)) = $List(tCase, 2)
        Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Search", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "400 PORT.VALIDATION " _ $List(tCase, 3), $List(tCase, 1) _ " " _ $Extract($List(tCase, 2), 1, 20) _ " is refused with its reason")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Search", "200 OK", ..#SEARCHANSWER)
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("text") = $Translate($Justify("", 256), " ", "a")
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Search", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "200 1", "a text of 256 characters, the bound, is searched")
}

/// <p>AD-61 rule 2: an instance whose highest version is 1 is refused the search 501 naming both
/// versions before any route.</p>
Method TestTheVersionSeamRefusesTheSearch()
{
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(1)
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("text") = "needle"
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Search", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tWanted = $Replace($Replace(##class(OcuPilot.Port.AtelierPort).#REASONVERSION, "{highest}", 1), "{needed}", 2)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "501 PORT.NOTIMPLEMENTED " _ tWanted, "the search on a version 1 instance is refused naming both versions")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
}

}
