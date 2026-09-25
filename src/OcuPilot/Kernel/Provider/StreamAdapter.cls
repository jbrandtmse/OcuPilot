/// <p>Assembles one family's streamed events into that family's own <b>non-streamed</b> JSON body,
/// so the adapter's unchanged <method>OcuPilot.Kernel.Provider.Base.MapResponse</method> reads a
/// streamed reply exactly as it reads a plain one (AD-42). One instance serves one attempt of one
/// call; <property>Family</property> is <code>anthropic</code>, <code>openai</code> or
/// <code>gemini</code>.</p>
/// <p><method>Take</method> consumes one server-sent event; <property>TextSoFar</property> is the
/// reply's non-thinking text so far, text blocks joined with no separator as
/// <method>OcuPilot.Kernel.Provider.Anthropic.MapResponse</method> joins them; <method>Body</method>
/// answers the assembled body and a status that is an error when the stream carried an error event
/// or ended without its terminator (<code>message_stop</code>, <code>[DONE]</code>, or a Gemini
/// <code>finishReason</code> or prompt <code>blockReason</code>).</p>
/// <p>Unknown events, unknown delta types and data that is not JSON are ignored; an unknown block
/// type is kept as it started. Nothing here raises past <method>Take</method> or
/// <method>Body</method>, and nothing does device I/O: the caller runs inside
/// <method>%Net.ChunkedReader.ReadChunk</method>.</p>
Class OcuPilot.Kernel.Provider.StreamAdapter Extends %RegisteredObject
{

/// <p><code>anthropic</code>, <code>openai</code> or <code>gemini</code>.</p>
Property Family As %String(MAXLEN = 16);

/// <p>The reply's text so far: every text the family's own mapping reads as reply text, in order,
/// and never thinking.</p>
Property TextSoFar As %String(MAXLEN = "");

/// <p>Whether the family's terminator arrived.</p>
Property Terminated As %Boolean [ InitialExpression = 0 ];

/// <p>Whether the stream carried an error event.</p>
Property Errored As %Boolean [ InitialExpression = 0 ];

/// <p>The first text of an error event, for the log.</p>
Property ErrorText As %String(MAXLEN = 2000);

/// <p>Anthropic: the <code>message_start</code> message, whose content is rebuilt from the
/// blocks. OpenAI: the first chunk's <code>id</code>, <code>created</code> and
/// <code>model</code>. Gemini: the last chunk's top-level members other than candidates.</p>
Property Head As %DynamicObject;

/// <p>Anthropic: the content blocks by index as they started.</p>
Property Blocks As %DynamicArray;

/// <p>Anthropic: per block index, the text, thinking, input JSON and signature accumulated from
/// its deltas, subscripted <code>(index, "text")</code>, <code>(index, "thinking")</code>,
/// <code>(index, "json")</code> and <code>(index, "signature")</code>.</p>
Property Accumulated [ MultiDimensional ];

/// <p>Anthropic: the <code>message_delta</code> stop reason and usage. OpenAI and Gemini: the last
/// finish reason and usage.</p>
Property StopReason As %String(MAXLEN = 64);

Property Usage As %DynamicObject;

/// <p>OpenAI: the content and refusal so far, and whether either member ever arrived.</p>
Property Content As %String(MAXLEN = "");

Property HasContent As %Boolean [ InitialExpression = 0 ];

Property Refusal As %String(MAXLEN = "");

Property HasRefusal As %Boolean [ InitialExpression = 0 ];

/// <p>OpenAI: the tool calls by their <code>index</code>, <code>(index, "id")</code>,
/// <code>(index, "type")</code>, <code>(index, "name")</code> and
/// <code>(index, "arguments")</code>.</p>
Property Calls [ MultiDimensional ];

/// <p>Gemini: the assembled parts, with consecutive plain-text parts joined.</p>
Property Parts As %DynamicArray;

/// <p>Gemini: a plain-text run not yet written into <property>Parts</property>.</p>
Property PendingText As %String(MAXLEN = "");

Property HasPending As %Boolean [ InitialExpression = 0 ];

/// <p>Gemini: whether any chunk carried a candidate, and the last prompt feedback.</p>
Property SawCandidate As %Boolean [ InitialExpression = 0 ];

Property Feedback As %DynamicObject;

/// <p>A fresh assembler for <var>pFamily</var>.</p>
Method %OnNew(pFamily As %String = "") As %Status
{
    Set ..Family = pFamily
    Set ..Head = {}
    Set ..Blocks = []
    Set ..Parts = []
    Quit $$$OK
}

/// <p>Consume one server-sent event: its name <var>pEvent</var> (<code>""</code> when the event
/// named none) and its data <var>pData</var>. Never raises.</p>
Method Take(pEvent As %String, pData As %String)
{
    Try {
        If ..Family = "anthropic" {
            Do ..TakeAnthropic(pEvent, pData)
        } ElseIf ..Family = "openai" {
            Do ..TakeOpenAi(pData)
        } ElseIf ..Family = "gemini" {
            Do ..TakeGemini(pData)
        }
    } Catch ex {
        ; A malformed event is ignored rather than failing the call: the terminator check at the
        ; end is what decides whether the stream was whole.
    }
}

/// <p>The family's non-streamed body assembled from every event taken, whole or not, and in
/// <var>pStatus</var> an error when the stream carried an error event or no terminator -- which
/// the caller, not this method, turns into a failed call.</p>
Method Body(Output pStatus As %Status) As %String
{
    Set pStatus = $$$OK
    Set tBody = ""
    Try {
        If ..Errored {
            Set pStatus = $$$ERROR($$$GeneralError, "the provider's stream carried an error event: " _ ..ErrorText)
        } ElseIf '..Terminated {
            Set pStatus = $$$ERROR($$$GeneralError, "the provider's stream ended before its terminator")
        }
        If ..Family = "anthropic" {
            Set tBody = ..AnthropicBody()
        } ElseIf ..Family = "openai" {
            Set tBody = ..OpenAiBody()
        } ElseIf ..Family = "gemini" {
            Set tBody = ..GeminiBody()
        } Else {
            Set pStatus = $$$ERROR($$$GeneralError, "no stream assembler for this family")
        }
    } Catch ex {
        Set pStatus = ex.AsStatus()
        Set tBody = ""
    }
    Quit tBody
}

