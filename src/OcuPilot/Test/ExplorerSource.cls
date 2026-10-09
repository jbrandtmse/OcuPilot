/// <p>Pins the agent's source reads, <code>explorer.class.source</code> and <code>explorer.routine.source</code>
/// (Story 20.19, AD-36, AD-60, AD-61), in process as the suite account: a class and a routine read whole;
/// a class whose text escapes past 60,000 characters is cut at whole lines; a first line that alone does
/// is cut at a character; the cut counts escaped characters, line feeds included; an object-only routine,
/// an absent class and a badly named document are refused; empty arguments are refused; a denied viewer
/// pair is refused naming the screen; and both reads are advertised on their viewers, which list them in
/// their context <code>tools</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the suite account reading
/// <code>USER</code>'s code, and the Atelier fixture free for the fake-route legs. It creates the probe
/// documents of package <code>OcuProbe193</code> in <code>USER</code> and removes them before and after
/// each method. The fake-route legs read through <class>OcuPilot.Test.ExplorerClassSourceOnFixture</class>
/// and <class>OcuPilot.Test.ExplorerRoutineSourceOnFixture</class> in the test's own namespace, answered by
/// <class>OcuPilot.Test.AtelierPortFixture</class>, which is cleared after each method.</p>
Class OcuPilot.Test.ExplorerSource Extends %UnitTest.TestCase
{

Parameter NAMESPACE = "USER";

Parameter PROBEPACKAGE = "OcuProbe193";

Parameter CLASSTOOL = "OcuPilot.Screen.Tool.ExplorerClassSource";

Parameter ROUTINETOOL = "OcuPilot.Screen.Tool.ExplorerRoutineSource";

Parameter PROBE = "OcuPilot.Test.ExplorerSaveProbe";

Parameter FAKE = "OcuPilot.Test.AtelierPortFixture";

Parameter LIMIT = 60000;

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FAKE, "Clear")
    Quit $ClassMethod(..#PROBE, "Remove", ..#NAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FAKE, "Clear")
    Do $ClassMethod(..#PROBE, "Remove", ..#NAMESPACE)
    Do $ClassMethod("OcuPilot.Test.ToolDispatchProbe", "Reset")
    Quit $$$OK
}

/// <p>One call of the source read <var>pTool</var> on <var>pName</var> in <var>pNamespace</var>: the
/// status, the answer and, for a refusal, the wire fault and its HTTP status.</p>
ClassMethod Fetch(pTool As %String, pName As %String, pNamespace As %String = {..#NAMESPACE}, Output pResult As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tArgs = {}
    Do tArgs.%Set("name", pName, "string")
    Set tSC = $ClassMethod(pTool, "View", "", tArgs, 0, .pResult, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit tSC
}

/// <p>The JSON string length of <var>pText</var>, quotes excluded: the measure the source read's cut
/// uses, computed here by serializing the text as a pushed string.</p>
ClassMethod Escaped(pText As %String) As %Integer
{
    Set tOne = []
    Do tOne.%Push(pText, "string")
    Quit $Length(tOne.%ToJSON()) - 4
}

/// <p>An index answer and a document answer for one document <var>pName</var> whose text is
/// <var>pLines</var>, armed on the fake routes. <var>pObjectOnly</var> 1 arms the document answer as
/// the instance gives an object-only routine: 404 with no status and no timestamp.</p>
ClassMethod ArmDocument(pName As %String, pLines As %DynamicArray, pObjectOnly As %Boolean = 0)
{
    Set tEntry = {"name": "", "db": "USER", "ts": "2026-10-08 10:00:00", "upd": false, "cat": "CLS", "gen": false, "others": [], "status": "", "content": {}}
    Do tEntry.%Set("name", pName, "string")
    Set tIndex = {"status": {"errors": [], "summary": ""}, "console": [], "result": {"content": []}}
    Do tIndex.%Get("result").%Get("content").%Push(tEntry)
    Do ##class(OcuPilot.Test.AtelierPortFixture).UseFakeRoutes()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(8)
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetResources("%DB_USER", "%DB_USER", "")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Index", "200 OK", tIndex.%ToJSON())
    If pObjectOnly {
        Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "404 Not Found", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""" _ pName _ """,""db"":""USER"",""ts"":"""",""upd"":false,""cat"":""RTN"",""status"":"""",""enc"":false,""flags"":0,""content"":[]}}")
        Quit
    }
    Set tDocument = {"status": {"errors": [], "summary": ""}, "console": [], "result": {"name": "", "db": "USER", "ts": "2026-10-08 10:00:00", "upd": false, "cat": "CLS", "status": "", "enc": false, "flags": 0, "content": []}}
    Do tDocument.%Get("result").%Set("name", pName, "string")
    Do tDocument.%Get("result").%Set("content", pLines)
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "200 OK", tDocument.%ToJSON())
}

Method TestAClassReadsWhole()
{
    Set tName = ..#PROBEPACKAGE _ ".Alpha.cls"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#NAMESPACE, ..#PROBEPACKAGE _ ".Alpha"), "the probe class is made")
    Set tSC = ..Fetch(..#CLASSTOOL, tName, ..#NAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the class source read runs")
    If $$$ISERR(tSC) Quit
    Set tSource = $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tName)
    Do $$$AssertTrue(tSource '= "", "the probe class has text")
    Do $$$AssertEquals(tHttp, 200, "the read answers 200")
    Do $$$AssertEquals(tResult.%Get("text"), tSource, "the text equals the document's text, whole")
    Do $$$AssertEquals(tResult.%Get("truncated"), 0, "and is not truncated")
    Do $$$AssertEquals(tResult.%Get("linesSent"), tResult.%Get("lines"), "every line is sent")
    Do $$$AssertEquals(tResult.%Get("name") _ " " _ tResult.%Get("namespace"), tName _ " " _ ..#NAMESPACE, "the answer names the document and its namespace")
}

/// <p>Pins AC3's routine leg.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerRoutineSource.Endpoint</method> answering
/// the class endpoint -- this goes red.</p>
Method TestARoutineReadsWhole()
{
    Set tName = ..#PROBEPACKAGE _ "Mac.mac"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#NAMESPACE, tName), "the probe routine is made")
    Set tSC = ..Fetch(..#ROUTINETOOL, tName, ..#NAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the routine source read runs")
    If $$$ISERR(tSC) Quit
    Set tSource = $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tName)
    Do $$$AssertTrue(tSource '= "", "the probe routine has text")
    Do $$$AssertEquals(tResult.%Get("text"), tSource, "the routine's text is returned whole")
    Do $$$AssertEquals(tResult.%Get("truncated"), 0, "and is not truncated")
}

Method TestALongClassIsCutAtWholeLines()
{
    Set tName = ..#PROBEPACKAGE _ ".Long.cls"
    Set tClass = ..#PROBEPACKAGE _ ".Long"
    Set tBody = ""
    For tI = 1:1:2000 {
        Set tBody = tBody _ "/// row " _ tI _ " says ""quoted"" and a back\slash, padding for the cut" _ $Char(13, 10)
    }
    Set tText = "Class " _ tClass _ " Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ tBody _ "}" _ $Char(13, 10)
    Do $$$AssertStatusOK(##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tName, tText), "the long probe class is made")
    Set tSC = ..Fetch(..#CLASSTOOL, tName, ..#NAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the long class reads")
    If $$$ISERR(tSC) Quit
    Set tSent = tResult.%Get("linesSent")
    Set tTotal = tResult.%Get("lines")
    Set tCut = tResult.%Get("text")
    Do $$$AssertEquals(tResult.%Get("truncated"), 1, "the cut is reported")
    Do $$$AssertTrue(tSent < tTotal, "fewer lines than the document holds are sent: " _ tSent _ " of " _ tTotal)
    Do $$$AssertTrue(..Escaped(tCut) <= ..#LIMIT, "the text escapes to at most 60,000 characters: " _ ..Escaped(tCut))
    Do $$$AssertEquals($Length(tCut, $Char(10)), tSent, "the text is exactly the lines it reports")
    Set tSource = $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tName)
    Do $$$AssertEquals(tCut, $Piece(tSource, $Char(10), 1, tSent), "the text is the document's first lines, verbatim")
    Set tNext = $Piece(tSource, $Char(10), tSent + 1)
    Do $$$AssertTrue(..Escaped(tCut _ $Char(10) _ tNext) > ..#LIMIT, "the next line would not have fit")
}

Method TestAWideFirstLineIsCutAtACharacter()
{
    Set tWide = $TR($Justify("", 70000), " ", """")
    Set tLines = []
    Do tLines.%Push(tWide, "string")
    Do tLines.%Push("}", "string")
    Do ..ArmDocument("OcuProbe193.Wide.cls", tLines)
    Set tSC = ..Fetch("OcuPilot.Test.ExplorerClassSourceOnFixture", "OcuProbe193.Wide.cls", $Namespace, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the wide first line reads")
    If $$$ISERR(tSC) Quit
    Set tCut = tResult.%Get("text")
    Do $$$AssertEquals(tResult.%Get("truncated"), 1, "the cut is reported")
    Do $$$AssertEquals(tResult.%Get("linesSent"), 1, "the first line is the one line sent")
    Do $$$AssertTrue(..Escaped(tCut) <= ..#LIMIT, "the cut first line escapes to at most 60,000 characters")
    Do $$$AssertTrue($Length(tCut) > 0, "the cut keeps a prefix, not nothing")
    Do $$$AssertEquals(tCut, $Extract(tWide, 1, $Length(tCut)), "the text is a prefix of the first line")
    Do $$$AssertTrue(..Escaped($Extract(tWide, 1, $Length(tCut) + 1)) > ..#LIMIT, "one more character would not have fit")
}

Method TestCutCountsEscapedCharactersAndLineFeeds()
{
    Set tLines = []
    Do tLines.%Push("a""b", "string")
    Do tLines.%Push("c", "string")
    Set tText = ##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Cut(tLines, 6, .tSent, .tTruncated)
    Do $$$AssertEquals(tText _ "|" _ tSent _ "|" _ tTruncated, "a""b|1|1", "a quote escapes to two characters and the next line, with its line feed, does not fit 6")
    Set tText = ##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Cut(tLines, 7, .tSent, .tTruncated)
    Do $$$AssertEquals(tText _ "|" _ tSent _ "|" _ tTruncated, "a""b" _ $Char(10) _ "c|2|0", "the same two lines fit 7 exactly")
}

Method TestAnObjectOnlyRoutineAnswersNotFound()
{
    Set tName = "OcuProbe193Obj.mac"
    Do ..ArmDocument(tName, [], 1)
    Set tSC = ..Fetch("OcuPilot.Test.ExplorerRoutineSourceOnFixture", tName, $Namespace, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "an object-only routine answers 404")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "PORT.NOTFOUND", "as PORT.NOTFOUND")
    Do $$$AssertStatusNotOK(tSC, "and the read is an error")
}

Method TestAnAbsentClassAndABadNameAreRefused()
{
    Set tSC = ..Fetch(..#CLASSTOOL, ..#PROBEPACKAGE _ ".Absent.cls", ..#NAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an absent class reads as an error")
    Do $$$AssertEquals(tHttp, 404, "an absent class answers 404")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "PORT.NOTFOUND", "as PORT.NOTFOUND")
    Set tSC = ..Fetch(..#CLASSTOOL, "Bad", ..#NAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a name that is not a class name answers 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "PORT.VALIDATION", "as PORT.VALIDATION")
}

Method TestEmptyArgumentsAreRefused()
{
    Set tSC = $ClassMethod(..#CLASSTOOL, "View", "", {}, 0, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an empty argument object is refused")
    Do $$$AssertEquals(tHttp, 400, "with 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "TOOL.ARGUMENTS", "as TOOL.ARGUMENTS")
}

/// <p>Pins AC4: with <code>%Development:USE</code> denied at dispatch's pair seam, a model's call is
/// refused <code>AUTH.NOPRIVILEGE</code> naming the pair and the screen <code>explorer.class</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.PrivilegePairs</method>
/// answering <code>""</code> -- this goes red.</p>
Method TestADeniedViewerPairIsRefusedNamingTheScreen()
{
    Do $ClassMethod("OcuPilot.Test.ToolDispatchProbe", "Reset")
    Do $ClassMethod("OcuPilot.Test.ToolDispatchProbe", "SetRegistryClass", "OcuPilot.Screen.Tool.Registry")
    Do $ClassMethod("OcuPilot.Test.ToolDispatchProbe", "DenyPair", "%Development", "USE")
    Set tUse = {"type": "tool_use", "id": "toolu_source_denied", "input": {"name": "OcuProbe193.Alpha.cls"}}
    Do tUse.%Set("name", "explorer_class_source", "string")
    Set tSC = $ClassMethod("OcuPilot.Test.ToolDispatchProbe", "Answer", "refusal", $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do $ClassMethod("OcuPilot.Test.ToolDispatchProbe", "Reset")
    Set tDetail = tDetails.%Get(0)
    Do $$$AssertEquals(tResults.%Get(0).%Get("content") _ "|" _ tDetail.failedPair _ "|" _ tDetail.failedScreen, "{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Development:USE"",""screen"":""explorer.class""}}|%Development:USE|explorer.class", "the pair and the viewer are named")
}

/// <p>Pins AC1: each source read is listed, with its viewer's pairs, bound to its viewer's descriptor and
/// advertised; the viewers' context <code>tools</code> list their read and their source read, and the
/// editors' stay empty.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerClassSource</class> declaring
/// <parameter>ADVERTISED</parameter> 0 -- this goes red.</p>
Method TestBothSourceReadsAreAdvertisedOnTheirViewers()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists")
    If $$$ISERR(tSC) Quit
    Kill tByName
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tByName(tTool.name) = tTool
    }
    Do $$$AssertTrue($Data(tByName("explorer.class.source")) && $Data(tByName("explorer.routine.source")), "both source reads are listed")
    Do $$$AssertEquals(tByName("explorer.class.source").class, ..#CLASSTOOL, "the class read is answered by its own class")
    Do $$$AssertEquals(tByName("explorer.routine.source").class, ..#ROUTINETOOL, "the routine read is answered by its own class")
    For tName = "explorer.class.source", "explorer.routine.source" {
        Do $$$AssertEquals(tByName(tName).kind, "read", tName _ " is a read")
        Do $$$AssertEquals(tByName(tName).descriptor, "", tName _ " is derived from no descriptor")
        Do $$$AssertTrue(##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tByName(tName)), tName _ " is advertised")
        Set tViewer = $Parameter(tByName(tName).class, "DESCRIPTORCLASS")
        Set tExpected = ##class(OcuPilot.Screen.Gate).RequiredPairs(tViewer, .tResolved)
        Set tRequired = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tByName(tName), .tRequiredResolved)
        Do $$$AssertEquals($ListToString(tRequired, "|"), $ListToString(tExpected, "|"), tName _ " requires exactly its viewer's pairs")
    }
    Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools("OcuPilot.Screen.Descriptor.ExplorerClassDocument", .tClassTools, .tClassList)
    Do $$$AssertStatusOK(tSC, "the class viewer's tools build")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tClassTools.%ToJSON(), "[""explorer_class_read"",""explorer_class_source""]", "the class viewer's context lists its read and its source read")
    Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools("OcuPilot.Screen.Descriptor.ExplorerRoutineDocument", .tRoutineTools, .tRoutineList)
    Do $$$AssertStatusOK(tSC, "the routine viewer's tools build")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRoutineTools.%ToJSON(), "[""explorer_routine_read"",""explorer_routine_source""]", "the routine viewer's context lists its read and its source read")
    For tEditor = "ExplorerClassEditor", "ExplorerRoutineEditor" {
        Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools("OcuPilot.Screen.Descriptor." _ tEditor, .tEditorTools, .tEditorList)
        Do $$$AssertStatusOK(tSC, tEditor _ "'s tools build")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(tEditorTools.%ToJSON(), "[]", tEditor _ "'s context tools stay empty")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tProvider)
    Do $$$AssertStatusOK(tSC, "the provider tool list builds")
    If $$$ISERR(tSC) Quit
    Set tWire = ""
    Set tFoundClass = 0
    Set tFoundRoutine = 0
    For {
        Set tWire = $Order(tProvider(tWire))
        Quit:tWire=""
        Set tFoundClass = tFoundClass || (tProvider(tWire, "name") = "explorer_class_source")
        Set tFoundRoutine = tFoundRoutine || (tProvider(tWire, "name") = "explorer_routine_source")
    }
    Do $$$AssertTrue(tFoundClass, "the provider tool list carries explorer_class_source")
    Do $$$AssertTrue(tFoundRoutine, "and explorer_routine_source")
    For tName = "explorer.class.source", "explorer.routine.source" {
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ResolveWire($Translate(tName, ".", "_"), .tResolved)
        Do $$$AssertStatusOK(tSC, "the dispatch lookup resolves " _ tName _ "'s wire name")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(tResolved.name, tName, "to the canonical name")
    }
}

}
