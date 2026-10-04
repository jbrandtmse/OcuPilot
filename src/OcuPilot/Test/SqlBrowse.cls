/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s data browser parts that run nothing (Story 19.7): the
/// delimited identifier, the wildcard filter value over every metacharacter, the kind table over
/// every measured catalog type, every refusal of the request's shape, the two composed statements
/// with their values in order, and the cell mapping of NULL, an empty value and binary.</p>
/// <p><b>What it needs from the environment:</b> the compiled port. It creates nothing and prepares
/// nothing.</p>
Class OcuPilot.Test.SqlBrowse Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlPort";

/// <p>The kind table as Task 0 read the catalog's spellings, typed here apart from the port's own
/// parameter so the two are compared rather than read twice.</p>
Parameter EXPECTEDKINDS = "tinyint=number,smallint=number,integer=number,bigint=number,numeric=number,double=number,bit=boolean,date=date,time=time,timestamp=timestamp,longvarchar=stream,varbinary=binary,longvarbinary=binary,varchar=text,guid=text,=text";

/// <p>A name is delimited with each <code>"</code> doubled.</p>
Method TestQuotedDoublesEachQuote()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "Quoted", "Name"), """Name""", "a plain name")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Quoted", "a""b"), """a""""b""", "a quote is doubled")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Quoted", "x"" OR 1=1 --"), """x"""" OR 1=1 --""", "so a name never ends the identifier")
}

