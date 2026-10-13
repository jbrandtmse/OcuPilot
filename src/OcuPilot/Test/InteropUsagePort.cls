/// <p>Pins the interoperability usage lists of <class>OcuPilot.Port.MonitorPort</class> (Story 18.37, AD-8,
/// AD-16, AD-29): the <code>Interfaces</code>, <code>MessageVolume</code> and <code>DatabaseImpact</code>
/// reads answer the classic Interoperability Usage page's class queries as typed rows, cut at the cap,
/// read in <code>%SYS</code> with the caller's namespace restored, refused before any query when a pair
/// is missing, and failed whole, logged once, when a query raises or errs.</p>
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

Parameter FIELDSINTERFACES = "Type,Namespace,Protocol,Active,Count";

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
/// or a name, as strings, the way the vendor query answers them.</p>
ClassMethod Arm(pEndpoint As %String, pCount As %Integer)
{
    Set tRows = []
    For tI = 1:1:pCount {
        Set tRow = {}
        If pEndpoint = "Interfaces" {
            Do tRow.%Set("Type", "Inbound" _ tI)
            Do tRow.%Set("Namespace", "NS" _ tI)
            Do tRow.%Set("Protocol", "Proto" _ tI)
            Do tRow.%Set("Active", 1)
            Do tRow.%Set("Count", tI)
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

/// <p>Typing: a number the vendor answers as the string <code>"12"</code> is the JSON number 12, a
/// boolean <code>"1"</code> or <code>"0"</code> is <code>true</code> or <code>false</code>, and a text is
/// kept as answered, the empty namespace and protocol of a totals row included. A column the port does not
/// name is not answered.</p>
/// <p>Mutation (Rule 19): answer <code>Active</code> as text in
/// <method>OcuPilot.Port.MonitorPort.Usage</method> -- the interfaces row goes red; answer every
/// number as text -- the volume and impact rows go red.</p>
Method TestEachListTypesItsFieldsAndKeepsATotalsRow()
{
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("Interfaces", "[{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""Active"":""1"",""Count"":""12"",""Surplus"":""x""},{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""Active"":""0"",""Count"":""0""}]")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("MessageVolume", "[{""Namespace"":""USER"",""Type"":""Inbound"",""Volume"":""80""}]")
    Do ##class(OcuPilot.Test.MonitorPortFixture).SetUsageRows("DatabaseImpact", "[{""Database"":""USER"",""DataCreated"":""7""}]")
    Set tExpected = $ListBuild("[{""Type"":""Inbound"",""Namespace"":"""",""Protocol"":"""",""Active"":true,""Count"":12},{""Type"":""Web API"",""Namespace"":""USER"",""Protocol"":""REST/SOAP"",""Active"":false,""Count"":0}]", "[{""Namespace"":""USER"",""Type"":""Inbound"",""Volume"":80}]", "[{""Database"":""USER"",""DataCreated"":7}]")
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tSC = ..ReadList(tEndpoint, "", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ ": the read succeeds")
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": with 200")
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: "absent"), $List(tExpected, tI), tEndpoint _ ": each row carries exactly its typed fields, the totals row's empty cells kept")
        Do $$$AssertEquals(tFault, "", tEndpoint _ ": and no fault")
    }
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
/// <method>OcuPilot.Port.MonitorPort.UsageSource</method> -- the restore leg goes red.</p>
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
            If (tEndpoint = "Interfaces") && (tRow.%GetTypeOf("Active") '= "boolean") Continue
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
/// over every date with every grouping on, the caller's namespace restored; -1 when it cannot be run.</p>
ClassMethod VendorRowCount(pEndpoint As %String) As %Integer
{
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
                Set tCount = tCount + 1
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
/// date with every grouping on, so a narrower argument list or date window in the port fails here; and
/// the real <method>OcuPilot.Port.MonitorPort.UsageSource</method> answers an error status for an
/// endpoint it has no query for.</p>
/// <p>Mutation (Rule 19): narrow the interfaces call in <method>OcuPilot.Port.MonitorPort.UsageSource</method>
/// to <code>1, 0, 0, 0</code> -- the interfaces leg goes red.</p>
Method TestTheLiveReadsHoldEveryRowTheVendorQueriesAnswer()
{
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tVendor = ..VendorRowCount(tEndpoint)
        Do $$$AssertTrue(tVendor >= 0, tEndpoint _ ": the vendor query runs directly")
        Kill tQuery
        Set tQuery("maxRows") = 1000
        Set tSC = ##class(OcuPilot.Port.MonitorPort).Invoke(tEndpoint, ##class(OcuPilot.Port.MonitorPort).#TYPELIST, .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tEndpoint _ ": the live read succeeds")
        If (tVendor < 0) || (tVendor >= 1000) || '$IsObject($Get(tRows)) Continue
        Do $$$AssertEquals(tRows.%Size(), tVendor, tEndpoint _ ": the port answers every row the vendor query holds")
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
/// <code>ROWSPEC</code> as the instance compiles them in <code>%SYS</code>, and the fields the port reads
/// are exactly the columns <code>ROWSPEC</code> names, so a vendor release that reorders a parameter or
/// renames a column fails here and not as a wrong table.</p>
/// <p>Mutation (Rule 19): rename a field in <parameter>OcuPilot.Port.MonitorPort.FIELDSDATABASEIMPACT</parameter>
/// -- the columns leg goes red.</p>
Method TestTheVendorQueriesKeepTheirSignatures()
{
    Set tNamespace = $NAMESPACE
    Set tCases = $ListBuild($ListBuild("SYS.Monitor.Interop.Interface.Utils||InteropInterfaces", "pStart:%TimeStamp="""",pEnd:%TimeStamp="""",pNamespace:%String="""",pProtocol:%String="""",pType:%String="""",pIncludeTotals:%Boolean=1,pIncludePerNamespace:%Boolean=1,pIncludePerProtocol:%Boolean=1,pNSpaceContains:%Boolean=0", "Type:%String,Namespace:%String,Protocol:%String,Count:%Integer,Active:%Boolean", "FIELDSINTERFACES"), $ListBuild("%SYS.Monitor.Interop.Messages.Utils||MetricsTotalPerNamespace", "pStartDate:%TimeStamp="""",pEndDate:%TimeStamp="""",pNamespace:%String=""""", "Namespace:%String,Type:%String,Volume:%BigInt", "FIELDSMESSAGEVOLUME"), $ListBuild("%SYS.Monitor.Interop.DatabaseImpact.Utils||Impact", "pStartDate:%TimeStamp,pEndDate:%TimeStamp,pDatabase:%String=""""", "Database:%String,DataCreated:%Integer", "FIELDSDATABASEIMPACT"))
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
        Set tPortFields = $Parameter(..#PORT, $List(tCase, 4))
        Set tSpecNames = ","
        For tJ = 1:1:$Length(tRowSpec, ",") {
            Set tSpecNames = tSpecNames _ $Piece($Piece(tRowSpec, ",", tJ), ":", 1) _ ","
        }
        Set tMatched = 0
        For tJ = 1:1:$Length(tPortFields, ",") {
            If $Find(tSpecNames, "," _ $Piece($Piece(tPortFields, ",", tJ), ":", 1) _ ",") Set tMatched = tMatched + 1
        }
        Do $$$AssertEquals(tMatched _ "/" _ $Length(tPortFields, ","), $Length(tRowSpec, ",") _ "/" _ $Length(tRowSpec, ","), $List(tCase, 4) _ ": the port reads exactly the columns the query answers")
    }
}

}
