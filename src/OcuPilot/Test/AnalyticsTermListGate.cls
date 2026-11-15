/// <p>Pins Story 24.2's gate on the term list editor's six writes (AD-8, AD-29, AD-44, AD-65), for both callers, against <code>USER</code>: a
/// principal without the Term List Manager's own pair <code>%DeepSee_PortalEdit:USE</code>, and one holding the pairs but only READ on the
/// database <code>^DeepSee.TermList</code> maps to, are each refused 403 <code>AUTH.NOPRIVILEGE</code> naming the failed pair on every route
/// and screen action, with the term lists as they were; and a term list database that is mounted read-only is refused 409
/// <code>ANALYTICS.TERMLIST.READONLY</code> at the port before any vendor call, for each of the six writes.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP,
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates users and roles, turns analytics on in <code>USER</code>
/// and writes term lists there; it removes the principals, their roles, the lists and the probe after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsTermListGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter EDIT = "OcuPilot.Test.AnalyticsTermListEdit";

Parameter SEAM = "OcuPilot.Test.AnalyticsTermListSeam";

Parameter NAMESPACE = "USER";

Parameter MARKER = "OcuProbeTL24G";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>: P1 without
/// the editor's pair, P2 with both pairs and READ on <code>USER</code> alone, P3 with both and WRITE.</p>
Parameter PRINCIPALS = "OcuP242NoEdit:%Development:U,%DeepSee_Portal:U,%DB_USER:RW;OcuP242ReadOnly:%Development:U,%DeepSee_Portal:U,%DeepSee_PortalEdit:U,%DB_USER:R;OcuP242Editor:%Development:U,%DeepSee_Portal:U,%DeepSee_PortalEdit:U,%DB_USER:RW";

Parameter P1 = "OcuP242NoEdit";

Parameter P2 = "OcuP242ReadOnly";

Parameter P3 = "OcuP242Editor";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListGate creates and deletes users and roles, turns analytics on in USER and writes term lists there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set ..PreparedPassword = "OcuP242Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsTermListGate")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principals, their roles, the lists and the probe; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#EDIT, "Sweep")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ($ClassMethod(..#EDIT, "Marked") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListGate left term lists in USER: " _ $ClassMethod(..#EDIT, "Marked"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#EDIT, "Sweep")
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#EDIT, "Sweep")
    Quit $$$OK
}

/// <p>A request over the wire as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>: the HTTP status, the raw body in <var>pRaw</var>.</p>
Method Call(pMethod As %String, pPath As %String, pUser As %String, pBody As %String, Output pRaw) As %Integer
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody, $Select(pBody = "": "", 1: "application/json"))
    Quit +$Get(tStatus)
}

/// <p>The refusal a raw body carries, as <code>&lt;code&gt;|&lt;failed pair&gt;</code>; <code>""</code> for a body that is not a refusal.</p>
ClassMethod Refusal(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || (tBody.%Get("code") = "") Quit ""
    Quit tBody.%Get("code") _ "|" _ $Select($IsObject(tBody.%Get("detail")): tBody.detail.%Get("failedPair"), 1: "")
}

/// <p>The six writes as the person reaches them, each as <code>&lt;method&gt;|&lt;path&gt;|&lt;body&gt;</code> for the list <var>pList</var>.</p>
ClassMethod Requests(pList As %String) As %List
{
    Set tEntry = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pList, "K1"))
    Quit $ListBuild("POST|/analytics/term-lists|" _ {"Name": (pList _ "New")}.%ToJSON(), "POST|/screens/analytics.termlists/action|" _ {"action": "update", "id": (pList), "values": {"Caption": "x"}}.%ToJSON(), "POST|/screens/analytics.termlists/action|" _ {"action": "delete", "id": (pList)}.%ToJSON(), "POST|/analytics/term-list-entries|" _ {"TermList": (pList), "Key": "K7"}.%ToJSON(), "POST|/screens/analytics.termlistentries/action|" _ {"action": "set", "id": (tEntry), "values": {"Value": "x"}}.%ToJSON(), "POST|/screens/analytics.termlistentries/action|" _ {"action": "remove", "id": (tEntry)}.%ToJSON())
}

