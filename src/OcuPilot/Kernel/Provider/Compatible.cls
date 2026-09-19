/// <p>The OpenAI-compatible adapter (AD-42): the Chat Completions wire, served by a model on the
/// operator's own network or by a third-party gateway that speaks the same dialect. It differs from
/// <class>OcuPilot.Kernel.Provider.OpenAI</class> in three things and nothing else -- the endpoint
/// is normalized rather than stored complete, the credential is optional, and its catalog row is the
/// one shipped row that sets <code>allowsLocal</code>.</p>
/// <p><b>The translation is the OpenAI pair, unchanged.</b>
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.CanonicalToOpenAi</method>,
/// <method>OcuPilot.Kernel.Provider.ToolDefAdapter.ToOpenAi</method> and
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.OpenAiToCanonical</method> are inherited through
/// that class, so a body this adapter builds and a reply it reads are that family's own and the
/// locked JSON-Schema subset is not relaxed.</p>
/// <p><b>This class is reached only through its catalog row's <code>adapterClass</code>
/// column.</b> Nothing names it in a branch.</p>
/// <p>Wire contract, verified against the four endpoints operators actually name (Ollama, vLLM, LM
/// Studio and OpenRouter, vendor docs retrieved 2026-09-19): <code>POST</code> to
/// <code>&lt;base&gt;/chat/completions</code>, header <code>Authorization: Bearer &lt;key&gt;</code>
/// where a key is configured and <b>no such header at all</b> where none is; body and reply the
/// Chat Completions ones. Ollama, vLLM and LM Studio serve an unauthenticated request by default
/// and OpenRouter always requires a key, which is why the credential is optional rather than
/// absent. No API-version header exists for this dialect, so the row's <code>authVersion</code> is
/// empty and nothing sends one.</p>
Class OcuPilot.Kernel.Provider.Compatible Extends OcuPilot.Kernel.Provider.OpenAI
{

/// <p>The path segment a Chat Completions request is issued to, appended to a stored base endpoint
/// that does not already end in it.</p>
Parameter COMPLETIONSPATH = "/chat/completions";

/// <p>The provider key whose catalog row points at this class.</p>
Method ProviderName() As %String
{
    Quit "compatible"
}

/// <p>The stored endpoint with <parameter>COMPLETIONSPATH</parameter> appended when its path does
/// not already end in it, and unchanged when it does.</p>
/// <p><b>Both spellings are accepted because both are what operators have.</b> Every one of the four
/// endpoints this family serves documents a base ending <code>/v1</code>, and the OpenAI client
/// convention appends the operation; the shipped <code>openai</code> row instead stores the complete
/// URL. Normalizing here is what keeps the operator from having to guess which one this field
/// wants.</p>
/// <p><b>The scheme and the authority are left byte-identical</b>, so
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s origin check passes: only the path is
/// written, from a fixed literal and never from a caller-supplied value (AD-21). A query or a
/// fragment the operator stored is kept after the appended segment rather than being written
/// into.</p>
Method RequestUrl(ByRef pValues) As %String
{
    Set tUrl = ""
    Try {
        Set tEndpoint = $Get(pValues("endpointUrl"))
        If tEndpoint = "" Quit
        ; The path decides; a query or a fragment is split off first so nothing is appended inside
        ; one, and re-attached after the segment.
        Set tMark = 0
        If tEndpoint [ "?" Set tMark = $Find(tEndpoint, "?") - 1
        If tEndpoint [ "#" {
            Set tHash = $Find(tEndpoint, "#") - 1
            If (tMark = 0) || (tHash < tMark) Set tMark = tHash
        }
        Set tHead = $Select(tMark > 0: $Extract(tEndpoint, 1, tMark - 1), 1: tEndpoint)
        Set tTail = $Select(tMark > 0: $Extract(tEndpoint, tMark, $Length(tEndpoint)), 1: "")
        ; One trailing slash is tolerated, because a pasted base often carries one.
        If $Extract(tHead, $Length(tHead)) = "/" Set tHead = $Extract(tHead, 1, $Length(tHead) - 1)
        If tHead = "" Quit
        If $Extract(tHead, $Length(tHead) - $Length(..#COMPLETIONSPATH) + 1, $Length(tHead)) '= ..#COMPLETIONSPATH {
            Set tHead = tHead _ ..#COMPLETIONSPATH
        }
        Set tUrl = tHead _ tTail
    } Catch ex {
        Set tUrl = ""
    }
    Quit tUrl
}

}
