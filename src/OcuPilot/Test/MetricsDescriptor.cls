/// <p>Pins Story 18.11's declarations (AD-5, AD-29, AD-36, AD-43): the <code>monitor</code> source
/// kind's refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off this class's
/// <code>Cases</code> block as well; the Prometheus metrics descriptor; its declared read over canned
/// exposition text, through <class>OcuPilot.Test.Read.ReadFixture</class>; and the read tool over the
/// live collection.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. Live-safe: it creates
/// nothing and writes only process-private globals; each of its two live reads takes a sensor
/// collection, as every read does (AD-7).</p>
Class OcuPilot.Test.MetricsDescriptor Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.MetricsList";

Parameter FIXTURE = "OcuPilot.Test.Read.ReadFixture";

Parameter PORT = "OcuPilot.Port.MonitorPort";

/// <p>The corpus both engines run: each case replaces the declaration's <code>read.source</code>, sets
/// <code>read.criteria</code> or <code>privileges</code> when it carries one, and names the sentence
/// the registry's <code>check</code> (<code>read</code> or <code>criteria</code>) answers, or
/// <code>null</code>.</p>
XData Cases
{
{
  "declaration": {
    "route": "os-management/metrics-corpus", "area": "os-management", "labelKey": "metricsLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "none", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Metric", "Labels", "Value", "Help"], "secretFields": []},
    "emptyStateKey": "metricsEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST"},
      "fields": ["Metric", "Labels", "Value", "Help"],
      "filter": ["Metric", "Help"],
      "sort": {"fields": ["Metric"], "default": "Metric", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Metric", "labelKey": "metricsColumnMetric", "kind": "name"}, {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "number"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.metricscorpus"
  },
  "cases": [
    {"name": "a monitor LIST of Metrics is sound", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST"}, "expected": null},
    {"name": "and declares no criteria", "check": "criteria", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST"}, "expected": null},
    {"name": "the sensors endpoint a part names", "check": "read", "source": {"port": "monitor", "endpoint": "Sensors", "type": "LIST"}, "expected": "read.source.endpoint 'Sensors' is not one of the monitor port's endpoints ('Metrics', 'Interfaces', 'MessageVolume', 'DatabaseImpact') (AD-29)"},
    {"name": "a single-object type", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a monitor source, which lists the instance's metrics and interoperability usage (AD-36)"},
    {"name": "the volume list type", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "VOLUMELIST"}, "expected": "read.source.type 'VOLUMELIST' is declared on a monitor source, which lists the instance's metrics and interoperability usage (AD-36)"},
    {"name": "a per-row detail call", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST", "rowGet": {"key": "Metric", "param": "name", "fields": ["Help"], "derived": []}}, "expected": "read.source.rowGet is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "a parent list", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST", "forEach": {"endpoint": "Metrics", "key": "Metric", "param": "name", "fields": []}}, "expected": "read.source.forEach is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "a fixed query", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST", "query": {"prefix": "iris"}}, "expected": "read.source.query is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "parts", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a monitor source, which answers its list whole (AD-36)"},
    {"name": "a list over one member", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST", "rows": "rows"}, "expected": "read.source.rows is declared on a 'monitor' source, and a list over one member reads an admin endpoint's one-object answer (AD-36)"},
    {"name": "server criteria", "check": "criteria", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST"}, "criteria": {"fields": [{"param": "pattern", "labelKey": "metricsColumnMetric", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on a 'monitor' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)"},
    {"name": "no read of the system database", "check": "read", "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST"}, "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}], "expected": "read.source.port 'monitor' requires the declared privileges to include %DB_IRISSYS:READ, because the port reads in %SYS (AD-29)"},
    {"name": "an unknown port", "check": "read", "source": {"port": "monitors", "endpoint": "Metrics", "type": "LIST"}, "expected": "read.source.port 'monitors' is not one of 'admin', 'state', 'mgmnt', 'logsource', 'path', 'timeline', 'background', 'atelier', 'encryption', 'docdb', 'sqlactivity', 'interop', 'access' or 'monitor', the fourteen sources a declared read names (AD-36)"}
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

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry,
/// and the corpus refuses at least one shape.</p>
/// <p>Mutation (Rule 19): drop the monitor arm from
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> -- the endpoint, type and key cases go red;
/// drop <code>SOURCEMONITOR</code> from its last arm -- the system database case goes red.</p>
Method TestTheMonitorSourceRefusals()
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
        If tCase.%GetTypeOf("privileges") = "array" Do tDeclaration.%Set("privileges", ##class(%DynamicArray).%FromJSON(tCase.privileges.%ToJSON()))
        If tCase.check = "criteria" {
            Set tProblem = ##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration)
        } Else {
            Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        }
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertTrue(tRefusals >= 10, "the corpus refuses its shapes: " _ tRefusals)
}

/// <p>The descriptor declares the screen the spec names -- OS management's twenty-first side-bar entry,
/// an instance-scoped list with no id and no entity type, read through the monitor port under the
/// port's two pairs and no own pair, never refreshing, with no action and no classic page, its four
/// fields filtered and sorted as declared, and three prompts: one in the Capacity group and two in
/// Troubleshooting.</p>
/// <p>Mutation (Rule 19): set <code>refreshes</code> true -- the refresh leg goes red; drop
/// <code>%DB_IRISSYS:READ</code> from <parameter>OcuPilot.Port.MonitorPort.PAIRS</parameter> -- the
/// pairs leg goes red.</p>
Method TestTheDescriptorShape()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.entityType, "os-management/metrics|os-management|21|list|instance|", "its route, area, position, archetype, scope and no entity type")
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""none"",""parts"":[]}", "its id is none")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "its pairs are the port's")
    Do $$$AssertEquals(##class(OcuPilot.Test.SqlActivityDescriptor).Spelled($ClassMethod(..#DESCRIPTOR, "PrivilegePairs")), $Parameter(..#PORT, "PAIRS"), "and equal the port's PAIRS, in order, so the side bar refuses whom the port refuses")
    Do $$$AssertEquals($Select($IsObject(tDeclaration.%Get("ownPrivileges")): tDeclaration.ownPrivileges.%Size(), 1: 0), 0, "and none is its own")
    Do $$$AssertEquals(tDeclaration.refreshes _ "|" _ tDeclaration.refreshRates.%ToJSON(), "0|[]", "it never refreshes: each read rewrites the sensor baseline (AD-7)")
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size(), "|0", "no action")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""monitor"",""endpoint"":""Metrics"",""type"":""LIST""}", "its read names the monitor port")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Metric"",""Labels"",""Value"",""Help""]", "and the row's fields")
    Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), "every read field is a context field")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "and none is secret")
    Do $$$AssertEquals(tDeclaration.read.filter.%ToJSON() _ "|" _ tDeclaration.read.sort.fields.%ToJSON() _ "|" _ tDeclaration.read.sort.default _ "|" _ tDeclaration.read.sort.direction _ "|" _ tDeclaration.read.paging, "[""Metric"",""Labels"",""Help""]|[""Metric"",""Value""]|Metric|asc|cap", "filtered on the name, labels and help, sorted by metric")
    Do $$$AssertEquals(tDeclaration.read.note.key, "metricsNote", "with the note that says why it never refreshes")
    Do $$$AssertEquals(tDeclaration.table.columns.%Size() _ "|" _ tDeclaration.table.columns.%Get(0).kind _ "|" _ tDeclaration.table.columns.%Get(1).kind _ "|" _ tDeclaration.table.columns.%Get(2).kind _ "|" _ tDeclaration.table.columns.%Get(3).kind, "4|name|identifier|number|text", "four columns")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size() _ "|" _ tDeclaration.suggestedPrompts.%Get(0).groupKey _ "|" _ tDeclaration.suggestedPrompts.%Get(1).groupKey _ "|" _ tDeclaration.suggestedPrompts.%Get(2).groupKey, "3|promptGroupCapacity|promptGroupTroubleshooting|promptGroupTroubleshooting", "three prompts")
    Do $$$AssertEquals(tDeclaration.commandAliases.%ToJSON(), "[""prometheus metrics"",""metrics"",""sensors""]", "its aliases")
    Do $$$AssertEquals("[" _ tDeclaration.classicPage _ "]|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.emptyStateKey _ "|" _ tDeclaration.table.emptyNextKey, "[]|osmgmt.metrics|metricsEmpty|tableReadOnlyEmptyNext", "no classic page, its tool identifier and its read-only empty state")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
}

