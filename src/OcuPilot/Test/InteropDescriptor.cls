/// <p>Pins Story 20.2's declarations with no production started (AD-5, AD-8, AD-29, AD-36, AD-44, AD-51,
/// AD-59, AD-62): the <code>interop</code> source kind's refusals, which
/// <file>ui/tools/screen-mirror.test.mjs</file> runs off this class's <code>Cases</code> block as well;
/// the four Interoperability descriptors and the five production tools; <method>OcuPilot.Port.InteropPort.Refusal</method>
/// over the state matrix; the four lists read through the port; the refusal of a namespace that runs no
/// productions; and every <class>OcuPilot.Api.InteropError</class> code resolving to its sentence.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries, the <code>HSCUSTOM</code>
/// namespace, whose Interoperability classes the code lists read, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the Rules leg compiles the probe classes of
/// <class>OcuPilot.Test.ProductionProbe</class> in <code>USER</code>. It starts no production.</p>
Class OcuPilot.Test.InteropDescriptor Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropDescriptor compiles the probe classes in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe classes.</p>
Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "Remove")
}

/// <p>The four screens, <code>&lt;descriptor&gt;|&lt;route&gt;|&lt;position&gt;|&lt;classic page&gt;|&lt;endpoint&gt;|&lt;own pair&gt;|&lt;tool identifier&gt;</code>.</p>
Parameter SCREENS = "InteropProductionList|interoperability/productions|1|EnsPortal.Productions|Productions|%Ens_ProductionConfig:READ|interop.productions;InteropProcessList|interoperability/processes|2|EnsPortal.BusinessProcesses|Processes|%Ens_Code:READ|interop.processes;InteropTransformList|interoperability/transforms|3|EnsPortal.DataTransformations|Transforms|%Ens_Code:READ|interop.transforms;InteropRuleList|interoperability/rules|4|EnsPortal.Rules|Rules|%Ens_Code:READ|interop.rules";

/// <p>The five tools, <code>&lt;class&gt;|&lt;tool&gt;|&lt;write type&gt;|&lt;action&gt;|&lt;subject&gt;|&lt;consequence&gt;</code>.</p>
Parameter TOOLS = "InteropProductionStart|interop.productions.start|START|start|State,Current,Namespace|;InteropProductionStop|interop.productions.stop|STOP|stop|State,Namespace|INTEROP.STOP;InteropProductionRestart|interop.productions.restart|RESTART|restart|State,Namespace|INTEROP.RESTART;InteropProductionUpdate|interop.productions.update|UPDATE|update|State,NeedsUpdate,Namespace|INTEROP.UPDATE;InteropProductionRecover|interop.productions.recover|RECOVER|recover|State,Namespace|INTEROP.RECOVER";

