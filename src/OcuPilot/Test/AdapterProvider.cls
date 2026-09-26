/// <p>A family adapter that exists only as a probe catalog row plus this class, which is what
/// makes "a second family is one row plus one adapter" (AD-42) an observation rather than an
/// assertion against the single shipped row.</p>
/// <p>It extends <class>OcuPilot.Test.ProviderStub</class>, so the recording transport seam, the
/// queued answer script and the fake clock are inherited and <b>no socket is opened</b>. What it
/// overrides is the family contract and nothing else: <method>CallMessages</method> builds the
/// dialect's own body through
/// <class>OcuPilot.Kernel.Provider.MessageAdapter</class> and
/// <class>OcuPilot.Kernel.Provider.ToolDefAdapter</class>, and <method>MapResponse</method> reads
/// the dialect's own reply back through the same message adapter.</p>
/// <p><b>The dialect is a switch, not a second class</b> (<method>SetDialect</method>), because the
/// translators are what is under test and one adapter exercising both directions of both dialects
/// is the smallest fixture that does it. Unset, the dialect is
/// <parameter>DIALECTCANONICAL</parameter> and every method falls through to the inherited
/// Anthropic behaviour, so an inherited test that reaches this class sees no change.</p>
/// <p>The switch lives in a process-private global for the reason the stub's script does: the port
/// constructs the adapter itself, so a test has no reference to set a property on.</p>
Class OcuPilot.Test.AdapterProvider Extends OcuPilot.Test.ProviderStub
{

/// <p>The identity this adapter reports through <method>OcuPilot.Test.ProviderStub.ServedBy</method>.</p>
Parameter STUBIDENTITY = "adapterprovider";

/// <p>The dialect switch value for the OpenAI pair.</p>
Parameter DIALECTOPENAI = "openai";

/// <p>The dialect switch value for the Gemini pair.</p>
Parameter DIALECTGEMINI = "gemini";

/// <p>The dialect switch value for the canonical family: no translator is reached and the
/// inherited Anthropic passthrough serves the call. Also the answer when nothing is set.</p>
Parameter DIALECTCANONICAL = "canonical";

/// <p>Serve subsequent calls in <var>pDialect</var> -- one of the three parameters above.</p>
ClassMethod SetDialect(pDialect As %String)
{
    Set ^||OcuPilotAdapterProvider("dialect") = pDialect
}

/// <p>Forget the dialect, so the next call is served canonically. Called from a test's teardown,
/// since <method>OcuPilot.Test.ProviderStub.Reset</method> owns a different global.</p>
ClassMethod Forget()
{
    Kill ^||OcuPilotAdapterProvider
}

/// <p>The dialect in force.</p>
ClassMethod Dialect() As %String
{
    If $Get(^||OcuPilotAdapterProvider("dialect")) = "" Quit ..#DIALECTCANONICAL
    Quit ^||OcuPilotAdapterProvider("dialect")
}

/// <p>Build the request body in the dialect in force, through the two translators, and attach it
/// to <var>pRequest</var>. The canonical dialect defers to the inherited passthrough.</p>
/// <p><b>The body carries the translators' output, a model and a token cap, and nothing else.</b>
/// The endpoint each family answers on, the generation settings it spells its own way and the auth
/// it wants are the shipped adapters' own business, in Stories 10.2 and 10.3; this fixture exists
/// to record what the translators produced, not to be copied as a family adapter.</p>
/// <p>An error <class>%Status</class> from either translator is returned unchanged, so a
/// translation that cannot be completed reaches
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s body-could-not-be-built exit and no
/// call is made.</p>
Method CallMessages(pRequest As %Net.HttpRequest, ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt As %String) As %Status
{
    If ..Dialect() = ..#DIALECTCANONICAL Quit ##super(pRequest, .pValues, .pMessages, .pTools, pSystemPrompt)
    Set tSC = $$$OK
    Try {
        Set tBody = {}
        Do tBody.%Set("model", $Get(pValues("model")), "string")
        If ..Dialect() = ..#DIALECTOPENAI {
            Set tSC = ##class(OcuPilot.Kernel.Provider.MessageAdapter).CanonicalToOpenAi(.pMessages, pSystemPrompt, .tMessageArray)
            If $$$ISERR(tSC) Quit
            Do tBody.%Set("max_tokens", +$Get(pValues("maxTokens")), "number")
            Do tBody.%Set("messages", tMessageArray)
            If +$Get(pTools) > 0 {
                Set tSC = ##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToOpenAi(.pTools, .tToolArray)
                If $$$ISERR(tSC) Quit
                Do tBody.%Set("tools", tToolArray)
            }
        } Else {
            Set tSC = ##class(OcuPilot.Kernel.Provider.MessageAdapter).CanonicalToGemini(.pMessages, pSystemPrompt, .tContents, .tSystemInstruction)
            If $$$ISERR(tSC) Quit
            Do tBody.%Set("contents", tContents)
            If $IsObject(tSystemInstruction) Do tBody.%Set("systemInstruction", tSystemInstruction)
            If +$Get(pTools) > 0 {
                Set tSC = ##class(OcuPilot.Kernel.Provider.ToolDefAdapter).ToGemini(.pTools, .tToolArray)
                If $$$ISERR(tSC) Quit
                Do tBody.%Set("tools", tToolArray)
            }
        }
        Do pRequest.EntityBody.Clear()
        Do pRequest.EntityBody.Write($ZConvert(tBody.%ToJSON(), "O", "UTF8"))
        ; Set after the write, for the reason the Anthropic adapter records: ContentType is a
        ; calculated property over an attribute of the entity-body stream.
        Set pRequest.ContentType = ..#CONTENTTYPE
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Record the message of every log line the base emits during a call, then log it as the base
/// would. <method>Logged</method> reads the recording back, so a claim about a line OcuPilot wrote
/// is asserted against the line rather than against the condition that should have produced it.</p>
ClassMethod LogRaw(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tNext = +$Get(^||OcuPilotAdapterProvider("log")) + 1
    Set ^||OcuPilotAdapterProvider("log") = tNext
    Set ^||OcuPilotAdapterProvider("log", tNext) = pMessage
    Do ##super(pMessage, pStatus, pCode)
}

/// <p>How many recorded log lines carry <var>pFragment</var>. <method>Forget</method> clears the
/// recording, since it owns the same global.</p>
ClassMethod Logged(pFragment As %String) As %Integer
{
    Set tCount = 0
    For tI = 1:1:+$Get(^||OcuPilotAdapterProvider("log")) {
        If $Get(^||OcuPilotAdapterProvider("log", tI)) [ pFragment Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Read the reply in the dialect in force back into <var>pResponse</var>. The canonical dialect
/// defers to the inherited passthrough.</p>
Method MapResponse(pBody As %String, pResponse As OcuPilot.Kernel.Provider.Response) As %Status
{
    If ..Dialect() = ..#DIALECTOPENAI Quit ##class(OcuPilot.Kernel.Provider.MessageAdapter).OpenAiToCanonical(pBody, pResponse)
    If ..Dialect() = ..#DIALECTGEMINI Quit ##class(OcuPilot.Kernel.Provider.MessageAdapter).GeminiToCanonical(pBody, pResponse)
    Quit ##super(pBody, pResponse)
}

}
