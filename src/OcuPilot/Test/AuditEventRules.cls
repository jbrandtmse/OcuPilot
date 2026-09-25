/// <p>Pins Story 9.10's server rules short of a write: every row of the user audit event editor's
/// rules at their bounds, the ownership rule on all six audit event tools through both hooks
/// (DW-1575), the create tool's declarations and schema, the prohibited set's field lists for both
/// event types, and a published sentence behind every <code>AUDITEVENT.*</code> code.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot compiled. Nothing here reads or writes the
/// instance's audit events.</p>
Class OcuPilot.Test.AuditEventRules Extends %UnitTest.TestCase
{

Parameter RULES = "OcuPilot.Area.Security.AuditEventRules";

Parameter CREATE = "OcuPilot.Screen.Tool.AuditUserEventCreate";

/// <p>The six audit event tools and the list each administers.</p>
Parameter TOOLS = "OcuPilot.Screen.Tool.AuditEventUpdate:system,OcuPilot.Screen.Tool.AuditEventReset:system,OcuPilot.Screen.Tool.AuditUserEventUpdate:user,OcuPilot.Screen.Tool.AuditUserEventReset:user,OcuPilot.Screen.Tool.AuditUserEventDelete:user,OcuPilot.Screen.Tool.AuditUserEventCreate:user";

Parameter SYSTEMEVENT = "%System/%Security/AuditChange";

Parameter USEREVENT = "OcuP910Probe/Rules/One";

/// <p>Each identity rule refuses on the field it names, at the vendor's measured bounds: 64
/// characters pass and 65 do not, a Description of 256 passes and 257 does not, a <code>%</code>
/// Source or Type is reserved and a <code>%</code> Name is not.</p>
/// <p>Mutation (Rule 19): drop the reserved check from
/// <method>OcuPilot.Area.Security.AuditEventRules.PartViolation</method> -- the reserved legs go
/// red.</p>
Method TestEveryRuleRefusesOnItsFieldAtTheBounds()
{
    Set tE = "OcuPilot.Api.Error"
    Set t64 = $Translate($Justify("", 64), " ", "a")
    Set t256 = $Translate($Justify("", 256), " ", "d")
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": "T", "Name": "N"}), "", "a plain event breaks nothing")
    Do $$$AssertEquals(..Codes({"Source": (t64), "Type": (t64), "Name": (t64), "Description": (t256)}), "", "64-character parts and a 256-character Description pass")
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": "T", "Name": "%N"}), "", "a Name beginning with % passes (measured)")
    Set tOdd = "a b^,:""" _ $Char(9, 233)
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": "T", "Name": (tOdd)}), "", "and so do space, caret, comma, colon, quote, tab and non-ASCII")
    Do $$$AssertEquals(..Codes({"Source": "", "Type": "T", "Name": "N"}), "Source:" _ $Parameter(tE, "AUDITEVENTPARTREQUIRED"), "an empty Source is required")
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": "T"}), "Name:" _ $Parameter(tE, "AUDITEVENTPARTREQUIRED"), "an absent Name is required")
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": (t64 _ "a"), "Name": "N"}), "Type:" _ $Parameter(tE, "AUDITEVENTPARTLENGTH"), "a 65-character Type is too long")
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": "T", "Name": "N/M"}), "Name:" _ $Parameter(tE, "AUDITEVENTPARTSLASH"), "a slash in a Name is refused")
    Do $$$AssertEquals(..Codes({"Source": "%Mine", "Type": "T", "Name": "N"}), "Source:" _ $Parameter(tE, "AUDITEVENTPARTRESERVED"), "a Source beginning with % is reserved")
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": "%T", "Name": "N"}), "Type:" _ $Parameter(tE, "AUDITEVENTPARTRESERVED"), "and so is a Type")
    Do $$$AssertEquals(..Codes({"Source": "S", "Type": "T", "Name": "N", "Description": (t256 _ "d")}), "Description:" _ $Parameter(tE, "AUDITEVENTDESCRIPTIONLENGTH"), "a 257-character Description is too long")
    Do $$$AssertEquals(..Codes({"Description": (t256 _ "d")}, 0), "Description:" _ $Parameter(tE, "AUDITEVENTDESCRIPTIONLENGTH"), "and an edit checks the Description alone")
    Do $$$AssertEquals(..Codes({"Description": "d"}, 0), "", "leaving the identity unchecked")
    Set tSC = ##class(OcuPilot.Screen.Tool.AuditUserEventUpdate).ArgumentProblem(..#USEREVENT, {"Description": (t256 _ "d")}, .tProblem)
    Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Api.Error).#REASONAUDITEVENTDESCRIPTIONLENGTH, "the agent's Description edit is held to the same bound: " _ tProblem)

    Set tSC = $ClassMethod(..#RULES, "ArgumentViolations", "a/b", {}, 1, .tViolations)
    Do $$$AssertStatusOK(tSC, "the agent's arguments are checked")
    Do $$$AssertEquals(..Joined(.tViolations), "EventName:" _ $Parameter(tE, "AUDITEVENTEVENTNAMESHAPE"), "an id of two parts is the shape refusal")
    Set tSC = $ClassMethod(..#RULES, "ArgumentViolations", "%S/T/N", {"Description": "d"}, 1, .tViolations)
    Do $$$AssertEquals(..Joined(.tViolations), "Source:" _ $Parameter(tE, "AUDITEVENTPARTRESERVED"), "each part of a three-part id is held to its own rule")
    Set tSC = $ClassMethod(..#RULES, "ArgumentViolations", "S/T/N", {"Description": (t256 _ "d")}, 1, .tViolations)
    Do $$$AssertEquals(..Joined(.tViolations), "Description:" _ $Parameter(tE, "AUDITEVENTDESCRIPTIONLENGTH"), "with the Description beside them")
}

/// <p>DW-1575: every tool refuses the other list's events, and a system event is one whose Source
/// begins with <code>%</code> -- asked directly, through <code>ArgumentProblem</code> (the mint)
/// and through <code>ScreenActionDelta</code> (the screen action), before anything is sent.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.AuditEventRules.OwnerProblem</method>
/// answers <code>""</code> -- every refusing leg goes red.</p>
Method TestEveryToolRefusesTheOtherListsEventsThroughBothHooks()
{
    Set tSystemReason = ##class(OcuPilot.Api.Error).#REASONAUDITEVENTSYSTEM
    Set tUserReason = ##class(OcuPilot.Api.Error).#REASONAUDITEVENTUSER
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tEntry = $Piece(..#TOOLS, ",", tI)
        Set tTool = $Piece(tEntry, ":", 1)
        Set tOwner = $Piece(tEntry, ":", 2)
        Do $$$AssertEquals($Parameter(tTool, "EVENTOWNER"), tOwner, tTool _ " administers the " _ tOwner _ " list")
        Set tForeign = $Select(tOwner = "user": ..#SYSTEMEVENT, 1: ..#USEREVENT)
        Set tOwn = $Select(tOwner = "user": ..#USEREVENT, 1: ..#SYSTEMEVENT)
        Set tCode = $Select(tOwner = "user": ##class(OcuPilot.Api.Error).#AUDITEVENTSYSTEM, 1: ##class(OcuPilot.Api.Error).#AUDITEVENTUSER)
        Set tReason = $Select(tOwner = "user": tSystemReason, 1: tUserReason)
        Do $$$AssertEquals($ClassMethod(..#RULES, "OwnerProblem", tTool, tForeign), tCode, tTool _ " refuses '" _ tForeign _ "' as " _ tCode)
        Do $$$AssertEquals($ClassMethod(..#RULES, "OwnerProblem", tTool, tOwn), "", "and accepts '" _ tOwn _ "'")

        Set tSC = $ClassMethod(tTool, "ArgumentProblem", tForeign, {"Enabled": true}, .tProblem)
        Do $$$AssertStatusOK(tSC, tTool _ ": ArgumentProblem answers")
        If tTool = ..#CREATE {
            ; A create checks the part rules first, so a system event's reserved Source is what it names.
            Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Api.Error).#REASONAUDITEVENTPARTRESERVED, "the create refuses a system event's reserved Source: " _ tProblem)
        } Else {
            Do $$$AssertTrue(tProblem [ tReason, tTool _ ": the mint's hook refuses the other list's event: " _ tProblem)
        }
        Set tSC = $ClassMethod(tTool, "ArgumentProblem", tOwn, {"Enabled": true}, .tProblem)
        Do $$$AssertEquals(tProblem, "", tTool _ ": and not its own list's")

        If $ListLength($ClassMethod(tTool, "ScreenActionIds")) = 0 Continue
        Set tAction = $List($ClassMethod(tTool, "ScreenActionIds"), 1)
        Set tValues = {}
        Do tValues.%Set("EventName", tForeign, "string")
        Set tSC = $ClassMethod(tTool, "ScreenActionDelta", tAction, tValues, {"Description": "d", "Enabled": false, "Total": 1}, .tArgs, .tProblem)
        Do $$$AssertStatusOK(tSC, tTool _ ": ScreenActionDelta answers")
        Do $$$AssertTrue(tProblem [ tReason, tTool _ ": the screen action's hook refuses the other list's event: " _ tProblem)
        Do tValues.%Set("EventName", tOwn, "string")
        Set tSC = $ClassMethod(tTool, "ScreenActionDelta", tAction, tValues, {"Description": "d", "Enabled": false, "Total": 1}, .tArgs, .tProblem)
        Do $$$AssertTrue((tProblem '[ tReason), tTool _ ": and not its own list's: " _ tProblem)
    }
}

/// <p>AD-54, AD-3: the create tool creates, over the class-derived list, admitting exactly what the
/// prohibited set reviewed for a user event create, and its schema states the id's format.</p>
Method TestTheCreateToolDeclaresACreateOverTheDerivedList()
{
    Set tClass = ..#CREATE
    Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), "security.audituserevents.create", "the tool is security.audituserevents.create")
    Do $$$AssertEquals($Parameter(tClass, "DESCRIPTORCLASS"), "OcuPilot.Screen.Descriptor.AuditUserEventList", "on the User events list")
    Do $$$AssertEquals($ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "ReadType"), "1|created|PUT|GET", "a create through the vendor's PUT, read with its GET")
    Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "IdArgument") _ "|" _ $ClassMethod(tClass, "IdParam"), "Security.Audit.Event|EventName|event", "keyed by EventName, split by the port")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), "Description,Enabled", "admitting Description and Enabled")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "PermittedFields")), $ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields("audit-user-event")), "which is what the prohibited set permits a user event create")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking(tClass), 1, "and it moves the marking")
    Set tSchema = $ClassMethod(tClass, "InputSchema")
    Do $$$AssertEquals(tSchema.properties.%GetTypeOf("Description") _ "|" _ tSchema.properties.%GetTypeOf("Enabled"), "object|object", "the schema advertises both fields")
    Do $$$AssertTrue(tSchema.properties.EventName.description [ "Source/Type/Name", "and states the id's format: " _ tSchema.properties.EventName.description)
    Do $$$AssertTrue(tSchema.required.%ToJSON() [ """EventName""", "the id is required")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
    Do $$$AssertTrue(tResolved && ($ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) > 0) && ($ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) > 0), "its pairs are the list's own")
}

