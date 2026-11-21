/// <p>Pins Story 24.15's writes end to end against probe system default settings in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53,
/// AD-54, AD-55, AD-58, AD-59, AD-62): a person's Save adds a setting, their Edit and Remove change and remove one, and the agent's three
/// tools mint and confirm over HTTP. Each answers a read-back verdict and the change event's triple, and what it stored reads back from
/// <code>Ens.Config.DefaultSettings</code> exactly as sent; the vendor records its own audit row for each insert, update and delete, and
/// OcuPilot records none of its own beside it; a setting changed out of band after the mint closes the confirm target-changed. Each write has
/// a script form, and the System default settings read lists what each caller wrote.</p>
/// <p>It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>. <b>What it needs from the environment:</b> an
/// interoperability-enabled <code>USER</code> namespace, the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>. It starts no production and removes every setting it creates.</p>
Class OcuPilot.Test.InteropDefaultSettingControl Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PORT = "OcuPilot.Port.InteropPort";

/// <p>The probe production every setting names, which the namespace never holds.</p>
Parameter PRODUCTION = "OcuProbe2415.Production";

Parameter SETTING = "ArchiveIO";

Parameter VALUEMARKER = "OcuValueMarker2415";

Parameter SCREEN = "/screens/interop.defaultsettings";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropDefaultSettingControl writes probe system default settings in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe settings are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION), 0, "and none survives in USER")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The composite id of the probe production's setting <var>pSetting</var>, its item and host class <code>*</code>.</p>
ClassMethod IdFor(pSetting As %String = {..#SETTING}) As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PRODUCTION, "*", "*", pSetting))
}

/// <p>The setting <var>pSetting</var> as the port's single-setting read answers it, or <code>""</code> when it is not held.</p>
ClassMethod Held(pSetting As %String = {..#SETTING}) As %DynamicObject
{
    Kill tQuery
    Set tQuery("id") = ..IdFor(pSetting)
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "DefaultSettings", "DEFAULTSETTING", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select(tHttp = 200: tRow, 1: "")
}

/// <p>One person's row action on the System default settings screen as <code>status code</code>, the answer in <var>pAnswer</var>.
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

/// <p>The person's Save of a setting as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer) As %String
{
    Do $ClassMethod(..#CONTROL, "Call", "POST", "/interop/default-settings", pBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The body of a Save of the probe setting <var>pSetting</var> with <var>pValue</var>, <var>pDescription</var> and the flag.</p>
ClassMethod SaveBody(pSetting As %String, pValue As %String, pDescription As %String = "", pDeployable As %Boolean = 0) As %DynamicObject
{
    Set tBody = {"Production": (..#PRODUCTION), "Item": "*", "HostClass": "*", "Setting": (pSetting), "Value": (pValue), "Description": (pDescription)}
    Do tBody.%Set("Deployable", ''pDeployable, "boolean")
    Quit tBody
}

/// <p>The vendor's own audit rows since <var>pSince</var> whose data begins with the words <var>pWords</var> and names the probe
/// production and the setting <var>pSetting</var>, with the last row's data in <var>pData</var>.</p>
ClassMethod VendorRows(pSince As %String, pWords As %String, pSetting As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ModifyDefaultSetting", pWords, .pData, "SettingName: " _ pSetting, "%Ensemble", "%Production")
}

/// <p>How many rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> name the probe setting.</p>
ClassMethod OwnRows(pSince As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", ..#SETTING)
}

/// <p>The arguments of a call naming the probe setting <var>pSetting</var>, with each member of <var>pSet</var> beside it.</p>
ClassMethod ArgsFor(pSetting As %String, pSet As %DynamicObject = "") As %DynamicObject
{
    Set tArgs = {"Production": (..#PRODUCTION), "Item": "*", "HostClass": "*", "Setting": (pSetting)}
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

/// <p>Confirm <var>pProposal</var> over HTTP: the status, and the single envelope's answer in <var>pAnswer</var>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pAnswer, Output pRaw) As %Integer
{
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", pProposal.proposalId, .tStatus, .pRaw, .pAnswer)
    Quit tStatus
}

/// <p>How many ledger rows the turn <var>pTurn</var> holds for the tool <var>pTool</var>.</p>
ClassMethod LedgerCount(pTurn As %String, pTool As %String) As %Integer
{
    Quit $ClassMethod(..#CONTROL, "LedgerCount", pTurn, pTool)
}

/// <p>AC1: a person's Save adds a setting: it answers 201 with the composite key as its id, its target in the change event's triple and a
/// read-back that matches, stores exactly what was sent, and the vendor records one insert row for it with OcuPilot recording none of its
/// own.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformDefaultSetting</method> store <code>Description</code> empty on an
/// add -- the stored-text leg goes red.</p>
Method TestTheSaveAddsASettingThatReadsBackExactly()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertTrue('$IsObject(..Held()), "the setting is not held yet")
    Set tText = ..Save(..SaveBody(..#SETTING, "1", "probe description", 1), .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save answers 201: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, 1: ""), ..IdFor() _ "|default-setting|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the key as its id, its entity type and a matching read-back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), "1|probe description|1", "the class holds exactly what was sent")
    Do $$$AssertEquals(..VendorRows(tSince, "Create System Default Setting", ..#SETTING, .tData), 1, "the vendor records one insert row")
    Do $$$AssertEquals(..OwnRows(tSince), 0, "and OcuPilot records none of its own beside it")
}

/// <p>AC1: the Save route answers JSON over the wire: 201 with the key's id, its target and a matching read-back, and a key the namespace
/// holds 409 with <code>INTEROP.DEFAULTSETTING.TAKEN</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Interop.DefaultSettingSave.IdOf</method> answer an id of three parts -- this goes red.</p>
Method TestTheSaveRouteAnswersJsonOverTheWire()
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/interop/default-settings?ns=USER"
    Set tBody = ..SaveBody(..#SETTING, "wire")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the Save answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, ..IdFor() _ "|default-setting|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with the key's id, its target and a matching read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 409, "a held key is refused 409: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tRaw).code, "INTEROP.DEFAULTSETTING.TAKEN", "with the envelope's code")
}

/// <p>AC1: a person's Edit and Remove answer 200 with the <code>updated</code> and <code>deleted</code> events: an Edit that carries the value
/// alone changes it and keeps the description and the flag, one that carries the flag alone changes it, an empty description clears it, and a
/// Remove takes the setting; the vendor records an update row for each change and a delete row for the removal, none carrying a value
/// OcuPilot added.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PerformDefaultSetting</method> skip the assignment of
/// <code>Deployable</code> -- the flag leg goes red.</p>
Method TestThePersonsEditAndRemoveChangeOnlyWhatTheyCarry()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutDefault", ..#PRODUCTION, "*", "*", ..#SETTING, "1", "kept description", 1), "the probe setting is arranged")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act("edit", ..IdFor(), {"Value": (..#VALUEMARKER)}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "an Edit answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|default-setting|" _ ..IdFor() _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event for the setting, whose read-back matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), ..#VALUEMARKER _ "|kept description|1", "the value changed and the description and the flag are kept")
    Do $$$AssertEquals(..VendorRows(tSince, "Modify System Default Setting", ..#SETTING, .tData), 1, "the vendor records one update row")
    Do $$$AssertEquals(..Act("edit", ..IdFor(), {"Deployable": "false"}, .tAnswer), "200 ", "an Edit that carries the flag alone answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), ..#VALUEMARKER _ "|kept description|0", "the flag changed and the rest is kept")
    Do $$$AssertEquals(..Act("edit", ..IdFor(), {"Description": ""}, .tAnswer), "200 ", "an Edit that sends an empty description answers 200")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), ..#VALUEMARKER _ "||0", "and the description is cleared")
    Do $$$AssertEquals(..Act("edit", ..IdFor(), {"Description": ""}, .tAnswer), "200 ", "an Edit that changes nothing is accepted and calls nothing")
    Do $$$AssertEquals(..VendorRows(tSince, "Modify System Default Setting", ..#SETTING, .tData), 3, "so the vendor records an update row for each of the three changes and no more")
    Set tText = ..Act("remove", ..IdFor(), "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "Remove answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "deleted|default-setting", "as a deletion")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), "<absent>", "the setting is gone from the class")
    Do $$$AssertEquals(..Act("remove", ..IdFor(), "", .tAnswer), "404 PORT.NOTFOUND", "a second Remove finds none")
    Do $$$AssertEquals(..VendorRows(tSince, "Delete System Default Setting", ..#SETTING, .tData), 1, "the vendor records one delete row")
    Do $$$AssertEquals(..OwnRows(tSince), 0, "and OcuPilot records none of its own")
}

/// <p>AC1: the agent's add of a setting, minted for the HTTP account and confirmed over HTTP, creates a setting that did not exist, answers
/// one envelope with a read-back that matches, is ledgered once and marked (AD-15); an update minted for it and then made impossible out of
/// band (the setting is removed) closes target-changed with nothing written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ReadDefaultSetting</method> answer a row for a key the namespace does not
/// hold -- the target-changed leg goes red.</p>
Method TestTheAgentsAddConfirmsOverHttp()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropDefaultSettingAdd", ..ArgsFor(..#SETTING, {"Value": (..#VALUEMARKER), "Description": "agent description", "Deployable": true}), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "default-setting|USER|" _ ..IdFor(), "the target is the setting, by its composite key")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0, 0, "it is not destructive")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence"), "INTEROP.DEFAULTSETTING.PENDING", "its consequence says a running production uses the value once it is updated")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), "<absent>", "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the add confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|created|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as a creation, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.defaultsettings.add"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), ..#VALUEMARKER _ "|agent description|1", "the class holds what the proposal reviewed")
    Do $$$AssertEquals(..VendorRows(tSince, "Create System Default Setting", ..#SETTING, .tData), 1, "the vendor records one insert row")
    ; The update, and a setting removed out of band after the mint.
    Set tSC = ..Mint("InteropDefaultSettingUpdate", ..ArgsFor(..#SETTING, {"Value": "changed"}), .tSet, .tFault, .tSetTurn)
    Do $$$AssertStatusOK(tSC, "the update mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tSet)) Quit
    Do $ClassMethod(..#FIXTURE, "DropDefaults", ..#PRODUCTION)
    Set tStatus = ..Confirm(tSet, .tAnswer, .tRaw)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), "<absent>", "and nothing was written: the setting stays gone")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSetTurn))
}

/// <p>AC1: the agent's update of a setting mints with one row for each field it moves, an empty one included, confirms over HTTP and is
/// ledgered once and marked; it restates nothing, since a call that changes nothing is refused at the mint.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropDefaultSettingUpdate.SettableFields</method> drop <code>Description</code>
/// -- the card leg goes red.</p>
Method TestTheAgentsUpdateConfirmsOverHttp()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutDefault", ..#PRODUCTION, "*", "*", ..#SETTING, "1", "before description", 0), "the probe setting is arranged")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Mint("InteropDefaultSettingUpdate", ..ArgsFor(..#SETTING, {"Value": (..#VALUEMARKER), "Description": ""}), .tProposal, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the update mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""Value"",""before"":""1"",""after"":""" _ ..#VALUEMARKER _ """},{""field"":""Description"",""before"":""before description"",""after"":""""}]", "its card shows the two fields it moves")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the update confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "as an update, marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.defaultsettings.update"), 1, "ledgered once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), ..#VALUEMARKER _ "||0", "the two fields moved and the flag was kept")
    Do $$$AssertEquals(..VendorRows(tSince, "Modify System Default Setting", ..#SETTING, .tData), 1, "the vendor records one update row")
    Set tSC = ..Mint("InteropDefaultSettingUpdate", ..ArgsFor(..#SETTING, {"Value": (..#VALUEMARKER)}), .tSame, .tFault, .tSameTurn)
    Do $$$AssertTrue('$IsObject($Get(tSame)), "an update that restates what the setting holds, which changes nothing, is refused at the mint")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSameTurn))
}

/// <p>AC1, AC6: the agent's remove of a setting is destructive and ships off: its card shows the setting's name, value and description as
/// removed rows and says what removing it does; the confirm is refused while the tool's key is off and removes the setting once it is on; a
/// setting changed after the mint closes the confirm target-changed.</p>
/// <p>Mutation (Rule 19): turn the tool's baseline key on -- the refusal leg goes red.</p>
Method TestTheAgentsRemoveConfirmsOverHttp()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutDefault", ..#PRODUCTION, "*", "*", ..#SETTING, "1", "removal description", 0), "the probe setting is arranged")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        ; The baseline alone decides, whatever a stored policy holds: it ships the remove off.
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the stored policy is cleared")
        Set tSC = ..Mint("InteropDefaultSettingRemove", ..ArgsFor(..#SETTING), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.DEFAULTSETTING.REMOVE|1", "its consequence says the items use their own value again, and it is destructive")
        Do $$$AssertTrue((tProposal.changed.%ToJSON() [ """field"":""Setting""") && (tProposal.changed.%ToJSON() [ "removal description") && (tProposal.changed.%ToJSON() [ """removed"":true"), "its card shows the setting's name and description as removed rows: " _ tProposal.changed.%ToJSON())
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), "1|removal description|0", "and the setting is still there")
        Kill tSettings
        Set tSettings("interop.defaultsettings.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        ; A field changed out of band after the mint closes the remove target-changed, and the setting stays.
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "DropDefaults", ..#PRODUCTION), "the setting is replaced")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutDefault", ..#PRODUCTION, "*", "*", ..#SETTING, "moved", "removal description", 0), "by one that differs")
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "a setting changed after the mint closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), "moved|removal description|0", "and the setting is still there")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        Set tSC = ..Mint("InteropDefaultSettingRemove", ..ArgsFor(..#SETTING), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "a fresh remove mints")
        If '$IsObject($Get(tProposal)) Quit
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "and the remove then confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "as a deletion, marked (AD-15), whose read-back finds the setting gone: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..LedgerCount(tTurn, "interop.defaultsettings.remove"), 1, "ledgered once")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultText", ..#PRODUCTION, "*", "*", ..#SETTING), "<absent>", "the setting is gone")
        Do $$$AssertEquals(..VendorRows(tSince, "Delete System Default Setting", ..#SETTING, .tData), 1, "the vendor records one delete row")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC3: the three tools name <code>Value</code> as the argument to redact when the call names a setting whose name holds a credential
/// (<method>OcuPilot.Screen.Tool.InteropDefaultSettingAction.CallSecretNames</method>), so its ledger row and step show the redaction mark
/// in place of what the agent sent; an ordinary setting, a call with no setting, a setting that is not a string and a call that is not an
/// object redact nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropDefaultSettingAction.CallSecretNames</method> quit <code>""</code> --
/// the credential-name rows go red.</p>
Method TestTheCallSecretNamesAreTheDefaultSettingToolsAlone()
{
    For tTool = "InteropDefaultSettingAdd", "InteropDefaultSettingUpdate", "InteropDefaultSettingRemove" {
        Set tClass = "OcuPilot.Screen.Tool." _ tTool
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "CallSecretNames", {"Production": (..#PRODUCTION), "Setting": "SSLPassword", "Value": "x"})), "Value", tTool _ ": a credential-named setting redacts the value")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Production": (..#PRODUCTION), "Setting": (..#SETTING), "Value": "7"})), 0, tTool _ ": an ordinary setting redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Production": (..#PRODUCTION), "Value": "7"})), 0, tTool _ ": a call with no setting redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", {"Setting": 5, "Value": "7"})), 0, tTool _ ": a setting that is not a string redacts nothing")
        Do $$$AssertEquals($ListLength($ClassMethod(tClass, "CallSecretNames", "")), 0, tTool _ ": and a call that is not an object redacts nothing")
    }
}

/// <p>AC1: every default setting write has a script form (AD-59) the person can run in a terminal, each key part and value one string literal
/// in which a quote or a control character cannot end the literal, with the vendor call of its kind; the read has none, and a flag renders
/// as its number.</p>
/// <p>Mutation (Rule 19): render the description unquoted in <method>OcuPilot.Port.InteropPort.DefaultSettingSnippet</method> -- this goes
/// red.</p>
Method TestEveryDefaultSettingWriteRendersItsScript()
{
    Set tPort = ..#PORT
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("P""x", "*", "*", "S" _ $Char(10) _ "n"))
    Set tBody = {"Value": ("v""al"), "Description": ("d""es" _ $Char(9) _ "c"), "Deployable": true}
    Set tId = """P""""x||*||*||S""_$Char(10)_""n"""
    Set tDescription = """d""""es""_$Char(9)_""c"""
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "DefaultSettings", "DEFAULTSETTING"), "", "the read has no script form")
    For tCase = $ListBuild("ADDDEFAULT", "##class(Ens.Config.DefaultSettings).%New()", "tSetting.ProductionName = ""P""""x"""), $ListBuild("SETDEFAULT", "##class(Ens.Config.DefaultSettings).%OpenId(" _ tId _ ", 4)", "tSetting.SettingValue = ""v""""al"""), $ListBuild("REMOVEDEFAULT", "##class(Ens.Config.DefaultSettings).%DeleteId(" _ tId _ ")", "") {
        Set tType = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "DefaultSettings", tType), "objectscript", tType _ " has a script form")
        Set tSteps = $ClassMethod(tPort, "Snippet", "DefaultSettings", tType, .tQuery, tBody)
        Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 2)), tType _ ": it switches and makes the vendor's call: " _ tText)
        If $List(tCase, 3) '= "" Do $$$AssertTrue(tText [ $List(tCase, 3), tType _ ": with the key part or value as one literal")
        If tType '= "REMOVEDEFAULT" Do $$$AssertTrue((tText [ ("tSetting.Description = " _ tDescription)) && (tText [ "tSetting.Deployable = 1"), tType _ ": the description is one string literal and the flag its number")
        If tType = "REMOVEDEFAULT" Do $$$AssertTrue(tText '[ "Description", tType _ ": a remove carries no field")
    }
}

/// <p>AC1: the agent's reviewed field lists for a system default setting name exactly the port's three settable fields (and the name for a
/// create), the precondition codes are the three refusals a setting's fresh read answers, and each tool declares only codes the list names.</p>
/// <p>Mutation (Rule 19): misspell one field in the update list of <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>
/// -- this goes red.</p>
Method TestTheReviewedFieldListsAndPreconditionCodesAreTheTools()
{
    Set tFields = $Parameter(..#PORT, "DEFAULTSETTINGSETFIELDS")
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    Do $$$AssertEquals($ListToString($ClassMethod(tProhibited, "PermittedChangeFields", "default-setting")), tFields, "an update may change the three fields and no other")
    Do $$$AssertEquals($ListToString($ClassMethod(tProhibited, "PermittedCreateFields", "default-setting")), "Setting," _ tFields, "a create may carry the name and the three")
    Set tCodes = $ClassMethod("OcuPilot.Api.InteropError", "DefaultSettingPreconditionCodes")
    Do $$$AssertEquals($ListToString(tCodes), "INTEROP.DEFAULTSETTING.TAKEN,INTEROP.DEFAULTSETTING.SECRET,INTEROP.DEFAULTSETTING.SOURCECONTROL", "the precondition codes are those a setting's fresh read answers")
    For tTool = "InteropDefaultSettingAdd", "InteropDefaultSettingUpdate", "InteropDefaultSettingRemove" {
        Set tDeclared = $ListFromString($Parameter("OcuPilot.Screen.Tool." _ tTool, "PRECONDITIONCODES"))
        Set tWithin = 1
        For tI = 1:1:$ListLength(tDeclared) {
            If ($List(tDeclared, tI) '= "INTEROP.NAMESPACE") && '$ListFind(tCodes, $List(tDeclared, tI)) Set tWithin = 0
        }
        Do $$$AssertTrue(tWithin, tTool _ " declares only codes the setting list names")
    }
}

/// <p>AC1, AC4: the System default settings read -- the screen's read route over the wire and the read tool
/// <code>interop.defaultsettings.read</code> -- lists a setting added through the Save with its fields, then the values an Edit changed, then
/// no longer lists it once it is removed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.DefaultSettingRow</method> answer an empty <code>Description</code> -- the
/// first listing goes red.</p>
Method TestTheSystemDefaultSettingsReadListsTheAddedChangedAndRemovedSetting()
{
    Do $$$AssertEquals(..Save(..SaveBody(..#SETTING, "first", "first description", 1), .tAnswer), "201 ", "the setting is added: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Set tRow = ..ListedRow()
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.Value _ "|" _ tRow.Description _ "|" _ tRow.Deployable _ "|" _ tRow.Setting, 1: "unlisted"), "first|first description|1|" _ ..#SETTING, "both reads list it with its fields")
    Do $$$AssertEquals(..Act("edit", ..IdFor(), {"Value": "second"}, .tAnswer), "200 ", "the setting is edited")
    Set tRow = ..ListedRow()
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.Value, 1: "unlisted"), "second", "both reads list the changed value")
    Do $$$AssertEquals(..Act("remove", ..IdFor(), "", .tAnswer), "200 ", "the setting is removed")
    Do $$$AssertEquals($Select($IsObject(..ListedRow()): "listed", 1: "unlisted"), "unlisted", "and neither read lists it any more")
}

/// <p>The row of the probe setting as the screen's read route answers it, after checking the read tool answers the same row, or
/// <code>""</code> when either does not list it.</p>
ClassMethod ListedRow() As %DynamicObject
{
    Do $ClassMethod(..#CONTROL, "Call", "GET", ..#SCREEN _ "/read?maxRows=1000", "", .tStatus, .tAnswer)
    Set tScreenRow = ..RowIn($Select($IsObject(tAnswer): tAnswer.%Get("rows"), 1: ""))
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.defaultsettings.read", .tTool)
    Set tToolRow = ""
    If $IsObject($Get(tTool)) {
        Do ##class(OcuPilot.Kernel.Scope).Set("USER")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tHttp, .tFault)
        If +$Get(tHttp) = 200 Set tToolRow = ..RowIn(tResult.%Get("rows"))
    }
    If $IsObject(tScreenRow) && $IsObject(tToolRow) && (tScreenRow.%ToJSON() '= tToolRow.%ToJSON()) Quit {"error": "the screen's row and the tool's row differ"}
    Quit $Select($IsObject(tScreenRow) && $IsObject(tToolRow): tScreenRow, 1: "")
}

/// <p>The probe setting's row in <var>pRows</var>, or <code>""</code>.</p>
ClassMethod RowIn(pRows As %DynamicArray) As %DynamicObject
{
    Set tHit = ""
    If '$IsObject(pRows) Quit tHit
    For tI = 0:1:pRows.%Size() - 1 {
        If (pRows.%Get(tI).Production = ..#PRODUCTION) && (pRows.%Get(tI).Setting = ..#SETTING) Set tHit = pRows.%Get(tI) Quit
    }
    Quit tHit
}

}
