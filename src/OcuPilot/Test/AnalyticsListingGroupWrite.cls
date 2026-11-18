/// <p>Pins Story 24.11's listing group writes (Batch 2: AD-54, AD-61, AD-65) against <code>USER</code>, with analytics on through <class>OcuPilot.Test.AnalyticsProbe</class> and
/// groups and classes named with the probe's write marker: the four group writes (add, update, copy, delete) at both callers, the person's screen routes and the agent's proposals
/// minted and confirmed over HTTP. Each leaves the group as the vendor's model reads it, every line of the class outside its <code>Listings</code> XData and its
/// <code>DependsOn</code> as it was, the read-back verdict <code>matches</code> (<code>notFound</code> for a delete), one audit row of OcuPilot's own and, for the agent, its marker
/// and one ledger row; the screens' reads and the agent's read tool answer the new state; and each refusal writes nothing. The helpers are <class>OcuPilot.Test.AnalyticsListingGroupBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics on in <code>USER</code> and saves, compiles and deletes classes there. It removes
/// everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsListingGroupWrite Extends OcuPilot.Test.AnalyticsListingGroupBase
{

/// <p>AC1, AC2: the person's New listing group and the agent's add proposal each make a compiled group that the vendor's model reads as sent; each answers the AD-14 action
/// <code>created</code> with the read-back verdict <code>matches</code> and leaves one audit row (the agent's also its marker and ledger row); the Listing groups screen and
/// the agent's read tool answer both.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.PerformListingGroup</method> skip the compile -- the compiled legs go red.</p>
Method TestAGroupIsAddedByEachCallerAndReadsBack()
{
    Set tPerson = ..#MARKER _ "Person"
    Set tPersonClass = ..#CLASSMARKER _ "Person"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Post("/analytics/listing-groups", {"Name": (tPerson), "Class": (tPersonClass), "Caption": "Person caption", "Description": "made by a person", "TargetCubes": (..#VISITS), "DefaultResource": "%DeepSee_Portal"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's New listing group answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, "listing-group|matches", "created, the read-back matching what was sent")
    Do $$$AssertEquals(..Model(tPersonClass), tPerson _ "|Person caption|made by a person|" _ ..#VISITS _ "||%DeepSee_Portal|0", "the vendor's model holds exactly what was sent")
    Do $$$AssertEquals(..Registered(tPerson, tPersonClass), 1, "and the group is compiled and registered")
    Do $$$AssertEquals(..Rows(tSince, "listing-group", tPerson, "analytics.listinggroups.add"), 1, "one audit row names the add")

    Set tAgent = ..#MARKER _ "Agent"
    Set tAgentClass = ..#CLASSMARKER _ "Agent"
    Do ..Mint(..#ADDTOOL, {"Name": (tAgent), "Class": (tAgentClass), "Caption": "Agent caption", "TargetCubes": (..#CATEGORIES)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.LISTINGGROUP.SAVE|0", "the add's card states that the class is saved and compiled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the add confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId _ "|" _ tAnswer.readBack.verdict, "created|" _ tAgent _ "|matches", "created, naming the group, the read-back matching")
    Do $$$AssertEquals(..Model(tAgentClass), tAgent _ "|Agent caption||" _ ..#CATEGORIES _ "|||0", "the vendor's model holds exactly what the agent sent")
    Do $$$AssertEquals(..Registered(tAgent, tAgentClass), 1, "and the group is compiled and registered")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ADDTOOL, tTurn, "listing-group", tAgent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tRows = ..ScreenRows("analytics.listinggroups")
    Do $$$AssertEquals(tRows, tAgent _ ":1," _ tPerson _ ":1", "the Listing groups screen answers both groups compiled: " _ tRows)
    Do $$$AssertEquals(..ToolHas("analytics.listinggroups.read", {}, tPerson) _ ..ToolHas("analytics.listinggroups.read", {}, tAgent), "11", "and so does the agent's read tool")
}

/// <p>AC1: the person's Edit and the agent's update change a group's caption and cubes, and only those. The group's listing and its SQL (which the caller could not have
/// composed from a screen row) and the class's own parameter are as they were: every line of the class outside the <code>Listings</code> XData and the class header is the
/// same text, and the header now depends on both cubes' classes.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.ListingGroupText.Splice</method> keep the old XData body -- the caption legs go red.</p>
Method TestAnUpdateChangesTheHeaderAndKeepsTheSqlAndEveryOtherLine()
{
    Set tName = ..#MARKER _ "Update"
    Set tClass = ..#CLASSMARKER _ "Update"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWSql"), "the group is saved and compiled")
    Set tBefore = ..TextOf(tClass)
    Set tListings = $Piece(..Model(tClass), "#", 2, *)
    Do $$$AssertTrue(tListings [ "SELECT ID FROM", "the group's listing holds its SQL")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act(..#GROUPSCREEN, "update", tName, {"Caption": "Person caption", "TargetCubes": (..#VISITS _ "," _ ..#CATEGORIES)}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Edit answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Set tModel = ..Model(tClass)
    Do $$$AssertEquals($Piece($Piece(tModel, "#", 1), "|", 2) _ "|" _ $Piece($Piece(tModel, "#", 1), "|", 4), "Person caption|" _ ..#VISITS _ "," _ ..#CATEGORIES, "the caption and the cubes changed")
    Do $$$AssertEquals($Piece(tModel, "#", 2, *), tListings, "and the listing, its SQL included, is as it was")
    Set tAfter = ..TextOf(tClass)
    Do $$$AssertEquals(..Outside(tAfter), ..Outside(tBefore), "every line outside the XData body and the header is the same text")
    Do $$$AssertTrue($Piece(tAfter, $Char(10), 1) [ ..#CATEGORIESCLASS, "and the header depends on the Categories cube's class too")
    Do $$$AssertEquals(..Registered(tName, tClass), 1, "the group is compiled again")
    Do $$$AssertEquals(..Rows(tSince, "listing-group", tName, "analytics.listinggroups.update"), 1, "one audit row names the update")

    Do ..Mint(..#UPDATETOOL, {"Name": (tName), "Caption": "Agent caption"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the update confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Set tModel = ..Model(tClass)
    Do $$$AssertEquals($Piece($Piece(tModel, "#", 1), "|", 2) _ "|" _ $Piece($Piece(tModel, "#", 1), "|", 4), "Agent caption|" _ ..#VISITS _ "," _ ..#CATEGORIES, "the agent's caption is in and the cubes are kept")
    Do $$$AssertEquals($Piece(tModel, "#", 2, *), tListings, "the listing is still as it was")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), ..Outside(tBefore), "and so is every other line of the class")
    Do ..AssertAgentRecords(tSince, tProposal, ..#UPDATETOOL, tTurn, "listing-group", tName)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC1, AC2: the agent's copy into another cube and the person's Copy make new compiled groups that hold the source's listing, SQL included, under the new name and class;
/// the source's class text is unchanged; a copy into the cubes of an enabled source is refused <code>ANALYTICS.LISTINGGROUP.LISTINGTAKEN</code> and writes nothing.</p>
/// <p>Mutation (Rule 19): make the listing check of <method>OcuPilot.Port.AnalyticsPort.VendorListingGroupCompose</method> skip a registered listing of another group -- the refused copy goes red.</p>
Method TestACopyMakesANewGroupAndLeavesTheSource()
{
    Set tSource = ..#MARKER _ "Source"
    Set tSourceClass = ..#CLASSMARKER _ "Source"
    Do $$$AssertStatusOK(..SaveGroup(tSource, tSourceClass, "LGWCopied"), "the source is saved and compiled")
    Set tText = ..TextOf(tSourceClass)
    Set tBefore = ..Snapshot()
    Do $$$AssertEquals(..Act(..#GROUPSCREEN, "copy", tSource, {"NewName": (..#MARKER _ "Same"), "NewClass": (..#CLASSMARKER _ "Same")}, .tAnswer), 409, "a copy into the source's own cubes is refused 409")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.%Get("code"), "ANALYTICS.LISTINGGROUP.LISTINGTAKEN", "naming the listing")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing was written")

    Set tAgent = ..#MARKER _ "AgentCopy"
    Set tAgentClass = ..#CLASSMARKER _ "AgentCopy"
    Do ..Mint(..#COPYTOOL, {"Name": (tSource), "NewName": (tAgent), "NewClass": (tAgentClass), "NewCubes": (..#CATEGORIES)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's copy confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId, "created|" _ tAgent, "created, naming the copy")
    Do $$$AssertEquals(..Model(tAgentClass), tAgent _ "|Original||" _ ..#CATEGORIES _ "|||0#LGWCopied||Amount|SELECT ID FROM OcuPilotProbe_Analytics.Visit|1|0", "the copy holds the source's listing and its SQL, in the other cube")
    Do $$$AssertEquals(..Registered(tAgent, tAgentClass), 1, "and is compiled")
    Do $$$AssertEquals(..TextOf(tSourceClass), tText, "the source's class is unchanged")
    Do ..AssertAgentRecords(tSince, tProposal, ..#COPYTOOL, tTurn, "listing-group", tAgent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do $$$AssertEquals(..Act(..#GROUPSCREEN, "delete", tAgent, "", .tAnswer), 200, "the person deletes the agent's copy")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act(..#GROUPSCREEN, "copy", tSource, {"NewName": (..#MARKER _ "PersonCopy"), "NewClass": (..#CLASSMARKER _ "PersonCopy"), "NewCubes": (..#CATEGORIES)}, .tAnswer), 200, "the person's Copy answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..Registered(..#MARKER _ "PersonCopy", ..#CLASSMARKER _ "PersonCopy"), 1, "the person's copy is compiled")
    Do $$$AssertEquals(..Rows(tSince, "listing-group", ..#MARKER _ "PersonCopy", "analytics.listinggroups.copy"), 1, "and one audit row names the copy")
    Do $$$AssertEquals(..TextOf(tSourceClass), tText, "the source's class is still unchanged")
}

/// <p>AC1, AC2: a delete removes the group's class and every node it registered, for the person (not asked for the governance key, AD-22) and for the agent once the test turns
/// its key on; the agent's card is destructive and states the consequence; the read-back finds the group gone; the key ships off, so a delete confirmed with the baseline alone is
/// refused <code>GOVERNANCE.DISABLED</code>.</p>
/// <p>Mutation (Rule 19): flip the delete line of <class>OcuPilot.Kernel.Governance.Baseline</class> to <code>true</code> -- the refusal leg goes red.</p>
Method TestADeleteRemovesTheClassAndItsNodesAndShipsOff()
{
    Set tPerson = ..#MARKER _ "DelPerson"
    Set tAgent = ..#MARKER _ "DelAgent"
    Do $$$AssertStatusOK(..SaveGroup(tPerson, ..#CLASSMARKER _ "DelPerson", "LGWDelP"), "the person's group is saved and compiled")
    Do $$$AssertStatusOK(..SaveGroup(tAgent, ..#CLASSMARKER _ "DelAgent", "LGWDelA", ..#CATEGORIES), "the agent's group is saved and compiled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Act(..#GROUPSCREEN, "delete", tPerson, "", .tAnswer), 200, "the person's Delete runs: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..Gone(tPerson, ..#CLASSMARKER _ "DelPerson", "LGWDelP"), 1, "the class and every node of the group are gone")
    Do $$$AssertEquals(..Rows(tSince, "listing-group", tPerson, "analytics.listinggroups.delete"), 1, "one audit row names the delete")

    Do ..EnableKey("analytics.listinggroups.delete")
    Do ..Mint(..#DELETETOOL, {"Name": (tAgent)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.LISTINGGROUP.DELETE|1", "the delete's card is destructive and states the consequence")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's delete is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..Registered(tAgent, ..#CLASSMARKER _ "DelAgent"), 1, "and the group is still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Do ..EnableKey("analytics.listinggroups.delete")
    Do ..Mint(..#DELETETOOL, {"Name": (tAgent)}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "with its key on the agent's delete confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone")
    Do $$$AssertEquals(..Gone(tAgent, ..#CLASSMARKER _ "DelAgent", "LGWDelA"), 1, "the class and every node of the agent's group are gone")
    Do ..AssertAgentRecords(tSince, tProposal, ..#DELETETOOL, tTurn, "listing-group", tAgent)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC1, AC2: each refusal answers its own code and sentence, and the classes and registry nodes are as they were: a name taken (over a group, and over a class that holds
/// none), a class outside the allowed shape (a <code>%</code> package, an <code>OcuPilot</code> package, no package), a target cube that does not exist, and the agent's mint
/// refusing what the write would refuse before a proposal exists.</p>
/// <p>Mutation (Rule 19): make the class check of <method>OcuPilot.Port.AnalyticsPort.ListingClassShaped</method> accept an <code>OcuPilot</code> package -- the class legs go red.</p>
Method TestEachRefusalWritesNothing()
{
    Set tName = ..#MARKER _ "Held"
    Set tClass = ..#CLASSMARKER _ "Held"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWHeld"), "a group is held")
    Set tBefore = ..Snapshot()
    Set tOk = {"Class": (..#CLASSMARKER _ "Free"), "TargetCubes": (..#VISITS)}
    For tCase = $ListBuild(tName, ..#CLASSMARKER _ "Free", ..#VISITS, "409 ANALYTICS.LISTINGGROUP.TAKEN", "a name already held"), $ListBuild(..#MARKER _ "Free", tClass, ..#VISITS, "409 ANALYTICS.LISTINGGROUP.TAKEN", "a class already defined"), $ListBuild(..#MARKER _ "Free", "OcuPilot.Probe", ..#VISITS, "422 ANALYTICS.LISTINGGROUP.CLASS", "a class in an OcuPilot package"), $ListBuild(..#MARKER _ "Free", "%Probe.Free", ..#VISITS, "422 ANALYTICS.LISTINGGROUP.CLASS", "a class in a % package"), $ListBuild(..#MARKER _ "Free", "NoPackage", ..#VISITS, "422 ANALYTICS.LISTINGGROUP.CLASS", "a class with no package"), $ListBuild(..#MARKER _ "Free", ..#CLASSMARKER _ "Free", "NoSuchCubeLGW", "422 ANALYTICS.LISTINGGROUP.CUBE", "a cube that is not there"), $ListBuild(..#MARKER _ "Free", ..#CLASSMARKER _ "Free", "", "422 ANALYTICS.LISTINGGROUP.CUBE", "no cube at all") {
        Set tResult = ..Port("ListingGroups", "ADD", $List(tCase, 1), {"Name": ($List(tCase, 1)), "Class": ($List(tCase, 2)), "TargetCubes": ($List(tCase, 3))}, "", .tRes)
        Do $$$AssertEquals(tResult, $List(tCase, 4), $List(tCase, 5) _ " is refused by its own code")
    }
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing was written")
    Do ..MintRefused(..#ADDTOOL, {"Name": (tName), "Class": (..#CLASSMARKER _ "Free"), "TargetCubes": (..#VISITS)}, "ANALYTICS.LISTINGGROUP.TAKEN")
    Do ..MintRefused(..#ADDTOOL, {"Name": (..#MARKER _ "Free"), "Class": "OcuPilot.Probe", "TargetCubes": (..#VISITS)}, "TOOL.ARGUMENTS")
    Do ..MintRefused(..#UPDATETOOL, {"Name": (..#MARKER _ "Nothing"), "Caption": "x"}, "TOOL.ARGUMENTS")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no proposal was minted and nothing was written")
    Do $$$AssertEquals(..Port("ListingGroups", "UPDATE", ..#MARKER _ "Nothing", {"Caption": "x"}, "", .tRes), "404 ANALYTICS.LISTINGGROUP.ABSENT", "an update of a group that is not there is refused")
    Do $$$AssertEquals(..Port("ListingGroups", "DELETE", ..#MARKER _ "Nothing", {}, "", .tRes), "404 ANALYTICS.LISTINGGROUP.ABSENT", "and so is a delete")
    Do $$$AssertEquals(..Port("ListingGroups", "UPDATE", tName, {"Disabled": "yes"}, "", .tRes), "422 PORT.FIELD.SHAPE", "a member of the wrong type is refused by the shape rule")
}

/// <p>AC1, AC2: a copy's own refusals, each by its own code with the classes and registry nodes as they were: a new name already held by a group (409 <code>TAKEN</code>), a new class
/// already defined (409 <code>TAKEN</code>), a new name that is empty or holds a control character (422 <code>PORT.FIELD.SHAPE</code>), and a new class in a <code>%</code> package, an
/// <code>OcuPilot</code> package or with no package (422 <code>CLASS</code>). A copy with a free name and class succeeds, so the refusals are the new name's and class's alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.VendorListingGroupCompose</method> check only the new name of a copy for TAKEN -- the class leg goes red; make
/// <method>OcuPilot.Port.AnalyticsPort.PlanListingGroup</method> skip the class shape of a copy -- the three class-shape legs go red.</p>
Method TestEachCopyRefusalWritesNothing()
{
    Set tName = ..#MARKER _ "CopyHeld"
    Set tClass = ..#CLASSMARKER _ "CopyHeld"
    Set tSource = ..#MARKER _ "CopySource"
    Do $$$AssertStatusOK(..SaveGroup(tName, tClass, "LGWCopyHeld"), "a group is held")
    Do $$$AssertStatusOK(..SaveGroup(tSource, ..#CLASSMARKER _ "CopySource", "LGWCopySource", ..#CATEGORIES), "the group to copy is saved and compiled over the other cube")
    Set tBefore = ..Snapshot()
    Set tFreeName = ..#MARKER _ "CopyFree"
    Set tFreeClass = ..#CLASSMARKER _ "CopyFree"
    For tCase = $ListBuild(tName, tFreeClass, "409 ANALYTICS.LISTINGGROUP.TAKEN", "a new name already held by a group"), $ListBuild(tFreeName, tClass, "409 ANALYTICS.LISTINGGROUP.TAKEN", "a new class already defined"), $ListBuild("", tFreeClass, "422 PORT.FIELD.SHAPE", "an empty new name"), $ListBuild(tFreeName _ $Char(9), tFreeClass, "422 PORT.FIELD.SHAPE", "a new name with a control character"), $ListBuild(tFreeName, "%Probe.Free", "422 ANALYTICS.LISTINGGROUP.CLASS", "a new class in a % package"), $ListBuild(tFreeName, "OcuPilot.Probe", "422 ANALYTICS.LISTINGGROUP.CLASS", "a new class in an OcuPilot package"), $ListBuild(tFreeName, "NoPackage", "422 ANALYTICS.LISTINGGROUP.CLASS", "a new class with no package") {
        Set tResult = ..Port("ListingGroups", "COPY", tSource, {}, {"newName": ($List(tCase, 1)), "newClass": ($List(tCase, 2)), "targetCubes": (..#VISITS)}, .tRes)
        Do $$$AssertEquals(tResult, $List(tCase, 3), $List(tCase, 4) _ " is refused by its own code")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 4) _ ": nothing was written")
    }
    Do $$$AssertEquals(..Port("ListingGroups", "COPY", tSource, {}, {"newName": (tFreeName), "newClass": (tFreeClass), "targetCubes": (..#VISITS)}, .tRes), "200 ", "a copy with a free name and class succeeds")
    Do $$$AssertEquals(..Registered(tFreeName, tFreeClass), 1, "and is compiled")
}

/// <p>AC1: each write has a script form (AD-59) that makes the same change: the add's script saves and compiles the class, the delete's deletes it, and a script for a write the
/// port refuses only sets the refusal's sentence.</p>
/// <p>Mutation (Rule 19): drop the compile line from <method>OcuPilot.Port.AnalyticsPort.ListingGroupSnippet</method> -- the registered leg goes red.</p>
Method TestEachWritesScriptFormMakesTheSameChange()
{
    Set tName = ..#MARKER _ "Script"
    Set tClass = ..#CLASSMARKER _ "Script"
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "ListingGroups", "ADD") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "ListingGroups", "LISTINGGROUP"), "objectscript|", "a write has a script form and a read has none")
    Do $$$AssertEquals(..RunScript(..Script("ADD", tName, {"Name": (tName), "Class": (tClass), "TargetCubes": (..#VISITS)})), 1, "the add's script runs")
    Do $$$AssertEquals(..Registered(tName, tClass), 1, "and leaves the group compiled and registered")
    Do $$$AssertEquals(..RunScript(..Script("ADD", tName, {"Name": (tName), "Class": (tClass), "TargetCubes": (..#VISITS)})), 0, "a second add only sets the refusal: the name is held")
    Do $$$AssertEquals(..RunScript(..Script("UPDATE", tName, {"Caption": "From a script"})), 1, "the update's script runs")
    Do $$$AssertEquals($Piece($Piece(..Model(tClass), "#", 1), "|", 2), "From a script", "and changes the caption")
    Do $$$AssertEquals(..RunScript(..Script("DELETE", tName, {})), 1, "the delete's script runs")
    Do $$$AssertEquals(..Gone(tName, tClass, "LGWNone"), 1, "and removes the class and its nodes")
    Do $$$AssertEquals(..RunScript(..Script("DELETE", tName, {})), 0, "a second delete only sets the refusal: the group is not there")
}

/// <p>The three routes the editor adds answer JSON envelopes of the declared type and shape as the HTTP account: <code>POST /analytics/listing-groups</code> creates a group (201
/// <code>{id, target, readBack}</code>), <code>GET /analytics/listing-groups/form</code> answers it (200), <code>POST /analytics/listing-group-listings</code> adds a listing (201); a name
/// the instance does not hold is a 404 envelope, and a request without a name a 400 one.</p>
/// <p>Mutation (Rule 19): answer the form read as <code>text/plain</code> in <method>OcuPilot.Area.Analytics.ListingGroupForm.HandleRead</method> -- the content-type leg goes red.</p>
Method TestTheRoutesAnswerJsonEnvelopesOfTheDeclaredShape()
{
    Set tName = ..#MARKER _ "Wire"
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tCase = $ListBuild("POST", "/analytics/listing-groups?ns=USER", {"Name": (tName), "Class": (..#CLASSMARKER _ "Wire"), "TargetCubes": (..#VISITS)}.%ToJSON(), 201), $ListBuild("GET", "/analytics/listing-groups/form?ns=USER&name=" _ tName, "", 200), $ListBuild("POST", "/analytics/listing-group-listings?ns=USER", {"ListingGroup": (tName), "Name": "LGWWireOne", "Fields": "Amount"}.%ToJSON(), 201), $ListBuild("GET", "/analytics/listing-groups/form?ns=USER&name=" _ tName _ "None", "", 404), $ListBuild("GET", "/analytics/listing-groups/form?ns=USER", "", 400), $ListBuild("POST", "/analytics/listing-groups?ns=USER", "{}", 422) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tCase, 1), tBase _ $List(tCase, 2), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, $List(tCase, 3), $Select($List(tCase, 3) = "": "", 1: "application/json"))
        Do $$$AssertEquals(tStatus, $List(tCase, 4), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " answers " _ $List(tCase, 4) _ ": " _ $Extract(tRaw, 1, 200))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", $List(tCase, 2) _ ": its content type is JSON (" _ $Get(tHeaders("CONTENT-TYPE")) _ ")")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        If '$IsObject(tBody) {
            Do $$$AssertTrue(0, $List(tCase, 2) _ ": its body is one JSON document")
            Continue
        }
        If $List(tCase, 4) = 200 Do $$$AssertEquals(tBody.Name _ "|" _ tBody.Class _ "|" _ tBody.Listings, tName _ "|" _ ..#CLASSMARKER _ "Wire|0", "the form names the group, its class and its listing count")
        If $List(tCase, 4) = 201 Do $$$AssertTrue(tBody.id '= "", "the create names its target")
        If $List(tCase, 4) > 299 Do $$$AssertTrue(tBody.code '= "", "a refusal carries its code")
    }
}

/// <p>The script steps of the write <var>pType</var> on the group <var>pId</var> with the body <var>pBody</var>, through the port.</p>
ClassMethod Script(pType As %String, pId As %String, pBody As %DynamicObject) As %DynamicArray
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Quit $ClassMethod(..#PORT, "Snippet", "ListingGroups", pType, .tQuery, pBody)
}

/// <p>Run the first step of <var>pSteps</var>, a script, line by line in this process; 1 when it left <code>tSC</code> a success, 0 when it left it an error.</p>
ClassMethod RunScript(pSteps As %DynamicArray) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    XECUTE "Kill tSC"
    Try {
        Set tText = pSteps.%Get(0).text
        For tAt = 1:1:$Length(tText, $Char(10)) {
            Set tLine = $Piece(tText, $Char(10), tAt)
            If tLine '= "" XECUTE tLine
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit ''$System.Status.IsOK($Get(@"tSC"))
}

}
