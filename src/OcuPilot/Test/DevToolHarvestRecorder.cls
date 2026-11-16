/// <p><class>OcuPilot.Port.HarvestPort</class> that records each <method>Invoke</method>'s handler, method, pairs and
/// query in <code>^||OcuPilotDevToolRecorder</code> before it runs the call, so a test reads whether a body was
/// asked for and what it was sent, and, for a call that names a namespace, what that namespace's unit-test root held while
/// the call ran. After <method>SetDry</method> it answers an empty success and runs no body, so a test can lift the port's
/// document cap without a scan; after <method>SetAnswer</method> it answers that result.</p>
Class OcuPilot.Test.DevToolHarvestRecorder Extends OcuPilot.Port.HarvestPort
{

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDevToolRecorder
    Kill ^||OcuPilotDevToolRecorderDry
    Kill ^||OcuPilotDevToolRecorderAnswer
}

/// <p>Answer every later call an empty success, without running its body, until <method>Clear</method>.</p>
ClassMethod SetDry()
{
    Set ^||OcuPilotDevToolRecorderDry = 1
}

/// <p>Answer every later call <var>pJson</var>, a JSON object, as the body's result, without running its body, until
/// <method>Clear</method> (Story 24.5: a unit-test run is never started from a test).</p>
ClassMethod SetAnswer(pJson As %String)
{
    Set ^||OcuPilotDevToolRecorderAnswer = pJson
}

/// <p>How many calls were recorded since <method>Clear</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotDevToolRecorder)
}

/// <p>Recorded call <var>pIndex</var> (1-based) as <code>{handler, method, pairs, query}</code>, or <code>{}</code>;
/// <code>pairs</code> reads <code>resource:permission</code>, comma-separated.</p>
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
    Set tPairText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPairText = tPairText _ $Select(tI = 1: "", 1: ",") _ $List($List(pPairs, tI), 1) _ ":" _ $List($List(pPairs, tI), 2)
    }
    Do tCall.%Set("pairs", tPairText, "string")
    Do tCall.%Set("query", tQuery)
    Set tRootNamespace = $Get(pQuery("namespace"))
    If tRootNamespace '= "" Do tCall.%Set("root", $Get(^|tRootNamespace|UnitTestRoot), "string")
    Set tIndex = $Increment(^||OcuPilotDevToolRecorder)
    Set ^||OcuPilotDevToolRecorder(tIndex) = tCall.%ToJSON()
    If $Data(^||OcuPilotDevToolRecorderAnswer) {
        Set pResult = ##class(%DynamicObject).%FromJSON(^||OcuPilotDevToolRecorderAnswer)
        Set pHttpStatus = 200
        Set pFault = ""
        Set pConsole = []
        Quit $$$OK
    }
    If $Get(^||OcuPilotDevToolRecorderDry) {
        Set pResult = {"documents": [], "count": 0}
        Set pHttpStatus = 200
        Set pFault = ""
        Set pConsole = []
        Quit $$$OK
    }
    ; No test starts a unit-test run: a call of that body with no armed answer is refused here, before the body.
    If pHandler = "OcuPilot.Port.Harvest.UnitTestRun" {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, "OcuPilot.Test.DevToolHarvestRecorder: the unit-test body is never run from a test")
        Set pConsole = []
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DevToolHarvestRecorder: the unit-test body is never run from a test")
    }
    Quit ##super(pHandler, pMethod, pPairs, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pConsole, pArgs...)
}

}
