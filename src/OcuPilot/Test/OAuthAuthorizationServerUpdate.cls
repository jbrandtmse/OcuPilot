/// <p>Pins Story 12.7's authorization server edit (AD-4, AD-10, AD-39, AD-55): an edit sends the
/// complete set, so a partial change keeps every other field and <code>Metadata</code> member; the
/// scopes and the grant types change as edited; the refresh token policy round-trips as an ordinary
/// field; every bad value refuses an edit on both callers with nothing sent; a vendor 500 is named;
/// and an agent change adding <code>%All</code> or an
/// <code>%Admin_</code> customization role is minted destructive, naming the effect.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, no authorization server configuration, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and X.509 credentials
/// (<class>OcuPilot.Test.OAuthAuthorizationServerProbe</class>).</p>
Class OcuPilot.Test.OAuthAuthorizationServerUpdate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate";

Parameter SCREEN = "OcuPilot.Test.OAuthAuthorizationServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthAuthorizationServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthAuthorizationServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthAuthorizationServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.Server";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerUpdate creates and deletes this instance's OAuth 2.0 authorization server configuration and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Seed")
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

/// <p>AC2, AD-4: an edit that removes one scope, adds one, changes the grant types, an interval and the
/// description answers 200; the instance holds exactly that, every other field and the metadata
/// members the edit did not name read as before, and the body sent is the complete set with the fresh
/// read's whole <code>Metadata</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.MergedMetadata</method>
/// starts from an empty object rather than the fresh read's -- the sent metadata assertion goes
/// red.</p>
Method TestAnEditSendsTheCompleteSet()
{
    Set tBefore = $ClassMethod(..#PROBE, "Stored")
    Set tEdit = {"Description": "edited", "AccessTokenInterval": 1800, "SupportedScopes": [{"Scope": "openid", "Description": "OpenID"}, {"Scope": "email", "Description": "Email"}], "Metadata": {"grant_types_supported": ["authorization_code", "password"]}}
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", tEdit, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200: " _ $Extract(tRaw, 1, 300))
    Set tAfter = $ClassMethod(..#PROBE, "Stored")
    Do $$$AssertEquals(tAfter.%Get("Description") _ "|" _ tAfter.%Get("AccessTokenInterval") _ "|" _ tAfter.%Get("SupportedScopes") _ "|" _ tAfter.%Get("GrantTypes"), "edited|1800|email,openid|authorization_code,password,refresh_token", "the instance holds exactly the edit")
    For tField = "IssuerEndpoint", "AuthorizationCodeInterval", "RefreshTokenInterval", "SessionInterval", "CustomizationRoles", "CustomizationNamespace", "AuthenticateClass", "SigningAlgorithm", "service_documentation", "frontchannel_logout_supported", "frontchannel_logout_session_supported", "SupportSession" {
        Do $$$AssertEquals(tAfter.%Get(tField), tBefore.%Get(tField), tField _ " reads as before")
    }
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastBody", "PUT"))
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSent), $Parameter("OcuPilot.Test.OAuthAuthorizationServerCreate", "TEMPLATE"), "the body sent is the twenty-nine template fields")
    Set tMetadata = tSent.%Get("Metadata")
    Do $$$AssertTrue($IsObject(tMetadata) && (tMetadata.%Get("service_documentation") = tBefore.%Get("service_documentation")) && (tMetadata.%Get("issuer") '= ""), "whose metadata is the fresh read's whole object")
    Do $$$AssertEquals(tMetadata.%Get("grant_types_supported").%ToJSON(), "[""authorization_code"",""password"",""refresh_token""]", "with the edited grant types and the refresh grant the vendor adds")
}

/// <p>The agent's edit of one field is minted with that field's row alone, confirmed, and leaves every
/// other field and metadata member as it was; the card draws scopes as their names.</p>
Method TestTheAgentsEditKeepsEveryOtherField()
{
    Set tBefore = $ClassMethod(..#PROBE, "Stored")
    Set tArgs = {"SupportedScopes": [{"Scope": "openid", "Description": "OpenID"}]}
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the edit is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after")) }
    Do $$$AssertEquals($ListToString(tRows, ";"), "SupportedScopes|openid, profile|openid", "one row, the scopes drawn as names")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Set tAfter = $ClassMethod(..#PROBE, "Stored")
    Do $$$AssertEquals(tAfter.%Get("SupportedScopes"), "openid", "the instance holds the edit")
    For tField = "Description", "AccessTokenInterval", "CustomizationRoles", "GrantTypes", "service_documentation", "frontchannel_logout_supported" {
        Do $$$AssertEquals(tAfter.%Get(tField), tBefore.%Get(tField), tField _ " reads as before")
    }
}

/// <p>The refresh token policy is an ordinary field: an edit stores <code>c</code>, the port's read
/// answers it, and an agent's proposal shows it in its row (Conventions, Secrets).</p>
Method TestTheRefreshTokenPolicyRoundTrips()
{
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", {"ReturnRefreshToken": "c"}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("ReturnRefreshToken") _ " " _ $ClassMethod(..#PROBE, "Read").%Get("ReturnRefreshToken"), "c c", "the instance and the port's read hold it")
    Set tArgs = {"ReturnRefreshToken": "a"}
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If $IsObject($Get(tProposal)) Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""ReturnRefreshToken"",""before"":""c"",""after"":""a""}]", "and its row shows both values")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Log).IsCredentialName("ReturnRefreshToken"), 0, "the log's backstop reads it as no credential")
}

/// <p>Matrix row "Edit, bad value" in update mode, over the seeded configuration: each bad value
/// answers 422 on the field it names through the Save route and refuses in the edit tool's
/// <method>OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate.ArgumentProblem</method> with that
/// field's sentence, with no write recorded and the configuration unchanged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.Changes</method>
/// answers <var>pCreates</var> alone, so an edit applies no field's rule -- this goes red.</p>
Method TestEveryBadValueRefusesAnEditOnBothCallers()
{
    Set tBefore = $ClassMethod(..#PROBE, "Stored").%ToJSON()
    ; field|code|the edit's fields as JSON
    Set tCases = $ListBuild($ListBuild("SupportedScopes", "OAUTH.SCOPES.REQUIRED", "{""SupportedScopes"":[]}"))
    Set tCases = tCases _ $ListBuild($ListBuild("IssuerEndpoint", "OAUTH.SERVERISSUER.SHAPE", "{""IssuerEndpoint"":""http://ocupilotprobe127.invalid/probe""}"))
    Set tCases = tCases _ $ListBuild($ListBuild("CustomizationNamespace", "OAUTH.CUSTOMIZATIONNAMESPACE.ABSENT", "{""CustomizationNamespace"":""OCUPILOTNOSUCHNS""}"))
    Set tCases = tCases _ $ListBuild($ListBuild("SessionClass", "OAUTH.CUSTOMIZATIONCLASS.ABSENT", "{""SessionClass"":""OcuPilot.No.Such.Class""}"))
    Set tCases = tCases _ $ListBuild($ListBuild("CustomizationRoles", "OAUTH.CUSTOMIZATIONROLES.ABSENT", "{""CustomizationRoles"":[""%DB_IRISSYS"",""OcuPilotNoSuchRole127""]}"))
    Set tCases = tCases _ $ListBuild($ListBuild("AccessTokenInterval", "OAUTH.INTERVAL.VALUE", "{""AccessTokenInterval"":0}"))
    Set tCases = tCases _ $ListBuild($ListBuild("Metadata.grant_types_supported", "OAUTH.GRANTTYPES.REQUIRED", "{""Metadata"":{""grant_types_supported"":[]}}"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tField = $List(tCase, 1)
        Set tCode = $List(tCase, 2)
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tRaw, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.OAuthAuthorizationServerWire).ViolationCode(tRaw, tField), "422 " _ tCode, tField _ ": the Save refuses the edit on the field: " _ $Extract(tRaw, 1, 300))
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, tField _ ": and records no write")
        Set tSC = $ClassMethod(..#TOOL, "ArgumentProblem", ..Id(), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProblem)
        Do $$$AssertStatusOK(tSC, tField _ ": the edit tool's argument check runs")
        Do $$$AssertTrue($Get(tProblem) [ ("'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)), tField _ ": and refuses it with the field's sentence: " _ $Get(tProblem))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%ToJSON(), tBefore, "the configuration is unchanged")
}

/// <p>A vendor 500 on an edit is named: server credentials whose private key the instance cannot use
/// as <code>OAUTH.SERVERCREDENTIALS.KEY</code> on that field, and any other as
/// <code>OAUTH.SERVERVALIDATION</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthAuthorizationServerPort.Put</method> returns a
/// vendor 500 unmapped -- this goes red.</p>
Method TestAVendorRefusalIsNamed()
{
    Set tAlias = $ClassMethod(..#PROBE, "Name", "NoKey")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddCredential", tAlias, 0), "a credential without a private key is made")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", {"ServerCredentials": (tAlias)}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 422, "the edit is refused: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue((tRaw [ "OAUTH.SERVERCREDENTIALS.KEY") && (tRaw [ """field"":""ServerCredentials"""), "on the credentials, naming the key")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("ServerCredentials"), "", "and nothing is stored")
    Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, "PUT", 500)
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "PUT", {"Description": "refused"}, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 422, "another vendor refusal answers 422: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue(tRaw [ "OAUTH.SERVERVALIDATION", "as the configuration refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("Description"), "seeded", "and the description is unchanged")
}

/// <p>An agent change adding <code>%All</code> or an <code>%Admin_</code> customization role is minted
/// destructive with <code>OAUTH.CUSTOMIZATIONPRIVILEGED</code>; one adding an ordinary role is not.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>'s
/// authorization server arm -- the privileged change is minted plain and this goes red.</p>
Method TestAPrivilegedCustomizationRoleIsMintedDestructive()
{
    For tCase = $ListBuild("%All", 1, "OAUTH.CUSTOMIZATIONPRIVILEGED"), $ListBuild("%Admin_Secure", 1, "OAUTH.CUSTOMIZATIONPRIVILEGED"), $ListBuild("%Manager", 0, "") {
        Set tRoles = ["%DB_IRISSYS"]
        Do tRoles.%Push($List(tCase, 1))
        Set tArgs = {}
        Do tArgs.%Set("CustomizationRoles", tRoles)
        Do tArgs.%Set("Name", ..Id(), "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the change is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
        Do $$$AssertEquals($Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), $List(tCase, 2) _ " " _ $List(tCase, 3), $List(tCase, 1) _ ": destructive and named as declared")
    }
}

}
