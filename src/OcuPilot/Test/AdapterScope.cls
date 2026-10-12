/// <p>Story 18.45's scoped tool array per provider family (AD-24, AD-42): the Anthropic adapter sends
/// every tool, defers each one outside the turn's starting set and marks the last tool that is not
/// deferred, with the same bytes whatever the turn has found; the dialects that send only the tools
/// they are given carry the starting set, then the found tools by the number they were found under
/// (<method>OcuPilot.Kernel.Provider.ToolDefAdapter.Carried</method>), and read the discovery tool's
/// <code>tool_reference</code> result as the names it found. An array that is not scoped is built as
/// it always was.</p>
/// <p>Driven as <class>OcuPilot.Test.AdapterCache</class> drives the families, through
/// <class>OcuPilot.Test.AdapterCacheCase</class>. <b>Live-safe</b>: it opens no socket and stores
/// nothing.</p>
Class OcuPilot.Test.AdapterScope Extends OcuPilot.Test.AdapterCacheCase
{

/// <p>The members of the canonical tool array <var>pTools</var> (<method>Tools</method>'s three)
/// scoped to the tools in <var>pStart</var>, comma-separated, as the loop's
/// <method>OcuPilot.Kernel.Agent.Loop.Scope</method> leaves them.</p>
ClassMethod Scoped(ByRef pTools, pStart As %String)
{
    Set pTools("scoped") = 1
    For tI = 1:1:pTools {
        If ("," _ pStart _ ",") [ ("," _ tI _ ",") Set pTools(tI, "start") = 1
    }
}

/// <p>The names of the members of <var>pTools</var> (an Anthropic request's array) that carry
/// <var>pMember</var>, comma-separated.</p>
ClassMethod Carrying(pTools As %DynamicArray, pMember As %String) As %String
{
    Set tNames = ""
    Set tIterator = pTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If tTool.%GetTypeOf(pMember) = "unassigned" Continue
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tTool.name
    }
    Quit tNames
}

/// <p>A canonical history of one call to <code>shell_tools_find</code> and the result block
/// <var>pResultJson</var> answers it with, in <var>pMessages</var>.</p>
ClassMethod History(Output pMessages, pResultJson As %String)
{
    Kill pMessages
    Set pMessages = 3
    Set pMessages(1, "role") = "user"
    Set pMessages(1, "content") = "find a tool"
    Set pMessages(2, "role") = "assistant"
    Set pMessages(2, "blocks") = "[{""type"":""tool_use"",""id"":""call1"",""name"":""shell_tools_find"",""input"":{""query"":""users""}}]"
    Set pMessages(3, "role") = "user"
    Set pMessages(3, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""call1"",""content"":" _ pResultJson _ "}]"
}

