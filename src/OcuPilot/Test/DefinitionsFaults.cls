/// <p>The error shapes on <class>OcuPilot.Api.Definitions</class> that are reachable through seams
/// the handler already publishes: a credential store that fails, a test of the stored values given
/// no row version, and a request body the server could not read.</p>
/// <p>The first two render 500 with code <code>INTERNAL</code> and a reason of their own, and the
/// second is distinguished from the verification-write refusal by what it does <b>not</b> do -- it
/// makes no provider call at all. The same call is driven once with the version first, where it
/// reaches the transport and consumes a queued answer, so the zero read afterwards is a
/// measurement rather than a counter that was never live. The third answers 500 for a read fault
/// on every definition and switch route that reads a body, and 400 for a malformed document.</p>
/// <p>The handler's remaining error shapes name <class>OcuPilot.Kernel.State.Agent</class> by
/// literal <code>##class</code> and are unreachable without a state-class seam; they are recorded
/// in the ledger rather than worked around here.</p>
/// <p>Self-cleaning: every definition is named with <parameter>PROBEPREFIX</parameter> and removed
/// in <method>OnAfterOneTest</method>, which asserts none survives. No arming variable applies.</p>
Class OcuPilot.Test.DefinitionsFaults Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The credential reference the store-failure leg names. Nothing is ever stored behind it: the
/// store fails.</p>
Parameter FAULTCREDENTIAL = "OcuPilotProbeFaultCredential";

/// <p>A key of the shape the shipped <code>anthropic</code> row requires, so the request reaches
/// the store rather than being refused for its shape.</p>
Parameter PROBEKEY = "sk-ant-ocupilotfaultprobe000000000";

/// <p>The credential class whose <method>Store</method> fails: its rung is available and its entry
/// class answers no save, so the failure is the store's own rather than the rung's.</p>
Parameter FAILINGSTORECLASS = "OcuPilot.Test.SecretFakeRung";

/// <p>A well-formed provider reply, queued on the leg that must not call the provider.</p>
Parameter OKBODY = "{""content"":[{""type"":""text"",""text"":""probe-reply-marker ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":2}}";

/// <p>A documentation-reserved endpoint (RFC 5737 TEST-NET-1). Nothing connects to it.</p>
Parameter PUBLICENDPOINT = "https://192.0.2.1/v1/messages";

/// <p>A second documentation-reserved endpoint (RFC 5737 TEST-NET-2), for the leg that tests edited
/// values. Nothing connects to it.</p>
Parameter OTHERENDPOINT = "https://198.51.100.7/v1/messages";

/// <p>The credential seam that answers <parameter>LOCALKEY</parameter> for the stubbed row, so the
/// live-counter call resolves a key and reaches the transport instead of refusing before it.</p>
Parameter SECRETPROBECLASS = "OcuPilot.Test.SecretProbe";

/// <p>A key of the shape the probe catalog's local row requires.</p>
Parameter LOCALKEY = "probe-local-abcdefghijklmnop";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ##class(OcuPilot.Test.FakeCredentialRow).Clear()
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#FAULTCREDENTIAL)
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ##class(OcuPilot.Test.FakeCredentialRow).Clear()
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#FAULTCREDENTIAL)
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#FAULTCREDENTIAL), 0, "and no credential entry " _ ..#FAULTCREDENTIAL _ " survives it either")
    Quit $$$OK
}

/// <p>One stored definition on the shipped <code>anthropic</code> row naming
/// <parameter>FAULTCREDENTIAL</parameter>, and its id -- or <code>""</code>.</p>
Method CredentialDefinition(pSuffix As %String) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ pSuffix
    Set tRow.Provider = "anthropic"
    Set tRow.Model = "claude-opus-5"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "creds"
    Set tRow.EnvVarName = ""
    Set tRow.CredentialName = ..#FAULTCREDENTIAL
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": a stored definition is created")
    Set tId = ""
    If $$$ISOK(tSC) Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

/// <p>One stored definition on <class>OcuPilot.Test.CatalogProbe</class>'s local-allowed row,
/// whose adapter is the transport stub, and its id -- or <code>""</code>.</p>
Method StubbedDefinition(pSuffix As %String) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ pSuffix
    Set tRow.Provider = ##class(OcuPilot.Test.CatalogProbe).#LOCALKEY
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = ..#PUBLICENDPOINT
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": a stored definition is created")
    Set tId = ""
    If $$$ISOK(tSC) Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

