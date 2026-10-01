/// <p>DW-1192's first half (Story 16.15): a <code>gemini</code> definition saved with an endpoint
/// that carries no <code>{model}</code> placeholder logs one info line, on create and on update,
/// naming the definition's id, name and unused Model and never its endpoint; an endpoint carrying
/// the placeholder, or none, logs only the change record. Also pins
/// <method>OcuPilot.Kernel.Provider.Gemini.ModelUnused</method>.</p>
/// <p>Driven in process through <class>OcuPilot.Test.RouterFixture</class>'s
/// <code>/agent-definitions</code> routes, which run the shipped handler bodies through
/// <class>OcuPilot.Test.DefinitionsProbe</class>, whose log seam captures the last line into
/// <class>OcuPilot.Test.LogProbe</class>. Self-cleaning: every definition is named with
/// <parameter>PROBEPREFIX</parameter> and removed in <method>OnAfterOneTest</method>. No arming
/// variable applies, and nothing connects to the documentation-reserved endpoints.</p>
Class OcuPilot.Test.GeminiModelUnused Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>A model-specific endpoint (RFC 5737 TEST-NET-1), which calls the model its path names.</p>
Parameter PINNEDENDPOINT = "https://192.0.2.20/v1beta/models/pinned:generateContent";

/// <p>The same endpoint carrying the placeholder the definition's Model replaces.</p>
Parameter PLACEHOLDERENDPOINT = "https://192.0.2.20/v1beta/models/{model}:generateContent";

Parameter MODEL = "gemini-3.8-flash";

/// <p>An endpoint (RFC 5737 TEST-NET-1) for a provider whose canonical endpoint carries no
/// placeholder.</p>
Parameter OTHERENDPOINT = "https://192.0.2.20/v1/messages";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>Create a <var>pProvider</var> definition named for <var>pSuffix</var> at <var>pEndpoint</var>
/// through the shipped create handler, and answer its id, or <code>""</code> when the create did not
/// answer 201.</p>
Method Create(pSuffix As %String, pEndpoint As %String, pProvider As %String = "gemini") As %String
{
    Set tBody = {"name": (..#PROBEPREFIX _ "Gemini" _ pSuffix), "provider": (pProvider), "model": (..#MODEL), "endpointUrl": (pEndpoint), "credType": "env", "envVarName": "GEMINI_API_KEY"}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions", "POST", , .tAnswer, .tStatus, , , tBody.%ToJSON())
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create dispatches")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created: " _ tAnswer)
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tAnswer).id
}

/// <p>Update definition <var>pId</var> with <var>pBody</var> through the shipped update handler,
/// asserting it answers 200.</p>
Method Update(pId As %String, pBody As %DynamicObject, pLabel As %String)
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions/" _ pId, "PUT", , .tAnswer, .tStatus, , , pBody.%ToJSON())
    Do $$$AssertStatusOK(tSC, pLabel _ ": the update dispatches")
    Do $$$AssertEquals(tStatus, 200, pLabel _ ": the update is saved: " _ tAnswer)
}

/// <p>The last captured log line, without its prefix, as an object, and its raw text in
/// <var>pText</var>.</p>
Method LastLine(Output pText As %String) As %DynamicObject
{
    Set pText = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Set tLine = ""
    Try {
        Set tLine = ##class(%DynamicObject).%FromJSON($Piece(pText, "[OcuPilot] ", 2, *))
    } Catch ex {
        Set tLine = ""
    }
    Quit tLine
}

/// <p>Assert the last captured line is the model-unused note for definition <var>pId</var>.</p>
Method AssertNote(pId As %String, pName As %String, pLabel As %String)
{
    Set tLine = ..LastLine(.tText)
    Do $$$AssertTrue($IsObject(tLine), pLabel _ ": a line was captured: " _ tText)
    If '$IsObject(tLine) Quit
    Do $$$AssertEquals(tLine.level _ "|" _ tLine.subsystem, "info|agent-definition", pLabel _ ": an info line under agent-definition")
    Do $$$AssertTrue(tLine.msg [ "model unused", pLabel _ ": saying the Model is unused: " _ tLine.msg)
    Do $$$AssertEquals(tLine.data.id _ "|" _ tLine.data.name _ "|" _ tLine.data.model, pId _ "|" _ pName _ "|" _ ..#MODEL, pLabel _ ": naming the definition's id, name and Model")
    Do $$$AssertTrue((tText '[ "https://") && (tText '[ "192.0.2.20"), pLabel _ ": and carrying no URL and no host: " _ tText)
}

/// <p><method>OcuPilot.Kernel.Provider.Gemini.ModelUnused</method> holds for a non-empty endpoint
/// without the placeholder, and for nothing else.</p>
Method TestModelUnusedHoldsOnlyForANonEmptyEndpointWithoutThePlaceholder()
{
    Set tGemini = "OcuPilot.Kernel.Provider.Gemini"
    Do $$$AssertEquals($ClassMethod(tGemini, "ModelUnused", ..#PINNEDENDPOINT), 1, "a model-specific endpoint leaves the Model unused")
    Do $$$AssertEquals($ClassMethod(tGemini, "ModelUnused", ..#PLACEHOLDERENDPOINT), 0, "an endpoint carrying the placeholder uses it")
    Do $$$AssertEquals($ClassMethod(tGemini, "ModelUnused", ""), 0, "and an empty endpoint is the catalog's, which carries it")
}

/// <p>Create: a definition saved at a model-specific endpoint logs the note as its last line.</p>
Method TestACreateWithoutThePlaceholderLogsTheUnusedModel()
{
    Set tId = ..Create("Pinned", ..#PINNEDENDPOINT)
    If tId = "" Quit
    Do ..AssertNote(tId, ..#PROBEPREFIX _ "GeminiPinned", "create")
}

/// <p>Update: repointing a definition at a model-specific endpoint logs the note, and repointing it
/// back at the placeholder logs only the change record.</p>
Method TestAnUpdateWithoutThePlaceholderLogsTheUnusedModel()
{
    Set tId = ..Create("Moved", ..#PLACEHOLDERENDPOINT)
    If tId = "" Quit
    Do ..Update(tId, {"endpointUrl": (..#PINNEDENDPOINT)}, "pinned")
    Do ..AssertNote(tId, ..#PROBEPREFIX _ "GeminiMoved", "update")
    Do ..Update(tId, {"endpointUrl": (..#PLACEHOLDERENDPOINT)}, "placeholder")
    Set tLine = ..LastLine(.tText)
    Do $$$AssertEquals($Select($IsObject(tLine): tLine.msg, 1: ""), "update", "an endpoint carrying the placeholder leaves the change record last: " _ tText)
}

/// <p>An endpoint carrying the placeholder, or none, logs only the change record, and so does a
/// provider whose canonical endpoint carries no placeholder, at an endpoint without one.</p>
Method TestAnEndpointWithThePlaceholderOrNoneLogsOnlyTheChangeRecord()
{
    For tCase = "Placeholder|" _ ..#PLACEHOLDERENDPOINT _ "|gemini", "Empty||gemini", "Anthropic|" _ ..#OTHERENDPOINT _ "|anthropic" {
        Set tId = ..Create($Piece(tCase, "|", 1), $Piece(tCase, "|", 2), $Piece(tCase, "|", 3))
        If tId = "" Continue
        Set tLine = ..LastLine(.tText)
        Do $$$AssertEquals($Select($IsObject(tLine): tLine.msg, 1: ""), "create", $Piece(tCase, "|", 1) _ ": the change record is the last line: " _ tText)
    }
}

}
