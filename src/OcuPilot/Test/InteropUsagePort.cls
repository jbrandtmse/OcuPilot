/// <p>Pins the interoperability usage lists of <class>OcuPilot.Port.MonitorPort</class> (Story 18.37, AD-8,
/// AD-16, AD-29): the <code>Interfaces</code>, <code>MessageVolume</code> and <code>DatabaseImpact</code>
/// reads answer the vendor class queries of the classes the classic Interoperability Usage page reads as
/// typed rows, cut at the cap, read in <code>%SYS</code> with the caller's namespace restored, refused
/// before any query when a pair is missing, and failed whole, logged once, when a query raises or errs.</p>
/// <p>Runs through <class>OcuPilot.Test.MonitorPortFixture</class>, whose <method>UsageSource</method>
/// answers the rows a test arms and whose gate a test can swap for
/// <class>OcuPilot.Test.ScreenGate</class>. Two methods read the live queries as this account.
/// Live-safe: it creates nothing and writes only process-private globals, and the live queries only
/// read.</p>
Class OcuPilot.Test.InteropUsagePort Extends %UnitTest.TestCase
{

/// <p>The port under test.</p>
Parameter PORT = "OcuPilot.Port.MonitorPort";

/// <p>The three endpoints, each followed by its fields in the order its rows answer them, spelled here
/// rather than read from the port so a port that answered other fields is caught.</p>
Parameter ENDPOINTS = "Interfaces,MessageVolume,DatabaseImpact";

Parameter FIELDSINTERFACES = "Type,Namespace,Protocol,ActiveNow,Count";

Parameter FIELDSMESSAGEVOLUME = "Namespace,Type,Volume";

Parameter FIELDSDATABASEIMPACT = "Database,DataCreated";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>The fields of <var>pEndpoint</var>'s rows, comma-separated.</p>
ClassMethod Fields(pEndpoint As %String) As %String
{
    If pEndpoint = "Interfaces" Quit ..#FIELDSINTERFACES
    If pEndpoint = "MessageVolume" Quit ..#FIELDSMESSAGEVOLUME
    Quit ..#FIELDSDATABASEIMPACT
}

/// <p>The field of <var>pEndpoint</var>'s rows that <method>Arm</method> numbers, so a test tells which
/// armed row it holds.</p>
ClassMethod Marker(pEndpoint As %String) As %String
{
    Quit $Select(pEndpoint = "DatabaseImpact": "Database", 1: "Namespace")
}

/// <p>The list <var>pEndpoint</var> over the fixture, with <var>pMaxRows</var> as the cap
/// (<code>""</code> sends none).</p>
ClassMethod ReadList(pEndpoint As %String, pMaxRows As %String, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    If pMaxRows '= "" Set tQuery("maxRows") = pMaxRows
    Quit ##class(OcuPilot.Test.MonitorPortFixture).Invoke(pEndpoint, ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>The armed rows for <var>pEndpoint</var>: <var>pCount</var> rows whose every field holds a number
/// or a name, as the vendor query answers them. For <code>Interfaces</code> they are <var>pCount</var>
/// groupings, each answered twice as the vendor answers it: <code>Active</code> 1 with the count active now
/// (<code>tI</code>) and <code>Active</code> 0 with the count enabled at any time (<code>tI + 10</code>).</p>
ClassMethod Arm(pEndpoint As %String, pCount As %Integer)
{
    Set tRows = []
    For tI = 1:1:pCount {
        Set tRow = {}
        If pEndpoint = "Interfaces" {
            For tActive = 1, 0 {
                Do tRows.%Push({"Type": ("Inbound" _ tI), "Namespace": ("NS" _ tI), "Protocol": ("Proto" _ tI), "Active": (tActive), "Count": ($Select(tActive: tI, 1: tI + 10))})
            }
            Continue
        } ElseIf pEndpoint = "MessageVolume" {
            Do tRow.%Set("Namespace", "NS" _ tI)
            Do tRow.%Set("Type", "Inbound")
            Do tRow.%Set("Volume", tI * 10)
        } Else {
            Do tRow.%Set("Database", "DB" _ tI)
            Do tRow.%Set("DataCreated", tI)
        }
        Do tRows.%Push(tRow)
    }
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows(pEndpoint, tRows.%ToJSON())
}

/// <p>The names of <var>pRow</var>'s members, comma-separated, in order.</p>
ClassMethod Keys(pRow As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pRow.%GetIterator()
    While tIterator.%GetNext(.tKey) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

/// <p>Typing: a number the vendor answers as the string <code>"12"</code> is the JSON number 12, and a text
/// is kept as answered, the empty namespace and protocol of a totals row included. A column the port does
/// not name is not answered.</p>
/// <p>Mutation (Rule 19): answer <code>ActiveNow</code> and <code>Count</code> as text in
/// <method>OcuPilot.Port.MonitorPort.Usage</method> -- the interfaces row goes red; answer every
/// number as text -- the volume and impact rows go red.</p>
Method TestEachListTypesItsFieldsAndKeepsATotalsRow()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("Interfaces", "[{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""Active"":""1"",""Count"":""4"",""Surplus"":""x""},{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""Active"":""0"",""Count"":""12""},{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""Active"":""0"",""Count"":""0""}]")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("MessageVolume", "[{""Namespace"":""USER"",""Type"":""Inbound"",""Volume"":""80""}]")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("DatabaseImpact", "[{""Database"":""USER"",""DataCreated"":""7""}]")
    Set tExpected = $ListBuild("[{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""ActiveNow"":4,""Count"":12},{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""ActiveNow"":0,""Count"":0}]", "[{""Namespace"":""USER"",""Type"":""Inbound"",""Volume"":80}]", "[{""Database"":""USER"",""DataCreated"":7}]")
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tSC = ..ReadList(tEndpoint, "", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ ": the read succeeds")
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": with 200")
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: "absent"), $List(tExpected, tI), tEndpoint _ ": each row carries exactly its typed fields, the totals row's empty cells kept")
        Do $$$AssertEquals(tFault, "", tEndpoint _ ": and no fault")
    }
}

