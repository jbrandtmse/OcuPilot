/// <p>Pins Story 12.4's server description edit (AD-4, AD-6, AD-39, AD-55): the screen's Save sends
/// the complete set, one member changed and a member and a flag cleared with every other member kept;
/// an edit renames the issuer and keeps the clients configured against it, and the edit route answers
/// the new issuer, and a refused token write beside the saved description; an X.509 credential the
/// caller cannot use is refused on its field with nothing stored; an emptied SSL/TLS configuration and
/// a malformed rename are refused on both callers; a description deleted since is refused and not
/// re-created; and the agent's edit, whose <code>Metadata</code> replaces the stored metadata whole,
/// sends the complete set at its confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed with the demo fixture, an account
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// it creates and deletes OAuth 2.0 server descriptions and a client configuration. Every write reaches
/// the instance through <class>OcuPilot.Test.OAuthServerRecordPort</class>, except the one rename sent
/// over the wire, which the shipped route and port make.</p>
Class OcuPilot.Test.OAuthServerUpdate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionUpdate";

Parameter SCREEN = "OcuPilot.Test.OAuthServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthServerProbe";

Parameter RULES = "OcuPilot.Area.Security.OAuthServerRules";

Parameter ENDPOINT = "Security.OAuth2.Client.ServerDefinition";

/// <p>The edit route without its one segment.</p>
Parameter EDITPATH = "/oauth/server-description/";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerUpdate creates and deletes OAuth 2.0 server descriptions on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and no probe description survives")
    Quit $$$OK
}

/// <p>A description holding five members beyond the two required ones.</p>
Method Seeded(pSuffix As %String) As %String
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", pSuffix)
    Set tMore = {"userinfo_endpoint": (tIssuer _ "/userinfo"), "revocation_endpoint": (tIssuer _ "/revoke"), "scopes_supported": ["openid", "profile"], "response_types_supported": ["code"], "claims_parameter_supported": true}
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer, $ClassMethod(..#PROBE, "Metadata", tIssuer, tMore)), "description " _ pSuffix _ " is created")
    Quit tIssuer
}

