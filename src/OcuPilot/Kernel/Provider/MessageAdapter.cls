/// <p>The canonical message array in each non-canonical family's dialect, and each dialect's reply
/// back in canonical blocks (AD-42). Anthropic's shape is canonical, so this class is what a
/// second, third or fourth family's adapter translates through; the canonical family reaches none
/// of it.</p>
/// <p><b>No method here branches on a provider name.</b> Each pair is called from inside the
/// family adapter that already knows its own dialect, and that adapter is reached from its catalog
/// row's <code>adapterClass</code> column.</p>
/// <p><b>The response direction produces canonical blocks.</b>
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> pushes a reply's tool-use blocks into
/// the canonical history verbatim and reads <code>name</code> and <code>input</code> off them, so
/// a family's reply arrives here as a vendor body and leaves as
/// <code>{type: "tool_use", id, name, input}</code> with <code>input</code> an object.</p>
/// <p><b>A translation that cannot be completed returns an error <class>%Status</class></b> and
/// never raises: <method>OcuPilot.Kernel.Provider.Base.Attempts</method> turns that into a
/// <code>PROVIDER.*</code> fault and <method>OcuPilot.Kernel.Provider.Base.Invoke</method> still
/// answers <code>$$$OK</code> (AD-12, AD-39, AD-42). No status built here carries any part of a
/// vendor body, and nothing here reads
/// <property>OcuPilot.Kernel.Provider.Base.ApiKey</property> (AD-35, AD-48).</p>
/// <p><b>Correlation, and the one place the families differ.</b> A <code>tool_result</code>
/// correlates with the <b>nearest preceding</b> <code>tool_use</code> block carrying its
/// <code>tool_use_id</code>, which is unambiguous even when ids repeat across iterations, and a
/// result with no such call is an error rather than a dropped result. OpenAI carries the call id
/// itself (<code>tool_calls[].id</code>, echoed as <code>tool_call_id</code>), so the canonical id
/// passes through in both directions. A Gemini <code>functionResponse</code> carries the function
/// <b>name</b>, so the request direction resolves the id back to a name and two calls to one tool
/// stay correlated by the order their responses appear -- which holds because the canonical history
/// appends a turn's results in the order the calls were made; the reply direction synthesizes a
/// canonical id (<parameter>GEMINICALLIDPREFIX</parameter>) that the next request resolves back to
/// the same name.</p>
/// <p>Wire contracts, verified against the vendors' published references on 2026-09-18 --
/// OpenAI's Chat Completions reference and function-calling guide
/// (<code>platform.openai.com/docs/guides/function-calling</code>): a leading
/// <code>{role: "system", content}</code> message, <code>{role: "assistant", content,
/// tool_calls: [{id, type: "function", function: {name, arguments}}]}</code> with
/// <code>arguments</code> a JSON <b>string</b>, <code>{role: "tool", tool_call_id, content}</code>
/// per result, <code>finish_reason</code> one of
/// <code>stop, length, tool_calls, content_filter, function_call</code>, usage
/// <code>prompt_tokens</code> / <code>completion_tokens</code>; Gemini's
/// <code>generateContent</code> reference (<code>ai.google.dev/api/generate-content</code>):
/// <code>contents[] = {role: "user" | "model", parts[]}</code>, the system prompt in
/// <code>systemInstruction.parts[].text</code>, parts
/// <code>{functionCall: {name, args}}</code> and
/// <code>{functionResponse: {name, response}}</code>, <code>candidates[0].content.parts[]</code>
/// on the way back, <code>finishReason</code> one of
/// <code>STOP, MAX_TOKENS, SAFETY, RECITATION, BLOCKLIST, PROHIBITED_CONTENT, SPII, LANGUAGE,
/// OTHER</code>, usage <code>usageMetadata.promptTokenCount</code> /
/// <code>candidatesTokenCount</code>.</p>
Class OcuPilot.Kernel.Provider.MessageAdapter Extends %RegisteredObject
{

/// <p>Each OpenAI <code>finish_reason</code> and the canonical stop reason that says the same
/// thing, as <code>vendor:canonical</code> pairs. <code>function_call</code> is the deprecated
/// spelling of <code>tool_calls</code> and maps to the same canonical value.</p>
Parameter OPENAISTOPREASONS = "stop:end_turn,length:max_tokens,tool_calls:tool_use,function_call:tool_use,content_filter:refusal";

/// <p>Each Gemini <code>finishReason</code> and its canonical stop reason. The six that mean the
/// model would not answer -- safety, recitation, the block list, prohibited content, personal
/// information and an unsupported language -- are one canonical reason, because a caller can do
/// nothing different about them. <code>OTHER</code> is deliberately absent: an unknown reason is
/// what <parameter>DEFAULTSTOPREASON</parameter> is for.</p>
Parameter GEMINISTOPREASONS = "STOP:end_turn,MAX_TOKENS:max_tokens,SAFETY:refusal,RECITATION:refusal,BLOCKLIST:refusal,PROHIBITED_CONTENT:refusal,SPII:refusal,LANGUAGE:refusal";

/// <p>The canonical stop reason a reason outside the family's own vocabulary, and an absent one,
/// are read as. The canonical vocabulary is closed, so an unmapped value is normalized rather than
/// carried through.</p>
Parameter DEFAULTSTOPREASON = "end_turn";

/// <p>The canonical stop reason for a reply that called a tool. It is taken from the blocks where
/// the vendor's own reason said no more than that, because Gemini finishes a function call
/// <code>STOP</code>.</p>
Parameter TOOLUSESTOPREASON = "tool_use";

/// <p>The prefix a synthesized Gemini call id carries. The ordinal and the function name follow
/// it, so the id says which call it belongs to in a log and in a transcript; nothing resolves a
/// result by parsing it.</p>
Parameter GEMINICALLIDPREFIX = "geminicall";

/// <p>Translate the canonical message array <var>pMessages</var> --
/// <code>pMessages(n, "role")</code> with either <code>("content")</code> or a
/// <code>("blocks")</code> JSON array, the count in <code>pMessages</code> -- and
/// <var>pSystemPrompt</var> into <var>pMessageArray</var>, an OpenAI request's
/// <code>messages</code>.</p>
/// <p>A non-empty system prompt leads the array as a <code>system</code> message. An assistant
/// message's text blocks concatenate into <code>content</code> and its tool-use blocks become
/// <code>tool_calls</code>; a message carrying calls and no text sends <code>content</code>
/// <code>null</code>. Each <code>tool_result</code> becomes its own <code>tool</code> message, and
/// those are pushed <b>before</b> any text the same canonical message carried, because a tool
/// message must follow the assistant message that called it.</p>
/// <p>Answers an error <class>%Status</class>, with <var>pMessageArray</var> empty, for a
/// <code>tool_result</code> whose <code>tool_use_id</code> no preceding <code>tool_use</code>
/// carried: no call is made, rather than one that silently drops the result.</p>
ClassMethod CanonicalToOpenAi(ByRef pMessages, pSystemPrompt As %String = "", Output pMessageArray As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pMessageArray = []
    Try {
        If pSystemPrompt '= "" {
            Set tSystem = {}
            Do tSystem.%Set("role", "system", "string")
            Do tSystem.%Set("content", pSystemPrompt, "string")
            Do pMessageArray.%Push(tSystem)
        }
        Kill tCalled
        For tI = 1:1:+$Get(pMessages) {
            Set tRole = $Get(pMessages(tI, "role"))
            Set tBlocks = ..BlocksOf($Get(pMessages(tI, "blocks")))
            If '$IsObject(tBlocks) {
                Set tPlain = {}
                Do tPlain.%Set("role", tRole, "string")
                Do tPlain.%Set("content", $Get(pMessages(tI, "content")), "string")
                Do pMessageArray.%Push(tPlain)
                Continue
            }
            Set tText = ""
            Set tCalls = []
            Set tResults = []
            Set tIterator = tBlocks.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tBlock) {
                If '$IsObject(tBlock) Continue
                If tBlock.type = "text" {
                    Set tText = tText _ tBlock.text
                    Continue
                }
                If tBlock.type = "tool_use" {
                    Set tUseId = tBlock.id
                    If tUseId '= "" Set tCalled(tUseId) = tBlock.name
                    Set tFunction = {}
                    Do tFunction.%Set("name", tBlock.name, "string")
                    Do tFunction.%Set("arguments", ..ArgumentsText(tBlock.%Get("input")), "string")
                    Set tCall = {}
                    Do tCall.%Set("id", tBlock.id, "string")
                    Do tCall.%Set("type", "function", "string")
                    Do tCall.%Set("function", tFunction)
                    Do tCalls.%Push(tCall)
                    Continue
                }
                If tBlock.type '= "tool_result" Continue
                Set tResultId = tBlock."tool_use_id"
                If (tResultId = "") || '$Data(tCalled(tResultId)) {
                    Set tSC = ..UnmatchedResult()
                    Quit
                }
                Set tResult = {}
                Do tResult.%Set("role", "tool", "string")
                Do tResult.%Set("tool_call_id", tResultId, "string")
                Do tResult.%Set("content", ..ResultText(tBlock), "string")
                Do tResults.%Push(tResult)
            }
            If $$$ISERR(tSC) Quit
            Set tResultIterator = tResults.%GetIterator()
            While tResultIterator.%GetNext(.tResultIndex, .tResultMessage) {
                Do pMessageArray.%Push(tResultMessage)
            }
            ; A canonical message whose blocks were results alone has already been sent as those
            ; results; an empty message beside them is not a message the provider accepts.
            If (tCalls.%Size() = 0) && (tText = "") && (tResults.%Size() > 0) Continue
            Set tMessage = {}
            Do tMessage.%Set("role", tRole, "string")
            If tText '= "" {
                Do tMessage.%Set("content", tText, "string")
            } ElseIf tCalls.%Size() > 0 {
                Do tMessage.%Set("content", "", "null")
            } Else {
                Do tMessage.%Set("content", "", "string")
            }
            If tCalls.%Size() > 0 Do tMessage.%Set("tool_calls", tCalls)
            Do pMessageArray.%Push(tMessage)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pMessageArray = []
    Quit tSC
}

