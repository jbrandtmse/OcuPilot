/// <p>Pins Story 21.27's advice (AC3, AC4; AD-3, AD-21, AD-36, AD-60): <class>OcuPilot.Port.SqlAdvice</class>'s findings over the plans an instance of this
/// build gave a probe schema, one leg for each kind and for the plans that hold nothing to advise on or that it does not recognize; the sentences, which are
/// the ruled templates filled with names read from the plan; the answer of <code>explorer.sqladvice.read</code> and of SQL query's Advise route for the same
/// statement, which are the same plan and the same findings; a statement that is not a query refused before the plan is read; OcuPilot's own tables refused
/// by the console's check; and the two dictionary reads, which bind the names they are given.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, the calling
/// account holding <code>%Development:USE</code> and READ and WRITE on <code>USER</code>'s code databases, and a <code>USER</code> namespace, where the live
/// tests make <class>OcuPilot.Test.SqlTuningProbe</class>'s advice table and remove it after. It gathers nothing and touches no analyzer store.</p>
Class OcuPilot.Test.SqlAdviceRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter ADVISOR = "OcuPilot.Port.SqlAdvice";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerSqlAdviceRead";

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter ERROR = "OcuPilot.Api.AtelierError";

Parameter NAMESPACE = "USER";

Parameter PLAN = "/api/ocupilot/explorer/sql/plan";

Parameter QUERY = "SELECT A FROM OcuProbe227Advice.T WHERE B = 'x'";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ^||OcuPilotSqlTuningAdvisor
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAdvice", ..#NAMESPACE), "the advice probe's table is removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AdviceState", ..#NAMESPACE), "0|", "and reads back absent")
    Quit $$$OK
}

/// <p>The lines of a plan joined by CR LF, as the instance writes one.</p>
ClassMethod Joined(pLines As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pLines) Set tText = tText _ $Select(tI = 1: "", 1: $Char(13, 10)) _ $List(pLines, tI)
    Quit tText
}

/// <p>A plan as the instance writes one: the statement, a warning when <var>pWarning</var> is not empty, the cost, and <var>pBody</var>, the lines under
/// <code>Module-FIRST:</code>.</p>
ClassMethod Shaped(pStatement As %String, pWarning As %String, pCost As %String, pBody As %List) As %String
{
    Set tLines = $ListBuild("<plans>", " <plan>", "   SQL:", "    " _ pStatement, "   ")
    If pWarning '= "" Set tLines = tLines _ $ListBuild("   Warning:", "   " _ pWarning, "   ")
    Set tLines = tLines _ $ListBuild("   Cost: " _ pCost, "   ", "   Module-FIRST:") _ pBody _ $ListBuild(" </plan>", "</plans>")
    Quit ..Joined(tLines)
}

