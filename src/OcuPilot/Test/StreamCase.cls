/// <p>What <class>OcuPilot.Test.ProviderStream</class> and
/// <class>OcuPilot.Test.ProviderStreamFamilies</class> share: each family's stub, values and
/// native reply bodies, one direct adapter call with or without a stream sink, and the parity and
/// snapshot-prefix assertions. It declares no test of its own.</p>
/// <p>Needs a writable protected database and nothing else: no socket is opened and no stored
/// definition is read, because every call is made with settings stated here, on an adapter
/// instance directly or through the port's draft path with its catalog replaced.</p>
Class OcuPilot.Test.StreamCase Extends %UnitTest.TestCase [ Abstract ]
{

/// <p>The system prompt every call sends.</p>
Parameter SYSTEMPROMPT = "you are a probe";

/// <p>A reply text carrying two- and three-byte UTF-8 characters, so a split character is
/// exercised.</p>
ClassMethod ReplyText() As %String
{
    Quit "Hello, w" _ $Char(246) _ "rld " _ $Char(8364) _ " and " _ $Char(28450, 23383) _ ", streamed in pieces."
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.StreamSinkProbe).Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.StreamSinkProbe).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Quit $$$OK
}

/// <p>The stub class that serves <var>pFamily</var> with the shipped adapter above its
/// transport.</p>
ClassMethod StubFor(pFamily As %String) As %String
{
    Quit $Case(pFamily, "anthropic": "OcuPilot.Test.ProviderStub", "openai": "OcuPilot.Test.OpenAIStub", "gemini": "OcuPilot.Test.GeminiStub", "compatible": "OcuPilot.Test.CompatibleStub", : "")
}

/// <p>The endpoint a call on <var>pFamily</var> is made to.</p>
ClassMethod EndpointFor(pFamily As %String) As %String
{
    Quit $Case(pFamily, "anthropic": "https://api.anthropic.com/v1/messages", "openai": "https://api.openai.com/v1/chat/completions", "gemini": "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent", "compatible": "https://llm.example.test/v1", : "")
}

/// <p>The value array a direct call on <var>pFamily</var> reads.</p>
ClassMethod Values(pFamily As %String, Output pValues)
{
    Kill pValues
    Set pValues("provider") = pFamily
    Set pValues("model") = "probe-model"
    Set pValues("endpointUrl") = ..EndpointFor(pFamily)
    Set pValues("markedLocal") = 0
    Set pValues("credType") = "env"
    Set pValues("envVarName") = "OCUPILOTSTREAMPROBE"
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = 1024
    Set pValues("temperature") = ""
    Set pValues("keyPrefix") = $Select(pFamily = "anthropic": "sk-ant-", 1: "")
    Set pValues("authVersion") = $Select(pFamily = "anthropic": "2023-06-01", 1: "")
    Set pValues("reasoningEffort") = ""
}