/// <p>The corpus both engines run: each case replaces the declaration's <code>read.source</code>, sets
/// <code>read.criteria</code> when it carries one, and names the sentence the registry's
/// <code>check</code> (<code>read</code> or <code>criteria</code>) answers, or <code>null</code>.</p>
XData Cases
{
{
  "declaration": {
    "route": "interoperability/corpus", "area": "interoperability", "labelKey": "interopProductionsLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
    "entityType": "production", "secondaryEntityTypes": [],
    "scope": "namespace", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "Status"], "secretFields": []},
    "emptyStateKey": "interopProductionsEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "interop", "endpoint": "Productions", "type": "LIST"},
      "fields": ["Name", "Status"],
      "filter": ["Name", "Status"],
      "sort": {"fields": ["Name", "Status"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "interop.corpus"
  },
  "cases": [
    {"name": "an interop LIST of Productions is sound", "check": "read", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST"}, "expected": null},
    {"name": "so is each code list", "check": "read", "source": {"port": "interop", "endpoint": "Rules", "type": "LIST"}, "expected": null},
    {"name": "and declares no criteria", "check": "criteria", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST"}, "expected": null},
    {"name": "an endpoint the port does not serve", "check": "read", "source": {"port": "interop", "endpoint": "Items", "type": "LIST"}, "expected": "read.source.endpoint 'Items' is not one of the interop port's endpoints ('Productions', 'Processes', 'Transforms', 'Rules') (AD-62)"},
    {"name": "a type other than LIST", "check": "read", "source": {"port": "interop", "endpoint": "Productions", "type": "GET"}, "expected": "read.source.type 'GET' is declared on an interop source, which lists the namespace's productions and classes (AD-36)"},
    {"name": "rowGet", "check": "read", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["Status"], "derived": []}}, "expected": "read.source.rowGet is declared on an interop source, which answers its list whole (AD-36)"},
    {"name": "forEach", "check": "read", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST", "forEach": ["Rules"]}, "expected": "read.source.forEach is declared on an interop source, which answers its list whole (AD-36)"},
    {"name": "query", "check": "read", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST", "query": {"a": "b"}}, "expected": "read.source.query is declared on an interop source, which answers its list whole (AD-36)"},
    {"name": "parts", "check": "read", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on an interop source, which answers its list whole (AD-36)"},
    {"name": "a list over one member", "check": "read", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST", "rows": "rows"}, "expected": "read.source.rows is declared on a 'interop' source, and a list over one member reads an admin endpoint's one-object answer (AD-36)"},
    {"name": "server criteria", "check": "criteria", "source": {"port": "interop", "endpoint": "Productions", "type": "LIST"}, "criteria": {"fields": [{"param": "pattern", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on a 'interop' source, and server criteria travel on the admin, mgmnt, atelier, timeline and encryption ports alone (AD-21)"},
    {"name": "an unknown port", "check": "read", "source": {"port": "interopx", "endpoint": "Productions", "type": "LIST"}, "expected": "read.source.port 'interopx' is not one of 'admin', 'state', 'mgmnt', 'logsource', 'path', 'timeline', 'background', 'atelier', 'encryption', 'docdb', 'sqlactivity', 'interop' or 'access', the thirteen sources a declared read names (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry,
/// and the corpus refuses at least one shape.</p>
/// <p>Mutation (Rule 19): drop the interop arm from <method>OcuPilot.Screen.Registry.ReadProblem</method>
/// -- the endpoint, type and key cases go red.</p>
Method TestTheInteropSourceRefusals()
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

/// <p>The four descriptors declare what the spec names: the interoperability area, their route,
/// side-bar position, classic page, pairs (the menu's and the page's own), entity type, scope, three
/// prompts, the interop source on the right endpoint, and no action but the Productions' five.</p>
/// <p>Mutation (Rule 19): drop <code>Status</code> from <code>InteropProductionList</code>'s read fields
/// -- the Productions leg goes red.</p>
Method TestTheFourDeclarationsRegister()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tRow, "|", 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration reads")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope, $Piece(tRow, "|", 2) _ "|interoperability|" _ $Piece(tRow, "|", 3) _ "|list|namespace", tClass _ ": route, area, position, archetype and scope")
        Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier, $Piece(tRow, "|", 4) _ "|" _ $Piece(tRow, "|", 7), tClass _ ": its own classic page and tool identifier")
        Set tOwn = $Piece(tRow, "|", 6)
        Do $$$AssertEquals(tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""" _ $Piece(tOwn, ":", 1) _ """,""permission"":""" _ $Piece(tOwn, ":", 2) _ """}]", tClass _ ": its own pair is the classic page's resource")
        Do $$$AssertEquals(tDeclaration.privileges.%Get(0).resource _ ":" _ tDeclaration.privileges.%Get(0).permission _ "|" _ tDeclaration.privileges.%Size(), "%Ens_Portal:USE|2", tClass _ ": the Interoperability menu's pair, then its own")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "interop|" _ $Piece(tRow, "|", 5) _ "|LIST", tClass _ ": read through the interop port")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tClass _ ": three suggested prompts")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read passes the registry")
        Set tActions = ""
        Set tIterator = tDeclaration.rowActions.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tAction) {
            Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
        }
        If $Piece(tRow, "|", 1) = "InteropProductionList" {
            Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tActions _ "|" _ tDeclaration.read.fields.%ToJSON(), "production|start,stop,restart,update,recover|[""Name"",""Status"",""LastStartTime"",""LastStopTime""]", "Productions: the production entity, its five row actions and its four fields")
            Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Get(0).groupKey, "promptGroupTroubleshooting", "Productions: prompts in the Troubleshooting group")
        } Else {
            Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tActions _ "|" _ tDeclaration.table.emptyNextKey, "class||tableReadOnlyEmptyNext", tClass _ ": class rows, no action and the read-only empty state")
            Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Get(0).groupKey, "promptGroupGettingStarted", tClass _ ": prompts in the Getting started group")
        }
    }
    Set tArea = ##class(OcuPilot.Screen.Area).Find("interoperability")
    Do $$$AssertEquals($Select($IsObject(tArea): tArea.appliesWhen, 1: ""), "interoperability", "the area the four screens inherit declares its applicability")
}

/// <p>Each tool declares the Boundaries' parameters: the action-style write over the port's
/// <code>STATE</code> read, its own write type and screen action, its fingerprint subject carrying the
/// namespace and the precondition field, no body, no destructive flag, and its consequence code; each is
/// advertised and passes the subject's adequacy rule.</p>
Method TestTheToolShapes()
{
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), $Piece(tRow, "|", 2) _ "|" _ $Piece(tRow, "|", 3) _ "|STATE|OcuPilot.Port.InteropPort|Productions", tTool _ ": name, request types and port")
        Do $$$AssertEquals($ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "ChangeAction") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "SettableFields") _ "|" _ $ClassMethod(tTool, "IdArgument") _ "|" _ $ClassMethod(tTool, "IdParam"), "0|0|updated|" _ $Piece(tRow, "|", 4) _ "||Name|id", tTool _ ": no body, not destructive, one screen action and no settable field")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")) _ "|" _ $ClassMethod(tTool, "PreconditionField"), $Piece(tRow, "|", 5) _ "|State", tTool _ ": its subject")
        Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}, 0, ""), $Piece(tRow, "|", 6), tTool _ ": its consequence code")
        Do $$$AssertTrue($ListFind($ClassMethod(tTool, "PreconditionCodes"), ##class(OcuPilot.Api.InteropError).#NAMESPACE) && $ListFind($ClassMethod(tTool, "PreconditionCodes"), ##class(OcuPilot.Api.InteropError).#NOTRUNNING), tTool _ ": its precondition codes name the namespace and state refusals")
        Do $$$AssertTrue($Parameter(tTool, "ADVERTISED") = 1, tTool _ " is advertised")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tTool), "", tTool _ " passes the subject's adequacy rule")
        Kill tQuery
        Do $ClassMethod(tTool, "PortQuery", {"Name": "P"}, .tQuery)
        Do $$$AssertEquals($Get(tQuery("action")) _ "|" _ $Get(tQuery("namespace")), $Piece(tRow, "|", 3) _ "|", tTool _ ": the read made from the call's arguments is composed for its action")
        Kill tQuery
        Do $ClassMethod(tTool, "PortQuery", {"State": "Running", "Namespace": "USER"}, .tQuery)
        Do $$$AssertEquals($Get(tQuery("action")) _ "|" _ $Get(tQuery("namespace")), "|USER", tTool _ ": the read made from the stored payload names the payload's namespace and no action")
        Kill tQuery
        Set tSchema = $ClassMethod(tTool, "InputSchema")
        Do $$$AssertEquals(tSchema.required.%ToJSON(), "[""Name""]", tTool _ " requires the production's name alone")
        Do $$$AssertTrue(##class(OcuPilot.Kernel.Governance.Baseline).Seed($Piece(tRow, "|", 2), .tListed) && tListed, tTool _ " is listed in the governance baseline, enabled")
    }
}

