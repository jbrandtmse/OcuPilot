/// <p>Pins Story 18.37's declarations (AD-5, AD-29, AD-36, AD-43, AD-44): the <code>monitor</code> source
/// kind's four endpoints and its refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off this
/// class's <code>Cases</code> block as well; the three Interoperability usage tabs and the group they form;
/// each tab's declared read over armed rows, through <class>OcuPilot.Test.Read.ReadFixture</class>; and the
/// three read tools over the live queries.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. Live-safe: it creates nothing and
/// writes only process-private globals; its live reads only run the vendor's usage queries.</p>
Class OcuPilot.Test.InteropUsageDescriptor Extends %UnitTest.TestCase
{

Parameter FIXTURE = "OcuPilot.Test.Read.ReadFixture";

Parameter PORT = "OcuPilot.Port.MonitorPort";

/// <p>The package the three descriptors sit in.</p>
Parameter PACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The group every tab declares: the first tab's own route.</p>
Parameter GROUP = "os-management/interoperability-usage";

/// <p>The three tabs, in position order, as
/// <code>descriptor:route:endpoint:tool:emptyKey:tabLabelKey:sideBarPosition:fields</code>, the fields
/// separated by <code>/</code>.</p>
Parameter TABS = "InteropUsageTab:os-management/interoperability-usage:Interfaces:osmgmt.interopusage:interopUsageInterfacesEmpty:interopUsageInterfacesTab:22:Type/Namespace/Protocol/ActiveNow/Count,InteropUsageVolumeTab:os-management/interoperability-usage/volume:MessageVolume:osmgmt.interopvolume:interopUsageVolumeEmpty:interopUsageVolumeLabel:0:Namespace/Type/Volume,InteropUsageImpactTab:os-management/interoperability-usage/impact:DatabaseImpact:osmgmt.interopimpact:interopUsageImpactEmpty:interopUsageImpactLabel:0:Database/DataCreated";

/// <p>The corpus both engines run: each case replaces the declaration's <code>read.source</code>, sets
/// <code>read.criteria</code> or <code>privileges</code> when it carries one, and names the sentence the
/// registry's <code>check</code> (<code>read</code> or <code>criteria</code>) answers, or <code>null</code>.</p>
XData Cases
{
{
  "declaration": {
    "route": "os-management/interop-usage-corpus", "area": "os-management", "labelKey": "interopUsageLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "none", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Namespace", "Type", "Volume"], "secretFields": []},
    "emptyStateKey": "interopUsageVolumeEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "monitor", "endpoint": "MessageVolume", "type": "LIST"},
      "fields": ["Namespace", "Type", "Volume"],
      "filter": ["Namespace", "Type"],
      "sort": {"fields": ["Namespace", "Volume"], "default": "Volume", "direction": "desc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "name"}, {"field": "Volume", "labelKey": "interopItemTabMessages", "kind": "number"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.interopusagecorpus"
  },
  "cases": [
    {"name": "the metrics endpoint is sound", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST"}, "expected": null},
    {"name": "the interfaces endpoint is sound", "check": "read", "source": {"port": "monitor", "endpoint": "Interfaces", "type": "LIST"}, "expected": null},
    {"name": "the message volume endpoint is sound", "check": "read", "source": {"port": "monitor", "endpoint": "MessageVolume", "type": "LIST"}, "expected": null},
    {"name": "the database impact endpoint is sound", "check": "read", "source": {"port": "monitor", "endpoint": "DatabaseImpact", "type": "LIST"}, "expected": null},
    {"name": "and declares no criteria", "check": "criteria", "source": {"port": "monitor", "endpoint": "Interfaces", "type": "LIST"}, "expected": null},
    {"name": "the sensors endpoint a part names", "check": "read", "source": {"port": "monitor", "endpoint": "Sensors", "type": "LIST"}, "expected": "read.source.endpoint 'Sensors' is not one of the monitor port's endpoints ('Metrics', 'Interfaces', 'MessageVolume', 'DatabaseImpact') (AD-29)"},
    {"name": "an endpoint in another letter case", "check": "read", "source": {"port": "monitor", "endpoint": "interfaces", "type": "LIST"}, "expected": "read.source.endpoint 'interfaces' is not one of the monitor port's endpoints ('Metrics', 'Interfaces', 'MessageVolume', 'DatabaseImpact') (AD-29)"},
    {"name": "a single-object type", "check": "read", "source": {"port": "monitor", "endpoint": "Interfaces", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a monitor source, which lists the instance's metrics and interoperability usage (AD-36)"},
    {"name": "a per-row detail call", "check": "read", "source": {"port": "monitor", "endpoint": "MessageVolume", "type": "LIST", "rowGet": {"key": "Namespace", "param": "name", "fields": ["Volume"], "derived": []}}, "expected": "read.source.rowGet is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "a parent list", "check": "read", "source": {"port": "monitor", "endpoint": "DatabaseImpact", "type": "LIST", "forEach": {"endpoint": "DatabaseImpact", "key": "Database", "param": "name", "fields": []}}, "expected": "read.source.forEach is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "a fixed query", "check": "read", "source": {"port": "monitor", "endpoint": "Interfaces", "type": "LIST", "query": {"prefix": "iris"}}, "expected": "read.source.query is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "parts", "check": "read", "source": {"port": "monitor", "endpoint": "Interfaces", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "server criteria", "check": "criteria", "source": {"port": "monitor", "endpoint": "Interfaces", "type": "LIST"}, "criteria": {"fields": [{"param": "pattern", "labelKey": "interopUsageColumnProtocol", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on a 'monitor' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)"},
    {"name": "no read of the system database", "check": "read", "source": {"port": "monitor", "endpoint": "DatabaseImpact", "type": "LIST"}, "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}], "expected": "read.source.port 'monitor' requires the declared privileges to include %DB_IRISSYS:READ, because the port reads in %SYS (AD-29)"}
  ]
}
}

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>The <var>pIndex</var>th piece <var>pPiece</var> of <parameter>TABS</parameter>.</p>
ClassMethod Tab(pIndex As %Integer, pPiece As %Integer) As %String
{
    Quit $Piece($Piece(..#TABS, ",", pIndex), ":", pPiece)
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry: the
/// four endpoints the monitor port lists are sound, and another endpoint, another type and each of the
/// keys a list answered whole cannot carry are refused with one sentence.</p>
/// <p>Mutation (Rule 19): let the registry's monitor arm admit any endpoint -- the endpoint cases go red;
/// drop the arm -- the key and type cases go red as well.</p>
Method TestTheMonitorSourceAdmitsItsFourEndpointsAndRefusesTheRest()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tSC)
    Do $$$AssertTrue($IsObject(tXData), "the corpus is declared")
    If '$IsObject(tXData) Quit
    Set tCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tRefusals = 0
    Set tSound = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tDeclaration = ##class(%DynamicObject).%FromJSON(tCorpus.declaration.%ToJSON())
        Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(tCase.source.%ToJSON()))
        If tCase.%GetTypeOf("criteria") = "object" Do tDeclaration.read.%Set("criteria", ##class(%DynamicObject).%FromJSON(tCase.criteria.%ToJSON()))
        If tCase.%GetTypeOf("privileges") = "array" Do tDeclaration.%Set("privileges", ##class(%DynamicArray).%FromJSON(tCase.privileges.%ToJSON()))
        If tCase.check = "criteria" {
            Set tProblem = ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration)
        } Else {
            Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        }
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        If (tExpected = "") && (tCase.check = "read") Set tSound = tSound + 1
    }
    Do $$$AssertEquals(tSound, 4, "the four endpoints are sound")
    Do $$$AssertTrue(tRefusals >= 8, "the corpus refuses its shapes: " _ tRefusals)
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Port.MonitorPort).Endpoints()), "Metrics,Interfaces,MessageVolume,DatabaseImpact", "and they are the port's own list")
}

/// <p>The three declarations pass the read and tab grammar and form one group: Interfaces is the side
/// bar's entry at the group's route, the other two unlisted at positions 2 and 3. Each is a
/// <code>detail</code> screen over <code>{monitor, its endpoint, LIST}</code>, with the port's two pairs
/// and no own pair, no entity type, instance scope, no id, no action, no refresh,
/// <code>%CSP.UI.Portal.InteroperabilityUsage</code> as its classic page with no exemption, a context
/// carrying exactly the read's fields, its own tool identifier, empty text and tab label, the same note and
/// the same three Capacity prompts. Interfaces alone carries the two command aliases, and reads an empty
/// namespace or protocol as "All".</p>
/// <p>Mutation (Rule 19): set <code>refreshes</code> true on any tab -- the refresh leg goes red; drop
/// <code>%DB_IRISSYS:READ</code> from <parameter>OcuPilot.Port.MonitorPort.PAIRS</parameter> -- the
/// pairs leg goes red; drop the Protocol column's <code>emptyKey</code> -- the cell leg goes red.</p>
Method TestTheThreeTabsDeclareTheirReadsAndFormOneGroup()
{
    Set tValidateSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tValidateSC, "the registry validates with the three tabs in it: " _ $Get(tProblem))
    For tI = 1:1:3 {
        Set tClass = ..#PACKAGE _ ..Tab(tI, 1)
        Set tWhere = ..Tab(tI, 1) _ ": "
        Set tFields = $Translate(..Tab(tI, 8), "/", ",")
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tWhere _ "the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tWhere _ "its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TabProblem(tDeclaration), "", tWhere _ "its tab is the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tWhere _ "and it links out to nothing")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute(..Tab(tI, 2)), tClass, tWhere _ "its route resolves to it")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..Tab(tI, 4)), tClass, tWhere _ "and so does its tool identifier")

        Set tTab = tDeclaration.tab
        Do $$$AssertEquals(tTab.group _ "|" _ tTab.position _ "|" _ tTab.labelKey, ..#GROUP _ "|" _ tI _ "|" _ ..Tab(tI, 6), tWhere _ "the group, its position and its tab label")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), +..Tab(tI, 7), tWhere _ "Interfaces is listed and the others are unlisted")
        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "Archetype") _ "|" _ $ClassMethod(tClass, "IsBuilt"), "os-management|detail|1", tWhere _ "a built detail screen in OS management")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, tWhere _ "never refreshing")
        Do $$$AssertEquals(##class(OcuPilot.Test.SqlActivityDescriptor).Spelled($ClassMethod(tClass, "PrivilegePairs")), $Parameter(..#PORT, "PAIRS"), tWhere _ "the port's pairs, in order, so the side bar refuses whom the port refuses")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "OwnPrivilegePairs")), 0, tWhere _ "none of them its own")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", tWhere _ "which the area covers")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind"), "|instance|none", tWhere _ "no entity type, instance scope, no id")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, tWhere _ "no action")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.InteroperabilityUsage", tWhere _ "the classic page it replaces")
        Do $$$AssertEquals($ClassMethod(tClass, "EmptyStateKey") _ "|" _ tDeclaration.table.emptyNextKey, ..Tab(tI, 5) _ "|tableReadOnlyEmptyNext", tWhere _ "its own read-only empty state")
        Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""monitor"",""endpoint"":""" _ ..Tab(tI, 3) _ """,""type"":""LIST""}", tWhere _ "its read names the monitor port's endpoint")
        Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""" _ $Replace(tFields, ",", """,""") _ """]", tWhere _ "and the row's fields")
        Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON() _ "|" _ tDeclaration.context.secretFields.%Size(), tDeclaration.read.fields.%ToJSON() _ "|0", tWhere _ "the context is exactly the read's fields, none secret")
        Do $$$AssertEquals(tDeclaration.read.paging _ "|" _ tDeclaration.read.note.key _ "|" _ tDeclaration.read.note.text, "cap|interopUsageNote|Counts cover all the usage data the instance still keeps, with no date range.", tWhere _ "bounded by the cap, under the note")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%ToJSON(), "[{""groupKey"":""promptGroupCapacity"",""textKey"":""interopUsagePrompt1""},{""groupKey"":""promptGroupCapacity"",""textKey"":""interopUsagePrompt2""},{""groupKey"":""promptGroupCapacity"",""textKey"":""interopUsagePrompt3""}]", tWhere _ "the three shared Capacity prompts")
        Do $$$AssertEquals(tDeclaration.commandAliases.%ToJSON(), $Select(tI = 1: "[""interoperability usage"",""interop usage""]", 1: "[]"), tWhere _ "its aliases")
        Do $$$AssertEquals(tDeclaration.table.columns.%Get(0).field _ "|" _ tDeclaration.table.columns.%Get(0).kind, $Piece(tFields, ",", 1) _ "|name", tWhere _ "whose first column is the name column")
    }

    Set tSC = $ClassMethod(..#PACKAGE _ ..Tab(1, 1), "DeclarationJson", .tFirst)
    Do $$$AssertEquals(tFirst.read.filter.%ToJSON() _ "|" _ tFirst.read.sort.default _ "|" _ tFirst.read.sort.direction, "[""Type"",""Namespace"",""Protocol""]|Type|asc", "Interfaces filters on its three names and sorts by type")
    Do $$$AssertEquals(tFirst.table.columns.%ToJSON(), "[{""field"":""Type"",""labelKey"":""tableColumnType"",""kind"":""name""},{""field"":""Namespace"",""labelKey"":""headerNamespaceLabel"",""kind"":""identifier"",""emptyKey"":""interopUsageAll""},{""field"":""Protocol"",""labelKey"":""interopUsageColumnProtocol"",""kind"":""text"",""emptyKey"":""interopUsageAll""},{""field"":""ActiveNow"",""labelKey"":""interopUsageColumnActiveNow"",""kind"":""number""},{""field"":""Count"",""labelKey"":""interopColumnCount"",""kind"":""number""}]", "its columns, the namespace and protocol cells reading All when empty")
    Set tSC = $ClassMethod(..#PACKAGE _ ..Tab(2, 1), "DeclarationJson", .tVolume)
    Do $$$AssertEquals(tVolume.read.filter.%ToJSON() _ "|" _ tVolume.read.sort.default _ "|" _ tVolume.read.sort.direction, "[""Namespace"",""Type""]|Volume|desc", "Message volume filters on namespace and type and sorts by volume, largest first")
    Do $$$AssertEquals(tVolume.table.columns.%ToJSON(), "[{""field"":""Namespace"",""labelKey"":""headerNamespaceLabel"",""kind"":""name""},{""field"":""Type"",""labelKey"":""tableColumnType"",""kind"":""text""},{""field"":""Volume"",""labelKey"":""interopItemTabMessages"",""kind"":""number""}]", "its columns")
    Set tSC = $ClassMethod(..#PACKAGE _ ..Tab(3, 1), "DeclarationJson", .tImpact)
    Do $$$AssertEquals(tImpact.read.filter.%ToJSON() _ "|" _ tImpact.read.sort.default _ "|" _ tImpact.read.sort.direction, "[""Database""]|DataCreated|desc", "Database impact filters on the database and sorts by data created, largest first")
    Do $$$AssertEquals(tImpact.table.columns.%ToJSON(), "[{""field"":""Database"",""labelKey"":""systemInfoDatabase"",""kind"":""name""},{""field"":""DataCreated"",""labelKey"":""interopUsageColumnDataCreated"",""kind"":""number""}]", "its columns")
}

/// <p>Each tab's declared read, issued as <class>OcuPilot.Screen.Read</class> issues it over armed rows,
/// answers one row per armed row as the tab's fields, typed, with a totals row's empty cells kept (the
/// interfaces are armed as the vendor answers them, each grouping twice, and answer one row per grouping); a
/// cap of one over two rows answers one and reports the cut; one query runs, in <code>%SYS</code>.</p>
/// <p>Mutation (Rule 19): drop <code>SOURCEMONITOR</code> from the source list in
/// <method>OcuPilot.Screen.Read.Execute</method> -- every leg goes red with the internal fault; take
/// <code>Count</code> from the <code>Active</code> 1 row in <method>OcuPilot.Port.MonitorPort.Groupings</method>
/// -- the interfaces leg goes red.</p>
Method TestEachReadAnswersItsArmedRowsAndReportsTheCut()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("Interfaces", "[{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""Active"":""1"",""Count"":""4""},{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""Active"":""0"",""Count"":""11""},{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""Active"":""1"",""Count"":""2""},{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""Active"":""0"",""Count"":""9""}]")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("MessageVolume", "[{""Namespace"":""USER"",""Type"":""Inbound"",""Volume"":""80""},{""Namespace"":""USER"",""Type"":""Outbound"",""Volume"":""18""}]")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("DatabaseImpact", "[{""Database"":""USER"",""DataCreated"":""7""},{""Database"":""HSCUSTOM"",""DataCreated"":""3""}]")
    Set tExpected = $ListBuild("[{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""ActiveNow"":4,""Count"":11},{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""ActiveNow"":2,""Count"":9}]", "[{""Namespace"":""USER"",""Type"":""Inbound"",""Volume"":80},{""Namespace"":""USER"",""Type"":""Outbound"",""Volume"":18}]", "[{""Database"":""USER"",""DataCreated"":7},{""Database"":""HSCUSTOM"",""DataCreated"":3}]")
    For tI = 1:1:3 {
        Set tClass = ..#PACKAGE _ ..Tab(tI, 1)
        Set tWhere = ..Tab(tI, 1) _ ": "
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRaise(0)
        Set tBefore = ##class(OcuPilot.Test.MonitorPortFixture).UsageCalls()
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tWhere _ "the read succeeds")
        Do $$$AssertEquals(tHttp, 200, tWhere _ "with 200")
        If '$IsObject($Get(tAnswer)) Continue
        Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""" _ $Replace($Translate(..Tab(tI, 8), "/", ","), ",", """,""") _ """]", tWhere _ "the declared fields")
        Do $$$AssertEquals(tAnswer.rows.%ToJSON() _ "|" _ tAnswer.truncated, $List(tExpected, tI) _ "|0", tWhere _ "one typed row per armed row (per grouping for the interfaces), not truncated")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).UsageCalls() - tBefore _ " " _ ##class(OcuPilot.Test.MonitorPortFixture).UsageNamespace(), "1 %SYS", tWhere _ "from one query taken in %SYS")

        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, 1, .tCut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tWhere _ "a cap of one reads")
        Do $$$AssertEquals($Select($IsObject($Get(tCut)): tCut.rows.%Size() _ "|" _ tCut.truncated, 1: "absent"), "1|1", tWhere _ "and keeps the first row, reporting the cut")
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, 2, .tExact, .tHttp, .tFault)
        Do $$$AssertEquals($Select($IsObject($Get(tExact)): tExact.rows.%Size() _ "|" _ tExact.truncated, 1: "absent"), "2|0", tWhere _ "a cap equal to the row count is not a cut")
    }
}

