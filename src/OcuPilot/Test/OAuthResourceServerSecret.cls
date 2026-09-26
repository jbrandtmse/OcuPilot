/// <p>Pins Story 12.6's client secret (AD-3, AD-6, AD-35, AD-56): the editor's Save stores it through
/// one secret write; no read, form read, screen context, proposal, ledger row, agent marker or OcuPilot
/// log line carries it; an empty field sends nothing and keeps the stored secret; a secret write with
/// no secret is refused before the vendor clears the stored one; a secret write refused after the save
/// is answered; and the agent's secret tool asks for it at the confirm and never stores it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes OAuth 2.0 resource servers and server descriptions.
/// Every secret is synthetic (<method>OcuPilot.Test.OAuthResourceServerProbe.Secret</method>).</p>
Class OcuPilot.Test.OAuthResourceServerSecret Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthResourceServerSetSecret";

Parameter SCREEN = "OcuPilot.Test.OAuthResourceServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthResourceServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthResourceServerRecordPort";

Parameter FAILPORT = "OcuPilot.Test.OAuthResourceServerFailPort";

Parameter FAILSAVE = "OcuPilot.Test.OAuthResourceServerFailSave";

Parameter PROBE = "OcuPilot.Test.OAuthResourceServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.ResourceServer";

Parameter CREATEPATH = "/oauth/resource-server";

Parameter FORMPATH = "/oauth/resource-server/form";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerSecret creates and deletes OAuth 2.0 resource servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "AddServer", ..Issuer())
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

