/// <p>Pins Story 12.7's authorization server create (AD-3, AD-10, AD-39, AD-54, AD-55): what the five
/// tools and the editor's descriptor declare, one create through the Save route, a present
/// configuration refused before any write, every form rule refused on both callers before anything is
/// sent, a create taken after the mint refused at its confirm, and the port refusing a caller without
/// one of its pairs before any vendor call.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, no authorization server configuration, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and X.509 credentials
/// (<class>OcuPilot.Test.OAuthAuthorizationServerProbe</class>).</p>
Class OcuPilot.Test.OAuthAuthorizationServerCreate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate";

Parameter TAB = "OcuPilot.Screen.Descriptor.OAuthServerTab";

Parameter FORM = "OcuPilot.Screen.Descriptor.OAuthServerForm";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.OAuthAuthorizationServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthAuthorizationServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthAuthorizationServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthAuthorizationServerProbe";

/// <p>The 12.4 probe, whose mint and listing helpers take any tool.</p>
Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.Server";

Parameter CREATEPATH = "/oauth/authorization-server";

/// <p>The twenty-nine template fields, sorted.</p>
Parameter TEMPLATE = "AccessTokenInterval,AllowPublicClientRefresh,AllowUnsupportedScope,AudRequired,AuthenticateClass,AuthorizationCodeInterval,ClientSecretInterval,CustomizationNamespace,CustomizationRoles,DefaultScope,Description,EncryptionAlgorithm,ForcePKCEForConfidentialClients,ForcePKCEForPublicClients,GenerateTokenClass,IssuerEndpoint,KeyAlgorithm,Metadata,RefreshTokenInterval,ReturnRefreshToken,RevokeTokenClass,SSLConfiguration,ServerCredentials,SessionClass,SessionInterval,SigningAlgorithm,SupportSession,SupportedScopes,ValidateUserClass";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthAuthorizationServerCreate creates and deletes this instance's OAuth 2.0 authorization server configuration and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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

/// <p>The singleton id every tool is minted against.</p>
ClassMethod Id() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>The five tools are write tools over the tab, reached through the authorization server port,
/// named by the singleton id, each requiring exactly the tab's pairs; each declares its own request
/// types, body, change and row action; each action write's subject is adequate; and each description
/// says nothing changes until the user confirms.</p>
Method TestTheFiveToolsAreDeclaredOverTheTabAndThePort()
{
    ; name|class suffix|read|write|sends body|change|destructive|screen actions|creates
    Set tRows = $ListBuild("create|Create|GET|PUT|1|created|0||1", "update|Update|GET|PUT|1|updated|0||0", "setpassword|SetPassword|GET|CHANGEPWD|0|updated|0||0", "rotatekeys|RotateKeys|GET|ROTATEKEYS|0|updated|0|rotatekeys|0", "delete|Delete|GET|DELETE|0|deleted|1|delete|0")
    Set tTabPairs = $ClassMethod(..#TAB, "PrivilegePairs")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tName = "security.oauthserver." _ $Piece(tRow, "|", 1)
        Set tClass = "OcuPilot.Screen.Tool.OAuthAuthorizationServer" _ $Piece(tRow, "|", 2)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ ": the registry resolves it")
        If '$IsObject($Get(tTool)) Continue
        Do $$$AssertEquals(tTool.%Get("class") _ " " _ tTool.%Get("kind"), tClass _ " write", tName _ ": a write tool of its own class")
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), ..#TAB, tName _ ": over the tab")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.OAuthAuthorizationServerPort", tName _ ": through the authorization server port")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint"), ..#ENDPOINT, tName _ ": on the configuration's endpoint")
        Set tDeclared = $ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ListToString($ClassMethod(tClass, "ScreenActionIds")) _ "|" _ $ClassMethod(tClass, "Creates")
        Do $$$AssertEquals(tDeclared, $Piece(tRow, "|", 3, 9), tName _ ": its read, write, body, change, treatment, row action and kind")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PrivilegePairs")), $ListToString(tTabPairs), tName _ ": requiring the tab's own pairs")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, $ClassMethod(tClass, "WriteType")), tName _ ": the port admits its write")
        If '$ClassMethod(tClass, "SendsBody") Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": its subject is adequate")
        Do $$$AssertTrue($Parameter(tClass, "DESCRIPTION") [ "by itself", tName _ ": its description says nothing changes until the user confirms")
        Do $$$AssertTrue($ClassMethod(tClass, "InputSchema").%ToJSON() [ ("'" _ ..Id() _ "'"), tName _ ": its schema names the singleton id")
    }
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.OAuthAuthorizationServerSetPassword", "SecretBodyNames")) _ " " _ $ListToString($ClassMethod(..#TAB, "SecretArguments")), "ServerPassword ServerPassword", "the password tool's body is the one secret the tab declares")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("oauth2-server", "https://anything.invalid/x"), ..Id(), "and every id folds to the singleton")
}

