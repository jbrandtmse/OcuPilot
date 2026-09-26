/// <p>Story 11.7, adapter level, on the Anthropic family and on the rules every family shares: a
/// streamed call answers the canonical reply a plain call answers, every text handed to the sink is
/// a whole snapshot and a prefix of the next, the request asks for a stream only when a sink is
/// passed, a retry before any status line streams the text once, and a stream that broke, carried
/// an error event or lost its terminator after a status line ends <code>PROVIDER.TRANSPORT</code>
/// with one call (AD-42).</p>
/// <p>Needs a writable protected database only; see <class>OcuPilot.Test.StreamCase</class>.</p>
Class OcuPilot.Test.ProviderStream Extends OcuPilot.Test.StreamCase
{

/// <p>Canonical parity and the snapshot-prefix property on text, a tool call whose input arrives
/// in <code>input_json_delta</code> fragments, thinking with its signature, and a refusal; thinking
/// never reaches a snapshot.</p>
/// <p>mutation: drop the <code>input_json_delta</code> branch of
/// <method>OcuPilot.Kernel.Provider.StreamAdapter.TakeAnthropic</method> -- the tool leg's parity
/// goes red.</p>
Method TestAnthropicStreamedEqualsPlain()
{
    Do ..AssertParity("anthropic", ..TextBody("anthropic", ..ReplyText()), "text")
    Do ..AssertParity("anthropic", ..ToolBody("anthropic"), "tool call")
    Set tThinking = "{""content"":[{""type"":""thinking"",""thinking"":""Let me weigh this carefully."",""signature"":""c2lnbmF0dXJlLXByb2Jl""},{""type"":""text"",""text"":""Answer first.""},{""type"":""tool_use"",""id"":""toolu_2"",""name"":""logs_errors_read"",""input"":{""maxRows"":2}}],""stop_reason"":""tool_use"",""usage"":{""input_tokens"":30,""output_tokens"":12}}"
    Do ..AssertParity("anthropic", tThinking, "thinking")
    Set tLeaked = 0
    For tI = 1:1:##class(OcuPilot.Test.StreamSinkProbe).Count() {
        If ##class(OcuPilot.Test.StreamSinkProbe).Text(tI) [ "weigh" Set tLeaked = 1
    }
    Do $$$AssertEquals(tLeaked, 0, "thinking never reaches a snapshot")
    Do ..AssertParity("anthropic", ..RefusalBody("anthropic"), "refusal")
}

/// <p>A split UTF-8 character, one-byte slices, CR LF line ends, comment lines, a keep-alive and an
/// unknown event read as the unsplit stream does.</p>
/// <p>mutation: decode each chunk in <method>OcuPilot.Kernel.Provider.StreamReader.ReadChunk</method>
/// without the carried handle (<code>$ZConvert(chunk, "I", "UTF8")</code>) -- the one-byte and
/// three-byte legs go red.</p>
Method TestSplitInputReadsAsTheWholeStream()
{
    Set tBody = ..TextBody("anthropic", ..ReplyText())
    Do ..AssertParity("anthropic", tBody, "one-byte slices", 1)
    Do ..AssertParity("anthropic", tBody, "three-byte slices with CR LF", 3, 1)
    Do ..AssertParity("anthropic", tBody, "one large slice", 100000)
}

