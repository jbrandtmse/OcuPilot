/// <p>Pins Story 12.8's server client create (AD-3, AD-10, AD-39, AD-54, AD-55): what the five tools
/// and the editor's descriptor declare, one create through the Save route, a registered name refused on
/// both callers, a create with no authorization server configuration named, every form rule refused on
/// both callers before anything is sent, a create's secret required unless the client is public, a
/// create taken after the mint refused at its confirm, every rule code reading its sentence, and the
/// port refusing a caller without one of its pairs before any vendor call.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%All</code>, no authorization server configuration and no registered client, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes the
/// instance's configuration and clients (<class>OcuPilot.Test.OAuthRegisteredClientProbe</class>).</p>
Class OcuPilot.Test.OAuthRegisteredClientCreate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthRegisteredClientCreate";

Parameter TAB = "OcuPilot.Screen.Descriptor.OAuthServerClientTab";

Parameter FORM = "OcuPilot.Screen.Descriptor.OAuthServerClientForm";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.OAuthRegisteredClientSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthRegisteredClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthRegisteredClientRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthRegisteredClientProbe";

/// <p>The 12.4 probe, whose mint and listing helpers take any tool.</p>
Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.ServerClients";

Parameter CREATEPATH = "/oauth/server-client";

/// <p>The eight template fields, sorted.</p>
Parameter TEMPLATE = "ClientCredentials,ClientType,DefaultScope,Description,LaunchURL,Metadata,Name,RedirectURL";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthRegisteredClientCreate creates and deletes this instance's OAuth 2.0 authorization server configuration and clients and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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

/// <p>The five tools are write tools over the tab, reached through the server client port, each
/// requiring exactly the tab's pairs; each declares its own request types, body, change and row
/// action; each action write's subject is adequate; and each description says nothing changes until
/// the user confirms.</p>
Method TestTheFiveToolsAreDeclaredOverTheTabAndThePort()
{
    ; name|class|read|write|sends body|change|destructive|screen actions|creates
    Set tRows = $ListBuild("create|OAuthRegisteredClientCreate|LIST|POST|1|created|0||1", "update|OAuthRegisteredClientUpdate|GET|PUT|1|updated|0||0", "setsecret|OAuthRegisteredClientSetSecret|GET|SECRET|0|updated|1||0", "updatejwks|OAuthRegisteredClientUpdateJwks|JWKS|REFRESHJWKS|0|updated|0|updatejwks|0", "delete|OAuthServerClientDelete|GET|DELETE|0|deleted|1|delete|0")
    Set tTabPairs = $ClassMethod(..#TAB, "PrivilegePairs")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tName = "security.oauthserverclients." _ $Piece(tRow, "|", 1)
        Set tClass = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 2)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ ": the registry resolves it")
        If '$IsObject($Get(tTool)) Continue
        Do $$$AssertEquals(tTool.%Get("class") _ " " _ tTool.%Get("kind"), tClass _ " write", tName _ ": a write tool of its own class")
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), ..#TAB, tName _ ": over the tab")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.OAuthRegisteredClientPort", tName _ ": through the server client port")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint"), ..#ENDPOINT, tName _ ": on the clients' endpoint")
        Set tDeclared = $ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ListToString($ClassMethod(tClass, "ScreenActionIds")) _ "|" _ $ClassMethod(tClass, "Creates")
        Do $$$AssertEquals(tDeclared, $Piece(tRow, "|", 3, 9), tName _ ": its read, write, body, change, treatment, row action and kind")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PrivilegePairs")), $ListToString(tTabPairs), tName _ ": requiring the tab's own pairs")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, $ClassMethod(tClass, "WriteType")), tName _ ": the port admits its write")
        If '$ClassMethod(tClass, "SendsBody") Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": its subject is adequate")
        Do $$$AssertTrue($Parameter(tClass, "DESCRIPTION") [ "by itself", tName _ ": its description says nothing changes until the user confirms")
    }
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret", "SecretBodyNames")) _ " " _ $ListToString($ClassMethod(..#TAB, "SecretArguments")), "ClientSecret ClientSecret", "the secret tool's body is the one secret the tab declares")
}

