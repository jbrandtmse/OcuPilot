/// <p>Pins Story 20.22's setting identity against a probe production in <code>USER</code> (AD-13, AD-62): a setting's item
/// is the composite <code>[Production, Name]</code>, never the vendor's integer id, which a compile of the production
/// class renumbers. A write minted or listed before a compile therefore reaches the named item after it, among two items
/// of one class that declare the same setting: an agent's set of the second Op item's <code>InitSeconds</code>, minted
/// before a compile and confirmed after it, changes that item in the stored configuration and in the class and leaves the
/// first item's own value as it was; the person's Set value and Reset to default after a further compile do the same; and
/// the item's list reads the same rows after the compile, while the vendor's integer id names no item.</p>
/// <p>It shares <class>OcuPilot.Test.InteropSettingControl</class>'s helpers and <class>OcuPilot.Test.InteropItemIdentity</class>'s
/// id readers. <b>What it needs from the environment:</b> the same as those classes, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because it compiles and <b>writes a probe production in <code>USER</code></b> (nothing is
/// started). One class per run.</p>
Class OcuPilot.Test.InteropSettingIdentity Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropSettingControl";

Parameter ITEMS = "OcuPilot.Test.InteropItemControl";

Parameter IDENTITY = "OcuPilot.Test.InteropItemIdentity";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SETTOOL = "OcuPilot.Screen.Tool.InteropSettingSet";

/// <p>The probe's first Op item, which holds a value of its own for the setting both items declare.</p>
Parameter FIRST = "OcuPilotProbeOp";

