/// <p>Story 18.45's scoped tool set on the canonical (Anthropic) dialect, in process (AD-5, AD-8,
/// AD-24, AD-53): a turn whose registry holds the discovery tool sends every advertised tool,
/// byte-identical on every call, with each tool outside the starting set deferred and the cache
/// marker on the last tool that is not; a tool the model finds is answered as a
/// <code>tool_reference</code> and is called on the next step; a search that finds nothing keeps its
/// answer and the array; any advertised tool dispatches whether or not it was found; the screen
/// context's own tools start undeferred; a registry without the discovery tool is sent whole; and
/// every built screen's starting set fits the size the other dialects carry.</p>
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

/// <p>A search that finds nothing is an ordinary answer (matrix, "no match") -- the query's words
/// are carried only by the unadvertised fixture tool, so nothing is found: both calls carry the same
/// <code>tools</code> text, and the search's result is its own text, an empty row list, not a
/// <code>tool_reference</code> block.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Found</method> replaces the content even when it
/// names no tool -> this goes red.</p>
Method TestASearchThatFindsNothingKeepsItsAnswerAndTheArray()
{
    Do ..UseScopeTools()
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_find", "name": "shell_tools_find", "input": {"query": "hidden advertised"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 2, "after two provider calls")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Sent(2).tools.%ToJSON(), ##class(OcuPilot.Test.TurnBudget).Sent(1).tools.%ToJSON(), "the array is the same text on both calls")
    Set tResult = ##class(OcuPilot.Test.TurnBudget).Sent(2).messages.%Get(2).content.%Get(0)
    Do $$$AssertEquals(tResult."is_error" _ "|" _ tResult.%GetTypeOf("content"), "0|string", "the search's result is ordinary text")
    Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tResult.content))
    Do $$$AssertEquals(tAnswer.rows.%ToJSON() _ "|" _ tAnswer.rowsAvailable, "[]|0", "naming no tool: the hidden tool is not advertised, so it is not found")
    Do $$$AssertEquals(..Steps(tKey), "model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;", "and the search step is ok")
}