/// <p>Anthropic -- a scoped array is sent whole: each tool outside the starting set carries
/// <code>defer_loading</code> true, the cache marker is on the last tool that is not deferred even when a
/// deferred tool follows it, and no deferred tool carries a marker. What the turn has found does not
/// change a byte of the array; an array that is not scoped has no <code>defer_loading</code> and its
/// marker on the last tool, as before.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Provider.Anthropic.MarkedTool</method> answers the last tool
/// -> this goes red on the marker; <method>OcuPilot.Kernel.Provider.Anthropic.CallMessages</method>
/// reads <code>found</code> as <code>start</code> -> this goes red on the found leg.</p>
Method TestAScopedAnthropicRequestDefersTheRestAndMarksTheLastStartingTool()
{
    Do ##class(OcuPilot.Test.Adapter).Canonical(.tMessages)
    Do ..Tools(.tCanonical)
    Do ..Scoped(.tCanonical, "1,2")
    Set tSent = ..AnthropicCall(.tMessages, .tCanonical, "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{}}", .tResponse)
    Set tTools = tSent.tools
    Do $$$AssertEquals(tTools.%Size(), 3, "every tool is sent")
    Do $$$AssertEquals(..Carrying(tTools, "defer_loading"), "logs_probe3_read", "only the tool outside the starting set is deferred")
    Do $$$AssertEquals(tTools.%Get(2).%Get("defer_loading"), 1, "as defer_loading true")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).MarkOf(tTools.%Get(1)), ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL, "the cache marker is on the last tool that is not deferred")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tTools.%ToJSON()), 1, "and on no other tool, a deferred one least of all")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1)), 2, "beside the one on the final message's last block")
    Set tScopedJson = tTools.%ToJSON()

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Set tCanonical(3, "found") = 1
    Set tFound = ..AnthropicCall(.tMessages, .tCanonical, "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{}}", .tResponse)
    Do $$$AssertEquals(tFound.tools.%ToJSON(), tScopedJson, "a tool found since changes no byte of the array")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ..Tools(.tPlain)
    Set tWhole = ..AnthropicCall(.tMessages, .tPlain, "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{}}", .tResponse)
    Do $$$AssertEquals(..Carrying(tWhole.tools, "defer_loading") _ "|" _ (tWhole.tools.%ToJSON() [ "defer_loading"), "|0", "an array that is not scoped defers nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).MarkOf(tWhole.tools.%Get(2)) _ "|" _ ##class(OcuPilot.Test.TurnBudget).Marks(tWhole.tools.%ToJSON()), ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL _ "|1", "and marks its last tool alone")
}

/// <p>The dialects that send only the tools they are given -- the starting set in array order, then
/// the found tools by the number they were found under, not by array order; an array that is not
/// scoped is carried whole. OpenAI's and Gemini's declarations are those tools, and the Gemini
/// respelling map covers them and no tool left out.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Provider.ToolDefAdapter.Carried</method> answers every index
/// -> this goes red.</p>
Method TestTheOtherDialectsCarryTheStartingSetThenWhatWasFound()
{
    Do ..Tools(.tTools)
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).Carried(.tTools), ","), "1,2,3", "an array that is not scoped is carried whole")
    Do ..Scoped(.tTools, "2")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).Carried(.tTools), ","), "2", "a scoped array that has found nothing carries the starting set")
    Set tTools(3, "found") = 1
    Set tTools(1, "found") = 2
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).Carried(.tTools), ","), "2,3,1", "then the found tools by the number they were found under")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.tTools, .tOpenAi), "OpenAI's declarations are built")
    Set tNames = ""
    For tI = 0:1:tOpenAi.%Size() - 1 Set tNames = tNames _ $Select(tI = 0: "", 1: ",") _ tOpenAi.%Get(tI)."function".name
    Do $$$AssertEquals(tNames, "logs_probe2_read,logs_probe3_read,logs_probe1_read", "and declare those tools in that order")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToGemini(.tTools, .tGemini), "Gemini's declarations are built")
    Set tNames = ""
    Set tFunctions = tGemini.%Get(0).functionDeclarations
    For tI = 0:1:tFunctions.%Size() - 1 Set tNames = tNames _ $Select(tI = 0: "", 1: ",") _ tFunctions.%Get(tI).name
    Do $$$AssertEquals(tNames, "logs_probe2_read,logs_probe3_read,logs_probe1_read", "Gemini's one entry holds the same, in that order")

    Kill tEnums
    Do ..Tools(.tEnums)
    For tI = 1, 3 Set tEnums(tI, "inputSchema") = "{""type"":""object"",""properties"":{""route"":{""type"":""string"",""enum"":["""",""a""],""description"":""the route""}},""required"":[],""additionalProperties"":false}"
    Do ..Scoped(.tEnums, "2")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).GeminiEmptyEnumArgs(.tEnums).%ToJSON(), "{}", "the respelling map names no tool the request leaves out")
    Set tEnums(3, "found") = 1
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.ToolDefAdapter).GeminiEmptyEnumArgs(.tEnums).%ToJSON(), "{""logs_probe3_read"":{""route"":""value""}}", "and names a tool once it is found")
}

/// <p>The discovery tool's result -- a non-empty array of nothing but <code>tool_reference</code>
/// blocks -- reaches OpenAI's <code>tool</code> message and Gemini's <code>functionResponse</code> as
/// the sentence naming the tools found; any other content is carried as it was: a string as it is, an
/// empty array, a mixed array or a block of another type as JSON.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Provider.MessageAdapter.ResultText</method> reads every array
/// as its JSON -> this goes red on the reference legs.</p>
Method TestAToolReferenceResultReadsAsTheNamesItFound()
{
    Set tSentence = "Found tools you can call from your next step: logs_probe2_read, logs_probe3_read."
    For tCase = $ListBuild("[{""type"":""tool_reference"",""tool_name"":""logs_probe2_read""},{""type"":""tool_reference"",""tool_name"":""logs_probe3_read""}]", tSentence), $ListBuild("[{""type"":""tool_reference"",""tool_name"":""logs_probe2_read""},{""type"":""text"",""text"":""x""}]", "[{""type"":""tool_reference"",""tool_name"":""logs_probe2_read""},{""type"":""text"",""text"":""x""}]"), $ListBuild("[{""type"":""tool_reference""}]", "[{""type"":""tool_reference""}]"), $ListBuild("[{""type"":""text"",""text"":""x""}]", "[{""type"":""text"",""text"":""x""}]"), $ListBuild("[]", "[]"), $ListBuild("""plain text""", "plain text") {
        Do ..History(.tHistory, $List(tCase, 1))
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.MessageAdapter).CanonicalToOpenAi(.tHistory, "", .tOpenAi), "OpenAI: " _ $Extract($List(tCase, 1), 1, 40) _ " translates")
        Set tOpenAiText = ""
        For tI = 0:1:tOpenAi.%Size() - 1 If tOpenAi.%Get(tI).role = "tool" Set tOpenAiText = tOpenAi.%Get(tI).content
        Do $$$AssertEquals(tOpenAiText, $List(tCase, 2), "OpenAI: the tool message for " _ $Extract($List(tCase, 1), 1, 40))
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Provider.MessageAdapter).CanonicalToGemini(.tHistory, "", .tContents, .tSystem), "Gemini: " _ $Extract($List(tCase, 1), 1, 40) _ " translates")
        Set tGeminiText = ""
        For tI = 0:1:tContents.%Size() - 1 {
            Set tParts = tContents.%Get(tI).parts
            For tJ = 0:1:tParts.%Size() - 1 If tParts.%Get(tJ).%GetTypeOf("functionResponse") = "object" Set tGeminiText = tParts.%Get(tJ).functionResponse.response.content
        }
        Do $$$AssertEquals(tGeminiText, $List(tCase, 2), "Gemini: the function response for " _ $Extract($List(tCase, 1), 1, 40))
    }
}

}
