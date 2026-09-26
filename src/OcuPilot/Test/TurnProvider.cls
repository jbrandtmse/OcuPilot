/// <p>The scripted adapter behind the armed <code>turnprobe</code> catalog row: an
/// <class>OcuPilot.Kernel.Provider.Anthropic</class> whose <method>IssueHttpsPost</method> answers
/// from a script instead of opening a socket. Everything above that one method -- the credential
/// resolution, the key-shape gate, the body the adapter builds -- is the shipped code.</p>
/// <p><b>Its state is instance-wide</b>, under <code>^IRIS.Temp.OcuPilotTurnProvider(tag)</code>,
/// because the process it runs in is a turn job the test did not start in-process; the tag is the
/// request's <code>model</code>, so each test selects its own script by naming a model.</p>
/// <p><b>What it records per call</b>, under <code>(tag, "call", n)</code>: <code>user</code>
/// (<code>$USERNAME</code>), <code>roles</code> (<code>$ROLES</code>), <code>keySha</code> (the
/// SHA-256 of the key header, hex; the key itself is never recorded), <code>systemPresent</code>,
/// <code>system</code>, <code>messages</code> (the request's messages as JSON, decoded from the
/// UTF-8 bytes the adapter wrote), <code>tools</code> (the request's tool array as JSON, or
/// <code>""</code> when it carried none), <code>at</code> and, once its hang is over,
/// <code>returned</code> (both in <method>OcuPilot.Kernel.State.Turn.NowSeconds</method> units).</p>
/// <p>A script entry is a hang in seconds, a reply body, an HTTP status and a
/// <code>Retry-After</code> header value; entries are consumed in call order and the last one
/// repeats. With no script a call answers a short text reply, HTTP 200, at once. A scripted status
/// of <code>0</code> is a transport timeout and <code>-1</code> any other transport failure, both
/// instead of an HTTP answer.</p>
/// <p><b>Streaming (Story 11.7).</b> A call that streams -- a turn passes a sink, and
/// <method>Plain</method> has not turned its tag off -- is answered a scripted HTTP 200 by feeding
/// <method>OcuPilot.Test.SseFixture.Anthropic</method> of the scripted body into the request's chunk
/// reader in 7-byte slices, as the real transport would; <method>ScriptStream</method> paces those
/// slices and can break the stream at half. The call records <code>stream</code>, 1 when the
/// request asked for a stream.</p>
Class OcuPilot.Test.TurnProvider Extends OcuPilot.Kernel.Provider.Anthropic
{

/// <p>Append a script entry for <var>pTag</var>: hang <var>pHangSeconds</var>, then answer
/// <var>pReplyBody</var> with HTTP <var>pHttpStatus</var> and the <code>Retry-After</code> header
/// value <var>pRetryAfter</var>. Refuses an unarmed (empty) tag rather than scripting a call nothing
/// will ever ask for (DW-1086) -- the caller-facing seam <method>OcuPilot.Test.TurnProvider
/// .Script</method>'s own %Status callers should check, not a value they discard.</p>
/// <p><b>The last two arguments are what makes a provider failure reachable from a real turn job</b>
/// (Story 4.8): until they existed this adapter answered 200 whatever it was asked, so no test
/// could drive a turn to <code>PROVIDER.*</code>. They default to today's answer, so every caller
/// written before them is unchanged.</p>
/// <p><var>pHttpStatus</var> <code>0</code> and <code>-1</code> are this seam's own contract for
/// "no HTTP answer at all", and they are the two <class>%Status</class> values
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> tells apart: <code>0</code> is the
/// timeout it reports as <code>PROVIDER.TIMEOUT</code> and <code>-1</code> every other transport
/// failure, which it reports as <code>PROVIDER.TRANSPORT</code>. Neither sends a body or a
/// header.</p>
ClassMethod Script(pTag As %String, pHangSeconds As %Numeric, pReplyBody As %String, pHttpStatus As %Integer = 200, pRetryAfter As %String = "") As %Status
{
    If pTag = "" Quit $$$ERROR($$$GeneralError, "Script requires a tag")
    Set tIndex = $Increment(^IRIS.Temp.OcuPilotTurnProvider(pTag, "script"))
    Set ^IRIS.Temp.OcuPilotTurnProvider(pTag, "script", tIndex) = $ListBuild(+pHangSeconds, pReplyBody, +pHttpStatus, pRetryAfter)
    Quit $$$OK
}

/// <p>Append a streamed script entry for <var>pTag</var>: hang <var>pHangSeconds</var> before the
/// status line, then stream <var>pReplyBody</var> with HTTP 200, spreading
/// <var>pMidHangSeconds</var> evenly across its slices. <var>pBreakAtHalf</var> stops after half
/// the bytes and answers the <code>&lt;READ&gt;</code> error a dropped connection produces. A call
/// that does not stream answers the body plain.</p>
ClassMethod ScriptStream(pTag As %String, pHangSeconds As %Numeric, pReplyBody As %String, pMidHangSeconds As %Numeric = 0, pBreakAtHalf As %Boolean = 0) As %Status
{
    If pTag = "" Quit $$$ERROR($$$GeneralError, "ScriptStream requires a tag")
    Set tIndex = $Increment(^IRIS.Temp.OcuPilotTurnProvider(pTag, "script"))
    Set ^IRIS.Temp.OcuPilotTurnProvider(pTag, "script", tIndex) = $ListBuild(+pHangSeconds, pReplyBody, 200, "", +pMidHangSeconds, ''pBreakAtHalf)
    Quit $$$OK
}

/// <p>Make every call for <var>pTag</var> plain: <method>StreamsFor</method> answers 0, so the
/// request asks for no stream and the scripted body is answered whole.</p>
ClassMethod Plain(pTag As %String) As %Status
{
    If pTag = "" Quit $$$ERROR($$$GeneralError, "Plain requires a tag")
    Set ^IRIS.Temp.OcuPilotTurnProvider(pTag, "plain") = 1
    Quit $$$OK
}

/// <p>The base's answer, and 0 for a tag <method>Plain</method> turned off.</p>
Method StreamsFor(ByRef pSettings, ByRef pValues) As %Boolean
{
    Set tTag = $Get(pValues("model"))
    If (tTag '= "") && +$Get(^IRIS.Temp.OcuPilotTurnProvider(tTag, "plain")) Quit 0
    Quit ##super(.pSettings, .pValues)
}

/// <p>Remove <var>pTag</var>'s script and records.</p>
ClassMethod Forget(pTag As %String)
{
    Kill ^IRIS.Temp.OcuPilotTurnProvider(pTag)
}

/// <p>Whether any node remains for <var>pTag</var>.</p>
ClassMethod Remains(pTag As %String) As %Boolean
{
    Quit ($Data(^IRIS.Temp.OcuPilotTurnProvider(pTag)) > 0)
}

/// <p>How many calls <var>pTag</var> has answered, or begun answering.</p>
ClassMethod Calls(pTag As %String) As %Integer
{
    Quit +$Get(^IRIS.Temp.OcuPilotTurnProvider(pTag, "calls"))
}

/// <p>What call <var>pCall</var> for <var>pTag</var> recorded under <var>pField</var>.</p>
ClassMethod Recorded(pTag As %String, pCall As %Integer, pField As %String) As %String
{
    Quit $Get(^IRIS.Temp.OcuPilotTurnProvider(pTag, "call", pCall, pField))
}

/// <p>A reply body that ends the turn with <var>pText</var>, reporting <var>pInput</var> and
/// <var>pOutput</var> tokens.</p>
ClassMethod TextReply(pText As %String, pInput As %Integer = 1, pOutput As %Integer = 2) As %String
{
    Set tBody = {"content": [{"type": "text"}], "stop_reason": "end_turn", "usage": {}}
    Do tBody.content.%Get(0).%Set("text", pText, "string")
    Do tBody.usage.%Set("input_tokens", +pInput, "number")
    Do tBody.usage.%Set("output_tokens", +pOutput, "number")
    Quit tBody.%ToJSON()
}

/// <p>A reply body that asks for tools. <var>pCalls</var> is one tool's name, called with id
/// <code>toolu_probe</code> and input <code>{}</code>, or a <class>%DynamicArray</class> of
/// <code>{name, id, input}</code>, one <code>tool_use</code> block each, in order.</p>
ClassMethod ToolUseReply(pCalls As %RawString, pInput As %Integer = 1, pOutput As %Integer = 2) As %String
{
    Set tBody = {"content": [], "stop_reason": "tool_use", "usage": {}}
    Set tCalls = pCalls
    If '$IsObject(tCalls) {
        Set tCalls = []
        Do tCalls.%Push({"id": "toolu_probe", "input": {}})
        Do tCalls.%Get(0).%Set("name", pCalls, "string")
    }
    Set tIterator = tCalls.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCall) {
        Set tBlock = {"type": "tool_use"}
        Do tBlock.%Set("id", tCall.%Get("id"), "string")
        Do tBlock.%Set("name", tCall.%Get("name"), "string")
        Do tBlock.%Set("input", $Select($IsObject(tCall.%Get("input")): tCall.%Get("input"), 1: {}))
        Do tBody.content.%Push(tBlock)
    }
    Do tBody.usage.%Set("input_tokens", +pInput, "number")
    Do tBody.usage.%Set("output_tokens", +pOutput, "number")
    Quit tBody.%ToJSON()
}

