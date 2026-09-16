/// <p>DW-357 and DW-397 -- which key a Test connection call carries, what it says it carried, and
/// what it records when a call that did not test the stored values faults (AD-42).</p>
/// <p><b>The stored key goes only to the stored effective endpoint, under the stored reference.</b>
/// A body naming another endpoint or reference gets no key unless it brings its own, and a body key
/// is sent shape-gated and never recorded as a verification.</p>
/// <p>Driven in process through <class>OcuPilot.Test.DefinitionsProbe</class> -- the shipped
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> with its port answering from
/// <class>OcuPilot.Test.ProviderStub</class> -- so <b>no socket is opened</b>, and what reached the
/// request is read off the stub's record of its header names. The change record is read from
/// <class>OcuPilot.Test.LogProbe</class>'s capture. Every definition this class creates is named
/// with <parameter>PROBEPREFIX</parameter> and removed afterwards.</p>
Class OcuPilot.Test.ConnectionKey Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The key the stored reference resolves to, shaped for the <code>probe-local</code> row.</p>
Parameter STOREDKEY = "probe-local-storedkey00000000";

/// <p>A key a request body carries, shaped for the same row.</p>
Parameter BODYKEY = "probe-local-bodykey000000000";

/// <p>The stored endpoint (RFC 5737 TEST-NET-1).</p>
Parameter STOREDENDPOINT = "https://192.0.2.1/v1/messages";

/// <p>An endpoint a body names instead (RFC 5737 TEST-NET-2).</p>
Parameter OTHERENDPOINT = "https://198.51.100.7/v1/messages";

/// <p>The credential reference a <code>creds</code> definition stores. No entry holds it.</p>
Parameter STOREDCREDENTIAL = "OcuPilotProbeKeyStoredCredential";

/// <p>A credential reference a body names instead. No entry holds it either.</p>
Parameter OTHERCREDENTIAL = "OcuPilotProbeKeyOtherCredential";

/// <p>A well-formed reply.</p>
Parameter OKBODY = "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":1}}";

/// <p>A provider refusal in the Anthropic error shape.</p>
Parameter REFUSALBODY = "{""type"":""error"",""error"":{""type"":""authentication_error"",""message"":""invalid x-api-key""}}";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSecretClass("OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSslState("present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#STOREDKEY)
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>One stored definition on the <code>probe-local</code> row, whose adapter is the stub,
/// carrying <var>pEndpoint</var>; its id, or <code>""</code>. It reads an environment variable, or
/// the credential entry <var>pCredentialName</var> when one is named.</p>
Method Definition(pSuffix As %String, pEndpoint As %String, pCredentialName As %String = "") As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ pSuffix
    Set tRow.Provider = ##class(OcuPilot.Test.CatalogProbe).#LOCALKEY
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = pEndpoint
    Set tRow.CredType = $Select(pCredentialName = "": "env", 1: "creds")
    Set tRow.EnvVarName = $Select(pCredentialName = "": "OCUPILOT_PROBE_LOCAL_KEY", 1: "")
    Set tRow.CredentialName = pCredentialName
    Set tRow.MaxTokens = 4000
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": a stored definition is created")
    If $$$ISERR(tSC) Quit ""
    Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

/// <p>The test outcome for definition <var>pId</var> and body <var>pBody</var>, through the
/// arrangement <method>OcuPilot.Test.AgentConnection.Outcome</method> makes.</p>
ClassMethod Outcome(pId As %String, pBody As %DynamicObject, Output pAnswer, Output pHttpStatus, Output pFault) As %Status
{
    Quit ##class(OcuPilot.Test.AgentConnection).Outcome(pId, pBody, .pAnswer, .pHttpStatus, .pFault)
}

