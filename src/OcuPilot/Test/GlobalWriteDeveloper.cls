/// <p>Pins Story 21.5's writes for a real principal that holds <code>%Development:USE</code> and the install namespace's databases' READ and WRITE, and
/// no <code>OcuPilotAdmin</code> and no <code>%All</code> (AC3, AC4, AC5; AD-8, AD-10): every call is an HTTP request signed in as that principal, so the
/// kernel's globals arm finds its protected locations with calls such a caller may make. Its edit of a node, its kill of a node and its delete of a
/// global of its own are answered 200, and its edit, kill and delete of a node or a global stored in a system database are refused
/// <code>PROHIBITED.PROTECTEDGLOBAL</code> before any write, as the classic page would not write them either. Story 21.17's transfers, the way a
/// developer without a server-file pair reaches them: its own global exported to this browser and imported back over itself from the local file, a
/// non-Latin value included, a local file holding a <code>%</code>-global refused, and an export of one of OcuPilot's own globals refused
/// <code>GLOBAL.OWNDATA</code>. Story 21.18's find and replace: its own global replaced, and the <code>%</code> copy of it refused
/// <code>PROHIBITED.PROTECTEDGLOBAL</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes a user and a role. <method>OnBeforeAllTests</method> refuses anywhere it does not, and
/// <method>OnAfterAllTests</method> removes the principal. Each test makes its own <code>^ZZOcuGlbDev&lt;pid&gt;</code> in <code>HSCUSTOM</code> and kills it.
/// It writes no protected global other than the <code>%</code> copy of its own global, which the replace test makes, and kills that copy.</p>
Class OcuPilot.Test.GlobalWriteDeveloper Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PORT = "OcuPilot.Port.GlobalPort";

Parameter FIXTURE = "OcuPilot.Test.DeveloperFloorFixture";

Parameter DEVUSER = "OcuPilotGlobalDev";

Parameter DEVROLE = "OcuPilotGlobalDevRole";

Parameter LISTSCREEN = "explorer.globals";

Parameter NODESCREEN = "explorer.globalnodes";

Parameter NAMESPACE = "HSCUSTOM";

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The name of the test's own global, without <code>^</code>.</p>
Property PreparedName As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedName = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.GlobalWriteDeveloper creates and deletes a user and a role and writes a global on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(..PreparedPassword, ..Principals(), "RW")
}

/// <p>Remove the principal and its role; a failing status when either survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Principals(), "OcuPilot.Test.GlobalWriteDeveloper")
}

/// <p>The developer, as <method>OcuPilot.Test.AdminStateWrite.EnsurePrincipals</method> takes it.</p>
ClassMethod Principals() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U", 0))
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedName = "ZZOcuGlbDev" _ $Job
    Do ..Remove()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Remove()
    Quit $$$OK
}

/// <p>Kill the test's global.</p>
Method Remove()
{
    Set tRoot = "^" _ ..PreparedName
    Kill @tRoot
    Set tPercent = "^%" _ ..PreparedName
    Kill @tPercent
}

/// <p>The canonical reference of the test's node <var>pSubscripts</var> (the text inside the parentheses).</p>
Method Ref(pSubscripts As %String) As %String
{
    Quit "^" _ ..PreparedName _ "(" _ pSubscripts _ ")"
}

/// <p>The screen action <var>pAction</var> of <var>pScreen</var> on <var>pId</var> over HTTP, in <parameter>NAMESPACE</parameter>, signed in as the
/// developer, through the screen's <var>pRoute</var> (<code>action</code>, or <code>dryrun</code> for a review): the status, and the parsed answer in
/// <var>pAnswer</var>.</p>
Method Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer As %DynamicObject, pRoute As %String = "action") As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set pAnswer = ""
    Set tSC = $ClassMethod(..#FIXTURE, "Call", "POST", "/screens/" _ pScreen _ "/" _ pRoute _ "?ns=" _ ..#NAMESPACE, ..#DEVUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, $ZConvert(tBody.%ToJSON(), "O", "UTF8"))
    If $$$ISERR(tSC) Quit 0
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tText)
    } Catch {
        Set pAnswer = ""
    }
    Quit tStatus
}

