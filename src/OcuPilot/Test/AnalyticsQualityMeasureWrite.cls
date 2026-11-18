/// <p>Pins Story 24.12's quality measure writes (Batch 2: AD-54, AD-61, AD-65) against <code>USER</code>, with analytics on through <class>OcuPilot.Test.AnalyticsProbe</class> and measures and
/// classes named with the write marker: the four writes (add, update, copy, delete) at both callers, the person's screen routes and the agent's proposals minted and confirmed over HTTP.
/// Each leaves the measure as the vendor's model reads it, every line of the class outside its <code>QualityMeasure</code> XData as it was, the read-back verdict <code>matches</code>
/// (<code>notFound</code> for a delete), one audit row of OcuPilot's own and, for the agent, its marker and one ledger row; the screens' reads and the agent's read tool answer the new
/// state; and each refusal writes nothing. The helpers are <class>OcuPilot.Test.AnalyticsQualityMeasureBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. One class per run.</p>
Class OcuPilot.Test.AnalyticsQualityMeasureWrite Extends OcuPilot.Test.AnalyticsQualityMeasureBase
{

/// <p>AC1, AC2: the person's New quality measure and the agent's add proposal each make a compiled measure that the vendor's model reads as sent, with the classic starter groups; each answers the
/// AD-14 action <code>created</code> with the read-back verdict <code>matches</code> and leaves one audit row (the agent's also its marker and ledger row); the Quality measures screen and the
/// agent's read tool answer both.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.QualityMeasureRow</method> answer an empty <code>Caption</code> -- the two read-back legs go red.</p>
Method TestAMeasureIsAddedByEachCallerAndReadsBack()
{
    Set tStarter = "|[Numerator]/[Denominator]||1||~G:Numerator||Numerator|0;E:Numerator Cohort||100|0~G:Denominator||Denominator|0;E:Denominator Cohort||100|0"
    Set tPerson = ..Name("Person")
    Set tPersonClass = ..#CLASSMARKER _ "Person"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Post("/analytics/quality-measures", {"Name": (tPerson), "Class": (tPersonClass), "Caption": "Person caption", "Description": "made by a person", "SubjectArea": (..#VISITS)}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's New quality measure answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, "quality-measure|matches", "created, the read-back matching what was sent")
    Do $$$AssertEquals(..QModel(tPerson), tPerson _ "|Person caption|made by a person|" _ ..#VISITS _ tStarter, "the vendor's model holds what was sent and the classic starter groups")
    Do $$$AssertEquals(..QRegistered(tPerson, tPersonClass), 1, "and the measure is compiled and registered")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", tPerson, "analytics.qualitymeasures.add"), 1, "one audit row names the add")

    Set tAgent = ..Name("Agent")
    Set tAgentClass = ..#CLASSMARKER _ "Agent"
    Do ..Mint(..#ADDTOOL, {"Name": (tAgent), "Class": (tAgentClass), "Caption": "Agent caption", "SubjectArea": (..#CATEGORIES)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.QUALITYMEASURE.SAVE|0", "the add's card states that the class is saved and compiled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the add confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId _ "|" _ tAnswer.readBack.verdict, "created|" _ tAgent _ "|matches", "created, naming the measure, the read-back matching")
    Do $$$AssertEquals(..QModel(tAgent), tAgent _ "|Agent caption||" _ ..#CATEGORIES _ tStarter, "the vendor's model holds what the agent sent")
    Do $$$AssertEquals(..QRegistered(tAgent, tAgentClass), 1, "and the measure is compiled and registered")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ADDTOOL, tTurn, "quality-measure", tAgent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tRows = ..ScreenRows("analytics.qualitymeasures")
    Do $$$AssertEquals(tRows, tAgent _ ":1," _ tPerson _ ":1", "the Quality measures screen answers both measures compiled: " _ tRows)
    Do $$$AssertEquals(..ToolHas("analytics.qualitymeasures.read", {}, tPerson) _ ..ToolHas("analytics.qualitymeasures.read", {}, tAgent), "11", "and so does the agent's read tool")
}

/// <p>AC1, AC2: the person's Edit and the agent's update change a measure's header, and only that. The groups, elements and documentation and the class's own parameter are as they were: every
/// line of the class outside the <code>QualityMeasure</code> XData is the same text.</p>
/// <p>Mutation (Rule 19): make an update's compose in <method>OcuPilot.Port.AnalyticsPort.VendorQualityMeasureCompose</method> skip the caption -- the header and read-back legs go red; make
/// <method>OcuPilot.Port.AnalyticsPort.QualityMeasureRow</method> answer an empty <code>Caption</code> -- the two read-back legs go red.</p>
Method TestAnUpdateChangesTheHeaderAndKeepsEverythingElse()
{
    Set tName = ..Name("Update")
    Set tClass = ..#CLASSMARKER _ "Update"
    Do $$$AssertStatusOK(..SaveMeasure("Update", tClass), "the measure is saved and compiled")
    Set tBefore = ..TextOf(tClass)
    Set tMembers = ..Members(..QModel(tName))
    Do $$$AssertTrue(tMembers [ "Over30", "the measure holds its groups, elements and documentation")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act(..#MEASURESCREEN, "update", tName, {"Caption": "Person caption", "Description": "", "SubjectArea": (..#CATEGORIES), "Expression": "[Long]", "Published": "false", "Format": "#", "Href": "https://example.invalid/new"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Edit answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Do $$$AssertEquals($Piece(..QModel(tName), "~", 1), tName _ "|Person caption||" _ ..#CATEGORIES _ "|[Long]||0|#|https://example.invalid/new", "the header holds what was sent")
    Do $$$AssertEquals(..Members(..QModel(tName)), tMembers, "and the groups, elements and documentation are as they were")
    Do $$$AssertEquals(..ScreenField(tName, "Caption"), "Person caption", "the screen's read answers the new caption")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tBefore), "every line outside the XData body is the same text")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "the measure is compiled again")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", tName, "analytics.qualitymeasures.update"), 1, "one audit row names the update")

    Do ..Mint(..#UPDATETOOL, {"Name": (tName), "Caption": "Agent caption", "Published": true, "LinkedTo": ""}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the update confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Do $$$AssertEquals($Piece(..QModel(tName), "~", 1), tName _ "|Agent caption||" _ ..#CATEGORIES _ "|[Long]||1|#|https://example.invalid/new", "the agent's caption and flag are in and the rest is kept")
    Do $$$AssertEquals(..Members(..QModel(tName)), tMembers, "the members are still as they were")
    Set tSeen = ..ScreenField(tName, "Caption") _ "|" _ ..ToolField(tName, "Caption")
    Do $$$AssertEquals(tSeen, "Agent caption|Agent caption", "the screen's read and the agent's read tool answer the agent's caption: " _ tSeen)
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tBefore), "and so is every other line of the class")
    Do ..AssertAgentRecords(tSince, tProposal, ..#UPDATETOOL, tTurn, "quality-measure", tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC1, AC2: the agent's copy and the person's Copy make new compiled measures that hold the source's groups, elements and documentation under the new name and class; the source's class
/// text is unchanged.</p>
Method TestACopyMakesANewMeasureAndLeavesTheSource()
{
    Set tSource = ..Name("Source")
    Set tSourceClass = ..#CLASSMARKER _ "Source"
    Do $$$AssertStatusOK(..SaveMeasure("Source", tSourceClass), "the source is saved and compiled")
    Set tText = ..TextOf(tSourceClass)
    Set tSourceModel = ..QModel(tSource)
    Set tAgent = ..Name("AgentCopy")
    Set tAgentClass = ..#CLASSMARKER _ "AgentCopy"
    Do ..Mint(..#COPYTOOL, {"Name": (tSource), "NewName": (tAgent), "NewClass": (tAgentClass)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's copy confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId _ "|" _ tAnswer.readBack.verdict, "created|" _ tAgent _ "|nothingSent", "created, naming the copy; a copy sends no body, so its read-back sends nothing to compare")
    Do $$$AssertEquals(..QModel(tAgent), tAgent _ "|" _ $Piece($Piece(tSourceModel, "~", 1), "|", 2, *) _ "~" _ ..Members(tSourceModel), "the copy holds the source's header and every group, element and documentation item")
    Do $$$AssertEquals(..QRegistered(tAgent, tAgentClass), 1, "and is compiled")
    Set tSeen = ..ScreenField(tAgent, "Caption") _ "|" _ ..ToolField(tAgent, "Caption")
    Do $$$AssertEquals(tSeen, "Original|Original", "the screen's read and the agent's read tool answer the agent's copy with the source's caption: " _ tSeen)
    Do $$$AssertEquals(..TextOf(tSourceClass), tText, "the source's class is unchanged")
    Do ..AssertAgentRecords(tSince, tProposal, ..#COPYTOOL, tTurn, "quality-measure", tAgent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tPerson = ..Name("PersonCopy")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act(..#MEASURESCREEN, "copy", tSource, {"NewName": (tPerson), "NewClass": (..#CLASSMARKER _ "PersonCopy")}, .tAnswer), 200, "the person's Copy answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..Members(..QModel(tPerson)), ..Members(tSourceModel), "the person's copy holds the source's members")
    Do $$$AssertEquals(..QRegistered(tPerson, ..#CLASSMARKER _ "PersonCopy"), 1, "and is compiled")
    Set tSeen = ..ScreenField(tPerson, "Caption") _ "|" _ ..ToolField(tPerson, "Caption")
    Do $$$AssertEquals(tSeen, "Original|Original", "the screen's read and the agent's read tool answer the person's copy: " _ tSeen)
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", tPerson, "analytics.qualitymeasures.copy"), 1, "and one audit row names the copy")
    Do $$$AssertEquals(..TextOf(tSourceClass), tText, "the source's class is still unchanged")
}

/// <p>AC1, AC2, AC5: a delete removes the measure's class and every node it registered, for the person (not asked for the governance key, AD-22) and for the agent once the test turns its key on;
/// the agent's card is destructive and states the consequence; the read-back finds the measure gone; the key ships off, so a delete confirmed with the baseline alone is refused
/// <code>GOVERNANCE.DISABLED</code>.</p>
/// <p>Mutation (Rule 19): flip the delete line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the refusal leg goes red.</p>
Method TestADeleteRemovesTheClassAndItsNodesAndShipsOff()
{
    Set tPerson = ..Name("DelPerson")
    Set tAgent = ..Name("DelAgent")
    Do $$$AssertStatusOK(..SaveMeasure("DelPerson", ..#CLASSMARKER _ "DelPerson"), "the person's measure is saved and compiled")
    Do $$$AssertStatusOK(..SaveMeasure("DelAgent", ..#CLASSMARKER _ "DelAgent"), "the agent's measure is saved and compiled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act(..#MEASURESCREEN, "delete", tPerson, "", .tAnswer), 200, "the person's Delete runs: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..QGone(tPerson, ..#CLASSMARKER _ "DelPerson"), 1, "the class and every node of the measure are gone")
    Do $$$AssertEquals(..ScreenField(tPerson, "Name"), "absent", "and the screen's read does not answer it")
    Do $$$AssertEquals(..Rows(tSince, "quality-measure", tPerson, "analytics.qualitymeasures.delete"), 1, "one audit row names the delete")

    Do ..EnableKey("analytics.qualitymeasures.delete")
    Do ..Mint(..#DELETETOOL, {"Name": (tAgent)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.QUALITYMEASURE.DELETE|1", "the delete's card is destructive and states the consequence")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's delete is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..QRegistered(tAgent, ..#CLASSMARKER _ "DelAgent"), 1, "and the measure is still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ..EnableKey("analytics.qualitymeasures.delete")
    Do ..Mint(..#DELETETOOL, {"Name": (tAgent)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "with its key on the agent's delete confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals(..QGone(tAgent, ..#CLASSMARKER _ "DelAgent"), 1, "the class and every node of the agent's measure are gone")
    Set tSeen = ..ScreenField(tAgent, "Name") _ "|" _ ..ToolField(tAgent, "Name")
    Do $$$AssertEquals(tSeen, "absent|absent", "and neither read answers the agent's measure: " _ tSeen)
    Do ..AssertAgentRecords(tSince, tProposal, ..#DELETETOOL, tTurn, "quality-measure", tAgent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC1: each refusal answers its own code and the classes and registry nodes are as they were: an add whose name is held (compared without regard to case) or whose class is defined (409
/// <code>TAKEN</code>), whose name is not three parts of no dot or slash or whose class is outside the allowed shape (422), or in an <code>OcuPilot</code> package (403); an update whose
/// expression names a group the measure lacks or does not close its brackets (422 <code>EXPRESSION</code>), whose flag is not a boolean (422), or that changes a linked measure's format (409
/// <code>LINKED</code>); a measure that is not there (404); and the agent's mint refusing what the write would refuse before a proposal exists.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.ExpressionHolds</method> answer 1 -- the expression legs and the mint leg go red; skip the class shape check in
/// <method>OcuPilot.Port.AnalyticsPort.PlanQualityMeasure</method> -- the <code>%</code> and no-package legs go red.</p>
Method TestEachRefusalWritesNothing()
{
    Set tName = ..Name("Held")
    Set tClass = ..#CLASSMARKER _ "Held"
    Set tLinked = ..Name("Linked")
    Do $$$AssertStatusOK(..SaveMeasure("Held", tClass), "a measure is held")
    Do $$$AssertStatusOK(..SaveMeasure("Linked", ..#CLASSMARKER _ "Linked", tName), "and a measure linked to it")
    Set tBefore = ..Snapshot()
    Set tFree = ..Name("Free")
    Set tFreeClass = ..#CLASSMARKER _ "Free"
    For tCase = $ListBuild(tName, tFreeClass, "409 ANALYTICS.QUALITYMEASURE.TAKEN", "a name already held"), $ListBuild($ZConvert(tName, "U"), tFreeClass, "409 ANALYTICS.QUALITYMEASURE.TAKEN", "a name held in other letter case"), $ListBuild(tFree, tClass, "409 ANALYTICS.QUALITYMEASURE.TAKEN", "a class already defined"), $ListBuild(..#MARKER _ "/Probe/Dot.Id", tFreeClass, "422 PORT.FIELD.SHAPE", "an id with a dot"), $ListBuild(..#MARKER _ "//Free", tFreeClass, "422 PORT.FIELD.SHAPE", "an empty set"), $ListBuild(..#MARKER _ "/Probe", tFreeClass, "422 PORT.FIELD.SHAPE", "a name of two parts"), $ListBuild(tFree _ "/Extra", tFreeClass, "422 PORT.FIELD.SHAPE", "a name of four parts"), $ListBuild(tFree, "OcuPilot.Probe", "403 PROHIBITED.OCUPILOTCODE", "a class in an OcuPilot package"), $ListBuild(tFree, "%Probe.Free", "422 ANALYTICS.QUALITYMEASURE.CLASS", "a class in a % package"), $ListBuild(tFree, "NoPackage", "422 ANALYTICS.QUALITYMEASURE.CLASS", "a class with no package") {
        Set tResult = ..Port("QualityMeasures", "ADD", $List(tCase, 1), {"Name": ($List(tCase, 1)), "Class": ($List(tCase, 2)), "SubjectArea": (..#VISITS)}, "", .tRes)
        Do $$$AssertEquals(tResult, $List(tCase, 3), $List(tCase, 4) _ " is refused by its own code")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 4) _ ": nothing was written")
    }
    For tCase = $ListBuild(tName, "{""Expression"":""[Missing]/[Everyone]""}", "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", "an expression naming a group the measure lacks"), $ListBuild(tName, "{""Expression"":""[Long]/[Everyone""}", "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", "an expression that does not close its bracket"), $ListBuild(tName, "{""Expression"":""[]""}", "422 ANALYTICS.QUALITYMEASURE.EXPRESSION", "an expression with an empty group name"), $ListBuild(tName, "{""Published"":""yes""}", "422 PORT.FIELD.SHAPE", "a published flag that is no boolean"), $ListBuild(tLinked, "{""Format"":""x""}", "409 ANALYTICS.QUALITYMEASURE.LINKED", "a linked measure's format changed"), $ListBuild(tLinked, "{""Expression"":""2""}", "409 ANALYTICS.QUALITYMEASURE.LINKED", "a linked measure's expression changed"), $ListBuild(tName, "{""LinkedTo"":""" _ ..Name("Nothing") _ """,""Format"":""x""}", "409 ANALYTICS.QUALITYMEASURE.LINKED", "a link set while the format changes") {
        Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", $List(tCase, 1), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 2)), "", .tRes), $List(tCase, 3), $List(tCase, 4) _ " is refused")
    }
    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tName, {"LinkedTo": (tName)}, "", .tRes), "422 PORT.FIELD.SHAPE", "a measure linked to itself is refused by the shape rule")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing was written")
    Do ..MintRefused(..#ADDTOOL, {"Name": (tName), "Class": (tFreeClass), "SubjectArea": (..#VISITS)}, "ANALYTICS.QUALITYMEASURE.TAKEN")
    Do ..MintRefused(..#ADDTOOL, {"Name": (tFree), "Class": "OcuPilot.Probe", "SubjectArea": (..#VISITS)}, "PROHIBITED.OCUPILOTCODE")
    Do ..MintRefused(..#UPDATETOOL, {"Name": (..Name("Nothing")), "Caption": "x"}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#UPDATETOOL, {"Name": (tName), "Expression": "[Missing]"}, "TOOL.ARGUMENTS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no proposal was minted and nothing was written")
    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", ..Name("Nothing"), {"Caption": "x"}, "", .tRes), "404 ANALYTICS.QUALITYMEASURE.ABSENT", "an update of a measure that is not there is refused")
    Do $$$AssertEquals(..Port("QualityMeasures", "DELETE", ..Name("Nothing"), {}, "", .tRes), "404 ANALYTICS.QUALITYMEASURE.ABSENT", "and so is a delete")
    Do $$$AssertEquals(..Port("QualityMeasures", "UPDATE", tLinked, {"Caption": "still allowed"}, "", .tRes), "200 ", "a linked measure's caption is not its master's to define")
}

/// <p>AC1: a copy's own refusals, each by its own code with nothing written: a new name already held (409 <code>TAKEN</code>), a new class already defined (409), a new name that is not three parts
/// of no dot (422 <code>PORT.FIELD.SHAPE</code>), a new class in a <code>%</code> package or with no package (422 <code>CLASS</code>) or in an <code>OcuPilot</code> package (403). A copy with a free name and
/// class succeeds, so the refusals are the new name's and class's alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.VendorQualityMeasureCompose</method> check a new class for TAKEN on an add only -- the copy's class leg goes red.</p>
Method TestEachCopyRefusalWritesNothing()
{
    Set tName = ..Name("CopyHeld")
    Set tClass = ..#CLASSMARKER _ "CopyHeld"
    Do $$$AssertStatusOK(..SaveMeasure("CopyHeld", tClass), "a measure is held")
    Set tBefore = ..Snapshot()
    Set tFree = ..Name("CopyFree")
    Set tFreeClass = ..#CLASSMARKER _ "CopyFree"
    For tCase = $ListBuild(tName, tFreeClass, "409 ANALYTICS.QUALITYMEASURE.TAKEN", "a new name already held"), $ListBuild(tFree, tClass, "409 ANALYTICS.QUALITYMEASURE.TAKEN", "a new class already defined"), $ListBuild("", tFreeClass, "422 PORT.FIELD.SHAPE", "an empty new name"), $ListBuild(..#MARKER _ "/Probe/Dot.Id", tFreeClass, "422 PORT.FIELD.SHAPE", "a new name with a dot"), $ListBuild(tFree, "%Probe.Free", "422 ANALYTICS.QUALITYMEASURE.CLASS", "a new class in a % package"), $ListBuild(tFree, "OcuPilot.Probe", "403 PROHIBITED.OCUPILOTCODE", "a new class in an OcuPilot package"), $ListBuild(tFree, "NoPackage", "422 ANALYTICS.QUALITYMEASURE.CLASS", "a new class with no package") {
        Set tResult = ..Port("QualityMeasures", "COPY", tName, {}, {"newName": ($List(tCase, 1)), "newClass": ($List(tCase, 2))}, .tRes)
        Do $$$AssertEquals(tResult, $List(tCase, 3), $List(tCase, 4) _ " is refused by its own code")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 4) _ ": nothing was written")
    }
    Do $$$AssertEquals(..Port("QualityMeasures", "COPY", tName, {}, {"newName": (tFree), "newClass": (tFreeClass)}, .tRes), "200 ", "a copy with a free name and class succeeds")
    Do $$$AssertEquals(..QRegistered(tFree, tFreeClass), 1, "and is compiled")
}

/// <p>AD-10: a write whose class is one of OcuPilot's own is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> with the published sentence, by the port, by the person's screen call and by the agent's mint,
/// with nothing written, for each of the four writes: an add into, and a copy into, a class whose name begins <code>OcuPilot</code> in any letter case and at any package depth, and an update and a delete of
/// Batch 1's probe measure, whose class has that stem. A copy out of such a measure into an ordinary class is not refused: a copy writes only its new class.</p>
/// <p>Mutation (Rule 19): make the four own-code checks of <method>OcuPilot.Port.AnalyticsPort.PlanQualityMeasure</method> and <method>OcuPilot.Port.AnalyticsPort.ReadQualityMeasure</method> answer 0 -- every
/// refusal leg goes red here, and the own-code legs of the two refusal tests with it.</p>
Method TestOwnCodeIsRefusedByEveryMeasureWrite()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateQualityMeasures"), "Batch 1's probe measures are saved and compiled, their classes in an OcuPilot package")
    Set tOwn = $Parameter(..#PROBE, "QMCOMPILED")
    Set tPlain = ..Name("OwnSource")
    Do $$$AssertStatusOK(..SaveMeasure("OwnSource", ..#CLASSMARKER _ "OwnSource"), "and a measure in an ordinary class")
    Set tNew = ..Name("OwnNew")
    For tClass = ..#OWNCLASSMARKER _ "New", $ZConvert(..#OWNCLASSMARKER, "L") _ ".deep.new" {
        Set tBody = {"Name": (tNew), "Class": (tClass), "SubjectArea": (..#VISITS)}
        Do ..AssertOwnCodeRefused("an add into " _ tClass, "QualityMeasures", "ADD", tNew, tBody, "", "/analytics/quality-measures", "", tBody, ..#ADDTOOL, tBody)
        Do ..AssertOwnCodeRefused("a copy into " _ tClass, "QualityMeasures", "COPY", tPlain, {}, {"newName": (tNew), "newClass": (tClass)}, ..#MEASURESCREEN, "copy", {"NewName": (tNew), "NewClass": (tClass)}, ..#COPYTOOL, {"Name": (tPlain), "NewName": (tNew), "NewClass": (tClass)})
    }
    Do ..AssertOwnCodeRefused("an update of a measure in an OcuPilot class", "QualityMeasures", "UPDATE", tOwn, {"Caption": "x"}, "", ..#MEASURESCREEN, "update", {"Caption": "x"}, ..#UPDATETOOL, {"Name": (tOwn), "Caption": "x"})
    Do ..EnableKey("analytics.qualitymeasures.delete")
    Do ..AssertOwnCodeRefused("a delete of a measure in an OcuPilot class", "QualityMeasures", "DELETE", tOwn, {}, "", ..#MEASURESCREEN, "delete", "", ..#DELETETOOL, {"Name": (tOwn)})
    Do $$$AssertEquals(..QRegistered(tOwn, $Parameter(..#PROBE, "QMCOMPILEDCLASS")), 1, "and the measure is still there")
    Do $$$AssertEquals(..Port("QualityMeasures", "COPY", tOwn, {}, {"newName": (..Name("OwnCopy")), "newClass": (..#CLASSMARKER _ "OwnCopy")}, .tRes), "200 ", "a copy out of a measure in an OcuPilot class into an ordinary class is not refused")
}

/// <p>AC1: each write has a script form (AD-59) that makes the same change: the add's script saves and compiles the class, the update's changes the caption, the delete's deletes the class, and a script
/// for a write the port refuses only sets the refusal's sentence. An add's script run after another writer took the name leaves that writer's class as it is.</p>
/// <p>Mutation (Rule 19): make a create's compile line in <method>OcuPilot.Port.AnalyticsPort.ClassWriteSnippet</method> do nothing -- the registered leg and the legs after it go red; make that create line
/// ignore its free-name condition -- the late script's two legs go red.</p>
Method TestEachWritesScriptFormMakesTheSameChange()
{
    Set tName = ..Name("Script")
    Set tClass = ..#CLASSMARKER _ "Script"
    Set tBody = {"Name": (tName), "Class": (tClass), "SubjectArea": (..#VISITS)}
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "QualityMeasures", "ADD") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "QualityMeasures", "QUALITYMEASURE"), "objectscript|", "a write has a script form and a read has none")
    Do $$$AssertEquals(..RunScript(..Script("ADD", tName, tBody)), 1, "the add's script runs")
    Do $$$AssertEquals(..QRegistered(tName, tClass), 1, "and leaves the measure compiled and registered")
    Do $$$AssertEquals(..RunScript(..Script("ADD", tName, tBody)), 0, "a second add only sets the refusal: the name is held")
    Do $$$AssertEquals(..RunScript(..Script("UPDATE", tName, {"Caption": "From a script"})), 1, "the update's script runs")
    Do $$$AssertEquals($Piece($Piece(..QModel(tName), "~", 1), "|", 2), "From a script", "and changes the caption")
    Set tCopy = ..Name("ScriptCopy")
    Do $$$AssertEquals(..RunScript(..Script("COPY", tName, {}, {"newName": (tCopy), "newClass": (..#CLASSMARKER _ "ScriptCopy")})), 1, "the copy's script runs")
    Do $$$AssertEquals(..QRegistered(tCopy, ..#CLASSMARKER _ "ScriptCopy"), 1, "and leaves the copy compiled")
    Do $$$AssertEquals(..RunScript(..Script("DELETE", tName, {})), 1, "the delete's script runs")
    Do $$$AssertEquals(..QGone(tName, tClass), 1, "and removes the class and its nodes")
    Do $$$AssertEquals(..RunScript(..Script("DELETE", tName, {})), 0, "a second delete only sets the refusal: the measure is not there")
    Set tLate = ..Name("ScriptLate")
    Set tLateClass = ..#CLASSMARKER _ "ScriptLate"
    Set tSteps = ..Script("ADD", tLate, {"Name": (tLate), "Class": (tLateClass), "SubjectArea": (..#VISITS)})
    Do $$$AssertEquals(..Port("QualityMeasures", "ADD", tLate, {"Name": (tLate), "Class": (tLateClass), "SubjectArea": (..#VISITS), "Caption": "taken first"}, "", .tRes), "200 ", "another writer takes the name after the add's script was rendered")
    Set tTaken = ..TextOf(tLateClass)
    Do $$$AssertEquals(..RunScript(tSteps), 0, "the earlier add's script finds the name taken and only sets the refusal")
    Do $$$AssertEquals((..TextOf(tLateClass) = tTaken) _ "|" _ ..QRegistered(tLate, tLateClass), "1|1", "and the other writer's class is neither replaced nor deleted")
}

/// <p>The two routes the editor adds answer JSON envelopes of the declared type and shape as the HTTP account: <code>POST /analytics/quality-measures</code> creates a measure (201
/// <code>{id, target, readBack}</code>) and <code>GET /analytics/quality-measures/form</code> answers it (200); a name the instance does not hold is a 404 envelope, a request without a name a 400
/// one, and a body without a name a 422 one.</p>
Method TestTheRoutesAnswerJsonEnvelopesOfTheDeclaredShape()
{
    Set tName = ..Name("Wire")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tEncoded = $ZConvert(tName, "O", "URL")
    For tCase = $ListBuild("POST", "/analytics/quality-measures?ns=USER", {"Name": (tName), "Class": (..#CLASSMARKER _ "Wire"), "SubjectArea": (..#VISITS)}.%ToJSON(), 201), $ListBuild("GET", "/analytics/quality-measures/form?ns=USER&name=" _ tEncoded, "", 200), $ListBuild("GET", "/analytics/quality-measures/form?ns=USER&name=" _ $ZConvert(..Name("WireNone"), "O", "URL"), "", 404), $ListBuild("GET", "/analytics/quality-measures/form?ns=USER", "", 400), $ListBuild("GET", "/analytics/quality-measures/form?ns=USER&name=NoSlashes", "", 400), $ListBuild("POST", "/analytics/quality-measures?ns=USER", "{}", 422) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tCase, 1), tBase _ $List(tCase, 2), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, $List(tCase, 3), $Select($List(tCase, 3) = "": "", 1: "application/json"))
        Do $$$AssertEquals(tStatus, $List(tCase, 4), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " answers " _ $List(tCase, 4) _ ": " _ $Extract(tRaw, 1, 200))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", $List(tCase, 2) _ ": its content type is JSON (" _ $Get(tHeaders("CONTENT-TYPE")) _ ")")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        If '$IsObject(tBody) {
            Do $$$AssertTrue(0, $List(tCase, 2) _ ": its body is one JSON document")
            Continue
        }
        If $List(tCase, 4) = 200 Do $$$AssertEquals(tBody.Name _ "|" _ tBody.Class _ "|" _ tBody.Groups, tName _ "|" _ ..#CLASSMARKER _ "Wire|2", "the form names the measure, its class and its group count")
        If $List(tCase, 4) = 201 Do $$$AssertTrue(tBody.id '= "", "the create names its target")
        If $List(tCase, 4) > 299 Do $$$AssertTrue(tBody.code '= "", "a refusal carries its code")
    }
}

}
