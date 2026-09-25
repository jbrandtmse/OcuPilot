/// <p>Pins Story 12.6's resource server create (AD-3, AD-10, AD-39, AD-54, AD-55): what the six resource
/// server tools and the editor's descriptor declare, one create through the Save route carrying the two
/// default mappings, a taken name refused on its field before any write, every form rule refused on
/// both callers before anything is sent, a create whose name is taken after the mint refused at its
/// confirm, the port refusing a caller without one of its pairs before any vendor call, and the form
/// read's count of the instance's resource servers.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes OAuth 2.0 resource servers, service mappings and
/// server descriptions. Every object is an <class>OcuPilot.Test.OAuthResourceServerProbe</class> one,
/// removed by exact name; the <code>*</code> mappings must be held by no other server.</p>
Class OcuPilot.Test.OAuthResourceServerCreate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthResourceServerCreate";

Parameter TAB = "OcuPilot.Screen.Descriptor.OAuthResourceServerTab";

Parameter FORM = "OcuPilot.Screen.Descriptor.OAuthResourceServerForm";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.OAuthResourceServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthResourceServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthResourceServerRecordPort";

Parameter FAIL = "OcuPilot.Test.OAuthResourceServerFailPort";

Parameter PROBE = "OcuPilot.Test.OAuthResourceServerProbe";

/// <p>The 12.4 probe, whose mint and listing helpers take any tool.</p>
Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter ENDPOINT = "Security.OAuth2.ResourceServer";

Parameter CREATEPATH = "/oauth/resource-server";

Parameter FORMPATH = "/oauth/resource-server/form";

