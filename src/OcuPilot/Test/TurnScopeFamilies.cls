/// <p>Story 18.45's scoped tool set on the dialects that send only the tools they are given
/// (OpenAI, Gemini and the OpenAI-compatible family; AD-24, AD-42): the first request carries the
/// turn's starting set, the request after a search adds each tool the search found, after the starting
/// set, and the search's own result reads as the names it found, never as a
/// <code>tool_reference</code> block. The found tool is then called and dispatched once. A search that
/// finds nothing new -- no tool, or only a tool of the starting set -- changes no later request and
/// reads as its own text.</p>
/// <p>Driven through <class>OcuPilot.Test.TurnLoopProbe</class> over
/// <class>OcuPilot.Test.ScopeTool.Registry</class>, with each family's shipped catalog row re-adapted to
/// its stub by <class>OcuPilot.Test.CatalogProbeShipped</class>, as
/// <class>OcuPilot.Test.AnthropicThinking</class> reaches Gemini. The harness is
/// <class>OcuPilot.Test.TurnToolsCase</class>'s. <b>Live-safe</b>: it spawns nothing and opens no
/// socket; it writes probe agent definitions and turn rows in OcuPilot's own database and removes
/// every one after each method.</p>
Class OcuPilot.Test.TurnScopeFamilies Extends OcuPilot.Test.TurnToolsCase
{

Parameter CATALOG = "OcuPilot.Test.CatalogProbeShipped";

Parameter REGISTRY = "OcuPilot.Test.ScopeTool.Registry";

/// <p>The endpoint the compatible family's definition holds; the shipped row has none.</p>
Parameter COMPATIBLEENDPOINT = "http://127.0.0.1:11434/v1";

/// <p>The text a search's result reads as on these dialects when it found
/// <code>probe_found_read</code>.</p>
Parameter FOUNDTEXT = "Found tools you can call from your next step: probe_found_read.";

/// <p>A Chat Completions reply that calls <var>pName</var> with the JSON text <var>pArguments</var>.</p>
ClassMethod OpenAiCall(pId As %String, pName As %String, pArguments As %String) As %String
{
    Set tFunction = {}
    Do tFunction.%Set("name", pName, "string")
    Do tFunction.%Set("arguments", pArguments, "string")
    Set tCall = {"type": "function"}
    Do tCall.%Set("id", pId, "string")
    Do tCall.%Set("function", tFunction)
    Set tMessage = {"role": "assistant", "content": ""}
    Do tMessage.%Set("tool_calls", [])
    Do tMessage."tool_calls".%Push(tCall)
    Set tChoice = {"index": 0, "finish_reason": "tool_calls"}
    Do tChoice.%Set("message", tMessage)
    Quit {"choices": [(tChoice)], "usage": {"prompt_tokens": 1, "completion_tokens": 1}}.%ToJSON()
}

/// <p>A Chat Completions reply that ends the turn with <var>pText</var>.</p>
ClassMethod OpenAiText(pText As %String) As %String
{
    Set tMessage = {"role": "assistant"}
    Do tMessage.%Set("content", pText, "string")
    Set tChoice = {"index": 0, "finish_reason": "stop"}
    Do tChoice.%Set("message", tMessage)
    Quit {"choices": [(tChoice)], "usage": {"prompt_tokens": 1, "completion_tokens": 1}}.%ToJSON()
}

/// <p>A <code>generateContent</code> reply that calls <var>pName</var> with the arguments object
/// <var>pArguments</var>.</p>
ClassMethod GeminiCall(pName As %String, pArguments As %DynamicObject) As %String
{
    Set tCall = {}
    Do tCall.%Set("name", pName, "string")
    Do tCall.%Set("args", pArguments)
    Set tPart = {}
    Do tPart.%Set("functionCall", tCall)
    Quit ..GeminiReply(tPart)
}

/// <p>A <code>generateContent</code> reply that ends the turn with <var>pText</var>.</p>
ClassMethod GeminiText(pText As %String) As %String
{
    Set tPart = {}
    Do tPart.%Set("text", pText, "string")
    Quit ..GeminiReply(tPart)
}

/// <p>A <code>generateContent</code> reply whose one candidate holds <var>pPart</var>.</p>
ClassMethod GeminiReply(pPart As %DynamicObject) As %String
{
    Set tContent = {"role": "model", "parts": []}
    Do tContent.parts.%Push(pPart)
    Set tCandidate = {"finishReason": "STOP"}
    Do tCandidate.%Set("content", tContent)
    Quit {"candidates": [(tCandidate)], "usageMetadata": {"promptTokenCount": 1, "candidatesTokenCount": 1}}.%ToJSON()
}

/// <p>The names of the tools request <var>pCall</var> declared in family <var>pFamily</var>'s
/// dialect, comma-separated, in the order the request carried them.</p>
ClassMethod Declared(pFamily As %String, pCall As %Integer) As %String
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#STUB, "Recorded", "body", pCall))
    Set tNames = ""
    If pFamily = "gemini" {
        Set tDeclarations = tBody.tools.%Get(0).functionDeclarations
        For tI = 0:1:tDeclarations.%Size() - 1 Set tNames = tNames _ $Select(tI = 0: "", 1: ",") _ tDeclarations.%Get(tI).name
        Quit tNames
    }
    For tI = 0:1:tBody.tools.%Size() - 1 Set tNames = tNames _ $Select(tI = 0: "", 1: ",") _ tBody.tools.%Get(tI)."function".name
    Quit tNames
}

