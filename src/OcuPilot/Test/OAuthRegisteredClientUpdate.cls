/// <p>Pins Story 12.8's server client edit (AD-4, AD-39, AD-55): an edit sends the complete property set
/// -- every template field, the redirect URLs whole, and every metadata member as read with the changed
/// ones applied -- and never a secret member, so the stored ones survive; the card shows what the write
/// sends; the port refuses a body carrying a secret before the vendor; every bad value refuses an edit
/// on both callers; the vendor's own refusals are named; and an edit of a client the instance does not
/// hold is 404 by name with nothing sent.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%All</code>, no authorization server configuration and no registered client, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and clients (<class>OcuPilot.Test.OAuthRegisteredClientProbe</class>).</p>
Class OcuPilot.Test.OAuthRegisteredClientUpdate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientUpdate";

Parameter SCREEN = "OcuPilot.Test.OAuthRegisteredClientSaveFixture";

Parameter RECORD = "OcuPilot.Test.OAuthRegisteredClientRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthRegisteredClientProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.ServerClients";

Parameter FORMPATH = "/oauth/server-client/form";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthRegisteredClientUpdate creates and deletes this instance's OAuth 2.0 authorization server configuration and clients and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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

/// <p>A client seeded with two redirect URLs and display metadata, holding a registration access token
/// and a metadata client secret, its id in <var>pClientId</var>.</p>
Method SeedFull(Output pClientId As %String, pToken As %String) As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Seed")
    If $$$ISERR(tSC) Quit tSC
    Set tSettings = {"Description": "seeded", "Metadata": {"client_name": "Seeded client", "logo_uri": "https://app.ocupilotprobe128.invalid/logo.png", "contacts": ["ops@ocupilotprobe128.invalid"], "default_max_age": 300}}
    Do tSettings.%Set("RedirectURL", [($ClassMethod(..#PROBE, "Url", "one")), ($ClassMethod(..#PROBE, "Url", "two"))])
    Do tSettings.%Get("Metadata").%Set("registration_access_token", pToken, "string")
    Do tSettings.%Get("Metadata").%Set("client_secret", pToken _ "meta", "string")
    Quit $ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Full"), .pClientId, tSettings)
}

/// <p>AC2, AD-4: an edit that removes one redirect URL, adds one, and changes the description and a
/// Client Information member sends one <code>PUT</code> carrying every template field, the redirect
/// URLs as edited and every metadata member as read with the change applied, and no secret member; the
/// instance then holds exactly that, every other member as before, and both secret members kept.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthRegisteredClientRules.MergedMetadata</method>
/// starts from <code>{}</code> rather than the fresh read's metadata -- the sent body lacks the members
/// the edit did not name and this goes red.</p>
Method TestAnEditSendsTheCompleteSet()
{
    Set tToken = $ClassMethod(..#PROBE, "Secret", "token")
    Do $$$AssertStatusOK(..SeedFull(.tClientId, tToken), "a client is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tClientId)
    Set tBody = {"Description": "edited", "Metadata": {"client_name": "Edited client"}}
    Do tBody.%Set("RedirectURL", [($ClassMethod(..#PROBE, "Url", "two")), ($ClassMethod(..#PROBE, "Url", "three"))])
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", tClientId, tBody, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes"), "PUT", "through one PUT")
    Set tSent = ""
    Try { Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastBody", "PUT")) } Catch { Set tSent = "" }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSent), "ClientCredentials,ClientType,DefaultScope,Description,LaunchURL,Metadata,Name,RedirectURL", "carrying every template field")
    If '$IsObject(tSent) Quit
    Set tMetadata = tSent.%Get("Metadata")
    Do $$$AssertEquals(tMetadata.%Get("client_name") _ "|" _ tMetadata.%Get("logo_uri") _ "|" _ tMetadata.%Get("contacts").%ToJSON() _ "|" _ tMetadata.%Get("default_max_age"), "Edited client|https://app.ocupilotprobe128.invalid/logo.png|[""ops@ocupilotprobe128.invalid""]|300", "every member as read, the change applied")
    Do $$$AssertEquals(tMetadata.%GetTypeOf("registration_access_token") _ " " _ tMetadata.%GetTypeOf("client_secret") _ " " _ ($ClassMethod(..#RECORD, "LastBody", "PUT") [ tToken), "unassigned unassigned 0", "and no secret member")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tClientId)
    Do $$$AssertEquals(tAfter.%Get("Description") _ "|" _ tAfter.%Get("RedirectURL") _ "|" _ tAfter.%Get("Metadata").%Get("client_name"), "edited|" _ $ClassMethod(..#PROBE, "Url", "two") _ "," _ $ClassMethod(..#PROBE, "Url", "three") _ "|Edited client", "the instance holds exactly the edit")
    Do tBefore.%Get("Metadata").%Set("client_name", "Edited client", "string")
    Do $$$AssertEquals(tAfter.%Get("Metadata").%ToJSON(), tBefore.%Get("Metadata").%ToJSON(), "every other member as before")
    Do $$$AssertEquals(tAfter.%Get("RegistrationTokenLength") _ " " _ tAfter.%Get("ClientSecretLength") _ " " _ tAfter.%Get("SecretLength"), tBefore.%Get("RegistrationTokenLength") _ " " _ tBefore.%Get("ClientSecretLength") _ " " _ tBefore.%Get("SecretLength"), "and the secret members and the secret survive")
}

/// <p>The port's read and the form read answer neither secret member, and an edit that changes nothing
/// sends nothing.</p>
Method TestNoReadAnswersASecretMember()
{
    Set tToken = $ClassMethod(..#PROBE, "Secret", "readtoken")
    Do $$$AssertStatusOK(..SeedFull(.tClientId, tToken), "a client holding both secret members is seeded")
    Set tRead = $ClassMethod(..#PROBE, "Read", tClientId)
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%Get("Metadata").%GetTypeOf("registration_access_token") = "unassigned") && (tRead.%Get("Metadata").%GetTypeOf("client_secret") = "unassigned") && (tRead.%ToJSON() '[ tToken), "the port's read strips both")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#FORMPATH _ "?clientId=" _ tClientId, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Do $$$AssertEquals((tRaw [ tToken) || (tRaw [ "registration_access_token") || (tRaw [ """client_secret"""), 0, "and carries neither")
    Do $$$AssertTrue(tRaw [ ("""clientId"":""" _ tClientId _ """"), "naming the client")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", tClientId, {"Description": "seeded"}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#RECORD, "WriteCount"), "200 0", "an edit restating the stored value sends nothing")
}

/// <p>The agent's edit card draws the redirect URLs as URLs and the metadata as one row per member it
/// changes, and its payload is the complete set with no secret member.</p>
Method TestTheCardShowsWhatTheWriteSends()
{
    Set tToken = $ClassMethod(..#PROBE, "Secret", "card")
    Do $$$AssertStatusOK(..SeedFull(.tClientId, tToken), "a client is seeded")
    Set tArgs = {"Metadata": {"client_name": "Carded"}}
    Do tArgs.%Set("ClientId", tClientId, "string")
    Do tArgs.%Set("RedirectURL", [($ClassMethod(..#PROBE, "Url", "one"))])
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tClientId, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "=" _ tRow.%Get("before") _ ">" _ tRow.%Get("after")) }
    Do $$$AssertEquals($ListToString(tRows, "|"), "RedirectURL=" _ $ClassMethod(..#PROBE, "Url", "one") _ ", " _ $ClassMethod(..#PROBE, "Url", "two") _ ">" _ $ClassMethod(..#PROBE, "Url", "one") _ "|Metadata.client_name=Seeded client>Carded", "the URLs and the one changed member")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound) && ($Get(tValues("payload")) [ """logo_uri""") && ($Get(tValues("payload")) '[ tToken) && ($Get(tValues("payload")) '[ "registration_access_token"), "the stored payload is the complete set with no secret member")
}

/// <p>Matrix row "Edit, bad value": no redirect URL, a relative one, a logo on another host and a grant
/// type outside the list each refuse an edit on both callers, on the field, with nothing sent.</p>
Method TestEveryBadValueRefusesAnEditOnBothCallers()
{
    Set tToken = $ClassMethod(..#PROBE, "Secret", "bad")
    Do $$$AssertStatusOK(..SeedFull(.tClientId, tToken), "a client is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tClientId).%ToJSON()
    Set tCase($Increment(tCase)) = $ListBuild("RedirectURL", "OAUTH.REDIRECTURL.REQUIRED"), tPatch(tCase) = {"RedirectURL": []}
    Set tCase($Increment(tCase)) = $ListBuild("RedirectURL", "OAUTH.REDIRECTURL.SHAPE"), tPatch(tCase) = {"RedirectURL": ["cb"]}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.logo_uri", "OAUTH.CLIENTURL.HOST"), tPatch(tCase) = {"Metadata": {"logo_uri": ("https://" _ $Parameter(..#PROBE, "OTHERHOST") _ "/logo.png")}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.logo_uri", "OAUTH.CLIENTURL.HOST"), tPatch(tCase) = {"RedirectURL": [("https://" _ $Parameter(..#PROBE, "OTHERHOST") _ "/cb")]}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.grant_types", "OAUTH.CLIENTGRANTTYPES.VALUE"), tPatch(tCase) = {"Metadata": {"grant_types": ["urn:bogus"]}}
    For tI = 1:1:tCase {
        Set tField = $List(tCase(tI), 1)
        Set tCode = $List(tCase(tI), 2)
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", tClientId, tPatch(tI), .tHttp, .tFault, .tViolations, .tName)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, tField), tCode, "case " _ tI _ ": the Save refuses " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing")
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(tPatch(tI).%ToJSON())
        Do tArgs.%Set("ClientId", tClientId, "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tClientId, tArgs, .tProposal, .tHttp, .tFault)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ("'" _ tField _ "': " _ tReason)), "case " _ tI _ ": and the agent's mint refuses it with the field's sentence: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tClientId).%ToJSON(), tBefore, "and the client is unchanged")
}

/// <p>Matrix row "Edit, bad value", the client type changed: a resource server with no redirect URL
/// made confidential is refused on <code>RedirectURL</code> on both callers, with nothing sent.</p>
/// <p>Mutation (Rule 19): drop <code>|| tTypeChanged</code> from the redirect URL rule in
/// <method>OcuPilot.Area.Security.OAuthRegisteredClientRules.Validate</method> -- the edit passes the
/// rules and this goes red.</p>
Method TestAChangedClientTypeIsHeldToItsRules()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Type"), .tClientId, {"ClientType": "resource", "RedirectURL": []}), "a resource server with no redirect URL is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tClientId).%ToJSON()
    Set tSC = $ClassMethod(..#SCREEN, "Update", tClientId, {"ClientType": "confidential"}, .tHttp, .tFault, .tViolations, .tName)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "RedirectURL"), "OAUTH.REDIRECTURL.REQUIRED", "the Save refuses the missing redirect URL")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Set tArgs = {"ClientType": "confidential"}
    Do tArgs.%Set("ClientId", tClientId, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tClientId, tArgs, .tProposal, .tHttp, .tFault)
    Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation("OAUTH.REDIRECTURL.REQUIRED")
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ("'RedirectURL': " _ tReason)), "and the agent's mint refuses it with the field's sentence: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tClientId).%ToJSON(), tBefore, "and the client is unchanged")
}

/// <p>The vendor's own refusals are named: a grant type the authorization server does not support on
/// <code>Metadata.grant_types</code>, a credential the instance does not hold on
/// <code>ClientCredentials</code>, and any other 500 as the client refused, on no field.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthRegisteredClientPort.SendWrite</method> answers the
/// vendor's status unnamed -- the rows go and this goes red.</p>
Method TestAVendorRefusalIsNamed()
{
    Set tToken = $ClassMethod(..#PROBE, "Secret", "vendor")
    Do $$$AssertStatusOK(..SeedFull(.tClientId, tToken), "a client is seeded")
    Kill tQuery
    Set tQuery("clientId") = tClientId
    Set tFresh = $ClassMethod(..#PROBE, "Read", tClientId)
    Do tFresh.%Get("Metadata").%Set("grant_types", ["password", "refresh_token"])
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "PUT", .tQuery, tFresh, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultRow($Get(tFault)), "422 OAUTH.SERVERCLIENTVALIDATION Metadata.grant_types|OAUTH.CLIENTGRANTTYPES.UNSUPPORTED", "an unsupported grant type is named on the grant types")
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "PUT", .tQuery, {"ClientCredentials": "OcuPilotNoSuchCredential128"}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultRow($Get(tFault)), "422 OAUTH.SERVERCLIENTVALIDATION ClientCredentials|OAUTH.SERVERCLIENTCREDENTIALS.ABSENT", "an unknown credential is named on the credentials")
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "PUT", 500)
    Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "PUT", .tQuery, {"Description": "refused"}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultRow($Get(tFault)), "422 OAUTH.SERVERCLIENTVALIDATION |", "and any other refusal is the client refused, on no field")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tClientId).%Get("Description"), "seeded", "and nothing is stored")
}

/// <p>The port refuses a <code>PUT</code> or <code>POST</code> body carrying the secret or a secret
/// metadata member as a caller fault before the vendor, and the stored secret members survive.</p>
/// <p>Mutation (Rule 19): delete <method>OcuPilot.Port.OAuthRegisteredClientPort.SendWrite</method>'s
/// <code>If ..CarriesSecret(pBody) {...}</code> block -- the bodies reach the armed vendor call and this
/// goes red.</p>
Method TestABodyCarryingASecretIsRefused()
{
    Set tToken = $ClassMethod(..#PROBE, "Secret", "carried")
    Do $$$AssertStatusOK(..SeedFull(.tClientId, tToken), "a client is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tClientId)
    Set tCarried = $ClassMethod(..#PROBE, "Secret", "sent")
    Set tBodies($Increment(tBodies)) = $ListBuild("PUT", "Metadata.client_secret"), tBody(tBodies) = {"Metadata": {"client_secret": (tCarried)}}
    Set tBodies($Increment(tBodies)) = $ListBuild("PUT", "Metadata.registration_access_token"), tBody(tBodies) = {"Metadata": {"registration_access_token": (tCarried)}}
    Set tBodies($Increment(tBodies)) = $ListBuild("POST", "ClientSecret"), tBody(tBodies) = $ClassMethod(..#PROBE, "Body", $ClassMethod(..#PROBE, "Name", "Carried"))
    Do tBody(tBodies).%Set("ClientSecret", tCarried, "string")
    Kill tQuery
    Set tQuery("clientId") = tClientId
    For tI = 1:1:tBodies {
        Set tType = $List(tBodies(tI), 1)
        Set tLabel = tType _ " " _ $List(tBodies(tI), 2)
        Do $ClassMethod(..#RECORD, "Clear")
        Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, tType, 500)
        Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, tType, .tQuery, tBody(tI), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, tLabel _ ": refused as a caller fault")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, tType), 0, tLabel _ ": before the vendor")
    }
    Do $ClassMethod(..#RECORD, "Clear")
    Set tAfter = $ClassMethod(..#PROBE, "Stored", tClientId)
    Do $$$AssertEquals(tAfter.%Get("RegistrationTokenLength") _ " " _ tAfter.%Get("ClientSecretLength") _ " " _ tAfter.%Get("SecretLength") _ " " _ $ClassMethod(..#PROBE, "ClientCount"), tBefore.%Get("RegistrationTokenLength") _ " " _ tBefore.%Get("ClientSecretLength") _ " " _ tBefore.%Get("SecretLength") _ " 1", "the stored secret members survive and nothing was created")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "SecretIs", tClientId, tCarried), "and the stored secret is not the one sent")
}

/// <p>An edit, a form read and a port write naming a client the instance does not hold answer 404 by
/// name, and nothing is sent: the vendor's <code>PUT</code> is not an upsert.</p>
Method TestAnAbsentClientIsNamed()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", "OcuPilotNoSuchClient128", {"Description": "absent"}, .tRaw, .tStatus)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch { Set tCode = "" }
    Do $$$AssertEquals(tStatus _ " " _ tCode, "404 OAUTH.SERVERCLIENT.ABSENT", "the edit is refused by name")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#FORMPATH _ "?clientId=OcuPilotNoSuchClient128", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ (tRaw [ "OAUTH.SERVERCLIENT.ABSENT"), "404 1", "and so is the form read")
    Kill tQuery
    Set tQuery("clientId") = "OcuPilotNoSuchClient128"
    Set tSC = ##class(OcuPilot.Port.OAuthRegisteredClientPort).Invoke(..#ENDPOINT, "PUT", .tQuery, {"Description": "absent"}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $ClassMethod(..#PROBE, "ClientCount"), "404 0", "and the port's PUT creates nothing")
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

}
