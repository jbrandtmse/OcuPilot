/// <p><class>OcuPilot.Port.GlobalPort</class> with its node walk and node read replaced by ones that fail with an exception carrying a node's text, and its log line captured,
/// so <class>OcuPilot.Test.GlobalRead</class> shows that a failing page or node read logs the exception's name and no node text. Nothing else differs from the shipped
/// port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.GlobalSeamPort Extends OcuPilot.Port.GlobalPort
{

/// <p>The text a failing walk's exception carries, standing for a node's value.</p>
Parameter SECRET = "ZZSecretNodeValue";

/// <p>Forget the captured line.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotGlobalSeamLog
}

/// <p>The captured line: the message and the status's text, or <code>""</code>.</p>
ClassMethod Logged() As %String
{
    Quit $Get(^||OcuPilotGlobalSeamLog)
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotGlobalSeamLog = pMessage _ "|" _ $System.Status.GetErrorText(pStatus)
}

/// <p>A walk that fails, whatever it is asked.</p>
ClassMethod VendorWalk(pNamespace As %String, pName As %String, pFrom As %String, pAfter As %String, pSize As %Integer, Output pRaw, Output pMore As %Boolean, Output pCaught)
{
    Kill pRaw
    Set pRaw = 0
    Set pMore = 0
    Set pCaught = ##class(%Exception.General).%New("<UNDEFINED>", 5001, "", "node " _ ..#SECRET)
}

/// <p>A node read that fails, whatever it is asked.</p>
ClassMethod VendorNode(pNamespace As %String, pName As %String, pReference As %String, Output pNode, Output pCaught)
{
    Kill pNode
    Set pCaught = ##class(%Exception.General).%New("<UNDEFINED>", 5001, "", "node " _ ..#SECRET)
}

}