/// <p>Read an OpenAI reply body <var>pBody</var> into <var>pResponse</var>: the first choice's
/// text into <property>OcuPilot.Kernel.Provider.Response.Text</property>, its
/// <code>tool_calls</code> into canonical <code>tool_use</code> blocks with each
/// <code>function.arguments</code> string parsed into an <code>input</code> object, the
/// <code>finish_reason</code> mapped into the canonical vocabulary, and
/// <code>usage.prompt_tokens</code> / <code>usage.completion_tokens</code> into the two token
/// counts.</p>
/// <p>Answers an error <class>%Status</class> for a body that is not a JSON object, a body with no
/// <code>choices</code> array, a first choice carrying no <code>message</code>, and an
/// <code>arguments</code> string that will not parse as an object -- never a silent empty reply,
/// which is what a caller would otherwise hand the turn.</p>
ClassMethod OpenAiToCanonical(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tParsed = ..BodyOf(pBody, .tSC)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tParsed.choices) || 'tParsed.choices.%IsA("%Library.DynamicArray") || (tParsed.choices.%Size() = 0) {
            Set tSC = $$$ERROR($$$GeneralError, "the provider's reply carries no choices array")
            Quit
        }
        Set tChoice = tParsed.choices.%Get(0)
        If '$IsObject(tChoice) {
            Set tSC = $$$ERROR($$$GeneralError, "the provider's reply carries no first choice")
            Quit
        }
        Set tMessage = tChoice.message
        If '$IsObject(tMessage) {
            Set tSC = $$$ERROR($$$GeneralError, "the provider's first choice carries no message")
            Quit
        }
        Set tText = ""
        If tMessage.%GetTypeOf("content") = "string" Set tText = tMessage.%Get("content")
        Set tToolCalls = []
        If $IsObject(tMessage."tool_calls") && tMessage."tool_calls".%IsA("%Library.DynamicArray") {
            Set tIterator = tMessage."tool_calls".%GetIterator()
            While tIterator.%GetNext(.tIndex, .tCall) {
                If '$IsObject(tCall) Continue
                If '$IsObject(tCall.function) {
                    Set tSC = $$$ERROR($$$GeneralError, "a tool call in the provider's reply names no function")
                    Quit
                }
                Set tInput = ..ArgumentsObject(tCall.function.arguments, .tArgumentsSC)
                If $$$ISERR(tArgumentsSC) {
                    Set tSC = tArgumentsSC
                    Quit
                }
                Set tUse = {}
                Do tUse.%Set("type", "tool_use", "string")
                Do tUse.%Set("id", tCall.id, "string")
                Do tUse.%Set("name", tCall.function.name, "string")
                Do tUse.%Set("input", tInput)
                Do tToolCalls.%Push(tUse)
            }
            If $$$ISERR(tSC) Quit
        }
        Set pResponse.Text = tText
        If tToolCalls.%Size() > 0 Set pResponse.ToolCallsJson = tToolCalls.%ToJSON()
        Set pResponse.StopReason = ..StopReason(..#OPENAISTOPREASONS, tChoice."finish_reason", tToolCalls.%Size())
        If $IsObject(tParsed.usage) {
            Set pResponse.RequestTokens = +tParsed.usage."prompt_tokens"
            Set pResponse.ResponseTokens = +tParsed.usage."completion_tokens"
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Translate the same canonical message array into <var>pContents</var>, a Gemini request's
/// <code>contents</code>, and <var>pSystemInstruction</var>, its <code>systemInstruction</code>
/// (<code>""</code> when the call carries no system prompt -- an empty instruction is not the same
/// request as none).</p>
/// <p>Roles are Gemini's own two: an assistant message is <code>model</code> and everything else
/// is <code>user</code>. Tool-use blocks become <code>functionCall</code> parts; each
/// <code>tool_result</code> becomes a <code>functionResponse</code> part naming the
/// <b>function</b> its id resolves to, in the order the results appear, which is what keeps two
/// calls to one tool correlated where the dialect carries no call id.</p>
/// <p>Answers an error <class>%Status</class>, with both outputs blank, for a
/// <code>tool_result</code> whose id no preceding <code>tool_use</code> carried.</p>
ClassMethod CanonicalToGemini(ByRef pMessages, pSystemPrompt As %String = "", Output pContents As %DynamicArray, Output pSystemInstruction As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pContents = []
    Set pSystemInstruction = ""
    Try {
        If pSystemPrompt '= "" {
            Set tSystemParts = []
            Set tSystemPart = {}
            Do tSystemPart.%Set("text", pSystemPrompt, "string")
            Do tSystemParts.%Push(tSystemPart)
            Set pSystemInstruction = {}
            Do pSystemInstruction.%Set("parts", tSystemParts)
        }
        Kill tCalled
        For tI = 1:1:+$Get(pMessages) {
            Set tParts = []
            Set tBlocks = ..BlocksOf($Get(pMessages(tI, "blocks")))
            If '$IsObject(tBlocks) {
                Set tTextPart = {}
                Do tTextPart.%Set("text", $Get(pMessages(tI, "content")), "string")
                Do tParts.%Push(tTextPart)
            } Else {
                Set tIterator = tBlocks.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tBlock) {
                    If '$IsObject(tBlock) Continue
                    If tBlock.type = "text" {
                        Set tPart = {}
                        Do tPart.%Set("text", tBlock.text, "string")
                        Do tParts.%Push(tPart)
                        Continue
                    }
                    If tBlock.type = "tool_use" {
                        Set tUseId = tBlock.id
                        If tUseId '= "" Set tCalled(tUseId) = tBlock.name
                        Set tCall = {}
                        Do tCall.%Set("name", tBlock.name, "string")
                        Do tCall.%Set("args", ..ArgumentsOf(tBlock.%Get("input")))
                        Set tPart = {}
                        Do tPart.%Set("functionCall", tCall)
                        Do tParts.%Push(tPart)
                        Continue
                    }
                    If tBlock.type '= "tool_result" Continue
                    Set tResultId = tBlock."tool_use_id"
                    If (tResultId = "") || '$Data(tCalled(tResultId)) {
                        Set tSC = ..UnmatchedResult()
                        Quit
                    }
                    Set tAnswer = {}
                    Do tAnswer.%Set("response", ..ResponseObject(tBlock))
                    Do tAnswer.%Set("name", tCalled(tResultId), "string")
                    Set tPart = {}
                    Do tPart.%Set("functionResponse", tAnswer)
                    Do tParts.%Push(tPart)
                }
                If $$$ISERR(tSC) Quit
            }
            If tParts.%Size() = 0 Continue
            Set tContent = {}
            Do tContent.%Set("role", ..GeminiRole($Get(pMessages(tI, "role"))), "string")
            Do tContent.%Set("parts", tParts)
            Do pContents.%Push(tContent)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pContents = []
        Set pSystemInstruction = ""
    }
    Quit tSC
}

