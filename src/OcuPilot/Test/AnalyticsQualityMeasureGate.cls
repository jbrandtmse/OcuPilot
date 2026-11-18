/// <p>Pins the privilege pair of Story 24.12's quality measure reads (AD-8, AD-29, AD-44, AD-65) against real principals and, in process, through
/// <class>OcuPilot.Test.AnalyticsGateSeam</class>: a principal holding the developer floor, the portal's pair and READ on <code>USER</code> but not <code>%DeepSee_PortalEdit:USE</code>
/// is refused 403 <code>AUTH.NOPRIVILEGE</code> naming it on the three screens and by the agent's three read tools; a principal that also holds it reads the measures, a measure's groups and
/// elements and its documentation, as itself and not as <code>%All</code>, on the screens and by the tools; and the port names the first missing pair of the two, and refuses a namespace without
/// analytics, before any vendor call.</p>
/// <p>The screen legs run over HTTP as each principal; the tool legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named <code>OcuP2412*</code> and, through
/// <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on for <code>USER</code> and compiles quality measure classes there. The principals and the probe are removed after the last test.
/// One class per run.</p>
Class OcuPilot.Test.AnalyticsQualityMeasureGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter SEAM = "OcuPilot.Test.AnalyticsGateSeam";

Parameter NAMESPACE = "USER";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>: the reader (the developer floor, the portal's pair and
/// READ on USER) and the editor (the reader and <code>%DeepSee_PortalEdit:USE</code>). The portal's pair is public at USE, so no principal lacks it; the in-process leg covers it.</p>
Parameter PRINCIPALS = "OcuP2412Reader:%Development:U,%DeepSee_Portal:U,%DB_USER:R;OcuP2412Editor:%Development:U,%DeepSee_Portal:U,%DeepSee_PortalEdit:U,%DB_USER:R";

Parameter READER = "OcuP2412Reader";

Parameter EDITOR = "OcuP2412Editor";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsQualityMeasureGate creates and deletes users and roles, turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP2412Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateQualityMeasures")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsQualityMeasureGate")
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
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsQualityMeasureGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsQualityMeasureGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
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

/// <p>The rows of a read's raw JSON body as <code>&lt;count&gt;|&lt;the Name of each, comma-separated&gt;</code>; <code>"unreadable"</code> for no rows array.</p>
ClassMethod Rows(pRaw As %String, pPrefix As %String = "") As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit "unreadable"
    Quit ..RowsOf(tBody.rows, pPrefix)
}

/// <p><var>pRows</var> as <code>&lt;count&gt;|&lt;the Name of each, comma-separated&gt;</code>; when <var>pPrefix</var> is given, of the rows whose
/// <code>Name</code> starts with it only, so a measures read is judged on the probe's own rows.</p>
ClassMethod RowsOf(pRows As %DynamicArray, pPrefix As %String = "") As %String
{
    Set tNames = ""
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get("Name"), 1, $Length(pPrefix)) '= pPrefix Continue
        Set tCount = tCount + 1
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tCount _ "|" _ tNames
}

/// <p>The refusal a raw body carries, as <code>&lt;code&gt;|&lt;failed pair&gt;</code>.</p>
ClassMethod Refusal(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) Quit "unreadable"
    Quit tBody.%Get("code") _ "|" _ $Select($IsObject(tBody.%Get("detail")): tBody.detail.%Get("failedPair"), 1: "")
}

/// <p>The principals hold exactly what <parameter>PRINCIPALS</parameter> declares, read back from the instance, so the legs below test the pair and not a mistyped role.</p>
Method TestThePrincipalsHoldWhatTheyDeclare()
{
    For tCase = $ListBuild(..#READER, "%DeepSee_Portal", "USE", 1), $ListBuild(..#READER, "%DeepSee_PortalEdit", "USE", 0), $ListBuild(..#READER, "%DB_USER", "READ", 1), $ListBuild(..#READER, "%All", "USE", 0), $ListBuild(..#EDITOR, "%DeepSee_Portal", "USE", 1), $ListBuild(..#EDITOR, "%DeepSee_PortalEdit", "USE", 1), $ListBuild(..#EDITOR, "%DB_USER", "READ", 1), $ListBuild(..#EDITOR, "%All", "USE", 0) {
        Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) + 0, $List(tCase, 4), $List(tCase, 1) _ " and " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " read back as declared")
    }
}