/// <p>AC2 on the screen's caller: an edit that changes the userinfo endpoint and clears the
/// revocation endpoint and a flag sends the complete set -- the four template fields, no row field,
/// and every derived member, each cleared one empty -- and the instance then holds exactly that change
/// and those clearances, with every other field and member as before. A flag is cleared with
/// <code>""</code>, which the instance clears, never <code>false</code>, which it stores.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthServerRules.MemberViolations</method>
/// holds a flag to a boolean alone -- the flag's <code>""</code> is refused and this goes red.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthServerRules.Expand</method> returns before
/// it adds an empty member for each absent one -- the cleared member survives and this goes red.</p>
Method TestAnEditSendsTheCompleteSetAndClearsAMember()
{
    Set tIssuer = ..Seeded("Edit")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tIssuer)
    Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, {"Metadata": {"userinfo_endpoint": "https://ocupilotprobe124.invalid/changed", "revocation_endpoint": "", "claims_parameter_supported": ""}}, .tNew, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the edit completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastIssuer"), "PUT " _ tIssuer, "at the vendor's PUT, named by the issuer")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Keys", tSent), "IssuerEndpoint,Metadata,SSLConfiguration,ServerCredentials", "the four template fields and no row field")
    Do $ClassMethod(..#RULES, "Members", .tNames, .tKinds)
    Do $$$AssertEquals($ListLength($ListFromString($ClassMethod(..#PROBE, "Keys", tSent.%Get("Metadata")))), $ListLength(tNames), "every derived member is sent")
    Do $$$AssertEquals(tSent.%Get("Metadata").%Get("revocation_endpoint") _ "|" _ tSent.%Get("Metadata").%GetTypeOf("claims_parameter_supported"), "|string", "the cleared ones empty")

    Set tAfter = $ClassMethod(..#PROBE, "Stored", tIssuer)
    Set tExpected = tBefore.%Get("Metadata")
    Do tExpected.%Set("userinfo_endpoint", "https://ocupilotprobe124.invalid/changed", "string")
    Do tExpected.%Remove("revocation_endpoint")
    Do tExpected.%Remove("claims_parameter_supported")
    Do $$$AssertEquals(tAfter.%Get("Metadata").%ToJSON(), tExpected.%ToJSON(), "the instance holds exactly the change and the clearances")
    Do $$$AssertEquals(tAfter.%Get("SSLConfiguration") _ "|" _ tAfter.%Get("ServerCredentials"), tBefore.%Get("SSLConfiguration") _ "|" _ tBefore.%Get("ServerCredentials"), "and every other field as before")
}

/// <p>An edit renames the issuer: the description answers at the new issuer and not the old, and the
/// client configured against it still is; a rename onto an issuer another description carries is
/// refused on its field with nothing sent.</p>
Method TestAnEditRenamesTheIssuerAndKeepsItsClients()
{
    Set tIssuer = ..Seeded("Rename")
    Set tOther = ..Seeded("Other")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tIssuer), "a client configuration uses it")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, {"IssuerEndpoint": (tOther)}, .tNew, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, "IssuerEndpoint"), "OAUTH.ISSUERENDPOINT.TAKEN", "a rename onto a taken issuer is refused on its field")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Set tRenamed = $ClassMethod(..#PROBE, "Issuer", "Renamed")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, {"IssuerEndpoint": (tRenamed)}, .tNew, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the rename completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($Get(tNew), tRenamed, "answering the new issuer")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tRenamed) _ $ClassMethod(..#PROBE, "Holds", tIssuer), "10", "which the instance holds, and the old one it does not")
    Kill tNone
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tNone, "", .tRows, .tHttp, .tFault)
    Set tRow = ##class(OcuPilot.Port.OAuthServerPort).Matching($Get(tRows), tRenamed)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("ClientCount"), 1: -1), 1, "and its client configuration still uses it")
}

/// <p>The edit route answers a rename's new issuer over a real HTTP request; and a Save whose token
/// write the instance refuses answers the saved description with <code>tokenRefused</code>, the
/// refusal's sentence, dispatched in process through <class>OcuPilot.Test.RouterFixture</class> so
/// that <class>OcuPilot.Test.OAuthServerRecordPort</class> can refuse the token write alone.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthServerSave.HandleUpdate</method> answers
/// the route's issuer, not the new one -- the rename assertion goes red.</p>
Method TestTheEditRouteAnswersARenameAndARefusedToken()
{
    Set tIssuer = ..Seeded("RouteRename")
    Set tRenamed = $ClassMethod(..#PROBE, "Issuer", "RouteRenamed")
    Set tBody = {}
    Do tBody.%Set("IssuerEndpoint", tRenamed, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#EDITPATH _ ##class(OcuPilot.Kernel.EntityId).Encode(tIssuer), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the rename answers 200 over the wire: " _ $Extract($Get(tRaw), 1, 300))
    Set tAnswer = ..Parsed($Get(tRaw))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("issuer"), 1: ""), tRenamed, "answering the new issuer")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tRenamed), 1, "which the instance holds")

    Set tToken = "ocupilotrouteprobe000" _ $Job
    Set tRequest = {"Metadata": {"userinfo_endpoint": "https://ocupilotprobe124.invalid/route"}}
    Do tRequest.%Set("InitialAccessToken", tToken, "string")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#RECORD, "FailType", "TOKEN")
    ; The segment the web server would deliver: Encode's second encoding is consumed in transit.
    Set tSegment = ##class(OcuPilot.Test.EntityId).ServerDecode(##class(OcuPilot.Kernel.EntityId).Encode(tRenamed))
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", ..#EDITPATH _ tSegment, "PUT", , .tRaw, .tStatus, , , tRequest.%ToJSON())
    Do $$$AssertEquals(tStatus, 200, "a Save whose token write is refused answers 200: " _ $Extract($Get(tRaw), 1, 300))
    Set tAnswer = ..Parsed($Get(tRaw))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("issuer") _ "|" _ tAnswer.%Get("tokenRefused"), 1: ""), tRenamed _ "|" _ ##class(OcuPilot.Api.Error).#REASONPORTNOTAPPLIED, "with the issuer and the token write's refusal")
    Do $$$AssertEquals($Get(tRaw) [ tToken, 0, "and without the token")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "CallTypes") [ "PUT", 1, "the description was sent")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType"), "TOKEN", "and then the token write, which was refused")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tRenamed)
    Do $$$AssertEquals(tStored.%Get("Metadata").%Get("userinfo_endpoint") _ "|" _ tStored.%Get("TokenLength"), "https://ocupilotprobe124.invalid/route|0", "the instance holds the edit and no token")
}