/// <p>The eleven template fields, sorted.</p>
Parameter TEMPLATE = "AccessTokenIsJWT,AlwaysCallIntrospection,Audiences,Authenticator,ClientId,Description,Enabled,IntrospectionAuthMethod,IssuerEndpoint,ScopeRequiredToConnect,UseOIDC";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerCreate creates and deletes OAuth 2.0 resource servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $ClassMethod(..#FAIL, "Disarm")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The description the class's servers trust.</p>
ClassMethod Issuer() As %String
{
    Quit $ClassMethod(..#PROBE, "Issuer", "create")
}

/// <p>A create's body for server <var>pName</var>: the fields the form requires.</p>
ClassMethod Body(pName As %String) As %DynamicObject
{
    Set tBody = {"Audiences": ["https://ocupilotprobe126.invalid/api"]}
    Do tBody.%Set("Name", pName, "string")
    Do tBody.%Set("IssuerEndpoint", ..Issuer(), "string")
    Quit tBody
}

/// <p>The six tools are write tools over the tab, reached through the resource server port, named by
/// the server's name, each requiring exactly the tab's pairs; each declares its own request types,
/// body, change and row action; each action write's subject is adequate; and each description says
/// nothing changes until the user confirms.</p>
Method TestTheSixToolsAreDeclaredOverTheTabAndThePort()
{
    ; name|class suffix|read|write|sends body|change|destructive|screen actions|creates
    Set tRows = $ListBuild("create|Create|GET|PUT|1|created|0||1", "update|Update|GET|PUT|1|updated|0||0", "setsecret|SetSecret|GET|CHANGESECRET|0|updated|0||0", "delete|Delete|MAPPINGS|DELETE|0|deleted|1|delete|0", "addmapping|AddMapping|MAPPINGS|ADDMAPPING|0|updated|0||0", "removemapping|RemoveMapping|MAPPINGS|REMOVEMAPPING|0|updated|0||0")
    Set tTabPairs = $ClassMethod(..#TAB, "PrivilegePairs")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tName = "security.oauthresourceservers." _ $Piece(tRow, "|", 1)
        Set tClass = "OcuPilot.Screen.Tool.OAuthResourceServer" _ $Piece(tRow, "|", 2)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ ": the registry resolves it")
        If '$IsObject($Get(tTool)) Continue
        Do $$$AssertEquals(tTool.%Get("class") _ " " _ tTool.%Get("kind"), tClass _ " write", tName _ ": a write tool of its own class")
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), ..#TAB, tName _ ": over the tab")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.OAuthResourceServerPort", tName _ ": through the resource server port")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), ..#ENDPOINT _ " Name name", tName _ ": named by the server's name")
        Set tDeclared = $ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ListToString($ClassMethod(tClass, "ScreenActionIds")) _ "|" _ $ClassMethod(tClass, "Creates")
        Do $$$AssertEquals(tDeclared, $Piece(tRow, "|", 3, 9), tName _ ": its read, write, body, change, treatment, row action and kind")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PrivilegePairs")), $ListToString(tTabPairs), tName _ ": requiring the tab's own pairs")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, $ClassMethod(tClass, "WriteType")), tName _ ": the port admits its write")
        If '$ClassMethod(tClass, "SendsBody") Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": its subject is adequate")
        Do $$$AssertTrue($Parameter(tClass, "DESCRIPTION") [ "by itself", tName _ ": its description says nothing changes until the user confirms")
    }
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.OAuthResourceServerSetSecret", "SecretBodyNames")) _ " " _ $ListToString($ClassMethod(..#TAB, "SecretArguments")), "ClientSecret ClientSecret", "the secret tool's body is the one secret the tab declares")
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.OAuthResourceServerAddMapping", "FingerprintSubject")), "Mappings,Held,Service,Key", "the mapping tools' subject covers this server's mappings, every holder and the mapping named")
}

/// <p>The create's settable set is the eleven template fields, which are the prohibited set's reviewed
/// create and change lists; its schema adds <code>Authenticator</code> as an object, and requires the
/// name, the issuer and the audiences.</p>
Method TestTheSchemaAndTheSettableSetAreTheTemplatesFields()
{
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#TOOL, "SettableFields")), ..#TEMPLATE, "the eleven template fields")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedCreateFields", "oauth2-resource-server")), ..#TEMPLATE, "the prohibited set's create list")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", $ClassMethod(..#SET, "PermittedChangeFields", "oauth2-resource-server")), ..#TEMPLATE, "and its change list")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Keys", tSchema.%Get("properties")), "AccessTokenIsJWT,AlwaysCallIntrospection,Audiences,Authenticator,ClientId,Description,Enabled,IntrospectionAuthMethod,IssuerEndpoint,Name,ScopeRequiredToConnect,UseOIDC,expectedImpact,rationale,reverse", "the schema's properties")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("Authenticator").%Get("type") _ " " _ tSchema.%Get("properties").%Get("Audiences").%Get("type") _ " " _ tSchema.%Get("properties").%Get("Enabled").%Get("type"), "object array boolean", "Authenticator an object, Audiences an array and Enabled a boolean")
    Set tRequired = ""
    Set tIterator = tSchema.%Get("required").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) { Set tRequired = tRequired _ $ListBuild(tName) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tRequired), "Audiences,IssuerEndpoint,Name", "requiring the name, the issuer and the audiences")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "and the schema is one a provider request carries")
}

