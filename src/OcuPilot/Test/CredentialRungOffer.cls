/// <p>Pins where the credentials rung is offered (Story 8.9, AC2): the providers route publishes
/// <code>credentialsRungAvailable</code>, and a <code>creds</code> definition is refused
/// <code>AGENT.CREDTYPE.UNAVAILABLE</code> where the rung is unreachable, while <code>env</code>
/// and every other type are not.</p>
/// <p>The unavailable arm is driven in process through <class>OcuPilot.Test.DefinitionsProbe</class>
/// and <class>OcuPilot.Test.SecretProbe</class>, against the real
/// <method>OcuPilot.Api.Definitions.ProvidersBody</method> and
/// <method>OcuPilot.Api.Definitions.CredTypeRefusal</method>, because no request can reach it on an
/// instance whose install namespace is interoperability-enabled. The create and update legs run the
/// literal, inherited handler bodies through <class>OcuPilot.Test.RouterFixture</class>'s fixture
/// routes, and remove every <class>OcuPilot.Test.AgentFixture</class> probe definition they store.
/// The HTTP leg needs such an install namespace and the suite's own credentials.</p>
Class OcuPilot.Test.CredentialRungOffer Extends %UnitTest.TestCase
{

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class stored are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives this class")
    Quit $$$OK
}

/// <p>A definition body on the shipped <code>anthropic</code> row, named with the fixture's probe
/// prefix, on <var>pCredType</var>'s rung.</p>
ClassMethod Body(pSuffix As %String, pCredType As %String) As %String
{
    Set tBody = {"provider":"anthropic","endpointUrl":"https://192.0.2.1/v1/messages"}
    Do tBody.%Set("name", ##class(OcuPilot.Test.AgentFixture).#PROBEPREFIX _ pSuffix)
    Do tBody.%Set("credType", pCredType)
    If pCredType = "env" Do tBody.%Set("envVarName", "ANTHROPIC_API_KEY")
    If pCredType = "creds" Do tBody.%Set("credentialName", "OcuPilotProbeRungCredential")
    Quit tBody.%ToJSON()
}

/// <p>Whether <var>pBody</var>'s violations carry <code>AGENT.CREDTYPE.UNAVAILABLE</code> on
/// <code>credType</code>.</p>
ClassMethod CarriesTheRefusal(pBody As %String) As %Boolean
{
    Set tAnswer = ##class(%DynamicObject).%FromJSON(pBody)
    If '$IsObject(tAnswer.detail) || '$IsObject(tAnswer.detail.violations) Quit 0
    Set tFound = 0
    Set tIter = tAnswer.detail.violations.%GetIterator()
    While tIter.%GetNext(.tKey, .tViolation) {
        If (tViolation.field = "credType") && (tViolation.code = "AGENT.CREDTYPE.UNAVAILABLE") Set tFound = 1
    }
    Quit tFound
}

/// <p>With the rung reported unreachable, the providers body says so as a JSON boolean
/// <code>false</code>, a <code>creds</code> definition is refused with the new code, and the
/// <code>env</code> rung and the keyless type are not refused.</p>
Method TestAnUnreachableRungIsPublishedAndRefused()
{
    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(0)
    Set tSC = ##class(OcuPilot.Test.DefinitionsProbe).ProvidersBody(.tBody)
    Do $$$AssertStatusOK(tSC, "the providers body is built")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%GetTypeOf("credentialsRungAvailable"), "boolean", "the flag is a JSON boolean")
    Do $$$AssertEquals(tBody.credentialsRungAvailable, 0, "and it reads false")
    Do $$$AssertTrue($IsObject(tBody.providers) && (tBody.providers.%Size() > 0), "beside the provider rows")

    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredTypeRefusal("creds"), "AGENT.CREDTYPE.UNAVAILABLE", "a creds definition is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredTypeRefusal("env"), "", "an env definition is not")
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredTypeRefusal("none"), "", "nor a keyless one")
    Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation("AGENT.CREDTYPE.UNAVAILABLE"), "", "and the refusal carries its published sentence")
}

