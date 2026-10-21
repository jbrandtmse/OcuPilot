/// <p>Pins Story 20.32's three link screens and the vocabulary they open (AD-5, AD-8, AD-44, AD-47, AD-65): Architect, Analyzer and User Portal
/// declared as the story names them, each classic page the portal's own and compiled, each compiled <code>RESOURCE</code> naming a pair its
/// screen declares; <class>OcuPilot.Screen.ExternalPage</class> closed, composing the address the instance composes and nothing else;
/// <method>OcuPilot.Screen.Registry.ExternalProblem</method>'s four refusals, on doctored values and through <method>OcuPilot.Screen.Registry.Validate</method>;
/// a namespace that does not report analytics carrying no address on the navigation map; and the agent's navigation tool opening each route under the screen's pairs.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and the instance's classic DeepSee pages. It reads declarations and the page
/// dictionary, writes nothing and needs no armed variable. <method>TestHscustomCarriesNoAddress</method> stashes a request scope in this process and
/// clears it, and reads <code>HSCUSTOM</code> as the instance ships it, with analytics off; nothing in the suite turns it on.</p>
Class OcuPilot.Test.AnalyticsLinkDescriptor Extends %UnitTest.TestCase
{

Parameter PACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The three screens, <code>&lt;descriptor&gt;|&lt;route&gt;|&lt;position&gt;|&lt;label key&gt;|&lt;tool&gt;|&lt;classic page&gt;|&lt;page file&gt;|&lt;pairs&gt;|&lt;own pair&gt;|&lt;prompt key prefix&gt;|&lt;aliases&gt;</code>,
/// pairs separated by <code>/</code> and aliases by <code>,</code>.</p>
Parameter SCREENS = "AnalyticsArchitectLink|analytics/architect|4|analyticsArchitectLabel|analytics.architect|%DeepSee.UI.Architect|_DeepSee.UI.Architect.zen|%DeepSee_Portal:USE/%DeepSee_Architect:USE|%DeepSee_Architect:USE|analyticsArchitectPrompt|architect,cube designer,deepsee architect;AnalyticsAnalyzerLink|analytics/analyzer|5|analyticsAnalyzerLabel|analytics.analyzer|%DeepSee.UI.Analyzer|_DeepSee.UI.Analyzer.zen|%DeepSee_Portal:USE/%DeepSee_Analyzer:USE|%DeepSee_Analyzer:USE|analyticsAnalyzerPrompt|analyzer,pivot tables,deepsee analyzer;AnalyticsUserPortalLink|analytics/user-portal|6|analyticsUserPortalLabel|analytics.userportal|%DeepSee.UserPortal.Home|_DeepSee.UserPortal.Home.zen|%DeepSee_Portal:USE||analyticsUserPortalPrompt|user portal,dashboards,deepsee portal";

/// <p>The fixture registry the through-<method>Validate</method> legs run, and the fixture descriptor it holds.</p>
Parameter REGISTRY = "OcuPilot.Test.ExternalLinkRegistry";

Parameter FIXTURE = "OcuPilot.Test.ExternalLink.Doctored";

/// <p>The agent's navigation tool.</p>
Parameter NAVIGATE = "OcuPilot.Screen.Tool.Navigate";

/// <p>The sentence <method>OcuPilot.Screen.Registry.ExternalProblem</method> ends the declaration half with, which
/// <file>ui/tools/screen-mirror.mjs</file>'s <code>externalProblem</code> returns too.</p>
Parameter DECLARES = "and an external screen opens a page in a new tab with no read, table, action, tab or parentScope (AD-44)";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Disarm")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Each declaration carries the table's values, and the registry validates the roster with the three: a listed screen of the Analytics area
/// after Folder items, archetype <code>external</code>, scoped to the namespace, with no read, table, action, id or context field, three
/// <code>promptGroupGettingStarted</code> prompts, no classic-link exemption, the vocabulary's classic page (the page the portal's own resolver
/// names for the page's file, compiled) whose compiled <code>RESOURCE</code> names the screen's own pair.</p>
/// <p>Mutation (Rule 19): drop <code>%DeepSee_Architect:USE</code> from <code>AnalyticsArchitectLink</code> -- the pair legs go red here, and
/// <class>OcuPilot.Test.InteropFloor</class>'s and <class>OcuPilot.Test.DeveloperFloor</class>'s rosters go red, because the developer then opens it.</p>
Method TestTheLinkScreensRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    Set tArea = ##class(OcuPilot.Screen.Area).Find("analytics")
    Do $$$AssertEquals($Select($IsObject(tArea): tArea.appliesWhen, 1: ""), "analytics", "the area the links inherit applies when the namespace reports analytics")
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = ..#PACKAGE _ $Piece(tRow, "|", 1)
        Kill tDeclaration
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.built _ "|" _ tDeclaration.refreshes, $Piece(tRow, "|", 2) _ "|analytics|" _ $Piece(tRow, "|", 3) _ "|external|namespace|1|0", tClass _ ": route, area, listed position, archetype, scope, built and not refreshing")
        Do $$$AssertEquals(tDeclaration.labelKey _ "|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.emptyStateKey, $Piece(tRow, "|", 4) _ "|" _ $Piece(tRow, "|", 5) _ "|", tClass _ ": label, tool identifier and no empty sentence")
        Do $$$AssertEquals(..PairsOf(tDeclaration, "privileges"), $Piece(tRow, "|", 8), tClass _ ": the Analytics menu's pair, then its own")
        Do $$$AssertEquals(..PairsOf(tDeclaration, "ownPrivileges"), $Piece(tRow, "|", 9), tClass _ ": its own pair, if it has one")
        Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.parentScope _ "|" _ tDeclaration.id.%ToJSON() _ "|" _ tDeclaration.secondaryEntityTypes.%Size(), "||{""kind"":""none"",""parts"":[]}|0", tClass _ ": no entity type, no parent and no id")
        Do $$$AssertEquals(tDeclaration.%IsDefined("read") _ tDeclaration.%IsDefined("table") _ tDeclaration.%IsDefined("tab") _ tDeclaration.%IsDefined("banner") _ tDeclaration.%IsDefined("rowTarget"), "00000", tClass _ ": no read, table, tab, banner or row target")
        Do $$$AssertEquals(tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.context.fields.%Size() _ "|" _ tDeclaration.context.secretFields.%Size(), "0||0|0", tClass _ ": no action and an empty context")
        Do $$$AssertEquals(tDeclaration.classicLinkExemption.exempt _ "|" _ tDeclaration.classicLinkExemption.reason _ "|" _ tDeclaration.classicLinkExemption.label _ "|" _ tDeclaration.classicLinkExemption.href, "0|||", tClass _ ": all-false classic-link exemption")
        Set tAliases = ""
        Set tIterator = tDeclaration.commandAliases.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tAlias) { Set tAliases = tAliases _ $Select(tAliases = "": "", 1: ",") _ tAlias }
        Do $$$AssertEquals(tAliases, $Piece(tRow, "|", 11), tClass _ ": its command aliases")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": three suggested prompts")
        For tJ = 1:1:3 {
            Set tPrompt = tDeclaration.suggestedPrompts.%Get(tJ - 1)
            Do $$$AssertEquals($Select($IsObject(tPrompt): tPrompt.groupKey _ "|" _ tPrompt.textKey, 1: ""), "promptGroupGettingStarted|" _ $Piece(tRow, "|", 10) _ tJ, tClass _ ": prompt " _ tJ _ " is its own, in the getting-started group")
        }
        Set tPage = $Piece(tRow, "|", 6)
        Do $$$AssertEquals(tDeclaration.classicPage, tPage, tClass _ ": its classic page")
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/user/" _ $Piece(tRow, "|", 7)), tPage, tClass _ ": which the portal's own resolver answers for the page's file")
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(tPage), tClass _ ": " _ tPage _ " is compiled on this instance")
        Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).File($Piece(tRow, "|", 5)) _ "|" _ ##class(OcuPilot.Screen.ExternalPage).ClassicPage($Piece(tRow, "|", 5)), $Piece(tRow, "|", 7) _ "|" _ tPage, tClass _ ": the vocabulary names the same file and classic page")
        Set tResource = ##class(OcuPilot.Test.DeveloperFloor).ClassicResource(tPage, .tHasResource)
        Do $$$AssertTrue(tHasResource, tPage _ ": declares a compiled RESOURCE")
        Set tOwn = tDeclaration.privileges.%Get(tDeclaration.privileges.%Size() - 1).resource
        Do $$$AssertTrue($ListFind($ListFromString(tResource, ","), tOwn) > 0, tClass _ ": " _ tPage _ "'s RESOURCE '" _ tResource _ "' names " _ tOwn _ ", the last pair the screen declares")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ExternalProblem(tDeclaration), "", tClass _ ": the declaration passes ExternalProblem")
    }
}