/// <p>One call on <var>pFamily</var> answered by whatever the stub has queued, streamed when
/// <var>pSink</var> is a sink. <var>pMaxAttempts</var> is the stated attempt bound.</p>
ClassMethod CallDirect(pFamily As %String, pSink As %RawString = "", pMaxAttempts As %Integer = 1, Output pResponse As OcuPilot.Kernel.Provider.Response, Output pFault As %DynamicObject, pEndpoint As %String = "") As %Status
{
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("sk-ant-ocupilotstreamprobe0000")
    Do ..Values(pFamily, .tValues)
    If pEndpoint '= "" Set tValues("endpointUrl") = pEndpoint
    Do ##class(OcuPilot.Test.Provider).Settings(.tSettings, pMaxAttempts)
    If $IsObject(pSink) Set tSettings("stream") = pSink
    Kill tMessages, tTools
    Do ##class(OcuPilot.Test.Provider).Messages(.tMessages)
    Set tAdapter = $ClassMethod(..StubFor(pFamily), "%New")
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Set tSC = tAdapter.Invoke(.tValues, .tMessages, .tTools, ..#SYSTEMPROMPT, .tSettings, .pResponse, .pFault, .tHttpStatus)
    Set tAdapter = ""
    Quit tSC
}

/// <p><var>pBody</var>, a native non-streamed body, as <var>pFamily</var>'s stream.</p>
ClassMethod Sse(pFamily As %String, pBody As %String, pPiece As %Integer = 5, pCrLf As %Boolean = 0) As %String
{
    If pFamily = "anthropic" Quit ##class(OcuPilot.Test.SseFixture).Anthropic(pBody, pPiece, pCrLf)
    If pFamily = "gemini" Quit ##class(OcuPilot.Test.SseFixture).Gemini(pBody, pPiece, pCrLf)
    Quit ##class(OcuPilot.Test.SseFixture).OpenAI(pBody, pPiece, pCrLf)
}

/// <p>A native text reply on <var>pFamily</var> carrying <var>pText</var>.</p>
ClassMethod TextBody(pFamily As %String, pText As %String) As %String
{
    If pFamily = "anthropic" {
        Set tBody = {"content": [{"type": "text"}], "stop_reason": "end_turn", "usage": {"input_tokens": 11, "output_tokens": 7}}
        Do tBody.content.%Get(0).%Set("text", pText, "string")
    } ElseIf pFamily = "gemini" {
        Set tBody = {"candidates": [{"content": {"role": "model", "parts": [{}]}, "finishReason": "STOP"}], "usageMetadata": {"promptTokenCount": 11, "candidatesTokenCount": 7}}
        Do tBody.candidates.%Get(0).content.parts.%Get(0).%Set("text", pText, "string")
    } Else {
        Set tBody = {"id": "chatcmpl-probe", "object": "chat.completion", "model": "probe-model", "choices": [{"index": 0, "message": {"role": "assistant"}, "finish_reason": "stop"}], "usage": {"prompt_tokens": 11, "completion_tokens": 7}}
        Do tBody.choices.%Get(0).message.%Set("content", pText, "string")
    }
    Quit tBody.%ToJSON()
}

/// <p>A native reply on <var>pFamily</var> carrying a preamble and one tool call whose arguments
/// hold a quoted, non-ASCII value.</p>
ClassMethod ToolBody(pFamily As %String) As %String
{
    If pFamily = "anthropic" Quit "{""content"":[{""type"":""text"",""text"":""Checking.""},{""type"":""tool_use"",""id"":""toolu_1"",""name"":""logs_errors_read"",""input"":{""maxRows"":5,""filter"":""a \""quoted\"" \u00e9 value""}}],""stop_reason"":""tool_use"",""usage"":{""input_tokens"":21,""output_tokens"":9}}"
    If pFamily = "gemini" Quit "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""Checking.""},{""functionCall"":{""name"":""logs_errors_read"",""args"":{""maxRows"":5,""filter"":""a \""quoted\"" \u00e9 value""}},""thoughtSignature"":""c2lnbmF0dXJl""}]},""finishReason"":""STOP""}],""usageMetadata"":{""promptTokenCount"":21,""candidatesTokenCount"":9}}"
    Quit "{""id"":""chatcmpl-probe"",""object"":""chat.completion"",""model"":""probe-model"",""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""Checking."",""tool_calls"":[{""id"":""call_1"",""type"":""function"",""function"":{""name"":""logs_errors_read"",""arguments"":""{\""maxRows\"":5,\""filter\"":\""a \\\""quoted\\\"" \\u00e9 value\""}""}}]},""finish_reason"":""tool_calls""}],""usage"":{""prompt_tokens"":21,""completion_tokens"":9}}"
}

