/// <p>Pins Story 20.11's seven declarations (AD-5, AD-8, AD-29, AD-36, AD-44, AD-65): the <code>analytics</code> source kind's
/// refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off this class's <code>Cases</code> block as well; the
/// Cubes list, its three tabs, Term lists, a term list's entries and Folder items declared as the story names them; each
/// classic page being the portal's own; and each classic page's compiled <code>RESOURCE</code> naming a pair its screen
/// declares.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and the instance's classic DeepSee pages. It reads
/// declarations and the page dictionary, writes nothing and needs no armed variable.</p>
Class OcuPilot.Test.AnalyticsDescriptor Extends %UnitTest.TestCase
{

Parameter PACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The seven screens, <code>&lt;descriptor&gt;|&lt;route&gt;|&lt;position&gt;|&lt;archetype&gt;|&lt;pairs&gt;|&lt;own pair&gt;|&lt;entity&gt;|&lt;id parts&gt;|&lt;endpoint&gt;|&lt;criterion&gt;|&lt;tool&gt;|&lt;classic page&gt;|&lt;tab position&gt;|&lt;parent&gt;</code>,
/// pairs separated by <code>/</code>.</p>
Parameter SCREENS = "AnalyticsCubeList|analytics/cubes|1|list|%DeepSee_Portal:USE||cube||Cubes||analytics.cubes|%DeepSee.UI.ModelBrowser||;AnalyticsCubeMeasuresTab|analytics/cubes/document|0|detail|%DeepSee_Portal:USE||cube||Measures|cube|analytics.cubemeasures|%DeepSee.UI.ModelBrowser|1|analytics/cubes;AnalyticsCubeDimensionsTab|analytics/cubes/dimensions|0|detail|%DeepSee_Portal:USE||cube||Dimensions|cube|analytics.cubedimensions|%DeepSee.UI.ModelBrowser|2|analytics/cubes;AnalyticsCubeRelationshipsTab|analytics/cubes/relationships|0|detail|%DeepSee_Portal:USE||cube||Relationships|cube|analytics.cuberelationships|%DeepSee.UI.ModelBrowser|3|analytics/cubes;AnalyticsTermListList|analytics/term-lists|2|list|%DeepSee_Portal:USE/%DeepSee_PortalEdit:USE|%DeepSee_PortalEdit:USE|term-list||TermLists||analytics.termlists|%DeepSee.UI.TermListManager||;AnalyticsTermListEntryList|analytics/term-lists/entries|0|list|%DeepSee_Portal:USE/%DeepSee_PortalEdit:USE|%DeepSee_PortalEdit:USE|term-list-entry|TermList,Key|TermListEntries|termlist|analytics.termlistentries|%DeepSee.UI.TermListManager||analytics/term-lists;AnalyticsFolderItemList|analytics/folder-items|3|list|%DeepSee_Portal:USE/%Development:USE|%Development:USE|folder-item||FolderItems||analytics.folderitems|%DeepSee.UI.FolderManager||";

/// <p>The corpus both engines run: each case replaces the declaration's <code>read.source</code>, sets
/// <code>read.criteria</code> when it carries one, and names the sentence the registry's <code>check</code>
/// (<code>read</code> or <code>criteria</code>) answers, or <code>null</code>.</p>
XData Cases
{
{
  "declaration": {
    "route": "analytics/corpus", "area": "analytics", "labelKey": "analyticsCubesLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}],
    "entityType": "cube", "secondaryEntityTypes": [],
    "scope": "namespace", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "Caption"], "secretFields": []},
    "emptyStateKey": "analyticsCubesEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST"},
      "fields": ["Name", "Caption"],
      "filter": ["Name", "Caption"],
      "sort": {"fields": ["Name", "Caption"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "analytics.corpus"
  },
  "cases": [
    {"name": "an analytics LIST of Cubes is sound", "check": "read", "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST"}, "expected": null},
    {"name": "so is each of the other six endpoints (Measures)", "check": "read", "source": {"port": "analytics", "endpoint": "Measures", "type": "LIST"}, "expected": null},
    {"name": "TermListEntries", "check": "read", "source": {"port": "analytics", "endpoint": "TermListEntries", "type": "LIST"}, "expected": null},
    {"name": "FolderItems", "check": "read", "source": {"port": "analytics", "endpoint": "FolderItems", "type": "LIST"}, "expected": null},
    {"name": "and declares no criteria", "check": "criteria", "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST"}, "expected": null},
    {"name": "an endpoint the port does not serve", "check": "read", "source": {"port": "analytics", "endpoint": "Nothing", "type": "LIST"}, "expected": "read.source.endpoint 'Nothing' is not one of the analytics port's endpoints ('Cubes', 'Measures', 'Dimensions', 'Relationships', 'TermLists', 'TermListEntries', 'FolderItems') (AD-65)"},
    {"name": "a type other than LIST", "check": "read", "source": {"port": "analytics", "endpoint": "Cubes", "type": "GET"}, "expected": "read.source.type 'GET' is declared on an analytics source, which lists the namespace's cubes, term lists and folder items (AD-36)"},
    {"name": "rowGet", "check": "read", "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["Caption"], "derived": []}}, "expected": "read.source.rowGet is declared on an analytics source, which answers its list whole (AD-36)"},
    {"name": "forEach", "check": "read", "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST", "forEach": ["Measures"]}, "expected": "read.source.forEach is declared on an analytics source, which answers its list whole (AD-36)"},
    {"name": "query", "check": "read", "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST", "query": {"a": "b"}}, "expected": "read.source.query is declared on an analytics source, which answers its list whole (AD-36)"},
    {"name": "parts", "check": "read", "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on an analytics source, which answers its list whole (AD-36)"},
    {"name": "criteria on a list that has no parent", "check": "criteria", "source": {"port": "analytics", "endpoint": "Measures", "type": "LIST"}, "criteria": {"fields": [{"param": "cube", "labelKey": "analyticsCubeCriterion", "kind": "text", "maxLength": 255}]}, "expected": "read.criteria is declared on a 'analytics' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry, and the corpus refuses at
/// least one shape.</p>
/// <p>Mutation (Rule 19): drop the analytics arm from <method>OcuPilot.Screen.Registry.ReadProblem</method> -- the endpoint, type
/// and key cases go red. The parent-only rule in <method>OcuPilot.Screen.Registry.CriteriaProblem</method> is pinned by
/// <method>TestTheSevenDeclarationsRegister</method>, whose parent-scoped tabs it admits; the criteria case here is refused either way.</p>
Method TestTheAnalyticsSourceRefusals()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tSC)
    Do $$$AssertTrue($IsObject(tXData), "the corpus is declared")
    If '$IsObject(tXData) Quit
    Set tCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tDeclaration = ##class(%DynamicObject).%FromJSON(tCorpus.declaration.%ToJSON())
        Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(tCase.source.%ToJSON()))
        If tCase.%GetTypeOf("criteria") = "object" Do tDeclaration.read.%Set("criteria", ##class(%DynamicObject).%FromJSON(tCase.criteria.%ToJSON()))
        If tCase.check = "criteria" {
            Set tProblem = ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration)
        } Else {
            Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        }
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertTrue(tRefusals >= 7, "the corpus refuses its shapes: " _ tRefusals)
}

