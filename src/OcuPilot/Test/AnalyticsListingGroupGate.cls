/// <p>Pins Story 24.11's gate on the Listing groups and Listings reads (AD-8, AD-29, AD-44, AD-65) against real principals and, in process, through
/// <class>OcuPilot.Test.AnalyticsGateSeam</class>: a principal holding the portal's pair and <code>%DeepSee_ListingGroup:USE</code> reads the groups its resources admit and
/// reads a listing's SQL as empty; the same principal with <code>%DeepSee_ListingGroupSQL:USE</code> reads the text; a holder of the edit and SQL resources without the
/// view resource, and one without the portal's pair, are refused 403 <code>AUTH.NOPRIVILEGE</code> naming the failed pair; the group a resource guards is no row and its
/// listings no rows for a principal that holds nothing on it; the agent's read tools apply the same rules; and the port refuses a missing pair and a namespace
/// without analytics before any vendor call.</p>
/// <p>The screen legs run over HTTP as each principal; the tool legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never
/// changes identity.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named
/// <code>OcuP2411*</code> and, through <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on for <code>USER</code> and writes cubes and listing group classes there.
/// The principals and the probe are removed after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsListingGroupGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter SEAM = "OcuPilot.Test.AnalyticsGateSeam";

Parameter NAMESPACE = "USER";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>: the viewer (the developer floor,
/// the portal's pair and the view resource, with READ on USER), the SQL holder (the viewer and <code>%DeepSee_ListingGroupSQL:USE</code>), the editor without the view
/// resource (the edit and SQL resources instead). The portal's pair is public at USE, so no principal lacks it; the in-process legs cover it.</p>
Parameter PRINCIPALS = "OcuP2411Viewer:%Development:U,%DeepSee_Portal:U,%DeepSee_ListingGroup:U,%DB_USER:R;OcuP2411Sql:%Development:U,%DeepSee_Portal:U,%DeepSee_ListingGroup:U,%DeepSee_ListingGroupSQL:U,%DB_USER:R;OcuP2411Edit:%Development:U,%DeepSee_Portal:U,%DeepSee_ListingGroupEdit:U,%DeepSee_ListingGroupSQL:U,%DB_USER:R";

Parameter VIEWER = "OcuP2411Viewer";

Parameter SQLHOLDER = "OcuP2411Sql";

Parameter EDITOR = "OcuP2411Edit";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsListingGroupGate creates and deletes users and roles, turns analytics on in USER and writes cubes and classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP2411Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", ..#VIEWER)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateListingGroups")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsListingGroupGate")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principals, their roles and the probe; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsListingGroupGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsListingGroupGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

/// <p>The person's GET of <var>pPath</var> (under the API's base path, scoped to <parameter>NAMESPACE</parameter>) as <var>pUser</var>: the HTTP status; the raw body in
/// <var>pRaw</var>.</p>
Method Get(pPath As %String, pUser As %String, Output pRaw) As %Integer
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw)
    Quit +$Get(tStatus)
}

/// <p>The <code>Name</code> of a read's rows (raw JSON) that start with the probe's group prefix, comma-separated.</p>
ClassMethod Names(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit "unreadable"
    Quit ..NamesOf(tBody.rows)
}

/// <p>The <code>Name</code> of <var>pRows</var> that start with the probe's group prefix, comma-separated.</p>
ClassMethod NamesOf(pRows As %DynamicArray) As %String
{
    Set tNames = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get("Name"), 1, 21) = "OcuPilotProbeListings" Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tNames
}

/// <p>The <code>SQL</code> of the row named <var>pName</var> in the rows (raw JSON) of a Listings read; <code>"unreadable"</code> when there is none.</p>
ClassMethod SqlOf(pRaw As %String, pName As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit "unreadable"
    Quit ..SqlIn(tBody.rows, pName)
}

/// <p>The <code>SQL</code> of the row named <var>pName</var> in <var>pRows</var>; <code>"unreadable"</code> when there is none.</p>
ClassMethod SqlIn(pRows As %DynamicArray, pName As %String) As %String
{
    Set tSQL = "unreadable"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pName Set tSQL = tRow.%Get("SQL")
    }
    Quit tSQL
}

/// <p>The refusal a raw body carries, as <code>&lt;code&gt;|&lt;failed pair&gt;</code>.</p>
ClassMethod Refusal(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) Quit "unreadable"
    Quit tBody.%Get("code") _ "|" _ $Select($IsObject(tBody.%Get("detail")): tBody.detail.%Get("failedPair"), 1: "")
}

/// <p>The <code>Name</code> of every row of a read (raw JSON), comma-separated.</p>
ClassMethod AllNames(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit "unreadable"
    Set tNames = ""
    Set tIterator = tBody.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tNames
}