/// <p>The ten plans this build gave the probe schema <code>ZZProbe227</code> (<code>Tbl</code>: <code>Name</code>, <code>Code</code>, <code>Amt</code>
/// and the index <code>IdxAmt</code>; <code>Tbl2</code>: <code>Code</code>), byte for byte, by the name of the capture.</p>
ClassMethod Fixture(pName As %String) As %String
{
    Set tWarn = "Table ZZProbe227.Tbl is not tuned."
    Set tScan = $ListBuild("     Module-B:", "     Read master map ZZProbe227.Tbl.IDKEY, looping on ID.", "     For each row:", "         Test the = condition on %SQLUPPER(Name) and the NOT NULL condition on %SQLUPPER(Name).", "         Output the row.")
    Set tName = "SELECT ID FROM ZZProbe227 . Tbl WHERE Name = ? /*#OPTIONS {""DynamicSQLTypeList"":""1""} */"
    Set tAmt = "SELECT ID FROM ZZProbe227 . Tbl WHERE Amt = ? /*#OPTIONS {""DynamicSQLTypeList"":""10""} */"
    Set tIndex = $ListBuild("     Module-B:", "     Read index map ZZProbe227.Tbl.IdxAmt, using the given Amt, and looping on ID.", "     For each row:", "         Output the row.")
    Set tJoin = "SELECT a . ID FROM ZZProbe227 . Tbl a , ZZProbe227 . Tbl2 b WHERE a . Code = b . Code"
    If pName = "fullscan-notuned" Quit ..Shaped(tName, tWarn, "1333600", tScan)
    If pName = "fullscan-tuned" Quit ..Shaped(tName, "", "2200", tScan)
    If pName = "indexmap-notuned" Quit ..Shaped(tAmt, tWarn, "2732", tIndex)
    If pName = "indexmap-tuned" Quit ..Shaped(tAmt, "", "206.66", tIndex)
    If pName = "tempfile-groupby" Quit ..Shaped("SELECT Code , COUNT ( * ) FROM ZZProbe227 . Tbl GROUP BY Code ORDER BY Code", tWarn, "4655216", $ListBuild("   Call Module-B, which populates temp-file B.", "     Module-B:", "     Read master map ZZProbe227.Tbl.IDKEY, looping on ID.", "     For each row:", "           Module-C:", "           Check distinct values for %SQLUPPER(Code) using temp-file B,", "               subscripted by %SQLUPPER(Code).", "           For each distinct row:", "               Add a row to temp-file B, subscripted by %SQLUPPER(Code),", "                   with no node data.", "         Update the accumulated count(rows) in temp-file B,", "             subscripted by %SQLUPPER(Code)", "     Module-D:", "     Read temp-file B, looping on %SQLUPPER(Code).", "     For each row:", "         Output the row."))
    If pName = "tempfile-orderby-indexrange" Quit ..Shaped("SELECT ID FROM ZZProbe227 . Tbl WHERE Amt > ? ORDER BY Code /*#OPTIONS {""DynamicSQLTypeList"":""10""} */", tWarn, "825020", $ListBuild("   Call Module-C, which populates temp-file B.", "     Module-C:", "     Call Module-B, which populates bitmap temp-file A.", "       Module-B:", "       Read index map ZZProbe227.Tbl.IdxAmt, looping on Amt (with a range condition) and ID.", "       For each row:", "           Add ID bit to bitmap temp-file A.", "     Read bitmap temp-file A, looping on ID.", "     For each row:", "         Read master map ZZProbe227.Tbl.IDKEY, using the given idkey value.", "         Add a row to temp-file B, subscripted by %SQLUPPER(Code) and ID,", "             with no node data.", "     Module-D:", "     Read temp-file B, looping on %SQLUPPER(Code) and ID.", "     For each row:", "         Output the row."))
    If pName = "join-tempfile-twotables" Quit ..Shaped(tJoin, "Tables ZZProbe227.Tbl and ZZProbe227.Tbl2 are not tuned.", "166281416", $ListBuild("     Module-B:", "     Read master map ZZProbe227.Tbl(A).IDKEY, looping on A.ID.", "     For each row:", "           Module-D:", "           Call Module-C once, which populates temp-file A.", "             Module-C:", "             Read master map ZZProbe227.Tbl2(B).IDKEY, looping on B.ID.", "             For each row:", "                 Test the NOT NULL condition on %SQLUPPER(Code).", "                 Add a row to temp-file A, subscripted by %SQLUPPER(Code) and B.ID,", "                     with no node data.", "           Read temp-file A, using the given %SQLUPPER(Code), and looping on B.ID.", "           For each row:", "               Output the row."))
    If pName = "join-onetuned" Quit ..Shaped(tJoin, "Table ZZProbe227.Tbl2 is not tuned.", "1834656", $ListBuild("     Module-B:", "     Read master map ZZProbe227.Tbl2(B).IDKEY, looping on B.ID.", "     For each row:", "         Test the NOT NULL condition on %SQLUPPER(Code).", "           Module-D:", "           Call Module-C once, which populates temp-file A.", "             Module-C:", "             Read master map ZZProbe227.Tbl(A).IDKEY, looping on A.ID.", "             For each row:", "                 Add a row to temp-file A, subscripted by %SQLUPPER(Code) and A.ID,", "                     with no node data.", "           Read temp-file A, using the given %SQLUPPER(Code), and looping on A.ID.", "           For each row:", "               Output the row."))
    If pName = "multicond-bitmap" Quit ..Shaped("SELECT ID FROM ZZProbe227 . Tbl WHERE Name = ? AND Code = ? AND Amt > ? /*#OPTIONS {""DynamicSQLTypeList"":""1,1,10""} */", tWarn, "693062", $ListBuild("     Module-C:", "     Call Module-B, which populates bitmap temp-file A.", "       Module-B:", "       Read index map ZZProbe227.Tbl.IdxAmt, looping on Amt (with a range condition) and ID.", "       For each row:", "           Add ID bit to bitmap temp-file A.", "     Read bitmap temp-file A, looping on ID.", "     For each row:", "         Read master map ZZProbe227.Tbl.IDKEY, using the given idkey value.", "         Test the = condition on %SQLUPPER(Code), the = condition on %SQLUPPER(Name), the NOT NULL condition on %SQLUPPER(Code), and the NOT NULL condition on %SQLUPPER(Name).", "         Output the row."))
    If pName = "constant-nowarning" Quit ..Shaped("SELECT ? /*#OPTIONS {""DynamicSQLTypeList"":""10""} */", "", "600400", $ListBuild("     Module-B:", "     Read master map %TSQL_sys.snf.Map1, looping on ID.", "     For each row:", "         Output the row."))
    Quit ""
}

/// <p>The index rows of <code>ZZProbe227.Tbl</code> as the dictionary answers them: its key, and <code>IdxAmt</code> on <code>Amt</code>.</p>
ClassMethod Probe(pExtra As %String = "") As %DynamicArray
{
    Set tRows = [{"Name": "IDKEY", "Properties": "", "Type": "key", "PrimaryKey": false, "IdKey": true}, {"Name": "IdxAmt", "Properties": "Amt", "Type": "index", "PrimaryKey": false, "IdKey": false}]
    If pExtra '= "" Do tRows.%Push({}.%FromJSON(pExtra))
    Quit [{"Schema": "ZZProbe227", "Table": "Tbl", "Rows": (tRows)}]
}

