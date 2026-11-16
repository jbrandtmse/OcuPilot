/// <p>Pins Story 24.5's unit-test Run behind a person's screen action (AD-10, AD-22, AD-23, AD-53): the governance key
/// <code>explorer.unittests.run</code> shipped off, the port's checks in their fixed order, the root global and the run lock put
/// back on every path, and the one body call the port makes. <b>No test starts a <code>%UnitTest</code> run</b>:
/// <class>OcuPilot.Test.UnitTestActionFixture</class> sends the route's own action to
/// <class>OcuPilot.Test.DevToolPortFixture</class>, whose harvest port is <class>OcuPilot.Test.DevToolHarvestRecorder</class>,
/// which records a body call and answers a canned result or none.</p>
/// <p>Needs the namespace <code>USER</code> and a process holding the screen's pairs. Each test saves the probe test classes
/// <code>OcuProbe245</code> and <code>OcuProbe245P</code> in <code>USER</code>, the stored governance policy and
/// <code>USER</code>'s root global before it, and puts all three back after it; the lock it holds is the fixture's own name.</p>
Class OcuPilot.Test.UnitTestRunGate Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter RECORDER = "OcuPilot.Test.DevToolHarvestRecorder";

Parameter ACTION = "OcuPilot.Test.UnitTestActionFixture";

Parameter GOVERNANCE = "OcuPilot.Test.GovernanceFixture";

Parameter SCREEN = "explorer.unittests";

Parameter KEY = "explorer.unittests.run";

Parameter NAMESPACE = "USER";

Parameter LOCKNAME = "^CacheTemp.OcuPilotUnitTestProbe245";

Parameter MIXED = "OcuProbe245.Mixed";

/// <p>The governance policy found before each test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

/// <p>Whether <code>USER</code>'s root global held a value before the test, and which.</p>
Property RootHad As %Boolean;

