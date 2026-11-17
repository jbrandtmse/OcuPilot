/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass with one replaced seam: while armed,
/// <method>RegistryClass</method> names this class, whose <method>Resolve</method> answers the tool a test names as one the
/// agent can reach, with the class the shipped registry gives it, so the person-only arm reads the tool's own
/// <code>PERSONGATE</code> (Story 24.5). Disarmed, the shipped registry answers and every predicate is the shipped code.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. The arming lives in a
/// process-private global, so nothing outlives the test process.</p>
Class OcuPilot.Test.UnitTestPersonOnlySet Extends OcuPilot.Kernel.Proposal.Prohibited
{

/// <p>Answer <var>pName</var> as an advertised tool of class <var>pClass</var> until <method>Disarm</method>.</p>
ClassMethod Arm(pName As %String, pClass As %String)
{
    Set ^||OcuPilotUnitTestPersonOnlySet = $ListBuild(pName, pClass)
}

ClassMethod Disarm()
{
    Kill ^||OcuPilotUnitTestPersonOnlySet
}

ClassMethod RegistryClass() As %String
{
    If $Data(^||OcuPilotUnitTestPersonOnlySet) Quit $ClassName()
    Quit ##super()
}

/// <p>The registry's resolve: the armed name resolves to an advertised entry carrying its class, any other name to none.</p>
ClassMethod Resolve(pName As %String, Output pTool As %DynamicObject, pUnadvertised As %Boolean = 0) As %Status
{
    Set pTool = ""
    If pName = $List(^||OcuPilotUnitTestPersonOnlySet, 1) Set pTool = {"name": (pName), "class": ($List(^||OcuPilotUnitTestPersonOnlySet, 2)), "advertised": true}
    Quit $$$OK
}

}
