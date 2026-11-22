/// <p>Pins Story 24.15's schedule spec writes end to end against probe schedule specs in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53, AD-54,
/// AD-55, AD-58, AD-59, AD-62): a person's Save adds a schedule spec, their Edit and Remove change and remove one, and the agent's three tools mint
/// and confirm over HTTP. Each answers a read-back verdict and the change event's triple, and what it stored reads back from
/// <code>Ens.Util.Schedule</code> exactly as sent; the vendor records no audit row, so OcuPilot's own <code>ConfigChange</code> is the record, naming
/// the namespace, the schedule spec and the field names, never a value; a schedule spec changed out of band after the mint closes the confirm
/// target-changed. The script form of each write names the schedule spec.</p>
/// <p>It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>. <b>What it needs from the environment:</b> an
/// interoperability-enabled <code>USER</code> namespace and an <code>HSCUSTOM</code> one, the HTTP test account and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It starts no production and removes every schedule spec it creates.</p>
Class OcuPilot.Test.InteropScheduleControl Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropScheduleFixture";

Parameter CLEARER = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PORT = "OcuPilot.Port.InteropPort";

/// <p>The probe schedule spec every test names, and two specs the vendor accepts.</p>
Parameter NAME = "OcuProbe2415SA";

Parameter SPEC1 = "START:*-*-*T08:00:00,STOP:*-*-*T17:00:00";

Parameter SPEC2 = "START:*-*-*T09:00:00,STOP:*-*-*T18:00:00";

Parameter SCREEN = "/screens/interop.schedules";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropScheduleControl writes probe schedule specs in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#CLEARER, "Clear"), "the probe schedule specs are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount") + $ClassMethod(..#FIXTURE, "ScheduleCount", "OcuProbe2415S", "HSCUSTOM"), 0, "and none survives in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The schedule spec <var>pName</var> as the port's single-schedule read answers it, or <code>""</code> when it is not held.</p>
ClassMethod Held(pName As %String = {..#NAME}) As %DynamicObject
{
    Kill tQuery
    Set tQuery("id") = pName
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Schedules", "SCHEDULE", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select(tHttp = 200: tRow, 1: "")
}

/// <p>The port's call of the type <var>pType</var> on <var>pName</var> in USER as <code>status code</code>.</p>
ClassMethod Verdict(pType As %String, pName As %String, pBody As %DynamicObject = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Schedules", pType, .tQuery, pBody, .tRow, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>One person's row action on the Schedule specs screen as <code>status code</code>, the answer in <var>pAnswer</var>. <var>pValues</var>, when it is
/// an object, is the dialog's values.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The person's Save of a schedule spec as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/interop/schedules", pBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The body of a Save of the probe schedule spec <var>pName</var> with <var>pSpec</var> and, as given, <var>pDescription</var> and
/// <var>pDeployable</var>.</p>
ClassMethod SaveBody(pName As %String, pSpec As %String, pDescription As %String = "", pDeployable As %Boolean = 0) As %DynamicObject
{
    Set tBody = {"Name": (pName), "ScheduleSpec": (pSpec), "Description": (pDescription)}
    Do tBody.%Set("Deployable", pDeployable = 1, "boolean")
    Quit tBody
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that name the schedule spec <var>pName</var>, with the last row's
/// data in <var>pData</var>.</p>
ClassMethod OwnRows(pSince As %String, Output pData As %String, pName As %String = {..#NAME}) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", pName, .pData)
}

/// <p>How many rows of the vendor's own <code>%Ensemble</code> audit since <var>pSince</var> carry <var>pWords</var> in their data or description: the
/// vendor records no schedule spec row (measured).</p>
ClassMethod VendorRows(pSince As %String, pWords As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData, Description FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%Ensemble'", pSince)
        While tRS.%Next() {
            If (tRS.%Get("EventData") [ pWords) || (tRS.%Get("Description") [ pWords) Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The arguments of a call naming the probe schedule spec <var>pName</var>, with each member of <var>pSet</var> beside it.</p>
ClassMethod ArgsFor(pName As %String, pSet As %DynamicObject = "") As %DynamicObject
{
    Set tArgs = {"Name": (pName)}
    If $IsObject(pSet) {
        Set tIterator = pSet.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Do tArgs.%Set(tKey, tValue, pSet.%GetTypeOf(tKey))
        }
    }
    Quit tArgs
}

/// <p>Mint <var>pTool</var> (a class name) for <var>pArgs</var> as the HTTP account, with the proposal in <var>pProposal</var>.</p>
ClassMethod Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pFault, Output pTurn) As %Status
{
    Quit $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool." _ pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .pFault, .pTurn)
}

/// <p>Confirm <var>pProposal</var> over HTTP from a request scoped to <var>pNamespace</var> (<code>USER</code> when empty): the status, and the answer
/// in <var>pAnswer</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pAnswer, Output pRaw, pNamespace As %String = "") As %Integer
{
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer, pNamespace)
    Quit tStatus
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod(..#CONTROL, "LedgerCount", pTurn, pTool)
}

/// <p>The screen is declared as the plan places it: in the Interoperability area at side bar 15 with the schedule spec's name as its key, New schedule
/// spec as its primary action and Edit and Remove as its row actions, over <code>%Ens_ProductionConfig:READ</code>, naming the entity type
/// <code>interop-schedule</code> and the classic page it replaces, and declaring no secret.</p>
/// <p>Mutation (Rule 19): change the screen's <code>sideBarPosition</code> to 14 -- this goes red.</p>
Method TestTheDeclarationRegisters()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropScheduleList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, "interoperability/schedules|15|list|interoperability", "its route, place, archetype and area")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON() _ "|" _ tDeclaration.toolIdentifier, "interop-schedule|composite|[""Name""]|interop.schedules", "its entity type, its key and its tool identifier")
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Get(0).id _ "," _ tDeclaration.rowActions.%Get(1).id, "add|edit,remove", "its actions")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.context.secretFields.%ToJSON(), "EnsPortal.ScheduleEditor|[]", "its classic page and no secret field")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_ProductionConfig"",""permission"":""READ""}]", "its pairs are the classic page's")
}

