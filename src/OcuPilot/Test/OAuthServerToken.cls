/// <p>Pins Story 12.4's registration access token (AD-3, AD-6, AD-35, AD-56): the editor's Save
/// stores a token sent beside the description, with a body of exactly <code>{InitialAccessToken}</code>
/// and an empty field sending nothing; no read, form read, screen context, proposal, ledger row or
/// OcuPilot log line carries it; the agent's token tool asks for it at the confirm and never stores
/// it; and a token the instance refuses is answered beside the saved description.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo
/// fixture, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes OAuth 2.0 server descriptions. Every token is
/// synthetic (<method>Token</method>).</p>
Class OcuPilot.Test.OAuthServerToken Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionSetToken";

Parameter SCREEN = "OcuPilot.Test.OAuthServerSaveFixture";

Parameter RECORD = "OcuPilot.Test.OAuthServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.Client.ServerDefinition";

Parameter CREATEPATH = "/oauth/server-description";

Parameter FORMPATH = "/oauth/server-description/form";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerToken creates and deletes OAuth 2.0 server descriptions on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK(tSC, "every probe description is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>A synthetic token unique to this call, shaped like no real key.</p>
ClassMethod Token(pTag As %String) As %String
{
    Quit "ocupilot" _ pTag _ "probe000" _ $Job _ $Translate($Piece($ZTimeStamp, ",", 2), ".", "")
}

/// <p>A request over the wire as the test account, answering the status and the raw body.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
}

