/// <p>Story 18.42's fence (AD-10, AD-21, AD-53): the kernel refuses any write of the directory allow-list through a tool the
/// agent can reach, and the tool that writes it is never one. A <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass
/// whose registry lists a tool as advertised refuses <code>PROHIBITED.ALLOWLISTAGENT</code> for the target, as does one whose
/// registry cannot be read; the shipped tool passes, and appears in no provider list, no wire lookup, no screen context and
/// no <code>shell.tools.find</code> result.</p>
/// <p>Live-safe and unarmed: it reads the registry, the descriptor and the set, and writes nothing.</p>
Class OcuPilot.Test.AllowListAgent Extends %UnitTest.TestCase
{

Parameter SET = "OcuPilot.Test.AllowListAgentSet";

Parameter TOOLNAME = "security.alloweddirectories.update";

Parameter WIRENAME = "security_alloweddirectories_update";

Parameter READWIRENAME = "security_alloweddirectories_read";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AllowedDirectoryList";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SET, "Disarm")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SET, "Disarm")
    Quit $$$OK
}

/// <p>The allow-list's scoped target reference.</p>
ClassMethod Target() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("allowed-directory", ##class(OcuPilot.Kernel.EntityRef).ScopeFor("instance"), "%GUIFileSelector", .tRef)
    Quit tRef
}