/// <p>AC3: each of the six writes, from the person's side, is refused 403 naming the failed pair for the principal without the editor's pair
/// (<code>%DeepSee_PortalEdit:USE</code>) and for the one with READ alone on the term list database (<code>%DB_USER:WRITE</code>), with the term
/// lists as they were; the principal holding every pair is not refused for the pair (a leg that fails for another reason is no pass).</p>
/// <p>Mutation (Rule 19): each pair is enforced at several layers, so no single drop reddens this: remove <code>%DeepSee_PortalEdit:USE</code> from
/// <parameter>OcuPilot.Port.AnalyticsPort.TERMLISTPAIRS</parameter>, from both term list descriptors' <code>privileges</code> and the classic page's addition in
/// <method>OcuPilot.Screen.Tool.AnalyticsAction.PrivilegePairs</method> together -- the first principal's legs go red.</p>
Method TestEachWriteIsRefusedNamingTheFailedPair()
{
    Set tName = ..#MARKER _ "Pairs"
    Do $ClassMethod(..#EDIT, "Arrange", tName)
    Set tBefore = $ClassMethod(..#EDIT, "Snapshot")
    Set tRequests = ..Requests(tName)
    For tCase = $ListBuild(..#P1, "AUTH.NOPRIVILEGE|%DeepSee_PortalEdit:USE"), $ListBuild(..#P2, "AUTH.NOPRIVILEGE|%DB_USER:WRITE") {
        For tI = 1:1:$ListLength(tRequests) {
            Set tRequest = $List(tRequests, tI)
            Set tStatus = ..Call($Piece(tRequest, "|", 1), $Piece(tRequest, "|", 2), $List(tCase, 1), $Piece(tRequest, "|", 3, *), .tRaw)
            Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": request " _ tI _ " is refused naming its pair")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Snapshot"), tBefore, "and the term lists are as they were")
    Set tStatus = ..Call("POST", "/screens/analytics.termlists/action", ..#P3, {"action": "update", "id": (tName), "values": {"Caption": "by the editor"}}.%ToJSON(), .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the principal holding every pair writes: " _ $Extract(tRaw, 1, 200))
}

/// <p>AC3: with the term list database mounted read-only, each of the six writes is refused 409 <code>ANALYTICS.TERMLIST.READONLY</code> before
/// any vendor call, and the term lists are as they were.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AnalyticsPort.AdmitDestination</method> in <method>OcuPilot.Port.AnalyticsPort.AdmitTermList</method> -- the
/// six legs go red.</p>
Method TestAReadOnlyDatabaseIsRefusedBeforeAnyVendorCall()
{
    Set tName = ..#MARKER _ "ReadOnly"
    Do $ClassMethod(..#EDIT, "Arrange", tName)
    Set tBefore = $ClassMethod(..#EDIT, "Snapshot")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "readonly")
    For tCase = $ListBuild("TermLists", "ADD", tName _ "New"), $ListBuild("TermLists", "UPDATE", tName), $ListBuild("TermLists", "DELETE", tName), $ListBuild("TermListEntries", "ENTRYADD", $ClassMethod(..#EDIT, "Entry", tName, "K7")), $ListBuild("TermListEntries", "ENTRYSET", $ClassMethod(..#EDIT, "Entry", tName, "K1")), $ListBuild("TermListEntries", "ENTRYREMOVE", $ClassMethod(..#EDIT, "Entry", tName, "K1")) {
        Set tStatus = $ClassMethod(..#EDIT, "Call", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), {"Caption": "x", "Value": "x"}, .tRes, .tFault)
        Do $$$AssertEquals(tStatus, "409 ANALYTICS.TERMLIST.READONLY", $List(tCase, 2) _ " is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#EDIT, "Snapshot") _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "with nothing written and no vendor write attempted")
}

/// <p>The three routes the editor adds answer JSON envelopes of the declared type and shape as a principal holding every pair: <code>POST
/// /analytics/term-lists</code> creates a list (201 <code>{id, target, readBack}</code>), <code>GET /analytics/term-lists/form</code> answers its header
/// (200) and <code>POST /analytics/term-list-entries</code> adds an entry (201); a name the instance does not hold is a 404 envelope, and a request
/// without a name a 400 one.</p>
/// <p>Mutation (Rule 19): answer the form read as <code>text/plain</code> in <method>OcuPilot.Area.Analytics.TermListForm.HandleRead</method> -- the
/// content-type leg goes red.</p>
Method TestTheRoutesAnswerJsonEnvelopesOfTheDeclaredShape()
{
    Set tName = ..#MARKER _ "Wire"
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tCase = $ListBuild("POST", "/analytics/term-lists?ns=USER", {"Name": (tName), "Caption": "c", "Fields": ["Region"]}.%ToJSON(), 201), $ListBuild("GET", "/analytics/term-lists/form?ns=USER&name=" _ tName, "", 200), $ListBuild("POST", "/analytics/term-list-entries?ns=USER", {"TermList": (tName), "Key": "K1", "Value": "v"}.%ToJSON(), 201), $ListBuild("GET", "/analytics/term-lists/form?ns=USER&name=" _ tName _ "None", "", 404), $ListBuild("GET", "/analytics/term-lists/form?ns=USER", "", 400) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tCase, 1), tBase _ $List(tCase, 2), ..#P3, ..PreparedPassword, .tStatus, .tRaw, .tHeaders, $List(tCase, 3), $Select($List(tCase, 3) = "": "", 1: "application/json"))
        Do $$$AssertEquals(tStatus, $List(tCase, 4), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " answers " _ $List(tCase, 4) _ ": " _ $Extract(tRaw, 1, 200))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", $List(tCase, 2) _ ": its content type is JSON (" _ $Get(tHeaders("CONTENT-TYPE")) _ ")")
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        If '$IsObject(tBody) {
            Do $$$AssertTrue(0, $List(tCase, 2) _ ": its body is one JSON document")
            Continue
        }
        If $List(tCase, 4) = 200 Do $$$AssertEquals(tBody.Name _ "|" _ tBody.Fields.%ToJSON(), tName _ "|[""Region""]", "the header names the list and its fields")
        If $List(tCase, 4) = 201 Do $$$AssertTrue(tBody.id '= "", "the create names its target")
        If $List(tCase, 4) > 299 Do $$$AssertTrue(tBody.code '= "", "a refusal carries its code")
    }
}

}