/// <p>Read a Gemini reply body <var>pBody</var> into <var>pResponse</var>: the first candidate's
/// text parts concatenated, each <code>functionCall</code> part as a canonical
/// <code>tool_use</code> block carrying a synthesized id, the <code>finishReason</code> mapped
/// into the canonical vocabulary, and
/// <code>usageMetadata.promptTokenCount</code> / <code>candidatesTokenCount</code> into the two
/// token counts.</p>
/// <p>Answers an error <class>%Status</class> for a body that is not a JSON object and for one
/// with no <code>candidates</code> array. A candidate that carried no parts is an empty reply and
/// not an error: the model answered, with nothing in it.</p>
ClassMethod GeminiToCanonical(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tParsed = ..BodyOf(pBody, .tSC)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tParsed.candidates) || 'tParsed.candidates.%IsA("%Library.DynamicArray") || (tParsed.candidates.%Size() = 0) {
            Set tSC = $$$ERROR($$$GeneralError, "the provider's reply carries no candidates array")
            Quit
        }
        Set tCandidate = tParsed.candidates.%Get(0)
        If '$IsObject(tCandidate) {
            Set tSC = $$$ERROR($$$GeneralError, "the provider's reply carries no first candidate")
            Quit
        }
        Set tText = ""
        Set tToolCalls = []
        If $IsObject(tCandidate.content) && $IsObject(tCandidate.content.parts) && tCandidate.content.parts.%IsA("%Library.DynamicArray") {
            Set tIterator = tCandidate.content.parts.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tPart) {
                If '$IsObject(tPart) Continue
                If tPart.%GetTypeOf("text") = "string" {
                    Set tText = tText _ tPart.%Get("text")
                    Continue
                }
                If '$IsObject(tPart.functionCall) Continue
                Set tUse = {}
                Do tUse.%Set("type", "tool_use", "string")
                Do tUse.%Set("id", ..#GEMINICALLIDPREFIX _ (tToolCalls.%Size() + 1) _ "_" _ tPart.functionCall.name, "string")
                Do tUse.%Set("name", tPart.functionCall.name, "string")
                Do tUse.%Set("input", ..ArgumentsOf(tPart.functionCall.args))
                Do tToolCalls.%Push(tUse)
            }
        }
        Set pResponse.Text = tText
        If tToolCalls.%Size() > 0 Set pResponse.ToolCallsJson = tToolCalls.%ToJSON()
        Set pResponse.StopReason = ..StopReason(..#GEMINISTOPREASONS, tCandidate.finishReason, tToolCalls.%Size())
        If $IsObject(tParsed.usageMetadata) {
            Set pResponse.RequestTokens = +tParsed.usageMetadata.promptTokenCount
            Set pResponse.ResponseTokens = +tParsed.usageMetadata.candidatesTokenCount
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The one error <class>%Status</class> an unmatched <code>tool_result</code> produces, so both
/// request directions refuse it in the same words. It names no id and no vendor text.</p>
ClassMethod UnmatchedResult() As %Status [ Private ]
{
    Quit $$$ERROR($$$GeneralError, "a tool result answers a tool call this conversation does not carry")
}

/// <p><var>pBody</var> parsed as a JSON object, or <code>""</code> with an error
/// <class>%Status</class> in <var>pSC</var>. The status names no part of the body (AD-39).</p>
ClassMethod BodyOf(pBody As %String, Output pSC As %Status) As %DynamicObject [ Private ]
{
    Set pSC = $$$OK
    Set tParsed = ""
    Try {
        Set tCandidate = ##class(%DynamicAbstractObject).%FromJSON(pBody)
        If '$IsObject(tCandidate) || 'tCandidate.%IsA("%Library.DynamicObject") {
            Set pSC = $$$ERROR($$$GeneralError, "the provider's reply is not a JSON object")
            Quit
        }
        Set tParsed = tCandidate
    } Catch ex {
        Set pSC = $$$ERROR($$$GeneralError, "the provider's reply could not be read as JSON")
    }
    Quit tParsed
}

/// <p><var>pBlocks</var> -- a canonical message's <code>blocks</code> text -- as the array it
/// holds, or <code>""</code> when the message carries none or the text is not a JSON array. A
/// message with no blocks sends its <code>content</code> string instead.</p>
ClassMethod BlocksOf(pBlocks As %String) As %DynamicArray [ Private ]
{
    Set tBlocks = ""
    Try {
        If pBlocks = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pBlocks)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tBlocks = tParsed
    } Catch ex {
        Set tBlocks = ""
    }
    Quit tBlocks
}

/// <p>A canonical <code>tool_use</code> block's <var>pInput</var> as the JSON <b>text</b> OpenAI's
/// <code>function.arguments</code> carries; <code>"{}"</code> for an input that is not an
/// object.</p>
ClassMethod ArgumentsText(pInput As %RawString = "") As %String [ Private ]
{
    If '$IsObject(pInput) Quit "{}"
    Quit pInput.%ToJSON()
}

/// <p>The same block's <var>pInput</var> as the object Gemini's <code>args</code> carries; an
/// empty object for an input that is not one.</p>
ClassMethod ArgumentsOf(pInput As %RawString = "") As %DynamicObject [ Private ]
{
    Set tArgs = {}
    If $IsObject(pInput) Set tArgs = pInput
    Quit tArgs
}

/// <p>An OpenAI <code>function.arguments</code> value as the canonical <code>input</code> object.
/// An empty or absent value is an empty object -- a tool called with no arguments -- and anything
/// else that is not a JSON object is an error <class>%Status</class> in <var>pSC</var>, which names
/// no part of the value.</p>
ClassMethod ArgumentsObject(pArguments As %RawString = "", Output pSC As %Status) As %DynamicObject [ Private ]
{
    Set pSC = $$$OK
    Set tInput = ""
    Try {
        If $IsObject(pArguments) {
            Set tInput = pArguments
            Quit
        }
        If $ZStrip(pArguments, "<>WC") = "" {
            Set tInput = {}
            Quit
        }
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pArguments)
        If '$IsObject(tParsed) || 'tParsed.%IsA("%Library.DynamicObject") {
            Set pSC = $$$ERROR($$$GeneralError, "a tool call's arguments are not a JSON object")
            Quit
        }
        Set tInput = tParsed
    } Catch ex {
        Set pSC = $$$ERROR($$$GeneralError, "a tool call's arguments could not be read as JSON")
    }
    Quit tInput
}

