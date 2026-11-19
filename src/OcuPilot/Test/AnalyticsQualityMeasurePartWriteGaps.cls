/// <p>Pins what <class>OcuPilot.Test.AnalyticsQualityMeasurePartWrite</class> and <class>OcuPilot.Test.AnalyticsQualityMeasurePartWriteEdge</class> leave open in Story 24.12's element and
/// documentation writes (Batch 3) against <code>USER</code>: a measure whose stored documentation cannot be written again is refused before any save; the person's routes and the agent's
/// mints refuse a taken name, a part that is not there and an expression that would no longer hold, each with its own sentence and nothing written; an emptied group is changed and
/// filled again; and a write that gives an enabled element to the group a measure's expression needs compiles a measure that was only registered. The helpers are
/// <class>OcuPilot.Test.AnalyticsQualityMeasurePartBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes marker-named measures and classes in <code>USER</code>.</p>
Class OcuPilot.Test.AnalyticsQualityMeasurePartWriteGaps Extends OcuPilot.Test.AnalyticsQualityMeasurePartBase
{

/// <p>The class text of the measure <var>pId</var> in <var>pClass</var> with the documentation item <code>Purpose</code> holding a price in euros, which the model reads as an entity XML does
/// not define, saved and compiled in <code>USER</code>.</p>
ClassMethod SaveEuroMeasure(pId As %String, pClass As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tText = $Replace(..MeasureText(pId, pClass), "Counts the long visits &amp; their share.", "Costs 5 " _ $Char(8364) _ " a visit.")
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, pClass, tText)
    If $$$ISOK(tSC) {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(pClass, "ck-d")
        Set $NAMESPACE = tOrigNS
    }
    Quit tSC
}

/// <p>The agent's mint of <var>pTool</var> with <var>pArgs</var>, refused: the HTTP status, the fault's code and the sentence it carries as the problem, as <code>status code|problem</code>;
/// <code>"minted"</code> when it was not refused.</p>
ClassMethod MintFault(pTool As %String, pArgs As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    If $IsObject($Get(tProposal)) {
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
        Quit "minted"
    }
    If '$IsObject($Get(tFault)) Quit $Get(tHttp)
    Quit $Get(tHttp) _ " " _ tFault.%Get("code") _ "|" _ $Select($IsObject(tFault.%Get("detail")): tFault.detail.%Get("problem"), 1: "")
}

