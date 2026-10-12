/// <p>Story 18.45's scoped tool set on the canonical (Anthropic) dialect, in process (AD-5, AD-8,
/// AD-24, AD-53): a turn whose registry holds the discovery tool sends every advertised tool,
/// byte-identical on every call, with each tool outside the starting set deferred and the cache
/// marker on the last tool that is not; a tool the model finds is answered as a
/// <code>tool_reference</code> and is called on the next step; the screen context's own tools start
/// undeferred; a registry without the discovery tool is sent whole; and every built screen's starting
/// set fits the size the other dialects carry.</p>
/// <p>Driven through <class>OcuPilot.Test.TurnLoopProbe</class> and
/// <class>OcuPilot.Test.ToolDispatchProbe</class> over <class>OcuPilot.Test.ScopeTool.Registry</class>
/// (or <class>OcuPilot.Test.DispatchTool.Registry</class>, which holds no discovery tool), on
/// <class>OcuPilot.Test.ProviderStub</class>. The harness is <class>OcuPilot.Test.TurnToolsCase</class>'s.
/// <b>Live-safe</b>: it spawns nothing and opens no socket; it writes probe agent definitions and
/// turn rows in OcuPilot's own database and removes every one after each method.</p>
Class OcuPilot.Test.TurnScope Extends OcuPilot.Test.TurnToolsCase
{

Parameter REGISTRY = "OcuPilot.Test.ScopeTool.Registry";

/// <p>The most characters a starting set may carry in the OpenAI dialect (C2).</p>
Parameter STARTINGSETMAX = 65536;

/// <p>Run turns over the scoped-turn fixture registry with the shipped limits.</p>
Method UseScopeTools()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#DISPATCH, "SetRegistryClass", ..#REGISTRY)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
}

/// <p>The names of <var>pTools</var>' members that carry (<code>1</code>) or lack (<code>0</code>)
/// <code>defer_loading</code>, comma-separated, in array order.</p>
ClassMethod Deferred(pTools As %DynamicArray, pDeferred As %Boolean) As %String
{
    Set tNames = ""
    Set tIterator = pTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If ''tTool.%Get("defer_loading") '= pDeferred Continue
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tTool.name
    }
    Quit tNames
}

/// <p>The kind, name and status of every step of turn <var>pKey</var>, one
/// <code>kind:name:status</code> per step, joined by semicolons.</p>
ClassMethod Steps(pKey As %String) As %String
{
    Set tSteps = ""
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(pKey, $Username, .tFound, .tView)
    If '$IsObject($Get(tView)) Quit "(no view)"
    For tI = 0:1:tView.steps.%Size() - 1 {
        Set tStep = tView.steps.%Get(tI)
        Set tSteps = tSteps _ tStep.kind _ ":" _ tStep.name _ ":" _ tStep.status _ ";"
    }
    Quit tSteps
}

