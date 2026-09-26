/// <p>Fixture: a read tool whose body records <code>$USERNAME</code> and <code>$ROLES</code> at the
/// instant it runs, then makes one real <class>OcuPilot.Port.AdminPort</class> call through
/// <class>OcuPilot.Test.AsTheUserProbe.Port</class>, which records the same two inside the port's
/// own frame (Story 5.4, AC1 and AC4).</p>
/// <p>The snapshot is taken in this method, not in a helper: <code>New $ROLES</code> unwinds with
/// the method frame, so a snapshot one frame out would be a snapshot of the wrong frame.</p>
Class OcuPilot.Test.AsTheUserProbe.Tool Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "probe.astheuser.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "A fixture read tool that records the identity and roles its body runs under.";

/// <p>The endpoint the port leg calls, and its request type. A list that changes nothing.</p>
Parameter PORTENDPOINT = "WebApp.App";

Parameter PORTTYPE = "LIST";

ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Quit ""
}

ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Quit ""
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "port": {"type": "integer", "minimum": 0, "maximum": 1, "description": "1 makes the body also call a port."}
        },
        "additionalProperties": false
    }
}

ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "user": {"type": "string", "description": "The identity the body observed."},
            "portCalled": {"type": "boolean", "description": "Whether the body reached a port."}
        },
        "additionalProperties": false
    }
}

ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pFault = ""
    Set pHttpStatus = 200
    Do ##class(OcuPilot.Test.AsTheUserProbe).Record("tool")
    Set tPortCalled = 0
    If $IsObject(pArgs) && (+pArgs.%Get("port") = 1) {
        Kill tQuery
        Do ##class(OcuPilot.Test.AsTheUserProbe.Port).Invoke(..#PORTENDPOINT, ..#PORTTYPE, .tQuery, "", .tRows, .tPortHttp, .tPortFault)
        Set tPortCalled = 1
    }
    Set pResult = {}
    Do pResult.%Set("user", $Username, "string")
    Do pResult.%Set("portCalled", ''tPortCalled, "boolean")
    Quit $$$OK
}

}
