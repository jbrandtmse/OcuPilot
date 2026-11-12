/// <p>Pins Story 20.34's cube manager at the port (AD-7, AD-16, AD-29, AD-51, AD-65) against the analytics probe in <code>USER</code>: the
/// <code>CubeManager</code> list answers the vendor's own facts, last build and update, and which cubes depend on which; <code>STATE</code>
/// reads one cube by its exact logical name over the cube and its dependents; a build or synchronize the state does not fit is refused by
/// its own code before any vendor call -- a source that records no changes, a cube never built, a cube being built or synchronized now
/// (held by this process's lock, with the action made over HTTP by another), a read-only facts database and a namespace without analytics --
/// and each refusal leaves the vendor's build events and the cube's facts as they were; and the vendor's answers are mapped as
/// <class>OcuPilot.Test.AnalyticsCubeSeam</class> arms them.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns
/// analytics on in <code>USER</code> and builds, kills and rebuilds cubes there through <class>OcuPilot.Test.AnalyticsProbe</class>, which
/// removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsCubeManager Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter SEAM = "OcuPilot.Test.AnalyticsCubeSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter ACTION = "/screens/analytics.cubemanager/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsCubeManager turns analytics on in USER and builds and kills cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", ##class(OcuPilot.Test.Http).GetTestUsername())
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe; a failing status when any of it survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsCubeManager left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

/// <p>Release the locks a test took, forget the seam and rebuild the cubes a test killed.</p>
Method OnAfterOneTest() As %Status
{
    Do ..Release()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertStatusOK(..Rebuild(), "the probe cubes are built as they were created")
    Quit $$$OK
}

/// <p>Hold the vendor's lock on the cube <var>pCube</var> in <code>USER</code>, at the node <var>pNode</var> (<code>""</code> for the
/// build lock itself, <code>"SYNC"</code> for the synchronize node), in this process.</p>
ClassMethod Hold(pCube As %String, pNode As %String)
{
    Set tIndex = $ZConvert(pCube, "U")
    If pNode = "" {
        Lock +^|"USER"|DeepSee.Build(tIndex)
    } Else {
        Lock +^|"USER"|DeepSee.Build(tIndex, pNode)
    }
}

/// <p>Release every lock this process holds on the probe cubes.</p>
ClassMethod Release()
{
    Set tIndex = $ZConvert("OcuPilotProbeVisits", "U")
    Lock -^|"USER"|DeepSee.Build(tIndex)
    Lock -^|"USER"|DeepSee.Build(tIndex, "SYNC")
}

