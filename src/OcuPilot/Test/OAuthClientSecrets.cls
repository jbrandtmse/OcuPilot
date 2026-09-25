/// <p>Pins Story 12.5's four secrets (AD-3, AD-6, AD-35, AD-56): the editor's Save stores the client
/// secret, the key password and the registration access token through one secrets write and the
/// initial access token on the chosen server description; no read, form read, screen context,
/// proposal, ledger row, agent marker or OcuPilot log line carries any of them; an edit that changes
/// only secrets sends no configuration write; a secrets write carrying none is refused before the
/// vendor saves; and the agent's secrets tool asks for them at the confirm and never stores them.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo
/// fixture, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes OAuth 2.0 client configurations and server
/// descriptions. Every secret is synthetic (<method>OcuPilot.Test.OAuthClientProbe.Secret</method>).</p>
Class OcuPilot.Test.OAuthClientSecrets Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthClientSetSecrets";

Parameter SCREEN = "OcuPilot.Test.OAuthClientSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthClientRecordPort";

Parameter FAILPORT = "OcuPilot.Test.OAuthClientFailPort";

Parameter FAILSAVE = "OcuPilot.Test.OAuthClientFailSave";

Parameter PROBE = "OcuPilot.Test.OAuthClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.Client.ClientConfiguration";

Parameter CREATEPATH = "/oauth/client-configuration";

Parameter FORMPATH = "/oauth/client-configuration/form";

/// <p>The server description the class's clients are configured against, made per method.</p>
Property ServerId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..ServerId = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientSecrets creates and deletes OAuth 2.0 client configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "AddServer", $ClassMethod(..#PROBE, "Issuer", "secrets"), .tId)
    Set ..ServerId = $Get(tId)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#FAILPORT, "Disarm")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>A request over the wire as the test account, answering the status and the raw body.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
}