/// <p>Parse <var>pData</var> as a JSON object, or answer <code>""</code>.</p>
ClassMethod Parsed(pData As %String) As %DynamicObject [ Private ]
{
    Set tParsed = ""
    Try {
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pData)
        If '$IsObject(tParsed) || 'tParsed.%IsA("%Library.DynamicObject") Set tParsed = ""
    } Catch ex {
        Set tParsed = ""
    }
    Quit tParsed
}

/// <p>Record an error event's text, once.</p>
Method NoteError(pError As %DynamicAbstractObject) [ Private ]
{
    Set ..Errored = 1
    If ..ErrorText '= "" Quit
    Set tText = ""
    If $IsObject(pError) && pError.%IsA("%Library.DynamicObject") && (pError.%GetTypeOf("message") = "string") Set tText = pError.%Get("message")
    If tText = "" Set tText = "(no message)"
    Set ..ErrorText = $Extract(tText, 1, 2000)
}

/// <p>One Anthropic Messages event.</p>
Method TakeAnthropic(pEvent As %String, pData As %String) [ Private ]
{
    Set tParsed = ..Parsed(pData)
    If '$IsObject(tParsed) Quit
    Set tType = $Select(tParsed.%GetTypeOf("type") = "string": tParsed.%Get("type"), 1: pEvent)
    If tType = "message_start" {
        If $IsObject(tParsed.message) Set ..Head = tParsed.message
        If $IsObject(..Head.usage) Set ..Usage = ..Head.usage
        Quit
    }
    If tType = "content_block_start" {
        Set tIndex = +tParsed.index
        Set tBlock = tParsed."content_block"
        If '$IsObject(tBlock) Quit
        Do ..Blocks.%Set(tIndex, tBlock)
        If tBlock.type = "text" {
            Set ..Accumulated(tIndex, "text") = $Select(tBlock.%GetTypeOf("text") = "string": tBlock.%Get("text"), 1: "")
            Set ..TextSoFar = ..TextSoFar _ ..Accumulated(tIndex, "text")
        }
        If tBlock.type = "thinking" Set ..Accumulated(tIndex, "thinking") = $Select(tBlock.%GetTypeOf("thinking") = "string": tBlock.%Get("thinking"), 1: "")
        Quit
    }
    If tType = "content_block_delta" {
        Set tIndex = +tParsed.index
        Set tDelta = tParsed.delta
        If '$IsObject(tDelta) Quit
        Set tDeltaType = tDelta.type
        If tDeltaType = "text_delta" {
            Set tPiece = tDelta.%Get("text")
            Set ..Accumulated(tIndex, "text") = $Get(..Accumulated(tIndex, "text")) _ tPiece
            Set ..TextSoFar = ..TextSoFar _ tPiece
        } ElseIf tDeltaType = "input_json_delta" {
            Set ..Accumulated(tIndex, "json") = $Get(..Accumulated(tIndex, "json")) _ tDelta.%Get("partial_json")
        } ElseIf tDeltaType = "thinking_delta" {
            Set ..Accumulated(tIndex, "thinking") = $Get(..Accumulated(tIndex, "thinking")) _ tDelta.%Get("thinking")
        } ElseIf tDeltaType = "signature_delta" {
            Set ..Accumulated(tIndex, "signature") = $Get(..Accumulated(tIndex, "signature")) _ tDelta.%Get("signature")
        }
        Quit
    }
    If tType = "message_delta" {
        If $IsObject(tParsed.delta) && (tParsed.delta.%GetTypeOf("stop_reason") = "string") Set ..StopReason = tParsed.delta.%Get("stop_reason")
        If $IsObject(tParsed.usage) {
            If '$IsObject(..Usage) Set ..Usage = {}
            Set tIterator = tParsed.usage.%GetIterator()
            While tIterator.%GetNext(.tKey, .tValue) {
                If tParsed.usage.%GetTypeOf(tKey) = "null" Continue
                Do ..Usage.%Set(tKey, tValue)
            }
        }
        Quit
    }
    If tType = "message_stop" {
        Set ..Terminated = 1
        Quit
    }
    If tType = "error" {
        Do ..NoteError(tParsed.error)
    }
}

