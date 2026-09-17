/// <p>The tool dispatcher's order, one refusal at a time (AD-1, AD-8, AD-11, AD-22, AD-24, AD-30,
/// AD-39): a registered call, an unknown tool, another user, a gate denial, a restrained write, a
/// denied or unreadable pair, refused arguments, a tool fault, a failure inside the dispatch path, and
/// both result caps -- each observed on
/// the <code>tool_result</code> content <method>OcuPilot.Kernel.Agent.Dispatch.Answer</method> renders
/// and on the counting fixtures' record of what was reached.</p>
/// <p>Driven through <class>OcuPilot.Test.ToolDispatchProbe</class> over
/// <class>OcuPilot.Test.DispatchTool.Registry</class>. <b>Live-safe</b>: it spawns nothing, writes
/// nothing and reads only the registry.</p>
Class OcuPilot.Test.ToolDispatch Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.ToolDispatchProbe";

Parameter COUNTER = "OcuPilot.Test.DispatchTool.Counter";

Parameter READER = "probe.counter.read";

Parameter WRITER = "probe.counter.write";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#COUNTER, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#COUNTER, "Clear")
    Quit $$$OK
}

/// <p>Answer one call to wire name <var>pWire</var> with <var>pInput</var>, as <var>pUser</var>.
/// <var>pResult</var> is the <code>tool_result</code> block and <var>pName</var> the name recorded
/// for it.</p>
Method Call(pWire As %String, pInput As %RawString, Output pResult As %DynamicObject, Output pName As %String, pUser As %String = {$Username})
{
    Set tUse = {"type": "tool_use", "id": "toolu_1"}
    Do tUse.%Set("name", pWire, "string")
    If $IsObject(pInput) {
        Do tUse.%Set("input", pInput)
    } Else {
        Do tUse.%Set("input", pInput, "string")
    }
    Set tUses = []
    Do tUses.%Push(tUse)
    Set tSC = $ClassMethod(..#PROBE, "Answer", "probe", pUser, "", tUses, ..#LIMITS, .tResults, .tNames)
    Do $$$AssertStatusOK(tSC, "the dispatcher answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResults)): tResults.%Size(), 1: 0), 1, "with one result for one call")
    Set pResult = $Select($IsObject($Get(tResults)): tResults.%Get(0), 1: {})
    Set pName = $Select($IsObject($Get(tNames)): tNames.%Get(0), 1: "")
}

/// <p>Read call and Several calls -- a registered read tool's call answers its result JSON under
/// the same id, not an error, recorded under the dotted name, with the cap passed and both pairs
/// checked; two calls answer two results in order.</p>
Method TestARegisteredReadCallAnswersItsResult()
{
    Do ..Call("probe_counter_read", {"marker": "m1", "rows": 2, "width": 3}, .tResult, .tName)
    Do $$$AssertEquals(tResult."tool_use_id" _ "|" _ tResult."is_error" _ "|" _ tResult.type, "toolu_1|0|tool_result", "one result block, under the call's id, not an error")
    Do $$$AssertEquals(tResult.content, "{""marker"":""m1"",""rows"":[{""n"":1,""text"":""rrr""},{""n"":2,""text"":""rrr""}],""truncated"":false}", "carrying the tool's result JSON")
    Do $$$AssertEquals(tName, ..#READER, "recorded under the dotted name")
    Do $$$AssertEquals($ClassMethod(..#COUNTER, "Calls", ..#READER), 1, "the tool ran once")
    Do $$$AssertEquals($ClassMethod(..#COUNTER, "Last", ..#READER, "cap"), $Parameter(..#LIMITS, "TOOLROWS"), "under the row cap")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "pair") _ "|" _ $ClassMethod(..#PROBE, "Count", "restraint"), "2|0", "both pairs were checked, and a read tool reads no restraint")

    Set tUses = [{"type": "tool_use", "id": "toolu_a", "name": "probe_counter_read", "input": {"marker": "a"}}, {"type": "tool_use", "id": "toolu_b", "name": "probe_nosuch_read", "input": {}}, {"type": "tool_use", "id": "toolu_c", "name": "probe_counter_read", "input": {"marker": "c"}}]
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Answer", "probe", $Username, "", tUses, ..#LIMITS, .tResults, .tNames), "three calls are answered")
    Do $$$AssertEquals(tResults.%Get(0)."tool_use_id" _ "," _ tResults.%Get(1)."tool_use_id" _ "," _ tResults.%Get(2)."tool_use_id", "toolu_a,toolu_b,toolu_c", "in the order they were made")
    Do $$$AssertEquals(tNames.%ToJSON(), "[""probe.counter.read"",""probe_nosuch_read"",""probe.counter.read""]", "each named, the unknown one as the model sent it")
    Do $$$AssertTrue((tResults.%Get(0).content [ """a""") && (tResults.%Get(2).content [ """c"""), "and each result is its own call's")
}

/// <p>Unknown -- a wire name no tool is advertised as answers <code>TOOL.UNKNOWN</code> and reaches
/// nothing, and a dotted name is not a wire name.</p>
/// <p>Mutation: resolution falls back to the first tool -> this goes red.</p>
Method TestAnUnknownToolReachesNothing()
{
    For tWire = "probe_nosuch_read", "probe.counter.read", "" {
        Do ..Call(tWire, {}, .tResult, .tName)
        Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNKNOWN""}", "'" _ tWire _ "' is unknown")
        Do $$$AssertEquals(tName, tWire, "and recorded as the model named it")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "gate") + $ClassMethod(..#COUNTER, "Calls", ..#READER), 0, "no gate was asked and no tool ran")
}

/// <p>Identity -- a call made in a process whose user is not the turn's answers
/// <code>TOOL.UNAVAILABLE</code>, is logged, and reaches no gate and no tool.</p>
/// <p>Mutation: the <code>$USERNAME</code> check removed -> this goes red.</p>
Method TestAnotherUsersCallIsRefusedAndLogged()
{
    Do ..Call("probe_counter_read", {}, .tResult, .tName, "OcuPilotProbeNotTheCaller")
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNAVAILABLE""}", "the call is unavailable")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "gate") + $ClassMethod(..#COUNTER, "Calls", ..#READER), 0, "no gate was asked and no tool ran")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "a user other than the turn's | TOOL.UNAVAILABLE", "and the refusal was logged: " _ $ClassMethod(..#PROBE, "Logged"))
}

/// <p>Gate denies -- a denial answers <code>TOOL.DENIED</code>, or its own code when it carries one,
/// reads no restraint, checks no pair and runs no tool; the tool is still advertised. A gate that
/// cannot decide answers <code>TOOL.UNAVAILABLE</code>, logged.</p>
/// <p>Mutation: <code>InvokeTool</code> called before <code>Decide</code> -> the tool's count goes red.</p>
Method TestAGateDenialReachesNothingAndTheToolStaysAdvertised()
{
    Do $ClassMethod(..#PROBE, "DenyGate")
    Do ..Call("probe_counter_write", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.DENIED""}", "the call is denied")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "gate"), 1, "by the gate, asked once")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "restraint") _ "|" _ $ClassMethod(..#PROBE, "Count", "pair") _ "|" _ $ClassMethod(..#COUNTER, "Calls", ..#WRITER), "0|0|0", "with no restraint read, no pair check and no tool")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Advertise", .tTools), "the tools are advertised after the denial")
    Set tWires = ""
    For tI = 1:1:+$Get(tTools) Set tWires = tWires _ $Select(tI = 1: "", 1: ",") _ tTools(tI, "name")
    Do $$$AssertEquals(tWires, "probe_counter_read,probe_counter_write", "the denied tool among them")

    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#PROBE, "DenyGate", "PROBE.POLICY")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""PROBE.POLICY""}", "a denial carrying its own code answers that code")

    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#PROBE, "FailGate")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNAVAILABLE""}", "a gate that cannot decide is unavailable")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "pair") _ "|" _ $ClassMethod(..#COUNTER, "Calls", ..#READER), "0|0", "and reaches no pair check and no tool")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "governance gate could not decide", "and is logged: " _ $ClassMethod(..#PROBE, "Logged"))
}

/// <p>Every live tool is allowed by the shipped gate point (AD-10, AD-22).</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Governance.Gate.Decide</method> answers 0 -> this goes red.</p>
Method TestTheShippedGateAllowsEveryLiveTool()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools), "the live tools list")
    If '$IsObject(tTools) Quit
    Do $$$AssertTrue(tTools.%Size() > 0, "there are live tools: " _ tTools.%Size())
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide(tTool.name, tTool.kind, $Username, {}, .tDecision), tTool.name _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), "1|", tTool.name _ ": allowed, with no code")
    }
}

/// <p>Write, restrained (DW-387, DW-390) -- a blocked verdict answers its own code and a verdict
/// that could not be read answers <code>TOOL.UNAVAILABLE</code> although it says not blocked; in
/// neither is the tool run. A clear verdict runs the write, and a read tool never reads one.</p>
/// <p>Mutations: the write branch skipped -> the blocked leg goes red. The branch trusts
/// <code>blocked</code> and not the status -> the error leg goes red.</p>
Method TestARestrainedWriteIsNotRun()
{
    Do $ClassMethod(..#PROBE, "ForceRestraint", "blocked", "AGENT.READONLY.ENFORCED")
    Do ..Call("probe_counter_write", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""AGENT.READONLY.ENFORCED""}", "blocked: the verdict's own code")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "pair") _ "|" _ $ClassMethod(..#COUNTER, "Calls", ..#WRITER), "0|0", "blocked: no pair check and no tool")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ $ClassMethod(..#COUNTER, "Calls", ..#READER) _ "|" _ $ClassMethod(..#PROBE, "Count", "restraint"), "0|1|1", "blocked: a read tool still runs, and the one restraint read was the write's")

    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#PROBE, "ForceRestraint", "error")
    Do ..Call("probe_counter_write", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNAVAILABLE""}", "unreadable with blocked 0: unavailable")
    Do $$$AssertEquals($ClassMethod(..#COUNTER, "Calls", ..#WRITER), 0, "unreadable: no tool")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "restraint verdict could not be read", "unreadable: logged")

    Do $ClassMethod(..#PROBE, "ForceRestraint", "clear")
    Do ..Call("probe_counter_write", {"marker": "w"}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ $ClassMethod(..#COUNTER, "Calls", ..#WRITER), "0|1", "clear: the write runs")
}

/// <p>Pair denied -- the first pair the user's grants lack is named in
/// <code>detail.failedPair</code> and no tool runs; pairs that cannot be read answer
/// <code>TOOL.UNAVAILABLE</code> and check nothing.</p>
/// <p>Mutation: the pair check removed -> the denial leg goes red.</p>
Method TestADeniedPairIsNamedAndNothingRuns()
{
    Do $ClassMethod(..#PROBE, "DenyPair", "OcuPilotProbeResourceB", "READ")
    Do ..Call("probe_counter_read", {"bogus": 1}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""OcuPilotProbeResourceB:READ""}}", "the failed pair is named, ahead of the arguments")
    Do $$$AssertEquals($ClassMethod(..#COUNTER, "Calls", ..#READER), 0, "and the tool did not run")

    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#COUNTER, "ArmUnresolvedPairs")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNAVAILABLE""}", "unreadable pairs are unavailable")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "pair") _ "|" _ $ClassMethod(..#COUNTER, "Calls", ..#READER), "0|0", "with no pair checked and no tool run")
}

/// <p>Arguments -- an input that is not an object, an undeclared argument and an over-long one each
/// answer <code>TOOL.ARGUMENTS</code> with <code>detail.problem</code>, and no tool runs.</p>
/// <p>Mutation: validation skipped -> this goes red.</p>
Method TestRefusedArgumentsReachNoTool()
{
    Set tLong = {"marker": ($Translate($Justify("", 65), " ", "x"))}
    For tCase = $ListBuild("text", 0, "not an object"), $ListBuild("{""bogus"": 1}", 1, "'bogus'"), $ListBuild(tLong.%ToJSON(), 1, "(maxLength)") {
        Set tInput = $Select($List(tCase, 2): ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 1)), 1: $List(tCase, 1))
        Do ..Call("probe_counter_read", tInput, .tResult, .tName)
        Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tResult.content)
        Do $$$AssertEquals(tResult."is_error" _ "|" _ tContent.code, "1|TOOL.ARGUMENTS", $List(tCase, 3) _ ": refused")
        Do $$$AssertTrue($IsObject(tContent.detail) && (tContent.detail.problem [ $List(tCase, 3)), $List(tCase, 3) _ ": the problem names it: " _ tResult.content)
    }
    Do $$$AssertEquals($ClassMethod(..#COUNTER, "Calls", ..#READER), 0, "and the tool never ran")
}

/// <p>Tool fault (DW-298) -- a view's fault answers its <code>code</code> and <code>detail</code>
/// and nothing else, whatever the HTTP status; one at 500 or above is also logged.</p>
/// <p>Mutation: the fault's <code>reason</code> rendered -> this goes red.</p>
Method TestAToolFaultAnswersItsCodeAndDetailOnly()
{
    Do $ClassMethod(..#COUNTER, "ArmFault", 404, "PROBE.NOTHERE", "{""x"":1}")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""PROBE.NOTHERE"",""detail"":{""x"":1}}", "the code and the detail")
    Do $ClassMethod(..#COUNTER, "ArmFault", 403, "PROBE.DENIED")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult.content, "{""code"":""PROBE.DENIED""}", "a fault with no detail answers its code alone")
    Do $$$AssertEquals(tResult.content [ "sentence", 0, "and no reason reaches the model")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Logged"), "", "a refusal below 500 is not logged")

    Do $ClassMethod(..#COUNTER, "ArmFault", 500, "INTERNAL")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult.content, "{""code"":""INTERNAL""}", "an internal failure answers its code alone")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "failed on the instance | INTERNAL", "and is logged, so the cause is kept: " _ $ClassMethod(..#PROBE, "Logged"))
}

/// <p>A failure inside the dispatch path -- a registry that cannot list, a view that throws and a view
/// that answers no result -- each answers <code>TOOL.UNAVAILABLE</code> and is logged; a result whose
/// part outside its rows is over the size cap answers <code>TOOL.RESULTTOOLARGE</code>.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method> without its registry-error
/// branch -> this goes red.</p>
Method TestAFailureInsideTheDispatchPathIsUnavailableAndLogged()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", "OcuPilot.Test.ReadTwinToolRegistry")
    Do ..Call("probe_counter_read", {}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNAVAILABLE""}", "a registry that cannot list is unavailable")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ "the tool registry could not be read | TOOL.UNAVAILABLE", "and is logged: " _ $ClassMethod(..#PROBE, "Logged"))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "gate"), 0, "and reaches no gate")

    For tCase = $ListBuild("throw", "failed with no fault"), $ListBuild("empty", "answered no result") {
        Do $ClassMethod(..#PROBE, "Reset")
        Set tInput = {}
        Do tInput.%Set($List(tCase, 1), 1, "number")
        Do ..Call("probe_counter_read", tInput, .tResult, .tName)
        Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.UNAVAILABLE""}", $List(tCase, 1) _ ": unavailable")
        Do $$$AssertTrue($ClassMethod(..#PROBE, "Logged") [ ($List(tCase, 2) _ " | TOOL.UNAVAILABLE"), $List(tCase, 1) _ ": logged: " _ $ClassMethod(..#PROBE, "Logged"))
    }

    Set tMax = $Parameter(..#LIMITS, "TOOLRESULTMAXLENGTH")
    Do ..Call("probe_counter_read", {"rows": 2, "width": 1, "blob": (tMax + 10)}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.RESULTTOOLARGE""}", "a result over the cap once every row is dropped is refused")
}

/// <p>Row cap -- a result holding more rows than the cap is cut to it and marked truncated; one at
/// the cap is not.</p>
Method TestTheRowCapCutsAndMarks()
{
    Set tCap = $Parameter(..#LIMITS, "TOOLROWS")
    Do ..Call("probe_counter_read", {"rows": (tCap + 50)}, .tResult, .tName)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tResult.content)
    Do $$$AssertEquals(tContent.rows.%Size() _ "|" _ tContent.truncated, tCap _ "|1", "cut to the cap and marked")
    Do ..Call("probe_counter_read", {"rows": (tCap)}, .tResult, .tName)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tResult.content)
    Do $$$AssertEquals(tContent.rows.%Size() _ "|" _ tContent.truncated, tCap _ "|0", "at the cap, nothing is cut")
}

/// <p>Size cap -- a result longer than the cap has trailing rows dropped until it fits and is marked
/// truncated; a result with no rows that still exceeds answers <code>TOOL.RESULTTOOLARGE</code>.</p>
/// <p>Mutation: the size check removed -> this goes red.</p>
Method TestTheSizeCapDropsTrailingRows()
{
    Set tMax = $Parameter(..#LIMITS, "TOOLRESULTMAXLENGTH")
    Do ..Call("probe_counter_read", {"rows": 100, "width": 1000}, .tResult, .tName)
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tResult.content)
    Do $$$AssertEquals(tResult."is_error", 0, "the result is answered")
    Do $$$AssertTrue($Length(tResult.content) <= tMax, "within the cap: " _ $Length(tResult.content))
    Do $$$AssertTrue((tContent.rows.%Size() > 0) && (tContent.rows.%Size() < 100), "with trailing rows dropped: " _ tContent.rows.%Size())
    Do $$$AssertEquals(tContent.rows.%Get(tContent.rows.%Size() - 1).n, tContent.rows.%Size(), "keeping the leading rows")
    Do $$$AssertEquals(tContent.truncated, 1, "and marked truncated")
    Do $$$AssertTrue($Length(tResult.content) > (tMax - 1200), "keeping every row that fits: " _ $Length(tResult.content))

    Do ..Call("probe_counter_read", {"blob": (tMax + 10)}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.content, "1|{""code"":""TOOL.RESULTTOOLARGE""}", "a rowless result over the cap is refused")
    Do ..Call("probe_counter_read", {"blob": (tMax - 20)}, .tResult, .tName)
    Do $$$AssertEquals(tResult."is_error", 0, "and one under it is answered")
}

}
