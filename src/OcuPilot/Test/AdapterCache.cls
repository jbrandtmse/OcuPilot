/// <p>Story 18.39's request and usage per provider family (AD-24, AD-31): the Anthropic adapter marks
/// the last tool and the final message's last block <code>cache_control</code> and nothing else,
/// leaves <code>system</code> a string, and reads a prompt's whole size from its usage; the OpenAI,
/// Gemini and compatible adapters send no caching field and read the prompt figure they always
/// have, whatever cached-token detail the reply carries. Each family also reports the prompt with its
/// cached part at the family's weight, which is what a turn's token bound counts.</p>
/// <p>Anthropic is driven through <class>OcuPilot.Test.ProviderStub</class> as
/// <class>OcuPilot.Test.Provider</class> drives it; the other three through the stub of their shipped
/// row, on an adapter instance directly, as <class>OcuPilot.Test.OpenAIAdapter</class>,
/// <class>OcuPilot.Test.GeminiAdapter</class> and <class>OcuPilot.Test.CompatibleAdapter</class> do.
/// <b>Live-safe</b>: it opens no socket and stores nothing.</p>
Class OcuPilot.Test.AdapterCache Extends OcuPilot.Test.AdapterCacheCase
{

/// <p>A reply carrying the cache figures matrix row 5 names: 10 input, 200 written, 3,000 read.</p>
Parameter CACHEDREPLY = "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":10,""cache_creation_input_tokens"":200,""cache_read_input_tokens"":3000,""output_tokens"":7}}";

/// <p>An OpenAI-shaped reply whose prompt figure already includes its 3,000 cached tokens.</p>
Parameter OPENAICACHED = "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""hello""},""finish_reason"":""stop""}],""usage"":{""prompt_tokens"":3210,""completion_tokens"":7,""prompt_tokens_details"":{""cached_tokens"":3000}}}";

/// <p>A Gemini reply whose prompt figure already includes its 3,000 cached tokens.</p>
Parameter GEMINICACHED = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""hello""}]},""finishReason"":""STOP""}],""usageMetadata"":{""promptTokenCount"":3210,""cachedContentTokenCount"":3000,""candidatesTokenCount"":7}}";