/// <p>The seven descriptors declare what the story names: the analytics area, their route, side-bar position, archetype, pairs
/// (the portal's, then each screen's own), entity type, id, endpoint, criterion, tool identifier and classic page; three suggested
/// prompts; a read-only table with no action; context fields equal to the read's; the cube tabs one group under Cubes, in strip
/// order; the Relationships tab's row target; and the registry validates the whole roster.</p>
/// <p>Mutation (Rule 19): change <code>AnalyticsCubeRelationshipsTab</code>'s <code>rowTarget</code> field to <code>Name</code>
/// -- the Relationships leg goes red.</p>
Method TestTheSevenDeclarationsRegister()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = ..#PACKAGE _ $Piece(tRow, "|", 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration reads")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.built, $Piece(tRow, "|", 2) _ "|analytics|" _ $Piece(tRow, "|", 3) _ "|" _ $Piece(tRow, "|", 4) _ "|namespace|1", tClass _ ": route, area, position, archetype, scope and built")
        Set tPairs = ""
        Set tIterator = tDeclaration.privileges.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPair) {
            Set tPairs = tPairs _ $Select(tPairs = "": "", 1: "/") _ tPair.resource _ ":" _ tPair.permission
        }
        Set tOwn = ""
        If tDeclaration.%IsDefined("ownPrivileges") {
            Set tIterator = tDeclaration.ownPrivileges.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tPair) {
                Set tOwn = tOwn _ $Select(tOwn = "": "", 1: "/") _ tPair.resource _ ":" _ tPair.permission
            }
        }
        Do $$$AssertEquals(tPairs _ "|" _ tOwn, $Piece(tRow, "|", 5) _ "|" _ $Piece(tRow, "|", 6), tClass _ ": the portal's pair, then its own")
        Set tParts = ""
        Set tIterator = tDeclaration.id.parts.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPart) {
            Set tParts = tParts _ $Select(tParts = "": "", 1: ",") _ tPart
        }
        Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tParts, $Piece(tRow, "|", 7) _ "|" _ $Select($Piece(tRow, "|", 8) = "": "single", 1: "composite") _ "|" _ $Piece(tRow, "|", 8), tClass _ ": its entity type and id")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "analytics|" _ $Piece(tRow, "|", 9) _ "|LIST", tClass _ ": read through the analytics port")
        Set tCriterion = $Select($IsObject(tDeclaration.read.%Get("criteria")): tDeclaration.read.criteria.fields.%Get(0).param _ "|" _ tDeclaration.read.criteria.fields.%Get(0).kind _ "|" _ tDeclaration.read.criteria.fields.%Get(0).maxLength _ "|" _ tDeclaration.read.criteria.fields.%Size(), 1: "")
        Do $$$AssertEquals(tCriterion, $Select($Piece(tRow, "|", 10) = "": "", 1: $Piece(tRow, "|", 10) _ "|text|255|1"), tClass _ ": its one criterion is the parent's route id")
        Do $$$AssertEquals(tDeclaration.toolIdentifier _ "|" _ tDeclaration.classicPage, $Piece(tRow, "|", 11) _ "|" _ $Piece(tRow, "|", 12), tClass _ ": its tool and its classic page")
        Do $$$AssertEquals(tDeclaration.parentScope, $Piece(tRow, "|", 14), tClass _ ": its parent list")
        Do $$$AssertEquals($Select($IsObject(tDeclaration.%Get("tab")): tDeclaration.tab.group _ "|" _ tDeclaration.tab.position, 1: ""), $Select($Piece(tRow, "|", 13) = "": "", 1: "analytics/cubes/document|" _ $Piece(tRow, "|", 13)), tClass _ ": its place in the cube tab group")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": three suggested prompts")
        Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), tDeclaration.context.fields.%ToJSON(), tClass _ ": its context fields are its read fields")
        Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.refreshes _ "|" _ tDeclaration.classicLinkExemption.exempt, "|0|0|0", tClass _ ": no action, no refresh and no classic-link exemption")
        Do $$$AssertEquals(tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey, "tableReadOnlyEmptyNext|", tClass _ ": the read-only empty state")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read passes the registry")
        If $Piece(tRow, "|", 1) = "AnalyticsCubeRelationshipsTab" {
            Do $$$AssertEquals(tDeclaration.rowTarget.%ToJSON(), "{""route"":""analytics/cubes/document"",""field"":""RelatedCube""}", "a Relationships row opens the related cube's Measures tab")
        } Else {
            Do $$$AssertEquals(tDeclaration.%IsDefined("rowTarget"), 0, tClass _ " declares no row target")
        }
    }
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tProblem), "1|", "the registry validates the roster with the seven: " _ $Get(tProblem))
    Set tArea = ##class(OcuPilot.Screen.Area).Find("analytics")
    Do $$$AssertEquals($Select($IsObject(tArea): tArea.appliesWhen, 1: ""), "analytics", "the area the seven inherit applies when the namespace reports analytics")
    For tType = "cube", "term-list", "term-list-entry", "folder-item" {
        Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown(tType), tType _ " is a declared entity type")
    }
}

