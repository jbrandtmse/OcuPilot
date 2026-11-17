/// <p>Story 24.5's person-only rule (AD-10, AD-53): the unit-test run is a person's alone. Its tool is declared unadvertised, so
/// the provider's list, the wire lookup, the agent's lookup by name, the screen's context and the discovery tool never carry it
/// while the route's own lookup resolves it; a <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass whose registry lists
/// it as advertised refuses <code>PROHIBITED.PERSONONLY</code>, including through the shared operation gate; and every
/// registered write whose port endpoint is the run's declares <code>PERSONGATE</code>.</p>
/// <p>Live-safe and unarmed: it reads the registry, the descriptors and the set, and writes nothing. Needs a process holding the
/// screen's privilege pairs, since the shared gate asks them before the prohibited set.</p>
Class OcuPilot.Test.UnitTestPersonOnly Extends %UnitTest.TestCase
{

Parameter SET = "OcuPilot.Test.UnitTestPersonOnlySet";

Parameter TOOLNAME = "explorer.unittests.run";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.ExplorerUnitTestRun";

Parameter WIRENAME = "explorer_unittests_run";

Parameter READWIRENAME = "explorer_unittests_read";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerUnitTests";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SET, "Disarm")
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SET, "Disarm")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The run's target reference: the literal <code>unittests</code> under <code>class</code> in the route's namespace.</p>
ClassMethod Target() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("class", ##class(OcuPilot.Kernel.EntityRef).ScopeFor("namespace"), "unittests", .tRef)
    Quit tRef
}