/// <p>AD-39 on an edit: an emptied SSL/TLS configuration and a rename to an issuer that is not an
/// absolute <code>http</code> or <code>https</code> URL are each refused on their field by the
/// screen's Save with nothing sent; and the agent's edit, which cannot rename, refuses the emptied
/// SSL/TLS configuration with the field's sentence.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthServerRules.Validate</method> requires
/// the SSL/TLS configuration on a create alone -- both SSL/TLS assertions go red.</p>
Method TestAnEditThatEmptiesTheSslOrRenamesToAMalformedIssuerIsRefused()
{
    Set tIssuer = ..Seeded("EditShape")
    For tCase = "SSLConfiguration||OAUTH.SSLCONFIGURATION.REQUIRED", "IssuerEndpoint|ftp://ocupilotprobe124.invalid/renamed|OAUTH.ISSUERENDPOINT.SHAPE" {
        Set tField = $Piece(tCase, "|", 1)
        Set tBody = {}
        Do tBody.%Set(tField, $Piece(tCase, "|", 2), "string")
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, tBody, .tNew, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, tField), $Piece(tCase, "|", 3), tField _ ": the Save refuses it on its field")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tField _ ": and sends nothing")
    }
    Set tArgs = {"SSLConfiguration": ""}
    Do tArgs.%Set("IssuerEndpoint", tIssuer, "string")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, tArgs, .tProposal, .tHttp, .tFault)
    Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation("OAUTH.SSLCONFIGURATION.REQUIRED")
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#PROBE, "Problem", $Get(tFault)) [ ("'SSLConfiguration': " _ tReason)), "the agent's edit refuses the emptied SSL/TLS configuration with the field's sentence")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tIssuer)
    Do $$$AssertEquals(tStored.%Get("SSLConfiguration") _ "|" _ tStored.%Get("IssuerEndpoint"), $Parameter(..#PROBE, "SSLCONFIG") _ "|" _ tIssuer, "and the stored description is unchanged")
}

/// <p><var>pRaw</var> parsed as JSON, or <code>""</code>.</p>
ClassMethod Parsed(pRaw As %String) As %DynamicAbstractObject
{
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(pRaw)
    } Catch {
        Set tAnswer = ""
    }
    Quit tAnswer
}

/// <p>An X.509 credential the caller cannot use is refused on its field before the vendor's own save
/// refuses it with a 500, on the Save and at the port, and nothing is stored.</p>
Method TestAnUnusableCredentialIsRefusedOnItsField()
{
    Set tIssuer = ..Seeded("Credential")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, {"ServerCredentials": "OcuPilotProbe124NoSuchCredential"}, .tNew, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, "ServerCredentials"), "OAUTH.SERVERCREDENTIALS.ABSENT", "the Save refuses the credential on its field")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke(..#ENDPOINT, "PUT", .tQuery, {"ServerCredentials": "OcuPilotProbe124NoSuchCredential"}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "the port answers a body naming it 422")
    Set tRow = ""
    If $IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object") Set tRow = tFault.%Get("detail").%Get("violations").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ " " _ tRow.%Get("code"), 1: ""), "ServerCredentials OAUTH.SERVERCREDENTIALS.ABSENT", "on the credential's field")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("ServerCredentials"), "", "and nothing is stored")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, {"ServerCredentials": ($Parameter(..#PROBE, "CREDENTIAL"))}, .tNew, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "a credential the caller can use is saved")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("ServerCredentials"), $Parameter(..#PROBE, "CREDENTIAL"), "and stored")
}