/// <p>Rebuild the Categories cube, and with it the Visits cube, when either reads no facts: a test that killed or emptied one leaves it so.</p>
ClassMethod Rebuild() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If (+##class(%DeepSee.Utils).%GetCubeFactCount("OcuPilotProbeVisits") '= 1000) || (+##class(%DeepSee.Utils).%GetCubeFactCount("OcuPilotProbeCategories") '= 5) {
            Set tSC = ##class(%DeepSee.Utils).%BuildCube("OcuPilotProbeCategories", 0, 0)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The number of build events the vendor recorded for the probe cubes, read in <code>USER</code>.</p>
ClassMethod Events() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %DeepSee_CubeManager.CubeEvent WHERE CubeKey %STARTSWITH ?", "OCUPILOTPROBE")
        If tRS.%Next() Set tCount = +tRS.%GetData(1)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The facts the vendor counts in the cube <var>pCube</var> in <code>USER</code>.</p>
ClassMethod Facts(pCube As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tFacts = ##class(%DeepSee.Utils).%GetCubeFactCount(pCube)
    Set $NAMESPACE = tOrigNS
    Quit tFacts
}

/// <p>The port's answer for <var>pEndpoint</var> and <var>pType</var> on the cube <var>pName</var> in <var>pNamespace</var>, through
/// <var>pPort</var>: <code>&lt;http&gt; &lt;code&gt;</code>, the result in <var>pResult</var> and the fault in <var>pFault</var>.</p>
ClassMethod Ask(pType As %String, pName As %String, Output pResult, Output pFault, pNamespace As %String = {..#NAMESPACE}, pPort As %String = {..#PORT}, pAction As %String = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    If pName '= "" Set tQuery("id") = pName
    If pAction '= "" Set tQuery("action") = pAction
    Set pResult = ""
    Set pFault = ""
    Set tSC = $ClassMethod(pPort, "Invoke", "CubeManager", pType, .tQuery, "", .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>The person's row action <var>pAction</var> on the cube <var>pName</var> over the wire as the test account (another process than
/// this one): <code>&lt;status&gt; &lt;code&gt;</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pName As %String, Output pAnswer) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pName, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#ACTION, tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The row of <var>pCube</var> in the list's answer <var>pRows</var>, or <code>""</code>.</p>
ClassMethod RowOf(pRows, pCube As %String) As %DynamicObject
{
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pCube Quit
    }
    Quit $Select($IsObject($Get(tRow)) && (tRow.%Get("Name") = pCube): tRow, 1: "")
}

/// <p>AC: the list answers one row per probe cube, each field the vendor's own answer: the facts of <code>%GetCubeFactCount</code>, the
/// last build and update of <code>GetLastUpdate</code> in local time to the second, <code>Synchronizes</code> true for Visits (its source
/// declares <code>DSTIME</code>) and false for Categories, <code>Updating</code> false, and Categories' dependents naming Visits. The
/// screen's read over HTTP answers the same rows.</p>
/// <p>Mutation (Rule 19): drop <code>%GetDependentCubes</code> from <method>OcuPilot.Port.AnalyticsPort.CubeNodeHere</method> -- the dependents
/// leg goes red; answer <code>Synchronizes</code> true for every cube -- the Categories leg goes red.</p>
Method TestTheListRowsEqualTheVendorsOwnAnswers()
{
    Set tAsk = ..Ask("LIST", "", .tRows, .tFault)
    Do $$$AssertEquals(tAsk, "200 ", "the list answers")
    Set tVisits = ..RowOf(tRows, "OcuPilotProbeVisits")
    Set tCategories = ..RowOf(tRows, "OcuPilotProbeCategories")
    Do $$$AssertTrue($IsObject(tVisits) && $IsObject(tCategories), "it holds a row for the Visits and the Categories cubes: " _ $Select($IsObject(tRows): tRows.%ToJSON(), 1: ""))
    If '$IsObject(tVisits) || '$IsObject(tCategories) Quit
    Do $$$AssertEquals(tVisits.Synchronizes _ "|" _ tCategories.Synchronizes, "1|0", "Visits synchronizes (its source declares DSTIME) and Categories does not")
    Do $$$AssertEquals(tVisits.Updating _ "|" _ tCategories.Updating, "0|0", "and neither is updating now")
    Do $$$AssertEquals(tCategories.DependentCubes _ "|" _ tVisits.DependentCubes, "OcuPilotProbeVisits|", "Categories' dependent cube is Visits, and Visits has none")
    Do $$$AssertEquals(tVisits.Facts _ "|" _ tCategories.Facts, ..Facts("OcuPilotProbeVisits") _ "|" _ ..Facts("OcuPilotProbeCategories"), "each Facts equals the vendor's own count")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tBuild = ##class(%DeepSee.CubeManager.Utils).GetLastUpdate("OcuPilotProbeVisits", "build")
    Set tUpdate = ##class(%DeepSee.CubeManager.Utils).GetLastUpdate("OcuPilotProbeVisits", "synch")
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tVisits.LastBuild _ "|" _ tVisits.LastUpdate, $Extract(tBuild, 1, 19) _ "|" _ $Extract(tUpdate, 1, 19), "and its last build and update are the vendor's, to the second")
    Do $$$AssertTrue(tVisits.LastBuild '= "", "a built cube has a last build")
    Set tStatus = $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.cubemanager/read", "", .tHttp, .tAnswer)
    Do $$$AssertEquals(tHttp, 200, "the screen's read answers over HTTP: " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 200), 1: tAnswer))
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")) {
        Set tScreenRow = ..RowOf(tAnswer.rows, "OcuPilotProbeVisits")
        Do $$$AssertTrue($IsObject(tScreenRow), "and holds a Visits row")
        If $IsObject(tScreenRow) Do $$$AssertEquals(tScreenRow.Facts _ "|" _ tScreenRow.LastBuild _ "|" _ tScreenRow.Synchronizes _ "|" _ tScreenRow.DependentCubes, tVisits.Facts _ "|" _ tVisits.LastBuild _ "|" _ tVisits.Synchronizes _ "|" _ tVisits.DependentCubes, "which is the port's row")
    }
}