/// <p>The interfaces query answers each grouping twice, <code>Active</code> 1 counting the interfaces active
/// now and <code>Active</code> 0 every interface enabled at any time, the active ones included. A grouping
/// answered 4 and 11 reads as one row, <code>ActiveNow</code> 4 and <code>Count</code> 11, whichever row comes
/// first; groupings that differ in type, namespace or protocol stay apart, in the order their first row came
/// in; a grouping answered only its <code>Active</code> 0 row reads <code>ActiveNow</code> <code>0</code>; and
/// the cut counts groupings, not vendor rows.</p>
/// <p>Mutation (Rule 19): take <code>Count</code> from the <code>Active</code> 1 row and <code>ActiveNow</code>
/// from the <code>Active</code> 0 row in <method>OcuPilot.Port.MonitorPort.Groupings</method> -- the merged
/// rows go red; drop <code>Protocol</code> from the grouping key there -- the two web API groupings of one
/// namespace merge and the rows go red; cut the vendor rows at the cap before
/// <method>OcuPilot.Port.MonitorPort.Usage</method> merges them -- the cap leg goes red.</p>
Method TestAGroupingTheVendorAnswersTwiceReadsAsOneRow()
{
    Set tRaw = []
    For tRow = $ListBuild("Inbound", "", "", 1, 4), $ListBuild("Inbound", "", "", 0, 11), $ListBuild("Web API", "USER", "REST/SOAP", 0, 9), $ListBuild("Outbound", "USER", "", 0, 5), $ListBuild("Outbound", "USER", "", 1, 3), $ListBuild("Web API", "USER", "", 1, 1), $ListBuild("Web API", "USER", "", 0, 6) {
        Do tRaw.%Push({"Type": ($List(tRow, 1)), "Namespace": ($List(tRow, 2)), "Protocol": ($List(tRow, 3)), "Active": ($List(tRow, 4) _ ""), "Count": ($List(tRow, 5) _ "")})
    }
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("Interfaces", tRaw.%ToJSON())
    Set tExpected = $ListBuild("{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""ActiveNow"":4,""Count"":11}", "{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""ActiveNow"":0,""Count"":9}", "{""Type"":""Outbound"",""Namespace"":""USER"",""Protocol"":"""",""ActiveNow"":3,""Count"":5}", "{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":"""",""ActiveNow"":1,""Count"":6}")
    Set tSC = ..ReadList("Interfaces", "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Set tJson = ""
    For tI = 1:1:$ListLength(tExpected) {
        Set tJson = tJson _ $Select(tI = 1: "", 1: ",") _ $List(tExpected, tI)
    }
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: "absent"), "[" _ tJson _ "]", "seven vendor rows read as four groupings, each with the count enabled at any time and the count active now")
    Set tSC = ..ReadList("Interfaces", 3, .tCut, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tCut): tCut.%Size(), 1: "absent"), 3, "a cap of three reads three groupings, not three vendor rows")
    Do $$$AssertEquals($Select($IsObject(tCut): tCut.%Get(2).%ToJSON(), 1: "absent"), $List(tExpected, 3), "the third being the third grouping")
}