/// <p>The reader, which holds the portal's pair and not <code>%DeepSee_PortalEdit:USE</code>, is refused 403 <code>AUTH.NOPRIVILEGE</code> naming that pair on the three screens and by the agent's three
/// read tools, as the classic page refuses it.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Port.AnalyticsPort.QUALITYMEASUREPAIRS</parameter> the portal's pair alone -- the three tool legs here and the portal-alone legs of <method>TestThePortNamesTheFirstMissingPairBeforeAnyVendorCall</method> go red (the screens' own pairs still refuse).</p>
Method TestAReaderWithoutTheEditResourceIsRefusedNamingIt()
{
    Set tName = $Parameter(..#PROBE, "QMCOMPILED")
    For tPath = "/screens/analytics.qualitymeasures/read?maxRows=100", "/screens/analytics.qualitymeasureelements/read?qualitymeasure=" _ $ZConvert(tName, "O", "URL"), "/screens/analytics.qualitymeasuremetas/read?qualitymeasure=" _ $ZConvert(tName, "O", "URL") {
        Set tStatus = ..Get(tPath, ..#READER, .tRaw)
        Do $$$AssertEquals(tStatus _ "|" _ ..Refusal(tRaw), "403|AUTH.NOPRIVILEGE|%DeepSee_PortalEdit:USE", "the reader is refused " _ $Piece(tPath, "?", 1) _ " naming the pair: " _ $Extract(tRaw, 1, 160))
    }
    Set tProbe = ..ProbeAs(..#READER)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#READER, "the tool probe ran as the reader: " _ tProbe.%ToJSON())
    For tTool = "measures", "elements", "metas" {
        Set tLeg = tProbe.%Get(tTool)
        Do $$$AssertTrue($IsObject(tLeg), "the reader's " _ tTool _ " tool answered")
        If $IsObject(tLeg) Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ ..Refusal(tLeg.%Get("error")), "403|AUTH.NOPRIVILEGE|%DeepSee_PortalEdit:USE", "the reader's " _ tTool _ " tool is refused naming the pair: " _ tLeg.%ToJSON())
    }
}

/// <p>The editor, a principal that is not <code>%All</code>, reads the three probe measures, the compiled measure's three elements and its one documentation item on the screens, and the agent's tools answer the same
/// rows: the vendor's reads need no more than the pair and READ on the database.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Port.AnalyticsPort.QUALITYMEASUREPAIRS</parameter> name <code>%DeepSee_Admin:USE</code> in place of the edit resource -- the editor's tool legs answer 403 and this goes red.</p>
Method TestAnEditorReadsTheMeasuresAsARealPrincipal()
{
    Set tName = $Parameter(..#PROBE, "QMCOMPILED")
    Set tAll = tName _ "," _ $Parameter(..#PROBE, "QMLINKED") _ "," _ $Parameter(..#PROBE, "QMREFUSED")
    Set tPrefix = $Parameter(..#PROBE, "QMCATALOG") _ "/"
    Set tStatus = ..Get("/screens/analytics.qualitymeasures/read?maxRows=100", ..#EDITOR, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ ..Rows(tRaw, tPrefix), "200|3|" _ tAll, "the editor reads the three measures: " _ $Extract(tRaw, 1, 160))
    Set tStatus = ..Get("/screens/analytics.qualitymeasureelements/read?qualitymeasure=" _ $ZConvert(tName, "O", "URL"), ..#EDITOR, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ ..Rows(tRaw), "200|3|Over30,Retired,AllVisits", "its three elements: " _ $Extract(tRaw, 1, 160))
    Set tStatus = ..Get("/screens/analytics.qualitymeasuremetas/read?qualitymeasure=" _ $ZConvert(tName, "O", "URL"), ..#EDITOR, .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ ..Rows(tRaw), "200|1|Purpose", "and its documentation: " _ $Extract(tRaw, 1, 160))
    Set tProbe = ..ProbeAs(..#EDITOR)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#EDITOR, "the tool probe ran as the editor: " _ tProbe.%ToJSON())
    For tCase = $ListBuild("measures", 3, tAll), $ListBuild("elements", 3, "Over30,Retired,AllVisits"), $ListBuild("metas", 1, "Purpose") {
        Set tLeg = tProbe.%Get($List(tCase, 1))
        Do $$$AssertTrue($IsObject(tLeg), "the editor's " _ $List(tCase, 1) _ " tool answered")
        If $IsObject(tLeg) {
            Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ tLeg.%Get("error"), "200|", "the editor's " _ $List(tCase, 1) _ " tool answers: " _ tLeg.%ToJSON())
            If $IsObject(tLeg.%Get("rows")) Do $$$AssertEquals(..SortedRows(tLeg.rows, $Select($List(tCase, 1) = "measures": tPrefix, 1: "")), $List(tCase, 2) _ "|" _ ..Sorted($List(tCase, 3)), "the tool's rows are the screen's, in the descriptor's sort order")
        }
    }
}

/// <p>The names in <var>pNames</var> (comma-separated), sorted and comma-separated, so a read in the descriptor's order and one in the port's compare equal.</p>
ClassMethod Sorted(pNames As %String) As %String
{
    Kill tSort
    For tI = 1:1:$Length(pNames, ",") {
        Set tSort($Piece(pNames, ",", tI)) = ""
    }
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSort(tKey))
        If tKey = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tKey
    }
    Quit tText
}

/// <p><var>pRows</var> as <code>&lt;count&gt;|&lt;the sorted Names&gt;</code>.</p>
ClassMethod SortedRows(pRows As %DynamicArray, pPrefix As %String = "") As %String
{
    Set tRows = ..RowsOf(pRows, pPrefix)
    Quit $Piece(tRows, "|", 1) _ "|" _ ..Sorted($Piece(tRows, "|", 2, *))
}

/// <p>In process, through the gate seam: with nothing held the port refuses naming the portal's pair; with only <code>%DeepSee_PortalEdit:USE</code> held it still names the portal's pair, the first of the two;
/// with only the portal's pair it names <code>%DeepSee_PortalEdit:USE</code>; with both and a namespace that does not report analytics, 409 <code>ANALYTICS.NAMESPACE</code>. Each refusal is answered while a vendor
/// failure is armed, so a vendor call before the gate would answer 500 and not the refusal; with every pair held the armed failure is reached, which proves the arming.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Port.AnalyticsPort.QUALITYMEASUREPAIRS</parameter> list <code>%DeepSee_PortalEdit:USE</code> first -- the nothing-held leg goes red.</p>
Method TestThePortNamesTheFirstMissingPairBeforeAnyVendorCall()
{
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    For tEndpoint = "QualityMeasures", "QualityMeasureElements", "QualityMeasureMetas" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("qualitymeasure") = "any"
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ ..Refusal($Select($IsObject(tFault): tFault.%ToJSON(), 1: "")), "403|AUTH.NOPRIVILEGE|%DeepSee_Portal:USE", tEndpoint _ ": nothing held names the portal's pair")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_PortalEdit", "USE")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ ..Refusal($Select($IsObject(tFault): tFault.%ToJSON(), 1: "")), "403|AUTH.NOPRIVILEGE|%DeepSee_Portal:USE", tEndpoint _ ": the edit resource alone still names the portal's pair")
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ ..Refusal($Select($IsObject(tFault): tFault.%ToJSON(), 1: "")), "403|AUTH.NOPRIVILEGE|%DeepSee_PortalEdit:USE", tEndpoint _ ": the portal's pair alone names the edit resource")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_PortalEdit", "USE")
        Kill tQuery
        Set tQuery("namespace") = "HSCUSTOM"
        Set tQuery("qualitymeasure") = "any"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", tEndpoint _ ": both pairs held and a namespace without analytics is refused")
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("qualitymeasure") = "any"
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 500, tEndpoint _ ": with every pair held the armed vendor failure is reached, so the refusals above came first")
    }
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AnalyticsQualityMeasureGate).Probe($Job, pUser, ..#NAMESPACE)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run the agent's three quality measure read tools (the elements and documentation tools for the compiled measure), scoped to
/// <var>pNamespace</var>, and signal <code>{loggedIn, username, measures, elements, metas}</code> (each as <method>OcuPilot.Test.AnalyticsGate.ToolLeg</method> answers) to process <var>pParent</var>, or
/// <code>{error}</code> when something raised.</p>
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
        Set tName = $Parameter(..#PROBE, "QMCOMPILED")
        Do tOut.%Set("measures", ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasures.read", {}, tCap))
        Do tOut.%Set("elements", ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasureelements.read", {"qualitymeasure": (tName)}, tCap))
        Do tOut.%Set("metas", ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasuremetas.read", {"qualitymeasure": (tName)}, tCap))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