/// <p><var>pPlan</var> without the instance's warning about a process whose collation differs from the temporary database's, which the plan of a web
/// process can carry and a job's does not.</p>
ClassMethod WithoutCollationWarning(pPlan As %String) As %String
{
    Set tText = ""
    For tI = 1:1:$Length(pPlan, $Char(10)) {
        Set tLine = $Piece(pPlan, $Char(10), tI)
        If tLine '[ "The NLS Collation" Set tText = tText _ tLine _ $Char(10)
    }
    Quit tText
}

/// <p>The kinds of <var>pFindings</var>, in order, comma separated.</p>
ClassMethod Kinds(pFindings As %DynamicArray) As %String
{
    Set tKinds = ""
    Set tIterator = pFindings.%GetIterator()
    While tIterator.%GetNext(.tKey, .tFinding) {
        Set tKinds = tKinds _ $Select(tKinds = "": "", 1: ",") _ tFinding.Kind
    }
    Quit tKinds
}

/// <p>The first finding of <var>pKind</var> in <var>pFindings</var>, or <code>{}</code>.</p>
ClassMethod Find(pFindings As %DynamicArray, pKind As %String) As %DynamicObject
{
    Set tFound = {}
    Set tIterator = pFindings.%GetIterator()
    While tIterator.%GetNext(.tKey, .tFinding) {
        If tFinding.Kind = pKind {
            Set tFound = tFinding
            Quit
        }
    }
    Quit tFound
}