/// <p>A native reply on <var>pFamily</var> that the model declined: <var>pVariant</var> 1 is the
/// family's first refusal shape, 2 its second (OpenAI <code>content_filter</code>, Gemini
/// <code>blockReason</code>).</p>
ClassMethod RefusalBody(pFamily As %String, pVariant As %Integer = 1) As %String
{
    If pFamily = "anthropic" Quit "{""content"":[{""type"":""text"",""text"":""I can""}],""stop_reason"":""refusal"",""usage"":{""input_tokens"":5,""output_tokens"":2}}"
    If pFamily = "gemini" {
        If pVariant = 2 Quit "{""promptFeedback"":{""blockReason"":""SAFETY""},""usageMetadata"":{""promptTokenCount"":5}}"
        Quit "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""partial""}]},""finishReason"":""SAFETY""}],""usageMetadata"":{""promptTokenCount"":5,""candidatesTokenCount"":1}}"
    }
    If pVariant = 2 Quit "{""id"":""chatcmpl-probe"",""object"":""chat.completion"",""model"":""probe-model"",""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""""},""finish_reason"":""content_filter""}],""usage"":{""prompt_tokens"":5,""completion_tokens"":0}}"
    Quit "{""id"":""chatcmpl-probe"",""object"":""chat.completion"",""model"":""probe-model"",""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":null,""refusal"":""I can't help with that.""},""finish_reason"":""stop""}],""usage"":{""prompt_tokens"":5,""completion_tokens"":6}}"
}

/// <p>The canonical fields a call answered, as one string, so two calls compare in one
/// assertion.</p>
ClassMethod Canonical(pResponse As OcuPilot.Kernel.Provider.Response) As %String
{
    If '$IsObject(pResponse) Quit "(no response)"
    Quit "stop=" _ pResponse.StopReason _ "|text=" _ pResponse.Text _ "|tools=" _ pResponse.ToolCallsJson _ "|content=" _ pResponse.ContentJson _ "|tokens=" _ pResponse.RequestTokens _ "/" _ pResponse.ResponseTokens
}

/// <p>The call's fault code, or <code>""</code>.</p>
ClassMethod FaultCode(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.code
}

/// <p>Assert that <var>pBody</var> on <var>pFamily</var>, streamed in <var>pSlice</var>-byte
/// slices, answers the canonical fields a plain call on it answers, and that every text the sink
/// was handed is a prefix of the next and -- unless <var>pRefusal</var>, whose final text may be the
/// vendor's refusal rather than the streamed text -- of the final text.</p>
Method AssertParity(pFamily As %String, pBody As %String, pWhat As %String, pSlice As %Integer = 7, pCrLf As %Boolean = 0, pRefusal As %Boolean = 0)
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, pBody)
    Do $$$AssertStatusOK(..CallDirect(pFamily, "", 1, .tPlain, .tPlainFault), pFamily _ " " _ pWhat _ ": the plain call returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tPlainFault), "", pFamily _ " " _ pWhat _ ": the plain call succeeds")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.StreamSinkProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, ..Sse(pFamily, pBody, 5, pCrLf), pSlice)
    Set tSink = ##class(OcuPilot.Test.StreamSinkProbe).%New()
    Do $$$AssertStatusOK(..CallDirect(pFamily, tSink, 1, .tStreamed, .tStreamedFault), pFamily _ " " _ pWhat _ ": the streamed call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("streamReader", 1), 1, pFamily _ " " _ pWhat _ ": the streamed call read through a chunk reader")
    Do $$$AssertEquals(..FaultCode(tStreamedFault), "", pFamily _ " " _ pWhat _ ": the streamed call succeeds")
    Do $$$AssertEquals(..Canonical(tStreamed), ..Canonical(tPlain), pFamily _ " " _ pWhat _ ": streamed and plain answer the same canonical reply")
    Do ..AssertPrefixes(tStreamed.Text, pFamily _ " " _ pWhat, pRefusal)
}

/// <p>Assert that every text the sink probe recorded is a prefix of the next one and of
/// <var>pFinal</var>, and that at least one was recorded when <var>pFinal</var> is not empty. With
/// <var>pRefusal</var> only the first holds.</p>
Method AssertPrefixes(pFinal As %String, pWhat As %String, pRefusal As %Boolean = 0)
{
    Set tCount = ##class(OcuPilot.Test.StreamSinkProbe).Count()
    If pRefusal Set pFinal = ##class(OcuPilot.Test.StreamSinkProbe).Text(tCount)
    If (pFinal '= "") && 'pRefusal Do $$$AssertTrue(tCount > 0, pWhat _ ": the sink was handed text")
    Set tPrior = ""
    Set tHeld = 1
    For tI = 1:1:tCount {
        Set tText = ##class(OcuPilot.Test.StreamSinkProbe).Text(tI)
        If ($Extract(tText, 1, $Length(tPrior)) '= tPrior) || ($Extract(pFinal, 1, $Length(tText)) '= tText) || ($Length(tText) <= $Length(tPrior)) Set tHeld = 0
        Set tPrior = tText
    }
    Do $$$AssertTrue(tHeld, pWhat _ ": every handed text is a longer prefix of the next and of the final text (" _ tCount _ " handed)")
}

}
