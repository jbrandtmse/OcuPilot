/// <p>Pins Story 24.11's read surface (AD-29, AD-36, AD-65) against <code>USER</code>, with analytics on and the probe's listing groups saved and compiled through
/// <class>OcuPilot.Test.AnalyticsProbe</class>: the Listing groups and Listings endpoints of <class>OcuPilot.Port.AnalyticsPort</class> answer what the vendor's model reads
/// from each group's class (a compiled group, a saved group whose cube does not exist, a disabled group, a group another resource guards, and one whose XData the vendor
/// cannot read, which is no row); a listing's fields equal the class's; an unknown or empty group answers no rows; a cap truncates; the Listing groups screen and the agent's
/// read tool answer the same rows; no read makes a journaled write; and removing the probe leaves no group class and no registry node.</p>
/// <p>This class runs as the unit-test process, which holds <code>%All</code>, so the guarded group and a listing's SQL are visible to it;
/// <class>OcuPilot.Test.AnalyticsListingGroupGate</class> pins their absence for callers without the resource or the SQL pair.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the probe turns analytics on for <code>USER</code>, compiles classes and writes cubes there. It removes everything after the last test.
/// One class per run.</p>
Class OcuPilot.Test.AnalyticsListingGroupRead Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

/// <p>The prefix every probe group's name carries.</p>
Parameter PREFIX = "OcuPilotProbeListings";

/// <p>The row fields of each endpoint, in the order the port answers them.</p>
Parameter GROUPFIELDS = "Name,Caption,Cubes,Class,Compiled,Listings,Disabled,Description,Resource,DefaultResource";

Parameter LISTINGFIELDS = "ListingGroup,Name,DisplayName,Type,Fields,OrderBy,Joins,Formats,Source,Resource,SelectMode,Disabled,Description,SQL";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsListingGroupRead turns analytics on in USER and writes cubes and classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $USERNAME)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateListingGroups")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateBrokenListingGroup")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe and restore USER's flags; a failing status when anything of it, a listing group included, is left.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsListingGroupRead left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Remove any twin listing group class a test left, whether or not that test reached its own removal.</p>
Method OnAfterOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveTwinListingGroup")
}

