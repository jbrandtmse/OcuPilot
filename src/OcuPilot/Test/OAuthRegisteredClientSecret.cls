/// <p>Pins Story 12.8's client secret (AD-3, AD-6, AD-35, AD-56): the editor's Save stores it through
/// one secret write; no read, form read, screen context, proposal, ledger row, agent marker or OcuPilot
/// log line carries it; an empty field sends nothing and keeps the stored secret; a secret write with
/// no secret is refused before the vendor clears the stored one; a secret refused after an edit or a
/// create is answered; the agent's secret tool is minted destructive with its effect named, asks for the secret
/// at the confirm and never stores it; and the vendor's own audit rows, which carry the registration
/// access token in plain text, read masked through both audit reads.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with auditing on, an
/// account holding <code>%All</code>, no authorization server configuration and no registered client,
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and clients. Every secret is synthetic
/// (<method>OcuPilot.Test.OAuthRegisteredClientProbe.Secret</method>); the audit rows it causes stay in
/// the audit database.</p>
Class OcuPilot.Test.OAuthRegisteredClientSecret Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret";

Parameter SCREEN = "OcuPilot.Test.OAuthRegisteredClientSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthRegisteredClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthRegisteredClientRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthRegisteredClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

/// <p>The audit mask's own test, whose read helpers take any row.</p>
Parameter AUDIT = "OcuPilot.Test.AuditVendorSecrets";

Parameter ENDPOINT = "Security.OAuth2.ServerClients";

Parameter FORMPATH = "/oauth/server-client/form";

Parameter AUDITPATH = "/screens/logs.audit/read";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthRegisteredClientSecret creates and deletes this instance's OAuth 2.0 authorization server configuration and clients and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "the configuration and every client are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>A configuration and one client, its id in <var>pClientId</var>.</p>
Method SeedClient(Output pClientId As %String, pSettings As %DynamicObject = "") As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Seed")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Secret"), .pClientId, pSettings)
}

/// <p>AC4 on the screen's caller: an edit sent with the secret stores it and answers without it; the
/// port's read and the form read carry none; an edit with the field empty sends no secret write and
/// keeps the stored one.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthRegisteredClientSave.HandleUpdate</method>
/// sends the secret write for an empty field -- the no-secret-write assertion goes red.</p>
Method TestTheSaveStoresTheSecretAndNoReadCarriesIt()
{
    Do $$$AssertStatusOK(..SeedClient(.tClientId), "a client is seeded")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "clientsecret")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", tClientId, {"Description": "with a secret", "ClientSecret": (tSecret)}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the edit with a secret answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and its answer does not carry it")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastBody", "SECRET"), "PUT,SECRET ClientSecret", "the client, then one secret write carrying the secret alone")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretIs", tClientId, tSecret), "the instance stores the secret")
    Set tRead = $ClassMethod(..#PROBE, "Read", tClientId)
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%ToJSON() '[ tSecret) && (tRead.%GetTypeOf("ClientSecret") = "unassigned"), "the port's read carries neither the secret nor its field")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#FORMPATH _ "?clientId=" _ tClientId, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Set tDefinition = ""
    Try { Set tDefinition = ##class(%DynamicObject).%FromJSON(tRaw).%Get("definition") } Catch { Set tDefinition = "" }
    Do $$$AssertEquals((tRaw [ tSecret) _ " " _ $Select($IsObject(tDefinition): tDefinition.%GetTypeOf("ClientSecret"), 1: ""), "0 unassigned", "and carries neither")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", tClientId, {"ClientSecret": "", "Description": "edited"}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "an edit with the field empty answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#PROBE, "Stored", tClientId).%Get("Description"), "PUT edited", "sends no secret write and saves the edit")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretIs", tClientId, tSecret), "and keeps the stored secret")
}

/// <p>A secret write with no secret -- an empty body, an empty value, a null -- is refused by the port
/// with nothing sent, because the vendor stores an empty or null value, which clears the secret; a
/// body carrying a key beside the secret is refused as a caller fault.</p>
Method TestAnEmptySecretIsRefused()
{
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "kept")
    Do $$$AssertStatusOK(..SeedClient(.tClientId, {"ClientSecret": (tSecret)}), "a client with a secret is seeded")
    Set tNull = {}
    Do tNull.%Set("ClientSecret", "", "null")
    For tBody = {}, {"ClientSecret": ""}, tNull {
        Do $ClassMethod(..#RECORD, "Clear")
        Kill tQuery
        Set tQuery("clientId") = tClientId
        Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "SECRET", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "422 OAUTH.SERVERCLIENTNOSECRET", tBody.%ToJSON() _ ": refused naming the missing secret")
    }
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "SECRET", .tQuery, {"ClientSecret": "ocupilotstrayprobe000", "Name": "x"}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 500, "a key beside the secret is refused as a caller fault")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretIs", tClientId, tSecret), "and the stored secret is kept")
}

