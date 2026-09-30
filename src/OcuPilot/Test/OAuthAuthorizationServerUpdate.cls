/// <p>Pins Story 12.7's authorization server edit (AD-4, AD-10, AD-39, AD-55): an edit sends the
/// complete set, so a partial change keeps every other field and <code>Metadata</code> member; the
/// scopes and the grant types change as edited; the refresh token policy round-trips as an ordinary
/// field; every bad value refuses an edit on both callers with nothing sent; a vendor 500 is named;
/// an agent change adding a customization role that grants <code>%All</code> or an administrative
/// privilege is minted destructive, naming the effect; and a role the caller cannot read counts as
/// privileged.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, no authorization server configuration, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and X.509 credentials
/// (<class>OcuPilot.Test.OAuthAuthorizationServerProbe</class>), and a user and a role.</p>
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

/// <p>The principal the fail-closed leg classifies as: the install namespace's code read, the system
/// database read and the tab's resource, and not <code>%Admin_Secure:USE</code>, so the instance
/// refuses it a role read.</p>
Parameter UNREADUSER = "OcuPilotUpdateRoleUnread";

Parameter UNREADROLE = "OcuPilotUpdateRoleUnreadRole";

/// <p>A role name this instance holds no role for.</p>
Parameter ABSENTROLE = "OcuPilotNoSuchRole127";

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
    ; A leg that stopped before its own removal leaves its principal and its armed read; this
    ; removes both.
    Do ..RemoveUnreadPrincipal(.tLeft)
    Do ##class(OcuPilot.Test.ProhibitedFixture).ArmRoleReadFault(0)
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

