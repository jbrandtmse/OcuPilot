/// <p>Test-only <class>OcuPilot.Screen.Tool.ErrorRead</class> subclass that is its own port: its
/// <method>Errors</method> records the arguments the tool passes and answers armed rows or an armed
/// fault, so the tool's clamp and its fault pass-through are observed without the instance's error
/// log. Nothing of the tool itself is replaced.</p>
/// <p>State lives in <code>^||OcuPilotErrorReadStub</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.ErrorReadStub Extends OcuPilot.Screen.Tool.ErrorRead
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ErrorReadStub"
}

ClassMethod Clear()
{
    Kill ^||OcuPilotErrorReadStub
}

/// <p>Answer the port with an error carrying <var>pHttpStatus</var> and the fault
/// <code>{error, reason, code}</code>, plus <var>pDetailJson</var> as <code>detail</code>.</p>
ClassMethod ArmFault(pHttpStatus As %Integer, pCode As %String, pDetailJson As %String = "")
{
    Set ^||OcuPilotErrorReadStub("fault") = $ListBuild(pHttpStatus, pCode, pDetailJson)
}

/// <p>Answer the port's own <code>truncated</code> as <b>false</b> from now on, so a
/// <code>truncated</code> a caller then reads can only have come from
/// <method>OcuPilot.Screen.Tool.ErrorRead.View</method>'s own context-cap branch. The default is
/// true, which is what every other caller of this stub already relies on.</p>
ClassMethod ArmUntruncated()
{
    Set ^||OcuPilotErrorReadStub("untruncated") = 1
}

/// <p>What the last port call was given under <var>pField</var>: <code>level</code>,
/// <code>namespace</code>, <code>date</code> or <code>maxRows</code>.</p>
ClassMethod Recorded(pField As %String) As %String
{
    Quit $Get(^||OcuPilotErrorReadStub("last", pField))
}

/// <p>The stub port: three summary rows, truncated unless <method>ArmUntruncated</method> was
/// called, or the armed fault. <var>pMaxRows</var> is recorded and never applied -- the three rows
/// are what makes a caller's own cap observable.</p>
ClassMethod Errors(pLevel As %String = "", pNamespace As %String = "", pDate As %String = "", pErrorNumber As %String = "", pMaxRows As %String = "", Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pFault = ""
    Set ^||OcuPilotErrorReadStub("last", "level") = pLevel
    Set ^||OcuPilotErrorReadStub("last", "namespace") = pNamespace
    Set ^||OcuPilotErrorReadStub("last", "date") = pDate
    Set ^||OcuPilotErrorReadStub("last", "maxRows") = pMaxRows
    Set tFault = $Get(^||OcuPilotErrorReadStub("fault"))
    If tFault '= "" {
        Set pHttpStatus = $List(tFault, 1)
        Set pFault = {"error": "forbidden", "reason": "This account may not read that log source"}
        Do pFault.%Set("code", $List(tFault, 2), "string")
        If $List(tFault, 3) '= "" Do pFault.%Set("detail", ##class(%DynamicAbstractObject).%FromJSON($List(tFault, 3)))
        Quit $$$ERROR($$$GeneralError, "the stub port's fault")
    }
    Set pResult = {"rows": []}
    Do pResult.%Set("truncated", '$Get(^||OcuPilotErrorReadStub("untruncated"), 0), "boolean")
    For tI = 1:1:3 {
        Do pResult.rows.%Push({"errorNumber": (tI), "time": "10:00:00", "errorText": "<UNDEFINED>", "routine": "X", "line": "X+1", "username": "u", "process": 1})
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

}
