/// <p>Stories 11.9, 11.10 and 11.1 in process: the built-in prompt's seven screen statements, the tools each
/// kind of screen names (<method>OcuPilot.Screen.Context.ScreenTools</method>), the refusal of a
/// request that supplies a derived member (<method>OcuPilot.Api.Turn.ContextViolation</method>),
/// Home's empty route, and the two members <method>OcuPilot.Api.Turn.BoundedContext</method> adds on both payload
/// branches and inside the total bound (AD-11, AD-24).</p>
/// <p>Spawns nothing, writes no state and creates no principal, so it needs no arming variable. It
/// reads the compiled tool and screen registries, so it runs on an instance where OcuPilot is
/// compiled.</p>
Class OcuPilot.Test.ScreenGrounding Extends %UnitTest.TestCase
{

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The process list's tools, as the registry names them: its read, then the four write tools
/// behind its four row actions, in name order.</p>
Parameter PROCESSTOOLS = "[""osmgmt_processes_read"",""osmgmt_processes_resume"",""osmgmt_processes_suspend"",""osmgmt_processes_terminate"",""osmgmt_processes_terminatewitherror""]";

/// <p>The prompt's statement at <var>pIndex</var> (1 to 7), verbatim.</p>
ClassMethod Statement(pIndex As %Integer) As %String
{
    Quit $Case(pIndex,
        1: "A turn may open with a screen_context result describing the screen the user is viewing: its route, namespace and selected row (entity), the rows as shown with how many were available (rows, rowsSent, rowsAvailable, truncated), the tools that act on that screen (tools), and whether you are read-only (readOnly).",
        2: "When that context holds what was asked, answer from it without calling a tool; call a read tool when it does not, or when its rows were cut.",
        3: "A change confirmed through one of the screen's tools refreshes that screen and marks the changed row.",
        4: "When you are read-only, say so, and describe the change you would make instead of proposing it.",
        5: "Use only the tools you are offered, and when none of them can do what was asked, say so rather than describe a capability you lack.",
        6: "When the user asks about something a screen shows, or asks to change it, and the screen_context does not show them on that screen, open that screen with the navigation tool first, before you answer or propose the change, so they see what you are discussing and the change when it lands; when they are already on it, do not navigate.",
        7: "When the user asks you to explain this screen, say what the screen is for, what data it shows and what actions its tools offer, name the read tool in tools that its data comes from, or say that it has none, and propose no change.",
        : "")
}

/// <p>The tools <method>OcuPilot.Screen.Context.ScreenTools</method> names for the screen at
/// <var>pRoute</var>, as JSON text.</p>
Method ToolsFor(pRoute As %String) As %String
{
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(pRoute)
    Do $$$AssertTrue(tDescriptor '= "", pRoute _ " resolves to a descriptor")
    Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools(tDescriptor, .tTools)
    Do $$$AssertStatusOK(tSC, "the tools for " _ pRoute _ " are listed")
    Quit tTools.%ToJSON()
}

/// <p>The prompt is the class parameter, whole, and carries each of the seven screen statements
/// verbatim, one assertion each.</p>
Method TestThePromptCarriesTheScreenStatements()
{
    Set tPrompt = ##class(OcuPilot.Kernel.Agent.Prompt).Builtin()
    Do $$$AssertEquals(tPrompt, $Parameter("OcuPilot.Kernel.Agent.Prompt", "BUILTIN"), "Builtin() is the build-time constant, whole")
    Do $$$AssertTrue(tPrompt [ ..Statement(1), "the screen_context statement names its route, entity, rows, tools and readOnly")
    Do $$$AssertTrue(tPrompt [ ..Statement(2), "the answer-from-context statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(3), "the refresh-and-mark statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(4), "the read-only statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(5), "the only-the-tools-offered statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(6), "the open-the-screen-first statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(7), "the explain statement")
    Set tOutside = 0
    For tI = 1:1:$Length(tPrompt) If ($Ascii(tPrompt, tI) < 32) || ($Ascii(tPrompt, tI) > 126) Set tOutside = tOutside + 1
    Do $$$AssertEquals(tOutside, 0, "the prompt is printable ASCII throughout")
}

/// <p>A list with row actions names its read tool and the write tool behind each row action.</p>
Method TestAListWithRowActionsNamesItsReadAndActionTools()
{
    Do $$$AssertEquals(..ToolsFor("os-management/processes"), ..#PROCESSTOOLS, "the process list's read, then its four action tools in name order")
}

/// <p>A primary action names the tool that creates; a write tool bound to the screen that carries
/// none of its declared actions is not named.</p>
Method TestAPrimaryActionNamesItsCreateToolOnly()
{
    Set tTools = ..ToolsFor("os-management/devices")
    Do $$$AssertEquals(tTools, "[""osmgmt_devices_read"",""osmgmt_devices_create""]", "the device list's read and its create")
    Do $$$AssertTrue(tTools '[ "osmgmt_devices_update", "update is bound to the screen but behind no declared action")
    Do $$$AssertTrue(tTools '[ "osmgmt_devices_delete", "and so is delete")
}

/// <p>A detail screen whose row actions no tool of its own carries resolves them through its
/// <code>parentScope</code>.</p>
Method TestADetailScreenReachesItsActionsThroughItsParent()
{
    Set tExpected = "[""osmgmt_processdetails_read"",""osmgmt_processes_resume"",""osmgmt_processes_suspend"",""osmgmt_processes_terminate"",""osmgmt_processes_terminatewitherror""]"
    Do $$$AssertEquals(..ToolsFor("os-management/processes/details"), tExpected, "the detail's own read, then the list's four action tools")
}

/// <p>A form page declares no read, no action and no parent, so it names no tool; the identity-only
/// form page too.</p>
Method TestAFormPageNamesNoTool()
{
    Do $$$AssertEquals(..ToolsFor("os-management/devices/edit"), "[]", "the device form names none")
    Do $$$AssertEquals(..ToolsFor("security/wallet/secrets/edit"), "[]", "and neither does the wallet secret form")
}

/// <p>The application error list, whose read tool is a class of its own, names it and its
/// delete.</p>
Method TestTheErrorListNamesItsClassReadAndDelete()
{
    Do $$$AssertEquals(..ToolsFor("logs/errors"), "[""logs_applicationerrors_read"",""logs_applicationerrors_delete""]", "the error list's read and delete")
}

/// <p>A tool list that cannot be built fails <method>OcuPilot.Screen.Context.ScreenTools</method>
/// with that error and an empty list, never a silent <code>[]</code>.</p>
Method TestAToolListFailureReturnsItsError()
{
    Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/processes")
    Set tSC = ##class(OcuPilot.Test.ScreenToolsFault).ScreenTools(tDescriptor, .tTools)
    Do $$$AssertStatusNotOK(tSC, "the registry's failure is returned")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "ScreenToolsFault", "and it is that failure: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tTools.%ToJSON(), "[]", "with no tool named")
}

/// <p>A request that supplies <code>tools</code> or <code>readOnly</code>, of any type, is refused
/// <code>TURN.CONTEXT.INVALID</code>; the same context without them is accepted.</p>
Method TestARequestSupplyingADerivedMemberIsRefused()
{
    Set tCode = ##class(OcuPilot.Api.Error).#TURNCONTEXTINVALID
    Set tSound = {"context": {"route": "os-management/processes", "view": {"rows": [{"Pid": "1"}]}}}
    Do tSound.context.%Set("namespace", ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tSound, ..#LIMITS), "", "a context carrying neither member is accepted")
    For tMember = "tools", "readOnly" {
        For tType = "array", "string", "boolean", "null", "number", "object" {
            Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tSound.%ToJSON())
            If tType = "array" Do tBody.context.%Set(tMember, [])
            If tType = "object" Do tBody.context.%Set(tMember, {})
            If tType = "string" Do tBody.context.%Set(tMember, "x", "string")
            If tType = "boolean" Do tBody.context.%Set(tMember, 0, "boolean")
            If tType = "null" Do tBody.context.%Set(tMember, "", "null")
            If tType = "number" Do tBody.context.%Set(tMember, 1, "number")
            Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tBody, ..#LIMITS), tCode, tMember _ " as " _ tType _ " is refused")
        }
    }
}

/// <p>Home's route is <code>""</code>: a context carrying it is accepted while a route that is not a
/// string is refused, and its payload is Home's identity with no tool, no row and a boolean
/// <code>readOnly</code>.</p>
Method TestHomesEmptyRouteIsAccepted()
{
    Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tHome = {"context": {"route": ""}}
    Do tHome.context.%Set("namespace", tNamespace, "string")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tHome, ..#LIMITS), "", "Home's empty route is accepted")
    Set tNumber = {"context": {"route": 5}}
    Do tNumber.context.%Set("namespace", tNamespace, "string")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tNumber, ..#LIMITS), ##class(OcuPilot.Api.Error).#TURNCONTEXTINVALID, "a route that is not a string is refused")
    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tHome.context, 0, 200, ..#LIMITS, .tJson), "Home's payload builds")
    Do $$$AssertTrue(tJson '= "", "and is not empty")
    If tJson = "" Quit
    Set tPayload = ##class(%DynamicObject).%FromJSON(tJson)
    Do $$$AssertEquals(tPayload.screen _ "|" _ tPayload.route, "shell.home|", "Home's identity")
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), "[]", "naming no tool")
    Do $$$AssertEquals(tPayload.rowsSent, 0, "sending no row")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly"), "boolean", "and carrying readOnly as a boolean")
}

/// <p>Both members ride the rows branch and the identity-only branch, with <code>readOnly</code> a
/// JSON boolean following the argument; a form page carries them over no rows.</p>
Method TestBothMembersRideBothBranches()
{
    Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tList = {"route": "os-management/processes", "view": {"rows": [{"Pid": "7", "Routine": "x", "Secret": "dropped"}]}}
    Do tList.%Set("namespace", tNamespace, "string")
    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tList, 0, 200, ..#LIMITS, .tJson), "the list's payload builds")
    Set tPayload = ##class(%DynamicObject).%FromJSON(tJson)
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), ..#PROCESSTOOLS, "the rows branch carries the screen's tools")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly") _ "|" _ tPayload.readOnly, "boolean|0", "and readOnly false, as a boolean")
    Do $$$AssertEquals(tPayload.rowsSent, 1, "beside its one row")
    Do $$$AssertEquals(tPayload.rows.%Get(0).%IsDefined("Secret"), 0, "narrowed to the declared fields")

    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tList, 1, 200, ..#LIMITS, .tBlockedJson), "the same payload, blocked")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBlockedJson).readOnly, 1, "readOnly follows the verdict it is given")

    Set tSecret = {"route": "security/wallet/secrets/edit", "entity": "probe"}
    Do tSecret.%Set("namespace", tNamespace, "string")
    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tSecret, 1, 200, ..#LIMITS, .tSecretJson), "the identity-only payload builds")
    Set tSecretPayload = ##class(%DynamicObject).%FromJSON(tSecretJson)
    Do $$$AssertEquals(tSecretPayload.%GetTypeOf("rows"), "unassigned", "the identity-only branch carries no rows")
    Do $$$AssertEquals(tSecretPayload.rowsSent, 0, "reports rowsSent 0")
    Do $$$AssertEquals(tSecretPayload.tools.%ToJSON(), "[]", "carries its empty tool list")
    Do $$$AssertEquals(tSecretPayload.%GetTypeOf("readOnly") _ "|" _ tSecretPayload.readOnly, "boolean|1", "and readOnly")

    Set tForm = {"route": "os-management/devices/edit"}
    Do tForm.%Set("namespace", tNamespace, "string")
    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tForm, 0, 200, ..#LIMITS, .tFormJson), "the form page's payload builds")
    Set tFormPayload = ##class(%DynamicObject).%FromJSON(tFormJson)
    Do $$$AssertEquals(tFormPayload.rows.%Size() _ "|" _ tFormPayload.rowsSent, "0|0", "a form page sends no row")
    Do $$$AssertEquals(tFormPayload.tools.%ToJSON() _ "|" _ tFormPayload.%GetTypeOf("readOnly"), "[]|boolean", "and carries both members")

    Set tUnknown = {"route": "no/such/screen"}
    Do tUnknown.%Set("namespace", tNamespace, "string")
    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tUnknown, 0, 200, ..#LIMITS, .tUnknownJson), "an unknown route answers")
    Do $$$AssertEquals(tUnknownJson, "", "with no payload, and so no members")
}

/// <p>Rows that overfill the budget are cut by whole rows with both members inside it: each row is
/// shorter than the two members, so the slack a whole-row cut leaves cannot hold them, and adding
/// them after the cut would overrun 65,536 characters.</p>
Method TestTheMembersCountWithinTheTotalBound()
{
    Set tContext = {"route": "os-management/processes", "view": {"rows": []}}
    Do tContext.%Set("namespace", ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Set tRoutine = $Translate($Justify("", 80), " ", "r")
    For tI = 1:1:1000 {
        Do tContext.view.rows.%Push({"Pid": (tI _ ""), "Routine": (tRoutine)})
    }
    Set tRowLength = $Length({"Pid": "1000", "Routine": (tRoutine)}.%ToJSON()) + 1
    Set tMembersLength = $Length(",""tools"":" _ ..#PROCESSTOOLS _ ",""readOnly"":false")
    Do $$$AssertTrue(tRowLength < tMembersLength, "each row (" _ tRowLength _ ") is shorter than the members (" _ tMembersLength _ ")")

    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tContext, 0, 1000, ..#LIMITS, .tJson), "the payload builds")
    Do $$$AssertTrue(tJson '= "", "and fits")
    Do $$$AssertTrue($Length(tJson) <= 65536, "the JSON is at most 65,536 characters: " _ $Length(tJson))
    Set tPayload = ##class(%DynamicObject).%FromJSON(tJson)
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), ..#PROCESSTOOLS, "the tools are kept")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly"), "boolean", "and so is readOnly")
    Do $$$AssertTrue((tPayload.rowsSent > 0) && (tPayload.rowsSent < 1000), "whole rows were cut: " _ tPayload.rowsSent)
    Do $$$AssertEquals(tPayload.rows.%Size(), tPayload.rowsSent, "rowsSent counts the rows kept")
    Do $$$AssertEquals(tPayload.truncated, 1, "and the payload is marked truncated")
}

}
