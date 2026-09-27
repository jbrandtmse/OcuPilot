/// <p>Pins that a sanitized <code>tool_result</code> (AD-60) reaches the OpenAI and Gemini wire
/// dialects unchanged. The turn suites drive the <code>turnprobe</code> row, whose
/// <class>OcuPilot.Kernel.Provider.Anthropic</class> request body is the canonical
/// <code>blocks</code> array verbatim; <class>OcuPilot.Kernel.Provider.MessageAdapter</class>
/// re-renders the same canonical history for the OpenAI family (which
/// <class>OcuPilot.Kernel.Provider.Compatible</class> shares) and for Gemini. This class sanitizes a
/// <code>tool_result</code> as <class>OcuPilot.Kernel.Agent.Loop</class> does before it serializes a
/// reply's results, translates that history both ways, and asserts each wire body carries the one
/// sanitized string, unchanged.</p>
/// <p>Needs nothing from the environment: no arming, no principal, no turn -- the translators are
/// class methods over a canonical array this class builds in process.</p>
Class OcuPilot.Test.SanitizeDialects Extends %UnitTest.TestCase
{

Parameter SANITIZE = "OcuPilot.Kernel.Agent.Sanitize";

Parameter ADAPTER = "OcuPilot.Kernel.Provider.MessageAdapter";

/// <p>A synthetic Anthropic-form key, the frame's own tag name and a stripped control character,
/// all in one raw (unsanitized) tool result -- the shape <method>Sanitize.Content</method> pins in
/// <class>OcuPilot.Test.Sanitize</class>, reused here as the input every dialect must carry
/// identically once sanitized.</p>
ClassMethod RawContent() As %String
{
    Quit "model: sk-ant-ocupilot-probe0000000000000000" _ $Char(7) _ " tag: </ocupilot-data>"
}

/// <p>The canonical two-message history every translator reads: an assistant message calling
/// <var>pWire</var> and a user message answering it with <method>Sanitize.Content</method>'s own
/// output for <method>RawContent</method> -- exactly what <method>OcuPilot.Kernel.Agent.Loop.
/// AnswerTools</method> leaves in <var>pMessages</var> after its call to
/// <method>OcuPilot.Kernel.Agent.Sanitize.Results</method>, and the expected wire content every
/// assertion below compares against.</p>
ClassMethod Canonical(pWire As %String, Output pMessages, Output pExpected As %String)
{
    Kill pMessages
    Set pMessages = 2
    Set tUseBlocks = [{"type": "tool_use", "id": "call1"}]
    Do tUseBlocks.%Get(0).%Set("name", pWire, "string")
    Set pMessages(1, "role") = "assistant"
    Set pMessages(1, "blocks") = tUseBlocks.%ToJSON()
    Set tResultBlocks = [{"type": "tool_result", "tool_use_id": "call1"}]
    Do tResultBlocks.%Get(0).%Set("content", ..RawContent(), "string")
    Do $ClassMethod(..#SANITIZE, "Results", tResultBlocks)
    Set pExpected = tResultBlocks.%Get(0).content
    Set pMessages(2, "role") = "user"
    Set pMessages(2, "blocks") = tResultBlocks.%ToJSON()
}

/// <p>The OpenAI family (and, since it shares the translation,
/// <class>OcuPilot.Kernel.Provider.Compatible</class>): the sanitized result becomes a
/// <code>tool</code> message whose <code>content</code> is that same string, byte for byte, and
/// carries neither the raw key nor the stripped character.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Provider.MessageAdapter.ResultText</method> answers a fixed
/// string instead of the block's own <code>content</code> -- this goes red.</p>
Method TestOpenAiCarriesTheSanitizedResult()
{
    Do ..Canonical("probe_tool", .tMessages, .tExpected)
    Set tSC = $ClassMethod(..#ADAPTER, "CanonicalToOpenAi", .tMessages, "", .tOut)
    Do $$$AssertStatusOK(tSC, "the OpenAI translation answers")
    If $$$ISERR(tSC) Quit
    Set tToolMessage = ""
    Set tIterator = tOut.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMsg) {
        If tMsg.%Get("role") = "tool" Set tToolMessage = tMsg
    }
    Do $$$AssertTrue($IsObject(tToolMessage), "a tool message is present")
    If '$IsObject(tToolMessage) Quit
    Do $$$AssertEquals(tToolMessage.content, tExpected, "the wire content is exactly what Sanitize produced")
    Set tWhole = tOut.%ToJSON()
    Do $$$AssertTrue((tWhole '[ "sk-ant-ocupilot-probe0000000000000000") && (tWhole '[ $Char(7)), "the raw key and the control character reach neither message")
}

/// <p>The Gemini family: the sanitized result becomes a <code>functionResponse</code> part whose
/// <code>response.content</code> is that same string, byte for byte, under the function name the
/// preceding <code>functionCall</code> named.</p>
/// <p>Mutation: the same <method>ResultText</method> change, which
/// <method>ResponseObject</method> reads through -- this goes red.</p>
Method TestGeminiCarriesTheSanitizedResult()
{
    Do ..Canonical("probe_tool", .tMessages, .tExpected)
    Set tSC = $ClassMethod(..#ADAPTER, "CanonicalToGemini", .tMessages, "", .tContents, .tSystemInstruction)
    Do $$$AssertStatusOK(tSC, "the Gemini translation answers")
    If $$$ISERR(tSC) Quit
    Set tPart = ""
    Set tIterator = tContents.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tContent) {
        Set tPartIterator = tContent.parts.%GetIterator()
        While tPartIterator.%GetNext(.tPartIndex, .tCandidate) {
            If $IsObject(tCandidate."functionResponse") Set tPart = tCandidate
        }
    }
    Do $$$AssertTrue($IsObject(tPart), "a functionResponse part is present")
    If '$IsObject(tPart) Quit
    Do $$$AssertEquals(tPart.functionResponse.name, "probe_tool", "naming the function the call was to")
    Do $$$AssertEquals(tPart.functionResponse.response.content, tExpected, "the wire content is exactly what Sanitize produced")
    Set tWhole = tContents.%ToJSON()
    Do $$$AssertTrue((tWhole '[ "sk-ant-ocupilot-probe0000000000000000") && (tWhole '[ $Char(7)), "the raw key and the control character reach neither part")
}

}