/// <p>Search, find, call (C1, C3) -- call 1 searches "found", call 2 calls the tool the search
/// found, call 3 ends: every call carries the same <code>tools</code> text, holding every advertised
/// tool of the registry, only the tools outside the starting set deferred, and the cache marker on the
/// last tool that is not deferred and on no other; call 2 carries the search's answer as a
/// <code>tool_reference</code>; the found tool is dispatched once and its step is ok.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Agent.Loop.Scope</method> marks every tool
/// <code>start</code> -> this goes red on the deferred names;
/// <method>OcuPilot.Kernel.Provider.Anthropic.MarkedTool</method> answers the last tool -> this goes
/// red on the marker.</p>
Method TestASearchedToolIsCalledOnTheNextStepOverAnUnchangedArray()
{
    Do ..UseScopeTools()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ScopeTool.Registry).ProviderTools(.tAdvertised), "the fixture registry advertises")
    Do $$$AssertEquals(+$Get(tAdvertised), 4, "four tools, the hidden one left out")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_find", "name": "shell_tools_find", "input": {"query": "found"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_found", "name": "probe_found_read", "input": {"marker": "m1"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 3, "after three provider calls")
    Set tFirst = ##class(OcuPilot.Test.TurnBudget).Sent(1).tools
    Set tNames = ""
    For tI = 0:1:tFirst.%Size() - 1 Set tNames = tNames _ $Select(tI = 0: "", 1: ",") _ tFirst.%Get(tI).name
    Do $$$AssertEquals(tNames, "probe_found_read,shell_probe_read,shell_tools_find,zprobe_late_read", "every advertised tool is sent, in name order")
    For tCall = 1:1:3 {
        Set tTools = ##class(OcuPilot.Test.TurnBudget).Sent(tCall).tools
        Do $$$AssertEquals(tTools.%ToJSON(), tFirst.%ToJSON(), "call " _ tCall _ ": the tools are the same text as call 1's")
        Do $$$AssertEquals(..Deferred(tTools, 1), "probe_found_read,zprobe_late_read", "call " _ tCall _ ": only the tools outside the starting set are deferred")
        Do $$$AssertEquals(..Deferred(tTools, 0), "shell_probe_read,shell_tools_find", "call " _ tCall _ ": the shell's tools, the search among them, are not")
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tTools.%ToJSON()), 1, "call " _ tCall _ ": one tool carries the cache marker")
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).MarkOf(tTools.%Get(2)) _ "|" _ tTools.%Get(2).name, ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL _ "|shell_tools_find", "call " _ tCall _ ": it is the last tool that is not deferred, though a deferred tool follows it")
    }
    Set tResults = ##class(OcuPilot.Test.TurnBudget).Sent(2).messages.%Get(2).content
    Do $$$AssertEquals(tResults.%Size(), 1, "call 2 carries the search's one result")
    Set tFound = tResults.%Get(0)
    Do $$$AssertEquals(tFound."tool_use_id" _ "|" _ tFound."is_error" _ "|" _ tFound.content.%ToJSON(), "toolu_find|0|[{""type"":""tool_reference"",""tool_name"":""probe_found_read""}]", "and it is the reference to the tool found, passed unwrapped")
    Set tCalled = ##class(OcuPilot.Test.TurnBudget).Sent(3).messages.%Get(4).content.%Get(0)
    Do $$$AssertEquals(tCalled."tool_use_id" _ "|" _ tCalled."is_error", "toolu_found|0", "call 3 carries the found tool's own result")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.found.read"), 1, "the found tool was dispatched once")
    Do $$$AssertEquals(..Steps(tKey), "model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;tool:probe.found.read:ok;model:provider:ok;", "and both tool steps are ok")
}