/// <p>AC1: a person's Save adds a schedule spec: it answers 201 with the name as its id, its target in the change event's triple and a read-back that
/// matches, stores exactly what was sent, and records one <code>ConfigChange</code> naming the namespace, the schedule spec and the field names, and no
/// value. The vendor records none.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformSchedule</method> drop <code>Deployable</code> on an add -- the stored-text
/// leg goes red.</p>
Method TestTheSaveAddsAScheduleSpecThatReadsBackExactly()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertTrue('$IsObject(..Held()), "the schedule spec is not held yet")
    Set tText = ..Save(..SaveBody(..#NAME, ..#SPEC1, "weekdays", 1), .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#NAME _ "|interop-schedule|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name as its id, its entity type and a matching read-back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC1 _ "|weekdays|1", "the class holds exactly what was sent")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one ConfigChange row")
    Do $$$AssertTrue((tData [ "USER") && (tData [ "ScheduleSpec,Description,Deployable") && (tData '[ ..#SPEC1) && (tData '[ "weekdays"), "naming the namespace and the field names, never a value: " _ tData)
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAME), 0, "and the vendor records none")
    Set tHeld = ..Held()
    Do $$$AssertEquals($Select($IsObject(tHeld): tHeld.ScheduleSpec _ "|" _ tHeld.Description _ "|" _ tHeld.Deployable _ "|" _ tHeld.Namespace, 1: ""), ..#SPEC1 _ "|weekdays|1|USER", "the single read answers the row as stored")
    Set tNone = ..#NAME _ "N"
    Set tText = ..Save({"Name": (tNone), "ScheduleSpec": (..#SPEC2)}, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "a Save with only a name and a spec answers 201")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", tNone), ..#SPEC2 _ "||0", "and stores an empty description and a flag that is not set")
}

/// <p>AC1: the Save route answers JSON over the wire: 201 with the name as its id, and a name the namespace holds, in another letter case too, 409 with
/// <code>INTEROP.SCHEDULE.TAKEN</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.ItemSave.IdOf</method> answer an empty id for a schedule spec -- this goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/schedules?ns=USER"
    Set tBody = ..SaveBody(..#NAME, ..#SPEC1)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, ..#NAME _ "|interop-schedule|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the name's id, its target and a matching read-back")
    For tName = ..#NAME, $ZConvert(..#NAME, "L") {
        Set tBody = ..SaveBody(tName, ..#SPEC2)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus, 409, "a held name '" _ tName _ "' is refused 409: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tRaw).code, "INTEROP.SCHEDULE.TAKEN", "with the envelope's code")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC1 _ "||0", "the held schedule spec is untouched")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount"), 1, "and only its row exists")
}

/// <p>AC1: a person's Edit and Remove answer 200 with the <code>updated</code> and <code>deleted</code> events: an Edit that carries the spec alone
/// changes it and keeps the description and the flag, an Edit that changes nothing calls nothing, an Edit of the flag and the description alone keeps the
/// spec, and a Remove takes the schedule spec; each change records one <code>ConfigChange</code>, none carrying a value.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformSchedule</method> store the description on a set that carries only the spec
/// -- the kept-description leg goes red.</p>
Method TestThePersonsEditAndRemoveChangeOnlyWhatTheyCarry()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutSchedule", ..#NAME, ..#SPEC1, "before", 1), "the probe schedule spec is arranged")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act("edit", ..#NAME, {"ScheduleSpec": (..#SPEC2)}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "an Edit answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-schedule|" _ ..#NAME _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event for the schedule spec, whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC2 _ "|before|1", "the spec changed and the description and the flag are kept")
    Do $$$AssertEquals(..Act("edit", ..#NAME, {"ScheduleSpec": (..#SPEC2)}, .tAnswer), "200 ", "an Edit that changes nothing is accepted and calls nothing")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "so OcuPilot records one row")
    Do $$$AssertTrue((tData [ "ScheduleSpec") && (tData '[ ..#SPEC2) && (tData '[ "before"), "naming the field and no value: " _ tData)
    Do $$$AssertEquals(..Act("edit", ..#NAME, {"Description": "after", "Deployable": "false"}, .tAnswer), "200 ", "an Edit of the description and the flag answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC2 _ "|after|0", "and keeps the spec")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 2, "the Edit of the description and the flag records its own row")
    Do $$$AssertTrue((tData [ "Description") && (tData [ "Deployable") && (tData '[ "ScheduleSpec") && (tData '[ "after"), "naming those two fields and no value: " _ tData)
    Do $$$AssertEquals(..Act("edit", ..#NAME, {"Description": ""}, .tAnswer), "200 ", "an Edit that sends an empty description answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC2 _ "||0", "and the description is cleared")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 3, "the cleared description records its own row")
    Do $$$AssertTrue((tData [ "Description") && (tData '[ "Deployable"), "naming the description alone: " _ tData)
    Set tText = ..Act("remove", ..#NAME, "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "deleted|interop-schedule", "as a deletion")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), "<absent>", "the schedule spec is gone from the class")
    Do $$$AssertEquals(..Act("remove", ..#NAME, "", .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds none")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 4, "the Remove records its own row and the refused second Remove records none")
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAME), 0, "and the vendor recorded no row throughout")
}

/// <p>AC1: the agent's add of a schedule spec, minted for the HTTP account and confirmed over HTTP, creates a schedule spec that did not exist, answers
/// one envelope with a read-back that matches, is ledgered once and marked (AD-15); a name taken after the mint, in another letter case, closes the
/// confirm target-changed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ScheduleWriteToken</method> answer no token for an add -- the taken leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropScheduleAdd", ..ArgsFor(..#NAME, {"ScheduleSpec": (..#SPEC1), "Description": "agent", "Deployable": true}), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-schedule|USER|" _ ..#NAME, "the target is the schedule spec, by its name")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), "<absent>", "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.schedules.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC1 _ "|agent|1", "the class holds what the proposal reviewed")
    Do $$$AssertEquals(..VendorRows(tSince, ..#NAME), 0, "the vendor records no row")
    Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue(tData '[ ..#SPEC1, "carrying no value")
    Set tOther = ..#NAME _ "B"
    Set tSC = ..Mint("InteropScheduleAdd", ..ArgsFor(tOther, {"ScheduleSpec": (..#SPEC2)}), .tSecond, .tFault, .tSecondTurn)
    Do $$$AssertStatusOK(tSC, "a second add mints")
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutSchedule", $ZConvert(tOther, "L"), ..#SPEC1), "the name is taken after the mint, in another letter case")
    Set tStatus = ..Confirm(tSecond, .tAnswer, .tRaw)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", tOther), "<absent>", "and nothing was written under the name the agent proposed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSecondTurn))
}

/// <p>AC1: the agent's update changes the spec and keeps the description and the flag, and the agent's remove is destructive and ships off: it is
/// refused while the tool's key is off, closes target-changed when the schedule spec moved after the mint, and removes the schedule spec once it is on.
/// The update's consequence says a running production follows a changed spec at once, and the remove's says what becomes of the items that name it.</p>
/// <p>Mutation (Rule 19): turn the remove tool's baseline key on -- the refusal leg goes red.</p>
Method TestTheAgentsUpdateAndRemoveConfirmOverHttp()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutSchedule", ..#NAME, ..#SPEC1, "one", 1), "the probe schedule spec is arranged")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the stored policy is cleared")
        Set tSC = ..Mint("InteropScheduleUpdate", ..ArgsFor(..#NAME, {"ScheduleSpec": (..#SPEC2)}), .tUpdate, .tFault, .tUpdateTurn)
        Do $$$AssertStatusOK(tSC, "the update mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tUpdate)) Quit
        Do $$$AssertEquals(tUpdate.changed.%ToJSON(), "[{""field"":""ScheduleSpec"",""before"":""" _ ..#SPEC1 _ """,""after"":""" _ ..#SPEC2 _ """}]", "its card shows the one field it moves")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tUpdate.proposalId, "Consequence"), "INTEROP.SCHEDULE.CHANGE", "its consequence says a running production follows the change at once")
        Set tStatus = ..Confirm(tUpdate, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "the update confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked (AD-15), whose read-back matches")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC2 _ "|one|1", "the spec changed and the description and the flag are kept")
        Do $$$AssertEquals(..OwnRows(tSince, .tData), 1, "the update records one ConfigChange")
        Do $$$AssertTrue((tData [ "ScheduleSpec") && (tData '[ "Description") && (tData '[ ..#SPEC2), "naming the one field it changed and no value: " _ tData)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tUpdateTurn)
        Set tSC = ..Mint("InteropScheduleRemove", ..ArgsFor(..#NAME), .tRemove, .tFault, .tRemoveTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tRemove)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tRemove.proposalId, "Destructive") + 0), "INTEROP.SCHEDULE.REMOVE|1", "its consequence says what becomes of the items that name it, and it is destructive")
        Set tStatus = ..Confirm(tRemove, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC2 _ "|one|1", "and the schedule spec is still there")
        Kill tSettings
        Set tSettings("interop.schedules.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutSchedule", ..#NAME, ..#SPEC1, "moved", 0), "the schedule spec is changed after the mint")
        Set tStatus = ..Confirm(tRemove, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "a schedule spec changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC1 _ "|moved|0", "and the schedule spec is still there")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tRemoveTurn))
        Set tSC = ..Mint("InteropScheduleRemove", ..ArgsFor(..#NAME), .tRemove, .tFault, .tRemoveTurn)
        Do $$$AssertStatusOK(tSC, "a fresh remove mints")
        If '$IsObject($Get(tRemove)) Quit
        Set tStatus = ..Confirm(tRemove, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the schedule spec gone")
        Do $$$AssertEquals(..LedgerCount(tRemoveTurn, "interop.schedules.remove"), 1, "ledgered once")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), "<absent>", "the schedule spec is gone")
        Do $$$AssertEquals(..OwnRows(tSince, .tData), 2, "the remove records its own ConfigChange and the refused confirms record none")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    For tTurn = $Get(tUpdateTurn), $Get(tRemoveTurn) {
        If tTurn '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
}

/// <p>AC1: the script form of each write names the schedule spec and the fields the body carries, as string literals, and the list and the agent's read
/// tool show the spec as text.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ScheduleSnippet</method> drop the spec -- the script leg goes red.</p>
Method TestTheScriptFormAndTheReadShowTheSpecAsText()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutSchedule", ..#NAME, ..#SPEC1, "reader", 1), "a schedule spec is arranged")
    Do $ClassMethod(..#CONTROL, "Call", "GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tScreen)
    Do $$$AssertTrue($IsObject(tScreen) && (tScreen.%ToJSON() [ ..#NAME) && (tScreen.%ToJSON() [ ..#SPEC1), "the screen's read lists the schedule spec with its spec as text")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.schedules.read", .tTool)
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertTrue((+$Get(tToolHttp) = 200) && (tResult.%ToJSON() [ ..#NAME) && (tResult.%ToJSON() [ ..#SPEC1), "the agent's read tool lists it with its spec as text")
    For tType = "ADDSCHEDULE", "SETSCHEDULE", "REMOVESCHEDULE" {
        Kill tScript
        Set tScript("namespace") = "USER"
        Set tScript("id") = ..#NAME
        Set tSteps = $ClassMethod(..#PORT, "Snippet", "Schedules", tType, .tScript, {"ScheduleSpec": (..#SPEC1), "Description": "d", "Deployable": true})
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ ..#NAME) && (tText [ "Ens.Util.Schedule"), tType _ ": the script form names the schedule spec and the vendor's class")
        If tType '= "REMOVESCHEDULE" Do $$$AssertTrue((tText [ ..#SPEC1) && (tText [ "Deployable = 1"), tType _ ": and carries the spec and the flag as the body had them: " _ tText)
    }
}

}
