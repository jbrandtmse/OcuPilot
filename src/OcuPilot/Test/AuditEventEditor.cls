/// <p>Pins Story 9.10 against the instance itself: the user audit event editor's routes over HTTP --
/// a create, a taken name, the vendor's bounds, a Description edit that keeps <code>Enabled</code>,
/// an edit of a vanished event, and each list refusing the other's events from both callers -- the
/// agent's create, its create race and its Description edit through the shipped mint and confirm,
/// the marking fact a Save records after its write, and a principal holding exactly the list's pairs
/// creating and editing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// the list's pairs, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code> -- the legs register and delete
/// audit events and create a principal. Every event it creates has the Source
/// <parameter>PROBESOURCE</parameter> and is deleted by exact name after each method;
/// <method>OnBeforeAllTests</method> refuses to adopt one that already exists.</p>
Class OcuPilot.Test.AuditEventEditor Extends %UnitTest.TestCase
{

/// <p>The variable <file>scripts/ci-throwaway.sh</file> sets and nothing else does.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_AUDIT_EVENTS";

/// <p>The least-privileged leg creates a principal.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter LIST = "OcuPilot.Screen.Descriptor.AuditUserEventList";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AuditUserEventCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AuditUserEventUpdate";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter FORMPATH = "/audit-events/form";

Parameter CREATEPATH = "/audit-events";

Parameter EDITPATH = "/audit-events/:id";

Parameter SYSTEMEVENT = "%System/%Security/AuditChange";

/// <p>Every probe event's Source; nothing else is created.</p>
Parameter PROBESOURCE = "OcuP910Probe";

/// <p>The probe events' Type/Name halves, each deleted by exact name.</p>
Parameter PROBES = "Editor/One,Editor/Gone,Bounds/Long,Agent/Create,Agent/Race,Agent/Edit,Principal/One";

Parameter PRINCIPALROLE = "OcuPilotProbeAuditEditorRole";

Parameter PRINCIPALUSER = "OcuPilotProbeAuditEditorUser";

Parameter PRINCIPALPASSWORD = "OcuPilotAudit910ProbePassword9Aa";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditEventEditor registers and deletes audit events on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditEventEditor creates a principal on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If ..AnyProbe() Quit $$$ERROR($$$GeneralError, "a probe audit event of OcuPilot.Test.AuditEventEditor already exists on this instance, and this class deletes what it creates -- it will not adopt one it did not make.")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.MarkingPort).Clear()
    For tI = 1:1:$Length(..#PROBES, ",") Do ..Remove(..Probe($Piece(..#PROBES, ",", tI)))
    Do ..RemoveParts(..#PROBESOURCE, "Bounds", $Translate($Justify("", 64), " ", "n"))
    Do $$$AssertEquals(..AnyProbe(), 0, "the probe audit events are gone")
    Do ..RemovePrincipal()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AD-12, AD-39: the form read answers one JSON envelope with the vendor's bounds, and with an
/// event its fields; a system event is refused <code>AUDITEVENT.SYSTEM</code> and an absent one
/// <code>AUDITEVENT.ABSENT</code>, as is an edit of an absent one.</p>
Method TestEachRouteAnswersOneEnvelope()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the bare form read answers 200")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.maxLengths.%ToJSON(), "{""Source"":64,""Type"":64,""Name"":64,""Description"":256}", "carrying the vendor's bounds")
    Do $$$AssertEquals(tParsed.%GetTypeOf("event"), "unassigned", "and no event")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?event=" _ ..Query(..#SYSTEMEVENT), .tStatus, .tParsed)
    Do $$$AssertEquals(tStatus _ " " _ ..CodeOf(tParsed), "422 AUDITEVENT.SYSTEM", "a system event's form read is refused")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?event=" _ ..Query(..Probe("Editor/One")), .tStatus, .tParsed)
    Do $$$AssertEquals(tStatus _ " " _ ..CodeOf(tParsed), "404 AUDITEVENT.ABSENT", "and an absent one's")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(..Probe("Editor/One")), .tStatus, .tParsed, "{""Description"":""x""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..CodeOf(tParsed), "404 AUDITEVENT.ABSENT", "an edit of an absent event is 404")
    Do $$$AssertEquals(..Exists(..Probe("Editor/One")), 0, "and no stub was created")
}

/// <p>AC1, AC2: a create registers the event as sent and answers the canonical triple; the same
/// name in another case is refused <code>AUDITEVENT.TAKEN</code> on Name and never overwrites it;
/// a Description edit changes it alone, so a disabled event stays disabled; an edit carrying another
/// key is refused.</p>
/// <p>Mutation (Rule 19): skip the absence read in
/// <method>OcuPilot.Area.Security.AuditEventSave.Create</method> -- the taken leg goes red and the
/// stored Description is overwritten.</p>
Method TestACreateThenATakenNameThenADescriptionEdit()
{
    Set tId = ..Probe("Editor/One")
    Set tRequest = {"Source": (..#PROBESOURCE), "Type": "Editor", "Name": "One", "Description": "d", "Enabled": false}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tParsed, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the create answers 201")
    Do $$$AssertEquals($Select($IsObject(tParsed) && $IsObject(tParsed.%Get("target")): tParsed.target.%ToJSON(), 1: ""), "{""type"":""audit-user-event"",""scope"":""instance"",""id"":""" _ $ZConvert(tId, "L") _ """}", "with the canonical triple")
    Do $$$AssertEquals(..Stored(tId), "d|0", "the instance holds the event as sent, disabled")

    Set tAgain = {"Source": ($ZConvert(..#PROBESOURCE, "L")), "Type": "editor", "Name": "one", "Description": "overwritten", "Enabled": true}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tParsed, tAgain.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..CodeOf(tParsed), "422 AUDITEVENT.VALIDATION", "the same name in another case is refused")
    Do $$$AssertEquals(..Violation(tParsed), "Name:AUDITEVENT.TAKEN", "on Name, as taken")
    Do $$$AssertEquals(..Stored(tId), "d|0", "and the stored event is unchanged")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath($ZConvert(tId, "L")), .tStatus, .tParsed, "{""Description"":""changed""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Description edit answers 200, the id in another case")
    Do $$$AssertEquals(..Stored(tId), "changed|0", "the Description changed and Enabled still reads false")

    Set tLong = {}
    Do tLong.%Set("Description", $Translate($Justify("", 257), " ", "d"), "string")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(tId), .tStatus, .tParsed, tLong.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tParsed), "422 Description:AUDITEVENT.DESCRIPTION.LENGTH", "a 257-character Description edit is refused on its field")
    Do $$$AssertEquals(..Stored(tId), "changed|0", "and nothing moved")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(tId), .tStatus, .tParsed, "{""Enabled"":true}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..CodeOf(tParsed), "400 PORT.FIELD.UNEXPECTED", "an edit carrying Enabled is refused")
    Do $$$AssertEquals(..Stored(tId), "changed|0", "and nothing moved")
}

/// <p>AC3: the vendor's measured rules refuse before any write -- a reserved Source or Type, a part
/// or Description over its bound -- and the bounds themselves are created.</p>
Method TestTheVendorsRulesRefuseBeforeAnyWriteAndTheBoundsAreCreated()
{
    Set t64 = $Translate($Justify("", 64), " ", "n")
    Set t256 = $Translate($Justify("", 256), " ", "d")
    For tCase = $ListBuild("%Mine", "Editor", "One", "Source:AUDITEVENT.PART.RESERVED"), $ListBuild(..#PROBESOURCE, "%T", "One", "Type:AUDITEVENT.PART.RESERVED"), $ListBuild(..#PROBESOURCE, "Bounds", t64 _ "n", "Name:AUDITEVENT.PART.LENGTH") {
        Set tRequest = {"Description": "d"}
        Do tRequest.%Set("Source", $List(tCase, 1), "string")
        Do tRequest.%Set("Type", $List(tCase, 2), "string")
        Do tRequest.%Set("Name", $List(tCase, 3), "string")
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tParsed, tRequest.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus _ " " _ ..Violation(tParsed), "422 " _ $List(tCase, 4), "refused as " _ $List(tCase, 4))
        Do $$$AssertEquals(..ExistsParts($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)), 0, "and nothing was created")
    }
    Set tRequest = {"Source": (..#PROBESOURCE), "Type": "Bounds", "Name": "Long", "Description": (t256 _ "d")}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tParsed, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tParsed), "422 Description:AUDITEVENT.DESCRIPTION.LENGTH", "a 257-character Description is refused")
    Do $$$AssertEquals(..Exists(..Probe("Bounds/Long")), 0, "and nothing was created")

    Set tRequest = {"Source": (..#PROBESOURCE), "Type": "Bounds", "Name": (t64), "Description": (t256)}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tParsed, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "a 64-character Name and a 256-character Description are created")
    Do $$$AssertEquals(..ExistsParts(..#PROBESOURCE, "Bounds", t64), 1, "and the instance holds the event")
    Do ..RemoveParts(..#PROBESOURCE, "Bounds", t64)
    Do $$$AssertEquals(..ExistsParts(..#PROBESOURCE, "Bounds", t64), 0, "which is removed by its exact name")
}

/// <p>AC2: an event deleted after the dialog opened is refused <code>AUDITEVENT.ABSENT</code>, and
/// the vendor's upsert creates no stub.</p>
Method TestAnEditOfAVanishedEventIsAbsentAndCreatesNoStub()
{
    Set tId = ..Probe("Editor/Gone")
    Do $$$AssertStatusOK(..Make(tId, "before", 1), "the probe event is created")
    Do ..Remove(tId)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(tId), .tStatus, .tParsed, "{""Description"":""after""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..CodeOf(tParsed), "404 AUDITEVENT.ABSENT", "the edit is refused as absent")
    Do $$$AssertEquals(..Exists(tId), 0, "and Security.Events.Exists stays 0")
}

/// <p>AC3, DW-1575: each list refuses the other's events from both callers -- the system tools'
/// screen actions on a user event, the user tools' on a system event, the editor's edit of a system
/// event, and the agent's mint of either -- and nothing moves.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.AuditEventRules.OwnerProblem</method>
/// answers <code>""</code> -- the system disable leg writes the probe and goes red.</p>
Method TestEachListRefusesTheOthersEventsFromBothCallers()
{
    Set tId = ..Probe("Editor/One")
    Do $$$AssertStatusOK(..Make(tId, "d", 1), "the probe user event is created, enabled")
    Set tSystemEnabled = ..StoredParts("%System", "%Security", "AuditChange")
    For tCase = $ListBuild("security.auditsystemevents", "disable", tId, ##class(OcuPilot.Api.Error).#REASONAUDITEVENTUSER), $ListBuild("security.auditsystemevents", "reset", tId, ##class(OcuPilot.Api.Error).#REASONAUDITEVENTUSER), $ListBuild("security.audituserevents", "enable", ..#SYSTEMEVENT, ##class(OcuPilot.Api.Error).#REASONAUDITEVENTSYSTEM), $ListBuild("security.audituserevents", "reset", ..#SYSTEMEVENT, ##class(OcuPilot.Api.Error).#REASONAUDITEVENTSYSTEM) {
        Set tAnswer = ..ScreenAction($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..CodeOf(tAnswer), "400 TOOL.ARGUMENTS", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " on '" _ $List(tCase, 3) _ "' is refused")
        Set tProblem = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.problem, 1: "")
        Do $$$AssertTrue(tProblem [ $List(tCase, 4), "naming the other list: " _ tProblem)
    }
    Do $$$AssertEquals(..Stored(tId), "d|1", "the probe is still enabled")
    Do $$$AssertEquals(..StoredParts("%System", "%Security", "AuditChange"), tSystemEnabled, "and the system event unchanged")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(..#SYSTEMEVENT), .tStatus, .tParsed, "{""Description"":""x""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tParsed), "422 EventName:AUDITEVENT.SYSTEM", "the editor's edit of a system event is refused")
    Do $$$AssertEquals(..StoredParts("%System", "%Security", "AuditChange"), tSystemEnabled, "and it is unchanged")

    Set tSC = ..Mint(..#UPDATETOOL, ..#SYSTEMEVENT, {"Description": "x"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "the agent's user update of a system event is refused at the mint")
    Do $$$AssertTrue(..ProblemOf(tFault) [ ##class(OcuPilot.Api.Error).#REASONAUDITEVENTSYSTEM, "with the system-event sentence: " _ ..ProblemOf(tFault))
    Set tSC = ..Mint("OcuPilot.Screen.Tool.AuditEventUpdate", tId, {"Enabled": false}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "and its system update of a user event")
    Do $$$AssertTrue(..ProblemOf(tFault) [ ##class(OcuPilot.Api.Error).#REASONAUDITEVENTUSER, "with the user-event sentence: " _ ..ProblemOf(tFault))
    Do $$$AssertEquals(..Stored(tId), "d|1", "and the probe never moved")
}

/// <p>AC1, AD-54: the agent's create registers the event through the shipped mint and confirm; a
/// malformed id mints nothing; and a name taken between the mint and the confirm is refused
/// <code>PROPOSAL.TARGETCHANGED</code> with the direct Description kept.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Confirm</method>'s fingerprint
/// re-read ignore a create's presence -- the race leg's refusal and kept Description go red.</p>
Method TestTheAgentsCreateAndItsRace()
{
    Set tId = ..Probe("Agent/Create")
    Set tSC = ..Mint(..#CREATETOOL, tId, {"Description": "agent", "Enabled": false}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create mints: " _ ..ProblemOf(tFault))
    If $$$ISOK(tSC) {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusOK(tSC, "and confirms: " _ $Get(tCode))
        Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "created", "as a create")
        Do $$$AssertEquals(..Stored(tId), "agent|0", "the instance holds the event as proposed")
    }

    Set tSC = ..Mint(..#CREATETOOL, "a/b", {"Description": "x"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "an id of two parts is refused at the mint")
    Do $$$AssertTrue(..ProblemOf(tFault) [ ##class(OcuPilot.Api.Error).#REASONAUDITEVENTEVENTNAMESHAPE, "with the shape sentence: " _ ..ProblemOf(tFault))

    Set tRace = ..Probe("Agent/Race")
    Set tSC = ..Mint(..#CREATETOOL, tRace, {"Description": "agent", "Enabled": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the racing create mints")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK(..Make(tRace, "direct", 0), "the same event is registered directly behind it")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as a target that changed")
    Do $$$AssertEquals(..Stored(tRace), "direct|0", "and the direct Description survives")
}

/// <p>AC2: the agent's Description edit, confirmed, changes the Description alone.</p>
Method TestTheAgentsDescriptionEditKeepsEnabled()
{
    Set tId = ..Probe("Agent/Edit")
    Do $$$AssertStatusOK(..Make(tId, "before", 0), "a disabled probe event is created")
    Set tSC = ..Mint(..#UPDATETOOL, tId, {"Description": "after"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the Description edit mints: " _ ..ProblemOf(tFault))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "with its one Description row")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirms: " _ $Get(tCode))
    Do $$$AssertEquals(..Stored(tId), "after|0", "the Description changed and Enabled still reads false")
}

/// <p>AD-53, AD-15: a Save through a tool that moves the marking records the marking fact it
/// observes after the write.</p>
/// <p>Mutation (Rule 19): drop the observation from
/// <method>OcuPilot.Area.Security.AuditEventSave.Send</method> -- the recorded fact stays marked.</p>
Method TestASaveRecordsTheMarkingItObservesAfterTheWrite()
{
    Set tId = ..Probe("Editor/One")
    Do $$$AssertStatusOK(..Make(tId, "before", 1), "the probe user event is created")
    Set tBefore = ##class(OcuPilot.Kernel.Audit.Event).WritesMarked()
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Event).RecordMarking(1), "the fact is recorded marked first")
        Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "0")
        Set tSC = ##class(OcuPilot.Test.MarkingSave).SaveWrite(..#UPDATETOOL, tId, {"Description": "observed", "Enabled": true}, .tHttp)
        Do $$$AssertStatusOK(tSC, "the Save's write lands")
        Do $$$AssertEquals(..Stored(tId), "observed|1", "as sent")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 0, "and the observed 'not marked' is recorded")
    } Catch ex {
        Do $$$AssertTrue(0, "the Save raised: " _ ex.DisplayString())
    }
    Do ##class(OcuPilot.Test.MarkingPort).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Event).RecordMarking(tBefore), "the recorded fact is put back")
}

/// <p>AD-8, AD-55: a principal holding exactly the list's pairs, and the code database read, creates
/// and edits an event through the editor's routes.</p>
Method TestAPrincipalHoldingTheListsPairsCreatesAndEdits()
{
    Set tCode = ..CodeDatabaseResource()
    Do $$$AssertNotEquals(tCode, "", "the install namespace's code database resource resolves")
    If tCode = "" Quit
    Set tSC = ..EnsurePrincipal("%Admin_Secure:U,%DB_IRISSYS:R," _ tCode _ ":R")
    Do $$$AssertStatusOK(tSC, "a principal holding only the list's pairs is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tId = ..Probe("Principal/One")
    Set tRequest = {"Source": (..#PROBESOURCE), "Type": "Principal", "Name": "One", "Description": "p", "Enabled": true}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the principal's create answers 201: " _ $Extract($Get(tBody), 1, 300))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..EditPath(tId), ..#PRINCIPALUSER, ..#PRINCIPALPASSWORD, .tStatus, .tBody, .tHeaders, "{""Description"":""q""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "and its edit 200: " _ $Extract($Get(tBody), 1, 300))
    Do $$$AssertEquals(..Stored(tId), "q|1", "the instance holds the edited event")
}

/// <p>Mint one proposal of tool <var>pTool</var> for <var>pId</var> with <var>pArgs</var> through
/// the shipped mint and port, on a seeded turn.</p>
Method Mint(pTool As %String, pId As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = ##class(%DynamicObject).%FromJSON(pArgs.%ToJSON())
    Do tArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>One screen action <var>pAction</var> on <var>pId</var> through the list <var>pScreen</var>
/// names, as the test account, answering the parsed body or <code>""</code>.</p>
Method ScreenAction(pScreen As %String, pAction As %String, pId As %String, Output pStatus As %Integer) As %DynamicObject
{
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/screens/" _ pScreen _ "/action", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertStatusOK(tSC, pAction _ ": the request completes")
    If $$$ISERR(tSC) || ($Get(tBody) = "") Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody)
}

/// <p>The envelope code of <var>pBody</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pBody) As %String
{
    If '$IsObject($Get(pBody)) Quit ""
    Quit pBody.%Get("code")
}

/// <p>The first violation of <var>pBody</var> as <code>field:code</code>, or <code>""</code>.</p>
ClassMethod Violation(pBody) As %String
{
    If '$IsObject($Get(pBody)) || '$IsObject(pBody.%Get("detail")) || '$IsObject(pBody.detail.%Get("violations")) Quit ""
    If pBody.detail.violations.%Size() = 0 Quit ""
    Quit pBody.detail.violations.%Get(0).field _ ":" _ pBody.detail.violations.%Get(0).code
}

/// <p>The mint refusal's <code>detail.problem</code>, or <code>""</code>.</p>
ClassMethod ProblemOf(pFault) As %String
{
    If '$IsObject($Get(pFault)) || '$IsObject(pFault.%Get("detail")) Quit ""
    Quit pFault.detail.%Get("problem")
}

/// <p>The probe event <parameter>PROBESOURCE</parameter><code>/</code><var>pRest</var>.</p>
ClassMethod Probe(pRest As %String) As %String
{
    Quit ..#PROBESOURCE _ "/" _ pRest
}

/// <p><parameter>EDITPATH</parameter> for <var>pId</var>, its segment encoded by the one shared
/// encoder (AD-13).</p>
ClassMethod EditPath(pId As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pId))
}

/// <p><var>pValue</var> percent-encoded once, for a query string.</p>
ClassMethod Query(pValue As %String) As %String
{
    Quit $ZConvert(pValue, "O", "URL")
}

/// <p>Whether any probe event this class names exists.</p>
ClassMethod AnyProbe() As %Boolean
{
    Set tAny = 0
    For tI = 1:1:$Length(..#PROBES, ",") {
        If ..Exists(..Probe($Piece(..#PROBES, ",", tI))) Set tAny = 1
    }
    Quit tAny
}

ClassMethod Exists(pId As %String) As %Boolean
{
    Quit ..ExistsParts($Piece(pId, "/", 1), $Piece(pId, "/", 2), $Piece(pId, "/", 3))
}

/// <p>Whether the instance registers the event, read in <code>%SYS</code>.</p>
ClassMethod ExistsParts(pSource As %String, pType As %String, pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Events).Exists(pSource, pType, pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

ClassMethod Stored(pId As %String) As %String
{
    Quit ..StoredParts($Piece(pId, "/", 1), $Piece(pId, "/", 2), $Piece(pId, "/", 3))
}

/// <p>The event as <code>description|enabled</code>, read in <code>%SYS</code>, or
/// <code>""</code>.</p>
ClassMethod StoredParts(pSource As %String, pType As %String, pName As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Events).Exists(pSource, pType, pName, .tEvent) Set tValue = tEvent.Description _ "|" _ (''tEvent.Enabled)
        Set tEvent = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Register the probe event <var>pId</var> directly, for a leg that needs one to exist.</p>
ClassMethod Make(pId As %String, pDescription As %String, pEnabled As %Boolean) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Events).Create($Piece(pId, "/", 1), $Piece(pId, "/", 2), $Piece(pId, "/", 3), pDescription, pEnabled)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

ClassMethod Remove(pId As %String)
{
    Do ..RemoveParts($Piece(pId, "/", 1), $Piece(pId, "/", 2), $Piece(pId, "/", 3))
}

/// <p>Delete the event named exactly by the three parts, if it exists.</p>
ClassMethod RemoveParts(pSource As %String, pType As %String, pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Events).Exists(pSource, pType, pName) Do ##class(Security.Events).Delete(pSource, pType, pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The resource guarding the install namespace's code database, which a principal needs to read
/// OcuPilot's classes.</p>
ClassMethod CodeDatabaseResource() As %String
{
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tNs)
        Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tNsObj.Routines).Directory).ResourceName
    } Catch ex {
        Set tResource = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tResource
}

/// <p>Create or reset <parameter>PRINCIPALUSER</parameter> holding <parameter>PRINCIPALROLE</parameter>
/// with exactly <var>pResources</var>.</p>
ClassMethod EnsurePrincipal(pResources As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(..#PRINCIPALROLE) {
            Kill tProps
            Set tProps("Resources") = pResources
            Set tProps("GrantedRoles") = ""
            Set tSC = ##class(Security.Roles).Modify(..#PRINCIPALROLE, .tProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#PRINCIPALROLE, "OcuPilot Story 9.10 probe (throwaway)", pResources, "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#PRINCIPALUSER) {
            Set tSC = ##class(Security.Users).Delete(..#PRINCIPALUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#PRINCIPALUSER, ..#PRINCIPALROLE, ..#PRINCIPALPASSWORD, "OcuPilot Story 9.10 probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AuditEventEditor")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the probe principal and its role when the instance holds them.</p>
ClassMethod RemovePrincipal()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PRINCIPALUSER) Do ##class(Security.Users).Delete(..#PRINCIPALUSER)
        If ##class(Security.Roles).Exists(..#PRINCIPALROLE) Do ##class(Security.Roles).Delete(..#PRINCIPALROLE)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

}
