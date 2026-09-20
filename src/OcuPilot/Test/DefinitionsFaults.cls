/// <p>DW-421 -- the two error shapes on <class>OcuPilot.Api.Definitions</class> that are reachable
/// through seams the handler already publishes: a credential store that fails, and a definition
/// whose row version cannot be read.</p>
/// <p>Both render 500 with code <code>INTERNAL</code> and a reason of their own, and the second is
/// distinguished from its neighbour by what it does <b>not</b> do -- it makes no provider call at
/// all. The same call is driven once with the row intact first, where it reaches the transport and
/// consumes a queued answer, so the zero read afterwards is a measurement rather than a counter
/// that was never live.</p>
/// <p>The handler's remaining error shapes name <class>OcuPilot.Kernel.State.Agent</class> by
/// literal <code>##class</code> and are unreachable without a state-class seam, which is
/// production code outside this story's footprint; they are recorded in the ledger rather than
/// worked around here.</p>
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

/// <p>DW-421 -- a definition whose row version cannot be read refuses at 500 with code
/// <code>INTERNAL</code>, and <b>makes no provider call</b>. That is what separates this refusal
/// from the verification-write refusal that follows the call: both render the same envelope, and
/// only the provider counter tells them apart.</p>
/// <p>The row is read, the same outcome is computed <b>with the row still present</b> to show the
/// call reaching the transport, and only then is the row deleted and the outcome computed again
/// against the values it held -- the shape a definition removed between the read and the call
/// leaves behind.</p>
/// <p>Mutation: delete the <code>GuardedVersion</code> guard from
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> and recompile the package -> the
/// status, code and reason assertions go red, because the call proceeds into the port and comes
/// back with the port's own fault instead of this arm's.</p>
Method TestAnUnreadableVersionRefusesBeforeTheProviderIsCalled()
{
    Set tId = ..StubbedDefinition("VersionFault")
    If tId = "" Quit
    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow)
    Do $$$AssertStatusOK(tOpenSC, "the row opens")
    Do ##class(OcuPilot.Test.DefinitionsProbe).ValuesFromRow(tRow, .tStored)
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
    Do ##class(OcuPilot.Test.DefinitionsProbe).ConnectionOutcome(tId, .tValues, .tStored, .tLiveAnswer, .tLiveStatus, .tLiveFault)
    Do $$$AssertTrue('$IsObject(tLiveFault), "with the row present the call completes without a fault")
    Do $$$AssertTrue($IsObject(tLiveAnswer), "answering a body")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and the queued answer was consumed, so the counter is live on this path")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tId), "the row is deleted, so its version cannot be read")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)

    Do ##class(OcuPilot.Test.DefinitionsProbe).ConnectionOutcome(tId, .tValues, .tStored, .tAnswer, .tHttpStatus, .tFault)
    Do $$$AssertTrue('$IsObject(tAnswer), "no answer body is produced")
    Do $$$AssertTrue($IsObject(tFault), "a fault is, instead")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tHttpStatus, 500, "reported as a server error")
    Do $$$AssertEquals(tFault.code, "INTERNAL", "with the internal code")
    Do $$$AssertEquals(tFault.reason, "The agent definition could not be read", "and this arm's own reason")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and the provider was never called, which is what distinguishes this refusal from the one after the call")
}

}
