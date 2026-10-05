/// <p>Pins Story 19.10's declarations with no instance write (AD-5, AD-13, AD-36, AD-43, AD-59): the
/// <code>sqlactivity</code> source kind's refusals, which <file>ui/tools/screen-mirror.test.mjs</file>
/// runs off this class's <code>Cases</code> block as well; the SQL activity descriptor; its entity
/// type; and the port's empty script forms.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. Live-safe: it writes
/// nothing.</p>
Class OcuPilot.Test.SqlActivityDescriptor Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.SqlActivityList";

Parameter PORT = "OcuPilot.Port.SqlActivityPort";

/// <p>The corpus both engines run: each case replaces the declaration's <code>read.source</code>, sets
/// <code>read.criteria</code> when it carries one, and names the sentence the registry's
/// <code>check</code> (<code>read</code> or <code>criteria</code>) answers, or <code>null</code>.</p>
XData Cases
{
{
  "declaration": {
    "route": "os-management/sql-activity-corpus", "area": "os-management", "labelKey": "sqlActivityLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "sql-statement", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "composite", "parts": ["Server", "ProcessID", "StatementHash"]},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Server", "ProcessID", "StatementHash", "Statement"], "secretFields": []},
    "emptyStateKey": "sqlActivityEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST"},
      "fields": ["Server", "ProcessID", "StatementHash", "Statement"],
      "filter": ["ProcessID", "Statement"],
      "sort": {"fields": ["ProcessID"], "default": "ProcessID", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "ProcessID", "labelKey": "processColumnPid", "kind": "name"}, {"field": "Statement", "labelKey": "explorerSqlColumnStatement", "kind": "identifier"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.sqlactivitycorpus"
  },
  "cases": [
    {"name": "a sqlactivity LIST of CurrentStatements is sound", "check": "read", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST"}, "expected": null},
    {"name": "and declares no criteria", "check": "criteria", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST"}, "expected": null},
    {"name": "another endpoint", "check": "read", "source": {"port": "sqlactivity", "endpoint": "Statements", "type": "LIST"}, "expected": "read.source.endpoint 'Statements' is not the sqlactivity port's endpoint ('CurrentStatements') (AD-29)"},
    {"name": "a single-object type", "check": "read", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a sqlactivity source, which lists the instance's running SQL statements (AD-36)"},
    {"name": "a per-row detail call", "check": "read", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST", "rowGet": {"key": "ProcessID", "param": "pid", "fields": ["Statement"], "derived": []}}, "expected": "read.source.rowGet is declared on a sqlactivity source, which answers the running statements whole (AD-36)"},
    {"name": "a parent list", "check": "read", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST", "forEach": {"endpoint": "CurrentStatements", "key": "ProcessID", "param": "pid", "fields": []}}, "expected": "read.source.forEach is declared on a sqlactivity source, which answers the running statements whole (AD-36)"},
    {"name": "a fixed query", "check": "read", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST", "query": {"namespace": "USER"}}, "expected": "read.source.query is declared on a sqlactivity source, which answers the running statements whole (AD-36)"},
    {"name": "parts", "check": "read", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a sqlactivity source, which answers the running statements whole (AD-36)"},
    {"name": "a list over one member", "check": "read", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST", "rows": "rows"}, "expected": "read.source.rows is declared on a 'sqlactivity' source, and a list over one member reads an admin endpoint's one-object answer (AD-36)"},
    {"name": "server criteria", "check": "criteria", "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST"}, "criteria": {"fields": [{"param": "pattern", "labelKey": "explorerSqlColumnStatement", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on a 'sqlactivity' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)"},
    {"name": "an unknown port", "check": "read", "source": {"port": "sqlactivities", "endpoint": "CurrentStatements", "type": "LIST"}, "expected": "read.source.port 'sqlactivities' is not one of 'admin', 'state', 'mgmnt', 'logsource', 'path', 'timeline', 'background', 'atelier', 'encryption', 'docdb' or 'sqlactivity', the eleven sources a declared read names (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry,
/// and the corpus refuses at least one shape.</p>
/// <p>Mutation (Rule 19): drop the sqlactivity arm from
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> -- the endpoint, type and key cases go red.</p>
Method TestTheSqlActivitySourceRefusals()
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
    Do $$$AssertTrue(tRefusals >= 8, "the corpus refuses its shapes: " _ tRefusals)
}

/// <p>AC5, AC6 and AC8: the descriptor declares the screen the spec names -- OS management's twentieth
/// side-bar entry, an instance-scoped list of <code>sql-statement</code> rows keyed by the vendor's
/// IdKey, read through the sqlactivity port under the port's two pairs and no own pair, refreshing at
/// 5, 10, 30 or 60 seconds and off by default, with no action, its Process ID cell opening Process
/// details unless the row is remote, and three prompts in the Troubleshooting group.</p>
/// <p>Mutation (Rule 19): set <code>refreshes</code> false -- the refresh leg goes red; remove the third
/// prompt -- the prompts leg goes red; drop a pair from
/// <parameter>OcuPilot.Port.SqlActivityPort.PAIRS</parameter> -- the pairs leg goes red.</p>
Method TestTheDescriptorShape()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.entityType, "os-management/sql-activity|os-management|20|list|instance|sql-statement", "its route, area, position, archetype, scope and entity type")
    Do $$$AssertEquals(tDeclaration.id.%ToJSON(), "{""kind"":""composite"",""parts"":[""Server"",""ProcessID"",""StatementHash""]}", "its id is the vendor's IdKey")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "its pairs are the port's")
    Do $$$AssertEquals(..Spelled($ClassMethod(..#DESCRIPTOR, "PrivilegePairs")), $Parameter(..#PORT, "PAIRS"), "and equal the port's PAIRS, in order, so the side bar refuses whom the port refuses")
    Do $$$AssertEquals($Select($IsObject(tDeclaration.%Get("ownPrivileges")): tDeclaration.ownPrivileges.%Size(), 1: 0), 0, "and none is its own")
    Do $$$AssertEquals(tDeclaration.refreshes _ "|" _ tDeclaration.refreshRates.%ToJSON() _ "|" _ tDeclaration.%Get("refreshDefault"), "1|[5,10,30,60]|", "it refreshes at 5, 10, 30 or 60 seconds, off by default")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RefreshProblem(tDeclaration.refreshes, $ListBuild(5, 10, 30, 60), ""), "", "a refresh the registry admits")
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size(), "|0", "no action")
    Do $$$AssertEquals(tDeclaration.rowTarget.%ToJSON(), "{""route"":""os-management/processes/details"",""field"":""ProcessID"",""unless"":""Remote""}", "its Process ID cell opens Process details unless the row is remote")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""sqlactivity"",""endpoint"":""CurrentStatements"",""type"":""LIST""}", "its read names the sqlactivity port")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Server"",""ProcessID"",""UserName"",""Namespace"",""RunType"",""Elapsed"",""Started"",""StatementId"",""StatementHash"",""Statement"",""Routine"",""CachedQuery"",""Workers"",""TransactionLevel"",""Remote""]", "and the row's fields")
    Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), "every read field is a context field")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "and none is secret")
    Do $$$AssertEquals(tDeclaration.read.sort.default _ "|" _ tDeclaration.read.sort.direction _ "|" _ tDeclaration.read.note.key, "Elapsed|desc|sqlActivityNote", "slowest first, with its note")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size() _ "|" _ tDeclaration.suggestedPrompts.%Get(0).groupKey _ "|" _ tDeclaration.suggestedPrompts.%Get(2).groupKey, "3|promptGroupTroubleshooting|promptGroupTroubleshooting", "three prompts in the Troubleshooting group")
    Do $$$AssertEquals(tDeclaration.commandAliases.%ToJSON(), "[""sql activity"",""running queries"",""current statements""]", "its aliases")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier, "%CSP.UI.Portal.SQL.CurrentStatements|osmgmt.sqlactivity", "its classic page and tool identifier")
    Do $$$AssertEquals(tDeclaration.emptyStateKey _ "|" _ tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey _ "|" _ tDeclaration.table.columns.%Get(5).field _ "|" _ tDeclaration.table.columns.%Get(5).emptyKey, "sqlActivityEmpty|tableReadOnlyEmptyNext||Statement|sqlActivityTextWithheld", "its own read-only empty state, and a withheld text reads its own word")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("sql-statement"), "its entity type is in the vocabulary")
}

/// <p><var>pPairs</var>, a pair list as the gate evaluates it, spelled
/// <code>resource:permission</code> and comma-separated, as a port's <code>PAIRS</code> is.</p>
ClassMethod Spelled(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tText = tText _ $Select(tI > 1: ",", 1: "") _ $ListToString($List(pPairs, tI), ":")
    }
    Quit tText
}

/// <p>The port carries no write, so it has no script form (AD-59).</p>
Method TestTheScriptForms()
{
    Set tPort = ..#PORT
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "CurrentStatements", "LIST"), "", "no script form")
    Kill tQuery
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "CurrentStatements", "LIST", .tQuery).%ToJSON(), "[]", "and no script steps")
}

}