/// <p>A source that answers no rows reads as a list with no rows, not truncated, 200: the answer the
/// client shows as the tab's empty state.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Usage</method> fail a source that answers
/// no rows -- every tab goes red.</p>
Method TestAnEmptyListReadsAsNoRows()
{
    For tI = 1:1:3 {
        Set tClass = ..#PACKAGE _ ..Tab(tI, 1)
        Set tWhere = ..Tab(tI, 1) _ ": "
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows(..Tab(tI, 3), "[]")
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tWhere _ "the read succeeds")
        Do $$$AssertEquals(tHttp, 200, tWhere _ "with 200")
        If '$IsObject($Get(tAnswer)) Continue
        Do $$$AssertEquals(tAnswer.rows.%ToJSON() _ "|" _ tAnswer.truncated, "[]|0", tWhere _ "no rows, not truncated")
    }
}

/// <p>A query that raises fails each tab's read 500 <code>INTERNAL</code>, logged once, with no rows; a
/// caller missing either pair is refused 403 naming it, and no query runs.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Gate</method> answer OK -- the refusal
/// legs go red; skip the status test after <method>OcuPilot.Port.MonitorPort.UsageSource</method> -- the
/// failure leg goes red.</p>
Method TestAFaultFailsTheReadAndAMissingPairRefusesIt()
{
    For tI = 1:1:3 {
        Set tClass = ..#PACKAGE _ ..Tab(tI, 1)
        Set tWhere = ..Tab(tI, 1) _ ": "
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRaise(1)
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tWhere _ "a query that raises fails the read")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "500 INTERNAL", tWhere _ "as the generic internal fault")
        Do $$$AssertEquals($Get(tAnswer), "", tWhere _ "answering no rows")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, tWhere _ "logged once")

        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
        For tCase = $ListBuild("%DB_IRISSYS", "READ", "%Admin_Operate:USE"), $ListBuild("%Admin_Operate", "USE", "%DB_IRISSYS:READ") {
            Do ##class(OcuPilot.Test.ScreenGate).Reset()
            Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tCase, 1), $List(tCase, 2))
            Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tClass, "", .tDenied, .tHttp, .tFault)
            Set tPair = ""
            If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: "") _ " " _ tPair, "403 AUTH.NOPRIVILEGE " _ $List(tCase, 3), tWhere _ "holding only " _ $List(tCase, 1) _ ": 403 naming the pair that failed")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).UsageCalls(), 0, tWhere _ "and no query ran")
    }
}