/// <p>Over armed rows, <method>OcuPilot.Port.MonitorPort.Usage</method> maps each database impact row by
/// column name: the port's two fields in the port's order whatever order the columns came in, a zero kept as
/// the number <code>0</code>, a count beyond 32 bits kept as a number, a database name kept as answered, and a
/// column the port does not name left out.</p>
/// <p>Mutation (Rule 19): type a zero as text in <method>OcuPilot.Port.MonitorPort.Usage</method> -- the
/// assertion goes red.</p>
Method TestDatabaseImpactMapsTheVendorRowsByColumnName()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("DatabaseImpact", "[{""Database"":""USER"",""DataCreated"":""0""},{""DataCreated"":""123456789012"",""Database"":""HSCUSTOM""},{""Database"":""IRISTEMP"",""DataCreated"":""3"",""Surplus"":""x""}]")
    Set tSC = ..ReadList("DatabaseImpact", "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: "absent"), "[{""Database"":""USER"",""DataCreated"":0},{""Database"":""HSCUSTOM"",""DataCreated"":123456789012},{""Database"":""IRISTEMP"",""DataCreated"":3}]", "one row per vendor row, its two fields in the port's order, the numbers typed as numbers")
}

/// <p>The cut: at most the cap's rows come back, the first ones, whatever follows them; no cap reads the
/// port's default; a cap that is not a whole number above zero is 400 <code>PORT.VALIDATION</code>
/// before any query.</p>
/// <p>Mutation (Rule 19): drop the <code>pMax</code> test in
/// <method>OcuPilot.Port.MonitorPort.Usage</method> -- the cut rows go red for the fixture, which
/// answers every armed row.</p>
Method TestEachListIsCutAtTheCap()
{
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Do ..Arm(tEndpoint, 3)
        Set tSC = ..ReadList(tEndpoint, 2, .tRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ ": a cap of two reads")
        Set tMarker = ..Marker(tEndpoint)
        Set tPrefix = $Select(tEndpoint = "DatabaseImpact": "DB", 1: "NS")
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size() _ ":" _ tRows.%Get(0).%Get(tMarker) _ ":" _ tRows.%Get(1).%Get(tMarker), 1: "absent"), "2:" _ tPrefix _ "1:" _ tPrefix _ "2", tEndpoint _ ": the first two rows")
        Set tSC = ..ReadList(tEndpoint, "", .tAll, .tHttp, .tFault)
        Do $$$AssertEquals(tAll.%Size(), 3, tEndpoint _ ": no cap reads every row up to the default")
    }

    For tBad = "0", "-1", "abc", "1.5", "2 " {
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ..Arm("Interfaces", 3)
        Set tSC = ..ReadList("Interfaces", tBad, .tRows, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "maxRows '" _ tBad _ "' is refused")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "400 PORT.VALIDATION", "'" _ tBad _ "' as 400 PORT.VALIDATION")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).UsageCalls(), 0, "'" _ tBad _ "': before any query")
    }
}

