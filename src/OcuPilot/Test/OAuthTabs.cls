/// <p>The OAuth 2.0 screen's five tabs (Story 6.4): each descriptor's declaration against the read,
/// classic-link and tab grammars, the registry and the Security and secrets area's pair set; each
/// read over the wire as the configured test account (<class>OcuPilot.Test.Http</class>) against the
/// objects <class>OcuPilot.Test.OAuthProbe</class> makes; the key set of every row the five reads,
/// the five derived tools and the raw port LISTs answer, with no secret key among them; and each
/// derived read tool, which answers the route's rows narrowed by its cap.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code>, the demo fixture's SSL/TLS
/// configuration, and both the test account and the process running this class holding every OAuth 2.0
/// resource, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>. <b>It makes OAuth 2.0
/// objects in <method>OnBeforeAllTests</method> and removes them in <method>OnAfterAllTests</method>,
/// so it refuses to run unless <parameter>ARMINGVARIABLE</parameter> arms it</b>, as on the throwaway
/// <file>scripts/ci-throwaway.sh</file> builds.</p>
Class OcuPilot.Test.OAuthTabs Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

/// <p>The keys no row of these reads may carry: the client and server client metadata, which the
/// vendor answers unmasked on a GET, and every secret an OAuth 2.0 object holds (AD-35).</p>
Parameter SECRETKEYS = "Metadata,ClientSecret,ClientPassword,PrivateJWKS,SymmetricJWKS,InitialAccessToken,ServerPassword,client_secret,registration_access_token";

/// <p>The reason the one Release 1 exemption carries, declared by all five tabs (AD-44).</p>
Parameter EXEMPTIONREASON = "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthTabs makes and removes OAuth 2.0 objects on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was made. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ##class(OcuPilot.Test.OAuthProbe).Create()
}

