/// <p>Pins edges of Story 24.15's system default settings (AD-29, AD-35, AD-52, AD-54, AD-62) against probe settings in <code>USER</code> and
/// <code>HSCUSTOM</code>: an empty or absent value for <code>PoolSize</code>, which the vendor holds to a positive integer, is refused
/// <code>INTEROP.DEFAULTSETTING.VALUE</code> from the person's Save and Edit, the port and the agent's mint, while an empty value for a text
/// setting and a description-only edit are accepted; the person's Save asks the vendor nothing before the port's gate; an item and a host class
/// that differ are each kept where they sit; a remove confirmed from another namespace acts where the proposal read; and the vendor's own
/// audit rows of a secret-named setting read masked, a value on several lines included, through the Logs audit screen's read over the wire
/// and through <code>logs.audit.read</code>.</p>
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
    Do $$$AssertEquals($ClassMethod(tRefusals, "MintVerdict", "InteropDefaultSettingUpdate", "PoolSize", {"Description": "agent"}), "minted", "the agent's update that carries a description alone mints")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", $ClassMethod(..#CONTROL, "IdFor", "PoolSize"), {"Description": "edited"}, .tEdit), "200 ", "and the person's Edit of the description alone answers 200")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "PoolSize"), "3|edited|0", "keeping the value")
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

/// <p>AC2: the person's Save asks the vendor nothing before the port's gate and refusals: its own rules judge no violation in a value the
/// vendor refuses (<code>PoolSize</code> <code>0</code>), the Save is still refused <code>INTEROP.DEFAULTSETTING.VALUE</code> by the port's add,
/// and a secret-named setting is refused by its name.</p>
/// <p>Mutation (Rule 19): pass 1 for the value judgement in <method>OcuPilot.Area.Interop.DefaultSettingSave.Violations</method> -- the
/// rules leg goes red.</p>
Method TestTheSaveAsksTheVendorNothingBeforeThePortsGate()
{
    Set tControl = ..#CONTROL
    Set tSC = ##class(OcuPilot.Area.Interop.DefaultSettingSave).Violations("USER", ..#PRODUCTION, "PoolSize", {"Item": "*", "HostClass": "*", "Value": "0"}, .tViolations)
    Do $$$AssertStatusOK(tSC, "the Save's rules run")
    Do $$$AssertEquals(+$Get(tViolations), 0, "and judge no violation in a value only the vendor refuses")
    Do $$$AssertEquals($ClassMethod(tControl, "Save", $ClassMethod(tControl, "SaveBody", "PoolSize", "0"), .tAnswer), "422 INTEROP.DEFAULTSETTING.VALUE", "the Save is refused the value by the port's add")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), $Parameter("OcuPilot.Api.InteropError", "REASONDEFAULTSETTINGVALUE"), "with the published sentence")
    Do $$$AssertEquals($ClassMethod(tControl, "Save", $ClassMethod(tControl, "SaveBody", "SSLPassword", "0"), .tAnswer), "409 INTEROP.DEFAULTSETTING.SECRET", "a secret-named setting is refused by its name")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "DefaultCount", ..#PRODUCTION), 0, "and nothing was stored")
}