/// <p>The declared read, issued as <class>OcuPilot.Screen.Read</class> issues it over canned exposition
/// text, answers one row per sample in exposition order as <code>{Metric, Labels, Value, Help}</code>;
/// a cap of two over four samples answers two rows and reports the cut; one collection is taken in
/// <code>%SYS</code>.</p>
/// <p>Mutation (Rule 19): drop <code>SOURCEMONITOR</code> from the source list in
/// <method>OcuPilot.Screen.Read.Execute</method> -- this leg, the next and the tool's go red with the
/// internal fault.</p>
Method TestTheReadAnswersTheSamplesInOrderAndReportsTheCut()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText($ListToString($ListBuild("# HELP probe_b the second", "probe_b{id=""x y""} 2", "probe_a 1", "probe_c NaN", "probe_d 4"), $Char(10)))
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Metric"",""Labels"",""Value"",""Help""]", "the declared fields")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPort).RowsText(tAnswer.rows), $ListToString($ListBuild("probe_b|id=""x y""|2:number|the second", "probe_a||1:number|", "probe_c||NaN:string|", "probe_d||4:number|"), $Char(10)), "one row per sample, in exposition order")
    Do $$$AssertEquals(tAnswer.truncated, 0, "not truncated")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 1, "from one collection")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceNamespace(), "%SYS", "taken in %SYS")

    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, 2, .tCut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a cap of two reads")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPort).RowsText(tCut.rows), $ListToString($ListBuild("probe_b|id=""x y""|2:number|the second", "probe_a||1:number|"), $Char(10)), "and keeps the first two rows")
    Do $$$AssertEquals(tCut.truncated, 1, "reporting the cut")

    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, 4, .tExact, .tHttp, .tFault)
    Do $$$AssertEquals(tExact.rows.%Size() _ "|" _ tExact.truncated, "4|0", "a cap equal to the sample count is not a cut")
}

