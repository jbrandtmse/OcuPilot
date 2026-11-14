/// <p>Pins Story 20.26's refusals end to end against probe business partners in <code>USER</code> (AD-6, AD-39, AD-54, AD-55, AD-56,
/// AD-62): each row of the plan's refusal matrix is refused by its own code with its published sentence, before any vendor call, and
/// nothing is written -- a name the namespace holds, a name held in another letter case, a remove of a partner an item of a production
/// that is not running names, a name or field the rules refuse (422), a rename sent under any key, a partner that is not there (404), a
/// namespace under source control and a namespace that runs no interoperability. The person's Save and row actions, the agent's mint
/// and its dispatched call and the port itself are each driven where they can be.</p>
/// <p>A namespace under source control is arranged in process through <class>OcuPilot.Test.InteropItemSeam</class>, because no
/// throwaway can be put under source control: that leg drives the port, which both callers reach.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes every partner and the probe production it creates.</p>
Class OcuPilot.Test.InteropPartnerRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropPartnerControl";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter LEDGER = "OcuPilot.Test.Ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter PARTNER = "OcuProbe226Refuse";

Parameter ITEM = "OcuPilotProbe226Named";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropPartnerRefusals writes probe business partners and a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create")
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "ResetProduction"))
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe partners are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The published sentence of the code <var>pName</var> names (a parameter of <class>OcuPilot.Api.InteropError</class>).</p>
ClassMethod Reason(pName As %String) As %String
{
    Quit $Parameter(..#ERROR, "REASON" _ pName)
}

/// <p>Declare the pairs of every partner read and write held, so the port driven in process through the seam passes its gate for
/// <code>USER</code>.</p>
ClassMethod HoldPartnerPairs()
{
    For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
}

/// <p>The partner <var>pName</var> through the port: the HTTP status and, in <var>pFault</var>, the envelope.</p>
ClassMethod PortWrite(pType As %String, pName As %String, pBody As %DynamicObject = "", Output pFault, pClass As %String = {..#PORT}) As %Integer
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = pName
    Set tSC = $ClassMethod(pClass, "Invoke", "BusinessPartners", pType, .tQuery, pBody, .tResult, .tHttp, .pFault)
    Quit +$Get(tHttp)
}

/// <p>The code of <var>pFault</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pFault) As %String
{
    Quit $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>AC1: an add of a name the namespace holds is <code>INTEROP.PARTNER.TAKEN</code> and an add of a name held in another letter
/// case is <code>INTEROP.PARTNER.NAMECASE</code>, each with its published sentence, from the person's Save, the agent's mint and the
/// port, and the partner held is untouched.</p>
/// <p>Mutation (Rule 19): drop the <code>NAMECASE</code> decision from <method>OcuPilot.Port.InteropPort.PartnerWriteToken</method> --
/// the case-variant legs go red.</p>
Method TestAHeldNameAndItsOtherLetterCaseAreRefusedByTheirCodes()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER), "the probe partner is held")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    For tCase = $ListBuild(..#PARTNER, "TAKEN"), $ListBuild($ZConvert(..#PARTNER, "U"), "NAMECASE") {
        Set tName = $List(tCase, 1)
        Set tCode = "INTEROP.PARTNER." _ $List(tCase, 2)
        Set tLabel = tName _ ": "
        Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/business-partners", {"Name": (tName), "Description": "x"}, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), "409 " _ tCode _ " " _ ..Reason("PARTNER" _ $List(tCase, 2)), tLabel _ "the Save is refused with the published sentence")
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "MintVerdict", "InteropPartnerAdd", $ClassMethod(..#CONTROL, "ArgsFor", tName, {"Description": "x"}), .tReason), tCode, tLabel _ "the agent's add is refused at the mint")
        Do $$$AssertEquals(tReason, ..Reason("PARTNER" _ $List(tCase, 2)), tLabel _ "with the published sentence")
        Do $$$AssertEquals(..PortWrite("ADDPARTNER", tName, {"Description": "x"}, .tFault) _ " " _ ..CodeOf(tFault), "409 " _ tCode, tLabel _ "and so is the port's own write")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was written")
}

/// <p>AC1: a name that is empty or holds a control character or is past 255 characters, and a field past the vendor's length, are
/// 422 <code>INTEROP.PARTNER.NAME</code> or <code>INTEROP.PARTNER.LENGTH</code> naming the field, from the Save, the Edit, the
/// agent's mint and the port, with nothing written; a name that holds <code>||</code> is a name (measured), and a value that is not
/// a string is a shape violation.</p>
/// <p>Mutation (Rule 19): raise the description's limit in <method>OcuPilot.Port.InteropPort.PartnerLimit</method> to 5001 -- the
/// description leg goes red.</p>
Method TestANameOrAFieldOutsideItsRuleIsRefusedByItsCode()
{
    Set tFixture = ..#FIXTURE
    Set tControl = "OcuPilot.Test.InteropItemControl"
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    For tCase = $ListBuild("", "INTEROP.PARTNER.NAME", "Name"), $ListBuild("bad" _ $Char(1) _ "name", "INTEROP.PARTNER.NAME", "Name"), $ListBuild($Translate($Justify("", 256), " ", "n"), "INTEROP.PARTNER.NAME", "Name") {
        Do $ClassMethod(tControl, "Call", "POST", "/interop/business-partners", {"Name": ($List(tCase, 1))}, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "422 " _ $List(tCase, 2), "the Save refuses the name '" _ $Extract($List(tCase, 1), 1, 12) _ "'")
    }
    Do $$$AssertEquals(..PortWrite("ADDPARTNER", "", {}, .tFault) _ " " _ ..CodeOf(tFault), "400 PORT.VALIDATION", "the port's own add needs a name to be named at all")
    Do $$$AssertEquals(..PortWrite("ADDPARTNER", "bad" _ $Char(1) _ "name", {}, .tFault) _ " " _ ..CodeOf(tFault), "422 INTEROP.PARTNER.NAME", "and refuses a control character in it")
    Do $$$AssertEquals(..PortWrite("ADDPARTNER", $Translate($Justify("", 256), " ", "n"), {}, .tFault) _ " " _ ..CodeOf(tFault), "422 INTEROP.PARTNER.NAME", "and one past 255 characters")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "MintVerdict", "InteropPartnerAdd", $ClassMethod(..#CONTROL, "ArgsFor", "bad" _ $Char(1) _ "name"), .tReason), "TOOL.ARGUMENTS", "the agent's add of that name is refused at the mint")
    Do $$$AssertTrue(tReason [ "'Name'", "naming the field: " _ tReason)
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "no refused name wrote a thing")
    ; The fields.
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER), "the probe partner is held")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    For tCase = $ListBuild("Description", 5001), $ListBuild("PrimaryContact", 256), $ListBuild("PrimaryTitle", 256), $ListBuild("PrimaryEmail", 256), $ListBuild("PrimaryPhone", 51), $ListBuild("PrimaryMobile", 51), $ListBuild("PrimaryNotes", 1001), $ListBuild("AlternativeContact", 256), $ListBuild("AlternativeTitle", 256), $ListBuild("AlternativeEmail", 256), $ListBuild("AlternativePhone", 51), $ListBuild("AlternativeMobile", 51), $ListBuild("AlternativeNotes", 1001) {
        Set tField = $List(tCase, 1)
        Set tTooLong = $Translate($Justify("", $List(tCase, 2)), " ", "x")
        Set tFields = {}
        Do tFields.%Set(tField, tTooLong, "string")
        Set tLabel = tField _ ": "
        Set tBody = {"Name": "OcuProbe226Long"}
        Do tBody.%Set(tField, tTooLong, "string")
        Do $ClassMethod(tControl, "Call", "POST", "/interop/business-partners", tBody, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.detail.violations.%Get(0).field, 1: ""), "422 INTEROP.PARTNER.LENGTH " _ tField, tLabel _ "the Save refuses one character past its length, naming the field")
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ..Reason("PARTNERLENGTH"), tLabel _ "with the published sentence")
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", ..#PARTNER, $ClassMethod(..#CONTROL, "Values", tFields), .tEdit), "422 INTEROP.PARTNER.LENGTH", tLabel _ "and so does the Edit")
        Do $$$AssertEquals(..PortWrite("SETPARTNER", ..#PARTNER, tFields, .tFault) _ " " _ ..CodeOf(tFault), "422 INTEROP.PARTNER.LENGTH", tLabel _ "and the port")
        Set tMintArgs = $ClassMethod(..#CONTROL, "ArgsFor", ..#PARTNER, tFields)
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "MintVerdict", "InteropPartnerUpdate", tMintArgs, .tReason), "TOOL.ARGUMENTS", tLabel _ "and the agent's update at the mint")
        Do $$$AssertTrue(tReason [ ("'" _ tField _ "'"), tLabel _ "naming the field: " _ tReason)
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "no refused field wrote a thing")
    Do $$$AssertEquals(..PortWrite("SETPARTNER", ..#PARTNER, {"Description": 5}, .tFault) _ " " _ ..CodeOf(tFault), "422 PORT.FIELD.SHAPE", "a value that is not a string is a shape violation")
    ; A name that holds the vendor's own id separator is a name like any other.
    Set tPiped = "OcuProbe226||piped"
    Do $ClassMethod(tControl, "Call", "POST", "/interop/business-partners", {"Name": (tPiped), "Description": "p"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "a name holding || is saved: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue($IsObject($ClassMethod(..#CONTROL, "Held", tPiped)), "and read back by it")
}

/// <p>AC2: a rename cannot be expressed. The agent's update carrying a new name under any key is refused by the tool's schema
/// before the mint, the screen's Edit carrying a <code>Name</code> value is refused as an undeclared value, and a Save carrying a
/// member the add does not settle is <code>PORT.FIELD.UNEXPECTED</code>; the partner keeps its name and every field, and no audit
/// row is written.</p>
/// <p>Mutation (Rule 19): add <code>Name</code> to <code>FIELDS</code> of <class>OcuPilot.Screen.Tool.InteropPartnerUpdate</class>
/// -- the dispatched call is admitted by the schema and this goes red.</p>
Method TestARenameIsRefusedBeforeAnyPortCall()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER), "the probe partner is held")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    For tKey = "NewName", "Name2", "PartnerName" {
        Set tInput = {"Name": (..#PARTNER), "Description": "renamed"}
        Do tInput.%Set(tKey, "OcuProbe226Renamed", "string")
        Set tUse = {"id": "toolu_partner"}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("interop.businesspartners.update"), "string")
        Do tUse.%Set("input", tInput)
        Set tUses = []
        Do tUses.%Push(tUse)
        Set tTurn = $ClassMethod(..#LEDGER, "NewTurnKey")
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "interoperability/business-partners")
        Do $$$AssertStatusOK(tSC, tKey _ ": the dispatcher answers the call")
        Do $$$AssertEquals(tResults.%Size() _ "|" _ tResults.%Get(0).%Get("is_error"), "1|1", tKey _ ": the agent's update carrying it is refused")
        Do $$$AssertTrue(tResults.%Get(0).%ToJSON() [ "TOOL.ARGUMENTS", tKey _ ": by the tool's arguments: " _ tResults.%Get(0).%ToJSON())
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Set tValues = $ClassMethod(..#CONTROL, "Values", {"Description": "renamed"})
    Do tValues.%Set("Name", "OcuProbe226Renamed", "string")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", ..#PARTNER, tValues, .tAnswer), "400 TOOL.ARGUMENTS", "the screen's Edit carrying a Name value is refused as an undeclared value")
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/business-partners", {"Name": "OcuProbe226Fresh", "NewName": "x"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "400 PORT.FIELD.UNEXPECTED", "and a Save carrying a member the add does not settle is refused")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "no partner was renamed, changed or added")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", "OcuProbe226", .tData), 0, "and no audit row was written")
}

/// <p>AC3: a remove of a partner an item names in its Host <code>BusinessPartner</code> setting is <code>INTEROP.PARTNER.NAMED</code>
/// with its published sentence, from the person's Remove, the agent's mint, the confirm and the port, though the production that
/// holds the item is not running; the partner stays, and once the item no longer names it the remove runs. A partner no item names
/// is removed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.PartnerWriteToken</method> ignore <var>pNamed</var> -- every leg goes
/// red; make <method>OcuPilot.Port.InteropPort.PartnerNamedByHere</method> read only the running production's items -- the legs on the
/// probe production, which is stopped, go red.</p>
Method TestARemoveOfAPartnerAnItemNamesIsRefused()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER), "the probe partner is held")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#ITEM, "OcuPilotProbe.Interop.Op", 1, 0, "BusinessPartner", ..#PARTNER, "Host"), "an item of the stopped probe production names it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Current"), "", "no production runs")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tControl = ..#CONTROL
    Set tHeld = $ClassMethod(tControl, "Held", ..#PARTNER)
    Do $$$AssertEquals($Select($IsObject(tHeld): tHeld.NamedBy, 1: -1), 1, "the partner's read counts the item")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", "remove", ..#PARTNER, "", .tAnswer), "409 INTEROP.PARTNER.NAMED", "the person's Remove is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ..Reason("PARTNERNAMED"), "with the published sentence")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "MintVerdict", "InteropPartnerRemove", $ClassMethod(tControl, "ArgsFor", ..#PARTNER), .tReason), "INTEROP.PARTNER.NAMED", "the agent's remove is refused at the mint")
    Do $$$AssertEquals(tReason, ..Reason("PARTNERNAMED"), "with the published sentence")
    Do $$$AssertEquals(..PortWrite("REMOVEPARTNER", ..#PARTNER, "", .tFault) _ " " _ ..CodeOf(tFault), "409 INTEROP.PARTNER.NAMED", "and so is the port's own write")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "the partner is untouched")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", ..#PARTNER, .tData), 0, "and no audit row was written")
    ; The item names the partner after the remove was minted: the confirm closes target-changed and the partner stays.
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "the item stops naming the partner")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Try {
        Kill tSettings
        Set tSettings("interop.businesspartners.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the tool's key is turned on")
        Set tSC = $ClassMethod(tControl, "Mint", "InteropPartnerRemove", $ClassMethod(tControl, "ArgsFor", ..#PARTNER), .tProposal, .tMintFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "a remove of the unnamed partner mints: " _ $Select($IsObject($Get(tMintFault)): tMintFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#ITEM, "OcuPilotProbe.Interop.Op", 1, 0, "BusinessPartner", ..#PARTNER, "Host"), "an item then names it")
        Set tStatus = $ClassMethod(tControl, "Confirm", tProposal, .tConfirmed, .tRaw)
        Do $$$AssertEquals($Select($IsObject(tConfirmed): tConfirmed.%Get("code"), 1: tStatus), "PROPOSAL.TARGETCHANGED", "the confirm closes target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertTrue($IsObject($ClassMethod(tControl, "Held", ..#PARTNER)), "and the partner remains")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the confirm leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "the item stops naming the partner again")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", "remove", ..#PARTNER, "", .tAnswer), "200 ", "and the person's Remove then runs: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue('$IsObject($ClassMethod(tControl, "Held", ..#PARTNER)), "the partner is gone")
}

/// <p>AC1: an Edit or a Remove of a partner the namespace does not hold is 404 <code>PORT.NOTFOUND</code>, unlogged, from the person's
/// row action, the agent's mint and the port, and an add the namespace does not hold is free.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ReadPartner</method> answer a row for an absent partner -- the mint
/// legs go red.</p>
Method TestAnUnknownPartnerIsNotFound()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", "edit", ..#PARTNER, $ClassMethod(tControl, "Values", {"Description": "x"}), .tAnswer), "404 PORT.NOTFOUND", "an Edit of a partner that is not there is not found")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", "remove", ..#PARTNER, "", .tAnswer), "404 PORT.NOTFOUND", "and so is a Remove")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "MintVerdict", "InteropPartnerUpdate", $ClassMethod(tControl, "ArgsFor", ..#PARTNER, {"Description": "x"})), "TOOL.ARGUMENTS", "the agent's update is refused at the mint: it names no partner of this instance")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "MintVerdict", "InteropPartnerRemove", $ClassMethod(tControl, "ArgsFor", ..#PARTNER)), "TOOL.ARGUMENTS", "and so is its remove")
    Do $$$AssertEquals(..PortWrite("SETPARTNER", ..#PARTNER, {"Description": "x"}, .tFault) _ " " _ ..CodeOf(tFault), "404 PORT.NOTFOUND", "the port's own update finds none")
    Do $$$AssertEquals(..PortWrite("REMOVEPARTNER", ..#PARTNER, "", .tFault) _ " " _ ..CodeOf(tFault), "404 PORT.NOTFOUND", "and so does its remove")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was written")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "MintVerdict", "InteropPartnerAdd", $ClassMethod(tControl, "ArgsFor", ..#PARTNER, {"Description": "x"})), "minted", "while an add of the free name mints")
}

/// <p>AC1: a namespace under source control refuses every partner write by <code>SOURCECONTROL</code> before the vendor is called,
/// the composed reads of a write included, while the list stays readable; and a namespace that runs no interoperability is refused
/// <code>INTEROP.NAMESPACE</code>. Both are driven through the port both callers reach.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.PerformPartner</method>
/// -- the write rows go red.</p>
Method TestASourceControlledNamespaceAndAPlainOneAreRefusedByTheirCodes()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER), "the probe partner is held")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Do ..HoldPartnerPairs()
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Kill tList
    Set tList("namespace") = "USER"
    Set tSC = $ClassMethod(tSeam, "Invoke", "BusinessPartners", "LIST", .tList, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the partners list is readable under source control")
    For tWrite = $ListBuild("ADDPARTNER", "OcuProbe226Fresh", {"Description": "v"}), $ListBuild("SETPARTNER", ..#PARTNER, {"Description": "v"}), $ListBuild("REMOVEPARTNER", ..#PARTNER, "") {
        Set tHttp = ..PortWrite($List(tWrite, 1), $List(tWrite, 2), $List(tWrite, 3), .tFault, tSeam)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 INTEROP.PARTNER.SOURCECONTROL", $List(tWrite, 1) _ " is refused for source control")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ..Reason("PARTNERSOURCECONTROL"), "with the published sentence")
    }
    For tAction = "ADDPARTNER", "SETPARTNER", "REMOVEPARTNER" {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = ..#PARTNER
        Set tQuery("action") = tAction
        Set tSC = $ClassMethod(tSeam, "Invoke", "BusinessPartners", "PARTNER", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 INTEROP.PARTNER.SOURCECONTROL", "the partner read composed for " _ tAction _ " is refused too")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was written")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
    Do $ClassMethod(tSeam, "Disarm")
    Kill tQuery
    Set tQuery("namespace") = "%SYS"
    Set tQuery("id") = ..#PARTNER
    Set tSC = $ClassMethod(tSeam, "Invoke", "BusinessPartners", "ADDPARTNER", .tQuery, {}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 INTEROP.NAMESPACE", "a namespace that runs no interoperability is refused for it")
}

/// <p>AC1: an Edit of a partner whose vendor lock another process holds is refused 503 and the partner keeps what it held, since the
/// update opens the partner at concurrency 4.</p>
/// <p>Mutation (Rule 19): drop the <code>tBusy</code> answer of <method>OcuPilot.Port.InteropPort.PerformPartner</method> -- the Edit
/// answers 200 without writing and this goes red.</p>
Method TestAnEditOfAPartnerWhoseLockIsHeldIsRefusedUnavailable()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutPartner", ..#PARTNER), "the probe partner is held")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Try {
        Set $NAMESPACE = "USER"
        Lock +^Ens.Config.BusinessPartnerD(..#PARTNER):5
        Set tLocked = $Test
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(tLocked, "this process holds the partner's lock")
        If tLocked {
            Set tStatus = $ClassMethod(..#CONTROL, "Act", "edit", ..#PARTNER, $ClassMethod(..#CONTROL, "Values", {"Description": "changed"}), .tAnswer)
            Do $$$AssertEquals($Piece(tStatus, " ", 1), 503, "the Edit is refused unavailable while the lock is held: " _ tStatus)
            Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "and nothing was written")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the lock leg raised")
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tLocked {
        Set $NAMESPACE = "USER"
        Lock -^Ens.Config.BusinessPartnerD(..#PARTNER)
        Set $NAMESPACE = tOrigNS
    }
}

}
