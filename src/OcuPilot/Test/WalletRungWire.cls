/// <p>Pins the wallet credential rung above the ladder (AD-35, AD-39, AD-42; Story 18.41's C2, C3, C4, C5 and the
/// integration criterion): what a definition save does with a <code>wallet</code> credential type and its secret name,
/// what the credential store route does with a key posted to such a definition, and what the provider base and port do
/// with the ladder's answers -- a refusal, an absence, a value that opens with a brace and a stored key.</p>
/// <p>The save and the store route are driven over HTTP as the suite's own account; the provider calls go through
/// <class>OcuPilot.Test.ProviderPortProbe</class> and <class>OcuPilot.Test.ProviderStub</class>, so <b>no socket is
/// opened</b>. A refusal is answered by <class>OcuPilot.Test.SecretWalletRefusal</class>; every other resolution reads the
/// probe collection of <class>OcuPilot.Test.WalletRungProbe</class> through the shipped ladder.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and an account holding
/// <code>%Admin_Wallet</code>. Every wallet object and every definition is created by exact name and removed after each
/// test.</p>
Class OcuPilot.Test.WalletRungWire Extends %UnitTest.TestCase
{

Parameter APIBASE = "/api/ocupilot";

Parameter PROBE = "OcuPilot.Test.WalletRungProbe";

Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>The prefix every definition this class creates is named with; <class>OcuPilot.Test.AgentFixture</class> removes by
/// the prefix it shares.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgentWire1841";

/// <p>The stored value of the probe key-value secret: key-shaped for the canary provider row, fabricated.</p>
Parameter CANARY = "sk-ant-ocupilotwalletwirecanary18410000";

/// <p>A key posted to the credential store route, key-shaped and fabricated.</p>
Parameter POSTEDKEY = "sk-ant-ocupilotwalletpostedkey18410000";

/// <p>The distinctive middle of both, which the assertions search for.</p>
Parameter CANARYMARK = "ocupilotwallet";

/// <p>The key-value secrets whose <code>AllowedHosts</code> do not list the canary provider row's host, and list it; each
/// holds <parameter>CANARY</parameter> and requires TLS. The row's host is <parameter>CANARYHOST</parameter>.</p>
Parameter OFFLIST = "OcuPilotProbe1841.offlist";

Parameter ONLIST = "OcuPilotProbe1841.onlist";

Parameter CANARYHOST = "api.anthropic.com";

/// <p>The endpoint of a marked-local definition on the plain-http row, and of the one the canary row serves.</p>
Parameter PLAINENDPOINT = "http://127.0.0.1:11434/v1/messages";

/// <p>Whether the vendor audit event <code>WalletSecretUse</code> was enabled before the test, or <code>-1</code>.</p>
Property PreparedUseEvent As %Integer;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedUseEvent = -1
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Each test runs over the probe resource, collection and three secrets and over a clean port, stub and ladder.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretWalletRefusal).Disarm()
    Set ..PreparedUseEvent = $ClassMethod(..#PROBE, "UseEventEnabled")
    Set tSC = $ClassMethod(..#PROBE, "EnsureResource")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsureCollection")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddKeyValue", $Parameter(..#PROBE, "DEFAULTSECRET"), {"Secret": (..#CANARY), "Usage": 15})
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddKeyValue", $Parameter(..#PROBE, "MULTISECRET"), {"Secret": {"first": (..#CANARY), "second": "two"}, "Usage": 15})
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddSymmetricKey", $Parameter(..#PROBE, "SYMMETRICSECRET"))
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.SecretWalletRefusal).Disarm()
    If ..PreparedUseEvent '= -1 Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetUseEvent", ..PreparedUseEvent), "the WalletSecretUse event is restored to the state it was read in")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions), "every probe definition is removed")
    Do $$$AssertEquals(tDefinitions, 0, "and none survives")
    ; A store that reached the credentials rung would have created an entry under the secret's name.
    Do ##class(OcuPilot.Test.CredentialFixture).Remove($Parameter(..#PROBE, "DEFAULTSECRET"))
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists($Parameter(..#PROBE, "DEFAULTSECRET")), 0, "no credential entry of the secret's name survives")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every wallet object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>One request to the definitions surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/agent/definitions" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .tHeaders, pBody, "application/json")
}

/// <p>Create a definition on the wallet rung naming <var>pSecret</var> over the wire, with a stray environment variable
/// name the server must clear; its id, or <code>""</code>.</p>
Method Create(pSuffix As %String, pSecret As %String) As %String
{
    Set tBody = {"name": (..#PROBEPREFIX _ pSuffix), "provider": "anthropic", "credType": "wallet", "credentialName": (pSecret), "envVarName": "STRAYENVVAR"}
    Set tSC = ..Call("POST", "", tBody.%ToJSON(), .tStatus, .tText)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created (" _ tText _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tText).id
}

/// <p>The first violation of a 422 body <var>pText</var> as <code>field code reason</code>, or what the body was.</p>
ClassMethod FirstViolation(pText As %String) As %String
{
    Set tAnswer = ##class(%DynamicObject).%FromJSON(pText)
    If '$IsObject(tAnswer.detail) || '$IsObject(tAnswer.detail.violations) Quit "no violations: " _ pText
    Set tViolation = tAnswer.detail.violations.%Get(0)
    If '$IsObject(tViolation) Quit "no violations: " _ pText
    Quit tViolation.field _ " " _ tViolation.code _ " " _ tViolation.reason
}

/// <p>C2, the server's half: a definition saved on the wallet rung reads back as <code>wallet</code> with the secret's
/// name and its stray environment variable name cleared, and a name that is not <code>collection.secret</code> within 128
/// characters is refused <code>WALLETRUNG.NAME</code> on <code>credentialName</code> with its published sentence, the
/// stored definition unchanged.</p>
/// <p>Mutation (Rule 19): drop the <code>wallet</code> arm of <method>OcuPilot.Kernel.AgentRules.CredTypeAccepted</method>
/// -- the create is refused on <code>credType</code> and this goes red.</p>
Method TestASaveStoresTheRungAndTheNameAndRefusesAMalformedOne()
{
    Set tSecret = $Parameter(..#PROBE, "DEFAULTSECRET")
    Set tId = ..Create("Save", tSecret)
    If tId = "" Quit
    Set tSC = ..Call("GET", "/" _ tId, "", .tStatus, .tText)
    Set tRead = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tRead.credType _ " " _ tRead.credentialName _ " [" _ tRead.envVarName _ "]", "wallet " _ tSecret _ " []", "it reads back as the wallet rung naming the secret, with no environment variable")
    For tBad = "", "nodot", ".lead", "trail.", "has space.x", "9digit.x", "coll.sec ret", "coll.sec/ret", $Translate($Justify("", 127), " ", "a") _ ".b" {
        Set tBody = {"credType": "wallet", "credentialName": (tBad)}
        Set tSC = ..Call("PUT", "/" _ tId, tBody.%ToJSON(), .tStatus, .tText)
        Do $$$AssertEquals(tStatus, 422, "the name '" _ $Extract(tBad, 1, 40) _ "' (" _ $Length(tBad) _ " characters) is refused")
        If tStatus = 422 Do $$$AssertEquals(..FirstViolation(tText), "credentialName WALLETRUNG.NAME " _ ##class(OcuPilot.Api.WalletRungError).#REASONNAME, "on credentialName, with the published sentence")
    }
    Set tSC = ..Call("GET", "/" _ tId, "", .tStatus, .tText)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).credentialName, tSecret, "and the stored name is unchanged")
    Set tEdge = "%Collection-1_2.name.with-dots_1"
    Set tBody = {"credType": "wallet", "credentialName": (tEdge)}
    Set tSC = ..Call("PUT", "/" _ tId, tBody.%ToJSON(), .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "a name of the vendor's own shape is accepted: " _ tText)
    Set tLong = $Translate($Justify("", 126), " ", "a") _ ".b"
    Set tBody = {"credType": "wallet", "credentialName": (tLong)}
    Set tSC = ..Call("PUT", "/" _ tId, tBody.%ToJSON(), .tStatus, .tText)
    Do $$$AssertEquals(tStatus _ " " _ $Length(tLong), "200 128", "and so is one of exactly 128 characters")
}

/// <p>C5, the store route: a key posted to a wallet definition is refused <code>WALLETRUNG.KEYSTORE</code> on
/// <code>apiKey</code> with its published sentence, and nothing is written -- the wallet secret keeps its value, no
/// credential entry of that name exists, the definition is not marked as owning one, and the answer carries no part of
/// the key. A body with no key is still refused for that first.</p>
/// <p>Mutation (Rule 19): remove the <code>wallet</code> arm from
/// <method>OcuPilot.Api.Definitions.CredentialRefusal</method> -- the post reaches the store, the entry is created and
/// this goes red.</p>
Method TestAKeyPostedToAWalletDefinitionIsRefusedAndNothingIsWritten()
{
    Set tSecret = $Parameter(..#PROBE, "DEFAULTSECRET")
    Set tId = ..Create("Store", tSecret)
    If tId = "" Quit
    Set tBefore = $ClassMethod(..#PROBE, "StoredValue", tSecret)
    Set tSC = ..Call("POST", "/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#POSTEDKEY), .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 422, "the post is refused: " _ tText)
    If tStatus = 422 Do $$$AssertEquals(..FirstViolation(tText), "apiKey WALLETRUNG.KEYSTORE " _ ##class(OcuPilot.Api.WalletRungError).#REASONKEYSTORE, "on apiKey, with the published sentence")
    Do $$$AssertEquals(tText [ ..#CANARYMARK, 0, "and the answer carries no part of the key")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredValue", tSecret) = tBefore, 1, "the wallet secret keeps its value")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(tSecret), 0, "no credential entry of that name was created")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow), "the definition reads back")
    If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.CredentialCreated, 0, "and is not marked as owning an entry")
    Set tRow = ""
    Set tSC = ..Call("POST", "/" _ tId _ "/credential", "{}", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 422, "a post with no key is refused: " _ tText)
    If tStatus = 422 Do $$$AssertEquals($Piece(..FirstViolation(tText), " ", 1, 2), "apiKey AGENT.CREDENTIAL.REQUIRED", "for the missing key first")
}

/// <p>C5, the brace: a stored value that opens with <code>{</code> -- a wallet secret with several members -- is refused
/// <code>PROVIDER.KEYSHAPE</code> before any request is built, so none is sent and no member of it reaches the
/// transport, the envelope or the log. It is driven on the <code>gemini</code> row, whose keys declare no prefix: a
/// family whose keys begin with a prefix refuses the value on that alone, and its own shape test is not what this pins.</p>
/// <p>Mutation (Rule 19): drop the brace term from <method>OcuPilot.Kernel.Provider.Base.Invoke</method>'s shape gate --
/// the call reaches the stub and this goes red.</p>
Method TestAValueThatOpensWithABraceSendsNoRequest()
{
    Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
    Do $ClassMethod(..#PORT, "SetCatalogClass", "OcuPilot.Test.CatalogProbeShipped")
    Do ##class(OcuPilot.Test.ProviderSecret).Definition(.tValues, "gemini", $Parameter(..#PROBE, "MULTISECRET"), 1, "wallet")
    Set tSC = $ClassMethod(..#PORT, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE, "the call is refused as not shaped like a key")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no request is sent")
    If $IsObject(tFault) Do $$$AssertEquals(tFault.%ToJSON() [ ..#CANARYMARK, 0, "the envelope carries no member of the secret")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Logged") [ ..#CANARYMARK, 0, "nor does the log")
}

/// <p>The integration criterion: a wallet definition whose secret holds a key-shaped canary calls the provider with it in
/// the family's key header -- and nowhere else in the request.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> answer <code>""</code> -- the call
/// is refused for its credential and this goes red.</p>
Method TestTheStoredValueIsTheKeyTheRequestCarries()
{
    Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
    Do ##class(OcuPilot.Test.ProviderSecret).Definition(.tValues, "", $Parameter(..#PROBE, "DEFAULTSECRET"), 0, "wallet")
    Do ##class(OcuPilot.Test.ProviderStub).ArmKeyCompare(..#CANARY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":1}}")
    Set tSC = $ClassMethod(..#PORT, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%ToJSON(), 1: ""), "", "the call succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and sends one request")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("keyMatches"), 1, "whose key header is the stored value")
    Do $$$AssertTrue(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames") [ "x-api-key", "in the family's key header")
    Do $$$AssertEquals((##class(OcuPilot.Test.ProviderStub).Recorded("body") _ ##class(OcuPilot.Test.ProviderStub).Recorded("url")) [ ..#CANARYMARK, 0, "and in no other part of the request")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Logged") [ ..#CANARYMARK, 0, "nor in the log")
}

/// <p>C3, above the ladder: a refusal the ladder answers faults the provider call with its own code, a reason that names
/// the pair or the setting, the detail member that carries it (<code>failedPair</code> or <code>setting</code>), opens no
/// socket, and leaves the stored definition enabled and verified. The use refusal answers 403 and the usage and setting
/// refusals 503, each on its status's own slug.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Provider.Base.Invoke</method> fault every empty resolution
/// <code>PROVIDER.CREDENTIAL</code> -- the code assertion goes red, and the port disables the definition. Drop the slug
/// line from <method>OcuPilot.Kernel.Provider.Base.FaultRefused</method> -- the use refusal reads
/// <code>unavailable</code> and this goes red. Make <method>OcuPilot.Api.WalletRungError.DetailKeyFor</method> answer
/// <code>failedPair</code> for every code -- the setting refusals carry no <code>setting</code> and this goes red.</p>
Method TestARefusalNamesThePairAndLeavesTheDefinitionEnabled()
{
    Set tId = ..StoredDefinition("Refused", $Parameter(..#PROBE, "DEFAULTSECRET"))
    If tId = "" Quit
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretWalletRefusal")
    For tCase = $ListBuild("WALLETRUNG.USE", "OcuPilotProbe1841Use:USE", 403, "failedPair"), $ListBuild("WALLETRUNG.USAGE", "%Admin_Wallet:USE", 503, "failedPair"), $ListBuild("WALLETRUNG.REQUIRETLS", "RequireTLS", 503, "setting"), $ListBuild("WALLETRUNG.ALLOWEDHOSTS", "AllowedHosts", 503, "setting") {
        Set tCode = $List(tCase, 1)
        Set tPair = $List(tCase, 2)
        Do ##class(OcuPilot.Test.SecretWalletRefusal).Arm(tCode, tPair)
        Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), tCode _ ": the definition is enabled and verified before the call")
        Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
        Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
        Do $$$AssertStatusOK(tSC, tCode _ ": the port returns $$$OK")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), tCode, tCode _ ": the fault carries the ladder's code")
        Do $$$AssertEquals(tHttpStatus, $List(tCase, 3), tCode _ ": answered " _ $List(tCase, 3))
        If $IsObject(tFault) {
            Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.WalletRungError).ReasonFor(tCode, tPair), tCode _ ": the reason is the published sentence naming the pair or the setting")
            Do $$$AssertEquals(tFault.detail.%Get($List(tCase, 4)), tPair, tCode _ ": and detail." _ $List(tCase, 4) _ " carries it")
            Do $$$AssertEquals(tFault.error, ##class(OcuPilot.Api.Error).GetSlugForStatus($List(tCase, 3)), tCode _ ": and the slug is its status's own")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, tCode _ ": and no socket was opened")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow), tCode _ ": the definition reads back")
        If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.Enabled _ tRow.ConnectionVerified, 11, tCode _ ": still enabled and verified")
        Set tRow = ""
    }
}

/// <p>C4, above the ladder: a wallet reference that names no key-value secret -- an absent one and a symmetric key --
/// faults the call <code>PROVIDER.CREDENTIAL</code>, naming the rung and the reference, opens no socket, and leaves the
/// stored definition disabled and unverified.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> answer an absent secret as
/// transient -- the code is <code>PROVIDER.CREDENTIALSTORE</code>, the definition stays enabled and this goes red.</p>
Method TestAnAbsentSecretFaultsTheCredentialAndDisablesTheDefinition()
{
    For tSecret = "OcuPilotProbe1841.nope", $Parameter(..#PROBE, "SYMMETRICSECRET") {
        Set tId = ..StoredDefinition("Absent", tSecret)
        If tId = "" Quit
        Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), tSecret _ ": the definition is enabled and verified before the call")
        Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
        Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
        Do $$$AssertStatusOK(tSC, tSecret _ ": the port returns $$$OK")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL, tSecret _ ": the call faults for its credential")
        If $IsObject(tFault) Do $$$AssertTrue(tFault.reason [ ("wallet " _ tSecret), tSecret _ ": naming the rung and the reference: " _ tFault.reason)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, tSecret _ ": and no socket was opened")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow), tSecret _ ": the definition reads back")
        If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.Enabled _ tRow.ConnectionVerified, "00", tSecret _ ": disabled, its verification cleared")
        Set tRow = ""
        Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    }
}

/// <p>C4's neighbour, above the ladder: a wallet whose listing raises, so the ladder cannot say whether the secret exists,
/// faults the call <code>PROVIDER.CREDENTIALSTORE</code> (503) naming the rung and the reference, opens no socket and
/// leaves the stored definition enabled and verified: a store that could not be read judges nothing about the reference.
/// The shipped arm's own failure path runs; only the listing is made to raise.</p>
/// <p>Mutation (Rule 19): leave <var>pTransient</var> 0 in the catch of
/// <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> -- the call faults <code>PROVIDER.CREDENTIAL</code>, the port
/// disables the definition and this goes red.</p>
Method TestAWalletThatCouldNotBeReadLeavesTheDefinitionEnabled()
{
    Set tSecret = $Parameter(..#PROBE, "DEFAULTSECRET")
    Set tId = ..StoredDefinition("Unreadable", tSecret)
    If tId = "" Quit
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretWalletRefusal")
    Do ##class(OcuPilot.Test.SecretWalletRefusal).ArmRaise()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified before the call")
    Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERCREDENTIALSTORE, "a wallet that could not be read is a store failure, not an absent reference")
    Do $$$AssertEquals(tHttpStatus, 503, "answered 503")
    If $IsObject(tFault) Do $$$AssertTrue(tFault.reason [ ("wallet " _ tSecret), "naming the rung and the reference: " _ tFault.reason)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no socket was opened")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow), "the definition reads back")
    If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.Enabled _ tRow.ConnectionVerified, 11, "still enabled and verified")
    Set tRow = ""
}

/// <p>A refusal by the secret's own <code>RequireTLS</code>, through the shipped ladder and the port: a marked-local
/// definition on the plain-http row that names a secret that requires TLS faults <code>WALLETRUNG.REQUIRETLS</code> (503)
/// with the published sentence and <code>detail.setting</code>, opens no socket, carries no part of the secret and leaves
/// the stored definition enabled and verified.</p>
/// <p>Mutation (Rule 19): drop the scheme test from <method>OcuPilot.Kernel.Secret.Ladder.WalletTransportRefusal</method>
/// -- the call reaches the stub and this goes red.</p>
Method TestAnEndpointThatIsNotHttpsFaultsAWalletCallThatRequiresTls()
{
    Set tId = ..StoredDefinition("Plain", $Parameter(..#PROBE, "DEFAULTSECRET"), 1)
    If tId = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified before the call")
    Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.WalletRungError).#REQUIRETLS, "the call is refused by the secret's RequireTLS")
    Do $$$AssertEquals(tHttpStatus, 503, "answered 503")
    If $IsObject(tFault) {
        Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.WalletRungError).#REASONREQUIRETLS, "with the published sentence")
        Do $$$AssertEquals(tFault.detail.setting, "RequireTLS", "naming the setting")
        Do $$$AssertEquals(tFault.%ToJSON() [ ..#CANARYMARK, 0, "and carrying no part of the secret")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "no socket was opened")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Logged") [ ..#CANARYMARK, 0, "and the log carries no part of the secret")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow), "the definition reads back")
    If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.Enabled _ tRow.ConnectionVerified, 11, "still enabled and verified")
    Set tRow = ""
}

/// <p>A refusal by the secret's own <code>AllowedHosts</code>, and the host it lists: a stored definition whose endpoint
/// host the secret does not list faults <code>WALLETRUNG.ALLOWEDHOSTS</code> (503) with the published sentence and
/// <code>detail.setting</code>, opens no socket and stays enabled and verified; a secret that lists the host is read, and
/// the stub's request carries its value. With <code>WalletSecretUse</code> on, the refused call wrote no use row and the
/// served one wrote one, so the refusal came before the read.</p>
/// <p>Mutation (Rule 19): pass no endpoint from <method>OcuPilot.Kernel.Provider.Base.Invoke</method> to the ladder -- the
/// listed host is refused as not https and this goes red. Drop the host test from
/// <method>OcuPilot.Kernel.Secret.Ladder.WalletTransportRefusal</method> -- the unlisted host is served and this goes
/// red.</p>
Method TestAListedHostIsServedAndAnUnlistedOneFaultsTheCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", ..#OFFLIST, {"Secret": (..#CANARY), "Usage": 15, "AllowedHosts": ["other.example.test"]}), "a secret that does not list the endpoint's host exists")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", ..#ONLIST, {"Secret": (..#CANARY), "Usage": 15, "AllowedHosts": [(..#CANARYHOST)]}), "and one that does")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetUseEvent", 1), "the WalletSecretUse event is turned on")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Hang 1
    Set tId = ..StoredDefinition("Unlisted", ..#OFFLIST)
    If tId = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified before the call")
    Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.WalletRungError).#ALLOWEDHOSTS, "the call is refused by the secret's AllowedHosts")
    Do $$$AssertEquals(tHttpStatus, 503, "answered 503")
    If $IsObject(tFault) {
        Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.WalletRungError).#REASONALLOWEDHOSTS, "with the published sentence")
        Do $$$AssertEquals(tFault.detail.setting, "AllowedHosts", "naming the setting")
        Do $$$AssertEquals(tFault.%ToJSON() [ ..#CANARYMARK, 0, "and carrying no part of the secret")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "no socket was opened")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow), "the definition reads back")
    If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.Enabled _ tRow.ConnectionVerified, 11, "still enabled and verified")
    Set tRow = ""
    Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
    Do ##class(OcuPilot.Test.ProviderSecret).Definition(.tValues, "", ..#ONLIST, 0, "wallet")
    Do ##class(OcuPilot.Test.ProviderStub).ArmKeyCompare(..#CANARY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":1}}")
    Set tSC = $ClassMethod(..#PORT, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "the port returns $$$OK for the listed host")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%ToJSON(), 1: ""), "", "and the call succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "sending one request")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("keyMatches"), 1, "whose key header is the stored value")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "UseRows", tSince, ..#ONLIST, 1), 1, "The served read wrote its use row")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "UseRows", tSince, ..#OFFLIST), 0, "and the refused call wrote none")
}

/// <p>The order of the two checks: with the TLS configuration the call goes through absent and the endpoint host unlisted by
/// the secret, the call is refused for the configuration (<code>PROVIDER.TLS</code>) and not for the secret; once the
/// configuration is present, the same call is refused for the secret.</p>
/// <p>Mutation (Rule 19): skip the refusal for an absent configuration in <method>OcuPilot.Port.ProviderPort.Dispatch</method>
/// -- the first call reaches the ladder and is refused <code>WALLETRUNG.ALLOWEDHOSTS</code>, so this goes red.</p>
Method TestTheTlsConfigurationIsJudgedBeforeTheSecretsSettings()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddKeyValue", ..#OFFLIST, {"Secret": (..#CANARY), "Usage": 15, "AllowedHosts": ["other.example.test"]}), "a secret that does not list the endpoint's host exists")
    Set tId = ..StoredDefinition("Order", ..#OFFLIST)
    If tId = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled and verified before the calls")
    Do $ClassMethod(..#PORT, "SetSslState", "missing")
    Do ##class(OcuPilot.Test.ProviderPort).Messages(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERTLS, "with the configuration absent, the call is refused for the configuration")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.WalletRungError).#ALLOWEDHOSTS, "with it present, the same call is refused for the secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and neither opened a socket")
}

/// <p>One stored definition on the wallet rung for the canary provider row, naming <var>pSecret</var>; its id, or
/// <code>""</code>. With <var>pLocal</var> it is the marked-local definition of the row that allows local, which names
/// the plain-http <parameter>PLAINENDPOINT</parameter>.</p>
Method StoredDefinition(pSuffix As %String, pSecret As %String, pLocal As %Boolean = 0) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ pSuffix
    Set tRow.Provider = $Select(pLocal: ##class(OcuPilot.Test.CatalogProbe).#LOCALKEY, 1: ##class(OcuPilot.Test.CatalogProbe).#CANARYKEY)
    Set tRow.Model = "probe-canary-model-1"
    Set tRow.EndpointUrl = $Select(pLocal: ..#PLAINENDPOINT, 1: "https://api.anthropic.com/v1/messages")
    Set tRow.MarkedLocal = ''pLocal
    Set tRow.CredType = "wallet"
    Set tRow.CredentialName = pSecret
    Set tRow.MaxTokens = 4000
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": a stored wallet definition is created")
    If $$$ISERR(tSC) Quit ""
    Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

}