/// <p>Ask the set about the tool <var>pTool</var> writing the run's target: <code>&lt;prohibits&gt; &lt;code&gt;</code>.</p>
ClassMethod Ask(pTool As %String) As %String
{
    Set tSC = $ClassMethod(..#SET, "Prohibits", pTool, ..Target(), {"Tests": "OcuProbe245.Mixed", "Level": "class"}.%ToJSON(), "[]", .tProhibits, .tCode)
    Quit $Select($$$ISOK(tSC): tProhibits _ " " _ tCode, 1: "error")
}

/// <p>The tool is declared unadvertised and so appears nowhere the agent is offered tools: not the provider list, not the wire
/// lookup by either name, not the agent's lookup by name, not the screen's context, not the discovery tool's result -- while the
/// screens' read tools appear where they should, and the registry still resolves the tool for the action route.</p>
/// <p>Mutation (Rule 19): <code>ADVERTISED</code> 1 on <class>OcuPilot.Screen.Tool.ExplorerUnitTestRun</class> -- the provider,
/// wire, name and discovery legs go red.</p>
Method TestTheToolIsInNoListTheAgentSees()
{
    Do $$$AssertEquals($ClassMethod(..#TOOLCLASS, "Advertised"), 0, "it declares itself unadvertised")
    Set tSC = $ClassMethod(..#REGISTRY, "ProviderTools", .tTools)
    Do $$$AssertStatusOK(tSC, "the provider list builds")
    Set tNames = ""
    For tI = 1:1:+$Get(tTools) Set tNames = tNames _ $ListBuild(tTools(tI, "name"))
    Do $$$AssertTrue($ListFind(tNames, ..#READWIRENAME) > 0, "the provider list carries the Unit tests read tool")
    Do $$$AssertEquals($ListFind(tNames, ..#WIRENAME), 0, "and not the run")
    Set tSC = $ClassMethod(..#REGISTRY, "ResolveWire", ..#WIRENAME, .tWire)
    Do $$$AssertEquals($IsObject(tWire), 0, "the model's call to it by wire name resolves to nothing")
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#TOOLNAME, .tByName)
    Do $$$AssertEquals($IsObject(tByName), 0, "the agent's lookup by name finds nothing")
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#TOOLNAME, .tOwn, 1)
    Do $$$AssertEquals($IsObject(tOwn), 1, "while the screen's own route resolves it")
    Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tContext)
    Do $$$AssertStatusOK(tSC, "the screen context's tools build")
    Set tContext = $Select($IsObject($Get(tContext)): tContext.%ToJSON(), 1: "")
    Do $$$AssertTrue(tContext [ ..#READWIRENAME, "the context carries the read tool")
    Do $$$AssertTrue(tContext '[ ..#WIRENAME, "and not the run")
    Set tSC = ##class(OcuPilot.Screen.Tool.ToolsFind).View("", {"query": "unit tests"}, 200, .tFound, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the discovery tool answers")
    Set tFound = $Select($IsObject($Get(tFound)): tFound.%ToJSON(), 1: "")
    Do $$$AssertTrue(tFound [ ..#READWIRENAME, "and finds the read tool for the same words")
    Do $$$AssertTrue(tFound '[ ..#WIRENAME, "and never lists the run")
}

/// <p>A tool the registry lists as advertised whose class declares <code>PERSONGATE</code> is refused
/// <code>PROHIBITED.PERSONONLY</code> for the run's target, before any type arm; the
/// shipped tool, which the registry leaves out unless asked, passes; and the shared operation gate refuses it 403 when the
/// registry lists it, and passes it when the shipped registry answers.</p>
/// <p>Mutation (Rule 19): remove the <code>PERSONONLY</code> arm from <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>
/// -- the refusal legs go red.</p>
Method TestAToolTheAgentCanReachCannotRunTheTests()
{
    Set tCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "PERSONONLY")
    Do $ClassMethod(..#SET, "Arm", ..#TOOLNAME, ..#TOOLCLASS)
    Do $$$AssertEquals(..Ask(..#TOOLNAME), "1 " _ tCode, "the tool, listed as advertised, is refused")
    Do $ClassMethod(..#SET, "Arm", "probe.unittests.run", ..#TOOLCLASS)
    Do $$$AssertEquals(..Ask(..#TOOLNAME), "0 ", "while a tool the registry does not list as that name passes this arm and the type arms")
    Do $ClassMethod(..#SET, "Disarm")
    Do $$$AssertEquals(..Ask(..#TOOLNAME), "0 ", "and the shipped registry leaves the shipped tool out, so it passes")
    Do $$$AssertEquals(..Ask("webapp.list.update"), "0 ", "a tool that declares no PERSONGATE is not judged by this arm")
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#TOOLNAME, .tTool, 1)
    Do $$$AssertEquals($IsObject(tTool), 1, "the shipped tool resolves for the screen's own route")
    If '$IsObject(tTool) Quit
    Set tPayload = {"Tests": "OcuProbe245.Mixed", "Level": "class"}.%ToJSON()
    Do $ClassMethod(..#SET, "Arm", ..#TOOLNAME, ..#TOOLCLASS)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, ..Target(), tPayload, "[]", tPayload, $Username, ..#SET, "", .tPairs, .tRefused, .tHttp, .tGateCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the gate answers")
    Do $$$AssertEquals(tRefused _ "|" _ tHttp _ "|" _ tGateCode, "1|403|" _ tCode, "a reachable tool is refused 403 with the kernel's code")
    Do $ClassMethod(..#SET, "Disarm")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, ..Target(), tPayload, "[]", tPayload, $Username, ..#SET, "", .tPairs2, .tRefused2, .tHttp2, .tGateCode2, .tDetail2)
    Do $$$AssertEquals(tRefused2 _ "|" _ tGateCode2, "0|", "and the unadvertised tool passes the same gate")
}

/// <p>Every registered write whose port is the developer-tool port and whose endpoint is the unit-test run's declares
/// <code>PERSONGATE</code> and is unadvertised, so a later write of the run cannot ship open or reachable; and at least one
/// exists, so the loop is not empty.</p>
/// <p>Mutation (Rule 19): empty <code>PERSONGATE</code> on <class>OcuPilot.Screen.Tool.ExplorerUnitTestRun</class> -- this goes
/// red.</p>
Method TestEveryWriteOfTheRunEndpointDeclaresThePersonGate()
{
    Set tSC = $ClassMethod(..#REGISTRY, "ListTools", .tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists")
    If $$$ISERR(tSC) Quit
    Set tFound = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If (tTool.kind '= "write") || (tTool.class = "") Continue
        If $ClassMethod(tTool.class, "PortClass") '= "OcuPilot.Port.DevToolPort" Continue
        If $ClassMethod(tTool.class, "Endpoint") '= ##class(OcuPilot.Port.DevToolPort).#ENDPOINTUNITTESTRUN Continue
        Set tFound = tFound + 1
        Do $$$AssertTrue($Parameter(tTool.class, "PERSONGATE") '= "", tTool.name _ ": declares PERSONGATE")
        Do $$$AssertEquals($Parameter(tTool.class, "ADVERTISED"), 0, tTool.name _ ": is unadvertised")
    }
    Do $$$AssertTrue(tFound > 0, "the run's write is registered (" _ tFound _ ")")
}

/// <p>The kernel's reason is the published sentence and names no caller, and its code is one of the set's.</p>
Method TestTheCodeIsTheSetsAndItsReasonNamesNoCaller()
{
    Set tSet = "OcuPilot.Kernel.Proposal.Prohibited"
    Set tCode = $Parameter(tSet, "PERSONONLY")
    Do $$$AssertEquals(tCode, "PROHIBITED.PERSONONLY", "the code")
    Do $$$AssertTrue($ListFind($ClassMethod(tSet, "Codes"), tCode) > 0, "the set lists it")
    Do $$$AssertEquals($ClassMethod(tSet, "ReasonFor", tCode), $Parameter(tSet, "PERSONONLYREASON"), "and answers its one sentence")
    Do $$$AssertTrue($ZConvert($ClassMethod(tSet, "ReasonFor", tCode), "L") '[ "agent", "which names no caller")
}

}
