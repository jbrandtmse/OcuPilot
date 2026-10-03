/// <p>Pins the source code API port's macro lookup (AD-61 rules 2 and 3, AD-36): live, on
/// <class>OcuPilot.Test.ExplorerFindProbe</class>'s include, classes and routine, a macro found
/// through a class's own include, a superclass, a parenthesized include list, a routine's
/// <code>#include</code> and an include file's own name, a <code>$$$</code> name and a definition of
/// two lines, an unknown macro read as no row and an absent document refused unlogged; through
/// <class>OcuPilot.Test.AtelierPortFixture</class>'s canned routes, the body both macro routes are
/// sent, the arguments refused before any route and an instance too old refused; and
/// <method>OcuPilot.Port.AtelierPort.MacroContext</method> on its own.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in the install namespace and a
/// <code>USER</code> namespace, where the live legs create the probe documents and remove them after
/// each test, failing if any is left.</p>
Class OcuPilot.Test.AtelierPortMacro Extends %UnitTest.TestCase
{

/// <p>The namespace the probe documents are created in.</p>
Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerFindProbe";

/// <p>A document read's answer: a class whose header names an import, an include list, an include
/// generator and two superclasses.</p>
Parameter DOCANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""name"":""Probe.Alpha.cls"",""content"":[""Import Probe.Lib"",""Include (%occInclude, ProbeInc)"",""IncludeGenerator ProbeGen"","""",""/// A probe"",""Class Probe.Alpha Extends (Probe.Base, %RegisteredObject) [ Abstract ]"",""{"",""}""]}}";

/// <p>A definition answer of two lines.</p>
Parameter DEFINITIONANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":{""definition"":[""ProbeMacro(%a) 1 ##continue"",""  + %a""]}}}";

/// <p>A location answer.</p>
Parameter LOCATIONANSWER = "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":{""document"":""ProbeInc.inc"",""line"":7}}}";

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

/// <p>The port's lookup of <var>pMacro</var> in <var>pDocument</var>'s context in the probe
/// namespace, through <var>pPort</var>: its rows as <code>Macro|Document|Line|Definition</code>
/// joined by <code>;</code>, or the fault's code.</p>
ClassMethod Lookup(pDocument As %String, pMacro As %String, Output pHttp As %Integer, pPort As %String = "OcuPilot.Port.AtelierPort", pNamespace As %String = {..#PROBENAMESPACE}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("document") = pDocument
    Set tQuery("macro") = pMacro
    Set tSC = $ClassMethod(pPort, "Invoke", "Macro", "LIST", .tQuery, "", .tRows, .pHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select($IsObject(tFault): tFault.code, 1: "?")
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tLine = $Select(tRow.%GetTypeOf("Line") = "null": "null", 1: tRow.%Get("Line"))
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.%Get("Macro") _ "|" _ tRow.%Get("Document") _ "|" _ tLine _ "|" _ tRow.%Get("Definition")
    }
    Quit tText
}

/// <p>AC5: a macro the probe include defines is found, with its definition and the include and line
/// that define it, in the context of the class that includes it, of a parenthesized include list,
/// of a routine's <code>#include</code> and of the include file itself.</p>
Method TestAMacroIsFoundThroughEachIncludeForm()
{
    If '..MakeProbes() Quit
    Set tFound = "OcuProbe194Value|OcuProbe194Inc.inc|1|OcuProbe194Value 42"
    For tDocument = "OcuProbe194.Parent.cls", "OcuProbe194.Pair.cls", "OcuProbe194Mac.mac", "OcuProbe194Inc.inc" {
        Do $$$AssertEquals(..Lookup(tDocument, "OcuProbe194Value", .tHttp), tFound, "found in " _ tDocument _ "'s context")
        Do $$$AssertEquals(tHttp, 200, "with 200")
    }
    Do $$$AssertEquals(..Lookup("%Library.Persistent.cls", "OcuProbe194Value", .tHttp), "", "and not in a class whose context names no probe include")
}

/// <p>AC5: a subclass that includes nothing finds the macro through the superclass whose own include
/// defines it.</p>
/// <p>Mutation (Rule 19): drop the <code>Extends</code> list from
/// <method>OcuPilot.Port.AtelierPort.MacroContext</method> -&gt; this goes red.</p>
Method TestAMacroIsFoundThroughASuperclass()
{
    If '..MakeProbes() Quit
    Do $$$AssertEquals(..Lookup("OcuProbe194.Child.cls", "OcuProbe194Value", .tHttp), "OcuProbe194Value|OcuProbe194Inc.inc|1|OcuProbe194Value 42", "the subclass's context reaches its superclass's include")
}

/// <p>Matrix: a leading <code>$$$</code> is dropped, and a definition of two lines is answered
/// joined by LF, its line the first of them.</p>
Method TestADollarNameAndATwoLineDefinition()
{
    If '..MakeProbes() Quit
    Do $$$AssertEquals(..Lookup("OcuProbe194.Parent.cls", "$$" _ "$OcuProbe194Multi", .tHttp), "OcuProbe194Multi|OcuProbe194Inc.inc|2|OcuProbe194Multi 1 ##continue" _ $Char(10) _ "  + 2", "found under its own name, its two lines joined by LF")
}

/// <p>Matrix: a macro nothing in the context defines reads as no row, and a document the namespace
/// does not hold is 404 <code>PORT.NOTFOUND</code> and logs nothing.</p>
Method TestUnknownMacroAndAbsentDocument()
{
    If '..MakeProbes() Quit
    Do $$$AssertEquals(..Lookup("OcuProbe194.Parent.cls", "OcuProbe194None", .tHttp) _ " " _ tHttp, " 200", "an unknown macro reads as no row")
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(8)
    Do $$$AssertEquals(..Lookup("OcuProbe194.Absent.cls", "OcuProbe194Value", .tHttp, "OcuPilot.Test.AtelierPortFixture") _ " " _ tHttp, "PORT.NOTFOUND 404", "an absent document is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing is logged")
}

/// <p>AD-61 rule 3: the document's text is read first, and both macro routes are sent one body,
/// <code>{docname, macroname, includes, superclasses, imports}</code>, as JSON, built from that text
/// with the macro's <code>$$$</code> dropped; the answer is one row.</p>
Method TestBothMacroRoutesAreSentTheBodyTheTextGives()
{
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetDoc", "200 OK", ..#DOCANSWER)
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetMacroDefinition", "200 OK", ..#DEFINITIONANSWER)
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("GetMacroLocation", "200 OK", ..#LOCATIONANSWER)
    Set tRows = ..Lookup("Probe.Alpha.cls", "$$" _ "$ProbeMacro", .tHttp, "OcuPilot.Test.AtelierPortFixture", $Namespace)
    Do $$$AssertEquals(tRows, "ProbeMacro|ProbeInc.inc|7|ProbeMacro(%a) 1 ##continue" _ $Char(10) _ "  + %a", "one row from the two answers")
    Set tWanted = "{""docname"":""Probe.Alpha.cls"",""macroname"":""ProbeMacro"",""includes"":[""%occInclude"",""ProbeInc"",""ProbeGen""],""superclasses"":[""Probe.Base"",""%RegisteredObject""],""imports"":[""Probe.Lib""]}"
    Set tSeen = ""
    For tI = 1:1:##class(OcuPilot.Test.AtelierPortFixture).CallCount() {
        Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(tI)
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ";") _ tCall.method _ "(" _ tCall.arg _ ") " _ tCall.contentType _ " " _ tCall.body
    }
    Do $$$AssertEquals(tSeen, "GetDoc(Probe.Alpha.cls)  ;GetMacroDefinition() application/json " _ tWanted _ ";GetMacroLocation() application/json " _ tWanted, "the text first, then both routes with the one body")
}

/// <p>Matrix: a document matching neither name shape and a macro that is not a name are refused 400
/// <code>PORT.VALIDATION</code> before any route; an instance whose highest version is 1 is refused
/// 501 naming both versions before any route.</p>
Method TestMalformedLookupsAndAnOldInstanceAreRefusedBeforeAnyRoute()
{
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    For tCase = $ListBuild("Probe.Alpha", "X"), $ListBuild("Probe.Alpha.txt", "X"), $ListBuild("Probe.Alpha.cls", ""), $ListBuild("Probe.Alpha.cls", "$$X"), $ListBuild("Probe.Alpha.cls", "X(1)"), $ListBuild("Probe.Alpha.cls", "1X") {
        Kill tQuery
        Set tQuery("namespace") = $Namespace
        Set tQuery("document") = $List(tCase, 1)
        Set tQuery("macro") = $List(tCase, 2)
        Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Macro", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "400 PORT.VALIDATION " _ ##class(OcuPilot.Port.AtelierPort).#REASONMACRO, $ListToString(tCase, " ") _ " is refused")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(1)
    Set tRows = ..Lookup("Probe.Alpha.cls", "X", .tHttp, "OcuPilot.Test.AtelierPortFixture", $Namespace)
    Do $$$AssertEquals(tHttp _ " " _ tRows, "501 PORT.NOTIMPLEMENTED", "a version 1 instance is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
}

/// <p><method>OcuPilot.Port.AtelierPort.MacroContext</method>: a class's header names one include, a
/// parenthesized list and an import, a <code>/* */</code> banner naming a decoy is skipped, the
/// <code>Extends</code> list is read in either form, and nothing after the <code>Class</code> line
/// counts; a routine's <code>#include</code> lines join in any case, an include file names itself
/// first, and a list keeps at most the first 50 names the text gives.</p>
Method TestMacroContextReadsTheDocumentsOwnText()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    Set tLines = ["/* Include Decoy", "   Import Decoy */", "Import (Probe.Lib, Probe.Other)", "Include ProbeInc", "IncludeGenerator (%occInclude, ProbeInc)", "/// Include NotThisEither", "Class Probe.Alpha Extends Probe.Base [ Final ]", "{", "Include Later", "}"]
    Do $$$AssertEquals($ClassMethod(tPort, "MacroContext", "Probe.Alpha.cls", tLines).%ToJSON(), "{""includes"":[""ProbeInc"",""%occInclude""],""superclasses"":[""Probe.Base""],""imports"":[""Probe.Lib"",""Probe.Other""]}", "a class: its header's names, each once, the banner and the body skipped")
    Set tLines = ["Class Probe.Beta Extends (%Persistent, Probe.Base)", "{", "}"]
    Do $$$AssertEquals($ClassMethod(tPort, "MacroContext", "Probe.Beta.cls", tLines).%ToJSON(), "{""includes"":[],""superclasses"":[""%Persistent"",""Probe.Base""],""imports"":[]}", "a parenthesized Extends list")
    Set tLines = ["ProbeR ; routine", "#include ProbeInc", " #Include %occStatus", "#includes NotThis", " Quit"]
    Do $$$AssertEquals($ClassMethod(tPort, "MacroContext", "ProbeR.mac", tLines).%ToJSON(), "{""includes"":[""ProbeInc"",""%occStatus""],""superclasses"":[],""imports"":[]}", "a routine's #include lines, in any case")
    Set tLines = ["#define X 1", "#include Other"]
    Do $$$AssertEquals($ClassMethod(tPort, "MacroContext", "ProbeInc.inc", tLines).%ToJSON(), "{""includes"":[""ProbeInc"",""Other""],""superclasses"":[],""imports"":[]}", "an include file names itself first")
    Set tLines = ["Include (Ok, Bad-Name, ;Drop)", "Class Probe.Gamma Extends %RegisteredObject", "{", "}"]
    Do $$$AssertEquals($ClassMethod(tPort, "MacroContext", "Probe.Gamma.cls", tLines).includes.%ToJSON(), "[""Ok""]", "a name of any other shape is dropped")
    Set tLines = []
    For tI = 1:1:60 Do tLines.%Push("#include ProbeInc" _ tI)
    Set tIncludes = $ClassMethod(tPort, "MacroContext", "ProbeMany.mac", tLines).includes
    Do $$$AssertEquals(tIncludes.%Size() _ " " _ tIncludes.%Get(49), "50 ProbeInc50", "a list keeps at most 50 names, the first the text gives")
}

}