/// <p>The state of one cube is read by its exact logical name over the cube and its dependents: Categories reads built, not synchronizing
/// (its own source records no changes) and naming Visits; Visits reads synchronizing; <code>BuildStamp</code> is the last build to the
/// millisecond where <code>LastBuild</code> shows the second; a spelling other than the vendor's logical name, an unknown cube and a
/// subject-less name read as absent (404) or as a request without a cube (400).</p>
/// <p>Mutation (Rule 19): compare the name case-insensitively in <method>OcuPilot.Port.AnalyticsPort.CubeShownHere</method> -- the
/// spelling leg goes red.</p>
Method TestTheStateReadsOneCubeByItsExactNameOverItsDependents()
{
    Set tAsk = ..Ask("STATE", "OcuPilotProbeCategories", .tRow, .tFault)
    Do $$$AssertEquals(tAsk, "200 ", "the state of Categories is read")
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.Built _ "|" _ tRow.Synchronizes _ "|" _ tRow.Updating _ "|" _ tRow.DependentCubes _ "|" _ tRow.Namespace, "1|0|0|OcuPilotProbeVisits|USER", "built, not synchronizing, not updating, with Visits as its dependent")
        Do $$$AssertTrue(($Length(tRow.BuildStamp) > 19) && ($Extract(tRow.BuildStamp, 1, 19) = tRow.LastBuild), "BuildStamp is the last build to the millisecond: " _ tRow.BuildStamp _ " against " _ tRow.LastBuild)
    }
    Set tAsk = ..Ask("STATE", "OcuPilotProbeVisits", .tVisits, .tFault)
    Do $$$AssertTrue($IsObject(tVisits) && tVisits.Synchronizes && tVisits.Built, "Visits reads built and synchronizing")
    Do $$$AssertEquals(..Ask("STATE", "ocupilotprobevisits", .tNone, .tFault), "404 PORT.NOTFOUND", "a spelling other than the logical name reads as absent")
    Do $$$AssertEquals(..Ask("STATE", "NoSuchCube", .tNone, .tFault), "404 PORT.NOTFOUND", "so does an unknown cube")
    Do $$$AssertEquals($Extract(..Ask("STATE", "", .tNone, .tFault), 1, 3), "400", "and a request that names no cube is refused")
    Do $$$AssertEquals(..Ask("STATE", "OcuPilotProbeVisits", .tNone, .tFault, , , "ABORT"), "501 PORT.NOTIMPLEMENTED", "an action the port does not carry is not implemented")
}

/// <p>A synchronize of Categories, whose source records no changes (no <code>DSTIME</code>), is refused 409
/// <code>ANALYTICS.CUBE.NODSTIME</code> by the port, at the state read and at the write, before any vendor call: no build event is
/// recorded and no fact moves. A build of it is not refused for that.</p>
/// <p>Mutation (Rule 19): skip the <code>Synchronizes</code> test in <method>OcuPilot.Port.AnalyticsPort.StateRefusal</method> -- the
/// vendor is called, answers #20008, and this goes red on the refusal code and the new build event.</p>
Method TestASynchronizeOfACubeWithoutDstimeIsRefusedBeforeAnyVendorCall()
{
    Set tEvents = ..Events()
    Set tFacts = ..Facts("OcuPilotProbeCategories")
    Do $$$AssertEquals(..Ask("STATE", "OcuPilotProbeCategories", .tNone, .tFault, , , "SYNCHRONIZE"), "409 ANALYTICS.CUBE.NODSTIME", "the read composed for a synchronize is refused")
    Do $$$AssertEquals(..Ask("SYNCHRONIZE", "OcuPilotProbeCategories", .tNone, .tFault), "409 ANALYTICS.CUBE.NODSTIME", "and so is the write")
    Do $$$AssertEquals(..Events() _ "|" _ ..Facts("OcuPilotProbeCategories"), tEvents _ "|" _ tFacts, "no build event is recorded and no fact moves")
    Do $$$AssertEquals(..Ask("STATE", "OcuPilotProbeCategories", .tRow, .tFault, , , "BUILD"), "200 ", "a build of the same cube is not refused")
}