/// <p>AC4 on the screen's caller: a create sent with the four secrets stores each -- the three
/// client secrets on the configuration, the initial access token on its server description -- and
/// answers without any; the port's read and the form read carry none, nor either secret member; an
/// edit with the four fields empty sends no secret and keeps each stored one.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthClientPort.Stripped</method> stops removing
/// <code>registration_access_token</code> -- the port's-read assertion goes red.</p>
Method TestTheSaveStoresEachSecretAndNoReadCarriesIt()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Secrets")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "clientsecret")
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "keypassword")
    Set tToken = $ClassMethod(..#PROBE, "Secret", "registration")
    Set tInitial = $ClassMethod(..#PROBE, "Secret", "initial")
    Set tBody = {"ClientType": "confidential", "SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG")), "RedirectionEndpoint": ($Parameter(..#PROBE, "REDIRECT"))}
    Do tBody.%Set("ApplicationName", tName, "string")
    Do tBody.%Set("ServerDefinition", ..ServerId, "string")
    Do tBody.%Set("ClientSecret", tSecret, "string")
    Do tBody.%Set("ClientPassword", tPassword, "string")
    Do tBody.%Set("RegistrationAccessToken", tToken, "string")
    Do tBody.%Set("InitialAccessToken", tInitial, "string")
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 201, "the create with four secrets answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals(..Carries(tRaw, tSecret, tPassword, tToken, tInitial), 0, "and its answer carries none of them")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertTrue($IsObject(tStored), "the instance holds the configuration")
    If '$IsObject(tStored) Quit
    Do $$$AssertEquals(tStored.%Get("SecretLength") _ " " _ tStored.%Get("PasswordLength") _ " " _ tStored.%Get("TokenLength"), $Length(tSecret) _ " " _ $Length(tPassword) _ " " _ $Length(tToken), "and stores the client secret, the key password and the registration access token")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ServerTokenLength", $ClassMethod(..#PROBE, "Issuer", "secrets")), $Length(tInitial), "and the initial access token on the server description")

    Kill tQuery
    Set tQuery("applicationName") = tName
    Set tSC = ##class(OcuPilot.Port.OAuthClientPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tRead)), "the port's read answers")
    If $IsObject($Get(tRead)) {
        Do $$$AssertEquals(..Carries(tRead.%ToJSON(), tSecret, tPassword, tToken, tInitial), 0, "and carries no secret")
        Do $$$AssertEquals(tRead.%Get("Metadata").%GetTypeOf("registration_access_token") _ " " _ tRead.%Get("Metadata").%GetTypeOf("client_secret"), "unassigned unassigned", "nor either secret member")
    }
    Set tSC = ..Request("GET", ..#FORMPATH _ "?applicationName=" _ $ZConvert(tName, "O", "URL"), "", .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Do $$$AssertEquals(..Carries(tRaw, tSecret, tPassword, tToken, tInitial), 0, "and carries no secret")
    Do $$$AssertTrue('(tRaw [ "registration_access_token") && '(tRaw [ """client_secret"""), "nor either secret member")

    Set tEmpty = {"ClientSecret": "", "ClientPassword": "", "RegistrationAccessToken": "", "InitialAccessToken": "", "Description": "edited"}
    Set tSC = ..Request("PUT", ..#CREATEPATH _ "/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tName), tEmpty, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "an edit with the four fields empty answers 200")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertEquals(tAfter.%Get("SecretLength") _ " " _ tAfter.%Get("PasswordLength") _ " " _ tAfter.%Get("TokenLength") _ " " _ $ClassMethod(..#PROBE, "ServerTokenLength", $ClassMethod(..#PROBE, "Issuer", "secrets")), $Length(tSecret) _ " " _ $Length(tPassword) _ " " _ $Length(tToken) _ " " _ $Length(tInitial), "and keeps each stored secret")
}

/// <p>An edit that changes only a secret sends no configuration write: the edit completes with nothing
/// sent, and the secret goes through the one secrets write alone, its body named by the secret.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthClientSave.Update</method> no longer
/// returns on an empty body -- a <code>PUT</code> is recorded and this goes red.</p>
Method TestASecretsOnlyEditSendsNoPut()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "SecretOnly")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, {}, .tHttp, .tFault, .tViolations, .tAnswer, .tServer)
    Do $$$AssertStatusOK(tSC, "an edit with nothing to change completes")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends no configuration write")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "only")
    Set tReason = $ClassMethod(..#SCREEN, "StoreSecrets", tName, {"ClientSecret": (tSecret)})
    Do $$$AssertEquals(tReason, "", "the secret is written")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "CHANGESECRET ClientSecret", "through the one secrets write, carrying the secret alone")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), $Length(tSecret), "and the instance stores it")
}

