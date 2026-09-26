/// <p>Pins Story 12.5's client configuration create (AD-3, AD-4, AD-10, AD-39, AD-54, AD-55): what the
/// six client configuration tools and the editor's descriptor declare, one create through the screen's
/// Save carrying the complete settable member set, a taken name refused on its field before any write,
/// every form rule refused on both callers before anything is sent, and a create whose name is taken
/// after the mint refused at its confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed with the demo fixture, an account
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// it creates and deletes OAuth 2.0 client configurations and server descriptions. Every write reaches
/// the instance through <class>OcuPilot.Test.OAuthClientRecordPort</class>; every object is an
/// <class>OcuPilot.Test.OAuthClientProbe</class> one, removed by exact name.</p>
Class OcuPilot.Test.OAuthClientCreate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthClientCreate";

Parameter TAB = "OcuPilot.Screen.Descriptor.OAuthClientTab";

Parameter FORM = "OcuPilot.Screen.Descriptor.OAuthClientForm";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.OAuthClientSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthClientConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthClientRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthClientProbe";

/// <p>The 12.4 probe, whose mint and listing helpers take any tool.</p>
Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter RULES = "OcuPilot.Area.Security.OAuthClientRules";

Parameter ENDPOINT = "Security.OAuth2.Client.ClientConfiguration";

/// <p>The twelve template fields, sorted.</p>
Parameter TEMPLATE = "ClientCredentials,ClientId,ClientType,DefaultScope,Description,Enabled,JWTAudience,JWTInterval,Metadata,RedirectionEndpoint,SSLConfiguration,ServerDefinition";

