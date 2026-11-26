/// <p>The text scan behind Alternate plans (Story 21.28, AD-21): the table and condition counts of a statement, the cross-product test and the
/// <code>%NOPARALLEL</code> keyword inserted after each FROM clause's keyword. Pure: it reads the statement's text and the view texts it is given, and
/// never the instance.</p>
/// <p>A statement is cut into tokens with comments, string literals and delimited identifiers each reduced to one placeholder token, so nothing inside
/// them is read as a keyword. The tables are the clause FROM keywords, the commas that separate the relations of a FROM clause (or of an UPDATE up to its
/// SET) at the same parenthesis depth, the JOIN keywords, and one for each UPDATE and each INSERT. The conditions are WHERE, ON, AND, OR, <code>&amp;</code>,
/// <code>!</code> and HAVING, and one for each column of a USING list. A FROM inside SUBSTRING, TRIM, EXTRACT or OVERLAY, or after DISTINCT, belongs to
/// the function and is not a clause. <code>BETWEEN ... AND</code> and a derived table count one more than they hold, which only makes the bound
/// stricter.</p>
Class OcuPilot.Port.SqlAlternateScan Extends %RegisteredObject
{

/// <p>The functions whose parentheses may hold a FROM that is not a clause.</p>
Parameter FUNCTIONS = "SUBSTRING,TRIM,EXTRACT,OVERLAY";

/// <p>The keywords that end a FROM clause (or an UPDATE's relation list) at their own parenthesis depth.</p>
Parameter CLAUSEENDS = "WHERE,GROUP,HAVING,ORDER,UNION,INTERSECT,EXCEPT,LIMIT,OFFSET,FETCH,SET";

/// <p>The keyword the instance reads as the first token after FROM to run a statement without parallel workers.</p>
Parameter NOPARALLEL = "%NOPARALLEL";

/// <p>The tables and conditions <var>pText</var> holds, in <var>pTables</var> and <var>pConditions</var>. <var>pViews</var>, an array of the texts of
/// the views the statement reads, adds each view's own two counts to both; <var>pRelations</var>, the number of relations the instance records for the
/// statement, is the least <var>pTables</var> may be.</p>
ClassMethod Count(pText As %String, pViews As %DynamicArray = "", pRelations As %Integer = 0, Output pTables As %Integer, Output pConditions As %Integer)
{
    Do ..Walk(pText, .pTables, .pConditions, .tInsert)
    If $IsObject(pViews) {
        Set tIterator = pViews.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tView) {
            Do ..Walk(tView, .tTables, .tConditions, .tIgnored)
            Set pTables = pTables + tTables
            Set pConditions = pConditions + tConditions
        }
    }
    If pRelations > pTables Set pTables = pRelations
}

/// <p>Whether a statement with <var>pTables</var> tables and <var>pConditions</var> conditions joins some table by no condition: fewer conditions than
/// the tables minus one.</p>
ClassMethod CrossProduct(pTables As %Integer, pConditions As %Integer) As %Boolean
{
    Quit pConditions < (pTables - 1)
}

/// <p>The statement's own text as <var>pPlan</var>, a plan the instance explained, gives it: the lines after the one reading <code>SQL:</code> up to the
/// next blank line, each stripped and joined by one space, with the <code>/*#OPTIONS ... */</code> comment the instance appends removed. The literals in it
/// are the <code>?</code> the instance replaced them with. <code>""</code> when the plan holds no such section.</p>
ClassMethod StatementText(pPlan As %String) As %String
{
    Set tLines = $ListFromString($Translate(pPlan, $Char(13)), $Char(10))
    Set tText = ""
    Set tIn = 0
    Set tPointer = 0
    While $ListNext(tLines, tPointer, tLine) {
        Set tLine = $ZStrip(tLine, "<>W")
        If 'tIn {
            If tLine = "SQL:" Set tIn = 1
            Continue
        }
        If tLine = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: " ") _ tLine
    }
    Set tStart = $Find(tText, "/*#OPTIONS")
    If tStart > 0 {
        Set tEnd = $Find(tText, "*/", tStart)
        Set tText = $ZStrip($Extract(tText, 1, tStart - 11) _ $Select(tEnd = 0: "", 1: $Extract(tText, tEnd, *)), "<>W")
    }
    Quit tText
}