/// <p>The read tools <code>osmgmt.interopusage.read</code>, <code>osmgmt.interopvolume.read</code> and
/// <code>osmgmt.interopimpact.read</code> resolve and answer the live queries as rows of exactly their
/// fields, at most the tool's 200 rows; the interfaces tool answers its totals rows.</p>
/// <p>Mutation (Rule 19): drop <code>SOURCEMONITOR</code> from the source list in
/// <method>OcuPilot.Screen.Read.Execute</method> -- every tool answers the internal fault and this goes
/// red.</p>
Method TestTheThreeReadToolsAnswerTheLiveRows()
{
    For tI = 1:1:3 {
        Set tTool = ..Tab(tI, 4) _ ".read"
        Set tFields = $Translate(..Tab(tI, 8), "/", ",")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tTool, .tResolved, 1)
        Do $$$AssertStatusOK(tSC, tTool _ ": the read tool resolves")
        If '$IsObject($Get(tResolved)) Continue
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tResolved, {}, 200, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp), 200, tTool _ ": the tool answers")
        If '$IsObject($Get(tResult)) Continue
        Do $$$AssertTrue(tResult.rows.%Size() <= 200, tTool _ ": at most 200 rows: " _ tResult.rows.%Size())
        Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""" _ $Replace(tFields, ",", """,""") _ """]", tTool _ ": the declared fields")
        Set tWhole = 0
        Set tIterator = tResult.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tKeys = ""
            Set tKeyIterator = tRow.%GetIterator()
            While tKeyIterator.%GetNext(.tKey) {
                Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
            }
            If tKeys = tFields Set tWhole = tWhole + 1
        }
        Do $$$AssertEquals(tWhole, tResult.rows.%Size(), tTool _ ": every row is exactly " _ tFields)
        If tI = 1 Do $$$AssertTrue(tResult.rows.%Size() > 0, tTool _ ": the interfaces answer holds its totals rows")
    }
}

}
