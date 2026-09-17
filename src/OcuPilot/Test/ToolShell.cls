/// <p>The three shell read tools (AD-1, AD-36): each answers its handler's <code>Payload</code>
/// unchanged, conforms to its result schema, declares no pairs, and refuses any argument.</p>
/// <p><b>Live-safe</b>: the payloads read the instance and write nothing.</p>
Class OcuPilot.Test.ToolShell Extends %UnitTest.TestCase
{

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Shell reads -- each shell tool, called through the registry with <code>{}</code>, answers 200
/// and exactly the object its handler's payload builds, and that object conforms to the tool's result
/// schema.</p>
/// <p>Mutation: <class>OcuPilot.Screen.Tool.ShellNamespaces</class> drops <code>writable</code> from
/// the payload it answers -> this goes red.</p>
Method TestEachShellToolAnswersItsHandlersPayload()
{
    For tCase = "shell.instance.read|OcuPilot.Api.Instance", "shell.namespaces.read|OcuPilot.Api.Namespaces", "shell.privileges.read|OcuPilot.Api.Navigation" {
        Set tName = $Piece(tCase, "|", 1)
        Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "Resolve", tName, .tTool), tName _ ": the registry lists")
        Do $$$AssertTrue($IsObject(tTool), tName _ ": is registered")
        If '$IsObject(tTool) Continue
        Set tSC = $ClassMethod(..#REGISTRY, "InvokeTool", tTool, {}, 200, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tName _ ": answers")
        Do $$$AssertEquals(tHttp _ "|" _ $IsObject(tFault), "200|0", tName _ ": with 200 and no fault")
        If '$IsObject(tResult) Continue
        Do $$$AssertStatusOK($ClassMethod($Piece(tCase, "|", 2), "Payload", .tPayload), tName _ ": the handler's payload builds")
        Do $$$AssertEquals(tResult.%ToJSON(), $Select($IsObject(tPayload): tPayload.%ToJSON(), 1: ""), tName _ ": the tool answers the payload unchanged")
        Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ValidateArguments", $ClassMethod(..#REGISTRY, "ResultSchemaOf", tTool), tResult, .tProblem), tName _ ": conforms to its result schema " _ tProblem)
        Set tPairs = $ClassMethod(..#REGISTRY, "RequiredPairs", tTool, .tResolved)
        Do $$$AssertEquals(tResolved _ "|" _ $ListLength(tPairs), "1|0", tName _ ": declares no pairs beyond the router's gate")
    }
}

/// <p>A shell tool takes no arguments: any is refused 400 <code>TOOL.ARGUMENTS</code> and no payload
/// is built.</p>
Method TestAShellToolRefusesAnyArgument()
{
    For tName = "shell.instance.read", "shell.namespaces.read", "shell.privileges.read" {
        Do $ClassMethod(..#REGISTRY, "Resolve", tName, .tTool)
        If '$IsObject(tTool) Continue
        Set tSC = $ClassMethod(..#REGISTRY, "InvokeTool", tTool, {"namespace": "USER"}, 200, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tName _ ": an argument is refused")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "400|TOOL.ARGUMENTS", tName _ ": as TOOL.ARGUMENTS")
        Do $$$AssertEquals(tResult, "", tName _ ": with no result")
    }
}

}
