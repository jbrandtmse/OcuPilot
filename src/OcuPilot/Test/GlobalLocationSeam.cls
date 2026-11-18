/// <p><class>OcuPilot.Port.GlobalPort</class> whose vendor reads answer what a test armed (<method>Arm</method>) instead of where the instance stores a global,
/// so <class>OcuPilot.Test.GlobalWrite</class> drives the kernel's globals arm over every directory without writing a protected global. Nothing else differs
/// from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.GlobalLocationSeam Extends OcuPilot.Port.GlobalPort
{

/// <p>Answer <var>pLocations</var>, a <code>%List</code> of directories, for every global and node read, or fail the read with <var>pFail</var> 1.</p>
ClassMethod Arm(pLocations As %List, pFail As %Boolean = 0)
{
    Set ^||OcuPilotGlobalLocations = pLocations
    Set ^||OcuPilotGlobalLocationsFail = pFail
}

/// <p>Forget what was armed.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotGlobalLocations
    Kill ^||OcuPilotGlobalLocationsFail
}

ClassMethod VendorLocations(pNamespace As %String, pName As %String, Output pLocations As %List, Output pDefined As %Boolean, Output pCaught)
{
    Set pLocations = $Get(^||OcuPilotGlobalLocations)
    Set pDefined = 1
    Set pCaught = $Select($Get(^||OcuPilotGlobalLocationsFail): ##class(%Exception.General).%New("<FUNCTION>", 1), 1: "")
}

ClassMethod VendorNode(pNamespace As %String, pName As %String, pReference As %String, Output pNode, Output pCaught)
{
    Kill pNode
    Set pNode("data") = 1
    Set pNode("value") = "x"
    Set pNode("display") = "x"
    Set pNode("length") = 1
    Set pNode("format") = 1
    Set pNode("control") = 0
    Set pNode("location") = $ListGet($Get(^||OcuPilotGlobalLocations), 1)
    Set pCaught = $Select($Get(^||OcuPilotGlobalLocationsFail): ##class(%Exception.General).%New("<FUNCTION>", 1), 1: "")
}

}
