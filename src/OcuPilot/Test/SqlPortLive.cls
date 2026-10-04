/// <p>Pins <class>OcuPilot.Port.SqlPort</class> on the instance (Story 19.6), over
/// <class>OcuPilot.Test.SqlConsoleProbe</class>'s probe objects in <code>USER</code>: a query's rows
/// bound by its values and cut by Max rows, a cell and the whole answer; the kind read from the
/// prepared statement type whatever the text's comments say; the session, administration and
/// server-file statements refused and a password statement never reaching the statement index; a query
/// and a DML statement stopped at the bound, the DML statement undone; a transaction a run leaves open
/// rolled back; a plan that executes nothing; a CALL's first result set and its output position taking
/// no value; OcuPilot's own tables found
/// through the statement index and a view's usage; a statement the index answers no row for refused,
/// its log line carrying none of it; and, as real principals in child processes, the gate naming the
/// missing pair and the instance refusing SQLCODE -99 at prepare for every statement on a table the
/// principal holds no SQL privilege on (DW-1964), every kind still refused although another account
/// holds the same statement open, and no cached DDL compile left behind by the console (DW-1986). <code>THROUGH</code> needs a foreign server that
/// passes statements through, which a probe cannot make; the kind table pins its type.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a <code>USER</code> namespace.
/// It creates and removes the probe objects, data included, and three principals, so it runs on a
/// throwaway only: <method>OnBeforeAllTests</method> refuses unless
/// <parameter>OcuPilot.Test.SqlConsoleProbe.ARMINGVARIABLE</parameter> reads <code>1</code>. The
/// principals' password is generated for the run.</p>
Class OcuPilot.Test.SqlPortLive Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlConsoleProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

/// <p>The port with a two-second bound.</p>
Parameter FIXTURE = "OcuPilot.Test.SqlPortFixture";

Parameter NAMESPACE = "USER";

/// <p>The port whose statement index answers no row.</p>
Parameter UNINDEXED = "OcuPilot.Test.SqlPortUnindexed";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlPortLive creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter(..#PROBE, "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe196" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

/// <p><var>pAnswer</var> or <var>pFault</var> as one line for an assertion.</p>
ClassMethod Said(pSC As %Status, pAnswer, pHttp, pFault) As %String
{
    If $$$ISERR(pSC) Quit $Get(pHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
    If '$IsObject($Get(pAnswer)) Quit "no answer"
    Quit pAnswer.%ToJSON()
}

/// <p>AC1: a query answers its columns and rows, its values bound as values and cut by Max rows with
/// the cut reported; a cell is cut at 1,000 characters ending in U+2026, and the whole answer at
/// 1,000,000 characters by whole rows.</p>
/// <p>Mutation (Rule 19): splice the first value into the statement's text in
/// <method>OcuPilot.Port.SqlPort.Executed</method> -- the bound-not-spliced leg goes red.</p>
Method TestAQueryAnswersItsRowsBoundAndCut()
{
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "SELECT Name FROM OcuProbe196.Granted WHERE Num > ? ORDER BY Num", ["0"], 1, "query", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[[""n1""]],""truncated"":true}", "one row of forty, the cut reported")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "SELECT Name FROM OcuProbe196.Granted WHERE Name = ?", ["' OR ''='"], 10, "query", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[],""truncated"":false}", "a value is bound, never spliced")
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, "SELECT Name FROM OcuProbe196.Granted WHERE Num > ? AND Name <> ?", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.Parameters, 1: -1), 2, "a statement with two ? takes two values")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "SELECT REPEAT('x', 1500) AS L", [], 10, "query", .tAnswer, .tHttp, .tFault)
    Set tCell = $Select($$$ISOK(tSC) && $IsObject(tAnswer.%Get("rows")): tAnswer.rows.%Get(0).%Get(0), 1: "")
    Do $$$AssertEquals($Length(tCell) _ " " _ $Ascii($Extract(tCell, *)) _ " " _ $Select($$$ISOK(tSC): tAnswer.truncated, 1: ""), "1000 8230 1", "a cell is cut at 1,000 characters ending in U+2026")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "SELECT REPEAT('y', 999) AS L FROM OcuProbe196.Granted a, OcuProbe196.Granted b", [], 1000, "query", .tAnswer, .tHttp, .tFault)
    Set tRows = $Select($$$ISOK(tSC) && $IsObject(tAnswer.%Get("rows")): tAnswer.rows.%Size(), 1: -1)
    Do $$$AssertTrue((tRows > 900) && (tRows < 1000) && ($Length(tAnswer.rows.%ToJSON()) <= 1001002) && tAnswer.truncated, "the answer is cut at 1,000,000 characters by whole rows: " _ tRows)
}

