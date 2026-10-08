/// <p>Stories 11.9, 11.10, 11.1, 11.2 and 20.18 in process: the built-in prompt's nine screen statements, the tools each
/// kind of screen names (<method>OcuPilot.Screen.Context.ScreenTools</method>), the refusal of a
/// request that supplies a derived member (<method>OcuPilot.Api.Turn.ContextViolation</method>),
/// Home's empty route, the error read tool's input schema, the four members <method>OcuPilot.Api.Turn.BoundedContext</method> adds on both payload
/// branches and inside the total bound, and the explain-entry marker it carries, drops when invalid
/// and keeps within the bounds (AD-11, AD-24).</p>
/// <p>Spawns nothing, writes no state and creates no principal, so it needs no arming variable. It
/// reads the compiled tool and screen registries, so it runs on an instance where OcuPilot is
/// compiled.</p>
Class OcuPilot.Test.ScreenGrounding Extends %UnitTest.TestCase
{

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The process list's tools, as the registry names them: its read, then the five write tools
/// behind its five row actions, in name order.</p>
Parameter PROCESSTOOLS = "[""osmgmt_processes_read"",""osmgmt_processes_broadcast"",""osmgmt_processes_resume"",""osmgmt_processes_suspend"",""osmgmt_processes_terminate"",""osmgmt_processes_terminatewitherror""]";

/// <p>The prompt's statement at <var>pIndex</var> (1 to 9), verbatim.</p>
ClassMethod Statement(pIndex As %Integer) As %String
{
    Quit $Case(pIndex,
        1: "A turn may open with a screen_context result describing the screen the user is viewing: its route, namespace and selected row (entity), the rows as shown with how many were available (rows, rowsSent, rowsAvailable, truncated), the tools that act on that screen (tools), whether you are read-only (readOnly), whether the user can open that screen and, if not, the permission they lack (verdict), and which of its tools the user cannot use, with the permission each lacks (unavailable).",
        2: "When that context holds what was asked, answer from it without calling a tool; call a read tool when it does not, or when its rows were cut.",
        3: "A change confirmed through one of the screen's tools refreshes that screen and marks the changed row.",
        4: "When you are read-only, say so, and describe the change you would make instead of proposing it.",
        5: "Use only the tools you are offered, and when none of them can do what was asked, say so rather than describe a capability you lack.",
        6: "When the user asks about something a screen shows, or asks to change it, and the screen_context does not show them on that screen, open that screen with the navigation tool first, before you answer or propose the change, so they see what you are discussing and the change when it lands; when they are already on it, do not navigate.",
        7: "When the user asks you to explain this screen, say what the screen is for, what data it shows and what actions its tools offer, name the read tool in tools that its data comes from, or say that it has none, and propose no change.",
        8: "When the user asks you to explain the selected entry, screen_context marks the entry they chose: selected is its index in rows, the first row being 0, or focus holds it when rows does not; that marker, not entity, names the entry, and the other rows are the rest of the screen, context for that entry. Explain that one entry: what it records, what likely caused it and what to check next, and propose no change.",
        9: "When a tool answers AUTH.NOPRIVILEGE, it names the permission the user lacks (failedPair) and, when the user cannot open that tool's screen, the screen (screen): say that the user cannot access that screen and which permission they would need, propose nothing on it, and do not call it again; do not call a tool that unavailable names, and say which permission it needs instead.",
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

/// <p>The prompt is the class parameter, whole, and carries each of the nine screen statements
/// verbatim, one assertion each.</p>
Method TestThePromptCarriesTheScreenStatements()
{
    Set tPrompt = ##class(OcuPilot.Kernel.Agent.Prompt).Builtin()
    Do $$$AssertEquals(tPrompt, $Parameter("OcuPilot.Kernel.Agent.Prompt", "BUILTIN"), "Builtin() is the build-time constant, whole")
    Do $$$AssertTrue(tPrompt [ ..Statement(1), "the screen_context statement names its route, entity, rows, tools, readOnly, verdict and unavailable")
    Do $$$AssertTrue(tPrompt [ ..Statement(2), "the answer-from-context statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(3), "the refresh-and-mark statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(4), "the read-only statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(5), "the only-the-tools-offered statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(6), "the open-the-screen-first statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(7), "the explain statement")
    Do $$$AssertTrue(tPrompt [ ..Statement(8), "the explain-entry statement, which says what the marker means")
    Do $$$AssertTrue(tPrompt [ ..Statement(9), "the AUTH.NOPRIVILEGE statement, which names failedPair and screen")
    Set tOutside = 0
    For tI = 1:1:$Length(tPrompt) If ($Ascii(tPrompt, tI) < 32) || ($Ascii(tPrompt, tI) > 126) Set tOutside = tOutside + 1
    Do $$$AssertEquals(tOutside, 0, "the prompt is printable ASCII throughout")
}

/// <p>A list with row actions names its read tool and the write tool behind each row action.</p>
Method TestAListWithRowActionsNamesItsReadAndActionTools()
{
    Do $$$AssertEquals(..ToolsFor("os-management/processes"), ..#PROCESSTOOLS, "the process list's read, then its five action tools in name order")
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

/// <p>The error list's read tool, resolved by name through the tool registry, takes exactly the
/// namespace, the date and <code>maxRows</code> and refuses any other argument, so no caller can
/// ask it for an entry's captured detail (AD-48).</p>
Method TestTheErrorReadToolTakesNoDetailArgument()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("logs.applicationerrors.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the tool list is built")
    Do $$$AssertTrue($IsObject(tTool), "logs.applicationerrors.read is registered")
    If '$IsObject(tTool) Quit
    Set tSchema = ##class(OcuPilot.Screen.Tool.Registry).InputSchemaOf(tTool)
    Set tNames = ""
    Set tIterator = tSchema.properties.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tNames = tNames _ $ListBuild(tName)
    }
    Do $$$AssertEquals($ListToString(tNames), "namespace,date,maxRows", "its input properties are the namespace, the date and maxRows alone")
    Do $$$AssertEquals(tSchema.%GetTypeOf("additionalProperties") _ "|" _ tSchema.additionalProperties, "boolean|0", "and any other argument is refused")
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

/// <p>A request that supplies <code>tools</code>, <code>readOnly</code>, <code>verdict</code> or <code>unavailable</code>, of any type, is refused
/// <code>TURN.CONTEXT.INVALID</code>; the same context without them is accepted.</p>
Method TestARequestSupplyingADerivedMemberIsRefused()
{
    Set tCode = ##class(OcuPilot.Api.Error).#TURNCONTEXTINVALID
    Set tSound = {"context": {"route": "os-management/processes", "view": {"rows": [{"Pid": "1"}]}}}
    Do tSound.context.%Set("namespace", ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tSound, ..#LIMITS), "", "a context carrying neither member is accepted")
    For tMember = "tools", "readOnly", "verdict", "unavailable" {
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
/// <code>readOnly</code>. The namespace and view checks still apply on Home's route, and a row sent
/// with it reaches the payload narrowed to Home's context fields, the performance row's five
/// values.</p>
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
    Do $$$AssertEquals(tPayload.verdict.%ToJSON() _ "|" _ tPayload.unavailable.%ToJSON(), "{""allowed"":true}|{}", "Home is allowed and marks no tool unavailable")
    Do $$$AssertEquals(tPayload.rowsSent, 0, "sending no row")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly"), "boolean", "and carrying readOnly as a boolean")
    Set tForeign = {"context": {"route": "", "namespace": "OCUPILOTNOSUCHNAMESPACE"}}
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tForeign, ..#LIMITS), ##class(OcuPilot.Api.Error).#TURNCONTEXTINVALID, "Home in another namespace is refused")
    Set tBadRows = {"context": {"route": "", "view": {"rows": {}}}}
    Do tBadRows.context.%Set("namespace", tNamespace, "string")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tBadRows, ..#LIMITS), ##class(OcuPilot.Api.Error).#TURNCONTEXTINVALID, "Home with rows that are not an array is refused")
    Set tRowed = {"context": {"route": "", "view": {"rows": [{"Pid": "homeprobevalue", "globalReferencesPerSecond": 4711}]}}}
    Do tRowed.context.%Set("namespace", tNamespace, "string")
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation(tRowed, ..#LIMITS), "", "Home with a well-formed view passes the shape check")
    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tRowed.context, 0, 200, ..#LIMITS, .tRowedJson), "Home's payload with a row builds")
    Do $$$AssertTrue(tRowedJson '= "", "and is not empty")
    Do $$$AssertTrue('(tRowedJson [ "homeprobevalue"), "and carries no value of a field Home does not declare")
    Do $$$AssertTrue(tRowedJson [ """globalReferencesPerSecond"":4711", "while a declared field's value reaches it")
}

/// <p>The members ride the rows branch and the identity-only branch, with <code>readOnly</code> a
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
    Do $$$AssertEquals(tPayload.%GetTypeOf("verdict") _ "|" _ tPayload.verdict.allowed _ "|" _ tPayload.%GetTypeOf("unavailable"), "object|1|object", "and the screen's verdict and an unavailable map")
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
    Set tMembersLength = $Length(",""tools"":" _ ..#PROCESSTOOLS _ ",""readOnly"":false,""verdict"":{""allowed"":true},""unavailable"":{}")
    Do $$$AssertTrue(tRowLength < tMembersLength, "each row (" _ tRowLength _ ") is shorter than the members (" _ tMembersLength _ ")")

    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(tContext, 0, 1000, ..#LIMITS, .tJson), "the payload builds")
    Do $$$AssertTrue(tJson '= "", "and fits")
    Do $$$AssertTrue($Length(tJson) <= 65536, "the JSON is at most 65,536 characters: " _ $Length(tJson))
    Set tPayload = ##class(%DynamicObject).%FromJSON(tJson)
    Do $$$AssertEquals(tPayload.tools.%ToJSON(), ..#PROCESSTOOLS, "the tools are kept")
    Do $$$AssertEquals(tPayload.%GetTypeOf("readOnly"), "boolean", "and so is readOnly")
    Do $$$AssertEquals(tPayload.%GetTypeOf("verdict") _ "|" _ tPayload.%GetTypeOf("unavailable"), "object|object", "and so are verdict and unavailable")
    Do $$$AssertTrue((tPayload.rowsSent > 0) && (tPayload.rowsSent < 1000), "whole rows were cut: " _ tPayload.rowsSent)
    Do $$$AssertEquals(tPayload.rows.%Size(), tPayload.rowsSent, "rowsSent counts the rows kept")
    Do $$$AssertEquals(tPayload.truncated, 1, "and the payload is marked truncated")
}

/// <p>A messages.log context of three rows, with <var>pMarker</var>'s members set on its view.</p>
ClassMethod MessagesContext(pMarker As %DynamicObject = "") As %DynamicObject
{
    Set tContext = {"route": "logs/messages", "view": {"sort": "", "direction": "", "filter": "", "rowsAvailable": 3, "rows": [{"time": "2026-09-29T10:00:02.000", "severity": "2", "text": "third"}, {"time": "2026-09-29T10:00:01.000", "severity": "1", "text": "the chosen entry"}, {"time": "2026-09-29T10:00:00.000", "severity": "0", "text": "first"}]}}
    Do tContext.%Set("namespace", ##class(OcuPilot.Kernel.Scope).Current(), "string")
    If $IsObject(pMarker) {
        Set tIterator = pMarker.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue, .tType) {
            If (tType = "object") || (tType = "array") {
                Do tContext.view.%Set(tKey, tValue)
            } Else {
                Do tContext.view.%Set(tKey, tValue, tType)
            }
        }
    }
    Quit tContext
}

/// <p><var>pContext</var>'s bounded payload under a row cap of <var>pRowCap</var>, parsed, or
/// <code>""</code> when none was built.</p>
Method Bounded(pContext As %DynamicObject, pRowCap As %Integer = 200) As %DynamicObject
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Turn).ContextViolation({"context": (pContext)}, ..#LIMITS), "", "the context passes the shape check")
    Do $$$AssertStatusOK(##class(OcuPilot.Api.Turn).BoundedContext(pContext, 0, pRowCap, ..#LIMITS, .tJson), "the payload builds")
    Do $$$AssertTrue(tJson '= "", "and is not empty")
    If tJson = "" Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tJson)
}

/// <p>An explain turn's <code>selected</code> reaches the payload beside every row of the screen,
/// the first row's index 0 among them; its <code>focus</code> reaches it narrowed to the declared
/// fields, an object or array value dropped and reported; and an ordinary turn's payload carries
/// neither.</p>
/// <p>Mutation: drop the marker projection from <method>OcuPilot.Screen.Context.Build</method> --
/// this goes red; raise the lower bound on <code>selected</code> to 1 -- the first row's case goes
/// red.</p>
Method TestAnEntryMarkerRidesBesideTheScreensRows()
{
    Set tPayload = ..Bounded(..MessagesContext({"selected": 1}))
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.rowsSent _ "|" _ tPayload.rows.%Size(), "3|3", "every row of the screen is sent")
    Do $$$AssertEquals(tPayload.%GetTypeOf("selected") _ "|" _ tPayload.selected, "number|1", "with the chosen entry's index")
    Do $$$AssertEquals(tPayload.rows.%Get(1).text, "the chosen entry", "which names the chosen row")
    Do $$$AssertEquals(tPayload.%GetTypeOf("focus"), "unassigned", "and no focus row")

    Set tPayload = ..Bounded(..MessagesContext({"selected": 0}))
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.%GetTypeOf("selected") _ "|" _ tPayload.selected, "number|0", "the first row's index is kept")

    Set tFocus = {"time": "2026-09-29T09:00:00.000", "severity": "2", "text": "an older entry", "pid": "4711"}
    Set tPayload = ..Bounded(..MessagesContext({"focus": (tFocus)}))
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.rowsSent, 3, "the screen's rows are still sent")
    Do $$$AssertEquals(tPayload.%GetTypeOf("focus"), "object", "beside the focus row")
    Do $$$AssertEquals(tPayload.focus.text, "an older entry", "which is the chosen entry")
    Do $$$AssertEquals(tPayload.focus.%IsDefined("pid"), 0, "narrowed to the declared fields")
    Do $$$AssertEquals(tPayload.%GetTypeOf("selected"), "unassigned", "and no index")

    Set tPayload = ..Bounded(..MessagesContext({"focus": {"time": "t", "severity": ["2"], "text": "nested"}}))
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.focus.%IsDefined("severity") _ "|" _ tPayload.truncatedFields.%ToJSON(), "0|[""severity""]", "a focus value that is an array is dropped and reported")

    Set tPayload = ..Bounded(..MessagesContext())
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.%GetTypeOf("selected") _ "|" _ tPayload.%GetTypeOf("focus"), "unassigned|unassigned", "an ordinary turn carries neither marker")
}

/// <p>A marker of the wrong shape is dropped and the turn's payload is built without it: an index
/// out of range, negative, fractional, sent as a string or too large to read, a focus that is not
/// an object or holds a number too large to read, and both markers sent together. None is refused,
/// and a screen declaring secret fields carries no marker.</p>
/// <p>Mutation: drop the range check on <code>selected</code> in
/// <method>OcuPilot.Screen.Context.Build</method> -- the out-of-range case goes red; drop the
/// <code>Try</code> around the marker read -- the two unreadable cases go red.</p>
Method TestAnInvalidMarkerIsDroppedNotRefused()
{
    Set tCases = [{"selected": 3}, {"selected": -1}, {"selected": 1.5}, {"selected": "1"}, {"focus": "the chosen entry"}, {"focus": [{"text": "x"}]}, {"selected": 1, "focus": {"text": "x"}}]
    Set tIterator = tCases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMarker) {
        Set tLabel = tMarker.%ToJSON()
        Set tPayload = ..Bounded(..MessagesContext(tMarker))
        If '$IsObject(tPayload) Continue
        Do $$$AssertEquals(tPayload.%GetTypeOf("selected") _ "|" _ tPayload.%GetTypeOf("focus"), "unassigned|unassigned", tLabel _ " is dropped")
        Do $$$AssertEquals(tPayload.rowsSent, 3, tLabel _ ": the rows are still sent")
    }
    For tMarkerJson = """selected"":1e400", """focus"":{""time"":""t"",""text"":1e400}" {
        Set tJson = $Replace(..MessagesContext().%ToJSON(), """rowsAvailable"":3", """rowsAvailable"":3," _ tMarkerJson)
        Set tPayload = ..Bounded(##class(%DynamicObject).%FromJSON(tJson))
        If '$IsObject(tPayload) Continue
        Do $$$AssertEquals(tPayload.%GetTypeOf("selected") _ "|" _ tPayload.%GetTypeOf("focus") _ "|" _ tPayload.rowsSent, "unassigned|unassigned|3", tMarkerJson _ " is dropped")
    }
    Set tSecret = {"route": "security/wallet/secrets/edit", "view": {"rows": [], "focus": {"Name": "x"}}}
    Do tSecret.%Set("namespace", ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Set tPayload = ..Bounded(tSecret)
    If $IsObject(tPayload) Do $$$AssertEquals(tPayload.%GetTypeOf("focus") _ "|" _ tPayload.%GetTypeOf("rows"), "unassigned|unassigned", "a screen declaring secret fields carries no marker")
}

/// <p>A selected entry the row cap cuts, or the total bound cuts, arrives as the focus row, cut per
/// field as a row is; one the cap keeps keeps its index; a focus row's over-long field is cut as a
/// row's is and reported.</p>
/// <p>Mutation: drop the selected-to-focus step from
/// <method>OcuPilot.Api.Turn.BoundedContext</method> -- the two cut cases go red; skip either
/// <method>OcuPilot.Api.Turn.BoundFocus</method> call -- its field case goes red; convert whenever
/// a row was cut -- the kept case goes red.</p>
Method TestACutEntryArrivesAsTheFocusRow()
{
    Set tContext = ..MessagesContext({"selected": 2})
    Do tContext.view.rows.%Get(2).%Set("text", $Translate($Justify("", 1500), " ", "f"), "string")
    Set tPayload = ..Bounded(tContext, 2)
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.rowsSent, 2, "the row cap cuts the chosen row")
    Do $$$AssertEquals(tPayload.%GetTypeOf("selected"), "unassigned", "so its index is not sent")
    Do $$$AssertEquals(tPayload.focus.time _ "|" _ $Length(tPayload.focus.text), "2026-09-29T10:00:00.000|1000", "and it arrives as the focus row, cut to the field bound")

    Set tPayload = ..Bounded(..MessagesContext({"selected": 1}), 2)
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals(tPayload.rowsSent _ "|" _ tPayload.selected _ "|" _ tPayload.%GetTypeOf("focus"), "2|1|unassigned", "a chosen row the cap keeps keeps its index")

    Set tContext = ..MessagesContext()
    Set tRows = []
    Set tText = $Translate($Justify("", 900), " ", "t")
    For tI = 1:1:100 Do tRows.%Push({"time": (tI _ ""), "severity": "0", "text": (tText)})
    Do tContext.view.%Set("rows", tRows)
    Do tContext.view.%Set("rowsAvailable", 100, "number")
    Do tContext.view.%Set("selected", 99, "number")
    Set tPayload = ..Bounded(tContext)
    If '$IsObject(tPayload) Quit
    Do $$$AssertTrue(tPayload.rowsSent < 99, "the total bound cuts the chosen row: " _ tPayload.rowsSent)
    Do $$$AssertEquals(tPayload.%GetTypeOf("focus") _ "|" _ tPayload.focus.time, "object|100", "and it arrives as the focus row")
    Do $$$AssertTrue($Length(tPayload.%ToJSON()) <= 65536, "within the total bound")

    Set tLong = $Translate($Justify("", 1500), " ", "x")
    Set tPayload = ..Bounded(..MessagesContext({"focus": {"time": "t", "severity": "0", "text": (tLong)}}))
    If '$IsObject(tPayload) Quit
    Do $$$AssertEquals($Length(tPayload.focus.text), 1000, "a focus field is cut to the field bound")
    Do $$$AssertEquals($Extract(tPayload.focus.text, *), ##class(OcuPilot.Kernel.Agent.Bound).Ellipsis(), "and marked")
    Do $$$AssertEquals(tPayload.truncated _ "|" _ tPayload.truncatedFields.%ToJSON(), "1|[""text""]", "and reported")
}

}
