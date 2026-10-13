/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass with one replaced seam: while armed,
/// <method>RegistryClass</method> names this class, whose <method>Resolve</method> answers as a tool registry would for the
/// tool a test names as one the agent can reach, or fails as a registry that cannot be read does. Disarmed, the shipped
/// registry answers and every predicate is the shipped code.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. The arming lives in a
/// process-private global, so nothing outlives the test process.</p>
Class OcuPilot.Test.AllowListAgentSet Extends OcuPilot.Kernel.Proposal.Prohibited
{

/// <p>Answer <var>pName</var> as an advertised tool until <method>Disarm</method>; with <var>pName</var> empty, fail the
/// resolve instead.</p>
ClassMethod Arm(pName As %String = "")
{
    Set ^||OcuPilotAllowListAgentSet = $ListBuild(pName)
}

/// <p>Raise from the resolve, as a registry that faults does, until <method>Disarm</method>.</p>
ClassMethod ArmRaise()
{
    Set ^||OcuPilotAllowListAgentSet = $ListBuild("", 1)
}

ClassMethod Disarm()
{
    Kill ^||OcuPilotAllowListAgentSet
}

ClassMethod RegistryClass() As %String
{
    If $Data(^||OcuPilotAllowListAgentSet) Quit $ClassName()
    Quit ##super()
}

/// <p>The registry's resolve: the armed name resolves to an advertised entry, any other name to none, and an arm with no name
/// to an error. An unadvertised tool never resolves unless <var>pUnadvertised</var> asks.</p>
ClassMethod Resolve(pName As %String, Output pTool As %DynamicObject, pUnadvertised As %Boolean = 0) As %Status
{
    Set pTool = ""
    Set tArmed = $List(^||OcuPilotAllowListAgentSet, 1)
    If $ListGet(^||OcuPilotAllowListAgentSet, 2) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "OcuPilot.Test.AllowListAgentSet: the tool registry raised"))
    If tArmed = "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AllowListAgentSet: the tool registry cannot be read")
    If pName = tArmed Set pTool = {"name": (pName), "advertised": true}
    Quit $$$OK
}

}