/// <p>A malformed sample fails the screen's read 500 <code>INTERNAL</code>, logged once, with no rows;
/// a caller missing either pair is refused 403 naming it and no collection is taken.</p>
/// <p>Mutation (Rule 19): skip the sample with no value in
/// <method>OcuPilot.Port.MonitorPort.Samples</method> -- the failure leg goes red; drop
/// <code>%DB_IRISSYS:READ</code> from <parameter>OcuPilot.Port.MonitorPort.PAIRS</parameter> -- the
/// refusal legs go red.</p>
Method TestAMalformedSampleAndAMissingPairFailTheRead()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText($ListToString($ListBuild("probe_a 1", "probe_b"), $Char(10)))
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a sample with no value fails the read")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "500 INTERNAL", "as the generic internal fault")
    Do $$$AssertEquals($Get(tAnswer), "", "answering no rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, "logged once")

    Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetText("probe_a 1")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    For tCase = $ListBuild("%DB_IRISSYS", "READ", "%Admin_Operate:USE"), $ListBuild("%Admin_Operate", "USE", "%DB_IRISSYS:READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tCase, 1), $List(tCase, 2))
        Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(..#DESCRIPTOR, "", .tDenied, .tHttp, .tFault)
        Set tPair = ""
        If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: "") _ " " _ tPair, "403 AUTH.NOPRIVILEGE " _ $List(tCase, 3), "holding only " _ $List(tCase, 1) _ ": 403 naming the pair that failed")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).SourceCalls(), 0, "with no collection")
    }
}

/// <p>The read tool <code>osmgmt.metrics.read</code> resolves and answers the live collection as rows of
/// the four fields, at most the tool's 200 rows, and the screen's read answers the same shape.</p>
/// <p>Mutation (Rule 19): drop <code>SOURCEMONITOR</code> from the source list in
/// <method>OcuPilot.Screen.Read.Execute</method> -- the tool answers the internal fault and this goes
/// red.</p>
Method TestTheReadToolAnswersTheLiveRows()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.metrics.read", .tTool, 1)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    If '$IsObject($Get(tTool)) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp), 200, "the tool answers")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertTrue((tResult.rows.%Size() > 0) && (tResult.rows.%Size() <= 200), "with at most 200 rows, and some: " _ tResult.rows.%Size())
    Set tFirst = tResult.rows.%Get(0)
    Do $$$AssertEquals(tFirst.%GetTypeOf("Metric") _ "|" _ tFirst.%GetTypeOf("Labels") _ "|" _ tFirst.%GetTypeOf("Help"), "string|string|string", "each row a metric with its labels and help")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 5, .tScreen, .tScreenHttp, .tScreenFault)
    Do $$$AssertEquals($Get(tScreenHttp), 200, "and the screen's read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tScreen)): tScreen.rows.%Size() _ "|" _ tScreen.truncated, 1: ""), "5|1", "cut at the cap it was given")
}

/// <p>The port carries no write, so it has no script form (AD-59).</p>
Method TestTheScriptForms()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Metrics", "LIST"), "", "no script form")
    Kill tQuery
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "Metrics", "LIST", .tQuery).%ToJSON(), "[]", "and no script steps")
}

}