/// <p>A call with a sink asks for a stream, with no gzip and a raw read; a call with none sends
/// neither, to the same URL with the same headers.</p>
Method TestOnlyACallWithASinkAsksForAStream()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse("anthropic", ..TextBody("anthropic", "ok")))
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 1, .tResponse, .tFault)
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "I", "UTF8"))
    Do $$$AssertEquals(tBody.%GetTypeOf("stream") _ "|" _ tBody.stream, "boolean|1", "the streamed body carries stream true")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("acceptGzip", 1) _ "|" _ ##class(OcuPilot.Test.ProviderStub).Recorded("readRawMode", 1) _ "|" _ ##class(OcuPilot.Test.ProviderStub).Recorded("streamReader", 1), "0|1|1", "and is read raw, ungzipped, through a chunk reader")
    Set tStreamedUrl = ##class(OcuPilot.Test.ProviderStub).Recorded("url", 1)
    Set tStreamedHeaders = ##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1)

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..TextBody("anthropic", "ok"))
    Do ..CallDirect("anthropic", "", 1, .tPlain, .tPlainFault)
    Set tPlainBody = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "I", "UTF8"))
    Do $$$AssertEquals(tPlainBody.%IsDefined("stream"), 0, "a call with no sink sends no stream member")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("acceptGzip", 1) _ "|" _ ##class(OcuPilot.Test.ProviderStub).Recorded("readRawMode", 1) _ "|" _ ##class(OcuPilot.Test.ProviderStub).Recorded("streamReader", 1), "1|0|0", "and reads its body as it always did")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", 1), tStreamedUrl, "to the same URL")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames", 1), tStreamedHeaders, "with the same headers")
    Do $$$AssertEquals(tPlain.Text, "ok", "and the same reply")
}

/// <p>The one wiring <method>TestOnlyACallWithASinkAsksForAStream</method> does not reach: a
/// Test-connection call through the real port (<method>OcuPilot.Port.ProviderPort.InvokeDraft</method>)
/// against a shipped streaming-capable row. <code>InvokeDraft</code> has no sink parameter to hand
/// <code>Dispatch</code>, so the request it builds -- through the real catalog lookup and the
/// family's own adapter, not the adapter called directly -- carries no <code>stream</code> member
/// and is read as an ordinary call.</p>
/// <p>mutation: in <method>OcuPilot.Port.ProviderPort.InvokeDraft</method>, pass a stream sink on
/// <code>Dispatch</code>'s trailing argument instead of leaving it unsupplied -- the streamed-body
/// assertion below goes red.</p>
Method TestATestConnectionCallCarriesNoStreamThroughTheRealPort()
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetCatalogClass("OcuPilot.Test.CatalogProbeShipped")
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSslState("present")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..TextBody("compatible", "ok"))
    Kill tValues
    Set tValues("provider") = "compatible"
    Set tValues("model") = "llama-3.3-70b-instruct"
    Set tValues("endpointUrl") = "https://192.0.2.1/v1"
    Set tValues("markedLocal") = 0
    Set tValues("credType") = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPENONE
    Set tValues("keySource") = ##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCENONE
    Set tValues("maxTokens") = 1024
    Set tValues("temperature") = 0
    Kill tMessages
    Do ##class(OcuPilot.Test.Provider).Messages(.tMessages)
    Set tSC = ##class(OcuPilot.Test.ProviderPortProbe).InvokeDraft(.tValues, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "InvokeDraft answers")
    Do $$$AssertTrue('$IsObject(tFault), "and is not refused: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the call reached the transport")
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "I", "UTF8"))
    Do $$$AssertEquals(tBody.%IsDefined("stream") _ "|" _ tBody.%IsDefined("stream_options"), "0|0", "a Test-connection call through the real port carries no stream member")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("streamReader", 1), 0, "and reads its body as an ordinary call, not through a chunk reader")
    Do $$$AssertEquals(tResponse.Text, "ok", "and the reply arrives")
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
}