/// <p>A tool the screen context names starts undeferred (C1): the same turn with a context whose
/// <code>tools</code> names <code>probe_found_read</code> sends it without <code>defer_loading</code>,
/// and a search for it finds nothing more to reference.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.ContextTools</method> answers no names -> this goes
/// red.</p>
Method TestAToolTheScreenNamesStartsUndeferred()
{
    Do ..UseScopeTools()
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_find", "name": "shell_tools_find", "input": {"query": "found"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, "{""route"":""logs/audit"",""tools"":[""probe_found_read"",""not_a_tool""]}")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tTools = ##class(OcuPilot.Test.TurnBudget).Sent(1).tools
    Do $$$AssertEquals(..Deferred(tTools, 1), "zprobe_late_read", "only the tool neither the shell nor the screen names is deferred")
    Do $$$AssertEquals(..Deferred(tTools, 0), "probe_found_read,shell_probe_read,shell_tools_find", "the screen's tool starts with the shell's")
    Do $$$AssertEquals(tTools.%Size(), 4, "a name the registry does not advertise adds no tool")
    Set tResult = ##class(OcuPilot.Test.TurnBudget).Sent(2).messages.%Get(4).content.%Get(0)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ $Select(tResult.%GetTypeOf("content") = "string": "string", 1: "array"), "0|string", "a tool in the starting set is not referenced: the search answers its text")
    Do $$$AssertEquals($ListToString($ClassMethod(..#LOOP, "ContextTools", "{""tools"":[""a"",1,"""",""b""]}"), ","), "a,b", "ContextTools reads the context's string names and nothing else")
    Do $$$AssertEquals($ClassMethod(..#LOOP, "ContextTools", "") _ "|" _ $ClassMethod(..#LOOP, "ContextTools", "not json") _ "|" _ $ClassMethod(..#LOOP, "ContextTools", "{""tools"":""x""}"), "||", "and no name from a turn without context, an unreadable one or a tools member that is not an array")
}

/// <p>A registry without the discovery tool is sent whole (C1): no tool is deferred and the marker is
/// on the last tool, as before this story.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Scope</method> scopes without checking for the
/// discovery tool -> this goes red.</p>
Method TestARegistryWithoutTheSearchIsSentWhole()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tTools = ##class(OcuPilot.Test.TurnBudget).Sent(1).tools
    Do $$$AssertEquals(tTools.%Size(), 2, "both counting tools are sent")
    Do $$$AssertEquals(..Deferred(tTools, 1), "", "none is deferred")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tTools.%ToJSON()) _ "|" _ ##class(OcuPilot.Test.TurnBudget).MarkOf(tTools.%Get(1)), "1|" _ ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL, "and the marker is on the last tool alone")
}

/// <p>An unadvertised tool is never sent or dispatched (AD-53): the hidden fixture tool is in the
/// registry's listing, not in any request, and a call to it is answered <code>TOOL.UNKNOWN</code>
/// without the tool running.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Registry.ResolveWire</method> resolves an unadvertised
/// tool -> this goes red.</p>
Method TestAnUnadvertisedToolIsNeitherSentNorDispatched()
{
    Do ..UseScopeTools()
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_hidden", "name": "probe_hidden_read", "input": {}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Sent(1).tools.%ToJSON() [ "probe_hidden_read", 0, "no request carries the hidden tool")
    Set tResult = ##class(OcuPilot.Test.TurnBudget).Sent(2).messages.%Get(2).content.%Get(0)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tResult.content), "1|{""code"":""TOOL.UNKNOWN""}", "calling it is answered as an unknown tool")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.hidden.read"), 0, "and it never ran")
}

/// <p>The size of a starting set (C2) -- for every built screen, the production roster scoped by the
/// tools that screen names, carried as <method>OcuPilot.Kernel.Provider.ToolDefAdapter.ToOpenAi</method>
/// carries it, is at most <parameter>STARTINGSETMAX</parameter> characters, while the whole roster is
/// more. The largest set is named in the assertion text.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Provider.ToolDefAdapter.Carried</method> answers every index
/// -> this goes red.</p>
Method TestEveryBuiltScreensStartingSetFitsTheLimit()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tAll), "the production registry advertises")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors), "the screen registry lists its screens")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.tAll, .tWhole), "the whole roster is declared")
    Set tWholeLength = $Length(tWhole.%ToJSON())
    Set tBuilt = 0
    Set tLargest = 0
    Set tLargestRoute = ""
    Set tLargestTools = 0
    Set tOver = ""
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tDescriptor = $List(tDescriptors, tI)
        If '$ClassMethod(tDescriptor, "IsBuilt") Continue
        Set tBuilt = tBuilt + 1
        Kill tScoped
        Merge tScoped = tAll
        Do ##class(OcuPilot.Screen.Context).ScreenTools(tDescriptor, .tNames)
        Set tContext = {}
        Do tContext.%Set("tools", tNames)
        Do ##class(OcuPilot.Kernel.Agent.Loop).Scope(.tScoped, tContext.%ToJSON())
        Do ##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.tScoped, .tDeclarations)
        Set tLength = $Length(tDeclarations.%ToJSON())
        If tLength > tLargest {
            Set tLargest = tLength
            Set tLargestRoute = $ClassMethod(tDescriptor, "Route")
            Set tLargestTools = tDeclarations.%Size()
        }
        If tLength > ..#STARTINGSETMAX Set tOver = tOver _ " " _ $ClassMethod(tDescriptor, "Route") _ "=" _ tLength
    }
    Do $$$AssertTrue(tBuilt > 0, tBuilt _ " screens are built")
    Do $$$AssertTrue(tLargestTools > 0, "and the largest starting set names tools: " _ tLargestTools)
    Do $$$AssertEquals(tOver, "", "no built screen's starting set passes " _ ..#STARTINGSETMAX _ " characters; the largest is " _ tLargestRoute _ " at " _ tLargest _ " characters in " _ tLargestTools _ " tools, against " _ tWholeLength _ " for the whole roster")
    Do $$$AssertTrue(tWholeLength > ..#STARTINGSETMAX, "the whole roster does not fit it: " _ tWholeLength)
}

}