/// <p>The server description the class's clients are configured against, made per method.</p>
Property ServerId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..ServerId = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthClientCreate creates and deletes OAuth 2.0 client configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "AddServer", $ClassMethod(..#PROBE, "Issuer", "create"), .tId)
    Set ..ServerId = $Get(tId)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The description the method's clients are configured against.</p>
Method Server() As %String
{
    Quit ..ServerId
}

/// <p>A create's body for client <var>pName</var>: the fields the form requires, and
/// <var>pMetadata</var>.</p>
Method Body(pName As %String, pMetadata As %DynamicObject = "") As %DynamicObject
{
    Set tBody = {"ClientType": "confidential", "SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG")), "RedirectionEndpoint": ($Parameter(..#PROBE, "REDIRECT"))}
    Do tBody.%Set("ApplicationName", pName, "string")
    Do tBody.%Set("ServerDefinition", ..Server(), "string")
    If $IsObject(pMetadata) Do tBody.%Set("Metadata", pMetadata)
    Quit tBody
}

/// <p>The six tools are write tools over the tab, reached through the client configuration port, named
/// by the application name, each requiring exactly the tab's two pairs; each declares its own request
/// types, body, change and row action; each action write's subject is adequate; and each description
/// says nothing changes until the user confirms.</p>
Method TestTheSixToolsAreDeclaredOverTheTabAndThePort()
{
    ; name|class suffix|read|write|sends body|change|destructive|screen actions|creates
    Set tRows = $ListBuild("create|Create|GET|PUT|1|created|0||1", "update|Update|GET|PUT|1|updated|0||0", "setsecrets|SetSecrets|GET|CHANGESECRET|0|updated|0||0", "rotatekeys|RotateKeys|GET|ROTATEKEYS|0|updated|0|rotatekeys|0", "register|Register|REGISTRATION|REGISTERCLIENT|0|updated|0|register|0", "delete|Delete|GET|DELETE|0|deleted|1|delete|0")
    Set tTabPairs = $ClassMethod(..#TAB, "PrivilegePairs")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tName = "security.oauthclients." _ $Piece(tRow, "|", 1)
        Set tClass = "OcuPilot.Screen.Tool.OAuthClient" _ $Piece(tRow, "|", 2)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ ": the registry resolves it")
        If '$IsObject($Get(tTool)) Continue
        Do $$$AssertEquals(tTool.%Get("class") _ " " _ tTool.%Get("kind"), tClass _ " write", tName _ ": a write tool of its own class")
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), ..#TAB, tName _ ": over the tab")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.OAuthClientPort", tName _ ": through the client configuration port")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), ..#ENDPOINT _ " ApplicationName applicationName", tName _ ": named by the application name")
        Set tDeclared = $ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ListToString($ClassMethod(tClass, "ScreenActionIds")) _ "|" _ $ClassMethod(tClass, "Creates")
        Do $$$AssertEquals(tDeclared, $Piece(tRow, "|", 3, 9), tName _ ": its read, write, body, change, treatment, row action and kind")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PrivilegePairs")), $ListToString(tTabPairs), tName _ ": requiring the tab's own pairs")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, $ClassMethod(tClass, "WriteType")), tName _ ": the port admits its write")
        If '$ClassMethod(tClass, "SendsBody") Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": its subject is adequate")
        Do $$$AssertTrue($Parameter(tClass, "DESCRIPTION") [ "by itself", tName _ ": its description says nothing changes until the user confirms")
    }
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.OAuthClientSetSecrets", "SecretBodyNames")), "ClientSecret,ClientPassword,RegistrationAccessToken", "the secrets tool's body is its three declared secrets alone")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TAB, "SecretArguments")), "ClientSecret,ClientPassword,RegistrationAccessToken", "which the tab declares secret")
}

/// <p>The create's settable set is the twelve template fields, which are the prohibited set's reviewed
/// create and change lists; its schema adds <code>Metadata</code> as an object naming every settable
/// member and no secret or managed one, and requires the name, the description, the client type and
/// the SSL/TLS configuration.</p>
Method TestTheSchemaAndTheSettableSetAreTheTemplatesFields()
{
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#TOOL, "SettableFields")), ..#TEMPLATE, "the twelve template fields")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedCreateFields", "oauth2-client-configuration")), ..#TEMPLATE, "the prohibited set's create list")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedChangeFields", "oauth2-client-configuration")), ..#TEMPLATE, "and its change list")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSchema.%Get("properties")), "ApplicationName," _ ..#TEMPLATE _ ",expectedImpact,rationale,reverse", "the schema's properties")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("Metadata").%Get("type") _ " " _ tSchema.%Get("properties").%Get("Enabled").%Get("type") _ " " _ tSchema.%Get("properties").%Get("JWTInterval").%Get("type"), "object boolean integer", "Metadata an object, Enabled a boolean and the interval an integer")
    Set tSC = $ClassMethod(..#RULES, "Members", .tNames, .tKinds, .tValues)
    Do $$$AssertStatusOK(tSC, "the derived members are read")
    Do $$$AssertEquals($ListLength(tNames), 42, "42 of them")
    Set tText = tSchema.%Get("properties").%Get("Metadata").%Get("description")
    Set (tMissing, tNamed) = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tSettable = $ClassMethod(..#RULES, "Settable", tName)
        If tSettable && '(tText [ (" " _ tName)) Set tMissing = tMissing _ " " _ tName
        If 'tSettable && (tText [ (" " _ tName _ ",")) Set tNamed = tNamed _ " " _ tName
    }
    Do $$$AssertEquals(tMissing, "", "the Metadata description names every settable member")
    Do $$$AssertEquals(tNamed, "", "and no secret or managed one")
    Set tRequired = ""
    Set tIterator = tSchema.%Get("required").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) { Set tRequired = tRequired _ $ListBuild(tName) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tRequired), "ApplicationName,ClientType,SSLConfiguration,ServerDefinition", "requiring the name, the client type, the SSL/TLS configuration and the description")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "and the schema is one a provider request carries")
}

