/// <p>The advice heuristics (Story 21.27, AD-21): findings computed from the text of one query plan and the indices of the tables it reads,
/// with no call to the instance. <class>OcuPilot.Port.SqlPort</class> reads the plan and the dictionary and passes both here.</p>
/// <p>The kinds, each with its confidence: <parameter>KINDFULLSCAN</parameter> (medium), <parameter>KINDMISSINGINDEX</parameter> (high when one
/// column is missing an index and every condition on it is an equality, else medium), <parameter>KINDNOTTUNED</parameter> (low),
/// <parameter>KINDTEMPFILE</parameter> (low) and <parameter>KINDUNUSEDINDEX</parameter> (low). A table in a system schema, a key or primary-key index and an
/// index with no field are never advised on. Every sentence is filled from the templates below with names the plan or the dictionary gave, never with
/// text a caller or a model wrote, and a finding carries the plan text it was read from.</p>
Class OcuPilot.Port.SqlAdvice Extends %RegisteredObject
{

Parameter KINDFULLSCAN = "fullscan";

Parameter KINDMISSINGINDEX = "missingindex";

Parameter KINDNOTTUNED = "nottuned";

Parameter KINDTEMPFILE = "tempfile";

Parameter KINDUNUSEDINDEX = "unusedindex";

Parameter CONFIDENCEHIGH = "high";

Parameter CONFIDENCEMEDIUM = "medium";

Parameter CONFIDENCELOW = "low";

/// <p>The most findings one plan answers; a plan that would answer more is cut and reported.</p>
Parameter MAXFINDINGS As INTEGER = 200;

/// <p>The most tables of one plan that are advised on.</p>
Parameter MAXTABLES As INTEGER = 20;

/// <p>The sentences, <code>%1</code> the table, <code>%2</code> the fields and <code>%3</code> the index.</p>
Parameter FULLSCANDETAIL = "The plan reads every row of %1 and tests a condition on each one.";

Parameter FULLSCANRECOMMENDATION = "Check whether an index on the condition's fields would let the plan skip this scan.";

Parameter MISSINGINDEXDETAIL = "No index on %1 starts with %2, which the statement's conditions test.";

Parameter MISSINGINDEXRECOMMENDATION = "Consider an index on %1 that starts with %2, then explain the plan again.";

Parameter NOTTUNEDDETAIL = "The plan reports that %1 has not been tuned, so the optimizer has no statistics for it.";

Parameter NOTTUNEDRECOMMENDATION = "Tune the table so the optimizer can choose a better plan.";

Parameter TEMPFILEDETAIL = "The plan builds a temporary file, as a GROUP BY, an ORDER BY or a join can need.";

Parameter TEMPFILERECOMMENDATION = "Check whether an index could serve the grouping, ordering or join so the plan needs no temporary file.";

Parameter UNUSEDINDEXDETAIL = "This statement's plan does not use the index %3 on %1.";

Parameter UNUSEDINDEXRECOMMENDATION = "Check that no other statement uses it before you remove it.";

/// <p>The plan lines that read a table: a master map or an index map, with an optional join alias before the map's name.</p>
Parameter MAPPATTERN = "Read (?:[a-z]+ )?(?:master|index) map ([\w%]+)\.([\w%]+?)(?:\([A-Za-z0-9]+\))?\.([\w%]+)";

/// <p>A master map read that loops over the whole map: a full table scan.</p>
Parameter SCANPATTERN = "Read master map ([\w%]+)\.([\w%]+?)(?:\([A-Za-z0-9]+\))?\.[\w%]+, looping on [\w.]+(?: and [\w.]+)*\.";

/// <p>A condition the plan tests on a row: its operator, then the field, with or without the plan's upper-casing function.</p>
Parameter CONDITIONPATTERN = "(?i)the (NOT NULL|IS NOT NULL|IS NULL|BETWEEN|LIKE|IN|<>|<=|>=|=|<|>) condition on (?:%SQLUPPER\(([\w.%]+)\)|([\w.%]*[\w%]))";

/// <p>The warning line that names the tables the optimizer holds no statistics for, wherever in the plan's warnings it stands.</p>
Parameter TUNEDPATTERN = "(?m)^[ \t]*(Tables? [^\r\n]*? (?:is|are) not tuned\.)";

Parameter TABLENAMEPATTERN = "[\w%]+\.[\w%]+";

Parameter TEMPFILEPATTERN = "Call Module-[A-Za-z0-9]+(?: once)?, which populates temp-file [A-Za-z0-9]+\.|Read temp-file [A-Za-z0-9]+, [^\r\n]*";

/// <p>Whether <var>pPlan</var> is a plan this class can read: it has a module, a map read, a temporary file or a not-tuned warning.</p>
ClassMethod Recognized(pPlan As %String) As %Boolean
{
    If pPlan = "" Quit 0
    If (pPlan [ "Read master map ") || (pPlan [ "Read index map ") || (pPlan [ "Read temp-file ") || (pPlan [ "which populates temp-file") Quit 1
    Quit ($Locate(pPlan, "Module-[A-Za-z0-9]+:") > 0) || ($Locate(pPlan, ..#TUNEDPATTERN) > 0)
}

/// <p>The tables <var>pPlan</var> reads, as an array of <code>{Schema, Table}</code>, each once in the order the plan first reads it, a join alias
/// dropped.</p>
ClassMethod Tables(pPlan As %String) As %DynamicArray
{
    Set tTables = []
    Set tSeen = ""
    Set tMatcher = ##class(%Regex.Matcher).%New(..#MAPPATTERN, pPlan)
    While tMatcher.Locate() {
        Set tKey = $ZConvert(tMatcher.Group(1) _ "." _ tMatcher.Group(2), "U")
        If $ListFind(tSeen, tKey) Continue
        Set tSeen = tSeen _ $ListBuild(tKey)
        Set tTable = {}
        Do tTable.%Set("Schema", tMatcher.Group(1), "string")
        Do tTable.%Set("Table", tMatcher.Group(2), "string")
        Do tTables.%Push(tTable)
    }
    Quit tTables
}

/// <p>The findings for <var>pPlan</var>, as an array of <code>{Kind, Confidence, Table, Fields, Index, Detail, Recommendation, Excerpt}</code>
/// in the order full scan, missing index, not tuned, temporary file, unused index. <var>pIndexes</var> is an array of <code>{Schema, Table, Rows}</code>,
/// where <code>Rows</code> is an array of <code>{Name, Properties, Type, PrimaryKey, IdKey}</code> as the dictionary answers an index, or is not an array
/// when the table's indices could not be listed, which leaves that table without an index finding. A plan this class does not recognize has none.
/// <var>pTruncated</var> is 1 when <parameter>MAXFINDINGS</parameter> cut the list.</p>
ClassMethod Findings(pPlan As %String, pIndexes As %DynamicArray, Output pTruncated As %Boolean) As %DynamicArray
{
    Set pTruncated = 0
    Set tFindings = []
    If '..Recognized(pPlan) Quit tFindings
    Set tIndexes = $Select($IsObject($Get(pIndexes)): pIndexes, 1: [])
    Set tConditions = ..Conditions(pPlan)
    Set tSeen = ""
    Set tMatcher = ##class(%Regex.Matcher).%New(..#SCANPATTERN, pPlan)
    While tMatcher.Locate() {
        If $ListLength(tConditions) = 0 Quit
        Set tSchema = tMatcher.Group(1)
        Set tTable = tMatcher.Group(2)
        Set tName = tSchema _ "." _ tTable
        If $ListFind(tSeen, $ZConvert(tName, "U")) Continue
        Set tSeen = tSeen _ $ListBuild($ZConvert(tName, "U"))
        Set tExcerpt = tMatcher.Group(0)
        If '..Add(tFindings, ..Finding(..#KINDFULLSCAN, ..#CONFIDENCEMEDIUM, tName, "", "", ..#FULLSCANDETAIL, ..#FULLSCANRECOMMENDATION, tExcerpt), .pTruncated) Quit
        If ..SystemSchema(tSchema) Continue
        Set tRows = ..RowsOf(tIndexes, tSchema, tTable)
        If '$IsObject(tRows) Continue
        Set tLeading = ..Leading(tRows)
        Set tMissing = ""
        Set tAllEqual = 1
        Set tMissingColumns = ""
        For tI = 1:1:$ListLength(tConditions) {
            Set tCondition = $List(tConditions, tI)
            Set tOperator = $List(tCondition, 1)
            Set tColumn = $List(tCondition, 2)
            If '$ListFind($ListBuild("=", "<>", "<=", ">=", "<", ">", "BETWEEN"), tOperator) Continue
            If $ListFind(tLeading, $ZConvert(tColumn, "U")) Continue
            Set tUpper = $ZConvert(tColumn, "U")
            If '$ListFind(tMissingColumns, tUpper) {
                Set tMissingColumns = tMissingColumns _ $ListBuild(tUpper)
                Set tMissing = tMissing _ $Select(tMissing = "": "", 1: ", ") _ tColumn
            }
            If tOperator '= "=" Set tAllEqual = 0
        }
        If tMissing = "" Continue
        Set tConfidence = $Select(($ListLength(tMissingColumns) = 1) && tAllEqual: ..#CONFIDENCEHIGH, 1: ..#CONFIDENCEMEDIUM)
        If '..Add(tFindings, ..Finding(..#KINDMISSINGINDEX, tConfidence, tName, tMissing, "", ..#MISSINGINDEXDETAIL, ..#MISSINGINDEXRECOMMENDATION, tExcerpt), .pTruncated) Quit
    }
    If pTruncated Quit tFindings
    Set tMatcher = ##class(%Regex.Matcher).%New(..#TUNEDPATTERN, pPlan)
    While tMatcher.Locate() {
        Set tSentence = tMatcher.Group(1)
        Set tNames = ##class(%Regex.Matcher).%New(..#TABLENAMEPATTERN, tSentence)
        While tNames.Locate() {
            Set tName = tNames.Group(0)
            If ..SystemSchema($Piece(tName, ".", 1)) Continue
            If '..Add(tFindings, ..Finding(..#KINDNOTTUNED, ..#CONFIDENCELOW, tName, "", "", ..#NOTTUNEDDETAIL, ..#NOTTUNEDRECOMMENDATION, tSentence), .pTruncated) Quit
        }
        If pTruncated Quit
    }
    If pTruncated Quit tFindings
    Set tTemp = ..TempFileLines(pPlan)
    If tTemp '= "" {
        If '..Add(tFindings, ..Finding(..#KINDTEMPFILE, ..#CONFIDENCELOW, "", "", "", ..#TEMPFILEDETAIL, ..#TEMPFILERECOMMENDATION, tTemp), .pTruncated) Quit tFindings
    }
    Set tUsed = ..UsedIndexes(pPlan, .tLines)
    Set tGroupIterator = tIndexes.%GetIterator()
    While tGroupIterator.%GetNext(.tGroupKey, .tGroup) {
        If '$IsObject(tGroup) Continue
        Set tSchema = tGroup.%Get("Schema")
        Set tTable = tGroup.%Get("Table")
        If ..SystemSchema(tSchema) Continue
        If tGroup.%GetTypeOf("Rows") '= "array" Continue
        Set tRowIterator = tGroup.%Get("Rows").%GetIterator()
        While tRowIterator.%GetNext(.tRowKey, .tRow) {
            If '$IsObject(tRow) Continue
            If ..Skipped(tRow) Continue
            Set tIndex = tRow.%Get("Name")
            If $ListFind(tUsed, $ZConvert(tSchema _ "." _ tTable _ "." _ tIndex, "U")) Continue
            If '..Add(tFindings, ..Finding(..#KINDUNUSEDINDEX, ..#CONFIDENCELOW, tSchema _ "." _ tTable, ..PropertyNames(tRow.%Get("Properties")), tIndex, ..#UNUSEDINDEXDETAIL, ..#UNUSEDINDEXRECOMMENDATION, tLines), .pTruncated) Quit
        }
        If pTruncated Quit
    }
    Quit tFindings
}

/// <p>Append <var>pFinding</var> to <var>pFindings</var> unless it holds <parameter>MAXFINDINGS</parameter> already, in which case
/// <var>pTruncated</var> is set. Answers whether it was appended.</p>
ClassMethod Add(pFindings As %DynamicArray, pFinding As %DynamicObject, ByRef pTruncated As %Boolean) As %Boolean [ Private ]
{
    If pFindings.%Size() >= ..#MAXFINDINGS {
        Set pTruncated = 1
        Quit 0
    }
    Do pFindings.%Push(pFinding)
    Quit 1
}

/// <p>One finding: its kind, confidence, table, fields and index, the two templates filled with them, and the plan text it was read from.</p>
ClassMethod Finding(pKind As %String, pConfidence As %String, pTable As %String, pFields As %String, pIndex As %String, pDetail As %String, pRecommendation As %String, pExcerpt As %String) As %DynamicObject [ Private ]
{
    Set tFinding = {}
    Do tFinding.%Set("Kind", pKind, "string")
    Do tFinding.%Set("Confidence", pConfidence, "string")
    Do tFinding.%Set("Table", pTable, "string")
    Do tFinding.%Set("Fields", pFields, "string")
    Do tFinding.%Set("Index", pIndex, "string")
    Do tFinding.%Set("Detail", ..Filled(pDetail, pTable, pFields, pIndex), "string")
    Do tFinding.%Set("Recommendation", ..Filled(pRecommendation, pTable, pFields, pIndex), "string")
    Do tFinding.%Set("Excerpt", pExcerpt, "string")
    Quit tFinding
}

/// <p><var>pTemplate</var> with <code>%1</code>, <code>%2</code> and <code>%3</code> replaced in one pass by <var>pTable</var>, <var>pFields</var>
/// and <var>pIndex</var>, so a value that holds one of the three marks is not replaced again.</p>
ClassMethod Filled(pTemplate As %String, pTable As %String, pFields As %String, pIndex As %String) As %String
{
    Set tMarks = $Char(1, 2, 3)
    Set tText = $Replace($Replace($Replace(pTemplate, "%1", $Char(1)), "%2", $Char(2)), "%3", $Char(3))
    Set tText = $Replace(tText, $Char(1), $Translate(pTable, tMarks))
    Set tText = $Replace(tText, $Char(2), $Translate(pFields, tMarks))
    Quit $Replace(tText, $Char(3), $Translate(pIndex, tMarks))
}

/// <p>Whether <var>pSchema</var> is a system schema.</p>
ClassMethod SystemSchema(pSchema As %String) As %Boolean [ Private ]
{
    Quit ($Extract(pSchema, 1) = "%") || ($ZConvert(pSchema, "U") = "INFORMATION_SCHEMA")
}

/// <p>The conditions <var>pPlan</var> tests, in plan order, as a list of <code>$ListBuild(operator, field)</code>, a field with its table alias cut
/// off.</p>
ClassMethod Conditions(pPlan As %String) As %List [ Private ]
{
    Set tList = ""
    Set tMatcher = ##class(%Regex.Matcher).%New(..#CONDITIONPATTERN, pPlan)
    While tMatcher.Locate() {
        Set tColumn = $Select(tMatcher.Group(2) '= "": tMatcher.Group(2), 1: tMatcher.Group(3))
        Set tColumn = $Piece(tColumn, ".", $Length(tColumn, "."))
        If tColumn = "" Continue
        Set tList = tList _ $ListBuild($ListBuild($ZConvert(tMatcher.Group(1), "U"), tColumn))
    }
    Quit tList
}

/// <p>The rows of the table <var>pSchema</var>.<var>pTable</var> in <var>pIndexes</var>, compared without regard to case, or <code>""</code> when the
/// table is not there or its rows are not an array.</p>
ClassMethod RowsOf(pIndexes As %DynamicArray, pSchema As %String, pTable As %String) As %DynamicArray [ Private ]
{
    Set tRows = ""
    Set tIterator = pIndexes.%GetIterator()
    While tIterator.%GetNext(.tKey, .tGroup) {
        If '$IsObject(tGroup) Continue
        If ($ZConvert(tGroup.%Get("Schema"), "U") '= $ZConvert(pSchema, "U")) || ($ZConvert(tGroup.%Get("Table"), "U") '= $ZConvert(pTable, "U")) Continue
        If tGroup.%GetTypeOf("Rows") = "array" Set tRows = tGroup.%Get("Rows")
        Quit
    }
    Quit tRows
}

/// <p>The first field of each index in <var>pRows</var>, upper-cased, as a list.</p>
ClassMethod Leading(pRows As %DynamicArray) As %List [ Private ]
{
    Set tList = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tKey, .tRow) {
        If '$IsObject(tRow) Continue
        Set tNames = ..PropertyNames(tRow.%Get("Properties"))
        Set tFirst = $Piece(tNames, ", ", 1)
        If tFirst '= "" Set tList = tList _ $ListBuild($ZConvert(tFirst, "U"))
    }
    Quit tList
}

/// <p>The field names of an index's <code>Properties</code> text (<code>Name:Collation,Other(ELEMENTS)</code>), collations and subscript parts dropped,
/// joined by a comma and a space.</p>
ClassMethod PropertyNames(pProperties As %String) As %String [ Private ]
{
    Set tNames = ""
    For tI = 1:1:$Length(pProperties, ",") {
        Set tName = $ZStrip($Piece($Piece($Piece(pProperties, ",", tI), ":", 1), "(", 1), "<>W")
        If tName '= "" Set tNames = tNames _ $Select(tNames = "": "", 1: ", ") _ tName
    }
    Quit tNames
}

/// <p>Whether the index row <var>pRow</var> is never advised on: a key or primary-key index, or an index with no field, as the extent index is.</p>
ClassMethod Skipped(pRow As %DynamicObject) As %Boolean [ Private ]
{
    If ($ZConvert(pRow.%Get("Type"), "L") = "key") || ''pRow.%Get("PrimaryKey") || ''pRow.%Get("IdKey") Quit 1
    Quit (..PropertyNames(pRow.%Get("Properties")) = "")
}

/// <p>The temporary-file lines of <var>pPlan</var>, one to a line, or <code>""</code> when it has none.</p>
ClassMethod TempFileLines(pPlan As %String) As %String [ Private ]
{
    Set tText = ""
    Set tMatcher = ##class(%Regex.Matcher).%New(..#TEMPFILEPATTERN, pPlan)
    While tMatcher.Locate() {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ $ZStrip(tMatcher.Group(0), "<>W")
    }
    Quit tText
}

/// <p>The indices <var>pPlan</var> reads, as a list of <code>SCHEMA.TABLE.INDEX</code> upper-cased. <var>pLines</var> is the map-read lines themselves,
/// one to a line, the plan text an unused-index finding carries.</p>
ClassMethod UsedIndexes(pPlan As %String, Output pLines As %String) As %List [ Private ]
{
    Set pLines = ""
    Set tList = ""
    Set tMatcher = ##class(%Regex.Matcher).%New(..#MAPPATTERN, pPlan)
    While tMatcher.Locate() {
        Set tList = tList _ $ListBuild($ZConvert(tMatcher.Group(1) _ "." _ tMatcher.Group(2) _ "." _ tMatcher.Group(3), "U"))
        Set pLines = pLines _ $Select(pLines = "": "", 1: $Char(10)) _ tMatcher.Group(0)
    }
    Quit tList
}

}
