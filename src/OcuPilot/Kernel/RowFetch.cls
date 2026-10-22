/// <p>The row reader the SQL console's port and the analytics port share (Story 19.6, Story 20.33; AD-36): the rows of an open SQL
/// result set as bounded text cells. It is a class both ports <b>extend</b>, not one they call, because a port reads its result set
/// while the namespace is switched to the one the statement ran in (AD-16), where a call to another <code>OcuPilot.*</code> class
/// does not resolve and a method compiled into the port's own class does.</p>
/// <p>The bounds are this class's parameters, which a port overrides: <parameter>MAXCELL</parameter> and
/// <parameter>MAXANSWER</parameter>.</p>
Class OcuPilot.Kernel.RowFetch [ Abstract ]
{

/// <p>The bounds an answer is held to: a cell, and the whole answer measured as each kept row's JSON text, cut by whole rows from
/// the end.</p>
Parameter MAXCELL As INTEGER = 1000;

Parameter MAXANSWER As INTEGER = 1000000;

/// <p>Read the rows of the open result set <var>pSet</var> (a <class>%SQL.StatementResult</class>) as text cells, at most
/// <var>pMaxRows</var>, one more fetched to learn whether more exist, each cell cut at <parameter>MAXCELL</parameter> characters,
/// and rows kept while their JSON text totals at most <parameter>MAXANSWER</parameter> characters. The width is
/// <var>pColumns</var>, the array of the set's column names. <var>pRows</var> is an array of rows, each an array of strings;
/// <var>pMore</var> is 1 when a fetched row was not kept, past <var>pMaxRows</var> or dropped by the answer's cut, and
/// <var>pCut</var> is 1 when a cell was cut, the two parts of <var>pTruncated</var>. It names no namespace and reads only
/// <var>pSet</var>, so the caller's namespace is the one the statement ran in.</p>
ClassMethod FetchRows(pSet, pColumns As %DynamicArray, pMaxRows As %Integer, Output pRows As %DynamicArray, Output pTruncated As %Boolean, Output pMore As %Boolean, Output pCut As %Boolean)
{
    Set tWidth = pColumns.%Size()
    Set pRows = []
    Set tTotal = 0
    Set pTruncated = 0
    Set pMore = 0
    Set pCut = 0
    While pSet.%Next() {
        If pRows.%Size() >= pMaxRows {
            Set pTruncated = 1
            Set pMore = 1
            Quit
        }
        Set tRow = []
        For tI = 1:1:tWidth {
            Set tValue = pSet.%GetData(tI)
            If $IsObject(tValue) Set tValue = ""
            If $Length(tValue) > ..#MAXCELL {
                Set tValue = $Extract(tValue, 1, ..#MAXCELL - 1) _ $Char(8230)
                Set pTruncated = 1
                Set pCut = 1
            }
            Do tRow.%Push(tValue, "string")
        }
        Set tLength = $Length(tRow.%ToJSON())
        If tTotal + tLength > ..#MAXANSWER {
            Set pTruncated = 1
            Set pMore = 1
            Quit
        }
        Set tTotal = tTotal + tLength
        Do pRows.%Push(tRow)
    }
}

}