/// <p>A synchronize of Visits after the vendor killed its facts is refused 409 <code>ANALYTICS.CUBE.NOTBUILT</code> and leaves it empty:
/// the vendor would turn it into a full build under the synchronize key. A build is not refused, and rebuilds it (Categories' own build
/// rebuilds Visits too, and this leg builds Visits alone).</p>
/// <p>Mutation (Rule 19): skip the <code>Built</code> test in <method>OcuPilot.Port.AnalyticsPort.StateRefusal</method> -- the vendor builds
/// Visits (1,000 facts) and this goes red.</p>
Method TestASynchronizeOfANeverBuiltCubeIsRefusedAndItsFactsStayEmpty()
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Do ##class(%DeepSee.Utils).%KillCube("OcuPilotProbeVisits", 0)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(..Facts("OcuPilotProbeVisits"), 0, "the vendor killed Visits' facts")
    Set tEvents = ..Events()
    Do $$$AssertEquals(..Ask("SYNCHRONIZE", "OcuPilotProbeVisits", .tNone, .tFault), "409 ANALYTICS.CUBE.NOTBUILT", "a synchronize of it is refused")
    Do $$$AssertEquals(..Events() _ "|" _ ..Facts("OcuPilotProbeVisits"), tEvents _ "|0", "and records no build event and builds nothing")
    Do $$$AssertEquals(..Ask("STATE", "OcuPilotProbeVisits", .tRow, .tFault, , , "BUILD"), "200 ", "a build of it is not refused")
}

/// <p>A build or a synchronize of Visits while another process holds the vendor's lock on it -- the build lock, then the synchronize node
/// alone -- is refused 409 <code>ANALYTICS.CUBE.BUSY</code> over HTTP, as the person's action: no vendor call, so no build event and no
/// fact moved. A build of Categories, whose dependent Visits is busy, is refused the same.</p>
/// <p>Mutation (Rule 19): skip the <code>"SYNC"</code> probe in <method>OcuPilot.Port.AnalyticsPort.CubeUpdatingHere</method> -- the leg on the
/// synchronize node goes red, a build event appearing.</p>
Method TestABusyCubeIsRefusedAndTheVendorIsNeverCalled()
{
    Set tEvents = ..Events()
    Set tFacts = ..Facts("OcuPilotProbeVisits")
    For tCase = $ListBuild(""), $ListBuild("SYNC") {
        Set tNode = $List(tCase, 1)
        Do ..Hold("OcuPilotProbeVisits", tNode)
        For tAction = "build", "synchronize" {
            Do $$$AssertEquals(..Act(tAction, "OcuPilotProbeVisits", .tAnswer), "409 ANALYTICS.CUBE.BUSY", tAction _ " on Visits held at '" _ tNode _ "' is refused")
        }
        Do $$$AssertEquals(..Act("build", "OcuPilotProbeCategories", .tAnswer), "409 ANALYTICS.CUBE.BUSY", "a build of Categories is refused while its dependent is busy (node '" _ tNode _ "')")
        Do ..Release()
        Do $$$AssertEquals(..Events() _ "|" _ ..Facts("OcuPilotProbeVisits"), tEvents _ "|" _ tFacts, "no build event and no fact moved (node '" _ tNode _ "')")
    }
}