/// <p>An edit's rules read the members it changes and the metadata the description will hold: an
/// unknown member, an ill-shaped one and an emptied required endpoint are each refused with nothing
/// sent; and an edit of a description the instance no longer holds is 404, re-creating nothing.</p>
Method TestTheRulesHoldAnEditAndAnAbsentDescriptionIsNotRecreated()
{
    Set tIssuer = ..Seeded("EditRules")
    For tCase = "bogus|OAUTH.METADATA.UNKNOWN", "scopes_supported|OAUTH.METADATA.SHAPE", "token_endpoint|OAUTH.TOKENENDPOINT.REQUIRED" {
        Set tMember = $Piece(tCase, "|", 1)
        Set tMetadata = {}
        If tMember = "token_endpoint" {
            Do tMetadata.%Set(tMember, "", "string")
        } ElseIf tMember = "scopes_supported" {
            Do tMetadata.%Set(tMember, "openid", "string")
        } Else {
            Do tMetadata.%Set(tMember, "x", "string")
        }
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Update", tIssuer, {"Metadata": (tMetadata)}, .tNew, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, "Metadata." _ tMember), $Piece(tCase, "|", 2), tMember _ ": refused on its field")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tMember _ ": and nothing is sent")
    }
    Set tGone = $ClassMethod(..#PROBE, "Issuer", "Gone")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Update", tGone, {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}, .tNew, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp, 404, "an edit of a description the instance does not hold is 404")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ $ClassMethod(..#PROBE, "Holds", tGone), "00", "and nothing is sent or created")
}

/// <p>AC7's edit half: the agent's <code>Metadata</code> replaces the stored metadata whole, so its
/// proposal shows one <code>Metadata</code> row, before and after, and its confirm sends the complete
/// set -- the member it left out empty -- after which the instance holds exactly the metadata it
/// proposed.</p>
Method TestTheAgentsEditSendsTheCompleteSet()
{
    Set tIssuer = ..Seeded("Agent")
    Set tMetadata = $ClassMethod(..#PROBE, "Metadata", tIssuer, {"userinfo_endpoint": (tIssuer _ "/me"), "scopes_supported": ["openid"]})
    Set tArgs = {}
    Do tArgs.%Set("IssuerEndpoint", tIssuer, "string")
    Do tArgs.%Set("Metadata", tMetadata)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted: " _ $ClassMethod(..#PROBE, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field")) }
    Do $$$AssertEquals($ListToString(tRows), "Metadata", "one Metadata row")
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("after"), 1: ""), tMetadata.%ToJSON(), "whose after is the metadata proposed")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the edit is confirmed: " _ $Get(tCode))
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Keys", tSent), "IssuerEndpoint,Metadata,SSLConfiguration,ServerCredentials", "the confirm sends the four template fields")
    Do $ClassMethod(..#RULES, "Members", .tNames, .tKinds)
    Do $$$AssertEquals($ListLength($ListFromString($ClassMethod(..#PROBE, "Keys", tSent.%Get("Metadata")))), $ListLength(tNames), "and every derived member")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tIssuer).%Get("Metadata").%ToJSON(), ##class(%DynamicObject).%FromJSON(tMetadata.%ToJSON()).%ToJSON(), "and the instance holds exactly the metadata proposed")
}

}
