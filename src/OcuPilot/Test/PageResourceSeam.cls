/// <p><class>OcuPilot.Port.PortalResourcePort</class> with its gate and its vendor reads observable by a test: <method>DenyPair</method> answers
/// the gate as not holding one pair, and every vendor read made through the port (<method>Stored</method>, <method>Resolve</method>,
/// <method>Held</method>) is recorded in order (<method>Calls</method>) and then made as the port makes it. State lives in
/// <code>^||OcuPilotPageResourceSeam</code>; <method>Clear</method> forgets it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PageResourceSeam Extends OcuPilot.Port.PortalResourcePort
{

/// <p>Forget every denied pair and every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotPageResourceSeam
}

/// <p>Answer the gate as not holding <var>pPair</var>.</p>
ClassMethod DenyPair(pPair As %String)
{
    Set ^||OcuPilotPageResourceSeam("denied") = pPair
}

/// <p>Every vendor read made since <method>Clear</method>, oldest first, joined by <code>;</code>.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotPageResourceSeam("calls", tAt), 1, tCall)
        If tAt = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tCall
    }
    Quit tOut
}

/// <p>The gate's pair check, answering a denied pair as not held; the port's own check otherwise.</p>
ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Data(^||OcuPilotPageResourceSeam("denied")) Quit ($Get(^||OcuPilotPageResourceSeam("denied")) '= pPair)
    Quit ##super(pPair)
}

/// <p>The port's own listing, recorded.</p>
ClassMethod Stored(pMax As %Integer, Output pStored As %List) As %Status [ Private ]
{
    Set ^||OcuPilotPageResourceSeam("calls", $Increment(^||OcuPilotPageResourceSeam("calls"))) = "STORED"
    Quit ##super(pMax, .pStored)
}

/// <p>The port's own resolution, recorded.</p>
ClassMethod Resolve(pEncoded As %String, Output pNormalized As %String) As %Status [ Private ]
{
    Set ^||OcuPilotPageResourceSeam("calls", $Increment(^||OcuPilotPageResourceSeam("calls"))) = "RESOLVE"
    Quit ##super(pEncoded, .pNormalized)
}

/// <p>The port's own read of a page's resource, recorded.</p>
ClassMethod Held(pNormalized As %String, Output pResource As %String) As %Status [ Private ]
{
    Set ^||OcuPilotPageResourceSeam("calls", $Increment(^||OcuPilotPageResourceSeam("calls"))) = "HELD"
    Quit ##super(pNormalized, .pResource)
}

}