/// <p>Remove the probe objects, <b>returning a failing status</b> if the removal fails, since
/// <code>%UnitTest.Manager</code> records no assertion from this method. An unarmed run made nothing
/// and removes nothing: the manager calls this after a refused <method>OnBeforeAllTests</method>
/// too.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Quit ##class(OcuPilot.Test.OAuthProbe).Remove()
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The five tabs as <code>$ListBuild(descriptor, route, tool, tab position, side-bar position,
/// entity types, classic page, editor page, read fields as JSON, first pair, rowLink params as
/// JSON)</code>.</p>
ClassMethod Tabs() As %List
{
    Set tTabs = ""
    Set tTabs = tTabs _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab", "security/oauth", "security.oauthserverdescriptions", 1, 5, "oauth2-server-definition,oauth2-client-configuration,oauth2-resource-server", "%CSP.UI.Portal.OAuth2.Client.ServerList", "%CSP.UI.Portal.OAuth2.Client.ServerConfiguration", "[""ID"",""IssuerEndpoint"",""ClientCount"",""ResourceCount""]", "%Admin_OAuth2_Client", "[{""name"":""PID"",""field"":""ID""}]"))
    Set tTabs = tTabs _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.OAuthClientTab", "security/oauth/clients", "security.oauthclients", 2, 0, "oauth2-client-configuration,oauth2-server-definition", "%CSP.UI.Portal.OAuth2.Client.ConfigurationList", "%CSP.UI.Portal.OAuth2.Client.Configuration", "[""ApplicationName"",""ClientType"",""DefaultScope"",""ServerDefinitionID"",""IssuerEndpoint""]", "%Admin_OAuth2_Client", "[{""name"":""PID"",""field"":""ApplicationName""},{""name"":""IssuerEndpointID"",""field"":""ServerDefinitionID""},{""name"":""IssuerEndpoint"",""field"":""IssuerEndpoint""}]"))
    Set tTabs = tTabs _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.OAuthResourceServerTab", "security/oauth/resource-servers", "security.oauthresourceservers", 3, 0, "oauth2-resource-server,oauth2-server-definition", "%CSP.UI.Portal.OAuth2.ResourceServer.ConfigurationList", "%CSP.UI.Portal.OAuth2.ResourceServer.Configuration", "[""Name"",""ServerDefinition""]", "%Admin_Secure", "[{""name"":""PID"",""field"":""Name""}]"))
    Set tTabs = tTabs _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.OAuthServerTab", "security/oauth/server", "security.oauthserver", 4, 0, "oauth2-server", "%CSP.UI.Portal.OAuth2.Server.Configuration", "%CSP.UI.Portal.OAuth2.Server.Configuration", "[""IssuerEndpoint"",""Metadata.scopes_supported"",""Metadata.grant_types_supported"",""SigningAlgorithm"",""EncryptionAlgorithm"",""KeyAlgorithm"",""ServerCredentials""]", "%Admin_OAuth2_Server", "[]"))
    Set tTabs = tTabs _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.OAuthServerClientTab", "security/oauth/server-clients", "security.oauthserverclients", 5, 0, "oauth2-server-client,oauth2-server", "%CSP.UI.Portal.OAuth2.Server.ClientList", "%CSP.UI.Portal.OAuth2.Server.Client", "[""Name"",""ClientId"",""ClientType"",""RedirectURL"",""Description""]", "%Admin_OAuth2_Registration", "[{""name"":""ClientId"",""field"":""ClientId""}]"))
    Quit tTabs
}

/// <p>Request <var>pTool</var>'s read at <var>pMaxRows</var> as the test account. <var>pAnswer</var>
/// is the parsed body, or <code>""</code>.</p>
Method Read(pTool As %String, pMaxRows As %Integer, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ pTool _ "/read?maxRows=" _ pMaxRows, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Do $$$AssertTrue($IsObject(pAnswer), pTool _ ": the body parses as JSON")
    Quit tSC
}

/// <p>The first row of <var>pRows</var> whose <var>pKey</var> is <var>pValue</var>, or <code>""</code>.</p>
ClassMethod RowWhere(pRows As %DynamicArray, pKey As %String, pValue As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get(pKey) = pValue {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>What is wrong with <var>pRows</var>' key sets, or <code>""</code>: every row carries exactly
/// <var>pFields</var>, in that order, and no key <parameter>SECRETKEYS</parameter> names, whole or as
/// the member of a dotted key.</p>
ClassMethod KeySetProblem(pRows As %DynamicArray, pFields As %String) As %String
{
    Set tBad = ""
    Set tSecrets = $ListFromString(..#SECRETKEYS)
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = []
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            If $ListFind(tSecrets, tKey) || $ListFind(tSecrets, $Piece(tKey, ".", *)) Set tBad = "row " _ tIndex _ " carries the secret key " _ tKey
            Do tKeys.%Push(tKey)
        }
        If (tBad = "") && (tKeys.%ToJSON() '= pFields) Set tBad = "row " _ tIndex _ " carries " _ tKeys.%ToJSON()
        If tBad '= "" Quit
    }
    Quit tBad
}

/// <p>Each tab passes the read, classic-link and tab grammars; its route and tool identifier resolve to
/// it; it is a built <code>detail</code> view in the Security and secrets area on its declared entity
/// types, at instance scope, with no action, no refresh and no secret field, its context fields its
/// read fields; it is tab <code>n</code> of <code>security/oauth</code>, the first listed at side-bar
/// position 5 and the rest unlisted; its classic page and editor page compile under the declared case,
/// and its exemption carries the one reason, the editor page's own <code>PAGENAME</code> as its label,
/// the editor's root-relative href and its row link params; its pair set is its resource then
/// <code>%DB_IRISSYS:READ</code>; and <code>AreaCoverageProblem("security", ...)</code> is empty.</p>
Method TestEachTabIsDeclaredAsTheOAuthScreenTab()
{
    Set tTabs = ..Tabs()
    For tI = 1:1:$ListLength(tTabs) {
        Set tCase = $List(tTabs, tI)
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tClass _ ": and so is its classic link-out")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TabProblem(tDeclaration), "", tClass _ ": and so is its tab")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute($List(tCase, 2)), tClass, tClass _ ": the route resolves to it")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 3)), tClass, tClass _ ": and so does its tool identifier")
        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "security", tClass _ ": in the Security and secrets area")
        Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "detail", tClass _ ": on the detail archetype")
        Do $$$AssertEquals($ClassMethod(tClass, "IsBuilt"), 1, tClass _ ": built")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "EntityTypes")), $List(tCase, 6), tClass _ ": on its entity types, primary first")
        Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", tClass _ ": at instance scope")
        Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "single", tClass _ ": keyed by one id")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, tClass _ ": and it does not refresh")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), $List(tCase, 5), tClass _ ": at its side-bar position")
        Do $$$AssertEquals(tDeclaration.tab.group, "security/oauth", tClass _ ": in the OAuth 2.0 tab group")
        Do $$$AssertEquals(tDeclaration.tab.position, $List(tCase, 4), tClass _ ": at its tab position")
        Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), $List(tCase, 9), tClass _ ": its read fields are the ones this class pins")
        Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), tClass _ ": its context fields are its read fields")
        Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, tClass _ ": with no secret field")
        Do $$$AssertEquals(tDeclaration.table.emptyNextKey, "tableReadOnlyEmptyNext", tClass _ ": its empty state names what to do next")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, tClass _ ": because it declares no action")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""" _ $List(tCase, 10) _ """,""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", tClass _ ": its pair set, its resource first")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("security", $ClassMethod(tClass, "PrivilegePairs")), "", tClass _ ": and the Security and secrets area covers it")

        Set tPage = $ClassMethod(tClass, "ClassicPage")
        Do $$$AssertEquals(tPage, $List(tCase, 7), tClass _ ": the classic page is the one this class pins")
        Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId(tPage)), tClass _ ": which is a compiled class on this instance, under the declaration's own case")
        Set tEditor = $List(tCase, 8)
        Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId(tEditor)), tClass _ ": and so is its editor page " _ tEditor)
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkExempt"), 1, tClass _ ": it declares the exemption")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkExemptionReason"), ..#EXEMPTIONREASON, tClass _ ": with the one exemption's reason")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkLabel"), $Parameter(tEditor, "PAGENAME"), tClass _ ": labelled by the editor page's own name")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicLinkHref"), "/csp/sys/sec/%25" _ $Extract(tEditor, 2, *) _ ".zen", tClass _ ": opening the editor page by its root-relative path")
        Do $$$AssertEquals(tDeclaration.classicLinkExemption.rowLink.params.%ToJSON(), $List(tCase, 11), tClass _ ": with the params the classic list sends")
    }
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped roster, tab groups included, validates: " _ tProblem)
}

