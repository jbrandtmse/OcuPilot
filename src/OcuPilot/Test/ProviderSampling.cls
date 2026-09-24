/// <p>Story 10.4's stored half, over HTTP against the shipped router: a create that omits the
/// temperature stores it unset and projects JSON <code>null</code>, an explicit empty value is
/// accepted unset, an explicit value is stored and projected as given, an out-of-range one is
/// refused with the one rule 4 violation, <code>GET /agent/providers</code> serves
/// <code>canonicalTemperature</code> <code>null</code> and <code>acceptsTemperature</code> per row,
/// and a row stored before this story keeps its 0 through an unrelated update and still sends
/// it.</p>
/// <p>Needs the API application and the suite's own credentials; the one provider call is made
/// through <class>OcuPilot.Test.ProviderPortProbe</class> on
/// <class>OcuPilot.Test.CatalogProbeShipped</class>, so no socket is opened and no key is read.
/// Every definition it creates is named with the probe prefix and removed after each method.</p>
Class OcuPilot.Test.ProviderSampling Extends %UnitTest.TestCase
{

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The port entry for the one provider call.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>A credential the <code>openai</code> row's shape gate accepts.</p>
Parameter PROBEKEY = "probesamplingkeyabcdefghijklm";

/// <p>The loopback endpoint the <code>compatible</code> row's create carries, marked local.
/// Nothing connects to it.</p>
Parameter LOCALENDPOINT = "http://127.0.0.1:11434/v1";

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
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining), "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>One request under <parameter>APIBASE</parameter> as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>A create body on the shipped row <var>pKey</var> every rule but the temperature's accepts,
/// named <var>pSuffix</var>, carrying <var>pTemperature</var> verbatim as JSON text when it is not
/// <code>$Char(0)</code>, which leaves the key out.</p>
ClassMethod CreateBody(pKey As %String, pSuffix As %String, pTemperature As %String = {$Char(0)}) As %String
{
    Do ##class(OcuPilot.Kernel.Provider.Catalog).Row(pKey, .tRow)
    Set tBody = {}
    Do tBody.%Set("name", $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Sampling" _ pSuffix, "string")
    Do tBody.%Set("provider", pKey, "string")
    If $IsObject($Get(tRow)) && +tRow.endpointRequired {
        Do tBody.%Set("model", "llama-3.3-70b-instruct", "string")
        Do tBody.%Set("endpointUrl", ..#LOCALENDPOINT, "string")
        Do tBody.%Set("markedLocal", 1, "boolean")
        Do tBody.%Set("credType", ##class(OcuPilot.Kernel.AgentRules).#CREDTYPENONE, "string")
    } Else {
        Do tBody.%Set("credType", ##class(OcuPilot.Kernel.AgentRules).#CREDTYPEENV, "string")
        Do tBody.%Set("envVarName", $Select($IsObject($Get(tRow)): tRow.defaultEnvVarName, 1: ""), "string")
    }
    Set tText = tBody.%ToJSON()
    If pTemperature = $Char(0) Quit tText
    Quit $Extract(tText, 1, $Length(tText) - 1) _ ",""temperature"":" _ pTemperature _ "}"
}

/// <p>POST <var>pBody</var>, assert a 201, and answer the created projection, or <code>""</code>.</p>
Method Create(pBody As %String, pWhat As %String) As %DynamicObject
{
    Set tSC = ..Call("POST", "/agent/definitions", pBody, .tStatus, .tText, .tHeaders)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pWhat _ ": the definition is created (" _ tText _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tText)
}

/// <p>The stored <code>Temperature</code> of definition <var>pId</var>, read through the state
/// class, or <code>"missing"</code>.</p>
ClassMethod StoredTemperature(pId As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject($Get(tRow)) Quit "missing"
    Quit tRow.Temperature
}

/// <p>AC1 -- a create that omits the temperature, on every shipped row, stores it unset and the
/// create's projection and the single-definition read both answer JSON <code>null</code>.</p>
Method TestACreateWithNoTemperatureStoresItUnset()
{
    Set tKeys = ##class(OcuPilot.Kernel.Provider.Catalog).Keys()
    For tI = 1:1:$ListLength(tKeys) {
        Set tKey = $List(tKeys, tI)
        Set tCreated = ..Create(..CreateBody(tKey, "Omit" _ tI), tKey)
        If '$IsObject(tCreated) Continue
        Do $$$AssertEquals(tCreated.%GetTypeOf("temperature"), "null", tKey _ ": the create projects the temperature as null: " _ tCreated.%ToJSON())
        Do $$$AssertEquals(..StoredTemperature(tCreated.id), "", tKey _ ": and stores it unset")
        Do ..Call("GET", "/agent/definitions/" _ tCreated.id, "", .tStatus, .tText, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tKey _ ": the definition reads back")
        If tStatus '= 200 Continue
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).%GetTypeOf("temperature"), "null", tKey _ ": as null again")
    }
}

/// <p>An explicit empty temperature is accepted and stored unset.</p>
Method TestAnExplicitEmptyTemperatureIsStoredUnset()
{
    Set tCreated = ..Create(..CreateBody("openai", "Empty", """"""), "empty")
    If '$IsObject(tCreated) Quit
    Do $$$AssertEquals(tCreated.%GetTypeOf("temperature"), "null", "an empty temperature projects as null")
    Do $$$AssertEquals(..StoredTemperature(tCreated.id), "", "and is stored unset")
}

/// <p>An explicit value -- 0, <code>.7</code>, 0.7, 2 -- is stored and projected as given, on a
/// family that takes one and on one that does not, since rule 4 is family-blind.</p>
Method TestAnExplicitTemperatureIsStoredAndProjectedAsGiven()
{
    Set tCases = $ListBuild($ListBuild("0", 0), $ListBuild("""" _ ".7" _ """", .7), $ListBuild("0.7", .7), $ListBuild("2", 2))
    For tKey = "openai", "anthropic" {
        For tI = 1:1:$ListLength(tCases) {
            Set tCase = $List(tCases, tI)
            Set tCreated = ..Create(..CreateBody(tKey, "Set" _ tKey _ tI, $List(tCase, 1)), tKey _ " " _ $List(tCase, 1))
            If '$IsObject(tCreated) Continue
            Do $$$AssertEquals(tCreated.%GetTypeOf("temperature"), "number", tKey _ " " _ $List(tCase, 1) _ ": projected as a number")
            Do $$$AssertEquals(+tCreated.temperature, $List(tCase, 2), tKey _ " " _ $List(tCase, 1) _ ": the value given")
            Do $$$AssertEquals(+..StoredTemperature(tCreated.id), $List(tCase, 2), tKey _ " " _ $List(tCase, 1) _ ": and stored")
            Do $$$AssertTrue(..StoredTemperature(tCreated.id) '= "", tKey _ " " _ $List(tCase, 1) _ ": as a value, never unset")
        }
    }
}

/// <p>An out-of-range or non-numeric temperature is refused with exactly one violation,
/// <code>{temperature, AGENT.TEMPERATURE.RANGE}</code>, and nothing is written.</p>
Method TestAnOutOfRangeTemperatureIsRefused()
{
    Set tExpected = ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("temperature", ##class(OcuPilot.Api.Error).#AGENTTEMPERATURERANGE)))
    For tBad = "3", "-1", """abc""" {
        Set tSC = ..Call("POST", "/agent/definitions", ..CreateBody("openai", "Bad", tBad), .tStatus, .tText, .tHeaders)
        Do $$$AssertStatusOK(tSC, tBad _ ": the request completes")
        Do $$$AssertEquals(tStatus, 422, tBad _ ": is refused (" _ tText _ ")")
        Do $$$AssertEquals(##class(OcuPilot.Test.AgentWire).ViolationsOf(tText), tExpected, tBad _ ": with the one rule 4 violation")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), 0, "and nothing was written")
}

/// <p><code>GET /agent/providers</code> serves each row's <code>canonicalTemperature</code> as
/// <code>null</code> and its <code>acceptsTemperature</code>: false for anthropic, true for openai,
/// gemini and compatible.</p>
Method TestTheProvidersRouteServesBothTemperatureColumns()
{
    Set tSC = ..Call("GET", "/agent/providers", "", .tStatus, .tText, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the providers request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200")
    If tStatus '= 200 Quit
    Set tRows = ##class(%DynamicObject).%FromJSON(tText).providers
    Set tSeen = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.key _ ":" _ tRow.%GetTypeOf("canonicalTemperature") _ ":" _ tRow.%GetTypeOf("acceptsTemperature") _ ":" _ $Select(tRow.acceptsTemperature: "true", 1: "false")
    }
    Do $$$AssertEquals(tSeen, "anthropic:null:boolean:false,openai:null:boolean:true,gemini:null:boolean:true,compatible:null:boolean:true", "each row: no canonical temperature, and whether the family takes one")
}

/// <p>AC6 -- a row stored before this story with temperature 0, then updated in an unrelated field,
/// still holds 0, projects 0 and sends 0 to a family that takes one.</p>
Method TestAStoredTemperatureIsKeptThroughAnUpdateAndSent()
{
    Do ##class(OcuPilot.Kernel.Provider.Catalog).Row("openai", .tRow)
    Set tDef = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tDef.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "SamplingPreStory"
    Set tDef.Provider = "openai"
    Set tDef.Model = tRow.defaultModel
    Set tDef.CredType = "env"
    Set tDef.EnvVarName = tRow.defaultEnvVarName
    Set tDef.MaxTokens = +tRow.canonicalMaxTokens
    Set tDef.Temperature = 0
    Set tDef.Enabled = 1
    Set tDef.ConnectionVerified = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tDef), "a row as a pre-story build stored it, temperature 0")
    Set tId = tDef.%Id()
    Set tDef = ""

    Set tSC = ..Call("PUT", "/agent/definitions/" _ tId, "{""systemPromptOverride"":""answer briefly""}", .tStatus, .tText, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the unrelated update completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted (" _ tText _ ")")
    If tStatus '= 200 Quit
    Set tUpdated = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tUpdated.%GetTypeOf("temperature") _ ":" _ tUpdated.temperature, "number:0", "the update projects the temperature as 0")
    Do $$$AssertEquals(..StoredTemperature(tId), 0, "and the row still holds 0")

    Do $ClassMethod(..#PORT, "SetCatalogClass", "OcuPilot.Test.CatalogProbeShipped")
    Do ##class(OcuPilot.Test.CatalogProbeShipped).Row("openai", .tStubRow)
    Do $$$AssertEquals(tStubRow.adapterClass, "OcuPilot.Test.OpenAIStub", "the switched catalog answers the OpenAI stub, so no socket is opened")
    If tStubRow.adapterClass '= "OcuPilot.Test.OpenAIStub" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""ok""},""finish_reason"":""stop""}]}")
    Kill tMessages
    Set tMessages = 1
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "what is on this screen"
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertTrue('$IsObject($Get(tFault)), "with no fault: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Set tText = ##class(OcuPilot.Test.ProviderStub).Recorded("body", 1)
    Set tSent = $Select(tText = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tText, "I", "UTF8")))
    Do $$$AssertTrue($IsObject(tSent), "the body was recorded")
    If '$IsObject(tSent) Quit
    Do $$$AssertEquals(tSent.%GetTypeOf("temperature") _ ":" _ tSent.temperature, "number:0", "and the stored 0 is sent: " _ tSent.%ToJSON())
}

}
