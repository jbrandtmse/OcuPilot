/// <p>Pins <class>OcuPilot.Port.SqlAlternateScan</class> (Story 21.28): the table and condition counts at the bounds of
/// <parameter>OcuPilot.Port.SqlPort.ALTMAXTABLES</parameter> and <parameter>OcuPilot.Port.SqlPort.ALTMAXCONDITIONS</parameter>, by FROM, comma, JOIN,
/// USING, aliases of one table, <code>&amp;</code> and <code>!</code> and the text of a view; what a comment, a string literal, a delimited identifier or a
/// function's FROM leaves uncounted; the cross-product test; the place of <code>%NOPARALLEL</code> in each shape of FROM; and the statement text read out of
/// a plan.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. The class is pure and touches no instance state.</p>
Class OcuPilot.Test.SqlAlternateScan Extends %UnitTest.TestCase
{

Parameter SCAN = "OcuPilot.Port.SqlAlternateScan";

Parameter PORT = "OcuPilot.Port.SqlPort";

/// <p><var>pText</var>'s counts as <code>tables/conditions</code>, with the view texts <var>pViews</var> and the relation count <var>pRelations</var>.</p>
ClassMethod Counts(pText As %String, pViews As %DynamicArray = "", pRelations As %Integer = 0) As %String
{
    Do $ClassMethod(..#SCAN, "Count", pText, pViews, pRelations, .tTables, .tConditions)
    Quit tTables _ "/" _ tConditions
}

/// <p><var>pText</var> with the keyword inserted.</p>
ClassMethod Inserted(pText As %String) As %String
{
    Quit $ClassMethod(..#SCAN, "NoParallel", pText)
}

/// <p>The tables a FROM, a comma, a JOIN, an UPDATE and an INSERT each add, and the bound's boundary at the fourth and fifth table by each way of writing
/// one.</p>
/// <p>Mutation (Rule 19): <code>Walk</code> counts no comma of a FROM clause -> the comma legs go red.</p>
Method TestTablesAreCountedByFromCommaJoinUpdateAndInsert()
{
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a"), "1/0", "one table")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a, b, c, d"), "4/0", "four tables by commas, the bound's own count")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a, b, c, d, e"), "5/0", "five tables by commas, one past it")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a JOIN b ON a.x = b.x JOIN c ON b.y = c.y JOIN d ON c.z = d.z"), "4/3", "four tables by JOIN")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a JOIN b ON a.x = b.x JOIN c ON b.y = c.y JOIN d ON c.z = d.z JOIN e ON d.w = e.w"), "5/4", "five tables by JOIN")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a NATURAL JOIN b CROSS JOIN c"), "3/0", "a NATURAL or CROSS JOIN is a JOIN")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t a, t b, t c, t d WHERE a.x = b.x AND b.x = c.x AND c.x = d.x"), "4/3", "four aliases of one table are four tables")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t a, t b, t c, t d, t e WHERE a.x = b.x AND b.x = c.x AND c.x = d.x AND d.x = e.x"), "5/4", "five aliases of one table are five")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM (SELECT a, b FROM t1, t2) q, u"), "4/0", "a derived table's own FROM and comma count, beside the outer ones")
    Do $$$AssertEquals(..Counts("SELECT a, b, c, d, e, f FROM t"), "1/0", "the commas of a select list are not tables")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t WHERE x IN (1, 2, 3) ORDER BY a, b"), "1/1", "nor those after WHERE, inside parentheses or in ORDER BY")
    Do $$$AssertEquals(..Counts("UPDATE t SET a = 1, b = 2 WHERE c = 3"), "1/1", "an UPDATE is one table and the commas of its SET are not tables")
    Do $$$AssertEquals(..Counts("UPDATE t1, t2 SET a = 1"), "2/0", "an UPDATE's relation list counts each relation")
    Do $$$AssertEquals(..Counts("INSERT INTO t (a, b) VALUES (1, 2)"), "1/0", "an INSERT is one table")
    Do $$$AssertEquals(..Counts("INSERT INTO t SELECT a, b FROM u"), "2/0", "an INSERT ... SELECT adds the SELECT's table")
    Do $$$AssertEquals(..Counts("INSERT OR UPDATE INTO t (a) VALUES (1)"), "1/1", "INSERT OR UPDATE is one table")
    Do $$$AssertEquals(..Counts("DELETE FROM t WHERE a = 1"), "1/1", "a DELETE's FROM is a table")
    Do $$$AssertEquals(..Counts("select 1 from a, b"), "2/0", "the words are read in any case")
    Do $$$AssertTrue(4 <= $Parameter(..#PORT, "ALTMAXTABLES"), "four tables are within the bound")
    Do $$$AssertTrue(5 > $Parameter(..#PORT, "ALTMAXTABLES"), "five are over it")
}

/// <p>The conditions WHERE, ON, AND, OR, HAVING, <code>&amp;</code>, <code>!</code> and each column of a USING list add, and the bound's boundary at the
/// fourth and fifth.</p>
/// <p>Mutation (Rule 19): <code>Walk</code> skips the columns of a USING list -> the USING leg goes red.</p>
Method TestConditionsAreCountedByWhereOnAndOrHavingAndUsing()
{
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t WHERE a = 1 AND b = 2 AND c = 3 AND d = 4"), "1/4", "four conditions, the bound's own count")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t WHERE a = 1 AND b = 2 AND c = 3 AND d = 4 AND e = 5"), "1/5", "five conditions, one past it")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t WHERE a = 1 OR b = 2"), "1/2", "WHERE and OR")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a JOIN b ON a.x = b.x JOIN c ON b.y = c.y"), "3/2", "each ON")
    Do $$$AssertEquals(..Counts("SELECT a FROM t GROUP BY a HAVING COUNT(*) > 1"), "1/1", "HAVING")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a JOIN b USING (x, y, z)"), "2/3", "one condition for each column of a USING list")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM a JOIN b USING (x) JOIN c USING (y)"), "3/2", "and for a list of one")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t WHERE a = 1 & b = 2 ! c = 3"), "1/3", "& is AND and ! is OR")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t WHERE a != 1 AND b = 2"), "1/2", "but the ! of != is not")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t"), "1/0", "no condition")
    Do $$$AssertTrue(4 <= $Parameter(..#PORT, "ALTMAXCONDITIONS"), "four conditions are within the bound")
    Do $$$AssertTrue(5 > $Parameter(..#PORT, "ALTMAXCONDITIONS"), "five are over it")
}

/// <p>A keyword inside a comment, a string literal, a delimited identifier (a name that is a keyword, a doubled quote inside one) or a function's own FROM
/// is not counted.</p>
/// <p>Mutation (Rule 19): <code>Tokens</code> reads a string literal's text as words -> the literal legs go red.</p>
Method TestWhatIsInsideCommentsLiteralsQuotesAndFunctionsIsNotCounted()
{
    Do $$$AssertEquals(..Counts("SELECT 'a, b FROM c WHERE d AND e' FROM t"), "1/0", "a string literal")
    Do $$$AssertEquals(..Counts("SELECT 'it''s FROM x AND y' FROM t"), "1/0", "a string literal with a doubled quote")
    Do $$$AssertEquals(..Counts("SELECT 1 FROM t -- WHERE a AND b" _ $Char(10) _ "WHERE c = 1"), "1/1", "a line comment ends at the line")
    Do $$$AssertEquals(..Counts("/* FROM x, y JOIN z */ SELECT 1 FROM t /*#OPTIONS {""a"":1} */"), "1/0", "a block comment, the instance's options comment included")
    Do $$$AssertEquals(..Counts("SELECT ""from"", ""where"" FROM t"), "1/0", "delimited identifiers named like keywords")
    Do $$$AssertEquals(..Counts("SELECT ""a"""" FROM x"" FROM t"), "1/0", "a delimited identifier with a doubled quote")
    Do $$$AssertEquals(..Counts("SELECT SUBSTRING(a FROM 2), TRIM(BOTH 'x' FROM b), EXTRACT(YEAR FROM c) FROM t"), "1/0", "the FROM of SUBSTRING, TRIM and EXTRACT")
    Do $$$AssertEquals(..Counts("SELECT SUBSTRING((SELECT a FROM u) FROM 2) FROM t"), "2/0", "a subquery's FROM inside a function's parentheses is a clause")
}

/// <p>A view's text adds its own counts: a view whose text repeats one table is over the bound although the instance records two relations for it, and the
/// relation count is the least the tables can be.</p>
/// <p>Mutation (Rule 19): <code>Count</code> ignores <var>pViews</var> -> the view legs go red.</p>
Method TestAViewAddsItsOwnCounts()
{
    Do $$$AssertEquals(..Counts("SELECT * FROM v", ["SELECT * FROM t a, t b, t c, t d"], 2), "5/0", "a view of four aliases of one table: its four and the statement's one")
    Do $$$AssertTrue(5 > $Parameter(..#PORT, "ALTMAXTABLES"), "which is over the bound")
    Do $$$AssertEquals(..Counts("SELECT * FROM v WHERE x = 1", ["SELECT * FROM t WHERE a = 1 AND b = 2"], 2), "2/3", "a view's conditions are added")
    Do $$$AssertEquals(..Counts("SELECT * FROM a", "", 6), "6/0", "the relations the instance records are the least the tables can be")
    Do $$$AssertEquals(..Counts("SELECT * FROM a, b", "", 1), "2/0", "and not the most")
    Do $$$AssertEquals(..Counts("SELECT * FROM v", ["SELECT * FROM t1", "SELECT * FROM t2 JOIN t3 ON t2.a = t3.a"], 3), "4/1", "every view's text is added")
}

/// <p>A table joined by no condition: fewer conditions than tables minus one.</p>
/// <p>Mutation (Rule 19): <code>CrossProduct</code> compares with the tables, not the tables minus one -> the boundary legs go red.</p>
Method TestACrossProductIsFewerConditionsThanTablesMinusOne()
{
    Do $$$AssertEquals($ClassMethod(..#SCAN, "CrossProduct", 1, 0), 0, "one table needs no condition")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "CrossProduct", 2, 0), 1, "two tables and no condition")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "CrossProduct", 2, 1), 0, "two tables and one condition")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "CrossProduct", 3, 1), 1, "three tables and one condition")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "CrossProduct", 3, 2), 0, "three tables and two conditions")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "CrossProduct", 4, 4), 0, "more conditions than tables")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "CrossProduct", 3, 0), 1, "a three-table cross join")
}

/// <p>The keyword is inserted after the FROM that opens a FROM clause, in a subquery and a derived table too, and nowhere else: not after a function's FROM,
/// DELETE's FROM or a FROM already followed by it, and nothing inside a comment, a string literal or a delimited identifier.</p>
/// <p>Mutation (Rule 19): <code>Walk</code> inserts after a function's FROM -> the SUBSTRING, TRIM and EXTRACT leg goes red.</p>
Method TestNoParallelFollowsEachFromClauseAndNothingElse()
{
    Do $$$AssertEquals(..Inserted("SELECT a FROM t"), "SELECT a FROM %NOPARALLEL t", "one FROM")
    Do $$$AssertEquals(..Inserted("select a from t"), "select a from %NOPARALLEL t", "in any case")
    Do $$$AssertEquals(..Inserted("SELECT a FROM t1, t2 WHERE x = 1"), "SELECT a FROM %NOPARALLEL t1, t2 WHERE x = 1", "one keyword covers a FROM clause's tables")
    Do $$$AssertEquals(..Inserted("SELECT a FROM (SELECT b FROM u) q"), "SELECT a FROM %NOPARALLEL (SELECT b FROM %NOPARALLEL u) q", "a derived table's FROM is covered")
    Do $$$AssertEquals(..Inserted("SELECT a FROM t WHERE a IN (SELECT b FROM u) UNION SELECT c FROM v"), "SELECT a FROM %NOPARALLEL t WHERE a IN (SELECT b FROM %NOPARALLEL u) UNION SELECT c FROM %NOPARALLEL v", "a subquery's and a UNION's FROM")
    Do $$$AssertEquals(..Inserted("SELECT SUBSTRING(a FROM 2), TRIM(BOTH 'x' FROM b), EXTRACT(YEAR FROM c) FROM t"), "SELECT SUBSTRING(a FROM 2), TRIM(BOTH 'x' FROM b), EXTRACT(YEAR FROM c) FROM %NOPARALLEL t", "not after the FROM of SUBSTRING, TRIM or EXTRACT")
    Do $$$AssertEquals(..Inserted("SELECT OVERLAY(a PLACING 'x' FROM 2) FROM t WHERE b IS DISTINCT FROM c"), "SELECT OVERLAY(a PLACING 'x' FROM 2) FROM %NOPARALLEL t WHERE b IS DISTINCT FROM c", "nor after OVERLAY's FROM or IS DISTINCT FROM")
    Do $$$AssertEquals(..Inserted("DELETE FROM t WHERE a = 1"), "DELETE FROM t WHERE a = 1", "not after DELETE's FROM, which it makes a syntax error")
    Do $$$AssertEquals(..Inserted("DELETE %NOCHECK FROM t"), "DELETE %NOCHECK FROM t", "nor after DELETE's options")
    Do $$$AssertEquals(..Inserted("SELECT a FROM %NOPARALLEL t"), "SELECT a FROM %NOPARALLEL t", "not twice")
    Do $$$AssertEquals(..Inserted("SELECT 'FROM x', ""from"" FROM t /* FROM y */ -- FROM z"), "SELECT 'FROM x', ""from"" FROM %NOPARALLEL t /* FROM y */ -- FROM z", "nothing inside a literal, a delimited identifier or a comment")
    Do $$$AssertEquals(..Inserted("SELECT a FROM ""from"""), "SELECT a FROM %NOPARALLEL ""from""", "a delimited identifier named from is a table's name")
    Do $$$AssertEquals(..Inserted("SELECT a FROM" _ $Char(10) _ "t"), "SELECT a FROM %NOPARALLEL" _ $Char(10) _ "t", "a FROM at the end of a line")
    Do $$$AssertEquals(..Inserted("SELECT a FROM(SELECT 1) q"), "SELECT a FROM %NOPARALLEL (SELECT 1) q", "a FROM touching a parenthesis")
    Do $$$AssertEquals(..Inserted("SELECT 1"), "SELECT 1", "a statement with no FROM")
}

/// <p>The statement's text is the lines after <code>SQL:</code> up to the blank line, joined by one space, without the instance's options comment.</p>
/// <p>Mutation (Rule 19): <code>StatementText</code> joins the lines with no space -> the two-line leg goes red.</p>
Method TestTheStatementTextIsReadOutOfAPlan()
{
    Set tEol = $Char(13, 10)
    Set tPlan = "<plans>" _ tEol _ " <plan>" _ tEol _ "   SQL:" _ tEol _ "    SELECT A AS Probe FROM T WHERE B = ? AND C = ? /*#OPTIONS {""DynamicSQLTypeList"":""10,1""} */" _ tEol _ "   " _ tEol _ "   Cost: 697.86" _ tEol _ " </plan>" _ tEol _ "</plans>"
    Do $$$AssertEquals($ClassMethod(..#SCAN, "StatementText", tPlan), "SELECT A AS Probe FROM T WHERE B = ? AND C = ?", "the statement, its literals as ?, without the options comment")
    Set tPlan = "<plans>" _ tEol _ "   SQL:" _ tEol _ "    SELECT A" _ tEol _ "    FROM T" _ tEol _ "    WHERE B = ?" _ tEol _ "   " _ tEol _ "   Cost: 1" _ tEol _ "</plans>"
    Do $$$AssertEquals($ClassMethod(..#SCAN, "StatementText", tPlan), "SELECT A FROM T WHERE B = ?", "a statement on several lines is joined by one space")
    Set tPlan = "<plans>" _ $Char(10) _ "   SQL:" _ $Char(10) _ "    SELECT A FROM T" _ $Char(10) _ "   " _ $Char(10) _ "</plans>"
    Do $$$AssertEquals($ClassMethod(..#SCAN, "StatementText", tPlan), "SELECT A FROM T", "lines ended by a line feed alone")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "StatementText", "<plans></plans>"), "", "a plan with no statement section answers nothing")
    Do $$$AssertEquals($ClassMethod(..#SCAN, "StatementText", ""), "", "and so does no plan")
}

}