/// <p>AC2: the kind is the prepared statement type, so a leading comment or <code>/* SELECT */</code>
/// leaves a DELETE DML; text holding two statements is refused by the instance (SQLCODE -25); a
/// statement records its tables; and a write refuses a query <code>EXPLORER.SQL.READS</code>.</p>
/// <p>Mutation (Rule 19): map type 4 to <code>query</code> -- the disguised legs go red.</p>
Method TestTheKindIsThePreparedStatementType()
{
    For tCase = $ListBuild("/* SELECT */ DELETE FROM OcuProbe196.Granted WHERE Num < 0", "dml 4"), $ListBuild("-- c" _ $Char(10) _ "DELETE FROM OcuProbe196.Granted WHERE Num < 0", "dml 4"), $ListBuild("TRUNCATE TABLE OcuProbe196.Hidden", "dml 4"), $ListBuild("UPDATE OcuProbe196.Granted SET Num = Num WHERE Num < 0", "dml 3"), $ListBuild("CREATE TABLE OcuProbe196.Made (X INTEGER)", "ddl 9"), $ListBuild("CALL OcuProbe196.LeaveOpen()", "call 45"), $ListBuild("WITH x AS (SELECT 1 AS a) SELECT a FROM x", "query 1") {
        Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, $List(tCase, 1), .tGuard, .tHttp, .tFault)
        Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.Kind _ " " _ tGuard.StatementType, 1: ..Said(tSC, "", .tHttp, .tFault)), $List(tCase, 2), $List(tCase, 1))
    }
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, "UPDATE OcuProbe196.Granted SET Num = Num WHERE Num < 0", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.Tables.%ToJSON(), 1: ""), "[""OCUPROBE196.GRANTED""]", "an UPDATE records its table")
    Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.DefaultSchema, 1: "unread"), ..DefaultSchemaIn(..#NAMESPACE), "and the guard carries the namespace's default schema, which rule (c) reads")
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, "SELECT Name FROM OcuProbe196.Granted; DELETE FROM OcuProbe196.Granted", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC) && $IsObject(tGuard.%Get("error")): tGuard.error.sqlcode, 1: ""), -25, "two statements are refused by the instance")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "SELECT Name FROM OcuProbe196.Granted", [], 10, "write", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "422 EXPLORER.SQL.READS", "a write refuses a query")
}

/// <p>AC3: a session, administration or server-file statement is refused by name on a run and on a
/// plan; a password statement is refused before any prepare, so the statement index holds no row
/// for it.</p>
/// <p>Mutation (Rule 19): move the password check after the prepare in
/// <method>OcuPilot.Port.SqlPort.Classify</method> -- the index leg goes red.</p>
Method TestRefusedStatementsAndThePasswordNeverReachTheIndex()
{
    Set tGroups = $ListBuild($ListBuild("EXPLORER.SQL.SESSION", "START TRANSACTION", "COMMIT", "SAVEPOINT OcuProbe196Point", "SET OPTION DEFAULT_SCHEMA = OcuProbe196", "LOCK TABLE OcuProbe196.Granted IN EXCLUSIVE MODE", "CANCEL QUERY 1"), $ListBuild("EXPLORER.SQL.ADMINISTRATION", "GRANT SELECT ON OcuProbe196.Granted TO _PUBLIC", "REVOKE SELECT ON OcuProbe196.Granted FROM _PUBLIC", "CREATE ROLE OcuProbe196Role2", "DROP USER OcuProbe196Nobody", "DROP DATABASE OcuProbe196Db"), $ListBuild("EXPLORER.SQL.SERVERFILES", "LOAD DATA FROM FILE '/tmp/ocuprobe196.csv' INTO OcuProbe196.Granted", "CREATE SERVER OcuProbe196Server FOREIGN DATA WRAPPER CSV HOST '/tmp/'", "CREATE FOREIGN TABLE OcuProbe196.Far (X INT) SERVER OcuProbe196Server FILE 'x.csv'"))
    For tG = 1:1:$ListLength(tGroups) {
        Set tGroup = $List(tGroups, tG)
        For tI = 2:1:$ListLength(tGroup) {
            Set tText = $List(tGroup, tI)
            Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, tText, [], 10, "write", .tAnswer, .tHttp, .tFault)
            Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "422 " _ $List(tGroup, 1), "run: " _ tText)
            Set tSC = $ClassMethod(..#PORT, "Plan", ..#NAMESPACE, tText, .tAnswer, .tHttp, .tFault)
            Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "422 " _ $List(tGroup, 1), "plan: " _ tText)
        }
    }
    Set tMark = "OcuProbe196Mark" _ $Translate($ZTimeStamp, ",.", "")
    Set tText = "SELECT ((" _ $Char(39) _ tMark _ " IDENTIFY" _ $Char(39) _ ")) AS Probe FROM OcuProbe196.Granted"
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, tText, .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, "", .tHttp, .tFault), "422 EXPLORER.SQL.PASSWORD", "text that sets a password is refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "IndexRows", tMark), 0, "before any prepare: the statement index holds no row for it")
}

