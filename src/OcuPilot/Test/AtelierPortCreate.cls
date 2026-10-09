/// <p>Story 20.20's port-level create (AD-54, AD-59, DW-2241): the <code>NEWDOC</code> read answers which held
/// documents take a name, <code>CREATE</code> writes and compiles one new document and refuses a taken name
/// before the PUT, and <code>Snippet</code> renders a create's and a save's stored text as script, bounded,
/// one self-contained line per step. Probes are made in <code>USER</code> by
/// <class>OcuPilot.Test.ExplorerCreateProbe</class> and removed after each test.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> with the
/// <code>USER</code> namespace's routines database readable and writable by the suite account, and
/// <class>OcuPilot.Test.ExplorerCreateProbe</class>'s documents not already held.</p>
Class OcuPilot.Test.AtelierPortCreate Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.ExplorerCreateProbe";

Parameter PROBENAMESPACE = "USER";

Parameter PORT = "OcuPilot.Port.AtelierPort";

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Quit $$$OK
}

/// <p>Invokes <var>pType</var> on the classes or routines list <var>pEndpoint</var> for the one name
/// <var>pName</var> in the probe namespace, with <var>pContent</var> and <var>pCompile</var> when given.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, pName As %String, pContent As %String = "", pCompile As %String = "", Output pResult, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("names") = pName
    If pType = "CREATE" {
        Set tQuery("content") = pContent
        Set tQuery("Compile") = pCompile
    }
    Quit ##class(OcuPilot.Port.AtelierPort).Invoke(pEndpoint, pType, .tQuery, "", .pResult, .pHttp, .pFault, .tDocument)
}

/// <p>The read a name takes: a held class in another case, and a routine that takes a routine of its base
/// name in exact case, are answered with the held name; a held include file takes its own name; a free name,
/// an include file beside a routine of its name, a routine beside an include file of its name, and a routine
/// name differing only in case are answered 404 <code>PORT.NOTFOUND</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.Takes</method> lets a held include file take a
/// routine of its base name -- the routine-beside-an-include leg goes red.</p>
Method TestNewDocAnswersWhichHeldDocumentsTakeAName()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe2020.Port"), "a probe class is held")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Int.int"), "a probe intermediate routine is held")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Inc.inc"), "a probe include file is held")
    Set tSC = ..Call("Classes", "NEWDOC", "OcuProbe2020.Port.cls", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200) && (tResult.Present = "OcuProbe2020.Port.cls"), "the held class takes its own name: " _ tHttp)
    Set tSC = ..Call("Classes", "NEWDOC", "OcuProbe2020.PORT.cls", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200) && (tResult.Present = "OcuProbe2020.Port.cls"), "and a class of the same name in any case, named as it is held: " _ tHttp _ " " _ $Select($IsObject($Get(tResult)): tResult.Present, 1: ""))
    Set tSC = ..Call("Routines", "NEWDOC", "OcuProbe2020Inc.inc", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200) && (tResult.Present = "OcuProbe2020Inc.inc"), "a held include file takes its own name: " _ tHttp)
    Set tSC = ..Call("Routines", "NEWDOC", "OcuProbe2020Inc.mac", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 404), "a routine beside a held include file of its name is free: " _ tHttp)
    Set tSC = ..Call("Classes", "NEWDOC", "OcuProbe2020.Free.cls", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 404) && (tFault.code = "PORT.NOTFOUND"), "a free class name is answered 404 PORT.NOTFOUND: " _ tHttp)
    Set tSC = ..Call("Routines", "NEWDOC", "OcuProbe2020Int.mac", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200) && (tResult.Present = "OcuProbe2020Int.int"), "a .mac name is taken by a held .int of its base name")
    Set tSC = ..Call("Routines", "NEWDOC", "OcuProbe2020Int.inc", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 404), "an include file beside a held intermediate routine of its name is free")
    Set tSC = ..Call("Routines", "NEWDOC", "OcuProbe2020INT.mac", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 404), "a routine name differing only in case is free")
}

