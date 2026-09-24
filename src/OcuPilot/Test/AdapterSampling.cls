/// <p>Story 10.4's wire half: which sampling fields each shipped catalog row's adapter sends. A
/// stored temperature reaches the OpenAI, Gemini and OpenAI-compatible bodies only when it is set,
/// the Anthropic body never carries a sampling parameter, each row's
/// <code>acceptsTemperature</code> column agrees with what its adapter actually sends, and only
/// the <code>openai</code> row's body carries <code>reasoning_effort</code>.</p>
/// <p>Every leg drives a <b>shipped</b> row through
/// <method>OcuPilot.Port.ProviderPort.Invoke</method> with only the transport swapped: the three
/// OpenAI-family rows through <class>OcuPilot.Test.CatalogProbeShipped</class>, the
/// <code>anthropic</code> row through <class>OcuPilot.Test.CatalogAnthropicStub</class>. Needs a
/// writable protected database and a resolver that answers the shipped endpoints' hosts; opens no
/// socket and reads no key. The definitions it stores are removed after each method.</p>
Class OcuPilot.Test.AdapterSampling Extends %UnitTest.TestCase
{

/// <p>The port entry, with its switched catalog, gate, credential class and TLS answer.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>The catalog that re-adapts the three OpenAI-family rows to their stubs.</p>
Parameter SHIPPEDCATALOG = "OcuPilot.Test.CatalogProbeShipped";

/// <p>The catalog that re-adapts the <code>anthropic</code> row to its stub.</p>
Parameter ANTHROPICCATALOG = "OcuPilot.Test.CatalogAnthropicStub";

/// <p>The shipped key <parameter>ANTHROPICCATALOG</parameter> re-adapts.</p>
Parameter ANTHROPICKEY = "anthropic";

/// <p>The package every stub adapter lives in; a row naming a class outside it is never called.</p>
Parameter STUBPACKAGE = "OcuPilot.Test.";

/// <p>A credential every shipped row's shape gate accepts: the Anthropic prefix, no whitespace.</p>
Parameter PROBEKEY = "sk-ant-probesamplingabcdefghij";

/// <p>The model a row that supplies none is stored with. Nothing connects to it.</p>
Parameter LOCALMODEL = "llama-3.3-70b-instruct";

/// <p>The loopback endpoint such a row is stored with, marked local.</p>
Parameter LOCALENDPOINT = "http://127.0.0.1:11434/v1";

/// <p>The explicit temperature the set legs store.</p>
Parameter SETTEMPERATURE = 0.7;

/// <p>The wire name of the one tool the tools legs advertise.</p>
Parameter TOOLNAME = "logs_errors_read";

/// <p>A Chat Completions reply, for the OpenAI-family rows.</p>
Parameter OPENAIREPLY = "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""ok""},""finish_reason"":""stop""}],""usage"":{""prompt_tokens"":1,""completion_tokens"":1}}";

/// <p>A <code>generateContent</code> reply, for the Gemini row.</p>
Parameter GEMINIREPLY = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""ok""}]},""finishReason"":""STOP""}],""usageMetadata"":{""promptTokenCount"":1,""candidatesTokenCount"":1}}";

