/// <p>Builds each family's server-sent-event stream from that family's own non-streamed body, so a
/// test can stream a reply and compare the result with the plain one. Text, thinking and tool
/// arguments are cut into <var>pPiece</var>-character deltas; every stream opens with a comment
/// line and carries a keep-alive and an event no assembler knows, which a reader must ignore.</p>
/// <p><var>pCrLf</var> ends lines with CR LF instead of LF. Nothing here opens a socket.</p>
Class OcuPilot.Test.SseFixture Extends %RegisteredObject
{

/// <p>One event: an optional <code>event:</code> line, one <code>data:</code> line, a blank
/// line.</p>
ClassMethod Event(pName As %String, pData As %String, pCrLf As %Boolean = 0) As %String
{
    Set tEol = $Select(pCrLf: $Char(13, 10), 1: $Char(10))
    Quit $Select(pName = "": "", 1: "event: " _ pName _ tEol) _ "data: " _ pData _ tEol _ tEol
}

/// <p>The opening every stream here carries: a comment line and an unknown event.</p>
ClassMethod Opening(pCrLf As %Boolean = 0) As %String
{
    Set tEol = $Select(pCrLf: $Char(13, 10), 1: $Char(10))
    Quit ": probe stream" _ tEol _ tEol _ ..Event("probe_unknown", "{""type"":""probe_unknown""}", pCrLf)
}

/// <p><var>pText</var> cut into pieces of <var>pPiece</var> characters, as a
/// <class>%DynamicArray</class>; an empty text is one empty piece.</p>
ClassMethod Pieces(pText As %String, pPiece As %Integer) As %DynamicArray
{
    Set tPieces = []
    Set tSize = $Select(pPiece < 1: 1, 1: pPiece)
    If pText = "" {
        Do tPieces.%Push("")
        Quit tPieces
    }
    For tAt = 1:tSize:$Length(pText) {
        Do tPieces.%Push($Extract(pText, tAt, tAt + tSize - 1))
    }
    Quit tPieces
}

/// <p>A copy of <var>pObject</var>.</p>
ClassMethod Copy(pObject As %DynamicAbstractObject) As %DynamicAbstractObject
{
    Quit ##class(%DynamicAbstractObject).%FromJSON(pObject.%ToJSON())
}

/// <p>The Anthropic Messages stream of the non-streamed body <var>pBody</var>: text, thinking with
/// its signature, <code>tool_use</code> with its input split across <code>input_json_delta</code>
/// fragments, any other block whole, and the stop reason -- a refusal among them -- in
/// <code>message_delta</code>.</p>
ClassMethod Anthropic(pBody As %String, pPiece As %Integer = 5, pCrLf As %Boolean = 0) As %String
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody)
    Set tSse = ..Opening(pCrLf)
    Set tMessage = {"type": "message", "role": "assistant", "content": [], "stop_reason": null, "stop_sequence": null}
    Do tMessage.%Set("id", $Select(tBody.%GetTypeOf("id") = "string": tBody.id, 1: "msg_probe"), "string")
    Do tMessage.%Set("model", $Select(tBody.%GetTypeOf("model") = "string": tBody.model, 1: "probe"), "string")
    Set tUsage = {}
    Do tUsage.%Set("input_tokens", $Select($IsObject(tBody.usage): +tBody.usage."input_tokens", 1: 0), "number")
    Do tUsage.%Set("output_tokens", 1, "number")
    Do tMessage.%Set("usage", tUsage)
    Set tStart = {"type": "message_start"}
    Do tStart.%Set("message", tMessage)
    Set tSse = tSse _ ..Event("message_start", tStart.%ToJSON(), pCrLf)
    Set tSse = tSse _ ..Event("ping", "{""type"":""ping""}", pCrLf)
    Set tIterator = tBody.content.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tBlock) {
        Set tType = tBlock.type
        Set tOpen = ..Copy(tBlock)
        Kill tDeltas
        If tType = "text" {
            Do tOpen.%Set("text", "", "string")
            Set tPieces = ..Pieces(tBlock.text, pPiece)
            For tI = 0:1:(tPieces.%Size() - 1) Set tDeltas($Increment(tDeltas)) = $ListBuild("text_delta", "text", tPieces.%Get(tI))
        } ElseIf tType = "thinking" {
            Do tOpen.%Set("thinking", "", "string")
            Do tOpen.%Remove("signature")
            Set tPieces = ..Pieces(tBlock.thinking, pPiece)
            For tI = 0:1:(tPieces.%Size() - 1) Set tDeltas($Increment(tDeltas)) = $ListBuild("thinking_delta", "thinking", tPieces.%Get(tI))
            If tBlock.%GetTypeOf("signature") = "string" Set tDeltas($Increment(tDeltas)) = $ListBuild("signature_delta", "signature", tBlock.signature)
        } ElseIf tType = "tool_use" {
            Do tOpen.%Set("input", {})
            Set tInput = $Select($IsObject(tBlock.input): tBlock.input.%ToJSON(), 1: "{}")
            Set tPieces = ..Pieces(tInput, pPiece)
            For tI = 0:1:(tPieces.%Size() - 1) Set tDeltas($Increment(tDeltas)) = $ListBuild("input_json_delta", "partial_json", tPieces.%Get(tI))
        }
        Set tBlockStart = {"type": "content_block_start"}
        Do tBlockStart.%Set("index", tIndex, "number")
        Do tBlockStart.%Set("content_block", tOpen)
        Set tSse = tSse _ ..Event("content_block_start", tBlockStart.%ToJSON(), pCrLf)
        For tI = 1:1:$Get(tDeltas) {
            Set tDelta = {}
            Do tDelta.%Set("type", $List(tDeltas(tI), 1), "string")
            Do tDelta.%Set($List(tDeltas(tI), 2), $List(tDeltas(tI), 3), "string")
            Set tEvent = {"type": "content_block_delta"}
            Do tEvent.%Set("index", tIndex, "number")
            Do tEvent.%Set("delta", tDelta)
            Set tSse = tSse _ ..Event("content_block_delta", tEvent.%ToJSON(), pCrLf)
        }
        Set tBlockStop = {"type": "content_block_stop"}
        Do tBlockStop.%Set("index", tIndex, "number")
        Set tSse = tSse _ ..Event("content_block_stop", tBlockStop.%ToJSON(), pCrLf)
    }
    Set tDelta = {"type": "message_delta", "delta": {"stop_sequence": null}}
    Do tDelta.delta.%Set("stop_reason", tBody."stop_reason", "string")
    Set tOut = {}
    Do tOut.%Set("output_tokens", $Select($IsObject(tBody.usage): +tBody.usage."output_tokens", 1: 0), "number")
    Do tDelta.%Set("usage", tOut)
    Set tSse = tSse _ ..Event("message_delta", tDelta.%ToJSON(), pCrLf)
    Quit tSse _ ..Event("message_stop", "{""type"":""message_stop""}", pCrLf)
}