/// <p>Each classic page a screen names is the one the portal's own resolver gives for the page's file, so the link the screen draws
/// to it is the portal's.</p>
/// <p>Mutation (Rule 19): change <code>AnalyticsFolderItemList</code>'s <code>classicPage</code> to <code>%DeepSee.UI.FolderManagerx</code>
/// -- the Folder Manager leg goes red.</p>
Method TestEachClassicPageIsThePortalsOwn()
{
    Kill tPortal
    For tPage = "ModelBrowser", "TermListManager", "FolderManager" {
        Set tName = "%DeepSee.UI." _ tPage
        Set tPortal(##class(%SYS.Portal.Resources).NormalizePage("/csp/user/_DeepSee.UI." _ tPage _ ".zen")) = 0
        Do $$$AssertTrue($Data(tPortal(tName)), tName _ ": the portal's own resolver answers it for the page's file")
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(tName), tName _ ": compiled on this instance")
    }
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tClass = ..#PACKAGE _ $Piece($Piece(..#SCREENS, ";", tI), "|", 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertTrue($Data(tPortal(tDeclaration.classicPage)), tClass _ ": its classic page " _ tDeclaration.classicPage _ " is the portal's own")
        If $Data(tPortal(tDeclaration.classicPage)) Set tPortal(tDeclaration.classicPage) = 1
    }
    Set tPage = ""
    For {
        Set tPage = $Order(tPortal(tPage))
        If tPage = "" Quit
        Do $$$AssertEquals(tPortal(tPage), 1, tPage _ ": named by one of the seven screens")
    }
}

/// <p>Each classic page's compiled <code>RESOURCE</code> names a resource the screen declares a pair of, so the screen admits
/// the account the classic page admits, narrowed by its own pairs and no further (AD-8, AD-44): the Model Browser's and the Term
/// List Manager's resources are among their screens' pairs, and the Folder Manager's either-of list holds the developer
/// resource the Folder items screen requires.</p>
/// <p>Mutation (Rule 19): change <code>AnalyticsFolderItemList</code>'s pairs to <code>%DeepSee_Portal:USE</code> and
/// <code>%Admin_Secure:USE</code> -- the Folder items leg goes red.</p>
Method TestEachClassicPagesResourceNamesAPairTheScreenDeclares()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = ..#PACKAGE _ $Piece(tRow, "|", 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration reads")
        If '$IsObject($Get(tDeclaration)) Continue
        Set tPage = tDeclaration.classicPage
        Set tResources = $Parameter(tPage, "RESOURCE")
        Do $$$AssertNotEquals(tResources, "", tPage _ ": declares a compiled RESOURCE")
        Set tFound = 0
        Set tIterator = tDeclaration.privileges.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPair) {
            If $ListFind($ListFromString(tResources, ","), tPair.resource) Set tFound = 1
        }
        Do $$$AssertTrue(tFound, tClass _ ": declares a pair on a resource of " _ tPage _ "'s RESOURCE (" _ tResources _ ")")
    }
}

}
