/// <p>The text scan behind Alternate plans (Story 21.28, AD-21): the table and condition counts of a statement, the cross-product test and the
/// <code>%NOPARALLEL</code> keyword inserted after each FROM clause's keyword. Pure: it reads the statement's text and the view texts it is given, and
/// never the instance.</p>
/// <p>A statement is cut into tokens with comments, string literals and delimited identifiers each reduced to one placeholder token, so nothing inside
/// them is read as a keyword. The tables are the clause FROM keywords, the commas that separate the relations of a FROM clause (or of an UPDATE up to its
/// SET) at the same parenthesis depth, the JOIN keywords, and one for each UPDATE and each INSERT. The conditions are WHERE, ON, AND, OR, <code>&amp;</code>,
/// <code>!</code> (not the <code>!</code> of <code>!=</code>) and HAVING, and one for each column of a USING list. A FROM inside SUBSTRING, TRIM, EXTRACT
/// or OVERLAY, or after DISTINCT, belongs to the function and is not a clause. <code>BETWEEN ... AND</code> and a derived table count one more than they
/// hold, which makes the bound stricter and the cross-product test looser.</p>
/// <p>The cross-product test reads joins, not conditions. A join is a comparison of two columns that each carry a qualifier (<code>t1.B = t2.B</code>), the
/// qualifiers differing, standing as a conjunct of its WHERE or ON clause: the token before it is WHERE, ON, AND, <code>&amp;</code> or an opening
/// parenthesis that follows one of those, the token after it is a clause end, AND, <code>&amp;</code> or a closing parenthesis, and no OR, <code>!</code> or
/// NOT joins it at its own level or an enclosing one. Anything else is not counted, so a shape the scan cannot read is refused, never passed: an
/// unqualified column, a column of three parts, an expression around a side, an OR, a subquery that no condition correlates. Each USING column is a
/// join.</p>
Class OcuPilot.Port.SqlAlternateScan Extends %RegisteredObject
{

/// <p>The functions whose parentheses may hold a FROM that is not a clause.</p>
Parameter FUNCTIONS = "SUBSTRING,TRIM,EXTRACT,OVERLAY";

/// <p>The keywords that end a FROM clause (or an UPDATE's relation list) at their own parenthesis depth.</p>
Parameter CLAUSEENDS = "WHERE,GROUP,HAVING,ORDER,UNION,INTERSECT,EXCEPT,LIMIT,OFFSET,FETCH,SET";

/// <p>The keyword the instance reads as the first token after FROM to run a statement without parallel workers.</p>
Parameter NOPARALLEL = "%NOPARALLEL";

/// <p>The keywords, besides <parameter>CLAUSEENDS</parameter> and the comma, that end the conjunct a join stands in.</p>
Parameter JOINENDS = "JOIN,INNER,LEFT,RIGHT,FULL,CROSS,NATURAL,OUTER,ON,USING,FROM,SELECT";

/// <p>The joins counted for one text stop here: a text that passes the bound has at most four tables and so needs at most three.</p>
Parameter JOINCAP = 8;

/// <p>The tables and conditions <var>pText</var> holds, in <var>pTables</var> and <var>pConditions</var>. <var>pViews</var>, an array of the texts of
/// the views the statement reads, adds each view's own two counts to both; <var>pRelations</var>, the number of relations the instance records for the
/// statement, is the least <var>pTables</var> may be. <var>pCross</var> is 1 when the statement's own text, or the text of any view, has a table no join
/// reaches (<method>CrossProduct</method> over that text's own tables and joins).</p>
ClassMethod Count(pText As %String, pViews As %DynamicArray = "", pRelations As %Integer = 0, Output pTables As %Integer, Output pConditions As %Integer, Output pCross As %Boolean)
{
    Do ..Walk(pText, .pTables, .pConditions, .tInsert, .tJoins)
    Set pCross = ..CrossProduct(pTables, tJoins)
    If $IsObject(pViews) {
        Set tIterator = pViews.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tView) {
            Do ..Walk(tView, .tTables, .tConditions, .tIgnored, .tViewJoins)
            Set pTables = pTables + tTables
            Set pConditions = pConditions + tConditions
            If ..CrossProduct(tTables, tViewJoins) Set pCross = 1
        }
    }
    If pRelations > pTables Set pTables = pRelations
}

