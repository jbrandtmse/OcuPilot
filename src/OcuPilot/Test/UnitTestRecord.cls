/// <p>Pins Story 24.5's run record (AD-5, AD-23, AD-36): the two reads <class>OcuPilot.Port.DevToolPort</class> serves from
/// <code>%UnitTest_Result</code> -- a namespace's runs, newest first, and one run's methods with the failed assertions' text --
/// over a tree this class builds itself in <code>USER</code> under the next instance index, and the three harvested methods
/// <class>OcuPilot.Port.Harvest.UnitTest</class> carries, held equal to the sibling's by a hash of each method's code.
/// <b>No test starts a run.</b></p>
/// <p>Needs the namespace <code>USER</code>. Every test builds its runs in it and removes them, and puts the result counter back
/// as it found it, in <method>OnAfterOneTest</method>.</p>
Class OcuPilot.Test.UnitTestRecord Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FIXTURE = "OcuPilot.Test.DevToolPortFixture";

Parameter NAMESPACE = "USER";

Parameter HARVEST = "OcuPilot.Port.Harvest.UnitTest";

/// <p>The instance indexes this test built, comma-separated, removed after it.</p>
Property BuiltRuns As %String(MAXLEN = "");

/// <p>Whether the result counter held a value before the test, and which.</p>
Property CounterHad As %Boolean;