/// <p>C1 -- the Anthropic request marks the last tool and the final message's last block, and
/// nothing else: not an earlier tool, not an earlier block of the final message, not an earlier
/// message, and <code>system</code> stays the string it was sent as.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Provider.Anthropic.CallMessages</method> marks no tool, then
/// no message block -> this goes red on each.</p>
Method TestTheAnthropicRequestMarksTheLastToolAndTheTailAndNothingElse()
{
    Do ##class(OcuPilot.Test.Adapter).Canonical(.tMessages)
    Do ..Tools(.tTools)
    Set tSent = ..AnthropicCall(.tMessages, .tTools, ..#CACHEDREPLY, .tResponse)
    Do $$$AssertEquals(tSent.tools.%Size(), 3, "three tools are sent")
    For tI = 0:1:1 {
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).MarkOf(tSent.tools.%Get(tI)), "(none)", "tool " _ (tI + 1) _ " carries no marker")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).MarkOf(tSent.tools.%Get(2)), ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL, "the last tool carries {""type"":""ephemeral""}")
    Do $$$AssertEquals(tSent.messages.%Size(), 3, "three messages are sent")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tSent.messages.%Get(0).%ToJSON()) _ "|" _ ##class(OcuPilot.Test.TurnBudget).Marks(tSent.messages.%Get(1).%ToJSON()), "0|0", "neither of the first two messages is marked")
    Set tBlocks = tSent.messages.%Get(2).content
    Do $$$AssertEquals(tBlocks.%Size(), 3, "the final message has three blocks")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).MarkOf(tBlocks.%Get(2)), ##class(OcuPilot.Test.TurnBudget).#EPHEMERAL, "its last block carries the marker")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tBlocks.%Get(0).%ToJSON()) _ "|" _ ##class(OcuPilot.Test.TurnBudget).Marks(tBlocks.%Get(1).%ToJSON()), "0|0", "and its earlier blocks do not")
    Do $$$AssertEquals(tSent.%GetTypeOf("system") _ "|" _ tSent.system, "string|" _ ..#SYSTEMPROMPT, "system is the string it was sent as")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1)), 2, "two markers in all")

    ; A final message of plain text has no block to mark; a message of no blocks has none either.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.Provider).Messages(.tPlain)
    Set tSent = ..AnthropicCall(.tPlain, .tTools, ..#CACHEDREPLY, .tResponse)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tSent.messages.%ToJSON()) _ "|" _ ##class(OcuPilot.Test.TurnBudget).Marks(tSent.tools.%ToJSON()), "0|1", "a plain-text tail leaves the tool as the one marker")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Set tEmpty = 1
    Set tEmpty(1, "role") = "user"
    Set tEmpty(1, "blocks") = "[]"
    Set tSent = ..AnthropicCall(.tEmpty, .tTools, ..#CACHEDREPLY, .tResponse)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnBudget).Marks(tSent.messages.%ToJSON()) _ "|" _ ##class(OcuPilot.Test.TurnBudget).Marks(tSent.tools.%ToJSON()), "0|1", "a tail of no blocks is not marked and does not raise")

    ; No tools: the tail is still marked and no tool array is sent.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Kill tNone
    Set tNone = 0
    Set tSent = ..AnthropicCall(.tMessages, .tNone, ..#CACHEDREPLY, .tResponse)
    Do $$$AssertEquals(tSent.%GetTypeOf("tools") _ "|" _ ##class(OcuPilot.Test.TurnBudget).Marks(tSent.messages.%ToJSON()), "unassigned|1", "with no tools the request has none, and the tail is marked")
}

/// <p>C2 -- the OpenAI, Gemini and compatible requests carry no caching field of any family's
/// spelling.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Provider.ToolDefAdapter.ToOpenAi</method> marks its last
/// declaration -> the OpenAI and compatible legs go red.</p>
Method TestTheOtherFamiliesSendNoCachingField()
{
    Do ..Tools(.tTools)
    For tFamily = "openai", "gemini", "compatible" {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Set tReply = $Parameter($Case(tFamily, "openai": "OcuPilot.Test.OpenAIAdapter", "gemini": "OcuPilot.Test.GeminiAdapter", : "OcuPilot.Test.CompatibleAdapter"), "REPLY")
        Set tText = ..FamilyCall(tFamily, .tTools, tReply, .tResponse)
        Do $$$AssertTrue($Length(tText) > 0, tFamily _ ": a request was recorded")
        For tField = ##class(OcuPilot.Test.TurnBudget).#MARK, "cachedContent", "prompt_cache_key", "cache_creation", "cache_read" {
            Do $$$AssertEquals(tText [ tField, 0, tFamily _ ": the request carries no " _ tField)
        }
        Do $$$AssertTrue(tText [ "logs_probe3_read", tFamily _ ": and still carries its tools")
    }
}

/// <p>C4, matrix row 5 -- the Anthropic prompt figure is <code>input_tokens</code> plus the cache
/// writes and reads, a figure the reply does not carry counting 0; the OpenAI, Gemini and compatible
/// figures are the prompt counts they report, not summed again with their cached detail.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Provider.Anthropic.MapResponse</method> leaves out
/// <code>cache_read_input_tokens</code> -> the Anthropic legs go red.</p>
Method TestTheTokenFigureCountsEachFamilysPromptWhole()
{
    Do ##class(OcuPilot.Test.Provider).Messages(.tMessages)
    Do ..Tools(.tTools)
    Do ..AnthropicCall(.tMessages, .tTools, ..#CACHEDREPLY, .tResponse)
    Do $$$AssertEquals(tResponse.RequestTokens _ "|" _ tResponse.ResponseTokens, "3210|7", "anthropic, through the call: 10 + 200 + 3,000 input, 7 output")

    Set tAdapter = ##class(OcuPilot.Kernel.Provider.Anthropic).%New()
    For tCase = $ListBuild("{""input_tokens"":10,""output_tokens"":7}", 10), $ListBuild("{""input_tokens"":10,""cache_read_input_tokens"":3000}", 3010), $ListBuild("{""input_tokens"":10,""cache_creation_input_tokens"":200}", 210), $ListBuild("{""cache_creation_input_tokens"":200,""cache_read_input_tokens"":3000}", 3200), $ListBuild("{""input_tokens"":10,""cache_read_input_tokens"":null}", 10), $ListBuild("{}", 0) {
        Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
        Do $$$AssertStatusOK(tAdapter.MapResponse("{""content"":[{""type"":""text"",""text"":""x""}],""usage"":" _ $List(tCase, 1) _ "}", tResponse), "usage " _ $List(tCase, 1) _ " reads")
        Do $$$AssertEquals(tResponse.RequestTokens, $List(tCase, 2), "usage " _ $List(tCase, 1) _ " counts " _ $List(tCase, 2))
    }
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK(tAdapter.MapResponse("{""content"":[{""type"":""text"",""text"":""x""}]}", tResponse), "a reply with no usage reads")
    Do $$$AssertEquals(tResponse.RequestTokens _ "|" _ tResponse.ResponseTokens, "0|0", "and counts nothing")
    Set tAdapter = ""

    For tFamily = "openai", "gemini", "compatible" {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ..FamilyCall(tFamily, .tTools, $Case(tFamily, "gemini": ..#GEMINICACHED, : ..#OPENAICACHED), .tFamilyResponse)
        Do $$$AssertEquals(tFamilyResponse.RequestTokens _ "|" _ tFamilyResponse.ResponseTokens, "3210|7", tFamily _ ": the prompt figure is read as before, its cached detail not added")
    }
}

/// <p>C5 -- each family reports the prompt with its cached part at that family's weight
/// (<code>BoundTokens</code>), beside the whole count (<code>RequestTokens</code>): Anthropic
/// weights its cache reads at 0.1 and counts its writes whole, a fraction of a token rounds up, and
/// a figure the reply does not carry counts 0; OpenAI and Gemini weight the cached subset their prompt
/// count contains at 0.1; compatible counts the whole prompt whatever it reports.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Provider.Anthropic.MapResponse</method> weights cache reads
/// at 1 -> the Anthropic legs go red; <method>OcuPilot.Kernel.Provider.OpenAI.MapResponse</method>
/// leaves out its weight -> the OpenAI leg goes red;
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.GeminiUsage</method> leaves out the cached count
/// -> the Gemini legs go red; <parameter>OcuPilot.Kernel.Provider.Compatible.CACHEDINPUTWEIGHT</parameter>
/// removed -> the compatible leg goes red.</p>
Method TestTheBoundFigureWeighsEachFamilysCachedPrompt()
{
    Do ##class(OcuPilot.Test.Provider).Messages(.tMessages)
    Do ..Tools(.tTools)
    Do $$$AssertEquals(+$Parameter("OcuPilot.Kernel.Provider.Anthropic", "CACHEREADWEIGHT") _ "|" _ +$Parameter("OcuPilot.Kernel.Provider.OpenAI", "CACHEDINPUTWEIGHT") _ "|" _ +$Parameter("OcuPilot.Kernel.Provider.Gemini", "CACHEDINPUTWEIGHT") _ "|" _ +$Parameter("OcuPilot.Kernel.Provider.Compatible", "CACHEDINPUTWEIGHT"), ".1|.1|.1|1", "the rates: 0.1 for Anthropic, OpenAI and Gemini, 1 for compatible")

    Do ..AnthropicCall(.tMessages, .tTools, ..#CACHEDREPLY, .tResponse)
    Do $$$AssertEquals(tResponse.RequestTokens _ "|" _ tResponse.BoundTokens, "3210|510", "anthropic, through the call: 10 + 200 + 3,000 whole, 10 + 200 + 0.1 x 3,000 billed")

    Set tAdapter = ##class(OcuPilot.Kernel.Provider.Anthropic).%New()
    For tCase = $ListBuild("{""input_tokens"":10,""cache_read_input_tokens"":3000}", "3010|310"), $ListBuild("{""input_tokens"":10,""cache_creation_input_tokens"":200}", "210|210"), $ListBuild("{""cache_read_input_tokens"":3000}", "3000|300"), $ListBuild("{""cache_creation_input_tokens"":200,""cache_read_input_tokens"":3000}", "3200|500"), $ListBuild("{""input_tokens"":10,""cache_read_input_tokens"":null}", "10|10"), $ListBuild("{""input_tokens"":5,""cache_read_input_tokens"":1}", "6|6"), $ListBuild("{""cache_read_input_tokens"":15}", "15|2"), $ListBuild("{}", "0|0") {
        Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
        Do $$$AssertStatusOK(tAdapter.MapResponse("{""content"":[{""type"":""text"",""text"":""x""}],""usage"":" _ $List(tCase, 1) _ "}", tResponse), "usage " _ $List(tCase, 1) _ " reads")
        Do $$$AssertEquals(tResponse.RequestTokens _ "|" _ +tResponse.BoundTokens, $List(tCase, 2), "usage " _ $List(tCase, 1) _ " counts " _ $List(tCase, 2) _ " whole|billed")
    }
    Set tAdapter = ""

    Set tOpenAiPlain = $Replace(..#OPENAICACHED, ",""prompt_tokens_details"":{""cached_tokens"":3000}", "")
    Set tOpenAiNull = $Replace(..#OPENAICACHED, "{""cached_tokens"":3000}", "null")
    Set tGeminiPlain = $Replace(..#GEMINICACHED, """cachedContentTokenCount"":3000,", "")
    Do $$$AssertTrue((tOpenAiPlain '[ "cached_tokens") && (tOpenAiNull [ "null") && (tGeminiPlain '[ "cachedContentTokenCount"), "the uncached replies are the cached ones without their detail")
    For tCase = $ListBuild("openai", ..#OPENAICACHED, "3210|510", "3,000 cached"), $ListBuild("openai", tOpenAiPlain, "3210|3210", "no cached detail"), $ListBuild("openai", tOpenAiNull, "3210|3210", "a null detail"), $ListBuild("gemini", ..#GEMINICACHED, "3210|510", "3,000 cached"), $ListBuild("gemini", tGeminiPlain, "3210|3210", "no cached count"), $ListBuild("compatible", ..#OPENAICACHED, "3210|3210", "3,000 cached"), $ListBuild("compatible", tOpenAiPlain, "3210|3210", "no cached detail") {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ..FamilyCall($List(tCase, 1), .tTools, $List(tCase, 2), .tFamilyResponse)
        Do $$$AssertEquals(tFamilyResponse.RequestTokens _ "|" _ tFamilyResponse.BoundTokens, $List(tCase, 3), $List(tCase, 1) _ ", " _ $List(tCase, 4) _ ": whole|billed " _ $List(tCase, 3))
    }
}

/// <p>The weighted count is the whole count less the cached part plus the weight times it, rounded up
/// to a whole token; a cached part outside 0 to the whole count is clamped into it, and a weight of
/// 1 is the whole count.</p>
/// <p>Mutations: <method>OcuPilot.Kernel.Provider.Response.WeightedTokens</method> rounds down -> the
/// fraction legs go red; leaves the cached part unclamped -> the clamp legs go red.</p>
Method TestTheWeightedCountRoundsUpAndClampsTheCachedPart()
{
    For tCase = $ListBuild(3210, 3000, .1, 510), $ListBuild(6, 1, .1, 6), $ListBuild(15, 15, .1, 2), $ListBuild(10, 10, .01, 1), $ListBuild(100, 500, .1, 10), $ListBuild(100, -5, .1, 100), $ListBuild(100, 50, 1, 100), $ListBuild(100, 50, 0, 50), $ListBuild(0, 0, .1, 0), $ListBuild(-4, 3, .1, 0) {
        Set tCount = ##class(OcuPilot.Kernel.Provider.Response).WeightedTokens($List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        Do $$$AssertEquals(tCount, $List(tCase, 4), $List(tCase, 1) _ " tokens, " _ $List(tCase, 2) _ " cached, weight " _ $List(tCase, 3) _ " counts " _ $List(tCase, 4))
    }
}

}