/// <p>Whether a text with <var>pTables</var> tables and <var>pJoins</var> joins leaves some table unjoined: fewer joins than the tables minus one.</p>
ClassMethod CrossProduct(pTables As %Integer, pJoins As %Integer) As %Boolean
{
    Quit pJoins < (pTables - 1)
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

/// <p>Walk <var>pText</var>'s tokens: the counts, <var>pJoins</var> (at most <parameter>JOINCAP</parameter>), and in <var>pInsert</var> one subscript
/// for the last position of each FROM keyword that <method>NoParallel</method> follows with the keyword.</p>
ClassMethod Walk(pText As %String, Output pTables As %Integer, Output pConditions As %Integer, Output pInsert, Output pJoins As %Integer) [ Private ]
{
    Kill pInsert
    Set (pTables, pConditions, pJoins) = 0
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
            If tUsing(tDepth) {
                Set pConditions = pConditions + 1
                Set pJoins = pJoins + 1
            }
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
            If tUsing(tDepth) {
                Set pConditions = pConditions + 1
                Set pJoins = pJoins + 1
            }
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
        If (tWord = "ON") || (tWord = "AND") || (tWord = "OR") || (tWord = "&") || ((tWord = "!") && (tFollowing '= "=")) {
            Set pConditions = pConditions + 1
            Continue
        }
        If (tWord = "USING") && (tFollowing '= "(") Set pConditions = pConditions + 1
        If (pJoins < ..#JOINCAP) && ..IsColumn(tWord) && ..JoinAt(.tTok, tN) Set pJoins = pJoins + 1
    }
}

/// <p>Whether <var>pWord</var>, an upper-case word token, is a column with one qualifier: two names of letters, digits and <code>_ % $ # @</code> that
/// start with a letter, <code>_</code> or <code>%</code>, joined by one dot.</p>
ClassMethod IsColumn(pWord As %String) As %Boolean [ Private ]
{
    If $Length(pWord, ".") '= 2 Quit 0
    Quit $Match(pWord, "[A-Z_%][A-Z0-9_%$#@]*\.[A-Z_%][A-Z0-9_%$#@]*")
}

/// <p>Whether the qualified column at token <var>pN</var> opens a join: a comparison operator, then a qualified column with another qualifier, the
/// whole standing as a conjunct (<method>Conjunct</method>).</p>
ClassMethod JoinAt(ByRef pTok, pN As %Integer) As %Boolean [ Private ]
{
    Set tAt = pN + 1
    Set tOperator = $Get(pTok(tAt))
    If '$ListFind($ListBuild("=", "<", ">", "!"), tOperator) Quit 0
    Set tAt = tAt + 1
    Set tSecond = $Get(pTok(tAt))
    If (tOperator '= "=") && ((tSecond = "=") || ((tOperator = "<") && (tSecond = ">"))) Set tAt = tAt + 1
    Set tRight = $Get(pTok(tAt))
    If '..IsColumn(tRight) || ($Piece(tRight, ".", 1) = $Piece(pTok(pN), ".", 1)) Quit 0
    Quit ..Conjunct(.pTok, pN, tAt)
}

/// <p>Whether the comparison from token <var>pLeft</var> to token <var>pRight</var> stands as a conjunct: the token before it and the one after it are
/// boundaries, and scanning outward at its own level and then each enclosing one, to the WHERE or ON that opens the clause, meets no OR and no
/// <code>!</code>; an enclosing parenthesis must itself follow WHERE, ON, AND, <code>&amp;</code> or another parenthesis. A closing parenthesis or a clause
/// end after the comparison ends the scan forward.</p>
ClassMethod Conjunct(ByRef pTok, pLeft As %Integer, pRight As %Integer) As %Boolean [ Private ]
{
    Set tOpeners = $ListBuild("WHERE", "ON", "AND", "&", "(")
    Set tStops = $ListFromString(..#CLAUSEENDS) _ $ListFromString(..#JOINENDS) _ $ListBuild(",")
    Set tNext = $Get(pTok(pRight + 1))
    If '$ListFind(tOpeners, $Get(pTok(pLeft - 1))) Quit 0
    If (tNext '= "") && (tNext '= "AND") && (tNext '= "&") && (tNext '= ")") && '$ListFind(tStops, tNext) Quit 0
    Set tDepth = 0
    Set tGroups = 0
    Set tBound = 0
    Set tAt = pLeft - 1
    While tAt >= 1 {
        Set tWord = pTok(tAt)
        If tWord = ")" {
            Set tDepth = tDepth + 1
        } ElseIf tWord = "(" {
            If tDepth > 0 {
                Set tDepth = tDepth - 1
            } Else {
                If '$ListFind(tOpeners, $Get(pTok(tAt - 1))) Return 0
                Set tGroups = tGroups + 1
            }
        } ElseIf tDepth = 0 {
            If (tWord = "OR") || ((tWord = "!") && ($Get(pTok(tAt + 1)) '= "=")) Return 0
            If (tWord = "WHERE") || (tWord = "ON") {
                Set tBound = 1
                Quit
            }
        }
        Set tAt = tAt - 1
    }
    If 'tBound Quit 0
    Set tDepth = 0
    Set tAt = pRight + 1
    While tAt <= pTok {
        Set tWord = pTok(tAt)
        If tWord = "(" {
            Set tDepth = tDepth + 1
        } ElseIf tWord = ")" {
            If tDepth > 0 {
                Set tDepth = tDepth - 1
            } ElseIf tGroups > 0 {
                Set tGroups = tGroups - 1
            } Else {
                Quit
            }
        } ElseIf tDepth = 0 {
            If (tWord = "OR") || ((tWord = "!") && ($Get(pTok(tAt + 1)) '= "=")) Return 0
            If $ListFind(tStops, tWord) Quit
        }
        Set tAt = tAt + 1
    }
    Quit 1
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
