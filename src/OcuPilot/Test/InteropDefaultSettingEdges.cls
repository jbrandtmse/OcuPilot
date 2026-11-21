/// <p>Pins two edges of Story 24.15's system default settings (AD-35, AD-54, AD-62) against probe settings in <code>USER</code> and
/// <code>HSCUSTOM</code>: an empty or absent value for a setting the vendor holds to an integer is refused <code>INTEROP.DEFAULTSETTING.VALUE</code>
/// from the person's Save and Edit, the port and the agent's mint, while an empty value for a text setting and a description-only edit
/// are accepted; and the vendor's own audit rows of a secret-named setting read masked through the Logs audit screen's read over the wire and
/// through <code>logs.audit.read</code>.</p>
/// <p><b>What it needs from the environment:</b> interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, auditing on,
/// the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes every setting it creates; the audit rows
/// the vendor writes stay in the audit database.</p>
Class OcuPilot.Test.InteropDefaultSettingEdges Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropDefaultSettingControl";

Parameter REFUSALS = "OcuPilot.Test.InteropDefaultSettingRefusals";

Parameter PRODUCTION = "OcuProbe2415.Production";

Parameter SECRETMARKER = "OcuEdgeMarker2415";

Parameter READPATH = "/screens/logs.audit/read";

Parameter READSECONDS = 15;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropDefaultSettingEdges writes probe system default settings in USER and HSCUSTOM on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION) + $ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION, "HSCUSTOM"), 0, "and none survives in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AC2: a value the vendor refuses for the setting <code>PoolSize</code> that is empty, or that an add leaves out, is
/// <code>INTEROP.DEFAULTSETTING.VALUE</code> (422) from the port, the person's Save and Edit and the agent's mint, nothing is stored and a
/// held setting keeps its value; an edit that carries a description alone keeps the value, and a text setting takes an empty value.</p>
/// <p>Mutation (Rule 19): put back the <code>Value '= ""</code> test in <method>OcuPilot.Port.InteropPort.DefaultSettingViolations</method> --
/// the empty value legs go red; drop its <code>unassigned</code> arm -- the legs that leave the value out go red.</p>
Method TestAnEmptyValueForAnIntegerSettingIsRefusedAsAValue()
{
    Set tFixture = ..#FIXTURE
    Set tRefusals = ..#REFUSALS
    Set tCode = "422 INTEROP.DEFAULTSETTING.VALUE"
    Do $$$AssertEquals($ClassMethod(tRefusals, "Verdict", "ADDDEFAULT", "PoolSize", {"Value": ""}), tCode, "the port refuses an add of PoolSize with an empty value")
    Do $$$AssertEquals($ClassMethod(tRefusals, "Verdict", "ADDDEFAULT", "PoolSize", {}), tCode, "and one that leaves the value out")
    Do $$$AssertEquals($ClassMethod(tRefusals, "Verdict", "ADDDEFAULT", "PoolSize", {"Description": "d"}), tCode, "and one that carries a description alone")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Save", $ClassMethod(..#CONTROL, "SaveBody", "PoolSize", ""), .tAnswer), tCode, "the person's Save is refused the same")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), $Parameter("OcuPilot.Api.InteropError", "REASONDEFAULTSETTINGVALUE"), "with the published sentence")
    Do $$$AssertEquals($ClassMethod(tRefusals, "MintVerdict", "InteropDefaultSettingAdd", "PoolSize", {"Value": ""}), "TOOL.ARGUMENTS", "and the agent's add is refused at the mint")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultCount", ..#PRODUCTION), 0, "nothing was stored")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "PoolSize", "3", "held"), "a PoolSize setting is held")
    Do $$$AssertEquals($ClassMethod(tRefusals, "Verdict", "SETDEFAULT", "PoolSize", {"Value": ""}), tCode, "the port refuses a set of it to an empty value")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", $ClassMethod(..#CONTROL, "IdFor", "PoolSize"), {"Value": ""}, .tEdit), tCode, "and so does the person's Edit")
    Do $$$AssertEquals($ClassMethod(tRefusals, "MintVerdict", "InteropDefaultSettingUpdate", "PoolSize", {"Value": ""}), "TOOL.ARGUMENTS", "and the agent's update at the mint")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "PoolSize"), "3|held|0", "the held value is unchanged")
    Do $$$AssertEquals($ClassMethod(tRefusals, "Verdict", "SETDEFAULT", "PoolSize", {"Description": "kept"}), "200 ", "an edit that carries a description alone is accepted")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "PoolSize"), "3|kept|0", "and keeps the value")
    Do $$$AssertEquals($ClassMethod(tRefusals, "Verdict", "ADDDEFAULT", "ArchiveIO", {"Value": "", "Description": "text"}), "200 ", "a text setting takes an empty value")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "ArchiveIO"), "|text|0", "stored empty")
}