/// <p>The text of request <var>pCall</var>'s tool result in family <var>pFamily</var>'s dialect: an
/// OpenAI <code>tool</code> message's content, or a Gemini <code>functionResponse</code>'s.</p>
ClassMethod ResultOf(pFamily As %String, pCall As %Integer) As %String
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#STUB, "Recorded", "body", pCall))
    Set tText = "(none)"
    If pFamily = "gemini" {
        Set tContents = tBody.contents
        For tI = 0:1:tContents.%Size() - 1 {
            Set tParts = tContents.%Get(tI).parts
            For tJ = 0:1:tParts.%Size() - 1 {
                Set tPart = tParts.%Get(tJ)
                If tPart.%GetTypeOf("functionResponse") = "object" Set tText = tPart.functionResponse.response.content
            }
        }
        Quit tText
    }
    For tI = 0:1:tBody.messages.%Size() - 1 {
        Set tMessage = tBody.messages.%Get(tI)
        If tMessage.role = "tool" Set tText = tMessage.content
    }
    Quit tText
}

/// <p>Point the loop at the scoped fixture registry and family <var>pFamily</var>'s shipped catalog
/// row, and answer the id of a probe definition on that family's stub with model <var>pModel</var>
/// and, for an endpoint that is local, <var>pEndpoint</var>.</p>
Method PrepareFamily(pFamily As %String, pModel As %String, pEndpoint As %String) As %String
{
    Do $ClassMethod(..#PORT, "SetCatalogClass", ..#CATALOG)
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#DISPATCH, "SetRegistryClass", ..#REGISTRY)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row(pFamily, .tRow), 1, "the shipped " _ pFamily _ " row is readable")
    Quit ..NewDefinition(pFamily, pModel, pEndpoint, tRow.defaultEnvVarName, (pEndpoint '= ""))
}

/// <p>Run the search-then-call turn for family <var>pFamily</var> through its stub and assert what the
/// three requests carried. <var>pCalls</var> is the two tool-call replies and <var>pDone</var> the
/// last, each in the family's dialect.</p>
Method AssertScopedTurn(pFamily As %String, pModel As %String, pEndpoint As %String, pFind As %String, pCall As %String, pDone As %String)
{
    Set tDefinition = ..PrepareFamily(pFamily, pModel, pEndpoint)
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, pFind)
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, pCall)
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, pDone)
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, "", "", tDefinition)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", pFamily _ ": the turn completes: " _ tOutcome("state") _ " " _ tOutcome("code"))
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 3, pFamily _ ": after three provider calls")
    Do $$$AssertEquals($ClassMethod(..#STUB, "ServedBy"), $Case(pFamily, "openai": "openaistub", "gemini": "geministub", : "compatiblestub"), pFamily _ ": and its own stub served them")
    Set tStart = "shell_probe_read,shell_tools_find"
    Do $$$AssertEquals(..Declared(pFamily, 1), tStart, pFamily _ ": call 1 carries the starting set alone")
    Do $$$AssertEquals(..Declared(pFamily, 2), tStart _ ",probe_found_read", pFamily _ ": call 2 adds the tool the search found, after the starting set")
    Do $$$AssertEquals(..Declared(pFamily, 3), tStart _ ",probe_found_read", pFamily _ ": and call 3 keeps it")
    Do $$$AssertEquals(..ResultOf(pFamily, 2), ..#FOUNDTEXT, pFamily _ ": the search's result names the tool it found: " _ ..ResultOf(pFamily, 2))
    For tCall = 1:1:3 {
        Set tText = $ClassMethod(..#STUB, "Recorded", "body", tCall)
        Do $$$AssertTrue((tText '[ "tool_reference") && (tText '[ "defer_loading") && (tText '[ "cache_control"), pFamily _ ": call " _ tCall _ " carries no Anthropic-only member")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.found.read"), 1, pFamily _ ": the found tool was dispatched once")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnScope).Steps(tKey), "model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;tool:probe.found.read:ok;model:provider:ok;", pFamily _ ": both tool steps are ok")
}

/// <p>OpenAI -- the Chat Completions request carries the starting set, then the found tool.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Found</method> numbers no tool as found -> this
/// goes red on call 2's tool list.</p>
Method TestOpenAiCarriesTheStartingSetThenWhatItFound()
{
    Do ..AssertScopedTurn("openai", "probe-openai-model", "", ..OpenAiCall("call_find", "shell_tools_find", "{""query"":""found""}"), ..OpenAiCall("call_found", "probe_found_read", "{""marker"":""m1""}"), ..OpenAiText("done"))
}

/// <p>A second search -- OpenAI's tool list only ever grows at its end, in the order the tools were
/// found: search 1 ("late") finds <code>zprobe_late_read</code>, which sorts last in the listing;
/// search 2 ("read") names the tools <code>probe_found_read</code>, <code>shell_probe_read</code> and
/// <code>zprobe_late_read</code>, of which only the first is new. Calls 3 and 4 therefore carry the
/// late tool before the found one, although the listing orders them the other way, and the late tool
/// keeps its place.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Found</method> numbers from 0 on every search
/// -> this goes red on call 3's tool list.</p>
Method TestASecondSearchAppendsAfterWhatTheFirstFound()
{
    Set tDefinition = ..PrepareFamily("openai", "probe-openai-model", "")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiCall("call_late", "shell_tools_find", "{""query"":""late""}"))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiCall("call_read", "shell_tools_find", "{""query"":""read""}"))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiCall("call_found", "probe_found_read", "{""marker"":""m1""}"))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiText("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, "", "", tDefinition)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes: " _ tOutcome("state") _ " " _ tOutcome("code"))
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 4, "after four provider calls")
    Set tStart = "shell_probe_read,shell_tools_find"
    Do $$$AssertEquals(..Declared("openai", 1), tStart, "call 1 carries the starting set alone")
    Do $$$AssertEquals(..Declared("openai", 2), tStart _ ",zprobe_late_read", "call 2 adds the tool the first search found")
    Do $$$AssertEquals(..Declared("openai", 3), tStart _ ",zprobe_late_read,probe_found_read", "call 3 appends the tool the second search found, after the first")
    Do $$$AssertEquals(..Declared("openai", 4), ..Declared("openai", 3), "and call 4 keeps both")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.found.read"), 1, "the found tool was dispatched once")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnScope).Steps(tKey), "model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;tool:probe.found.read:ok;model:provider:ok;", "every step is ok")
}

/// <p>A search that adds nothing -- OpenAI's tool list never shrinks and never repeats a tool: search
/// 1 ("late") finds <code>zprobe_late_read</code>; search 2 names no tool (the only tool carrying its
/// words is not advertised); search 3 ("shell") names only <code>shell_probe_read</code>, which is in
/// the starting set. Calls 3 and 4 carry exactly call 2's list, and the results of searches 2 and 3 read
/// as their own text, not as a list of tools found.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Agent.Loop.Found</method> replaces the content even when it
/// names no tool -> this goes red on call 3's result; <method>OcuPilot.Kernel.Agent.Loop.Found</method>
/// references a tool of the starting set -> this goes red on call 4's result;
/// <method>OcuPilot.Kernel.Agent.Loop.Found</method> forgets what earlier searches found -> this goes
/// red on call 3's tool list.</p>
Method TestASearchThatAddsNothingNeverChangesTheArray()
{
    Set tDefinition = ..PrepareFamily("openai", "probe-openai-model", "")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiCall("call_late", "shell_tools_find", "{""query"":""late""}"))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiCall("call_none", "shell_tools_find", "{""query"":""hidden advertised""}"))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiCall("call_start", "shell_tools_find", "{""query"":""shell""}"))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..OpenAiText("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, "", "", tDefinition)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes: " _ tOutcome("state") _ " " _ tOutcome("code"))
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 4, "after four provider calls")
    Set tStart = "shell_probe_read,shell_tools_find"
    Do $$$AssertEquals(..Declared("openai", 1), tStart, "call 1 carries the starting set alone")
    Do $$$AssertEquals(..Declared("openai", 2), tStart _ ",zprobe_late_read", "call 2 adds the tool search 1 found")
    Do $$$AssertEquals(..ResultOf("openai", 2), "Found tools you can call from your next step: zprobe_late_read.", "and names it, so the later legs are not vacuous")
    Do $$$AssertEquals(..Declared("openai", 3), ..Declared("openai", 2), "call 3, after a search that found nothing, carries the same list")
    Do $$$AssertEquals(..Declared("openai", 4), ..Declared("openai", 2), "call 4, after a search that found a tool already carried, carries it still")
    Set tNone = ..ResultOf("openai", 3)
    Do $$$AssertTrue((tNone [ """rows"":[]") && (tNone '[ "Found tools"), "search 2's result is its own empty answer: " _ tNone)
    Set tOwn = ..ResultOf("openai", 4)
    Do $$$AssertTrue((tOwn [ "shell_probe_read") && (tOwn '[ "Found tools"), "search 3's result is its own answer, not a list of tools found: " _ tOwn)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnScope).Steps(tKey), "model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;tool:shell.tools.find:ok;model:provider:ok;", "every step is ok")
}

/// <p>Gemini -- the <code>generateContent</code> request carries the starting set, then the found
/// tool, in its one <code>functionDeclarations</code> entry.</p>
Method TestGeminiCarriesTheStartingSetThenWhatItFound()
{
    Do ..AssertScopedTurn("gemini", "probe-gemini-model", "", ..GeminiCall("shell_tools_find", {"query": "found"}), ..GeminiCall("probe_found_read", {"marker": "m1"}), ..GeminiText("done"))
}

/// <p>An OpenAI-compatible server -- the request carries the starting set, then the found tool, as
/// OpenAI's does.</p>
Method TestACompatibleServerCarriesTheStartingSetThenWhatItFound()
{
    Do ..AssertScopedTurn("compatible", "probe-compatible-model", ..#COMPATIBLEENDPOINT, ..OpenAiCall("call_find", "shell_tools_find", "{""query"":""found""}"), ..OpenAiCall("call_found", "probe_found_read", "{""marker"":""m1""}"), ..OpenAiText("done"))
}

}
