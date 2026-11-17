/// <p>Pins Story 24.6's two consoles end to end through <class>OcuPilot.Port.DevToolPort</class> with the real bodies
/// (<class>OcuPilot.Port.Harvest.ConsoleRun</class>) over the real harvest port: the matrix's rows from Command to Open
/// transaction, the one <code>SecurityChange</code> row each run writes and what it never carries, the namespace and the
/// transaction level left as they were, and the harvested methods held equal to the sibling's by a hash of each method's code.</p>
/// <p>Needs the namespace <code>USER</code> and a process holding every pair the consoles ask. Each test saves the probe class
/// <code>OcuProbe246.Echo</code> in <code>USER</code> before it and removes it after; every command and call touches only
/// <code>^||</code> nodes, locals and that class.</p>
Class OcuPilot.Test.ConsoleRoundTrip Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter NAMESPACE = "USER";

Parameter ECHO = "OcuProbe246.Echo";

Parameter HARVEST = "OcuPilot.Port.Harvest.Console";

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

/// <p>Run the command <var>pText</var> through the port: the result, the status it answered with and the fault.</p>
Method Command(pText As %String, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
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

/// <p>How many <code>SecurityChange</code> rows since the test began carry <var>pMarker</var> and, when given, <var>pAlso</var>;
/// <var>pData</var> is the last one's data.</p>
Method Rows(pMarker As %String, Output pData As %String, pAlso As %String = "") As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(..Since, "SecurityChange", pMarker, .pData, pAlso)
}