/// <p>A create's violation set carries the refusal on <code>credType</code>, beside what the
/// rules found, and an <code>env</code> definition's set does not.</p>
Method TestTheRefusalJoinsTheRuleViolations()
{
    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(0)
    Kill tValues
    Set tValues("credType") = "creds"
    Set tValues("credentialName") = "OcuPilotAnthropic"
    Set tCount = ##class(OcuPilot.Test.DefinitionsProbe).ValidateDefinition(.tValues, "", .tViolations)
    Set tFound = 0
    For tI = 1:1:tCount {
        If ($List(tViolations(tI), 1) = "credType") && ($List(tViolations(tI), 2) = "AGENT.CREDTYPE.UNAVAILABLE") Set tFound = 1
    }
    Do $$$AssertTrue(tFound, "the credType refusal is in the set the rules filled")
    Do $$$AssertTrue(tCount > 1, "beside the rules' own violations on this incomplete body (" _ tCount _ ")")

    Kill tValues, tViolations
    Set tValues("credType") = "env"
    Set tValues("envVarName") = "ANTHROPIC_API_KEY"
    Set tCount = ##class(OcuPilot.Test.DefinitionsProbe).ValidateDefinition(.tValues, "", .tViolations)
    For tI = 1:1:tCount {
        Do $$$AssertNotEquals($List(tViolations(tI), 2), "AGENT.CREDTYPE.UNAVAILABLE", "an env definition carries no credType refusal")
    }
}

/// <p>With the rung reachable, the flag reads <code>true</code> and nothing is refused.</p>
Method TestAReachableRungIsPublishedAndAccepted()
{
    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(1)
    Set tSC = ##class(OcuPilot.Test.DefinitionsProbe).ProvidersBody(.tBody)
    Do $$$AssertStatusOK(tSC, "the providers body is built")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%GetTypeOf("credentialsRungAvailable"), "boolean", "the flag is a JSON boolean")
    Do $$$AssertEquals(tBody.credentialsRungAvailable, 1, "and it reads true")
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredTypeRefusal("creds"), "", "a creds definition is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Test.DefinitionsProbe).CredTypeRefusal("env"), "", "and so is an env one")
}

/// <p>Over HTTP, as the suite's account, <code>GET /agent/providers</code> answers the shipped
/// predicate's value in the install namespace, which is interoperability-enabled.</p>
Method TestTheProvidersRouteCarriesTheInstanceAnswer()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIBASE _ "/agent/providers", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the providers request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Extract(tBody, 1, 200))
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.%GetTypeOf("credentialsRungAvailable"), "boolean", "the flag arrives as a JSON boolean")
    Do $$$AssertEquals(tAnswer.credentialsRungAvailable, ##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable(), "and it is the shipped predicate's answer in this namespace")
    Do $$$AssertEquals(tAnswer.credentialsRungAvailable, 1, "which is true in an interoperability-enabled install namespace (" _ $Namespace _ ")")
}

/// <p>Through the shipped create handler with the rung unreachable: a <code>creds</code> body
/// answers 422 carrying the refusal on <code>credType</code> and stores nothing, and an
/// <code>env</code> body answers 201.</p>
Method TestTheCreateHandlerRefusesCredsWhereTheRungIsUnreachable()
{
    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(0)
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions", "POST", , .tBody, .tStatus, , , ..Body("RungCreds", "creds"))
    Do $$$AssertStatusOK(tSC, "dispatch through the shipped, inherited HandleCreate completes")
    Do $$$AssertEquals(tStatus, 422, "a creds definition is refused: " _ tBody)
    Do $$$AssertTrue(..CarriesTheRefusal(tBody), "with AGENT.CREDTYPE.UNAVAILABLE on credType: " _ tBody)
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), 0, "and nothing is stored")

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions", "POST", , .tBody, .tStatus, , , ..Body("RungEnv", "env"))
    Do $$$AssertStatusOK(tSC, "the env create dispatches")
    Do $$$AssertEquals(tStatus, 201, "an env definition is created: " _ tBody)
}

/// <p>Through the shipped update handler with the rung unreachable: moving a stored
/// <code>env</code> definition onto <code>creds</code> answers 422 carrying the refusal, and the
/// stored row keeps its rung.</p>
Method TestTheUpdateHandlerRefusesCredsWhereTheRungIsUnreachable()
{
    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable(0)
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions", "POST", , .tBody, .tStatus, , , ..Body("RungUpdate", "env"))
    Do $$$AssertEquals(tStatus, 201, "an env definition is stored to update: " _ tBody)
    If tStatus '= 201 Quit
    Set tId = ##class(%DynamicObject).%FromJSON(tBody).id

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions/" _ tId, "PUT", , .tBody, .tStatus, , , {"credType":"creds","credentialName":"OcuPilotProbeRungCredential"}.%ToJSON())
    Do $$$AssertStatusOK(tSC, "dispatch through the shipped, inherited HandleUpdate completes")
    Do $$$AssertEquals(tStatus, 422, "moving it onto creds is refused: " _ tBody)
    Do $$$AssertTrue(..CarriesTheRefusal(tBody), "with AGENT.CREDTYPE.UNAVAILABLE on credType: " _ tBody)
    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow)
    Do $$$AssertStatusOK(tOpenSC, "the stored row reads back")
    If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.CredType, "env", "still on the env rung")
    Set tRow = ""
}

}