/// <p>The principals hold exactly what <parameter>PRINCIPALS</parameter> declares, read back from the instance, so the legs below test the pair and not a mistyped role.</p>
Method TestThePrincipalsHoldWhatTheyDeclare()
{
    For tCase = $ListBuild(..#VIEWER, "%DeepSee_ListingGroup", "USE", 1), $ListBuild(..#VIEWER, "%DeepSee_ListingGroupSQL", "USE", 0), $ListBuild(..#VIEWER, "%DeepSee_Architect", "USE", 0), $ListBuild(..#SQLHOLDER, "%DeepSee_ListingGroupSQL", "USE", 1), $ListBuild(..#EDITOR, "%DeepSee_ListingGroup", "USE", 0), $ListBuild(..#EDITOR, "%DeepSee_ListingGroupEdit", "USE", 1) {
        Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) + 0, $List(tCase, 4), $List(tCase, 1) _ " and " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " read back as declared")
    }
}

/// <p>The viewer reads the groups its resources admit, not the group that carries <code>%DeepSee_Architect</code>, and reads a listing's SQL as empty; the SQL holder reads it; the
/// guarded group's listings are no rows for either.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.Invoke</method> answer <code>tShowSQL</code> 1 -- the viewer's SQL leg goes red, and so do the tool leg of
/// <method>TestTheAgentsToolsApplyTheSameRules</method> and <method>TestAListingsSqlNeedsItsOwnPair</method>.</p>
Method TestAViewerReadsWhatItsResourcesAdmitAndNoSql()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    Set tSql = $Parameter(..#PROBE, "LISTGROUPSQL")
    For tUser = ..#VIEWER, ..#SQLHOLDER {
        Set tStatus = ..Get("/screens/analytics.listinggroups/read?maxRows=100", tUser, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ ..Names(tRaw), "200|" _ tP _ "," _ tP _ "Off," _ tP _ "Saved", tUser _ ": the groups it is admitted to, less the guarded one: " _ $Extract(tRaw, 1, 160))
        Set tStatus = ..Get("/screens/analytics.listinggrouplistings/read?listinggroup=" _ tP, tUser, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ ..AllNames(tRaw), "200|ByAmount,CustomSql", tUser _ ": the compiled group's two listings")
        Set tStatus = ..Get("/screens/analytics.listinggrouplistings/read?listinggroup=" _ tP _ "Hidden", tUser, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ ..AllNames(tRaw), "200|", tUser _ ": the guarded group's listings are no rows")
    }
    Set tStatus = ..Get("/screens/analytics.listinggrouplistings/read?listinggroup=" _ tP, ..#VIEWER, .tRaw)
    Do $$$AssertEquals(..SqlOf(tRaw, "CustomSql") _ "|" _ ..SqlOf(tRaw, "ByAmount"), "|", "the viewer reads the custom listing's SQL as empty")
    Set tStatus = ..Get("/screens/analytics.listinggrouplistings/read?listinggroup=" _ tP, ..#SQLHOLDER, .tRaw)
    Do $$$AssertEquals(..SqlOf(tRaw, "CustomSql"), tSql, "the SQL holder reads it")
}

/// <p>A principal without the view resource is refused 403 naming <code>%DeepSee_ListingGroup:USE</code> on both screens although it holds the edit and SQL resources: the classic page's
/// either-of list is narrowed to the view resource.</p>
/// <p>The screens' route gate refuses before the port, and the agent's tools reach the port's pairs alone, so <method>TestTheAgentsToolsApplyTheSameRules</method> pins the same narrowing for them.</p>
/// <p>Mutation (Rule 19): none reddens this method alone, because the descriptors' pairs enforce the narrowing too; the port's own pair is pinned by the two methods that name it.</p>
Method TestAPrincipalWithoutTheViewResourceIsRefusedNamingIt()
{
    For tPath = "/screens/analytics.listinggroups/read", "/screens/analytics.listinggrouplistings/read?listinggroup=any" {
        Set tStatus = ..Get(tPath, ..#EDITOR, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tRaw), "403 AUTH.NOPRIVILEGE|%DeepSee_ListingGroup:USE", ..#EDITOR _ " is refused naming the view resource on " _ tPath)
    }
}

/// <p>The agent's read tools apply the screens' rules as the principal who calls them: the viewer's Listings answer has no SQL and the groups less the guarded one; the SQL holder's has
/// the text; the editor's tools are refused.</p>
Method TestTheAgentsToolsApplyTheSameRules()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    Set tSql = $Parameter(..#PROBE, "LISTGROUPSQL")
    For tUser = ..#VIEWER, ..#SQLHOLDER {
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the tool probe ran as the principal: " _ tProbe.%ToJSON())
        Set tGroups = tProbe.%Get("groups")
        Set tListings = tProbe.%Get("listings")
        If '$IsObject(tGroups) || '$IsObject(tListings) {
            Do $$$AssertTrue(0, tUser _ ": the probe answered both tools")
            Continue
        }
        Do $$$AssertEquals(tGroups.%Get("http") _ "|" _ tGroups.%Get("error"), "200|", tUser _ ": the groups tool answers: " _ tGroups.%ToJSON())
        If $IsObject(tGroups.%Get("rows")) Do $$$AssertEquals(..NamesOf(tGroups.rows), tP _ "," _ tP _ "Off," _ tP _ "Saved", tUser _ ": the tool's groups are the screen's, the guarded one absent")
        Do $$$AssertEquals(tListings.%Get("http") _ "|" _ tListings.%Get("error"), "200|", tUser _ ": the listings tool answers: " _ tListings.%ToJSON())
        If $IsObject(tListings.%Get("rows")) Do $$$AssertEquals(..SqlIn(tListings.rows, "CustomSql"), $Select(tUser = ..#SQLHOLDER: tSql, 1: ""), tUser _ ": the tool's SQL is the screen's")
    }
    Set tProbe = ..ProbeAs(..#EDITOR)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#EDITOR, "the tool probe ran as the editor: " _ tProbe.%ToJSON())
    For tTool = "groups", "listings" {
        Set tLeg = tProbe.%Get(tTool)
        Do $$$AssertTrue($IsObject(tLeg), "the editor's " _ tTool _ " tool answered")
        If $IsObject(tLeg) Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ ..Refusal(tLeg.%Get("error")), "403|AUTH.NOPRIVILEGE|%DeepSee_ListingGroup:USE", "the editor's " _ tTool _ " tool is refused naming the view resource: " _ tLeg.%ToJSON())
    }
}

/// <p>In process, through the gate seam: with nothing held the port refuses naming the portal's pair; with it, the view resource; with both and a namespace that does not report
/// analytics, 409 <code>ANALYTICS.NAMESPACE</code>. Each refusal is answered while a vendor failure is armed, so a vendor call before the gate would answer 500 and not the refusal; with
/// every pair held the armed failure is reached, which proves the arming.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Port.AnalyticsPort.LISTINGGROUPPAIRS</parameter> the portal's pair alone -- the second leg goes red, and so do the editor's tool legs of
/// <method>TestTheAgentsToolsApplyTheSameRules</method>.</p>
Method TestThePortRefusesBeforeAnyVendorCall()
{
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    For tEndpoint = "ListingGroups", "ListingGroupListings" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("listinggroup") = "any"
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ ..Refusal($Select($IsObject(tFault): tFault.%ToJSON(), 1: "")), "403|AUTH.NOPRIVILEGE|%DeepSee_Portal:USE", tEndpoint _ ": nothing held names the portal's pair")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ ..Refusal($Select($IsObject(tFault): tFault.%ToJSON(), 1: "")), "403|AUTH.NOPRIVILEGE|%DeepSee_ListingGroup:USE", tEndpoint _ ": the portal's pair alone names the view resource")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_ListingGroup", "USE")
        Kill tQuery
        Set tQuery("namespace") = "HSCUSTOM"
        Set tQuery("listinggroup") = "any"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", tEndpoint _ ": both pairs held and a namespace without analytics is refused")
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("listinggroup") = "any"
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 500, tEndpoint _ ": with every pair held the armed vendor failure is reached, so the refusals above came first")
    }
}

