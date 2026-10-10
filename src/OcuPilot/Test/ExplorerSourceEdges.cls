/// <p>Pins the edges of the agent's source reads, <code>explorer.class.source</code> and
/// <code>explorer.routine.source</code> (Story 20.19, AD-36, AD-60, AD-61), beside
/// <class>OcuPilot.Test.ExplorerSource</class>: every answer validates against the tool's
/// <code>ResultSchema</code>; a document of one line that alone exceeds the cap is cut and reports
/// <code>linesSent</code> equal to <code>lines</code>; a long routine is cut at whole lines; an include file
/// and an intermediate routine read whole; a routine the instance keeps only as object code answers 404; a
/// denied routine-viewer pair names <code>explorer.routine</code>; the port's own refusal passes through
/// and reads nothing; the arguments are closed and bounded; <method>OcuPilot.Screen.Tool.ExplorerSourceRead.Cut</method>
/// measures a number-typed line as a string, never ends on the high half of a surrogate pair and
/// answers an empty document as no lines; and a full-size read fits a reply alone and answers
/// <code>TOOL.RESULTTOOLARGE</code> when the reply has less left.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the suite account reading
/// <code>USER</code>'s code, the vendor routine <code>EnsJob.mac</code> kept as object code in the install
/// namespace, and the Atelier fixture free for the fake-route legs. It creates the probe documents of
/// package <code>OcuProbe193</code> and the probe routines <code>OcuProbe193Mac.mac</code>,
/// <code>OcuProbe193Inc.inc</code> and <code>OcuProbe193Int.int</code> in <code>USER</code> and removes them
/// before and after each method. The fake-route legs run in the test's own namespace: a canned route is a
/// method of <class>OcuPilot.Test.AtelierPortFixture</class>, which <code>USER</code> does not hold.</p>
Class OcuPilot.Test.ExplorerSourceEdges Extends OcuPilot.Test.ExplorerSourceTestCase
{

Parameter PROBEPACKAGE = "OcuProbe193";

Parameter CLASSTOOL = "OcuPilot.Screen.Tool.ExplorerClassSource";

Parameter ROUTINETOOL = "OcuPilot.Screen.Tool.ExplorerRoutineSource";

Parameter CLASSFIXTURE = "OcuPilot.Test.ExplorerClassSourceOnFixture";

Parameter PROBE = "OcuPilot.Test.ExplorerSaveProbe";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Parameter DISPATCH = "OcuPilot.Test.ToolDispatchProbe";

Parameter LIMIT = 60000;

Method OnBeforeOneTest() As %Status
{
    Do ..Reset()
    Quit $ClassMethod(..#PROBE, "Remove", ..#NAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do ..Reset()
    Do $ClassMethod(..#PROBE, "Remove", ..#NAMESPACE)
    Quit $$$OK
}

/// <p>Forget the scope, the fake routes, the armed gate and the dispatch probe's switches.</p>
ClassMethod Reset()
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FAKE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#DISPATCH, "Reset")
}

/// <p>The fault code of <var>pFault</var>, or <code>""</code> when it is not an object.</p>
ClassMethod CodeOf(pFault As %DynamicObject) As %String
{
    Quit $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>Save routine <var>pName</var> (one of the probe routines) in <parameter>NAMESPACE</parameter>:
/// a header line, <var>pRows</var> comment lines carrying quotes and a backslash, and a quit.</p>
ClassMethod MakeLongRoutine(pName As %String, pRows As %Integer) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRoutine = ##class(%Routine).%New(pName)
        Do tRoutine.WriteLine($Piece(pName, ".", 1) _ " ; long probe")
        For tI = 1:1:pRows {
            Do tRoutine.WriteLine(" ; row " _ tI _ " says ""quoted"" and a back\slash, padding for the cut")
        }
        Do tRoutine.WriteLine(" Quit")
        Set tSC = tRoutine.Save()
        Set tRoutine = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Save class <var>pName</var> in <parameter>NAMESPACE</parameter> with <var>pRows</var> doc-comment
/// lines carrying quotes and a backslash.</p>
ClassMethod MakeLongClass(pName As %String, pRows As %Integer) As %Status
{
    Set tBody = ""
    For tI = 1:1:pRows {
        Set tBody = tBody _ "/// row " _ tI _ " says ""quoted"" and a back\slash, padding for the cut" _ $Char(13, 10)
    }
    Set tText = "Class " _ $Piece(pName, ".cls", 1) _ " Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ tBody _ "}" _ $Char(13, 10)
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, pName, tText)
}

/// <p>Every answer validates against <code>ResultSchema</code>: a class read whole, a routine read whole
/// and a cut read.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.View</method> adding a member to
/// its answer -- this goes red.</p>
Method TestEveryAnswerConformsToTheResultSchema()
{
    Set tClassName = ..#PROBEPACKAGE _ ".Alpha.cls"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#NAMESPACE, ..#PROBEPACKAGE _ ".Alpha"), "the probe class is made")
    Set tSC = ..Fetch(..#CLASSTOOL, tClassName, ..#NAMESPACE, .tClass, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the class source read runs")
    If $$$ISOK(tSC) Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.ExplorerClassSource).ResultSchema(), tClass, .tProblem), "a class read whole conforms to the result schema: " _ $Get(tProblem))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#NAMESPACE, ..#PROBEPACKAGE _ "Mac.mac"), "the probe routine is made")
    Set tSC = ..Fetch(..#ROUTINETOOL, ..#PROBEPACKAGE _ "Mac.mac", ..#NAMESPACE, .tRoutine, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the routine source read runs")
    If $$$ISOK(tSC) Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.ExplorerRoutineSource).ResultSchema(), tRoutine, .tProblem), "a routine read whole conforms to the result schema: " _ $Get(tProblem))
    Set tLines = []
    Do tLines.%Push($TR($Justify("", 70000), " ", """"), "string")
    Do tLines.%Push("}", "string")
    Do ..ArmDocument("OcuProbe193.Wide.cls", tLines)
    Set tSC = ..Fetch(..#CLASSFIXTURE, "OcuProbe193.Wide.cls", $Namespace, .tCut, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the cut read runs")
    If $$$ISOK(tSC) {
        Do $$$AssertEquals(tCut.%Get("truncated"), 1, "the read was cut")
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.ExplorerClassSource).ResultSchema(), tCut, .tProblem), "a cut read conforms to the result schema: " _ $Get(tProblem))
    }
}

/// <p>A document of one line that alone exceeds the cap: the line is cut at a character, <code>truncated</code>
/// is true and <code>linesSent</code> equals <code>lines</code>, both 1. The result schema defines
/// <code>linesSent</code> as one when the first line itself was cut, so a one-line document cannot report
/// fewer lines sent than it holds.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.Cut</method> reporting a cut
/// first line as truncated only when the document holds more than one line -- this goes red.</p>
Method TestAOneLineDocumentOverTheCapKeepsItsOneLine()
{
    Set tWide = $TR($Justify("", 70000), " ", """")
    Set tLines = []
    Do tLines.%Push(tWide, "string")
    Do ..ArmDocument("OcuProbe193.Wide.cls", tLines)
    Set tSC = ..Fetch(..#CLASSFIXTURE, "OcuProbe193.Wide.cls", $Namespace, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the one-line document reads")
    If $$$ISERR(tSC) Quit
    Set tCut = tResult.%Get("text")
    Do $$$AssertEquals(tResult.%Get("lines") _ "|" _ tResult.%Get("linesSent") _ "|" _ tResult.%Get("truncated"), "1|1|1", "one line held, one line sent, and the cut is reported")
    Do $$$AssertEquals($Length(tCut), 30000, "the cut keeps the 30,000 quotes that escape to 60,000 characters")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Escaped(tCut) <= ..#LIMIT, "the text escapes to at most 60,000 characters")
    Do $$$AssertEquals(tCut, $Extract(tWide, 1, $Length(tCut)), "the text is a prefix of the line")
}

/// <p>A routine whose text escapes past 60,000 characters is cut at whole lines through the routine tool,
/// read from the instance: the text is the document's first lines verbatim, the next line would not have
/// fit, and fewer lines than the document holds are sent.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerRoutineSource</class> declaring
/// <parameter>SOURCEMAXLENGTH</parameter> 600000 -- this goes red.</p>
Method TestALongRoutineIsCutAtWholeLines()
{
    Set tName = ..#PROBEPACKAGE _ "Mac.mac"
    Do $$$AssertStatusOK(..MakeLongRoutine(tName, 2000), "the long probe routine is made")
    Set tSC = ..Fetch(..#ROUTINETOOL, tName, ..#NAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the long routine reads")
    If $$$ISERR(tSC) Quit
    Set tSent = tResult.%Get("linesSent")
    Set tTotal = tResult.%Get("lines")
    Set tCut = tResult.%Get("text")
    Do $$$AssertEquals(tResult.%Get("truncated"), 1, "the cut is reported")
    Do $$$AssertTrue(tSent < tTotal, "fewer lines than the routine holds are sent: " _ tSent _ " of " _ tTotal)
    Do $$$AssertEquals(tTotal, 2003, "the routine holds its ROUTINE line, its label line, 2000 rows and its quit")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Escaped(tCut) <= ..#LIMIT, "the text escapes to at most 60,000 characters: " _ ##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Escaped(tCut))
    Do $$$AssertEquals($Length(tCut, $Char(10)), tSent, "the text is exactly the lines it reports")
    Set tSource = $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tName)
    Do $$$AssertEquals(tCut, $Piece(tSource, $Char(10), 1, tSent), "the text is the routine's first lines, verbatim")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Escaped(tCut _ $Char(10) _ $Piece(tSource, $Char(10), tSent + 1)) > ..#LIMIT, "the next line would not have fit")
}

/// <p>An include file and an intermediate routine read whole through the routine tool, as the viewer's name
/// hint promises (<code>.inc</code>, <code>.int</code>).</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerRoutineSource.Endpoint</method> answering
/// the class endpoint -- this goes red.</p>
Method TestAnIncludeFileAndAnIntermediateRoutineReadWhole()
{
    For tName = ..#PROBEPACKAGE _ "Inc.inc", ..#PROBEPACKAGE _ "Int.int" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#NAMESPACE, tName), tName _ " is made")
        Set tSC = ..Fetch(..#ROUTINETOOL, tName, ..#NAMESPACE, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tName _ " reads")
        If $$$ISERR(tSC) Continue
        Set tSource = $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tName)
        Do $$$AssertTrue(tSource '= "", tName _ " has text")
        Do $$$AssertEquals(tResult.%Get("text"), tSource, tName _ ": the text is returned whole")
        Do $$$AssertEquals(tResult.%Get("truncated") _ "|" _ tResult.%Get("name"), "0|" _ tName, tName _ ": not truncated, and the answer names it")
    }
}

/// <p>A routine the instance keeps only as object code, read from the instance, answers 404
/// <code>PORT.NOTFOUND</code> with no result. The vendor routine <code>EnsJob.mac</code> is the
/// instance's own example (<class>OcuPilot.Test.AtelierPortDocument</class> reads it the same way); the
/// first assertion fails the leg, and ends it, if the instance no longer holds it that way.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.View</method> ignoring the
/// document's <code>available</code> -- this goes red.</p>
Method TestARoutineKeptOnlyAsObjectCodeOnTheInstanceAnswersNotFound()
{
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tQuery("name") = "EnsJob.mac"
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Routine", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)
    Set tHeld = $Select($IsObject($Get(tDocument)): tHttp _ " " _ tDocument.available _ " " _ tDocument.%Get("reason"), 1: tHttp)
    Do $$$AssertEquals(tHeld, "200 0 objectonly", "the instance keeps EnsJob.mac as object code alone")
    If tHeld '= "200 0 objectonly" Quit
    Set tSC = ..Fetch(..#ROUTINETOOL, "EnsJob.mac", $Namespace, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read is an error")
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "404 PORT.NOTFOUND", "it answers 404 PORT.NOTFOUND")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ##class(OcuPilot.Port.AtelierPort).#REASONNOSOURCE, "whose reason says the instance keeps no source")
    Do $$$AssertEquals(tResult, "", "and carries no result")
}

/// <p>Pins AC4 for the routine tool: with <code>%Development:USE</code> denied at dispatch's pair seam, a
/// model's call to <code>explorer_routine_source</code> is refused <code>AUTH.NOPRIVILEGE</code> naming the
/// pair and the screen <code>explorer.routine</code>, before any read: the named routine does not exist, and
/// a read would have answered 404.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerRoutineSource</class> declaring the class
/// viewer as its <parameter>DESCRIPTORCLASS</parameter> -- this goes red.</p>
Method TestADeniedRoutinePairNamesTheRoutineScreen()
{
    Do $ClassMethod(..#DISPATCH, "SetRegistryClass", ..#REGISTRY)
    Do $ClassMethod(..#DISPATCH, "DenyPair", "%Development", "USE")
    Set tUse = {"type": "tool_use", "id": "toolu_routine_denied", "input": {"name": "OcuProbe193Absent.mac"}}
    Do tUse.%Set("name", "explorer_routine_source", "string")
    Set tSC = $ClassMethod(..#DISPATCH, "Answer", "routinerefusal", $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do $$$AssertStatusOK(tSC, "the dispatcher runs")
    Set tDetail = tDetails.%Get(0)
    Do $$$AssertEquals(tResults.%Get(0).%Get("content") _ "|" _ tDetail.failedPair _ "|" _ tDetail.failedScreen, "{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Development:USE"",""screen"":""explorer.routine""}}|%Development:USE|explorer.routine", "the pair and the routine viewer are named")
}

/// <p>The port's own gate runs after the viewer's pairs and its refusal passes through unchanged: with
/// <code>%Development:USE</code> held and READ on the namespace's code database not, the read answers 403
/// <code>AUTH.NOPRIVILEGE</code> naming <code>%DB_USER:READ</code>, carries no result, and no route is called.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.View</method> answering every port
/// refusal as 404 <code>PORT.NOTFOUND</code> -- this goes red.</p>
Method TestThePortsOwnRefusalPassesThroughAndNothingIsRead()
{
    Do ..ArmDocument("OcuProbe193.Gated.cls", ["Class OcuProbe193.Gated {", "}"])
    Do $ClassMethod(..#FAKE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tSC = ..Fetch(..#CLASSFIXTURE, "OcuProbe193.Gated.cls", $Namespace, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the read is an error")
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "403 AUTH.NOPRIVILEGE", "it answers 403 AUTH.NOPRIVILEGE")
    Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: ""), "%DB_USER:READ", "naming the code database's pair")
    Do $$$AssertEquals(tResult, "", "with no result")
    Do $$$AssertEquals($ClassMethod(..#FAKE, "CallCount"), 0, "and no route called")
}

/// <p>The arguments are closed and bounded: a member besides <code>name</code>, a name past 256 characters
/// and a name that is not a string are each refused 400 <code>TOOL.ARGUMENTS</code>, before any read, and a
/// name of exactly 256 characters passes the arguments to the port, which answers it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.InputSchema</method> without
/// its <code>maxLength</code>, or with <code>maxLength</code> 128 -- this goes red.</p>
Method TestTheArgumentsAreClosedAndBounded()
{
    Set tExtra = {"name": "OcuProbe193.Alpha.cls", "form": "xml"}
    Set tLong = {}
    Do tLong.%Set("name", $TR($Justify("", 257), " ", "a"), "string")
    Set tNumber = {}
    Do tNumber.%Set("name", 5, "number")
    Set tArgs(1) = tExtra
    Set tLabel(1) = "an extra member"
    Set tArgs(2) = tLong
    Set tLabel(2) = "a name of 257 characters"
    Set tArgs(3) = tNumber
    Set tLabel(3) = "a name that is a number"
    For tLeg = 1:1:3 {
        For tTool = ..#CLASSTOOL, ..#ROUTINETOOL {
            Set tSC = $ClassMethod(tTool, "View", "", tArgs(tLeg), 0, .tResult, .tHttp, .tFault)
            Do $$$AssertStatusNotOK(tSC, tLabel(tLeg) _ " is refused by " _ tTool)
            Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "400 TOOL.ARGUMENTS", tLabel(tLeg) _ " answers 400 TOOL.ARGUMENTS from " _ tTool)
        }
    }
    Set tName = $TR($Justify("", 252), " ", "a") _ ".cls"
    Set tSC = ..Fetch(..#CLASSTOOL, tName, ..#NAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a name of 256 characters names no class")
    Do $$$AssertTrue((tHttp = 400) || (tHttp = 404), "it is answered by the port: " _ tHttp)
    Do $$$AssertNotEquals(..CodeOf(tFault), "TOOL.ARGUMENTS", "and is not refused as an argument: " _ ..CodeOf(tFault))
}

/// <p><method>OcuPilot.Screen.Tool.ExplorerSourceRead.Cut</method> measures a line the array holds as a number
/// as the string it is sent as, quotes counted: two such lines of two characters each fit a cap of 6 and not
/// a cap of 5. (A line pushed as a string measures the same either way; only a number-typed element
/// serializes unquoted without the type.)</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.Escaped</method> pushing its text
/// without the <code>string</code> type -- this goes red.</p>
Method TestANumberTypedLineIsMeasuredAsAString()
{
    Set tLines = []
    Do tLines.%Push(12)
    Do tLines.%Push(34)
    Set tText = ##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Cut(tLines, 5, .tSent, .tTruncated)
    Do $$$AssertEquals(tText _ "|" _ tSent _ "|" _ tTruncated, "12|1|1", "two lines of two characters and a line feed need 6, so a cap of 5 keeps the first")
    Set tText = ##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Cut(tLines, 6, .tSent, .tTruncated)
    Do $$$AssertEquals(tText _ "|" _ tSent _ "|" _ tTruncated, "12" _ $Char(10) _ "34|2|0", "and a cap of 6 keeps both")
}

/// <p>A first line cut at the cap never ends on the high half of a UTF-16 surrogate pair: a first line of
/// <code>a</code> and 35,000 pairs, whose 60,000-unit prefix would end between the halves of a pair, is
/// cut one unit short, on the low half of the last whole pair.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.CutFirst</method> without its
/// surrogate guard -- this goes red.</p>
Method TestACutFirstLineNeverEndsOnAHighSurrogate()
{
    Set tPair = $Char(55357, 56832)
    Set tFirst = "a"
    For tI = 1:1:35000 {
        Set tFirst = tFirst _ tPair
    }
    Set tLines = []
    Do tLines.%Push(tFirst, "string")
    Set tText = ##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Cut(tLines, ..#LIMIT, .tSent, .tTruncated)
    Set tLast = $Ascii($Extract(tText, *))
    Do $$$AssertEquals(tSent _ "|" _ tTruncated, "1|1", "the first line is the one line sent, and the cut is reported")
    Do $$$AssertTrue('((tLast >= 55296) && (tLast <= 56319)), "the text does not end on a high surrogate: last unit " _ tLast)
    Do $$$AssertEquals(tLast, 56832, "it ends on the low half of the last whole pair")
    Do $$$AssertEquals($Length(tText), 59999, "one unit short of the 60,000 allowance")
}

/// <p>A document that holds no lines reads as none: <code>lines</code> and <code>linesSent</code> 0, not
/// truncated, empty text.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.ExplorerSourceRead.Cut</method> starting its count of
/// lines sent at 1 -- this goes red.</p>
Method TestADocumentOfNoLinesReadsAsNone()
{
    Do ..ArmDocument("OcuProbe193.Empty.cls", [])
    Set tSC = ..Fetch(..#CLASSFIXTURE, "OcuProbe193.Empty.cls", $Namespace, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the empty document reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.%Get("lines") _ "|" _ tResult.%Get("linesSent") _ "|" _ tResult.%Get("truncated") _ "|" _ tResult.%Get("text"), "0|0|0|", "no lines held, none sent, nothing cut, no text")
}

/// <p>A full-size cut read is dispatchable: called alone in a reply it fits the reply's 65,536-character
/// budget and answers its text cut and reported, the text the class's first lines with no per-field cut
/// (AD-24's named exception); called with less than its size left, it answers
/// <code>TOOL.RESULTTOOLARGE</code>, as its description says.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerSourceRead</class> declaring
/// <parameter>SOURCEMAXLENGTH</parameter> 66000, or <class>OcuPilot.Kernel.Agent.Dispatch</class> cutting a
/// rowless result's <code>text</code> to 1,000 characters -- this goes red.</p>
Method TestAFullSizeCutReadFitsAReplyAloneAndIsRefusedWhenTheReplyHasLess()
{
    Set tName = ..#PROBEPACKAGE _ ".Long.cls"
    Do $$$AssertStatusOK(..MakeLongClass(tName, 2000), "the long probe class is made")
    Do $ClassMethod(..#DISPATCH, "SetRegistryClass", ..#REGISTRY)
    Set tUse = {"type": "tool_use", "id": "toolu_source_long", "input": {}}
    Do tUse.%Get("input").%Set("name", tName, "string")
    Do tUse.%Set("name", "explorer_class_source", "string")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = $ClassMethod(..#DISPATCH, "Answer", "sourcefit", $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do $$$AssertStatusOK(tSC, "the dispatcher runs")
    Set tAlone = tResults.%Get(0)
    Do $$$AssertEquals(tAlone.%Get("is_error"), 0, "called alone, the read is not an error: " _ $Extract(tAlone.%Get("content"), 1, 120))
    Do $$$AssertTrue($Length(tAlone.%Get("content")) <= ##class(OcuPilot.Kernel.Agent.Limits).#TOOLRESULTMAXLENGTH, "and its content fits the reply's budget: " _ $Length(tAlone.%Get("content")))
    Set tParsed = ""
    Try { Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tAlone.%Get("content")) } Catch {}
    Do $$$AssertTrue($IsObject(tParsed), "the content parses")
    If $IsObject(tParsed) {
        Do $$$AssertEquals(tParsed.%Get("truncated"), 1, "the cut is reported")
        Do $$$AssertTrue(tParsed.%Get("linesSent") < tParsed.%Get("lines"), "fewer lines than the class holds are sent")
        Do $$$AssertTrue(##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Escaped(tParsed.%Get("text")) <= ..#LIMIT, "the text escapes to at most 60,000 characters")
        Set tSource = $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tName)
        Do $$$AssertEquals(tParsed.%Get("text"), $Piece(tSource, $Char(10), 1, tParsed.%Get("linesSent")), "the text dispatch delivers is the class's first lines, uncut by the per-field bound")
        Do $$$AssertTrue($Length(tParsed.%Get("text")) > 1000, "and longer than the 1,000-character field bound: " _ $Length(tParsed.%Get("text")))
    }
    Set tSC = $ClassMethod(..#DISPATCH, "Answer", "sourcetight", $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 50000, .tDetails)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the dispatcher runs with less left")
    Set tTight = tResults.%Get(0)
    Do $$$AssertEquals(tTight.%Get("is_error"), 1, "with 50,000 characters left the read is an error")
    Do $$$AssertTrue(tTight.%Get("content") [ "TOOL.RESULTTOOLARGE", "and it answers TOOL.RESULTTOOLARGE: " _ $Extract(tTight.%Get("content"), 1, 120))
}

}