/// <p>One read of <var>pEndpoint</var> in <code>USER</code> through the port: the rows in <var>pRows</var>, the HTTP status and the fault.
/// <var>pGroup</var> names the listing group of a Listings read.</p>
ClassMethod Read(pEndpoint As %String, pGroup As %String = "", pMax As %String = 100, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    If pMax '= "" Set tQuery("maxRows") = pMax
    If pGroup '= "" Set tQuery($Parameter(..#PORT, "LISTINGGROUPKEY")) = pGroup
    Set pRows = ""
    Set pFault = ""
    Quit $ClassMethod(..#PORT, "Invoke", pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>The names of <var>pRows</var> that start with <parameter>PREFIX</parameter>, comma-separated; <code>"unreadable"</code> for no array.</p>
ClassMethod Names(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "unreadable"
    Set tNames = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get("Name"), 1, $Length(..#PREFIX)) = ..#PREFIX Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tNames
}

/// <p>How many rows of <var>pRows</var>, of any group, have no <code>Name</code>; -1 for no array.</p>
ClassMethod Nameless(pRows As %DynamicArray) As %Integer
{
    If '$IsObject(pRows) Quit -1
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = "" Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The row of <var>pRows</var> whose <code>Name</code> is <var>pName</var>, or <code>""</code>.</p>
ClassMethod RowNamed(pRows As %DynamicArray, pName As %String) As %DynamicObject
{
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pName Quit
        Set tRow = ""
    }
    Quit $Get(tRow)
}

/// <p>What the vendor's model reads from the class <var>pClass</var> in <code>USER</code>, as the Listing groups row and the Listings rows should
/// carry it: <code>{group, listings}</code>. The model is read through <code>%GetModel</code>, and <code>Compiled</code> through the vendor's own existence check.</p>
ClassMethod Facts(pClass As %String) As %DynamicObject
{
    Set tFacts = {"group": {}, "listings": []}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tModel = ##class(%DeepSee.ListingGroup).%GetModel(pClass)
        Set tGroup = tFacts.group
        Do tGroup.%Set("Name", tModel.name, "string")
        Do tGroup.%Set("Caption", $Select(tModel.displayName '= "": tModel.displayName, 1: tModel.name), "string")
        Do tGroup.%Set("Cubes", tModel.targetCubes, "string")
        Do tGroup.%Set("Class", pClass, "string")
        Do tGroup.%Set("Compiled", ''##class(%DeepSee.ListingGroup).%ListingGroupExists(tModel.name, 1), "boolean")
        Do tGroup.%Set("Listings", tModel.listings.Count(), "number")
        Do tGroup.%Set("Disabled", ''tModel.disabled, "boolean")
        Do tGroup.%Set("Description", tModel.description, "string")
        Do tGroup.%Set("Resource", tModel.resource, "string")
        Do tGroup.%Set("DefaultResource", tModel.defaultResource, "string")
        For tAt = 1:1:tModel.listings.Count() {
            Set tListing = tModel.listings.GetAt(tAt)
            Set tRow = {}
            Do tRow.%Set("ListingGroup", tModel.name, "string")
            Do tRow.%Set("Name", tListing.name, "string")
            Do tRow.%Set("DisplayName", tListing.displayName, "string")
            Do tRow.%Set("Type", tListing.listingType, "string")
            Do tRow.%Set("Fields", tListing.fieldList, "string")
            Do tRow.%Set("OrderBy", tListing.orderBy, "string")
            Do tRow.%Set("Joins", tListing.joinInfo, "string")
            Do tRow.%Set("Formats", tListing.formatList, "string")
            Do tRow.%Set("Source", tListing.sourceClass, "string")
            Do tRow.%Set("Resource", tListing.resource, "string")
            Do tRow.%Set("SelectMode", tListing.selectMode, "string")
            Do tRow.%Set("Disabled", ''tListing.disabled, "boolean")
            Do tRow.%Set("Description", tListing.description, "string")
            Do tRow.%Set("SQL", tListing.sql, "string")
            Do tFacts.listings.%Push(tRow)
        }
    } Catch ex {
        Do tFacts.%Set("error", ex.DisplayString())
    }
    Set $NAMESPACE = tOrigNS
    Quit tFacts
}

/// <p>Assert that <var>pRow</var> carries, for each of <var>pFields</var>, the value of <var>pExpected</var>.</p>
Method AssertSameFields(pRow As %DynamicObject, pExpected As %DynamicObject, pFields As %String, pLabel As %String)
{
    If '$IsObject(pRow) {
        Do $$$AssertTrue(0, pLabel _ ": the row is present")
        Quit
    }
    For tI = 1:1:$Length(pFields, ",") {
        Set tField = $Piece(pFields, ",", tI)
        Do $$$AssertEquals(pRow.%Get(tField), pExpected.%Get(tField), pLabel _ ": " _ tField _ " equals the model's")
    }
}

/// <p>AC1: every probe group the vendor lists is a row whose fields equal the model <code>%GetModel</code> reads from its class: the compiled group
/// (two listings, compiled), the saved group whose target cube does not exist (listed, not compiled), the disabled group, and the group another resource guards,
/// which the unit-test process holds. The group whose XData the model refuses is no row, and its presence breaks no other.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.Collect</method> read <code>Compiled</code> as 1 for every row -- the saved and disabled legs go red; read it from
/// <code>%Dictionary.CompiledClass</code> instead of the vendor's compiled list -- the saved and disabled groups' legs go red, because a refused or skipped compile leaves that class.</p>
Method TestTheGroupsAreTheModelsOfTheirClasses()
{
    Set tSC = ..Read("ListingGroups", "", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the groups read answers")
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    Do $$$AssertEquals(..Nameless(tRows), 0, "no row of the whole read is nameless, so the group the vendor cannot read is not one")
    Do $$$AssertEquals(..Names(tRows), tP _ "," _ tP _ "Hidden," _ tP _ "Off," _ tP _ "Saved", "the four groups the vendor reads are rows, and the group it cannot read is not")
    For tCase = $ListBuild("LISTGROUPCLASS", 1, 2), $ListBuild("LISTGROUPSAVEDCLASS", 0, 1), $ListBuild("LISTGROUPHIDDENCLASS", 1, 1), $ListBuild("LISTGROUPOFFCLASS", 0, 1) {
        Set tFacts = ..Facts($Parameter(..#PROBE, $List(tCase, 1)))
        Do $$$AssertEquals(tFacts.%Get("error"), "", $List(tCase, 1) _ ": the model reads")
        Set tRow = ..RowNamed(tRows, tFacts.group.Name)
        Do ..AssertSameFields(tRow, tFacts.group, ..#GROUPFIELDS, tFacts.group.Name)
        If $IsObject(tRow) Do $$$AssertEquals(tRow.Compiled _ "|" _ tRow.Listings, $List(tCase, 2) _ "|" _ $List(tCase, 3), tFacts.group.Name _ ": compiled, and its listing count")
    }
    Set tRow = ..RowNamed(tRows, tP)
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Cubes _ "|" _ tRow.Caption _ "|" _ tRow.DefaultResource, $Parameter(..#PROBE, "VISITS") _ "|OcuPilot probe listings|%DeepSee_Portal", "the compiled group's cubes, caption and default resource")
    Set tRow = ..RowNamed(tRows, tP _ "Saved")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Cubes _ "|" _ tRow.Caption, $Parameter(..#PROBE, "LISTGROUPNOCUBE") _ "|" _ tP _ "Saved", "the saved group names the cube that does not exist, and its caption is its name")
    Set tRow = ..RowNamed(tRows, tP _ "Off")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Disabled, 1, "the disabled group reads disabled")
    Set tRow = ..RowNamed(tRows, tP _ "Hidden")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Resource, $Parameter(..#PROBE, "HIDDENRESOURCE"), "the guarded group carries its resource")
}

/// <p>AC1: the Listings of the compiled group are one row per listing whose fields equal the class's, the SQL included for a caller holding the SQL pair; the saved
/// group's one disabled listing reads disabled; the criterion is read without regard to case; and a criterion that names no group, or none, answers no rows.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.Collect</method> push no <code>joinInfo</code> -- the Joins leg goes red; match the criterion in
/// its own case instead of the vendor's upper case -- the listings legs go red.</p>
Method TestAGroupsListingsAreTheModelsListings()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    Set tFacts = ..Facts($Parameter(..#PROBE, "LISTGROUPCLASS"))
    Set tSC = ..Read("ListingGroupListings", tP, 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: -1), "200|2", "the compiled group's listings are two rows")
    If '$IsObject(tRows) || (tRows.%Size() '= 2) Quit
    For tAt = 0:1:1 {
        Do ..AssertSameFields(tRows.%Get(tAt), tFacts.listings.%Get(tAt), ..#LISTINGFIELDS, "listing " _ (tAt + 1))
    }
    Set tByAmount = ..RowNamed(tRows, "ByAmount")
    If $IsObject(tByAmount) {
        Do $$$AssertEquals(tByAmount.Fields _ "|" _ tByAmount.OrderBy _ "|" _ tByAmount.Formats _ "|" _ tByAmount.SelectMode _ "|" _ tByAmount.Type, "Amount,Minutes|Amount DESC|color:red^|2|table", "ByAmount's fields, order, formats, select mode and type")
        Do $$$AssertTrue(tByAmount.Joins [ "LEFT JOIN OcuPilotProbe_Analytics.Category", "ByAmount's join info is the class's own")
        Do $$$AssertEquals(tByAmount.SQL, "", "and it has no SQL")
    }
    Set tCustom = ..RowNamed(tRows, "CustomSql")
    If $IsObject(tCustom) Do $$$AssertEquals(tCustom.SQL _ "|" _ tCustom.SelectMode _ "|" _ tCustom.Resource, $Parameter(..#PROBE, "LISTGROUPSQL") _ "|1|%DeepSee_Admin", "CustomSql carries its SQL, select mode and resource")
    Set tSC = ..Read("ListingGroupListings", $ZConvert(tP, "U"), 100, .tUpper, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tUpper): tUpper.%Size(), 1: -1), "200|2", "the criterion is read without regard to case")
    Set tSC = ..Read("ListingGroupListings", tP _ "Saved", 100, .tSaved, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tSaved) && (tSaved.%Size() = 1): tSaved.%Get(0).Name _ "|" _ tSaved.%Get(0).Disabled, 1: "unreadable"), "Pending|1", "the saved group's one listing reads disabled")
    Set tSC = ..Read("ListingGroupListings", "OcuPilotProbeNoSuchGroup", 100, .tNone, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tNone): tNone.%Size(), 1: -1), "200|0", "a criterion that names no group answers no rows")
    Set tSC = ..Read("ListingGroupListings", "", 100, .tEmpty, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tEmpty): tEmpty.%Size(), 1: -1), "200|0", "and so does an empty one")
}

/// <p>AC1: when a second saved class names the compiled group's name, its listings are the compiled class's, not the second class's, whichever way the two class names
/// sort, so the answer does not depend on the order the vendor lists the classes in; and of the groups rows that name the group, only the compiled class's reads compiled.</p>
/// <p>Mutation (Rule 19): make the listings branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> always take the first saved class of the name -- the early twin's
/// listing answers and the early leg goes red; make it take the last saved class -- the late leg goes red; make <code>Compiled</code> ignore which class the compiled list
/// names -- the groups legs go red.</p>
Method TestTheCompiledClassAnswersWhenTwoClassesNameOneGroup()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    For tLate = 0, 1 {
        Set tLabel = $Select(tLate: "the late twin", 1: "the early twin")
        Set tSC = $ClassMethod(..#PROBE, "CreateTwinListingGroup", tLate)
        Do $$$AssertStatusOK(tSC, tLabel _ " is saved")
        Set tSC = ..Read("ListingGroupListings", tP, 100, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: -1), "200|2", tLabel _ ": the group's listings are still the compiled class's two")
        Do $$$AssertEquals(..RowNamed(tRows, "Twin"), "", tLabel _ ": and none of them is the twin's")
        Do $$$AssertTrue($IsObject(..RowNamed(tRows, "ByAmount")), tLabel _ ": they are the compiled class's own")
        Set tSC = ..Read("ListingGroups", "", 100, .tGroups, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tLabel _ ": the groups read answers")
        Do $$$AssertEquals(..Nameless(tGroups), 0, tLabel _ ": and no row is nameless")
        Set tCompiledRows = 0
        Set tOtherCompiled = 0
        If $IsObject(tGroups) {
            Set tIterator = tGroups.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If tRow.%Get("Name") '= tP Continue
                If tRow.%Get("Class") = $Parameter(..#PROBE, "LISTGROUPCLASS") {
                    Set tCompiledRows = tCompiledRows + 1
                    Do $$$AssertEquals(tRow.%Get("Compiled") _ "|" _ tRow.%Get("Listings"), "1|2", tLabel _ ": the compiled class's row reads compiled, with its two listings")
                } ElseIf tRow.%Get("Compiled") {
                    Set tOtherCompiled = tOtherCompiled + 1
                }
            }
        }
        Do $$$AssertEquals(tCompiledRows _ "|" _ tOtherCompiled, "1|0", tLabel _ ": one row is the compiled class's and no other class's row reads compiled")
        Set tSC = $ClassMethod(..#PROBE, "RemoveTwinListingGroup")
        Do $$$AssertStatusOK(tSC, tLabel _ " is removed again")
    }
}

/// <p>The cap: a maxRows below the count answers that many rows through the port, and the screen reports the read truncated (AD-36).</p>
/// <p>The Listings screen is cut at one listing and reports it, and a cap equal to the count reports nothing cut.</p>
/// <p>Mutation (Rule 19): drop the <code>pMax</code> stop of the listings branch in <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the one-listing cap leg goes red.</p>
Method TestACapBoundsTheListAndTheScreenSaysSo()
{
    Set tSC = ..Read("ListingGroups", "", 2, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: -1), "200|2", "a cap of two answers two groups")
    Set tSC = ..Read("ListingGroupListings", $Parameter(..#PROBE, "LISTGROUP"), 1, .tListings, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tListings): tListings.%Size(), 1: -1), "200|1", "and a cap of one answers one listing")
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.listinggroups/read?maxRows=2", "", .tStatus, .tScreen)
    Do $$$AssertEquals(tStatus, 200, "the screen reads")
    If $IsObject(tScreen) Do $$$AssertEquals(tScreen.%Get("truncated") _ "|" _ $Select($IsObject(tScreen.%Get("rows")): tScreen.rows.%Size(), 1: -1), "1|2", "two rows, and the read says it was cut")
    Set tListings = "/screens/analytics.listinggrouplistings/read?listinggroup=" _ $Parameter(..#PROBE, "LISTGROUP") _ "&maxRows="
    Do $ClassMethod(..#CONTROL, "Call", "GET", tListings _ "1", "", .tStatus, .tCut)
    Do $$$AssertEquals(tStatus, 200, "the Listings screen reads under a cap of one")
    If $IsObject(tCut) Do $$$AssertEquals(tCut.%Get("truncated") _ "|" _ $Select($IsObject(tCut.%Get("rows")): tCut.rows.%Size(), 1: -1), "1|1", "one listing, and the Listings read says it was cut")
    Do $ClassMethod(..#CONTROL, "Call", "GET", tListings _ "2", "", .tStatus, .tFit)
    Do $$$AssertEquals(tStatus, 200, "the Listings screen reads under a cap equal to the count")
    If $IsObject(tFit) Do $$$AssertEquals(tFit.%Get("truncated") _ "|" _ $Select($IsObject(tFit.%Get("rows")): tFit.rows.%Size(), 1: -1), "0|2", "both listings, and the read says nothing was cut")
}

/// <p>AC2 (Integration, Rule 1): the Listing groups screen's read and the agent's <code>analytics.listinggroups.read</code> answer the same rows, and so do the
/// Listings screen and <code>analytics.listinggrouplistings.read</code> for the compiled group; the rows carry the compiled group and its SQL for this
/// caller.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Read.View</method> drop the criteria it was given -- the Listings tool is refused 400 and this goes red.</p>
Method TestTheScreenAndTheAgentsToolAnswerTheSameRows()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.listinggroups/read?maxRows=100", "", .tStatus, .tScreen)
    Do $$$AssertEquals(tStatus, 200, "the Listing groups screen reads")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.listinggroups.read", {}, tCap)
    Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ tLeg.%Get("error"), "200|", "the agent's read tool answers: " _ tLeg.%ToJSON())
    Do $$$AssertTrue($IsObject(tScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tScreen.%Get("rows")), "both reads carry rows")
    If $IsObject(tScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tScreen.%Get("rows")) {
        Do $$$AssertTrue(tLeg.rows.%Size() >= 4, "with at least the four probe groups, so the comparison is never of two empty reads")
        Do $$$AssertEquals(tLeg.rows.%ToJSON(), tScreen.rows.%ToJSON(), "the tool's rows are the screen's")
        Set tRow = ..RowNamed(tLeg.rows, tP)
        If $IsObject(tRow) Do $$$AssertEquals(tRow.Compiled _ "|" _ tRow.Listings, "1|2", "and the compiled group's row is the same row")
    }
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.listinggrouplistings/read?listinggroup=" _ tP, "", .tStatus, .tListingScreen)
    Do $$$AssertEquals(tStatus, 200, "the Listings screen reads")
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.listinggrouplistings.read", {"listinggroup": (tP)}, tCap)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ tLeg.%Get("error"), "200|", "the Listings tool answers: " _ tLeg.%ToJSON())
    Do $$$AssertTrue($IsObject(tListingScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tListingScreen.%Get("rows")), "both listings reads carry rows")
    If $IsObject(tListingScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tListingScreen.%Get("rows")) {
        Do $$$AssertEquals(tLeg.rows.%Size(), 2, "with the group's two listings")
        Do $$$AssertEquals(tLeg.rows.%ToJSON(), tListingScreen.rows.%ToJSON(), "the tool's rows are the screen's")
        Do $$$AssertEquals(tLeg.rows.%Get(1).SQL, $Parameter(..#PROBE, "LISTGROUPSQL"), "and the second carries its SQL for a caller who holds %All")
    }
}

/// <p>AC4: no read of the matrix makes a journaled write in the calling process. The scan is proved able to see one: a control write made inside the same window is
/// the only record it finds, and the reads before it found none. It covers the process's journaled databases; a write to a database that is not journaled is not seen.</p>
/// <p>Mutation (Rule 19): make the groups branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> set a global node in <code>USER</code> -- the no-write leg goes red.</p>
Method TestNoReadMakesAJournaledWrite()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    ; The framework journals each assertion it records, so nothing is asserted until both scans are done.
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tSC = ..Read("ListingGroups", "", 100, .tRows, .tGroupsHttp, .tFault)
    Set tListingsHttp = ""
    For tGroup = tP, tP _ "Saved", tP _ "Off", tP _ "Hidden", "OcuPilotProbeNoSuchGroup" {
        Set tSC = ..Read("ListingGroupListings", tGroup, 100, .tListings, .tHttp, .tFault)
        Set tListingsHttp = tListingsHttp _ $Select(tListingsHttp = "": "", 1: ",") _ tHttp
    }
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.listinggroups.read", {}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Set tListingsLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.listinggrouplistings.read", {"listinggroup": (tP)}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tReads = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tReadWrites)
    Set tFirst = $Get(tReadWrites(1))
    Set ^|"USER"|OcuPilotProbeAnalyticsScan = 1
    Set tSeen = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tAllWrites)
    Kill ^|"USER"|OcuPilotProbeAnalyticsScan
    Set tControl = $Get(tAllWrites(1))
    Do $$$AssertEquals(tGroupsHttp _ "|" _ tListingsHttp _ "|" _ tLeg.%Get("http") _ "|" _ tListingsLeg.%Get("http"), "200|200,200,200,200,200|200|200", "the groups read, the five listings reads and the agent's two reads answer")
    Do $$$AssertEquals(tReads, 0, "the reads made no journaled write" _ $Select(tReads > 0: ": " _ tFirst, 1: ""))
    Do $$$AssertEquals(tSeen, 1, "while the scan sees the control write made after them" _ $Select(tSeen > 0: ": " _ tControl, 1: ""))
}

/// <p>AC6: removing the probe's listing groups deletes every group class and every registry node of a probe group, so <method>OcuPilot.Test.AnalyticsProbe.Left</method>
/// names none; creating them again restores them. The registry nodes are read directly, not through the probe.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Test.AnalyticsProbe.RemoveListingGroups</method> delete no class -- this goes red.</p>
Method TestRemovingTheListingGroupsLeavesNothing()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveListingGroups"), "the groups are removed")
    Do $$$AssertEquals(..Left(), "", "no group class and no registry node of a probe group remains: " _ ..Left())
    Set tSC = ..Read("ListingGroups", "", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(..Names(tRows), "", "and the groups read answers none of them")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateListingGroups"), "the groups are made again")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateBrokenListingGroup"), "with the broken one")
    Set tSC = ..Read("ListingGroups", "", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(..Names(tRows), tP _ "," _ tP _ "Hidden," _ tP _ "Off," _ tP _ "Saved", "and the read answers them again")
}

/// <p>What the probe's listing groups leave in <code>USER</code>: a group class of the probe's package, or a registry node of a probe group, a class or a listing.</p>
ClassMethod Left() As %String
{
    Set tLeft = ""
    Set tNames = ""
    For tClass = "LISTGROUPCLASS", "LISTGROUPSAVEDCLASS", "LISTGROUPHIDDENCLASS", "LISTGROUPOFFCLASS", "LISTGROUPBROKENCLASS", "LISTGROUPTWINCLASS", "LISTGROUPTWINLATECLASS" {
        Set tNames = tNames _ $ListBuild($Parameter(..#PROBE, tClass))
    }
    Set tPrefix = $ZConvert(..#PREFIX, "U")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tName) Set tLeft = tLeft _ ",class " _ tName
            If $Data(^DeepSee.ListingGroups("classes", tName)) Set tLeft = tLeft _ ",class node " _ tName
        }
        Set tGroup = ""
        For {
            Set tGroup = $Order(^DeepSee.ListingGroups("groups", tGroup))
            If tGroup = "" Quit
            If $Extract(tGroup, 1, $Length(tPrefix)) = tPrefix Set tLeft = tLeft _ ",group node " _ tGroup
        }
        Set tCube = ""
        For {
            Set tCube = $Order(^DeepSee.ListingGroups("cubes", tCube))
            If tCube = "" Quit
            Set tListing = ""
            For {
                Set tListing = $Order(^DeepSee.ListingGroups("cubes", tCube, "listing", tListing))
                If tListing = "" Quit
                If $ListFind($ListBuild("ByAmount", "CustomSql", "Pending", "Secret", "Idle", "Twin"), tListing) Set tLeft = tLeft _ ",listing node " _ tCube _ "/" _ tListing
            }
        }
    } Catch ex {
        Set tLeft = tLeft _ ",unreadable: " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit $Extract(tLeft, 2, *)
}

}
