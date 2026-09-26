/// <p>The OpenAI Chat Completions adapter (AD-42). The canonical shapes are Anthropic's, so
/// everything about the wire is a translation: the body is built through
/// <class>OcuPilot.Kernel.Provider.MessageAdapter</class> and
/// <class>OcuPilot.Kernel.Provider.ToolDefAdapter</class>, and the reply is read back through the
/// first of those.</p>
/// <p><b>This class is reached only through its catalog row's <code>adapterClass</code>
/// column.</b> Nothing names it in a branch, which is what makes adding a family one row plus one
/// class.</p>
/// <p>Wire contract, verified against the vendor's published Chat Completions reference and
/// function-calling guide (<code>platform.openai.com/docs/guides/function-calling</code>,
/// 2026-09-18): <code>POST</code> to the row's endpoint with headers
/// <code>Authorization: Bearer &lt;key&gt;</code> and <code>content-type</code>; body
/// <code>{model, max_completion_tokens, temperature?, reasoning_effort?, messages, tools?}</code>;
/// reply
/// <code>{choices, usage}</code>; error body <code>{error: {message}}</code>. The token cap is
/// <code>max_completion_tokens</code> and not <code>max_tokens</code>, which the vendor's schema
/// marks deprecated and refuses on its reasoning models. <code>temperature</code> is sent only
/// when the definition holds one, so an unset value leaves the provider's default in force;
/// <code>reasoning_effort</code> only when the catalog row's <code>reasoningEffort</code> names
/// one. No API-version header exists for this family, so the row's <code>authVersion</code> is
/// empty and nothing sends one.</p>
Class OcuPilot.Kernel.Provider.OpenAI Extends OcuPilot.Kernel.Provider.Base
{

/// <p>The header the credential is sent in.</p>
Parameter KEYHEADER = "Authorization";

/// <p>The scheme that header's value carries before the credential.</p>
Parameter AUTHSCHEME = "Bearer ";

/// <p>The body's media type.</p>
Parameter CONTENTTYPE = "application/json";

/// <p>This family, and <class>OcuPilot.Kernel.Provider.Compatible</class> through it, streams when
/// the caller passes a sink (AD-42); 0 turns it off.</p>
Parameter STREAMS As %Boolean = 1;

/// <p>Streamed as Chat Completions chunks ending <code>[DONE]</code>.</p>
Parameter STREAMFAMILY As %String = "openai";

/// <p>The provider key whose catalog row points at this class.</p>
Method ProviderName() As %String
{
    Quit "openai"
}

/// <p>The Chat Completions request body, attached to <var>pRequest</var>.</p>
/// <p>An error <class>%Status</class> from either translator is returned unchanged, so a history
/// or a tool array that cannot be translated reaches
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s body-could-not-be-built exit and no
/// call is made.</p>
/// <p><code>tools</code> is omitted rather than sent empty: an empty array advertises a tool set
/// the turn does not have. A streamed call (<property>Streaming</property>) also carries
/// <code>"stream": true</code> and <code>"stream_options": {"include_usage": true}</code>, so its
/// last chunk reports the usage a plain reply does. <b>The body is written as UTF-8 bytes</b> and the media type is set
/// after the write, because <property>%Net.HttpRequest.ContentType</property> is a calculated
/// property over an attribute of the entity-body stream and <code>Clear()</code> drops it.</p>
Method CallMessages(pRequest As %Net.HttpRequest, ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Provider.MessageAdapter).CanonicalToOpenAi(.pMessages, pSystemPrompt, .tMessageArray)
        If $$$ISERR(tSC) Quit
        Set tBody = {}
        Do tBody.%Set("model", $Get(pValues("model")), "string")
        Do tBody.%Set("max_completion_tokens", +$Get(pValues("maxTokens")), "number")
        If $Get(pValues("temperature")) '= "" Do tBody.%Set("temperature", +pValues("temperature"), "number")
        If $Get(pValues("reasoningEffort")) '= "" Do tBody.%Set("reasoning_effort", pValues("reasoningEffort"), "string")
        Do tBody.%Set("messages", tMessageArray)
        If +$Get(pTools) > 0 {
            Set tSC = ##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.pTools, .tToolArray)
            If $$$ISERR(tSC) Quit
            If tToolArray.%Size() > 0 Do tBody.%Set("tools", tToolArray)
        }
        If ..Streaming {
            Do tBody.%Set("stream", 1, "boolean")
            Set tOptions = {}
            Do tOptions.%Set("include_usage", 1, "boolean")
            Do tBody.%Set("stream_options", tOptions)
        }
        Do pRequest.EntityBody.Clear()
        Do pRequest.EntityBody.Write($ZConvert(tBody.%ToJSON(), "O", "UTF8"))
        Set pRequest.ContentType = ..#CONTENTTYPE
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write the bearer credential onto <var>pRequest</var>, and nothing else: this family sends no
/// version header. A call with no key writes no header at all rather than an empty one.</p>
/// <p><b><property>OcuPilot.Kernel.Provider.Base.ApiKey</property> is read straight onto the
/// header.</b> No local holds it, not even to build the value, because <code>^%ETN</code> captures
/// every local at every stack level and OcuPilot renders that log (AD-35, AD-46, AD-48).</p>
Method ApplyAuth(pRequest As %Net.HttpRequest)
{
    If ..ApiKey = "" Quit
    Do pRequest.SetHeader(..#KEYHEADER, ..#AUTHSCHEME _ ..ApiKey)
}

/// <p>Whether <property>OcuPilot.Kernel.Provider.Base.ApiKey</property> is shaped like a key for
/// this family, which is the base's own concrete test
/// (<method>OcuPilot.Kernel.Provider.Base.KeyShapeAccepted</method>).</p>
/// <p>This row declares no prefix, and that is deliberate: the vendor's authentication reference
/// publishes no key grammar and names workload-identity access tokens as valid bearer
/// credentials, so a prefix gate would refuse currently-issued credentials.</p>
Method IsApiKeyShapeValid() As %Boolean
{
    Quit ..KeyShapeAccepted()
}

/// <p>Read a successful reply into <var>pResponse</var> through the message translator, which is
/// where this dialect's <code>choices</code>, <code>tool_calls</code>, <code>finish_reason</code>
/// and usage field names are read.</p>
Method MapResponse(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response) As %Status
{
    Quit ##class(OcuPilot.Kernel.Provider.MessageAdapter).OpenAiToCanonical(pBody, pResponse)
}

}