/// <p>The Anthropic Messages body the events described.</p>
Method AnthropicBody() As %String [ Private ]
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(..Head.%ToJSON())
    Set tContent = []
    For tIndex = 0:1:(..Blocks.%Size() - 1) {
        Set tBlock = ..Blocks.%Get(tIndex)
        If '$IsObject(tBlock) Continue
        Set tType = tBlock.type
        If tType = "text" Do tBlock.%Set("text", $Get(..Accumulated(tIndex, "text")), "string")
        If tType = "thinking" Do tBlock.%Set("thinking", $Get(..Accumulated(tIndex, "thinking")), "string")
        If $Data(..Accumulated(tIndex, "signature")) Do tBlock.%Set("signature", ..Accumulated(tIndex, "signature"), "string")
        If $Data(..Accumulated(tIndex, "json")) {
            Set tJson = ..Accumulated(tIndex, "json")
            Set tInput = {}
            If $ZStrip(tJson, "<>W") '= "" Set tInput = ##class(%DynamicAbstractObject).%FromJSON(tJson)
            Do tBlock.%Set("input", tInput)
        }
        Do tContent.%Push(tBlock)
    }
    Do tBody.%Set("content", tContent)
    If ..StopReason '= "" Do tBody.%Set("stop_reason", ..StopReason, "string")
    If $IsObject(..Usage) Do tBody.%Set("usage", ..Usage)
    Quit tBody.%ToJSON()
}