/// <p>Dispatch is not scoped (AD-8, C3) -- the model calls <code>probe_found_read</code>, which a
/// search found, and <code>zprobe_late_read</code>, which nothing found, in one reply: both run once,
/// both steps are ok and the two results are the same answer, so a tool outside the starting set is
/// answered as it was before this story whether or not it was reached through the search.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> refuses a call to a tool that
/// is neither in the starting set nor found -> this goes red.</p>
Method TestAnAdvertisedToolDispatchesWhetherOrNotASearchFoundIt()
{
    Do ..UseScopeTools()
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_find", "name": "shell_tools_find", "input": {"query": "found"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_found", "name": "probe_found_read", "input": {"marker": "m1"}}, {"id": "toolu_late", "name": "zprobe_late_read", "input": {"marker": "m1"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes")
    Set tResults = ##class(OcuPilot.Test.TurnBudget).Sent(3).messages.%Get(4).content
    Do $$$AssertEquals(tResults.%Size(), 2, "call 3 carries both results")
    Set tFound = tResults.%Get(0)
    Set tLate = tResults.%Get(1)
    Do $$$AssertEquals(tFound."tool_use_id" _ "|" _ tFound."is_error" _ "|" _ tLate."tool_use_id" _ "|" _ tLate."is_error", "toolu_found|0|toolu_late|0", "neither call is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tLate.content), ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tFound.content), "and the tool nothing found answers as the tool the search found")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.found.read") _ "|" _ ##class(OcuPilot.Test.DispatchTool.Counter).Calls("zprobe.late.read"), "1|1", "each ran once")
    Do $$$AssertEquals(..Steps(tKey), "model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;tool:probe.found.read:ok;tool:zprobe.late.read:ok;model:provider:ok;", "and both tool steps are ok")
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
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DispatchTool.Registry).ProviderTools(.tAdvertised), "the counting registry advertises")
    Do $$$AssertTrue(+$Get(tAdvertised) > 1, "more than one counting tool, so the last is told from the rest: " _ +$Get(tAdvertised))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tTools = ##class(OcuPilot.Test.TurnBudget).Sent(1).tools
    Do $$$AssertEquals(tTools.%Size(), +$Get(tAdvertised), "every counting tool is sent")
    Do $$$AssertEquals(..Deferred(tTools, 1), "", "none is deferred")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tTools.%ToJSON()) _ "|" _ ##class(OcuPilot.Test.TurnBudget).MarkOf(tTools.%Get(tTools.%Size() - 1)), "1|" _ ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL, "and the marker is on the last tool alone")
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
/// tools that screen names (<method>OcuPilot.Screen.Context.ScreenTools</method>, the list a turn's
/// context carries), carried as <method>OcuPilot.Kernel.Provider.ToolDefAdapter.ToOpenAi</method>
/// carries it, holds every tool the screen names and is at most <parameter>STARTINGSETMAX</parameter>
/// characters, while the whole roster is more; the largest set holds more tools than the shell's own.
/// The largest set is named in the assertion text.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Provider.ToolDefAdapter.Carried</method> answers every index
/// -> this goes red; <method>OcuPilot.Kernel.Agent.Loop.ContextTools</method> answers no names -> this
/// goes red on the screens' tools.</p>
Method TestEveryBuiltScreensStartingSetFitsTheLimit()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tAll), "the production registry advertises")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors), "the screen registry lists its screens")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.tAll, .tWhole), "the whole roster is declared")
    Set tWholeLength = $Length(tWhole.%ToJSON())
    Kill tShellOnly
    Merge tShellOnly = tAll
    Do ##class(OcuPilot.Kernel.Agent.Loop).Scope(.tShellOnly, "")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.tShellOnly, .tShellDeclarations), "the starting set of a turn with no screen is declared")
    Set tShellTools = tShellDeclarations.%Size()
    Set tBuilt = 0
    Set tLargest = 0
    Set tLargestRoute = ""
    Set tLargestTools = 0
    Set tOver = ""
    Set tMissing = ""
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tDescriptor = $List(tDescriptors, tI)
        If '$ClassMethod(tDescriptor, "IsBuilt") Continue
        Set tBuilt = tBuilt + 1
        Kill tScoped
        Merge tScoped = tAll
        Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tDescriptor, .tNames), tDescriptor _ ": the screen's tools are listed")
        Set tContext = {}
        Do tContext.%Set("tools", tNames)
        Do ##class(OcuPilot.Kernel.Agent.Loop).Scope(.tScoped, tContext.%ToJSON())
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.tScoped, .tDeclarations), tDescriptor _ ": its starting set is declared")
        Set tCarried = ","
        For tJ = 0:1:tDeclarations.%Size() - 1 Set tCarried = tCarried _ tDeclarations.%Get(tJ)."function".name _ ","
        For tJ = 0:1:tNames.%Size() - 1 If tCarried '[ ("," _ tNames.%Get(tJ) _ ",") Set tMissing = tMissing _ " " _ $ClassMethod(tDescriptor, "Route") _ ":" _ tNames.%Get(tJ)
        Set tLength = $Length(tDeclarations.%ToJSON())
        If tLength > tLargest {
            Set tLargest = tLength
            Set tLargestRoute = $ClassMethod(tDescriptor, "Route")
            Set tLargestTools = tDeclarations.%Size()
        }
        If tLength > ..#STARTINGSETMAX Set tOver = tOver _ " " _ $ClassMethod(tDescriptor, "Route") _ "=" _ tLength
    }
    Do $$$AssertTrue(tBuilt > 0, tBuilt _ " screens are built")
    Do $$$AssertEquals(tMissing, "", "every built screen's starting set carries every tool the screen names")
    Do $$$AssertTrue(tLargestTools > tShellTools, "and the largest starting set holds more than the shell's own " _ tShellTools _ " tools: " _ tLargestTools)
    Do $$$AssertEquals(tOver, "", "no built screen's starting set passes " _ ..#STARTINGSETMAX _ " characters; the largest is " _ tLargestRoute _ " at " _ tLargest _ " characters in " _ tLargestTools _ " tools, against " _ tWholeLength _ " for the whole roster")
    Do $$$AssertTrue(tWholeLength > ..#STARTINGSETMAX, "the whole roster does not fit it: " _ tWholeLength)
}

}