/// <p>The status and refusal code an answer carries, as <code>status code</code>.</p>
ClassMethod Verdict(pStatus As %Integer, pAnswer As %DynamicObject) As %String
{
    Quit pStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The node <var>pReference</var>'s value as the dialog would read it, read in-process through the port.</p>
Method Shown(pReference As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("reference") = pReference
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Node", "GET", .tQuery, "", .tNode, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tNode)): tNode.Value, 1: "")
}

/// <p>AC3, AC4. The developer opens the node page on its own global, edits a node, kills a node with everything below it, and deletes the global, each
/// answered 200: the page holds the global's nodes, the edit's read-back matches, and the instance holds what the answers say.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.ProtectedDirectories</method> reads the database configuration through
/// <code>Database.ConfigCRUD</code> as the caller again -> every write row answers 500 and goes red; <method>OcuPilot.Area.Explorer.GlobalNodes.Gate</method>
/// also requires <code>OcuPilotAdmin:USE</code> -> the page row answers 403 and goes red.</p>
Method TestADeveloperWritesAnOrdinaryGlobalWithoutAdministratorRights()
{
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot@(1) = "v1"
    Set @tRoot@("t") = "top"
    Set @tRoot@("t", 1) = "a"
    Do ..AssertPrincipal()
    Set tSC = $ClassMethod(..#FIXTURE, "Call", "POST", "/explorer/globals/nodes?ns=" _ ..#NAMESPACE, ..#DEVUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, {"global": (..PreparedName)}.%ToJSON())
    Set tPage = ""
    If $$$ISOK(tSC) && ($Get(tStatus) = 200) Set tPage = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals($Get(tStatus) _ "|" _ $Select($IsObject(tPage): tPage.rows.%Size(), 1: ""), "200|3", "the developer opens the node page on its own global and it holds its three nodes: " _ $Extract($Get(tText), 1, 200))
    Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(1), {"Value": "new", "Was": "v1"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ @tRoot@(1), "200|new", "the developer's edit is answered 200 and the node holds the new value: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.readBack): tAnswer.readBack.verdict, 1: ""), "matches", "and its read-back matches")
    Set tStatus = ..Act(..#NODESCREEN, "delete", ..Ref("""t"""), , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Data(@tRoot@("t")) _ "|" _ $Data(@tRoot@("t", 1)), "200|0|0", "the developer's node kill is answered 200 and takes everything below the node")
    Set tStatus = ..Act(..#LISTSCREEN, "delete", ..PreparedName, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Data(@tRoot), "200|0", "the developer's delete of the global is answered 200 and the global is gone")
}

/// <p>AC5. The developer is refused <code>PROHIBITED.PROTECTEDGLOBAL</code>, as <code>403</code> and before any write, for an edit and a kill of a node
/// stored in the system library and for the delete of the global that holds it, and nothing of it changes.</p>
/// <p>Mutation (Rule 19): drop the directory comparison in <method>OcuPilot.Kernel.Proposal.Prohibited.ProtectedLocation</method> -> every row goes red;
/// leave out the library's global from <method>OcuPilot.Kernel.Proposal.Prohibited.ProtectedDirectories</method> -> the edit row goes red (the kill and
/// the delete judge every mapping row of the global, so another row can still refuse them).</p>
Method TestADeveloperIsRefusedAGlobalStoredInASystemDatabase()
{
    Set tNode = $Query(^oddDEF)
    Set tBefore = $Data(^oddDEF) _ "|" _ $Get(@tNode)
    Set tLibrary = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^%qZZOcuGlb"), "^", 2)
    Set tStored = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^oddDEF", $ClassMethod(..#PORT, "SubscriptText", tNode)), "^", 2)
    Do $$$AssertTrue((tNode '= "") && (tStored '= "") && (tStored = tLibrary), "the first node of oddDEF is stored in the system library, so a regressed arm meets the instance's own refusal: " _ tNode _ " " _ tStored)
    If (tNode = "") || (tStored '= tLibrary) Quit
    Set tSentence = ##class(OcuPilot.Kernel.Proposal.Prohibited).#PROTECTEDGLOBALREASON
    Set tStatus = ..Act(..#NODESCREEN, "save", tNode, {"Value": "x", "Was": (..Shown(tNode))}, .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), "403 PROHIBITED.PROTECTEDGLOBAL|" _ tSentence, "an edit of its node is refused with the published sentence")
    Set tStatus = ..Act(..#NODESCREEN, "delete", tNode, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "403 PROHIBITED.PROTECTEDGLOBAL", "a kill of its node is refused")
    Set tStatus = ..Act(..#LISTSCREEN, "delete", "oddDEF", , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "403 PROHIBITED.PROTECTEDGLOBAL", "and so is the delete of the whole global")
    Do $$$AssertEquals($Data(^oddDEF) _ "|" _ $Get(@tNode), tBefore, "nothing of it changed")
}

/// <p>Story 21.17. The developer exports its own global, a non-Latin value included, to this browser, and imports the lines back from a local file
/// over the changed global, which is then as it was; a local file holding the <code>%</code> copy of it is refused
/// <code>PROHIBITED.PROTECTEDGLOBAL</code> with nothing loaded; and an export of a global named for OcuPilot is refused <code>GLOBAL.OWNDATA</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.GlobalPort.GlobalTotals</method> also requires <code>OcuPilotAdmin:USE</code> -> the export row answers 403
/// and goes red.</p>
Method TestADeveloperExportsAndImportsItsOwnGlobalAndIsRefusedAProtectedOne()
{
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot@(1) = "plain"
    Set @tRoot@(2) = $Char(955, 8364, 26085)
    Set tBefore = $Get(@tRoot@(1)) _ "|" _ $Get(@tRoot@(2)) _ "|" _ $Data(@tRoot@(9))
    Do ..AssertPrincipal()
    Set tStatus = ..Act(..#LISTSCREEN, "export-browser", ..PreparedName, , .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the developer exports its own global to this browser: " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""), 1, 200))
    Set tText = ""
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("output")) {
        Set tIterator = tAnswer.output.lines.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
        }
    }
    Do $$$AssertTrue(tText [ ("<Sub>" _ tRoot _ "</Sub>"), "its output is the XML of the global")
    Set @tRoot@(1) = "changed"
    Set @tRoot@(9) = "extra"
    Set tStatus = ..Act(..#LISTSCREEN, "import-local", "import", {"fileName": "dev.xml", "content": (tText), "Compile": "false"}, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "and imports the lines back over the changed global: " _ $Extract($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""), 1, 200))
    Do $$$AssertEquals($Get(@tRoot@(1)) _ "|" _ $Get(@tRoot@(2)) _ "|" _ $Data(@tRoot@(9)), tBefore, "which is as it was, its non-Latin value included")
    Set tPercent = "^%" _ ..PreparedName
    Set tStatus = ..Act(..#LISTSCREEN, "import-local", "import", {"fileName": "pct.xml", "content": ($Replace(tText, "<Sub>" _ tRoot _ "</Sub>", "<Sub>" _ tPercent _ "</Sub>")), "Compile": "false"}, .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Data(@tPercent), "403 PROHIBITED.PROTECTEDGLOBAL|0", "a local file holding its % copy is refused and loads nothing")
    Set tStatus = ..Act(..#LISTSCREEN, "export-browser", "OcuPilotZZ" _ $Job, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "403 GLOBAL.OWNDATA", "an export of a global named for OcuPilot is refused")
}

/// <p>Story 21.18. The developer reviews a find and replace in its own global and confirms it, answered 200 with every plain-text occurrence replaced and the
/// <code>$ListBuild</code> value kept; its replace in the <code>%</code> copy of the global, which the namespace stores in the system database, is refused
/// <code>PROHIBITED.PROTECTEDGLOBAL</code> before any write, the kernel's globals arm reading where the changing nodes are stored as the developer.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.ReplaceLocations</method> also requires <code>%Admin_Manage:USE</code> -> the
/// developer's replace of its own global is refused and goes red.</p>
Method TestADeveloperReplacesInItsOwnGlobalAndIsRefusedAProtectedOne()
{
    Do ..AssertPrincipal()
    For tName = ..PreparedName, "%" _ ..PreparedName {
        Set tRoot = "^" _ tName
        Set @tRoot@(1) = "a abc"
        Set @tRoot@("s") = "abc abc"
        Set @tRoot@(2) = $ListBuild("abc")
    }
    Set tValues = {"Find": "abc", "Replace": "xyz", "MatchCase": "true"}
    Set tStatus = ..Act(..#LISTSCREEN, "replace", ..PreparedName, tValues, .tReview, "dryrun")
    Set tDigest = $Select($IsObject(tReview) && $IsObject(tReview.%Get("review")): tReview.review.Digest, 1: "")
    Do $$$AssertTrue((tStatus = 200) && (tDigest '= ""), "the developer's review of its own global is answered with a digest: " _ $Select($IsObject(tReview): tReview.%ToJSON(), 1: ""))
    Do tValues.%Set("Reviewed", tDigest, "string")
    Set tStatus = ..Act(..#LISTSCREEN, "replace", ..PreparedName, tValues, .tAnswer)
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertEquals(tStatus _ "|" _ @tRoot@(1) _ "|" _ @tRoot@("s") _ "|" _ (@tRoot@(2) = $ListBuild("abc")), "200|a xyz|xyz xyz|1", "the developer's replace is answered 200 and replaces every plain-text occurrence: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tPercent = "^%" _ ..PreparedName
    Set tStored = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, tPercent), "^", 2)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GlobalProhibited).DirectoriesOf(.tProtected), "the protected directories are read")
    Do $$$AssertTrue((tStored '= "") && ($ListFind($Get(tProtected), tStored) > 0), "the % copy is stored in a protected database: " _ tStored)
    Do tValues.%Remove("Reviewed")
    Set tStatus = ..Act(..#LISTSCREEN, "replace", "%" _ ..PreparedName, tValues, .tReview, "dryrun")
    Set tDigest = $Select($IsObject(tReview) && $IsObject(tReview.%Get("review")): tReview.review.Digest, 1: "")
    Do tValues.%Set("Reviewed", tDigest, "string")
    Set tStatus = ..Act(..#LISTSCREEN, "replace", "%" _ ..PreparedName, tValues, .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ @tPercent@(1) _ "|" _ @tPercent@("s"), "403 PROHIBITED.PROTECTEDGLOBAL|a abc|abc abc", "its replace in the % copy is refused before any write")
}

/// <p>The principal this class signs in as holds <code>%Development:USE</code> and neither <code>OcuPilotAdmin</code> nor <code>%All</code>.</p>
Method AssertPrincipal()
{
    Do $$$AssertEquals($System.Security.CheckUserPermission(..#DEVUSER, "%Development", "USE"), 1, "the principal holds %Development:USE")
    Do $$$AssertEquals($System.Security.CheckUserPermission(..#DEVUSER, "OcuPilotAdmin", "USE"), 0, "and not OcuPilotAdmin:USE")
    Do $$$AssertEquals($System.Security.CheckUserPermission(..#DEVUSER, "%All", "USE"), 0, "and not %All")
}

}