/// <p>The SHA-256 of <var>pValue</var>'s UTF-8 bytes, as lower-case hex -- the form
/// <method>IssueHttpsPost</method> records a key header in, computed there inline so the header's
/// value is never bound to a variable.</p>
ClassMethod Sha(pValue As %String) As %String
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(pValue, "O", "UTF8"))), "L")
}

/// <p>Record what the request carried, hang as scripted, and answer the scripted body.</p>
Method IssueHttpsPost(pRequest As %Net.HttpRequest, pUrl As %String, Output pStatus As %Integer, Output pBody As %String, Output pRetryAfter As %String) As %Status
{
    Set pStatus = 0
    Set pBody = ""
    Set pRetryAfter = ""
    Set tRaw = ""
    Do pRequest.EntityBody.Rewind()
    While 'pRequest.EntityBody.AtEnd {
        Set tRaw = tRaw _ pRequest.EntityBody.Read(32000)
    }
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tRaw, "I", "UTF8"))
    Set tTag = tSent.model
    Set tCall = $Increment(^IRIS.Temp.OcuPilotTurnProvider(tTag, "calls"))
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "user") = $Username
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "roles") = $Roles
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "keySha") = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(pRequest.GetHeader("x-api-key"), "O", "UTF8"))), "L")
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "systemPresent") = tSent.%IsDefined("system")
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "system") = tSent.system
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "messages") = tSent.messages.%ToJSON()
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "tools") = $Select($IsObject(tSent.tools): tSent.tools.%ToJSON(), 1: "")
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "at") = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "stream") = ''tSent.stream
    Set tIndex = tCall
    If tIndex > +$Get(^IRIS.Temp.OcuPilotTurnProvider(tTag, "script")) Set tIndex = +$Get(^IRIS.Temp.OcuPilotTurnProvider(tTag, "script"))
    Set tEntry = $Select(tIndex > 0: $Get(^IRIS.Temp.OcuPilotTurnProvider(tTag, "script", tIndex)), 1: "")
    If tEntry = "" Set tEntry = $ListBuild(0, ..TextReply("ok"))
    If $List(tEntry, 1) > 0 Hang $List(tEntry, 1)
    Set ^IRIS.Temp.OcuPilotTurnProvider(tTag, "call", tCall, "returned") = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    ; An entry written before the status was scriptable, and the unscripted default, both carry no
    ; status: 200 is what this adapter has always answered and stays the answer.
    Set tStatus = $Select($ListGet(tEntry, 3) = "": 200, 1: +$ListGet(tEntry, 3))
    If tStatus = 0 Quit $$$ERROR($$$CSPTimeout)
    If tStatus < 0 Quit $$$ERROR($$$GeneralError, "scripted transport failure")
    Set pStatus = tStatus
    Set pBody = $List(tEntry, 2)
    Set pRetryAfter = $ListGet(tEntry, 4)
    If (tStatus '= 200) || '$IsObject(pRequest.ResponseChunkReader) Quit $$$OK
    ; A body the fixture cannot turn into a stream is answered plain, as it always was.
    Set tBytes = ""
    Try {
        Set tBytes = $ZConvert(##class(OcuPilot.Test.SseFixture).Anthropic(pBody), "O", "UTF8")
    } Catch ex {
        Set tBytes = ""
    }
    If tBytes = "" Quit $$$OK
    Set pBody = ""
    Set tHalf = $Select(+$ListGet(tEntry, 6): $Length(tBytes) \ 2, 1: 0)
    Set tSlices = ($Select(tHalf > 0: tHalf, 1: $Length(tBytes)) + 6) \ 7
    Set tPace = $Select(tSlices > 1: +$ListGet(tEntry, 5) / (tSlices - 1), 1: 0)
    Do ##class(OcuPilot.Test.ProviderStubTransport).Feed(pRequest.ResponseChunkReader, tBytes, 7, tHalf, tPace)
    If tHalf > 0 Quit $$$ERROR($$$TCPIPError, "<READ>", 0)
    Quit $$$OK
}

}
