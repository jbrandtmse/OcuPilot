/// <p>What <class>OcuPilot.Test.AdapterCache</class> and <class>OcuPilot.Test.AdapterScope</class>
/// share: the request each provider family builds for a canonical message and tool array, observed on
/// the request its stub recorded -- Anthropic through <class>OcuPilot.Test.ProviderStub</class> as
/// <class>OcuPilot.Test.Provider</class> drives it, the other three through the stub of their shipped
/// row on an adapter instance directly, as <class>OcuPilot.Test.OpenAIAdapter</class>,
/// <class>OcuPilot.Test.GeminiAdapter</class> and <class>OcuPilot.Test.CompatibleAdapter</class> do.
/// It declares no test of its own. <b>Live-safe</b>: it opens no socket and stores nothing.</p>
Class OcuPilot.Test.AdapterCacheCase Extends %UnitTest.TestCase [ Abstract ]
{

/// <p>The system prompt every call sends.</p>
Parameter SYSTEMPROMPT = "you are a probe";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Quit $$$OK
}

/// <p>Three tools, so the last is told from the rest.</p>
ClassMethod Tools(Output pTools)
{
    Kill pTools
    Set pTools = 3
    For tI = 1:1:3 {
        Set pTools(tI, "name") = "logs_probe" _ tI _ "_read"
        Set pTools(tI, "description") = "probe tool " _ tI
        Set pTools(tI, "inputSchema") = "{""type"":""object"",""properties"":{""maxRows"":{""type"":""integer"",""description"":""how many""}},""required"":[],""additionalProperties"":false}"
    }
}

/// <p>One Anthropic call through the stub with <var>pMessages</var> and <var>pTools</var>, answering
/// <var>pReply</var>; the request it recorded, parsed, with the mapped reply in
/// <var>pResponse</var>.</p>
Method AnthropicCall(ByRef pMessages, ByRef pTools, pReply As %String, Output pResponse As OcuPilot.Kernel.Provider.Response) As %DynamicObject
{
    Do ##class(OcuPilot.Test.SecretProbe).SetValue($Parameter("OcuPilot.Test.Provider", "PROBEKEY"))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, pReply)
    Do ##class(OcuPilot.Test.Provider).Values(.tValues)
    Do ##class(OcuPilot.Test.Provider).Settings(.tSettings)
    Set tAdapter = ##class(OcuPilot.Test.ProviderStub).%New()
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Do $$$AssertStatusOK(tAdapter.Invoke(.tValues, .pMessages, .pTools, ..#SYSTEMPROMPT, .tSettings, .pResponse, .tFault, .tHttpStatus), "the call returns $$$OK")
    Set tAdapter = ""
    Do $$$AssertTrue('$IsObject($Get(tFault)), "with no fault")
    Quit ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1))
}

/// <p>One call through family <var>pFamily</var>'s shipped stub -- <code>openai</code>,
/// <code>gemini</code> or <code>compatible</code> -- on an adapter instance directly, with
/// <var>pTools</var>, answering <var>pReply</var>. The request text it recorded; the mapped reply in
/// <var>pResponse</var>.</p>
Method FamilyCall(pFamily As %String, ByRef pTools, pReply As %String, Output pResponse As OcuPilot.Kernel.Provider.Response) As %String
{
    Set tCase = $Case(pFamily, "openai": "OcuPilot.Test.OpenAIAdapter", "gemini": "OcuPilot.Test.GeminiAdapter", "compatible": "OcuPilot.Test.CompatibleAdapter", : "")
    Do $$$AssertTrue(tCase '= "", pFamily _ " is a family this class drives")
    If tCase = "" Quit ""
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row(pFamily, .tRow), 1, "the shipped " _ pFamily _ " row is readable")
    If pFamily = "compatible" {
        Do $ClassMethod(tCase, "DirectValues", tRow, $Parameter(tCase, "BASEENDPOINT"), .tValues)
    } Else {
        Do $ClassMethod(tCase, "DirectValues", tRow, .tValues)
    }
    Do ##class(OcuPilot.Test.SecretProbe).SetValue($Parameter(tCase, "PROBEKEY"))
    Do ##class(OcuPilot.Test.Adapter).Canonical(.tMessages)
    Do ##class(OcuPilot.Test.Provider).Settings(.tSettings)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, pReply)
    Set tAdapter = $ClassMethod(tCase, "Adapter")
    Do $$$AssertStatusOK(tAdapter.Invoke(.tValues, .tMessages, .pTools, ..#SYSTEMPROMPT, .tSettings, .pResponse, .tFault, .tHttpStatus), pFamily _ ": the call returns $$$OK")
    Set tAdapter = ""
    Do $$$AssertTrue('$IsObject($Get(tFault)), pFamily _ ": with no fault")
    Quit ##class(OcuPilot.Test.ProviderStub).Recorded("body", 1)
}

}