/// <p>The gate: a caller lacking either pair is refused 403 <code>AUTH.NOPRIVILEGE</code> naming that
/// pair, with no query run; holding both, it is served.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Gate</method> answer OK -- both
/// refusals go red.</p>
Method TestAMissingPairIsRefusedBeforeAnyQuery()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Do ..Arm(tEndpoint, 1)
        Set tBefore = ##class(OcuPilot.Test.MonitorPortFixture).UsageCalls()
        For tCase = $ListBuild("%DB_IRISSYS", "READ", "%Admin_Operate:USE"), $ListBuild("%Admin_Operate", "USE", "%DB_IRISSYS:READ") {
            Do ##class(OcuPilot.Test.ScreenGate).Reset()
            Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tCase, 1), $List(tCase, 2))
            Set tWhere = tEndpoint _ " holding only " _ $List(tCase, 1) _ ":" _ $List(tCase, 2)
            Set tSC = ..ReadList(tEndpoint, "", .tRows, .tHttp, .tFault)
            Do $$$AssertStatusNotOK(tSC, tWhere _ ": the read is refused")
            Set tPair = ""
            If $IsObject(tFault) && $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.failedPair
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: "") _ " " _ tPair, "403 AUTH.NOPRIVILEGE " _ $List(tCase, 3), tWhere _ ": 403 naming the pair that failed")
            Do $$$AssertEquals(tRows, "", tWhere _ ": answering no rows")
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).UsageCalls() - tBefore, 0, tEndpoint _ ": no query was run for either refusal")
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
        Set tSC = ..ReadList(tEndpoint, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tRows): tRows.%Size(), 1: "absent"), "200 1", tEndpoint _ ": holding both pairs, the read is served")
    }
}

/// <p>A query that raises, or answers an error status, fails the whole read: 500 <code>INTERNAL</code>,
/// logged once, no rows -- never an empty table answered 200 -- and the caller's namespace is
/// restored.</p>
/// <p>Mutation (Rule 19): drop the status test after <method>OcuPilot.Port.MonitorPort.UsageSource</method>
/// in <method>OcuPilot.Port.MonitorPort.Usage</method> -- the error-status leg goes red; drop the
/// namespace restore from its <code>Catch</code> -- the raise leg goes red.</p>
Method TestAQueryThatRaisesOrErrsFailsTheWholeRead()
{
    Set tNamespace = $NAMESPACE
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        For tMode = 1, 2 {
            Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
            Do ##class(OcuPilot.Test.LogProbe).Clear()
            Do ..Arm(tEndpoint, 2)
            Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRaise(tMode)
            Set tWhere = tEndpoint _ $Select(tMode = 1: " raising", 1: " erring")
            Set tSC = ..ReadList(tEndpoint, "", .tRows, .tHttp, .tFault)
            Do $$$AssertStatusNotOK(tSC, tWhere _ ": the read fails")
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "500 INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, tWhere _ ": as the generic internal fault")
            Do $$$AssertEquals(tRows, "", tWhere _ ": answering no rows")
            Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), 1, tWhere _ ": logged once")
            Do $$$AssertEquals($NAMESPACE, tNamespace, tWhere _ ": and the caller's namespace is restored")
        }
    }
}

/// <p>The query runs in <code>%SYS</code> and the caller's namespace is back when the read returns.</p>
/// <p>Mutation (Rule 19): drop the switch to <code>%SYS</code> from
/// <method>OcuPilot.Port.MonitorPort.Usage</method> -- the namespace leg goes red; drop the restore after
/// <method>OcuPilot.Port.MonitorPort.UsageSource</method> -- the method goes red, its next call left in
/// <code>%SYS</code>.</p>
Method TestTheQueryRunsInSysAndTheCallersNamespaceIsRestored()
{
    Set tNamespace = $NAMESPACE
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ..Arm(tEndpoint, 1)
        Set tSC = ..ReadList(tEndpoint, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": the read answers")
        Do $$$AssertEquals(##class(OcuPilot.Test.MonitorPortFixture).UsageCalls() _ " " _ ##class(OcuPilot.Test.MonitorPortFixture).UsageNamespace(), "1 %SYS", tEndpoint _ ": one query, taken in %SYS")
        Do $$$AssertEquals($NAMESPACE, tNamespace, tEndpoint _ ": and the caller's namespace is restored")
    }
}