/// <p>The create's settable set is the twenty-nine template fields, which are the prohibited set's
/// reviewed create and change lists; its schema adds the scopes and the metadata as objects, and
/// requires the issuer, the scopes and the roles.</p>
Method TestTheSchemaAndTheSettableSetAreTheTemplatesFields()
{
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#TOOL, "SettableFields")), ..#TEMPLATE, "the twenty-nine template fields")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedCreateFields", "oauth2-server")), ..#TEMPLATE, "the prohibited set's create list")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedChangeFields", "oauth2-server")), ..#TEMPLATE, "and its change list")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("SupportedScopes").%Get("type") _ " " _ tProperties.%Get("Metadata").%Get("type") _ " " _ tProperties.%Get("CustomizationRoles").%Get("type") _ " " _ tProperties.%Get("AccessTokenInterval").%Get("type") _ " " _ tProperties.%Get("AudRequired").%Get("type") _ " " _ tProperties.%Get("ReturnRefreshToken").%Get("type"), "array object array number boolean string", "the scopes, metadata, roles, an interval, a flag and the refresh policy are typed")
    Do $$$AssertEquals(tProperties.%GetTypeOf("ServerPassword"), "unassigned", "and the key password is no argument")
    Set tRequired = ""
    Set tIterator = tSchema.%Get("required").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) { Set tRequired = tRequired _ $ListBuild(tName) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tRequired), "CustomizationRoles,IssuerEndpoint,Name,SupportedScopes", "requiring the id, the issuer, the scopes and the roles")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "and the schema is one a provider request carries")
}

