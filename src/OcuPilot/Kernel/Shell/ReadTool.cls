/// <p>The base of the three shell read tools (AD-1, AD-36): each answers one shell read's
/// <code>Payload</code> in this package, unchanged, in the calling process -- the object the
/// shell's own route answers. A payload writes nothing and reads no <code>%request</code>.</p>
/// <p>A shell read takes no arguments and declares no pairs of its own: what it reads is what the
/// router's gate already admits the caller to read over HTTP, and each payload evaluates its own
/// per-entry privileges in the calling process.</p>
Class OcuPilot.Kernel.Shell.ReadTool Extends OcuPilot.Screen.Tool.Base [ Abstract ]
{

Parameter KIND = "read";

/// <p>The closed empty schema: a shell read takes no arguments.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
}

/// <p>Declared: none (AD-3). A shell read takes no arguments at all.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The shell read payload this tool answers. Each shell tool names its own.</p>
ClassMethod Payload(Output pObject As %DynamicObject) As %Status [ Abstract ]
{
    Set pObject = ""
    Quit $$$OK
}

/// <p>Answer <method>Payload</method>'s object unchanged. <var>pArgs</var> must be empty; anything
/// else is 400 <code>TOOL.ARGUMENTS</code> and no payload is built. A payload that fails is 500
/// with the generic fault. <var>pDescriptor</var> and <var>pContextCap</var> are ignored: a shell
/// payload carries no rows.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tPayloadSC = ..Payload(.tObject)
        If $$$ISERR(tPayloadSC) || '$IsObject(tObject) {
            Set tSC = ..InternalRefusal($Classname() _ "'s payload failed: " _ $Select($$$ISERR(tPayloadSC): $System.Status.GetErrorText(tPayloadSC), 1: "no object"), .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = tObject
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the shell read tool failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
