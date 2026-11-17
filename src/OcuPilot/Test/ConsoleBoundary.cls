/// <p>Pins what Story 24.6's consoles do at their edges, through <class>OcuPilot.Port.DevToolPort</class> with the real bodies:
/// the namespace a command runs in, how a line-by-line output is joined and cut, an astral character at the cut, each kind of
/// argument reaching the method, a transaction a method leaves open, a run that tries to break the port's own answer or leaves
/// another device current, and the order the port's checks run in.</p>
/// <p>Needs the namespaces <code>USER</code> and <code>%SYS</code> and a process holding every pair the consoles ask. Each test
/// saves the probe class <code>OcuProbe246.Echo</code> in <code>USER</code> before it and removes it after; every command and call
/// touches only <code>^||</code> nodes, locals and that class.</p>
Class OcuPilot.Test.ConsoleBoundary Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter RECORDER = "OcuPilot.Test.DevToolHarvestRecorder";

Parameter NAMESPACE = "USER";

Parameter ECHO = "OcuProbe246.Echo";

/// <p>The audit clock when the test began.</p>
Property Since As %String;

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    ; The audit stamps a row a little after the call that wrote it, so the clock is read once the last test's rows are behind it.
    Hang 0.25
    Set ..Since = ##class(OcuPilot.Test.AuditEvent).Now()
    Quit $ClassMethod(..#PROBE, "MakeConsoleProbe", ..#NAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveConsoleProbe", ..#NAMESPACE), "the console probe class is removed")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$OK
}