/// <p>An Anthropic <code>error</code> event, as the provider sends one mid-stream.</p>
ClassMethod AnthropicError() As %String
{
    Quit ..Event("error", "{""type"":""error"",""error"":{""type"":""overloaded_error"",""message"":""Overloaded""}}")
}

/// <p>The Chat Completions chunk stream of the non-streamed body <var>pBody</var>, ending with a
/// usage chunk and <code>[DONE]</code>.</p>
ClassMethod OpenAI(pBody As %String, pPiece As %Integer = 5, pCrLf As %Boolean = 0) As %String
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody)
    Set tChoice = tBody.choices.%Get(0)
    Set tMessage = tChoice.message
    Set tSse = ..Opening(pCrLf)
    Set tSse = tSse _ ..Event("", ..OpenAIChunk(tBody, {"role": "assistant", "content": ""}).%ToJSON(), pCrLf)
    If tMessage.%GetTypeOf("content") = "string" {
        Set tPieces = ..Pieces(tMessage.content, pPiece)
        For tI = 0:1:(tPieces.%Size() - 1) {
            Set tDelta = {}
            Do tDelta.%Set("content", tPieces.%Get(tI), "string")
            Set tSse = tSse _ ..Event("", ..OpenAIChunk(tBody, tDelta).%ToJSON(), pCrLf)
        }
    }
    If tMessage.%GetTypeOf("refusal") = "string" {
        Set tPieces = ..Pieces(tMessage.refusal, pPiece)
        For tI = 0:1:(tPieces.%Size() - 1) {
            Set tDelta = {}
            Do tDelta.%Set("refusal", tPieces.%Get(tI), "string")
            Set tSse = tSse _ ..Event("", ..OpenAIChunk(tBody, tDelta).%ToJSON(), pCrLf)
        }
    }
    If $IsObject(tMessage."tool_calls") {
        Set tCalls = tMessage."tool_calls".%GetIterator()
        While tCalls.%GetNext(.tIndex, .tCall) {
            Set tFirst = {"type": "function", "function": {"arguments": ""}}
            Do tFirst.%Set("index", tIndex, "number")
            Do tFirst.%Set("id", tCall.id, "string")
            Do tFirst.function.%Set("name", tCall.function.name, "string")
            Set tDelta = {"tool_calls": []}
            Do tDelta."tool_calls".%Push(tFirst)
            Set tSse = tSse _ ..Event("", ..OpenAIChunk(tBody, tDelta).%ToJSON(), pCrLf)
            Set tPieces = ..Pieces(tCall.function.arguments, pPiece)
            For tI = 0:1:(tPieces.%Size() - 1) {
                Set tPart = {"function": {}}
                Do tPart.%Set("index", tIndex, "number")
                Do tPart.function.%Set("arguments", tPieces.%Get(tI), "string")
                Set tDelta = {"tool_calls": []}
                Do tDelta."tool_calls".%Push(tPart)
                Set tSse = tSse _ ..Event("", ..OpenAIChunk(tBody, tDelta).%ToJSON(), pCrLf)
            }
        }
    }
    Set tLast = ..OpenAIChunk(tBody, {})
    Do tLast.choices.%Get(0).%Set("finish_reason", tChoice."finish_reason", "string")
    Set tSse = tSse _ ..Event("", tLast.%ToJSON(), pCrLf)
    If $IsObject(tBody.usage) {
        Set tUsage = ..OpenAIChunk(tBody, {})
        Do tUsage.%Set("choices", [])
        Do tUsage.%Set("usage", tBody.usage)
        Set tSse = tSse _ ..Event("", tUsage.%ToJSON(), pCrLf)
    }
    Quit tSse _ ..Event("", "[DONE]", pCrLf)
}