/// <p>The editor is built and unlisted at the tab's route with the editor suffix, a form page over the
/// authorization server type with the tab's own pairs and the classic page as its key, its key
/// password secret-typed in its context; the tab offers Create, Delete and Rotate Keys, declares the
/// password, and declares no classic link-out.</p>
Method TestTheEditorIsBuiltUnlistedOverTheTabsPairs()
{
    Do $$$AssertEquals($ClassMethod(..#FORM, "Route"), $ClassMethod(..#TAB, "Route") _ "/edit", "the editor's route is the tab's with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(..#FORM, "IsBuilt") _ " " _ (+$ClassMethod(..#FORM, "SideBarPosition")), "1 0", "built and unlisted")
    Do $$$AssertEquals($ClassMethod(..#FORM, "Archetype") _ " " _ $ClassMethod(..#FORM, "PrimaryEntityType"), "form-page oauth2-server", "a form page over the authorization server type")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "PrivilegePairs")), $ListToString($ClassMethod(..#TAB, "PrivilegePairs")), "requiring exactly the tab's pairs")
    Do $$$AssertEquals($ClassMethod(..#FORM, "ClassicPage"), "%CSP.UI.Portal.OAuth2.Server.Configuration", "keyed by the classic configuration page")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "ContextSecretFields")), "ServerPassword", "its password is secret-typed in its context")
    Do $$$AssertEquals($ClassMethod(..#TAB, "PrimaryActionId") _ " " _ $ListToString($ClassMethod(..#TAB, "RowActionIds")), "create delete,rotatekeys", "the tab offers Create, Delete and Rotate Keys")
    Set tSC = $ClassMethod(..#TAB, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the tab's declaration reads")
    If $IsObject($Get(tDeclaration)) Do $$$AssertEquals(tDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "and declares no classic link-out")
}

/// <p>AC1 over the wire: a create through <code>POST /oauth/authorization-server</code> answers 201,
/// and the instance, the port's read and the tab's read hold every value entered.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate.ComposeCreate</method>
/// composes no <code>CustomizationRoles</code> -- the new configuration takes the default roles and
/// this goes red.</p>
Method TestACreateThroughTheRouteStoresEveryValue()
{
    Set tBody = $ClassMethod(..#PROBE, "Body", {"Description": "created by the probe", "AccessTokenInterval": 1800, "ReturnRefreshToken": "c", "DefaultScope": "openid", "AudRequired": true, "Metadata": {"grant_types_supported": ["authorization_code", "client_credentials"], "op_tos_uri": "https://ocupilotprobe127.invalid/tos"}})
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 201, "the create answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue(tRaw [ $ClassMethod(..#PROBE, "Issuer"), "naming the issuer")
    Set tStored = $ClassMethod(..#PROBE, "Stored")
    Do $$$AssertTrue($IsObject(tStored), "the instance holds the configuration")
    If '$IsObject(tStored) Quit
    Set tSeen = tStored.%Get("IssuerEndpoint") _ "|" _ tStored.%Get("Description") _ "|" _ tStored.%Get("AccessTokenInterval") _ "|" _ tStored.%Get("ReturnRefreshToken") _ "|" _ tStored.%Get("DefaultScope") _ "|" _ tStored.%Get("AudRequired") _ "|" _ tStored.%Get("SupportedScopes") _ "|" _ tStored.%Get("CustomizationRoles") _ "|" _ tStored.%Get("GrantTypes") _ "|" _ tStored.%Get("op_tos_uri")
    Do $$$AssertEquals(tSeen, $ClassMethod(..#PROBE, "Issuer") _ "|created by the probe|1800|c|openid|1|openid,profile|%DB_IRISSYS|authorization_code,client_credentials,refresh_token|https://ocupilotprobe127.invalid/tos", "with every value entered")
    Do $$$AssertEquals(tStored.%Get("AuthorizationCodeInterval") _ "|" _ tStored.%Get("SupportSession") _ "|" _ tStored.%Get("CustomizationNamespace") _ "|" _ tStored.%Get("SessionClass"), "60|1|%SYS|OAuth2.Server.Session", "and the classic page's values for every field left out")
    Set tRead = $ClassMethod(..#PROBE, "Read")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.%Get("Description") _ "|" _ tRead.%Get("ClientsHidden") _ "|" _ tRead.%Get("Clients").%ToJSON(), "created by the probe|0|[]", "the port's read answers them, with no client")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#TAB, "", .tResult, .tHttp, .tFault)
    Set tListed = 0
    If $IsObject($Get(tResult)) {
        Set tIterator = tResult.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) { If tRow.%Get("IssuerEndpoint") = $ClassMethod(..#PROBE, "Issuer") Set tListed = 1 }
    }
    Do $$$AssertTrue(tListed, "and the tab's read shows it")
}

/// <p>A create while the instance holds a configuration is refused
/// <code>OAUTH.SERVERCONFIG.TAKEN</code> before any write, and the configuration is unchanged: the
/// vendor's <code>PUT</code> is an upsert.</p>
Method TestAPresentConfigurationIsRefusedTaken()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored").%ToJSON()
    Set tSC = $ClassMethod(..#SCREEN, "Create", $ClassMethod(..#PROBE, "Body", {"Description": "the second"}), .tHttp, .tFault, .tViolations, .tIssuer)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "IssuerEndpoint"), "OAUTH.SERVERCONFIG.TAKEN", "the Save refuses the create")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%ToJSON(), tBefore, "and the configuration is unchanged")
}

/// <p>The same refusal over the wire: <code>POST /oauth/authorization-server</code> with a
/// configuration present answers the editor's one 422 envelope with <code>OAUTH.SERVERCONFIG.TAKEN</code>
/// on <code>IssuerEndpoint</code> in <code>detail.violations</code>, and the configuration is
/// unchanged.</p>
Method TestAPresentConfigurationIsRefusedTakenOverTheWire()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tBefore = $ClassMethod(..#PROBE, "Stored").%ToJSON()
    Set tSC = ..Request("POST", ..#CREATEPATH, $ClassMethod(..#PROBE, "Body", {"Description": "the second"}), .tStatus, .tRaw)
    Set tCode = ""
    Set tTaken = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
        Set tCode = tAnswer.%Get("code")
        Set tIterator = tAnswer.%Get("detail").%Get("violations").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) { If tRow.%Get("field") = "IssuerEndpoint" Set tTaken = tRow.%Get("code") }
    } Catch {
        Set tCode = ""
    }
    Do $$$AssertEquals(tStatus _ " " _ tCode _ " " _ tTaken, "422 " _ ##class(OcuPilot.Api.Error).#OAUTHSERVERVALIDATION _ " OAUTH.SERVERCONFIG.TAKEN", "the create is refused on the issuer: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%ToJSON(), tBefore, "and the configuration is unchanged")
}

/// <p>Every form rule refuses on both callers, on the field it names, with nothing sent: the screen's
/// Save answers the field's violation and the agent's mint the field's sentence -- or, for a value the
/// tool's schema already refuses by type, a schema refusal.</p>
Method TestEveryFormRuleRefusesOnBothCallers()
{
    Set tLong = $Translate($Justify("", 1025), " ", "x")
    ; tCase(n) = $ListBuild(field, code, schema-refused), tPatch(n) = the fields replaced.
    Set tCase($Increment(tCase)) = $ListBuild("IssuerEndpoint", "OAUTH.SERVERISSUER.REQUIRED", 0), tPatch(tCase) = {"IssuerEndpoint": ""}
    Set tCase($Increment(tCase)) = $ListBuild("IssuerEndpoint", "OAUTH.SERVERISSUER.SHAPE", 0), tPatch(tCase) = {"IssuerEndpoint": "http://ocupilotprobe127.invalid/probe"}
    Set tCase($Increment(tCase)) = $ListBuild("IssuerEndpoint", "OAUTH.SERVERISSUER.SHAPE", 0), tPatch(tCase) = {"IssuerEndpoint": "https://ocupilotprobe127.invalid/probe?x=1"}
    Set tCase($Increment(tCase)) = $ListBuild("AccessTokenInterval", "OAUTH.INTERVAL.VALUE", 0), tPatch(tCase) = {"AccessTokenInterval": 0}
    Set tCase($Increment(tCase)) = $ListBuild("SessionInterval", "OAUTH.INTERVAL.VALUE", 0), tPatch(tCase) = {"SessionInterval": -1}
    Set tCase($Increment(tCase)) = $ListBuild("RefreshTokenInterval", "OAUTH.INTERVAL.VALUE", 0), tPatch(tCase) = {"RefreshTokenInterval": 1.5}
    Set tCase($Increment(tCase)) = $ListBuild("SupportedScopes", "OAUTH.SCOPES.REQUIRED", 0), tPatch(tCase) = {"SupportedScopes": []}
    Set tCase($Increment(tCase)) = $ListBuild("SupportedScopes", "OAUTH.SCOPES.SHAPE", 0), tPatch(tCase) = {"SupportedScopes": [{"Scope": "two words", "Description": ""}]}
    Set tCase($Increment(tCase)) = $ListBuild("SupportedScopes", "OAUTH.SCOPES.DUPLICATE", 0), tPatch(tCase) = {"SupportedScopes": [{"Scope": "a", "Description": ""}, {"Scope": "a", "Description": ""}]}
    Set tCase($Increment(tCase)) = $ListBuild("DefaultScope", "OAUTH.DEFAULTSCOPE.SHAPE", 0), tPatch(tCase) = {}
    Do tPatch(tCase).%Set("DefaultScope", "openid" _ $Char(9) _ "profile", "string")
    Set tCase($Increment(tCase)) = $ListBuild("Description", "OAUTH.SERVERDESCRIPTION.LENGTH", 0), tPatch(tCase) = {}
    Do tPatch(tCase).%Set("Description", tLong, "string")
    Set tCase($Increment(tCase)) = $ListBuild("ReturnRefreshToken", "OAUTH.RETURNREFRESHTOKEN.VALUE", 0), tPatch(tCase) = {"ReturnRefreshToken": "zz"}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.grant_types_supported", "OAUTH.GRANTTYPES.REQUIRED", 0), tPatch(tCase) = {"Metadata": {"grant_types_supported": ["refresh_token"]}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.grant_types_supported", "OAUTH.GRANTTYPES.VALUE", 0), tPatch(tCase) = {"Metadata": {"grant_types_supported": ["authorization_code", "bogus"]}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.op_policy_uri", "OAUTH.METADATAURL.SHAPE", 0), tPatch(tCase) = {"Metadata": {"op_policy_uri": "ftp://ocupilotprobe127.invalid/policy"}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.token_endpoint_auth_methods_supported", "OAUTH.SERVERMETADATA.MEMBER", 0), tPatch(tCase) = {"Metadata": {"token_endpoint_auth_methods_supported": ["bogus"]}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.frontchannel_logout_supported", "OAUTH.FLAG.VALUE", 0), tPatch(tCase) = {"Metadata": {"frontchannel_logout_supported": "yes"}}
    Set tCase($Increment(tCase)) = $ListBuild("AudRequired", "OAUTH.FLAG.VALUE", 1), tPatch(tCase) = {"AudRequired": "yes"}
    Set tCase($Increment(tCase)) = $ListBuild("SigningAlgorithm", "OAUTH.ALGORITHM.VALUE", 0), tPatch(tCase) = {"SigningAlgorithm": "XX"}
    Set tCase($Increment(tCase)) = $ListBuild("EncryptionAlgorithm", "OAUTH.ENCRYPTION.PAIR", 0), tPatch(tCase) = {"EncryptionAlgorithm": "A128CBC-HS256"}
    Set tCase($Increment(tCase)) = $ListBuild("CustomizationNamespace", "OAUTH.CUSTOMIZATIONNAMESPACE.ABSENT", 0), tPatch(tCase) = {"CustomizationNamespace": "OCUPILOTNOSUCHNS"}
    Set tCase($Increment(tCase)) = $ListBuild("AuthenticateClass", "OAUTH.CUSTOMIZATIONCLASS.REQUIRED", 0), tPatch(tCase) = {"AuthenticateClass": ""}
    Set tCase($Increment(tCase)) = $ListBuild("SessionClass", "OAUTH.CUSTOMIZATIONCLASS.ABSENT", 0), tPatch(tCase) = {"SessionClass": "OcuPilot.No.Such.Class"}
    Set tCase($Increment(tCase)) = $ListBuild("CustomizationRoles", "OAUTH.CUSTOMIZATIONROLES.REQUIRED", 0), tPatch(tCase) = {"CustomizationRoles": []}
    Set tCase($Increment(tCase)) = $ListBuild("CustomizationRoles", "OAUTH.CUSTOMIZATIONROLES.ABSENT", 0), tPatch(tCase) = {"CustomizationRoles": ["OcuPilotNoSuchRole127"]}
    Set tCase($Increment(tCase)) = $ListBuild("SSLConfiguration", "OAUTH.SSLCONFIGURATION.ABSENT", 0), tPatch(tCase) = {"SSLConfiguration": "OcuPilotNoSuchSsl127"}
    Set tCase($Increment(tCase)) = $ListBuild("ServerCredentials", "OAUTH.SERVERCREDENTIALS.ABSENT", 0), tPatch(tCase) = {"ServerCredentials": "OcuPilotNoSuchCredential127"}
    For tI = 1:1:tCase {
        Set tField = $List(tCase(tI), 1)
        Set tCode = $List(tCase(tI), 2)
        Set tArgs = $ClassMethod(..#PROBE, "Body", tPatch(tI))
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Create", tArgs, .tHttp, .tFault, .tViolations, .tIssuer)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, tField), tCode, "case " _ tI _ ": the Save refuses " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing")
        Set tMintArgs = ##class(%DynamicAbstractObject).%FromJSON(tArgs.%ToJSON())
        Do tMintArgs.%Set("Name", ..Id(), "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tMintArgs, .tProposal, .tHttp, .tFault)
        If $List(tCase(tI), 3) {
            Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400), "case " _ tI _ ": and the agent's mint refuses it by the schema")
        } Else {
            Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
            Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ("'" _ tField _ "': " _ tReason)), "case " _ tI _ ": and the agent's mint refuses it with the field's sentence: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds"), 0, "no configuration was created")
}

/// <p>AC7's AD-54 half: the agent's create is minted composed, with a diff row per field supplied and
/// every other template field counted unchanged; a configuration made after the mint refuses the
/// confirm, which sends nothing: the vendor's upsert would otherwise overwrite it.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.OAuthAuthorizationServerCreate.CREATES</parameter>
/// 0 -- the mint reads the absent configuration as gone and this goes red.</p>
Method TestACreateTakenAfterTheMintIsRefusedAtConfirm()
{
    Set tArgs = $ClassMethod(..#PROBE, "Body", {"Description": "late"})
    Do tArgs.%Set("Name", ..Id(), "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, ..Id(), tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tFields = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tFields = tFields _ $ListBuild(tRow.%Get("field")) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tFields), "CustomizationRoles,Description,IssuerEndpoint,SupportedScopes", "a diff row per field supplied")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 25, "and the other template fields unchanged")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", {"Description": "somebody else's"}), "then somebody else makes the configuration")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored").%Get("Description"), "somebody else's", "so the other configuration is unchanged")
}

/// <p>AD-29: the port refuses a caller without either of its two pairs 403 before any vendor call,
/// naming that pair, on a read and on a write alike.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.OAuthAuthorizationServerPort.Invoke</method>'s
/// <method>OcuPilot.Port.OAuthAuthorizationServerPort.RefusedPair</method> check -- the calls reach the
/// vendor and this goes red.</p>
Method TestThePortRefusesACallerWithoutAPairBeforeTheVendor()
{
    Set tPairs = $Parameter("OcuPilot.Port.OAuthAuthorizationServerPort", "GATEPAIRS")
    Do $$$AssertEquals(tPairs, "%Admin_OAuth2_Server:USE,%DB_IRISSYS:READ", "the port's pairs are the tab's two")
    For tI = 1:1:$Length(tPairs, ",") {
        Set tPair = $Piece(tPairs, ",", tI)
        Do $ClassMethod(..#RECORD, "Clear")
        For tType = "GET", "PUT", "ROTATEKEYS", "CHANGEPWD", "DELETE" Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, tType, 500)
        Do $ClassMethod(..#RECORD, "DenyPair", tPair)
        Kill tQuery
        Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..FaultOf($Get(tFault)), "403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " " _ tPair, tPair _ ": a read is refused naming the pair")
        Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "PUT", .tQuery, $ClassMethod(..#PROBE, "Body"), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Piece(..FaultOf($Get(tFault)), " ", 2), "403 " _ tPair, tPair _ ": and so is a write")
        Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, "ROTATEKEYS", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Piece(..FaultOf($Get(tFault)), " ", 2), "403 " _ tPair, tPair _ ": and so is a rotation")
        Set tReached = 0
        For tType = "GET", "PUT", "ROTATEKEYS", "CHANGEPWD", "DELETE" Set tReached = tReached + $ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, tType)
        Do $$$AssertEquals(tReached, 0, tPair _ ": before any vendor call")
    }
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds"), 0, "and nothing was created")
}

/// <p>A port fault as <code>&lt;code&gt; &lt;failed pair&gt;</code>, each empty when absent.</p>
ClassMethod FaultOf(pFault) As %String
{
    If '$IsObject(pFault) Quit " "
    Set tDetail = pFault.%Get("detail")
    Quit pFault.%Get("code") _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

/// <p>A request over the wire as the test account, answering the status and the raw body.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
}

}