ClassMethod Issuer() As %String
{
    Quit $ClassMethod(..#PROBE, "Issuer", "secret")
}

/// <p>Make server <var>pName</var> with one audience.</p>
ClassMethod MakeServer(pName As %String, pSettings As %DynamicObject = "") As %Status
{
    Quit $ClassMethod(..#PROBE, "AddResource", pName, ..Issuer(), $ListBuild("aud.secret"), pSettings)
}

/// <p>A request over the wire as the test account, answering the status and the raw body.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
}

/// <p>AC4 on the screen's caller: a create sent with the client secret stores it and answers without
/// it, its read-back naming the secret written; the port's read and the form read carry none; an edit with the field empty sends no secret
/// write and keeps the stored one.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthResourceServerSave.HandleUpdate</method>
/// sends the secret write for an empty field -- the no-secret-write assertion goes red.</p>
Method TestTheSaveStoresTheSecretAndNoReadCarriesIt()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Secret")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "clientsecret")
    Set tBody = {"Audiences": ["aud.secret"], "ClientId": "probe-client", "AlwaysCallIntrospection": true}
    Do tBody.%Set("Name", tName, "string")
    Do tBody.%Set("IssuerEndpoint", ..Issuer(), "string")
    Do tBody.%Set("ClientSecret", tSecret, "string")
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 201, "the create with a secret answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and its answer does not carry it")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Set tReadBack = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("readBack") = "object"): tAnswer.%Get("readBack"), 1: {})
    Do $$$AssertEquals(tReadBack.%Get("verdict") _ " " _ $Select(tReadBack.%GetTypeOf("written") = "array": tReadBack.%Get("written").%ToJSON(), 1: ""), "matches [""ClientSecret""]", "its read-back holds what was sent and names the secret stored apart as written (AD-58): " _ tReadBack.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), $Length(tSecret), "the instance stores the secret")
    Set tRead = $ClassMethod(..#PROBE, "Read", tName)
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%ToJSON() '[ tSecret) && (tRead.%GetTypeOf("ClientSecret") = "unassigned"), "the port's read carries neither the secret nor its field")
    Set tSC = ..Request("GET", ..#FORMPATH _ "?name=" _ $ZConvert(tName, "O", "URL"), "", .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and carries no secret")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#FAILSAVE, "Handle", tName, {"ClientSecret": "", "Description": "edited"}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "an edit with the field empty answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "PUT edited", "sends no secret write and saves the edit")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), $Length(tSecret), "and keeps the stored secret")
}

/// <p>A secret write with no secret -- an empty body, an empty value -- is refused by the port with
/// nothing sent, because the vendor stores an empty value as the secret.</p>
Method TestAnEmptySecretIsRefused()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "NoSecret")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "kept")
    Do $$$AssertStatusOK(..MakeServer(tName, {"ClientSecret": (tSecret)}), "a server with a secret is created")
    Kill tQuery
    Set tQuery("name") = tName
    For tBody = {}, {"ClientSecret": ""} {
        Do $ClassMethod(..#FAILPORT, "Disarm")
        Set tSC = $ClassMethod(..#FAILPORT, "Invoke", ..#ENDPOINT, "CHANGESECRET", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "422 OAUTH.RESOURCESERVERNOSECRET", tBody.%ToJSON() _ ": refused naming the missing secret")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), $Length(tSecret), "and the stored secret is kept")
}

/// <p>A secret write refused after the server saved: the edit's route answers 200 carrying
/// <code>secretRefused</code>, the refusal's own sentence, and the instance holds the edit.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthResourceServerSave.Answer</method> drops
/// <code>secretRefused</code> -- this goes red.</p>
Method TestASecretRefusedAfterTheSaveIsAnswered()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Refused")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "refused")
    Do $ClassMethod(..#FAILPORT, "Arm", ..#ENDPOINT, "CHANGESECRET", 422)
    Set tSC = $ClassMethod(..#FAILSAVE, "Handle", tName, {"Description": "saved before the refusal", "ClientSecret": (tSecret)}, .tRaw, .tStatus)
    Do $$$AssertStatusOK(tSC, "the edit's route runs")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Extract(tRaw, 1, 300))
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%Get("secretRefused") '= ""), "carrying secretRefused, the refusal's sentence")
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and no secret")
    Do $$$AssertEquals($ClassMethod(..#FAILPORT, "Reached", ..#ENDPOINT, "CHANGESECRET"), 1, "the route's secret write reached the armed port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description") _ " " _ $ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), "saved before the refusal 0", "and the instance holds the edit and no secret")
}

/// <p>AC7's secret half: the secret tool refuses a secret the model supplies at the mint, mints one
/// required row empty on both sides, stores nothing in the proposal, and its confirm, supplied the
/// secret, stores it through one secret write; neither the ledger row nor the agent marker carries
/// it.</p>
Method TestTheAgentsSecretIsAskedAtConfirmAndNeverStored()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Agent")
    Do $$$AssertStatusOK(..MakeServer(tName, {"ClientId": "probe-client"}), "a server is created")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "agentsecret")
    Set tArgs = {}
    Do tArgs.%Set("Name", tName, "string")
    Do tArgs.%Set("ClientSecret", tSecret, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "is a secret field"), "a secret from the model is refused at the mint")
    Set tArgs = {}
    Do tArgs.%Set("Name", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the secret write is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after") _ "|" _ tRow.%Get("optional")) }
    Do $$$AssertEquals($ListToString(tRows, ","), "ClientSecret|||", "one required row, empty on both sides")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), {"ClientSecret": (tSecret)}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the secret write is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), $Length(tSecret), "and the instance stores it")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastBody", "CHANGESECRET"), "CHANGESECRET ClientSecret", "through one secret write carrying the secret alone")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound) && (($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))) '[ tSecret), "the proposal stores no secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("Fields")) [ tSecret, 0, "which carries no secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "one agent marker names the proposal")
    Do $$$AssertEquals($Get(tData) [ tSecret, 0, "and carries no secret")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>The editor's screen context is identity alone, because its form descriptor declares the secret
/// in <code>context.secretFields</code> (AD-24, AD-35). No OcuPilot line in the instance's messages log
/// carries a secret this class stored or one whose write the instance refused, and the refusal did
/// write a line there.</p>
/// <p>Mutation (Rule 19): <code>secretFields</code> emptied on
/// <class>OcuPilot.Screen.Descriptor.OAuthResourceServerForm</class> -- the context answers the view
/// and this goes red.</p>
Method TestNoContextOrLogLineCarriesASecret()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Context")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "context")
    Set tContext = {"route": "security/oauth/resource-servers/edit", "namespace": "HSCUSTOM", "view": {"rows": [{"ClientSecret": (tSecret)}]}}
    Do tContext.%Set("entity", tName, "string")
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
    Do $$$AssertStatusOK(tSC, "the editor's context builds")
    Do $$$AssertTrue(tBuilt, "its route resolves")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", $Get(tPayload)), "entity,namespace,route,screen", "as identity alone")
    If $IsObject($Get(tPayload)) Do $$$AssertEquals(tPayload.%ToJSON() [ tSecret, 0, "and carries no secret")
    Do $$$AssertStatusOK(..MakeServer(tName), "a server is created")
    Set tReason = $ClassMethod(..#SCREEN, "StoreSecret", tName, tSecret)
    Do $$$AssertEquals(tReason _ " " _ $ClassMethod(..#PROBE, "Stored", tName).%Get("SecretLength"), " " _ $Length(tSecret), "the secret is stored")
    Set tRefused = $ClassMethod(..#PROBE, "Secret", "logrefused")
    Hang 1.1
    Set tBefore = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tSecret, tRefused, .tCarrying)
    ; A server the instance does not hold refuses the secret write, which the port logs.
    Set tReason = $ClassMethod(..#SCREEN, "StoreSecret", $ClassMethod(..#PROBE, "Name", "Missing"), tRefused)
    Do $$$AssertNotEquals(tReason, "", "a secret write to a server the instance does not hold is refused")
    For tTry = 1:1:20 {
        Set tAfter = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tSecret, tRefused, .tCarrying)
        If tAfter > tBefore Quit
        Hang 0.5
    }
    Do $$$AssertTrue(tAfter > tBefore, "the refusal wrote an OcuPilot line to messages.log (" _ tBefore _ " before, " _ tAfter _ " after)")
    Do $$$AssertEquals(tCarrying, 0, "and no OcuPilot line there carries either secret")
}

}