/// <p>AD-6: the card shows what the write sends. A change to a scope's description alone draws the
/// scopes with their descriptions, so its row reads differently before and after; and grant types
/// named without <code>refresh_token</code> read with it, as the write sends them.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.CardRows</method>
/// draws the scopes by name alone, or <method>OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate.MergeUpdate</method>
/// skips <method>OcuPilot.Area.Security.OAuthAuthorizationServerRules.WithRefreshGrant</method> -- this
/// goes red.</p>
Method TestTheCardShowsWhatTheWriteSends()
{
    Set tFresh = $ClassMethod(..#PROBE, "Read")
    Do $$$AssertTrue($IsObject(tFresh), "the seeded configuration reads")
    If '$IsObject(tFresh) Quit
    Set tScopes = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%Get("SupportedScopes").%ToJSON())
    Do tScopes.%Get(0).%Set("Description", "Described again", "string")
    Set tArgs = {}
    Do tArgs.%Set("SupportedScopes", tScopes)
    Set tSC = $ClassMethod(..#TOOL, "MergeUpdate", tFresh, tArgs, "", $ClassMethod(..#TOOL, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "a description-only scope change merges: " _ $Get(tProblem))
    Set tRow = ""
    If $IsObject($Get(tDiff)) && (tDiff.%Size() > 0) Set tRow = tDiff.%Get(0)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.%Get("field") = "SupportedScopes") && (tRow.%Get("before") '= tRow.%Get("after")) && (tRow.%Get("after") [ "Described again"), "its row shows the description changing: " _ $Select($IsObject(tRow): tRow.%ToJSON(), 1: "no row"))
    Set tArgs = {"Metadata": {"grant_types_supported": ["authorization_code", "password"]}}
    Set tSC = $ClassMethod(..#TOOL, "MergeUpdate", tFresh, tArgs, "", $ClassMethod(..#TOOL, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "a grant type change merges: " _ $Get(tProblem))
    Set tAfter = ""
    Set tIterator = tDiff.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("field") = "Metadata.grant_types_supported") Set tAfter = tRow.%Get("after")
    }
    Do $$$AssertEquals(tAfter, "authorization_code, password, refresh_token", "its row reads the grant types the write sends")
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

/// <p>AD-10: an agent change adding a customization role that is <code>%All</code>, or whose roles
/// hold <code>%All</code> or an <code>%Admin_</code> resource (<code>%Manager</code>, measured), is
/// minted destructive with <code>OAUTH.CUSTOMIZATIONPRIVILEGED</code>; one adding an ordinary role
/// (<code>%Developer</code>) is not.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>'s
/// authorization server arm, or judge a role by its name alone -- the <code>%Manager</code> change is
/// minted plain and this goes red.</p>
Method TestAPrivilegedCustomizationRoleIsMintedDestructive()
{
    For tCase = $ListBuild("%All", 1, "OAUTH.CUSTOMIZATIONPRIVILEGED"), $ListBuild("%Admin_Secure", 1, "OAUTH.CUSTOMIZATIONPRIVILEGED"), $ListBuild("%Manager", 1, "OAUTH.CUSTOMIZATIONPRIVILEGED"), $ListBuild("%Developer", 0, "") {
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

/// <p>AD-10's fail-closed arm: a role the classifier cannot read counts as privileged, never as
/// granting nothing and never as an error the mint would answer 500. Classified in a process signed
/// in as <parameter>UNREADUSER</parameter>, which the instance refuses every role read, adding
/// <code>%Developer</code> -- not privileged when read -- answers privileged with an OK status on the
/// authorization server arm, naming <code>OAUTH.CUSTOMIZATIONPRIVILEGED</code>, and on the
/// web-application arm, and the role read itself answers an error rather than "no resources". A
/// per-role read that fails for a caller who may read roles (<class>OcuPilot.Test.ProhibitedFixture</class>
/// armed) counts as privileged too. A role the instance does not hold, read by a caller who may read
/// roles, still grants nothing. The principal is created here and removed, and its removal read
/// back.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.RoleEscalates</method> reads a
/// failed role read as granting nothing -- both arms answer not privileged and this goes red;
/// <method>OcuPilot.Kernel.Proposal.Prohibited.RoleGrantsPrivilege</method> answers OK for a role it
/// cannot read -- the role-read assertion goes red.</p>
Method TestAnUnreadableRoleCountsAsPrivileged()
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).GrantsPrivilegeByEffect("oauth2-server", ..RolesBody(..#ABSENTROLE), ..RolesBody(), .tGrants)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tGrants, "1 0", "a role the instance does not hold grants nothing")
    Do ##class(OcuPilot.Test.ProhibitedFixture).ArmRoleReadFault(1)
    Set tArmed = ##class(OcuPilot.Test.ProhibitedFixture).RoleGrantsAdministrativePrivilege("%Developer")
    Do ##class(OcuPilot.Test.ProhibitedFixture).ArmRoleReadFault(0)
    Set tWhole = ##class(OcuPilot.Test.ProhibitedFixture).RoleGrantsAdministrativePrivilege("%Developer")
    Do $$$AssertEquals(tArmed _ " " _ tWhole, "1 0", "a per-role read that fails counts as privileged, where the same role read whole does not")
    Set tSC = ..EnsureUnreadPrincipal()
    Do $$$AssertStatusOK(tSC, "the principal without %Admin_Secure:USE is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISOK(tSC) {
        Set tOut = ..ClassifiedAs(..#UNREADUSER)
        Do $$$AssertEquals(tOut.%Get("error"), "", "the principal's process classified: " _ tOut.%ToJSON())
        Do $$$AssertEquals(tOut.%Get("username") _ " " _ tOut.%Get("read"), ..#UNREADUSER _ " 0 822", "as the principal, whose read of the role is refused")
        Do $$$AssertEquals(tOut.%Get("server"), "1 1 OAUTH.CUSTOMIZATIONPRIVILEGED", "the authorization server arm answers OK and privileged, naming the effect")
        Do $$$AssertEquals(tOut.%Get("webapp"), "1 1", "and so does the web-application arm")
        Do $$$AssertEquals(tOut.%Get("roleread"), "1 0", "and the role read itself answers an error, never no resources")
    }
    Set tSC = ..RemoveUnreadPrincipal(.tLeft)
    Do $$$AssertStatusOK(tSC, "the principal is removed")
    Do $$$AssertEquals(tLeft, "0 0", "and neither the account nor its role survives")
}

/// <p>A payload or target whose <code>CustomizationRoles</code> is <code>%DB_IRISSYS</code> and
/// <var>pAdded</var>, when it is not empty.</p>
ClassMethod RolesBody(pAdded As %String = "") As %DynamicObject
{
    Set tRoles = ["%DB_IRISSYS"]
    If pAdded '= "" Do tRoles.%Push(pAdded)
    Set tBody = {}
    Do tBody.%Set("CustomizationRoles", tRoles)
    Quit tBody
}

/// <p>Create <parameter>UNREADROLE</parameter> and <parameter>UNREADUSER</parameter>, holding it, and
/// read the grants back.</p>
ClassMethod EnsureUnreadPrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCodeRead = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set tNamespace = ""
        Set tDatabase = ""
        If ##class(Security.Users).Exists(..#UNREADUSER) Do ##class(Security.Users).Delete(..#UNREADUSER)
        If ##class(Security.Roles).Exists(..#UNREADROLE) Do ##class(Security.Roles).Delete(..#UNREADROLE)
        Set tSC = ##class(Security.Roles).Create(..#UNREADROLE, "OcuPilot test: a principal refused role reads (throwaway)", tCodeRead _ ",%DB_IRISSYS:R,%Admin_OAuth2_Server:U", "")
        If $$$ISERR(tSC) Quit
        Set tPassword = "OcuPilotUnread" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(Security.Users).Create(..#UNREADUSER, ..#UNREADROLE, tPassword, "OcuPilot test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.OAuthAuthorizationServerUpdate; deleted by the leg that made it")
        Set tPassword = ""
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#UNREADUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#UNREADUSER, "%Admin_OAuth2_Server", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#UNREADUSER, "%DB_IRISSYS", "READ") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal's grants did not read back as declared")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove <parameter>UNREADUSER</parameter> and <parameter>UNREADROLE</parameter>, with whether
/// each still exists in <var>pLeft</var> as <code>"&lt;user&gt; &lt;role&gt;"</code>.</p>
ClassMethod RemoveUnreadPrincipal(Output pLeft As %String) As %Status
{
    Set pLeft = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#UNREADUSER) Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete(..#UNREADUSER))
        If ##class(Security.Roles).Exists(..#UNREADROLE) Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(..#UNREADROLE))
        Set pLeft = ##class(Security.Users).Exists(..#UNREADUSER) _ " " _ ##class(Security.Roles).Exists(..#UNREADROLE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>What <method>ClassifyAs</method> signals from a process signed in as <var>pUser</var>, as
/// <code>{error, username, read, server, webapp, roleread}</code>, or <code>{error}</code>.</p>
ClassMethod ClassifiedAs(pUser As %String) As %DynamicObject
{
    Set tOut = {"error": ""}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.OAuthAuthorizationServerUpdate).ClassifyAs($Job, pUser)::10
        If '$Test {
            Do tOut.%Set("error", "the principal's process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the principal's process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Log in as <var>pUser</var> and signal to process <var>pParent</var> the classifier's answers
/// for adding <code>%Developer</code>: <code>read</code>, that principal's <code>Exists</code> answer
/// and error codes for the role; <code>server</code>, the authorization server arm's status, verdict
/// and consequence code; <code>webapp</code>, the web-application arm's status and verdict; and
/// <code>roleread</code>, whether the role read answers an error, and what it grants.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>ClassifiedAs</method> and by nothing
/// else; <code>$System.Security.Login</code> switches this process's own user context.</p>
ClassMethod ClassifyAs(pParent As %Integer, pUser As %String)
{
    Set tOut = {"error": ""}
    Set tOrigNS = $NAMESPACE
    Try {
        If '$SYSTEM.Security.Login(pUser) {
            Do tOut.%Set("error", "the login as " _ pUser _ " failed")
            Quit
        }
        Do tOut.%Set("username", $Username, "string")
        Set tRole = "%Developer"
        Set $NAMESPACE = "%SYS"
        Set tExistsSC = $$$OK
        Set tExists = ##class(Security.Roles).Exists(tRole, , .tExistsSC)
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("read", tExists _ " " _ $System.Status.GetErrorCodes(tExistsSC), "string")
        Set tSet = "OcuPilot.Kernel.Proposal.Prohibited"
        Set tSC = $ClassMethod(tSet, "GrantsPrivilegeByEffect", "oauth2-server", ..RolesBody(tRole), ..RolesBody(), .tGrants)
        Do tOut.%Set("server", $$$ISOK(tSC) _ " " _ tGrants _ " " _ $ClassMethod(tSet, "ServerConsequence", "", tGrants, ""), "string")
        Set tApplication = {"MatchRoles": [{"MatchRole": "", "TargetRoles": []}]}
        Do tApplication.%Get("MatchRoles").%Get(0).%Get("TargetRoles").%Push(tRole)
        Set tSC = $ClassMethod(tSet, "GrantsPrivilegeByEffect", "web-application", tApplication, {"MatchRoles": []}, .tGrants)
        Do tOut.%Set("webapp", $$$ISOK(tSC) _ " " _ tGrants, "string")
        Set tReadSC = ##class(OcuPilot.Test.ProhibitedFixture).RoleRead(tRole, .tReadGrants)
        Do tOut.%Set("roleread", $$$ISERR(tReadSC) _ " " _ +$Get(tReadGrants), "string")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