/// <p>AC3: the vendor's audit rows of a secret-named setting (an insert, an update and a delete in <code>USER</code>, an insert and a delete
/// in <code>HSCUSTOM</code>) are answered by the Logs audit screen's read over the wire and by <code>logs.audit.read</code> with the setting's
/// name kept and its value masked, while the audit database itself holds the value.</p>
/// <p>Mutation (Rule 19): drop the <code>MaskVendorSecrets</code> call from <method>OcuPilot.Screen.Read</method> -- both reads carry the
/// value and this goes red.</p>
Method TestTheVendorRowsOfASecretNamedSettingReadMaskedOnTheLogsAuditScreen()
{
    Set tFixture = ..#FIXTURE
    Set tMarker = ..#SECRETMARKER
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "SSLPassword", tMarker _ "-one", "stored"), "the vendor's insert of a secret-named setting is recorded in USER")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "SSLPassword", tMarker _ "-two", "stored"), "and its update")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "SSLPassword", tMarker _ "-three", "stored", 0, "HSCUSTOM"), "and an insert in HSCUSTOM")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "DropDefaults", ..#PRODUCTION), "and the delete of each")
    Do $$$AssertTrue($ClassMethod("OcuPilot.Test.AuditVendorSecrets", "VendorCarries", tUtcSince, tMarker, "%Ensemble/%Production/ModifyDefaultSetting") >= 4, "the audit database holds the value in plain text")
    Set tWant = 5
    Set tDeadline = $ZHorolog + ..#READSECONDS
    For {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#READPATH _ "?events=ModifyDefaultSetting&maxRows=200&beginDateTime=" _ $ZConvert(tSince, "O", "URL"), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
        Set tRows = ""
        Try { Set tRows = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows") } Catch { Set tRows = "" }
        Set tNamed = ..Named(tRows)
        If (tNamed >= tWant) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
    }
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers")
    Do $$$AssertEquals(tNamed, tWant, "with the five rows naming the setting")
    Do $$$AssertTrue(tRaw '[ tMarker, "and no part of the answer carries a value")
    Do $$$AssertEquals(..Masked(tRows), tWant, "each reading the mask where the value was")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("logs.audit.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tArgs = {"events": "ModifyDefaultSetting", "maxRows": 200}
    Do tArgs.%Set("beginDateTime", tSince, "string")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 200, .tResult, .tToolHttp, .tToolFault)
    Set tToolRows = $Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: "")
    Do $$$AssertEquals(..Named(tToolRows), tWant, "logs.audit.read answers the same five rows")
    Do $$$AssertTrue($IsObject($Get(tResult)) && (tResult.%ToJSON() '[ tMarker), "carrying no value")
    Do $$$AssertEquals(..Masked(tToolRows), tWant, "each masked")
}

/// <p>How many rows of <var>pRows</var> name the setting <code>SSLPassword</code> on their <code>SettingName:</code> line.</p>
ClassMethod Named(pRows) As %Integer
{
    Quit ..CountRows(pRows, "SettingName: SSLPassword", 0)
}

/// <p>How many rows of <var>pRows</var> naming the setting <code>SSLPassword</code> carry the mask in their event data.</p>
ClassMethod Masked(pRows) As %Integer
{
    Quit ..CountRows(pRows, "SettingName: SSLPassword", 1)
}

/// <p>The rows of <var>pRows</var> whose <code>EventData</code> holds <var>pText</var>, and with <var>pMasked</var> also the vendor's mask.</p>
ClassMethod CountRows(pRows, pText As %String, pMasked As %Boolean) As %Integer
{
    If '$IsObject(pRows) Quit 0
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tData = tRow.%Get("EventData")
        If tData '[ pText Continue
        If pMasked && (tData '[ $Parameter("OcuPilot.Port.AuditPort", "MASK")) Continue
        Set tCount = tCount + 1
    }
    Quit tCount
}

}
