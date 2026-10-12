/// <p>The Anthropic Messages adapter -- the first shipped provider, and the family whose message
/// shape is canonical (AD-42). Because it is canonical, everything here is a <b>passthrough</b>:
/// the body is built in the shape the caller already holds and the reply is read in the shape
/// <class>OcuPilot.Kernel.Provider.Response</class> already declares. A later family's adapter is
/// where translation lives.</p>
/// <p><b>This class is reached only through its catalog row's <code>adapterClass</code>
/// column.</b> Nothing names it in a branch, which is what makes adding a family one row plus one
/// class.</p>
/// <p>Wire contract: <code>POST</code> to the definition's endpoint with headers
/// <code>x-api-key</code>, <code>anthropic-version</code> and <code>content-type</code>; body
/// <code>{model, max_tokens, system?, messages, tools?}</code>; reply
/// <code>{content, stop_reason, usage}</code>; error body
/// <code>{type, error: {type, message}}</code>. <b>Prompt caching</b>: the request marks at most two
/// places <code>cache_control</code> <code>{"type":"ephemeral"}</code> -- the last tool that is not
/// deferred, and the last block of the final message when that message is blocks -- and nothing else.
/// <b>No sampling parameter is ever sent</b> --
/// <code>temperature</code>, <code>top_p</code> and <code>top_k</code> are absent whatever the
/// definition holds, because this family's current models refuse them; the catalog row's
/// <code>acceptsTemperature</code> says the same to the form.</p>
Class OcuPilot.Kernel.Provider.Anthropic Extends OcuPilot.Kernel.Provider.Base
{

/// <p>The header the credential is sent in.</p>
Parameter KEYHEADER = "x-api-key";

/// <p>The header the API version is sent in. Its <i>value</i> is the catalog row's
/// <code>authVersion</code>, not a literal here: the table is where a provider fact is
/// spelled.</p>
Parameter VERSIONHEADER = "anthropic-version";

/// <p>The body's media type.</p>
Parameter CONTENTTYPE = "application/json";

/// <p>The <code>type</code> of the <code>cache_control</code> member that marks a cache breakpoint.</p>
Parameter CACHEBREAKPOINT = "ephemeral";

/// <p>What one cache-read token counts against a turn's token limit, as a share of an input token:
/// 0.1, the standard cache-read multiplier on the vendor's pricing page
/// (<code>platform.claude.com/docs/en/about-claude/pricing</code>, read 2026-10-12). The page bills
/// Opus 5.5 and Sonnet 5.5 reads at 0.05 and Fable 5.1 and Mythos 5.1 at 0.025, so the bound counts
/// those reads above what they cost, which is the safe side. Cache writes count at 1.</p>
Parameter CACHEREADWEIGHT = 0.1;

/// <p>This family streams when the caller passes a sink (AD-42); 0 turns it off.</p>
Parameter STREAMS As %Boolean = 1;

/// <p>Streamed as Messages server-sent events.</p>
Parameter STREAMFAMILY As %String = "anthropic";

/// <p>The provider key whose catalog row points at this class.</p>
Method ProviderName() As %String
{
    Quit "anthropic"
}

/// <p>The canonical request body, attached to <var>pRequest</var>.</p>
/// <p><code>system</code> and <code>tools</code> are omitted rather than sent empty: an empty
/// system prompt is not the same request as no system prompt, and an empty tool array advertises a
/// tool set the turn does not have.</p>
/// <p>A message whose <code>pMessages(n, "blocks")</code> holds a JSON array is sent with that
/// array as its <code>content</code> -- the shape a tool call's echo and its results take; any
/// other message sends its <code>content</code> string.</p>
/// <p><b>Prompt caching.</b> The last tool that is not deferred gains <code>cache_control</code>, and
/// so does the last block of the final message when that message is blocks; no other tool, block or
/// the <code>system</code> string is marked. The cached prefix -- <code>tools</code>,
/// <code>system</code> and the messages already sent -- is the request's own bytes and never changes
/// within a turn; only the two markers move, the second to each call's new tail.</p>
/// <p><b>A scoped tool array</b> (<class>OcuPilot.Kernel.Provider.Base</class>'s <var>pTools</var>) is
/// sent whole: every tool is in <code>tools</code>, and each one outside the starting set carries
/// <code>"defer_loading": true</code>, which keeps its definition out of the model's context until a
/// <code>tool_reference</code> block names it. The array is the same bytes on every call of a turn,
/// because what the turn found never changes it, and a deferred tool never carries
/// <code>cache_control</code>, which the API refuses. An unscoped array is sent as it always was.</p>
/// <p>A streamed call (<property>Streaming</property>) also carries <code>"stream": true</code>.</p>
/// <p><b>The body is written as UTF-8 bytes.</b> The media type carries no charset, so
/// <class>%Net.HttpRequest</class> sends the entity body untranslated, and a character above 255
/// written as itself would not reach the provider intact.</p>
Method CallMessages(pRequest As %Net.HttpRequest, ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tBody = {}
        Do tBody.%Set("model", $Get(pValues("model")))
        Do tBody.%Set("max_tokens", +$Get(pValues("maxTokens")), "number")
        If pSystemPrompt '= "" Do tBody.%Set("system", pSystemPrompt)
        Set tMessageArray = []
        For tI = 1:1:+$Get(pMessages) {
            Set tMessage = {}
            Do tMessage.%Set("role", $Get(pMessages(tI, "role")))
            Set tBlocks = ""
            If $Get(pMessages(tI, "blocks")) '= "" {
                Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pMessages(tI, "blocks"))
                If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tBlocks = tParsed
            }
            If $IsObject(tBlocks) {
                Do tMessage.%Set("content", tBlocks)
            } Else {
                Do tMessage.%Set("content", $Get(pMessages(tI, "content")))
            }
            Do tMessageArray.%Push(tMessage)
        }
        If tMessageArray.%Size() > 0 {
            Set tTail = tMessageArray.%Get(tMessageArray.%Size() - 1).content
            If $IsObject(tTail) && (tTail.%Size() > 0) {
                Set tTailBlock = tTail.%Get(tTail.%Size() - 1)
                If $IsObject(tTailBlock) Do tTailBlock.%Set("cache_control", ..CacheMarker())
            }
        }
        Do tBody.%Set("messages", tMessageArray)
        If +$Get(pTools) > 0 {
            Set tScoped = +$Get(pTools("scoped"))
            Set tMarked = ..MarkedTool(.pTools)
            Set tToolArray = []
            For tI = 1:1:+$Get(pTools) {
                Set tTool = {}
                Do tTool.%Set("name", $Get(pTools(tI, "name")))
                Do tTool.%Set("description", $Get(pTools(tI, "description")))
                Do tTool.%Set("input_schema", ..SchemaOf($Get(pTools(tI, "inputSchema"))))
                If tScoped && '$Get(pTools(tI, "start")) Do tTool.%Set("defer_loading", 1, "boolean")
                If tI = tMarked Do tTool.%Set("cache_control", ..CacheMarker())
                Do tToolArray.%Push(tTool)
            }
            Do tBody.%Set("tools", tToolArray)
        }
        If ..Streaming Do tBody.%Set("stream", 1, "boolean")
        Do pRequest.EntityBody.Clear()
        Do pRequest.EntityBody.Write($ZConvert(tBody.%ToJSON(), "O", "UTF8"))
        ; Set last, and this order is the implementation rather than a preference:
        ; %Net.HttpRequest.ContentType is a calculated property over an ATTRIBUTE of the entity
        ; body stream, and Clear() drops the stream's attributes with its contents. Set before the
        ; clear, the request goes out as text/html and the provider refuses it.
        Set pRequest.ContentType = ..#CONTENTTYPE
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write the authentication headers onto <var>pRequest</var>: the version always, and the key
/// only when the call carries one.</p>
/// <p><b><property>ApiKey</property> is read straight onto the header.</b> No local holds it, not
/// even to build the value, because <code>^%ETN</code> captures every local at every stack level
/// and OcuPilot renders that log (AD-35, AD-46, AD-48).</p>
Method ApplyAuth(pRequest As %Net.HttpRequest)
{
    If ..ApiKey '= "" Do pRequest.SetHeader(..#KEYHEADER, ..ApiKey)
    Do pRequest.SetHeader(..#VERSIONHEADER, ..AuthVersion)
}

/// <p>Whether <property>ApiKey</property> starts with the prefix the catalog row declares.</p>
/// <p>The credential is read straight into the comparison and never into a local, per the base's
/// contract. A row that declares no prefix gates nothing, which is the right answer for a family
/// whose keys have no fixed shape.</p>
Method IsApiKeyShapeValid() As %Boolean
{
    If ..KeyPrefix = "" Quit 1
    Quit ($Extract(..ApiKey, 1, $Length(..KeyPrefix)) = ..KeyPrefix)
}

/// <p>Read a successful reply into <var>pResponse</var>: the text blocks concatenated in order,
/// every tool-use block kept verbatim as a JSON array, the stop reason, and the two usage
/// figures. <b><property>OcuPilot.Kernel.Provider.Response.RequestTokens</property> is the prompt's
/// whole size</b> (AD-31): <code>input_tokens</code>, which this family reports without the cached
/// part, plus <code>cache_creation_input_tokens</code> and <code>cache_read_input_tokens</code>; a
/// figure the reply does not carry counts 0. <property>OcuPilot.Kernel.Provider.Response.BoundTokens</property>
/// is the same figure with the cache reads at <parameter>CACHEREADWEIGHT</parameter>.</p>
/// <p><b>A reply carrying a <code>thinking</code> or <code>redacted_thinking</code> block also
/// sets <property>OcuPilot.Kernel.Provider.Response.ContentJson</property></b> to its whole
/// <code>content</code> array, verbatim: the provider requires those blocks back unchanged and in
/// order when the turn answers a tool call, and <property>Text</property> and
/// <property>ToolCallsJson</property> cannot carry them. A reply without one leaves it
/// <code>""</code>.</p>
/// <p>A body that is not a JSON object, or that carries no <code>content</code> array, is an error:
/// a 200 whose body this adapter cannot read is not a reply, and reporting it as an empty one would
/// hand the turn a silent blank.</p>
Method MapResponse(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pBody)
        If '$IsObject(tParsed) || 'tParsed.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the provider's reply is not a JSON object")
            Quit
        }
        ; An array, not merely an object: a JSON object passes $IsObject, %GetIterator then walks
        ; it by key, every value fails the block tests, and a reply this adapter cannot read would
        ; be reported as a successful empty one -- the silent blank this method exists to refuse.
        If '$IsObject(tParsed.content) || 'tParsed.content.%IsA("%Library.DynamicArray") {
            Set tSC = $$$ERROR($$$GeneralError, "the provider's reply carries no content array")
            Quit
        }
        Set tText = ""
        Set tToolCalls = []
        Set tReasoning = 0
        Set tIterator = tParsed.content.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tBlock) {
            If '$IsObject(tBlock) Continue
            If (tBlock.type = "thinking") || (tBlock.type = "redacted_thinking") Set tReasoning = 1
            If tBlock.type = "text" {
                Set tText = tText _ tBlock.text
                Continue
            }
            If tBlock.type = "tool_use" Do tToolCalls.%Push(tBlock)
        }
        Set pResponse.Text = tText
        If tToolCalls.%Size() > 0 Set pResponse.ToolCallsJson = tToolCalls.%ToJSON()
        If tReasoning Set pResponse.ContentJson = tParsed.content.%ToJSON()
        Set pResponse.StopReason = $Select(tParsed."stop_reason" = "": "end_turn", 1: tParsed."stop_reason")
        If $IsObject(tParsed.usage) {
            Set tRead = +tParsed.usage."cache_read_input_tokens"
            Set pResponse.RequestTokens = +tParsed.usage."input_tokens" + +tParsed.usage."cache_creation_input_tokens" + tRead
            Set pResponse.BoundTokens = ##class(OcuPilot.Kernel.Provider.Response).WeightedTokens(pResponse.RequestTokens, tRead, ..#CACHEREADWEIGHT)
            Set pResponse.ResponseTokens = +tParsed.usage."output_tokens"
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The index of the tool of <var>pTools</var> that carries the cache marker: the last one, or on a
/// scoped array the last one in the starting set, because a deferred tool cannot carry it. 0 when
/// there is none.</p>
Method MarkedTool(ByRef pTools) As %Integer [ Private ]
{
    Set tMarked = 0
    For tI = +$Get(pTools):-1:1 {
        If '$Get(pTools("scoped")) || $Get(pTools(tI, "start")) {
            Set tMarked = tI
            Quit
        }
    }
    Quit tMarked
}

/// <p>A new <code>cache_control</code> value, <code>{"type":"ephemeral"}</code>: one object per
/// mark, never shared between two places in a body.</p>
Method CacheMarker() As %DynamicObject [ Private ]
{
    Set tMarker = {}
    Do tMarker.%Set("type", ..#CACHEBREAKPOINT, "string")
    Quit tMarker
}

/// <p><var>pSchema</var> -- a tool's JSON-schema text -- as the object the body carries, or an
/// empty object when it is absent or will not parse. A tool whose schema could not be read is
/// still advertised, with no properties, rather than failing the whole call.</p>
Method SchemaOf(pSchema As %String) As %DynamicAbstractObject [ Private ]
{
    Set tSchema = {}
    Try {
        If pSchema = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pSchema)
        If $IsObject(tParsed) Set tSchema = tParsed
    } Catch ex {
        Set tSchema = {}
    }
    Quit tSchema
}

}