/// <p>The editor is built and unlisted at the tab's route with the editor suffix, a form page over the
/// resource server type with the tab's own pairs and the classic configuration page as its key, its
/// client secret secret-typed in its context; the tab offers Create and Delete, declares the secret,
/// and declares no classic link-out.</p>
Method TestTheEditorIsBuiltUnlistedOverTheTabsPairs()
{
    Do $$$AssertEquals($ClassMethod(..#FORM, "Route"), $ClassMethod(..#TAB, "Route") _ "/edit", "the editor's route is the tab's with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(..#FORM, "IsBuilt") _ " " _ (+$ClassMethod(..#FORM, "SideBarPosition")), "1 0", "built and unlisted")
    Do $$$AssertEquals($ClassMethod(..#FORM, "Archetype") _ " " _ $ClassMethod(..#FORM, "PrimaryEntityType"), "form-page oauth2-resource-server", "a form page over the resource server type")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "PrivilegePairs")), $ListToString($ClassMethod(..#TAB, "PrivilegePairs")), "requiring exactly the tab's pairs")
    Do $$$AssertEquals($ClassMethod(..#FORM, "ClassicPage"), "%CSP.UI.Portal.OAuth2.ResourceServer.Configuration", "keyed by the classic configuration page")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "ContextSecretFields")), "ClientSecret", "its secret is secret-typed in its context")
    Do $$$AssertEquals($ClassMethod(..#TAB, "PrimaryActionId") _ " " _ $ListToString($ClassMethod(..#TAB, "RowActionIds")), "create delete", "the tab offers Create and Delete")
    Set tSC = $ClassMethod(..#TAB, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the tab's declaration reads")
    If $IsObject($Get(tDeclaration)) Do $$$AssertEquals(tDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "and declares no classic link-out")
}

/// <p>AC1 over the wire: a create through <code>POST /oauth/resource-server</code> carrying the two
/// default mappings answers 201, and the instance, the port's read and the tab's read hold every value
/// entered, with both <code>*</code> mappings held by the new server.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthResourceServerSave.HandleCreate</method>
/// skips the mappings it took out of the body -- the held assertion goes red.</p>
Method TestACreateThroughTheRouteStoresTheDefaultMappings()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Create")
    Set tBody = ..Body(tName)
    Do tBody.%Set("Description", "created by the probe", "string")
    Do tBody.%Set("ScopeRequiredToConnect", "probe.scope", "string")
    Do tBody.%Set("mappingsAdded", [{"Service": "%Service_WebGateway", "Key": "*"}, {"Service": "%Service_Bindings", "Key": "*"}])
    Set tSC = ..Request("POST", ..#CREATEPATH, tBody, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 201, "the create answers 201: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue(tRaw '[ "mappingsRefused", "and stores both mappings")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName)
    Do $$$AssertTrue($IsObject(tStored), "the instance holds the server")
    If '$IsObject(tStored) Quit
    Do $$$AssertEquals(tStored.%Get("Description") _ "|" _ tStored.%Get("ScopeRequiredToConnect") _ "|" _ tStored.%Get("IssuerEndpoint") _ "|" _ tStored.%Get("Audiences").%ToJSON(), "created by the probe|probe.scope|" _ ..Issuer() _ "|[""https://ocupilotprobe126.invalid/api""]", "with every value entered")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "MappingsOf", tName), "%Service_Bindings/*,%Service_WebGateway/*", "and both default mappings held by it")
    Set tRead = $ClassMethod(..#PROBE, "Read", tName)
    If $IsObject(tRead) Do $$$AssertEquals(tRead.%Get("Description") _ "|" _ tRead.%Get("Authenticator").%Get("Implementation"), "created by the probe|%OAuth2.ResourceServer.SimpleAuthenticator", "the port's read answers them, with the default authenticator")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#TAB, "", .tResult, .tHttp, .tFault)
    Set tListed = 0
    If $IsObject($Get(tResult)) {
        Set tIterator = tResult.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) { If tRow.%Get("Name") = tName Set tListed = 1 }
    }
    Do $$$AssertTrue(tListed, "and the tab's read lists it")
}

/// <p>A name a server already carries is refused on its field before any write, and the existing
/// server is unchanged: the vendor's <code>PUT</code> is an upsert.</p>
Method TestATakenNameIsRefusedOnItsField()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Taken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", tName, ..Issuer(), $ListBuild("first"), {"Description": "the first"}), "a server is created")
    Set tBefore = $ClassMethod(..#PROBE, "Stored", tName).%ToJSON()
    Set tBody = ..Body(tName)
    Do tBody.%Set("Description", "the second", "string")
    Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tBody, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "Name"), "OAUTH.RESOURCESERVERNAME.TAKEN", "the Save refuses the name on its field")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%ToJSON(), tBefore, "and the existing server is unchanged")
}

/// <p>Every form rule refuses on both callers, on the field it names, with nothing sent: the screen's
/// Save answers the field's violation and the agent's mint the field's sentence -- or, for a value the
/// tool's schema already refuses by type, a schema refusal.</p>
Method TestEveryFormRuleRefusesOnBothCallers()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Rules")
    Set tLong = $Translate($Justify("", 300), " ", "x")
    ; tCase(n) = $ListBuild(name, field, code, schema-refused), tPatch(n) = the fields replaced.
    Set tCase($Increment(tCase)) = $ListBuild($ClassMethod(..#PROBE, "Name", $Extract(tLong, 1, 120)), "Name", "OAUTH.RESOURCESERVERNAME.SHAPE", 0)
    Set tPatch(tCase) = {}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "IssuerEndpoint", "OAUTH.ISSUERENDPOINT.REQUIRED", 0)
    Set tPatch(tCase) = {"IssuerEndpoint": ""}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "IssuerEndpoint", "OAUTH.ISSUERENDPOINT.ABSENT", 0)
    Set tPatch(tCase) = {"IssuerEndpoint": "https://ocupilotprobe126.invalid/nosuchissuer"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Audiences", "OAUTH.AUDIENCES.REQUIRED", 0)
    Set tPatch(tCase) = {"Audiences": []}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Audiences", "OAUTH.AUDIENCES.SHAPE", 0)
    Set tPatch(tCase) = {}
    Do tPatch(tCase).%Set("Audiences", [(tLong)])
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Audiences", "OAUTH.AUDIENCES.DUPLICATE", 0)
    Set tPatch(tCase) = {"Audiences": ["a", "a"]}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Description", "OAUTH.DESCRIPTION.LENGTH", 0)
    Set tPatch(tCase) = {}
    Do tPatch(tCase).%Set("Description", tLong, "string")
    Set tCase($Increment(tCase)) = $ListBuild(tName, "ScopeRequiredToConnect", "OAUTH.SCOPEREQUIRED.LENGTH", 0)
    Set tPatch(tCase) = {}
    Do tPatch(tCase).%Set("ScopeRequiredToConnect", tLong, "string")
    Set tCase($Increment(tCase)) = $ListBuild(tName, "IntrospectionAuthMethod", "OAUTH.INTROSPECTIONAUTHMETHOD.VALUE", 0)
    Set tPatch(tCase) = {"IntrospectionAuthMethod": "bogus"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "UseOIDC", "OAUTH.FLAG.VALUE", 1)
    Set tPatch(tCase) = {"UseOIDC": "yes"}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Authenticator.Namespace", "OAUTH.AUTHENTICATOR.NAMESPACE", 0)
    Set tPatch(tCase) = {"Authenticator": {"Namespace": "OCUPILOTNOSUCHNS", "Implementation": "%OAuth2.ResourceServer.SimpleAuthenticator"}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Authenticator.Implementation", "OAUTH.AUTHENTICATOR.IMPLEMENTATION", 0)
    Set tPatch(tCase) = {"Authenticator": {"Namespace": "%SYS", "Implementation": "%Library.RegisteredObject"}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Authenticator.Bogus", "OAUTH.AUTHENTICATOR.SETTING", 0)
    Set tPatch(tCase) = {"Authenticator": {"Namespace": "%SYS", "Implementation": "%OAuth2.ResourceServer.SimpleAuthenticator", "Bogus": "x"}}
    Set tCase($Increment(tCase)) = $ListBuild(tName, "Authenticator.UserClaim", "OAUTH.AUTHENTICATOR.SETTING", 0)
    Set tPatch(tCase) = {"Authenticator": {"Namespace": "%SYS", "Implementation": "%OAuth2.ResourceServer.SimpleAuthenticator", "UserClaim": true}}
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
        Set tSC = $ClassMethod(..#SCREEN, "Create", tCaseName, tArgs, [], [], .tHttp, .tFault, .tViolations)
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
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count"), 0, "no server was created")
}

/// <p>AC7's AD-54 half: the agent's create is minted composed, with a diff row per field and no
/// unchanged count; a server created at that name after the mint refuses the confirm, which sends
/// nothing: the vendor's upsert would otherwise overwrite it.</p>
/// <p>Mutation (Rule 19): drop the create's absence read (<parameter>OcuPilot.Screen.Tool.OAuthResourceServerCreate.CREATES</parameter>
/// 0) -- the mint reads the absent target as gone and this goes red.</p>
Method TestACreateTakenAfterTheMintIsRefusedAtConfirm()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Late")
    Set tArgs = ..Body(tName)
    Do tArgs.%Set("Description", "late", "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#TOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tFields = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tFields = tFields _ $ListBuild(tRow.%Get("field")) }
    Do $$$AssertEquals($ClassMethod(..#HELPER, "Sorted", tFields), "Audiences,Description,IssuerEndpoint", "a diff row per field supplied")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and none unchanged")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", tName, ..Issuer(), $ListBuild("other"), {"Description": "somebody else's"}), "then somebody else creates the name")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Description"), "somebody else's", "so the other server is unchanged")
}

/// <p>AD-29: the port refuses a caller without any one of its three pairs 403 before any vendor call,
/// naming that pair, on a read and on a write alike.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.OAuthResourceServerPort.Invoke</method>'s
/// <method>OcuPilot.Port.OAuthResourceServerPort.RefusedPair</method> check -- the calls reach the
/// vendor and this goes red.</p>
Method TestThePortRefusesACallerWithoutAPairBeforeTheVendor()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Gate")
    Set tPairs = $Parameter("OcuPilot.Port.OAuthResourceServerPort", "GATEPAIRS")
    Do $$$AssertEquals(tPairs, "%Admin_Secure:USE,%DB_IRISSYS:READ,%Admin_OAuth2_Client:USE", "the port's pairs are the tab's three")
    For tI = 1:1:$Length(tPairs, ",") {
        Set tPair = $Piece(tPairs, ",", tI)
        Do $ClassMethod(..#FAIL, "Disarm")
        Do $ClassMethod(..#FAIL, "Arm", ..#ENDPOINT, "GET", 500)
        Do $ClassMethod(..#FAIL, "Arm", ..#ENDPOINT, "PUT", 500)
        Do $ClassMethod(..#FAIL, "DenyPair", tPair)
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#FAIL, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals($$$ISERR(tSC) _ " " _ tHttp _ " " _ ..FaultOf($Get(tFault)), "1 403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " " _ tPair, tPair _ ": a read is refused naming the pair")
        Set tSC = $ClassMethod(..#FAIL, "Invoke", ..#ENDPOINT, "PUT", .tQuery, ..Body(tName), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Piece(..FaultOf($Get(tFault)), " ", 2), "403 " _ tPair, tPair _ ": and so is a write")
        Do $$$AssertEquals($ClassMethod(..#FAIL, "Reached", ..#ENDPOINT, "GET") + $ClassMethod(..#FAIL, "Reached", ..#ENDPOINT, "PUT"), 0, tPair _ ": before any vendor call")
    }
    Do $ClassMethod(..#FAIL, "Disarm")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing was created")
}

/// <p>The form read counts every resource server the instance holds, which is what decides whether a
/// create starts with the two default mappings.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.OAuthResourceServerRules.HandleForm</method>
/// answers <code>resourceServerCount</code> 0 -- this goes red.</p>
Method TestTheFormReadCountsTheInstancesServers()
{
    For tSuffix = "CountA", "CountB" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", $ClassMethod(..#PROBE, "Name", tSuffix), ..Issuer(), $ListBuild("aud.count")), "a server is created")
    }
    Set tSC = ..Request("GET", ..#FORMPATH, "", .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the form read answers: " _ $Extract(tRaw, 1, 200))
    Set tCount = ""
    Try { Set tCount = ##class(%DynamicObject).%FromJSON(tRaw).%Get("resourceServerCount") } Catch { Set tCount = "" }
    Do $$$AssertTrue(..InstanceCount() >= 2, "the instance holds the two servers")
    Do $$$AssertEquals(tCount, ..InstanceCount(), "and the form read counts every server it holds")
}

/// <p>A port fault as <code>&lt;code&gt; &lt;failed pair&gt;</code>, each empty when absent.</p>
ClassMethod FaultOf(pFault) As %String
{
    If '$IsObject(pFault) Quit " "
    Set tDetail = pFault.%Get("detail")
    Quit pFault.%Get("code") _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

/// <p>How many resource servers the instance holds, read from the vendor's table in
/// <code>%SYS</code>, or -1 when it cannot be read.</p>
ClassMethod InstanceCount() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OAuth2.ResourceServer")
        If tRS.%Next() Set tCount = tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>A request over the wire as the test account, answering the status and the raw body.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pRaw, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
}

}