/// <p>The person's call answered <var>pStatus</var> and <var>pAnswer</var>: it must carry the code <var>pCode</var> with the sentence <method>OcuPilot.Api.AnalyticsError.ReasonFor</method>
/// gives it, and the instance must hold what <var>pBefore</var> (a <method>Snapshot</method>) says.</p>
Method AssertPersonRefused(pWhat As %String, pStatus As %Integer, pAnswer, pCode As %String, pBefore As %String)
{
    Set tCode = $Piece(pCode, " ", 2)
    Do $$$AssertEquals(pStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code") _ "|" _ pAnswer.%Get("reason"), 1: ""), $Piece(pCode, " ", 1) _ " " _ tCode _ "|" _ ##class(OcuPilot.Api.AnalyticsError).ReasonFor(tCode), pWhat _ ": the person's call is refused with its own sentence")
    Do $$$AssertEquals(..Snapshot(), pBefore, pWhat _ ": nothing was written")
}

/// <p>A measure whose stored documentation the model cannot write again (a price in euros reads as <code>&amp;euro;</code>, which XML does not define) is refused 422
/// <code>ANALYTICS.QUALITYMEASURE.COMPILE</code> by the port, the person's route and the agent's mint before anything is saved, and so is the measure's own update: no class text changes and,
/// since no write reached the class, no audit row is recorded. A change that replaces the item's content, and then any other write, is accepted.</p>
/// <p>Mutation (Rule 19): make the <code>%XML.Reader</code> check of <method>OcuPilot.Port.AnalyticsPort.VendorQualityMeasureCompose</method> never refuse -- the audit-row legs go red.</p>
Method TestStoredDocumentationThatCannotBeWrittenAgainIsRefusedBeforeAnySave()
{
    Set tName = ..Name("Euro")
    Set tClass = ..#CLASSMARKER _ "Euro"
    Do $$$AssertStatusOK(..SaveEuroMeasure("Euro", tClass), "the measure with a price in its documentation is saved and compiled")
    Do $$$AssertTrue(..QModel(tName) [ "&euro;", "the model reads the price as an entity: " _ ..QModel(tName))
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = "422 ANALYTICS.QUALITYMEASURE.COMPILE"
    Set tCases = $ListBuild($ListBuild(..#ELEMENTENDPOINT, "ENTRYSET", ..ElementId(tName, "Long", "Over30"), {"Caption": "x"}.%ToJSON(), "quality-measure-element", "analytics.qualitymeasureelements.set"), $ListBuild(..#ELEMENTENDPOINT, "ENTRYADD", ..ElementId(tName, "Long", "Fresh"), {"Caption": "x"}.%ToJSON(), "quality-measure-element", "analytics.qualitymeasureelements.add"), $ListBuild(..#ELEMENTENDPOINT, "ENTRYREMOVE", ..ElementId(tName, "Long", "Retired"), "{}", "quality-measure-element", "analytics.qualitymeasureelements.remove"), $ListBuild(..#METAENDPOINT, "ENTRYADD", ..MetaId(tName, "Extra"), {"Content": "y"}.%ToJSON(), "quality-measure-meta", "analytics.qualitymeasuremetas.add"), $ListBuild(..#METAENDPOINT, "ENTRYSET", ..MetaId(tName, "Purpose"), {"Caption": "x"}.%ToJSON(), "quality-measure-meta", "analytics.qualitymeasuremetas.set"))
    For tAt = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tAt)
        Do $$$AssertEquals(..Port($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)), "", .tRes), tCode, $List(tCase, 6) _ " is refused as a compile")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 6) _ ": no class text or node changed")
        Do $$$AssertEquals(..Rows(tSince, $List(tCase, 5), $List(tCase, 3), $List(tCase, 6)), 0, $List(tCase, 6) _ ": no write reached the class, so no audit row was recorded")
    }
    Do $$$AssertEquals(..Port(..#WRITEENDPOINT, "UPDATE", tName, {"Caption": "x"}, "", .tRes), tCode, "the measure's own update is refused as a compile too")
    Do $$$AssertEquals(..Snapshot(), tBefore, "the update: no class text or node changed")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", tName, "analytics.qualitymeasures.update"), 0, "the update: no write reached the class, so no audit row was recorded")
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Long", "Over30"), {"Caption": "x"}, .tAnswer)
    Do ..AssertPersonRefused("the person's Change element", tStatus, $Get(tAnswer), tCode, tBefore)
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-element", ..ElementId(tName, "Long", "Over30"), "analytics.qualitymeasureelements.set"), 0, "and it recorded no audit row")
    Do ..MintRefused(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Over30", "Caption": "x"}, "TOOL.ARGUMENTS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "the agent's mint is refused and nothing was written")
    Do $$$AssertEquals(..Port(..#METAENDPOINT, "ENTRYSET", ..MetaId(tName, "Purpose"), {"Content": "Plain text."}, "", .tRes), "200 ", "a change that replaces the stored content is accepted")
    Do $$$AssertEquals(..Port(..#ELEMENTENDPOINT, "ENTRYSET", ..ElementId(tName, "Long", "Over30"), {"Caption": "x"}, "", .tRes), "200 ", "and so is a write of another part afterwards")
    Do $$$AssertTrue(..QModel(tName) '[ "&euro;", "the price is gone from the model")
}

/// <p>A part endpoint's target that is empty, or that names a measure with no part, is refused 422 <code>PORT.FIELD.SHAPE</code> by the port's read and its writes, as any other id of another
/// grammar is, and nothing is written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.QualityMeasureTarget</method> read the measure with <code>$List</code> in place of <code>$ListGet</code> -- the empty legs go red.</p>
Method TestAnEmptyOrPartlessTargetIsAShapeRefusal()
{
    Set tName = ..Name("Blank")
    Do $$$AssertStatusOK(..SaveMeasure("Blank", ..#CLASSMARKER _ "Blank"), "the measure is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tShape = "422 PORT.FIELD.SHAPE"
    For tEndpoint = ..#ELEMENTENDPOINT, ..#METAENDPOINT {
        For tId = "", tName {
            Set tLabel = tEndpoint _ " with the id '" _ tId _ "'"
            Do $$$AssertEquals(..Port(tEndpoint, $Select(tEndpoint = ..#ELEMENTENDPOINT: "QUALITYMEASUREELEMENT", 1: "QUALITYMEASUREMETA"), tId, "", "", .tRes), tShape, tLabel _ ": the read is a shape refusal")
            For tType = "ENTRYADD", "ENTRYSET", "ENTRYREMOVE" {
                Do $$$AssertEquals(..Port(tEndpoint, tType, tId, {"Caption": "x"}, "", .tRes), tShape, tLabel _ ": " _ tType _ " is a shape refusal")
            }
        }
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "nothing was written")
}

/// <p>The person's routes refuse a taken element or item name (409 <code>ELEMENTTAKEN</code>, <code>METATAKEN</code>, without regard to case, enabled or not), a group, element or item that
/// is not there (404 <code>PARTABSENT</code>) and a write after which the expression would name a group that cannot count (422 <code>EXPRESSION</code>: removing or disabling its only
/// enabled element, removing its last element, removing it, disabling it), each with the code's own sentence, each leaving the classes and the registry as they were.</p>
/// <p>Mutation (Rule 19): make the taken check of an element add in <method>OcuPilot.Port.AnalyticsPort.ApplyQualityMeasurePart</method> compare exact names -- the case and disabled legs go red.</p>
Method TestThePersonsRoutesRefuseTakenAbsentAndExpressionWrites()
{
    Set tName = ..Name("Route")
    Do $$$AssertStatusOK(..SaveMeasure("Route", ..#CLASSMARKER _ "Route"), "the measure is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tTaken = "409 ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN"
    Set tAbsent = "404 ANALYTICS.QUALITYMEASURE.PARTABSENT"
    Set tExpression = "422 ANALYTICS.QUALITYMEASURE.EXPRESSION"
    Set tStatus = ..Post("/analytics/quality-measure-elements", {"QualityMeasure": (tName), "Group": "Long", "Name": "over30"}, .tAnswer)
    Do ..AssertPersonRefused("an element name held in other letter case", tStatus, $Get(tAnswer), tTaken, tBefore)
    Set tStatus = ..Post("/analytics/quality-measure-elements", {"QualityMeasure": (tName), "Group": "Long", "Name": "RETIRED"}, .tAnswer)
    Do ..AssertPersonRefused("an element name held by a disabled element", tStatus, $Get(tAnswer), tTaken, tBefore)
    Set tStatus = ..Post("/analytics/quality-measure-metas", {"QualityMeasure": (tName), "Name": "purpose"}, .tAnswer)
    Do ..AssertPersonRefused("an item name held in other letter case", tStatus, $Get(tAnswer), "409 ANALYTICS.QUALITYMEASURE.METATAKEN", tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Long", "Missing"), {"Caption": "x"}, .tAnswer)
    Do ..AssertPersonRefused("a change of an element that is not there", tStatus, $Get(tAnswer), tAbsent, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Nowhere", ""), {"GroupCaption": "x"}, .tAnswer)
    Do ..AssertPersonRefused("a change of a group that is not there", tStatus, $Get(tAnswer), tAbsent, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "remove", ..ElementId(tName, "Long", "Missing"), "", .tAnswer)
    Do ..AssertPersonRefused("a removal of an element that is not there", tStatus, $Get(tAnswer), tAbsent, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "remove-group", ..ElementId(tName, "Nowhere", ""), "", .tAnswer)
    Do ..AssertPersonRefused("a removal of a group that is not there", tStatus, $Get(tAnswer), tAbsent, tBefore)
    Set tStatus = ..Act(..#METASCREEN, "set", ..MetaId(tName, "Missing"), {"Caption": "x"}, .tAnswer)
    Do ..AssertPersonRefused("a change of an item that is not there", tStatus, $Get(tAnswer), tAbsent, tBefore)
    Set tStatus = ..Act(..#METASCREEN, "remove", ..MetaId(tName, "Missing"), "", .tAnswer)
    Do ..AssertPersonRefused("a removal of an item that is not there", tStatus, $Get(tAnswer), tAbsent, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "remove", ..ElementId(tName, "Long", "Over30"), "", .tAnswer)
    Do ..AssertPersonRefused("a removal of the only enabled element of a group the expression needs", tStatus, $Get(tAnswer), tExpression, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "remove", ..ElementId(tName, "Everyone", "AllVisits"), "", .tAnswer)
    Do ..AssertPersonRefused("a removal of the last element of a group the expression needs", tStatus, $Get(tAnswer), tExpression, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Long", "Over30"), {"Disabled": "true"}, .tAnswer)
    Do ..AssertPersonRefused("disabling that element", tStatus, $Get(tAnswer), tExpression, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "remove-group", ..ElementId(tName, "Everyone", ""), "", .tAnswer)
    Do ..AssertPersonRefused("a removal of a group the expression names", tStatus, $Get(tAnswer), tExpression, tBefore)
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Everyone", ""), {"GroupDisabled": "true"}, .tAnswer)
    Do ..AssertPersonRefused("disabling that group", tStatus, $Get(tAnswer), tExpression, tBefore)
}

/// <p>The agent's mints are refused what the write would refuse, with the code's own sentence as the problem: a taken name in another letter case or held by a disabled part (the exact name is
/// the mint's own 409), and a removal or disabling that leaves the expression without a group it needs, for an element, a last element, a group and a group's own flag. A part that is not
/// there is the mint's own <code>TOOL.ARGUMENTS</code>. No proposal is minted and nothing is written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.QualityMeasureProblem</method> answer the fault's code in place of its sentence -- the sentence legs go red.</p>
Method TestTheAgentsMintsAreRefusedWithTheWritesOwnSentence()
{
    Set tName = ..Name("Mint")
    Do $$$AssertStatusOK(..SaveMeasure("Mint", ..#CLASSMARKER _ "Mint"), "the measure is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tHead = "400 TOOL.ARGUMENTS|"
    Kill tGot
    Set tExpression = tHead _ ##class(OcuPilot.Api.AnalyticsError).ReasonFor("ANALYTICS.QUALITYMEASURE.EXPRESSION")
    Set tGot = ..MintFault(..#ELEMENTADDTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "RETIRED"})
    Do $$$AssertEquals(tGot, tHead _ ##class(OcuPilot.Api.AnalyticsError).ReasonFor("ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN"), "an element name held by a disabled element is refused with the taken sentence: " _ tGot)
    Set tGot = ..MintFault(..#METAADDTOOL, {"QualityMeasure": (tName), "Name": "PURPOSE"})
    Do $$$AssertEquals(tGot, tHead _ ##class(OcuPilot.Api.AnalyticsError).ReasonFor("ANALYTICS.QUALITYMEASURE.METATAKEN"), "an item name held in other letter case is refused with the taken sentence: " _ tGot)
    Set tGot = ..MintFault(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Over30"})
    Do $$$AssertEquals(tGot, tExpression, "removing the only enabled element of a group the expression needs is refused with the expression sentence: " _ tGot)
    Set tGot = ..MintFault(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Everyone", "Name": "AllVisits"})
    Do $$$AssertEquals(tGot, tExpression, "so is removing the last element of such a group: " _ tGot)
    Set tGot = ..MintFault(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Everyone", "Name": ""})
    Do $$$AssertEquals(tGot, tExpression, "so is removing the group: " _ tGot)
    Set tGot = ..MintFault(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Everyone", "Name": "", "GroupDisabled": true})
    Do $$$AssertEquals(tGot, tExpression, "and disabling the group by its own flag: " _ tGot)
    Do ..MintRefused(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Missing"}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Nowhere", "Name": ""}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Nowhere", "Name": "", "GroupCaption": "x"}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#METASETTOOL, {"QualityMeasure": (tName), "Name": "Missing", "Caption": "x"}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#METAREMOVETOOL, {"QualityMeasure": (tName), "Name": "Missing"}, "TOOL.ARGUMENTS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no proposal was minted and nothing was written")
}

/// <p>A group a removal emptied stays as its empty row and is changed and filled again: the person's change of the empty group by the payload a merged form sends (its element fields empty and
/// its element flag false) sets the group's caption and enables it, the agent's add puts an element in it, and removing that element empties it again; the group's other fields, the other
/// groups and the documentation are as they were, and both reads answer the model.</p>
/// <p>Mutation (Rule 19): make the group caption of <method>OcuPilot.Port.AnalyticsPort.ApplyQualityMeasurePart</method> apply only when an element name is given -- the group legs go red.</p>
Method TestAnEmptiedGroupIsChangedAndFilledAgain()
{
    Set tName = ..Name("Empty")
    Set tClass = ..#CLASSMARKER _ "Empty"
    Do $$$AssertStatusOK(..SaveMeasure("Empty", tClass, "", "[Long]/[Everyone]", "", 1), "the measure with spare groups is saved and compiled")
    Set tBefore = ..QModel(tName)
    Set tText = ..TextOf(tClass)
    Do $$$AssertEquals(..Act(..#ELEMENTSCREEN, "remove", ..ElementId(tName, "Off", "OffRule"), "", .tAnswer), 200, "the person removes the last element of the group Off")
    Set tExpected = $Replace(tBefore, ";E:OffRule|Off rule|{[Minutes].&[30]}|0", "")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the group stays, emptied")
    Do $$$AssertEquals(..ScreenPartRows(tName, 1), ..RowsOfModel(..QModel(tName), 1), "the screen's read answers the emptied group as its empty row")
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Off", ""), {"Caption": "", "MDX": "", "Disabled": "false", "GroupCaption": "Off, edited", "GroupDisabled": "false"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's change of the empty group answers 200: " _ $Select($IsObject($Get(tAnswer)): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject($Get(tAnswer)) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Set tExpected = $Replace(tExpected, "~G:Off|Off group|Disabled|1", "~G:Off|Off, edited|Disabled|0")
    Do $$$AssertEquals(..QModel(tName), tExpected, "only the group's caption and flag changed")
    Do ..Mint(..#ELEMENTADDTOOL, {"QualityMeasure": (tName), "Group": "Off", "Name": "Refill", "Caption": "Refilled", "MDX": "{[Minutes].&[2]}"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's add to the emptied group confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "created|matches", "created, the read-back matching")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tExpected = $Replace(tExpected, "~G:Off|Off, edited|Disabled|0", "~G:Off|Off, edited|Disabled|0;E:Refill|Refilled|{[Minutes].&[2]}|0")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the element is in the group and every other part is as it was")
    Do $$$AssertEquals(..Act(..#ELEMENTSCREEN, "remove", ..ElementId(tName, "Off", "Refill"), "", .tAnswer), 200, "removing that element empties the group again")
    Do $$$AssertEquals(..QModel(tName), $Replace(tExpected, ";E:Refill|Refilled|{[Minutes].&[2]}|0", ""), "and the group is its empty row once more")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tText), "every line outside the XData body is the same text")
    Do ..AssertReadsEqualModel(tName, 1, "after the refill and the second removal")
}

/// <p>A write that gives the group a measure's expression needs its first enabled element compiles a measure that was only registered, because its expression named a group that could not
/// count: the write is accepted, the class is saved and compiled, and the registry then holds the measure compiled.</p>
/// <p>Mutation (Rule 19): make the element's <code>Disabled</code> flag of <method>OcuPilot.Port.AnalyticsPort.ApplyQualityMeasurePart</method> apply only to an add -- the change is refused as an
/// expression and this goes red.</p>
Method TestAWriteThatMakesTheExpressionHoldCompilesARegisteredMeasure()
{
    Set tName = ..Name("Mend")
    Set tClass = ..#CLASSMARKER _ "Mend"
    Do ..SaveMeasure("Mend", tClass, "", "[Long]/[Idle]", "", 1)
    Do $$$AssertEquals(..QRegistered(tName, tClass), 0, "the measure is registered and not compiled: its expression names a group with no enabled element")
    Set tBefore = ..QModel(tName)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Idle", "IdleRule"), {"Disabled": "false"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Change element answers 200: " _ $Select($IsObject($Get(tAnswer)): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject($Get(tAnswer)) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Do $$$AssertEquals(..QModel(tName), $Replace(tBefore, "E:IdleRule|Idle rule|{[Minutes].&[30]}|1", "E:IdleRule|Idle rule|{[Minutes].&[30]}|0"), "the element is enabled and every other part is as it was")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "the measure is compiled and registered")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-element", ..ElementId(tName, "Idle", "IdleRule"), "analytics.qualitymeasureelements.set"), 1, "one audit row names the change")
}

}
