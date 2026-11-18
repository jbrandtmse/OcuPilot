/// <p><class>OcuPilot.Port.GlobalPort</class> whose replace, once armed (<method>Arm</method>), sets the last node its walk recorded to the armed value just
/// before the transaction, so <class>OcuPilot.Test.GlobalReplace</class> drives a node that moves between the walk and the write through
/// <method>Invoke</method>. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.GlobalReplaceMoveSeam Extends OcuPilot.Port.GlobalPort
{

/// <p>Move the last recorded node to <var>pValue</var> at the next replace.</p>
ClassMethod Arm(pValue As %String)
{
    Set ^||OcuPilotGlobalReplaceMove = pValue
}

/// <p>Forget what was armed.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotGlobalReplaceMove
}

ClassMethod VendorReplaceApply(pNamespace As %String, Output pStale As %Boolean, Output pCaught)
{
    Set tLast = $Order(^||OcuPilotGlobalReplace(""), -1)
    If ($Data(^||OcuPilotGlobalReplaceMove) # 2) && (tLast '= "") {
        Set tOrigNS = $NAMESPACE
        Set $NAMESPACE = pNamespace
        Set tNode = $List(^||OcuPilotGlobalReplace(tLast), 1)
        Set @tNode = ^||OcuPilotGlobalReplaceMove
        Set $NAMESPACE = tOrigNS
    }
    Do ##super(pNamespace, .pStale, .pCaught)
}

}
