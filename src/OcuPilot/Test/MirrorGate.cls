/// <p>Pins the Mirror monitor's gate against real principals (AD-8, AD-29, Story 21.12). Each port leg runs in a child process logged in as
/// the principal (<method>OcuPilot.Test.JournalProbe.RunAs</method>) and calls <class>OcuPilot.Port.MirrorPort</class> itself, so the
/// port's own pair set is the only gate: a principal holding exactly its two pairs, <code>%Admin_Operate:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, reads both endpoints with no refusal, and one missing either pair is refused 403 naming it. Each screen leg
/// reads <code>GET /screens/osmgmt.mirrormonitor/read</code> over the wire: the screen's own third pair, <code>%DB_IRISSYS:WRITE</code>, is
/// the one the two-pair principal lacks.</p>
/// <p><b>What it needs from the environment:</b> <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>, because it creates four
/// users and roles named <code>OcuProbe2112*</code>, each also holding READ on the install namespace's code database, as every caller must.
/// They are removed after the last test, and the class asserts none survives. Expectations are derived from <code>IsMember()</code> and
/// <code>NoMirror()</code> read live, never assumed.</p>
Class OcuPilot.Test.MirrorGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms its throwaway principals.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.MirrorProbe";

Parameter PORT = "OcuPilot.Port.MirrorPort";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the grants it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: the holder of exactly the port's two pairs; the holder of those and the screen's own write pair; one missing
/// <code>%Admin_Operate:USE</code>; and one missing <code>%DB_IRISSYS:READ</code>.</p>
Parameter PRINCIPALS = "OcuProbe2112Two:%Admin_Operate:U,%DB_IRISSYS:R;OcuProbe2112Three:%Admin_Operate:U,%DB_IRISSYS:RW;OcuProbe2112NoOperate:%DB_IRISSYS:R;OcuProbe2112NoSys:%Admin_Operate:U";

/// <p>The screen's read under the API.</p>
Parameter READPATH = "/screens/osmgmt.mirrormonitor/read?maxRows=5";

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
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MirrorGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe2112Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    If $$$ISERR(tSC) Quit tSC
    If $ClassMethod(..#PROBE, "Remaining") '= (2 * $Length(..#PRINCIPALS, ";")) Quit $$$ERROR($$$GeneralError, "the probe principals and their roles were not all created")
    Quit $$$OK
}

/// <p>Remove the principals and their roles, and assert that none survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "no probe user or role survives the class")
    Quit tSC
}

/// <p>The run of <var>pPlan</var> as <var>pUser</var>, each step answered <code>http|code failedPair</code> and joined with <code>;</code>,
/// or the run's error; <var>pRun</var> is the run itself.</p>
ClassMethod Steps(pUser As %String, pPlan As %DynamicArray, Output pRun As %DynamicObject) As %String
{
    Set pRun = $ClassMethod("OcuPilot.Test.JournalProbe", "RunAs", pUser, pPlan, 180)
    If '$IsObject(pRun) || (pRun.%Get("error") '= "") Quit "error: " _ $Select($IsObject(pRun): pRun.%Get("error"), 1: "")
    If (pRun.%Get("username") '= pUser) || 'pRun.%Get("loggedIn") Quit "not " _ pUser _ ": " _ pRun.%Get("username")
    Set tOut = ""
    Set tIterator = pRun.%Get("steps").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tCode = $Select($IsObject(tStep.%Get("fault")): tStep.%Get("fault").%Get("code"), 1: "")
        Set tPair = $Select(tCode = "AUTH.NOPRIVILEGE": " " _ tStep.%Get("fault").%Get("detail").%Get("failedPair"), 1: "")
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tStep.%Get("http") _ "|" _ tCode _ tPair
    }
    Quit tOut
}

