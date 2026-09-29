/// <p>Pins what Story 18.3's database writes send, show and read back, beside the matrix
/// <class>OcuPilot.Test.DatabaseWrite</class> holds: the create's file carries the size asked for and
/// its resource is made with no public permission; the create's and the delete's cards show what the
/// write sends and removes; the create's and a new volume directory's read-back hold what was sent
/// (AD-58); the delete's impact matches a namespace by each of its three database fields (AD-8); and the
/// form read lists the database resources. Both callers are reached through
/// <class>OcuPilot.Test.DatabaseWrite</class>'s own helpers.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory
/// among the allowed directories, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the class creates and deletes databases, their files, directories and resources, and probe
/// namespaces (<class>OcuPilot.Test.DatabaseWriteProbe</class>), and sets the governance policy.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe object is removed by
/// exact name before all, after each and after all, and a survivor fails the class.</p>
Class OcuPilot.Test.DatabaseWriteDetail Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseWriteProbe";

Parameter WRITE = "OcuPilot.Test.DatabaseWrite";

Parameter SAVE = "OcuPilot.Test.DatabaseSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.DatabaseConfirm";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.LocalDatabaseDelete";

/// <p>A probe resource the form read must list.</p>
Parameter PROBERESOURCE = "%DB_OCUPROBE183ZR";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseWriteDetail creates and deletes databases, their files and resources, and namespaces on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#RECORD, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe database object is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove every probe object; a failing status when any survives or the configuration file no
/// longer validates or still names a probe database.</p>
Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe database, after OcuPilot.Test.DatabaseWriteDetail"))
    Quit tSC
}

