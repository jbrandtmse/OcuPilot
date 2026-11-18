/// <p>Pins the edges of Story 24.11's listing group writes (Batch 2: AD-8, AD-22, AD-34, AD-61, AD-65) against <code>USER</code>: two classes that declare one group's name refuse every
/// write before any write; a compile the instance refuses, armed through <class>OcuPilot.Test.AnalyticsListingGroupSeam</class>, leaves the class text and the registry as they were
/// before each of the six writes that compile (a created class is deleted, a changed one is saved back and, when the group was registered, compiled again) and each records its audit
/// row; a class changed after a proposal was minted closes it as target-changed; the baseline ships five keys on and two off; and the gate refuses, in process and before any write,
/// a caller without <code>%Development:USE</code> and one without <code>%DeepSee_ListingGroupEdit:USE</code>. The helpers are
/// <class>OcuPilot.Test.AnalyticsListingGroupBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes marker-named groups and classes in <code>USER</code>.</p>
Class OcuPilot.Test.AnalyticsListingGroupWriteEdge Extends OcuPilot.Test.AnalyticsListingGroupBase
{

Parameter ATELIERSEAM = "OcuPilot.Test.AnalyticsListingGroupAtelier";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#ATELIERSEAM, "Reset")
    Quit ##super()
}

/// <p>AC1: two classes that declare the group's name refuse every write that is keyed by the name, each 409 <code>ANALYTICS.LISTINGGROUP.AMBIGUOUS</code> and before any write, for an
/// update, a copy, a delete and the three listing writes; an add of the name is refused as taken. The classes, their text and the registry are as they were.</p>
/// <p>Mutation (Rule 19): drop the ambiguity check from <method>OcuPilot.Port.AnalyticsPort.PlanListingGroup</method> -- every leg goes red.</p>
Method TestTwoClassesThatDeclareAGroupRefuseEveryWrite()
{
    Set tName = ..#MARKER _ "Twin"
    Set tClass = ..#CLASSMARKER _ "Twin"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWTwinOne"), "the group is saved and compiled")
    ; The second class declares the same name over a cube that is not there, so its compile is refused and it stays a saved class.
    Do ..SaveGroup(tName, ..#CLASSMARKER _ "TwinSaved", "LGWTwinTwo", "OcuPilotProbeNoSuchCube")
    Do $$$AssertEquals(..Registered(tName, tClass), 1, "the first class is the compiled one")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tClass)
    Set tId = ..IdOf(tName, "LGWTwinOne")
    Set tCode = "409 ANALYTICS.LISTINGGROUP.AMBIGUOUS"
    Do $$$AssertEquals(..Port("ListingGroups", "UPDATE", tName, {"Caption": "x"}, "", .tRes), tCode, "an update is refused")
    Do $$$AssertEquals(..Port("ListingGroups", "COPY", tName, {}, {"newName": (..#MARKER _ "TwinCopy"), "newClass": (..#CLASSMARKER _ "TwinCopy"), "targetCubes": (..#CATEGORIES)}, .tRes), tCode, "a copy is refused")
    Do $$$AssertEquals(..Port("ListingGroups", "DELETE", tName, {}, "", .tRes), tCode, "a delete is refused")
    Do $$$AssertEquals(..Port("ListingGroupListings", "ENTRYADD", ..IdOf(tName, "LGWNew"), {}, "", .tRes), tCode, "a listing add is refused")
    Do $$$AssertEquals(..Port("ListingGroupListings", "ENTRYSET", tId, {"Description": "x"}, "", .tRes), tCode, "a listing change is refused")
    Do $$$AssertEquals(..Port("ListingGroupListings", "ENTRYREMOVE", tId, {}, "", .tRes), tCode, "a listing remove is refused")
    Do $$$AssertEquals(..Port("ListingGroups", "ADD", tName, {"Name": (tName), "Class": (..#CLASSMARKER _ "TwinNew"), "TargetCubes": (..#VISITS)}, "", .tRes), "409 ANALYTICS.LISTINGGROUP.TAKEN", "an add of the name is refused as taken")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node was added or lost")
    Do $$$AssertEquals(..TextOf(tClass), tText, "and the compiled class's text is unchanged")
    Do ..MintRefused(..#UPDATETOOL, {"Name": (tName), "Caption": "x"}, "ANALYTICS.LISTINGGROUP.AMBIGUOUS")
}

/// <p>AC3: a compile the instance refuses, after the pre-checks passed, undoes each of the six writes that compile. A change saves the prior text back and compiles it again, so the
/// class text, the model and the registry equal their state before the write; a group that was not registered is saved back and not compiled; an add and a copy delete the class they
/// created. Each answers 422 <code>ANALYTICS.LISTINGGROUP.COMPILE</code>, never the compiler's own text, and each records its audit row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> do nothing -- the text, model and registry legs go red.</p>
Method TestARefusedCompileUndoesEachWrite()
{
    Set tName = ..#MARKER _ "Undo"
    Set tClass = ..#CLASSMARKER _ "Undo"
    Set tOff = ..#MARKER _ "UndoOff"
    Set tOffClass = ..#CLASSMARKER _ "UndoOff"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWUndoOne"), "the group is saved and compiled")
    Do $$$AssertStatusOK(..SaveGroup(tOff, tOffClass, "LGWUndoOff", ..#CATEGORIES), "a second group is saved and compiled")
    Do ..Mint(..#UPDATETOOL, {"Name": (tOff), "Disabled": true}, .tDisableProposal, .tDisableTurn)
    If '$IsObject($Get(tDisableProposal)) Quit
    Do $$$AssertEquals(..Confirm(tDisableProposal, .tAnswer, .tRaw), 200, "the second group is disabled, which compiles it unregistered")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tDisableTurn)
    Do $$$AssertEquals(..Registered(tOff, tOffClass), 0, "it is no longer registered")
    Set tText = ..TextOf(tClass)
    Set tModel = ..Model(tClass)
    Set tOffText = ..TextOf(tOffClass)
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = "422 ANALYTICS.LISTINGGROUP.COMPILE"
    Set tId = ..IdOf(tName, "LGWUndoOne")
    For tCase = $ListBuild("ListingGroups", "UPDATE", tName, "{""Caption"":""changed""}", "analytics.listinggroups.update", tName), $ListBuild("ListingGroupListings", "ENTRYADD", ..IdOf(tName, "LGWUndoNew"), "{""Fields"":""Amount""}", "analytics.listinggrouplistings.add", ..IdOf(tName, "LGWUndoNew")), $ListBuild("ListingGroupListings", "ENTRYSET", tId, "{""Description"":""changed""}", "analytics.listinggrouplistings.set", tId), $ListBuild("ListingGroupListings", "ENTRYREMOVE", tId, "{}", "analytics.listinggrouplistings.remove", tId) {
        Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
        Set tResult = ..Compiling($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)))
        Do $$$AssertEquals(tResult, tCode, $List(tCase, 2) _ ": the refused compile answers the compile's code")
        Do $$$AssertEquals(..TextOf(tClass), tText, $List(tCase, 2) _ ": the class text is as it was")
        Do $$$AssertEquals(..Model(tClass), tModel, $List(tCase, 2) _ ": the model is as it was")
        Do $$$AssertEquals(..Registered(tName, tClass), 1, $List(tCase, 2) _ ": the group is registered again")
        Do $$$AssertEquals(..Rows(tSince, "listing-group" _ $Select($List(tCase, 1) = "ListingGroups": "", 1: "-listing"), $List(tCase, 6), $List(tCase, 5)), 1, $List(tCase, 2) _ ": the write recorded its audit row")
    }
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling("ListingGroups", "UPDATE", tOff, {"Caption": "changed"}), tCode, "an update of a group that was not registered answers the compile's code")
    Do $$$AssertEquals(..TextOf(tOffClass) _ "|" _ ..Registered(tOff, tOffClass), tOffText _ "|0", "its text is saved back and it is not compiled")
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling("ListingGroups", "ADD", ..#MARKER _ "UndoNew", {"Name": (..#MARKER _ "UndoNew"), "Class": (..#CLASSMARKER _ "UndoNew"), "TargetCubes": (..#CATEGORIES)}), tCode, "an add answers the compile's code")
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling("ListingGroups", "COPY", tName, {}, {"newName": (..#MARKER _ "UndoCopy"), "newClass": (..#CLASSMARKER _ "UndoCopy"), "targetCubes": (..#CATEGORIES)}), tCode, "a copy answers the compile's code")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class was added or left and no node changed")
    Do $$$AssertEquals(..Rows(tSince, "listing-group", ..#MARKER _ "UndoNew", "analytics.listinggroups.add") + ..Rows(tSince, "listing-group", ..#MARKER _ "UndoCopy", "analytics.listinggroups.copy"), 2, "the add and the copy recorded their audit rows")
    Do $$$AssertEquals(..Compiling("ListingGroups", "UPDATE", tName, {"Caption": "applied"}), "200 ", "with no failure armed the same write applies")
}

/// <p>AC5: a class changed after a proposal was minted closes the proposal as target-changed, 409 <code>PROPOSAL.TARGETCHANGED</code>, and nothing is written; and the baseline ships the five
/// writes on and the delete and the listing remove off, which the governance gate reads.</p>
/// <p>Mutation (Rule 19): drop <code>Version</code> from the update's reviewed state in <method>OcuPilot.Port.AnalyticsPort.ListingGroupRow</method> -- the stale leg goes red; flip the listing
/// remove's line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the key leg goes red.</p>
Method TestAChangedClassClosesTheProposalAndTheBaselineShipsTwoKeysOff()
{
    Set tName = ..#MARKER _ "Stale"
    Set tClass = ..#CLASSMARKER _ "Stale"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWStaleOne"), "the group is saved and compiled")
    Do ..Mint(..#UPDATETOOL, {"Name": (tName), "Caption": "from the agent"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWStaleTwo"), "the class is saved again after the mint, with another listing")
    Set tText = ..TextOf(tClass)
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409|PROPOSAL.TARGETCHANGED", "the confirm is refused as moved: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..TextOf(tClass), tText, "and the class is as the second save left it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    For tCase = $ListBuild("analytics.listinggroups.add", 1), $ListBuild("analytics.listinggroups.update", 1), $ListBuild("analytics.listinggroups.copy", 1), $ListBuild("analytics.listinggroups.delete", 0), $ListBuild("analytics.listinggrouplistings.add", 1), $ListBuild("analytics.listinggrouplistings.set", 1), $ListBuild("analytics.listinggrouplistings.remove", 0) {
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide($List(tCase, 1), "write", $Username, {}, .tDecision), $List(tCase, 1) _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), $List(tCase, 2) _ "|" _ $Select($List(tCase, 2): "", 1: ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), $List(tCase, 1) _ ": allowed or denied by the baseline")
    }
}

/// <p>AC1: a group that names a <code>resource</code> is changed only by a caller holding WRITE on it, judged in process through the gate seam while every other pair is held: an update, a
/// delete and a copy of the group are each refused 403 naming <code>resource:WRITE</code> and write nothing, and so is an add that names a resource the caller cannot write. A copy of a
/// group that names none needs no such pair, whatever resource another group names. With the WRITE held the same four writes are made, so each refusal is the resource's alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.ResourceDenied</method> answer 0 -- every refusal leg goes red.</p>
Method TestAGroupsResourceGuardsItsWrites()
{
    Set tResource = "%DeepSee_PortalEdit"
    Set tDenied = "403 AUTH.NOPRIVILEGE|" _ tResource _ ":WRITE"
    Set tGuarded = ..#MARKER _ "Guarded"
    Set tGuardedClass = ..#CLASSMARKER _ "Guarded"
    Set tPlain = ..#MARKER _ "Plain"
    Set tPlainClass = ..#CLASSMARKER _ "Plain"
    Do $$$AssertStatusOK(..SaveGroup(tGuarded, tGuardedClass, "LGWGuardedOne", ..#VISITS, tResource), "the group that names a resource is saved and compiled")
    Do $$$AssertStatusOK(..SaveGroup(tPlain, tPlainClass, "LGWPlainOne", ..#CATEGORIES), "a group that names none is saved and compiled over the other cube")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tGuardedClass)
    Do ..HoldEverythingBut("")
    Set tCopy = {"newName": (..#MARKER _ "GuardedCopy"), "newClass": (..#CLASSMARKER _ "GuardedCopy"), "targetCubes": (..#CATEGORIES)}
    Do $$$AssertEquals(..Seamed("ListingGroups", "UPDATE", tGuarded, {"Caption": "x"}, .tRes), tDenied, "an update of the guarded group is refused naming the resource's WRITE")
    Do $$$AssertEquals(..Seamed("ListingGroups", "DELETE", tGuarded, {}, .tRes), tDenied, "a delete is refused naming it")
    Do $$$AssertEquals(..Seamed("ListingGroups", "COPY", tGuarded, {}, .tRes, tCopy), tDenied, "a copy is refused naming it")
    Do $$$AssertEquals(..Seamed("ListingGroups", "ADD", ..#MARKER _ "GuardedNew", {"Name": (..#MARKER _ "GuardedNew"), "Class": (..#CLASSMARKER _ "GuardedNew"), "TargetCubes": (..#VISITS), "Resource": (tResource)}, .tRes), tDenied, "an add that names the resource is refused naming it")
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
    Do $$$AssertEquals(..TextOf(tGuardedClass), tText, "and the guarded class's text is as it was")
    Do $$$AssertEquals(..Seamed("ListingGroups", "COPY", tPlain, {}, .tRes, {"newName": (..#MARKER _ "PlainCopy"), "newClass": (..#CLASSMARKER _ "PlainCopy"), "targetCubes": (..#VISITS)}), "200 ", "a copy of a group that names no resource needs no WRITE, though another group names one")
    Do $$$AssertEquals(..Registered(..#MARKER _ "PlainCopy", ..#CLASSMARKER _ "PlainCopy"), 1, "and is compiled")
    Do $ClassMethod(..#GATE, "Hold", tResource, "WRITE")
    Do $$$AssertEquals(..Seamed("ListingGroups", "UPDATE", tGuarded, {"Caption": "x"}, .tRes), "200 ", "with the WRITE held the update is made")
    Do $$$AssertEquals($Piece($Piece(..Model(tGuardedClass), "#", 1), "|", 2), "x", "and changes the caption")
    Do $$$AssertEquals(..Seamed("ListingGroups", "COPY", tGuarded, {}, .tRes, tCopy), "200 ", "the copy is made")
    Do $$$AssertEquals(..Seamed("ListingGroups", "ADD", ..#MARKER _ "GuardedNew", {"Name": (..#MARKER _ "GuardedNew"), "Class": (..#CLASSMARKER _ "GuardedNew"), "TargetCubes": (..#CATEGORIES), "Resource": (tResource)}, .tRes), "200 ", "and so is the add")
    Do $$$AssertEquals(..Seamed("ListingGroups", "DELETE", tGuarded, {}, .tRes), "200 ", "and the delete")
    Do $$$AssertEquals(..Gone(tGuarded, tGuardedClass, "LGWNone"), 1, "which removes the class and the group's nodes")
}

/// <p>AC1: in process, through the gate seam, a write is refused before any write for a caller without <code>%DeepSee_ListingGroupEdit:USE</code> (403 naming it) and for one without
/// <code>%Development:USE</code> (403 naming it, one of the pairs <code>AtelierPort.Pairs</code> adds), each for the seven writes; the read of the group needs neither.</p>
/// <p>Mutation (Rule 19): drop the edit pair from <method>OcuPilot.Port.AnalyticsPort.AdmitListingGroup</method> -- the edit leg goes red.</p>
Method TestAWriteIsRefusedWithoutItsPairsBeforeAnyWrite()
{
    Set tName = ..#MARKER _ "Gate"
    Set tClass = ..#CLASSMARKER _ "Gate"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWGateOne"), "the group is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tClass)
    Set tId = ..IdOf(tName, "LGWGateOne")
    Set tWrites = $ListBuild($ListBuild("ListingGroups", "UPDATE", tName), $ListBuild("ListingGroups", "DELETE", tName), $ListBuild("ListingGroups", "COPY", tName), $ListBuild("ListingGroups", "ADD", ..#MARKER _ "GateNew"), $ListBuild("ListingGroupListings", "ENTRYADD", ..IdOf(tName, "LGWGateNew")), $ListBuild("ListingGroupListings", "ENTRYSET", tId), $ListBuild("ListingGroupListings", "ENTRYREMOVE", tId))
    For tExcept = "%DeepSee_ListingGroupEdit:USE", "%Development:USE" {
        Do ..HoldEverythingBut(tExcept)
        For tAt = 1:1:$ListLength(tWrites) {
            Set tWrite = $List(tWrites, tAt)
            Set tResult = ..Seamed($List(tWrite, 1), $List(tWrite, 2), $List(tWrite, 3), {"Name": ($List(tWrite, 3)), "Class": (..#CLASSMARKER _ "GateNew"), "TargetCubes": (..#VISITS)}, .tRes)
            Do $$$AssertEquals(tResult, "403 AUTH.NOPRIVILEGE|" _ tExcept, $List(tWrite, 2) _ " without " _ tExcept _ " is refused naming it: " _ tResult)
        }
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node was written")
    Do $$$AssertEquals(..TextOf(tClass), tText, "and the class text is as it was")
    Do ..HoldEverythingBut("%DeepSee_ListingGroupEdit:USE")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tName
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "ListingGroups", "LISTINGGROUP", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the plain read of the group needs neither pair")
}

}
