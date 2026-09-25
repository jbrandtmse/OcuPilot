/// <p>Pins Story 12.4's server description create (AD-3, AD-4, AD-10, AD-39, AD-54, AD-55): what the
/// five server description tools and the editor's descriptor declare, one create through the screen's
/// Save carrying the complete member set, a duplicate issuer refused on its field by the rules and by
/// the port's mapping of the vendor's 409, every form rule refused on both callers before anything is
/// sent, and a create whose issuer is taken after the mint refused at its confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed with the demo fixture, an account
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// it creates and deletes OAuth 2.0 server descriptions. Every write reaches the instance through
/// <class>OcuPilot.Test.OAuthServerRecordPort</class>; every description is a
/// <class>OcuPilot.Test.OAuthServerProbe</class> one, removed by exact issuer.</p>
Class OcuPilot.Test.OAuthServerCreate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.OAuthServerDescriptionCreate";

Parameter TAB = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab";

Parameter FORM = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "OcuPilot.Test.OAuthServerSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.OAuthServerConfirm";

Parameter RECORD = "OcuPilot.Test.OAuthServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthServerProbe";

Parameter RULES = "OcuPilot.Area.Security.OAuthServerRules";

Parameter ENDPOINT = "Security.OAuth2.Client.ServerDefinition";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthServerCreate creates and deletes OAuth 2.0 server descriptions on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK(tSC, "every probe description is removed by exact issuer")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The five tools are write tools over the tab, reached through the server description port,
/// named by the issuer, each requiring exactly the tab's two pairs; each declares its own request
/// types, body, change and row action; each action write's subject is adequate; and each description
/// says nothing changes until the user confirms.</p>
Method TestTheFiveToolsAreDeclaredOverTheTabAndThePort()
{
    ; name|class suffix|read|write|sends body|change|destructive|screen actions|creates
    Set tRows = $ListBuild("create|Create|GET|POST|1|created|0||1", "update|Update|GET|PUT|1|updated|0||0", "delete|Delete|GET|DELETE|0|deleted|1|delete|0", "updatejwks|UpdateJwks|JWKS|REFRESHJWKS|0|updated|0|updatejwks|0", "settoken|SetToken|GET|TOKEN|0|updated|0||0")
    Set tTabPairs = $ClassMethod(..#TAB, "PrivilegePairs")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tName = "security.oauthserverdescriptions." _ $Piece(tRow, "|", 1)
        Set tClass = "OcuPilot.Screen.Tool.OAuthServerDescription" _ $Piece(tRow, "|", 2)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ ": the registry resolves it")
        If '$IsObject($Get(tTool)) Continue
        Do $$$AssertEquals(tTool.%Get("class") _ " " _ tTool.%Get("kind"), tClass _ " write", tName _ ": a write tool of its own class")
        Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), ..#TAB, tName _ ": over the tab")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.OAuthServerPort", tName _ ": through the server description port")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), ..#ENDPOINT _ " IssuerEndpoint issuer", tName _ ": named by the issuer")
        Set tDeclared = $ClassMethod(tClass, "ReadType") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ListToString($ClassMethod(tClass, "ScreenActionIds")) _ "|" _ $ClassMethod(tClass, "Creates")
        Do $$$AssertEquals(tDeclared, $Piece(tRow, "|", 3, 9), tName _ ": its read, write, body, change, treatment, row action and kind")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PrivilegePairs")), $ListToString(tTabPairs), tName _ ": requiring the tab's own pairs")
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, $ClassMethod(tClass, "WriteType")), tName _ ": the port admits its write")
        If '$ClassMethod(tClass, "SendsBody") Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": its subject is adequate")
        Do $$$AssertTrue($Parameter(tClass, "DESCRIPTION") [ "by itself", tName _ ": its description says nothing changes until the user confirms")
    }
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.OAuthServerDescriptionSetToken", "SecretBodyNames")), "InitialAccessToken", "the token tool's body is its declared secret alone")
    Do $$$AssertTrue($ListFind($ClassMethod(..#TAB, "SecretArguments"), "InitialAccessToken") > 0, "which the tab declares secret")
}

/// <p>The create's settable set is the four template fields, which are the prohibited set's reviewed
/// create and change lists; its schema adds <code>Metadata</code> as an object naming every derived
/// member, and requires the SSL/TLS configuration and the metadata.</p>
Method TestTheSchemaAndTheSettableSetAreTheTemplatesFields()
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Sorted", $ClassMethod(..#TOOL, "SettableFields")), "IssuerEndpoint,Metadata,SSLConfiguration,ServerCredentials", "the four template fields")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Sorted", $ClassMethod(..#SET, "PermittedCreateFields", "oauth2-server-definition")), "IssuerEndpoint,Metadata,SSLConfiguration,ServerCredentials", "the prohibited set's create list")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Sorted", $ClassMethod(..#SET, "PermittedChangeFields", "oauth2-server-definition")), "IssuerEndpoint,Metadata,SSLConfiguration,ServerCredentials", "and its change list")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Keys", tSchema.%Get("properties")), "IssuerEndpoint,Metadata,SSLConfiguration,ServerCredentials,expectedImpact,rationale,reverse", "the schema's properties")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("Metadata").%Get("type"), "object", "Metadata is an object")
    Set tSC = $ClassMethod(..#RULES, "Members", .tNames, .tKinds)
    Do $$$AssertStatusOK(tSC, "the derived members are read")
    Do $$$AssertEquals($ListLength(tNames), 44, "44 of them")
    Set tText = tSchema.%Get("properties").%Get("Metadata").%Get("description")
    Set tMissing = ""
    For tI = 1:1:$ListLength(tNames) {
        If tText '[ $List(tNames, tI) Set tMissing = tMissing _ " " _ $List(tNames, tI)
    }
    Do $$$AssertEquals(tMissing, "", "the Metadata description names every member")
    Set tRequired = ""
    Set tIterator = tSchema.%Get("required").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) { Set tRequired = tRequired _ $ListBuild(tName) }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Sorted", tRequired), "IssuerEndpoint,Metadata,SSLConfiguration", "requiring the issuer, the SSL/TLS configuration and the metadata")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "and the schema is one a provider request carries")
}

/// <p>The editor is built and unlisted at the tab's route with the editor suffix, a form page over the
/// description type with the tab's own pairs and the classic server configuration page as its key,
/// its token secret-typed in its context; the tab offers Create, Delete and Update JWKS and declares
/// no classic link-out.</p>
Method TestTheEditorIsBuiltUnlistedOverTheTabsPairs()
{
    Do $$$AssertEquals($ClassMethod(..#FORM, "Route"), $ClassMethod(..#TAB, "Route") _ "/edit", "the editor's route is the tab's with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(..#FORM, "IsBuilt") _ " " _ (+$ClassMethod(..#FORM, "SideBarPosition")), "1 0", "built and unlisted")
    Do $$$AssertEquals($ClassMethod(..#FORM, "Archetype") _ " " _ $ClassMethod(..#FORM, "PrimaryEntityType"), "form-page oauth2-server-definition", "a form page over the description type")
    Do $$$AssertEquals($ListToString($ClassMethod(..#FORM, "PrivilegePairs")), $ListToString($ClassMethod(..#TAB, "PrivilegePairs")), "requiring exactly the tab's pairs")
    Do $$$AssertEquals($ClassMethod(..#FORM, "ClassicPage"), "%CSP.UI.Portal.OAuth2.Client.ServerConfiguration", "keyed by the classic server configuration page")
    Do $$$AssertTrue($ListFind($ClassMethod(..#FORM, "ContextSecretFields"), "InitialAccessToken") > 0, "its token is secret-typed in its context")
    Do $$$AssertEquals($ClassMethod(..#TAB, "PrimaryActionId") _ " " _ $ListToString($ClassMethod(..#TAB, "RowActionIds")), "create delete,updatejwks", "the tab offers Create, Delete and Update JWKS")
    Set tSC = $ClassMethod(..#TAB, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the tab's declaration reads")
    If $IsObject($Get(tDeclaration)) Do $$$AssertEquals(tDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "and declares no classic link-out")
}

/// <p>AC1 on the screen's caller: one create through the Save answers with no violation, reaches the
/// port's <code>POST</code> named by the issuer, carrying the template fields and <b>every</b> derived
/// member -- one the body left out empty -- and the instance and the tab's read then hold every value
/// entered.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.OAuthServerDescriptionCreate.DerivedFields</method>
/// removes <code>Metadata</code> from the payload -- the create fails and this goes red.</p>
Method TestACreateThroughTheSaveSendsTheCompleteSet()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Create")
    Set tMetadata = $ClassMethod(..#PROBE, "Metadata", tIssuer, {"userinfo_endpoint": (tIssuer _ "/userinfo"), "scopes_supported": ["openid"], "claims_parameter_supported": true})
    Set tBody = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG")), "ServerCredentials": ($Parameter(..#PROBE, "CREDENTIAL"))}
    Do tBody.%Set("IssuerEndpoint", tIssuer, "string")
    Do tBody.%Set("Metadata", tMetadata)
    Set tSC = $ClassMethod(..#SCREEN, "Create", tIssuer, tBody, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the create completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastIssuer"), "POST " _ tIssuer, "at the vendor's POST, named by the issuer")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Keys", tSent), "Metadata,SSLConfiguration,ServerCredentials", "carrying the template fields; the issuer travels as the port's query")
    Do $ClassMethod(..#RULES, "Members", .tNames, .tKinds)
    Set tMissing = ""
    For tI = 1:1:$ListLength(tNames) {
        If tSent.%Get("Metadata").%GetTypeOf($List(tNames, tI)) = "unassigned" Set tMissing = tMissing _ " " _ $List(tNames, tI)
    }
    Do $$$AssertEquals(tMissing, "", "and every derived member")
    Do $$$AssertEquals(tSent.%Get("Metadata").%Get("revocation_endpoint") _ "|" _ tSent.%Get("Metadata").%Get("acr_values_supported").%ToJSON() _ "|" _ tSent.%Get("Metadata").%Get("frontchannel_logout_supported"), "|[]|", "a member the body left out sent empty")

    Set tStored = $ClassMethod(..#PROBE, "Stored", tIssuer)
    Do $$$AssertTrue($IsObject(tStored), "the instance holds the description")
    If '$IsObject(tStored) Quit
    Do $$$AssertEquals(tStored.%Get("SSLConfiguration") _ "|" _ tStored.%Get("ServerCredentials"), $Parameter(..#PROBE, "SSLCONFIG") _ "|" _ $Parameter(..#PROBE, "CREDENTIAL"), "with the SSL/TLS configuration and credential entered")
    Do $$$AssertEquals(tStored.%Get("Metadata").%ToJSON(), ##class(%DynamicObject).%FromJSON(tMetadata.%ToJSON()).%ToJSON(), "and exactly the metadata entered")
    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port's GET reads it")
    If $IsObject($Get(tRead)) Do $$$AssertEquals(tRead.%Get("Metadata").%Get("userinfo_endpoint") _ "|" _ tRead.%Get("Metadata").%Get("scopes_supported").%ToJSON(), tIssuer _ "/userinfo|[""openid""]", "answering every value entered")
    Kill tNone
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tNone, "", .tRows, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(##class(OcuPilot.Port.OAuthServerPort).Matching($Get(tRows), tIssuer)), "and the tab's read lists it")
}

/// <p>An issuer another description carries is refused on its field before anything is sent; the
/// vendor's own 409 for one that reaches it is answered on the field too, by the port.</p>
Method TestADuplicateIssuerIsRefusedOnItsField()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Taken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "a description is created")
    Set tBody = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tBody.%Set("IssuerEndpoint", tIssuer, "string")
    Do tBody.%Set("Metadata", $ClassMethod(..#PROBE, "Metadata", tIssuer))
    Set tSC = $ClassMethod(..#SCREEN, "Create", tIssuer, tBody, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, "IssuerEndpoint"), "OAUTH.ISSUERENDPOINT.TAKEN", "the Save refuses the issuer on its field")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")

    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke(..#ENDPOINT, "POST", .tQuery, {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG")), "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer))}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the vendor refuses a duplicate that reaches it")
    Do $$$AssertEquals(tHttp, 422, "which the port answers 422")
    Set tRow = ""
    If $IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object") Set tRow = tFault.%Get("detail").%Get("violations").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ " " _ tRow.%Get("code"), 1: ""), "IssuerEndpoint OAUTH.ISSUERENDPOINT.TAKEN", "on the issuer's field")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count"), 1, "and nothing more is stored")
}

/// <p>Every form rule refuses on both callers, on the field it names, with nothing sent: the screen's
/// Save answers the field's violation and the agent's mint the field's sentence.</p>
Method TestEveryFormRuleRefusesOnBothCallers()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Rules")
    Set tSSL = $Parameter(..#PROBE, "SSLCONFIG")
    ; tCase(n) = $ListBuild(issuer, field, code), tBody(n) = the body: an object kept out of the list,
    ; which would stringify it.
    Set tCase($Increment(tCase)) = $ListBuild(tIssuer, "Metadata.token_endpoint", "OAUTH.TOKENENDPOINT.REQUIRED")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": {"authorization_endpoint": "https://a.invalid/authorize", "token_endpoint": ""}}
    Set tCase($Increment(tCase)) = $ListBuild(tIssuer, "Metadata.authorization_endpoint", "OAUTH.AUTHORIZATIONENDPOINT.REQUIRED")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": {"token_endpoint": "https://a.invalid/token"}}
    Set tCase($Increment(tCase)) = $ListBuild("ftp://ocupilotprobe124.invalid/x", "IssuerEndpoint", "OAUTH.ISSUERENDPOINT.SHAPE")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer))}
    Set tCase($Increment(tCase)) = $ListBuild("https://ocupilotprobe124.invalid/a b", "IssuerEndpoint", "OAUTH.ISSUERENDPOINT.SHAPE")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer))}
    Set tCase($Increment(tCase)) = $ListBuild("https://ocupilotprobe124.invalid/q?x=1", "IssuerEndpoint", "OAUTH.ISSUERENDPOINT.SHAPE")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer))}
    Set tCase($Increment(tCase)) = $ListBuild("https://ocupilotprobe124.invalid#f", "IssuerEndpoint", "OAUTH.ISSUERENDPOINT.SHAPE")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer))}
    Set tCase($Increment(tCase)) = $ListBuild(tIssuer, "SSLConfiguration", "OAUTH.SSLCONFIGURATION.REQUIRED")
    Set tBody(tCase) = {"SSLConfiguration": "", "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer))}
    Set tCase($Increment(tCase)) = $ListBuild(tIssuer, "Metadata.bogus", "OAUTH.METADATA.UNKNOWN")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer, {"bogus": "x"}))}
    Set tCase($Increment(tCase)) = $ListBuild(tIssuer, "Metadata.scopes_supported", "OAUTH.METADATA.SHAPE")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer, {"scopes_supported": "x"}))}
    Set tCase($Increment(tCase)) = $ListBuild(tIssuer, "ServerCredentials", "OAUTH.SERVERCREDENTIALS.ABSENT")
    Set tBody(tCase) = {"SSLConfiguration": (tSSL), "ServerCredentials": "OcuPilotProbe124NoSuchCredential", "Metadata": ($ClassMethod(..#PROBE, "Metadata", tIssuer))}
    For tI = 1:1:tCase {
        Set tCaseIssuer = $List(tCase(tI), 1)
        Set tField = $List(tCase(tI), 2)
        Set tCode = $List(tCase(tI), 3)
        Set tArgs = tBody(tI)
        Do tArgs.%Set("IssuerEndpoint", tCaseIssuer, "string")
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = $ClassMethod(..#SCREEN, "Create", tCaseIssuer, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, tField), tCode, "case " _ tI _ ": the Save refuses " _ tField)
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tCaseIssuer, tArgs, .tProposal, .tHttp, .tFault)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400) && ($ClassMethod(..#PROBE, "Problem", $Get(tFault)) [ ("'" _ tField _ "': " _ tReason)), "case " _ tI _ ": and the agent's mint refuses it with the field's sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count"), 0, "no description was created")
}

/// <p>AC7's AD-54 half: the agent's create is minted composed, with a diff row per field and no
/// unchanged count; a description created at that issuer after the mint refuses the confirm, which
/// sends nothing and closes the proposal.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.OAuthServerDescriptionCreate.CREATES</parameter>
/// set to 0 -- the mint reads the absent target as gone and this goes red.</p>
Method TestACreateTakenAfterTheMintIsRefusedAtConfirm()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "Late")
    Set tArgs = {"SSLConfiguration": ($Parameter(..#PROBE, "SSLCONFIG"))}
    Do tArgs.%Set("IssuerEndpoint", tIssuer, "string")
    Do tArgs.%Set("Metadata", $ClassMethod(..#PROBE, "Metadata", tIssuer))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#TOOL, tIssuer, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $ClassMethod(..#PROBE, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tFields = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tFields = tFields _ $ListBuild(tRow.%Get("field")) }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Sorted", tFields), "Metadata,SSLConfiguration", "a diff row per field supplied")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and none unchanged")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tIssuer), "then somebody else creates the issuer")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and nothing is sent")
}

}