/// <p>A transport failure before any status line is retried once on a fresh reader, and the text
/// arrives once: every snapshot is a prefix of the final text and the last equals it.</p>
/// <p>mutation: make <method>OcuPilot.Kernel.Provider.StreamReader.Publish</method> hand over only
/// the text added since the last hand-over (a delta) -- this goes red.</p>
Method TestARetryBeforeAnyStatusLineStreamsTheTextOnce()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse("anthropic", ..TextBody("anthropic", ..ReplyText())))
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tResponse, .tFault)
    Do $$$AssertEquals(..FaultCode(tFault), "", "the retried call succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "after one retry")
    Do $$$AssertEquals(tResponse.Text, ..ReplyText(), "with the reply's text once")
    Do ..AssertPrefixes(tResponse.Text, "the retried stream")
    Set tCount = ##class(OcuPilot.Test.StreamSinkProbe).Count()
    Do $$$AssertEquals(##class(OcuPilot.Test.StreamSinkProbe).Text(tCount), tResponse.Text, "and the last snapshot is the whole text, not twice it")
}

/// <p>A stream that broke after its status line ends <code>PROVIDER.TRANSPORT</code> after one
/// call, whatever the attempt bound.</p>
/// <p>mutation: drop <code>(+tStatus = 0)</code> from the transport-retry condition in
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> -- the <code>Calls</code> assertion goes
/// red.</p>
Method TestABreakAfterBytesIsNeverRetried()
{
    Set tSse = ..Sse("anthropic", ..TextBody("anthropic", ..ReplyText()))
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tSse, 7, $Length(tSse) \ 2)
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tSse)
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tResponse, .tFault)
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "the broken stream ends PROVIDER.TRANSPORT")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and is never retried")
    Do $$$AssertEquals(tResponse.StopReason, "error", "through the stop reason")
    Do $$$AssertTrue(##class(OcuPilot.Test.StreamSinkProbe).Count() > 0, "though text had been handed over before the break")
}

/// <p>A 2xx stream carrying an error event, and one that ended without <code>message_stop</code>,
/// each end <code>PROVIDER.TRANSPORT</code> after one call.</p>
/// <p>mutation: in <method>OcuPilot.Kernel.Provider.Base.Attempts</method>, map a 2xx body whose
/// assembly status is an error as a success -- both legs go red.</p>
Method TestAnErrorEventOrAMissingTerminatorFailsTheCall()
{
    Set tSse = ..Sse("anthropic", ..TextBody("anthropic", ..ReplyText()))
    Set tCut = $Piece(tSse, "event: message_delta", 1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, tCut _ ##class(OcuPilot.Test.SseFixture).AnthropicError())
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tErrorResponse, .tErrorFault)
    Do $$$AssertEquals(..FaultCode(tErrorFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "an in-stream error event ends PROVIDER.TRANSPORT")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "after one call")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, $Piece(tSse, "event: message_stop", 1))
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tCutResponse, .tCutFault)
    Do $$$AssertEquals(..FaultCode(tCutFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "a stream with no terminator ends PROVIDER.TRANSPORT")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "after one call")
    Do $$$AssertEquals(tCutResponse.Text, "", "and answers no reply text")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Set tEnd = "event: message_stop" _ $Piece(tSse, "event: message_stop", 2)
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, $Piece(tSse, "event: message_stop", 1) _ ##class(OcuPilot.Test.SseFixture).AnthropicError() _ tEnd)
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tEndedResponse, .tEndedFault)
    Do $$$AssertEquals(..FaultCode(tEndedFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "an error event followed by message_stop still ends PROVIDER.TRANSPORT")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "after one call")
}

/// <p>A retryable status whose JSON body reached the reader is retried on a fresh reader, and the
/// next attempt's stream reads from empty: the reply arrives once.</p>
/// <p>mutation: create the reader once, before the attempt loop of
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> -- this goes red.</p>
Method TestAStatusRetryReadsTheNextStreamFromEmpty()
{
    Set tBusy = "{""type"":""error"",""error"":{""type"":""overloaded_error"",""message"":""Overloaded""}}"
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(529, tBusy)
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse("anthropic", ..TextBody("anthropic", ..ReplyText())))
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tResponse, .tFault)
    Do $$$AssertEquals(..FaultCode(tFault), "", "the retried call succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "after one retry")
    Do $$$AssertEquals(tResponse.Text, ..ReplyText(), "with the reply's text once")
    Do ..AssertPrefixes(tResponse.Text, "the stream after a status retry")
}

