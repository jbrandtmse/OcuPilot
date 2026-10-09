/// <p>Story 20.20's port-level create (AD-54, AD-59, DW-2241): the <code>NEWDOC</code> read answers which held
/// documents take a name, <code>CREATE</code> writes and compiles one new document and refuses a taken name
/// before any vendor call, and <code>Snippet</code> renders a create's and a save's stored text as script,
/// bounded. Probes are made in <code>USER</code> by <class>OcuPilot.Test.ExplorerCreateProbe</class> and removed
/// after each test.</p>
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
/// name in exact case, are answered with the held name; a free name, an include file beside a routine of
/// its name, and a routine name differing only in case are answered 404 <code>PORT.NOTFOUND</code>.</p>
Method TestNewDocAnswersWhichHeldDocumentsTakeAName()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#PROBENAMESPACE, "OcuProbe2020.Port"), "a probe class is held")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeRoutine", ..#PROBENAMESPACE, "OcuProbe2020Int.int"), "a probe intermediate routine is held")
    Set tSC = ..Call("Classes", "NEWDOC", "OcuProbe2020.Port.cls", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200) && (tResult.Present = "OcuProbe2020.Port.cls"), "the held class takes its own name: " _ tHttp)
    Set tSC = ..Call("Classes", "NEWDOC", "OcuProbe2020.PORT.cls", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISOK(tSC) && (tHttp = 200), "and a class of the same name in any case")
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
    Do $$$AssertTrue(tText [ "##class(%RoutineMgr).Exists(""OcuProbe2020.Snip.cls"")", "a class create is under the existence guard")
    Do $$$AssertTrue((tText [ "SetTextFromArray") && (tText [ "already exists; nothing was created."), "and sets the stored lines, else saying nothing was created")
    Do $$$AssertTrue((tText [ "Quit 1") && '(tText [ "<content>"), "the stored text is rendered, not the placeholder")
    Do $$$AssertTrue(tText [ "CompileList(""OcuProbe2020.Snip.cls"", ""cuk"")", "and compiles it, the create's compile being on")
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

}