/// <p>One OpenAI Chat Completions chunk, or <code>[DONE]</code>.</p>
Method TakeOpenAi(pData As %String) [ Private ]
{
    If $ZStrip(pData, "<>W") = "[DONE]" {
        Set ..Terminated = 1
        Quit
    }
    Set tParsed = ..Parsed(pData)
    If '$IsObject(tParsed) Quit
    If $IsObject(tParsed.error) {
        Do ..NoteError(tParsed.error)
        Quit
    }
    For tKey = "id", "created", "model", "system_fingerprint" {
        If '..Head.%IsDefined(tKey) && tParsed.%IsDefined(tKey) && (tParsed.%GetTypeOf(tKey) '= "null") Do ..Head.%Set(tKey, tParsed.%Get(tKey))
    }
    If $IsObject(tParsed.usage) Set ..Usage = tParsed.usage
    If '$IsObject(tParsed.choices) Quit
    Set tIterator = tParsed.choices.%GetIterator()
    While tIterator.%GetNext(.tPosition, .tChoice) {
        If '$IsObject(tChoice) Continue
        If +tChoice.index '= 0 Continue
        If tChoice.%GetTypeOf("finish_reason") = "string" Set ..StopReason = tChoice.%Get("finish_reason")
        Set tDelta = tChoice.delta
        If '$IsObject(tDelta) Continue
        If tDelta.%GetTypeOf("content") = "string" {
            Set tPiece = tDelta.%Get("content")
            Set ..Content = ..Content _ tPiece
            Set ..HasContent = 1
            Set ..TextSoFar = ..TextSoFar _ tPiece
        }
        If tDelta.%GetTypeOf("refusal") = "string" {
            Set ..Refusal = ..Refusal _ tDelta.%Get("refusal")
            Set ..HasRefusal = 1
        }
        If $IsObject(tDelta."tool_calls") {
            Set tCalls = tDelta."tool_calls".%GetIterator()
            While tCalls.%GetNext(.tCallPosition, .tCall) {
                If '$IsObject(tCall) Continue
                Set tIndex = $Select(tCall.%GetTypeOf("index") = "number": +tCall.index, 1: tCallPosition)
                If tCall.%GetTypeOf("id") = "string" Set ..Calls(tIndex, "id") = tCall.%Get("id")
                If tCall.%GetTypeOf("type") = "string" Set ..Calls(tIndex, "type") = tCall.%Get("type")
                Set tFunction = tCall.function
                If $IsObject(tFunction) {
                    If (tFunction.%GetTypeOf("name") = "string") && ($Get(..Calls(tIndex, "name")) = "") Set ..Calls(tIndex, "name") = tFunction.%Get("name")
                    If tFunction.%GetTypeOf("arguments") = "string" Set ..Calls(tIndex, "arguments") = $Get(..Calls(tIndex, "arguments")) _ tFunction.%Get("arguments")
                }
                Set ..Calls(tIndex) = 1
            }
        }
    }
}

/// <p>The Chat Completions body the chunks described.</p>
Method OpenAiBody() As %String [ Private ]
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(..Head.%ToJSON())
    Do tBody.%Set("object", "chat.completion", "string")
    Set tMessage = {"role": "assistant"}
    If ..HasContent {
        Do tMessage.%Set("content", ..Content, "string")
    } Else {
        Do tMessage.%Set("content", "", "null")
    }
    If ..HasRefusal Do tMessage.%Set("refusal", ..Refusal, "string")
    Set tIndex = ""
    Set tToolCalls = []
    For {
        Set tIndex = $Order(..Calls(tIndex))
        If tIndex = "" Quit
        Set tCall = {}
        Do tCall.%Set("id", $Get(..Calls(tIndex, "id")), "string")
        Do tCall.%Set("type", $Select($Get(..Calls(tIndex, "type")) = "": "function", 1: ..Calls(tIndex, "type")), "string")
        Set tFunction = {}
        Do tFunction.%Set("name", $Get(..Calls(tIndex, "name")), "string")
        Do tFunction.%Set("arguments", $Get(..Calls(tIndex, "arguments")), "string")
        Do tCall.%Set("function", tFunction)
        Do tToolCalls.%Push(tCall)
    }
    If tToolCalls.%Size() > 0 Do tMessage.%Set("tool_calls", tToolCalls)
    Set tChoice = {"index": 0}
    Do tChoice.%Set("message", tMessage)
    If ..StopReason '= "" {
        Do tChoice.%Set("finish_reason", ..StopReason, "string")
    } Else {
        Do tChoice.%Set("finish_reason", "", "null")
    }
    Set tChoices = []
    Do tChoices.%Push(tChoice)
    Do tBody.%Set("choices", tChoices)
    If $IsObject(..Usage) Do tBody.%Set("usage", ..Usage)
    Quit tBody.%ToJSON()
}