/// <p>The live queries, read as this account through the production port, answer 200 with rows whose every
/// member is exactly the endpoint's fields in order, typed as declared; the interfaces answer holds its
/// totals rows (empty namespace and protocol), which the vendor query answers whether or not a
/// production has run.</p>
Method TestTheLiveQueriesAnswerExactlyTheirFields()
{
    Set tNamespace = $NAMESPACE
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Kill tQuery
        Set tQuery("maxRows") = 1000
        Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke(tEndpoint, ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ ": the live read succeeds")
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": with 200")
        Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() <= 1000), tEndpoint _ ": at most the cap's rows")
        If '$IsObject(tRows) Continue
        Set tFields = ..Fields(tEndpoint)
        Set tWhole = 0
        Set tTotals = 0
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If ..Keys(tRow) '= tFields Continue
            If (tEndpoint = "Interfaces") && (tRow.%GetTypeOf("ActiveNow") '= "number") Continue
            If (tEndpoint = "Interfaces") && (tRow.%GetTypeOf("Count") '= "number") Continue
            If (tEndpoint = "MessageVolume") && (tRow.%GetTypeOf("Volume") '= "number") Continue
            If (tEndpoint = "DatabaseImpact") && (tRow.%GetTypeOf("DataCreated") '= "number") Continue
            Set tWhole = tWhole + 1
            If (tEndpoint = "Interfaces") && (tRow.Namespace = "") && (tRow.Protocol = "") Set tTotals = tTotals + 1
        }
        Do $$$AssertEquals(tWhole, tRows.%Size(), tEndpoint _ ": every row is exactly " _ tFields _ ", typed as declared")
        If tEndpoint = "Interfaces" Do $$$AssertTrue(tTotals > 0, "the interfaces answer holds a totals row")
    }
    Do $$$AssertEquals($NAMESPACE, tNamespace, "and the caller's namespace is restored")
}

/// <p>The rows the vendor query behind <var>pEndpoint</var> answers when run directly in <code>%SYS</code>
/// over every date with every grouping on, the caller's namespace restored; -1 when it cannot be run. The
/// interfaces query answers each grouping twice, so for it the count is its groupings, and
/// <var>pCounts</var> holds each grouping's two counts as
/// <code>pCounts($ListBuild(type, namespace, protocol)) = "activeNow/count"</code>, the <code>Active</code>
/// 1 row's and the <code>Active</code> 0 row's.</p>
ClassMethod VendorRowCount(pEndpoint As %String, Output pCounts) As %Integer
{
    Kill pCounts
    Set tNamespace = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = "%SYS"
        If pEndpoint = "Interfaces" {
            Set tRS = ##class(%ResultSet).%New("SYS.Monitor.Interop.Interface.Utils:InteropInterfaces")
            Set tSC = tRS.Execute("", "", "", "", "", 1, 1, 1, 0)
        } ElseIf pEndpoint = "MessageVolume" {
            Set tRS = ##class(%ResultSet).%New("%SYS.Monitor.Interop.Messages.Utils:MetricsTotalPerNamespace")
            Set tSC = tRS.Execute("", "", "")
        } Else {
            Set tRS = ##class(%ResultSet).%New("%SYS.Monitor.Interop.DatabaseImpact.Utils:Impact")
            Set tSC = tRS.Execute("1840-12-31", "9999-12-31", "")
        }
        If $$$ISOK(tSC) {
            Set tCount = 0
            While tRS.Next(.tSC) {
                If pEndpoint '= "Interfaces" {
                    Set tCount = tCount + 1
                    Continue
                }
                Set tKey = $ListBuild(tRS.Get("Type"), tRS.Get("Namespace"), tRS.Get("Protocol"))
                If '$Data(pCounts(tKey)) {
                    Set pCounts(tKey) = "0/0"
                    Set tCount = tCount + 1
                }
                Set $Piece(pCounts(tKey), "/", $Select(tRS.Get("Active") = 1: 1, 1: 2)) = +tRS.Get("Count")
            }
            If $$$ISERR(tSC) Set tCount = -1
            Do tRS.Close()
        }
        Set $NAMESPACE = tNamespace
    } Catch {
        Set $NAMESPACE = tNamespace
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The live read of each endpoint holds every row the vendor query answers when run directly over every
/// date with every grouping on (for the interfaces, every grouping the query answers), so a narrower argument
/// list or date window in the port fails here for each list the instance holds rows of: the interfaces on
/// every instance of this image, message volume once a production has run and database impact once a message
/// purge has, since the vendor writes neither on its own. Each interfaces grouping reads the counts the
/// vendor query answers for it, <code>ActiveNow</code> its <code>Active</code> 1 row's and <code>Count</code>
/// its <code>Active</code> 0 row's, and some grouping has interfaces active now. A cap of two over the
/// interfaces reads the first two groupings whole, because the query is read whole and the cut counts
/// groupings. The real <method>OcuPilot.Port.MonitorPort.UsageSource</method> answers an error status for an
/// endpoint it has no query for.</p>
/// <p>Mutation (Rule 19): narrow the interfaces call in <method>OcuPilot.Port.MonitorPort.UsageSource</method>
/// to <code>1, 0, 0, 0</code> -- the interfaces leg goes red; start the message volume call in 2099 on an
/// instance holding message volume -- the message volume leg goes red; drop the interfaces line from
/// <method>OcuPilot.Port.MonitorPort.UsageColumns</method>, so no <code>Active</code> column is read -- the
/// grouping counts leg goes red; hand the cap to the source for the interfaces in
/// <method>OcuPilot.Port.MonitorPort.Usage</method> -- the cap leg goes red.</p>
Method TestTheLiveReadsHoldEveryRowTheVendorQueriesAnswer()
{
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tVendor = ..VendorRowCount(tEndpoint, .tCounts)
        Do $$$AssertTrue(tVendor >= 0, tEndpoint _ ": the vendor query runs directly")
        Kill tQuery
        Set tQuery("maxRows") = 1000
        Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke(tEndpoint, ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ ": the live read succeeds")
        If (tVendor < 0) || (tVendor >= 1000) || '$IsObject($Get(tRows)) Continue
        Do $$$AssertEquals(tRows.%Size(), tVendor, tEndpoint _ ": the port answers every row the vendor query holds" _ $Select(tEndpoint = "Interfaces": ", one per grouping", 1: ""))
        If tEndpoint '= "Interfaces" Continue
        Set tMatched = 0
        Set tActive = 0
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tVendorCounts = $Get(tCounts($ListBuild(tRow.Type, tRow.Namespace, tRow.Protocol)))
            If tVendorCounts = (tRow.ActiveNow _ "/" _ tRow.Count) Set tMatched = tMatched + 1
            If +$Piece(tVendorCounts, "/", 1) > 0 Set tActive = tActive + 1
        }
        Do $$$AssertEquals(tMatched, tRows.%Size(), "Interfaces: each grouping reads the vendor's Active 1 count as ActiveNow and its Active 0 count as Count")
        Do $$$AssertTrue(tActive > 0, "Interfaces: some grouping has interfaces active now, as every instance of this image has")
    }
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke("Interfaces", ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .tAll, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "Interfaces: the live read succeeds")
    Set tQuery("maxRows") = 2
    Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke("Interfaces", ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .tTwo, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "Interfaces: the live read under a cap of two succeeds")
    Do $$$AssertTrue($IsObject($Get(tAll)) && ($Get(tAll).%Size() >= 2), "Interfaces: the live read holds at least two groupings, which every instance of this image has")
    If $IsObject($Get(tAll)) && ($Get(tAll).%Size() >= 2) {
        Do $$$AssertEquals($Select($IsObject($Get(tTwo)): tTwo.%ToJSON(), 1: "absent"), "[" _ tAll.%Get(0).%ToJSON() _ "," _ tAll.%Get(1).%ToJSON() _ "]", "Interfaces: a cap of two reads the first two groupings, each with both of its vendor rows")
    }
    Set tSC = ##class(OcuPilot.Port.MonitorPort).UsageSource("Sessions", 5, .tNone)
    Do $$$AssertStatusNotOK(tSC, "the real source refuses an endpoint it has no query for")
}