/// <p>Each tool's pairs are the screen's two, then <code>%Ens_ProductionRun:USE</code>, then WRITE on
/// the request namespace's globals database, then the custom resource of each classic page the tool
/// declares, each pair once; in <code>USER</code>, <code>%DB_USER:WRITE</code>.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionRun:USE</code> from
/// <method>OcuPilot.Screen.Tool.InteropProductionAction.PrivilegePairs</method> -- this goes red.</p>
Method TestTheToolPairsAddTheRunResourceAndTheDatabaseWrite()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase("USER", .tResource, .tReadOnly)
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece($Piece(..#TOOLS, ";", tI), "|", 1)
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Set tText = ""
        For tJ = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tJ), ":")
        }
        Do $$$AssertEquals(tResolved _ "|" _ tText, "1|%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_ProductionRun:USE," _ tResource _ ":WRITE", $Parameter(tTool, "TOOLNAME") _ "'s pairs")
        Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), "EnsPortal.ProductionConfig,EnsPortal.Dialog.UpdateProduction,EnsPortal.StartStopFrame", $Parameter(tTool, "TOOLNAME") _ " declares the classic pages it performs")
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p><method>OcuPilot.Port.InteropPort.Refusal</method> over the state matrix: the vendor answers a
/// no-op as success in each state refused here, and the port names it by its own code before any vendor
/// call (AD-62). A state outside Running, Stopped, Suspended and Troubled refuses every action.</p>
/// <p>Mutation (Rule 19): remove the <code>NOTRUNNING</code> refusal from stop in
/// <method>OcuPilot.Port.InteropPort.Refusal</method> -- the stop rows go red.</p>
Method TestTheRefusalMatrix()
{
    Set tE = ..#ERROR
    ; type, word, current, id, needs update, expected
    For tCase = $ListBuild("START", "Stopped", "", "P", 0, ""), $ListBuild("START", "Suspended", "P", "P", 0, ""), $ListBuild("START", "Stopped", "Q", "P", 0, $Parameter(tE, "OTHER")), $ListBuild("START", "Running", "P", "P", 0, $Parameter(tE, "RUNNING")), $ListBuild("START", "Troubled", "P", "P", 0, $Parameter(tE, "TROUBLED")), $ListBuild("START", "Unknown", "P", "P", 0, $Parameter(tE, "STATE")), $ListBuild("START", "NetworkStopped", "P", "P", 0, $Parameter(tE, "STATE")),
        $ListBuild("STOP", "Running", "P", "P", 0, ""), $ListBuild("STOP", "Stopped", "", "P", 0, $Parameter(tE, "NOTRUNNING")), $ListBuild("STOP", "Suspended", "P", "P", 0, $Parameter(tE, "NOTRUNNING")), $ListBuild("STOP", "Troubled", "P", "P", 0, $Parameter(tE, "NOTRUNNING")), $ListBuild("STOP", "ShardWorkerProhibited", "P", "P", 0, $Parameter(tE, "STATE")),
        $ListBuild("RESTART", "Running", "P", "P", 0, ""), $ListBuild("RESTART", "Stopped", "", "P", 0, $Parameter(tE, "NOTRUNNING")), $ListBuild("RESTART", "Troubled", "P", "P", 0, $Parameter(tE, "NOTRUNNING")),
        $ListBuild("UPDATE", "Running", "P", "P", 1, ""), $ListBuild("UPDATE", "Running", "P", "P", 0, $Parameter(tE, "UPTODATE")), $ListBuild("UPDATE", "Stopped", "", "P", 0, $Parameter(tE, "NOTRUNNING")), $ListBuild("UPDATE", "Suspended", "P", "P", 1, $Parameter(tE, "NOTRUNNING")),
        $ListBuild("RECOVER", "Troubled", "P", "P", 0, ""), $ListBuild("RECOVER", "Running", "P", "P", 0, $Parameter(tE, "NOTTROUBLED")), $ListBuild("RECOVER", "Stopped", "", "P", 0, $Parameter(tE, "NOTTROUBLED")), $ListBuild("RECOVER", "Suspended", "P", "P", 0, $Parameter(tE, "NOTTROUBLED")), $ListBuild("RECOVER", "Unknown", "P", "P", 0, $Parameter(tE, "STATE")) {
        Set tCode = $ClassMethod(..#PORT, "Refusal", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), $List(tCase, 5))
        Do $$$AssertEquals(tCode, $List(tCase, 6), $List(tCase, 1) _ " of a " _ $List(tCase, 2) _ " production (current '" _ $List(tCase, 3) _ "', update pending " _ $List(tCase, 5) _ ")")
    }
}

/// <p>The four lists read through the port in <code>HSCUSTOM</code>: Productions answers its rows'
/// four fields, and the code lists answer at least one row each for processes and transformations, with
/// every <code>Name</code> a document name ending <code>.cls</code>, the vendor's base classes absent,
/// and the cap reported by the row count. Business rules may be empty.</p>
/// <p>Mutation (Rule 19): make <code>ListClasses</code> read <code>Ens.Rule.Definition</code> for every
/// endpoint -- the process and transformation legs go red.</p>
Method TestTheCodeListsReadThroughThePort()
{
    Kill tQuery
    Set tQuery("namespace") = "HSCUSTOM"
    Set tQuery("maxRows") = 2000
    For tEndpoint = "Processes", "Transforms", "Rules" {
        Kill tResult
        Set tSC = $ClassMethod(..#PORT, "Invoke", tEndpoint, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ " reads: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        Do $$$AssertEquals(+$Get(tHttp), 200, tEndpoint _ " answers 200")
        If '$IsObject($Get(tResult)) Continue
        Set tCount = tResult.%Size()
        Do $$$AssertTrue((tEndpoint = "Rules") || (tCount >= 1), tEndpoint _ " lists at least one class in HSCUSTOM: " _ tCount)
        Set tBad = 0
        Set tBase = 0
        Set tIterator = tResult.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $Extract(tRow.Name, *-3, *) '= ".cls" Set tBad = tBad + 1
            If (tRow.Name = "Ens.BusinessProcessBPL.cls") || (tRow.Name = "Ens.DataTransformDTL.cls") Set tBase = tBase + 1
        }
        Do $$$AssertEquals(tBad _ "|" _ tBase, "0|0", tEndpoint _ ": every name is a document name and the base classes are absent")
    }
    Set tQuery("maxRows") = 1
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Transforms", "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ "|" _ $Select($IsObject($Get(tResult)): tResult.%Size(), 1: -1), "200|1", "a cap of one answers one row")
    Set tQuery("namespace") = "USER"
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "Productions lists in USER")
    If $IsObject($Get(tResult)) && (tResult.%Size() > 0) {
        Set tRow = tResult.%Get(0)
        Do $$$AssertEquals(tRow.%GetTypeOf("Name") _ "|" _ tRow.%GetTypeOf("Status") _ "|" _ tRow.%GetTypeOf("LastStartTime") _ "|" _ tRow.%GetTypeOf("LastStopTime"), "string|string|string|string", "a production row carries its four fields")
    }
}