/// <p>The create's settable set is the eight template fields, which are the prohibited set's reviewed
/// create and change lists; its schema adds the metadata as an object, takes no secret, and requires
/// the name and the redirect URLs.</p>
Method TestTheSchemaAndTheSettableSetAreTheTemplatesFields()
{
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#TOOL, "SettableFields")), ..#TEMPLATE, "the eight template fields")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedCreateFields", "oauth2-server-client")), ..#TEMPLATE, "the prohibited set's create list")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedChangeFields", "oauth2-server-client")), ..#TEMPLATE, "and its change list")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("RedirectURL").%Get("type") _ " " _ tProperties.%Get("Metadata").%Get("type") _ " " _ tProperties.%Get("ClientType").%Get("type"), "array object string", "the redirect URLs, the metadata and the client type are typed")
    Do $$$AssertEquals(tProperties.%GetTypeOf("ClientSecret"), "unassigned", "and the secret is no argument")
    Set tRequired = ""
    Set tIterator = tSchema.%Get("required").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) { Set tRequired = tRequired _ $ListBuild(tName) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tRequired), "Name,RedirectURL", "requiring the name and the redirect URLs")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "and the schema is one a provider request carries")
}

/// <p>The editor is built and unlisted at the tab's route with the editor suffix, a form page over the
/// server client type with the tab's own pairs and the classic page as its key, its secret secret-typed
/// in its context; the tab offers Create, Delete and Update JWKS, declares the secret, and declares no
/// classic link-out.</p>
Method TestTheEditorIsBuiltUnlistedOverTheTabsPairs()
{
    Do $$$AssertEquals($ClassMethod(..#FORM, "Route"), $ClassMethod(..#TAB, "Route") _ "/edit", "the editor's route is the tab's with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(..#FORM, "IsBuilt") _ " " _ (+$ClassMethod(..#FORM, "SideBarPosition")), "1 0", "built and unlisted")
    Do $$$AssertEquals($ClassMethod(..#FORM, "Archetype") _ " " _ $ClassMethod(..#FORM, "PrimaryEntityType"), "form-page oauth2-server-client", "a form page over the server client type")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "PrivilegePairs")), $ListToString($ClassMethod(..#TAB, "PrivilegePairs")), "requiring exactly the tab's pairs")
    Do $$$AssertEquals($ClassMethod(..#FORM, "ClassicPage"), "%CSP.UI.Portal.OAuth2.Server.Client", "keyed by the classic client page")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "ContextSecretFields")), "ClientSecret", "its secret is secret-typed in its context")
    Do $$$AssertEquals($ClassMethod(..#TAB, "PrimaryActionId") _ " " _ $ListToString($ClassMethod(..#TAB, "RowActionIds")), "create delete,updatejwks", "the tab offers Create, Delete and Update JWKS")
    Set tSC = $ClassMethod(..#TAB, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the tab's declaration reads")
    If $IsObject($Get(tDeclaration)) Do $$$AssertEquals(tDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "and declares no classic link-out")
}

/// <p>AC1 over the wire: a create through <code>POST /oauth/server-client</code> answers 201 with the
/// generated client id, and the instance, the port's read and the tab's read hold every value entered;
/// the secret is stored. Through the Save's own class the writes are the create, then one secret write
/// carrying the secret alone.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthRegisteredClientSave.HandleCreate</method>
/// skips the secret write -- the stored-secret and write-order assertions go red.</p>
Method TestACreateThroughTheRouteStoresEveryValue()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tName = $ClassMethod(..#PROBE, "Name", "Route")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "route")
    Set tBody = $ClassMethod(..#PROBE, "Body", tName, {"Description": "created by the probe", "LaunchURL": "https://app.ocupilotprobe128.invalid/launch", "DefaultScope": "openid", "Metadata": {"grant_types": ["authorization_code", "client_credentials"], "response_types": ["code"], "token_endpoint_auth_method": "client_secret_post", "client_name": "Probe client", "logo_uri": "https://app.ocupilotprobe128.invalid/logo.png", "contacts": ["ops@ocupilotprobe128.invalid"], "default_max_age": 600}})
    Do tBody.%Set("RedirectURL", [($ClassMethod(..#PROBE, "Url", "one")), ($ClassMethod(..#PROBE, "Url", "two"))])
    Do tBody.%Set("ClientSecret", tSecret, "string")
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 201, "the create answers 201")
    Do $$$AssertEquals(tRaw [ tSecret, 0, "and its answer carries no secret")
    Set tId = ""
    Try { Set tId = ##class(%DynamicObject).%FromJSON(tRaw).%Get("clientId") } Catch { Set tId = "" }
    Do $$$AssertEquals(tId, $ClassMethod(..#PROBE, "IdOf", tName), "naming the client id the instance generated")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tId)
    Do $$$AssertTrue($IsObject(tStored), "the instance holds the client")
    If '$IsObject(tStored) Quit
    Set tMetadata = tStored.%Get("Metadata")
    Set tSeen = tStored.%Get("Name") _ "|" _ tStored.%Get("ClientType") _ "|" _ tStored.%Get("Description") _ "|" _ tStored.%Get("LaunchURL") _ "|" _ tStored.%Get("DefaultScope") _ "|" _ tStored.%Get("RedirectURL")
    Do $$$AssertEquals(tSeen, tName _ "|confidential|created by the probe|https://app.ocupilotprobe128.invalid/launch|openid|" _ $ClassMethod(..#PROBE, "Url", "one") _ "," _ $ClassMethod(..#PROBE, "Url", "two"), "with every field entered")
    Set tMembers = tMetadata.%Get("grant_types").%ToJSON() _ "|" _ tMetadata.%Get("response_types").%ToJSON() _ "|" _ tMetadata.%Get("token_endpoint_auth_method") _ "|" _ tMetadata.%Get("client_name") _ "|" _ tMetadata.%Get("logo_uri") _ "|" _ tMetadata.%Get("contacts").%ToJSON() _ "|" _ tMetadata.%Get("default_max_age")
    Do $$$AssertEquals(tMembers, "[""authorization_code"",""client_credentials"",""refresh_token""]|[""code""]|client_secret_post|Probe client|https://app.ocupilotprobe128.invalid/logo.png|[""ops@ocupilotprobe128.invalid""]|600", "and every member entered")
    Do $$$AssertEquals(tMetadata.%Get("id_token_signed_response_alg") _ " " _ tMetadata.%Get("userinfo_signed_response_alg"), "RS256 none", "with the classic page's values for every member left out")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretIs", tId, tSecret), "and the instance stores the secret entered")
    Set tRead = $ClassMethod(..#PROBE, "Read", tId)
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%ToJSON() '[ tSecret), "the port's read answers it with no secret")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#TAB, "", .tResult, .tHttp, .tFault)
    Set tListed = 0
    If $IsObject($Get(tResult)) {
        Set tIterator = tResult.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) { If tRow.%Get("ClientId") = tId Set tListed = 1 }
    }
    Do $$$AssertTrue(tListed, "and the tab's read lists it")
    Set tName = $ClassMethod(..#PROBE, "Name", "Order")
    Set tSecret = $ClassMethod(..#PROBE, "Secret", "order")
    Set tBody = $ClassMethod(..#PROBE, "Body", tName)
    Do tBody.%Set("ClientSecret", tSecret, "string")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "POST", "", tBody, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 201, "a second create answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastBody", "SECRET"), "POST,SECRET ClientSecret", "the create, then one secret write carrying the secret alone")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastBody", "POST") [ tSecret, 0, "and the create carries no secret")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SecretIs", $ClassMethod(..#PROBE, "IdOf", tName), tSecret), "which the instance stores")
}

/// <p>AC9: a client registered through the Save route is named on the card of an authorization server
/// update, Story 12.7's consumer of the clients this editor writes.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthAuthorizationServerPort.Read</method> answers
/// <code>Clients</code> as <code>[]</code> -- the card's row names no client and this goes red.</p>
Method TestARegisteredClientIsNamedOnTheAuthorizationServersCard()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tName = $ClassMethod(..#PROBE, "Name", "Card")
    Set tBody = $ClassMethod(..#PROBE, "Body", tName)
    Do tBody.%Set("ClientSecret", $ClassMethod(..#PROBE, "Secret", "card"), "string")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "POST", "", tBody, .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 201, "the client is registered through the Save: " _ $Extract(tRaw, 1, 300))
    Set tId = $ClassMethod(..#PROBE, "IdOf", tName)
    Set tSingleton = ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
    Set tArgs = {"Description": "card"}
    Do tArgs.%Set("Name", tSingleton, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", "OcuPilot.Screen.Tool.OAuthAuthorizationServerUpdate", tSingleton, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the authorization server update is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) { If tEntry.%Get("field") = "Clients" Set tRow = tEntry.%Get("before") }
    Do $$$AssertEquals(tRow, tName _ " (" _ tId _ ")", "and its card's Clients row names the client")
}

/// <p>A name any registered client holds, in any case, refuses the create on both callers: the Save
/// answers <code>OAUTH.SERVERCLIENTNAME.TAKEN</code> on <code>Name</code> with nothing sent, and the
/// agent's mint refuses the present target (AD-54).</p>
Method TestATakenNameIsRefusedOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tName = $ClassMethod(..#PROBE, "Name", "Taken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", tName, .tClientId), "a client is registered")
    Set tOther = $ZConvert(tName, "L")
    Set tSC = $ClassMethod(..#SCREEN, "Create", $ClassMethod(..#PROBE, "Body", tOther), 1, .tHttp, .tFault, .tViolations, .tId, .tCreated)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "Name"), "OAUTH.SERVERCLIENTNAME.TAKEN", "the Save refuses the name in another case")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Set tArgs = $ClassMethod(..#PROBE, "Body", tOther)
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tOther, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "already present"), "and the agent's mint refuses the present target: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 1, "and only the first client is registered")
}

/// <p>Matrix row "Create, no configuration": with no authorization server configuration the create is
/// refused 422 <code>OAUTH.SERVERCLIENTCONFIG.ABSENT</code>, the vendor's own refusal named, and nothing
/// is stored.</p>
Method TestACreateWithNoConfigurationIsNamed()
{
    Set tBody = $ClassMethod(..#PROBE, "Body", $ClassMethod(..#PROBE, "Name", "NoConfig"))
    Do tBody.%Set("ClientSecret", $ClassMethod(..#PROBE, "Secret", "noconfig"), "string")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "POST", "", tBody, .tRaw, .tStatus)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch { Set tCode = "" }
    Do $$$AssertEquals(tStatus _ " " _ tCode, "422 OAUTH.SERVERCLIENTCONFIG.ABSENT", "the create is refused naming the missing configuration: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes"), "POST", "after the create alone, no secret write")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 0, "and nothing is stored")
}

/// <p>A create's secret is required unless the client is public, because the one the vendor generates
/// is never shown: a confidential client without one is refused
/// <code>OAUTH.SERVERCLIENTSECRET.REQUIRED</code> with nothing sent, and a public client without one is
/// registered.</p>
Method TestACreatesSecretIsRequiredUnlessPublic()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tSC = $ClassMethod(..#SCREEN, "Create", $ClassMethod(..#PROBE, "Body", $ClassMethod(..#PROBE, "Name", "NoSecret")), 0, .tHttp, .tFault, .tViolations, .tId, .tCreated)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "ClientSecret"), "OAUTH.SERVERCLIENTSECRET.REQUIRED", "a confidential client needs a secret")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Set tName = $ClassMethod(..#PROBE, "Name", "Public")
    Set tSC = $ClassMethod(..#SCREEN, "Handle", "POST", "", $ClassMethod(..#PROBE, "Body", tName, {"ClientType": "public"}), .tRaw, .tStatus)
    Do $$$AssertEquals(tStatus, 201, "a public client needs none: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes"), "POST", "and no secret write is sent")
    Do $$$AssertNotEquals($ClassMethod(..#PROBE, "IdOf", tName), "", "and it is registered")
}

/// <p>Every form rule refuses on both callers, on the field it names, with nothing sent: the screen's
/// Save answers the field's violation and the agent's mint the field's sentence.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthRegisteredClientRules.MetadataViolations</method>
/// skips the display-URL host rule -- the logo case goes red on both callers.</p>
Method TestEveryFormRuleRefusesOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tFar = "https://" _ $Parameter(..#PROBE, "OTHERHOST") _ "/logo.png"
    ; tCase(n) = $ListBuild(field, code), tPatch(n) = the fields replaced.
    Set tCase($Increment(tCase)) = $ListBuild("ClientType", "OAUTH.SERVERCLIENTTYPE.VALUE"), tPatch(tCase) = {"ClientType": "other"}
    Set tCase($Increment(tCase)) = $ListBuild("RedirectURL", "OAUTH.REDIRECTURL.REQUIRED"), tPatch(tCase) = {"RedirectURL": []}
    Set tCase($Increment(tCase)) = $ListBuild("RedirectURL", "OAUTH.REDIRECTURL.SHAPE"), tPatch(tCase) = {"RedirectURL": ["/relative/cb"]}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.grant_types", "OAUTH.CLIENTGRANTTYPES.REQUIRED"), tPatch(tCase) = {"Metadata": {"grant_types": ["refresh_token"]}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.grant_types", "OAUTH.CLIENTGRANTTYPES.VALUE"), tPatch(tCase) = {"Metadata": {"grant_types": ["authorization_code", "bogus"]}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.response_types", "OAUTH.RESPONSETYPES.REQUIRED"), tPatch(tCase) = {"Metadata": {"response_types": []}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.response_types", "OAUTH.RESPONSETYPES.VALUE"), tPatch(tCase) = {"Metadata": {"response_types": ["code", "bogus"]}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.token_endpoint_auth_method", "OAUTH.AUTHMETHOD.VALUE"), tPatch(tCase) = {"Metadata": {"token_endpoint_auth_method": "bogus"}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.id_token_signed_response_alg", "OAUTH.ALGORITHM.VALUE"), tPatch(tCase) = {"Metadata": {"id_token_signed_response_alg": "XX"}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.id_token_encrypted_response_enc", "OAUTH.ENCRYPTION.PAIR"), tPatch(tCase) = {"Metadata": {"id_token_encrypted_response_enc": "A128CBC-HS256"}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.logo_uri", "OAUTH.CLIENTURL.HOST"), tPatch(tCase) = {"Metadata": {"logo_uri": (tFar)}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.policy_uri", "OAUTH.METADATAURL.SHAPE"), tPatch(tCase) = {"Metadata": {"policy_uri": "ftp://app.ocupilotprobe128.invalid/policy"}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.contacts", "OAUTH.CONTACTS.SHAPE"), tPatch(tCase) = {"Metadata": {"contacts": ["not an address"]}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.default_max_age", "OAUTH.MAXAGE.VALUE"), tPatch(tCase) = {"Metadata": {"default_max_age": -1}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.frontchannel_logout_session_required", "OAUTH.FLAG.VALUE"), tPatch(tCase) = {"Metadata": {"frontchannel_logout_session_required": "yes"}}
    Set tCase($Increment(tCase)) = $ListBuild("Metadata.client_secret", "OAUTH.METADATA.UNKNOWN"), tPatch(tCase) = {"Metadata": {"client_secret": "ocupilotruleprobe000"}}
    Set tCase($Increment(tCase)) = $ListBuild("LaunchURL", "OAUTH.LAUNCHURL.SHAPE"), tPatch(tCase) = {"LaunchURL": "not a url"}
    Set tCase($Increment(tCase)) = $ListBuild("DefaultScope", "OAUTH.DEFAULTSCOPE.SHAPE"), tPatch(tCase) = {}
    Do tPatch(tCase).%Set("DefaultScope", "openid" _ $Char(9) _ "profile", "string")
    Set tCase($Increment(tCase)) = $ListBuild("ClientCredentials", "OAUTH.CLIENTCREDENTIALS.ABSENT"), tPatch(tCase) = {"ClientCredentials": "OcuPilotNoSuchCredential128"}
    For tI = 1:1:tCase {
        Set tField = $List(tCase(tI), 1)
        Set tCode = $List(tCase(tI), 2)
        Set tName = $ClassMethod(..#PROBE, "Name", "Rule" _ tI)
        Set tArgs = $ClassMethod(..#PROBE, "Body", tName, tPatch(tI))
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Create", tArgs, 1, .tHttp, .tFault, .tViolations, .tId, .tCreated)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, tField), tCode, "case " _ tI _ ": the Save refuses " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing")
        Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ("'" _ tField _ "': " _ tReason)), "case " _ tI _ ": and the agent's mint refuses it with the field's sentence: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 0, "no client was registered")
}

/// <p>AC6's AD-54 half: the agent's create is minted composed, with a diff row per field supplied and
/// every other template field counted unchanged; a client registered under the name after the mint
/// refuses the confirm, which sends nothing.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.OAuthRegisteredClientCreate.CREATES</parameter>
/// 0 -- the mint reads the absent client as gone and this goes red.</p>
Method TestACreateTakenAfterTheMintIsRefusedAtConfirm()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Set tName = $ClassMethod(..#PROBE, "Name", "Late")
    Set tArgs = {"Description": "late"}
    Do tArgs.%Set("Name", tName, "string")
    Do tArgs.%Set("RedirectURL", [($ClassMethod(..#PROBE, "Url"))])
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tFields = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tFields = tFields _ $ListBuild(tRow.%Get("field")) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tFields), "Description,Name,RedirectURL", "a diff row per field supplied")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 5, "and the other template fields unchanged")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", tName, .tClientId), "then somebody else registers the name")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientCount"), 1, "so only the other client is registered")
}

/// <p>AD-29: the port refuses a caller without either of its two pairs 403 before any vendor call and
/// any key-set fetch, naming that pair, on a read and on every write alike.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.OAuthRegisteredClientPort.Invoke</method>'s
/// <method>OcuPilot.Port.OAuthRegisteredClientPort.RefusedPair</method> check -- the calls reach the
/// vendor and this goes red.</p>
Method TestThePortRefusesACallerWithoutAPairBeforeTheVendor()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed"), "a configuration is seeded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedClient", $ClassMethod(..#PROBE, "Name", "Gate"), .tClientId, {"Metadata": {"jwks_uri": ($Parameter(..#PROBE, "JWKSURL"))}}), "a client with a JWKS URL is registered")
    Set tPairs = $Parameter("OcuPilot.Port.OAuthRegisteredClientPort", "GATEPAIRS")
    Do $$$AssertEquals(tPairs, "%Admin_OAuth2_Registration:USE,%DB_IRISSYS:READ", "the port's pairs are the tab's two")
    Set tTypes = $ListBuild("GET", "LIST", "POST", "PUT", "SECRET", "DELETE", "JWKS", "REFRESHJWKS")
    For tI = 1:1:$Length(tPairs, ",") {
        Set tPair = $Piece(tPairs, ",", tI)
        Do $ClassMethod(..#RECORD, "Clear")
        For tJ = 1:1:$ListLength(tTypes) Do $ClassMethod(..#RECORD, "Arm", ..#ENDPOINT, $List(tTypes, tJ), 500)
        Do $ClassMethod(..#RECORD, "DenyPair", tPair)
        For tJ = 1:1:$ListLength(tTypes) {
            Set tType = $List(tTypes, tJ)
            Kill tQuery
            Set tQuery("clientId") = tClientId
            Set tBody = $Case(tType, "POST": $ClassMethod(..#PROBE, "Body", $ClassMethod(..#PROBE, "Name", "Denied")), "PUT": {"Description": "denied"}, "SECRET": {"ClientSecret": "ocupilotdeniedprobe000"}, : "")
            Set tSC = $ClassMethod(..#RECORD, "Invoke", ..#ENDPOINT, tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ " " _ ..FaultOf($Get(tFault)), "403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " " _ tPair, tPair _ ": " _ tType _ " is refused naming the pair")
        }
        Set tReached = 0
        For tJ = 1:1:$ListLength(tTypes) Set tReached = tReached + $ClassMethod(..#RECORD, "Reached", ..#ENDPOINT, $List(tTypes, tJ))
        Do $$$AssertEquals(tReached _ " " _ $ClassMethod(..#RECORD, "Fetches"), "0 0", tPair _ ": before any vendor call or fetch")
    }
    Do $ClassMethod(..#RECORD, "Clear")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tClientId)
    Do $$$AssertEquals(tStored.%Get("Description") _ " " _ tStored.%Get("PublicKeys") _ " " _ $ClassMethod(..#PROBE, "ClientCount"), " 0 1", "and nothing was changed, fetched, created or deleted")
}

/// <p>Every code the editor's rules produce reads its sentence: each Story 12.8 code reads the
/// <code>REASON</code> parameter of its own name through
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>, each reused code reads a non-empty one, and
/// the form's rules hold one row per code.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Api.Error.ReasonForOAuthAuthorizationServer</method> ends
/// <code>Quit ""</code> -- the Story 12.8 codes read no sentence and this goes red.</p>
Method TestEveryViolationCodeReadsItsSentence()
{
    Set tError = "OcuPilot.Api.Error"
    Set tOwn = $ListBuild("OAUTHSERVERCLIENTNAMEREQUIRED", "OAUTHSERVERCLIENTNAMETAKEN", "OAUTHSERVERCLIENTTYPEVALUE", "OAUTHREDIRECTURLREQUIRED", "OAUTHREDIRECTURLSHAPE", "OAUTHCLIENTGRANTTYPESREQUIRED", "OAUTHCLIENTGRANTTYPESVALUE", "OAUTHCLIENTGRANTTYPESUNSUPPORTED", "OAUTHRESPONSETYPESREQUIRED", "OAUTHRESPONSETYPESVALUE", "OAUTHAUTHMETHODVALUE", "OAUTHCLIENTURLHOST", "OAUTHCONTACTSSHAPE", "OAUTHMAXAGEVALUE", "OAUTHLAUNCHURLSHAPE", "OAUTHSERVERCLIENTSECRETREQUIRED")
    Set tCodes = $ClassMethod(tError, "OAuthServerClientViolationCodes")
    For tI = 1:1:$ListLength(tOwn) {
        Set tName = $List(tOwn, tI)
        Set tCode = $Parameter(tError, tName)
        Set tSentence = $Parameter(tError, "REASON" _ tName)
        Do $$$AssertTrue((tCode '= "") && $ListFind(tCodes, tCode), tName _ ": a code the rules produce")
        Do $$$AssertTrue((tSentence '= "") && ($ClassMethod(tError, "ReasonForViolation", tCode) = tSentence), tName _ ": reads its own sentence")
    }
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals($ClassMethod(tError, "ReasonForViolation", $List(tCodes, tI)), "", $List(tCodes, tI) _ ": reads a sentence")
    }
    Set tRules = ##class(OcuPilot.Area.Security.OAuthRegisteredClientRules).Rules()
    Set tRuled = ""
    Set tIterator = tRules.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRuled = tRuled _ $ListBuild(tRow.%Get("code")) }
    Do $$$AssertEquals(tRules.%Size(), $ListLength(tCodes), "the form's rules hold one row per code")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tRuled), $ClassMethod(..#HELPER, "Sorted", tCodes), "and every code has its row")
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
