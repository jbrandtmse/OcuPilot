/// <p>Pins Story 20.26's writes end to end against probe business partners in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53,
/// AD-54, AD-55, AD-58, AD-62): a person's Save adds a partner, their Edit and Remove change and remove one, and the agent's three
/// tools mint and confirm over HTTP. Each answers a read-back verdict and the change event's triple, writes one audit row of
/// OcuPilot's own (<code>ConfigChange</code>) that carries no value, and a partner changed out of band after the mint closes the
/// confirm target-changed. The integration test then reads the partners through Story 20.5's screen read route and read tool.</p>
/// <p>It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>. <b>What it needs from the
/// environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It starts no production and removes every partner it creates.</p>
Class OcuPilot.Test.InteropPartnerControl Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter PARTNER = "OcuProbe226Control";

Parameter VALUEMARKER = "OcuValueMarker226";

Parameter SCREEN = "/screens/interop.businesspartners";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropPartnerControl writes probe business partners in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe partners are removed")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.ProductionProbe", "Remove"), "no probe production is left")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The partner <var>pName</var> as the port's single-partner read answers it, or <code>""</code> when it is not held.</p>
ClassMethod Held(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("id") = pName
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "BusinessPartners", "PARTNER", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select(tHttp = 200: tRow, 1: "")
}

/// <p>One person's row action on the partners screen as <code>status code</code>, the answer in <var>pAnswer</var>.
/// <var>pValues</var>, when it is an object, is the dialog's values.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The person's Save of a partner as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/interop/business-partners", pBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The dialog's thirteen values: every field empty except those of <var>pSet</var>.</p>
ClassMethod Values(pSet As %DynamicObject) As %DynamicObject
{
    Set tValues = {}
    Set tFields = $ListFromString($Parameter(..#PORT, "PARTNERSETFIELDS"))
    For tI = 1:1:$ListLength(tFields) {
        Do tValues.%Set($List(tFields, tI), $Select(pSet.%GetTypeOf($List(tFields, tI)) = "string": pSet.%Get($List(tFields, tI)), 1: ""), "string")
    }
    Quit tValues
}

/// <p>How many <code>ConfigChange</code> rows since <var>pSince</var> record <var>pVerb</var> of partner <var>pName</var>, and the
/// last such row's data in <var>pData</var>.</p>
ClassMethod Audited(pSince As %String, pVerb As %String, pName As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", """id"":""" _ pName _ """", .pData, """verb"":""" _ pVerb _ """")
}

/// <p>The arguments of a call naming <var>pName</var>, with each member of <var>pSet</var> beside it.</p>
ClassMethod ArgsFor(pName As %String, pSet As %DynamicObject = "") As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    If $IsObject(pSet) {
        Set tIterator = pSet.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Do tArgs.%Set(tKey, tValue, "string")
        }
    }
    Quit tArgs
}

/// <p>Mint <var>pTool</var> (a class name) for <var>pArgs</var> as the HTTP account, with the proposal in <var>pProposal</var>.</p>
ClassMethod Mint(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pFault, Output pTurn) As %Status
{
    Quit $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool." _ pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .pFault, .pTurn)
}

/// <p>Confirm <var>pProposal</var> over HTTP: the status, and the single envelope's answer in <var>pAnswer</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pAnswer, Output pRaw) As %Integer
{
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer)
    Quit tStatus
}