/// <p>AC1: a setting whose item and host class differ is kept under each part where it sits, from the person's Save and the port's add; the
/// port's read answers each in its own field, and the add's script form names each.</p>
/// <p>Mutation (Rule 19): swap the item and the host class in <method>OcuPilot.Port.InteropPort.PerformDefaultSetting</method>'s add -- the
/// stored-key legs go red.</p>
Method TestADistinctItemAndHostClassAreKeptWhereTheySit()
{
    Set tFixture = ..#FIXTURE
    Set tItem = "OcuItem2415"
    Set tHost = "OcuProbe2415.Host"
    Set tBody = $ClassMethod(..#CONTROL, "SaveBody", "ArchiveIO", "1", "parts")
    Do tBody.%Set("Item", tItem)
    Do tBody.%Set("HostClass", tHost)
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PRODUCTION, tItem, tHost, "ArchiveIO"))
    Set tText = $ClassMethod(..#CONTROL, "Save", tBody, .tAnswer)
    Do $$$AssertEquals(tText, "201 ", "the Save adds it: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.id _ "|" _ tAnswer.readBack.verdict, 1: ""), tId _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "with its four parts as its id and a matching read-back")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, tItem, tHost, "ArchiveIO"), "1|parts|0", "stored under its item and its host class")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, tHost, tItem, "ArchiveIO"), "<absent>", "and not with the two swapped")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#PRODUCTION, tItem, tHost, "PoolSize"))
    Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke("DefaultSettings", "ADDDEFAULT", .tQuery, {"Value": "2"}, .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the port's add answers 200")
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): tRow.Item _ "|" _ tRow.HostClass, 1: ""), tItem _ "|" _ tHost, "and reads each part back in its own field")
    Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, tItem, tHost, "PoolSize"), "2||0", "stored under its item and its host class")
    Set tSteps = ##class(OcuPilot.Port.InteropPort).Snippet("DefaultSettings", "ADDDEFAULT", .tQuery, {"Value": "2"})
    Set tScript = $Select($IsObject(tSteps) && (tSteps.%Size() = 1): tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue((tScript [ ("tSetting.ItemName = """ _ tItem _ """")) && (tScript [ ("tSetting.HostClassName = """ _ tHost _ """")), "the add's script form names each part where it sits: " _ tScript)
}

/// <p>AC1: the agent's remove, minted in <code>USER</code> and confirmed by a request scoped to <code>HSCUSTOM</code>, where the same setting
/// is held with the same value, removes the setting in <code>USER</code> and leaves <code>HSCUSTOM</code>'s (AD-52).</p>
/// <p>Mutation (Rule 19): take <code>Namespace</code> out of <parameter>OcuPilot.Screen.Tool.InteropDefaultSettingRemove.FINGERPRINTSUBJECT</parameter>
/// -- the confirm removes HSCUSTOM's setting and this goes red.</p>
Method TestARemoveConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "ArchiveIO", "1", "same", 0), "the setting is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutDefault", ..#PRODUCTION, "*", "*", "ArchiveIO", "1", "same", 0, "HSCUSTOM"), "and the same setting in HSCUSTOM")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Set tTurn = ""
    Try {
        Kill tSettings
        Set tSettings("interop.defaultsettings.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove's key is turned on")
        Set tSC = $ClassMethod(..#CONTROL, "Mint", "InteropDefaultSettingRemove", $ClassMethod(..#CONTROL, "ArgsFor", "ArchiveIO"), .tProposal, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the remove mints in USER")
        If '$IsObject($Get(tProposal)) Quit
        Kill tExtra
        Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/proposal/" _ tProposal.proposalId _ "/confirm?ns=HSCUSTOM"
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, "", "application/json", .tExtra, 180)
        Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "ArchiveIO"), "<absent>", "it removed the setting in USER, where the proposal read")
        Do $$$AssertEquals($ClassMethod(tFixture, "DefaultText", ..#PRODUCTION, "*", "*", "ArchiveIO", "HSCUSTOM"), "1|same|0", "and left HSCUSTOM's alone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC3: a secret-named setting's value written on several lines (a key in PEM form, say) is masked on every line of the vendor's insert,
/// update and delete rows, the old value after an update's new one included, while the row's other lines are kept and a row of an ordinary
/// setting is unchanged. Pure: the rows are built here in the vendor's layout (<code>Ens.Util.Auditing.AuditModifyDefaultSetting</code>).</p>
/// <p>Mutation (Rule 19): mask the default setting rows with <method>OcuPilot.Port.AuditPort.MaskedEventData</method> over
/// <code>SettingValue</code> again -- the continuation and old value legs go red.</p>
Method TestASecretValueOnSeveralLinesIsMaskedOnEveryLine()
{
    Set tNL = $Char(13, 10)
    Set tHead = tNL _ tNL _ "ProductionName: " _ ..#PRODUCTION _ tNL _ "ItemName: *" _ tNL _ "HostClassName: *" _ tNL
    Set tInsert = "Create System Default Setting:" _ tHead _ "SettingName: SSLPrivateKey" _ tNL _ tNL _ "Deployable: 0" _ tNL _ "Description: kept line" _ tNL _ "SettingValue: OcuOne-first" _ tNL _ "OcuOne-second" _ tNL _ "OcuOne-third" _ tNL
    Set tUpdate = "Modify System Default Setting" _ tHead _ "SettingName: SSLPrivateKey" _ tNL _ tNL _ "SettingValue modified:" _ tNL _ "New value: OcuTwo-first" _ tNL _ "OcuTwo-second" _ tNL _ "Old value: OcuThree-first" _ tNL _ "OcuThree-second" _ tNL _ tNL
    Set tPlain = "Create System Default Setting:" _ tHead _ "SettingName: ArchiveIO" _ tNL _ tNL _ "SettingValue: OcuKeep-first" _ tNL _ "OcuKeep-second" _ tNL
    Set tRows = []
    For tData = tInsert, tUpdate, tPlain {
        Do tRows.%Push({"EventSource": "%Ensemble", "EventType": "%Production", "Event": "ModifyDefaultSetting", "EventData": (tData)})
    }
    Do ##class(OcuPilot.Port.AuditPort).MaskVendorSecrets(tRows)
    Set tMask = $Parameter("OcuPilot.Port.AuditPort", "MASK")
    Set tInserted = tRows.%Get(0).EventData
    Set tUpdated = tRows.%Get(1).EventData
    Do $$$AssertTrue(tInserted '[ "OcuOne", "no line of the insert's value is left: " _ tInserted)
    Do $$$AssertTrue((tInserted [ ("SettingValue: " _ tMask)) && (tInserted [ "Description: kept line") && (tInserted [ "SettingName: SSLPrivateKey"), "the insert reads the mask where its value was and keeps its other lines")
    Do $$$AssertTrue((tUpdated '[ "OcuTwo") && (tUpdated '[ "OcuThree"), "no line of the update's new or old value is left: " _ tUpdated)
    Do $$$AssertTrue((tUpdated [ ("New value: " _ tMask)) && (tUpdated [ ("Old value: " _ tMask)), "the update reads the mask after each label")
    Do $$$AssertEquals(tRows.%Get(2).EventData, tPlain, "an ordinary setting's row is unchanged")
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