/// <p>AC4: <code>\</code>, <code>%</code> and <code>_</code> are escaped with <code>\</code> and then
/// <code>*</code> is <code>%</code> and <code>?</code> is <code>_</code>.</p>
/// <p>Mutation (Rule 19): stop escaping <code>%</code> in <method>OcuPilot.Port.SqlPort.LikeValue</method>
/// -- the literal-<code>%</code> leg goes red.</p>
Method TestLikeValueEscapesThenMapsTheWildcards()
{
    For tCase = $ListBuild("n3*", "n3%"), $ListBuild("n?", "n_"), $ListBuild("n%", "n\%"), $ListBuild("a_b", "a\_b"), $ListBuild("c:\x", "c:\\x"), $ListBuild("*%?_\", "%\%_\_\\"), $ListBuild("plain", "plain"), $ListBuild("", "") {
        Do $$$AssertEquals($ClassMethod(..#PORT, "LikeValue", $List(tCase, 1)), $List(tCase, 2), $List(tCase, 1))
    }
}

/// <p>Each catalog type Task 0 measured maps to its kind, ignoring case; any other is text.</p>
Method TestKindOfTypeCoversTheKindTable()
{
    For tI = 1:1:$Length(..#EXPECTEDKINDS, ",") {
        Set tPair = $Piece(..#EXPECTEDKINDS, ",", tI)
        Do $$$AssertEquals($ClassMethod(..#PORT, "KindOfType", $Piece(tPair, "=", 1)), $Piece(tPair, "=", 2), "type '" _ $Piece(tPair, "=", 1) _ "'")
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "KindOfType", "LONGVARCHAR"), "stream", "ignoring case")
    Set tNamed = 0
    For tI = 1:1:$Length($Parameter(..#PORT, "KINDS"), ";") Set tNamed = tNamed + $Length($Piece($Piece($Parameter(..#PORT, "KINDS"), ";", tI), "=", 2), ",")
    Do $$$AssertEquals(tNamed, 13, "the table names the thirteen measured types")
}

/// <p>Matrix row Bad input: an unknown key, a bad name, a filter of 1,001 characters or on an empty
/// name, more than 100 filters, a sort with a stray key or the direction <code>up</code>, an offset of
/// -1, fractional or past 99,999,999, and a page size of 70 are each refused; the defaults are an
/// offset of 0 and a page of 100.</p>
Method TestBrowseRequestRefusesEveryShape()
{
    Set tMany = {}
    For tI = 1:1:101 Do tMany.%Set("c" _ tI, "v", "string")
    Set tBodies = [
        {"schema": "S", "table": "T", "extra": 1},
        {"table": "T"},
        {"schema": "", "table": "T"},
        {"schema": "S", "table": ($Translate($Justify("", 129), " ", "t"))},
        {"schema": "S", "table": ("a" _ $Char(9) _ "b")},
        {"schema": 1, "table": "T"},
        {"schema": "S", "table": "T", "filters": {"Name": ($Translate($Justify("", 1001), " ", "x"))}},
        {"schema": "S", "table": "T", "filters": {"Name": ""}},
        {"schema": "S", "table": "T", "filters": {"": "x"}},
        {"schema": "S", "table": "T", "filters": {"Name": 5}},
        {"schema": "S", "table": "T", "filters": (tMany)},
        {"schema": "S", "table": "T", "filters": ["Name"]},
        {"schema": "S", "table": "T", "sort": {"column": "Name", "direction": "up"}},
        {"schema": "S", "table": "T", "sort": {"column": "Name", "direction": "ASC"}},
        {"schema": "S", "table": "T", "sort": {"column": "Name"}},
        {"schema": "S", "table": "T", "sort": {"column": "Name", "direction": "asc", "extra": 1}},
        {"schema": "S", "table": "T", "sort": "Name"},
        {"schema": "S", "table": "T", "offset": -1},
        {"schema": "S", "table": "T", "offset": 1.5},
        {"schema": "S", "table": "T", "offset": 100000000},
        {"schema": "S", "table": "T", "offset": "5"},
        {"schema": "S", "table": "T", "size": 70},
        {"schema": "S", "table": "T", "size": "100"}
    ]
    Set tIterator = tBodies.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tBody) {
        Do $$$AssertTrue('$ClassMethod(..#PORT, "BrowseRequest", tBody, .tRequest), "refused, body " _ tIndex _ ": " _ $Extract(tBody.%ToJSON(), 1, 120))
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "BrowseRequest", "", .tRequest), "and a body that is not an object")
    Do $$$AssertTrue($ClassMethod(..#PORT, "BrowseRequest", {"schema": "S", "table": "T"}, .tRequest), "the two names alone are a request")
    Do $$$AssertEquals(tRequest.%ToJSON(), "{""schema"":""S"",""table"":""T"",""filters"":[],""sort"":null,""offset"":0,""size"":100}", "with no filter, no sort, offset 0 and a page of 100")
    Do $$$AssertTrue($ClassMethod(..#PORT, "BrowseRequest", {"schema": "S", "table": "T", "filters": {"B": "2", "A": "1"}, "sort": {"direction": "desc", "column": "A"}, "offset": 99999999, "size": 500}, .tRequest), "every key at its bound")
    Do $$$AssertEquals(tRequest.%ToJSON(), "{""schema"":""S"",""table"":""T"",""filters"":[{""column"":""B"",""value"":""2""},{""column"":""A"",""value"":""1""}],""sort"":{""column"":""A"",""direction"":""desc""},""offset"":99999999,""size"":500}", "the filters in the body's order")
}

/// <p>The two statements: every identifier delimited in the plan's spelling, a stream and a binary
/// column read by <code>SUBSTRING</code>, the date, time and timestamp filters through
/// <code>%ODBCOUT</code>, the order the sort then the key without the sort's column twice, and the
/// values the filters' in order, then the offset and the page size plus one.</p>
Method TestComposedNamesBindsAndOrders()
{
    Set tPlan = {"table": {"schema": "", "name": "T"}, "columns": [{"name": "Name", "kind": "text"}, {"name": "Notes", "kind": "stream"}, {"name": "Blob", "kind": "binary"}, {"name": "Born", "kind": "date"}, {"name": "A", "kind": "number"}, {"name": "B", "kind": "number"}], "key": ["A", "B"], "filters": [{"column": "Born", "kind": "date", "value": "2026*"}, {"column": "Name", "kind": "text", "value": "n%"}], "sort": {"column": "B", "direction": "desc"}, "offset": 100, "size": 50}
    Do tPlan.table.%Set("schema", "My""S", "string")
    Set tComposed = $ClassMethod(..#PORT, "Composed", tPlan)
    Do $$$AssertEquals(tComposed.page, "SELECT ""Name"", SUBSTRING(""Notes"", 1, 1001) AS ""Notes"", SUBSTRING(""Blob"", 1, 500) AS ""Blob"", ""Born"", ""A"", ""B"" FROM ""My""""S"".""T"" WHERE %ODBCOUT(""Born"") LIKE ? ESCAPE '\' AND ""Name"" LIKE ? ESCAPE '\' ORDER BY ""B"" DESC, ""A"" ASC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY", "the page")
    Do $$$AssertEquals(tComposed.pageValues.%ToJSON(), "[""2026%"",""n\\%"",100,51]", "its values: the filters, the offset and the page size plus one")
    Do $$$AssertEquals(tComposed.count, "SELECT COUNT(*) FROM ""My""""S"".""T"" WHERE %ODBCOUT(""Born"") LIKE ? ESCAPE '\' AND ""Name"" LIKE ? ESCAPE '\'", "the count")
    Do $$$AssertEquals(tComposed.countValues.%ToJSON(), "[""2026%"",""n\\%""]", "its values: the filters alone")
    Set tPlan = {"table": {"schema": "S", "name": "T"}, "columns": [{"name": "A", "kind": "number"}], "key": [], "filters": [], "sort": null, "offset": 0, "size": 100}
    Set tComposed = $ClassMethod(..#PORT, "Composed", tPlan)
    Do $$$AssertEquals(tComposed.page _ " | " _ tComposed.pageValues.%ToJSON() _ " | " _ tComposed.count, "SELECT ""A"" FROM ""S"".""T"" OFFSET ? ROWS FETCH NEXT ? ROWS ONLY | [0,101] | SELECT COUNT(*) FROM ""S"".""T""", "no filter, no sort and no key: no WHERE and no ORDER BY")
    Set tPlan = {"table": {"schema": "S", "name": "T"}, "columns": [{"name": "A", "kind": "number"}], "key": ["A"], "filters": [], "sort": {"column": "A", "direction": "asc"}, "offset": 0, "size": 50}
    Do $$$AssertTrue($ClassMethod(..#PORT, "Composed", tPlan).page [ "ORDER BY ""A"" ASC OFFSET", "a sort on the key names it once")
}

/// <p>AC3: <code>""</code> is NULL, <code>$Char(0)</code> an empty value, and a binary cell
/// <code>0x</code> and upper-case hex of at most 499 bytes, ending in U+2026 and cut at 500.</p>
/// <p>Mutation (Rule 19): map <code>$Char(0)</code> to NULL in
/// <method>OcuPilot.Port.SqlPort.CellOf</method> -- the empty leg goes red.</p>
Method TestTheCellMapping()
{
    Set tCell = $ClassMethod(..#PORT, "CellOf", "text", "", .tNull, .tCut)
    Do $$$AssertEquals(tNull _ " " _ tCut _ " [" _ tCell _ "]", "1 0 []", "an empty answer is NULL")
    Set tCell = $ClassMethod(..#PORT, "CellOf", "text", $Char(0), .tNull, .tCut)
    Do $$$AssertEquals(tNull _ " [" _ tCell _ "]", "0 []", "$Char(0) is an empty value")
    Set tCell = $ClassMethod(..#PORT, "CellOf", "number", "12.50", .tNull, .tCut)
    Do $$$AssertEquals(tNull _ " " _ tCell, "0 12.50", "anything else is itself")
    Set tCell = $ClassMethod(..#PORT, "CellOf", "binary", $Char(0, 10, 171, 255), .tNull, .tCut)
    Do $$$AssertEquals(tCut _ " " _ tCell, "0 0x000AABFF", "binary is 0x and upper-case hex")
    Set tCell = $ClassMethod(..#PORT, "CellOf", "binary", $Translate($Justify("", 500), " ", $Char(1)), .tNull, .tCut)
    Do $$$AssertEquals(tCut _ " " _ $Length(tCell) _ " " _ $Ascii($Extract(tCell, *)) _ " " _ $Extract(tCell, *-2, *-1), "1 1001 8230 01", "500 bytes are cut at 499, ending in U+2026")
    Set tCell = $ClassMethod(..#PORT, "CellOf", "binary", $Translate($Justify("", 499), " ", $Char(2)), .tNull, .tCut)
    Do $$$AssertEquals(tCut _ " " _ $Length(tCell), "0 1000", "499 bytes are whole")
}

}