Property RootWas As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..RootHad = 0
    Set ..RootWas = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = $ClassMethod(..#GOVERNANCE, "Snapshot", .tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Kill tNone
    Do $ClassMethod(..#GOVERNANCE, "Restore", .tNone)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do $ClassMethod(..#FIXTURE, "SetLockName", ..#LOCKNAME)
    Set tNs = ..#NAMESPACE
    Set ..RootHad = ($Data(^|tNs|UnitTestRoot) # 2)
    Set ..RootWas = $Get(^|tNs|UnitTestRoot)
    Kill ^|tNs|UnitTestRoot
    Quit $ClassMethod(..#PROBE, "MakeTests", ..#NAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do ..ReleaseHolder()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK($ClassMethod(..#GOVERNANCE, "Restore", .tRows), "the governance policy found before the test is put back")
    Set tNs = ..#NAMESPACE
    If ..RootHad {
        Set ^|tNs|UnitTestRoot = ..RootWas
    } Else {
        Kill ^|tNs|UnitTestRoot
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTests", ..#NAMESPACE), "the probe test classes are removed")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Store the key on, the one setting that lets the route past its governance ask.</p>
ClassMethod EnableKey()
{
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Do $ClassMethod(..#GOVERNANCE, "Apply", "", .tSettings)
}

/// <p>Send a person's Run of <var>pTests</var> at <var>pLevel</var> through the route: the status and the parsed envelope.</p>
Method Act(pTests As %String, pLevel As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set tValues = {}
    Do tValues.%Set("tests", pTests, "string")
    Do tValues.%Set("level", pLevel, "string")
    Set tBody = {"action": "run", "id": "unittests"}
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tRaw, .pStatus)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>The code of the envelope <var>pAnswer</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pAnswer) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The root global as <code>USER</code> holds it now: <code>&lt;has a value&gt;|&lt;value&gt;</code>.</p>
ClassMethod RootNow() As %String
{
    Quit ($Data(^|"USER"|UnitTestRoot) # 2) _ "|" _ $Get(^|"USER"|UnitTestRoot)
}

/// <p>Whether the run lock is free: this process takes it at once, and lets go.</p>
ClassMethod LockFree() As %Boolean
{
    Set tName = ..#LOCKNAME
    Lock +@tName:0
    Set tFree = $Test
    If tFree Lock -@tName
    Quit tFree
}

/// <p>A job that holds the run lock until <method>ReleaseHolder</method> or <var>pSeconds</var> pass.</p>
ClassMethod HoldLock(pSeconds As %Integer)
{
    Set tName = ..#LOCKNAME
    Lock +@tName:5
    If '$Test Quit
    Set tUntil = $ZHorolog + pSeconds
    While ($ZHorolog < tUntil) && '$Data(^CacheTemp.OcuPilotUnitTestProbe245Stop) {
        Hang 0.1
    }
    Lock -@tName
}

/// <p>Start a holder and wait until it holds the lock.</p>
Method StartHolder() As %Boolean
{
    Kill ^CacheTemp.OcuPilotUnitTestProbe245Stop
    Job ##class(OcuPilot.Test.UnitTestRunGate).HoldLock(20)::5
    If '$Test Quit 0
    For tI = 1:1:50 {
        If '..LockFree() Quit
        Hang 0.1
    }
    Quit '..LockFree()
}

/// <p>Tell the holder to let go and wait until the lock is free.</p>
Method ReleaseHolder()
{
    Set ^CacheTemp.OcuPilotUnitTestProbe245Stop = 1
    For tI = 1:1:50 {
        If ..LockFree() Quit
        Hang 0.1
    }
    Kill ^CacheTemp.OcuPilotUnitTestProbe245Stop
}

/// <p>Matrix, Switched off: with the key at its shipped <code>false</code> a Run, of a class that exists, is 403
/// <code>EXPLORER.UNITTEST.OFF</code> with its published sentence, before the hold and the fresh read: the port is never asked,
/// no body is recorded, and the root and the lock are as they were. The key stored on lets the same Run through.</p>
/// <p>Mutation (Rule 19): remove the <code>PERSONGATE</code> ask from <method>OcuPilot.Api.ScreenAction.Run</method> -- the
/// recorder records a call and this goes red.</p>
Method TestSwitchedOffRefusesBeforeTheHoldTheReadAndTheRun()
{
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"run": 7, "passed": 1, "failed": 1}.%ToJSON())
    Do $$$AssertStatusOK(..Act(..#MIXED, "class", .tStatus, .tAnswer), "the route answers")
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "403|EXPLORER.UNITTEST.OFF", "the Run is refused as switched off")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.reason, ##class(OcuPilot.Api.AtelierError).#REASONUNITTESTOFF, "with the published sentence")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ $ClassMethod(..#FIXTURE, "Invokes"), "0|0", "no read and no body call reached the port")
    Do $$$AssertEquals(..RootNow() _ "|" _ ..LockFree(), "0||1", "the root global and the lock are as they were")
    Do ..EnableKey()
    Do $$$AssertStatusOK(..Act(..#MIXED, "class", .tOnStatus, .tOnAnswer), "the route answers with the key on")
    Do $$$AssertEquals(tOnStatus, 200, "and the same Run goes through")
}

/// <p>Matrix, Run class, and AC4's second half: with the key on, one Run is one body call to
/// <code>UnitTestRun.Run</code> carrying the port's three keys alone, in the namespace the screen is scoped to, under the
/// pairs of the gate and the namespace including WRITE; the root global holds the manager directory while it runs and none
/// after; the answer is <code>{run, passed, failed}</code> as the body gave it; and a method-level Run sends the method.</p>
/// <p>Mutation (Rule 19): skip the root restore in <method>OcuPilot.Port.DevToolPort.RootEnd</method> -- the root assertion goes
/// red here and in the browser spec.</p>
Method TestARunWithTheKeyOnIsOneBodyCallWithThePortsKeysOnly()
{
    Do ..EnableKey()
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"run": 7, "passed": 1, "failed": 1}.%ToJSON())
    Do $$$AssertStatusOK(..Act(..#MIXED, "class", .tStatus, .tAnswer), "the route answers")
    Do $$$AssertEquals(tStatus, 200, "the Run is applied")
    If $IsObject(tAnswer) Do $$$AssertEquals(tAnswer.output.%ToJSON(), "{""run"":7,""passed"":1,""failed"":1}", "and answers the three numbers the body gave")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls"), 1, "one body call")
    Set tCall = $ClassMethod(..#RECORDER, "CallAt", 1)
    Do $$$AssertEquals(tCall.handler _ "." _ tCall.method, "OcuPilot.Port.Harvest.UnitTestRun.Run", "it is the run body")
    Do $$$AssertEquals(tCall.query.%ToJSON(), "{""level"":""class"",""namespace"":""USER"",""target"":""OcuProbe245.Mixed""}", "carrying the port's three keys alone")
    Do $$$AssertTrue(tCall.pairs [ "%Development:USE", "under the screen's pair")
    Do $$$AssertTrue(tCall.pairs [ "WRITE", "and WRITE on the routines database")
    Do $$$AssertEquals(tCall.root, $System.Util.ManagerDirectory(), "the root global named the manager directory while the body ran")
    Do $$$AssertEquals(..RootNow() _ "|" _ ..LockFree(), "0||1", "and none afterwards, the lock free")
    Do $ClassMethod(..#RECORDER, "Clear")
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"run": 8, "passed": 1, "failed": 0}.%ToJSON())
    Do $$$AssertStatusOK(..Act(..#MIXED _ ":TestPasses", "method", .tMethodStatus, .tMethodAnswer), "a method-level Run answers")
    Set tMethodCall = $ClassMethod(..#RECORDER, "CallAt", 1)
    Do $$$AssertEquals(tMethodStatus _ "|" _ tMethodCall.query.target _ "|" _ tMethodCall.query.level, "200|OcuProbe245.Mixed:TestPasses|method", "and sends the method")
}

/// <p>The matrix's refusals through the route, each with the key on: its status and code, no body call, and the root and the
/// lock as they were. The package cap is lowered to 0 for the last two, so the one probe class is over it.</p>
/// <p>Mutation (Rule 19): move the production check after the body call in <method>OcuPilot.Port.DevToolPort.UnitTest</method>
/// -- the production rows go red.</p>
Method TestEveryRefusalRowAnswersItsStatusAndCodeAndRecordsNoCall()
{
    Do ..EnableKey()
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"run": 7, "passed": 1, "failed": 1}.%ToJSON())
    For tRow = "OcuProbe245P.Prod|class|409|EXPLORER.UNITTEST.PRODUCTION", "OcuProbe245P|package|409|EXPLORER.UNITTEST.PRODUCTION", "OcuProbe245.Nope|class|404|EXPLORER.UNITTEST.NOTFOUND", "OcuProbe245.Plain|class|404|EXPLORER.UNITTEST.NOTFOUND", "OcuProbe245.Mixed:TestNope|method|404|EXPLORER.UNITTEST.NOTFOUND", "OcuProbe245Nothing|package|404|EXPLORER.UNITTEST.NOTFOUND", "%Library|class|400|PORT.VALIDATION", "a..b|class|400|PORT.VALIDATION", "A:B:C|method|400|PORT.VALIDATION", "*|class|400|PORT.VALIDATION", "OcuProbe245.Mixed|weird|400|PORT.VALIDATION", "OcuProbe245.Mixed|method|400|PORT.VALIDATION", "OcuPilot.Test.Prohibited|class|400|EXPLORER.UNITTEST.OWNCODE", "OCUPILOT|package|400|EXPLORER.UNITTEST.OWNCODE" {
        Set tTests = $Piece(tRow, "|", 1)
        Set tLevel = $Piece(tRow, "|", 2)
        Do $$$AssertStatusOK(..Act(tTests, tLevel, .tStatus, .tAnswer), tTests _ ": the route answers")
        Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), $Piece(tRow, "|", 3) _ "|" _ $Piece(tRow, "|", 4), tTests _ " (" _ tLevel _ "): its status and code")
        Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ ..RootNow() _ "|" _ ..LockFree(), "0|0||1", tTests _ ": no body call, and the root and the lock as they were")
    }
    Do $ClassMethod(..#FIXTURE, "SetMaxTestClasses", 0)
    Do $$$AssertStatusOK(..Act("OcuProbe245", "package", .tCapStatus, .tCapAnswer), "a package over the cap is asked")
    Do $$$AssertEquals(tCapStatus _ "|" _ ..CodeOf(tCapAnswer) _ "|" _ $Select($IsObject(tCapAnswer): tCapAnswer.detail.count _ "|" _ tCapAnswer.detail.max, 1: ""), "400|EXPLORER.UNITTEST.TOOMANY|1|0", "it is too many, its detail naming the count and the cap")
    Do $$$AssertStatusOK(..Act("OcuProbe245P", "package", .tFirstStatus, .tFirstAnswer), "a production package over the cap is asked")
    Do $$$AssertEquals(tFirstStatus _ "|" _ ..CodeOf(tFirstAnswer), "400|EXPLORER.UNITTEST.TOOMANY", "the cap is checked before the production test")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ ..RootNow() _ "|" _ ..LockFree() _ "|" _ $ClassMethod(..#FIXTURE, "LogCount"), "0|0||1|0", "no body call, the root and the lock as they were, and none of the refusals logged")
}

/// <p>Matrix, Busy: a run lock another process holds is 409 <code>EXPLORER.UNITTEST.BUSY</code>, unlogged, with no body call
/// and the holder's lock still held; once it is let go the same Run goes through.</p>
Method TestARunWhileAnotherHoldsTheLockIsBusyAndRecordsNoCall()
{
    Do ..EnableKey()
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"run": 7, "passed": 1, "failed": 1}.%ToJSON())
    Do $$$AssertTrue(..StartHolder(), "a second process holds the lock")
    Do $$$AssertStatusOK(..Act(..#MIXED, "class", .tStatus, .tAnswer), "the route answers")
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "409|EXPLORER.UNITTEST.BUSY", "the Run is busy")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ $ClassMethod(..#FIXTURE, "LogCount") _ "|" _ ..LockFree(), "0|0|0", "no body call, nothing logged, and the holder still holds it")
    Do ..ReleaseHolder()
    Do $$$AssertStatusOK(..Act(..#MIXED, "class", .tAgainStatus, .tAgainAnswer), "the route answers again")
    Do $$$AssertEquals(tAgainStatus _ "|" _ ..LockFree(), "200|1", "and the Run goes through, the lock free after it")
}

/// <p>Matrix, Gate: a caller without <code>%Development:USE</code>, or with it but without WRITE on the routines database, is
/// 403 <code>AUTH.NOPRIVILEGE</code> naming the failed pair, before any body, with the root and the lock as they were.</p>
/// <p>Mutation (Rule 19): ask <method>OcuPilot.Port.AtelierPort.NamespacePairs</method> instead of <code>WritePairs</code> for
/// the run -- the WRITE leg goes red.</p>
Method TestACallerShortOfAPairIsRefusedByName()
{
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("tests") = ..#MIXED
    Set tQuery("level") = "class"
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "UnitTestRun", "RUN", .tQuery, "", .tResult, .tHttp, .tFault), "a caller holding nothing is refused")
    Do $$$AssertEquals(tHttp _ "|" _ tFault.code _ "|" _ tFault.detail.failedPair, "403|AUTH.NOPRIVILEGE|%Development:USE", "naming %Development:USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(..#NAMESPACE)
    For tI = 1:1:$ListLength(tPairs) Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tPairs, tI), 1), $List($List(tPairs, tI), 2))
    Set tWritePairs = ##class(OcuPilot.Port.AtelierPort).WritePairs(..#NAMESPACE)
    Set tWritePair = $List(tWritePairs, $ListLength(tWritePairs))
    Set tWriteName = $List(tWritePair, 1) _ ":" _ $List(tWritePair, 2)
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "UnitTestRun", "RUN", .tQuery, "", .tResult2, .tHttp2, .tFault2), "a caller short of WRITE is refused")
    Do $$$AssertEquals(tHttp2 _ "|" _ tFault2.code _ "|" _ tFault2.detail.failedPair, "403|AUTH.NOPRIVILEGE|" _ tWriteName, "naming WRITE on the routines database")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ ..RootNow() _ "|" _ ..LockFree(), "0|0||1", "no body call, and the root and the lock as they were")
}

/// <p>Matrix, No result: a body that recorded no run is 500 <code>EXPLORER.UNITTEST.NORESULT</code>, logged once; a body that
/// raises is 500 <code>INTERNAL</code>, logged. Both put the root global and the lock back.</p>
Method TestARunThatRecordsNothingOrRaisesPutsTheRootAndTheLockBack()
{
    Do ..EnableKey()
    Do $ClassMethod(..#RECORDER, "SetDry")
    Do $$$AssertStatusOK(..Act(..#MIXED, "class", .tStatus, .tAnswer), "the route answers")
    Do $$$AssertEquals(tStatus _ "|" _ ..CodeOf(tAnswer), "500|EXPLORER.UNITTEST.NORESULT", "a run with no result is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Calls") _ "|" _ $ClassMethod(..#FIXTURE, "LogCount") _ "|" _ ..RootNow() _ "|" _ ..LockFree(), "1|1|0||1", "the body was asked once, it is logged once, and the root and the lock are back")
    Do $ClassMethod(..#RECORDER, "Clear")
    Do $ClassMethod(..#RECORDER, "SetAnswer", "not json")
    Do $$$AssertStatusOK(..Act(..#MIXED, "class", .tRaiseStatus, .tRaiseAnswer), "the route answers a raising body")
    Do $$$AssertEquals(tRaiseStatus _ "|" _ ..CodeOf(tRaiseAnswer) _ "|" _ ..RootNow() _ "|" _ ..LockFree(), "500|INTERNAL|0||1", "an exception is internal, with the root and the lock back")
}

/// <p>The root global is set for the run when it is absent or names a directory that does not exist, and put back as it was:
/// its old value, or killed when it had none. A root that names an existing directory is left alone.</p>
Method TestTheRootGlobalIsSetOnlyWhenNeededAndPutBackAsItWas()
{
    Do $ClassMethod(..#RECORDER, "SetAnswer", {"run": 7, "passed": 1, "failed": 1}.%ToJSON())
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("tests") = ..#MIXED
    Set tQuery("level") = "class"
    Set tManager = $System.Util.ManagerDirectory()
    Set tNs = ..#NAMESPACE
    Set tInstall = $System.Util.InstallDirectory()
    Do $$$AssertNotEquals(tInstall, tManager, "the install directory is an existing directory other than the manager's")
    For tRow = "||" _ tManager, "/ocuprobe245/missing/|/ocuprobe245/missing/|" _ tManager, tInstall _ "|" _ tInstall _ "|" _ tInstall {
        Kill ^|tNs|UnitTestRoot
        If $Piece(tRow, "|", 2) '= "" Set ^|tNs|UnitTestRoot = $Piece(tRow, "|", 2)
        Do $ClassMethod(..#RECORDER, "Clear")
        Do $ClassMethod(..#RECORDER, "SetAnswer", {"run": 7, "passed": 1, "failed": 1}.%ToJSON())
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Invoke", "UnitTestRun", "RUN", .tQuery, "", .tResult, .tHttp, .tFault), "the run answers")
        Set tCall = $ClassMethod(..#RECORDER, "CallAt", 1)
        Do $$$AssertEquals(tCall.root, $Piece(tRow, "|", 3), "the root while it ran, from '" _ $Piece(tRow, "|", 2) _ "'")
        Do $$$AssertEquals(..RootNow(), $Select($Piece(tRow, "|", 2) = "": "0|", 1: "1|" _ $Piece(tRow, "|", 2)), "and the root after, as it was")
    }
}

}
