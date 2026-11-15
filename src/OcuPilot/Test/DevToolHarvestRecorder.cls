/// <p><class>OcuPilot.Port.HarvestPort</class> that records each <method>Invoke</method>'s handler, method and
/// query in <code>^||OcuPilotDevToolRecorder</code> before it runs the call, so a test reads whether a body was
/// asked for and what it was sent. After <method>SetDry</method> it answers an empty success and runs no body, so a
/// test can lift the port's document cap without a scan.</p>
Class OcuPilot.Test.DevToolHarvestRecorder Extends OcuPilot.Port.HarvestPort
{

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDevToolRecorder
    Kill ^||OcuPilotDevToolRecorderDry
}

/// <p>Answer every later call an empty success, without running its body, until <method>Clear</method>.</p>
ClassMethod SetDry()
{
    Set ^||OcuPilotDevToolRecorderDry = 1
}

/// <p>How many calls were recorded since <method>Clear</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotDevToolRecorder)
}

/// <p>Recorded call <var>pIndex</var> (1-based) as <code>{handler, method, query}</code>, or <code>{}</code>.</p>
ClassMethod CallAt(pIndex As %Integer) As %DynamicObject
{
    Set tJson = $Get(^||OcuPilotDevToolRecorder(pIndex))
    If tJson = "" Quit {}
    Quit ##class(%DynamicObject).%FromJSON(tJson)
}

ClassMethod Invoke(pHandler As %String, pMethod As %String, pPairs As %List, ByRef pQuery, pBody = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pConsole As %DynamicArray, pArgs...) As %Status
{
    Set tQuery = {}
    Set tKey = ""
    For {
        Set tKey = $Order(pQuery(tKey))
        If tKey = "" Quit
        Do tQuery.%Set(tKey, pQuery(tKey), "string")
    }
    Set tCall = {}
    Do tCall.%Set("handler", pHandler, "string")
    Do tCall.%Set("method", pMethod, "string")
    Do tCall.%Set("query", tQuery)
    Set tIndex = $Increment(^||OcuPilotDevToolRecorder)
    Set ^||OcuPilotDevToolRecorder(tIndex) = tCall.%ToJSON()
    If $Get(^||OcuPilotDevToolRecorderDry) {
        Set pResult = {"documents": [], "count": 0}
        Set pHttpStatus = 200
        Set pFault = ""
        Set pConsole = []
        Quit $$$OK
    }
    Quit ##super(pHandler, pMethod, pPairs, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pConsole, pArgs...)
}

}
