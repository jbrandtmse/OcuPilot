/// <p>Pins Story 20.15's declarations (AD-5, AD-36, AD-51, AD-52, AD-53, AD-64): the <code>access</code>
/// source kind's refusals, which <file>ui/tools/screen-mirror.test.mjs</file> runs off this class's
/// <code>Cases</code> block as well; the Screen permissions descriptor; its three write tools' kind, port,
/// pairs, fingerprint subject and governance keys; their presence in every roster the agent sees; that no
/// other descriptor or tool declares the either-of pair; the <code>screen-permission</code> entity type; and
/// the signature of the internal
/// <code>$System.Security.ResourceExists</code> the port's rules call.</p>
/// <p>It needs a compiled instance, makes no request and writes nothing.</p>
Class OcuPilot.Test.ScreenAccessDescriptor Extends %UnitTest.TestCase
{

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AgentScreenPermissions";

Parameter PORT = "OcuPilot.Port.ScreenAccessPort";

/// <p>The three writes, <code>&lt;class&gt;|&lt;tool&gt;|&lt;write type&gt;|&lt;screen action&gt;|&lt;fingerprint subject&gt;</code>.</p>
Parameter TOOLS = "ScreenAccessAddPair|agent.screenpermissions.addpair|PUT|add-pair|Pair,Pairs,Adjusted;ScreenAccessRemovePair|agent.screenpermissions.removepair|PUT|remove-pair|Pair,Pairs,Adjusted;ScreenAccessReset|agent.screenpermissions.reset|DELETE|reset|Pairs,Adjusted";

/// <p>The corpus both engines run: each case replaces the declaration's <code>read.source</code>, sets
/// <code>read.criteria</code> when it carries one, and names the sentence the registry's
/// <code>ReadProblem</code> answers, or <code>null</code>.</p>
XData Cases
{
{
  "declaration": {
    "route": "agent/corpus", "area": "agent", "labelKey": "agentScreenPermissionsLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Development", "permission": "USE"}],
    "entityType": "screen-permission", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "composite", "parts": ["Screen"]},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Screen", "Area"], "secretFields": []},
    "emptyStateKey": "screenPermissionsEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "access", "endpoint": "Screens", "type": "LIST"},
      "fields": ["Screen", "Area"],
      "filter": ["Screen", "Area"],
      "sort": {"fields": ["Area", "Screen"], "default": "Area", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Screen", "labelKey": "agentLedgerColumnScreen", "kind": "name"}, {"field": "Area", "labelKey": "screenPermissionsColumnArea", "kind": "text"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "agent.corpus"
  },
  "cases": [
    {"name": "an access LIST of Screens is sound", "source": {"port": "access", "endpoint": "Screens", "type": "LIST"}, "expected": null},
    {"name": "an endpoint the source does not serve", "source": {"port": "access", "endpoint": "Items", "type": "LIST"}, "expected": "read.source.endpoint 'Items' is not the access source's endpoint ('Screens') (AD-64)"},
    {"name": "a type other than LIST", "source": {"port": "access", "endpoint": "Screens", "type": "GET"}, "expected": "read.source.type 'GET' is declared on an access source, which lists the screens' required permissions (AD-36)"},
    {"name": "rowGet", "source": {"port": "access", "endpoint": "Screens", "type": "LIST", "rowGet": {"key": "Screen", "param": "name", "fields": ["Area"], "derived": []}}, "expected": "read.source.rowGet is declared on an access source, which answers its list whole (AD-36)"},
    {"name": "forEach", "source": {"port": "access", "endpoint": "Screens", "type": "LIST", "forEach": ["Screens"]}, "expected": "read.source.forEach is declared on an access source, which answers its list whole (AD-36)"},
    {"name": "query", "source": {"port": "access", "endpoint": "Screens", "type": "LIST", "query": {"a": "b"}}, "expected": "read.source.query is declared on an access source, which answers its list whole (AD-36)"},
    {"name": "parts", "source": {"port": "access", "endpoint": "Screens", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on an access source, which answers its list whole (AD-36)"},
    {"name": "a list over one member", "source": {"port": "access", "endpoint": "Screens", "type": "LIST", "rows": "rows"}, "expected": "read.source.rows is declared on a 'access' source, and a list over one member reads an admin endpoint's one-object answer (AD-36)"},
    {"name": "criteria", "source": {"port": "access", "endpoint": "Screens", "type": "LIST"}, "criteria": {"fields": [{"param": "pattern", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on an access source, which takes no criteria (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry,
/// and the corpus refuses at least one shape.</p>
/// <p>Mutation (Rule 19): drop the access arm from <method>OcuPilot.Screen.Registry.ReadProblem</method>
/// -- the endpoint, type, key and criteria cases go red.</p>
Method TestTheAccessSourceRefusals()
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
        Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertTrue(tRefusals >= 7, "the corpus refuses its shapes: " _ tRefusals)
}

/// <p>The descriptor declares what the spec names: the Agent co-pilot area at position 7, a list of
/// the <code>screen-permission</code> entity at instance scope, the declared pair <code>%Development:USE</code>, which the descriptor widens to
/// either-of with <code>%Admin_Secure:USE</code>, and no classic page, the access source on <code>Screens</code>, the three row actions, three prompts in
/// the access group and the five columns, and passes the registry.</p>
/// <p>Mutation (Rule 19): set its <code>privileges</code> to <code>[]</code> -- the pair leg goes red; make <method>OcuPilot.Screen.Descriptor.AgentScreenPermissions.PrivilegePairs</method> answer the
/// declaration -- the either-of leg goes red.</p>
Method TestTheDescriptorDeclaresScreenPermissions()
{
    Set tClass = ..#DESCRIPTOR
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.scope, "agent/screenpermissions|agent|7|list|instance", "its place")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.classicPage, "screen-permission|agent.screenpermissions|", "its entity type, tool identifier and no classic page")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Development"",""permission"":""USE""}]", "its declared pair")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "OwnPrivilegePairs")), 0, "which is not an own pair beyond an area set")
    Set tEither = $ClassMethod(tClass, "PrivilegePairs")
    Do $$$AssertEquals($ListLength(tEither) _ "|" _ $List($List(tEither, 1), 1) _ "|" _ $List($List(tEither, 1), 2), "1|%Development|%Admin_Secure|USE", "but it requires the either-of pair: %Development:USE or %Admin_Secure:USE")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "access|Screens|LIST", "read through the access source")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RowActionIds")), "add-pair,remove-pair,reset", "its three row actions")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "three suggested prompts")
    Set tIterator = tDeclaration.suggestedPrompts.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPrompt) {
        Do $$$AssertEquals(tPrompt.groupKey, "userPromptGroupAccess", "prompt " _ (tIndex + 1) _ " is in the access group")
    }
    Do $$$AssertEquals(tDeclaration.table.columns.%Size(), 5, "five columns")
    Do $$$AssertEquals(tDeclaration.read.filter.%ToJSON(), "[""Screen"",""Area""]", "filtered on Screen and Area")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("screen-permission"), "the entity type is in the closed vocabulary")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).DescriptorForTool("agent.screenpermissions") = tClass, "the registry resolves it by tool identifier")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Gate).Adjustable(tClass), 0, "and the screen cannot itself be adjusted: its area declares no pair")
}