/// <p>One Gemini <code>streamGenerateContent</code> chunk: a whole
/// <code>GenerateContentResponse</code> carrying this chunk's parts.</p>
Method TakeGemini(pData As %String) [ Private ]
{
    Set tParsed = ..Parsed(pData)
    If '$IsObject(tParsed) Quit
    If $IsObject(tParsed.error) {
        Do ..NoteError(tParsed.error)
        Quit
    }
    If $IsObject(tParsed.usageMetadata) Set ..Usage = tParsed.usageMetadata
    For tKey = "modelVersion", "responseId" {
        If tParsed.%GetTypeOf(tKey) = "string" Do ..Head.%Set(tKey, tParsed.%Get(tKey), "string")
    }
    If $IsObject(tParsed.promptFeedback) {
        Set ..Feedback = tParsed.promptFeedback
        If tParsed.promptFeedback.%GetTypeOf("blockReason") = "string" Set ..Terminated = 1
    }
    If '$IsObject(tParsed.candidates) || (tParsed.candidates.%Size() = 0) Quit
    Set tCandidate = tParsed.candidates.%Get(0)
    If '$IsObject(tCandidate) Quit
    Set ..SawCandidate = 1
    If $IsObject(tCandidate.content) && $IsObject(tCandidate.content.parts) {
        Set tIterator = tCandidate.content.parts.%GetIterator()
        While tIterator.%GetNext(.tPosition, .tPart) {
            If '$IsObject(tPart) Continue
            Set tIsText = (tPart.%GetTypeOf("text") = "string")
            Set tThought = ((tPart.%GetTypeOf("thought") = "boolean") && tPart.%Get("thought"))
            If tIsText && 'tThought Set ..TextSoFar = ..TextSoFar _ tPart.%Get("text")
            If tIsText && (tPart.%Size() = 1) {
                Set ..PendingText = ..PendingText _ tPart.%Get("text")
                Set ..HasPending = 1
                Continue
            }
            Do ..FlushPending()
            Do ..Parts.%Push(tPart)
        }
    }
    If (tCandidate.%GetTypeOf("finishReason") = "string") && (tCandidate.%Get("finishReason") '= "") {
        Set ..StopReason = tCandidate.%Get("finishReason")
        Set ..Terminated = 1
    }
}

/// <p>Write a pending plain-text run into <property>Parts</property> as one part.</p>
Method FlushPending() [ Private ]
{
    If '..HasPending Quit
    Set tPart = {}
    Do tPart.%Set("text", ..PendingText, "string")
    Do ..Parts.%Push(tPart)
    Set ..PendingText = ""
    Set ..HasPending = 0
}

/// <p>The <code>generateContent</code> body the chunks described. A stream that carried no
/// candidate -- a prompt the model refused outright -- answers the prompt feedback alone, the shape
/// the non-streamed endpoint answers it in.</p>
Method GeminiBody() As %String [ Private ]
{
    Do ..FlushPending()
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(..Head.%ToJSON())
    If ..SawCandidate {
        Set tCandidate = {}
        Set tContent = {"role": "model"}
        Do tContent.%Set("parts", ..Parts)
        Do tCandidate.%Set("content", tContent)
        If ..StopReason '= "" Do tCandidate.%Set("finishReason", ..StopReason, "string")
        Set tCandidates = []
        Do tCandidates.%Push(tCandidate)
        Do tBody.%Set("candidates", tCandidates)
    }
    If $IsObject(..Feedback) Do tBody.%Set("promptFeedback", ..Feedback)
    If $IsObject(..Usage) Do tBody.%Set("usageMetadata", ..Usage)
    Quit tBody.%ToJSON()
}

}
