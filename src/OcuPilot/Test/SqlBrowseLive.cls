/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s data browser on the instance (Story 19.7), over
/// <class>OcuPilot.Test.SqlBrowseProbe</class>'s objects in <code>USER</code>: a keyless table's page,
/// its offset, the three kinds of key and the order an unsorted page takes from them, a request
/// resolved to the catalog's spelling, the wildcard and date filters, the sort, NULL beside an empty
/// value, a stream's cut and binary hex, a filter or sort refused on them and on an unlisted column,
/// an answer cut by size answering <code>more</code>, as fetched and again once binary is hex, a
/// filter on a column whose LIKE the statement index does not record, OcuPilot's own tables found
/// for the self-protection check, a view whose tables the index does not record refused, a failed
/// read's log line carrying nothing of the request, and the bound on the page and on the count, the
/// count given only what the page left; and, as real principals in child processes, the gate naming
/// the missing pair, a column grant on a table, on a view and leaving out a table's key, a view-only
/// grant and a plan naming an ungranted column refused SQLCODE -99 while this account holds its text
/// open.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a <code>USER</code> namespace.
/// It creates and removes the probe objects, data included, and four principals, so it runs on a
/// throwaway only: <method>OnBeforeAllTests</method> refuses unless
/// <method>OcuPilot.Test.SqlConsoleProbe.Armed</method> reads 1. The principals' password is
/// generated for the run.</p>
Class OcuPilot.Test.SqlBrowseLive Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlBrowseProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

/// <p>The port with a two-second bound.</p>
Parameter FIXTURE = "OcuPilot.Test.SqlPortFixture";

/// <p>That port recording each statement's bound, and able to answer a statement unrecorded.</p>
Parameter SEAMS = "OcuPilot.Test.SqlBrowseFixture";

Parameter NAMESPACE = "USER";