/// <p>AC1: the Rules list names a business rule class by its document name and the Processes list does not,
/// in <code>USER</code>, where <parameter>PROBE</parameter> compiled a bare <code>Ens.Rule.Definition</code>
/// subclass.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListClasses</method> read the Processes
/// family for the Rules endpoint -- the Rules leg goes red.</p>
Method TestTheRulesListNamesTheProbeRuleAndProcessesDoesNot()
{
    Set tDocument = $ClassMethod(..#PROBE, "RuleDocument")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("maxRows") = 2000
    For tCase = $ListBuild("Rules", 1), $ListBuild("Processes", 0) {
        Kill tResult
        Set tSC = $ClassMethod(..#PORT, "Invoke", $List(tCase, 1), "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp), 200, $List(tCase, 1) _ " answers 200 in USER")
        Set tSeen = 0
        If $IsObject($Get(tResult)) {
            Set tIterator = tResult.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If tRow.Name = tDocument Set tSeen = 1
            }
        }
        Do $$$AssertEquals(tSeen, $List(tCase, 2), $List(tCase, 1) _ $Select($List(tCase, 2): " lists ", 1: " does not list ") _ tDocument)
    }
}

/// <p>AC1, AD-36: each screen's declared read, issued as <class>OcuPilot.Screen.Read</class> issues it, and
/// its read tool answer the same rows, which are the rows the port answers for the screen's endpoint in
/// the route's namespace, and none is empty: processes and transformations in <code>HSCUSTOM</code>, and
/// Productions and Business rules in <code>USER</code>, where <parameter>PROBE</parameter> compiled its
/// productions and its rule. A cap of two answers at most two rows and reports the cut when the list is
/// longer.</p>
/// <p>Mutation (Rule 19): make the <code>interop</code> branch of <method>OcuPilot.Screen.Read.Execute</method>
/// ask the port for <code>Productions</code> whatever the source names -- the code list legs go red.</p>
Method TestEachScreenAndItsReadToolReadTheSameRows()
{
    For tCase = $ListBuild("InteropProductionList", "Productions", "USER", "interop.productions.read"), $ListBuild("InteropProcessList", "Processes", "HSCUSTOM", "interop.processes.read"), $ListBuild("InteropTransformList", "Transforms", "HSCUSTOM", "interop.transforms.read"), $ListBuild("InteropRuleList", "Rules", "USER", "interop.rules.read") {
        Set tDescriptor = "OcuPilot.Screen.Descriptor." _ $List(tCase, 1)
        Set tNamespace = $List(tCase, 3)
        Do ##class(OcuPilot.Kernel.Scope).Set(tNamespace)
        Kill tQuery, tPortRows
        Set tQuery("namespace") = tNamespace
        Set tQuery("maxRows") = 1000
        Set tSC = $ClassMethod(..#PORT, "Invoke", $List(tCase, 2), "LIST", .tQuery, "", .tPortRows, .tPortHttp, .tPortFault)
        Do $$$AssertEquals(+$Get(tPortHttp), 200, $List(tCase, 1) _ ": the port answers its endpoint in " _ tNamespace)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(tDescriptor, 1000, .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp), 200, $List(tCase, 1) _ ": the screen's read answers")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($List(tCase, 4), .tTool, 1)
        Do $$$AssertStatusOK(tSC, $List(tCase, 4) _ " resolves")
        Kill tResult
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 1000}, 1000, .tResult, .tToolHttp, .tToolFault)
        Do $$$AssertEquals(+$Get(tToolHttp), 200, $List(tCase, 4) _ " answers")
        If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) || '$IsObject($Get(tPortRows)) Continue
        Do $$$AssertEquals(tAnswer.rows.%Size() _ "|" _ tResult.rows.%Size(), tPortRows.%Size() _ "|" _ tPortRows.%Size(), $List(tCase, 1) _ ": the screen's read and its tool answer the port's rows")
        Do $$$AssertTrue(tPortRows.%Size() > 0, $List(tCase, 1) _ ": the port lists at least one row in " _ tNamespace)
        If tAnswer.rows.%Size() > 0 {
            Set tFirst = tAnswer.rows.%Get(0).Name
            Set tNames = ""
            Set tIterator = tResult.rows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                Set tNames = tNames _ $ListBuild(tRow.Name)
            }
            Do $$$AssertTrue($ListFind(tNames, tFirst) > 0, $List(tCase, 1) _ ": the tool carries the screen's first row " _ tFirst)
        }
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(tDescriptor, 2, .tCapped, .tHttp, .tFault)
        Do $$$AssertTrue($IsObject($Get(tCapped)) && (tCapped.rows.%Size() <= 2) && ((tPortRows.%Size() <= 2) || tCapped.truncated), $List(tCase, 1) _ ": a cap of two answers at most two rows and reports the cut")
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>A namespace that runs no productions is refused 409 <code>INTEROP.NAMESPACE</code> before any
/// switch, on each endpoint and for a write, with the published sentence.</p>
/// <p>Mutation (Rule 19): drop the <code>NamespaceFeatures.Reports</code> check from
/// <method>OcuPilot.Port.InteropPort.Invoke</method> -- this goes red.</p>
Method TestANamespaceThatRunsNoInteroperabilityIsRefused()
{
    Kill tQuery
    Set tQuery("namespace") = "%SYS"
    Set tQuery("id") = "Any.Production"
    For tCase = $ListBuild("Productions", "LIST"), $ListBuild("Processes", "LIST"), $ListBuild("Transforms", "LIST"), $ListBuild("Rules", "LIST"), $ListBuild("Productions", "STATE"), $ListBuild("Productions", "START"), $ListBuild("Productions", "RECOVER") {
        Set tSC = $ClassMethod(..#PORT, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ " " _ $List(tCase, 2) _ " in %SYS is refused")
        Do $$$AssertEquals(+$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "409|" _ ##class(OcuPilot.Api.InteropError).#NAMESPACE _ "|" _ ##class(OcuPilot.Api.InteropError).#REASONNAMESPACE, $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": 409 with the published sentence")
    }
}

/// <p>An unknown production is 404 <code>PORT.NOTFOUND</code> on a state read and on every write, and
/// the port answers 501 for an endpoint or a type it does not serve.</p>
Method TestAnUnknownProductionAndAnUnservedOperation()
{
    Kill tQuery
    Set tQuery("namespace") = "HSCUSTOM"
    Set tQuery("id") = "OcuPilotProbe.No.Such.Production"
    For tType = "STATE", "START", "STOP", "RESTART", "UPDATE", "RECOVER" {
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "404|" _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, tType _ " of an unknown production is not found")
    }
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Rules", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "501|" _ ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "a write on a code list is not implemented")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Items", "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 501, "an endpoint the port does not serve is not implemented")
}

/// <p>Each <code>INTEROP.*</code> code carries its published sentence, resolves through
/// <method>OcuPilot.Api.InteropError.ReasonFor</method>, and reaches a refused tool call and a
/// violation through <class>OcuPilot.Api.Error</class>; a code it does not declare resolves to
/// nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>INTEROP.</code> line from
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> -- this goes red.</p>
Method TestEveryInteropErrorCodeResolvesToItsSentence()
{
    Set tError = ..#ERROR
    Set tCodes = $ListFromString("NAMESPACE,RUNNING,OTHER,TROUBLED,NOTRUNNING,UPTODATE,NOTTROUBLED,BUSY,STATE,STOP,RESTART,UPDATE,RECOVER")
    For tI = 1:1:$ListLength(tCodes) {
        Set tName = $List(tCodes, tI)
        Set tCode = $Parameter(tError, tName)
        Set tReason = $Parameter(tError, "REASON" _ tName)
        Do $$$AssertTrue((tCode [ "INTEROP.") && (tReason '= ""), tName _ ": a code and a sentence are declared")
        Do $$$AssertEquals(##class(OcuPilot.Api.InteropError).ReasonFor(tCode), tReason, tCode _ ": ReasonFor answers the sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": a refused tool call carries it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": and a violation")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.InteropError).ReasonFor("INTEROP.NOSUCH"), "", "a code it does not declare resolves to nothing")
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Api.InteropError).Codes()) + $ListLength(##class(OcuPilot.Api.InteropError).ConsequenceCodes()), $ListLength(tCodes), "Codes and ConsequenceCodes list every code this test names")
}

/// <p>The port's script forms (AD-59): <code>objectscript</code> for each of the five writes, none for
/// the reads, each script switching to the namespace and calling <code>Ens.Director</code> with the
/// production as a string literal; <code>CleanProduction</code> is never named.</p>
Method TestTheScriptForms()
{
    For tType = "START", "STOP", "RESTART", "UPDATE", "RECOVER" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Productions", tType), "objectscript", tType _ " has an ObjectScript form")
    }
    For tType = "LIST", "STATE" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Productions", tType), "", tType _ " has no script form")
    }
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "Probe.""Quoted"
    For tCase = $ListBuild("START", "StartProduction(""Probe.""""Quoted"")"), $ListBuild("STOP", "StopProduction(tTimeout, 0)"), $ListBuild("RESTART", "RestartProduction(tTimeout, 0)"), $ListBuild("UPDATE", "UpdateProduction(tTimeout, 0)"), $ListBuild("RECOVER", "RecoverProduction()") {
        Set tSteps = $ClassMethod(..#PORT, "Snippet", "Productions", $List(tCase, 1), .tQuery)
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 2)) && (tText '[ "CleanProduction"), $List(tCase, 1) _ ": " _ tText)
        If ($List(tCase, 1) = "STOP") || ($List(tCase, 1) = "RESTART") || ($List(tCase, 1) = "UPDATE") {
            Do $$$AssertTrue(tText [ ("If tTimeout > " _ $Parameter(..#PORT, "STOPSECONDS")), $List(tCase, 1) _ ": the wait is capped at the port's cap")
        }
    }
}

}