/// <p><var>pText</var> with <code>%NOPARALLEL</code> inserted after each FROM keyword that opens a FROM clause, which the instance reads as the
/// statement's instruction to run without parallel workers. A FROM inside SUBSTRING, TRIM, EXTRACT or OVERLAY or after DISTINCT, DELETE's FROM, a FROM
/// already followed by the keyword, and everything inside a comment, a string literal or a delimited identifier are left as they are.</p>
ClassMethod NoParallel(pText As %String) As %String
{
    Do ..Walk(pText, .tTables, .tConditions, .tInsert)
    Set tOut = ""
    Set tFrom = 1
    Set tAt = ""
    For {
        Set tAt = $Order(tInsert(tAt))
        If tAt = "" Quit
        Set tNext = $Extract(pText, tAt + 1)
        Set tOut = tOut _ $Extract(pText, tFrom, tAt) _ " " _ ..#NOPARALLEL _ $Select((tNext '= "") && ($Ascii(tNext) <= 32): "", 1: " ")
        Set tFrom = tAt + 1
    }
    Quit tOut _ $Extract(pText, tFrom, *)
}

/// <p>Walk <var>pText</var>'s tokens: the counts, and in <var>pInsert</var> one subscript for the last position of each FROM keyword that
/// <method>NoParallel</method> follows with the keyword.</p>
ClassMethod Walk(pText As %String, Output pTables As %Integer, Output pConditions As %Integer, Output pInsert) [ Private ]
{
    Kill pInsert
    Set (pTables, pConditions) = 0
    Do ..Tokens(pText, .tTok)
    Set tFunctions = $ListFromString(..#FUNCTIONS)
    Set tEnds = $ListFromString(..#CLAUSEENDS)
    Set tDepth = 0
    Set tFrom(0) = 0
    Set tUsing(0) = 0
    Set tOpener(0) = ""
    For tN = 1:1:tTok {
        Set tWord = tTok(tN)
        Set tPrevious = $Select(tN > 1: tTok(tN - 1), 1: "")
        Set tFollowing = $Select(tN < tTok: tTok(tN + 1), 1: "")
        If tWord = "(" {
            Set tDepth = tDepth + 1
            Set tOpener(tDepth) = tPrevious
            Set tFrom(tDepth) = 0
            Set tUsing(tDepth) = (tPrevious = "USING")
            If tUsing(tDepth) Set pConditions = pConditions + 1
            Continue
        }
        If tWord = ")" {
            If tDepth > 0 {
                Kill tFrom(tDepth), tUsing(tDepth), tOpener(tDepth)
                Set tDepth = tDepth - 1
            }
            Continue
        }
        If tWord = "," {
            If tFrom(tDepth) Set pTables = pTables + 1
            If tUsing(tDepth) Set pConditions = pConditions + 1
            Continue
        }
        If tWord = "FROM" {
            If (tDepth > 0) && $ListFind(tFunctions, tOpener(tDepth)) Continue
            If tPrevious = "DISTINCT" Continue
            Set pTables = pTables + 1
            Set tFrom(tDepth) = 1
            Set tBack = tN - 1
            While (tBack > 0) && ($Extract(tTok(tBack), 1) = "%") {
                Set tBack = tBack - 1
            }
            If ((tBack > 0) && (tTok(tBack) = "DELETE")) || (tFollowing = ..#NOPARALLEL) Continue
            Set pInsert(tTok(tN, "e")) = ""
            Continue
        }
        If tWord = "JOIN" {
            Set pTables = pTables + 1
            Continue
        }
        If tWord = "INSERT" {
            Set pTables = pTables + 1
            Continue
        }
        If tWord = "UPDATE" {
            If (tPrevious '= "OR") && (tPrevious '= "FOR") {
                Set pTables = pTables + 1
                Set tFrom(tDepth) = 1
            }
            Continue
        }
        If $ListFind(tEnds, tWord) {
            Set tFrom(tDepth) = 0
            If (tWord = "WHERE") || (tWord = "HAVING") Set pConditions = pConditions + 1
            Continue
        }
        If (tWord = "ON") || (tWord = "AND") || (tWord = "OR") || (tWord = "&") || (tWord = "!") {
            Set pConditions = pConditions + 1
            Continue
        }
        If (tWord = "USING") && (tFollowing '= "(") Set pConditions = pConditions + 1
    }
}

/// <p>The tokens of <var>pText</var> in <var>pTok</var>: the count at <code>pTok</code>, and for each token <code>pTok(n)</code>, its word in upper case,
/// its single punctuation character, or <code>'</code> or <code>"</code> for a whole string literal or delimited identifier, with <code>pTok(n, "s")</code>
/// and <code>pTok(n, "e")</code> its first and last positions. Comments and white space yield none.</p>
ClassMethod Tokens(pText As %String, Output pTok) [ Private ]
{
    Kill pTok
    Set pTok = 0
    Set tLength = $Length(pText)
    Set tAt = 1
    While tAt <= tLength {
        Set tChar = $Extract(pText, tAt)
        Set tNext = $Extract(pText, tAt + 1)
        If (tChar = "-") && (tNext = "-") {
            Set tAt = tAt + 2
            While (tAt <= tLength) && ($Extract(pText, tAt) '= $Char(10)) && ($Extract(pText, tAt) '= $Char(13)) {
                Set tAt = tAt + 1
            }
            Continue
        }
        If (tChar = "/") && (tNext = "*") {
            Set tFound = $Find(pText, "*/", tAt + 2)
            Set tAt = $Select(tFound = 0: tLength + 1, 1: tFound)
            Continue
        }
        If (tChar = "'") || (tChar = """") {
            Set tEnd = ..QuotedEnd(pText, tAt, tChar)
            Do ..Push(.pTok, tChar, tAt, tEnd)
            Set tAt = tEnd + 1
            Continue
        }
        If ..IsWordChar(tChar) {
            Set tEnd = tAt
            While (tEnd < tLength) && ..IsWordChar($Extract(pText, tEnd + 1)) {
                Set tEnd = tEnd + 1
            }
            Do ..Push(.pTok, $ZConvert($Extract(pText, tAt, tEnd), "U"), tAt, tEnd)
            Set tAt = tEnd + 1
            Continue
        }
        If $Ascii(tChar) > 32 Do ..Push(.pTok, tChar, tAt, tAt)
        Set tAt = tAt + 1
    }
}

/// <p>The last position of the quoted run in <var>pText</var> that starts at <var>pStart</var> with the quote <var>pQuote</var>, a doubled quote
/// being one character of the run; the end of the text for a run that never closes.</p>
ClassMethod QuotedEnd(pText As %String, pStart As %Integer, pQuote As %String) As %Integer [ Private ]
{
    Set tAt = pStart + 1
    For {
        Set tFound = $Find(pText, pQuote, tAt)
        If tFound = 0 Quit
        If $Extract(pText, tFound) '= pQuote Return tFound - 1
        Set tAt = tFound + 1
    }
    Quit $Length(pText)
}

/// <p>Whether <var>pChar</var> can be part of a word: a letter, a digit, <code>_ % $ # . @</code>, or a character above ASCII.</p>
ClassMethod IsWordChar(pChar As %String) As %Boolean [ Private ]
{
    If pChar = "" Quit 0
    If $Ascii(pChar) > 127 Quit 1
    Quit $Match(pChar, "[A-Za-z0-9_%$#.@]")
}

/// <p>Append the token <var>pToken</var>, from <var>pStart</var> to <var>pEnd</var>, to <var>pTok</var>.</p>
ClassMethod Push(ByRef pTok, pToken As %String, pStart As %Integer, pEnd As %Integer) [ Private ]
{
    Set tN = pTok + 1
    Set pTok = tN
    Set pTok(tN) = pToken
    Set pTok(tN, "s") = pStart
    Set pTok(tN, "e") = pEnd
}

}