/// <p>One Chat Completions chunk carrying <var>pDelta</var> for choice 0.</p>
ClassMethod OpenAIChunk(pBody As %DynamicObject, pDelta As %DynamicObject) As %DynamicObject
{
    Set tChunk = {"object": "chat.completion.chunk"}
    Do tChunk.%Set("id", $Select(pBody.%GetTypeOf("id") = "string": pBody.id, 1: "chatcmpl-probe"), "string")
    Do tChunk.%Set("model", $Select(pBody.%GetTypeOf("model") = "string": pBody.model, 1: "probe"), "string")
    Set tChoice = {"index": 0, "finish_reason": null}
    Do tChoice.%Set("delta", pDelta)
    Set tChoices = []
    Do tChoices.%Push(tChoice)
    Do tChunk.%Set("choices", tChoices)
    Quit tChunk
}

/// <p>The <code>streamGenerateContent?alt=sse</code> stream of the non-streamed body
/// <var>pBody</var>: each text part cut into one chunk per piece, every other part in a chunk of its
/// own, then a chunk carrying the finish reason and the usage. A body with no candidates -- a prompt
/// the model refused -- is one chunk carrying it whole.</p>
ClassMethod Gemini(pBody As %String, pPiece As %Integer = 5, pCrLf As %Boolean = 0) As %String
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pBody)
    Set tSse = ..Opening(pCrLf)
    If '$IsObject(tBody.candidates) || (tBody.candidates.%Size() = 0) {
        Quit tSse _ ..Event("", tBody.%ToJSON(), pCrLf)
    }
    Set tCandidate = tBody.candidates.%Get(0)
    Set tParts = tCandidate.content.parts.%GetIterator()
    While tParts.%GetNext(.tIndex, .tPart) {
        If (tPart.%GetTypeOf("text") = "string") && (tPart.%Size() = 1) {
            Set tPieces = ..Pieces(tPart.text, pPiece)
            For tI = 0:1:(tPieces.%Size() - 1) {
                Set tOne = {}
                Do tOne.%Set("text", tPieces.%Get(tI), "string")
                Set tSse = tSse _ ..Event("", ..GeminiChunk(tOne).%ToJSON(), pCrLf)
            }
            Continue
        }
        Set tSse = tSse _ ..Event("", ..GeminiChunk(tPart).%ToJSON(), pCrLf)
    }
    Set tLast = ..GeminiChunk("")
    Do tLast.candidates.%Get(0).%Set("finishReason", tCandidate.finishReason, "string")
    If $IsObject(tBody.usageMetadata) Do tLast.%Set("usageMetadata", tBody.usageMetadata)
    Quit tSse _ ..Event("", tLast.%ToJSON(), pCrLf)
}

/// <p>One Gemini chunk carrying <var>pPart</var>, or no part when it is <code>""</code>.</p>
ClassMethod GeminiChunk(pPart As %RawString) As %DynamicObject
{
    Set tContent = {"role": "model", "parts": []}
    If $IsObject(pPart) Do tContent.parts.%Push(pPart)
    Set tCandidate = {}
    Do tCandidate.%Set("content", tContent)
    Set tChunk = {"candidates": [], "modelVersion": "probe"}
    Do tChunk.candidates.%Push(tCandidate)
    Quit tChunk
}

}