/// <p>The pairs <var>pKey</var> of <var>pDeclaration</var> holds, as <code>resource:permission</code> separated by <code>/</code>; <code>""</code> for a key it
/// does not declare.</p>
ClassMethod PairsOf(pDeclaration As %DynamicObject, pKey As %String) As %String
{
    Set tOut = ""
    Set tList = pDeclaration.%Get(pKey)
    If '$IsObject(tList) Quit tOut
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPair) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: "/") _ tPair.resource _ ":" _ tPair.permission
    }
    Quit tOut
}

/// <p>A copy of <var>pBase</var> with <var>pKey</var> set to <var>pJson</var>, a JSON value (a string is quoted).</p>
ClassMethod Doctor(pBase As %DynamicObject, pKey As %String, pJson As %String) As %DynamicObject
{
    Set tCopy = ##class(%DynamicObject).%FromJSON(pBase.%ToJSON())
    Set tWrapped = ##class(%DynamicObject).%FromJSON("{""v"":" _ pJson _ "}")
    Set tValue = tWrapped.%Get("v")
    If $IsObject(tValue) {
        Do tCopy.%Set(pKey, tValue)
    } Else {
        Do tCopy.%Set(pKey, tValue, "string")
    }
    Quit tCopy
}

/// <p>The vocabulary is closed and its address is the instance's: an identifier it lacks and an empty namespace have none; the address for <code>USER</code> is
/// the default application's, given its leading and trailing <code>/</code>, then the page file and <code>?$NAMESPACE=</code> and the namespace, and
/// passes <method>OcuPilot.Screen.Registry.ClassicHrefProblem</method>; a namespace is URL-encoded; and each of <method>OcuPilot.Screen.Registry.ExternalProblem</method>'s
/// four refusals fires on a doctored declaration, directly and through <method>OcuPilot.Screen.Registry.Validate</method>.</p>
/// <p>Mutation (Rule 19): drop the trailing <code>/</code> normalization from <method>OcuPilot.Screen.ExternalPage.Href</method> -- the composed-address leg goes
/// red. Stop <method>OcuPilot.Screen.Registry.Validate</method> calling <method>OcuPilot.Screen.Registry.ExternalProblem</method> -- the through-Validate legs go red
/// while the direct ones stay green.</p>
Method TestTheVocabularyIsClosed()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).Href("analytics.nothing", "USER"), "", "an identifier the vocabulary lacks has no address")
    Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).Href("", "USER"), "", "an empty identifier has none")
    Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).Href("analytics.architect", ""), "", "an empty namespace has none")
    Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).File("analytics.nothing") _ ##class(OcuPilot.Screen.ExternalPage).ClassicPage("analytics.nothing"), "", "nor a file or a classic page")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.ExternalPage).Identifiers()), "analytics.architect,analytics.analyzer,analytics.userportal", "the vocabulary names the three")
    Set tApplication = $System.CSP.GetDefaultApp("USER")
    If $Extract(tApplication, 1) '= "/" Set tApplication = "/" _ tApplication
    If $Extract(tApplication, *) '= "/" Set tApplication = tApplication _ "/"
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tHref = ##class(OcuPilot.Screen.ExternalPage).Href($Piece(tRow, "|", 5), "USER")
        Do $$$AssertEquals(tHref, tApplication _ $Piece(tRow, "|", 7) _ "?$NAMESPACE=USER", $Piece(tRow, "|", 5) _ ": the default application, a slash, the page file, and the namespace")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicHrefProblem(tHref), "", $Piece(tRow, "|", 5) _ ": and it is a root-relative same-origin path")
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage(tHref), $Piece(tRow, "|", 6), $Piece(tRow, "|", 5) _ ": which the portal's own resolver reads as its classic page")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).Href("analytics.architect", "USER"), "/csp/user/_DeepSee.UI.Architect.zen?$NAMESPACE=USER", "on a stock USER, the address the story's matrix gives")
    Do $$$AssertEquals($Piece(##class(OcuPilot.Screen.ExternalPage).Href("analytics.architect", "%SYS"), "?", 2), "$NAMESPACE=%25SYS", "a namespace is URL-encoded")
    Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).Href("analytics.architect", "NOSUCHNS"), "", "a namespace with no default application has no address")

    Set tSC = $ClassMethod("OcuPilot.Screen.Descriptor.AnalyticsArchitectLink", "DeclarationJson", .tBase)
    Do $$$AssertStatusOK(tSC, "the Architect declaration the cases doctor parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ExternalProblem(tBase), "", "the declaration the cases start from passes")
    Set tVocabulary = "toolIdentifier 'analytics.architect' names a page in OcuPilot.Screen.ExternalPage's vocabulary, and only an external screen may (AD-44)"
    Set tCases = $ListBuild(
        $ListBuild("toolIdentifier", """analytics.nothing""", "external screen's toolIdentifier 'analytics.nothing' is not in OcuPilot.Screen.ExternalPage's vocabulary, and an external screen opens only a page the vocabulary names (AD-44)"),
        $ListBuild("archetype", """viewer (source)""", tVocabulary),
        $ListBuild("classicPage", """%DeepSee.UI.Analyzer""", "external screen's classicPage '%DeepSee.UI.Analyzer' is not '%DeepSee.UI.Architect', the page OcuPilot.Screen.ExternalPage names for 'analytics.architect' (AD-44)"),
        $ListBuild("primaryAction", "{""id"":""open"",""selfProtection"":""""}", "external screen declares primaryAction, " _ ..#DECLARES),
        $ListBuild("rowActions", "[{""id"":""open"",""selfProtection"":""""}]", "external screen declares rowActions, " _ ..#DECLARES),
        $ListBuild("parentScope", """analytics/cubes""", "external screen declares parentScope, " _ ..#DECLARES),
        $ListBuild("tab", "{""group"":""analytics/architect"",""position"":1,""labelKey"":""analyticsArchitectLabel""}", "external screen declares tab, " _ ..#DECLARES),
        $ListBuild("table", "{""columns"":[]}", "external screen declares table, " _ ..#DECLARES),
        $ListBuild("read", "{""source"":{""port"":""analytics"",""endpoint"":""Cubes"",""type"":""LIST""}}", "external screen declares read, " _ ..#DECLARES))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tDoctored = ..Doctor(tBase, $List(tCase, 1), $List(tCase, 2))
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ExternalProblem(tDoctored), $List(tCase, 3), "doctored " _ $List(tCase, 1) _ ": refused with its sentence")
    }

    ; The same shapes through Validate, on a roster of the one fixture descriptor: every shape the rule is first to meet, one for each of its refusals.
    ; A read and a table are shown on values above, because an earlier rule refuses the parts of a declaration a doctored one lacks.
    For tI = 1, 2, 3, 4, 5, 6, 7 {
        Set tCase = $List(tCases, tI)
        Do $ClassMethod(..#FIXTURE, "Arm", ..Doctor(tBase, $List(tCase, 1), $List(tCase, 2)))
        Set tSC = $ClassMethod(..#REGISTRY, "Validate", .tProblem)
        Do $$$AssertStatusNotOK(tSC, "doctored " _ $List(tCase, 1) _ ": the roster is refused")
        Do $$$AssertEquals($Get(tProblem), ..#FIXTURE _ ": " _ $List(tCase, 3), "doctored " _ $List(tCase, 1) _ ": and Validate says why")
    }
    Do $ClassMethod(..#FIXTURE, "Arm", tBase)
    Set tSC = $ClassMethod(..#REGISTRY, "Validate", .tProblem)
    Do $$$AssertStatusOK(tSC, "the undoctored declaration is a sound roster: " _ $Get(tProblem))
}

/// <p>AC4: the agent opens each link's route. <code>shell.screen.open</code>'s directive for the route resolves to it with no entity, criterion or fault, and the
/// tool requires the pairs the screen itself requires (AD-8), each of the pairs the screen declares among them, so a caller the side bar refuses a link is
/// refused the link's page when the agent offers it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Navigate.Directive</method> refuse a screen whose archetype is <code>external</code> -- the directive leg
/// goes red here alone, because the tool's route enum is derived from the built roster and still names the three.</p>
Method TestTheAgentOpensEachLinkRouteUnderTheScreensPairs()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = ..#PACKAGE _ $Piece(tRow, "|", 1)
        Set tRoute = $Piece(tRow, "|", 2)
        Set tArgs = {}
        Do tArgs.%Set("route", tRoute)
        Kill tOpened, tEntity, tFault
        Set tSC = $ClassMethod(..#NAVIGATE, "Directive", "", tArgs, .tOpened, .tEntity, .tFault)
        Do $$$AssertStatusOK(tSC, tRoute _ ": the directive is not refused")
        Do $$$AssertEquals($Get(tOpened) _ "|" _ $Get(tEntity), tRoute _ "|", tRoute _ ": it opens the route, with no entity")
        Set tPairs = $ClassMethod(..#NAVIGATE, "ArgumentPairs", "", tArgs, .tResolved)
        Do $$$AssertEquals(tResolved, 1, tRoute _ ": the tool's pairs resolve")
        Do $$$AssertEquals(tPairs, ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass), tRoute _ ": the tool requires exactly the screen's own pairs")
        Set tSpelled = ""
        For tJ = 1:1:$ListLength(tPairs) {
            Set tSpelled = tSpelled _ $ListBuild($List($List(tPairs, tJ), 1) _ ":" _ $List($List(tPairs, tJ), 2))
        }
        For tJ = 1:1:$Length($Piece(tRow, "|", 8), "/") {
            Set tDeclared = $Piece($Piece(tRow, "|", 8), "/", tJ)
            Do $$$AssertTrue($ListFind(tSpelled, tDeclared) > 0, tRoute _ ": the tool requires " _ tDeclared)
        }
    }
}

/// <p>A namespace that does not report analytics carries no address: with <code>HSCUSTOM</code> as the request's scope, the navigation payload still lists
/// the three links under the Analytics area, which does not apply there, and no screen entry carries <code>href</code>.</p>
/// <p>Mutation (Rule 19): set <code>href</code> in <method>OcuPilot.Kernel.Shell.Navigation.Payload</method> without the <code>applies</code> test -- this goes red.</p>
Method TestHscustomCarriesNoAddress()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = ##class(OcuPilot.Kernel.Shell.Navigation).Payload(.tObject)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the payload builds")
    If '$IsObject(tObject) Quit
    Set tAnalytics = ##class(OcuPilot.Test.Descriptor).AreaEntry(tObject.areas, "analytics")
    Do $$$AssertTrue($IsObject(tAnalytics), "the payload carries the analytics area")
    If $IsObject(tAnalytics) Do $$$AssertEquals(tAnalytics.applies, 0, "which does not apply in HSCUSTOM")
    Set tListed = ""
    Set tCarrying = ""
    Set tAreas = tObject.areas.%GetIterator()
    While tAreas.%GetNext(.tAreaIndex, .tArea) {
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            If $ListFind($ListBuild("analytics/architect", "analytics/analyzer", "analytics/user-portal"), tScreen.route) > 0 Set tListed = tListed _ $Select(tListed = "": "", 1: ",") _ tScreen.route
            If tScreen.%IsDefined("href") Set tCarrying = tCarrying _ $Select(tCarrying = "": "", 1: ",") _ tScreen.route
        }
    }
    Do $$$AssertEquals(tListed, "analytics/architect,analytics/analyzer,analytics/user-portal", "the three links are on the map, in position order")
    Do $$$AssertEquals(tCarrying, "", "and no entry carries an address")
}

}