/// <p>A create writes the text, compiles it, and answers the compile's <code>{lines, errors}</code>: the class
/// exists, is compiled, and reports no error.</p>
Method TestCreateWritesAndCompiles()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Made")
    Set tSC = ..Call("Classes", "CREATE", "OcuProbe2020.Made.cls", tText, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is answered: " _ tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""))
    Do $$$AssertEquals(tHttp, 200, "the create answers 200")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe2020.Made.cls") && $ClassMethod(..#PROBE, "Compiled", ..#PROBENAMESPACE, "OcuProbe2020.Made"), "the class is held and compiled")
    Do $$$AssertEquals($ZStrip($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe2020.Made.cls"), "<>WC"), $ZStrip(tText, "<>WC"), "and holds the text")
    Do $$$AssertTrue($IsObject(tResult) && (tResult.%GetTypeOf("errors") = "boolean"), "the compile reports an errors flag")
    Do $$$AssertEquals($Select($IsObject(tResult): tResult.errors, 1: "none"), 0, "the compile reports no error")
}

/// <p>A name the namespace holds at the write is refused 409 <code>EXPLORER.DOCUMENT.CONFLICT</code> before any
/// vendor call: a create of <code>OcuProbe2020Int.mac</code> while <code>OcuProbe2020Int.int</code> is held leaves
/// the held routine unchanged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveSet</method> skips the create's taken check -- the
/// refusal leg goes red.</p>
Method TestAPortRaceIsRefusedWithNothingSent()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Int.int"), "a probe intermediate routine is held")
    Set tBefore = $ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe2020Int.int")
    Set tText = $ClassMethod(..#PROBE, "NewRoutineText", "OcuProbe2020Int.mac")
    Set tSC = ..Call("Routines", "CREATE", "OcuProbe2020Int.mac", tText, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 409) && (tFault.code = "EXPLORER.DOCUMENT.CONFLICT"), "the create is refused 409: " _ tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#PROBENAMESPACE, "OcuProbe2020Int.int"), tBefore, "and the held routine is unchanged")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe2020Int.mac"), "and no .mac was written")
}

/// <p>A create whose header names another document is refused 422 <code>EXPLORER.SAVE.HEADER</code>, and writes
/// nothing.</p>
Method TestAHeaderNamingAnotherDocumentIsRefused()
{
    Set tText = $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Other")
    Set tSC = ..Call("Classes", "CREATE", "OcuProbe2020.Made.cls", tText, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 422), "the header is refused 422: " _ tHttp)
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe2020.Made.cls") && '$ClassMethod(..#PROBE, "Exists", ..#PROBENAMESPACE, "OcuProbe2020.Other.cls"), "and neither document is written")
}

/// <p>A create's script stores the text under the existence guard, a routine's without its header line, and a
/// save's stored text in place of the placeholder (AD-59, DW-2241). A script past
/// <parameter>SNIPPETMAXCHARACTERS</parameter> renders no step, and a read renders none.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> writes the placeholder -- the text
/// legs go red.</p>
Method TestTheCreateAndTheSaveRenderTheirStoredText()
{
    Set tPort = ..#PORT
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("names") = "OcuProbe2020.Snip.cls"
    Set tQuery("content") = $ClassMethod(..#PROBE, "NewClassText", "OcuProbe2020.Snip")
    Set tQuery("Compile") = 1
    Set tText = $ClassMethod(tPort, "Snippet", "Classes", "CREATE", .tQuery).%Get(0).text
    Do $$$AssertTrue(tText [ "tFree = '$Data(^rINDEXCLASS(""OCUPROBE2020.SNIP""))", "a class create checks the name in any letter case")
    Do $$$AssertTrue((tText [ " If tFree Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromArray(") && (tText [ "is taken: this namespace holds it or another document of its name, so nothing was created."), "and sets the stored lines only while it is free, else saying nothing was created")
    Do $$$AssertTrue((tText [ "Quit 1") && '(tText [ "<content>"), "the stored text is rendered, not the placeholder")
    Do $$$AssertTrue(tText [ " If tFree,$System.Status.IsOK(tSC) Set tSC = $System.OBJ.CompileList(""OcuProbe2020.Snip.cls"", ""cuk"")", "and compiles it once it is written, the create's compile being on")
    Set tQuery("names") = "OcuProbe2020Snip.mac"
    Set tQuery("content") = "ROUTINE OcuProbe2020Snip" _ $Char(10) _ " Quit"
    Set tText = $ClassMethod(tPort, "Snippet", "Routines", "CREATE", .tQuery).%Get(0).text
    For tTaker = "OcuProbe2020Snip.mac", "OcuProbe2020Snip.int", "OcuProbe2020Snip.bas", "OcuProbe2020Snip.mvi", "OcuProbe2020Snip.mvb" {
        Do $$$AssertTrue(tText [ ("##class(%RoutineMgr).Exists(""" _ tTaker _ """)"), "a routine create checks " _ tTaker _ ", which takes its name")
    }
    Do $$$AssertTrue(tText '[ "OcuProbe2020Snip.inc", "and not the include file of its base name")
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("names") = "OcuProbe2020Snip.inc"
    Set tQuery("content") = "ROUTINE OcuProbe2020Snip [Type=INC]" _ $Char(10) _ "#define OcuProbe2020Snip 7"
    Set tQuery("Compile") = 0
    Set tText = $ClassMethod(tPort, "Snippet", "Routines", "CREATE", .tQuery).%Get(0).text
    Do $$$AssertTrue(tText [ "WriteLine(""#define OcuProbe2020Snip 7"")", "a routine's stored lines are written")
    Do $$$AssertTrue('(tText [ "ROUTINE OcuProbe2020Snip"), "without its header line")
    Do $$$AssertTrue(tText [ "%Routine).%New(""OcuProbe2020Snip.inc"")", "and as the routine it names")
    Do $$$AssertTrue(tText '[ "CompileList", "and is not compiled when Compile is off")
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("names") = "OcuProbe2020Long.cls"
    Set tQuery("content") = $Justify("", 1000001)
    Set tQuery("Compile") = 1
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "CREATE", .tQuery).%Size(), 0, "a script past the bound renders no step")
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Classes", "NEWDOC", .tQuery).%Size(), 0, "a read renders no step")
}

/// <p>A save or a create whose text is within the bound but whose script is not renders no step, and fails
/// nowhere: three hundred thousand one-character lines are 600,000 characters of text and over twelve million
/// of script, past the longest string the instance holds.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> renders every line before the
/// bound is read -- this goes red with <code>&lt;MAXSTRING&gt;</code>.</p>
Method TestAScriptPastTheBoundRendersNoStepForAnyText()
{
    For tCase = $ListBuild("Classes", "OcuProbe2020.Many.cls", "SAVE"), $ListBuild("Routines", "OcuProbe2020Many.mac", "CREATE") {
        Kill tQuery
        Set tQuery("namespace") = ..#PROBENAMESPACE
        Set tQuery("names") = $List(tCase, 2)
        Set tQuery("content") = $Replace($Justify("", 300000), " ", "x" _ $Char(10))
        Set tQuery("version") = "2026-10-09 09:00:00.000"
        Set tQuery("Compile") = 1
        Set tSteps = ""
        Try {
            Set tSteps = $ClassMethod(..#PORT, "Snippet", $List(tCase, 1), $List(tCase, 3), .tQuery)
        } Catch ex {
            Set tSteps = ex.DisplayString()
        }
        Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() = 0), $List(tCase, 1) _ " " _ $List(tCase, 3) _ " of many short lines renders no step: " _ $Select($IsObject(tSteps): tSteps.%Size(), 1: tSteps))
    }
}

/// <p>Every line of every script the port renders closes each block it opens, so the script runs the same
/// pasted line by line into a terminal, which runs each line on its own, as it does as a method body: the
/// compile, the delete, the export, the import, and a class's and a routine's save and create. String
/// literals are left out of the count.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveScript</method> wraps a create's steps in one
/// block <code>If ... {</code> spanning lines -- this goes red.</p>
Method TestEveryScriptLineClosesTheBlocksItOpens()
{
    Set tClass = "Class OcuProbe2020.Snip { ClassMethod Probe() { Quit 1 } }"
    Set tRoutine = "ROUTINE OcuProbe2020Snip" _ $Char(10) _ " If 1 { Set tBrace = ""{"" }"
    Set tLiteral = ##class(%Regex.Matcher).%New("""(?:[^""]|"""")*""")
    For tCase = $ListBuild("Classes", "COMPILE", "A.cls,B.cls", ""), $ListBuild("Routines", "DELETE", "A.mac,B.mac", ""), $ListBuild("Classes", "EXPORT", "A.cls", ""), $ListBuild("Classes", "IMPORT", "A.cls", ""), $ListBuild("Classes", "SAVE", "OcuProbe2020.Snip.cls", tClass), $ListBuild("Classes", "CREATE", "OcuProbe2020.Snip.cls", tClass), $ListBuild("Routines", "SAVE", "OcuProbe2020Snip.mac", tRoutine), $ListBuild("Routines", "CREATE", "OcuProbe2020Snip.mac", tRoutine) {
        Kill tQuery
        Set tQuery("namespace") = ..#PROBENAMESPACE
        Set tQuery("names") = $List(tCase, 3)
        Set tQuery("content") = $List(tCase, 4)
        Set tQuery("version") = "2026-10-09 09:00:00.000"
        Set tQuery("Compile") = 1
        Set tQuery("path") = "probe.xml"
        Set tQuery("root") = "/tmp"
        Set tSteps = $ClassMethod(..#PORT, "Snippet", $List(tCase, 1), $List(tCase, 2), .tQuery)
        Do $$$AssertEquals(tSteps.%Size(), 1, $List(tCase, 2) _ " on " _ $List(tCase, 1) _ " renders one step")
        If tSteps.%Size() '= 1 Continue
        Set tText = tSteps.%Get(0).text
        Set tOpen = ""
        For tI = 1:1:$Length(tText, $Char(10)) {
            Set tLiteral.Text = $Piece(tText, $Char(10), tI)
            Set tLine = tLiteral.ReplaceAll("")
            If ($Length(tLine, "{") '= $Length(tLine, "}")) && (tOpen = "") Set tOpen = $Piece(tText, $Char(10), tI)
        }
        Do $$$AssertEquals(tOpen, "", $List(tCase, 2) _ " on " _ $List(tCase, 1) _ ": no line leaves a block open")
    }
}

}
