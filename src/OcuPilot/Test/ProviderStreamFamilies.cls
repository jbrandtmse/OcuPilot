/// <p>Story 11.7, adapter level, on the OpenAI, Gemini and OpenAI-compatible families: each
/// family's streamed call answers the canonical reply its plain call answers -- text, a tool call,
/// and both refusal shapes -- split input reads as the whole stream, each asks for its stream in its
/// own way, and a broken stream, an error event and a missing terminator each end
/// <code>PROVIDER.TRANSPORT</code> after one call (AD-42).</p>
/// <p>Needs a writable protected database only; see <class>OcuPilot.Test.StreamCase</class>.</p>
Class OcuPilot.Test.ProviderStreamFamilies Extends OcuPilot.Test.StreamCase
{

/// <p>The families this class covers.</p>
Parameter FAMILIES = "openai,gemini,compatible";

/// <p>Canonical parity and the snapshot-prefix property, per family, on text, a tool call and both
/// refusal shapes.</p>
/// <p>mutation: drop the <code>tool_calls</code> arguments append in
/// <method>OcuPilot.Kernel.Provider.StreamAdapter.TakeOpenAi</method> -- the openai and compatible
/// tool legs go red.</p>
Method TestEachFamilyStreamedEqualsPlain()
{
    For tI = 1:1:$Length(..#FAMILIES, ",") {
        Set tFamily = $Piece(..#FAMILIES, ",", tI)
        Do ..AssertParity(tFamily, ..TextBody(tFamily, ..ReplyText()), "text")
        Do ..AssertParity(tFamily, ..ToolBody(tFamily), "tool call")
        Do ..AssertParity(tFamily, ..RefusalBody(tFamily, 1), "refusal", 7, 0, 1)
        Do ..AssertParity(tFamily, ..RefusalBody(tFamily, 2), "second refusal shape", 7, 0, 1)
    }
}

/// <p>One-byte slices with CR LF line ends read as the unsplit stream, per family.</p>
Method TestSplitInputReadsAsTheWholeStream()
{
    For tI = 1:1:$Length(..#FAMILIES, ",") {
        Set tFamily = $Piece(..#FAMILIES, ",", tI)
        Do ..AssertParity(tFamily, ..TextBody(tFamily, ..ReplyText()), "one-byte slices with CR LF", 1, 1)
    }
}

/// <p>OpenAI and compatible bodies carry <code>stream</code> and
/// <code>stream_options.include_usage</code>; Gemini names the streaming method with
/// <code>alt=sse</code> on the same origin and changes no body member; a call with no sink sends
/// neither and keeps its URL.</p>
Method TestEachFamilyAsksForItsStreamItsOwnWay()
{
    For tFamily = "openai", "compatible" {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse(tFamily, ..TextBody(tFamily, "ok")))
        Do ..CallDirect(tFamily, ##class(OcuPilot.Test.StreamSinkProbe).%New(), 1, .tResponse, .tFault)
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "I", "UTF8"))
        Do $$$AssertEquals(tBody.%GetTypeOf("stream") _ "|" _ tBody.stream, "boolean|1", tFamily _ ": the body carries stream true")
        Do $$$AssertEquals($Select($IsObject(tBody."stream_options"): tBody."stream_options".%GetTypeOf("include_usage") _ "|" _ tBody."stream_options"."include_usage", 1: ""), "boolean|1", tFamily _ ": and asks for the usage chunk")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("acceptGzip", 1) _ "|" _ ##class(OcuPilot.Test.ProviderStub).Recorded("readRawMode", 1), "0|1", tFamily _ ": read raw and ungzipped")
        Do $$$AssertEquals(tResponse.Text, "ok", tFamily _ ": and the reply arrives")
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..TextBody(tFamily, "ok"))
        Do ..CallDirect(tFamily, "", 1, .tPlain, .tPlainFault)
        Set tPlainBody = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "I", "UTF8"))
        Do $$$AssertEquals(tPlainBody.%IsDefined("stream") _ "|" _ tPlainBody.%IsDefined("stream_options"), "0|0", tFamily _ ": a call with no sink sends neither member")
    }

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse("gemini", ..TextBody("gemini", "ok")))
    Do ..CallDirect("gemini", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 1, .tGemini, .tGeminiFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), "https://generativelanguage.googleapis.com/v1beta/models/probe-model:streamGenerateContent?alt=sse", "gemini: the streaming method with alt=sse on the same origin")
    Set tGeminiBody = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "I", "UTF8"))
    Do $$$AssertEquals(tGeminiBody.%IsDefined("stream"), 0, "gemini: and no stream member in the body")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("acceptGzip", 1) _ "|" _ ##class(OcuPilot.Test.ProviderStub).Recorded("readRawMode", 1), "0|1", "gemini: read raw and ungzipped")
    Do $$$AssertEquals(tGemini.Text, "ok", "gemini: and the reply arrives")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..TextBody("gemini", "ok"))
    Do ..CallDirect("gemini", "", 1, .tGeminiPlain, .tGeminiPlainFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), "https://generativelanguage.googleapis.com/v1beta/models/probe-model:generateContent", "gemini: a call with no sink keeps the plain method")
}

/// <p>A stream broken after its status line, one carrying an error event and one missing its
/// terminator each end <code>PROVIDER.TRANSPORT</code> after one call, per family.</p>
Method TestABrokenStreamFailsEachFamilyOnce()
{
    Set tErrorEvent = ##class(OcuPilot.Test.SseFixture).Event("", "{""error"":{""code"":500,""message"":""the vendor's own words""}}")
    For tI = 1:1:$Length(..#FAMILIES, ",") {
        Set tFamily = $Piece(..#FAMILIES, ",", tI)
        Set tSse = ..Sse(tFamily, ..TextBody(tFamily, ..ReplyText()))
        ; The terminator is the last event: [DONE], or Gemini's finish-reason chunk.
        Set tEvents = $Length(tSse, $Char(10, 10))
        Set tHead = $Piece(tSse, $Char(10, 10), 1, tEvents - 2) _ $Char(10, 10)
        Set tEnd = $Piece(tSse, $Char(10, 10), tEvents - 1) _ $Char(10, 10)
        For tCase = "break", "error", "error then end", "cut" {
            Do ##class(OcuPilot.Test.ProviderStub).Reset()
            If tCase = "break" Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tSse, 7, $Length(tSse) \ 2)
            If tCase = "error" Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tHead _ tErrorEvent)
            If tCase = "error then end" Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tHead _ tErrorEvent _ tEnd)
            If tCase = "cut" Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tHead)
            Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tSse)
            Do ..CallDirect(tFamily, ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tResponse, .tFault)
            Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, tFamily _ " " _ tCase _ ": ends PROVIDER.TRANSPORT")
            Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, tFamily _ " " _ tCase _ ": after one call")
        }
    }
}

}