/// <p>Ask the set about the tool <var>pTool</var> writing the allow-list: <code>&lt;prohibits&gt; &lt;code&gt;</code>.</p>
ClassMethod Ask(pTool As %String) As %String
{
    Set tSC = $ClassMethod(..#SET, "Prohibits", pTool, ..Target(), {"Action": "add", "Directory": "/tmp/"}.%ToJSON(), "[]", .tProhibits, .tCode)
    Quit $Select($$$ISOK(tSC): tProhibits _ " " _ tCode, 1: "error")
}

/// <p>A tool the registry lists as advertised that writes the allow-list is refused, a registry that cannot be read is
/// refused as reachable, and the shipped tool, which the registry leaves out unless asked, passes.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.AgentReachable</method> answer 0 -- both refusals
/// go red.</p>
Method TestAToolTheAgentCanReachCannotWriteTheAllowList()
{
    Set tCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "ALLOWLISTAGENT")
    Do $ClassMethod(..#SET, "Arm", "probe.allowlist.write")
    Do $$$AssertEquals(..Ask("probe.allowlist.write"), "1 " _ tCode, "an advertised probe tool is refused")
    Do $$$AssertEquals(..Ask(..#TOOLNAME), "0 ", "while the shipped tool, which that registry does not list, passes")
    Do $ClassMethod(..#SET, "Arm", "")
    Do $$$AssertEquals(..Ask("probe.allowlist.write"), "1 " _ tCode, "a registry that cannot be read refuses it too")
    Do $$$AssertEquals(..Ask(..#TOOLNAME), "1 " _ tCode, "and refuses the shipped tool, since a question it cannot answer is not passed")
    Do $ClassMethod(..#SET, "Disarm")
    Do $$$AssertEquals(..Ask(..#TOOLNAME), "0 ", "the shipped registry leaves the shipped tool out, so it passes")
    Do $$$AssertEquals(..Ask("webapp.list.update"), "1 " _ tCode, "and an advertised tool the shipped registry lists is refused for the allow-list target")
}

/// <p>The gate both the confirm and the route call refuses the shipped tool's write when the registry lists that tool as
/// advertised, with 403 and the kernel's code, and passes it when the shipped registry answers (C3).</p>
/// <p>Mutation (Rule 19): remove the <code>TYPEALLOWEDDIRECTORY</code> clause from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- the refusal leg goes red.</p>
Method TestTheSharedOperationGateRefusesItWhenTheToolIsReachable()
{
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#TOOLNAME, .tTool, 1)
    Do $$$AssertEquals($IsObject(tTool), 1, "the shipped tool resolves for the screen's own route")
    If '$IsObject(tTool) Quit
    Set tCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "ALLOWLISTAGENT")
    Set tPayload = {"Action": "add", "Directory": "/tmp/"}.%ToJSON()
    Do $ClassMethod(..#SET, "Arm", ..#TOOLNAME)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, ..Target(), tPayload, "[]", tPayload, $Username, ..#SET, "", .tPairs, .tRefused, .tHttp, .tGateCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the gate answers")
    Do $$$AssertEquals(tRefused _ "|" _ tHttp _ "|" _ tGateCode, "1|403|" _ tCode, "a reachable tool is refused 403 with the kernel's code")
    Do $ClassMethod(..#SET, "Disarm")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, ..Target(), tPayload, "[]", tPayload, $Username, ..#SET, "", .tPairs2, .tRefused2, .tHttp2, .tGateCode2, .tDetail2)
    Do $$$AssertEquals(tRefused2 _ "|" _ tGateCode2, "0|", "and the unadvertised tool passes the same gate")
}

/// <p>The shipped tool is declared unadvertised and so appears nowhere the agent is offered tools: not the provider list, not
/// the wire lookup, not the screen's context, not the discovery tool's result -- while the screen's read tool appears in
/// each that should carry it.</p>
/// <p>Mutation (Rule 19): <code>ADVERTISED</code> 1 on <class>OcuPilot.Screen.Tool.AllowedDirectoryUpdate</class> -- every
/// leg goes red.</p>
Method TestTheShippedToolIsInNoListTheAgentSees()
{
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.AllowedDirectoryUpdate", "Advertised"), 0, "it declares itself unadvertised")
    Set tSC = $ClassMethod(..#REGISTRY, "ProviderTools", .tTools)
    Do $$$AssertStatusOK(tSC, "the provider list builds")
    Set tNames = ""
    For tI = 1:1:+$Get(tTools) Set tNames = tNames _ $ListBuild(tTools(tI, "name"))
    Do $$$AssertTrue($ListFind(tNames, ..#READWIRENAME) > 0, "the provider list carries the screen's read tool")
    Do $$$AssertEquals($ListFind(tNames, ..#WIRENAME), 0, "and not the update")
    Set tSC = $ClassMethod(..#REGISTRY, "ResolveWire", ..#WIRENAME, .tWire)
    Do $$$AssertEquals($IsObject(tWire), 0, "the model's call to it by wire name resolves to nothing")
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#TOOLNAME, .tByName)
    Do $$$AssertEquals($IsObject(tByName), 0, "and the agent's lookup by name finds nothing")
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#TOOLNAME, .tOwn, 1)
    Do $$$AssertEquals($IsObject(tOwn), 1, "while the screen's own route resolves it")
    Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tContext)
    Do $$$AssertStatusOK(tSC, "the screen context's tools build")
    Set tContext = $Select($IsObject($Get(tContext)): tContext.%ToJSON(), 1: "")
    Do $$$AssertTrue(tContext [ ..#READWIRENAME, "the context carries the read tool")
    Do $$$AssertTrue(tContext '[ ..#WIRENAME, "and not the update")
    Set tSC = ##class(OcuPilot.Screen.Tool.ToolsFind).View("", {"query": "allowed directories update"}, 200, .tFound, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the discovery tool answers")
    Set tFound = $Select($IsObject($Get(tFound)): tFound.%ToJSON(), 1: "")
    Do $$$AssertTrue(tFound [ ..#READWIRENAME, "it finds the read tool by what it does")
    Do $$$AssertTrue(tFound '[ ..#WIRENAME, "and never the update")
}

/// <p>The kernel's reason is the published sentence and names no caller, and its code is one of the set's.</p>
Method TestTheCodeIsTheSetsAndItsReasonNamesNoCaller()
{
    Set tSet = "OcuPilot.Kernel.Proposal.Prohibited"
    Set tCode = $Parameter(tSet, "ALLOWLISTAGENT")
    Do $$$AssertEquals(tCode, "PROHIBITED.ALLOWLISTAGENT", "the code")
    Do $$$AssertTrue($ListFind($ClassMethod(tSet, "Codes"), tCode) > 0, "the set lists it")
    Do $$$AssertEquals($ClassMethod(tSet, "ReasonFor", tCode), $Parameter(tSet, "ALLOWLISTAGENTREASON"), "and answers its one sentence")
    Do $$$AssertTrue($ZConvert($ClassMethod(tSet, "ReasonFor", tCode), "L") '[ "agent", "which names no caller")
    Do $$$AssertTrue($ListFind($ClassMethod(tSet, "CoveredTypes"), "allowed-directory") > 0, "and the type is covered")
}

}