Property CounterWas As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..BuiltRuns = ""
    Set ..CounterHad = 0
    Set ..CounterWas = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tNs = ..#NAMESPACE
    Set ..BuiltRuns = ""
    Set ..CounterHad = ($Data(^|tNs|UnitTest.Result) # 2)
    Set ..CounterWas = $Get(^|tNs|UnitTest.Result)
    Do $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tNs = ..#NAMESPACE
    For tI = 1:1:$Length(..BuiltRuns, ",") {
        If $Piece(..BuiltRuns, ",", tI) '= "" Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveRun", ..#NAMESPACE, $Piece(..BuiltRuns, ",", tI)), "run " _ $Piece(..BuiltRuns, ",", tI) _ " is removed")
    }
    If ..CounterHad {
        Set ^|tNs|UnitTest.Result = ..CounterWas
    } Else {
        ZKill ^|tNs|UnitTest.Result
    }
    Do $ClassMethod(..#FIXTURE, "Clear")
    Quit $$$OK
}

/// <p>Save one run in <var>pNamespace</var> under the next result index and answer the index: <var>pSpec</var> is
/// <code>{time, duration, cases: [{name, methods: [{name, status, duration, asserts: [[status, description]]}]}]}</code>. Only
/// system classes are named while the namespace is switched, and it is restored first in the <code>Catch</code>.</p>
ClassMethod BuildRun(pNamespace As %String, pSpec As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tIndex = 0
    Try {
        Kill tLong
        Set tSpec = ##class(%DynamicObject).%FromJSON(pSpec)
        Set $NAMESPACE = pNamespace
        Set tIndex = $Increment(^UnitTest.Result)
        Set tInstance = ##class(%UnitTest.Result.TestInstance).%New()
        Set tInstance.InstanceIndex = tIndex
        Set tInstance.DateTime = tSpec.time
        Set tInstance.Duration = tSpec.duration
        Set tSuite = ##class(%UnitTest.Result.TestSuite).%New()
        Set tSuite.Name = "(root)"
        Set tSuite.Status = 1
        Set tSuite.TestInstance = tInstance
        Set tCaseIterator = tSpec.cases.%GetIterator()
        While tCaseIterator.%GetNext(.tCaseAt, .tCaseSpec) {
            Set tCase = ##class(%UnitTest.Result.TestCase).%New()
            Set tCase.Name = tCaseSpec.name
            Set tCase.Status = 1
            Set tCase.TestSuite = tSuite
            Set tMethodIterator = tCaseSpec.methods.%GetIterator()
            While tMethodIterator.%GetNext(.tMethodAt, .tMethodSpec) {
                Set tMethod = ##class(%UnitTest.Result.TestMethod).%New()
                Set tMethod.Name = tMethodSpec.name
                Set tMethod.Status = tMethodSpec.status
                Set tMethod.Duration = tMethodSpec.duration
                Set tMethod.TestCase = tCase
                Set tAssertIterator = tMethodSpec.asserts.%GetIterator()
                While tAssertIterator.%GetNext(.tAssertAt, .tAssertSpec) {
                    Set tAssert = ##class(%UnitTest.Result.TestAssert).%New()
                    Set tAssert.Counter = tAssertAt + 1
                    Set tAssert.Status = tAssertSpec.%Get(0)
                    Set tAssert.Action = "AssertTrue"
                    Set tAssert.Description = $Extract(tAssertSpec.%Get(1), 1, 50)
                    If $Length(tAssertSpec.%Get(1)) > 50 Set tLong(tCaseSpec.name, tMethodSpec.name, tAssertAt + 1) = $ListBuild(tAssertSpec.%Get(0), tAssertSpec.%Get(1))
                    Set tAssert.TestMethod = tMethod
                }
            }
        }
        Set tSC = tInstance.%Save()
        If $$$ISERR(tSC) Set tIndex = 0
        ; A description is a 50-character property to the object layer; the manager stores longer ones in the node itself.
        Set tCaseName = ""
        For {
            Set tCaseName = $Order(tLong(tCaseName))
            If tCaseName = "" Quit
            Set tMethodName = ""
            For {
                Set tMethodName = $Order(tLong(tCaseName, tMethodName))
                If tMethodName = "" Quit
                Set tCounter = ""
                For {
                    Set tCounter = $Order(tLong(tCaseName, tMethodName, tCounter), 1, tPair)
                    If tCounter = "" Quit
                    Set ^UnitTest.Result(tIndex, "(root)", tCaseName, tMethodName, tCounter) = $ListBuild($List(tPair, 1), "AssertTrue", $List(tPair, 2), "")
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tIndex = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tIndex
}

/// <p>Build a run in the test namespace, remember its index for removal, and answer it.</p>
Method Build(pSpec As %String) As %Integer
{
    Set tIndex = ..BuildRun(..#NAMESPACE, pSpec)
    Do $$$AssertTrue(tIndex > 0, "a run is saved: " _ tIndex)
    If tIndex > 0 Set ..BuiltRuns = ..BuiltRuns _ $Select(..BuiltRuns = "": "", 1: ",") _ tIndex
    Quit tIndex
}

/// <p>The older run: three methods that straddle midnight, one passing, one failing two assertions among a passing one, one
/// skipped.</p>
ClassMethod MixedSpec() As %String
{
    Set tFails = {"name": "TestFails", "status": 0, "duration": 0.25, "asserts": [[0, "first problem"], [1, "an assertion that passed"], [0, "second problem"]]}
    Set tPasses = {"name": "TestPasses", "status": 1, "duration": 0.125, "asserts": [[1, "ok"]]}
    Set tSkipped = {"name": "TestSkipped", "status": 2, "duration": 0, "asserts": []}
    Quit {"time": "2026-11-16 23:59:58", "duration": 3, "cases": [{"name": "OcuProbe245.Mixed", "methods": [(tFails), (tPasses), (tSkipped)]}]}.%ToJSON()
}

/// <p>The newer run: one failing method whose one failed assertion describes itself in 3,000 characters.</p>
ClassMethod LongSpec() As %String
{
    Set tLong = {"name": "TestLong", "status": 0, "duration": 0.5, "asserts": [[0, ($Justify("", 3000))]]}
    Quit {"time": "2026-11-17 08:00:00", "duration": 0.5, "cases": [{"name": "OcuProbe245.Long", "methods": [(tLong)]}]}.%ToJSON()
}

/// <p>The rows <var>pEndpoint</var> answers for <var>pKey</var> (a query key) set to <var>pValue</var>, capped at
/// <var>pMax</var> when that is not <code>""</code>, in <var>pRows</var>.</p>
Method Read(pEndpoint As %String, pKey As %String, pValue As %String, pMax As %String, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    If pKey '= "" Set tQuery(pKey) = pValue
    If pMax '= "" Set tQuery("maxRows") = pMax
    Quit $ClassMethod(..#FIXTURE, "Invoke", pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>Matrix, Record, the runs: two runs this test built answer newest first, each with its method, passed and failed counts
/// (a skipped method is neither), its start, its duration, and the time it ended, which rolls over midnight.</p>
/// <p>Mutation (Rule 19): count <code>Status</code> 2 as failed in <method>OcuPilot.Port.DevToolPort.ReadRuns</method> -- the
/// counts go red.</p>
Method TestTheRunsListShowsEachRunNewestFirstWithItsCounts()
{
    Set tOlder = ..Build(..MixedSpec())
    Set tNewer = ..Build(..LongSpec())
    Do $$$AssertStatusOK(..Read("UnitTestRuns", "", "", "", .tRows, .tHttp, .tFault), "the runs read answers")
    If '$IsObject($Get(tRows)) Quit
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals(tRows.%Get(0).Run _ "|" _ tRows.%Get(1).Run, tNewer _ "|" _ tOlder, "the newer run is first")
    Do $$$AssertEquals(tRows.%Get(1).%ToJSON(), "{""Run"":" _ tOlder _ ",""Started"":""2026-11-16 23:59:58"",""Duration"":3,""Methods"":3,""Passed"":1,""Failed"":1,""Finished"":""2026-11-17 00:00:01""}", "the older run's counts, its times and the midnight rollover")
    Do $$$AssertEquals(tRows.%Get(0).Methods _ "|" _ tRows.%Get(0).Passed _ "|" _ tRows.%Get(0).Failed _ "|" _ tRows.%Get(0).Finished, "1|0|1|2026-11-17 08:00:00", "the newer run's counts")
    Do $$$AssertEquals(##class(OcuPilot.Port.DevToolPort).FinishedAt("not a time", 1), "", "a start that is no time has no end")
}

/// <p>Matrix, Record, the methods: a run's methods in class and method order, each with its result word, its time and, for
/// the failed one, its failed assertions' descriptions joined by <code>; </code> -- never the passed one's; and a run key that
/// names no run, or is no number, answers no rows.</p>
/// <p>Mutation (Rule 19): drop the <code>Status = 0</code> filter on the failure text in
/// <method>OcuPilot.Port.DevToolPort.ReadMethods</method> -- the failure text goes red.</p>
Method TestTheMethodsListCarriesEachResultAndTheFailureText()
{
    Set tRun = ..Build(..MixedSpec())
    Do $$$AssertStatusOK(..Read("UnitTestMethods", "run", tRun, "", .tRows, .tHttp, .tFault), "the methods read answers")
    If '$IsObject($Get(tRows)) Quit
    Do $$$AssertEquals(tRows.%Size(), 3, "three methods")
    Do $$$AssertEquals(tRows.%Get(0).Method _ "|" _ tRows.%Get(0).Result _ "|" _ tRows.%Get(0).Failure, "TestFails|Failed|first problem; second problem", "the failed one carries its two failed assertions and not the passed one")
    Do $$$AssertEquals(tRows.%Get(1).Method _ "|" _ tRows.%Get(1).Result _ "|" _ tRows.%Get(1).Failure _ "|" _ tRows.%Get(1).Class, "TestPasses|Passed||OcuProbe245.Mixed", "the passed one carries none")
    Do $$$AssertEquals(tRows.%Get(2).Method _ "|" _ tRows.%Get(2).Result, "TestSkipped|Skipped", "the skipped one reads Skipped")
    Do $$$AssertEquals(tRows.%Get(0).Duration, 0.25, "and its time")
    For tBad = tRun + 1000, "x", "" {
        Do $$$AssertStatusOK(..Read("UnitTestMethods", "run", tBad, "", .tNone, .tNoneHttp, .tNoneFault), "'" _ tBad _ "' answers")
        Do $$$AssertEquals($Select($IsObject($Get(tNone)): tNone.%Size(), 1: -1), 0, "'" _ tBad _ "' names no run, so no rows")
    }
}

/// <p>The caps: a row cap bounds each list and a cap that is not a whole number above zero is refused 400
/// <code>PORT.VALIDATION</code>; a failed assertion's text is cut at 2,000 characters.</p>
/// <p>Mutation (Rule 19): drop the cut on the failure text in <method>OcuPilot.Port.DevToolPort.ReadMethods</method> -- the
/// length leg goes red.</p>
Method TestTheCapsBoundBothReadsAndTheFailureTextIsCut()
{
    Set tOlder = ..Build(..MixedSpec())
    Set tNewer = ..Build(..LongSpec())
    Do $$$AssertStatusOK(..Read("UnitTestRuns", "", "", 1, .tRuns, .tHttp, .tFault), "the runs read answers with a cap of one")
    Do $$$AssertEquals($Select($IsObject($Get(tRuns)): tRuns.%Size() _ "|" _ tRuns.%Get(0).Run, 1: ""), "1|" _ tNewer, "it answers the one newest row")
    Do $$$AssertStatusOK(..Read("UnitTestMethods", "run", tOlder, 2, .tMethods, .tMethodsHttp, .tMethodsFault), "the methods read answers with a cap of two")
    Do $$$AssertEquals($Select($IsObject($Get(tMethods)): tMethods.%Size(), 1: ""), 2, "two rows")
    Do $$$AssertStatusOK(..Read("UnitTestMethods", "run", tNewer, "", .tLong, .tLongHttp, .tLongFault), "the long run's methods read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tLong)): $Length(tLong.%Get(0).Failure), 1: ""), 2000, "its failure text is cut at 2,000 characters")
    Do $$$AssertStatusNotOK(..Read("UnitTestRuns", "", "", "0", .tBad, .tBadHttp, .tBadFault), "a cap of zero is refused")
    Do $$$AssertEquals(tBadHttp _ "|" _ tBadFault.code, "400|PORT.VALIDATION", "as a validation fault")
}

/// <p>The counts the run body falls back to when the privilege-checked parse is refused: a run's passed and failed methods, a
/// skipped one neither, and only the named method when a filter is given. The run is built in the namespace this test runs in,
/// because the body is an OcuPilot class and <code>USER</code> holds none; it is removed, and the result counter put back,
/// before the test ends.</p>
/// <p>Mutation (Rule 19): swap the two statuses in <method>OcuPilot.Port.Harvest.UnitTestRun.CountResults</method> -- this
/// goes red.</p>
Method TestTheRunBodysFallbackCountsAreRightForARunAndForOneMethod()
{
    Set tHere = $NAMESPACE
    Set tHad = ($Data(^UnitTest.Result) # 2)
    Set tWas = $Get(^UnitTest.Result)
    Set tRun = ..BuildRun(tHere, ..MixedSpec())
    Do $$$AssertTrue(tRun > 0, "a run is saved: " _ tRun)
    If tRun > 0 {
        Do ##class(OcuPilot.Port.Harvest.UnitTestRun).CountResults(tRun, "", .tAllPassed, .tAllFailed)
        Do ##class(OcuPilot.Port.Harvest.UnitTestRun).CountResults(tRun, "TestFails", .tFailsPassed, .tFailsFailed)
        Do ##class(OcuPilot.Port.Harvest.UnitTestRun).CountResults(tRun, "TestPasses", .tPassesPassed, .tPassesFailed)
        Do ##class(OcuPilot.Port.Harvest.UnitTestRun).CountResults(tRun, "TestSkipped", .tNonePassed, .tNoneFailed)
        Do $$$AssertEquals($Get(tAllPassed) _ "|" _ $Get(tAllFailed), "1|1", "the run counts one passed and one failed, the skipped method neither")
        Do $$$AssertEquals($Get(tFailsPassed) _ "|" _ $Get(tFailsFailed), "0|1", "the failing method alone counts one failed")
        Do $$$AssertEquals($Get(tPassesPassed) _ "|" _ $Get(tPassesFailed), "1|0", "the passing method alone counts one passed")
        Do $$$AssertEquals($Get(tNonePassed) _ "|" _ $Get(tNoneFailed), "0|0", "the skipped method alone counts neither")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveRun", tHere, tRun), "the run is removed")
    }
    If tHad {
        Set ^UnitTest.Result = tWas
    } Else {
        ZKill ^UnitTest.Result
    }
}

/// <p>The run and the record reads take the endpoint's own request types only: a record read asked as <code>RUN</code> and the
/// run asked as <code>LIST</code> are 501.</p>
Method TestAnEndpointAnswersItsOwnRequestTypesOnly()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "UnitTestRuns", "RUN", .tQuery, "", .tResult, .tHttp, .tFault), "a record read asked as a run is refused")
    Do $$$AssertEquals(tHttp, 501, "501")
    Do $$$AssertStatusNotOK($ClassMethod(..#FIXTURE, "Invoke", "UnitTestRun", "LIST", .tQuery, "", .tResult2, .tHttp2, .tFault2), "the run asked as a list is refused")
    Do $$$AssertEquals(tHttp2, 501, "501")
}

/// <p>AC7: the three methods <class>OcuPilot.Port.Harvest.UnitTest</class> carries are the sibling's at <code>c6aad31</code>,
/// as the hash of each method's code. The doc comments are not part of the code, so the one comment the rename table changed
/// is not read.</p>
/// <p>Mutation (Rule 19): change one line of <code>ParseTestResults</code> -- this goes red naming it.</p>
Method TestTheHarvestedMethodsAreTheSiblingsUnchanged()
{
    Set tWant = $ListBuild($ListBuild("BuildTestSpec", "96F99A42A8CEF47ABE765D87076A5D9091C4E1D0D54C007C293957A784690932"), $ListBuild("ParseTestResults", "C16E4247DA2A9481CB257C82789740B70A7EF9934E19509674B8B23944049A9D"), $ListBuild("GetFailureMessage", "C7FE473D32C2C30E3A5A1289F31E4138627489D83050284E6C0B938BA6BE54A4"))
    For tI = 1:1:$ListLength(tWant) {
        Set tName = $List($List(tWant, tI), 1)
        Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(..#HARVEST _ "||" _ tName)
        Do $$$AssertTrue($IsObject(tMethod), tName _ " is defined in the harvested class")
        If '$IsObject(tMethod) Continue
        Set tCode = tMethod.Implementation.Read(3000000)
        Do $$$AssertEquals($System.Encryption.ToHex($System.Encryption.SHAHash(256, $ZConvert(tCode, "O", "UTF8"))), $List($List(tWant, tI), 2), tName _ " is the sibling's, line for line")
    }
}

}