/// <p>A canonical <code>tool_result</code> block's content as the string OpenAI's
/// <code>tool</code> message carries.</p>
ClassMethod ResultText(pBlock As %DynamicObject) As %String [ Private ]
{
    Set tContent = pBlock.%Get("content")
    If $IsObject(tContent) Quit tContent.%ToJSON()
    Quit tContent
}

/// <p>The same content as the object Gemini's <code>functionResponse.response</code> requires,
/// which is an object and never a bare string -- so the result text travels under one declared
/// member name.</p>
ClassMethod ResponseObject(pBlock As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tResponse = {}
    Do tResponse.%Set("content", ..ResultText(pBlock), "string")
    Quit tResponse
}

/// <p>The Gemini role for the canonical role <var>pRole</var>: <code>model</code> for the
/// assistant, <code>user</code> for everything else, because those are the only two the dialect
/// admits.</p>
ClassMethod GeminiRole(pRole As %String = "") As %String [ Private ]
{
    If pRole = "assistant" Quit "model"
    Quit "user"
}

/// <p>The canonical stop reason for the vendor reason <var>pReason</var>, read through
/// <var>pMap</var> -- one of the two <code>vendor:canonical</code> parameters. An unmapped or
/// absent reason answers <parameter>DEFAULTSTOPREASON</parameter>.</p>
/// <p><var>pToolCalls</var> above zero answers <parameter>TOOLUSESTOPREASON</parameter> only where
/// the vendor's reason mapped to no more than <parameter>DEFAULTSTOPREASON</parameter>, which is
/// the Gemini case this override exists for. A reply that called a tool and was <b>also</b>
/// truncated or filtered keeps the reason that says so, because that is the reason a caller can
/// act on.</p>
ClassMethod StopReason(pMap As %String, pReason As %String = "", pToolCalls As %Integer = 0) As %String [ Private ]
{
    Set tCanonical = ""
    For tI = 1:1:$Length(pMap, ",") {
        Set tPair = $Piece(pMap, ",", tI)
        If $Piece(tPair, ":", 1) '= pReason Continue
        Set tCanonical = $Piece(tPair, ":", 2)
        Quit
    }
    If tCanonical = "" Set tCanonical = ..#DEFAULTSTOPREASON
    If (+pToolCalls > 0) && (tCanonical = ..#DEFAULTSTOPREASON) Quit ..#TOOLUSESTOPREASON
    Quit tCanonical
}

}
