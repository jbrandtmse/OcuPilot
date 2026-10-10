/// <p>Pins Story 20.3's item identity against a probe production in <code>USER</code> (AD-13, AD-62): an item is
/// the composite <code>[Production, Name]</code>, never the vendor's integer id, which a compile of the production
/// class renumbers. A write minted or listed before a compile therefore reaches the named item after it: an
/// agent's disable of the second item, minted before a compile and confirmed after it, disables that item and no
/// other; a person's Enable after a further compile restores it; and a Remove of one of two added items, after a
/// compile, removes the one named and leaves the other in the configuration and in the class. An agent's add
/// minted in <code>USER</code> and confirmed from another namespace's scope is judged and written in
/// <code>USER</code>.</p>
/// <p>It shares <class>OcuPilot.Test.InteropItemControl</class>'s helpers and its probe. <b>What it needs from
/// the environment:</b> the same as that class, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because it compiles and <b>runs a probe production in <code>USER</code></b> (nothing is started). One class per
/// run.</p>
Class OcuPilot.Test.InteropItemIdentity Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

/// <p>The probe's second item, a business service: not the first item of the production, so a write that took
/// the first item instead of the named one would change the wrong item.</p>
Parameter SERVICE = "OcuPilotProbeSvc";

Parameter FIRST = "OcuP203IdentityA";

Parameter SECOND = "OcuP203IdentityB";