/// <p>Matrix, Command, Code error and Open transaction: a command's output comes back whole; an error it raises is the run's
/// answer, 200, with the output written before it and the error naming it; and a transaction it leaves open is rolled back to the
/// level the run began at, with the namespace as it was.</p>
/// <p>Mutation (Rule 19): drop the <code>output</code> set in <method>OcuPilot.Port.Harvest.ConsoleRun.OnCaptured</method> -- the
/// output assertions go red.</p>
Method TestACommandAnswersItsOutputItsOwnErrorAndLeavesNoTransaction()
{
    Set tNamespace = $NAMESPACE
    Do $$$AssertStatusOK(..Command("W ""ok""", .tResult, .tHttp, .tFault), "a command runs")
    Do $$$AssertEquals(tHttp _ "|" _ tResult.output _ "|" _ tResult.truncated _ "|" _ tResult.error, "200|ok|0|", "its output, uncut, with no error")
    Do $$$AssertTrue('tResult.%IsDefined("outputBudget"), "and the budget it was cut by is not in the answer")
    Do $$$AssertStatusOK(..Command("W ""a"" Set x=1/0", .tResult2, .tHttp2, .tFault2), "a command that raises is still answered")
    Do $$$AssertEquals(tHttp2 _ "|" _ tResult2.output, "200|a", "200, with what it wrote before the error")
    Do $$$AssertTrue(tResult2.error [ "<DIVIDE>", "and its error names <DIVIDE>: " _ tResult2.error)
    Set tLevel = $TLevel
    Do $$$AssertStatusOK(..Command("TStart  Set ^||ocu246=1", .tResult3, .tHttp3, .tFault3), "a command that opens a transaction runs")
    Set tLeft = $TLevel - tLevel
    While $TLevel > tLevel {
        TRollback 1
    }
    Do $$$AssertEquals(tHttp3 _ "|" _ tLeft, "200|0", "and the transaction level is back to where the run began")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "the namespace is the caller's again")
    Kill ^||ocu246
    Do $$$AssertStatusOK(..Command("Set $NAMESPACE = ""%SYS""", .tResult4, .tHttp4, .tFault4), "a command that changes the namespace runs")
    Do $$$AssertEquals($NAMESPACE, tNamespace, "and the caller's namespace is unchanged after it")
}

/// <p>Matrix, Long output (AC3): a command that writes 40,000 characters answers at most 32,768, ending with the cut marker, with
/// <code>truncated</code> true, and a command that writes 32,768 exactly is not cut.</p>
/// <p>Mutation (Rule 19): ignore <code>outputBudget</code> in <method>OcuPilot.Port.Harvest.ConsoleRun.OnCaptured</method> -- this
/// goes red.</p>
Method TestAnOutputPastTheCeilingIsCutWithTheMarker()
{
    Do $$$AssertStatusOK(..Command("W $Translate($Justify("""", 40000), "" "", ""x"")", .tResult, .tHttp, .tFault), "a command writing 40,000 characters runs")
    Set tMarker = $Char(10) _ "[cut at 32768 characters]" _ $Char(10)
    Do $$$AssertEquals(tHttp _ "|" _ tResult.truncated _ "|" _ ($Length(tResult.output) <= 32768), "200|1|1", "it answers truncated, within the ceiling")
    Do $$$AssertEquals($Extract(tResult.output, $Length(tResult.output) - $Length(tMarker) + 1, *), tMarker, "ending with the cut marker")
    Do $$$AssertEquals($Length(tResult.output), 32768, "and exactly at the ceiling")
    Do $$$AssertStatusOK(..Command("W $Translate($Justify("""", 32768), "" "", ""x"")", .tResult2, .tHttp2, .tFault2), "a command writing exactly 32,768 characters runs")
    Do $$$AssertEquals($Length(tResult2.output) _ "|" _ tResult2.truncated, "32768|0", "it is not cut")
}

/// <p>Matrix, Class method, Big return and Method error (AC2): a method called with an argument and one passed by reference
/// answers its return value, its output, the by-reference value and the argument count; a return value of 40,000 characters is cut
/// within the ceiling and flagged; a method that raises answers its error with the output it wrote before it.</p>
/// <p>Mutation (Rule 19): drop <code>byRefValues</code> from <method>OcuPilot.Port.Harvest.ConsoleRun.ClassMethod</method> -- the
/// by-reference leg goes red.</p>
Method TestAClassMethodAnswersItsReturnItsOutputAndItsByReferenceValues()
{
    Do $$$AssertStatusOK(..Call(..#ECHO, "Echo", "[""hi"",{""byRef"":true,""value"":""x""}]", .tResult, .tHttp, .tFault), "a class method runs")
    Do $$$AssertEquals(tHttp _ "|" _ tResult.returnValue _ "|" _ tResult.output _ "|" _ tResult.argCount _ "|" _ tResult.error, "200|2|hi|2|", "its return value, output and count")
    Do $$$AssertEquals(tResult.byRefValues.%ToJSON(), "{""1"":""hi!""}", "and the value it set through the by-reference argument")
    Do $$$AssertEquals(tResult.truncated _ tResult.byRefTruncated _ tResult.returnValueTruncated, "000", "nothing cut")
    Do $$$AssertStatusOK(..Call(..#ECHO, "Big", "[]", .tBig, .tBigHttp, .tBigFault), "a class method returning 40,000 characters runs")
    Do $$$AssertEquals(tBigHttp _ "|" _ tBig.returnValueTruncated _ "|" _ ($Length(tBig.returnValue) <= 32768) _ "|" _ tBig.argCount, "200|1|1|0", "its return value is cut within the ceiling and flagged")
    Do $$$AssertStatusOK(..Call(..#ECHO, "Fails", "", .tFails, .tFailsHttp, .tFailsFault), "a class method that raises is still answered")
    Do $$$AssertEquals(tFailsHttp _ "|" _ tFails.output, "200|before", "200, with what it wrote before the error")
    Do $$$AssertTrue(tFails.error [ "<DIVIDE>", "and its error names <DIVIDE>: " _ tFails.error)
    Do $$$AssertEquals(tFails.returnValue, "", "and it returned nothing")
}

/// <p>A class method that returns a long value and also writes shares one budget between the two: the output is cut to what the
/// return value leaves of the 32,768 characters, and flagged.</p>
/// <p>Mutation (Rule 19): answer <code>..#OUTPUTCEILING</code> for <code>outputBudget</code> in
/// <method>OcuPilot.Port.Harvest.ConsoleRun.ClassMethod</method> -- the sum goes past the ceiling and this goes red.</p>
Method TestAClassMethodsReturnAndOutputShareOneBudget()
{
    Do $$$AssertStatusOK(..Call(..#ECHO, "Both", "[]", .tResult, .tHttp, .tFault), "a method that returns 30,000 characters and writes 40,000 runs")
    Do $$$AssertEquals(tHttp _ "|" _ $Length(tResult.returnValue) _ "|" _ tResult.truncated, "200|30000|1", "its return value is whole and its output is flagged cut")
    Do $$$AssertTrue($Length(tResult.output) > 0, "some of its output is kept")
    Do $$$AssertTrue($Length(tResult.returnValue) + $Length(tResult.output) <= 32768, "and the two together stay within the ceiling: " _ ($Length(tResult.returnValue) + $Length(tResult.output)))
}

/// <p>Matrix, Own code: a command or a class naming OcuPilot never reaches a body, even when the namespace the person is scoped to
/// is the one OcuPilot runs in.</p>
Method TestARunAtOcuPilotItselfIsRefusedBeforeAnyBody()
{
    Do $$$AssertStatusNotOK(..Command("Do ##class(OcuPilot.Kernel.State.Switch).X()", .tResult, .tHttp, .tFault), "a command naming OcuPilot is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "400|EXPLORER.COMMAND.OWNCODE", "400 and its code")
    Do $$$AssertStatusNotOK(..Call("OcuPilot.Kernel.Fault", "Build", "[]", .tResult2, .tHttp2, .tFault2), "a class of OcuPilot is refused")
    Do $$$AssertEquals(tHttp2 _ "|" _ tFault2.code, "400|EXPLORER.CLASSMETHOD.OWNCODE", "400 and its code")
    Do $$$AssertEquals(..Rows("""verb"":""run"""), 0, "and no row is written")
}

/// <p>AC10: each run that reaches a body writes one <code>SecurityChange</code> row that names the console and the namespace and,
/// for a class method, the class and the method. The command, the arguments and the answer are in no row, and a refused run writes
/// none.</p>
/// <p>Mutation (Rule 19): remove the <code>AuditRun</code> call from <method>OcuPilot.Port.DevToolPort.RunConsole</method> -- the
/// row counts go red.</p>
Method TestARunWritesOneRowThatNamesTheConsoleAndNothingTheyTyped()
{
    Set tCommandMarker = "OcuMarker246Command"
    Set tArgumentMarker = "OcuMarker246Argument"
    Do $$$AssertStatusOK(..Command("W """ _ tCommandMarker _ """", .tResult, .tHttp, .tFault), "a command runs")
    Do $$$AssertEquals(tResult.output, tCommandMarker, "and writes the marker")
    Do $$$AssertEquals(..Rows("""console"":""command""", .tData, """namespace"":""USER"""), 1, "one row names the command console and the namespace")
    Do $$$AssertEquals(..Rows(tCommandMarker), 0, "and no row carries the command")
    Do $$$AssertStatusOK(..Call(..#ECHO, "Echo", "[""" _ tArgumentMarker _ """]", .tResult2, .tHttp2, .tFault2), "a class method runs")
    Do $$$AssertEquals(tResult2.output, tArgumentMarker, "and writes the marker")
    Do $$$AssertEquals(..Rows("""console"":""classmethod""", .tMethodData, """class"":""OcuProbe246.Echo"",""method"":""Echo"""), 1, "one row names the class method console, the class and the method")
    Do $$$AssertEquals(..Rows(tArgumentMarker), 0, "and no row carries the arguments or the answer")
    Do $$$AssertEquals(..Rows("""verb"":""run""", .tAll, """console"":"""), 2, "and the two runs wrote two rows")
    Do $$$AssertStatusNotOK(..Call(..#ECHO, "Nope", "[]", .tResult3, .tHttp3, .tFault3), "a refused run is refused")
    Do $$$AssertEquals(..Rows("""verb"":""run""", .tAfter, """console"":"""), 2, "and writes none")
}

/// <p>AC8: the six methods <class>OcuPilot.Port.Harvest.Console</class> carries are the sibling's at <code>c6aad31</code> after three
/// renames (the capture flag, the cut marker's text and a sibling file name in a comment), as the hash of each method's code. The doc comments are not part of the
/// code.</p>
/// <p>Mutation (Rule 19): change one line of <code>InvokeWithArgs</code> -- this goes red naming it.</p>
Method TestTheHarvestedMethodsAreTheSiblingsAfterTheRenames()
{
    Set tWant = $ListBuild($ListBuild("ApplyOutputCeiling", "DDD335A153499DDC8D710C245BF9C26BD334F037879B9638D0717B4F83BD1EEA"), $ListBuild("SurrogateSafeCutLength", "213B95DE4A6DB0D1270B4472555EF4740E78E4F594F4434A210998E5BD7DD371"), $ListBuild("ParseArgEntry", "BF5094D94CD96FEC26E901670CB6C111D84748047BFC917237269CBB9D71CD18"), $ListBuild("BuildByRefNode", "C466367ED182BBAD08E24AE8EAA3F5BBFDB0FF3A53346FB9F78A06BC4B9626AB"), $ListBuild("AddByRefPosition", "5F6AAA2A0BF218ACF9F91214D0BA0FFB8520C082889004E864B5EA35141E5D28"), $ListBuild("InvokeWithArgs", "435EA0C2B6ACA36FFB32C0EFC873DFDCE926732B6E0B8182C1DA5321EDA24867"))
    For tI = 1:1:$ListLength(tWant) {
        Set tName = $List($List(tWant, tI), 1)
        Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(..#HARVEST _ "||" _ tName)
        Do $$$AssertTrue($IsObject(tMethod), tName _ " is defined in the harvested class")
        If '$IsObject(tMethod) Continue
        Set tCode = tMethod.Implementation.Read(3000000)
        Do $$$AssertEquals($System.Encryption.ToHex($System.Encryption.SHAHash(256, $ZConvert(tCode, "O", "UTF8"))), $List($List(tWant, tI), 2), tName _ " is the sibling's, line for line")
    }
}

}