/// <p>AD-10, AD-54: a system event's change admits <code>Enabled</code> alone; a user event's change
/// and create admit <code>Description</code> and <code>Enabled</code>; no system event create is
/// reviewed.</p>
Method TestTheProhibitedSetsFieldListsForBothEventTypes()
{
    Set tP = "OcuPilot.Kernel.Proposal.Prohibited"
    Do $$$AssertEquals($ListToString($ClassMethod(tP, "PermittedChangeFields", "audit-event")), "Enabled", "a system event's change admits Enabled")
    Do $$$AssertEquals($ListToString($ClassMethod(tP, "PermittedChangeFields", "audit-user-event")), "Description,Enabled", "a user event's change admits Description and Enabled")
    Do $$$AssertEquals($ListToString($ClassMethod(tP, "PermittedCreateFields", "audit-user-event")), "Description,Enabled", "and so does its create")
    Do $$$AssertEquals($ClassMethod(tP, "PermittedCreateFields", "audit-event"), "", "a system event create is reviewed for nothing")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.AuditUserEventUpdate).PermittedFields()), "Description,Enabled", "the user update tool admits the same two")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.AuditEventUpdate).PermittedFields()), "Enabled", "and the system one Enabled alone")
}

/// <p>AD-39: every <code>AUDITEVENT.*</code> code carries a published sentence, which names no
/// caller.</p>
Method TestEveryCodeHasASentenceThatNamesNoCaller()
{
    Set tCodes = ##class(OcuPilot.Api.Error).AuditEventViolationCodes()
    Do $$$AssertEquals($ListLength(tCodes), 10, "ten codes, the rules table's")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " has a sentence")
        Do $$$AssertEquals(($ZConvert(tReason, "L") [ "agent"), 0, tCode _ "'s sentence names no caller")
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), tCode _ " is a machine code")
    }
}

/// <p><method>OcuPilot.Area.Security.AuditEventRules.Validate</method> over <var>pArgs</var> as
/// <code>field:code</code> pairs joined by commas.</p>
Method Codes(pArgs As %DynamicObject, pIdentity As %Boolean = 1) As %String
{
    Set tSC = $ClassMethod(..#RULES, "Validate", pArgs, pIdentity, .tViolations)
    Do $$$AssertStatusOK(tSC, "the rules answer")
    Quit ..Joined(.tViolations)
}

ClassMethod Joined(ByRef pViolations) As %String
{
    Set tOut = ""
    For tI = 1:1:$Get(pViolations) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(pViolations(tI), 1) _ ":" _ $List(pViolations(tI), 2)
    Quit tOut
}

}