/// <p>A secret write refused after the client saved: the edit's route answers 200 carrying
/// <code>secretRefused</code>, the refusal's own sentence, and the instance holds the edit.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthRegisteredClientSave.Answer</method>
/// drops <code>secretRefused</code> -- this goes red.</p>
Method TestASecretRefusedAfterTheSaveIsAnswered()
{
    Set tOld = $ClassMethod(..#PROBE, "Secret", "old")
    Do $$$AssertStatusOK(..SeedClient(.tClientId, {"ClientSecret": (tOld)}), "a client is seeded")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "refused")
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "SECRET", 422)
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", tClientId, {"Description": "saved before the refusal", "ClientSecret": (tSecret)}, .tRaw, .tStatus)
    Do $$$AssertStatusOK(tSC, "the edit's route runs")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Extract(tRaw, 1, 300))
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%Get("secretRefused") '= ""), "carrying secretRefused, the refusal's sentence")
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and no secret")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, "SECRET"), 1, "the route's secret write reached the armed port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tClientId).%Get("Description") _ " " _ $ClassMethod(..#PROBE, "SecretIs", tClientId, tOld), "saved before the refusal 1", "and the instance holds the edit and the old secret")
}

/// <p>A secret write refused after a create: the create's route answers 201 carrying the new client id
/// and <code>secretRefused</code>, the refusal's own sentence, and the instance holds the client.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthRegisteredClientSave.HandleCreate</method>
/// passes <code>""</code> as <method>OcuPilot.Area.Security.OAuthRegisteredClientSave.Answer</method>'s
/// last argument -- this goes red.</p>
Method TestASecretRefusedAfterACreateIsAnswered()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tName = $ClassMethod(..#PROBE, "Name", "CreateRefused")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "createrefused")
    Set tBody = $ClassMethod(..#PROBE, "Body", tName)
    Do tBody.%Set("ClientSecret", tSecret, "string")
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "SECRET", 422)
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "POST", "", tBody, .tRaw, .tStatus)
    Do $$$AssertStatusOK(tSC, "the create's route runs")
    Do $$$AssertEquals(tStatus, 201, "and answers 201: " _ $Extract(tRaw, 1, 300))
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Set tId = $ClassMethod(..#PROBE, "IdOf", tName)
    Do $$$AssertTrue((tId '= "") && $IsObject(tAnswer) && (tAnswer.%Get("clientId") = tId), "naming the client the instance holds")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%Get("secretRefused") '= ""), "carrying secretRefused, the refusal's sentence")
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and no secret")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, "SECRET"), "POST,SECRET 1", "the create, then the secret write the armed port refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SecretIs", tId, tSecret), 0, "which stored nothing")
}

