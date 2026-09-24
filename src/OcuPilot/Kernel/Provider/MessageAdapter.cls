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
/// passes through in both directions. Gemini's <code>functionCall</code> and
/// <code>functionResponse</code> carry a required <code>name</code> and an <b>optional</b>
/// <code>id</code> (DW-1180): where a reply's call carried one, the canonical block keeps it and
/// the next request carries it on <b>both</b> parts -- the replayed <code>functionCall</code> and
/// the <code>functionResponse</code> answering it -- which is what the vendor's function-calling
/// guide instructs and what keeps the pair correlated inside one request. Where a reply's call carried none, the reply direction
/// synthesizes a canonical id (<parameter>GEMINICALLIDPREFIX</parameter>) that the next request
/// resolves back to the same name and does <b>not</b> echo, since it means nothing to the
/// provider; two calls to one tool then stay correlated by the order their responses appear, which
/// holds because the canonical history appends a turn's results in the order the calls were
/// made.</p>
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
/// <code>{functionCall: {id?, name, args}}</code> and
/// <code>{functionResponse: {id?, name, response}}</code>,
/// <code>candidates[0].content.parts[]</code> on the way back, <code>finishReason</code> one of
/// <code>STOP, MAX_TOKENS, SAFETY, RECITATION, BLOCKLIST, PROHIBITED_CONTENT, SPII, LANGUAGE,
/// MALFORMED_FUNCTION_CALL, UNEXPECTED_TOOL_CALL, TOO_MANY_TOOL_CALLS, IMAGE_SAFETY,
/// OTHER</code>, usage <code>usageMetadata.promptTokenCount</code> /
/// <code>candidatesTokenCount</code>.</p>
/// <p><b>Either dialect can answer 200 with a refusal rather than a reply</b>: OpenAI under
/// <code>choices[0].message.refusal</code> beside a null <code>content</code>, Gemini under a
/// top-level <code>promptFeedback.blockReason</code> with no candidates at all. Both become the
/// canonical <code>refusal</code> stop reason carrying the vendor's own reason as the reply
/// text.</p>
Class OcuPilot.Kernel.Provider.MessageAdapter Extends %RegisteredObject
{

/// <p>Each OpenAI <code>finish_reason</code> and the canonical stop reason that says the same
/// thing, as <code>vendor:canonical</code> pairs. <code>function_call</code> is the deprecated
/// spelling of <code>tool_calls</code> and maps to the same canonical value.</p>
Parameter OPENAISTOPREASONS = "stop:end_turn,length:max_tokens,tool_calls:tool_use,function_call:tool_use,content_filter:refusal";

/// <p>Each Gemini <code>finishReason</code> and its canonical stop reason: twelve entries, of which
/// the ten that mean the model would not answer -- safety, image safety, recitation, the block
/// list, prohibited content, personal information, an unsupported language, and the three that
/// refuse a tool call (a call the model could not form, one it was not meant to make, and more than
/// the request allowed) -- are one canonical reason, because the canonical vocabulary has no finer
/// one to map them to: it is Anthropic's, and it distinguishes only ending, truncation, a tool call
/// and a refusal. <code>OTHER</code> is deliberately absent: an unknown reason is what
/// <parameter>DEFAULTSTOPREASON</parameter> is for.</p>
Parameter GEMINISTOPREASONS = "STOP:end_turn,MAX_TOKENS:max_tokens,SAFETY:refusal,IMAGE_SAFETY:refusal,RECITATION:refusal,BLOCKLIST:refusal,PROHIBITED_CONTENT:refusal,SPII:refusal,LANGUAGE:refusal,MALFORMED_FUNCTION_CALL:refusal,UNEXPECTED_TOOL_CALL:refusal,TOO_MANY_TOOL_CALLS:refusal";

/// <p>The canonical stop reason a reason outside the family's own vocabulary, and an absent one,
/// are read as. The canonical vocabulary is closed, so an unmapped value is normalized rather than
/// carried through.</p>
Parameter DEFAULTSTOPREASON = "end_turn";

/// <p>The canonical stop reason for a reply that called a tool. It is taken from the blocks where
/// the vendor's own reason said no more than that, because Gemini finishes a function call
/// <code>STOP</code>.</p>
Parameter TOOLUSESTOPREASON = "tool_use";

/// <p>The canonical stop reason for a reply the model would not give: the value both vendor maps
/// already carry, named here because two reply directions reach it with no vendor stop reason to
/// look up -- an OpenAI <code>refusal</code> member, and a Gemini prompt-level block.</p>
Parameter REFUSALSTOPREASON = "refusal";

/// <p>The prefix a synthesized Gemini call id carries. The ordinal and the function name follow
/// it, so the id says which call it belongs to in a log and in a transcript.</p>
/// <p><b>It is also what tells a synthesized id from a vendor one</b> (DW-1180): a request carries
/// a call id only where the provider issued it, and <method>IsSynthesizedCallId</method> is the one
/// place that distinction is made. A canonical id from another family is treated as a vendor one:
/// it is emitted on both parts, so the pair still correlates within the request it is sent in.</p>
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
/// <code>arguments</code> value that is not a JSON object -- never a silent empty reply, which is
/// what a caller would otherwise hand the turn.</p>
/// <p>A tool call carrying no <code>id</code>, or naming no function, is an error too: a canonical
/// block the next request could not correlate a result with would refuse <b>every</b> later request
/// in that conversation, so it is refused here rather than stored.</p>
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
        ; A refused reply carries a null content and its reason under `refusal`, with
        ; finish_reason still `stop` -- so without this the turn gets an empty reply and is told
        ; the model ended normally (DW-1202).
        Set tRefusal = ""
        If tMessage.%GetTypeOf("refusal") = "string" Set tRefusal = tMessage.%Get("refusal")
        ; A reply carrying both is the refusal: the partial content is what the model produced
        ; before it declined, and presenting it as the answer would read as an answer. It is
        ; dropped rather than concatenated, so the canonical text is one statement.
        If tRefusal '= "" Set tText = tRefusal
        Set tToolCalls = []
        If $IsObject(tMessage."tool_calls") && tMessage."tool_calls".%IsA("%Library.DynamicArray") {
            Set tIterator = tMessage."tool_calls".%GetIterator()
            While tIterator.%GetNext(.tIndex, .tCall) {
                If '$IsObject(tCall) Continue
                If '$IsObject(tCall.function) || (tCall.function.name = "") {
                    Set tSC = $$$ERROR($$$GeneralError, "a tool call in the provider's reply names no function")
                    Quit
                }
                If tCall.id = "" {
                    Set tSC = $$$ERROR($$$GeneralError, "a tool call in the provider's reply carries no id")
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
        Set pResponse.StopReason = $Select(tRefusal '= "": ..#REFUSALSTOPREASON, 1: ..StopReason(..#OPENAISTOPREASONS, tChoice."finish_reason", tToolCalls.%Size()))
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
/// <b>function</b> its id resolves to. <b>A call id travels on both parts or on neither</b>
/// (DW-1180): where the provider issued one, the replayed <code>functionCall</code> and the
/// <code>functionResponse</code> answering it both carry it; where it did not, neither does, and
/// the name and the order the results appear in are the whole correlation, which keeps two calls
/// to one tool apart. A tool-use block's <code>thoughtSignature</code> member is written back
/// verbatim as the replayed part's sibling <code>thoughtSignature</code>, and a block with none
/// writes none.</p>
/// <p><var>pEmptyEnums</var> is <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiEmptyEnumArgs</method>'s
/// map as JSON text, or <code>""</code>. On a (tool, argument) pair it names, and on no other, a
/// replayed <code>functionCall</code>'s <code>""</code> is written as
/// <parameter>OcuPilot.Kernel.Provider.ToolDefAdapter.GEMINIEMPTYENUM</parameter>, per element for
/// an <code>items</code> argument, so the history says what the declaration said.</p>
/// <p>Answers an error <class>%Status</class>, with both outputs blank, for a
/// <code>tool_result</code> whose id no preceding <code>tool_use</code> carried.</p>
ClassMethod CanonicalToGemini(ByRef pMessages, pSystemPrompt As %String = "", Output pContents As %DynamicArray, Output pSystemInstruction As %DynamicObject, pEmptyEnums As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pContents = []
    Set pSystemInstruction = ""
    Try {
        Set tEmptyEnums = ..EmptyEnumMap(pEmptyEnums)
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
                        Do tCall.%Set("args", ..RespellEmpty(..ArgumentsOf(tBlock.%Get("input")), tEmptyEnums.%Get(tBlock.name), "", ##class(OcuPilot.Kernel.Provider.ToolDefAdapter).#GEMINIEMPTYENUM))
                        ; DW-1180: a call whose answer carries an id must carry the same id here,
                        ; or the functionResponse names a call this request does not identify.
                        If (tUseId '= "") && '..IsSynthesizedCallId(tUseId) Do tCall.%Set("id", tUseId, "string")
                        Set tPart = {}
                        Do tPart.%Set("functionCall", tCall)
                        ; The part's sibling signature goes back verbatim, or the provider refuses
                        ; the replayed call; a block that carried none writes none.
                        If tBlock.%GetTypeOf("thoughtSignature") = "string" Do tPart.%Set("thoughtSignature", tBlock.%Get("thoughtSignature"), "string")
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
                    ; DW-1180: echoed under the same condition the functionCall above carries an
                    ; id, so the pair correlates within this request. A synthesized id is on
                    ; neither side: it names a call the provider never issued an id for.
                    If '..IsSynthesizedCallId(tResultId) Do tAnswer.%Set("id", tResultId, "string")
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
/// <code>tool_use</code> block carrying the vendor's own <code>id</code> where the call had one
/// and a synthesized one where it did not (DW-1180), the <code>finishReason</code> mapped
/// into the canonical vocabulary, and
/// <code>usageMetadata.promptTokenCount</code> / <code>candidatesTokenCount</code> into the two
/// token counts. A <code>functionCall</code> part's sibling <code>thoughtSignature</code> is kept
/// verbatim as the canonical block's own <code>thoughtSignature</code> member, which
/// <method>CanonicalToGemini</method> writes back beside the replayed call.</p>
/// <p><var>pEmptyEnums</var> is the same map <method>CanonicalToGemini</method> takes. On a
/// (tool, argument) pair it names, and on no other, a <code>functionCall</code> argument reading
/// <parameter>OcuPilot.Kernel.Provider.ToolDefAdapter.GEMINIEMPTYENUM</parameter> reaches the
/// canonical <code>input</code> as <code>""</code>, per element for an <code>items</code>
/// argument.</p>
/// <p>Answers an error <class>%Status</class> for a body that is not a JSON object, for one with no
/// <code>candidates</code> array, and for a <code>functionCall</code> part naming no function,
/// which no later request could answer. A candidate that carried no parts is an empty reply and
/// not an error: the model answered, with nothing in it.</p>
ClassMethod GeminiToCanonical(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response, pEmptyEnums As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tEmptyEnums = ..EmptyEnumMap(pEmptyEnums)
        Set tParsed = ..BodyOf(pBody, .tSC)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tParsed.candidates) || 'tParsed.candidates.%IsA("%Library.DynamicArray") || (tParsed.candidates.%Size() = 0) {
            ; A prompt the model refused before generating anything answers 200 carrying
            ; promptFeedback alone. That is a refusal, not a body this adapter could not read, so
            ; it must not become a PROVIDER.TRANSPORT fault (DW-1202).
            Set tBlocked = ..PromptBlockReason(tParsed)
            If tBlocked = "" {
                Set tSC = $$$ERROR($$$GeneralError, "the provider's reply carries no candidates array")
                Quit
            }
            Set pResponse.Text = tBlocked
            Set pResponse.StopReason = ..#REFUSALSTOPREASON
            Do ..GeminiUsage(tParsed, pResponse)
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
                If tPart.functionCall.name = "" {
                    Set tSC = $$$ERROR($$$GeneralError, "a function call in the provider's reply names no function")
                    Quit
                }
                ; DW-1180: a vendor id is kept so the next request can echo it; only a call that
                ; carried none gets a synthesized one.
                Set tVendorId = ""
                If tPart.functionCall.%GetTypeOf("id") = "string" Set tVendorId = tPart.functionCall.%Get("id")
                Set tUse = {}
                Do tUse.%Set("type", "tool_use", "string")
                Do tUse.%Set("id", $Select(tVendorId '= "": tVendorId, 1: ..#GEMINICALLIDPREFIX _ (tToolCalls.%Size() + 1) _ "_" _ tPart.functionCall.name), "string")
                Do tUse.%Set("name", tPart.functionCall.name, "string")
                Do tUse.%Set("input", ..RespellEmpty(..ArgumentsOf(tPart.functionCall.args), tEmptyEnums.%Get(tPart.functionCall.name), ##class(OcuPilot.Kernel.Provider.ToolDefAdapter).#GEMINIEMPTYENUM, ""))
                If tPart.%GetTypeOf("thoughtSignature") = "string" Do tUse.%Set("thoughtSignature", tPart.%Get("thoughtSignature"), "string")
                Do tToolCalls.%Push(tUse)
            }
            If $$$ISERR(tSC) Quit
        }
        Set pResponse.Text = tText
        If tToolCalls.%Size() > 0 Set pResponse.ToolCallsJson = tToolCalls.%ToJSON()
        Set pResponse.StopReason = ..StopReason(..#GEMINISTOPREASONS, tCandidate.finishReason, tToolCalls.%Size())
        Do ..GeminiUsage(tParsed, pResponse)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The reason <var>pParsed</var>'s top-level <code>promptFeedback</code> gives for refusing the
/// prompt itself, or <code>""</code> when it names none. Read only where it is a JSON string, for
/// the reason <method>OcuPilot.Kernel.Provider.Base.ProviderMessage</method> reads its own member
/// that way.</p>
ClassMethod PromptBlockReason(pParsed As %DynamicObject) As %String [ Private ]
{
    If '$IsObject(pParsed.promptFeedback) Quit ""
    If pParsed.promptFeedback.%GetTypeOf("blockReason") '= "string" Quit ""
    Quit pParsed.promptFeedback.%Get("blockReason")
}

/// <p>Copy <var>pParsed</var>'s <code>usageMetadata</code> token counts onto <var>pResponse</var>,
/// so both exits of <method>GeminiToCanonical</method> report what the call cost.</p>
ClassMethod GeminiUsage(pParsed As %DynamicObject, pResponse As OcuPilot.Kernel.Provider.Response) [ Private ]
{
    If '$IsObject(pParsed.usageMetadata) Quit
    Set pResponse.RequestTokens = +pParsed.usageMetadata.promptTokenCount
    Set pResponse.ResponseTokens = +pParsed.usageMetadata.candidatesTokenCount
}

/// <p>Whether <var>pId</var> is an id this class synthesized for a Gemini call that carried none
/// (<parameter>GEMINICALLIDPREFIX</parameter>), rather than one the provider issued.</p>
/// <p>A synthesized id names a call the provider issued no id for, so it is sent on neither the
/// replayed <code>functionCall</code> nor the <code>functionResponse</code> answering it (DW-1180):
/// sending it would assert a correlation nothing in the exchange supports.</p>
ClassMethod IsSynthesizedCallId(pId As %String = "") As %Boolean [ Private ]
{
    Quit ($Extract(pId, 1, $Length(..#GEMINICALLIDPREFIX)) = ..#GEMINICALLIDPREFIX)
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
    If '..IsJsonObject(pInput) Quit "{}"
    Quit pInput.%ToJSON()
}

/// <p>The same block's <var>pInput</var> as the object Gemini's <code>args</code> carries; an
/// empty object for an input that is not one.</p>
ClassMethod ArgumentsOf(pInput As %RawString = "") As %DynamicObject [ Private ]
{
    Set tArgs = {}
    If ..IsJsonObject(pInput) Set tArgs = pInput
    Quit tArgs
}

/// <p><var>pMap</var> -- <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiEmptyEnumArgs</method>'s
/// map as JSON text -- as the object it holds, or an empty object when it is empty or not a JSON
/// object.</p>
ClassMethod EmptyEnumMap(pMap As %String = "") As %DynamicObject [ Private ]
{
    Set tMap = {}
    Try {
        If pMap = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pMap)
        If ..IsJsonObject(tParsed) Set tMap = tParsed
    } Catch ex {
        Set tMap = {}
    }
    Quit tMap
}

/// <p>A copy of the arguments object <var>pArgs</var> with, on each argument <var>pArgKinds</var>
/// names, a string equal to <var>pFrom</var> written as <var>pTo</var>: the argument itself for
/// kind <code>value</code>, each element of its array for kind <code>items</code>. Every other
/// argument is copied as it is. <var>pArgs</var> itself when <var>pArgKinds</var> names
/// nothing.</p>
ClassMethod RespellEmpty(pArgs As %DynamicObject, pArgKinds As %RawString, pFrom As %String, pTo As %String) As %DynamicObject [ Private ]
{
    If '..IsJsonObject(pArgKinds) Quit pArgs
    If pArgKinds.%Size() = 0 Quit pArgs
    Set tOut = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Set tIterator = pArgKinds.%GetIterator()
    While tIterator.%GetNext(.tArg, .tKind) {
        If tKind = "value" {
            If (tOut.%GetTypeOf(tArg) = "string") && (tOut.%Get(tArg) = pFrom) Do tOut.%Set(tArg, pTo, "string")
            Continue
        }
        If tKind '= "items" Continue
        Set tList = tOut.%Get(tArg)
        If '$IsObject(tList) || 'tList.%IsA("%Library.DynamicArray") Continue
        For tI = 0:1:(tList.%Size() - 1) {
            If (tList.%GetTypeOf(tI) = "string") && (tList.%Get(tI) = pFrom) Do tList.%Set(tI, pTo, "string")
        }
    }
    Quit tOut
}

/// <p>Whether <var>pValue</var> is a JSON <b>object</b> -- the check
/// <method>BodyOf</method> makes, so a JSON array is not read as one anywhere in this class. A
/// canonical <code>tool_use</code> block's <code>input</code> is an object by contract, and the
/// loop reads arguments off it by member name.</p>
ClassMethod IsJsonObject(pValue As %RawString = "") As %Boolean [ Private ]
{
    If '$IsObject(pValue) Quit 0
    Quit ''pValue.%IsA("%Library.DynamicObject")
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
            If '..IsJsonObject(pArguments) {
                Set pSC = $$$ERROR($$$GeneralError, "a tool call's arguments are not a JSON object")
                Quit
            }
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