/// <p>An update in <code>HSLIB</code>, whose facts the vendor keeps in a read-only database, is refused 409
/// <code>ANALYTICS.CUBE.READONLY</code> before any vendor call, and one in <code>HSCUSTOM</code>, which reports no analytics, 409
/// <code>ANALYTICS.NAMESPACE</code>. The list answers in <code>HSLIB</code>.</p>
/// <p>Mutation (Rule 19): skip the destination check in <method>OcuPilot.Port.AnalyticsPort.Admit</method> -- the HSLIB leg goes red.</p>
Method TestAnUpdateWhereTheFactsAreReadOnlyOrAnalyticsIsOffIsRefused()
{
    For tType = "BUILD", "SYNCHRONIZE" {
        Do $$$AssertEquals(..Ask(tType, "OcuPilotProbeVisits", .tNone, .tFault, "HSLIB"), "409 ANALYTICS.CUBE.READONLY", tType _ " in HSLIB is refused as read-only")
        Do $$$AssertEquals(..Ask(tType, "OcuPilotProbeVisits", .tNone, .tFault, $NAMESPACE), "409 ANALYTICS.NAMESPACE", tType _ " in " _ $NAMESPACE _ " is refused: it reports no analytics")
    }
    Do $$$AssertEquals(..Ask("STATE", "OcuPilotProbeVisits", .tNone, .tFault, "HSLIB", , "BUILD"), "409 ANALYTICS.CUBE.READONLY", "so is the read composed for a build")
    Do $$$AssertEquals($Extract(..Ask("LIST", "", .tRows, .tFault, "HSLIB"), 1, 3), "200", "while the list answers in HSLIB")
}