/// <p>The agent's mint of <var>pTool</var> for <var>pArgs</var>: the code of the refusal, <code>minted</code> when it was not
/// refused. The fault's problem sentence, which names each field and its published sentence, or else its reason, is in
/// <var>pReason</var>.</p>
ClassMethod MintVerdict(pTool As %String, pArgs As %DynamicObject, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tSC = ..Mint(pTool, pArgs, .tProposal, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    If $IsObject($Get(tProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod(..#CONTROL, "LedgerCount", pTurn, pTool)
}

/// <p>AC1: a person's Save adds a partner: it answers 201 with the partner's name as its id, its target in the change event's
/// triple and a read-back that matches, stores what was sent (a field left out stores an empty one, both contacts included),
/// and writes one audit row of OcuPilot's own that names the partner and carries no value.</p>
/// <p>Mutation (Rule 19): drop the <code>AuditRuntime</code> call from <method>OcuPilot.Port.InteropPort.PerformPartner</method>
/// -- the audit leg goes red.</p>
Method TestTheSaveAddsAPartnerAndAuditsItWithoutAValue()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertTrue('$IsObject(..Held(..#PARTNER)), "the partner is not held yet")
    Set tBody = {"Name": (..#PARTNER), "Description": (..#VALUEMARKER), "PrimaryContact": "Pat", "PrimaryPhone": "555-0100", "AlternativeNotes": "kept"}
    Set tText = ..Save(tBody, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#PARTNER _ "|business-partner|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the partner's name as its id, its entity type and a matching read-back")
    Set tHeld = ..Held(..#PARTNER)
    Do $$$AssertTrue($IsObject(tHeld), "the partner is held")
    If $IsObject(tHeld) {
        Do $$$AssertEquals(tHeld.Description _ "|" _ tHeld.PrimaryContact _ "|" _ tHeld.PrimaryPhone _ "|" _ tHeld.AlternativeNotes _ "|" _ tHeld.PrimaryEmail _ "|" _ tHeld.AlternativeContact, ..#VALUEMARKER _ "|Pat|555-0100|kept||", "with the fields it was sent and the others empty")
    }
    Do $$$AssertEquals(..Audited(tSince, "add", ..#PARTNER, .tData), 1, "one audit row of OcuPilot's own for the add")
    Do $$$AssertTrue((tData [ ..#PARTNER) && (tData '[ ..#VALUEMARKER) && (tData '[ "555-0100"), "which names the partner and carries no value: " _ tData)
}

/// <p>AC1: the Save route answers JSON over the wire: 201 with the partner's id, its target and a matching read-back, and a held name
/// 409 with the envelope's code.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.PartnerSave.HandleCreate</method> answer 200 -- the status leg goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/business-partners?ns=USER"
    Set tBody = {"Name": (..#PARTNER), "Description": "wire"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, ..#PARTNER _ "|business-partner|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the partner's id, its target and a matching read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 409, "a held name is refused 409: " _ $Extract($Get(tRaw), 1, 300))
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tRefusal.code, "INTEROP.PARTNER.TAKEN", "with the envelope's code")
}

/// <p>AC1: a person's Edit and Remove answer 200 with the <code>updated</code> and <code>deleted</code> events: an Edit changes
/// the fields it sends and keeps the name, an empty value clears a field, the audit row names the fields it changed and no value,
/// and a Remove takes the partner and its contacts; a second Remove finds none.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformPartner</method> skip the assignment of
/// <code>AlternativeNotes</code> -- the Edit leg's read-back goes red.</p>
Method TestThePersonsEditAndRemoveWriteAndAuditWithoutAValue()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner", ..#PARTNER), "the probe partner is arranged")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Held(..#PARTNER)
    Set tValues = ..Values({"Description": (..#VALUEMARKER), "PrimaryContact": "Pat Primary", "PrimaryTitle": "Analyst", "PrimaryEmail": "pat@example.test", "PrimaryPhone": "555-0999", "PrimaryMobile": "555-0102", "PrimaryNotes": "Primary notes", "AlternativeContact": "Alex Alternative", "AlternativeTitle": "Lead", "AlternativeEmail": "alex@example.test", "AlternativePhone": "555-0201", "AlternativeMobile": "555-0202", "AlternativeNotes": ""})
    Set tText = ..Act("edit", ..#PARTNER, tValues, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Edit answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|business-partner|" _ ..#PARTNER _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event for the partner, whose read-back matches")
    Set tHeld = ..Held(..#PARTNER)
    Do $$$AssertTrue($IsObject(tBefore) && $IsObject(tHeld), "the partner is read before and after")
    If $IsObject(tHeld) {
        Do $$$AssertEquals(tHeld.Name _ "|" _ tHeld.Description _ "|" _ tHeld.PrimaryPhone _ "|" _ tHeld.AlternativeNotes _ "|" _ tHeld.AlternativeContact, ..#PARTNER _ "|" _ ..#VALUEMARKER _ "|555-0999||Alex Alternative", "the name is kept, the fields sent are stored and an empty one clears its field")
    }
    Do $$$AssertEquals(..Audited(tSince, "set", ..#PARTNER, .tData), 1, "one set row")
    Do $$$AssertTrue((tData [ "Description") && (tData [ "PrimaryPhone") && (tData [ "AlternativeNotes") && (tData '[ "PrimaryContact,") && (tData '[ ..#VALUEMARKER) && (tData '[ "555-0999"), "which names the fields it changed and none it left alone, with no value: " _ tData)
    Do $$$AssertEquals(..Act("edit", ..#PARTNER, tValues, .tAnswer), "200 ", "an Edit that changes nothing is accepted and calls nothing")
    Do $$$AssertEquals(..Audited(tSince, "set", ..#PARTNER, .tData), 1, "so it writes no second audit row")
    Set tText = ..Act("remove", ..#PARTNER, "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "deleted|business-partner", "as a deletion")
    Do $$$AssertTrue('$IsObject(..Held(..#PARTNER)), "the partner is gone")
    Do $$$AssertEquals(..Act("remove", ..#PARTNER, "", .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds none")
    Do $$$AssertEquals(..Audited(tSince, "remove", ..#PARTNER, .tData), 1, "one remove row")
    Do $$$AssertTrue((tData [ ..#PARTNER) && (tData '[ ..#VALUEMARKER), "naming the partner and carrying no trace of what it held: " _ tData)
}

/// <p>AC1: the agent's add of a partner, minted for the HTTP account and confirmed over HTTP, creates a partner that did not exist,
/// answers one envelope with a read-back that matches, is ledgered once and is audited with no value; an update minted for it and
/// then made impossible out of band (the partner is removed) closes target-changed with nothing written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ReadPartner</method> answer a row for a partner the namespace does not
/// hold -- the target-changed leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropPartnerAdd", ..ArgsFor(..#PARTNER, {"Description": (..#VALUEMARKER), "PrimaryContact": "Pat"}), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "business-partner|USER|" _ ..#PARTNER, "the target is the partner, by its name")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 0, "it is not destructive")
    Do $$$AssertTrue('$IsObject(..Held(..#PARTNER)), "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.businesspartners.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tHeld = ..Held(..#PARTNER)
    Do $$$AssertEquals($Select($IsObject(tHeld): tHeld.Description _ "|" _ tHeld.PrimaryContact, 1: ""), ..#VALUEMARKER _ "|Pat", "the partner is stored with what the proposal reviewed")
    Do $$$AssertEquals(..Audited(tSince, "add", ..#PARTNER, .tData), 1, "one audit row of OcuPilot's own")
    Do $$$AssertTrue(tData '[ ..#VALUEMARKER, "carrying no value: " _ tData)
    ; The update, and a partner removed out of band after the mint.
    Set tSC = ..Mint("InteropPartnerUpdate", ..ArgsFor(..#PARTNER, {"PrimaryContact": "Changed"}), .tSet, .tFault, .tSetTurn)
    Do $$$AssertStatusOK(tSC, "the update mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tSet)) Quit
    Do $ClassMethod(..#FIXTURE, "DropPartners", ..#PARTNER)
    Set tStatus = ..Confirm(tSet, .tAnswer, .tRaw)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue('$IsObject(..Held(..#PARTNER)), "and nothing was written: the partner stays gone")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSetTurn))
}

/// <p>AC1: the agent's update of a partner mints for the HTTP account with one row for each field it moves, an empty one included,
/// confirms over HTTP and is audited with the fields it changed and no value; its card shows no row for the name or for how many
/// items name the partner; items that start naming the partner after the mint do not close it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropPartnerUpdate.MergeUpdate</method> keep <code>NamedBy</code> in the
/// payload -- the leg that names the partner by an item after the mint goes red.</p>
Method TestTheAgentsUpdateConfirmsOverHttp()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner", ..#PARTNER), "the probe partner is arranged")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropPartnerUpdate", ..ArgsFor(..#PARTNER, {"Description": (..#VALUEMARKER), "PrimaryPhone": ""}), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the update mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""Description"",""before"":""Probe partner description"",""after"":""" _ ..#VALUEMARKER _ """},{""field"":""PrimaryPhone"",""before"":""555-0101"",""after"":""""}]", "its card shows the two fields it moves")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the update confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as an update, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.businesspartners.update"), 1, "ledgered once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tHeld = ..Held(..#PARTNER)
    Do $$$AssertEquals($Select($IsObject(tHeld): tHeld.Description _ "|" _ tHeld.PrimaryPhone _ "|" _ tHeld.PrimaryContact, 1: ""), ..#VALUEMARKER _ "||Pat Primary", "the two fields moved and the rest was kept")
    Do $$$AssertEquals(..Audited(tSince, "set", ..#PARTNER, .tData), 1, "one audit row of OcuPilot's own")
    Do $$$AssertTrue((tData [ "Description,PrimaryPhone") && (tData '[ ..#VALUEMARKER), "naming the two fields and carrying no value: " _ tData)
    Do $$$AssertEquals(..MintVerdict("InteropPartnerUpdate", ..ArgsFor(..#PARTNER, {"Description": (..#VALUEMARKER)}), .tReason), "TOOL.ARGUMENTS", "an update that restates what the partner holds, which changes nothing, is refused at the mint")
    ; An item that names the partner after the mint is no change the update reviewed.
    Set tSC = ..Mint("InteropPartnerUpdate", ..ArgsFor(..#PARTNER, {"PrimaryTitle": "Chief"}), .tNext, .tFault, .tNextTurn)
    Do $$$AssertStatusOK(tSC, "a second update mints")
    If '$IsObject($Get(tNext)) Quit
    Set tProbe = "OcuPilot.Test.ProductionProbe"
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Remove"), "no probe production is left from an earlier run")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Create"), "the probe production is made")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "AddItem", "OcuPilotProbe226Item", "OcuPilotProbe.Interop.Op", 1, 0, "BusinessPartner", ..#PARTNER, "Host"), "an item names the partner")
    Set tStatus = ..Confirm(tNext, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "and the second update still confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Remove"), "the probe production is removed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tNextTurn))
}

/// <p>AC1, AC6: the agent's remove of a partner is destructive and ships off: its card shows the partner's name, description and
/// both contacts' names as removed rows and says it cannot be restored; the confirm is refused while the tool's key is off and
/// removes the partner once it is on; a partner changed after the mint closes the confirm target-changed.</p>
/// <p>Mutation (Rule 19): turn the tool's baseline key on -- the refusal leg goes red.</p>
Method TestTheAgentsRemoveConfirmsOverHttp()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner", ..#PARTNER), "the probe partner is arranged")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        ; The baseline alone decides, whatever a stored policy holds: it ships the remove off.
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the stored policy is cleared")
        Set tSC = ..Mint("InteropPartnerRemove", ..ArgsFor(..#PARTNER), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.PARTNER.REMOVE|1", "its consequence says the partner and its contacts go, and it is destructive")
        Do $$$AssertTrue((tProposal.changed.%ToJSON() [ """field"":""Name""") && (tProposal.changed.%ToJSON() [ "Pat Primary") && (tProposal.changed.%ToJSON() [ "Alex Alternative") && (tProposal.changed.%ToJSON() [ """removed"":true"), "its card shows the partner's name, description and contacts as removed rows: " _ tProposal.changed.%ToJSON())
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertTrue($IsObject(..Held(..#PARTNER)), "and the partner is still there")
        Kill tSettings
        Set tSettings("interop.businesspartners.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        ; A field changed out of band after the mint closes the remove target-changed, and the partner stays.
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "DropPartners", ..#PARTNER), "the partner is replaced")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner", ..#PARTNER, {"Description": "movedOutOfBand"}), "by one that differs")
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "a partner changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertTrue($IsObject(..Held(..#PARTNER)), "and the partner is still there")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        Set tSC = ..Mint("InteropPartnerRemove", ..ArgsFor(..#PARTNER), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "a fresh remove mints")
        If '$IsObject($Get(tProposal)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the partner gone: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..LedgerCount(tTurn, "interop.businesspartners.remove"), 1, "ledgered once")
        Do $$$AssertTrue('$IsObject(..Held(..#PARTNER)), "the partner is gone")
        Do $$$AssertEquals(..Audited(tSince, "remove", ..#PARTNER, .tData), 1, "one audit row of OcuPilot's own")
        Do $$$AssertTrue((tData [ ..#PARTNER) && (tData '[ "movedOutOfBand"), "naming the partner and carrying no trace of what it held: " _ tData)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC1: a name of 255 characters and every field at exactly its vendor limit are saved and read back whole, so a limit below the
/// vendor's is caught as well as one above it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PartnerLimit</method> answer 255 for the description -- the Save of
/// the full description is refused and this goes red.</p>
Method TestAValueAtItsLimitIsSavedWhole()
{
    Set tName = ..#PARTNER _ $Translate($Justify("", 255 - $Length(..#PARTNER)), " ", "n")
    Set tFields = $ListFromString($Parameter(..#PORT, "PARTNERSETFIELDS"))
    Set tBody = {"Name": (tName)}
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
        Set tLimit = $Case(tField, "Description": 5000, "PrimaryNotes": 1000, "AlternativeNotes": 1000, "PrimaryPhone": 50, "PrimaryMobile": 50, "AlternativePhone": 50, "AlternativeMobile": 50, : 255)
        Do tBody.%Set(tField, $Translate($Justify("", tLimit), " ", "x"), "string")
    }
    Do $$$AssertEquals(..Save(tBody, .tAnswer), "201 ", "the partner with every value at its limit is added: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Set tHeld = ..Held(tName)
    Do $$$AssertTrue($IsObject(tHeld), "and held under its 255-character name")
    If '$IsObject(tHeld) Quit
    Set tWhole = 1
    For tI = 1:1:$ListLength(tFields) {
        If tHeld.%Get($List(tFields, tI)) '= tBody.%Get($List(tFields, tI)) Set tWhole = 0
    }
    Do $$$AssertTrue(tWhole, "with every field read back whole")
}

/// <p>AC1: every partner write has a script form (AD-59) the person can run in a terminal, each name and value one string literal in
/// which a quote or a control character cannot end the literal, with the vendor call of its kind; the read has none.</p>
/// <p>Mutation (Rule 19): render the description unquoted in <method>OcuPilot.Port.InteropPort.PartnerSnippet</method> -- this goes
/// red.</p>
Method TestEveryPartnerWriteRendersItsScript()
{
    Set tPort = ..#PORT
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "O""x" _ $Char(10) _ "n"
    Set tBody = {"Description": ("d""es" _ $Char(9) _ "c"), "PrimaryPhone": "555"}
    Set tName = """O""""x""_$Char(10)_""n"""
    Set tDescription = """d""""es""_$Char(9)_""c"""
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "BusinessPartners", "PARTNER"), "", "the read has no script form")
    For tCase = $ListBuild("ADDPARTNER", "##class(Ens.Config.BusinessPartner).%New()", "tPartner.PartnerName = " _ tName), $ListBuild("SETPARTNER", "##class(Ens.Config.BusinessPartner).%OpenId(" _ tName _ ", 4)", "tPartner.PrimaryContact.PhoneNumber = ""555"""), $ListBuild("REMOVEPARTNER", "##class(Ens.Config.BusinessPartner).%DeleteId(" _ tName _ ")", "") {
        Set tType = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "BusinessPartners", tType), "objectscript", tType _ " has a script form")
        Set tSteps = $ClassMethod(tPort, "Snippet", "BusinessPartners", tType, .tQuery, tBody)
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 2)), tType _ ": it switches and makes the vendor's call: " _ tText)
        If $List(tCase, 3) '= "" Do $$$AssertTrue(tText [ $List(tCase, 3), tType _ ": with the name or phone as one literal")
        If tType '= "REMOVEPARTNER" Do $$$AssertTrue(tText [ ("tPartner.Description = " _ tDescription), tType _ ": and the description is one string literal")
        If tType = "REMOVEPARTNER" Do $$$AssertTrue(tText '[ "Description", tType _ ": a remove carries no field")
    }
}

/// <p>AC1: the agent's reviewed field lists for a business partner name exactly the port's thirteen settable fields (and the name for
/// a create), and the partner precondition codes are the four refusals the tools' own lists hold.</p>
/// <p>Mutation (Rule 19): misspell one field in the update list of <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>
/// -- this goes red.</p>
Method TestTheReviewedFieldListsAndPreconditionCodesAreTheTools()
{
    Set tFields = $Parameter(..#PORT, "PARTNERSETFIELDS")
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    Do $$$AssertEquals($ListToString($ClassMethod(tProhibited, "PermittedChangeFields", "business-partner")), tFields, "an update may change the thirteen fields and no other")
    Do $$$AssertEquals($ListToString($ClassMethod(tProhibited, "PermittedCreateFields", "business-partner")), "Name," _ tFields, "a create may carry the name and the thirteen")
    Set tCodes = $ListToString($ClassMethod("OcuPilot.Api.InteropError", "PartnerPreconditionCodes"))
    Do $$$AssertEquals(tCodes, "INTEROP.PARTNER.TAKEN,INTEROP.PARTNER.NAMECASE,INTEROP.PARTNER.NAMED,INTEROP.PARTNER.SOURCECONTROL", "the precondition codes are those a partner's fresh read answers")
    For tTool = "InteropPartnerAdd", "InteropPartnerUpdate", "InteropPartnerRemove" {
        Set tDeclared = $ListFromString($Parameter("OcuPilot.Screen.Tool." _ tTool, "PRECONDITIONCODES"))
        Set tWithin = 1
        For tI = 1:1:$ListLength(tDeclared) {
            If ($List(tDeclared, tI) '= "INTEROP.NAMESPACE") && '$ListFind($ClassMethod("OcuPilot.Api.InteropError", "PartnerPreconditionCodes"), $List(tDeclared, tI)) Set tWithin = 0
        }
        Do $$$AssertTrue(tWithin, tTool _ " declares only codes the partner list names")
    }
}

/// <p>AC4 (Integration): Story 20.5's Business partners read -- the screen's read route over the wire and the read tool
/// <code>interop.businesspartners.read</code> -- lists a partner added through the Save with its fields, then lists the values an
/// Edit changed, then no longer lists the partner once it is removed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformPartner</method> store an empty <code>Description</code> on an
/// add -- the first listing goes red.</p>
Method TestTheBusinessPartnersReadListsTheAddedChangedAndRemovedPartner()
{
    Set tBody = {"Name": (..#PARTNER), "Description": "first description", "PrimaryContact": "Pat", "AlternativeEmail": "alex@example.test"}
    Do $$$AssertEquals(..Save(tBody, .tAnswer), "201 ", "the partner is added: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Set tRow = ..ListedRow()
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.Description _ "|" _ tRow.PrimaryContact _ "|" _ tRow.AlternativeEmail _ "|" _ tRow.Name, 1: "unlisted"), "first description|Pat|alex@example.test|" _ ..#PARTNER, "both reads list it with its fields")
    Do $$$AssertEquals(..Act("edit", ..#PARTNER, ..Values({"Description": "second description", "PrimaryContact": "Pat", "AlternativeEmail": "alex@example.test", "PrimaryPhone": "555-0100"}), .tAnswer), "200 ", "the partner is edited")
    Set tRow = ..ListedRow()
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.Description _ "|" _ tRow.PrimaryPhone, 1: "unlisted"), "second description|555-0100", "both reads list the changed values")
    Do $$$AssertEquals(..Act("remove", ..#PARTNER, "", .tAnswer), "200 ", "the partner is removed")
    Do $$$AssertEquals($Select($IsObject(..ListedRow()): "listed", 1: "unlisted"), "unlisted", "and neither read lists it any more")
}

/// <p>The row of the probe partner as the screen's read route answers it, after checking the read tool answers the same row, or
/// <code>""</code> when either does not list it.</p>
ClassMethod ListedRow() As %DynamicObject
{
    Do $ClassMethod(..#CONTROL, "Call", "GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tAnswer)
    Set tScreenRow = ..RowIn($Select($IsObject(tAnswer): tAnswer.%Get("rows"), 1: ""))
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.businesspartners.read", .tTool)
    Set tToolRow = ""
    If $IsObject($Get(tTool)) {
        Do ##class(OcuPilot.Kernel.Scope).Set("USER")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tHttp, .tFault)
        If +$Get(tHttp) = 200 Set tToolRow = ..RowIn(tResult.%Get("rows"))
    }
    If $IsObject(tScreenRow) && $IsObject(tToolRow) && (tScreenRow.%ToJSON() '= tToolRow.%ToJSON()) Quit {"error": "the screen's row and the tool's row differ"}
    Quit $Select($IsObject(tScreenRow) && $IsObject(tToolRow): tScreenRow, 1: "")
}

/// <p>The probe partner's row in <var>pRows</var>, or <code>""</code>.</p>
ClassMethod RowIn(pRows As %DynamicArray) As %DynamicObject
{
    Set tHit = ""
    If '$IsObject(pRows) Quit tHit
    For tI = 0:1:pRows.%Size() - 1 {
        If pRows.%Get(tI).Name = ..#PARTNER Set tHit = pRows.%Get(tI) Quit
    }
    Quit tHit
}

}
