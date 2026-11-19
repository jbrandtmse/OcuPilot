/// <p>Pins the edges of Story 24.12's quality measure element and documentation writes (Batch 3: AD-8, AD-10, AD-22, AD-34, AD-61, AD-65) against <code>USER</code>: a linked measure's groups
/// and documentation are its master's, so every one of the six writes is refused 409 <code>LINKEDPARTS</code> at the port, the person's call and the agent's mint; two classes that declare one
/// measure's name refuse every write before any write; a class of OcuPilot's own is refused by every caller; a compile the instance refuses, armed through
/// <class>OcuPilot.Test.AnalyticsListingGroupSeam</class>, leaves the class text and the registry as they were before each write and each records its audit row; a class changed after a proposal was
/// minted closes it as target-changed; the baseline ships four keys on and two off; and the gate refuses, in process and before any write, a caller without <code>%DeepSee_PortalEdit:USE</code> and
/// one without <code>%Development:USE</code>. The helpers are <class>OcuPilot.Test.AnalyticsQualityMeasurePartBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes marker-named measures and classes in <code>USER</code>.</p>
Class OcuPilot.Test.AnalyticsQualityMeasurePartWriteEdge Extends OcuPilot.Test.AnalyticsQualityMeasurePartBase
{

Parameter ATELIERSEAM = "OcuPilot.Test.AnalyticsListingGroupAtelier";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#ATELIERSEAM, "Reset")
    Quit ##super()
}

/// <p>The six writes on the measure <var>pName</var> as <code>$ListBuild(label, endpoint, type, id, body JSON)</code>: an element add, change and remove and an item add, change and remove, each
/// naming parts a measure with the fixtures' groups and documentation holds or may take.</p>
ClassMethod Writes(pName As %String) As %List
{
    Quit $ListBuild($ListBuild("an element add", ..#ELEMENTENDPOINT, "ENTRYADD", ..ElementId(pName, "Long", "Edge"), {"Caption": "x"}.%ToJSON()), $ListBuild("an element change", ..#ELEMENTENDPOINT, "ENTRYSET", ..ElementId(pName, "Long", "Over30"), {"Caption": "x"}.%ToJSON()), $ListBuild("an element removal", ..#ELEMENTENDPOINT, "ENTRYREMOVE", ..ElementId(pName, "Long", "Retired"), "{}"), $ListBuild("an item add", ..#METAENDPOINT, "ENTRYADD", ..MetaId(pName, "Edge"), {"Caption": "x"}.%ToJSON()), $ListBuild("an item change", ..#METAENDPOINT, "ENTRYSET", ..MetaId(pName, "Purpose"), {"Caption": "x"}.%ToJSON()), $ListBuild("an item removal", ..#METAENDPOINT, "ENTRYREMOVE", ..MetaId(pName, "Purpose"), "{}"))
}

/// <p>The port holds the composite separator as a literal, so that it compiles where this product's classes are not mapped; it is the one <class>OcuPilot.Kernel.EntityId</class> splits and joins by.</p>
/// <p>Mutation (Rule 19): make <parameter>PARTSEPARATOR</parameter> of <class>OcuPilot.Port.AnalyticsPort</class> 2 -- this goes red.</p>
Method TestThePartSeparatorIsTheCompositeSeparator()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.AnalyticsPort).#PARTSEPARATOR, ##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR, "the port's part separator is the id separator")
    Quit
}