/// <p>A second Op item the class adds, last in the production and disabled: a write that took the first item instead
/// of the named item would change the wrong one.</p>
Parameter SECOND = "OcuP2022SettingB";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSettingIdentity compiles a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes, its messages and its proposals.</p>
Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "Remove")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The probe's items are as they began and its proposals removed, whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left with its items as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Add <parameter>SECOND</parameter> through the person's Save, which writes the production class too, so the item
/// outlives a compile; and give the first item a value of its own for <code>InitSeconds</code>, through the person's Set
/// value, so a write that reached it would show.</p>
Method AddTheSecondItem()
{
    Set tFields = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": false}
    Do $$$AssertEquals($ClassMethod(..#ITEMS, "Save", ..#SECOND, tFields), "201 ", "the second Op item is saved")
    Do $$$AssertEquals($ClassMethod(..#ITEMS, "Items"), $Parameter(..#ITEMS, "BASELINE") _ "," _ ..#SECOND _ ":0", "it is the last item of the production")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "set", "Host", "InitSeconds", "9", .tAnswer, ..#FIRST), "200 ", "the first item takes its own value")
    Do $$$AssertEquals(..Held(..#FIRST), "9|9", "which it holds in the configuration and in the class")
    Do $$$AssertEquals(..Held(..#SECOND), "<none>|<none>", "while the second holds none")
}

/// <p>The stored value of the item <var>pItem</var>'s <code>InitSeconds</code> and what the production class carries for
/// it, <code>&lt;none&gt;</code> for either that holds none.</p>
ClassMethod Held(pItem As %String) As %String
{
    Quit $ClassMethod(..#CONTROL, "Stored", "Host", "InitSeconds", pItem) _ "|" _ $ClassMethod(..#CONTROL, "InClass", "Host", "InitSeconds", pItem)
}

/// <p>AC2, AD-13: an agent's set of the second item's <code>InitSeconds</code>, minted before a compile of the production
/// class and confirmed over HTTP after it, stores the value for that item in the configuration and in the class and
/// leaves the first item's own value as it was; the compile renumbered every item between the mint and the confirm, so
/// the proposal held the item by its name. The value then survives one more compile.</p>
/// <p>Mutation (Rule 19): take the item from the production's first position in
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> (<code>Set tItemObject = pLocked.Items.GetAt(1)</code>) -- the
/// confirm sets the first item's value and this goes red.</p>
Method TestAnAgentsSetMintedBeforeACompileReachesTheNamedItemAfterIt()
{
    Do ..AddTheSecondItem()
    Set tIdsMinted = $ClassMethod(..#IDENTITY, "VendorIds")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", "Host", "InitSeconds", "7", ..#SECOND)
    Set tSC = $ClassMethod(..#ITEMS, "MintAs", ..#SETTOOL, tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the set mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals($Translate(tProposal.target.id, $Char(1), "~"), $Parameter(..#CONTROL, "PRODUCTION") _ "~" _ ..#SECOND _ "~Host~InitSeconds", "the proposal's target holds the item by its name")
    Do $$$AssertStatusOK($ClassMethod(..#ITEMS, "Recompile"), "the production class is compiled between the mint and the confirm")
    Set tIdsConfirmed = $ClassMethod(..#IDENTITY, "VendorIds")
    Do $$$AssertTrue($ClassMethod(..#IDENTITY, "Renumbered", tIdsMinted, tIdsConfirmed), "the compile renumbered every item: " _ tIdsMinted _ " then " _ tIdsConfirmed)
    Set tSC = $ClassMethod(..#ITEMS, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the confirm over HTTP is admitted after the compile: " _ $Extract($Get(tRaw), 1, 300))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..Held(..#SECOND), "7|7", "the named item holds the value, in the configuration and in the class")
    Do $$$AssertEquals(..Held(..#FIRST), "9|9", "and the first item's own value is as it was")
    Do $$$AssertStatusOK($ClassMethod(..#ITEMS, "Recompile"), "the class is compiled once more")
    Do $$$AssertEquals(..Held(..#SECOND) _ "|" _ ..Held(..#FIRST), "7|7|9|9", "and the compile keeps the value on the named item")
}

/// <p>AC2, AD-13: the person's Set value and Reset to default of the second item's <code>InitSeconds</code>, each after a
/// compile that renumbered the items, reach that item and no other: the value is stored for it and carried into the class,
/// the reset removes the element from it, and the first item's own value stays through both.</p>
/// <p>Mutation (Rule 19): take the item from the production's first position in
/// <method>OcuPilot.Port.InteropPort.SettingStep</method> (<code>Set tItemObject = pLocked.Items.GetAt(1)</code>) -- the
/// set changes the first item and the reset removes the first item's value, and this goes red.</p>
Method TestAPersonsSetAndResetAfterACompileReachTheNamedItem()
{
    Do ..AddTheSecondItem()
    Set tIdsListed = $ClassMethod(..#IDENTITY, "VendorIds")
    Do $$$AssertStatusOK($ClassMethod(..#ITEMS, "Recompile"), "the production class is compiled after the item was listed")
    Set tIdsActing = $ClassMethod(..#IDENTITY, "VendorIds")
    Do $$$AssertTrue($ClassMethod(..#IDENTITY, "Renumbered", tIdsListed, tIdsActing), "the compile renumbered every item: " _ tIdsListed _ " then " _ tIdsActing)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "set", "Host", "InitSeconds", "5", .tAnswer, ..#SECOND), "200 ", "Set value of the second item answers 200: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Held(..#SECOND) _ "|" _ ..Held(..#FIRST), "5|5|9|9", "it stores the value for that item and leaves the first as it was")
    Do $$$AssertStatusOK($ClassMethod(..#ITEMS, "Recompile"), "the class is compiled again before the reset")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "reset", "Host", "InitSeconds", $Char(0), .tAnswer, ..#SECOND), "200 ", "Reset to default of the second item answers 200: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Held(..#SECOND) _ "|" _ ..Held(..#FIRST), "<none>|<none>|9|9", "it removes the element from that item in the configuration and the class, and the first keeps its own")
}

/// <p>AD-13: the item's settings list names the item and not its integer id, so the same rows are read after a compile
/// renumbered the items; the vendor's integer id names no item, alone or as the vendor's config name.</p>
/// <p>Mutation (Rule 19): take the first item whatever the name in
/// <method>OcuPilot.Port.InteropPort.GatherSettings</method> (<code>Set tChosen = tProduction.Items.GetAt(1)</code>, count 1)
/// -- the second item's rows read as the first's and this goes red.</p>
Method TestTheItemSettingsListNamesTheItemAndNotItsVendorId()
{
    Do ..AddTheSecondItem()
    Set tItemId = $ClassMethod(..#CONTROL, "ItemId", ..#SECOND)
    Set tBefore = ..Listed(tItemId, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the second item's settings are listed")
    Do $$$AssertTrue(tBefore [ ("""Item"":""" _ ..#SECOND _ """"), "every row names the second item: " _ $Extract(tBefore, 1, 200))
    Do $$$AssertTrue($Length(tBefore, """Item"":""") > 10, "and there are rows")
    Do $$$AssertEquals($Length(tBefore, """Item"":""" _ ..#SECOND _ """") - 1, $Length(tBefore, """Item"":""") - 1, "none names another item")
    Set tIdsListed = $ClassMethod(..#IDENTITY, "VendorIds")
    Do $$$AssertStatusOK($ClassMethod(..#ITEMS, "Recompile"), "the production class is compiled after the list was read")
    Set tIdsNow = $ClassMethod(..#IDENTITY, "VendorIds")
    Do $$$AssertTrue($ClassMethod(..#IDENTITY, "Renumbered", tIdsListed, tIdsNow), "the compile renumbered every item: " _ tIdsListed _ " then " _ tIdsNow)
    Do $$$AssertEquals(..Listed(tItemId), tBefore, "the same rows are read after the compile")
    Set tVendorId = ""
    For tI = 1:1:$Length(tIdsNow, ",") {
        If $Piece($Piece(tIdsNow, ",", tI), "=", 1) = ..#SECOND Set tVendorId = $Piece($Piece(tIdsNow, ",", tI), "=", 2)
    }
    Do $$$AssertTrue(tVendorId '= "", "the second item has an integer id: " _ tIdsNow)
    Do ..Listed(tVendorId, .tBare)
    Do $$$AssertEquals(tBare, 400, "the vendor's integer id alone names no item")
    Do ..Listed($Parameter(..#CONTROL, "PRODUCTION") _ "||" _ tVendorId, .tConfigName)
    Do $$$AssertEquals(tConfigName, 404, "and neither does it as the vendor's config name")
}

/// <p>The item <var>pItem</var>'s settings list through the port, as the rows' JSON, the status in
/// <var>pHttp</var>; <code>""</code> when none were answered.</p>
ClassMethod Listed(pItem As %String, Output pHttp As %Integer) As %String
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("item") = pItem
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "Settings", "LIST", .tQuery, "", .tRows, .pHttp, .tFault)
    Quit $Select($IsObject($Get(tRows)): tRows.%ToJSON(), 1: "")
}

}
