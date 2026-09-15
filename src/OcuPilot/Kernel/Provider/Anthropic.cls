/// <p>The Anthropic Messages adapter -- Release 1's only provider, and the family whose message
/// shape is canonical (AD-42). Because it is canonical, everything here is a <b>passthrough</b>:
/// the body is built in the shape the caller already holds and the reply is read in the shape
/// <class>OcuPilot.Kernel.Provider.Response</class> already declares. A later family's adapter is
/// where translation lives.</p>
/// <p><b>This class is reached only through its catalog row's <code>adapterClass</code>
/// column.</b> Nothing names it in a branch, which is what makes adding a family one row plus one
/// class.</p>
/// <p>Wire contract: <code>POST</code> to the definition's endpoint with headers
/// <code>x-api-key</code>, <code>anthropic-version</code> and <code>content-type</code>; body
/// <code>{model, max_tokens, temperature, system?, messages, tools?}</code>; reply
/// <code>{content, stop_reason, usage}</code>; error body
/// <code>{type, error: {type, message}}</code>.</p>
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

/// <p>The provider key whose catalog row points at this class.</p>
Method ProviderName() As %String
{
    Quit "anthropic"
}

/// <p>The canonical request body, attached to <var>pRequest</var>.</p>
/// <p><code>system</code> and <code>tools</code> are omitted rather than sent empty: an empty
/// system prompt is not the same request as no system prompt, and an empty tool array advertises a
/// tool set the turn does not have.</p>
Method CallMessages(pRequest As %Net.HttpRequest, ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tBody = {}
        Do tBody.%Set("model", $Get(pValues("model")))
        Do tBody.%Set("max_tokens", +$Get(pValues("maxTokens")), "number")
        Do tBody.%Set("temperature", +$Get(pValues("temperature")), "number")
        If pSystemPrompt '= "" Do tBody.%Set("system", pSystemPrompt)
        Set tMessageArray = []
        For tI = 1:1:+$Get(pMessages) {
            Set tMessage = {}
            Do tMessage.%Set("role", $Get(pMessages(tI, "role")))
            Do tMessage.%Set("content", $Get(pMessages(tI, "content")))
            Do tMessageArray.%Push(tMessage)
        }
        Do tBody.%Set("messages", tMessageArray)
        If +$Get(pTools) > 0 {
            Set tToolArray = []
            For tI = 1:1:+$Get(pTools) {
                Set tTool = {}
                Do tTool.%Set("name", $Get(pTools(tI, "name")))
                Do tTool.%Set("description", $Get(pTools(tI, "description")))
                Do tTool.%Set("input_schema", ..SchemaOf($Get(pTools(tI, "inputSchema"))))
                Do tToolArray.%Push(tTool)
            }
            Do tBody.%Set("tools", tToolArray)
        }
        Do pRequest.EntityBody.Clear()
        Do pRequest.EntityBody.Write(tBody.%ToJSON())
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

/// <p>Write the two authentication headers onto <var>pRequest</var>.</p>
/// <p><b><property>ApiKey</property> is read straight onto the header.</b> No local holds it, not
/// even to build the value, because <code>^%ETN</code> captures every local at every stack level
/// and OcuPilot renders that log (AD-35, AD-46, AD-48).</p>
Method ApplyAuth(pRequest As %Net.HttpRequest)
{
    Do pRequest.SetHeader(..#KEYHEADER, ..ApiKey)
    Do pRequest.SetHeader(..#VERSIONHEADER, ..AuthVersion)
}

/// <p>Whether <var>pKey</var> starts with the prefix the catalog row declares.</p>
/// <p>A pure comparison that calls nothing and cannot throw -- see the base's own contract for why
/// that matters here and nowhere else. A row that declares no prefix gates nothing, which is the
/// right answer for a family whose keys have no fixed shape.</p>
Method IsApiKeyShapeValid(pKey As %String) As %Boolean
{
    If ..KeyPrefix = "" Quit 1
    Quit ($Extract(pKey, 1, $Length(..KeyPrefix)) = ..KeyPrefix)
}

/// <p>Read a successful reply into <var>pResponse</var>: the text blocks concatenated in order,
/// every tool-use block kept verbatim as a JSON array, the stop reason, and the two usage
/// figures.</p>
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
        Set tIterator = tParsed.content.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tBlock) {
            If '$IsObject(tBlock) Continue
            If tBlock.type = "text" {
                Set tText = tText _ tBlock.text
                Continue
            }
            If tBlock.type = "tool_use" Do tToolCalls.%Push(tBlock)
        }
        Set pResponse.Text = tText
        If tToolCalls.%Size() > 0 Set pResponse.ToolCallsJson = tToolCalls.%ToJSON()
        Set pResponse.StopReason = $Select(tParsed."stop_reason" = "": "end_turn", 1: tParsed."stop_reason")
        If $IsObject(tParsed.usage) {
            Set pResponse.RequestTokens = +tParsed.usage."input_tokens"
            Set pResponse.ResponseTokens = +tParsed.usage."output_tokens"
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The provider's own <code>error.message</code> out of an error body, or <code>""</code>.</p>
/// <p>The message alone, and never the body: the message is what
/// <code>detail.providerText</code> carries to a screen and a tool result, while the body goes to
/// <method>OcuPilot.Kernel.Fault.LogRaw</method> and nowhere else (AD-39).</p>
Method ProviderMessage(pBody As %String) As %String
{
    Set tMessage = ""
    Try {
        If pBody = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pBody)
        If '$IsObject(tParsed) || 'tParsed.%IsA("%Library.DynamicObject") Quit
        If '$IsObject(tParsed.error) Quit
        Set tMessage = tParsed.error.message
    } Catch ex {
        Set tMessage = ""
    }
    Quit tMessage
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