/// <p>A non-2xx answer while streaming is handled as today: a retryable status is retried, and a
/// refusal carries the provider's own message whether its body reached the transport or the
/// reader. A 2xx JSON body from a server that ignored <code>stream</code> is read as a plain
/// reply.</p>
Method TestAnswersThatAreNotAStreamReadAsToday()
{
    Set tError = "{""type"":""error"",""error"":{""type"":""invalid_request_error"",""message"":""the vendor's own words""}}"
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "", 1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse("anthropic", ..TextBody("anthropic", "after a wait")))
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tRetried, .tRetriedFault)
    Do $$$AssertEquals(..FaultCode(tRetriedFault) _ "|" _ tRetried.Text, "|after a wait", "a retryable status while streaming is retried")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(400, tError)
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 3, .tRefused, .tRefusedFault)
    Do $$$AssertEquals(..FaultCode(tRefusedFault), ##class(OcuPilot.Api.Error).#PROVIDERREFUSED, "a 400 whose JSON body the reader received is PROVIDER.REFUSED")
    Do $$$AssertEquals($Select($IsObject(tRefusedFault) && $IsObject(tRefusedFault.detail): tRefusedFault.detail.providerText, 1: ""), "the vendor's own words", "carrying the provider's own message")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..TextBody("anthropic", ..ReplyText()))
    Do ..CallDirect("anthropic", ##class(OcuPilot.Test.StreamSinkProbe).%New(), 1, .tIgnored, .tIgnoredFault)
    Do $$$AssertEquals(..FaultCode(tIgnoredFault) _ "|" _ tIgnored.Text, "|" _ ..ReplyText(), "a JSON body from a server that ignored stream is read as a plain reply")
}

/// <p>A sink that raises is dropped for the rest of the call and never fails it.</p>
/// <p>mutation: remove the <code>Try</code> around the hand-over in
/// <method>OcuPilot.Kernel.Provider.StreamReader.Publish</method> -- the reader stops at the raise
/// and the call ends <code>PROVIDER.TRANSPORT</code>, so this goes red.</p>
Method TestASinkThatRaisesNeverFailsTheCall()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse("anthropic", ..TextBody("anthropic", ..ReplyText())))
    Set tSink = ##class(OcuPilot.Test.StreamSinkProbe).%New()
    Set tSink.Raise = 1
    Do ..CallDirect("anthropic", tSink, 1, .tResponse, .tFault)
    Do $$$AssertEquals(..FaultCode(tFault), "", "the call succeeds")
    Do $$$AssertEquals(tResponse.Text, ..ReplyText(), "with the whole reply")
    Do $$$AssertEquals(##class(OcuPilot.Test.StreamSinkProbe).Count(), 1, "and the sink was not handed anything after it raised")
}

/// <p>A reader whose own processing raised answers no body, even when the whole stream and its
/// terminator arrive afterwards, so a partly read reply is never mapped as one.</p>
/// <p>mutation: remove the <code>Faulted</code> check from
/// <method>OcuPilot.Kernel.Provider.StreamReader.Body</method> -- this goes red.</p>
Method TestAReaderThatRaisedAnswersNoBody()
{
    Set tBytes = $ZConvert(..Sse("anthropic", ..TextBody("anthropic", ..ReplyText())), "O", "UTF8")
    Set tReader = ##class(OcuPilot.Kernel.Provider.StreamReader).%New("anthropic", "")
    Set tAdapter = tReader.Adapter
    Set tReader.Adapter = ""
    Do tReader.ReadChunk(tBytes)
    Do $$$AssertEquals(tReader.Faulted, 1, "a raise inside the reader is caught and recorded")
    Set tReader.Adapter = tAdapter
    Do tReader.ReadChunk(tBytes)
    Do tReader.Finish()
    Set tBody = tReader.Body(.tSC)
    Do $$$AssertStatusNotOK(tSC, "and the body of record is an error, although the terminator arrived")
    Do tReader.Release()
}

}