/// <p>AC1: a linked measure's own model holds no group or item, and the classic page shows its master's as read-only, so each of the six writes is refused 409
/// <code>ANALYTICS.QUALITYMEASURE.LINKEDPARTS</code> by the port, before the part is looked for; the person's three routes and the agent's six mints are refused with the same code; nothing is written.</p>
/// <p>Mutation (Rule 19): make the linked check of <method>OcuPilot.Port.AnalyticsPort.VendorQualityMeasureCompose</method> answer 0 -- the port legs go red; make the linked check of
/// <method>OcuPilot.Port.AnalyticsPort.ReadQualityMeasure</method> answer 0 -- the person's and the mint's legs go red.</p>
Method TestALinkedMeasureRefusesEverySixPartWrites()
{
    Set tMaster = ..Name("Master")
    Set tLinked = ..Name("Linked")
    Do $$$AssertStatusOK(..SaveMeasure("Master", ..#CLASSMARKER _ "Master"), "a master measure is saved and compiled")
    Do $$$AssertStatusOK(..SaveMeasure("Linked", ..#CLASSMARKER _ "Linked", tMaster), "and a measure linked to it")
    Set tBefore = ..Snapshot()
    Set tWrites = ..Writes(tLinked)
    For tAt = 1:1:$ListLength(tWrites) {
        Set tWrite = $List(tWrites, tAt)
        Do $$$AssertEquals(..Port($List(tWrite, 2), $List(tWrite, 3), $List(tWrite, 4), ##class(%DynamicAbstractObject).%FromJSON($List(tWrite, 5)), "", .tRes), "409 ANALYTICS.QUALITYMEASURE.LINKEDPARTS", $List(tWrite, 1) _ " is refused by the port")
    }
    Do $$$AssertEquals(..Act(..#ELEMENTSCREEN, "set", ..ElementId(tLinked, "Long", "Over30"), {"Caption": "x"}, .tAnswer) _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "409 ANALYTICS.QUALITYMEASURE.LINKEDPARTS", "the person's Change element is refused")
    Do $$$AssertEquals(..Act(..#METASCREEN, "remove", ..MetaId(tLinked, "Purpose"), "", .tAnswer) _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "409 ANALYTICS.QUALITYMEASURE.LINKEDPARTS", "and so is the person's Remove documentation item")
    Do $$$AssertEquals(..Post("/analytics/quality-measure-metas", {"QualityMeasure": (tLinked), "Name": "Edge"}, .tAnswer) _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "409 ANALYTICS.QUALITYMEASURE.LINKEDPARTS", "and the person's Add documentation item")
    Do ..MintRefused(..#ELEMENTADDTOOL, {"QualityMeasure": (tLinked), "Group": "Long", "Name": "Edge"}, "ANALYTICS.QUALITYMEASURE.LINKEDPARTS")
    Do ..MintRefused(..#ELEMENTSETTOOL, {"QualityMeasure": (tLinked), "Group": "Long", "Name": "Over30", "Caption": "x"}, "ANALYTICS.QUALITYMEASURE.LINKEDPARTS")
    Do ..MintRefused(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tLinked), "Group": "Long", "Name": "Retired"}, "ANALYTICS.QUALITYMEASURE.LINKEDPARTS")
    Do ..MintRefused(..#METAADDTOOL, {"QualityMeasure": (tLinked), "Name": "Edge"}, "ANALYTICS.QUALITYMEASURE.LINKEDPARTS")
    Do ..MintRefused(..#METASETTOOL, {"QualityMeasure": (tLinked), "Name": "Purpose", "Caption": "x"}, "ANALYTICS.QUALITYMEASURE.LINKEDPARTS")
    Do ..MintRefused(..#METAREMOVETOOL, {"QualityMeasure": (tLinked), "Name": "Purpose"}, "ANALYTICS.QUALITYMEASURE.LINKEDPARTS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
}

/// <p>AC1: two classes that declare the measure's name refuse every part write, each 409 <code>ANALYTICS.QUALITYMEASURE.AMBIGUOUS</code> and before any write, at the port, at the person's call for
/// each write shape (an element add, change and removal, a group's change and removal, an item add, change and removal) and at the agent's six mints. The classes, their text and the registry are
/// as they were.</p>
/// <p>Mutation (Rule 19): drop the ambiguity check from <method>OcuPilot.Port.AnalyticsPort.PlanQualityMeasure</method> -- the six port legs go red; drop the one in
/// <method>OcuPilot.Port.AnalyticsPort.ReadQualityMeasure</method> -- the six mint legs go red.</p>
Method TestTwoClassesThatDeclareAMeasureRefuseEveryPartWrite()
{
    Set tName = ..Name("Twin")
    Set tClass = ..#CLASSMARKER _ "Twin"
    Do $$$AssertStatusOK(..SaveMeasure("Twin", tClass), "the measure is saved and compiled")
    Do $$$AssertStatusOK(..SaveMeasure("Twin", ..#CLASSMARKER _ "TwinSecond"), "a second class declares the same name, and compiles")
    Set tBefore = ..Snapshot()
    Set tWrites = ..Writes(tName)
    For tAt = 1:1:$ListLength(tWrites) {
        Set tWrite = $List(tWrites, tAt)
        Do $$$AssertEquals(..Port($List(tWrite, 2), $List(tWrite, 3), $List(tWrite, 4), ##class(%DynamicAbstractObject).%FromJSON($List(tWrite, 5)), "", .tRes), "409 ANALYTICS.QUALITYMEASURE.AMBIGUOUS", $List(tWrite, 1) _ " is refused")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node was added or lost")
    Do ..EnableKey("analytics.qualitymeasureelements.remove")
    Do ..EnableKey("analytics.qualitymeasuremetas.remove")
    Set tAmbiguous = "409 ANALYTICS.QUALITYMEASURE.AMBIGUOUS"
    Set tCases = $ListBuild($ListBuild("the person's Add element", "/analytics/quality-measure-elements", "", "", {"QualityMeasure": (tName), "Group": "Long", "Name": "Edge"}.%ToJSON()), $ListBuild("the person's Change element", ..#ELEMENTSCREEN, "set", ..ElementId(tName, "Long", "Over30"), {"Caption": "x"}.%ToJSON()), $ListBuild("the person's Remove element", ..#ELEMENTSCREEN, "remove", ..ElementId(tName, "Long", "Retired"), ""), $ListBuild("the person's change of a group", ..#ELEMENTSCREEN, "set", ..ElementId(tName, "Long", ""), {"GroupCaption": "x"}.%ToJSON()), $ListBuild("the person's Remove group", ..#ELEMENTSCREEN, "remove-group", ..ElementId(tName, "Long", ""), ""), $ListBuild("the person's Add documentation item", "/analytics/quality-measure-metas", "", "", {"QualityMeasure": (tName), "Name": "Edge"}.%ToJSON()), $ListBuild("the person's Change documentation item", ..#METASCREEN, "set", ..MetaId(tName, "Purpose"), {"Caption": "x"}.%ToJSON()), $ListBuild("the person's Remove documentation item", ..#METASCREEN, "remove", ..MetaId(tName, "Purpose"), ""))
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Set tValues = $Select($List(tCase, 5) = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 5)))
        Kill tAnswer
        Set tStatus = $Select($List(tCase, 3) = "": ..Post($List(tCase, 2), tValues, .tAnswer), 1: ..Act($List(tCase, 2), $List(tCase, 3), $List(tCase, 4), tValues, .tAnswer))
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), tAmbiguous, $List(tCase, 1) _ " is refused")
    }
    Do ..MintRefused(..#ELEMENTADDTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Edge"}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do ..MintRefused(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Over30", "Caption": "x"}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do ..MintRefused(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": ""}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do ..MintRefused(..#METAADDTOOL, {"QualityMeasure": (tName), "Name": "Edge"}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do ..MintRefused(..#METASETTOOL, {"QualityMeasure": (tName), "Name": "Purpose", "Caption": "x"}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do ..MintRefused(..#METAREMOVETOOL, {"QualityMeasure": (tName), "Name": "Purpose"}, "ANALYTICS.QUALITYMEASURE.AMBIGUOUS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and still nothing was written")
}

/// <p>AD-10: a write whose measure's class is one of OcuPilot's own is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> with the published sentence, by the port, by the person's call and by the agent's
/// mint, with nothing written, for each write shape (an element add, change and removal, a group's change and removal, an item add, change and removal), on Batch 1's probe measure, whose class
/// has that stem: its class text and its model are as they were.</p>
/// <p>Mutation (Rule 19): make the own-code check of <method>OcuPilot.Port.AnalyticsPort.PlanQualityMeasure</method> and the one in <method>OcuPilot.Port.AnalyticsPort.ReadQualityMeasure</method> answer 0 -- every leg goes red;
/// move the plan's check after <method>OcuPilot.Port.AnalyticsPort.WriteClass</method> -- the text and model legs go red.</p>
Method TestOwnCodeIsRefusedByEveryPartWrite()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateQualityMeasures"), "Batch 1's probe measures are saved and compiled, their classes in an OcuPilot package")
    Set tOwn = $Parameter(..#PROBE, "QMCOMPILED")
    Set tOwnClass = $Parameter(..#PROBE, "QMCOMPILEDCLASS")
    Set tOwnText = ..TextOf(tOwnClass)
    Set tOwnModel = ..QModel(tOwn)
    Do ..EnableKey("analytics.qualitymeasureelements.remove")
    Do ..EnableKey("analytics.qualitymeasuremetas.remove")
    Set tElement = {"QualityMeasure": (tOwn), "Group": "Long", "Name": "Edge", "Caption": "x"}
    Do ..AssertOwnCodeRefused("an element add", ..#ELEMENTENDPOINT, "ENTRYADD", ..ElementId(tOwn, "Long", "Edge"), {"Caption": "x"}, "", "/analytics/quality-measure-elements", "", tElement, ..#ELEMENTADDTOOL, tElement)
    Do ..AssertOwnCodeRefused("an element change", ..#ELEMENTENDPOINT, "ENTRYSET", ..ElementId(tOwn, "Long", "Over30"), {"Caption": "x"}, "", ..#ELEMENTSCREEN, "set", {"Caption": "x"}, ..#ELEMENTSETTOOL, {"QualityMeasure": (tOwn), "Group": "Long", "Name": "Over30", "Caption": "x"})
    Do ..AssertOwnCodeRefused("an element removal", ..#ELEMENTENDPOINT, "ENTRYREMOVE", ..ElementId(tOwn, "Long", "Over30"), {}, "", ..#ELEMENTSCREEN, "remove", "", ..#ELEMENTREMOVETOOL, {"QualityMeasure": (tOwn), "Group": "Long", "Name": "Over30"})
    Do ..AssertOwnCodeRefused("a group change", ..#ELEMENTENDPOINT, "ENTRYSET", ..ElementId(tOwn, "Long", ""), {"GroupCaption": "x"}, "", ..#ELEMENTSCREEN, "set", {"GroupCaption": "x"}, ..#ELEMENTSETTOOL, {"QualityMeasure": (tOwn), "Group": "Long", "Name": "", "GroupCaption": "x"})
    Do ..AssertOwnCodeRefused("a group removal", ..#ELEMENTENDPOINT, "ENTRYREMOVE", ..ElementId(tOwn, "Long", ""), {}, "", ..#ELEMENTSCREEN, "remove-group", "", ..#ELEMENTREMOVETOOL, {"QualityMeasure": (tOwn), "Group": "Long", "Name": ""})
    Set tItem = {"QualityMeasure": (tOwn), "Name": "Edge", "Caption": "x"}
    Do ..AssertOwnCodeRefused("an item add", ..#METAENDPOINT, "ENTRYADD", ..MetaId(tOwn, "Edge"), {"Caption": "x"}, "", "/analytics/quality-measure-metas", "", tItem, ..#METAADDTOOL, tItem)
    Do ..AssertOwnCodeRefused("an item change", ..#METAENDPOINT, "ENTRYSET", ..MetaId(tOwn, "Purpose"), {"Caption": "x"}, "", ..#METASCREEN, "set", {"Caption": "x"}, ..#METASETTOOL, {"QualityMeasure": (tOwn), "Name": "Purpose", "Caption": "x"})
    Do ..AssertOwnCodeRefused("an item removal", ..#METAENDPOINT, "ENTRYREMOVE", ..MetaId(tOwn, "Purpose"), {}, "", ..#METASCREEN, "remove", "", ..#METAREMOVETOOL, {"QualityMeasure": (tOwn), "Name": "Purpose"})
    Do $$$AssertEquals(..QRegistered(tOwn, tOwnClass), 1, "and the measure is still there")
    Do $$$AssertEquals(..TextOf(tOwnClass), tOwnText, "its class text is as it was")
    Do $$$AssertEquals(..QModel(tOwn), tOwnModel, "and so is its model")
}

/// <p>AC3: a compile the instance refuses, after the pre-checks passed, undoes each of the six writes: the class text, the model and the registry equal their state before it, a measure that was not
/// compiled is saved back and not compiled, and each answers 422 <code>ANALYTICS.QUALITYMEASURE.COMPILE</code> and records one audit row under its own verb with the outcome restored.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.RestoreClass</method> do nothing -- the text, model and snapshot legs go red; drop its <code>&amp;&amp; pCompiled</code> -- the outcome
/// leg of the not-compiled measure goes red.</p>
Method TestARefusedCompileUndoesEachPartWrite()
{
    Set tName = ..Name("Undo")
    Set tClass = ..#CLASSMARKER _ "Undo"
    Set tOff = ..Name("UndoOff")
    Set tOffClass = ..#CLASSMARKER _ "UndoOff"
    Do $$$AssertStatusOK(..SaveMeasure("Undo", tClass, "", "[Long]/[Everyone]", "", 1), "the measure is saved and compiled")
    Do ..SaveMeasure("UndoOff", tOffClass, "", "[Long]/[Missing]")
    Do $$$AssertEquals(..QRegistered(tOff, tOffClass), 0, "a second measure is saved and its compile is refused, so it is registered and not compiled")
    Set tText = ..TextOf(tClass)
    Set tModel = ..QModel(tName)
    Set tOffText = ..TextOf(tOffClass)
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = "422 ANALYTICS.QUALITYMEASURE.COMPILE"
    Set tCases = $ListBuild($ListBuild(..#ELEMENTENDPOINT, "ENTRYADD", ..ElementId(tName, "Long", "UndoNew"), {"Caption": "x"}.%ToJSON(), "analytics.qualitymeasureelements.add"), $ListBuild(..#ELEMENTENDPOINT, "ENTRYSET", ..ElementId(tName, "Long", "Over30"), {"Caption": "x"}.%ToJSON(), "analytics.qualitymeasureelements.set"), $ListBuild(..#ELEMENTENDPOINT, "ENTRYREMOVE", ..ElementId(tName, "Long", "Retired"), "{}", "analytics.qualitymeasureelements.remove"), $ListBuild(..#ELEMENTENDPOINT, "ENTRYREMOVE", ..ElementId(tName, "Idle", ""), "{}", "analytics.qualitymeasureelements.remove"), $ListBuild(..#METAENDPOINT, "ENTRYADD", ..MetaId(tName, "UndoNew"), {"Content": "x"}.%ToJSON(), "analytics.qualitymeasuremetas.add"), $ListBuild(..#METAENDPOINT, "ENTRYSET", ..MetaId(tName, "Purpose"), {"Caption": "x"}.%ToJSON(), "analytics.qualitymeasuremetas.set"), $ListBuild(..#METAENDPOINT, "ENTRYREMOVE", ..MetaId(tName, "Purpose"), "{}", "analytics.qualitymeasuremetas.remove"))
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
        Do $$$AssertEquals(..Compiling($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4))), tCode, $List(tCase, 5) _ ": the refused compile answers the compile's code")
        Do $$$AssertEquals(..TextOf(tClass), tText, $List(tCase, 5) _ ": the class text is as it was")
        Do $$$AssertEquals(..QModel(tName), tModel, $List(tCase, 5) _ ": the model is as it was")
        Set tType = $Select($List(tCase, 1) = ..#ELEMENTENDPOINT: "quality-measure-element", 1: "quality-measure-meta")
        Do $$$AssertEquals(..Rows(tSince, tType, $List(tCase, 3), $List(tCase, 5)), 1, $List(tCase, 5) _ ": the write recorded one audit row")
        Do $$$AssertTrue(..Recorded(tSince, $List(tCase, 3), $List(tCase, 5), "restored", tType), $List(tCase, 5) _ ": with the outcome restored")
    }
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "the measure is compiled and registered again")
    Do $ClassMethod(..#ATELIERSEAM, "Arm", 1)
    Do $$$AssertEquals(..Compiling(..#ELEMENTENDPOINT, "ENTRYADD", ..ElementId(tOff, "Missing", "Seed"), {}), tCode, "an add that makes the expression of a measure that was not compiled hold answers the compile's code")
    Do $$$AssertEquals(..TextOf(tOffClass) _ "|" _ ..QRegistered(tOff, tOffClass), tOffText _ "|0", "its text is saved back and it is not compiled")
    Do $$$AssertEquals(..Recorded(tSince, ..ElementId(tOff, "Missing", "Seed"), "analytics.qualitymeasureelements.add", "restored", "quality-measure-element"), 1, "and its audit row records the outcome restored, so the restore did not try to compile the saved-back text")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class was added or left and no node changed")
    Do $$$AssertEquals(..Compiling(..#ELEMENTENDPOINT, "ENTRYSET", ..ElementId(tName, "Long", "Over30"), {"Caption": "applied"}), "200 ", "with no failure armed the same write applies")
}

/// <p>AC5: a class changed after a proposal was minted closes the proposal as target-changed, 409 <code>PROPOSAL.TARGETCHANGED</code>, and nothing is written, for the change and the removal of an
/// element and of an item; and the baseline ships the four adds and changes on and the two removals off, which the governance gate reads.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.QualityMeasureElementRow</method> answer an empty <code>Version</code> -- the element legs go red; make
/// <method>OcuPilot.Port.AnalyticsPort.QualityMeasureMetaRow</method> answer one -- the item legs go red; flip a removal's line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> --
/// the key leg goes red.</p>
Method TestAChangedClassClosesTheProposalAndTheBaselineShipsTwoKeysOff()
{
    Set tName = ..Name("Stale")
    Set tClass = ..#CLASSMARKER _ "Stale"
    Do $$$AssertStatusOK(..SaveMeasure("Stale", tClass), "the measure is saved and compiled")
    Do ..EnableKey("analytics.qualitymeasureelements.remove")
    Do ..EnableKey("analytics.qualitymeasuremetas.remove")
    Do ..AssertStale(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Over30", "Caption": "from the agent"}, "Stale", tClass, "changed")
    Do ..AssertStale(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Retired"}, "Stale", tClass, "changedAgain")
    Do ..AssertStale(..#METASETTOOL, {"QualityMeasure": (tName), "Name": "Purpose", "Caption": "from the agent"}, "Stale", tClass, "changedThird")
    Do ..AssertStale(..#METAREMOVETOOL, {"QualityMeasure": (tName), "Name": "Purpose"}, "Stale", tClass, "changedLast")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    For tCase = $ListBuild("analytics.qualitymeasureelements.add", 1), $ListBuild("analytics.qualitymeasureelements.set", 1), $ListBuild("analytics.qualitymeasureelements.remove", 0), $ListBuild("analytics.qualitymeasuremetas.add", 1), $ListBuild("analytics.qualitymeasuremetas.set", 1), $ListBuild("analytics.qualitymeasuremetas.remove", 0) {
        Kill tDecision
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Gate).Decide($List(tCase, 1), "write", $Username, {}, .tDecision), $List(tCase, 1) _ ": the gate decides")
        Do $$$AssertEquals($Get(tDecision("allowed")) _ "|" _ $Get(tDecision("code")), $List(tCase, 2) _ "|" _ $Select($List(tCase, 2): "", 1: ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED), $List(tCase, 1) _ ": allowed or denied by the baseline")
    }
}

/// <p>AC1: in process, through the gate seam, a write is refused before any write for a caller without <code>%DeepSee_PortalEdit:USE</code> (403 naming it, the screen's own pair) and for one without
/// <code>%Development:USE</code> (403 naming it, one of the pairs <code>AtelierPort.Pairs</code> adds), each for the six writes.</p>
/// <p>Mutation (Rule 19): drop <code>AtelierPort.Pairs()</code> from <method>OcuPilot.Port.AnalyticsPort.AdmitClassWrite</method> -- the <code>%Development:USE</code> legs go red.</p>
Method TestAWriteIsRefusedWithoutItsPairsBeforeAnyWrite()
{
    Set tName = ..Name("Gate")
    Set tClass = ..#CLASSMARKER _ "Gate"
    Do $$$AssertStatusOK(..SaveMeasure("Gate", tClass), "the measure is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tText = ..TextOf(tClass)
    Set tWrites = ..Writes(tName)
    For tExcept = "%DeepSee_PortalEdit:USE", "%Development:USE" {
        Do ..HoldEverythingBut(tExcept)
        For tAt = 1:1:$ListLength(tWrites) {
            Set tWrite = $List(tWrites, tAt)
            Set tResult = ..Seamed($List(tWrite, 2), $List(tWrite, 3), $List(tWrite, 4), ##class(%DynamicAbstractObject).%FromJSON($List(tWrite, 5)), .tRes)
            Do $$$AssertEquals(tResult, "403 AUTH.NOPRIVILEGE|" _ tExcept, $List(tWrite, 1) _ " without " _ tExcept _ " is refused naming it: " _ tResult)
        }
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "no class or node was written")
    Do $$$AssertEquals(..TextOf(tClass), tText, "and the class text is as it was")
}

}
