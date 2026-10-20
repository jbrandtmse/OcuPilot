/// <p>Pins <class>OcuPilot.Port.AnalyticsPort</class>'s gate against real principals (AD-8, AD-29, AD-44, AD-65, Story 20.11): a
/// principal holding the developer floor and READ on <code>USER</code>'s database (the <b>reader</b>) is answered the probe cubes
/// and folder items less the ones the vendor's own resource check hides (the guarded cube and the guarded dashboard), reads a
/// hidden cube's three tabs as zero rows, and is refused Term lists and a term list's entries naming
/// <code>%DeepSee_PortalEdit:USE</code>; the same principal without READ on <code>USER</code>'s database is refused naming
/// <code>%DB_USER:READ</code>, before any vendor call would have answered an unnamed <code>&lt;PROTECT&gt;</code>; a principal that also holds
/// <code>%DeepSee_Admin:USE</code> and <code>%DeepSee_PortalEdit:USE</code> (the <b>editor</b>) reads all of it; and the agent's
/// <code>analytics.cubes.read</code>, run as the reader, answers the rows the Cubes screen answers.</p>
/// <p>The screen legs run over HTTP as each principal; the tool leg runs in a child process (<method>Probe</method>) that logs in as the
/// reader, so this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and
/// deletes users and roles named <code>OcuP2011*</code> and, through <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on for
/// <code>USER</code> and writes cubes, a term list and folder items there. Each principal also holds READ on the install namespace's
/// code database, as every caller of a route must. The principals and the probe are removed after the last test.</p>
Class OcuPilot.Test.AnalyticsGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter NAMESPACE = "USER";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: the reader (the developer floor and READ on USER), the reader without READ on USER, and the editor, which adds the
/// guarded resource and the term list editor's.</p>
Parameter PRINCIPALS = "OcuP2011Reader:%Development:U,%DB_USER:R;OcuP2011NoDb:%Development:U;OcuP2011Editor:%Development:U,%DB_USER:R,%DeepSee_Admin:U,%DeepSee_PortalEdit:U";

Parameter READER = "OcuP2011Reader";

Parameter NODB = "OcuP2011NoDb";

Parameter EDITOR = "OcuP2011Editor";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsGate creates and deletes users and roles, turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2011Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", ..#READER)
    If $$$ISOK(tSC) Set tSC = ..EnsurePrincipals()
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
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>The person's GET of <var>pPath</var> (under the API's base path, scoped to <parameter>NAMESPACE</parameter> unless it names its
/// own <code>ns</code>) as <var>pUser</var>: the HTTP status; the raw body in <var>pRaw</var>.</p>
Method Get(pPath As %String, pUser As %String, Output pRaw, pNamespace As %String = {..#NAMESPACE}) As %Integer
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ pNamespace
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw)
    Quit +$Get(tStatus)
}

/// <p>The <code>name</code> field of a list read's rows (raw JSON) that start with <var>pPrefix</var>, comma-separated.</p>
ClassMethod Names(pRaw As %String, pField As %String, pPrefix As %String) As %String
{
    Set tNames = ""
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit "unreadable"
    Set tIterator = tBody.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get(pField), 1, $Length(pPrefix)) = pPrefix Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get(pField)
    }
    Quit tNames
}

/// <p>The refusal a raw body carries, as <code>&lt;code&gt;|&lt;failed pair&gt;</code>.</p>
ClassMethod Refusal(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) Quit "unreadable"
    Quit tBody.%Get("code") _ "|" _ $Select($IsObject(tBody.%Get("detail")): tBody.detail.%Get("failedPair"), 1: "")
}