/// <p>AC6 on the screen's caller: a create sent with a token stores it -- through the token type,
/// with a body of exactly <code>{InitialAccessToken}</code> -- and answers without it; the admin API's
/// read and the form read never carry it; an edit with the field empty sends no token write and keeps
/// the stored one.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthServerRules.HandleForm</method> adds the
/// stored token to its answer -- the form-read assertion goes red.</p>
Method TestTheSaveStoresTheTokenAndNoReadCarriesIt()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Token")
    Set tToken = ..Token("save")
    Set tBody = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tBody.%Set("IssuerEndpoint", tIssuer, "string")
    Do tBody.%Set("Metadata", $ClassMethod(..#PROBE, "Metadata", tIssuer))
    Do tBody.%Set("InitialAccessToken", tToken, "string")
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 201, "the create with a token answers 201")
    Do $$$AssertEquals(tRaw [ tToken, 0, "and its answer does not carry the token")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("TokenLength"), $Length(tToken), "the instance stores the token")

    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(tRead)) && '(tRead.%ToJSON() [ tToken) && (tRead.%GetTypeOf("InitialAccessToken") = "unassigned"), "the admin API's read does not carry it")
    Set tSC = ..Request("GET", ..#FORMPATH _ "?issuer=" _ $ZConvert(tIssuer, "O", "URL"), "", .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Do $$$AssertTrue('(tRaw [ tToken) && '(tRaw [ "InitialAccessToken"), "and does not carry it")

    Set tSC = $ClassMethod(..#SCREEN, "StoreToken", tIssuer, ..Token("second"))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "TOKEN InitialAccessToken", "a token write sends the token type with a body of exactly {InitialAccessToken}")
    Set tStoredLength = $ClassMethod(..#PROBE, "Stored", tIssuer).%Get("TokenLength")
    Set tSC = ..Request("PUT", ..#CREATEPATH _ "/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tIssuer), {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG")), "InitialAccessToken": ""}, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "an edit with the token field empty answers 200")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("TokenLength"), tStoredLength, "and keeps the stored token")
}

/// <p>AC6 on the agent's caller: the token tool refuses a token the model supplies at the mint, mints
/// a proposal whose one row names the token with no value on either side, stores nothing in the
/// proposal, and its confirm, supplied the token, stores it; neither the ledger row nor the agent
/// marker carries it.</p>
Method TestTheAgentsTokenIsAskedAtConfirmAndNeverStored()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "AgentToken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Set tToken = ..Token("agent")
    Set tArgs = {}
    Do tArgs.%Set("IssuerEndpoint", tIssuer, "string")
    Do tArgs.%Set("InitialAccessToken", tToken, "string")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#PROBE, "Problem", $Get(tFault)) [ "is a secret field"), "a token from the model is refused at the mint")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, {"IssuerEndpoint": (tIssuer)}, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the token write is minted: " _ $ClassMethod(..#PROBE, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after"), 1: ""), "InitialAccessToken||", "one row naming the token, empty on both sides")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.OAuthServerConfirm).Confirm(tProposal.%Get("proposalId"), {"InitialAccessToken": (tToken)}, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the token write is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("TokenLength"), $Length(tToken), "and the instance stores the token")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "TOKEN InitialAccessToken", "through the token type, with a body of exactly {InitialAccessToken}")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Set tStored = $Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))
    Do $$$AssertTrue($Get(tFound) && '(tStored [ tToken), "the proposal stores no token")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("Fields")) [ tToken, 0, "which does not carry the token")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "one agent marker names the proposal")
    Do $$$AssertEquals($Get(tData) [ tToken, 0, "and does not carry the token")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>The editor's screen context is identity alone, because its form descriptor declares the token
/// in <code>context.secretFields</code>: a view carrying a typed token answers the screen, route,
/// namespace and entity and nothing else (AD-24, AD-35). No OcuPilot line in the instance's messages
/// log carries a token this class stored or one whose write the instance refused, and the refusal
/// did write a line there.</p>
/// <p>Mutation (Rule 19): <code>secretFields</code> emptied on
/// <class>OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm</class> -- the context answers the
/// view's sort, filter and rows and this goes red.</p>
Method TestNoContextOrLogLineCarriesTheToken()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Context")
    Set tToken = ..Token("context")
    Set tContext = {"route": "security/oauth/edit", "namespace": "HSCUSTOM", "view": {"rows": [{"InitialAccessToken": (tToken)}]}}
    Do tContext.%Set("entity", tIssuer, "string")
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
    Do $$$AssertStatusOK(tSC, "the editor's context builds")
    Do $$$AssertTrue(tBuilt, "its route resolves")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Keys", $Get(tPayload)), "entity,namespace,route,screen", "as identity alone")
    If $IsObject($Get(tPayload)) Do $$$AssertEquals(tPayload.%ToJSON() [ tToken, 0, "and carries no token")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Set tSC = $ClassMethod(..#SCREEN, "StoreToken", tIssuer, tToken)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("TokenLength"), $Length(tToken), "the token is stored")

    ; A description that no longer validates refuses the next token write, which the port logs.
    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke(..#ENDPOINT, "PUT", .tQuery, {"Metadata": {"token_endpoint": ""}}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the vendor stores a definition with its token endpoint cleared")
    Set tRefusedToken = ..Token("logrefused")
    ; Measured: a refusal logged in the same second as an identical one before it did not appear in
    ; the file, so the next second is waited for.
    Hang 1.1
    Set tBefore = ..LogLines(tToken, tRefusedToken, .tCarrying)
    Set tReason = $ClassMethod(..#SCREEN, "StoreToken", tIssuer, tRefusedToken)
    Do $$$AssertNotEquals(tReason, "", "the next token write is refused")
    ; The console log is written asynchronously, so the refusal's line is waited for, briefly.
    For tTry = 1:1:20 {
        Set tAfter = ..LogLines(tToken, tRefusedToken, .tCarrying)
        If tAfter > tBefore Quit
        Hang 0.5
    }
    Do $$$AssertTrue(tAfter > tBefore, "the refusal wrote an OcuPilot line to messages.log (" _ tBefore _ " before, " _ tAfter _ " after)")
    Do $$$AssertEquals(tCarrying, 0, "and no OcuPilot line there carries either token")
}

/// <p>How many OcuPilot lines the instance's messages log holds, with <var>pCarrying</var> 1 when
/// any of them carries <var>pFirst</var> or <var>pSecond</var>.</p>
ClassMethod LogLines(pFirst As %String, pSecond As %String, Output pCarrying As %Boolean) As %Integer
{
    Set pCarrying = 0
    Set tCount = 0
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If $$$ISOK(tStream.LinkToFile($System.Util.ManagerDirectory() _ "messages.log")) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If tLine '[ "OcuPilot" Continue
            Set tCount = tCount + 1
            If (tLine [ pFirst) || (tLine [ pSecond) Set pCarrying = 1
        }
    }
    Set tStream = ""
    Quit tCount
}

/// <p>A token the instance refuses after the description is saved is answered as the refusal's
/// sentence, which the editor shows beside "Saved": the vendor's token write fails on a description
/// that no longer validates.</p>
Method TestARefusedTokenIsAnsweredBesideTheSavedDescription()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Refused")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke(..#ENDPOINT, "PUT", .tQuery, {"Metadata": {"token_endpoint": ""}}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the vendor stores a definition with its token endpoint cleared")
    Set tReason = $ClassMethod(..#SCREEN, "StoreToken", tIssuer, ..Token("refused"))
    Do $$$AssertNotEquals(tReason, "", "the token write is refused with a sentence")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("TokenLength"), 0, "and nothing is stored")
}

}