/// <p>Run the command <var>pText</var> in <var>pNamespace</var> through the port.</p>
Method Command(pText As %String, Output pResult, Output pHttp As %Integer, Output pFault, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("command") = pText
    Quit $ClassMethod(..#FIXTURE, "Invoke", "Command", "RUN", .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>Call <var>pClass</var>.<var>pMethod</var> with the argument list <var>pArgs</var> through the port.</p>
Method Call(pClass As %String, pMethod As %String, pArgs As %String, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("class") = pClass
    Set tQuery("method") = pMethod
    If pArgs '= "" Set tQuery("args") = pArgs
    Quit $ClassMethod(..#FIXTURE, "Invoke", "ClassMethod", "RUN", .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>How many <code>SecurityChange</code> rows since the test began carry <var>pMarker</var>.</p>
Method Rows(pMarker As %String) As %Integer
{
    Set tCount = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(..Since, "SecurityChange", pMarker, .tData)
    Quit tCount
}

/// <p>A command runs in the namespace the request names, whichever namespace the caller is in, and the caller's own is back
/// afterwards.</p>
/// <p>Mutation (Rule 19): drop the <code>SwitchNamespace</code> call from <method>OcuPilot.Port.Harvest.ConsoleRun.Command</method>
/// -- one of the two legs reports the caller's namespace and this goes red.</p>
Method TestACommandRunsInTheNamespaceItIsScopedTo()
{
    Set tHome = $NAMESPACE
    For tNamespace = "USER", "%SYS" {
        Do $$$AssertStatusOK(..Command("W $NAMESPACE", .tResult, .tHttp, .tFault, tNamespace), tNamespace _ ": the command runs")
        Do $$$AssertEquals(tHttp _ "|" _ tResult.output _ "|" _ tResult.error, "200|" _ tNamespace _ "|", tNamespace _ ": it reports the namespace it was scoped to")
    }
    Do $$$AssertEquals($NAMESPACE, tHome, "the caller's namespace is unchanged")
}

/// <p>The lines a command writes are joined with line feeds, with none after the last; a command that writes thousands of lines,
/// or one line as long as a string can be, is cut at the ceiling across them, ending with the cut marker.</p>
/// <p>Mutation (Rule 19): join the lines with a space in <method>OcuPilot.Port.Harvest.ConsoleRun.OnCaptured</method> -- both
/// legs go red.</p>
Method TestLinesAreJoinedWithLineFeedsAndCutAcrossThem()
{
    Set tLF = $Char(10)
    Do $$$AssertStatusOK(..Command("W ""a"",!,""b"",!", .tResult, .tHttp, .tFault), "a command writing two lines runs")
    Do $$$AssertEquals(tHttp _ "|" _ tResult.output _ "|" _ tResult.truncated, "200|a" _ tLF _ "b|0", "the lines are joined with a line feed and none follows the last")
    Do $$$AssertStatusOK(..Command("F i=1:1:20000 W ""abcd"",!", .tManyResult, .tManyHttp, .tManyFault), "a command writing 20,000 lines runs")
    Set tMarker = tLF _ "[cut at 32768 characters]" _ tLF
    Do $$$AssertEquals(tManyHttp _ "|" _ tManyResult.truncated _ "|" _ $Length(tManyResult.output), "200|1|32768", "it is cut at the ceiling")
    Do $$$AssertEquals($Piece(tManyResult.output, tLF, 1) _ "|" _ $Piece(tManyResult.output, tLF, 2), "abcd|abcd", "its first lines are whole")
    Do $$$AssertEquals($Extract(tManyResult.output, $Length(tManyResult.output) - $Length(tMarker) + 1, *), tMarker, "and it ends with the cut marker")
    Do $$$AssertStatusOK(..Command("W ""a"",!,$J(""x"",3641144)", .tLongResult, .tLongHttp, .tLongFault), "a command whose second line is the longest string runs")
    Do $$$AssertEquals(tLongHttp _ "|" _ tLongResult.truncated _ "|" _ $Length(tLongResult.output), "200|1|32768", "and it is cut at the ceiling, not failed")
}

/// <p>A cut never leaves half of an astral character: a command that writes 20,000 of them is cut with a whole pair before the
/// marker, and the output encodes to UTF-8 and back unchanged.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.Harvest.Console.SurrogateSafeCutLength</method> answer the length it was
/// given -- the pair is split and this goes red.</p>
Method TestACutNeverSplitsAnAstralCharacter()
{
    Do $$$AssertStatusOK(..Command("F i=1:1:20000 W $Char(55357,56832)", .tResult, .tHttp, .tFault), "a command writing 20,000 astral characters runs")
    Do $$$AssertEquals(tHttp _ "|" _ tResult.truncated _ "|" _ (($Length(tResult.output) <= 32768) && ($Length(tResult.output) > 32000)), "200|1|1", "it is cut within the ceiling")
    Set tMarkerLength = $Length($Char(10) _ "[cut at 32768 characters]" _ $Char(10))
    Set tPayload = $Extract(tResult.output, 1, $Length(tResult.output) - tMarkerLength)
    Do $$$AssertEquals($ASCII($Extract(tPayload, $Length(tPayload) - 1)) _ "|" _ $ASCII($Extract(tPayload, $Length(tPayload))), "55357|56832", "the last character before the marker is a whole pair")
    Do $$$AssertEquals($ZConvert($ZConvert(tResult.output, "O", "UTF8"), "I", "UTF8"), tResult.output, "and the output survives a round trip through UTF-8")
}

/// <p>Each kind of argument reaches the method as the person wrote it: a number, a boolean as <code>1</code>, a decimal in its
/// canonical form, and a text holding a quote and a non-ASCII character.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.Harvest.Console.ParseArgEntry</method> pass a boolean as its text -- the
/// boolean leg goes red (and the harvest hash test with it).</p>
Method TestAnArgumentOfEachKindReachesTheMethod()
{
    For tRow = "[5]|1|5", "[true]|1|1", "[1.50]|3|1.5" {
        Set tArgs = $Piece(tRow, "|", 1)
        Do $$$AssertStatusOK(..Call(..#ECHO, "Echo", tArgs, .tResult, .tHttp, .tFault), tArgs _ ": the method runs")
        Do $$$AssertEquals(tHttp _ "|" _ tResult.returnValue _ "|" _ tResult.output _ "|" _ tResult.error, "200|" _ $Piece(tRow, "|", 2) _ "|" _ $Piece(tRow, "|", 3) _ "|", tArgs _ ": its return value and output")
    }
    Set tText = "say ""hi"" " _ $Char(960)
    Do $$$AssertStatusOK(..Call(..#ECHO, "Echo", "[""say \""hi\"" " _ $Char(960) _ """]", .tResult2, .tHttp2, .tFault2), "a text with a quote and a non-ASCII character runs")
    Do $$$AssertEquals(tHttp2 _ "|" _ tResult2.returnValue _ "|" _ tResult2.output, "200|" _ $Length(tText) _ "|" _ tText, "and reaches the method whole")
}

/// <p>A class method that leaves a transaction open is rolled back to the level the run began at, as is a command that raises
/// after opening one.</p>
/// <p>Mutation (Rule 19): roll back only a command's transaction in <method>OcuPilot.Port.DevToolPort.RunConsole</method> -- the
/// method leg goes red.</p>
Method TestATransactionALeftOpenByEitherConsoleIsRolledBack()
{
    Set tLevel = $TLevel
    Do $$$AssertStatusOK(..Call(..#ECHO, "Opens", "[]", .tResult, .tHttp, .tFault), "a method that opens a transaction runs")
    Set tLeft = $TLevel - tLevel
    While $TLevel > tLevel {
        TRollback 1
    }
    Do $$$AssertEquals(tHttp _ "|" _ tResult.returnValue _ "|" _ tLeft, "200|1|0", "and the level is back to where the run began")
    Do $$$AssertStatusOK(..Command("TStart  Set ^||ocu246=1 Set x=1/0", .tResult2, .tHttp2, .tFault2), "a command that opens one and then raises runs")
    Set tLeft2 = $TLevel - tLevel
    While $TLevel > tLevel {
        TRollback 1
    }
    Kill ^||ocu246
    Do $$$AssertEquals(tHttp2 _ "|" _ tLeft2, "200|0", "and its level is back too")
    Do $$$AssertTrue(tResult2.error [ "<DIVIDE>", "with its error named: " _ tResult2.error)
}

/// <p>A command that kills or sets the harvest port's response and request variables, or renders an answer of its own, changes
/// only its own copies: the run is answered 200 with the real answer, and still writes its one row. The render leg runs where
/// OcuPilot's classes are mapped, the only place the call can resolve.</p>
/// <p>Mutation (Rule 19): remove the <code>New</code> of those variables from <method>OcuPilot.Port.Harvest.ConsoleRun.Execute</method>
/// -- the runs answer 500, and this goes red.</p>
Method TestACommandCannotBreakThePortsAnswer()
{
    Set tHome = $NAMESPACE
    Set tForge = "Do $ClassMethod(""Ocu""_""Pilot.Port.Harvest.ConsoleRun"",""RenderResponseBody"",1,"""",{""error"":""forged""})"
    Set tCommands = $ListBuild("Set %response = 1", "Kill", "Kill %request, %response, %session W ""x""", tForge)
    Set tWant = $ListBuild("", "", "x", "")
    For tI = 1:1:$ListLength(tCommands) {
        Set tCommand = $List(tCommands, tI)
        Do $$$AssertStatusOK(..Command(tCommand, .tResult, .tHttp, .tFault, $Select(tI = 4: tHome, 1: ..#NAMESPACE)), tI _ ": the run is answered")
        Do $$$AssertEquals(tHttp _ "|" _ tResult.error _ "|" _ tResult.output, "200||" _ $List(tWant, tI), tI _ ": 200 with the real answer, not the forged one")
    }
    Hang 0.25
    Do $$$AssertEquals(..Rows("""console"":""command"""), 4, "and each of the four runs wrote its row")
}

/// <p>A class method that kills or sets the harvest port's response and request variables changes only its own copies: the call is
/// answered 200 with its return value and writes its row.</p>
/// <p>Mutation (Rule 19): remove the <code>New</code> of those variables from <method>OcuPilot.Port.Harvest.ConsoleRun.Call</method>
/// -- the call answers 500, and this goes red.</p>
Method TestAMethodCannotBreakThePortsAnswer()
{
    Do $$$AssertStatusOK(..Call(..#ECHO, "Wrecks", "[]", .tResult, .tHttp, .tFault), "the call is answered")
    Do $$$AssertEquals(tHttp _ "|" _ tResult.returnValue _ "|" _ tResult.error, "200|1|", "200 with its return value")
    Hang 0.25
    Do $$$AssertEquals(..Rows("""console"":""classmethod"""), 1, "and one row is written")
}

/// <p>A command that leaves another device current is answered, and the caller's own device is current again afterwards with the
/// mnemonic it had before the run, so the capture's routine stays on no device.</p>
/// <p>Mutation (Rule 19): put the caller's device back only after <code>EndCapture</code> in
/// <method>OcuPilot.Port.HarvestPort.Invoke</method> -- the caller's device keeps the capture's mnemonic and this goes red.</p>
Method TestACommandThatLeavesAnotherDeviceCurrentCannotKeepTheCapture()
{
    Set tDevice = $IO
    Set tMnemonic = $ZUtil(96, 12)
    Set tNull = ##class(%Device).GetNullDevice()
    Do $$$AssertStatusOK(..Command("O """ _ tNull _ """ U """ _ tNull _ """ W ""x""", .tResult, .tHttp, .tFault), "a command that leaves the null device current runs")
    Set tAfterDevice = $IO
    Set tAfterMnemonic = $ZUtil(96, 12)
    Close tNull
    Do $$$AssertEquals(tHttp _ "|" _ tResult.error, "200|", "it is answered")
    Do $$$AssertEquals(tAfterDevice _ "|" _ tAfterMnemonic, tDevice _ "|" _ tMnemonic, "and the caller's device is current again with its own mnemonic")
}

/// <p>The port's checks run in the order the story names, and a refusal records no body call and no row. A namespace of the wrong
/// shape and one the instance does not know are refused with their own reasons; a caller short of the namespace's write pair is
/// refused 403 before its input is looked at; the request type is looked at before the input; the input's shape before the
/// screen that names OcuPilot.</p>
/// <p>Mutation (Rule 19): answer a blank command's shape refusal ahead of the gate in <method>OcuPilot.Port.DevToolPort.Console</method>
/// -- the gate leg goes red.</p>
Method TestTheChecksRunInTheOrderTheStoryNames()
{
    Set tBlank = "   "
    For tEndpoint = "Command", "ClassMethod" {
        For tRow = "a b|" _ ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACESHAPE, "NoSuchNs246|" _ ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN {
            Kill tQuery
            Set tQuery("namespace") = $Piece(tRow, "|", 1)
            Set tQuery("command") = "W 1"
            Set tQuery("class") = ..#ECHO
            Set tQuery("method") = "Echo"
            Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", tEndpoint, "RUN", .tQuery, "", .tResult, .tHttp, .tFault), tEndpoint _ " in '" _ $Piece(tRow, "|", 1) _ "': refused")
            Do $$$AssertEquals(tHttp _ "|" _ tFault.code _ "|" _ tFault.reason, "400|PORT.VALIDATION|" _ $Piece(tRow, "|", 2), tEndpoint _ " in '" _ $Piece(tRow, "|", 1) _ "': 400 with the namespace's own reason")
        }
    }
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(..#NAMESPACE)
    For tI = 1:1:$ListLength(tPairs) Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tPairs, tI), 1), $List($List(tPairs, tI), 2))
    Set tWritePairs = ##class(OcuPilot.Port.AtelierPort).WritePairs(..#NAMESPACE)
    Set tWritePair = $List(tWritePairs, $ListLength(tWritePairs))
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("command") = tBlank
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "Command", "RUN", .tQuery, "", .tGateResult, .tGateHttp, .tGateFault), "a blank command from a caller short of WRITE is refused")
    Do $$$AssertEquals(tGateHttp _ "|" _ tGateFault.code _ "|" _ tGateFault.detail.failedPair, "403|AUTH.NOPRIVILEGE|" _ $List(tWritePair, 1) _ ":" _ $List(tWritePair, 2), "403 naming the pair, not 400 for the shape")
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("command") = tBlank
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "Command", "LIST", .tQuery, "", .tTypeResult, .tTypeHttp, .tTypeFault), "an unknown request type with a blank command is refused")
    Do $$$AssertEquals(tTypeHttp, 501, "501, the type before the input")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("command") = "W ""ocupilot""" _ $Char(9)
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "Command", "RUN", .tQuery, "", .tShapeResult, .tShapeHttp, .tShapeFault), "a command that names OcuPilot and holds a control character is refused")
    Do $$$AssertEquals(tShapeHttp _ "|" _ tShapeFault.code, "400|PORT.VALIDATION", "for its shape, before the screen")
    For tRow = "ocupilot..x|Echo|[]", "OcuPilot.Test.Prohibited|Run|{}" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("class") = $Piece(tRow, "|", 1)
        Set tQuery("method") = $Piece(tRow, "|", 2)
        Set tQuery("args") = $Piece(tRow, "|", 3)
        Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "ClassMethod", "RUN", .tQuery, "", .tClassResult, .tClassHttp, .tClassFault), $Piece(tRow, "|", 1) _ ": refused")
        Do $$$AssertEquals(tClassHttp _ "|" _ tClassFault.code, "400|PORT.VALIDATION", $Piece(tRow, "|", 1) _ " " _ $Piece(tRow, "|", 3) _ ": for its shape, before the screen")
    }
    Hang 0.25
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ ..Rows("""verb"":""run""") _ "|" _ $ClassMethod(..#FIXTURE, "LogCount"), "0|0|0", "no body call, no row and no log line")
}

}