/// <p>The vendor's answers are mapped by <class>OcuPilot.Test.AnalyticsCubeSeam</class>: a build with failed rows (#20006) is done and says
/// how many; the cube lock (#20005) is 409 <code>ANALYTICS.CUBE.BUSY</code>; a cube it does not know (#20013) is 404; a
/// <code>&lt;PROTECT&gt;</code> or #940 is 403 <code>PORT.ACCESSDENIED</code>; any other error, #20006 beside another error and a raised
/// exception included, is 409 <code>ANALYTICS.CUBE.FAILED</code>, its text logged and absent from the body. Each makes one vendor call and none changes a fact. A
/// completed update records one <code>ConfigChange</code> row naming the verb, the cube and the namespace, and a refused or failed one none.</p>
/// <p>Mutation (Rule 19): map #20006 to <code>FAILED</code> in <method>OcuPilot.Port.AnalyticsPort.VendorOutcome</method> -- the errors leg
/// goes red; audit the lock case, or call the vendor twice in <method>OcuPilot.Port.AnalyticsPort.PerformCube</method> -- the audit and call-count legs go red;
/// test #20006 with <code>HasCode</code> rather than <code>OnlyCode</code> -- the errors-and-another-fault leg goes red.</p>
Method TestTheVendorsAnswersAreMapped()
{
    Set tFacts = ..Facts("OcuPilotProbeVisits")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $ClassMethod(..#SEAM, "Arm", "errors")
    Set tAsk = ..Ask("BUILD", "OcuPilotProbeCategories", .tResult, .tFault, , ..#SEAM)
    Do $$$AssertEquals(tAsk, "200 ", "a build that finished with errors is done")
    Do $$$AssertTrue($IsObject(tResult) && (tResult.errors = 1) && (tResult.lines.%ToJSON() = "[""Facts in OcuPilotProbeCategories: 7"",""Build errors in OcuPilotProbeCategories: 2""]"), "and says how many rows failed: " _ $Select($IsObject(tResult): tResult.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeCategories", "build", .tData), 1, "one audit row names the build of the cube")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData [ "OcuPilotProbeCategories"), "naming the namespace and the cube: " _ tData)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the build that finished with errors made exactly one vendor call")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "lock")
    Do $$$AssertEquals(..Ask("BUILD", "OcuPilotProbeCategories", .tResult, .tFault, , ..#SEAM), "409 ANALYTICS.CUBE.BUSY", "the vendor's cube lock is busy")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the locked build made exactly one vendor call")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeCategories", "build", .tNone), 1, "and left no audit row beyond the first build's")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "absent")
    Do $$$AssertEquals(..Ask("SYNCHRONIZE", "OcuPilotProbeVisits", .tResult, .tFault, , ..#SEAM), "404 PORT.NOTFOUND", "a cube the vendor does not know is absent")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the synchronize of an unknown cube made exactly one vendor call")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeVisits", "synchronize", .tNone), 0, "and left no audit row")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "protect")
    Do $$$AssertEquals(..Ask("BUILD", "OcuPilotProbeCategories", .tResult, .tFault, , ..#SEAM), "403 PORT.ACCESSDENIED", "a protection fault is access denied")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the refused build made exactly one vendor call")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeCategories", "build", .tNone), 1, "and left no audit row beyond the first build's")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "other")
    Do $$$AssertEquals(..Ask("BUILD", "OcuPilotProbeCategories", .tResult, .tFault, , ..#SEAM), "409 ANALYTICS.CUBE.FAILED", "any other error is FAILED")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ $Parameter(..#SEAM, "VENDORTEXT")), "its text is not in the body")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "Logged") [ $Parameter(..#SEAM, "VENDORTEXT"), "but it is in the log: " _ $ClassMethod(..#SEAM, "Logged"))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the failed build made exactly one vendor call")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeCategories", "build", .tNone), 1, "and left no audit row beyond the first build's")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "errorsplus")
    Do $$$AssertEquals(..Ask("BUILD", "OcuPilotProbeCategories", .tResult, .tFault, , ..#SEAM), "409 ANALYTICS.CUBE.FAILED", "a build's row errors beside another error is FAILED, not done")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the build with errors and another fault made exactly one vendor call")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeCategories", "build", .tNone), 1, "and left no audit row beyond the first build's")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "privilege")
    Do $$$AssertEquals(..Ask("SYNCHRONIZE", "OcuPilotProbeVisits", .tResult, .tFault, , ..#SEAM), "403 PORT.ACCESSDENIED", "the vendor's privilege error is access denied")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the denied synchronize made exactly one vendor call")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Arm", "exception")
    Do $$$AssertEquals(..Ask("SYNCHRONIZE", "OcuPilotProbeVisits", .tResult, .tFault, , ..#SEAM), "409 ANALYTICS.CUBE.FAILED", "an exception the vendor call raised is FAILED like any other error")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ $Parameter(..#SEAM, "VENDORTEXT")), "its text is not in the body")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "Logged") [ $Parameter(..#SEAM, "VENDORTEXT"), "but it is in the log: " _ $ClassMethod(..#SEAM, "Logged"))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 1, "the synchronize that raised made exactly one vendor call")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeCategories", "build", .tNone), 1, "and left no audit row beyond the first build's")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.InteropQueueActions", "AuditRows", tSince, "cube", "OcuPilotProbeVisits", "synchronize", .tNone), 0, "and a refused update left no audit row")
    Do $$$AssertEquals(..Facts("OcuPilotProbeVisits"), tFacts, "and no fact moved")
}

/// <p>The new reads write nothing: <code>LIST</code> and <code>STATE</code> (also composed for an action) leave USER's cache, session, favorites,
/// term list and folder nodes, and its build events, as they were (<method>OcuPilot.Test.AnalyticsPort.Snapshot</method>).</p>
/// <p>Mutation (Rule 19): read the dependents through <code>%GetMemberTree</code> in <method>OcuPilot.Port.AnalyticsPort.CubeNodeHere</method> --
/// the session node changes and this goes red.</p>
Method TestTheNewReadsWriteNothing()
{
    Set tEvents = ..Events()
    For tCase = $ListBuild("LIST", "", ""), $ListBuild("STATE", "OcuPilotProbeCategories", ""), $ListBuild("STATE", "OcuPilotProbeVisits", "SYNCHRONIZE"), $ListBuild("STATE", "OcuPilotProbeCategories", "BUILD") {
        Do ##class(OcuPilot.Test.AnalyticsPort).ForgetSession()
        Set tBefore = ##class(OcuPilot.Test.AnalyticsPort).Snapshot()
        Do $$$AssertTrue($Extract(tBefore, 1, 5) '= "ERROR", "the snapshot before " _ $List(tCase, 1) _ " was taken: " _ tBefore)
        Set tAsk = ..Ask($List(tCase, 1), $List(tCase, 2), .tResult, .tFault, , , $List(tCase, 3))
        Do $$$AssertEquals($Extract(tAsk, 1, 3), "200", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " answers")
        Do $$$AssertEquals(##class(OcuPilot.Test.AnalyticsPort).Snapshot(), tBefore, $List(tCase, 1) _ " " _ $List(tCase, 2) _ " " _ $List(tCase, 3) _ " changes none of the cache, session, favorites, term list or folder nodes")
    }
    Do $$$AssertEquals(..Events(), tEvents, "and no build event")
}

}