/// <p>The principals' password for this run, generated in <method>OnBeforeAllTests</method>.</p>
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
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlBrowseLive creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter("OcuPilot.Test.SqlConsoleProbe", "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe197" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

/// <p>The answer to a request for <var>pTable</var> with <var>pExtra</var>, through <var>pPort</var>.</p>
Method Browse(pTable As %String, pExtra As %DynamicObject = "", pPort As %String = {..#PORT}) As %DynamicObject
{
    Set tRequest = $ClassMethod(..#PROBE, "Request", pTable, pExtra)
    If '$IsObject(tRequest) Quit {"http": 400, "code": "request", "failedPair": ""}
    Quit $ClassMethod(..#PROBE, "Browse", ..#NAMESPACE, tRequest, pPort)
}

/// <p>Matrix rows Open and Page: a keyless table answers its columns with their kinds, rows 1 to 40,
/// a total of 40, no more and no key; an offset of 5 starts at the sixth row the first page
/// shows.</p>
Method TestAKeylessTableOpensAndPages()
{
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"))
    Set tLine = $ClassMethod(..#PROBE, "Line", tAnswer)
    Do $$$AssertTrue(tLine [ "rows [Name,Num,Price,Flag,Born,Clock,Stamp,Notes,Blob,Image] key=[]", "the columns in ordinal order and no key: " _ tLine)
    Do $$$AssertTrue(tLine [ " total=40 more=0", "forty rows and no more: " _ tLine)
    Set tKinds = ""
    Set tIterator = tAnswer.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tKinds = tKinds _ $Select(tKinds = "": "", 1: ",") _ tColumn.kind
    }
    Do $$$AssertEquals(tKinds, "text,number,number,boolean,date,time,timestamp,stream,binary,binary", "each column's kind")
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " " _ tAnswer.offset _ " " _ tAnswer.size, "40 0 100", "every row on the default page of 100")
    Set tNums = ""
    For tI = 0:1:39 Set tNums = tNums _ $ListBuild(+tAnswer.rows.%Get(tI).%Get(1))
    Set tSorted = 1
    For tN = 1:1:40 If '$ListFind(tNums, tN) Set tSorted = 0
    Do $$$AssertTrue(tSorted, "rows 1 to 40")
    Set tPage = ..Browse($Parameter(..#PROBE, "PLAIN"), {"offset": 5, "size": 50})
    Do $$$AssertEquals($Select($IsObject(tPage.%Get("rows")): tPage.rows.%Size() _ " " _ tPage.rows.%Get(0).%Get(1), 1: $ClassMethod(..#PROBE, "Line", tPage)), "35 " _ tAnswer.rows.%Get(5).%Get(1), "an offset of 5 starts at the sixth row")
    Do $$$AssertEquals(tPage.offset _ " " _ tPage.size _ " " _ tPage.total, "5 50 40", "and answers its offset, size and total")
}

/// <p>AC2: a single primary key, a composite one and an identity column are each the table's key, the
/// columns marked, and an unsorted page is ordered by it.</p>
/// <p>Mutation (Rule 19): skip <parameter>OcuPilot.Port.SqlPort.BROWSEKEYQUERY</parameter> in
/// <method>OcuPilot.Port.SqlPort.BrowsePlan</method> -- the composite-key leg goes red.</p>
Method TestTheKeyIsFoundAndOrdersAnUnsortedPage()
{
    For tCase = $ListBuild("KEYED", "key=[""Code""] rows=c1,c2,c3"), $ListBuild("PAIR", "key=[""A"",""B""] rows=1,1,2"), $ListBuild("IDENT", "key=[""Id2""] rows=1,2") {
        Set tAnswer = ..Browse($Parameter(..#PROBE, $List(tCase, 1)))
        Set tLine = $ClassMethod(..#PROBE, "Line", tAnswer)
        Do $$$AssertTrue(tLine [ $List(tCase, 2), $List(tCase, 1) _ ": " _ tLine)
    }
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PAIR"))
    Set tSeconds = ""
    Set tMarked = ""
    If tAnswer.%GetTypeOf("rows") = "array" {
        For tI = 0:1:2 Set tSeconds = tSeconds _ tAnswer.rows.%Get(tI).%Get(1)
        Set tIterator = tAnswer.columns.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tColumn) {
            If tColumn.key Set tMarked = tMarked _ tColumn.name
        }
    }
    Do $$$AssertEquals(tSeconds, "121", "the composite key orders by A, then B")
    Do $$$AssertEquals(tMarked, "AB", "and both key columns are marked")
}

/// <p>AC4: a filter matches the whole value -- <code>*</code> any run and <code>?</code> one
/// character, while <code>%</code>, <code>_</code> and <code>\</code> match themselves -- and a date
/// matches its ODBC form.</p>
/// <p>Mutation (Rule 19): stop escaping <code>%</code> in <method>OcuPilot.Port.SqlPort.LikeValue</method>
/// -- the literal <code>n%</code> leg goes red.</p>
Method TestFiltersMatchTheWholeValue()
{
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"filters": {"Name": "n3*"}, "sort": {"column": "Num", "direction": "asc"}})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=n3,n30,n31,n32,n33,n34,n35,n36,n37,n38,n39 total=11", "n3* is n3 and n30 to n39: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"filters": {"Name": "n%"}})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=n% total=1", "n% matches only a value equal to n%: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"filters": {"Name": "n?"}, "sort": {"column": "Num", "direction": "asc"}})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=n1,n2,n3,n%,n7,n8,n9 total=7", "? stands for one character: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"filters": {"Name": "n1"}})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=n1 total=1", "a value with no wildcard matches itself whole: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"filters": {"Born": "2026-10*"}})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=n1 total=1", "a date matches its ODBC form: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"filters": {"Stamp": "2026-10-01 08*", "Clock": "13:45:01"}})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=n1 total=1", "so do a timestamp and a time, the filters joined with AND: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
}

/// <p>AC5: a sort on Num descending starts at 40; with the sort cleared a keyless table takes the
/// instance's order, and a keyed one its key's.</p>
Method TestTheSortAndItsClearing()
{
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"sort": {"column": "Num", "direction": "desc"}, "size": 50})
    Do $$$AssertEquals($Select(tAnswer.%GetTypeOf("rows") = "array": tAnswer.rows.%Get(0).%Get(1) _ " " _ tAnswer.rows.%Get(39).%Get(1), 1: ""), "40 1", "Num descending starts at 40")
    Set tAnswer = ..Browse($Parameter(..#PROBE, "KEYED"), {"sort": {"column": "Name", "direction": "desc"}})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=c2,c3,c1", "Name descending, two, three, one: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
    Set tAnswer = ..Browse($Parameter(..#PROBE, "KEYED"), {"sort": null})
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", tAnswer) [ "rows=c1,c2,c3", "the sort cleared, the key's order: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
}

/// <p>AC3: NULL is answered <code>null</code> and an empty value <code>""</code>; a stream's first
/// 1,000 characters end in U+2026 and binary is <code>0x</code> hex, cut at 499 bytes; each cut is
/// reported. A filter or sort on a stream, a binary or an unlisted column is refused 400.</p>
/// <p>Mutation (Rule 19): map <code>$Char(0)</code> to <code>null</code> in
/// <method>OcuPilot.Port.SqlPort.CellOf</method> -- the empty leg goes red.</p>
Method TestNullEmptyStreamAndBinaryCells()
{
    Set tAnswer = ..Browse($Parameter(..#PROBE, "PLAIN"), {"sort": {"column": "Num", "direction": "asc"}, "size": 50})
    If tAnswer.%GetTypeOf("rows") '= "array" {
        Do $$$AssertTrue(0, "the page reads: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
        Quit
    }
    Do $$$AssertEquals(tAnswer.rows.%Get(3).%GetTypeOf(0) _ " " _ tAnswer.rows.%Get(4).%GetTypeOf(0) _ " [" _ tAnswer.rows.%Get(4).%Get(0) _ "]", "null string []", "NULL is null, an empty value is """"")
    Set tNotes = tAnswer.rows.%Get(1).%Get(7)
    Do $$$AssertEquals($Length(tNotes) _ " " _ $Ascii($Extract(tNotes, *)) _ " " _ $Extract(tNotes, 1, 3), "1000 8230 xxx", "a stream's first 1,000 characters, ending in U+2026")
    Do $$$AssertEquals(tAnswer.rows.%Get(9).%Get(8), "0x00FF0A", "binary as 0x hex")
    Set tImage = tAnswer.rows.%Get(2).%Get(9)
    Do $$$AssertEquals($Length(tImage) _ " " _ $Extract(tImage, 1, 6) _ " " _ $Ascii($Extract(tImage, *)), (2 + 998 + 1) _ " 0xABAB 8230", "a long binary value cut at 499 bytes, ending in U+2026")
    Do $$$AssertEquals(tAnswer.truncated, 1, "and the cuts are reported")
    Do $$$AssertEquals(tAnswer.rows.%Get(0).%Get(3) _ " " _ tAnswer.rows.%Get(0).%Get(2) _ " " _ tAnswer.rows.%Get(0).%Get(4) _ " " _ tAnswer.rows.%Get(0).%Get(6), "1 1.5 2026-10-01 2026-10-01 08:00:00", "a bit, a number, a date and a timestamp in the ODBC form")
    For tExtra = {"filters": {"Notes": "x*"}}, {"filters": {"Blob": "*"}}, {"sort": {"column": "Image", "direction": "asc"}}, {"filters": {"Nope": "x"}}, {"sort": {"column": "name", "direction": "asc"}} {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Line", ..Browse($Parameter(..#PROBE, "PLAIN"), tExtra)), "400 EXPLORER.DATA.INPUT ", "refused: " _ tExtra.%ToJSON())
    }
}

/// <p>DW-2025's case: a filter on a string column whose statistics show a NULL outlier composes a
/// page the statement index does not record until it runs -- the console refuses that text 422
/// <code>EXPLORER.SQL.UNRECORDED</code> -- and the data browser still answers its rows, because no
/// part of its path reads the statement index for a table.</p>
/// <p>Mutation (Rule 19): call <method>OcuPilot.Port.SqlPort.Classify</method> on the page in
/// <method>OcuPilot.Port.SqlPort.BrowseRun</method> -- the rows leg goes red.</p>
Method TestAnUnrecordedFilterStillAnswersRows()
{
    Set tRequest = $ClassMethod(..#PROBE, "Request", $Parameter(..#PROBE, "PETS"), {"filters": {"Name": "n*"}, "sort": {"column": "Num", "direction": "asc"}})
    Set tSC = $ClassMethod(..#PORT, "BrowsePlan", ..#NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the page is planned")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, tPlan.page, .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISERR(tSC): $Get(tHttp) _ " " _ tFault.code, 1: "classified"), "422 EXPLORER.SQL.UNRECORDED", "the statement index does not record the composed page")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Line", ..Browse($Parameter(..#PROBE, "PETS"), {"filters": {"Name": "n*"}, "sort": {"column": "Num", "direction": "asc"}})) [ "rows=1,2 total=2", "and the data browser answers its rows")
    For tMethod = "BrowseRun", "Executed", "CatalogRows", "PrepareProblem", "Composed", "CellOf" {
        Set tCode = ##class(%Dictionary.MethodDefinition).%OpenId(..#PORT _ "||" _ tMethod).Implementation.Read(100000)
        Do $$$AssertTrue((tCode '[ "STATEMENT_") && (tCode '[ "StatementIndex") && (tCode '[ "..Prepared(") && (tCode '[ "..Classify("), tMethod _ " reads no statement index")
    }
}

/// <p>AC7 at the port: a table in an OcuPilot schema is refused by its name alone, and a view over
/// OcuPilot's proposal table, in the install namespace, is planned with that table among its tables,
/// so the composed page is refused <code>PROHIBITED.OCUPILOTSQL</code> before any row is read.</p>
Method TestOcuPilotsOwnTablesAreFoundForTheCheck()
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).SqlStatement("", $ListBuild("OcuPilot_Kernel_State.Turn"), 1, .tProhibits, .tCode)
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 PROHIBITED.OCUPILOTSQL", "a table in an OcuPilot schema is refused by its name")
    Set tRequest = $ClassMethod(..#PROBE, "Request", $Parameter(..#PROBE, "OWNVIEW"))
    Set tSC = $ClassMethod(..#PORT, "BrowsePlan", $NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the view over OcuPilot's table is planned")
    If $$$ISERR(tSC) Quit
    Set tTables = ""
    Set tIterator = tPlan.tables.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTable) {
        Set tTables = tTables _ $ListBuild($ZConvert(tTable, "U"))
    }
    Do $$$AssertTrue($ListFind(tTables, "OCUPILOT_KERNEL_STATE.PROPOSAL"), "its tables carry OcuPilot's table: " _ tPlan.tables.%ToJSON())
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).SqlStatement(tPlan.page, tTables, 1, .tProhibits, .tCode)
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 PROHIBITED.OCUPILOTSQL", "so the page is refused")
}

/// <p>AC8: a page past the bound answers <code>stopped</code>, and a count with too little of the
/// shared budget left answers <code>total: null</code> beside its page's rows.</p>
/// <p>Mutation (Rule 19): pass a bound of 0 for the page in
/// <method>OcuPilot.Port.SqlPort.BrowseRun</method> -- the stopped leg runs to completion and goes
/// red.</p>
Method TestThePageAndTheCountShareTheBound()
{
    Set tSlow = $Parameter(..#PROBE, "SLOWVIEW")
    Set tStart = $ZHorolog
    Set tAnswer = ..Browse(tSlow, {"size": 50, "filters": {"S": "99*"}}, ..#FIXTURE)
    Do $$$AssertEquals(tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("seconds") _ " " _ $Select($IsObject(tAnswer.%Get("table")): tAnswer.table.type, 1: "") _ " " _ tAnswer.%GetTypeOf("rows"), "stopped 2 view unassigned", "a page past the bound is stopped, with no row: " _ tAnswer.%ToJSON())
    Do $$$AssertTrue(($ZHorolog - tStart) < 6, "within the bound")
    ; The first read compiles the page and count statements, so the second's page is not slowed by it.
    Do ..Browse(tSlow, {"size": 50, "filters": {"S": "*"}}, ..#FIXTURE)
    Set tAnswer = ..Browse(tSlow, {"size": 50, "filters": {"S": "*"}}, ..#FIXTURE)
    Do $$$AssertEquals($Select(tAnswer.%GetTypeOf("rows") = "array": tAnswer.rows.%Size() _ " " _ tAnswer.%GetTypeOf("total") _ " " _ tAnswer.more, 1: $ClassMethod(..#PROBE, "Line", tAnswer)), "50 null 1", "the page's rows, and a count past what remains answers null")
}

/// <p>The gate (AD-29): without <code>%Development:USE</code>, or without READ on the namespace's
/// database, the port refuses 403 <code>AUTH.NOPRIVILEGE</code> naming the pair before any
/// statement.</p>
Method TestTheGateNamesTheMissingPair()
{
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tUserCode, .tGlobals, .tMapped, .tResolved)
    Set tLegs = [{"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "Plain"}}].%ToJSON()
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "NODEVUSER"), tLegs)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "403 AUTH.NOPRIVILEGE %Development:USE", "without %Development:USE")
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "NOUSERUSER"), tLegs)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "403 AUTH.NOPRIVILEGE " _ tUserCode _ ":READ", "without READ on the namespace's database")
}

/// <p>AC6: a principal sees only what it is granted -- a column grant, on a table or on a view, lists
/// and reads only its column, with no count; a column grant that leaves out a table's key column
/// leaves the page with no key, so it is never ordered by a column it cannot read; a view it holds
/// nothing on answers 404; the view-only grantee reads the view's ten rows and is answered 404 on its
/// base table.</p>
/// <p>Mutation (Rule 19): read a view's base tables from <code>SELECT COUNT(*)</code> in
/// <method>OcuPilot.Port.SqlPort.BrowsePlan</method> -- the view column grant's leg answers -99 and
/// goes red. Keep a key whose column is not listed in that method -- the keyed column grant's leg
/// answers -99 and goes red.</p>
Method TestTheReadChecksTheCallersPrivileges()
{
    Set tLegs = [
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "Two"}},
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "SlowView"}},
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "Two", "sort": {"column": "Secret", "direction": "asc"}}},
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "Over30", "sort": {"column": "Name", "direction": "asc"}}},
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "Keyed", "sort": {"column": "Name", "direction": "asc"}}}
    ].%ToJSON()
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "USER"), tLegs)
    Do $$$AssertEquals($Select($IsObject(tProbe): tProbe.%Get("username"), 1: ""), $Parameter(..#PROBE, "USER"), "the probe ran as the principal: " _ $Select($IsObject(tProbe): tProbe.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "rows [Name] key=[] rows=t1,t2 total=null more=0", "a column grant reads only its column, with no count")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 1), "404 EXPLORER.DATA.NOTFOUND ", "a view it holds nothing on answers 404")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 2), "400 EXPLORER.DATA.INPUT ", "and a sort on the ungranted column is an unlisted column")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 3), "rows [Name] key=[] rows=n31,n32,n33,n34,n35,n36,n37,n38,n39,n40 total=null more=0", "a column grant on a view reads only its column, without a -99")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 4), "rows [Name] key=[] rows=one,three,two total=null more=0", "a column grant that leaves out the key column has no key, and reads without a -99")
    Set tLegs = [
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "Over30", "sort": {"column": "Num", "direction": "asc"}}},
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197", "table": "Plain"}}
    ].%ToJSON()
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "VIEWUSER"), tLegs)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 0), "rows [Name,Num] key=[] rows=n31,n32,n33,n34,n35,n36,n37,n38,n39,n40 total=10 more=0", "the view-only grantee reads the view's ten rows")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 1), "404 EXPLORER.DATA.NOTFOUND ", "and is answered 404 on its base table")
}

/// <p>AC6: a plan naming a column the principal is not granted, composed by this account, whose texts
/// this account holds open, answers the principal SQLCODE -99 and no row.</p>
/// <p>Mutation (Rule 19): prepare with privilege checks off in
/// <method>OcuPilot.Port.SqlPort.Executed</method> -- the principal reads the rows and this goes
/// red.</p>
Method TestAStalePlanHeldOpenIsStillRefused()
{
    Set tRequest = $ClassMethod(..#PROBE, "Request", $Parameter(..#PROBE, "TWO"))
    Set tSC = $ClassMethod(..#PORT, "BrowsePlan", ..#NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "this account plans both columns")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tPlan.page [ """Secret""", "the plan names the ungranted column")
    Do $$$AssertEquals(##class(OcuPilot.Test.SqlConsoleProbe).Hold($ListBuild(tPlan.page, tPlan.count), .tHeld), 2, "this account holds its page and count open")
    Set tLegs = [{"op": "run", "namespace": (..#NAMESPACE), "plan": (tPlan)}].%ToJSON()
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "USER"), tLegs)
    Do ##class(OcuPilot.Test.SqlConsoleProbe).Release(.tHeld)
    Set tLeg = $Select($IsObject(tProbe) && (tProbe.%GetTypeOf("legs") = "array"): tProbe.legs.%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("outcome") _ " " _ tLeg.%Get("sqlcode") _ " " _ tLeg.%GetTypeOf("rows"), 1: $Select($IsObject(tProbe): tProbe.%ToJSON(), 1: "")), "error -99 unassigned", "the principal is refused -99 with no row")
}

/// <p>AC6: a request names the table in any case, and the plan, the composed page and the answer
/// carry the catalog's own spelling, never the request's.</p>
/// <p>Mutation (Rule 19): keep the request's schema and name in
/// <method>OcuPilot.Port.SqlPort.BrowsePlan</method> -- this goes red.</p>
Method TestARequestResolvesToTheCatalogsSpelling()
{
    Set tRequest = $ClassMethod(..#PROBE, "Request", "ocuprobe197.keyed")
    Set tSC = $ClassMethod(..#PORT, "BrowsePlan", ..#NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the lower-case request is planned")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(tPlan.page [ " FROM ""OcuProbe197"".""Keyed""", "the page names the catalog's spelling: " _ tPlan.page)
    Do $$$AssertTrue(tPlan.page '[ "ocuprobe197", "and never the request's")
    Do $$$AssertEquals(tPlan.table.schema _ "." _ tPlan.table.name, "OcuProbe197.Keyed", "so does the answer's table")
}

/// <p>AC8: a page of 500 asking for 400 rows of three 1,000-character cells stops short of the
/// answer's 1,000,000 characters by whole rows and answers <code>more</code>, so Next reaches the
/// rest.</p>
/// <p>Mutation (Rule 19): drop <code>more</code> from <method>OcuPilot.Port.SqlPort.Executed</method>'s
/// answer cut -- this goes red.</p>
Method TestAnAnswerCutBySizeSaysMore()
{
    Set tAnswer = ..Browse($Parameter(..#PROBE, "WIDE"), {"size": 500})
    If tAnswer.%GetTypeOf("rows") '= "array" {
        Do $$$AssertTrue(0, "the page reads: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
        Quit
    }
    Set tKept = tAnswer.rows.%Size()
    Do $$$AssertTrue((tKept > 0) && (tKept < $Parameter(..#PROBE, "WIDEROWS")), "some rows, not all of them: " _ tKept)
    Do $$$AssertTrue($Length(tAnswer.rows.%ToJSON()) <= $Parameter(..#PORT, "MAXANSWER"), "the rows stay within the answer's characters")
    Do $$$AssertEquals(tAnswer.more _ " " _ tAnswer.total _ " " _ tAnswer.truncated, "1 " _ $Parameter(..#PROBE, "WIDEROWS") _ " 1", "more, the whole total, and the cells' cut")
}

/// <p>AC8: a page whose rows fit the answer as fetched, but not once their binary cells are written as
/// <code>0x</code> hex, is cut again by whole rows after the cells are mapped and answers
/// <code>more</code>.</p>
/// <p>Mutation (Rule 19): drop <code>more</code> from <method>OcuPilot.Port.SqlPort.BrowseRun</method>'s
/// own answer cut -- this goes red.</p>
Method TestAnAnswerCutOnceHexSaysMore()
{
    Set tAnswer = ..Browse($Parameter(..#PROBE, "BLOBS"), {"size": 500})
    If tAnswer.%GetTypeOf("rows") '= "array" {
        Do $$$AssertTrue(0, "the page reads: " _ $ClassMethod(..#PROBE, "Line", tAnswer))
        Quit
    }
    Set tKept = tAnswer.rows.%Size()
    Do $$$AssertTrue((tKept > 0) && (tKept < $Parameter(..#PROBE, "BLOBROWS")), "some rows, not all of them: " _ tKept)
    Do $$$AssertTrue($Length(tAnswer.rows.%ToJSON()) <= $Parameter(..#PORT, "MAXANSWER"), "the hex rows stay within the answer's characters")
    Do $$$AssertEquals(tAnswer.more _ " " _ tAnswer.total, "1 " _ $Parameter(..#PROBE, "BLOBROWS"), "more, and the whole total")
}

/// <p>AC8: a refused catalog read and a view whose tables the statement index does not record each
/// write their log line, and neither line carries the requested table or what the instance answered
/// (AD-39).</p>
/// <p>Mutation (Rule 19): log the instance's SQLCODE and message in
/// <method>OcuPilot.Port.SqlPort.CatalogRows</method>'s refusal -- this goes red.</p>
Method TestAFailedReadLogsNothingOfTheRequest()
{
    Set tMark = "OcuProbe197Log" _ $Translate($ZTimeStamp, ",.", "")
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Set ^||OcuProbe197Refused = tMark
    Set tSC = $ClassMethod(..#SEAMS, "BrowsePlan", ..#NAMESPACE, $ClassMethod(..#PROBE, "Request", $Parameter(..#PROBE, "PLAIN")), .tPlan, .tHttp, .tFault)
    Kill ^||OcuProbe197Refused
    Do $$$AssertEquals($Select($$$ISERR(tSC): $Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), 1: "planned"), "500 INTERNAL", "a refused catalog read is refused 500")
    Set ^||OcuProbe197Unindexed = 1
    Set tSC = $ClassMethod(..#SEAMS, "BrowsePlan", ..#NAMESPACE, $ClassMethod(..#PROBE, "Request", $Parameter(..#PROBE, "OVER30")), .tPlan, .tHttp, .tFault)
    Kill ^||OcuProbe197Unindexed
    Do $$$AssertEquals($Select($$$ISERR(tSC): $Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), 1: "planned"), "500 INTERNAL", "and so is a view whose tables are unrecorded")
    Set tLogged = 0
    Set tFound = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If tLine '[ """subsystem"":""sqlport""" Continue
            Set tLogged = tLogged + 1
            If $ZConvert(tLine, "U") [ "OCUPROBE197" Set tFound = tLine
        }
    }
    Set tStream = ""
    Do $$$AssertTrue(tLogged >= 2, "each wrote its log line: " _ tLogged)
    Do $$$AssertEquals(tFound, "", "and neither carries the table or the instance's answer")
}

/// <p>AC8: every statement of one request shares one budget -- with a plan whose budget is mostly
/// spent, the page and the count are each given only the whole second left, never a fresh
/// bound.</p>
/// <p>Mutation (Rule 19): give the count <code>BoundSeconds()</code> in
/// <method>OcuPilot.Port.SqlPort.BrowseRun</method> -- this goes red.</p>
Method TestTheCountTakesWhatRemainsOfTheBudget()
{
    Set tRequest = $ClassMethod(..#PROBE, "Request", $Parameter(..#PROBE, "KEYED"))
    Set tSC = $ClassMethod(..#SEAMS, "BrowsePlan", ..#NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the page is planned")
    If $$$ISERR(tSC) Quit
    Kill ^||OcuProbe197Bounds
    Do tPlan.%Set("start", $ZHorolog - 1.5, "number")
    Set tSC = $ClassMethod(..#SEAMS, "BrowseRun", ..#NAMESPACE, tPlan, .tAnswer, .tHttp, .tFault)
    Set tBounds = $ClassMethod(..#SEAMS, "Bounds")
    Kill ^||OcuProbe197Bounds
    Do $$$AssertStatusOK(tSC, "the page runs")
    Do $$$AssertEquals(tBounds, "1,1", "the page and the count each get the second the plan left of two")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%Get("total"), 1: ""), 3, "and the count still answers within it")
}

/// <p>AC7: a view whose tables the statement index does not record is refused 500 before any row,
/// because the self-protection check could not see what it reads.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Port.SqlPort.BrowsePlan</method> carry on with the view
/// alone when its tables are unrecorded -- this goes red.</p>
Method TestAViewWhoseTablesAreUnrecordedFailsClosed()
{
    Set tRequest = $ClassMethod(..#PROBE, "Request", $Parameter(..#PROBE, "OVER30"))
    Set ^||OcuProbe197Unindexed = 1
    Set tSC = $ClassMethod(..#SEAMS, "BrowsePlan", ..#NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Kill ^||OcuProbe197Unindexed
    Do $$$AssertEquals($Select($$$ISERR(tSC): $Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), 1: "planned"), "500 INTERNAL", "refused, with no plan to run")
    Do $$$AssertEquals($Get(tPlan), "", "and no plan")
}

}