/// <p>The editor is built and unlisted at the tab's route with the editor suffix, a form page over the
/// client configuration type with the tab's own pairs and the classic configuration page as its key,
/// its four secrets secret-typed in its context; the tab offers Create, Delete, Rotate Keys and
/// Register and declares no classic link-out.</p>
Method TestTheEditorIsBuiltUnlistedOverTheTabsPairs()
{
    Do $$$AssertEquals($ClassMethod(..#FORM, "Route"), $ClassMethod(..#TAB, "Route") _ "/edit", "the editor's route is the tab's with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(..#FORM, "IsBuilt") _ " " _ (+$ClassMethod(..#FORM, "SideBarPosition")), "1 0", "built and unlisted")
    Do $$$AssertEquals($ClassMethod(..#FORM, "Archetype") _ " " _ $ClassMethod(..#FORM, "PrimaryEntityType"), "form-page oauth2-client-configuration", "a form page over the client configuration type")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "PrivilegePairs")), $ListToString($ClassMethod(..#TAB, "PrivilegePairs")), "requiring exactly the tab's pairs")
    Do $$$AssertEquals($ClassMethod(..#FORM, "ClassicPage"), "%CSP.UI.Portal.OAuth2.Client.Configuration", "keyed by the classic configuration page")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#FORM, "ContextSecretFields")), "ClientPassword,ClientSecret,InitialAccessToken,RegistrationAccessToken", "its four secrets are secret-typed in its context")
    Do $$$AssertEquals($ClassMethod(..#TAB, "PrimaryActionId") _ " " _ $ListToString($ClassMethod(..#TAB, "RowActionIds")), "create delete,rotatekeys,register", "the tab offers Create, Delete, Rotate Keys and Register")
    Set tSC = $ClassMethod(..#TAB, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the tab's declaration reads")
    If $IsObject($Get(tDeclaration)) Do $$$AssertEquals(tDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "and declares no classic link-out")
}

/// <p>AC1 on the screen's caller: one create through the Save answers with no violation, reaches the
/// port's <code>PUT</code> named by the application name, carrying the entered fields and members and
/// no other member, since a create is composed (AD-54); the instance, the port's read and the tab's
/// read then hold every value entered, beside the vendor's algorithm defaults.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.OAuthClientCreate.DerivedFields</method>
/// removes <code>Metadata</code> from the payload -- the members-entered assertions go red.</p>
Method TestACreateThroughTheSaveSendsTheCompleteSet()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Create")
    Set tMetadata = {"client_name": "Probe", "contacts": ["ops@example.com"], "grant_types": ["authorization_code"], "default_max_age": 60, "frontchannel_logout_session_required": true}
    Set tBody = ..Body(tName, tMetadata)
    Do tBody.%Set("Description", "created by the probe", "string")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tBody, .tHttp, .tFault, .tViolations, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the create completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteTypes") _ " " _ $ClassMethod(..#RECORD, "LastName"), "PUT " _ tName, "one vendor PUT, named by the application name")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSent), "ClientType,Description,Metadata,RedirectionEndpoint,SSLConfiguration,ServerDefinition", "carrying the fields entered; the name travels as the port's query")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSent.%Get("Metadata")), "client_name,contacts,default_max_age,frontchannel_logout_session_required,grant_types", "and exactly the members entered")

    Set tStored = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertTrue($IsObject(tStored), "the instance holds the configuration")
    If '$IsObject(tStored) Quit
    Do $$$AssertEquals(tStored.%Get("ClientType") _ "|" _ tStored.%Get("Description") _ "|" _ tStored.%Get("SSLConfiguration"), "confidential|created by the probe|" _ $Parameter(..#PROBE, "SSLCONFIG"), "with the fields entered")
    Set tStoredMetadata = tStored.%Get("Metadata")
    Do $$$AssertEquals(tStoredMetadata.%Get("client_name") _ "|" _ tStoredMetadata.%Get("contacts").%ToJSON() _ "|" _ tStoredMetadata.%Get("default_max_age") _ "|" _ tStoredMetadata.%Get("frontchannel_logout_session_required"), "Probe|[""ops@example.com""]|60|1", "and the members entered")
    Do $$$AssertEquals(tStoredMetadata.%Get("id_token_signed_response_alg") _ " " _ tStoredMetadata.%Get("token_endpoint_auth_signing_alg"), "RS256 RS256", "with the vendor's algorithm defaults")
    Kill tQuery
    Set tQuery("applicationName") = tName
    Set tSC = ##class(OcuPilot.Port.OAuthClientPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port's GET reads it")
    If $IsObject($Get(tRead)) Do $$$AssertEquals(tRead.%Get("RedirectionEndpoint") _ "|" _ tRead.%Get("Metadata").%Get("grant_types").%ToJSON(), $Parameter(..#PROBE, "REDIRECT") _ "|[""authorization_code""]", "answering every value entered")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#TAB, "", .tResult, .tHttp, .tFault)
    Set tListed = 0
    If $IsObject($Get(tResult)) {
        Set tIterator = tResult.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) { If tRow.%Get("ApplicationName") = tName Set tListed = 1 }
    }
    Do $$$AssertTrue(tListed, "and the tab's read lists it")
}

/// <p>A name a configuration already carries is refused on its field before any write, and the
/// existing configuration is unchanged: the vendor's <code>PUT</code> is an upsert.</p>
Method TestATakenNameIsRefusedOnItsField()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Taken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..Server(), "confidential", {"Description": "the first"}), "a configuration is created")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName).%ToJSON()
    Set tBody = ..Body(tName)
    Do tBody.%Set("Description", "the second", "string")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tBody, .tHttp, .tFault, .tViolations, .tAnswer)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "ApplicationName"), "OAUTH.APPLICATIONNAME.TAKEN", "the Save refuses the name on its field")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%ToJSON(), tBefore, "and the existing configuration is unchanged")
}

/// <p>Every form rule refuses on both callers, on the field it names, with nothing sent: the screen's
/// Save answers the field's violation and the agent's mint the field's sentence -- or, for a value
/// the tool's schema already refuses by type, a schema refusal.</p>
Method TestEveryFormRuleRefusesOnBothCallers()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Rules")
    ; tCase(n) = $ListBuild(name, field, code, schema-refused), tPatch(n) = the fields replaced.
    Set tCase($Increment(tCase)) = $ListBuild($ClassMethod(..#PROBE, "Name", $Translate($Justify("", 120), " ", "x")), "ApplicationName", "OAUTH.APPLICATIONNAME.SHAPE", 0)
    Set tPatch(tCase) = {}
    Set tCase($Increment(tCase)) = $ListBuild($ClassMethod(..#PROBE, "Name", "Tab" _ $Char(9)), "ApplicationName", "OAUTH.APPLICATIONNAME.SHAPE", 0)
    Set tPatch(tCase) = {}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "ServerDefinition", "OAUTH.SERVERDEFINITION.REQUIRED", 0)
    Set tPatch(tCase) = {"ServerDefinition": ""}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "ServerDefinition", "OAUTH.SERVERDEFINITION.ABSENT", 0)
    Set tPatch(tCase) = {"ServerDefinition": "987654321"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "ClientType", "OAUTH.CLIENTTYPE.VALUE", 0)
    Set tPatch(tCase) = {"ClientType": "bogus"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "SSLConfiguration", "OAUTH.SSLCONFIGURATION.REQUIRED", 0)
    Set tPatch(tCase) = {"SSLConfiguration": ""}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "RedirectionEndpoint", "OAUTH.REDIRECTIONENDPOINT.REQUIRED", 0)
    Set tPatch(tCase) = {"RedirectionEndpoint": ""}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "RedirectionEndpoint", "OAUTH.REDIRECTIONENDPOINT.SHAPE", 0)
    Set tPatch(tCase) = {"RedirectionEndpoint": "localhost"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "RedirectionEndpoint", "OAUTH.REDIRECTIONENDPOINT.SHAPE", 0)
    Set tPatch(tCase) = {"RedirectionEndpoint": "ftp://ocupilotprobe125.invalid/cb"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "ClientCredentials", "OAUTH.CLIENTCREDENTIALS.ABSENT", 0)
    Set tPatch(tCase) = {"ClientCredentials": "OcuPilotProbe125NoSuchCredential"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "JWTInterval", "OAUTH.JWTINTERVAL.SHAPE", 1)
    Set tPatch(tCase) = {"JWTInterval": "abc"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Metadata.id_token_signed_response_alg", "OAUTH.METADATA.VALUE", 0)
    Set tPatch(tCase) = {"Metadata": {"id_token_signed_response_alg": "bogus"}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Metadata.default_max_age", "OAUTH.METADATA.SHAPE", 0)
    Set tPatch(tCase) = {"Metadata": {"default_max_age": "abc"}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Metadata.contacts", "OAUTH.METADATA.SHAPE", 0)
    Set tPatch(tCase) = {"Metadata": {"contacts": "ops@example.com"}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Metadata.bogus", "OAUTH.METADATA.UNKNOWN", 0)
    Set tPatch(tCase) = {"Metadata": {"bogus": "x"}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Metadata.registration_client_uri", "OAUTH.METADATA.UNKNOWN", 0)
    Set tPatch(tCase) = {"Metadata": {"registration_client_uri": ""}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Metadata.client_secret", "OAUTH.METADATA.UNKNOWN", 0)
    Set tPatch(tCase) = {"Metadata": {"client_secret": "x"}}
    For tI = 1:1:tCase {
        Set tCaseName = $List(tCase(tI), 1)
        Set tField = $List(tCase(tI), 2)
        Set tCode = $List(tCase(tI), 3)
        Set tArgs = ..Body(tCaseName)
        Set tIterator = tPatch(tI).%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $IsObject(tValue) { Do tArgs.%Set(tKey, tValue) } Else { Do tArgs.%Set(tKey, tValue, tPatch(tI).%GetTypeOf(tKey)) }
        }
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Create", tCaseName, tArgs, .tHttp, .tFault, .tViolations, .tAnswer)
        Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, tField), tCode, "case " _ tI _ ": the Save refuses " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing")
        Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tCaseName, tArgs, .tProposal, .tHttp, .tFault)
        If $List(tCase(tI), 4) {
            Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400), "case " _ tI _ ": and the agent's mint refuses it by the schema")
        } Else {
            Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
            Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ("'" _ tField _ "': " _ tReason)), "case " _ tI _ ": and the agent's mint refuses it with the field's sentence: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count"), 0, "no configuration was created")
}

/// <p>A resource server needs no redirect URL: its create with none completes on both callers.</p>
Method TestAResourceServerNeedsNoRedirect()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Resource")
    Set tBody = ..Body(tName)
    Do tBody.%Set("ClientType", "resource", "string")
    Do tBody.%Set("RedirectionEndpoint", "", "string")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tBody, .tHttp, .tFault, .tViolations, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the create completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("ClientType"), "resource", "and the instance holds a resource server")
}

/// <p>AC7's AD-54 half: the agent's create is minted composed, with a diff row per field and no
/// unchanged count; a configuration created at that name after the mint refuses the confirm, which
/// sends nothing: the vendor's upsert would otherwise overwrite it.</p>
/// <p>Mutation (Rule 19): drop the create's absence read (<parameter>OcuPilot.Screen.Tool.OAuthClientCreate.CREATES</parameter>
/// 0) -- the mint reads the absent target as gone and this goes red.</p>
Method TestACreateTakenAfterTheMintIsRefusedAtConfirm()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Late")
    Set tArgs = ..Body(tName, {"client_name": "Late"})
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tFields = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tFields = tFields _ $ListBuild(tRow.%Get("field")) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tFields), "ClientType,Metadata,RedirectionEndpoint,SSLConfiguration,ServerDefinition", "a diff row per field supplied")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and none unchanged")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, ..Server(), "confidential", {"Description": "somebody else's"}), "then somebody else creates the name")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "somebody else's", "so the other configuration is unchanged")
}

}
