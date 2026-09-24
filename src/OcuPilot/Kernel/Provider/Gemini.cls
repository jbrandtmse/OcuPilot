/// <p>The Google Gemini <code>generateContent</code> adapter (AD-42). The canonical shapes are
/// Anthropic's, so everything about the wire is a translation: the body is built through
/// <class>OcuPilot.Kernel.Provider.MessageAdapter</class> and
/// <class>OcuPilot.Kernel.Provider.ToolDefAdapter</class>, and the reply is read back through the
/// first of those.</p>
/// <p><b>This class is reached only through its catalog row's <code>adapterClass</code>
/// column.</b> Nothing names it in a branch, which is what makes adding a family one row plus one
/// class.</p>
/// <p><b>This family names the model in the endpoint's path</b>, which is why
/// <method>RequestUrl</method> is overridden: the row's endpoint carries
/// <parameter>MODELPLACEHOLDER</parameter> and the definition's model replaces it. The model is
/// gated to <parameter>MODELPATTERN</parameter> first (AD-21) and the base then re-checks that the
/// URL's scheme and authority are still the ones the address policy judged, so a model that would
/// not survive substitution is refused <code>PROVIDER.EGRESS</code> with no socket opened.</p>
/// <p>Wire contract, verified against the vendor's published <code>generateContent</code>
/// reference (<code>ai.google.dev/api/generate-content</code>, 2026-09-18): <code>POST</code> to
/// the resolved endpoint with headers <code>x-goog-api-key</code> and <code>content-type</code>;
/// body
/// <code>{contents, systemInstruction?, tools?, generationConfig{maxOutputTokens, temperature?}}</code>,
/// <code>temperature</code> only when the definition holds one;
/// reply <code>{candidates, usageMetadata}</code>; error body <code>{error: {message}}</code>.
/// <b>The credential goes in the header, never in the <code>?key=</code> query parameter</b> the
/// wider Google API surface also accepts: a credential in a URL is refused by AD-35. The API
/// version is the endpoint's own path segment, so the row's <code>authVersion</code> is empty and
/// nothing sends a version header.</p>
Class OcuPilot.Kernel.Provider.Gemini Extends OcuPilot.Kernel.Provider.Base
{

/// <p>The header the credential is sent in.</p>
Parameter KEYHEADER = "x-goog-api-key";

/// <p>The body's media type.</p>
Parameter CONTENTTYPE = "application/json";

/// <p>The token the row's endpoint carries where the model belongs.</p>
Parameter MODELPLACEHOLDER = "{model}";

/// <p>The shape a model must have to enter a URL path: letters, digits, dot, underscore and
/// hyphen, and at least one character. It admits the bare model id this endpoint's path expects
/// and no character that could add a path segment, a query, a fragment or an authority -- so a
/// qualified resource name (<code>models/&lt;id&gt;</code>, <code>tunedModels/&lt;id&gt;</code>)
/// is refused, because the placeholder already sits under the endpoint's own
/// <code>models/</code> segment.</p>
Parameter MODELPATTERN = "^[A-Za-z0-9._-]+$";

/// <p>The provider key whose catalog row points at this class.</p>
Method ProviderName() As %String
{
    Quit "gemini"
}

/// <p>The judged endpoint with <parameter>MODELPLACEHOLDER</parameter> replaced by the
/// definition's model, or <code>""</code> when the model is not one
/// <parameter>MODELPATTERN</parameter> admits -- which
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> refuses
/// <code>PROVIDER.EGRESS</code> before any socket is opened.</p>
/// <p>An endpoint carrying no placeholder is answered unchanged, so an operator who stored a
/// model-specific endpoint is not required to write one in.</p>
Method RequestUrl(ByRef pValues) As %String
{
    Set tUrl = ""
    Try {
        Set tEndpoint = $Get(pValues("endpointUrl"))
        If tEndpoint = "" Quit
        If '(tEndpoint [ ..#MODELPLACEHOLDER) {
            Set tUrl = tEndpoint
            Quit
        }
        Set tModel = $Get(pValues("model"))
        If '$Match(tModel, ..#MODELPATTERN) Quit
        Set tUrl = $Replace(tEndpoint, ..#MODELPLACEHOLDER, tModel)
    } Catch ex {
        Set tUrl = ""
    }
    Quit tUrl
}

/// <p>The <code>generateContent</code> request body, attached to <var>pRequest</var>. The model is
/// not in it: this family carries the model in the URL (<method>RequestUrl</method>).</p>
/// <p>An error <class>%Status</class> from either translator is returned unchanged, so a history
/// or a tool array that cannot be translated reaches
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s body-could-not-be-built exit and no
/// call is made.</p>
/// <p><code>systemInstruction</code> and <code>tools</code> are omitted rather than sent empty: an
/// empty instruction is not the same request as none, and an empty declaration list advertises a
/// tool set the turn does not have. <b>The body is written as UTF-8 bytes</b> and the media type is
/// set after the write, because <property>%Net.HttpRequest.ContentType</property> is a calculated
/// property over an attribute of the entity-body stream and <code>Clear()</code> drops it.</p>
Method CallMessages(pRequest As %Net.HttpRequest, ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Provider.MessageAdapter).CanonicalToGemini(.pMessages, pSystemPrompt, .tContents, .tSystemInstruction)
        If $$$ISERR(tSC) Quit
        Set tBody = {}
        Do tBody.%Set("contents", tContents)
        If $IsObject(tSystemInstruction) Do tBody.%Set("systemInstruction", tSystemInstruction)
        If +$Get(pTools) > 0 {
            Set tSC = ##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToGemini(.pTools, .tToolArray)
            If $$$ISERR(tSC) Quit
            If tToolArray.%Size() > 0 Do tBody.%Set("tools", tToolArray)
        }
        Set tGeneration = {}
        Do tGeneration.%Set("maxOutputTokens", +$Get(pValues("maxTokens")), "number")
        If $Get(pValues("temperature")) '= "" Do tGeneration.%Set("temperature", +pValues("temperature"), "number")
        Do tBody.%Set("generationConfig", tGeneration)
        Do pRequest.EntityBody.Clear()
        Do pRequest.EntityBody.Write($ZConvert(tBody.%ToJSON(), "O", "UTF8"))
        Set pRequest.ContentType = ..#CONTENTTYPE
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write the credential onto <var>pRequest</var>'s own header, and nothing else: this family
/// sends no version header. A call with no key writes no header at all rather than an empty
/// one.</p>
/// <p><b><property>OcuPilot.Kernel.Provider.Base.ApiKey</property> is read straight onto the
/// header.</b> No local holds it, and it never enters the URL (AD-35, AD-46, AD-48).</p>
Method ApplyAuth(pRequest As %Net.HttpRequest)
{
    If ..ApiKey = "" Quit
    Do pRequest.SetHeader(..#KEYHEADER, ..ApiKey)
}

/// <p>Whether <property>OcuPilot.Kernel.Provider.Base.ApiKey</property> is shaped like a key for
/// this family, which is the base's own concrete test
/// (<method>OcuPilot.Kernel.Provider.Base.KeyShapeAccepted</method>).</p>
/// <p>This row declares no prefix, and that is deliberate: since 2026-05-28 AI Studio issues
/// service-account-bound auth keys rather than the older standard keys, so a prefix gate would
/// refuse currently-issued credentials.</p>
Method IsApiKeyShapeValid() As %Boolean
{
    Quit ..KeyShapeAccepted()
}

/// <p>Read a successful reply into <var>pResponse</var> through the message translator, which is
/// where this dialect's <code>candidates</code>, <code>functionCall</code>,
/// <code>finishReason</code> and usage field names are read.</p>
Method MapResponse(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response) As %Status
{
    Quit ##class(OcuPilot.Kernel.Provider.MessageAdapter).GeminiToCanonical(pBody, pResponse)
}

}