/// <p>The plan reading both of the port's endpoints.</p>
ClassMethod BothReads() As %DynamicArray
{
    Quit [{"port": (..#PORT), "endpoint": "State", "type": "GET"}, {"port": (..#PORT), "endpoint": "Members", "type": "LIST"}]
}

/// <p><b>AC3, AD-29.</b> The holder of exactly the port's two pairs reads the state and the members with no refusal, and the state it reads is
/// the one the instance's own accessors give; the members are none on an instance that is no member.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.MirrorPort</class>'s <code>State</code> ignores <code>NoMirror()</code> -> the state assertion goes red.</p>
Method TestTheTwoPortPairsReadBothEndpointsWithNoRefusal()
{
    Set tOut = ..Steps("OcuProbe2112Two", ..BothReads(), .tRun)
    Do $$$AssertEquals(tOut, "200|;200|", "the holder of the port's two pairs reads the state and the members")
    If '$IsObject(tRun) || '$IsObject(tRun.%Get("steps")) Quit
    Set tState = tRun.%Get("steps").%Get(0).%Get("result")
    Do $$$AssertEquals($Select($IsObject(tState): tState.%Get("State"), 1: ""), ##class(OcuPilot.Test.MirrorRead).LiveState(), "its state is the instance's own")
    Set tMembers = tRun.%Get("steps").%Get(1).%Get("result")
    Do $$$AssertTrue($IsObject(tMembers), "its members answer")
    If $IsObject(tMembers) && (+$System.Mirror.IsMember() = 0) Do $$$AssertEquals(tMembers.%Size(), 0, "none on an instance that is no member")
}

/// <p><b>AC3, AD-29.</b> A principal missing <code>%Admin_Operate:USE</code>, or <code>%DB_IRISSYS:READ</code>, is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming it on each endpoint, and nothing is answered.</p>
/// <p>Mutation (Rule 19): <code>PAIRS</code> loses <code>%DB_IRISSYS:READ</code> -> the missing-read leg goes red.</p>
Method TestEachMissingPortPairIsRefusedByNameOnEveryEndpoint()
{
    For tCase = $ListBuild("OcuProbe2112NoOperate", "%Admin_Operate:USE"), $ListBuild("OcuProbe2112NoSys", "%DB_IRISSYS:READ") {
        Set tWant = "403|AUTH.NOPRIVILEGE " _ $List(tCase, 2)
        Do $$$AssertEquals(..Steps($List(tCase, 1), ..BothReads(), .tRun), tWant _ ";" _ tWant, $List(tCase, 1) _ ": each endpoint is refused naming " _ $List(tCase, 2))
        If $IsObject(tRun) && $IsObject(tRun.%Get("steps")) Do $$$AssertEquals($IsObject(tRun.%Get("steps").%Get(0).%Get("result")) + $IsObject(tRun.%Get("steps").%Get(1).%Get("result")), 0, $List(tCase, 1) _ ": and neither answers a result")
    }
}

/// <p><b>AC1, AC3.</b> Over the wire, the holder of the port's two pairs is refused the screen naming the screen's own
/// <code>%DB_IRISSYS:WRITE</code>, and the holder of all three reads it, with the banner the instance's live state selects.</p>
/// <p>Mutation (Rule 19): the descriptor's <code>ownPrivileges</code> emptied and its third <code>privileges</code> row removed -> the
/// two-pair principal reads 200 and this goes red.</p>
Method TestTheScreenNamesItsOwnWritePairToTheTwoPairHolder()
{
    Do $$$AssertEquals(..Wire(..#READPATH, "OcuProbe2112Two", .tAnswer), "403 %DB_IRISSYS:WRITE", "the two-pair holder is refused naming the write pair")
    Do $$$AssertEquals(..Wire(..#READPATH, "OcuProbe2112Three", .tAnswer), "200 ", "the three-pair holder reads")
    Do $$$AssertTrue($IsObject(tAnswer), "with a JSON answer")
    If '$IsObject(tAnswer) Quit
    Set tState = ##class(OcuPilot.Test.MirrorRead).LiveState()
    Do $$$AssertEquals(tAnswer.%Get("banner"), $Case(tState, "NotMember": "mirrorNotMemberBanner", "Unlicensed": "mirrorUnlicensedBanner", : ""), "its banner is the one the live state selects")
    If +$System.Mirror.IsMember() = 0 Do $$$AssertEquals(tAnswer.rows.%Size() _ "|" _ tAnswer.truncated, "0|0", "and an instance that is no member has no rows")
}

/// <p>A request for <var>pPath</var> under the API over the wire as <var>pUser</var>, answered as <code>status failedPair</code>: the failed
/// pair, or <code>""</code>; <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
Method Wire(pPath As %String, pUser As %String, Output pAnswer As %DynamicObject) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ pPath, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}")) } Catch {}
    Set tDetail = $Select($IsObject(pAnswer): pAnswer.%Get("detail"), 1: "")
    Quit $Get(tStatus) _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

}