/// <p>AC3, AC1: the reader is answered the probe cubes the vendor's own resource check admits it to, and not the guarded one;
/// reads each of the three tabs of a cube it may see as rows, and of the guarded one as zero rows (the vendor's check, applied by
/// the port before the model is read); and is answered the probe folder items less the guarded dashboard, the pivot it favorited
/// marked. The editor, holding the guarded resource, is answered all three cubes and all three items, and the guarded cube's
/// tabs as rows.</p>
/// <p>Mutation (Rule 19): drop the <code>%CubeExists</code> and <code>%CheckPrivilege</code> test from the tabs in
/// <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the reader's guarded-cube tab legs go red. Dropping <code>%CheckPrivilege</code> alone
/// does not, because the vendor's <code>%CubeExists</code> answers false for a cube its resource check hides.</p>
Method TestTheVendorsOwnResourceChecksStillHideWhatTheyHide()
{
    Set tStatus = ..Get("/screens/analytics.cubes/read?maxRows=100", ..#READER, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the reader reads Cubes: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals(..Names(tRaw, "Name", "OcuPilotProbe"), "OcuPilotProbeCategories,OcuPilotProbeVisits", "and is answered the probe cubes less the guarded one")
    Set tStatus = ..Get("/screens/analytics.cubes/read?maxRows=100", ..#EDITOR, .tRaw)
    Do $$$AssertEquals(..Names(tRaw, "Name", "OcuPilotProbe"), "OcuPilotProbeCategories,OcuPilotProbeGuarded,OcuPilotProbeVisits", "the editor, holding the guarded resource, is answered all three")
    Set tStatus = ..Get("/screens/analytics.cubes/read?maxRows=2", ..#EDITOR, .tRaw)
    Set tCapped = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ tCapped.rows.%Size() _ "|" _ tCapped.truncated, "200|2|1", "a cap of two answers the first two cubes and says it truncated: " _ $Extract(tRaw, 1, 160))
    For tCase = $ListBuild("cubemeasures", "Name"), $ListBuild("cubedimensions", "Dimension"), $ListBuild("cuberelationships", "Name") {
        Set tTab = $List(tCase, 1)
        Set tStatus = ..Get("/screens/analytics." _ tTab _ "/read?cube=OcuPilotProbeVisits", ..#READER, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ (..Names(tRaw, $List(tCase, 2), "") '= ""), "200|1", tTab _ ": the reader reads a visible cube's tab: " _ $Extract(tRaw, 1, 160))
        Set tStatus = ..Get("/screens/analytics." _ tTab _ "/read?cube=OcuPilotProbeGuarded", ..#READER, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ ..Names(tRaw, $List(tCase, 2), ""), "200|", tTab _ ": and reads the guarded cube's tab as zero rows: " _ $Extract(tRaw, 1, 160))
    }
    Set tStatus = ..Get("/screens/analytics.cubemeasures/read?cube=OcuPilotProbeGuarded", ..#EDITOR, .tRaw)
    Do $$$AssertTrue(tStatus = 200 && (..Names(tRaw, "Name", "") '= ""), "the editor reads the guarded cube's measures: " _ $Extract(tRaw, 1, 160))
    Set tStatus = ..Get("/screens/analytics.folderitems/read?maxRows=200", ..#READER, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the reader reads Folder items: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals(..Names(tRaw, "Name", "OcuPilotProbe/"), "OcuPilotProbe/Board.dashboard,OcuPilotProbe/Visits.pivot", "and is answered the probe items less the guarded dashboard")
    Set tBody = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tFavorites = ""
    Set tIterator = tBody.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Favorite Set tFavorites = tFavorites _ $Select(tFavorites = "": "", 1: ",") _ tRow.Name
    }
    Do $$$AssertEquals(tFavorites, "OcuPilotProbe/Visits.pivot", "the pivot it favorited marked, and no other item")
    Set tStatus = ..Get("/screens/analytics.folderitems/read?maxRows=200", ..#EDITOR, .tRaw)
    Do $$$AssertEquals(..Names(tRaw, "Name", "OcuPilotProbe/"), "OcuPilotProbe/Board.dashboard,OcuPilotProbe/Guarded.dashboard,OcuPilotProbe/Visits.pivot", "the editor is answered all three items")
}

/// <p>AC3: Term lists and a term list's entries need the Term List Manager's pair: the reader, holding the portal's pair and
/// the developer floor but not <code>%DeepSee_PortalEdit:USE</code>, is refused 403 <code>AUTH.NOPRIVILEGE</code> naming it, on the
/// screens and through the port; the editor reads both.</p>
/// <p>Mutation (Rule 19): drop <code>%DeepSee_PortalEdit:USE</code> from
/// <parameter>OcuPilot.Port.AnalyticsPort.TERMLISTPAIRS</parameter> -- the reader reads Term lists and this goes red.</p>
Method TestTermListsNeedTheTermListManagersPair()
{
    For tPath = "/screens/analytics.termlists/read", "/screens/analytics.termlistentries/read?termlist=OcuPilotProbeTerms" {
        Set tStatus = ..Get(tPath, ..#READER, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRaw), "403|AUTH.NOPRIVILEGE|%DeepSee_PortalEdit:USE", "the reader is refused " _ tPath _ " naming the pair: " _ $Extract(tRaw, 1, 200))
    }
    Set tStatus = ..Get("/screens/analytics.termlists/read", ..#EDITOR, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ ..Names(tRaw, "Name", "OcuPilotProbe"), "200|OcuPilotProbeTerms", "the editor reads Term lists")
    Set tStatus = ..Get("/screens/analytics.termlistentries/read?termlist=OcuPilotProbeTerms", ..#EDITOR, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ ..Names(tRaw, "Key", ""), "200|k1,k2,k3", "and the entries")
    Set tProbe = ..ProbeAs(..#READER)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#READER, "the port probe ran as the reader: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.legs.%Get("TermLists"), "403|AUTH.NOPRIVILEGE|%DeepSee_PortalEdit:USE", "the port refuses the reader Term lists naming the pair")
    Do $$$AssertEquals(tProbe.legs.%Get("TermListEntries"), "403|AUTH.NOPRIVILEGE|%DeepSee_PortalEdit:USE", "and the entries")
    Do $$$AssertEquals(tProbe.legs.%Get("Cubes") _ ";" _ tProbe.legs.%Get("Measures") _ ";" _ tProbe.legs.%Get("FolderItems"), "200||;200||;200||", "while Cubes, a cube's tab and Folder items answer the reader")
}

/// <p>AC3: the reader without READ on <code>USER</code>'s database is refused by the port 403 <code>AUTH.NOPRIVILEGE</code> naming
/// <code>%DB_USER:READ</code> on Cubes, a cube's tab and Folder items, by the gate before any vendor call: the vendor's
/// <code>%GetCubeList</code> would have raised an unnamed <code>&lt;PROTECT&gt;</code>. Over HTTP the router's own namespace check refuses it
/// first, 403 <code>NS.DENIED</code> naming the same pair. The reader, in the install namespace, is refused the analytics namespace
/// sentence, 409 <code>ANALYTICS.NAMESPACE</code>.</p>
/// <p>Mutation (Rule 19): drop the globals database READ check from <method>OcuPilot.Port.AnalyticsPort.Admit</method>, so the vendor
/// call raises first -- the port's refusal becomes <code>PORT.ACCESSDENIED</code> and this goes red.</p>
Method TestAPrincipalWithoutTheDatabaseIsRefusedNamingIt()
{
    Set tProbe = ..ProbeAs(..#NODB)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#NODB, "the port probe ran as the principal: " _ tProbe.%ToJSON())
    For tEndpoint = "Cubes", "Measures", "FolderItems" {
        Do $$$AssertEquals(tProbe.legs.%Get(tEndpoint), "403|AUTH.NOPRIVILEGE|%DB_USER:READ", "the port refuses " _ tEndpoint _ ", naming the database pair")
    }
    For tPath = "/screens/analytics.cubes/read", "/screens/analytics.cubemeasures/read?cube=OcuPilotProbeVisits", "/screens/analytics.folderitems/read" {
        Set tStatus = ..Get(tPath, ..#NODB, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRaw), "403|NS.DENIED|%DB_USER:READ", "and the router refuses " _ tPath _ " first, naming it: " _ $Extract(tRaw, 1, 200))
    }
    Set tNamespace = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tStatus = ..Get("/screens/analytics.cubes/read", ..#READER, .tRaw, tNamespace)
    Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRaw), "409|ANALYTICS.NAMESPACE|", "the reader is refused " _ tNamespace _ " with the analytics sentence: " _ $Extract(tRaw, 1, 200))
}

/// <p>AC4: the agent's <code>analytics.cubes.read</code>, run as the reader against <code>USER</code>, answers the rows the Cubes screen
/// answers the reader over HTTP, each <code>{Name, Caption, Class, LastBuild, Facts}</code> from the port.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Read.View</method> remove <code>LastBuild</code> from each row it answers -- the
/// tool's rows differ from the screen's and this goes red.</p>
Method TestTheAgentsCubesReadAnswersTheScreensRows()
{
    Set tStatus = ..Get("/screens/analytics.cubes/read?maxRows=100", ..#READER, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the screen read answers")
    Set tScreen = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tProbe = ..ProbeAs(..#READER)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#READER, "the tool probe ran as the reader: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("toolHttp"), 200, "the tool answers: " _ tProbe.%Get("toolError"))
    Set tTool = tProbe.%Get("toolRows")
    Do $$$AssertTrue($IsObject(tTool) && (tTool.%Size() > 0), "with rows")
    If '$IsObject(tTool) Quit
    Set tScreenProbe = "", tToolProbe = ""
    Set tIterator = tScreen.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.Name, 1, 13) = "OcuPilotProbe" Set tScreenProbe = tScreenProbe _ $Select(tScreenProbe = "": "", 1: ";") _ tRow.Name _ "|" _ tRow.Caption _ "|" _ tRow.Class _ "|" _ tRow.LastBuild _ "|" _ tRow.Facts
    }
    Set tIterator = tTool.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.Name, 1, 13) = "OcuPilotProbe" Set tToolProbe = tToolProbe _ $Select(tToolProbe = "": "", 1: ";") _ tRow.Name _ "|" _ tRow.Caption _ "|" _ tRow.Class _ "|" _ tRow.LastBuild _ "|" _ tRow.Facts
    }
    Do $$$AssertNotEquals(tScreenProbe, "", "the screen answers the probe cubes")
    Do $$$AssertEquals(tToolProbe, tScreenProbe, "and the tool answers the same rows, last build and fact count included")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AnalyticsGate).Probe($Job, pUser, ..#NAMESPACE)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, read Cubes, the probe cube's measures, Term lists, the
/// probe term list's entries and Folder items through <class>OcuPilot.Port.AnalyticsPort</class> in <var>pNamespace</var>, run the agent's
/// <code>analytics.cubes.read</code> scoped to it, and signal <code>{loggedIn, username, legs, toolHttp, toolRows}</code> (each port leg
/// as <code>&lt;http&gt;|&lt;code&gt;|&lt;failed pair&gt;</code>) to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
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
        Set tLegs = {}
        For tEndpoint = "Cubes", "Measures", "TermLists", "TermListEntries", "FolderItems" {
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tQuery("maxRows") = 50
            If tEndpoint = "Measures" Set tQuery("cube") = "OcuPilotProbeVisits"
            If tEndpoint = "TermListEntries" Set tQuery("termlist") = "OcuPilotProbeTerms"
            Set tFault = ""
            Set tSC = ##class(OcuPilot.Port.AnalyticsPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
            Do tLegs.%Set(tEndpoint, tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code") _ "|" _ $Select($IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), 1: "|"))
        }
        Do tOut.%Set("legs", tLegs)
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("analytics.cubes.read", .tTool)
        If $$$ISERR(tSC) || '$IsObject(tTool) {
            Do tOut.%Set("toolError", "analytics.cubes.read does not resolve")
        } Else {
            Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
            Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, tCap, .tResult, .tToolHttp, .tToolFault)
            Do tOut.%Set("toolHttp", +tToolHttp, "number")
            If $IsObject($Get(tToolFault)) Do tOut.%Set("toolError", tToolFault.%ToJSON())
            If $IsObject($Get(tResult)) && $IsObject(tResult.%Get("rows")) Do tOut.%Set("toolRows", tResult.rows)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Create each of <parameter>PRINCIPALS</parameter> with a role of its own holding its pairs and READ on the install namespace's
/// code database, then read the decisive grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        If 'tResolved || (tHome = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the install namespace's code database could not be resolved")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tEntry = $Piece(..#PRINCIPALS, ";", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the analytics gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot analytics gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AnalyticsGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild(..#READER, "%DB_USER", "READ", 1), $ListBuild(..#READER, "%DeepSee_PortalEdit", "USE", 0), $ListBuild(..#READER, "%DeepSee_Admin", "USE", 0), $ListBuild(..#NODB, "%DB_USER", "READ", 0), $ListBuild(..#NODB, "%Development", "USE", 1), $ListBuild(..#EDITOR, "%DeepSee_Admin", "USE", 1), $ListBuild(..#EDITOR, "%DeepSee_PortalEdit", "USE", 1) {
            If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
