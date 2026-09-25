/// <p>Pins Story 12.7's key password (AD-3, AD-6, AD-35, AD-56): the editor's Save stores it through one
/// password write; no read, form read, screen context, proposal, ledger row, agent marker or OcuPilot
/// log line carries it; an empty field sends nothing and keeps the stored password; a password-only
/// Save sends no configuration write; a password write with no password is refused before the vendor
/// clears the stored one; a vendor 500 on it is named against the stored server credentials; a
/// password refused after the save is answered; the agent's password tool asks for it at the confirm and never stores it; and the
/// vendor's own audit rows, which carry it in plain text, read masked through both audit reads.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture
/// and auditing on, an account holding <code>%All</code>, no authorization server configuration, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration. Every password is synthetic
/// (<method>OcuPilot.Test.OAuthAuthorizationServerProbe.Secret</method>); the audit rows it causes stay
/// in the audit database.</p>
Class OcuPilot.Test.OAuthAuthorizationServerSecret Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerSetPassword";

Parameter SCREEN = "OcuPilot.Test.OAuthAuthorizationServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthAuthorizationServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthAuthorizationServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthAuthorizationServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

/// <p>The audit mask's own test, whose read helpers take any row.</p>
Parameter AUDIT = "OcuPilot.Test.AuditVendorSecrets";

Parameter ENDPOINT = "Security.OAuth2.Server";

Parameter FORMPATH = "/oauth/authorization-server/form";

Parameter AUDITPATH = "/screens/logs.audit/read";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerSecret creates and deletes this instance's OAuth 2.0 authorization server configuration and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK(tSC, "the configuration and every probe object are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Id() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>AC4 on the screen's caller: an edit sent with the password stores it and answers without it;
/// the port's read and the form read carry none; an edit with the field empty sends no password write
/// and keeps the stored one.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthAuthorizationServerSave.HandleUpdate</method>
/// sends the password write for an empty field -- the no-password-write assertion goes red.</p>
Method TestTheSaveStoresThePasswordAndNoReadCarriesIt()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "keypassword")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", {"Description": "with a password", "ServerPassword": (tPassword)}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the edit with a password answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals(tRaw [ tPassword, 0, "and its answer does not carry it")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastBody", "CHANGEPWD"), "PUT,CHANGEPWD ServerPassword", "the configuration, then one password write carrying the password alone")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("PasswordLength"), $Length(tPassword), "the instance stores the password")
    Set tRead = $ClassMethod(..#PROBE, "Read")
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%ToJSON() '[ tPassword) && (tRead.%GetTypeOf("ServerPassword") = "unassigned"), "the port's read carries neither the password nor its field")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#FORMPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Do $$$AssertEquals((tRaw [ tPassword) || (tRaw [ """ServerPassword"""), 0, "and carries neither")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", {"ServerPassword": "", "Description": "edited"}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "an edit with the field empty answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#PROBE, "Stored").%Get("Description"), "PUT edited", "sends no password write and saves the edit")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("PasswordLength"), $Length(tPassword), "and keeps the stored password")
}

/// <p>A Save whose body carries only the password sends no configuration write: the password goes
/// through its own write alone, the instance stores it, and the answer names the issuer (AD-56).</p>
Method TestAPasswordOnlySaveSendsNoConfigurationWrite()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "only")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", {"ServerPassword": (tPassword)}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the password-only Save answers 200: " _ $Extract(tRaw, 1, 300))
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""), "{""issuer"":""" _ $ClassMethod(..#PROBE, "Issuer") _ """}", "naming the issuer and nothing else")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastBody", "CHANGEPWD"), "CHANGEPWD ServerPassword", "through the password write alone")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("PasswordLength") _ " " _ $ClassMethod(..#PROBE, "Stored").%Get("Description"), $Length(tPassword) _ " seeded", "and the instance stores it, the configuration otherwise unchanged")
}

/// <p>A password write the vendor refuses with a 500 is named against the stored server credentials
/// when the configuration has them -- <code>OAUTH.SERVERCREDENTIALS.KEY</code> on
/// <code>ServerCredentials</code> -- and as the configuration refused, with no field, when it has
/// none.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthAuthorizationServerPort.ChangePassword</method>
/// skips the credentials arm -- the second leg goes red.</p>
Method TestAPasswordRefusalIsNamedAgainstTheCredentials()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration without credentials is seeded")
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "CHANGEPWD", 500)
    Kill tQuery
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "CHANGEPWD", .tQuery, {"ServerPassword": ($ClassMethod(..#PROBE, "Secret", "plain"))}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultRow($Get(tFault)), "422 OAUTH.SERVERVALIDATION |", "without credentials the refusal is the configuration's, on no field")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "the configuration is removed")
    Set tAlias = $ClassMethod(..#PROBE, "Name", "Pwd")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddCredential", tAlias, 1), "a credential with a private key is made")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", {"ServerCredentials": (tAlias)}), "and a configuration signing with it")
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "CHANGEPWD", 500)
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "CHANGEPWD", .tQuery, {"ServerPassword": ($ClassMethod(..#PROBE, "Secret", "credentials"))}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultRow($Get(tFault)), "422 OAUTH.SERVERVALIDATION ServerCredentials|OAUTH.SERVERCREDENTIALS.KEY", "with credentials it is named on them")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, "CHANGEPWD"), 2, "both refusals came from the armed vendor call")
}

/// <p>A port fault as <code>&lt;code&gt; &lt;field&gt;|&lt;code&gt;</code> of its first violation row,
/// each empty when absent.</p>
ClassMethod FaultRow(pFault) As %String
{
    If '$IsObject(pFault) Quit " |"
    Set tRow = ""
    If pFault.%GetTypeOf("detail") = "object" {
        Set tRows = pFault.%Get("detail").%Get("violations")
        If $IsObject(tRows) && (tRows.%Size() > 0) Set tRow = tRows.%Get(0)
    }
    Quit pFault.%Get("code") _ " " _ $Select($IsObject(tRow): tRow.%Get("field") _ "|" _ tRow.%Get("code"), 1: "|")
}

/// <p>A password write with no password -- an empty body, an empty value -- is refused by the port
/// with nothing sent, because the vendor stores an empty value, which clears the password.</p>
Method TestAnEmptyPasswordIsRefused()
{
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "kept")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", {"ServerPassword": (tPassword)}), "a configuration with a password is seeded")
    For tBody = {}, {"ServerPassword": ""} {
        Do $ClassMethod(..#RECORD, "Clear")
        Kill tQuery
        Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "CHANGEPWD", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "422 OAUTH.SERVERNOPASSWORD", tBody.%ToJSON() _ ": refused naming the missing password")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("PasswordLength"), $Length(tPassword), "and the stored password is kept")
}

/// <p>A password write refused after the configuration saved: the edit's route answers 200 carrying
/// <code>passwordRefused</code>, the refusal's own sentence, and the instance holds the edit.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthAuthorizationServerSave.Answer</method>
/// drops <code>passwordRefused</code> -- this goes red.</p>
Method TestAPasswordRefusedAfterTheSaveIsAnswered()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "refused")
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "CHANGEPWD", 422)
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", {"Description": "saved before the refusal", "ServerPassword": (tPassword)}, .tRaw, .tStatus)
    Do $$$AssertStatusOK(tSC, "the edit's route runs")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ $Extract(tRaw, 1, 300))
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set tAnswer = "" }
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%Get("passwordRefused") '= ""), "carrying passwordRefused, the refusal's sentence")
    Do $$$AssertEquals(tRaw [ tPassword, 0, "and no password")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, "CHANGEPWD"), 1, "the route's password write reached the armed port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("Description") _ " " _ $ClassMethod(..#PROBE, "Stored").%Get("PasswordLength"), "saved before the refusal 0", "and the instance holds the edit and no password")
}