/// <p>A create on both callers makes its file at the size asked for, makes
/// <code>%DB_&lt;NAME&gt;</code> with no public permission, and reads back what it sent; and a create
/// naming neither size nor journal state shows on its card the size and journal state its write
/// sends.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Port.DatabasePort.FileBody</method> always sends
/// <parameter>OcuPilot.Port.DatabasePort.DEFAULTSIZE</parameter> -> the size legs go red;
/// <method>OcuPilot.Port.DatabasePort.EnsureResource</method> makes the resource public -> the
/// resource legs go red; <method>OcuPilot.Screen.Tool.LocalDatabaseCreate.DerivedFields</method> adds
/// no <code>Directory</code> -> the read-back reads unchecked and this goes red.</p>
Method TestACreateSendsItsSizeAndMakesAPrivateResource()
{
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Set tScreen = "OCUPROBE183ZS"
    Set tSC = $ClassMethod(..#SAVE, "Create", tScreen, {"Name": (tScreen), "root": (tRoot), "path": "ocuprobe183zs", "Size": 3}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tSC, "the screen's create succeeds")
    Do $$$AssertEquals(..Member($ClassMethod(..#RECORD, "BodyOf", "Database.SysCRUD/POST"), "Size"), 3, "the screen's file is made at the size asked for")
    Set tResource = $ClassMethod(..#RECORD, "BodyOf", "Security.Resource/PUT")
    Do $$$AssertEquals(..Keys(tResource) _ "|" _ ..Member(tResource, "PublicPermission"), "Description,PublicPermission|", "its resource is made with no public permission")
    Do $$$AssertEquals(..PublicPermission("%DB_" _ tScreen), "", "which the instance holds")
    Do $$$AssertEquals(..Verdict($Get(tReadBack)), "matches", "and the create reads back what it sent")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tAgent = "OCUPROBE183ZA"
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#CREATETOOL, tAgent, {"Name": (tAgent), "root": (tRoot), "path": "ocuprobe183za", "Size": 2}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Set tResult = ..Confirmed(tProposal, .tAnswer)
    Do $$$AssertEquals(tAnswer, "200 ", "and confirmed")
    Do $$$AssertEquals(..Member($ClassMethod(..#RECORD, "BodyOf", "Database.SysCRUD/POST"), "Size"), 2, "the agent's file is made at the size asked for")
    Do $$$AssertEquals(..PublicPermission("%DB_" _ tAgent), "", "its resource has no public permission")
    Do $$$AssertEquals(..Verdict($Select($IsObject(tResult): tResult.%Get("readBack"), 1: "")), "matches", "and the confirm reads back what it sent")

    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#CREATETOOL, "OCUPROBE183ZC", {"Name": "OCUPROBE183ZC", "root": (tRoot), "path": "ocuprobe183zc"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a create naming neither size nor journal state is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..After(tProposal, "Size") _ " " _ ..After(tProposal, "GlobalJournalState"), "1 true", "its card shows the size and the journal state its write sends")
}

/// <p>The delete's card shows the file option and what the delete removes: the directory and the two
/// mounting settings, each marked removed with the value read.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.LocalDatabaseDelete.StateDiff</method> answers no
/// rows -> this goes red.</p>
Method TestTheDeleteCardShowsWhatTheWriteRemoves()
{
    Do $$$AssertStatusOK($ClassMethod(..#WRITE, "EnableDelete"), "the agent's delete key is enabled")
    Set tName = "OCUPROBE183ZD"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#DELETETOOL, tName, {"Name": (tName), "DeleteFile": true}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Fields(tProposal), "DeleteFile,Directory,MountAtStartup,MountRequired", "its card's rows are the file option and what the delete removes")
    Do $$$AssertEquals(..After(tProposal, "DeleteFile"), "true", "the file option as asked")
    Do $$$AssertEquals(..Before(tProposal, "Directory") _ "|" _ ..Removed(tProposal, "Directory"), $ClassMethod(..#PROBE, "DirectoryFor", "zd") _ "|1", "and the directory the delete removes")
}

/// <p>A new volume directory reads back as sent, on both callers (AD-58): the file edit's payload
/// carries the resolved directory the instance then holds, so the read-back reads matches.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.LocalDatabaseUpdate.DerivedFields</method> sets
/// no <code>NewVolumeDirectory</code> -> the payload keeps the old directory, the read-back reads
/// differs and this goes red.</p>
Method TestANewVolumeDirectoryReadsBackAsSent()
{
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tName = "OCUPROBE183ZV", "OCUPROBE183ZW" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
    }
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#UPDATETOOL, "OCUPROBE183ZV", {"ExpansionSize": 4, "volumeRoot": (tRoot), "volumePath": "ocuprobe183zv-vol"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tSC, "the screen's file edit succeeds")
    Do $$$AssertEquals(..Verdict($Get(tReadBack)), "matches", "and reads back what it sent")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#UPDATETOOL, "OCUPROBE183ZW", {"Name": "OCUPROBE183ZW", "volumeRoot": (tRoot), "volumePath": "ocuprobe183zw-vol"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's file edit is minted (" _ tProblem _ ")")
    Set tResult = ..Confirmed(tProposal, .tAnswer)
    Do $$$AssertEquals(tAnswer, "200 ", "and confirmed")
    Do $$$AssertEquals(..Verdict($Select($IsObject(tResult): tResult.%Get("readBack"), 1: "")), "matches", "and reads back what it sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", $ClassMethod(..#PROBE, "DirectoryFor", "zw"), "NewVolumeDirectory"), $ClassMethod(..#PROBE, "DirectoryFor", "zw-vol"), "which the instance holds")
}

/// <p>The delete's impact names a namespace that uses the database for its globals alone, one for its
/// routines alone and one for its temporary globals alone (AD-8).</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Kernel.Proposal.Impact.NAMESPACEUSEFIELDS</parameter>
/// holds <code>Globals</code> alone -> the other two are not named and this goes red.</p>
Method TestTheImpactMatchesANamespaceByEachDatabaseField()
{
    For tName = "OCUPROBE183ZI", "OCUPROBE183ZB" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddNamespace", "OCUPROBE183ZNG", "OCUPROBE183ZI", "OCUPROBE183ZB"), "a namespace uses it for its globals")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddNamespace", "OCUPROBE183ZNR", "OCUPROBE183ZB", "OCUPROBE183ZI"), "one for its routines")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddNamespace", "OCUPROBE183ZNT", "OCUPROBE183ZB", "OCUPROBE183ZB", "OCUPROBE183ZI"), "and one for its temporary globals")
    Set tImpact = $ClassMethod(..#WRITE, "RouteImpact", "OCUPROBE183ZI", .tStatus)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Said", tImpact), "database-delete||3|OCUPROBE183ZNG,OCUPROBE183ZNR,OCUPROBE183ZNT||0|||0||", "the advisory names all three (" _ tStatus _ ")")
}

/// <p>The form read answers, as the suite's account, the <code>%DB_*</code> resources the instance
/// holds and no other resource.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.DatabaseRules.Resources</method> drops its
/// <code>%DB_</code> filter -> another resource is listed and this goes red.</p>
Method TestTheFormListsTheDatabaseResources()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", ..#PROBERESOURCE), "a probe resource exists")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/database/form", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Set tAnswer = $ClassMethod(..#WRITE, "Parsed", tRaw)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%GetTypeOf("resources"), 1: ""), "200 array", "the form read answers the resources")
    Set tListed = ","
    Set tOther = ""
    If $IsObject(tAnswer) && (tAnswer.%GetTypeOf("resources") = "array") {
        Set tIterator = tAnswer.resources.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tOne) {
            Set tListed = tListed _ tOne _ ","
            If $ZConvert($Extract(tOne, 1, 4), "U") '= "%DB_" Set tOther = tOther _ " " _ tOne
        }
    }
    Do $$$AssertTrue((tListed [ (",%DB_USER,")) && (tListed [ ("," _ ..#PROBERESOURCE _ ",")), "listing the instance's database resources, the probe's among them")
    Do $$$AssertEquals(tOther, "", "and no other resource")
}

/// <p>Confirm <var>pProposal</var> through <parameter>CONFIRM</parameter> as this process's user:
/// the confirm's result, with <code>http code</code> in <var>pAnswer</var>.</p>
ClassMethod Confirmed(pProposal As %DynamicObject, Output pAnswer As %String) As %DynamicObject
{
    Set pAnswer = "no proposal"
    If '$IsObject(pProposal) Quit ""
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Set pAnswer = $Select($$$ISOK(tSC) && ($Get(tCode) = ""): 200, 1: +$Get(tHttp)) _ " " _ $Get(tCode)
    Quit $Get(tResult)
}

/// <p>A read-back's verdict, or <code>(none)</code>.</p>
ClassMethod Verdict(pReadBack) As %String
{
    If '$IsObject(pReadBack) Quit "(none)"
    Quit pReadBack.%Get("verdict") _ $Select(pReadBack.%Get("reason") '= "": " (" _ pReadBack.%Get("reason") _ ")", 1: "")
}

/// <p>The card rows' field names, sorted, comma-separated.</p>
ClassMethod Fields(pProposal As %DynamicObject) As %String
{
    Kill tSorted
    If $IsObject(pProposal) && (pProposal.%GetTypeOf("changed") = "array") {
        Set tIterator = pProposal.changed.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) Set tSorted(tRow.%Get("field")) = ""
        }
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>Card row <var>pField</var> of <var>pProposal</var>, or <code>""</code>.</p>
ClassMethod Row(pProposal As %DynamicObject, pField As %String) As %DynamicObject
{
    If '$IsObject(pProposal) || (pProposal.%GetTypeOf("changed") '= "array") Quit ""
    Set tFound = ""
    Set tIterator = pProposal.changed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("field") = pField) Set tFound = tRow Quit
    }
    Quit tFound
}

ClassMethod After(pProposal As %DynamicObject, pField As %String) As %String
{
    Set tRow = ..Row(pProposal, pField)
    Quit $Select($IsObject(tRow): tRow.%Get("after"), 1: "(no row)")
}

ClassMethod Before(pProposal As %DynamicObject, pField As %String) As %String
{
    Set tRow = ..Row(pProposal, pField)
    Quit $Select($IsObject(tRow): tRow.%Get("before"), 1: "(no row)")
}

ClassMethod Removed(pProposal As %DynamicObject, pField As %String) As %String
{
    Set tRow = ..Row(pProposal, pField)
    Quit $Select($IsObject(tRow): +tRow.%Get("removed"), 1: "(no row)")
}

/// <p>Resource <var>pResource</var>'s public permission as the instance holds it, read in
/// <code>%SYS</code> (test-only), or <code>(absent)</code>.</p>
ClassMethod PublicPermission(pResource As %String) As %String
{
    Set tOut = "(absent)"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Resources).Exists(pResource) {
            Kill tProperties
            Set tSC = ##class(Security.Resources).Get(pResource, .tProperties)
            If $$$ISOK(tSC) Set tOut = $Get(tProperties("PublicPermission"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = "(unread)"
    }
    Quit tOut
}

ClassMethod Keys(pJson As %String) As %String
{
    Quit $ClassMethod(..#WRITE, "Keys", pJson)
}

ClassMethod Member(pJson As %String, pName As %String) As %String
{
    Quit $ClassMethod(..#WRITE, "Member", pJson, pName)
}

}