/// <p>AC6: a query and a DML statement past the bound are stopped and reported, and the stopped DML
/// statement leaves its table unchanged.</p>
/// <p>Mutation (Rule 19): never set the alarm in <method>OcuPilot.Port.SqlPort.Executed</method> -- the
/// DML leg runs to completion and goes red.</p>
Method TestAStatementPastTheBoundIsStopped()
{
    Set tSC = $ClassMethod(..#FIXTURE, "Run", ..#NAMESPACE, "SELECT COUNT(*) FROM OcuProbe196.Granted a, OcuProbe196.Granted b, OcuProbe196.Granted c, OcuProbe196.Granted d, OcuProbe196.Granted e", [], 10, "query", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""outcome"":""stopped"",""kind"":""query"",""seconds"":2}", "a long query is stopped at the bound")
    Set tSC = $ClassMethod(..#FIXTURE, "Run", ..#NAMESPACE, "UPDATE OcuProbe196.Granted SET Num = OcuProbe196.Slow(Num) + 1", [], 10, "write", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""outcome"":""stopped"",""kind"":""dml"",""seconds"":2}", "a long UPDATE is stopped at the bound")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "and its table is unchanged")
    Do $$$AssertEquals($TLevel, 0, "with no transaction left open")
}

/// <p>A run that leaves a transaction open is rolled back to where it started and answers
/// <code>error</code> with <code>rolledBack</code>.</p>
Method TestARunThatLeavesATransactionOpenIsRolledBack()
{
    Set tLevel = $TLevel
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "CALL OcuProbe196.LeaveOpen()", [], 10, "write", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""outcome"":""error"",""kind"":""call"",""sqlcode"":null,""message"":"""",""rolledBack"":true}", "the run answers error, rolled back")
    Do $$$AssertEquals($TLevel, tLevel, "and $TLevel is where it started")
}

/// <p>AC5: a plan executes nothing -- an UPDATE's plan is its text and the table is unchanged -- and a
/// DDL statement or a CALL has none.</p>
/// <p>Mutation (Rule 19): run the statement in <method>OcuPilot.Port.SqlPort.Plan</method> before its
/// plan is read -- the unchanged-table leg goes red.</p>
Method TestAPlanExecutesNothing()
{
    Set tSC = $ClassMethod(..#PORT, "Plan", ..#NAMESPACE, "UPDATE OcuProbe196.Granted SET Num = Num + 1", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.outcome _ " " _ tAnswer.kind _ " " _ (tAnswer.plan [ "<plan>"), 1: ..Said(tSC, "", .tHttp, .tFault)), "plan dml 1", "an UPDATE's plan is read")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "and the table is unchanged")
    For tText = "CREATE TABLE OcuProbe196.Made (X INTEGER)", "CALL OcuProbe196.LeaveOpen()" {
        Set tSC = $ClassMethod(..#PORT, "Plan", ..#NAMESPACE, tText, .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.outcome, 1: ""), "noplan", tText _ " has no plan")
    }
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", "OcuProbe196.Made"), "and nothing was created")
}

/// <p>A CALL that answers a result set answers its first one as rows, cut by Max rows; DML answers its
/// changed rows.</p>
Method TestACallAnswersItsFirstResultSetAndDmlItsRowCount()
{
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "CALL OcuProbe196.Listing()", [], 3, "write", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""kind"":""call"",""outcome"":""rows"",""columns"":[""Name"",""Num""],""rows"":[[""n1"",""1""],[""n2"",""2""],[""n3"",""3""]],""truncated"":true}", "the procedure's rows, cut at three")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "UPDATE OcuProbe196.Granted SET Num = Num WHERE Num <= ?", ["5"], 10, "write", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""kind"":""dml"",""outcome"":""done"",""rowCount"":5}", "an UPDATE answers its changed rows")
}

/// <p>AC1: an output <code>?</code> takes no value. A CALL with an input and an output position asks
/// for one value, and runs with that one, the output position left to the instance.</p>
/// <p>Mutation (Rule 19): count every position in <method>OcuPilot.Port.SqlPort.ValuePositions</method>
/// -- both legs go red.</p>
Method TestAnOutputPositionTakesNoValue()
{
    Set tText = "CALL " _ $Parameter(..#PROBE, "ECHO") _ "(?, ?)"
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, tText, .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.Kind _ " " _ tGuard.Parameters, 1: ..Said(tSC, "", .tHttp, .tFault)), "call 1", "a CALL with an input and an output ? takes one value")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, tText, ["5"], 10, "write", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""kind"":""call"",""outcome"":""done"",""rowCount"":0}", "and runs with that one value")
}

/// <p>AC4: in the install namespace a statement over OcuPilot's own tables is found by the statement
/// index -- directly and through a view, whose base tables it records -- and refused
/// <code>PROHIBITED.OCUPILOTSQL</code>; DDL naming one records no table and is refused by its
/// text.</p>
/// <p>An INSERT through the view, whose base table the index leaves out, is found through the view's
/// recorded usage.</p>
/// <p>Mutation (Rule 19): skip rule (b) in <method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method>
/// -- the view leg goes red. Drop the view expansion from <method>OcuPilot.Port.SqlPort.Prepared</method>
/// -- the INSERT leg goes red.</p>
Method TestOcuPilotsOwnTablesAreFoundAndRefused()
{
    For tCase = $ListBuild("SELECT ID FROM OcuPilot_Kernel_State.Proposal", 1), $ListBuild("SELECT ID FROM " _ $Parameter(..#PROBE, "OWNVIEW"), 1), $ListBuild("INSERT INTO " _ $Parameter(..#PROBE, "OWNVIEW") _ " (ID) VALUES (-1)", 1), $ListBuild("DROP TABLE OcuPilot_Kernel_State.Proposal", 0) {
        Set tSC = $ClassMethod(..#PORT, "Classify", $NAMESPACE, $List(tCase, 1), .tGuard, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " is classified")
        If $$$ISERR(tSC) Continue
        Set tTables = ""
        Set tIterator = tGuard.Tables.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTable) {
            Set tTables = tTables _ $ListBuild(tTable)
        }
        Do $$$AssertEquals(''$ListFind(tTables, "OCUPILOT_KERNEL_STATE.PROPOSAL"), $List(tCase, 2), $List(tCase, 1) _ ": the index records OcuPilot's table where it reads it")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).SqlStatement($List(tCase, 1), tTables, tGuard.RecordsTables, .tProhibits, .tCode, tGuard.DefaultSchema)
        Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 PROHIBITED.OCUPILOTSQL", $List(tCase, 1) _ " is refused")
    }
}

/// <p>Fail closed: a query whose statement-index row cannot be read is refused 500
/// <code>INTERNAL</code> before it runs, and the log line the refusal writes carries nothing of the
/// statement (AD-39).</p>
/// <p>Mutation (Rule 19): drop the unindexed refusal from <method>OcuPilot.Port.SqlPort.Classify</method>
/// -- the refusal leg goes red. Put the statement into that refusal's logged status -- the log leg
/// goes red.</p>
Method TestAnUnindexedStatementFailsClosedAndLogsNoText()
{
    Set tMark = "OcuProbe196Log" _ $Translate($ZTimeStamp, ",.", "")
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Set tSC = $ClassMethod(..#UNINDEXED, "Run", ..#NAMESPACE, "SELECT Name FROM OcuProbe196.Granted WHERE Name = '" _ tMark _ "'", [], 10, "query", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "500 INTERNAL", "a query the statement index answers no row for is refused before it runs")
    Set (tLogged, tFound) = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If tLine [ """subsystem"":""sqlport""" Set tLogged = tLine
            If $ZConvert(tLine, "U") [ $ZConvert(tMark, "U") Set tFound = tLine
        }
    }
    Set tStream = ""
    Do $$$AssertNotEquals(tLogged, "", "the refusal wrote its log line")
    Do $$$AssertEquals(tFound, "", "which carries nothing of the statement")
}

/// <p>The default schema of namespace <var>pNamespace</var>, as the instance answers it there.</p>
ClassMethod DefaultSchemaIn(pNamespace As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tSchema = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tSchema = $SYSTEM.SQL.Schema.Default()
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tSchema
}

/// <p>The gate (AD-29): without <code>%Development:USE</code>, or without READ on the namespace's code
/// database, the port refuses 403 <code>AUTH.NOPRIVILEGE</code> naming the pair before any
/// prepare.</p>
Method TestTheGateNamesTheMissingPair()
{
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tUserCode, .tGlobals, .tMapped, .tResolved)
    Set tLegs = [{"op": "classify", "namespace": (..#NAMESPACE), "statement": "SELECT Name FROM OcuProbe196.Granted"}, {"op": "query", "namespace": (..#NAMESPACE), "statement": "SELECT Name FROM OcuProbe196.Granted"}, {"op": "plan", "namespace": (..#NAMESPACE), "statement": "SELECT Name FROM OcuProbe196.Granted"}].%ToJSON()
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "NODEVUSER"), tLegs)
    For tI = 0:1:2 {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, tI), "403 AUTH.NOPRIVILEGE %Development:USE  ", "without %Development:USE, leg " _ tI)
    }
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "NOUSERUSER"), tLegs)
    For tI = 0:1:2 {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, tI), "403 AUTH.NOPRIVILEGE " _ tUserCode _ ":READ  ", "without READ on the namespace's database, leg " _ tI)
    }
}

/// <p>DW-1964: a principal holding <code>%Development:USE</code>, <code>%DB_USER:RW</code> and SELECT
/// on <code>Granted</code> alone reads <code>Granted</code>, and is answered SQLCODE -99 for SELECT,
/// UPDATE, TRUNCATE, CREATE TABLE, CALL and a plan on the other, with nothing changed.</p>
/// <p>Mutation (Rule 19): prepare with privilege checks off in both
/// <method>OcuPilot.Port.SqlPort.Prepared</method> and <method>OcuPilot.Port.SqlPort.Executed</method> --
/// the UPDATE leg changes the table and goes red.</p>
Method TestTheInstanceRefusesAnUngrantedTableAtPrepare()
{
    Set tMade = "OcuProbe196.Made" _ $Translate($ZTimeStamp, ",.", "")
    Set tLegs = [
        {"op": "query", "namespace": "USER", "statement": "SELECT Name FROM OcuProbe196.Granted WHERE Num < 3"},
        {"op": "query", "namespace": "USER", "statement": "SELECT Name FROM OcuProbe196.Hidden"},
        {"op": "write", "namespace": "USER", "statement": "UPDATE OcuProbe196.Hidden SET Num = Num + 10"},
        {"op": "write", "namespace": "USER", "statement": "TRUNCATE TABLE OcuProbe196.Hidden"},
        {"op": "write", "namespace": "USER", "statement": ("CREATE TABLE " _ tMade _ " (X INTEGER)")},
        {"op": "write", "namespace": "USER", "statement": "CALL OcuProbe196.HiddenCount()"},
        {"op": "plan", "namespace": "USER", "statement": "SELECT Name FROM OcuProbe196.Hidden"}
    ].%ToJSON()
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "USER"), tLegs)
    Do $$$AssertEquals($Select($IsObject(tProbe): tProbe.%Get("username"), 1: ""), $Parameter(..#PROBE, "USER"), "the probe ran as the principal: " _ $Select($IsObject(tProbe): tProbe.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, 0), "200   rows ", "it reads the granted table")
    For tI = 1:1:6 {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, tI), "200   error -99", "leg " _ tI _ " is refused at prepare")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted", $Parameter(..#PROBE, "HIDDEN")), "2 3", "the ungranted table is unchanged")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", tMade), "and nothing was created")
}

/// <p>DW-1986: this account prepares, and holds open, two CREATE TABLE and two CREATE PROCEDURE
/// statements, an UPDATE, a CALL and a SELECT on the table the principal holds no privilege on. A held
/// DDL compile answers the next prepare of the same text without the system privilege check the
/// instance makes only when it compiles, so each text is sent once and every leg meets a held compile.
/// The principal, holding none of the privileges, sends each through the console -- one CREATE of each
/// kind classified and one run, the UPDATE and the CALL run, the SELECT queried -- and each is answered
/// SQLCODE -99: nothing is created and the table is unchanged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.SqlPort.PrivilegeFor</method> answering no privilege
/// -- the four DDL legs go red.</p>
Method TestAStatementAnotherAccountHoldsOpenIsStillChecked()
{
    Set tToken = $Translate($ZTimeStamp, ",.", "")
    Set tTables = $ListBuild("OcuProbe196.HeldA" _ tToken, "OcuProbe196.HeldB" _ tToken)
    Set tRoutines = $ListBuild("OcuProbe196.HeldCallA" _ tToken, "OcuProbe196.HeldCallB" _ tToken)
    Set tLegs = [
        {"op": "classify", "namespace": (..#NAMESPACE), "statement": ("CREATE TABLE " _ $List(tTables, 1) _ " (X INTEGER)")},
        {"op": "write", "namespace": (..#NAMESPACE), "statement": ("CREATE TABLE " _ $List(tTables, 2) _ " (X INTEGER)")},
        {"op": "classify", "namespace": (..#NAMESPACE), "statement": ("CREATE PROCEDURE " _ $List(tRoutines, 1) _ "() LANGUAGE OBJECTSCRIPT { Quit }")},
        {"op": "write", "namespace": (..#NAMESPACE), "statement": ("CREATE PROCEDURE " _ $List(tRoutines, 2) _ "() LANGUAGE OBJECTSCRIPT { Quit }")},
        {"op": "write", "namespace": (..#NAMESPACE), "statement": "UPDATE OcuProbe196.Hidden SET Num = Num + 20"},
        {"op": "write", "namespace": (..#NAMESPACE), "statement": "CALL OcuProbe196.HiddenCount()"},
        {"op": "query", "namespace": (..#NAMESPACE), "statement": "SELECT Name, Num FROM OcuProbe196.Hidden"}
    ]
    Set tTexts = ""
    For tI = 0:1:tLegs.%Size() - 1 {
        Set tTexts = tTexts _ $ListBuild(tLegs.%Get(tI).%Get("statement"))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Hold", tTexts, .tHeld), 7, "this account prepares every statement and holds it open")
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "USER"), tLegs.%ToJSON())
    Do $ClassMethod(..#PROBE, "Release", .tHeld)
    For tI = 0:1:6 {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, tI), "200   error -99", "leg " _ tI _ ": the principal is refused")
    }
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", $List(tTables, 2)), "the CREATE TABLE sent to run created no table")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsRoutine", $List(tRoutines, 2)), "and the CREATE PROCEDURE no procedure")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted", $Parameter(..#PROBE, "HIDDEN")), "2 3", "the ungranted table is unchanged")
}

/// <p>DW-1986: a DDL statement this account's console classified, and one it ran, leave no cached
/// compile behind, because the port releases each statement in its own namespace, where the instance
/// purges a one-use statement's cached query as it closes: the principal's own prepare of either text,
/// outside the port, is compiled afresh and refused SQLCODE -99.</p>
/// <p>Mutation (Rule 19): release the statement after restoring the namespace in
/// <method>OcuPilot.Port.SqlPort.Prepared</method> -- the classified leg goes red; in
/// <method>OcuPilot.Port.SqlPort.Executed</method> -- the run leg goes red.</p>
Method TestTheConsoleLeavesNoCachedDdlCompileBehind()
{
    Set tToken = $Translate($ZTimeStamp, ",.", "")
    Set tClassified = "CREATE TABLE OcuProbe196.Left" _ tToken _ " (X INTEGER)"
    Set tRan = "CREATE PROCEDURE OcuProbe196.LeftCall" _ tToken _ "() LANGUAGE OBJECTSCRIPT { Quit }"
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, tClassified, .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.Kind, 1: ..Said(tSC, "", .tHttp, .tFault)), "ddl", "this account's console classifies a CREATE TABLE")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, tRan, [], 10, "write", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""kind"":""ddl"",""outcome"":""done"",""rowCount"":0}", "and runs a CREATE PROCEDURE")
    Set tLegs = [{"op": "prepare", "namespace": (..#NAMESPACE), "statement": (tClassified)}, {"op": "prepare", "namespace": (..#NAMESPACE), "statement": (tRan)}].%ToJSON()
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", $Parameter(..#PROBE, "USER"), tLegs)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, 0), "200   error -99", "the classified text is compiled afresh for the principal")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegText", tProbe, 1), "200   error -99", "and so is the text that ran")
}

}