/// <p>AC7's password half: the password tool refuses a password the model supplies at the mint, mints
/// one required row empty on both sides, stores nothing in the proposal, and its confirm, supplied the
/// password, stores it through one password write; neither the ledger row nor the agent marker
/// carries it.</p>
Method TestTheAgentsPasswordIsAskedAtConfirmAndNeverStored()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "agentpassword")
    Set tArgs = {}
    Do tArgs.%Set("Name", ..Id(), "string")
    Do tArgs.%Set("ServerPassword", tPassword, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "is a secret field"), "a password from the model is refused at the mint")
    Set tArgs = {}
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the password write is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after")) }
    Do $$$AssertEquals($ListToString(tRows, ","), "ServerPassword||", "one row, empty on both sides")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), {"ServerPassword": (tPassword)}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the password write is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("PasswordLength"), $Length(tPassword), "and the instance stores it")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastBody", "CHANGEPWD"), "CHANGEPWD ServerPassword", "through one password write carrying the password alone")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound) && (($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))) '[ tPassword), "the proposal stores no password")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("Fields")) [ tPassword, 0, "which carries no password")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "one agent marker names the proposal")
    Do $$$AssertEquals($Get(tData) [ tPassword, 0, "and carries no password")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>AD-35: the vendor writes the key password in plain text into its "Create OAuth2 Server" and
/// "Modify OAuth2 Server" rows; the audit screen's read over the wire and <code>logs.audit.read</code>
/// each answer both rows with the password masked.</p>
/// <p>Mutation (Rule 19): remove the two authorization server declarations from
/// <parameter>OcuPilot.Port.AuditPort.VENDORSECRETS</parameter> -- both reads carry the password and
/// this goes red.</p>
Method TestTheAuditReadsMaskThePassword()
{
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCreated = $ClassMethod(..#PROBE, "Secret", "auditcreate")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", {"ServerPassword": (tCreated)}), "a configuration with a password is seeded")
    Set tModified = $ClassMethod(..#PROBE, "Secret", "auditmodify")
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.OAuthAuthorizationServerPort).Invoke(..#ENDPOINT, "CHANGEPWD", .tQuery, {"ServerPassword": (tModified)}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the password write stores a new password")
    Do $$$AssertTrue($ClassMethod(..#AUDIT, "VendorCarries", tUtcSince, tCreated) >= 1, "the vendor's own Create row carries the first in plain text")
    Do $$$AssertTrue($ClassMethod(..#AUDIT, "VendorCarries", tUtcSince, tModified) >= 1, "and its Modify row the second")
    For tCase = $ListBuild("Create OAuth2 Server ", tCreated), $ListBuild("Modify OAuth2 Server ", tModified) {
        Do ..AssertMasked(tSince, $List(tCase, 1), $List(tCase, 2))
    }
}

/// <p>Assert that the audit screen's read over the wire and <code>logs.audit.read</code> each answer a
/// row since <var>pSince</var> under <var>pPrefix</var> whose <code>ServerPassword</code> reads the
/// mask, and that no answered row carries <var>pPassword</var>.</p>
Method AssertMasked(pSince As %String, pPrefix As %String, pPassword As %String)
{
    Set tPath = ..#AUDITPATH _ "?events=OAuth2&maxRows=200&beginDateTime=" _ $ZConvert(pSince, "O", "URL")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, pPrefix _ ": the audit screen's read answers: " _ $Extract(tRaw, 1, 200))
    Set tScreen = ""
    Try { Set tScreen = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows") } Catch { Set tScreen = "" }
    Do $$$AssertEquals(tRaw [ pPassword, 0, pPrefix _ ": the screen's read carries no password")
    Do $$$AssertTrue($ClassMethod(..#AUDIT, "MaskedRows", $Get(tScreen), "", pPrefix, "ServerPassword") > 0, pPrefix _ ": where it was, ServerPassword reads the mask")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("logs.audit.read", .tTool)
    Set tArgs = {"events": "OAuth2", "maxRows": 200}
    Do tArgs.%Set("beginDateTime", pSince, "string")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, pPrefix _ ": logs.audit.read answers")
    Set tRows = $Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: "")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") [ pPassword, 0, pPrefix _ ": logs.audit.read carries no password")
    Do $$$AssertTrue($ClassMethod(..#AUDIT, "MaskedRows", tRows, "", pPrefix, "ServerPassword") > 0, pPrefix _ ": where it was, ServerPassword reads the mask")
}

/// <p>The editor's screen context is identity alone, because its form descriptor declares the password
/// in <code>context.secretFields</code> (AD-24, AD-35); and a password write the vendor refuses, which
/// the port logs, writes an OcuPilot line to the instance's messages log that carries neither the
/// stored password nor the refused one.</p>
/// <p>Mutation (Rule 19): <code>secretFields</code> emptied on
/// <class>OcuPilot.Screen.Descriptor.OAuthServerForm</class> -- the context answers the view and this
/// goes red.</p>
Method TestNoContextOrLogLineCarriesThePassword()
{
    Set tPassword = $ClassMethod(..#PROBE, "Secret", "context")
    Set tContext = {"route": "security/oauth/server/edit", "namespace": "HSCUSTOM", "view": {"rows": [{"ServerPassword": (tPassword)}]}}
    Do tContext.%Set("entity", ..Id(), "string")
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
    Do $$$AssertStatusOK(tSC, "the editor's context builds")
    Do $$$AssertTrue(tBuilt, "its route resolves")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", $Get(tPayload)), "entity,namespace,route,screen", "as identity alone")
    If $IsObject($Get(tPayload)) Do $$$AssertEquals(tPayload.%ToJSON() [ tPassword, 0, "and carries no password")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tReason = $ClassMethod(..#SCREEN, "StorePassword", tPassword)
    Do $$$AssertEquals(tReason _ " " _ $ClassMethod(..#PROBE, "Stored").%Get("PasswordLength"), " " _ $Length(tPassword), "the password is stored")

    ; A refused password write logs its fault with the password in flight.
    Set tRefused = $ClassMethod(..#PROBE, "Secret", "logrefused")
    ; A refusal logged in the same second as an identical one before it may not appear in the file.
    Hang 1.1
    Set tBefore = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tPassword, tRefused, .tCarrying)
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "CHANGEPWD", 500)
    Set tReason = $ClassMethod(..#SCREEN, "StorePassword", tRefused)
    Do $$$AssertNotEquals(tReason, "", "the next password write is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, "CHANGEPWD"), 1, "by the armed vendor call")
    ; The console log is written asynchronously, so the refusal's line is waited for, briefly.
    For tTry = 1:1:20 {
        Set tAfter = ##class(OcuPilot.Test.OAuthServerToken).LogLines(tPassword, tRefused, .tCarrying)
        If tAfter > tBefore Quit
        Hang 0.5
    }
    Do $$$AssertTrue(tAfter > tBefore, "the refusal wrote an OcuPilot line to messages.log (" _ tBefore _ " before, " _ tAfter _ " after)")
    Do $$$AssertEquals(tCarrying, 0, "and no OcuPilot line there carries either password")
}

}