/// <p>Matrix "Descriptions" -- the read answers its four declared fields; description A's row counts
/// one client configuration and one resource server; and the raw LIST row's key set is the declared
/// fields.</p>
Method TestTheServerDescriptionsTabReadsOverTheWire()
{
    Set tSC = ..Read("security.oauthserverdescriptions", 1000, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Tabs(), 1), 9), "fields are the four declared fields")
    Set tRow = ..RowWhere(tAnswer.rows, "IssuerEndpoint", ##class(OcuPilot.Test.OAuthProbe).#ISSUERA)
    Do $$$AssertTrue($IsObject(tRow), "description A is listed among " _ tAnswer.rows.%Size() _ " rows")
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.ClientCount, 1, "A counts one client configuration")
        Do $$$AssertEquals(tRow.ResourceCount, 1, "and one resource server")
    }
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.OAuth2.Client.ServerDefinition", "LIST", .tQuery, "", .tRaw, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live LIST answers")
    If $IsObject(tRaw) Do $$$AssertEquals(..KeySetProblem(tRaw, $List($List(..Tabs(), 1), 9)), "", "and every raw row's key set is the declared fields")
}

/// <p>Matrix "Clients" -- every client configuration is read with its description's issuer and id:
/// <parameter>OcuPilot.Test.OAuthProbe.CLIENTB</parameter> reads B's issuer and B's <code>ID</code>
/// from the descriptions tab.</p>
/// <p>Mutation: copy the parent's <code>IssuerEndpoint</code> into nothing in
/// <method>OcuPilot.Screen.Read.ForEachRows</method> -&gt; B's issuer assertion goes red.</p>
Method TestTheClientsTabReadsEachClientWithItsDescription()
{
    Set tSC = ..Read("security.oauthserverdescriptions", 1000, .tStatus, .tDescriptions)
    Do $$$AssertEquals(tStatus, 200, "the descriptions read answers")
    Set tB = $Select($IsObject(tDescriptions): ..RowWhere(tDescriptions.rows, "IssuerEndpoint", ##class(OcuPilot.Test.OAuthProbe).#ISSUERB), 1: "")
    Do $$$AssertTrue($IsObject(tB), "description B is listed")
    Set tSC = ..Read("security.oauthclients", 1000, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the clients read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) || '$IsObject(tB) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Tabs(), 2), 9), "fields are the five declared fields")
    Do $$$AssertEquals(tAnswer.truncated, 0, "nothing is cut at 1,000")
    Set tRow = ..RowWhere(tAnswer.rows, "ApplicationName", ##class(OcuPilot.Test.OAuthProbe).#CLIENTB)
    Do $$$AssertTrue($IsObject(tRow), "client B is listed among " _ tAnswer.rows.%Size() _ " rows")
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.IssuerEndpoint, ##class(OcuPilot.Test.OAuthProbe).#ISSUERB, "its issuer is B's")
    Do $$$AssertEquals(tRow.ServerDefinitionID, tB.ID, "and its description id is B's")
    Do $$$AssertEquals(tRow.%GetTypeOf("ServerDefinitionID"), "number", "keeping the id's JSON type")
    Do $$$AssertTrue($IsObject(..RowWhere(tAnswer.rows, "ApplicationName", ##class(OcuPilot.Test.OAuthProbe).#CLIENTA)), "and client A is listed too")
}

/// <p>Matrix "Clients cap" -- at <code>maxRows=1</code> the clients read answers one row, truncated.</p>
/// <p>Mutation: report truncation from the rows answered rather than the rows held in
/// <method>OcuPilot.Screen.Read.ForEachRows</method> -&gt; the truncated assertion goes red.</p>
Method TestTheClientsTabIsCapped()
{
    Set tSC = ..Read("security.oauthclients", 1, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the capped read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "one row")
    Do $$$AssertEquals(tAnswer.truncated, 1, "truncated")
}

/// <p>Matrix "Resource servers" -- the read answers its two declared fields, and the probe's resource
/// server reads description A's issuer.</p>
Method TestTheResourceServersTabReadsItsIssuer()
{
    Set tSC = ..Read("security.oauthresourceservers", 1000, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Tabs(), 3), 9), "fields are the two declared fields")
    Set tRow = ..RowWhere(tAnswer.rows, "Name", ##class(OcuPilot.Test.OAuthProbe).#RESOURCE)
    Do $$$AssertTrue($IsObject(tRow), "the probe resource server is listed")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.ServerDefinition, ##class(OcuPilot.Test.OAuthProbe).#ISSUERA, "reading A's issuer")
}

/// <p>Matrix "Authorization server", AC2 -- the read answers its seven declared fields and one row
/// equal, field by field, to the live <code>Security.OAuth2.Server</code> GET projected: each plain
/// field the GET's own, and each <code>Metadata.*</code> field the GET's <code>Metadata</code> member.
/// When the probe made the configuration, the scopes include <code>openid</code> and the grant types
/// <code>authorization_code</code>.</p>
/// <p>Mutation: declare <code>Metadata.grant_types</code> for <code>Metadata.grant_types_supported</code>
/// in <class>OcuPilot.Screen.Descriptor.OAuthServerTab</class> -&gt; the fields and grant-type assertions
/// go red.</p>
Method TestTheAuthorizationServerTabIsTheLiveGetProjected()
{
    Set tSC = ..Read("security.oauthserver", 1000, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Tabs(), 4), 9), "fields are the seven declared fields")
    Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "one row")
    Do $$$AssertEquals(tAnswer.truncated, 0, "not truncated")
    If tAnswer.rows.%Size() '= 1 Quit
    Set tRow = tAnswer.rows.%Get(0)
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.OAuth2.Server", "GET", .tQuery, "", .tLive, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live GET answers")
    If '$IsObject(tLive) Quit
    Set tIterator = tAnswer.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        If $Piece(tField, ".", 1) = "Metadata" {
            Set tWanted = tLive.Metadata.%Get($Piece(tField, ".", 2))
        } Else {
            Set tWanted = tLive.%Get(tField)
        }
        Set tWantedJson = $Select($IsObject(tWanted): tWanted.%ToJSON(), 1: tWanted)
        Set tGot = tRow.%Get(tField)
        Set tGotJson = $Select($IsObject(tGot): tGot.%ToJSON(), 1: tGot)
        Do $$$AssertEquals(tGotJson, tWantedJson, "the row's " _ tField _ " is the live GET's")
    }
    If '##class(OcuPilot.Test.OAuthProbe).MadeServer() Quit
    Do $$$AssertTrue(##class(OcuPilot.Screen.Read).TextOf(tRow, "Metadata.scopes_supported") [ "openid", "the scopes include openid: " _ ##class(OcuPilot.Screen.Read).TextOf(tRow, "Metadata.scopes_supported"))
    Do $$$AssertTrue(##class(OcuPilot.Screen.Read).TextOf(tRow, "Metadata.grant_types_supported") [ "authorization_code", "and the grant types authorization_code: " _ ##class(OcuPilot.Screen.Read).TextOf(tRow, "Metadata.grant_types_supported"))
}

/// <p>Matrix "Server clients" -- the read answers its five declared fields, and the probe's server
/// client carries a non-empty client id.</p>
Method TestTheServerClientsTabReadsTheRegistration()
{
    Set tSC = ..Read("security.oauthserverclients", 1000, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), $List($List(..Tabs(), 5), 9), "fields are the five declared fields")
    Set tRow = ..RowWhere(tAnswer.rows, "Name", ##class(OcuPilot.Test.OAuthProbe).#REGISTRATION)
    Do $$$AssertTrue($IsObject(tRow), "the probe server client is listed")
    If $IsObject(tRow) Do $$$AssertTrue(tRow.ClientId '= "", "with a client id: " _ tRow.ClientId)
}

/// <p>AD-35 -- every row the five reads answer over the wire and every row the five tools answer carries
/// exactly the declared fields and no key <parameter>SECRETKEYS</parameter> names; and every raw LIST
/// row of the three plain LIST tabs, and of one description's client list, carries exactly the fields
/// the read declares from it.</p>
/// <p>Mutation: add <code>Metadata</code> to <class>OcuPilot.Screen.Descriptor.OAuthServerTab</class>'s
/// read and context fields -&gt; its route and tool key-set assertions go red. Match
/// <parameter>SECRETKEYS</parameter> against whole keys only in <method>KeySetProblem</method> -&gt;
/// the member-field secret assertion goes red.</p>
Method TestEveryRowCarriesTheDeclaredFieldsAndNoSecret()
{
    Do $$$AssertTrue(..KeySetProblem([{"Metadata.client_secret": "x"}], "[""Metadata.client_secret""]") [ "secret key", "a member field naming a secret is refused though the key set matches")
    Set tTabs = ..Tabs()
    For tI = 1:1:$ListLength(tTabs) {
        Set tCase = $List(tTabs, tI)
        Set tClass = $List(tCase, 1)
        Set tTool = $List(tCase, 3)
        Set tFields = $List(tCase, 9)
        Set tSC = ..Read(tTool, 1000, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers")
        If (tStatus = 200) && $IsObject(tAnswer) {
            Do $$$AssertTrue(tAnswer.rows.%Size() > 0, tTool _ ": with rows: " _ tAnswer.rows.%Size())
            Do $$$AssertEquals(..KeySetProblem(tAnswer.rows, tFields), "", tTool _ ": every route row carries exactly the declared fields and no secret")
        }
        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tClass, {}, 1000, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISOK(tSC) && $IsObject(tView) {
            Do $$$AssertTrue(tView.rows.%Size() > 0, tTool _ ": the tool answers rows: " _ tView.rows.%Size())
            Do $$$AssertEquals(..KeySetProblem(tView.rows, tFields), "", tTool _ ": every tool row carries exactly the declared fields and no secret")
        }
    }
    For tEndpoint = "Security.OAuth2.Client.ServerDefinition", "Security.OAuth2.ResourceServer", "Security.OAuth2.ServerClients" {
        Set tWanted = $Case(tEndpoint, "Security.OAuth2.Client.ServerDefinition": $List($List(tTabs, 1), 9), "Security.OAuth2.ResourceServer": $List($List(tTabs, 3), 9), : $List($List(tTabs, 5), 9))
        Kill tQuery
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tRaw, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "the live " _ tEndpoint _ " LIST answers")
        If $IsObject(tRaw) Do $$$AssertEquals(..KeySetProblem(tRaw, tWanted), "", tEndpoint _ ": every raw row's key set is the declared fields")
    }
    Set tSC = ..Read("security.oauthserverdescriptions", 1000, .tStatus, .tDescriptions)
    Set tA = $Select($IsObject(tDescriptions): ..RowWhere(tDescriptions.rows, "IssuerEndpoint", ##class(OcuPilot.Test.OAuthProbe).#ISSUERA), 1: "")
    If '$IsObject(tA) Quit
    Kill tQuery
    Set tQuery("serverId") = tA.ID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.OAuth2.Client.ClientConfiguration", "LIST", .tQuery, "", .tRaw, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live client configuration LIST answers for A")
    If $IsObject(tRaw) Do $$$AssertEquals(..KeySetProblem(tRaw, "[""ApplicationName"",""ClientType"",""DefaultScope""]"), "", "every raw client row carries exactly the fields the read declares from it")
}

/// <p>Matrix "Tool", and the integration AC -- the read tool over each tab at a context cap of one
/// answers only <code>fields</code>, <code>rows</code> and <code>truncated</code>: the route's fields
/// and the first row of the route's rows in the declared default order, reporting a cut exactly when
/// the route has more; the descriptions and clients tabs hold two rows, so the cap cuts there.</p>
/// <p>Mutation: keep one row fewer than the cap in <method>OcuPilot.Screen.Tool.Read.View</method>
/// -&gt; the rows assertions go red.</p>
Method TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap()
{
    Set tTabs = ..Tabs()
    For tI = 1:1:$ListLength(tTabs) {
        Set tCase = $List(tTabs, tI)
        Set tDescriptor = $List(tCase, 1)
        Set tTool = $List(tCase, 3) _ ".read"
        Set tCap = 1
        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tDescriptor, {}, tCap, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISERR(tSC) || '$IsObject(tView) Continue

        Set tSC = ..Read($List(tCase, 3), 1000, .tStatus, .tRoute)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers the same read")
        If (tStatus '= 200) || '$IsObject(tRoute) Continue
        Set tOrdered = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(tDescriptor, "Read"))
        Do $$$AssertTrue(tOrdered.%Size() >= tCap, tTool _ ": the route has at least the cap's rows: " _ tOrdered.%Size())
        Set tWanted = []
        For tJ = 0:1:(tCap - 1) Do tWanted.%Push(tOrdered.%Get(tJ))
        Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), tTool _ ": the route's fields")
        Do $$$AssertEquals(tView.rows.%ToJSON(), tWanted.%ToJSON(), tTool _ ": the route's rows in default order, narrowed by the cap")
        Do $$$AssertEquals(tView.truncated, (tOrdered.%Size() > tCap), tTool _ ": reporting a cut exactly when the route has more rows")
        If (tDescriptor = "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab") || (tDescriptor = "OcuPilot.Screen.Descriptor.OAuthClientTab") {
            Do $$$AssertEquals(tView.truncated, 1, tTool _ ": which it does over the probe's two rows")
        }
        Set tKeys = ""
        Set tIterator = tView.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tKeys, "fields,rows,truncated", tTool _ ": and nothing else")
    }
}

}