/// <p>DW-421 -- a credential store that fails answers 500 with code <code>INTERNAL</code> and the
/// store's own reason, rather than reporting a key the instance does not hold.</p>
/// <p>Driven through <class>OcuPilot.Test.RouterFixture</class>'s credential route, which runs the
/// literal, inherited <method>OcuPilot.Api.Definitions.HandleStoreCredential</method> body with
/// the probe's credential seam under it: the entry class
/// <parameter>FAILINGSTORECLASS</parameter> names answers no save, so the shipped store's own
/// failure arm is what renders.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Definitions.HandleStoreCredential</method> ignore the
/// store's status and carry on, and recompile the package -> this goes red with a 200.</p>
Method TestACredentialStoreThatFailsAnswersFiveHundredInternal()
{
    Set tId = ..CredentialDefinition("StoreFault")
    If tId = "" Quit
    Do ##class(OcuPilot.Test.DefinitionsProbe).SetSecretClass(..#FAILINGSTORECLASS)

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/agent-definitions/" _ tId _ "/credential", "POST", , .tBody, .tStatus, , , ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY))
    Do $$$AssertStatusOK(tSC, "the dispatch completes")
    Do $$$AssertEquals(tStatus, 500, "a store that failed is a server error, not an accepted write (" _ tBody _ ")")
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON(tBody)
    } Catch ex {
        Set tAnswer = ""
    }
    Do $$$AssertTrue($IsObject(tAnswer), "and answers an AD-12 envelope (" _ tBody _ ")")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.code, "INTERNAL", "with the internal code (AD-39)")
    Do $$$AssertEquals(tAnswer.reason, "The credential could not be stored", "and the reason this arm writes, not a generic one")
    Do $$$AssertEquals(tBody [ ..#PROBEKEY, 0, "and no part of the key reaches the envelope")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#FAULTCREDENTIAL), 0, "and nothing was stored")
}

/// <p>A test of the stored values given no row version refuses at 500 with code
/// <code>INTERNAL</code>, and <b>makes no provider call</b>; a test of edited values given none
/// makes the call and answers, because it writes no verification the version could guard. The
/// provider counter is what tells the two refusals at 500 apart: this one comes before the call,
/// the verification-write refusal after it.</p>
/// <p>The same outcome is computed first <b>with the version</b>, to show the call reaching the
/// transport, so the zero read on the refused leg is a measurement.</p>
/// <p>Mutation: refuse an empty version on every branch of
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>, not only the as-stored one, and
/// recompile the package -> the edited-values leg goes red with a 500 and no call.</p>
Method TestAnAsStoredTestWithNoVersionRefusesBeforeTheProviderIsCalled()
{
    Set tId = ..StubbedDefinition("VersionFault")
    If tId = "" Quit
    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow)
    Do $$$AssertStatusOK(tOpenSC, "the row opens")
    ; Nothing below has a meaning without the row, and reading it undefined is an <UNDEFINED>
    ; raised from the middle of the method rather than the named failure just asserted.
    If $$$ISERR(tOpenSC) || '$IsObject(tRow) Quit
    Do ##class(OcuPilot.Test.DefinitionsProbe).ValuesFromRow(tRow, .tStored)
    Set tVersion = +tRow.RowVersion
    Set tRow = ""
    Kill tValues
    Merge tValues = tStored
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)

    ; The counter, shown live on this exact path. Without it, a stub that was never installed as
    ; this row's adapter would read 0 below and the fault leg would pass for the wrong reason.
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSecretClass(..#SECRETPROBECLASS)
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSslState("present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#LOCALKEY)
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Kill tLiveValues
    Merge tLiveValues = tValues
    Do ##class(OcuPilot.Test.DefinitionsProbe).ConnectionOutcome(tId, .tLiveValues, .tStored, .tLiveAnswer, .tLiveStatus, .tLiveFault, "", tVersion)
    Do $$$AssertTrue('$IsObject(tLiveFault), "with the version the call completes without a fault")
    Do $$$AssertTrue($IsObject(tLiveAnswer), "answering a body")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and the queued answer was consumed, so the counter is live on this path")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Kill tStoredValues
    Merge tStoredValues = tValues
    Do ##class(OcuPilot.Test.DefinitionsProbe).ConnectionOutcome(tId, .tStoredValues, .tStored, .tAnswer, .tHttpStatus, .tFault, "", "")
    Do $$$AssertTrue('$IsObject(tAnswer), "a test of the stored values given no version produces no answer body")
    Do $$$AssertTrue($IsObject(tFault), "a fault is, instead")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tHttpStatus, 500, "reported as a server error")
    Do $$$AssertEquals(tFault.code, "INTERNAL", "with the internal code")
    Do $$$AssertEquals(tFault.reason, "The agent definition could not be read", "and this arm's own reason")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and the provider was never called, which is what distinguishes this refusal from the one after the call")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tEdit = {"endpointUrl":(..#OTHERENDPOINT)}
    Kill tEditValues
    Merge tEditValues = tValues
    Do ##class(OcuPilot.Test.DefinitionsProbe).MergeBody(tEdit, .tEditValues, .tPresent)
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tEditValues)
    Do ##class(OcuPilot.Test.DefinitionsProbe).ConnectionOutcome(tId, .tEditValues, .tStored, .tEditAnswer, .tEditStatus, .tEditFault, tEdit, "")
    Do $$$AssertTrue('$IsObject(tEditFault), "a test of edited values given no version answers no fault: " _ $Select($IsObject(tEditFault): tEditFault.%ToJSON(), 1: ""))
    Do $$$AssertTrue($IsObject(tEditAnswer), "and answers a body")
    If '$IsObject(tEditAnswer) Quit
    Do $$$AssertEquals(tEditAnswer.testedAsStored, 0, "as a test of values that are not the stored ones")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and the provider was called")
}

/// <p>A request body the server could not read is the server's fault, not the client's: a read
/// fault answers 500 <code>INTERNAL</code> on every definition and switch route that reads a body,
/// and a malformed document still answers 400 <code>AGENT.BADBODY</code>. Nothing is written.</p>
/// <p>Driven through <method>OcuPilot.Test.Dispatch.InvokeHandlerWithRequest</method> with
/// <class>OcuPilot.Test.BodyRequest</class> as <code>%request</code>, whose content read throws;
/// the three routes that take an id are given a stored definition's.</p>
/// <p>Mutation: drop <code>.tStage</code> at any of the six <code>ReadRequestBody</code> calls and
/// recompile the package -> that route's read fault answers 400 and this goes red.</p>
Method TestAnUnreadableBodyIsAServerFaultAndAMalformedOneIsTheClients()
{
    Set tId = ..StubbedDefinition("BodyFault")
    If tId = "" Quit
    Set tBefore = ##class(OcuPilot.Test.AgentFixture).ProbeCount()
    Set tCases = $ListBuild("OcuPilot.Api.Definitions|HandleCreate|", "OcuPilot.Api.Definitions|HandleUpdate|" _ tId, "OcuPilot.Api.Definitions|HandleStoreCredential|" _ tId, "OcuPilot.Api.Definitions|HandleTest|" _ tId, "OcuPilot.Api.Switches|HandleUpdate|", "OcuPilot.Api.Switches|HandleHoldCreate|")
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tFault = ##class(OcuPilot.Test.BodyRequest).%New()
        Set tFault.FaultOnContent = 1
        Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHandlerWithRequest(tFault, $Piece(tCase, "|", 1), $Piece(tCase, "|", 2), $Piece(tCase, "|", 3), .tBody, .tStatus)
        Do $$$AssertStatusOK(tSC, tCase _ ": the handler completes")
        Do $$$AssertEquals(tStatus, 500, tCase _ ": a read fault is a server error (" _ tBody _ ")")
        Set tAnswer = ..EnvelopeOf(tBody)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), "INTERNAL", tCase _ ": with the internal code")
    }

    Set tRaw = ##class(%Stream.TmpBinary).%New()
    Do tRaw.Write("{not json at all")
    Set tMalformed = ##class(OcuPilot.Test.BodyRequest).%New()
    Set tMalformed.MimePayload = tRaw
    Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHandlerWithRequest(tMalformed, "OcuPilot.Api.Definitions", "HandleCreate", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the handler completes on a malformed document")
    Do $$$AssertEquals(tStatus, 400, "a malformed document is the client's (" _ tBody _ ")")
    Set tAnswer = ..EnvelopeOf(tBody)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), ##class(OcuPilot.Api.Error).#AGENTBADBODY, "under the bad-body code")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), tBefore, "and no definition was written")
}

/// <p>The AD-12 envelope <var>pBody</var> holds, or <code>""</code> when it holds none.</p>
ClassMethod EnvelopeOf(pBody As %String) As %DynamicObject
{
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON(pBody)
    } Catch ex {
        Set tAnswer = ""
    }
    Quit tAnswer
}

}