/// <p><b>The stored key goes only to the stored effective endpoint.</b> An empty body sends it; a
/// body naming another endpoint sends no key header at all and says <code>none</code>; a body
/// naming the endpoint the row's empty field stands for is the stored endpoint and sends it.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Definitions.KeySourceFor</method> answer
/// <code>stored</code> whenever the body carries no key -- the second leg's header assertion goes
/// red, the stored key sent to the body's endpoint.</p>
Method TestTheStoredKeyGoesOnlyToTheStoredEndpoint()
{
    Set tId = ..Definition("KeyStored", ..#STOREDENDPOINT)
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do $$$AssertStatusOK(..Outcome(tId, {}, .tAnswer, .tStatus, .tFault), "a test of the stored values runs")
    Do $$$AssertTrue($IsObject(tAnswer), "and answers")
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.keySource, "stored", "carrying the stored key")
        Do $$$AssertEquals(tAnswer.testedAsStored, 1, "as a test of the stored values")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "x-api-key,anthropic-version", "and the request carried a key header")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tEdit = {"endpointUrl": (..#OTHERENDPOINT)}
    Do $$$AssertStatusOK(..Outcome(tId, tEdit, .tOther, .tOtherStatus, .tOtherFault), "a test against another endpoint runs")
    Do $$$AssertTrue($IsObject(tOther), "and answers")
    If $IsObject(tOther) {
        Do $$$AssertEquals(tOther.keySource, "none", "saying it carried no key")
        Do $$$AssertEquals(tOther.testedAsStored, 0, "and was not a test of the stored values")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url"), ..#OTHERENDPOINT, "the call went to the body's endpoint")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "anthropic-version", "with no key header on the request")
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ """effects"":{""keySource"":""none""}", "and its change record names the key it carried: " _ tLine)

    Set tBlankId = ..Definition("KeyBlank", "")
    If tBlankId = "" Quit
    Do ##class(OcuPilot.Test.CatalogProbe).Row(##class(OcuPilot.Test.CatalogProbe).#LOCALKEY, .tCatalogRow)
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tSame = {"endpointUrl": (tCatalogRow.defaultEndpoint)}
    Do $$$AssertStatusOK(..Outcome(tBlankId, tSame, .tDefault, .tDefaultStatus, .tDefaultFault), "a test naming the endpoint an empty stored field stands for runs")
    Do $$$AssertEquals($Select($IsObject(tDefault): tDefault.keySource, 1: ""), "stored", "and carries the stored key, since that is the stored effective endpoint")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "x-api-key,anthropic-version", "on a key header")
}

/// <p><b>The stored key goes only under the stored credential reference.</b> A body naming another
/// credential entry, or another environment variable, at the stored endpoint sends no key header
/// and says <code>none</code>. A body editing another security field at the same endpoint and
/// reference carries the stored key and is still not a test of the stored values, so the row stays
/// unverified.</p>
/// <p>Mutation: drop the credential-field comparison from
/// <method>OcuPilot.Api.Definitions.KeySourceFor</method> -- the first leg goes red, the stored
/// reference resolved for a body that named another one. Drop only <code>envVarName</code> from it
/// -- the environment-variable leg goes red.</p>
Method TestTheStoredKeyGoesOnlyUnderTheStoredReference()
{
    Set tId = ..Definition("KeyReference", ..#STOREDENDPOINT, ..#STOREDCREDENTIAL)
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tEdit = {"credentialName": (..#OTHERCREDENTIAL)}
    Do $$$AssertStatusOK(..Outcome(tId, tEdit, .tAnswer, .tStatus, .tFault), "a test naming another credential reference runs")
    Do $$$AssertTrue($IsObject(tAnswer), "and answers: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.keySource, "none", "saying it carried no key")
        Do $$$AssertEquals(tAnswer.testedAsStored, 0, "and was not a test of the stored values")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "anthropic-version", "with no key header on the request")

    Set tEnvId = ..Definition("KeyEnvName", ..#STOREDENDPOINT)
    If tEnvId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tEnvEdit = {"envVarName": "OCUPILOT_PROBE_OTHER_KEY"}
    Do $$$AssertStatusOK(..Outcome(tEnvId, tEnvEdit, .tEnvAnswer, .tEnvStatus, .tEnvFault), "a test naming another environment variable runs")
    Do $$$AssertEquals($Select($IsObject(tEnvAnswer): tEnvAnswer.keySource, 1: ""), "none", "and says it carried no key: " _ $Select($IsObject(tEnvFault): tEnvFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "anthropic-version", "with no key header, although the variable it names would resolve")

    Set tMarkedId = ..Definition("KeyMarked", ..#STOREDENDPOINT)
    If tMarkedId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tMarked = {"markedLocal": true}
    Do $$$AssertStatusOK(..Outcome(tMarkedId, tMarked, .tMarkedAnswer, .tMarkedStatus, .tMarkedFault), "a test marking the definition local at the same endpoint runs")
    Do $$$AssertTrue($IsObject(tMarkedAnswer), "and answers: " _ $Select($IsObject(tMarkedFault): tMarkedFault.%ToJSON(), 1: ""))
    If $IsObject(tMarkedAnswer) {
        Do $$$AssertEquals(tMarkedAnswer.keySource, "stored", "carrying the stored key, since the endpoint and the reference are the stored ones")
        Do $$$AssertEquals(tMarkedAnswer.testedAsStored, 0, "and not a test of the stored values")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "x-api-key,anthropic-version", "on a key header")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnection).FlagsOf(tMarkedId), "0|0", "and the row is unverified")
}

/// <p><b>A call fault says which key the call carried.</b> The fault's <code>detail</code> keeps
/// the provider's own text and gains <code>keySource</code> and <code>testedAsStored</code>, so a
/// failed test of an unsaved endpoint reads as unauthenticated rather than as a key that was
/// refused.</p>
/// <p>Mutation: drop the <method>OcuPilot.Api.Definitions.AnnotateCallFault</method> call -- this
/// goes red on both detail members.</p>
Method TestACallFaultCarriesTheKeySourceInItsDetail()
{
    Set tId = ..Definition("KeyFault", ..#STOREDENDPOINT)
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, ..#REFUSALBODY)
    Set tEdit = {"endpointUrl": (..#OTHERENDPOINT)}
    Do $$$AssertStatusOK(..Outcome(tId, tEdit, .tAnswer, .tStatus, .tFault), "a test against another endpoint runs")
    Do $$$AssertTrue($IsObject(tFault), "and answers a fault")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.code, "PROVIDER.REFUSED", "the provider refused it")
    Do $$$AssertTrue($IsObject(tFault.detail), "with a detail object: " _ tFault.%ToJSON())
    If '$IsObject(tFault.detail) Quit
    Do $$$AssertEquals(tFault.detail.keySource, "none", "saying the call carried no key")
    Do $$$AssertEquals(tFault.detail.%GetTypeOf("testedAsStored"), "boolean", "and whether the stored values were tested, as a flag")
    Do $$$AssertEquals(tFault.detail.testedAsStored, 0, "which they were not")
    Do $$$AssertEquals(tFault.detail.providerText, "invalid x-api-key", "keeping the provider's own text")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "anthropic-version", "and the request carried no key header")
}

/// <p><b>A body key is sent, shape-gated, and never recorded as a verification.</b> The stored
/// reference resolves to nothing here, so a call that succeeded can only have carried the body's
/// key; a body key of the wrong shape is refused before any call.</p>
/// <p>Mutation: leave <code>tTestedAsStored</code> ignorant of the key source in
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> -- this goes red, the row verified
/// against a key that is not the stored one.</p>
Method TestABodyKeyIsSentShapeGatedAndNeverVerifies()
{
    Set tId = ..Definition("KeyBody", ..#STOREDENDPOINT)
    If tId = "" Quit
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tBody = {}
    Do tBody.%Set("apiKey", ..#BODYKEY)
    Do $$$AssertStatusOK(..Outcome(tId, tBody, .tAnswer, .tStatus, .tFault), "a test carrying a body key runs")
    Do $$$AssertTrue('$IsObject(tFault), "and answers no fault, though the stored reference resolves to nothing: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.keySource, "body", "saying the body's key was sent")
        Do $$$AssertEquals(tAnswer.testedAsStored, 0, "and that this was not a test of the stored values")
        Do $$$AssertEquals(tAnswer.connectionVerified, 0, "so nothing was verified")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "x-api-key,anthropic-version", "the request carried a key header")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnection).FlagsOf(tId), "0|0", "and the row is unverified")
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ """effects"":{""keySource"":""body""}", "the change record names the body's key as the one carried: " _ tLine)
    Do $$$AssertEquals(tLine [ ..#BODYKEY, 0, "and carries no part of the key")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Set tWrong = {}
    Do tWrong.%Set("apiKey", "not-a-probe-local-key")
    Do $$$AssertStatusOK(..Outcome(tId, tWrong, .tWrongAnswer, .tWrongStatus, .tWrongFault), "a test carrying a badly shaped body key runs")
    Do $$$AssertEquals($Select($IsObject(tWrongFault): tWrongFault.code, 1: ""), "PROVIDER.KEYSHAPE", "and is refused on the key's shape")
    Do $$$AssertEquals($Select($IsObject(tWrongFault) && $IsObject(tWrongFault.detail): tWrongFault.detail.keySource, 1: ""), "body", "saying the key was the body's")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "before any call")
}

/// <p><b>DW-397 -- a test of values the row does not hold is recorded even when its call
/// faults</b>, as a security change naming the key it carried and the code it met. A test of the
/// stored values that faults records nothing, as it did before.</p>
/// <p>Mutation: remove the record from <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>'s
/// fault branch -- the first leg goes red with nothing captured.</p>
Method TestAFaultedTestOfUnstoredValuesIsRecorded()
{
    Set tId = ..Definition("KeyRecord", ..#STOREDENDPOINT)
    If tId = "" Quit
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, ..#REFUSALBODY)
    Set tEdit = {"endpointUrl": (..#OTHERENDPOINT)}
    Do $$$AssertStatusOK(..Outcome(tId, tEdit, .tAnswer, .tStatus, .tFault), "a test against another endpoint runs")
    Do $$$AssertTrue($IsObject(tFault), "and faults")
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue(tLine [ """msg"":""test""", "the test is recorded: " _ tLine)
    Do $$$AssertTrue(tLine [ """securityChange"":true", "as a security change")
    Do $$$AssertTrue(tLine [ """effects"":{""keySource"":""none"",""faultCode"":""PROVIDER.REFUSED""}", "naming the key it carried and the code it met")
    Do $$$AssertTrue(tLine [ ("""endpointUrl"":{""old"":""" _ ..#STOREDENDPOINT _ """,""new"":""" _ ..#OTHERENDPOINT _ """}"), "and the endpoint it went to")

    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, ..#REFUSALBODY)
    Do $$$AssertStatusOK(..Outcome(tId, {}, .tStoredAnswer, .tStoredStatus, .tStoredFault), "a test of the stored values runs")
    Do $$$AssertTrue($IsObject(tStoredFault), "and faults")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and records nothing, as before")
}

}