/// <p>Each write declares its kind, port, request type, screen action, bodyless action style, fingerprint
/// subject and enabled key, and requires the descriptor's either-of pair alone (AD-51, AD-52, AD-64).</p>
/// <p>Mutation (Rule 19): route one tool's <code>PrivilegePairs</code> through
/// <method>OcuPilot.Screen.Gate.RequiredPairs</method> while <method>OcuPilot.Screen.Gate.Adjustable</method>
/// answers 1 -- <class>OcuPilot.Test.ScreenAccessGate</class>'s stray-row tool legs go red; change a
/// fingerprint subject here and the subject leg goes red.</p>
Method TestTheToolsDeclareTheirKindsPortsAndPairs()
{
    Set tDeclared = $ClassMethod(..#DESCRIPTOR, "PrivilegePairs")
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tRow = $Piece(..#TOOLS, ";", tI)
        Set tClass = "OcuPilot.Screen.Tool." _ $Piece(tRow, "|", 1)
        Set tName = $Piece(tRow, "|", 2)
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME") _ "|" _ $Parameter(tClass, "KIND") _ "|" _ $Parameter(tClass, "PORTCLASS"), tName _ "|write|" _ ..#PORT, tName _ ": a write through the screen access port")
        Do $$$AssertEquals($ClassMethod(tClass, "WriteType") _ "|" _ $Parameter(tClass, "SCREENACTIONS") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive"), $Piece(tRow, "|", 3) _ "|" _ $Piece(tRow, "|", 4) _ "|0|0", tName _ ": its request type, its screen action, bodyless and not destructive")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), $Piece(tRow, "|", 5), tName _ ": its fingerprint subject")
        Do $$$AssertEquals($ClassMethod(tClass, "Advertised"), 1, tName _ ": advertised to the agent (AD-64)")
        Do $$$AssertEquals($ClassMethod(tClass, "PrivilegePairs"), tDeclared, tName _ ": requires the descriptor's declared pairs")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "IdArgument") _ "|" _ $ClassMethod(tClass, "IdParam"), "Screen|Screen|Screen", tName _ ": addressed by the screen's identifier")
        Do $$$AssertTrue($ListFind($ClassMethod(tClass, "PreconditionCodes"), ##class(OcuPilot.Api.AccessError).#NOTADJUSTED) > 0, tName _ ": names the port's state refusals")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed(tName), 1, tName _ ": its governance key ships enabled")
    }
}

/// <p>AC1, AD-53, AD-64: the three writes are in every roster the agent sees -- the provider tool list, the
/// dispatch lookup, a proposal-path resolve and the screen context's <code>tools</code> -- and the registry
/// lists each, so the screen route resolves it.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ScreenAccessAction.ADVERTISED</parameter> 0 --
/// this goes red.</p>
Method TestTheWritesAreInEveryRosterTheAgentSees()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    Set tProviderNames = ""
    For tI = 1:1:+$Get(tProvider) Set tProviderNames = tProviderNames _ $ListBuild(tProvider(tI, "name"))
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tAll), "the registry lists")
    Set tListed = ""
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tListed = tListed _ $ListBuild(tEntry.%Get("name"))
    }
    Kill tContextTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tContextTools), "the screen context's tools build")
    Set tContextWires = ""
    If $IsObject($Get(tContextTools)) {
        Set tIterator = tContextTools.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tWireName) {
            Set tContextWires = tContextWires _ $ListBuild(tWireName)
        }
    }
    Do $$$AssertTrue($ListFind(tContextWires, $ClassMethod(tRegistry, "WireName", "agent.screenpermissions.read")), "the screen context's tools list the read tool: " _ $ListToString(tContextWires))
    For tI = 1:1:$Length(..#TOOLS, ";") {
        Set tTool = $Piece($Piece(..#TOOLS, ";", tI), "|", 2)
        Set tWire = $ClassMethod(tRegistry, "WireName", tTool)
        Do $$$AssertTrue($ListFind(tProviderNames, tWire), tTool _ ": the provider tool list carries it")
        Kill tByWire, tByName, tForRoute
        Do $ClassMethod(tRegistry, "ResolveWire", tWire, .tByWire)
        Do $$$AssertTrue($IsObject($Get(tByWire)), tTool _ ": the dispatch lookup finds it")
        Do $ClassMethod(tRegistry, "Resolve", tTool, .tByName)
        Do $$$AssertTrue($IsObject($Get(tByName)), tTool _ ": and a proposal-path resolve")
        Do $ClassMethod(tRegistry, "Resolve", tTool, .tForRoute, 1)
        Do $$$AssertTrue($IsObject($Get(tForRoute)) && $ListFind(tListed, tTool), tTool _ ": and the registry lists it and the screen route resolves it")
        Do $$$AssertTrue($ListFind(tContextWires, tWire), tTool _ ": and the screen context's tools carry it")
    }
    Do $$$AssertTrue($ListFind(tProviderNames, $ClassMethod(tRegistry, "WireName", "agent.screenpermissions.read")), "the read tool is advertised")
}

/// <p>The script form (AD-59): a write renders one <code>objectscript</code> step carrying the screen and the
/// one pair as string literals, a quote doubled; a read renders no step.</p>
/// <p>Mutation (Rule 19): <code>Literal</code> stops doubling a quote, or <code>Snippet</code> drops the
/// <code>ADDKEY</code> line; this reddens.</p>
Method TestTheScriptRendersTheWritesAndNotTheRead()
{
    Kill tQuery
    Set tQuery("Screen") = "osmgmt.locks"
    Set tQuery("addpair") = "%Admin_Secure:USE"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Screen", "PUT", .tQuery, "", {})
    Set tText = $Select($IsObject(tSteps) && (tSteps.%Size() > 0): tSteps.%Get(0).%Get("text"), 1: "")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Screen", "PUT") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Screen", "DELETE") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Screen", "GET"), "objectscript|objectscript|", "the writes have a script form and the read has none")
    Do $$$AssertTrue((tText [ "tQuery(""Screen"") = ""osmgmt.locks""") && (tText [ "tQuery(""addpair"") = ""%Admin_Secure:USE""") && (tText [ """PUT"""), "the step carries the screen, the pair and the call: " _ tText)
    Kill tQuery
    Set tQuery("Screen") = "a""b"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Screen", "DELETE", .tQuery, "", {})
    Set tText = $Select($IsObject(tSteps) && (tSteps.%Size() > 0): tSteps.%Get(0).%Get("text"), 1: "")
    Do $$$AssertTrue(tText [ "= ""a""""b""", "a quote in a value is doubled: " _ tText)
    Kill tQuery
    Set tQuery("Screen") = "osmgmt.locks"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Screen", "GET", .tQuery, "", {})
    Do $$$AssertEquals(tSteps.%Size(), 0, "a read renders no step")
}

/// <p>The either-of pair (a resource carrying <parameter>OcuPilot.Screen.Gate.ALTERNATIVESEPARATOR</parameter>)
/// is declared by five descriptors and tools alone: the Screen permissions descriptor, its read tool and its
/// three write tools. It reads every registered descriptor's <code>PrivilegePairs</code> and its
/// <code>RequiredPairs</code> as the gate reads it, and every registered tool's pairs as
/// <method>OcuPilot.Screen.Tool.Registry.RequiredPairs</method> reads them, extra and <code>CLASSICPAGES</code>
/// pairs included. A surface outside the five that declares one fails, naming it, and so does one of the five
/// that does not. A port's pair parameters and a tool's per-call <code>ArgumentPairs</code> are not read.</p>
/// <p>Mutation (Rule 19): make another descriptor's <code>PrivilegePairs</code> (Locks') answer
/// <method>OcuPilot.Screen.Gate.AdjusterPairs</method> -- this goes red naming it; make Screen permissions'
/// answer its declaration -- this goes red naming each of the five.</p>
Method TestTheEitherOfPairIsDeclaredByItsFiveSurfacesOnly()
{
    Set tSeparator = ##class(OcuPilot.Screen.Gate).#ALTERNATIVESEPARATOR
    Set tFive = $ListBuild(..#DESCRIPTOR, "agent.screenpermissions.read")
    For tI = 1:1:$Length(..#TOOLS, ";") Set tFive = tFive _ $ListBuild($Piece($Piece(..#TOOLS, ";", tI), "|", 2))
    Kill tCarrying
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors), "the descriptors list")
    Do $$$AssertTrue($ListLength(tDescriptors) > 1, "more than one descriptor is registered: " _ $ListLength(tDescriptors))
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tClass = $List(tDescriptors, tI)
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs")
        Set tRequired = $ClassMethod("OcuPilot.Screen.Gate", "RequiredPairs", tClass, .tResolved)
        If ..CarriesAlternative(tPairs, tSeparator) || ..CarriesAlternative(tRequired, tSeparator) Set tCarrying(tClass) = ""
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools), "the tools list")
    Do $$$AssertTrue(tTools.%Size() > 1, "more than one tool is registered: " _ tTools.%Size())
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tEntry, .tToolResolved)
        If ..CarriesAlternative(tPairs, tSeparator) Set tCarrying(tEntry.%Get("name")) = ""
    }
    For tI = 1:1:$ListLength(tFive) {
        Set tSurface = $List(tFive, tI)
        Do $$$AssertTrue($Data(tCarrying(tSurface)), tSurface _ ": still declares the either-of pair")
        Kill tCarrying(tSurface)
    }
    Set tStray = $Order(tCarrying(""))
    While tStray '= "" {
        Do $$$AssertTrue(0, tStray _ ": declares the either-of pair, which only Screen permissions and its four tools may")
        Set tStray = $Order(tCarrying(tStray))
    }
}