/// <p>An edit whose fields repeat what the instance stores sends no configuration write: the merge
/// finds no change, and a vendor save would write the stored registration access token into the audit
/// database again (DW-1640).</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthClientSave.Update</method> no longer
/// returns on an empty diff -- a <code>PUT</code> is recorded and this goes red.</p>
Method TestAnEditRepeatingStoredValuesSendsNoPut()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Repeat")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId, "confidential", {"Description": "kept", "Metadata": {"client_name": "Kept"}}), "a configuration is created")
    Kill tQuery
    Set tQuery("applicationName") = tName
    Set tSC = ##class(OcuPilot.Port.OAuthClientPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tFresh)), "the configuration reads")
    If '$IsObject($Get(tFresh)) Quit
    Set tBody = {"Metadata": {"client_name": (tFresh.%Get("Metadata").%Get("client_name"))}}
    For tField = "Description", "ClientType", "SSLConfiguration", "RedirectionEndpoint" Do tBody.%Set(tField, tFresh.%Get(tField), "string")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tBody, .tHttp, .tFault, .tViolations, .tAnswer, .tServer)
    Do $$$AssertStatusOK(tSC, "an edit re-sending " _ tBody.%ToJSON() _ " completes")
    Do $$$AssertEquals(+$Get(tViolations) _ " " _ $ClassMethod(..#RECORD, "WriteCount"), "0 0", "with no violation, and sends no configuration write")
}

/// <p>A secrets write refused after the configuration saved: the edit's route answers 200 carrying
/// <code>secretsRefused</code>, the refusal's own sentence, and the instance holds the configuration
/// change. The refusal is <class>OcuPilot.Test.OAuthClientFailPort</class>'s, armed for the secrets
/// write alone; the route runs in this process through <class>OcuPilot.Test.OAuthClientFailSave</class>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthClientSave.Answer</method> drops
/// <code>secretsRefused</code> -- this goes red.</p>
Method TestASecretsWriteRefusedAfterTheSaveIsAnswered()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "SecretsRefused")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "refused")
    Do $ClassMethod(..#FAILPORT, "Arm", "CHANGESECRET", 422)
    Kill tQuery
    Set tQuery("applicationName") = tName
    Set tSC = $ClassMethod(..#FAILPORT, "Invoke", ..#ENDPOINT, "CHANGESECRET", .tQuery, {"ClientSecret": (tSecret)}, .tResult, .tHttp, .tFault)
    Set tReason = $Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: "")
    Do $$$AssertTrue(($Get(tHttp) = 422) && (tReason '= ""), "the armed port refuses a secrets write with a sentence: " _ tReason)
    Set tBody = {"Description": "saved before the refusal", "ClientSecret": (tSecret)}
    Set tSC = $ClassMethod(..#FAILSAVE, "Handle", tName, tBody, .tRaw, .tStatus)
    Do $$$AssertStatusOK(tSC, "the edit's route runs")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Extract(tRaw, 1, 300))
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("secretsRefused"), 1: ""), tReason, "carrying secretsRefused, the refusal's sentence")
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and no secret")
    Do $$$AssertEquals($ClassMethod(..#FAILPORT, "Reached", "CHANGESECRET"), 2, "the route's secrets write reached the armed port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "saved before the refusal", "and the instance holds the configuration change")
}

/// <p>A secrets write carrying no secret is refused by the port before the vendor is called, which
/// would save the configuration unchanged; no vendor audit row names the client after it.</p>
Method TestAnEmptySecretsBodyIsRefused()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "NoSecret")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    ; The create's own audit row can carry the same millisecond as an immediate Now().
    Hang 0.1
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Kill tQuery
    Set tQuery("applicationName") = tName
    For tBody = {}, {"ClientSecret": "", "RegistrationAccessToken": ""} {
        Set tSC = ##class(OcuPilot.Port.OAuthClientPort).Invoke(..#ENDPOINT, "CHANGESECRET", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "422 OAUTH.CLIENTNOSECRET", tBody.%ToJSON() _ ": refused naming the missing secret")
    }
    Hang 1
    Do $$$AssertEquals($ClassMethod(..#PROBE, "VendorRows", tSince, tName), "", "and the vendor saved nothing")
}

/// <p>AC7's secrets half: the secrets tool refuses a secret the model supplies at the mint, mints a
/// proposal of three optional rows empty on both sides, stores nothing in the proposal, and its
/// confirm, supplied two secrets, stores them through one secrets write; neither the ledger row nor
/// the agent marker carries them.</p>
Method TestTheAgentsSecretsAreAskedAtConfirmAndNeverStored()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "AgentSecrets")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "agentsecret")
    Set tToken = $ClassMethod(..#PROBE, "Secret", "agenttoken")
    Set tArgs = {}
    Do tArgs.%Set("ApplicationName", tName, "string")
    Do tArgs.%Set("ClientSecret", tSecret, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "is a secret field"), "a secret from the model is refused at the mint")
    Set tArgs = {}
    Do tArgs.%Set("ApplicationName", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the secrets write is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after") _ "|" _ tRow.%Get("optional")) }
    Do $$$AssertEquals($ListToString(tRows, ","), "ClientSecret|||1,ClientPassword|||1,RegistrationAccessToken|||1", "three optional rows, each empty on both sides")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), {"ClientSecret": (tSecret), "RegistrationAccessToken": (tToken)}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the secrets write is confirmed: " _ $Get(tCode))
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertEquals(tStored.%Get("SecretLength") _ " " _ tStored.%Get("TokenLength"), $Length(tSecret) _ " " _ $Length(tToken), "and the instance stores both")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "CHANGESECRET ClientSecret,RegistrationAccessToken", "through one secrets write carrying exactly the two supplied")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Set tProposalText = $Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))
    Do $$$AssertTrue($Get(tFound) && (..Carries(tProposalText, tSecret, tToken, tSecret, tToken) = 0), "the proposal stores no secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals(..Carries($Get(tLedger("Fields")), tSecret, tToken, tSecret, tToken), 0, "which carries no secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "one agent marker names the proposal")
    Do $$$AssertEquals(..Carries($Get(tData), tSecret, tToken, tSecret, tToken), 0, "and carries no secret")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>The editor's screen context is identity alone, because its form descriptor declares the four
