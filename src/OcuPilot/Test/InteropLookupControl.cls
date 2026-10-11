/// <p>Pins Story 20.5's writes end to end against probe lookup tables in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53,
/// AD-54, AD-55, AD-58, AD-62): a person's Save creates a table with its first entry; a person's row actions set and remove an
/// entry and delete a table; and the agent's four tools mint and confirm over HTTP. Each answers a read-back verdict and the
/// change event's triple, writes one audit row of OcuPilot's own (<code>ConfigChange</code>) that carries no value, and a table
/// changed out of band after the mint closes the confirm target-changed. Removing a table's last entry removes the table.</p>
/// <p>It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>. <b>What it needs from the
/// environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It starts no production and removes every table it creates.</p>
Class OcuPilot.Test.InteropLookupControl Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter TABLE = "OcuProbe205Control";

Parameter VALUEMARKER = "OcuValueMarker205";

Parameter ENTRYSCREEN = "/screens/interop.lookupentries";

Parameter TABLESCREEN = "/screens/interop.lookuptables";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupControl writes probe lookup tables in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe tables are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The composite id of <var>pKey</var> in <var>pTable</var>.</p>
ClassMethod Id(pTable As %String, pKey As %String) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pTable, pKey))
}

/// <p>One row action on <var>pScreen</var> as <code>status code</code>, the answer in <var>pAnswer</var>. <var>pValue</var> is
/// the dialog's value when it is not <code>$Char(0)</code>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValue As %String, Output pAnswer) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    If pValue '= $Char(0) Do tBody.%Set("values", {"Value": (pValue)})
    Do $ClassMethod(..#CONTROL, "Call", "POST", pScreen _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The person's Save of an entry as <code>status code</code>, the answer in <var>pAnswer</var>. <var>pValue</var> is left out
/// of the body when it is <code>$Char(0)</code>.</p>
ClassMethod Save(pTable As %String, pKey As %String, pValue As %String, Output pAnswer) As %String
{
    Set tBody = {}
    Do tBody.%Set("Table", pTable, "string")
    Do tBody.%Set("Key", pKey, "string")
    If pValue '= $Char(0) Do tBody.%Set("Value", pValue, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/interop/lookup-entries", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>How many <code>ConfigChange</code> rows since <var>pSince</var> record <var>pVerb</var> of table <var>pTable</var>, and the
/// last such row's data in <var>pData</var>.</p>
ClassMethod Audited(pSince As %String, pVerb As %String, pTable As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", """table"":""" _ pTable _ """", .pData, """verb"":""" _ pVerb _ """")
}

/// <p>The arguments of a call naming <var>pTable</var> and <var>pKey</var>, with <var>pValue</var> when it is not
/// <code>$Char(0)</code>.</p>
ClassMethod ArgsFor(pTable As %String, pKey As %String, pValue As %String = {$Char(0)}) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Table", pTable, "string")
    Do tArgs.%Set("Key", pKey, "string")
    If pValue '= $Char(0) Do tArgs.%Set("Value", pValue, "string")
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

/// <p>AC2: a person's Save creates a table with its first entry and adds to a held one: each answers 201 with the entry's id,
/// its target in the change event's triple and a read-back that matches, stores what was sent (an omitted value stores an empty
/// one), and writes one audit row of OcuPilot's own that names the table and the entry and carries no value.</p>
/// <p>Mutation (Rule 19): drop the <code>AuditRuntime</code> call from <method>OcuPilot.Port.InteropPort.PerformLookup</method>
/// -- the audit leg goes red.</p>
Method TestTheSaveCreatesATableWithItsFirstEntry()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Exists", ..#TABLE), 0, "the table does not exist yet")
    Set tText = ..Save(..#TABLE, "first", ..#VALUEMARKER, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): $Translate(tAnswer.id, $Char(1), "~") _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), ..#TABLE _ "~first|lookup-entry|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the entry's id, its entity type and a matching read-back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Entries", ..#TABLE), "first=" _ ..#VALUEMARKER, "the table was created with its first entry")
    Do $$$AssertEquals(..Save(..#TABLE, "second", $Char(0), .tAnswer), "201 ", "a second Save adds to the held table, with no value")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Entries", ..#TABLE), "first=" _ ..#VALUEMARKER _ ";second=", "an omitted value stores an empty one")
    Do $$$AssertEquals(..Audited(tSince, "add", ..#TABLE, .tData), 2, "one audit row of OcuPilot's own for each add")
    Do $$$AssertTrue((tData [ ..#TABLE) && (tData '[ ..#VALUEMARKER), "which names the table and carries no value: " _ tData)
}

/// <p>AC2: <code>POST /interop/lookup-entries</code> answers over the wire as JSON: 201 with the entry's id, its target and its
/// read-back, and a held key 409 with the envelope's code, each as the test account.</p>
/// <p>Mutation (Rule 19): answer the Save's 201 as text -- the content-type leg goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/lookup-entries?ns=USER"
    Set tBody = {"Table": (..#TABLE), "Key": "wire", "Value": "w"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, "lookup-entry|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the entry's target and a matching read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 409, "a held key is refused 409: " _ $Extract($Get(tRaw), 1, 300))
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tRefusal.code, "INTEROP.LOOKUP.TAKEN", "with the envelope's code")
}

/// <p>AC2, AC3: a person's row actions write the same way: Set value answers 200 with the <code>updated</code> event and stores
/// the value, an empty one too; Remove answers 200 with <code>deleted</code>, and removing the last entry removes the table;
/// Delete on the tables list removes a table and every entry in it; each is audited with no value, and none leaves a table
/// behind.</p>
/// <p>Mutation (Rule 19): make <code>REMOVEENTRY</code> in <method>OcuPilot.Port.InteropPort.PerformLookup</method> call
/// <code>%ClearTable</code> -- the first remove leg goes red.</p>
Method TestThePersonsRowActionsSetRemoveAndDeleteWriteAndAuditWithoutAValue()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "a", "one")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "b", "two")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act(..#ENTRYSCREEN, "set", ..Id(..#TABLE, "a"), ..#VALUEMARKER, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Set value answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ $Translate(tAnswer.target.id, $Char(1), "~"), 1: ""), "updated|lookup-entry|" _ ..#TABLE _ "~a", "publishing the updated event for the entry")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "a=" _ ..#VALUEMARKER _ ";b=two", "the value is stored")
    Do $$$AssertEquals(..Act(..#ENTRYSCREEN, "set", ..Id(..#TABLE, "a"), "", .tAnswer), "200 ", "an empty value is accepted")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "a=;b=two", "and stored")
    Do $$$AssertEquals(..Act(..#ENTRYSCREEN, "set", ..Id(..#TABLE, "a"), $Char(0), .tAnswer), "400 TOOL.ARGUMENTS", "a set that sends no value is refused")
    Set tText = ..Act(..#ENTRYSCREEN, "remove", ..Id(..#TABLE, "a"), $Char(0), .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action, 1: ""), "deleted", "as a deletion")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "b=two", "the entry is gone and the table is kept")
    Do $$$AssertEquals(..Act(..#ENTRYSCREEN, "remove", ..Id(..#TABLE, "b"), $Char(0), .tAnswer), "200 ", "the last entry's Remove answers 200")
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "and takes the table with it")
    Do $$$AssertEquals(..Act(..#ENTRYSCREEN, "remove", ..Id(..#TABLE, "b"), $Char(0), .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds neither")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "x", "1")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "y", "2")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "z", "3")
    Set tText = ..Act(..#TABLESCREEN, "delete", ..#TABLE, $Char(0), .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Delete answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "deleted|lookup-table|" _ ..#TABLE, "publishing the deleted event for the table")
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "the table and every entry are gone")
    Do $$$AssertEquals(..Act(..#TABLESCREEN, "delete", ..#TABLE, $Char(0), .tAnswer), "404 PORT.NOTFOUND", "a second Delete finds no table")
    Do $$$AssertEquals(..Audited(tSince, "set", ..#TABLE, .tData), 2, "two set rows")
    Do $$$AssertEquals(..Audited(tSince, "remove", ..#TABLE, .tData), 2, "two remove rows")
    Do $$$AssertEquals(..Audited(tSince, "delete", ..#TABLE, .tData), 1, "one delete row")
    Do $$$AssertTrue((tData [ ..#TABLE) && (tData [ """entries"":3"), "which counts the entries it took: " _ tData)
    Do $$$AssertTrue(tData '[ ..#VALUEMARKER, "and no audit row carries a value")
}

/// <p>AC2: the agent's add of an entry, minted for the HTTP account and confirmed over HTTP, creates a table that did not exist,
/// answers one envelope with a read-back that matches, is ledgered once and is audited with no value; a set minted for the entry
/// and then made impossible out of band (the entry is removed) closes target-changed with nothing written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ReadLookupEntry</method> answer a row for an entry the table
/// does not hold -- the target-changed leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Set tFixture = ..#FIXTURE
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropLookupEntryAdd", ..ArgsFor(..#TABLE, "k1", ..#VALUEMARKER), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ $Translate(tProposal.target.id, $Char(1), "~"), "lookup-entry|USER|" _ ..#TABLE _ "~k1", "the target is the entry, by its composite id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 0, "it is not destructive")
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "nothing is written by the mint")
    Set tSC = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tSC, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.lookupentries.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "k1=" _ ..#VALUEMARKER, "the table is created with the entry")
    Do $$$AssertEquals(..Audited(tSince, "add", ..#TABLE, .tData), 1, "one audit row of OcuPilot's own")
    Do $$$AssertTrue(tData '[ ..#VALUEMARKER, "carrying no value: " _ tData)
    ; The set, and a value moved out of band after the mint.
    Set tSC = ..Mint("InteropLookupEntrySet", ..ArgsFor(..#TABLE, "k1", "changed"), .tSet, .tFault, .tSetTurn)
    Do $$$AssertStatusOK(tSC, "the set mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tSet)) Quit
    Do $$$AssertEquals(tSet.changed.%ToJSON(), "[{""field"":""Value"",""before"":""" _ ..#VALUEMARKER _ """,""after"":""changed""}]", "its card shows one Value row")
    Do $ClassMethod(tFixture, "Remove", ..#TABLE, "k1")
    Set tSC = ..Confirm(tSet, .tAnswer, .tRaw)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tSC), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "and nothing was written: the entry and its table stay gone")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSetTurn))
}

/// <p>AC2: the agent's set of an entry mints for the HTTP account with one Value row, confirms over HTTP and is audited with
/// no value; an empty value is allowed; a set of the value the entry holds is refused <code>SAME</code> at the mint.</p>
Method TestTheAgentsSetConfirmsOverHttp()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "k1", "old")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropLookupEntrySet", ..ArgsFor(..#TABLE, "k1", "old"), .tSame, .tFault, .tSameTurn)
    Do $$$AssertTrue($IsObject($Get(tFault)) && ('$IsObject($Get(tSame))), "a set of the value the entry holds is refused at the mint: " _ $Select($IsObject($Get(tFault)): tFault.code, 1: "minted"))
    Set tSC = ..Mint("InteropLookupEntrySet", ..ArgsFor(..#TABLE, "k1", ""), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "a set to an empty value mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""Value"",""before"":""old"",""after"":""""}]", "its card shows the value moving to empty")
    Set tSC = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tSC, 200, "the set confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as an update, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.lookupentries.set"), 1, "ledgered once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "k1=", "the value is empty")
    Do $$$AssertEquals(..Audited(tSince, "set", ..#TABLE, .tData), 1, "one audit row of OcuPilot's own")
}

/// <p>AC2: the agent's remove of an entry is destructive and ships off: its card shows the entry's key and value as removed
/// rows and says the table goes with its last entry; the confirm is refused while the tool's key is off and removes the entry once
/// it is on; removing the last entry removes the table.</p>
/// <p>Mutation (Rule 19): turn the tool's baseline key on -- the refusal leg goes red.</p>
Method TestTheAgentsRemoveConfirmsOverHttp()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "only", "valueHeld")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Set tSC = ..Mint("InteropLookupEntryRemove", ..ArgsFor(..#TABLE, "only"), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.LOOKUP.REMOVE|1", "its consequence says the table goes with its last entry, and it is destructive")
        Do $$$AssertTrue((tProposal.changed.%ToJSON() [ """field"":""Key""") && (tProposal.changed.%ToJSON() [ "valueHeld") && (tProposal.changed.%ToJSON() [ """removed"":true"), "its card shows the key and value as removed rows: " _ tProposal.changed.%ToJSON())
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertNotEquals(tStatus, 200, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "only=valueHeld", "and the entry is still there")
        Kill tSettings
        Set tSettings("interop.lookupentries.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        ; A value changed out of band after the mint closes the remove target-changed, and the entry stays.
        Do $ClassMethod(tFixture, "Put", ..#TABLE, "only", "movedOutOfBand")
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "an entry changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "only=movedOutOfBand", "and the entry is still there")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        Set tSC = ..Mint("InteropLookupEntryRemove", ..ArgsFor(..#TABLE, "only"), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "a fresh remove mints")
        If '$IsObject($Get(tProposal)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the entry gone: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..LedgerCount(tTurn, "interop.lookupentries.remove"), 1, "ledgered once")
        Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "the last entry took the table with it")
        Do $$$AssertEquals(..Audited(tSince, "remove", ..#TABLE, .tData), 1, "one audit row of OcuPilot's own")
        Do $$$AssertTrue(tData '[ "valueHeld", "carrying no value: " _ tData)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC3: the agent's delete of a table is destructive and ships off: its card shows the table's name and entry count as
/// removed rows; a table changed after the mint refuses the confirm target-changed with every entry still there; the confirm
/// removes the table and every entry once the key is on and the table is as reviewed.</p>
/// <p>Mutation (Rule 19): drop <code>Modified</code> from the tool's fingerprint subject -- the target-changed leg goes red
/// when the change leaves the count alone.</p>
Method TestTheAgentsDeleteConfirmsOverHttp()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "a", "1")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "b", "2")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Kill tSettings
        Set tSettings("interop.lookuptables.delete") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        Set tArgs = {}
        Do tArgs.%Set("Name", ..#TABLE, "string")
        Set tSC = ..Mint("InteropLookupTableDelete", tArgs, .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the delete mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.id, "lookup-table|" _ ..#TABLE, "the target is the table, by its name")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.LOOKUP.DELETE|1", "its consequence says every entry goes, and it is destructive")
        Do $$$AssertTrue((tProposal.changed.%ToJSON() [ """field"":""Entries""") && (tProposal.changed.%ToJSON() [ """before"":""2"""), "its card shows the entry count: " _ tProposal.changed.%ToJSON())
        ; A change that leaves the count alone: the stamp moves.
        Hang 0.01
        Do $ClassMethod(tFixture, "Put", ..#TABLE, "a", "changed")
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "a table changed after the mint closes the proposal target-changed")
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "a=changed;b=2", "and every entry is still there")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        Set tSC = ..Mint("InteropLookupTableDelete", tArgs, .tFresh, .tFault, .tFreshTurn)
        Do $$$AssertStatusOK(tSC, "a fresh delete mints")
        If '$IsObject($Get(tFresh)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tStatus = ..Confirm(tFresh, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "and confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, 1: ""), "1|deleted", "as a deletion, marked (AD-15)")
        Do $$$AssertEquals(..LedgerCount(tFreshTurn, "interop.lookuptables.delete"), 1, "ledgered once")
        Do $$$AssertEquals($ClassMethod(tFixture, "Exists", ..#TABLE), 0, "the table and every entry are gone")
        Do $$$AssertEquals(..Audited(tSince, "delete", ..#TABLE, .tData), 1, "one audit row of OcuPilot's own")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tFreshTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the delete leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod(..#CONTROL, "LedgerCount", pTurn, pTool)
}

}