/// <p>Whether any pair of <var>pPairs</var> has a resource carrying <var>pSeparator</var>.</p>
ClassMethod CarriesAlternative(pPairs As %List, pSeparator As %String) As %Boolean [ Private ]
{
    Set tFound = 0
    For tI = 1:1:$ListLength(pPairs) {
        If $List($List(pPairs, tI), 1) [ pSeparator Set tFound = 1
    }
    Quit tFound
}

/// <p>The port's rules call the <code>[Internal]</code> <code>$System.Security.ResourceExists</code>, so
/// its signature is pinned: a class method taking one resource name and answering a boolean. The
/// instance answers 1 for a defined resource, in any case, and 0 for an undefined name.</p>
/// <p>Mutation (Rule 19): none; an IRIS build that changes the signature reddens this.</p>
Method TestResourceExistsKeepsItsSignature()
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("%SYSTEM.Security||ResourceExists")
    Do $$$AssertTrue($IsObject(tMethod), "the method is compiled")
    If '$IsObject(tMethod) Quit
    Do $$$AssertEquals(tMethod.ClassMethod _ "|" _ tMethod.FormalSpec _ "|" _ tMethod.ReturnType, "1|Resource:%String|%Library.Boolean", "a class method of one resource name answering a boolean")
    Do $$$AssertEquals(''$System.Security.ResourceExists("%Admin_Secure") _ "|" _ ''$System.Security.ResourceExists("%ADMIN_SECURE") _ "|" _ ''$System.Security.ResourceExists("OcuPilotNoSuchResource"), "1|1|0", "defined in any case, and an undefined name is not")
}

}
