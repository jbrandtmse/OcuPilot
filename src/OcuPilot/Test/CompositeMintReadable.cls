/// <p>What a refused composite id reads as (AD-13): <class>OcuPilot.Kernel.Proposal.Mint</class> makes the
/// <code>detail.problem</code> of every refusal it answers readable, so the agent's cancel of a background
/// task the instance does not hold is refused naming <code>Management Portal &#8250; 999999999</code>, the
/// two parts joined by a breadcrumb and holding no <code>$Char(1)</code>, the composite separator.</p>
/// <p>The mint is <class>OcuPilot.Test.BackgroundTaskMintFixture</class>, whose one replaced seam is the port,
/// answering an armed empty portal list, so nothing here touches a task and nothing is stored.</p>
Class OcuPilot.Test.CompositeMintReadable Extends %UnitTest.TestCase
{

Parameter FIXTURE = "OcuPilot.Test.BackgroundTaskFixture";

Parameter MINT = "OcuPilot.Test.BackgroundTaskMintFixture";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.BackgroundTaskList";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter TOOL = "tasks.background.cancel";

Parameter SOURCE = "Management Portal";

Parameter ABSENTID = "999999999";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$OK
}

/// <p>The cancel of a task the portal list does not hold is refused 400 <code>TOOL.ARGUMENTS</code>, the
/// problem saying the task is not present and naming it by source and id with the breadcrumb between them.</p>
/// <p>Mutation (Rule 19): remove the readable-id pass from <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>
/// -- the problem carries <code>$Char(1)</code> and this goes red.</p>
Method TestAnAbsentBackgroundTaskIsNamedReadably()
{
    Do $ClassMethod(..#FIXTURE, "ArmPortal", "[]")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), ..#TOOL _ " is registered")
    If '$IsObject($Get(tTool)) Quit
    Set tClass = tTool.class
    Set tArgs = {}
    Do tArgs.%Set("source", ..#SOURCE, "string")
    Do tArgs.%Set("id", ..#ABSENTID, "string")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#TOOL, $Username, "", "", tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), ..#ABSENTID, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), tClass)
    Do $$$AssertStatusNotOK(tSC, "the cancel of an absent task does not mint")
    Set tCode = $Select($IsObject(tFault): tFault.%Get("code"), 1: "")
    Set tProblem = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "it is refused as a tool arguments refusal")
    Do $$$AssertTrue(tProblem [ "is not present", "and says the task is not present: " _ tProblem)
    Do $$$AssertTrue(tProblem '[ $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR), "its problem holds no U+0001")
    Do $$$AssertTrue(tProblem [ (..#SOURCE _ " " _ $Char(8250) _ " " _ ..#ABSENTID), "and names the task's parts with the breadcrumb: " _ tProblem)
    Do $$$AssertEquals(tProblem, "'" _ ..#SOURCE _ " " _ $Char(8250) _ " " _ ..#ABSENTID _ "' is not present on this instance", "in the sentence the sibling mints give")
}

}