/// <p>A Messages reply, for the Anthropic row.</p>
Parameter ANTHROPICREPLY = "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":1}}";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining), "every probe definition this method created is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Store a definition on the shipped row <var>pKey</var> holding <var>pTemperature</var>, make
/// one call through the port with the catalog that re-adapts that row to its stub, and answer the
/// body the stub recorded, parsed, or <code>""</code> when no call was made. With
/// <var>pWithTools</var> the call advertises one tool.</p>
/// <p>The call is made only when the switched catalog's row names a class in
/// <parameter>STUBPACKAGE</parameter>, so a re-adaptation that drifted can never reach a
/// vendor.</p>
Method BodyFor(pKey As %String, pTemperature As %String, pWithTools As %Boolean = 0) As %DynamicObject
{
    Set tBody = ""
    Try {
        Do $$$AssertTrue(##class(OcuPilot.Kernel.Provider.Catalog).Row(pKey, .tRow), pKey _ ": the shipped row is readable")
        If '$IsObject($Get(tRow)) Quit
        Set tCatalog = $Select(pKey = ..#ANTHROPICKEY: ..#ANTHROPICCATALOG, 1: ..#SHIPPEDCATALOG)
        Set tStubbed = $ClassMethod(tCatalog, "Row", pKey, .tStubRow)
        Set tAdapter = $Select(tStubbed && $IsObject($Get(tStubRow)): tStubRow.adapterClass, 1: "")
        Do $$$AssertEquals($Extract(tAdapter, 1, $Length(..#STUBPACKAGE)), ..#STUBPACKAGE, pKey _ ": the switched catalog answers a stub adapter, so no socket is opened: " _ tAdapter)
        If $Extract(tAdapter, 1, $Length(..#STUBPACKAGE)) '= ..#STUBPACKAGE Quit

        Set tDef = ##class(OcuPilot.Kernel.State.Agent).%New()
        Set tDef.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Sampling" _ pKey _ $Increment(^||OcuPilotAdapterSampling)
        Set tDef.Provider = pKey
        Set tDef.Model = $Select(tRow.defaultModel '= "": tRow.defaultModel, 1: ..#LOCALMODEL)
        If +tRow.endpointRequired {
            Set tDef.EndpointUrl = ..#LOCALENDPOINT
            Set tDef.MarkedLocal = 1
            Set tDef.HttpAcknowledged = 1
        }
        Set tDef.CredType = "env"
        Set tDef.EnvVarName = tRow.defaultEnvVarName
        Set tDef.MaxTokens = +tRow.canonicalMaxTokens
        Set tDef.Temperature = pTemperature
        Set tDef.Enabled = 1
        Set tDef.ConnectionVerified = 1
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tDef)
        Do $$$AssertStatusOK(tSC, pKey _ ": the probe definition holding temperature '" _ pTemperature _ "' is stored")
        If $$$ISERR(tSC) Quit
        Set tId = tDef.%Id()
        Set tDef = ""

        Do $ClassMethod(..#PORT, "SetCatalogClass", tCatalog)
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..ReplyFor(pKey))
        Kill tMessages, tTools
        Set tMessages = 1
        Set tMessages(1, "role") = "user"
        Set tMessages(1, "content") = "what is on this screen"
        If pWithTools {
            Set tTools = 1
            Set tTools(1, "name") = ..#TOOLNAME
            Set tTools(1, "description") = "read the error log"
            Set tTools(1, "inputSchema") = "{""type"":""object"",""properties"":{""maxRows"":{""type"":""integer"",""description"":""how many""}},""required"":[],""additionalProperties"":false}"
        }
        Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
        Do $$$AssertStatusOK(tSC, pKey _ ": the port returns $$$OK")
        Do $$$AssertTrue('$IsObject($Get(tFault)), pKey _ ": with no fault: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, pKey _ ": the stub's transport was entered once")
        Set tText = ##class(OcuPilot.Test.ProviderStub).Recorded("body", 1)
        If tText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tText, "I", "UTF8"))
        If $IsObject(tParsed) Set tBody = tParsed
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), pKey _ ": the call did not raise")
        Set tBody = ""
    }
    Quit tBody
}

/// <p>A well-formed reply in <var>pKey</var>'s own dialect.</p>
ClassMethod ReplyFor(pKey As %String) As %String
{
    If pKey = ..#ANTHROPICKEY Quit ..#ANTHROPICREPLY
    If pKey = "gemini" Quit ..#GEMINIREPLY
    Quit ..#OPENAIREPLY
}

/// <p>Where <var>pBody</var> carries a temperature, whichever dialect built it: the top-level
/// member, or Gemini's <code>generationConfig.temperature</code>. <code>""</code> when neither is
/// present.</p>
ClassMethod SentTemperature(pBody As %DynamicObject) As %String
{
    If '$IsObject(pBody) Quit ""
    If pBody.%GetTypeOf("temperature") '= "unassigned" Quit pBody.%Get("temperature")
    If $IsObject(pBody.generationConfig) && (pBody.generationConfig.%GetTypeOf("temperature") '= "unassigned") Quit pBody.generationConfig.%Get("temperature")
    Quit ""
}

/// <p>Whether <var>pBody</var> carries a temperature member anywhere a dialect puts one.</p>
ClassMethod CarriesTemperature(pBody As %DynamicObject) As %Boolean
{
    If '$IsObject(pBody) Quit 0
    If pBody.%GetTypeOf("temperature") '= "unassigned" Quit 1
    If $IsObject(pBody.generationConfig) && (pBody.generationConfig.%GetTypeOf("temperature") '= "unassigned") Quit 1
    Quit 0
}

/// <p>AC2 -- an unset temperature is not sent to the three families that take one: the OpenAI and
/// OpenAI-compatible bodies carry no <code>temperature</code> key, and Gemini's
/// <code>generationConfig</code> carries <code>maxOutputTokens</code> and no
/// <code>temperature</code>.</p>
Method TestAnUnsetTemperatureIsNotSentToTheOtherFamilies()
{
    For tKey = "openai", "compatible" {
        Set tBody = ..BodyFor(tKey, "")
        Do $$$AssertTrue($IsObject(tBody), tKey _ ": the body was recorded")
        If '$IsObject(tBody) Continue
        Do $$$AssertEquals(tBody.%GetTypeOf("temperature"), "unassigned", tKey _ ": an unset temperature is not sent: " _ tBody.%ToJSON())
    }
    Set tBody = ..BodyFor("gemini", "")
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.generationConfig), "gemini: the body carries a generationConfig")
    If '$IsObject(tBody) || '$IsObject(tBody.generationConfig) Quit
    Do $$$AssertEquals(tBody.generationConfig.%GetTypeOf("maxOutputTokens"), "number", "gemini: the generationConfig still carries maxOutputTokens")
    Do $$$AssertEquals(tBody.generationConfig.%GetTypeOf("temperature"), "unassigned", "gemini: and no temperature: " _ tBody.generationConfig.%ToJSON())
}

/// <p>An explicit temperature reaches the three families that take one, as the number stored.</p>
Method TestASetTemperatureIsSentToTheOtherFamilies()
{
    For tKey = "openai", "compatible", "gemini" {
        Set tBody = ..BodyFor(tKey, ..#SETTEMPERATURE)
        Do $$$AssertTrue(..CarriesTemperature(tBody), tKey _ ": the stored temperature is sent")
        Do $$$AssertEquals(+..SentTemperature(tBody), +..#SETTEMPERATURE, tKey _ ": as the value stored")
        If (tKey = "gemini") && $IsObject(tBody) {
            Do $$$AssertEquals(tBody.%GetTypeOf("temperature"), "unassigned", "gemini: inside generationConfig, never at the top level")
        }
    }
}

/// <p>AC3 -- the Anthropic body carries none of <code>temperature</code>, <code>top_p</code> or
/// <code>top_k</code>, whether the definition holds nothing, 0 or 0.7.</p>
Method TestAnthropicIsSentNoSamplingParameterWhateverTheDefinitionHolds()
{
    For tHeld = "", 0, ..#SETTEMPERATURE {
        Set tBody = ..BodyFor(..#ANTHROPICKEY, tHeld)
        Do $$$AssertTrue($IsObject(tBody), "anthropic holding '" _ tHeld _ "': the body was recorded")
        If '$IsObject(tBody) Continue
        For tField = "temperature", "top_p", "top_k" {
            Do $$$AssertEquals(tBody.%GetTypeOf(tField), "unassigned", "anthropic holding '" _ tHeld _ "': no " _ tField _ " is sent: " _ tBody.%ToJSON())
        }
    }
}

/// <p>For every shipped row, <code>acceptsTemperature</code> equals whether a stored 0.7 reaches
/// the recorded body, so the column the form reads and the adapter that builds the wire cannot
/// disagree.</p>
Method TestEachRowsColumnAgreesWithWhatItsAdapterSends()
{
    Set tKeys = ##class(OcuPilot.Kernel.Provider.Catalog).Keys()
    Do $$$AssertTrue($ListLength(tKeys) > 0, "the catalog declares rows")
    For tI = 1:1:$ListLength(tKeys) {
        Set tKey = $List(tKeys, tI)
        Do ##class(OcuPilot.Kernel.Provider.Catalog).Row(tKey, .tRow)
        Do $$$AssertEquals(tRow.%GetTypeOf("acceptsTemperature"), "boolean", tKey _ ": the row declares acceptsTemperature")
        Set tBody = ..BodyFor(tKey, ..#SETTEMPERATURE)
        Do $$$AssertEquals(..CarriesTemperature(tBody), +tRow.acceptsTemperature, tKey _ ": acceptsTemperature is " _ $Select(+tRow.acceptsTemperature: "true", 1: "false") _ " and a stored " _ ..#SETTEMPERATURE _ " is " _ $Select(..CarriesTemperature(tBody): "", 1: "not ") _ "sent")
    }
}

/// <p>DW-1590 -- the <code>openai</code> row's body carries <code>"reasoning_effort":"none"</code>
/// beside its tools, and the <code>compatible</code> row's carries no <code>reasoning_effort</code>
/// key.</p>
Method TestReasoningEffortRidesTheOpenAiRowAlone()
{
    Set tBody = ..BodyFor("openai", "", 1)
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.tools), "openai: the body advertises its tools")
    If $IsObject(tBody) {
        Do $$$AssertEquals(tBody.%GetTypeOf("reasoning_effort") _ ":" _ tBody.%Get("reasoning_effort"), "string:none", "openai: beside them it carries reasoning_effort none: " _ tBody.%ToJSON())
    }
    Set tBody = ..BodyFor("compatible", "", 1)
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.tools), "compatible: the body advertises its tools")
    If $IsObject(tBody) {
        Do $$$AssertEquals(tBody.%GetTypeOf("reasoning_effort"), "unassigned", "compatible: and carries no reasoning_effort key: " _ tBody.%ToJSON())
    }
}

}
