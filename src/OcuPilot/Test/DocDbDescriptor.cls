/// <p>Pins Story 19.17's declarations with no instance write (AD-5, AD-13, AD-29, AD-36, AD-59): the
/// <code>docdb</code> source kind's refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off
/// this class's <code>Cases</code> block as well; the Document databases descriptor and its three tools;
/// <method>OcuPilot.Port.DocDbPort.ClassNameOf</method> and <method>OcuPilot.Port.DocDbPort.NameProblem</method>
/// over the name matrix; and the port's script forms.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries and a <code>USER</code>
/// namespace whose databases' resources it reads. Live-safe: it writes nothing.</p>
Class OcuPilot.Test.DocDbDescriptor Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerDocDbList";

Parameter CREATE = "OcuPilot.Screen.Tool.ExplorerDocDbCreate";

Parameter DELETE = "OcuPilot.Screen.Tool.ExplorerDocDbDelete";

Parameter PORT = "OcuPilot.Port.DocDbPort";

/// <p>The corpus both engines run: each case replaces the declaration's <code>read.source</code>, sets
/// <code>read.criteria</code> when it carries one, and names the sentence the registry's
/// <code>check</code> (<code>read</code> or <code>criteria</code>) answers, or <code>null</code>.</p>
XData Cases
{
{
  "declaration": {
    "route": "system-explorer/docdb-corpus", "area": "system-explorer", "labelKey": "explorerDocDbListLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Development", "permission": "USE"}, {"resource": "%DocDB_Admin", "permission": "USE"}, {"resource": "%Service_DocDB", "permission": "USE"}],
    "entityType": "docdb-database", "secondaryEntityTypes": [],
    "scope": "namespace", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "Class", "DocumentType", "Resource"], "secretFields": []},
    "emptyStateKey": "explorerDocDbListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST"},
      "fields": ["Name", "Class", "DocumentType", "Resource"],
      "filter": ["Name", "Class", "DocumentType", "Resource"],
      "sort": {"fields": ["Name", "Class", "DocumentType", "Resource"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.docdbcorpus"
  },
  "cases": [
    {"name": "a docdb LIST of Databases is sound", "check": "read", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST"}, "expected": null},
    {"name": "and declares no criteria", "check": "criteria", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST"}, "expected": null},
    {"name": "another endpoint", "check": "read", "source": {"port": "docdb", "endpoint": "Documents", "type": "LIST"}, "expected": "read.source.endpoint 'Documents' is not the docdb port's endpoint ('Databases') (AD-29)"},
    {"name": "a single-object type", "check": "read", "source": {"port": "docdb", "endpoint": "Databases", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a docdb source, which lists the namespace's document databases (AD-36)"},
    {"name": "a per-row detail call", "check": "read", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["Class"], "derived": []}}, "expected": "read.source.rowGet is declared on a docdb source, which answers the document databases whole (AD-36)"},
    {"name": "a parent list", "check": "read", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST", "forEach": {"endpoint": "Databases", "key": "Name", "param": "name", "fields": []}}, "expected": "read.source.forEach is declared on a docdb source, which answers the document databases whole (AD-36)"},
    {"name": "a fixed query", "check": "read", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST", "query": {"system": "no"}}, "expected": "read.source.query is declared on a docdb source, which answers the document databases whole (AD-36)"},
    {"name": "parts", "check": "read", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a docdb source, which answers the document databases whole (AD-36)"},
    {"name": "a list over one member", "check": "read", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST", "rows": "rows"}, "expected": "read.source.rows is declared on a 'docdb' source, and a list over one member reads an admin endpoint's one-object answer (AD-36)"},
    {"name": "server criteria", "check": "criteria", "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST"}, "criteria": {"fields": [{"param": "pattern", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on a 'docdb' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)"},
    {"name": "an unknown port", "check": "read", "source": {"port": "docdbx", "endpoint": "Databases", "type": "LIST"}, "expected": "read.source.port 'docdbx' is not one of 'admin', 'state', 'mgmnt', 'logsource', 'path', 'timeline', 'background', 'atelier', 'encryption', 'docdb', 'sqlactivity' or 'interop', the twelve sources a declared read names (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry,
/// and the corpus refuses at least one shape.</p>
/// <p>Mutation (Rule 19): drop the docdb arm from <method>OcuPilot.Screen.Registry.ReadProblem</method>
/// -- the endpoint, type and key cases go red.</p>
Method TestTheDocDbSourceRefusals()
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

/// <p>The descriptor declares the screen the spec names: System Explorer's twelfth side-bar entry, a
/// namespace-scoped list of <code>docdb-database</code> rows read through the docdb port, gated on
/// <code>%Development:USE</code> with the DocDB pairs as its own, one Create and one Delete, three
/// prompts in the Code group, and no classic page.</p>
Method TestTheDescriptorShape()
{
    Set tSC = $ClassMethod(..#DESCRIPTOR, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.entityType, "system-explorer/docdb|system-explorer|12|list|namespace|docdb-database", "its route, area, position, archetype, scope and entity type")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Development"",""permission"":""USE""},{""resource"":""%DocDB_Admin"",""permission"":""USE""},{""resource"":""%Service_DocDB"",""permission"":""USE""}]", "its pairs")
    Do $$$AssertEquals(tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%DocDB_Admin"",""permission"":""USE""},{""resource"":""%Service_DocDB"",""permission"":""USE""}]", "the DocDB pairs are its own")
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%ToJSON(), "create|[{""id"":""delete"",""selfProtection"":""""}]", "one Create and one Delete")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""docdb"",""endpoint"":""Databases"",""type"":""LIST""}", "its read names the docdb port")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Name"",""Class"",""DocumentType"",""Resource""]", "and its four fields")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size() _ "|" _ tDeclaration.suggestedPrompts.%Get(0).groupKey, "3|webAppPromptGroupCode", "three prompts in the Code group")
    Do $$$AssertEquals(tDeclaration.commandAliases.%ToJSON(), "[""document databases"",""docdb"",""create document database""]", "its aliases")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier, "|explorer.docdb", "no classic page, and its tool identifier")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
}

/// <p>The two write tools declare the Boundaries' parameters: the create's absence read, its port, its
/// read-back field and its name argument; the drop's destructive action-style write, its fingerprint
/// subject and its screen action. Both are advertised and resolve to the port.</p>
Method TestTheToolShapes()
{
    Set tCreate = ..#CREATE
    Do $$$AssertEquals($Parameter(tCreate, "TOOLNAME") _ "|" _ $ClassMethod(tCreate, "Creates") _ "|" _ $ClassMethod(tCreate, "ChangeAction") _ "|" _ $ClassMethod(tCreate, "ReadType") _ "|" _ $ClassMethod(tCreate, "WriteType") _ "|" _ $ClassMethod(tCreate, "PortClass"), "explorer.docdb.create|1|created|DATABASE|CREATE|" _ ..#PORT, "the create is an AD-54 create through the port")
    Do $$$AssertEquals($ListToString($ClassMethod(tCreate, "ReadBackFields")) _ "|" _ $ListToString($ClassMethod(tCreate, "SettableFields")) _ "|" _ $ClassMethod(tCreate, "IdArgument") _ "|" _ $ClassMethod(tCreate, "IdParam") _ "|" _ $ClassMethod(tCreate, "Destructive"), "Name|Name|Name|name|0", "it reads back and sets the name alone")
    Set tDelete = ..#DELETE
    Do $$$AssertEquals($Parameter(tDelete, "TOOLNAME") _ "|" _ $ClassMethod(tDelete, "Destructive") _ "|" _ $ClassMethod(tDelete, "SendsBody") _ "|" _ $ClassMethod(tDelete, "ChangeAction") _ "|" _ $ClassMethod(tDelete, "ReadType") _ "|" _ $ClassMethod(tDelete, "WriteType"), "explorer.docdb.delete|1|0|deleted|DATABASE|DROP", "the drop is a destructive action-style write")
    Do $$$AssertEquals($ListToString($ClassMethod(tDelete, "FingerprintSubject")) _ "|" _ $ListToString($ClassMethod(tDelete, "ScreenActionIds")) _ "|" _ $ClassMethod(tDelete, "SettableFields"), "Name,Class,Namespace|delete|", "its subject, its screen action and no settable field")
    For tTool = tCreate, tDelete {
        Do $$$AssertTrue($Parameter(tTool, "ADVERTISED") '= 0, $Parameter(tTool, "TOOLNAME") _ " is advertised")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tTool), "", $Parameter(tTool, "TOOLNAME") _ " passes the subject's adequacy rule")
        Set tSchema = $ClassMethod(tTool, "InputSchema")
        Do $$$AssertEquals(tSchema.required.%ToJSON(), "[""Name""]", $Parameter(tTool, "TOOLNAME") _ " requires the name alone")
        Do $$$AssertTrue((tSchema.properties.Name.description [ "letters and digits in parts separated by dots") && (tSchema.properties.Name.description [ "ISC.DM.<name>"), $Parameter(tTool, "TOOLNAME") _ " describes the name's rules and the ISC.DM class an unqualified name makes")
    }
}

/// <p>Each tool's pairs are the screen's three plus WRITE on the request namespace's routines and
/// globals databases, each pair once: in <code>USER</code>, whose two are one database,
/// <code>%DB_USER:WRITE</code> alone.</p>
Method TestTheToolPairsAddTheNamespacesWrite()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources("USER", .tRoutine, .tGlobal, .tMapped, .tResolved)
    For tTool = ..#CREATE, ..#DELETE {
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tToolResolved)
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
        }
        Do $$$AssertEquals(tToolResolved _ "|" _ tText, "1|%Development:USE,%DocDB_Admin:USE,%Service_DocDB:USE," _ tRoutine _ ":WRITE" _ $Select(tGlobal '= tRoutine: "," _ tGlobal _ ":WRITE", 1: ""), $Parameter(tTool, "TOOLNAME") _ "'s pairs")
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>An unqualified name's class is <code>ISC.DM.&lt;name&gt;</code> and a qualified name is its own
/// class (measured).</p>
Method TestClassNameOf()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.DocDbPort).ClassNameOf("OcuProbe1917A"), "ISC.DM.OcuProbe1917A", "an unqualified name")
    Do $$$AssertEquals(##class(OcuPilot.Port.DocDbPort).ClassNameOf("OcuProbe1917.Q"), "OcuProbe1917.Q", "a qualified name")
}

/// <p>The name matrix: a class name, each part starting with a letter, whose class is at most 220
/// characters, passes, and every shape the vendor refuses (#25053, measured) is refused with the
/// published sentence before any vendor call.</p>
/// <p>Mutation (Rule 19): drop the length clause from
/// <method>OcuPilot.Port.DocDbPort.NameProblem</method> -- the 214-character leg goes red.</p>
Method TestTheNameMatrix()
{
    Set tLong213 = "A" _ $Translate($Justify("", 212), " ", "b")
    Set tLong214 = tLong213 _ "c"
    For tName = "OcuProbe1917A", "a1.b2", "OcuProbe1917.Q", "X", tLong213 {
        Do $$$AssertEquals(##class(OcuPilot.Port.DocDbPort).NameProblem(tName), "", "'" _ $Extract(tName, 1, 40) _ "' (" _ $Length(tName) _ ") passes")
    }
    For tName = "a_b", "1x", "x.", ".x", "a..b", "%X", "a b", "a-b", "", tLong214 {
        Do $$$AssertEquals(##class(OcuPilot.Port.DocDbPort).NameProblem(tName), ##class(OcuPilot.Api.DocDbError).#REASONNAMEINVALID, "'" _ $Extract(tName, 1, 40) _ "' (" _ $Length(tName) _ ") is refused")
    }
    Do $$$AssertEquals(##class(OcuPilot.Port.DocDbPort).NameProblem("A." _ $Translate($Justify("", 219), " ", "b")), ##class(OcuPilot.Api.DocDbError).#REASONNAMEINVALID, "a qualified name of 221 characters is refused")
}

/// <p>Each <code>DOCDB.*</code> code carries its published sentence to a refused tool call through
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method>, so a tool result says what the screen
/// says.</p>
/// <p>Mutation (Rule 19): drop the <code>DOCDB.</code> line from
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> -- each code reads the generic reason and this
/// goes red.</p>
Method TestEachCodeReachesAToolResultWithItsSentence()
{
    Set tError = "OcuPilot.Api.DocDbError"
    For tParameter = "SERVICEDISABLED", "NAMEINVALID", "NAMEMAPPED", "NAMETAKEN", "CLASSTAKEN" {
        Set tCode = $Parameter(tError, tParameter)
        Set tReason = $Parameter(tError, "REASON" _ tParameter)
        Do $$$AssertTrue((tReason '= "") && (##class(OcuPilot.Api.DocDbError).ReasonFor(tCode) = tReason), tCode _ ": its sentence is declared")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": and a refused tool call carries it")
    }
}

/// <p>The port's script forms (AD-59): <code>objectscript</code> for the create and the drop,
/// none for the list and the database read, and each script switches to the namespace and calls
/// <code>%SYSTEM.DocDB</code> with the name as a string literal.</p>
Method TestTheScriptForms()
{
    Set tPort = ..#PORT
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Databases", "CREATE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Databases", "DROP") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Databases", "LIST") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Databases", "DATABASE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Other", "CREATE"), "objectscript|objectscript|||", "the writes have a script form and nothing else does")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("name") = "OcuProbe1917A"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Databases", "CREATE", .tQuery)
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ tSteps.%Get(0).kind, "1|objectscript", "the create renders one step")
    Do $$$AssertEquals(tSteps.%Get(0).text, " Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tDatabase = ##class(%SYSTEM.DocDB).CreateDatabase(""OcuProbe1917A"")", "creating the one name in the namespace")
    Set tSteps = $ClassMethod(tPort, "Snippet", "Databases", "DROP", .tQuery)
    Do $$$AssertEquals(tSteps.%Get(0).text, " Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tDropped = ##class(%SYSTEM.DocDB).DropDatabase(""OcuProbe1917A"")", "the drop drops it")
    Set tQuery("name") = "x"",!,""y"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Databases", "DROP", .tQuery)
    Do $$$AssertTrue(tSteps.%Get(0).text [ "DropDatabase(""x"""",!,""""y"")", "a quote in the name stays inside the literal")
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Databases", "LIST", .tQuery).%Size(), 0, "a read renders nothing")
}

}
