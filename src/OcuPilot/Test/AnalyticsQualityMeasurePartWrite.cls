/// <p>Pins Story 24.12's quality measure element and documentation writes (Batch 3: AD-54, AD-58, AD-61, AD-65) against <code>USER</code>, with analytics on through
/// <class>OcuPilot.Test.AnalyticsProbe</class> and measures and classes named with the part marker: the six writes (an element or group add, change and remove, a documentation item add, change and
/// remove) at both callers, the person's screen routes and the agent's proposals minted and confirmed over HTTP. Each leaves the measure as the vendor's model reads it, with every other group,
/// element, item and header field and every line of the class outside its <code>QualityMeasure</code> XData as it was, the read-back verdict <code>matches</code> (<code>notFound</code> for a remove),
/// one audit row of OcuPilot's own and, for the agent, its marker and one ledger row; the two screens' reads and the agent's read tools answer the new state; and each refusal writes nothing. The
/// helpers are <class>OcuPilot.Test.AnalyticsQualityMeasurePartBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. One class per run.</p>
Class OcuPilot.Test.AnalyticsQualityMeasurePartWrite Extends OcuPilot.Test.AnalyticsQualityMeasurePartBase
{

/// <p>AC1, AC2: the person's Add element and the agent's add proposal each add an element, the person's to an existing group with the group's caption changed, the agent's to a group the measure lacks,
/// which is created at the end with its fields. Nothing else changes; the screens' reads, the read tool and the read-back verdict <code>matches</code> agree.</p>
/// <p>Mutation (Rule 19): make an element add in <method>OcuPilot.Port.AnalyticsPort.ApplyQualityMeasurePart</method> skip the MDX -- the model legs and the read-back go red.</p>
Method TestAnElementIsAddedByEachCallerAndReadsBack()
{
    Set tName = ..Name("Add")
    Set tClass = ..#CLASSMARKER _ "Add"
    Do $$$AssertStatusOK(..SaveMeasure("Add", tClass), "the measure is saved and compiled")
    Set tBefore = ..QModel(tName)
    Set tText = ..TextOf(tClass)
    Set tId = ..ElementId(tName, "Long", "Under5")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Post("/analytics/quality-measure-elements", {"QualityMeasure": (tName), "Group": "Long", "Name": "Under5", "Caption": "Under 5", "MDX": "{[Minutes].&[5]}", "Disabled": false, "GroupCaption": "Long stays, edited"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's Add element answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, "quality-measure-element|matches", "created, the read-back matching what was sent")
    Set tExpected = $Replace($Replace(tBefore, "~G:Long|Long stays|", "~G:Long|Long stays, edited|"), "~G:Everyone", ";E:Under5|Under 5|{[Minutes].&[5]}|0~G:Everyone")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the model holds the element and the group's caption, and every other part as it was")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tText), "every line outside the XData body is the same text")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "the measure is compiled again")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-element", tId, "analytics.qualitymeasureelements.add"), 1, "one audit row names the add")

    Set tFresh = ..ElementId(tName, "Fresh", "Seed")
    Do ..Mint(..#ELEMENTADDTOOL, {"QualityMeasure": (tName), "Group": "Fresh", "Name": "Seed", "Caption": "Seed rule", "MDX": "{[Minutes].&[1]}", "GroupCaption": "Fresh group", "GroupDescription": "Made by the agent"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the add confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId _ "|" _ tAnswer.readBack.verdict, "created|" _ tFresh _ "|matches", "created, naming the element, the read-back matching")
    Set tExpected = $Replace(tExpected, "~M:Purpose", "~G:Fresh|Fresh group|Made by the agent|0;E:Seed|Seed rule|{[Minutes].&[1]}|0~M:Purpose")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the new group is at the end of the groups with its element and fields")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ELEMENTADDTOOL, tTurn, "quality-measure-element", tFresh)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..AssertReadsEqualModel(tName, 1, "after both adds")
}

/// <p>AC1, AC2: the person's Change element and the agent's change proposal change an element, the group's fields and, with an empty element name, the group alone; the group's other elements, the other
/// groups, the documentation and the class's own lines stay as they were.</p>
/// <p>Mutation (Rule 19): make the group fields in <method>OcuPilot.Port.AnalyticsPort.ApplyQualityMeasurePart</method> apply to an add only -- the person's group legs go red.</p>
Method TestAnElementAndItsGroupAreChangedByEachCaller()
{
    Set tName = ..Name("Set")
    Set tClass = ..#CLASSMARKER _ "Set"
    Do $$$AssertStatusOK(..SaveMeasure("Set", tClass), "the measure is saved and compiled")
    Set tBefore = ..QModel(tName)
    Set tText = ..TextOf(tClass)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Long", "Over30"), {"Caption": "Over 30, edited", "MDX": "{[Minutes].&[31]}", "Disabled": "false", "GroupCaption": "Long, edited", "GroupDescription": "", "GroupDisabled": "false"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Change element answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Set tExpected = $Replace($Replace(tBefore, "~G:Long|Long stays|Visits over the limit|0", "~G:Long|Long, edited||0"), "E:Over30|Over 30 minutes|{[Minutes].&[30]}|0", "E:Over30|Over 30, edited|{[Minutes].&[31]}|0")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the model holds the element and its group's fields, and the sibling and every other part as they were")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tText), "every line outside the XData body is the same text")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-element", ..ElementId(tName, "Long", "Over30"), "analytics.qualitymeasureelements.set"), 1, "one audit row names the change")
    Do $$$AssertEquals(..Act(..#ELEMENTSCREEN, "set", ..ElementId(tName, "Everyone", ""), {"GroupCaption": "Everyone, edited"}, .tAnswer), 200, "the person's change of a group alone answers 200")
    Set tExpected = $Replace(tExpected, "~G:Everyone|All visits|", "~G:Everyone|Everyone, edited|")
    Do $$$AssertEquals(..QModel(tName), tExpected, "only the group's caption changed, its element is as it was")

    Do ..Mint(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Retired", "Caption": "Retired again", "Disabled": true}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's change confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Set tExpected = $Replace(tExpected, "E:Retired|Retired rule|", "E:Retired|Retired again|")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the agent's caption is in and the rest is kept")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ELEMENTSETTOOL, tTurn, "quality-measure-element", ..ElementId(tName, "Long", "Retired"))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Mint(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "", "GroupDescription": "By the agent"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's change of a group alone confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..QModel(tName), $Replace(tExpected, "~G:Long|Long, edited||0", "~G:Long|Long, edited|By the agent|0"), "only the group's description changed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..AssertReadsEqualModel(tName, 1, "after the changes")
}

/// <p>AC1, AC2, AC5: the person's Remove element and Remove group, and the agent's remove proposals once the test turns the key on, remove an element and a group with its elements and nothing else; the
/// agent's card is destructive and states the removal; the read-back finds the part gone; the key ships off, so a remove confirmed with the baseline alone is refused
/// <code>GOVERNANCE.DISABLED</code>. An emptied group stays as its empty row.</p>
/// <p>Mutation (Rule 19): flip the element remove line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the refusal leg goes red.</p>
Method TestAnElementAndAGroupAreRemovedAndTheKeyShipsOff()
{
    Set tName = ..Name("Del")
    Set tClass = ..#CLASSMARKER _ "Del"
    Do $$$AssertStatusOK(..SaveMeasure("Del", tClass, "", "[Long]/[Everyone]", "", 1), "the measure with spare groups is saved and compiled")
    Set tBefore = ..QModel(tName)
    Set tText = ..TextOf(tClass)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act(..#ELEMENTSCREEN, "remove", ..ElementId(tName, "Long", "Retired"), "", .tAnswer), 200, "the person's Remove element runs: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Set tExpected = $Replace(tBefore, ";E:Retired|Retired rule|{[Minutes].&[99]}|1", "")
    Do $$$AssertEquals(..QModel(tName), tExpected, "only the element is gone")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-element", ..ElementId(tName, "Long", "Retired"), "analytics.qualitymeasureelements.remove"), 1, "one audit row names the removal")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act(..#ELEMENTSCREEN, "remove-group", ..ElementId(tName, "Idle", ""), "", .tAnswer), 200, "the person's Remove group runs: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Set tExpected = $Replace(tExpected, "~G:Idle|Idle group|No enabled element|0;E:IdleRule|Idle rule|{[Minutes].&[30]}|1", "")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the group and its element are gone")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-element", ..ElementId(tName, "Idle", ""), "analytics.qualitymeasureelements.remove"), 1, "one audit row names the group's removal")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tText), "every line outside the XData body is the same text")

    Do ..EnableKey("analytics.qualitymeasureelements.remove")
    Do ..Mint(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Off", "Name": "OffRule"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.QUALITYMEASURE.REMOVE|1", "the card is destructive and states the removal")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's remove is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..QModel(tName), tExpected, "and the element is still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ..EnableKey("analytics.qualitymeasureelements.remove")
    Do ..Mint(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Off", "Name": "OffRule"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "with its key on the agent's remove confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Set tExpected = $Replace(tExpected, ";E:OffRule|Off rule|{[Minutes].&[30]}|0", "")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the group stays, emptied")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ELEMENTREMOVETOOL, tTurn, "quality-measure-element", ..ElementId(tName, "Off", "OffRule"))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..AssertReadsEqualModel(tName, 1, "with an emptied group")
    Do ..EnableKey("analytics.qualitymeasureelements.remove")
    Do ..Mint(..#ELEMENTREMOVETOOL, {"QualityMeasure": (tName), "Group": "Off", "Name": ""}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's removal of the group confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding the group gone")
    Do $$$AssertEquals(..QModel(tName), $Replace(tExpected, "~G:Off|Off group|Disabled|1", ""), "the emptied group is gone")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ELEMENTREMOVETOOL, tTurn, "quality-measure-element", ..ElementId(tName, "Off", ""))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..AssertReadsEqualModel(tName, 1, "after the removals")
}

/// <p>AC1, AC2: the documentation item's add, change and remove at both callers. A content is sent in the model's own form: markup with an entity and a tag reads back as sent; a quote is stored as its
/// entity and a line break is not kept, and each caller's read-back says <code>matches</code>. The item's section and every other part are as they were.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAction.ContentNormalized</method> return its argument unchanged -- the quote and line break legs' read-backs go red.</p>
Method TestADocumentationItemIsAddedChangedAndRemovedByEachCaller()
{
    Set tName = ..Name("Doc")
    Set tClass = ..#CLASSMARKER _ "Doc"
    Do $$$AssertStatusOK(..SaveMeasure("Doc", tClass), "the measure is saved and compiled")
    Set tBefore = ..QModel(tName)
    Set tText = ..TextOf(tClass)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Post("/analytics/quality-measure-metas", {"QualityMeasure": (tName), "Name": "Notes", "Caption": "Notes", "Content": "Plain &amp; <b>marked</b> text.", "Disabled": false}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's Add documentation item answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, "quality-measure-meta|matches", "created, the read-back matching what was sent")
    Set tExpected = tBefore _ "~M:Notes|Notes||0|Plain &amp; <b>marked</b> text."
    Do $$$AssertEquals(..QModel(tName), tExpected, "the item is at the end with its markup, and every other part is as it was")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tText), "every line outside the XData body is the same text")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-meta", ..MetaId(tName, "Notes"), "analytics.qualitymeasuremetas.add"), 1, "one audit row names the add")

    Do ..Mint(..#METAADDTOOL, {"QualityMeasure": (tName), "Name": "Quoted", "Content": ("Two ""quotes"" here")}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's add confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId _ "|" _ tAnswer.readBack.verdict, "created|" _ ..MetaId(tName, "Quoted") _ "|matches", "created, naming the item, the read-back matching")
    Set tExpected = tExpected _ "~M:Quoted|||0|Two &quot;quotes&quot; here"
    Do $$$AssertEquals(..QModel(tName), tExpected, "the quotes are stored as the entities the model holds")
    Do ..AssertAgentRecords(tSince, tProposal, ..#METAADDTOOL, tTurn, "quality-measure-meta", ..MetaId(tName, "Quoted"))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act(..#METASCREEN, "set", ..MetaId(tName, "Notes"), {"Caption": "Notes, edited", "Content": ("one" _ $Char(10) _ "two"), "Disabled": "true"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Change documentation item answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the line break not kept and the read-back matching")
    Set tExpected = $Replace(tExpected, "~M:Notes|Notes||0|Plain &amp; <b>marked</b> text.", "~M:Notes|Notes, edited||1|onetwo")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the item holds what was sent in the model's form")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-meta", ..MetaId(tName, "Notes"), "analytics.qualitymeasuremetas.set"), 1, "one audit row names the change")
    Do ..Mint(..#METASETTOOL, {"QualityMeasure": (tName), "Name": "Purpose", "Caption": "Why", "Content": "Because."}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's change confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Set tExpected = $Replace(tExpected, "~M:Purpose|Purpose|Overview|0|Counts the long visits &amp; their share.", "~M:Purpose|Why|Overview|0|Because.")
    Do $$$AssertEquals(..QModel(tName), tExpected, "the section is kept as stored")
    Do ..AssertAgentRecords(tSince, tProposal, ..#METASETTOOL, tTurn, "quality-measure-meta", ..MetaId(tName, "Purpose"))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..AssertReadsEqualModel(tName, 0, "after the adds and changes")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act(..#METASCREEN, "remove", ..MetaId(tName, "Notes"), "", .tAnswer), 200, "the person's Remove documentation item runs: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Set tExpected = $Replace(tExpected, "~M:Notes|Notes, edited||1|onetwo", "")
    Do $$$AssertEquals(..QModel(tName), tExpected, "only the item is gone")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure-meta", ..MetaId(tName, "Notes"), "analytics.qualitymeasuremetas.remove"), 1, "one audit row names the removal")
    Do ..EnableKey("analytics.qualitymeasuremetas.remove")
    Do ..Mint(..#METAREMOVETOOL, {"QualityMeasure": (tName), "Name": "Quoted"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's remove is refused as disabled by policy")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..EnableKey("analytics.qualitymeasuremetas.remove")
    Do ..Mint(..#METAREMOVETOOL, {"QualityMeasure": (tName), "Name": "Quoted"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "with its key on the agent's remove confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals(..QModel(tName), $Replace(tExpected, "~M:Quoted|||0|Two &quot;quotes&quot; here", ""), "the item is gone")
    Do ..AssertAgentRecords(tSince, tProposal, ..#METAREMOVETOOL, tTurn, "quality-measure-meta", ..MetaId(tName, "Quoted"))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..AssertReadsEqualModel(tName, 0, "after the removals")
}

/// <p>AC1: each refusal answers its own code and the classes and registry are as they were: an element or item name the group or measure holds, compared without regard to case, enabled or not (409
/// <code>ELEMENTTAKEN</code>, <code>METATAKEN</code>); a group, element or item that is not there (404 <code>PARTABSENT</code>) and a measure that is not (404 <code>ABSENT</code>); a removal or
/// disabling that leaves the expression naming a group that cannot count (422 <code>EXPRESSION</code>); a name, text or flag outside the shape rules (422 <code>PORT.FIELD.SHAPE</code>); and a content
/// that is not well-formed markup, or that the model cannot hold (422 <code>COMPILE</code>).</p>
/// <p>Mutation (Rule 19): make the taken check of <method>OcuPilot.Port.AnalyticsPort.ApplyQualityMeasurePart</method> compare exact names -- the case and disabled legs go red; make
/// <method>OcuPilot.Port.AnalyticsPort.NormalizedContent</method> answer storable for any text -- the content legs go red.</p>
Method TestEachRefusalWritesNothing()
{
    Set tName = ..Name("Held")
    Do $$$AssertStatusOK(..SaveMeasure("Held", ..#CLASSMARKER _ "Held"), "a measure is held")
    Set tBefore = ..Snapshot()
    Set tLongName = $Translate($Justify("", 251), " ", "n")
    Set tLongText = $Translate($Justify("", 2001), " ", "c")
    Set tLongMdx = $Translate($Justify("", 32001), " ", "m")
    For tCase = $ListBuild("E", "ENTRYADD", "Long", "over30", "{}", "409 ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN", "an element name held in other letter case"),
        $ListBuild("E", "ENTRYADD", "Long", "RETIRED", "{}", "409 ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN", "an element name held by a disabled element"),
        $ListBuild("M", "ENTRYADD", "", "purpose", "{}", "409 ANALYTICS.QUALITYMEASURE.METATAKEN", "an item name held in other letter case"),
        $ListBuild("E", "ENTRYSET", "Long", "Missing", {"Caption": "x"}.%ToJSON(), "404 ANALYTICS.QUALITYMEASURE.PARTABSENT", "a change of an element that is not there"),
        $ListBuild("E", "ENTRYSET", "Nowhere", "Over30", {"Caption": "x"}.%ToJSON(), "404 ANALYTICS.QUALITYMEASURE.PARTABSENT", "a change in a group that is not there"),
        $ListBuild("E", "ENTRYREMOVE", "Long", "Missing", "{}", "404 ANALYTICS.QUALITYMEASURE.PARTABSENT", "a removal of an element that is not there"),
        $ListBuild("E", "ENTRYREMOVE", "Nowhere", "", "{}", "404 ANALYTICS.QUALITYMEASURE.PARTABSENT", "a removal of a group that is not there"),
        $ListBuild("M", "ENTRYSET", "", "Missing", {"Caption": "x"}.%ToJSON(), "404 ANALYTICS.QUALITYMEASURE.PARTABSENT", "a change of an item that is not there"),
        $ListBuild("M", "ENTRYREMOVE", "", "Missing", "{}", "404 ANALYTICS.QUALITYMEASURE.PARTABSENT", "a removal of an item that is not there"),
        $ListBuild("E", "ENTRYREMOVE", "Long", "Over30", "{}", "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", "a removal of the only enabled element of a group the expression needs"),
        $ListBuild("E", "ENTRYSET", "Long", "Over30", {"Disabled": true}.%ToJSON(), "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", "disabling that element"),
        $ListBuild("E", "ENTRYREMOVE", "Everyone", "", "{}", "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", "a removal of a group the expression names"),
        $ListBuild("E", "ENTRYSET", "Everyone", "", {"GroupDisabled": true}.%ToJSON(), "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", "disabling that group"),
        $ListBuild("E", "ENTRYADD", "", "X", "{}", "422 PORT.FIELD.SHAPE", "an element with no group"),
        $ListBuild("E", "ENTRYADD", "Long", tLongName, "{}", "422 PORT.FIELD.SHAPE", "an element name of 251 characters"),
        $ListBuild("E", "ENTRYADD", "Long", "X", {"Caption": (tLongText)}.%ToJSON(), "422 PORT.FIELD.SHAPE", "a caption of 2,001 characters"),
        $ListBuild("E", "ENTRYADD", "Long", "X", {"MDX": (tLongMdx)}.%ToJSON(), "422 PORT.FIELD.SHAPE", "an MDX expression of 32,001 characters"),
        $ListBuild("E", "ENTRYADD", "Long", "X", {"GroupDescription": (tLongText)}.%ToJSON(), "422 PORT.FIELD.SHAPE", "a group description of 2,001 characters"),
        $ListBuild("E", "ENTRYADD", "Long", "X", {"Disabled": "yes"}.%ToJSON(), "422 PORT.FIELD.SHAPE", "a disabled flag that is no boolean"),
        $ListBuild("E", "ENTRYSET", "Long", "Over30", {"GroupDisabled": 1}.%ToJSON(), "422 PORT.FIELD.SHAPE", "a group flag that is no boolean"),
        $ListBuild("E", "ENTRYSET", "Long", "", {"MDX": "x"}.%ToJSON(), "422 PORT.FIELD.SHAPE", "an element field sent to a group"),
        $ListBuild("E", "ENTRYSET", "Long", "", {"Disabled": true}.%ToJSON(), "422 PORT.FIELD.SHAPE", "an element flag sent to a group"),
        $ListBuild("M", "ENTRYADD", "", tLongName, "{}", "422 PORT.FIELD.SHAPE", "an item name of 251 characters"),
        $ListBuild("M", "ENTRYADD", "", "X", {"Content": 7}.%ToJSON(), "422 PORT.FIELD.SHAPE", "a content that is no string"),
        $ListBuild("M", "ENTRYADD", "", "X", {"Content": "a & b"}.%ToJSON(), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "a content with a bare ampersand"),
        $ListBuild("M", "ENTRYADD", "", "X", {"Content": "a < b"}.%ToJSON(), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "a content with a bare less-than sign"),
        $ListBuild("M", "ENTRYADD", "", "X", {"Content": ("bad" _ $Char(1))}.%ToJSON(), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "a content with a control character"),
        $ListBuild("M", "ENTRYADD", "", "X", {"Content": ("price " _ $Char(8364))}.%ToJSON(), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "a content the writer turns into an entity XML does not define"),
        $ListBuild("M", "ENTRYSET", "", "Purpose", {"Content": "x ]]> y"}.%ToJSON(), "422 ANALYTICS.QUALITYMEASURE.COMPILE", "a change to a content with the end of a CDATA section") {
        Set tElements = ($List(tCase, 1) = "E")
        Set tId = $Select(tElements: ..ElementId(tName, $List(tCase, 3), $List(tCase, 4)), 1: ..MetaId(tName, $List(tCase, 4)))
        Set tResult = ..Port($Select(tElements: ..#ELEMENTENDPOINT, 1: ..#METAENDPOINT), $List(tCase, 2), tId, ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 5)), "", .tRes)
        Do $$$AssertEquals(tResult, $List(tCase, 6), $List(tCase, 7) _ " is refused by its own code")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 7) _ ": nothing was written")
    }
    Do $$$AssertEquals(..Port(..#ELEMENTENDPOINT, "ENTRYADD", ..ElementId(..Name("Nothing"), "Long", "X"), {}, "", .tRes), "404 ANALYTICS.QUALITYMEASURE.ABSENT", "an add to a measure that is not there is refused")
    Do $$$AssertEquals(..Port(..#METAENDPOINT, "ENTRYREMOVE", ..MetaId(..Name("Nothing"), "X"), {}, "", .tRes), "404 ANALYTICS.QUALITYMEASURE.ABSENT", "and so is a removal")
    Do $$$AssertEquals(..Port(..#ELEMENTENDPOINT, "ENTRYADD", tName, {}, "", .tRes), "422 PORT.FIELD.SHAPE", "an id that is no composite is a shape violation")
    Do ..MintRefused(..#ELEMENTADDTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Over30"}, "ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN")
    Do ..MintRefused(..#ELEMENTADDTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "OVER30"}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Missing", "Caption": "x"}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#METAADDTOOL, {"QualityMeasure": (tName), "Name": "Purpose"}, "ANALYTICS.QUALITYMEASURE.METATAKEN")
    Do ..MintRefused(..#METAADDTOOL, {"QualityMeasure": (tName), "Name": "X", "Content": "a & b"}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#ELEMENTSETTOOL, {"QualityMeasure": (tName), "Group": "Long", "Name": "Over30", "Disabled": true}, "TOOL.ARGUMENTS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no proposal was minted and nothing was written")
}

/// <p>AC1: each write has a script form (AD-59) that makes the same change: an element's and an item's add, change and remove each save and compile the class, and a script for a write the port refuses
/// only sets the refusal's sentence.</p>
/// <p>Mutation (Rule 19): make the update branch of <method>OcuPilot.Port.AnalyticsPort.ClassWriteSnippet</method> skip its compile line -- the registered legs go red.</p>
Method TestEachWritesScriptFormMakesTheSameChange()
{
    Set tName = ..Name("Script")
    Do $$$AssertStatusOK(..SaveMeasure("Script", ..#CLASSMARKER _ "Script"), "the measure is saved and compiled")
    Set tBefore = ..QModel(tName)
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", ..#ELEMENTENDPOINT, "ENTRYADD") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", ..#METAENDPOINT, "ENTRYREMOVE") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", ..#ELEMENTENDPOINT, "QUALITYMEASUREELEMENT"), "objectscript|objectscript|", "a write has a script form and a read has none")
    Set tElement = ..ElementId(tName, "Long", "Scripted")
    Do $$$AssertEquals(..RunScript(..PartScript(..#ELEMENTENDPOINT, "ENTRYADD", tElement, {"Name": "Scripted", "Caption": "From a script", "MDX": "{[Minutes].&[7]}"})), 1, "the element add's script runs")
    Do $$$AssertEquals(..QModel(tName), $Replace(tBefore, "~G:Everyone", ";E:Scripted|From a script|{[Minutes].&[7]}|0~G:Everyone"), "and adds the element, the class compiled")
    Do $$$AssertEquals(..QRegistered(tName, ..#CLASSMARKER _ "Script"), 1, "and registered")
    Do $$$AssertEquals(..RunScript(..PartScript(..#ELEMENTENDPOINT, "ENTRYADD", tElement, {"Name": "Scripted"})), 0, "an add of a name the group holds only sets the refusal")
    Do $$$AssertEquals(..RunScript(..PartScript(..#ELEMENTENDPOINT, "ENTRYSET", tElement, {"Caption": "Changed", "GroupCaption": "Long, scripted"})), 1, "the element change's script runs")
    Do $$$AssertEquals(..QModel(tName), $Replace($Replace(tBefore, "~G:Long|Long stays|", "~G:Long|Long, scripted|"), "~G:Everyone", ";E:Scripted|Changed|{[Minutes].&[7]}|0~G:Everyone"), "and changes the element and its group")
    Do $$$AssertEquals(..RunScript(..PartScript(..#ELEMENTENDPOINT, "ENTRYREMOVE", tElement, {})), 1, "the element removal's script runs")
    Do $$$AssertEquals(..RunScript(..PartScript(..#ELEMENTENDPOINT, "ENTRYREMOVE", ..ElementId(tName, "Everyone", ""), {})), 0, "a removal that breaks the expression only sets the refusal")
    Set tMeta = ..MetaId(tName, "Scripted")
    Do $$$AssertEquals(..RunScript(..PartScript(..#METAENDPOINT, "ENTRYADD", tMeta, {"Name": "Scripted", "Content": "A <i>note</i>."})), 1, "the item add's script runs")
    Do $$$AssertEquals(..RunScript(..PartScript(..#METAENDPOINT, "ENTRYSET", tMeta, {"Caption": "Cap"})), 1, "the item change's script runs")
    Do $$$AssertEquals($Piece(..QModel(tName), "~M:Scripted", 2), "|Cap||0|A <i>note</i>.", "and the item holds both")
    Do $$$AssertEquals(..RunScript(..PartScript(..#METAENDPOINT, "ENTRYREMOVE", tMeta, {})), 1, "the item removal's script runs")
    Do $$$AssertEquals(..QModel(tName), $Replace(tBefore, "~G:Long|Long stays|", "~G:Long|Long, scripted|"), "and only the group's caption differs from where it began")
    Do $$$AssertEquals(..QRegistered(tName, ..#CLASSMARKER _ "Script"), 1, "the measure is still compiled")
}

/// <p>The two routes the part screens add answer JSON envelopes of the declared type and shape as the HTTP account: <code>POST /analytics/quality-measure-elements</code> and
/// <code>/analytics/quality-measure-metas</code> create a part (201 <code>{id, target, readBack}</code>); a measure the instance does not hold is a 404 envelope and a body naming no part a 422 one.</p>
Method TestTheRoutesAnswerJsonEnvelopesOfTheDeclaredShape()
{
    Set tName = ..Name("Wire")
    Do $$$AssertStatusOK(..SaveMeasure("Wire", ..#CLASSMARKER _ "Wire"), "the measure is saved and compiled")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tCase = $ListBuild("POST", "/analytics/quality-measure-elements?ns=USER", {"QualityMeasure": (tName), "Group": "Long", "Name": "WireElement"}.%ToJSON(), 201), $ListBuild("POST", "/analytics/quality-measure-metas?ns=USER", {"QualityMeasure": (tName), "Name": "WireItem"}.%ToJSON(), 201), $ListBuild("POST", "/analytics/quality-measure-elements?ns=USER", {"QualityMeasure": (..Name("WireNone")), "Group": "Long", "Name": "X"}.%ToJSON(), 404), $ListBuild("POST", "/analytics/quality-measure-metas?ns=USER", {"QualityMeasure": (..Name("WireNone")), "Name": "X"}.%ToJSON(), 404), $ListBuild("POST", "/analytics/quality-measure-elements?ns=USER", "{}", 422), $ListBuild("POST", "/analytics/quality-measure-metas?ns=USER", "{}", 422), $ListBuild("POST", "/analytics/quality-measure-elements?ns=USER", {"QualityMeasure": (tName), "Name": "X"}.%ToJSON(), 422) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tCase, 1), tBase _ $List(tCase, 2), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, $List(tCase, 3), "application/json")
        Do $$$AssertEquals(tStatus, $List(tCase, 4), $List(tCase, 2) _ " answers " _ $List(tCase, 4) _ ": " _ $Extract(tRaw, 1, 200))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", $List(tCase, 2) _ ": its content type is JSON (" _ $Get(tHeaders("CONTENT-TYPE")) _ ")")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        If '$IsObject(tBody) {
            Do $$$AssertTrue(0, $List(tCase, 2) _ ": its body is one JSON document")
            Continue
        }
        If $List(tCase, 4) = 201 Do $$$AssertTrue(tBody.id '= "", "the create names its target")
        If $List(tCase, 4) > 299 Do $$$AssertTrue(tBody.code '= "", "a refusal carries its code")
    }
}

}