/// <p>A namespace that runs interoperability and holds no probe production, for a confirm scoped elsewhere.</p>
Parameter OTHERSCOPE = "HSCUSTOM";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemIdentity compiles a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left stopped with its items as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The vendor's integer id of every item of the probe production, <code>Name=Id</code> in name order,
/// comma-separated: the number a compile of the production class changes.</p>
ClassMethod VendorIds() As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, ID FROM Ens_Config.Item WHERE Production = ? ORDER BY Name", "OcuPilotProbe.Interop.Production")
        While tRS.%Next() {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRS.%GetData(1) _ "=" _ tRS.%GetData(2)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>Whether every item of the probe production that <var>pBefore</var> and <var>pAfter</var> (two
/// <method>VendorIds</method> texts) both name has a different id in the second, which is what a compile of
/// the production class does. The two texts must name the same items.</p>
ClassMethod Renumbered(pBefore As %String, pAfter As %String) As %Boolean
{
    Set tCount = $Length(pBefore, ",")
    If (pBefore = "") || (tCount '= $Length(pAfter, ",")) Quit 0
    For tI = 1:1:tCount {
        Set tOld = $Piece(pBefore, ",", tI)
        Set tNew = $Piece(pAfter, ",", tI)
        If ($Piece(tOld, "=", 1) '= $Piece(tNew, "=", 1)) || ($Piece(tOld, "=", 2) = $Piece(tNew, "=", 2)) Return 0
    }
    Quit 1
}

/// <p>AC2, AD-13: an agent's disable of the probe's second item, minted before a compile of the production class
/// and confirmed over HTTP after it, disables that item in the stored configuration and in the class and leaves
/// the first item enabled; the compile renumbered every item between the mint and the confirm, so the proposal
/// held the item by its name. The person's Enable of the same item after a further compile restores it.</p>
/// <p>Mutation (Rule 19): take the name from the production's first item in the enable and disable branch of
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> (<code>Set tName = tProduction.Items.GetAt(1).Name</code>)
/// -- the confirm disables the first item and this goes red.</p>
Method TestAnAgentsWriteMintedBeforeACompileReachesTheNamedItemAfterIt()
{
    Set tService = ..#SERVICE
    Set tIdsMinted = ..VendorIds()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.InteropItemDisable", $ClassMethod(..#CONTROL, "ArgsFor", tService), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the disable mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals($Translate(tProposal.target.id, $Char(1), "~"), $Parameter(..#CONTROL, "PRODUCTION") _ "~" _ tService, "the proposal's target is the item by its name")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Recompile"), "the production class is compiled between the mint and the confirm")
    Set tIdsConfirmed = ..VendorIds()
    Do $$$AssertTrue(..Renumbered(tIdsMinted, tIdsConfirmed), "the compile renumbered every item: " _ tIdsMinted _ " then " _ tIdsConfirmed)
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the confirm over HTTP is admitted after the compile: " _ $Extract($Get(tRaw), 1, 300))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), "OcuPilotProbeOp:1,OcuPilotProbeSvc:0", "the named item is disabled and the first item is as it was")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "ClassEnabled", tService) _ "|" _ $ClassMethod(..#CONTROL, "ClassEnabled", "OcuPilotProbeOp"), "false|true", "and the production class says the same")
    ; The person's Enable, after one more compile.
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Recompile"), "the class is compiled again before the person acts")
    Set tIdsActed = ..VendorIds()
    Do $$$AssertTrue(..Renumbered(tIdsConfirmed, tIdsActed), "the compile renumbered every item again: " _ tIdsConfirmed _ " then " _ tIdsActed)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "enable", tService, .tActed), "200 ", "the person's Enable of the same item answers 200: " _ $Select($IsObject($Get(tActed)): tActed.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE"), "the items are as they began")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "ClassEnabled", tService), "true", "and the class carries the enable")
}

/// <p>AC2, AD-13: with two items added through the person's Save, a compile of the production class renumbers
/// every item, and the person's Remove of the first added item then removes that item and no other: the second
/// stays in the stored configuration and in the class, through a further compile, until its own Remove.</p>
/// <p>Mutation (Rule 19): return the production's last item, not the named one, from
/// <method>OcuPilot.Port.InteropPort.ItemObject</method> (<code>Set tFound = pProduction.Items.GetAt(pProduction.Items.Count())</code>)
/// -- the Remove deletes the second added item and this goes red.</p>
Method TestARemoveAfterACompileTakesTheNamedItemAmongSeveral()
{
    Set tFirst = ..#FIRST
    Set tSecond = ..#SECOND
    Set tFields = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": false}
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Save", tFirst, tFields), "201 ", "the first item is saved")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Save", tSecond, tFields), "201 ", "the second item is saved")
    Set tBaseline = $Parameter(..#CONTROL, "BASELINE")
    Set tBoth = tBaseline _ "," _ tFirst _ ":0," _ tSecond _ ":0"
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBoth, "the production holds both")
    Set tIdsListed = ..VendorIds()
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Recompile"), "the production class is compiled after the list was read")
    Set tIdsRemoving = ..VendorIds()
    Do $$$AssertTrue(..Renumbered(tIdsListed, tIdsRemoving), "the compile renumbered every item: " _ tIdsListed _ " then " _ tIdsRemoving)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBoth, "and both survived it")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "remove", tFirst, .tAnswer), "200 ", "the Remove of the first item answers 200: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBaseline _ "," _ tSecond _ ":0", "the first item is gone and the second stays")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "ClassEnabled", tFirst) _ "|" _ $ClassMethod(..#CONTROL, "ClassEnabled", tSecond), "absent|false", "in the production class too")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Recompile"), "the class is compiled once more")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBaseline _ "," _ tSecond _ ":0", "and the compile keeps the second item")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "remove", tSecond, .tAnswer), "200 ", "the second item's own Remove answers 200")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tBaseline, "leaving the items as they began")
}

/// <p>AC2, AD-52: an agent's add minted in <code>USER</code> and confirmed while the request is scoped to
/// <parameter>OTHERSCOPE</parameter>, which holds no probe production, asks the add's rules again in
/// <code>USER</code> and adds the item there.</p>
/// <p>Mutation (Rule 19): read the namespace from the request's scope alone in
/// <method>OcuPilot.Screen.Tool.InteropItemAdd.ArgumentProblem</method> -- the confirm is refused 400 for a
/// production the other namespace does not hold, and this goes red.</p>
Method TestAnAddConfirmedFromAnotherScopeIsJudgedAndWrittenWhereItWasMinted()
{
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", ..#FIRST)
    Do tArgs.%Set("ClassName", "OcuPilotProbe.Interop.Op", "string")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool.InteropItemAdd", tArgs, $Username, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the add mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Test.InteropControl).ConfirmIn(tProposal, .tResult, .tConfirmHttp, .tCode, ..#OTHERSCOPE)
    Do $$$AssertEquals(+$Get(tConfirmHttp) _ " " _ $Get(tCode), "200 ", "the confirm from " _ ..#OTHERSCOPE _ "'s scope is admitted")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE") _ "," _ ..#FIRST _ ":0", "the item is added in USER, disabled")
}

}
