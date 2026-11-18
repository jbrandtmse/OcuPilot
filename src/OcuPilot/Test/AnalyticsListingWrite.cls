/// <p>Pins Story 24.11's listing writes (Batch 2: AD-54, AD-61, AD-65) against <code>USER</code>: a listing's add, change and remove at both callers, the person's screen routes and
/// the agent's proposals minted and confirmed over HTTP. Each leaves the group's model holding exactly the change (the other listing, its SQL included, as it was) and every line of
/// the class outside its <code>Listings</code> XData and header as it was; the group stays compiled; the Listings screen answers the new state; the read-back verdict is
/// <code>matches</code> (<code>notFound</code> for a remove). A listing's SQL needs its own pair, judged in process through <class>OcuPilot.Test.AnalyticsGateSeam</class>: without it a
/// write that sets SQL is refused naming the pair and a write that leaves SQL out keeps what the model holds; and a name the group, a cube or another group already defines is refused
/// by its own code with nothing written. The helpers are <class>OcuPilot.Test.AnalyticsListingGroupBase</class>'s.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes marker-named groups and classes in <code>USER</code>.</p>
Class OcuPilot.Test.AnalyticsListingWrite Extends OcuPilot.Test.AnalyticsListingGroupBase
{

Parameter LISTINGSCREEN = "/screens/analytics.listinggrouplistings/action";

Parameter ADDLISTINGTOOL = "OcuPilot.Screen.Tool.AnalyticsListingAdd";

Parameter SETLISTINGTOOL = "OcuPilot.Screen.Tool.AnalyticsListingSet";

Parameter REMOVELISTINGTOOL = "OcuPilot.Screen.Tool.AnalyticsListingRemove";

/// <p>AC1, AC2: the person's Add listing, Change listing and Remove listing and the agent's three proposals each change one listing of a compiled group and nothing else: the
/// group's other listing keeps its SQL, the class keeps its own lines, the group stays registered; each answers the read-back verdict <code>matches</code> (<code>notFound</code> for a
/// remove), leaves one audit row and, for the agent, its marker and one ledger row; the Listings screen answers the state after each; a remove's key ships off.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.VendorListingGroupCompose</method> start a listing write from a new model instead of <code>%GetModel</code> -- the SQL legs go red.</p>
Method TestAListingIsAddedChangedAndRemovedByEachCaller()
{
    Set tGroup = ..#MARKER _ "Listings"
    Set tClass = ..#CLASSMARKER _ "Listings"
    Do $$$AssertStatusOK(..SaveGroup(tGroup, tClass, "LGWBase"), "the group is saved and compiled")
    Set tBefore = ..Model(tClass)
    Set tBase = ..ListingIn(tBefore, "LGWBase")
    Set tOutside = ..Outside(..TextOf(tClass))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Post("/analytics/listing-group-listings", {"ListingGroup": (tGroup), "Name": "LGWPersonAdd", "DisplayName": "Person add", "Fields": "Minutes", "Description": "added by a person"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 201, "the person's Add listing answers 201: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.target.type _ "|" _ tAnswer.readBack.verdict, "listing-group-listing|matches", "created, the read-back matching what was sent")
    Set tModel = ..Model(tClass)
    Do $$$AssertEquals(..ListingIn(tModel, "LGWPersonAdd"), "LGWPersonAdd|Person add|Minutes||2|0", "the model holds the new listing as sent")
    Do $$$AssertEquals(..ListingIn(tModel, "LGWBase"), tBase, "the group's other listing, its SQL included, is as it was")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), tOutside, "every line of the class outside the XData body and the header is the same text")
    Do $$$AssertEquals(..Registered(tGroup, tClass), 1, "the group is compiled and registered")
    Do $$$AssertEquals(..Rows(tSince, "listing-group-listing", ..IdOf(tGroup, "LGWPersonAdd"), "analytics.listinggrouplistings.add"), 1, "one audit row names the add")

    Do ..Mint(..#ADDLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWAgentAdd", "Fields": "Amount", "OrderBy": "Amount DESC"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.LISTINGGROUP.SAVE|0", "the add's card states that the class is saved and compiled")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's add confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.createdId _ "|" _ tAnswer.readBack.verdict, "created|" _ ..IdOf(tGroup, "LGWAgentAdd") _ "|matches", "created, naming the listing, the read-back matching")
    Do $$$AssertEquals(..ListingIn(..Model(tClass), "LGWAgentAdd"), "LGWAgentAdd||Amount||2|0", "the model holds the agent's listing")
    Do ..AssertAgentRecords(tSince, tProposal, ..#ADDLISTINGTOOL, tTurn, "listing-group-listing", ..IdOf(tGroup, "LGWAgentAdd"))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act(..#LISTINGSCREEN, "set", ..IdOf(tGroup, "LGWPersonAdd"), {"Fields": "Amount,Minutes", "Description": "changed by a person"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the person's Change listing answers 200: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "updated|matches", "updated, the read-back matching")
    Do $$$AssertEquals(..ListingIn(..Model(tClass), "LGWPersonAdd"), "LGWPersonAdd|Person add|Amount,Minutes||2|0", "the listing's fields changed and its display name is kept")
    Do $$$AssertEquals(..ListingIn(..Model(tClass), "LGWBase"), tBase, "the other listing is still as it was")
    Do $$$AssertEquals(..Rows(tSince, "listing-group-listing", ..IdOf(tGroup, "LGWPersonAdd"), "analytics.listinggrouplistings.set"), 1, "one audit row names the change")
    Do ..Mint(..#SETLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWAgentAdd", "Description": "changed by the agent"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "the agent's change confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Piece(..ListingIn(..Model(tClass), "LGWAgentAdd"), "|", 3), "Amount", "the agent's change keeps the fields it left out")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tRows = ..ScreenRows("analytics.listinggrouplistings", tGroup)
    Do $$$AssertEquals(tRows, "LGWBase:-,LGWPersonAdd:-,LGWAgentAdd:-", "the Listings screen answers the three listings in the model's order: " _ tRows)

    Do $$$AssertEquals(..Act(..#LISTINGSCREEN, "remove", ..IdOf(tGroup, "LGWPersonAdd"), "", .tAnswer), 200, "the person's Remove listing runs: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: ""))
    Do $$$AssertEquals(..ListingIn(..Model(tClass), "LGWPersonAdd"), "", "the listing is gone from the model")
    Do ..EnableKey("analytics.listinggrouplistings.remove")
    Do ..Mint(..#REMOVELISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWAgentAdd"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "ANALYTICS.LISTINGGROUP.REMOVE|1", "the remove's card is destructive and states the consequence")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tStatus = ..Confirm(tProposal, .tAnswer, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "403|" _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's remove is refused as disabled by policy: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals(..ListingIn(..Model(tClass), "LGWAgentAdd") '= "", 1, "and the listing is still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..EnableKey("analytics.listinggrouplistings.remove")
    Do ..Mint(..#REMOVELISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWAgentAdd"}, .tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Confirm(tProposal, .tAnswer, .tRaw), 200, "with its key on the agent's remove confirms: " _ $Extract($Get(tRaw), 1, 300))
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.readBack.verdict, "deleted|notFound", "deleted, the read-back finding it gone: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(..Model(tClass), tBefore, "the model holds exactly what it held before the first add")
    Do $$$AssertEquals(..Outside(..TextOf(tClass)), tOutside, "and so does every other line of the class")
    Do ..AssertAgentRecords(tSince, tProposal, ..#REMOVELISTINGTOOL, tTurn, "listing-group-listing", ..IdOf(tGroup, "LGWAgentAdd"))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC1: a listing's SQL needs <code>%DeepSee_ListingGroupSQL:USE</code>, judged in process through the gate seam. Holding every other pair, a write that sets SQL (an add, or a change
/// that differs from what the model holds) is refused 403 naming the pair and writes nothing; a change that leaves SQL out, and one that sends the empty text a caller without the pair
/// reads, keep the SQL the model holds; with the pair held a change sets the SQL and a change that sends what the model holds changes nothing.</p>
/// <p>Mutation (Rule 19): judge the SQL pair as held in <method>OcuPilot.Port.AnalyticsPort.PlanListingGroup</method> -- the refusal legs go red.</p>
Method TestASqlChangeNeedsItsPairAndASilentOneKeepsTheSql()
{
    Set tGroup = ..#MARKER _ "Sql"
    Set tClass = ..#CLASSMARKER _ "Sql"
    Do $$$AssertStatusOK(..SaveGroup(tGroup, tClass, "LGWSqlOne"), "the group is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tSql = "SELECT ID FROM OcuPilotProbe_Analytics.Visit"
    Do ..HoldEverythingBut("%DeepSee_ListingGroupSQL:USE")
    Set tId = ..IdOf(tGroup, "LGWSqlOne")
    Set tNew = ..IdOf(tGroup, "LGWSqlTwo")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYADD", tNew, {"Fields": "Amount", "SQL": "SELECT 1"}, .tRes), "403 AUTH.NOPRIVILEGE|%DeepSee_ListingGroupSQL:USE", "an add that sets SQL, without the pair, is refused naming it")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYSET", tId, {"SQL": "SELECT 2"}, .tRes), "403 AUTH.NOPRIVILEGE|%DeepSee_ListingGroupSQL:USE", "and so is a change to other SQL")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYSET", tId, {"SQL": ""}, .tRes) _ "|" _ $Piece(..ListingIn(..Model(tClass), "LGWSqlOne"), "|", 4), "200 |" _ tSql, "the empty text a caller without the pair reads leaves the SQL as the model holds it")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYSET", tId, {"Description": "no sql here"}, .tRes) _ "|" _ $Piece(..ListingIn(..Model(tClass), "LGWSqlOne"), "|", 4), "200 |" _ tSql, "a change that leaves SQL out keeps it")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYADD", tNew, {"Fields": "Amount"}, .tRes) _ "|" _ (..ListingIn(..Model(tClass), "LGWSqlTwo") '= ""), "200 |1", "an add that sets no SQL needs no pair")
    Set tSnapshot = ..Snapshot()
    Do ..HoldEverythingBut("")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYSET", tId, {"SQL": (tSql)}, .tRes) _ "|" _ $Piece(..ListingIn(..Model(tClass), "LGWSqlOne"), "|", 4), "200 |" _ tSql, "with the pair held a change that sends the SQL the model holds changes nothing")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYSET", tId, {"SQL": "SELECT 3"}, .tRes) _ "|" _ $Piece(..ListingIn(..Model(tClass), "LGWSqlOne"), "|", 4), "200 |SELECT 3", "and one that sends other SQL sets it")
    Do $$$AssertEquals(..Seamed("ListingGroupListings", "ENTRYSET", tId, {"SQL": ""}, .tRes) _ "|" _ $Piece(..ListingIn(..Model(tClass), "LGWSqlOne"), "|", 4), "200 |", "and the empty text clears it")
    Do $$$AssertTrue(tSnapshot '= tBefore, "the writes the pair did not refuse were made")
}

/// <p>The refusals a listing write meets before anything is saved, each by its own code and each leaving the classes and registry nodes as they were: a name the group holds (add), a
/// name the group does not hold (change, remove), a group the namespace does not hold, and a group moved over a cube in which another listing group has registered a listing of the
/// same name.</p>
/// <p>Mutation (Rule 19): drop the registered-listing check from <method>OcuPilot.Port.AnalyticsPort.VendorListingGroupCompose</method> -- the move leg goes red.</p>
Method TestAListingTheGroupOrACubeAlreadyHoldsIsRefused()
{
    Set tGroup = ..#MARKER _ "Taken"
    Set tClass = ..#CLASSMARKER _ "Taken"
    Set tOther = ..#MARKER _ "Other"
    Do $$$AssertStatusOK(..SaveGroup(tGroup, tClass, "LGWHeldOne"), "the group is saved and compiled")
    Do $$$AssertStatusOK(..SaveGroup(tOther, ..#CLASSMARKER _ "Other", "LGWHeldOne", ..#CATEGORIES), "a group over the Categories cube, holding a listing of the same name, is saved and compiled")
    Set tBefore = ..Snapshot()
    Set tModel = ..Model(tClass)
    Do $$$AssertEquals(..Port("ListingGroupListings", "ENTRYADD", ..IdOf(tGroup, "LGWHeldOne"), {"Fields": "Amount"}, "", .tRes), "409 ANALYTICS.LISTINGGROUP.LISTINGTAKEN", "an add of a name the group holds is refused")
    Do $$$AssertEquals(..Port("ListingGroupListings", "ENTRYSET", ..IdOf(tGroup, "LGWNone"), {"Fields": "Amount"}, "", .tRes), "404 ANALYTICS.LISTINGGROUP.ABSENT", "a change of a listing the group does not hold is refused")
    Do $$$AssertEquals(..Port("ListingGroupListings", "ENTRYREMOVE", ..IdOf(tGroup, "LGWNone"), {}, "", .tRes), "404 ANALYTICS.LISTINGGROUP.ABSENT", "and so is a remove")
    Do $$$AssertEquals(..Port("ListingGroupListings", "ENTRYADD", ..IdOf(..#MARKER _ "Nothing", "LGWNew"), {}, "", .tRes), "404 ANALYTICS.LISTINGGROUP.ABSENT", "an add to a group the namespace does not hold is refused")
    Do $$$AssertEquals(..Port("ListingGroups", "UPDATE", tGroup, {"TargetCubes": (..#VISITS _ "," _ ..#CATEGORIES)}, "", .tRes), "409 ANALYTICS.LISTINGGROUP.LISTINGTAKEN", "a group moved over a cube where another group registered a listing of the same name is refused")
    Do $$$AssertEquals(..Snapshot(), tBefore, "and nothing was written")
    Do $$$AssertEquals(..Model(tClass), tModel, "the group's model is as it was")
    Do $$$AssertEquals(..Registered(tGroup, tClass) _ ..Registered(tOther, ..#CLASSMARKER _ "Other"), "11", "and both groups are still registered")
}

/// <p>AD-10: a listing add, change or remove in a group saved in a class whose name begins <code>OcuPilot</code> is refused 403 <code>PROHIBITED.OCUPILOTCODE</code> with the published
/// sentence, by the port, by the person's screen call and by the agent's mint, with nothing written.</p>
/// <p>Mutation (Rule 19): make the own-code checks of <method>OcuPilot.Port.AnalyticsPort.PlanListingGroup</method> and <method>OcuPilot.Port.AnalyticsPort.ReadListingGroup</method> answer
/// 0 -- every leg goes red.</p>
Method TestOwnCodeIsRefusedByEveryListingWrite()
{
    Set tGroup = ..#MARKER _ "OwnListings"
    Set tClass = ..#OWNCLASSMARKER _ "Listings"
    Do $$$AssertStatusOK(..SaveGroup(tGroup, tClass, "LGWOwnBase"), "a group saved in an OcuPilot class is held")
    Set tBefore = ..Model(tClass)
    Set tAdd = {"ListingGroup": (tGroup), "Name": "LGWOwnNew", "Fields": "Amount"}
    Do ..AssertOwnCodeRefused("a listing add", "ListingGroupListings", "ENTRYADD", ..IdOf(tGroup, "LGWOwnNew"), {"Fields": "Amount"}, "", "/analytics/listing-group-listings", "", tAdd, ..#ADDLISTINGTOOL, tAdd)
    Do ..AssertOwnCodeRefused("a listing change", "ListingGroupListings", "ENTRYSET", ..IdOf(tGroup, "LGWOwnBase"), {"Description": "x"}, "", ..#LISTINGSCREEN, "set", {"Description": "x"}, ..#SETLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWOwnBase", "Description": "x"})
    Do ..EnableKey("analytics.listinggrouplistings.remove")
    Do ..AssertOwnCodeRefused("a listing remove", "ListingGroupListings", "ENTRYREMOVE", ..IdOf(tGroup, "LGWOwnBase"), {}, "", ..#LISTINGSCREEN, "remove", "", ..#REMOVELISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWOwnBase"})
    Do $$$AssertEquals(..Model(tClass), tBefore, "and the group's model is as it was")
}

/// <p>AC1, AC5: an agent's mint of a listing add or change that sets SQL carries the consequence <code>ANALYTICS.LISTINGGROUP.SQL</code> (not destructive), where an add that leaves SQL out
/// carries the one every write states; and a principal without <code>%DeepSee_ListingGroupSQL:USE</code>, minting in a child process, is refused at the mint of either, 400
/// <code>TOOL.ARGUMENTS</code> with the privilege sentence, and no proposal and no class change results.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.AnalyticsListingAction.Consequence</method> always answer the tool's own code -- the two consequence legs go red; judge the SQL pair as
/// held in <method>OcuPilot.Port.AnalyticsPort.PlanListingGroup</method> -- the two refusal legs go red.</p>
Method TestAnAgentsSqlListingMintStatesItsConsequenceAndNeedsItsPair()
{
    Set tGroup = ..#MARKER _ "MintSql"
    Set tClass = ..#CLASSMARKER _ "MintSql"
    Do $$$AssertStatusOK(..SaveGroup(tGroup, tClass, "LGWMintOne"), "the group is saved and compiled")
    Set tBefore = ..Snapshot()
    For tCase = $ListBuild(..#ADDLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWMintTwo", "Fields": "Amount", "SQL": "SELECT 1"}.%ToJSON(), "ANALYTICS.LISTINGGROUP.SQL"), $ListBuild(..#SETLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWMintOne", "SQL": "SELECT 2"}.%ToJSON(), "ANALYTICS.LISTINGGROUP.SQL"), $ListBuild(..#ADDLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWMintThree", "Fields": "Amount"}.%ToJSON(), "ANALYTICS.LISTINGGROUP.SAVE") {
        Do ..Mint($List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tProposal, .tTurn)
        If '$IsObject($Get(tProposal)) Continue
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), $List(tCase, 3) _ "|0", $Parameter($List(tCase, 1), "TOOLNAME") _ ": the card states " _ $List(tCase, 3))
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Set tPassword = "OcuP2411Lgw" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#NOSQLPRINCIPAL, tPassword, $CLASSNAME())
    Do $$$AssertStatusOK(tSC, "the principal without the SQL pair is created")
    If $$$ISOK(tSC) {
        For tCase = $ListBuild(..#ADDLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWMintTwo", "Fields": "Amount", "SQL": "SELECT 1"}.%ToJSON()), $ListBuild(..#SETLISTINGTOOL, {"ListingGroup": (tGroup), "Name": "LGWMintOne", "SQL": "SELECT 2"}.%ToJSON()) {
            Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#NOSQLUSER, "completed", .tPrincipalTurn), "a turn is seeded for the principal")
            Set tOut = ..MintAsNoSql($List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), $Get(tPrincipalTurn))
            Do $$$AssertEquals($Select($IsObject(tOut): tOut.%Get("error"), 1: "no answer"), "", $Parameter($List(tCase, 1), "TOOLNAME") _ ": the probe process answered")
            If $IsObject(tOut) && (tOut.%Get("error") = "") {
                Do $$$AssertEquals(tOut.%Get("username"), ..#NOSQLUSER, "the probe process runs as the principal")
                Do $$$AssertEquals(tOut.%Get("minted") _ "|" _ tOut.%Get("http") _ "|" _ tOut.%Get("code") _ "|" _ tOut.%Get("problem"), "0|400|TOOL.ARGUMENTS|" _ ##class(OcuPilot.Api.Error).#REASONAUTHNOPRIVILEGE, $Parameter($List(tCase, 1), "TOOLNAME") _ ": the mint is refused with the privilege sentence and no proposal")
            }
        }
    }
    Do $$$AssertStatusOK(..RemoveNoSqlPrincipal(), "the principal is removed")
    Do $$$AssertEquals(..Snapshot(), tBefore, "no mint changed a class")
}

}