/// secrets in <code>context.secretFields</code> (AD-24, AD-35). No OcuPilot line in the instance's
/// messages log carries a secret this class stored or one whose write the instance refused, and the
/// refusal did write a line there.</p>
/// <p>Mutation (Rule 19): <code>secretFields</code> emptied on
/// <class>OcuPilot.Screen.Descriptor.OAuthClientForm</class> -- the context answers the view and this
/// goes red.</p>
Method TestNoContextOrLogLineCarriesASecret()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Context")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "context")
    Set tContext = {"route": "security/oauth/clients/edit", "namespace": "HSCUSTOM", "view": {"rows": [{"ClientSecret": (tSecret), "InitialAccessToken": (tSecret)}]}}
    Do tContext.%Set("entity", tName, "string")
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
    Do $$$AssertStatusOK(tSC, "the editor's context builds")
    Do $$$AssertTrue(tBuilt, "its route resolves")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", $Get(tPayload)), "entity,namespace,route,screen", "as identity alone")
    If $IsObject($Get(tPayload)) Do $$$AssertEquals(tPayload.%ToJSON() [ tSecret, 0, "and carries no secret")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..ServerId), "a configuration is created")
    Set tReason = $ClassMethod(..#SCREEN, "StoreSecrets", tName, {"ClientSecret": (tSecret)})
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), $Length(tSecret), "the secret is stored")
    Set tRefused = $ClassMethod(..#PROBE, "Secret", "logrefused")
    Hang 1.1
    Set tBefore = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tSecret, tRefused, .tCarrying)
    ; A configuration the instance does not hold refuses the secrets write, which the port logs.
    Set tReason = $ClassMethod(..#SCREEN, "StoreSecrets", $ClassMethod(..#PROBE, "Name", "Missing"), {"ClientSecret": (tRefused)})
    Do $$$AssertNotEquals(tReason, "", "a secrets write to a configuration the instance does not hold is refused")
    For tTry = 1:1:20 {
        Set tAfter = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tSecret, tRefused, .tCarrying)
        If tAfter > tBefore Quit
        Hang 0.5
    }
    Do $$$AssertTrue(tAfter > tBefore, "the refusal wrote an OcuPilot line to messages.log (" _ tBefore _ " before, " _ tAfter _ " after)")
    Do $$$AssertEquals(tCarrying, 0, "and no OcuPilot line there carries either secret")
}

/// <p>Whether <var>pText</var> carries any of the four values.</p>
ClassMethod Carries(pText As %String, pFirst As %String, pSecond As %String, pThird As %String, pFourth As %String) As %Boolean
{
    Quit (pText [ pFirst) || (pText [ pSecond) || (pText [ pThird) || (pText [ pFourth)
}

}