/// <p>A full table scan is a finding with the ruled sentence, and with it a missing index named for the field the condition tests, a table the plan reports
/// as not tuned, and an index the plan does not read, each with its table, its sentences filled from names the plan and the dictionary gave, and the plan
/// text it was read from.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlAdvice.Findings</code> compares no leading field -> the missing-index leg of
/// <method>TestTheLeadingFieldDecidesWhetherAnIndexIsMissing</method> goes red; <code>Filled</code> fills <code>%1</code> from the fields -> the
/// sentence assertions go red.</p>
Method TestAFullScanComesWithMissingIndexNotTunedAndUnusedIndex()
{
    Set tPlan = ..Fixture("fullscan-notuned")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tPlan, ..Probe(), .tCut)
    Do $$$AssertEquals(..Kinds(tFindings) _ "|" _ tCut, "fullscan,missingindex,nottuned,unusedindex|0", "the four kinds the plan holds, in order, none cut")
    Set tScan = ..Find(tFindings, "fullscan")
    Do $$$AssertEquals(tScan.Confidence _ "|" _ tScan.Table _ "|" _ tScan.Excerpt, "medium|ZZProbe227.Tbl|Read master map ZZProbe227.Tbl.IDKEY, looping on ID.", "a full scan is medium and carries the line that reads the map")
    Do $$$AssertEquals(tScan.Detail _ "|" _ tScan.Recommendation, "The plan reads every row of ZZProbe227.Tbl and tests a condition on each one.|Check whether an index on the condition's fields would let the plan skip this scan.", "with its ruled sentences")
    Set tMissing = ..Find(tFindings, "missingindex")
    Do $$$AssertEquals(tMissing.Confidence _ "|" _ tMissing.Fields _ "|" _ tMissing.Detail, "high|Name|No index on ZZProbe227.Tbl starts with Name, which the statement's conditions test.", "the missing index is high for one equality condition, naming the field")
    Do $$$AssertEquals(tMissing.Recommendation, "Consider an index on ZZProbe227.Tbl that starts with Name, then explain the plan again.", "and advises no DDL, only the table and the field")
    Set tTuned = ..Find(tFindings, "nottuned")
    Do $$$AssertEquals(tTuned.Confidence _ "|" _ tTuned.Table _ "|" _ tTuned.Detail _ "|" _ tTuned.Recommendation _ "|" _ tTuned.Excerpt, "low|ZZProbe227.Tbl|The plan reports that ZZProbe227.Tbl has not been tuned, so the optimizer has no statistics for it.|Tune the table so the optimizer can choose a better plan.|Table ZZProbe227.Tbl is not tuned.", "the not-tuned warning is read into its table and sentences")
    Set tUnused = ..Find(tFindings, "unusedindex")
    Do $$$AssertEquals(tUnused.Confidence _ "|" _ tUnused.Table _ "|" _ tUnused.Index _ "|" _ tUnused.Fields _ "|" _ tUnused.Detail, "low|ZZProbe227.Tbl|IdxAmt|Amt|This statement's plan does not use the index IdxAmt on ZZProbe227.Tbl.", "the index the plan never reads is named")
    Do $$$AssertEquals(tUnused.Recommendation _ "|" _ tUnused.Excerpt, "Check that no other statement uses it before you remove it.|Read master map ZZProbe227.Tbl.IDKEY", "with its sentence and the map reads the plan does hold")
    Set tTables = $ClassMethod(..#ADVISOR, "Tables", tPlan)
    Do $$$AssertEquals(tTables.%ToJSON(), "[{""Schema"":""ZZProbe227"",""Table"":""Tbl""}]", "the plan reads one table")
    Do $$$AssertEquals($ClassMethod(..#ADVISOR, "Filled", "%1 %2 %3", "A%2B", "X", "Y%1"), "A%2B X Y%1", "a name that holds a mark is not filled in again")
    Set tWarned = ..Shaped("SELECT ID FROM ZZProbe227 . Tbl", "The NLS Collation for the globals in the 'IRISTEMP' database (5) is different than that of the current process (30)." _ $Char(13, 10) _ "   Table ZZProbe227.Tbl is not tuned.", "1", $ListBuild("     Module-B:", "     Read index map ZZProbe227.Tbl.IdxAmt, using the given Amt, and looping on ID."))
    Do $$$AssertEquals(..Kinds($ClassMethod(..#ADVISOR, "Findings", tWarned, ..Probe())), "nottuned", "a not-tuned warning that follows another warning is read")
}

/// <p>A missing index is judged by each index's first field: an index that starts with the condition's field answers it, whatever its collation or case,
/// and one that has the field second does not. A key's own field counts as an index's first. A table whose indices could not be listed, or that no class
/// holds, has none of the index findings, and the scan finding stays.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlAdvice.Leading</code> takes every field of an index -> the second-field leg goes red; the missing-index check
/// is dropped -> the first leg goes red.</p>
Method TestTheLeadingFieldDecidesWhetherAnIndexIsMissing()
{
    Set tPlan = ..Fixture("fullscan-tuned")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tPlan, ..Probe("{""Name"":""IdxName"",""Properties"":""NAME:EXACT,Amt"",""Type"":""index"",""PrimaryKey"":false,""IdKey"":false}"))
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan,unusedindex,unusedindex", "an index that starts with the field, in another case and with a collation, answers the condition")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tPlan, ..Probe("{""Name"":""IdxAmtName"",""Properties"":""Amt,Name"",""Type"":""index"",""PrimaryKey"":false,""IdKey"":false}"))
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan,missingindex,unusedindex,unusedindex", "an index that has the field second does not")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tPlan, [{"Schema": "ZZProbe227", "Table": "Tbl", "Rows": null}])
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan", "a table whose indices could not be listed gets the scan and neither index finding")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tPlan, [])
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan", "and so does one the dictionary holds no class for")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tPlan, [{"Schema": "ZZProbe227", "Table": "Tbl", "Rows": [{"Name": "IDKEY", "Properties": "", "Type": "key", "PrimaryKey": false, "IdKey": true}, {"Name": "Extent", "Properties": "", "Type": "bitmap", "PrimaryKey": false, "IdKey": false}, {"Name": "PKey", "Properties": "Amt", "Type": "index", "PrimaryKey": true, "IdKey": false}]}])
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan,missingindex", "a key, a primary key and an index with no field are never called unused")
}

/// <p>The confidence of a missing index is high for one field tested only by equality, and medium for a range, for several fields, or an equality beside a
/// range on the same field; a plan that tests no condition has no full scan, and one that tests only that a field is not null has the scan and no missing index.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlAdvice.Findings</code> answers high for every missing index -> the medium legs go red.</p>
Method TestTheConfidenceOfAMissingIndexFollowsItsConditions()
{
    Set tHead = $ListBuild("     Module-B:", "     Read master map ZZProbe227.Tbl.IDKEY, looping on ID.", "     For each row:")
    Set tTail = $ListBuild("         Output the row.")
    For tCase = $ListBuild("= condition on %SQLUPPER(Name)", "high", "Name"), $ListBuild("> condition on %SQLUPPER(Name)", "medium", "Name"), $ListBuild("= condition on %SQLUPPER(Name), the > condition on %SQLUPPER(Name)", "medium", "Name"), $ListBuild("= condition on %SQLUPPER(Name), the = condition on %SQLUPPER(Code)", "medium", "Name, Code"), $ListBuild("= condition on Name", "high", "Name") {
        Set tPlan = ..Shaped("SELECT ID FROM ZZProbe227 . Tbl", "", "1", tHead _ $ListBuild("         Test the " _ $List(tCase, 1) _ ".") _ tTail)
        Set tMissing = ..Find($ClassMethod(..#ADVISOR, "Findings", tPlan, ..Probe()), "missingindex")
        Do $$$AssertEquals(tMissing.Confidence _ "|" _ tMissing.Fields, $List(tCase, 2) _ "|" _ $List(tCase, 3), "Test the " _ $List(tCase, 1))
    }
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", ..Shaped("SELECT ID FROM ZZProbe227 . Tbl", "", "1", tHead _ $ListBuild("         Test the NOT NULL condition on %SQLUPPER(Name).") _ tTail), ..Probe())
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan,unusedindex", "a NOT NULL test alone is a scan and names no missing index")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", ..Shaped("SELECT ID FROM ZZProbe227 . Tbl", "", "1", tHead _ tTail), ..Probe())
    Do $$$AssertEquals(..Kinds(tFindings), "unusedindex", "a plan that tests no condition has no scan finding")
}

/// <p>The plans this build gave for tuned and indexed tables hold nothing to advise on: the scan of a tuned table has no not-tuned finding, an index read
/// is not an unused index, a constant reads only a system table, and a plan read through an index and a bitmap names only the warning. A plan with no marker
/// the advice reads is not recognized, and a plan that names one is.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlAdvice.Recognized</code> answers 1 -> the unrecognized assertion goes red.</p>
Method TestPlansWithNothingToAdviseOnAndPlansItDoesNotRecognize()
{
    Set tTuned = $ClassMethod(..#ADVISOR, "Findings", ..Fixture("fullscan-tuned"), ..Probe())
    Do $$$AssertTrue(..Kinds(tTuned) '[ "nottuned", "a tuned table has no not-tuned finding: " _ ..Kinds(tTuned))
    For tName = "indexmap-tuned", "constant-nowarning" {
        Set tPlan = ..Fixture(tName)
        Set tFound = ##class(OcuPilot.Port.SqlAdvice).Findings(tPlan, $Select(tName = "indexmap-tuned": ..Probe(), 1: []))
        Do $$$AssertTrue($ClassMethod(..#ADVISOR, "Recognized", tPlan), tName _ " is recognized")
        Do $$$AssertEquals(tFound.%Size(), 0, tName _ " holds nothing to advise on")
    }
    Do $$$AssertEquals(..Kinds($ClassMethod(..#ADVISOR, "Findings", ..Fixture("indexmap-notuned"), ..Probe())), "nottuned", "an index read answers the warning and no unused index")
    Do $$$AssertEquals(..Kinds($ClassMethod(..#ADVISOR, "Findings", ..Fixture("multicond-bitmap"), ..Probe())), "nottuned", "a read through a bitmap of the index names only the warning")
    Set tTables = ##class(OcuPilot.Port.SqlAdvice).Tables(..Fixture("constant-nowarning"))
    Do $$$AssertEquals(tTables.%ToJSON(), "[{""Schema"":""%TSQL_sys"",""Table"":""snf""}]", "a constant's plan reads a system map")
    Set tNothing = "This is not a plan. Hello."
    Set tNone = ##class(OcuPilot.Port.SqlAdvice).Findings(tNothing, ..Probe())
    Set tNoTables = ##class(OcuPilot.Port.SqlAdvice).Tables(tNothing)
    Do $$$AssertEquals($ClassMethod(..#ADVISOR, "Recognized", tNothing) _ "|" _ $ClassMethod(..#ADVISOR, "Recognized", "") _ "|" _ tNone.%Size() _ "|" _ tNoTables.%Size(), "0|0|0|0", "text with no marker is not recognized and has no table or finding")
    Do $$$AssertTrue($ClassMethod(..#ADVISOR, "Recognized", "Module-FIRST:" _ $Char(13, 10) _ "  Output the row."), "a plan with a module and no map is recognized")
}

/// <p>A temporary file is one low finding that carries every line that builds or reads one, the bitmap temporary files of an index range left out, and the
/// plural warning of a join names each of its tables; a join's aliased scans are two scans, and a table that is tuned is left out.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlAdvice.TEMPFILEPATTERN</code> drops <code>(?: once)?</code> -> the join leg goes red; the warning pattern reads
/// only <code>Table</code> -> the plural leg goes red.</p>
Method TestTemporaryFilesAndJoinsAreRead()
{
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", ..Fixture("tempfile-groupby"), ..Probe())
    Do $$$AssertEquals(..Kinds(tFindings), "nottuned,tempfile,unusedindex", "a group by builds a temporary file and has no condition to scan on")
    Set tTemp = ..Find(tFindings, "tempfile")
    Do $$$AssertEquals(tTemp.Confidence _ "|" _ tTemp.Table _ "|" _ tTemp.Detail, "low||The plan builds a temporary file, as a GROUP BY, an ORDER BY or a join can need.", "it is low and names no table")
    Do $$$AssertEquals(tTemp.Recommendation _ "|" _ tTemp.Excerpt, "Check whether an index could serve the grouping, ordering or join so the plan needs no temporary file.|Call Module-B, which populates temp-file B." _ $Char(10) _ "Read temp-file B, looping on %SQLUPPER(Code).", "with its sentence and the two lines of the plan")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", ..Fixture("tempfile-orderby-indexrange"), ..Probe())
    Do $$$AssertEquals(..Kinds(tFindings), "nottuned,tempfile", "an order by over an index range builds one, and its index is read")
    Do $$$AssertEquals(..Find(tFindings, "tempfile").Excerpt, "Call Module-C, which populates temp-file B." _ $Char(10) _ "Read temp-file B, looping on %SQLUPPER(Code) and ID.", "the bitmap temporary files are not among its lines")
    Set tJoin = ..Fixture("join-tempfile-twotables")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tJoin, [{"Schema": "ZZProbe227", "Table": "Tbl", "Rows": []}, {"Schema": "ZZProbe227", "Table": "Tbl2", "Rows": []}])
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan,fullscan,nottuned,nottuned,tempfile", "a join scans both tables, names both as not tuned and builds a temporary file")
    Do $$$AssertEquals(..Find(tFindings, "nottuned").Table _ "|" _ ..Find(tFindings, "nottuned").Excerpt, "ZZProbe227.Tbl|Tables ZZProbe227.Tbl and ZZProbe227.Tbl2 are not tuned.", "the plural warning is read, and carried whole")
    Do $$$AssertTrue(..Find(tFindings, "tempfile").Excerpt [ "Call Module-C once, which populates temp-file A.", "a temporary file the plan builds once is read")
    Set tTables = ##class(OcuPilot.Port.SqlAdvice).Tables(tJoin)
    Do $$$AssertEquals(tTables.%ToJSON(), "[{""Schema"":""ZZProbe227"",""Table"":""Tbl""},{""Schema"":""ZZProbe227"",""Table"":""Tbl2""}]", "a join's alias is dropped from each table")
    Set tAliased = $Replace($Replace(tJoin, "(A)", "(A_1)"), "(B)", "(B_2)")
    Do $$$AssertTrue(tAliased '= tJoin, "the join fixture carries the aliases A and B")
    Do $$$AssertEquals(##class(OcuPilot.Port.SqlAdvice).Tables(tAliased).%ToJSON(), tTables.%ToJSON(), "an alias holding an underscore is dropped as well")
    Do $$$AssertEquals(..Kinds($ClassMethod(..#ADVISOR, "Findings", tAliased, [{"Schema": "ZZProbe227", "Table": "Tbl", "Rows": []}, {"Schema": "ZZProbe227", "Table": "Tbl2", "Rows": []}])), "fullscan,fullscan,nottuned,nottuned,tempfile", "and both of its tables' scans are still findings")
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", ..Fixture("join-onetuned"), [])
    Do $$$AssertEquals(..Find(tFindings, "nottuned").Table, "ZZProbe227.Tbl2", "of the two tables only the one the plan names as not tuned is a finding")
}

/// <p>A table in a system schema is scanned and never advised an index on; the findings stop at <parameter>MAXFINDINGS</parameter> and say so.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlAdvice.Add</code> never cuts -> the cap assertion goes red.</p>
Method TestSystemTablesAreNeverAdvisedAnIndexAndTheFindingsAreCapped()
{
    Set tPlan = ..Shaped("SELECT 1 FROM INFORMATION_SCHEMA.TABLES", "", "1", $ListBuild("     Module-B:", "     Read master map INFORMATION_SCHEMA.TABLES.Master, looping on SchemaExact and TableExact.", "     For each row:", "         Test the = condition on %SQLUPPER(TABLE_NAME).", "         Output the row."))
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", tPlan, [{"Schema": "INFORMATION_SCHEMA", "Table": "TABLES", "Rows": [{"Name": "Idx", "Properties": "Other", "Type": "index", "PrimaryKey": false, "IdKey": false}]}])
    Do $$$AssertEquals(..Kinds(tFindings), "fullscan", "a scan of a system table is a finding and no index is advised on it")
    Set tMax = $Parameter(..#ADVISOR, "MAXFINDINGS")
    Set tRows = []
    For tI = 1:1:tMax Do tRows.%Push({"Name": ("Idx" _ tI), "Properties": "Amt", "Type": "index", "PrimaryKey": false, "IdKey": false})
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", ..Fixture("indexmap-tuned"), [{"Schema": "ZZProbe227", "Table": "Tbl", "Rows": (tRows)}], .tCut)
    Do $$$AssertEquals(tFindings.%Size() _ "|" _ tCut, tMax _ "|0", "exactly the cap's unused indices answer every finding and no cut")
    Do tRows.%Push({"Name": ("Idx" _ (tMax + 1)), "Properties": "Amt", "Type": "index", "PrimaryKey": false, "IdKey": false})
    Set tFindings = $ClassMethod(..#ADVISOR, "Findings", ..Fixture("indexmap-tuned"), [{"Schema": "ZZProbe227", "Table": "Tbl", "Rows": (tRows)}], .tCut)
    Do $$$AssertEquals(tFindings.%Size() _ "|" _ tCut, tMax _ "|1", "one unused index past the cap answers the cap's findings and reports the cut")
}

/// <p>The tool declares its name, kind and statement alone, ends its description with the ruled note, and answers a result its schema admits. Its screen is
/// SQL query, so the screen's context lists it beside the query read.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlAdviceRead.DESCRIPTION</code> loses the note -> the description assertion goes red.</p>
Method TestTheToolDeclaresItsShape()
{
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $Parameter(tTool, "KIND") _ "|" _ $Parameter(tTool, "DESCRIPTORCLASS"), "explorer.sqladvice.read|read|OcuPilot.Screen.Descriptor.ExplorerSqlQuery", "named, a read, and gated as SQL query is")
    Do $$$AssertTrue($Parameter(tTool, "DESCRIPTION") [ "Advice is read from this one plan and its tables' indices. Check it against the real workload.", "its description carries the ruled note")
    Set tSchema = $ClassMethod(tTool, "InputSchema")
    Do $$$AssertEquals(tSchema.properties.%ToJSON() [ "statement", 1, "it takes a statement")
    Do $$$AssertEquals(tSchema.required.%ToJSON() _ "|" _ (tSchema.properties.%Size() = 1) _ "|" _ (tSchema.properties.%Get("parameters") = ""), "[""statement""]|1|1", "and nothing else: the plan is read without values")
}

/// <p>The agent's read and SQL query's Advise route answer the same plan and the same findings for the probe table's query: a full table scan, a missing
/// index on the unindexed field, a table not tuned and the two indices the plan does not read, each with its sentences; and both answers hold the table and its
/// class. The answer conforms to the tool's result schema, and the table and its row are as they were.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Plan</code> answers the advice with no findings -> both callers' assertions go red;
/// <code>OcuPilot.Area.Explorer.SqlConsole.Body</code> refuses the <code>advise</code> key -> the route leg goes red.</p>
Method TestTheProbeTableAnswersTheSameFindingsOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeAdvice", ..#NAMESPACE), "the advice probe's table is made")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": (..#QUERY)}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISERR(tSC): "refused " _ tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), 1: tHttp _ " " _ tResult.outcome), "200 plan", "the agent's read answers a plan")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "ResultSchema"), tResult, .tProblem), "the answer conforms to the tool's result schema: " _ $Get(tProblem))
    Do $$$AssertEquals(tResult.kind _ "|" _ tResult.namespace _ "|" _ tResult.tables.%ToJSON(), "query|" _ ..#NAMESPACE _ "|[""OCUPROBE227ADVICE.T""]", "typed a query in the scope's namespace")
    Do ..Post({"statement": (..#QUERY), "advise": true}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.outcome, 1: ""), "200 plan", "SQL query's Advise route answers a plan")
    If '$IsObject(tAnswer) Quit
    Set tAdvice = tResult.advice
    Do $$$AssertEquals(tAdvice.recognized _ "|" _ tAdvice.truncated _ "|" _ tAdvice.tables.%ToJSON(), "1|0|[{""Schema"":""OcuProbe227Advice"",""Table"":""T"",""Class"":""OcuProbe227Advice.T""}]", "the plan is recognized and its one table resolves to its class")
    Do $$$AssertEquals(..Kinds(tAdvice.findings), "fullscan,missingindex,nottuned,unusedindex,unusedindex", "a scan, a missing index, a table not tuned and the two indices nothing reads")
    Set tMissing = ..Find(tAdvice.findings, "missingindex")
    Do $$$AssertEquals(tMissing.Confidence _ "|" _ tMissing.Table _ "|" _ tMissing.Fields, "high|OcuProbe227Advice.T|B", "the missing index is high, for the unindexed field")
    Do $$$AssertTrue(tAdvice.findings.%Get(4).Index '= tAdvice.findings.%Get(3).Index, "the two unused indices are told apart")
    Do $$$AssertEquals(tAnswer.advice.%ToJSON(), tAdvice.%ToJSON(), "the screen's findings are the agent's, word for word")
    Do $$$AssertEquals(..WithoutCollationWarning(tAnswer.plan), ..WithoutCollationWarning(tResult.plan), "and so is the plan, but for the instance's collation warning, which a web process can add")
    Do $$$AssertTrue(tResult.plan [ "Read master map OcuProbe227Advice.T.IDKEY, looping on ID.", "which reads the table's master map")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AdviceState", ..#NAMESPACE), "1|x", "the table is there and its row is unchanged")
    Do ..Post({"statement": (..#QUERY)}, .tStatus, .tPlain)
    Do $$$AssertTrue(tPlain.%GetTypeOf("advice") = "unassigned", "a plan asked without advise carries none")
}

/// <p>The advice answer says when its tables were cut at the table cap: a plan over two tables answers both and no cut, and the same plan under a cap of one
/// answers the first table alone and the cut, which SQL query states.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Advised</code> answers <code>truncated</code> from the findings' cut alone -> the cap leg goes red.</p>
Method TestTheAdviceSaysWhenItsTablesAreCut()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeAdvice", ..#NAMESPACE), "the advice probe's table is made")
    Set tQuery = "SELECT T.ID FROM OcuProbe227Advice.T T, %Dictionary.ClassDefinition C WHERE C.Description = T.B"
    Set tFixture = "OcuPilot.Test.SqlTuningPortFixture"
    Set tSC = $ClassMethod(tFixture, "Plan", ..#NAMESPACE, tQuery, .tAnswer, .tHttp, .tFault, 0, 1)
    Do $$$AssertStatusOK(tSC, "the two-table plan is advised")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.advice.tables.%Size() _ "|" _ tAnswer.advice.truncated, "2|0", "two tables under the production cap, and no cut")
    Set ^||OcuPilotSqlTuningAdvisor = "OcuPilot.Test.SqlAdviceOneTable"
    Set tSC = $ClassMethod(tFixture, "Plan", ..#NAMESPACE, tQuery, .tAnswer, .tHttp, .tFault, 0, 1)
    Do $$$AssertStatusOK(tSC, "and advised again under a cap of one")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.advice.tables.%Size() _ "|" _ tAnswer.advice.truncated, "1|1", "one table past the cap is cut and the answer says so")
}

/// <p>A statement that is not a query is refused 422 <code>EXPLORER.SQL.ADVICE</code> with the published sentence on both callers, and the data it would have
/// changed is as it was; OcuPilot's own table is refused 403 by the console's check, first; and Advise with statistics is refused as input.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Plan</code> skips the query-only check -> the UPDATE legs go red.</p>
Method TestAStatementThatIsNotAQueryAndOwnTablesAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeAdvice", ..#NAMESPACE), "the advice probe's table is made")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tUpdate = "UPDATE OcuProbe227Advice.T SET B = 'changed'"
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": (tUpdate)}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tHttp _ " " _ tFault.code _ " " _ tFault.reason, 1: tHttp), "422 EXPLORER.SQL.ADVICE " _ $Parameter(..#ERROR, "REASONSQLADVICE"), "the agent's read refuses an UPDATE with the ruled sentence")
    Do ..Post({"statement": (tUpdate), "advise": true}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), "422 EXPLORER.SQL.ADVICE " _ $Parameter(..#ERROR, "REASONSQLADVICE"), "so does the route")
    Set tSC = $ClassMethod(..#PORT, "Plan", ..#NAMESPACE, tUpdate, .tAnswer, .tHttp, .tFault, 0, 1)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ tHttp _ "|" _ $IsObject(tAnswer), "1|422|0", "and the port, which answers no plan")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AdviceState", ..#NAMESPACE), "1|x", "the row is as it was")
    Set tOwn = "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Version"
    Do ##class(OcuPilot.Kernel.Scope).Set($NAMESPACE)
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": (tOwn)}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tHttp _ " " _ tFault.code, 1: tHttp), "403 PROHIBITED.OCUPILOTSQL", "OcuPilot's own table is refused by the console's check")
    Do ..Post({"statement": (tOwn), "advise": true}, .tStatus, .tAnswer, $NAMESPACE)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "403 PROHIBITED.OCUPILOTSQL", "on the route too")
    Do ..Post({"statement": (..#QUERY), "advise": true, "stats": true}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "400 EXPLORER.SQL.INPUT", "Advise with Plan with statistics is refused as input")
    Do ..Post({"statement": (..#QUERY), "advise": "yes"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "400 EXPLORER.SQL.INPUT", "and so is an advise that is not a boolean")
    Do ..Post({"statement": (..#QUERY), "advise": true}, .tStatus, .tAnswer, , "/api/ocupilot/explorer/sql/run")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "400 EXPLORER.SQL.INPUT", "and the run route takes no advise key")
}

/// <p>The two dictionary reads are fixed statements with their values bound: a table's class and its indices come back for the probe table, a name that
/// holds a quote resolves nothing and raises nothing, the probe table is still there after one that looks like a statement, and a system schema is not read.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Indexed</code> reads the system schemas too -> the system leg goes red; the class read is run with the
/// name spliced into its text -> the quote legs go red.</p>
Method TestTheDictionaryReadsBindTheNamesTheyAreGiven()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeAdvice", ..#NAMESPACE), "the advice probe's table is made")
    Set tPort = ..#PORT
    Do $$$AssertEquals(($Length($Parameter(tPort, "ADVICECLASSQUERY"), "?") - 1) _ "|" _ ($Length($Parameter(tPort, "ADVICEINDEXQUERY"), "?") - 1), "2|1", "the two statements carry their values as ? and nothing else")
    Set tSC = $ClassMethod(tPort, "Indexed", ..#NAMESPACE, "OcuProbe227Advice", "T", .tClass, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tClass, "1|OcuProbe227Advice.T", "the probe table's class is read")
    Set tNames = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tKey, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Name _ ":" _ tRow.Properties _ ":" _ tRow.IdKey
    }
    Do $$$AssertEquals(tNames, "DDLBEIndex::0,IDKEY::1,IdxA:A:0,IdxC:C:0", "with its indices, their fields and which is the key: " _ tNames)
    For tCase = $ListBuild("OcuProbe227Advice' OR '1'='1", "T"), $ListBuild("OcuProbe227Advice", "T' OR '1'='1"), $ListBuild("OcuProbe227Advice", "T'; DROP TABLE OcuProbe227Advice.T --"), $ListBuild("x""y", "T") {
        Set tSC = $ClassMethod(tPort, "Indexed", ..#NAMESPACE, $List(tCase, 1), $List(tCase, 2), .tClass, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tClass _ "|" _ tRows, "1||", "resolves nothing and raises nothing: " _ $List(tCase, 1) _ " " _ $List(tCase, 2))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AdviceState", ..#NAMESPACE), "1|x", "the table and its row are still there")
    Set tSC = $ClassMethod(tPort, "Indexed", ..#NAMESPACE, "%Dictionary", "ClassDefinition", .tClass, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tClass _ "|" _ tRows, "1||", "a system schema is not read")
}

/// <p>POST <var>pBody</var> to the plan route in <var>pNamespace</var> as the suite's own account, answering the status and the parsed answer.</p>
Method Post(pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer, pNamespace As %String = {..#NAMESPACE}, pPath As %String = {..#PLAN})
{
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", pPath _ "?ns=" _ pNamespace, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders, pBody.%ToJSON(), "application/json")
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = $Get(tBody)
    }
}

}