/// <p>In process, through the gate seam: with the portal's pair, the view resource and the databases' READ held, a listing's SQL is empty; holding <code>%DeepSee_ListingGroupSQL:USE</code>
/// as well answers it.</p>
Method TestAListingsSqlNeedsItsOwnPair()
{
    Set tP = $Parameter(..#PROBE, "LISTGROUP")
    Set tSql = $Parameter(..#PROBE, "LISTGROUPSQL")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_ListingGroup", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("listinggroup") = tP
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "ListingGroupListings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: -1), "200|2", "the listings read answers")
    If $IsObject(tRows) Do $$$AssertEquals(..SqlIn(tRows, "CustomSql") _ "|" _ ..SqlIn(tRows, "ByAmount"), "|", "without the SQL pair the SQL is empty")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_ListingGroupSQL", "USE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "ListingGroupListings", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $IsObject(tRows) Do $$$AssertEquals(..SqlIn(tRows, "CustomSql") _ "|" _ ..SqlIn(tRows, "ByAmount"), tSql _ "|", "with it the custom listing's SQL is answered, and a listing with none still reads empty")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AnalyticsListingGroupGate).Probe($Job, pUser, ..#NAMESPACE)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run the agent's Listing groups read and the Listings read of the probe's compiled group scoped to
/// <var>pNamespace</var>, and signal <code>{loggedIn, username, groups, listings}</code> (each as <method>OcuPilot.Test.AnalyticsGate.ToolLeg</method> answers) to process <var>pParent</var>,
/// or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
        Do tOut.%Set("groups", ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.listinggroups.read", {}, tCap))
        Do tOut.%Set("listings", ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.listinggrouplistings.read", {"listinggroup": ($Parameter(..#PROBE, "LISTGROUP"))}, tCap))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