/// <p>A source that answers no rows is a read that succeeded: 200 with an empty list, no fault and nothing
/// logged -- the table's empty state, never an error.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.MonitorPort.Usage</method> fail a source that answers no
/// rows -- every leg goes red.</p>
Method TestAnEmptyListIsAnsweredWholeNotAsAFault()
{
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Do ##class(OcuPilot.Test.MonitorPortFixture).Clear()
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows(tEndpoint, "[]")
        Set tSC = ..ReadList(tEndpoint, "", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ ": an empty list reads")
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": with 200")
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: "absent"), "[]", tEndpoint _ ": answering no rows")
        Do $$$AssertEquals(tFault _ "|" _ ##class(OcuPilot.Test.MonitorPortFixture).LogCalls(), "|0", tEndpoint _ ": with no fault and nothing logged")
    }
}

/// <p>The vendor queries keep the signatures the port calls them by: <code>FormalSpec</code> and
/// <code>ROWSPEC</code> as the instance compiles them in <code>%SYS</code>, and the columns the port asks the
/// result set for (<method>OcuPilot.Port.MonitorPort.UsageColumns</method>) are exactly the columns
/// <code>ROWSPEC</code> names, so a vendor release that reorders a parameter or renames a column fails here
/// and not as a wrong table.</p>
/// <p>Mutation (Rule 19): rename a field in <parameter>OcuPilot.Port.MonitorPort.FIELDSDATABASEIMPACT</parameter>
/// -- the columns leg goes red; drop the interfaces line from <method>OcuPilot.Port.MonitorPort.UsageColumns</method>,
/// or its <code>name:kind</code> split -- the columns leg goes red.</p>
Method TestTheVendorQueriesKeepTheirSignatures()
{
    Set tNamespace = $NAMESPACE
    Set tCases = $ListBuild($ListBuild("SYS.Monitor.Interop.Interface.Utils||InteropInterfaces", "pStart:%TimeStamp="""",pEnd:%TimeStamp="""",pNamespace:%String="""",pProtocol:%String="""",pType:%String="""",pIncludeTotals:%Boolean=1,pIncludePerNamespace:%Boolean=1,pIncludePerProtocol:%Boolean=1,pNSpaceContains:%Boolean=0", "Type:%String,Namespace:%String,Protocol:%String,Count:%Integer,Active:%Boolean", "Interfaces"), $ListBuild("%SYS.Monitor.Interop.Messages.Utils||MetricsTotalPerNamespace", "pStartDate:%TimeStamp="""",pEndDate:%TimeStamp="""",pNamespace:%String=""""", "Namespace:%String,Type:%String,Volume:%BigInt", "MessageVolume"), $ListBuild("%SYS.Monitor.Interop.DatabaseImpact.Utils||Impact", "pStartDate:%TimeStamp,pEndDate:%TimeStamp,pDatabase:%String=""""", "Database:%String,DataCreated:%Integer", "DatabaseImpact"))
    Set tPtr = 0
    While $ListNext(tCases, tPtr, tCase) {
        Set tActual = ""
        Set tRowSpec = ""
        Try {
            Set $NAMESPACE = "%SYS"
            Set tQuery = ##class(%Dictionary.CompiledQuery).%OpenId($List(tCase, 1))
            If $IsObject(tQuery) {
                Set tActual = tQuery.FormalSpec
                Set tRowSpec = tQuery.Parameters.GetAt("ROWSPEC")
            }
            Set $NAMESPACE = tNamespace
        } Catch {
            Set $NAMESPACE = tNamespace
        }
        Do $$$AssertEquals(tActual, $List(tCase, 2), $List(tCase, 1) _ ": its parameters")
        Do $$$AssertEquals(tRowSpec, $List(tCase, 3), $List(tCase, 1) _ ": its columns")
        Set tPortColumns = ##class(OcuPilot.Test.MonitorPortFixture).Columns($List(tCase, 4))
        Set tSpecNames = ","
        For tJ = 1:1:$Length(tRowSpec, ",") {
            Set tSpecNames = tSpecNames _ $Piece($Piece(tRowSpec, ",", tJ), ":", 1) _ ","
        }
        Set tMatched = 0
        For tJ = 1:1:$Length(tPortColumns, ",") {
            If $Find(tSpecNames, "," _ $Piece(tPortColumns, ",", tJ) _ ",") Set tMatched = tMatched + 1
        }
        Do $$$AssertEquals(tMatched _ "/" _ $Length(tPortColumns, ","), $Length(tRowSpec, ",") _ "/" _ $Length(tRowSpec, ","), $List(tCase, 4) _ ": the port asks for exactly the columns the query answers (" _ tPortColumns _ ")")
    }
}

}