/// <p>AC6's secret half: the secret tool refuses a secret the model supplies at the mint, mints one
/// required row empty on both sides, destructive, naming the effect that the client's application must
/// use the new secret; its confirm, supplied the secret, stores it through one secret write; neither the
/// proposal, the ledger row nor the agent marker carries it.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret.DESTRUCTIVE</parameter>
/// 0 and its <code>Consequence</code> answering <code>""</code> -- the treatment assertion goes red.</p>
Method TestTheAgentsSecretIsAskedAtConfirmAndNeverStored()
{
    Do $$$AssertStatusOK(..SeedClient(.tClientId), "a client is seeded")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "agentsecret")
    Set tArgs = {}
    Do tArgs.%Set("ClientId", tClientId, "string")
    Do tArgs.%Set("ClientSecret", tSecret, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tClientId, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "is a secret field"), "a secret from the model is refused at the mint")
    Set tArgs = {}
    Do tArgs.%Set("ClientId", tClientId, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tClientId, tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the secret write is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after")) }
    Do $$$AssertEquals($ListToString(tRows, ","), "ClientSecret||", "one row, empty on both sides")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "1 " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTSERVERCLIENTSECRET, "minted destructive, naming the new secret's effect")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), {"ClientSecret": (tSecret)}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the secret write is confirmed: " _ $Get(tCode))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretIs", tClientId, tSecret), "and the instance stores it")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastBody", "SECRET"), "SECRET ClientSecret", "through one secret write carrying the secret alone")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound) && (($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))) '[ tSecret), "the proposal stores no secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("Fields")) [ tSecret, 0, "which carries no secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "one agent marker names the proposal")
    Do $$$AssertEquals($Get(tData) [ tSecret, 0, "and carries no secret")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>AD-35's fourth declaration: the vendor writes a client's registration access token in plain text
/// into its "Create OAuth2 Server Client" and "Modify OAuth2 Server Client" rows; the audit screen's
/// read over the wire and <code>logs.audit.read</code> each answer those rows with the token masked.</p>
/// <p>Mutation (Rule 19): remove the two server client declarations from
/// <parameter>OcuPilot.Port.AuditPort.VENDORSECRETS</parameter> -- both reads carry the token and this
/// goes red.</p>
Method TestTheAuditReadsMaskTheRegistrationToken()
{
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tToken = $ClassMethod(..#PROBE, "Secret", "audittoken")
    Do $$$AssertStatusOK(..SeedClient(.tClientId, {"Metadata": {"registration_access_token": (tToken)}}), "a client holding a registration access token is seeded")
    Kill tQuery
    Set tQuery("clientId") = tClientId
    Set tSC = ##class(OcuPilot.Port.OAuthRegisteredClientPort).Invoke(..#ENDPOINT, "PUT", .tQuery, {"Description": "audited"}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an edit saves the client again")
    Do $$$AssertTrue($ClassMethod(..#AUDIT, "VendorCarries", tUtcSince, tToken) >= 1, "the vendor's own rows carry the token in plain text")
    Do ..AssertMasked(tSince, "Modify OAuth2 Server Client ", tToken)
    Do ..AssertMasked(tSince, "Create OAuth2 Server Client ", tToken)
}

/// <p>Assert that the audit screen's read over the wire and <code>logs.audit.read</code> each answer a
/// row since <var>pSince</var> under <var>pPrefix</var> whose <code>registration_access_token</code>
/// reads the mask, and that no answered row carries <var>pToken</var>.</p>
Method AssertMasked(pSince As %String, pPrefix As %String, pToken As %String)
{
    Set tPath = ..#AUDITPATH _ "?events=OAuth2&maxRows=200&beginDateTime=" _ $ZConvert(pSince, "O", "URL")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, pPrefix _ ": the audit screen's read answers: " _ $Extract(tRaw, 1, 200))
    Set tScreen = ""
    Try { Set tScreen = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows") } Catch { Set tScreen = "" }
    Do $$$AssertEquals(tRaw [ pToken, 0, pPrefix _ ": the screen's read carries no token")
    Do $$$AssertTrue($ClassMethod(..#AUDIT, "MaskedRows", $Get(tScreen), "", pPrefix, "registration_access_token") > 0, pPrefix _ ": where it was, the token reads the mask")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("logs.audit.read", .tTool)
    Set tArgs = {"events": "OAuth2", "maxRows": 200}
    Do tArgs.%Set("beginDateTime", pSince, "string")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, pPrefix _ ": logs.audit.read answers")
    Set tRows = $Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: "")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") [ pToken, 0, pPrefix _ ": logs.audit.read carries no token")
    Do $$$AssertTrue($ClassMethod(..#AUDIT, "MaskedRows", tRows, "", pPrefix, "registration_access_token") > 0, pPrefix _ ": where it was, the token reads the mask")
}

/// <p>The editor's screen context is identity alone, because its form descriptor declares the secret
/// in <code>context.secretFields</code> (AD-24, AD-35); and a secret write the vendor refuses, which
/// the port logs, writes an OcuPilot line to the instance's messages log that carries neither the
/// stored secret nor the refused one.</p>
/// <p>Mutation (Rule 19): <code>secretFields</code> emptied on
/// <class>OcuPilot.Screen.Descriptor.OAuthServerClientForm</class> -- the context answers the view and
/// this goes red.</p>
Method TestNoContextOrLogLineCarriesTheSecret()
{
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "context")
    Set tContext = {"route": "security/oauth/server-clients/edit", "namespace": "HSCUSTOM", "view": {"rows": [{"ClientSecret": (tSecret)}]}}
    Do tContext.%Set("entity", "someclient", "string")
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
    Do $$$AssertStatusOK(tSC, "the editor's context builds")
    Do $$$AssertTrue(tBuilt, "its route resolves")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", $Get(tPayload)), "entity,namespace,route,screen", "as identity alone")
    If $IsObject($Get(tPayload)) Do $$$AssertEquals(tPayload.%ToJSON() [ tSecret, 0, "and carries no secret")
    Do $$$AssertStatusOK(..SeedClient(.tClientId), "a client is seeded")
    Set tReason = $ClassMethod(..#SCREEN, "StoreSecret", tClientId, tSecret)
    Do $$$AssertEquals(tReason _ " " _ $ClassMethod(..#PROBE, "SecretIs", tClientId, tSecret), " 1", "the secret is stored")
    Set tRefused = $ClassMethod(..#PROBE, "Secret", "logrefused")
    ; A refusal logged in the same second as an identical one before it may not appear in the file.
    Hang 1.1
    Set tBefore = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tSecret, tRefused, .tCarrying)
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "SECRET", 500)
    Set tReason = $ClassMethod(..#SCREEN, "StoreSecret", tClientId, tRefused)
    Do $$$AssertNotEquals(tReason, "", "the next secret write is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, "SECRET"), 1, "by the armed vendor call")
    ; The console log is written asynchronously, so the refusal's line is waited for, briefly.
    For tTry = 1:1:20 {
        Set tAfter = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tSecret, tRefused, .tCarrying)
        If tAfter > tBefore Quit
        Hang 0.5
    }
    Do $$$AssertTrue(tAfter > tBefore, "the refusal wrote an OcuPilot line to messages.log (" _ tBefore _ " before, " _ tAfter _ " after)")
    Do $$$AssertEquals(tCarrying, 0, "and no OcuPilot line there carries either secret")
}

}
