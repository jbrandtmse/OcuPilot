/// <p>Story 21.6's probe objects, created in a namespace by the tests that read and change its statement index and cached queries, and removed by
/// <method>Remove</method>: the tables <parameter>FIRST</parameter> and <parameter>SECOND</parameter>, and in the namespace's statement index
/// the statements that read them.</p>
/// <ul>
/// <li><parameter>QUERYONE</parameter> and <parameter>QUERYTWO</parameter> read the first table and <parameter>QUERYOTHER</parameter> reads the
/// second, each run so that it holds one cached query; <parameter>QUERYONE</parameter> also holds run statistics, which
/// <method>SetStatistics</method> writes, since the instance writes them on its own schedule.</li>
/// <li><parameter>QUERYTWO</parameter> carries the plan error <parameter>PLANERROR</parameter>, set through the vendor's own update.</li>
/// <li><parameter>QUERYSTALE</parameter> reads the first table and had its cached query purged, so the index holds no location for it.</li>
/// </ul>
/// <p><method>Table</method> makes Story 21.25's tables, which carry rows and two indices of their own, in <parameter>TABLESCHEMA</parameter> or, given a
/// name, in <parameter>DELIMITEDSCHEMA</parameter>, whose name holds a space, or in the schema it is given, such as <parameter>QUOTEDSCHEMA</parameter>,
/// whose name holds a double quote; <method>Remove</method> purges their cached queries and drops them too.</p>
/// <p><method>Remove</method> unfreezes every probe statement and clears its plan error through the vendor calls that set them, purges both tables'
/// cached queries, then drops both tables. The statement-index entries of the same four texts stay and are reused by the next
/// <method>Make</method>. <method>MakeOwn</method> runs the one statement over OcuPilot's own table that the own-statement tests judge, in the
/// install namespace, and <method>RemoveOwn</method> puts it back.</p>
Class OcuPilot.Test.SqlTuningProbe Extends %RegisteredObject
{

Parameter FIRST = "OcuProbe216.T1";

Parameter SECOND = "OcuProbe216.T2";

Parameter QUERYONE = "SELECT A FROM OcuProbe216.T1";

Parameter QUERYTWO = "SELECT B FROM OcuProbe216.T1";

Parameter QUERYOTHER = "SELECT A FROM OcuProbe216.T2";

Parameter QUERYSTALE = "SELECT A, B FROM OcuProbe216.T1";

/// <p>A statement over one of OcuPilot's own tables, distinct from any statement the product runs.</p>
Parameter OWNQUERY = "SELECT COUNT(*) AS Probe216 FROM OcuPilot_Kernel_State.Version";

Parameter PLANERROR = "probe plan error";

/// <p>The schema of the tables <method>Table</method> makes (Story 21.25), and the two indices each carries.</p>
Parameter TABLESCHEMA = "OcuProbe225";

Parameter INDEXB = "IdxB";

Parameter INDEXC = "IdxC";

/// <p>The schema of the tables <method>Table</method> makes when it is given a name: one SQL reaches only as a delimited identifier.</p>
Parameter DELIMITEDSCHEMA = "OcuProbe225 Delim";

/// <p>A schema whose name holds a double quote, which SQL reaches only as a delimited identifier with the quote doubled.</p>
Parameter QUOTEDSCHEMA = "OcuProbe225 Q""s";

/// <p>Create the probe objects in <var>pNamespace</var>, after removing any an earlier run left.</p>
ClassMethod Make(pNamespace As %String) As %Status
{
    Set tSC = ..Remove(pNamespace)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ..Run("CREATE TABLE " _ ..#FIRST _ " (A INTEGER, B VARCHAR(20))")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run("CREATE TABLE " _ ..#SECOND _ " (A INTEGER, B VARCHAR(20))")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run("INSERT INTO " _ ..#FIRST _ " (A, B) VALUES (1, 'x')")
        If $$$ISERR(tSC) Quit
        Set tSC = $SYSTEM.SQL.PurgeQueries({"table": [(..#FIRST)]})
        If $$$ISERR(tSC) Quit
        For tText = ..#QUERYONE, ..#QUERYTWO, ..#QUERYOTHER, ..#QUERYSTALE {
            Set tSC = ..Run(tText)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set tSC = $SYSTEM.SQL.PurgeQueries({"class": [(..LocationOf(pNamespace, ..HashOf(pNamespace, "SELECT A , B FROM")))]})
        If $$$ISERR(tSC) Quit
        Do UpdateSQLIndex^%SYS.SQLSRV(..HashOf(pNamespace, "SELECT B FROM"), ..#PLANERROR)
        Do ..SetStatistics(..HashOf(pNamespace, "SELECT A FROM"))
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Put the probe's statements and tables back as an unmade probe has them, in <var>pNamespace</var>.</p>
ClassMethod Remove(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        For tToken = "SELECT A FROM", "SELECT B FROM", "SELECT A , B FROM" {
            For tRelation = "OCUPROBE216.T1", "OCUPROBE216.T2" {
                Set tHash = ..HashOf(pNamespace, tToken, tRelation)
                If tHash = "" Continue
                If $Extract(..Facts(pNamespace, tHash).PlanState, 1, 7) = "Frozen/" Do $SYSTEM.SQL.Statement.UnfreezeStatement(tHash)
                If ..Facts(pNamespace, tHash).PlanState = "Unfrozen/Parallel" Do ..SetPlanFlag(tHash, pNamespace, 0)
                Do UpdateSQLIndex^%SYS.SQLSRV(tHash, "")
                Do $SYSTEM.SQL.Statement.ClearStatement(tHash)
            }
        }
        Do ..RemoveStats(pNamespace)
        Do $SYSTEM.SQL.PurgeQueries({"table": [(..#FIRST), (..#SECOND)]})
        Do ..Run("DROP TABLE " _ ..#FIRST)
        Do ..Run("DROP TABLE " _ ..#SECOND)
        Set $NAMESPACE = tOrigNS
        Set tSC = ..RemoveTables(pNamespace)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the table <code>OcuProbe225.T</code><var>pNumber</var> in <var>pNamespace</var>, named by <var>pTable</var>, with the columns <code>A</code>,
/// <code>B</code> and <code>C</code>, the indices <parameter>INDEXB</parameter> and <parameter>INDEXC</parameter> and <var>pRows</var> rows
/// (Story 21.25), in the schema <parameter>TABLESCHEMA</parameter>. Given <var>pName</var>, the table is <var>pName</var> in
/// <var>pSchema</var> (<parameter>DELIMITEDSCHEMA</parameter> by default), created as a delimited identifier (<method>SqlName</method>), and
/// <var>pNumber</var> is not used. A table of that name an earlier run left is dropped first. <method>Remove</method> drops every table of the three
/// schemas.</p>
ClassMethod Table(pNamespace As %String, pNumber As %Integer, pRows As %Integer, Output pTable As %String, pName As %String = "", pSchema As %String = {..#DELIMITEDSCHEMA}) As %Status
{
    Set pTable = $Select(pName = "": ..#TABLESCHEMA _ ".T" _ pNumber, 1: pSchema _ "." _ pName)
    Set tSqlName = $Select(pName = "": pTable, 1: ..SqlName(pTable))
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = pNamespace
        Do $SYSTEM.SQL.PurgeQueries({"table": [(pTable)]})
        Do ..Run("DROP TABLE " _ tSqlName)
        Set tSC = ..Run("CREATE TABLE " _ tSqlName _ " (A INTEGER, B VARCHAR(20), C VARCHAR(20))")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run("CREATE INDEX " _ ..#INDEXB _ " ON TABLE " _ tSqlName _ " (B)")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run("CREATE INDEX " _ ..#INDEXC _ " ON TABLE " _ tSqlName _ " (C)")
        If $$$ISERR(tSC) Quit
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("INSERT INTO " _ tSqlName _ " (A, B, C) VALUES (?, ?, ?)")
        If $$$ISERR(tSC) Quit
        For tI = 1:1:pRows {
            Set tResult = tStatement.%Execute(tI, "v" _ tI, "w" _ tI)
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
                Quit
            }
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Kill the global of index <var>pIndex</var> of table <var>pTable</var> in <var>pNamespace</var>, so the index holds no entry and a rebuild is
/// observable (Story 21.25).</p>
ClassMethod KillIndex(pNamespace As %String, pTable As %String, pIndex As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tGlobal = ..IndexGlobal(pTable, pIndex)
        If tGlobal '= "" Kill @tGlobal
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>The global that holds index <var>pIndex</var> of table <var>pTable</var> in the current namespace, as the table's indices list reports it, or
/// <code>""</code>.</p>
ClassMethod IndexGlobal(pTable As %String, pIndex As %String) As %String
{
    Set tGlobal = ""
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%PrepareClassQuery("%SQL.Manager.Catalog", "Indices")
    If $$$ISERR(tSC) Quit ""
    Set tResult = tStatement.%Execute($Piece(pTable, ".", 1), $Piece(pTable, ".", 2))
    While tResult.%Next() {
        If tResult.%Get("INDEX_NAME") = pIndex {
            Set tGlobal = tResult.%Get("GLOBAL")
            Quit
        }
    }
    Quit tGlobal
}

/// <p>How many rows a query through index <var>pIndex</var> of <var>pTable</var> returns in <var>pNamespace</var>: a count over the indexed column
/// <var>pColumn</var>, which the instance answers from the index alone. A killed index answers fewer than the table's rows.</p>
ClassMethod IndexedCount(pNamespace As %String, pTable As %String, pColumn As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT COUNT(*) FROM " _ pTable _ " WHERE " _ pColumn _ " %STARTSWITH ?")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute($Select(pColumn = "B": "v", 1: "w"))
            If tResult.%Next() Set tCount = tResult.%GetData(1)
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The entries index <var>pIndex</var> of <var>pTable</var> holds in <var>pNamespace</var>, counted in its global directly (Story 21.25).</p>
ClassMethod IndexEntries(pNamespace As %String, pTable As %String, pIndex As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = ..IndexGlobal(pTable, pIndex)
        If tRoot '= "" {
            Set tValue = ""
            For {
                Set tValue = $Order(@tRoot@(tValue))
                If tValue = "" Quit
                Set tId = ""
                For {
                    Set tId = $Order(@tRoot@(tValue, tId))
                    If tId = "" Quit
                    Set tCount = tCount + 1
                }
            }
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p><var>pTable</var>, a <code>Schema.Table</code> name, written as SQL text reads it when either part needs delimiting: each part quoted, a double
/// quote inside a part doubled.</p>
ClassMethod SqlName(pTable As %String) As %String
{
    Quit """" _ $Replace($Piece(pTable, ".", 1), """", """""") _ """.""" _ $Replace($Piece(pTable, ".", 2, *), """", """""") _ """"
}

/// <p>Run the copy-out script <var>pText</var>, one line at a time, in the process's own variables, as a person pasting it into a terminal would, and
/// answer its status variable <code>tSC</code> where it sets one. The namespace the caller was in is restored first when a line throws.</p>
ClassMethod RunScript(pNamespace As %String, pText As %String) As %Status
{
    Set zOrig = $NAMESPACE
    Set zResult = $$$OK
    Try {
        Set $NAMESPACE = pNamespace
        For zI = 1:1:$Length(pText, $Char(10)) {
            Set zLine = $ZStrip($Piece(pText, $Char(10), zI), "<W")
            If zLine '= "" Xecute zLine
        }
        If $Data(tSC) && ($Get(tSC) '= 1) Set zResult = tSC
    } Catch zEx {
        Set $NAMESPACE = zOrig
        Set zResult = zEx.AsStatus()
    }
    Set $NAMESPACE = zOrig
    Quit zResult
}

/// <p>The tables of the schema <var>pSchema</var> (<parameter>TABLESCHEMA</parameter> by default) in <var>pNamespace</var>, as a <class>%List</class>
/// of <code>Schema.Table</code> names as the instance holds them.</p>
ClassMethod TablesOf(pNamespace As %String, pSchema As %String = {..#TABLESCHEMA}) As %List
{
    Set tList = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT TABLE_SCHEMA || '.' || TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ?")
        Set tResult = tStatement.%Execute(pSchema)
        While tResult.%Next() {
            Set tList = tList _ $ListBuild(tResult.%GetData(1))
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch {
        Set tList = $ListBuild("TablesOf failed")
    }
    Set $NAMESPACE = tOrigNS
    Quit tList
}

/// <p>Read the instance's schema list (<code>INFORMATION_SCHEMA.SCHEMATA</code>) in <var>pNamespace</var> to its end and answer <code>rows|sqlcode</code>:
/// the schemas read and the SQLCODE the read ended on, <code>100</code> for a list read whole and <code>-400</code> where the instance failed.</p>
ClassMethod SchemataRead(pNamespace As %String) As %String
{
    Set tAnswer = "unread"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute()
            Set tRows = 0
            While tResult.%Next() {
                Set tRows = tRows + 1
            }
            Set tAnswer = tRows _ "|" _ tResult.%SQLCODE
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Purge the cached queries of, then drop, every table of the schemas <parameter>TABLESCHEMA</parameter>, <parameter>DELIMITEDSCHEMA</parameter> and
/// <parameter>QUOTEDSCHEMA</parameter> in <var>pNamespace</var>. Dropping the last table of a schema whose name holds a double quote leaves the schema's entry in the
/// instance's schema index, and the instance's schema list (<code>INFORMATION_SCHEMA.SCHEMATA</code>) then fails; so the quoted schema is dropped
/// too, through the routine the instance's own <code>DROP SCHEMA</code> calls, which takes the name as an argument. A schema that is already gone
/// (SQLCODE -473) is not an error. <method>SchemataRead</method> reads the list.</p>
ClassMethod RemoveTables(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        For tSchema = ..#TABLESCHEMA, ..#DELIMITEDSCHEMA, ..#QUOTEDSCHEMA {
            Set tTables = ..TablesOf(pNamespace, tSchema)
            Set $NAMESPACE = pNamespace
            For tI = 1:1:$ListLength(tTables) {
                Do $SYSTEM.SQL.PurgeQueries({"table": [($List(tTables, tI))]})
                Do ..Run("DROP TABLE " _ $Select(tSchema = ..#TABLESCHEMA: $List(tTables, tI), 1: ..SqlName($List(tTables, tI))))
            }
            If tSchema = ..#QUOTEDSCHEMA {
                Set tSQLCODE = 0
                Set tMessage = ""
                Do DropSchema^%apiDDL(tSchema, 0, 0, .tSQLCODE, .tMessage)
                If (tSQLCODE '= 0) && (tSQLCODE '= -473) {
                    Set tSC = $$$ERROR($$$GeneralError, "the quoted schema was not dropped: SQLCODE " _ tSQLCODE _ " " _ tMessage)
                }
            }
            Set $NAMESPACE = tOrigNS
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The statistics the instance holds for <var>pTable</var> in <var>pNamespace</var>, read through the vendor's own calls: <code>kind size</code>,
/// the kind being <code>fixed</code>, <code>collected</code> or <code>none</code>, and the size the optimizer uses (the collected extent size unless the
/// table has fixed statistics). <code>unread</code> where a call raised.</p>
ClassMethod Statistics(pNamespace As %String, pTable As %String) As %String
{
    Set tAnswer = "unread"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSchema = $Piece(pTable, ".", 1)
        Set tName = $Piece(pTable, ".", 2)
        Set tFixed = ''##class(%SQL.Manager.Catalog).HasFixedStats(tSchema, tName)
        Set tCurrent = ##class(%SQL.Manager.Catalog).GetCurrentTableExtentSize(tSchema, tName)
        Kill tStat
        Do ##class(%SQL.Manager.Catalog).DisplayExtentDBStats(tSchema, tName, .tStatClass, .tStat, .tStatId)
        Set tCollected = $Select($IsObject($Get(tStat)): tStat.ExtentSize, 1: "")
        Set tStat = ""
        Set tKind = $Select(tFixed: "fixed", tCollected '= "": "collected", 1: "none")
        Set tAnswer = tKind _ " " _ $Select(tKind = "collected": +tCollected, 1: +tCurrent)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>Fix the extent size of <var>pTable</var> in <var>pNamespace</var> at <var>pSize</var> through the vendor's own call, so a test puts the table in
/// the state Clear fixed statistics acts on (Story 21.25).</p>
ClassMethod FixExtent(pNamespace As %String, pTable As %String, pSize As %Integer) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(%SQL.Manager.Catalog).SetTableExtentSize($Piece(pTable, ".", 1), $Piece(pTable, ".", 2), pSize, 0)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Set the fixed selectivity of field <var>pField</var> of <var>pTable</var> in <var>pNamespace</var> to <var>pSelectivity</var> with the outlier
/// selectivity, outlier value and average size <var>pOutlierSelectivity</var>, <var>pOutlierValue</var> and <var>pAverage</var>, through the vendor's own
/// call and after saving the table's collected statistics as its fixed ones, so a test puts the field in a state a setter then acts on (Story 21.31).
/// A precondition only.</p>
ClassMethod FixField(pNamespace As %String, pTable As %String, pField As %String, pSelectivity As %String, pOutlierSelectivity As %String = "", pOutlierValue As %String = "", pAverage As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If '##class(%SQL.Manager.Catalog).HasFixedStats($Piece(pTable, ".", 1), $Piece(pTable, ".", 2)) Set tSC = $SYSTEM.SQL.Stats.Table.FixTableStats(pTable)
        If $$$ISOK(tSC) Set tSC = ##class(%SQL.Manager.Catalog).SetFieldSelectivity($Piece(pTable, ".", 1), $Piece(pTable, ".", 2), pField, pSelectivity, 0, pOutlierSelectivity, pOutlierValue, pAverage)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Set the size of map <var>pMap</var> of <var>pTable</var> in <var>pNamespace</var> to <var>pBlocks</var> blocks of 2 KB through the vendor's own call,
/// after saving the table's collected statistics as its fixed ones (Story 21.31). A precondition only.</p>
ClassMethod FixMap(pNamespace As %String, pTable As %String, pMap As %String, pBlocks As %Integer) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If '##class(%SQL.Manager.Catalog).HasFixedStats($Piece(pTable, ".", 1), $Piece(pTable, ".", 2)) Set tSC = $SYSTEM.SQL.Stats.Table.FixTableStats(pTable)
        If $$$ISOK(tSC) Set tSC = ##class(%SQL.Manager.Catalog).SetMapBlockCount($Piece(pTable, ".", 1), $Piece(pTable, ".", 2), pMap, pBlocks, 0)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The statistics of field <var>pField</var> of <var>pTable</var> in <var>pNamespace</var> as the instance's own field query holds them, read directly:
/// <code>fixed selectivity|fixed outlier selectivity|fixed outlier value|fixed average size</code>, each as the instance shows it, or <code>unread</code>.</p>
ClassMethod FixedField(pNamespace As %String, pTable As %String, pField As %String) As %String
{
    Set tAnswer = "unread"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT SELECTIVITY, OUTLIER_SELECTIVITY, OUTLIER_VALUE, AVERAGE_FIELD_SIZE FROM %SQL_Manager.FieldCurrentSelectivity(?, ?) WHERE FIELD_NAME = ?")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute($Piece(pTable, ".", 1), $Piece(pTable, ".", 2), pField)
            If tResult.%Next() Set tAnswer = tResult.%GetData(1) _ "|" _ tResult.%GetData(2) _ "|" _ tResult.%GetData(3) _ "|" _ tResult.%GetData(4)
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>How many cached queries <var>pNamespace</var>'s statement index holds for a relation of the schema <var>pSchema</var>
/// (<parameter>TABLESCHEMA</parameter> by default), in the upper case the index keeps (Story 21.25).</p>
ClassMethod CachedQueryCount(pNamespace As %String, pSchema As %String = {..#TABLESCHEMA}) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATEMENT_LOCATIONS l JOIN INFORMATION_SCHEMA.STATEMENT_RELATIONS r ON r.Statement = l.Statement WHERE r.Relation [ ?")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute($ZConvert(pSchema, "U") _ ".")
            If tResult.%Next() Set tCount = tResult.%GetData(1)
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>Run <var>pText</var> in the current namespace, to its end.</p>
ClassMethod Run(pText As %String) As %Status
{
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare(pText)
    If $$$ISERR(tSC) Quit tSC
    Set tResult = tStatement.%Execute()
    If tResult.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
    While tResult.%Next() {
    }
    Quit $$$OK
}

/// <p>The hash of the statement of <var>pNamespace</var>'s index whose text holds <var>pToken</var> and that reads <var>pRelation</var>, or
/// <code>""</code>. The index keeps a statement's text normalized, so <code>SELECT A , B FROM</code> reads the one that selects two columns.</p>
ClassMethod HashOf(pNamespace As %String, pToken As %String, pRelation As %String = "OCUPROBE216.T1") As %String
{
    Set tHash = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT s.Hash FROM INFORMATION_SCHEMA.STATEMENT_RELATIONS r JOIN INFORMATION_SCHEMA.STATEMENTS s ON s.Hash = r.Statement WHERE r.Relation = ? AND s.Statement [ ?")
        Set tResult = tStatement.%Execute(pRelation, pToken)
        If tResult.%Next() Set tHash = tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHash
}

/// <p>The cached query class the statement <var>pHash</var> is held by in <var>pNamespace</var>, as the Cached queries tab names it, or
/// <code>""</code> when the index holds no location for it.</p>
ClassMethod LocationOf(pNamespace As %String, pHash As %String) As %String
{
    Quit $Piece(..Facts(pNamespace, pHash).Location, ".", 1, 3)
}

/// <p>What the instance's information schema holds for <var>pHash</var> in <var>pNamespace</var>, read directly, not through the port:
/// <code>{PlanState, PlanError, Executions, Location, Present}</code>. <code>Executions</code> is <code>""</code> where the index holds none.</p>
ClassMethod Facts(pNamespace As %String, pHash As %String) As %DynamicObject
{
    Set tFacts = {"PlanState": "", "PlanError": "", "Executions": "", "Location": "", "Present": 0}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT s.Frozen, s.Error, s.StatCount, MIN(l.Location) FROM INFORMATION_SCHEMA.STATEMENTS s LEFT OUTER JOIN INFORMATION_SCHEMA.STATEMENT_LOCATIONS l ON l.Statement = s.Hash WHERE s.Hash = ? GROUP BY s.Hash")
        Set tResult = tStatement.%Execute(pHash)
        If tResult.%Next() {
            Do tFacts.%Set("Present", 1, "boolean")
            Do tFacts.%Set("PlanState", $Case(tResult.%GetData(1), 1: "Frozen/Explicit", 2: "Frozen/Upgrade", 3: "Unfrozen/Parallel", : "Unfrozen"), "string")
            Do tFacts.%Set("PlanError", tResult.%GetData(2), "string")
            Do tFacts.%Set("Executions", tResult.%GetData(3), "string")
            Do tFacts.%Set("Location", tResult.%GetData(4), "string")
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tFacts
}

/// <p>Give <var>pHash</var> three recorded runs in <var>pNamespace</var>, or in the current namespace when it names none: the instance writes a
/// statement's statistics into the statement index on its own schedule, so the probe writes the same node.</p>
ClassMethod SetStatistics(pHash As %String, pNamespace As %String = "")
{
    If pNamespace = "" {
        Set ^rINDEXSQL("sqlidx", 5, pHash, "stat") = $ListBuild(3, 0.3, 0, +$Horolog, 3, 30)
        Quit
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set ^rINDEXSQL("sqlidx", 5, pHash, "stat") = $ListBuild(3, 0.3, 0, +$Horolog, 3, 30)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Put the plan-state flag of <var>pHash</var> in <var>pNamespace</var> at <var>pFlag</var>, <code>3</code> for <code>Unfrozen/Parallel</code>, in
/// the statement index's own node (the first element of its plan information, which the information schema's <code>Frozen</code> reads). The
/// throwaway's optimizer does not choose a parallel plan for the probe's statements, so a test that needs the state writes the flag.</p>
ClassMethod SetPlanFlag(pHash As %String, pNamespace As %String, pFlag As %Integer)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If $Data(^rINDEXSQL("sqlidx", 1, pHash, "planinfo")) Set $List(^rINDEXSQL("sqlidx", 1, pHash, "planinfo"), 1) = pFlag
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The statement <method>RecordStats</method> runs, and the token its statistics rows carry in their text (Story 21.26). The alias keeps it
/// apart from every statement the product or another test runs.</p>
Parameter QUERYSTATS = "SELECT A AS Probe226 FROM OcuProbe216.T1";

Parameter STATSTOKEN = "Probe226";

/// <p>Run <parameter>QUERYSTATS</parameter> in <var>pNamespace</var> with runtime statistics collection on for this process alone
/// (<code>SetSQLStatsFlagJob(3)</code>), so the instance's collection setting is never touched, and put the process's own flag back (Story 21.26).
/// The probe's tables exist (<method>Make</method>).</p>
ClassMethod RecordStats(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tPrevious = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tPrevious = $SYSTEM.SQL.SetSQLStatsFlagJob(3)
        Set tSC = ..Run(..#QUERYSTATS)
        Do $SYSTEM.SQL.SetSQLStatsFlagJob(tPrevious)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        If tPrevious '= "" Do $SYSTEM.SQL.SetSQLStatsFlagJob(tPrevious)
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The routines of <var>pNamespace</var>'s runtime statistics whose statement carries <var>pToken</var>, comma-joined, read with the caller's own
/// privileges.</p>
ClassMethod StatsRoutines(pNamespace As %String, pToken As %String = {..#STATSTOKEN}) As %String
{
    Set tList = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT DISTINCT RoutineName FROM %SYS_PTools.StatsSQLView WHERE NameSpace = ? AND QueryText [ ?")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute($ZConvert(pNamespace, "U"), pToken)
            While tResult.%Next() {
                Set tList = tList _ $Select(tList = "": "", 1: ",") _ tResult.%GetData(1)
            }
        }
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tList
}

/// <p>How many runtime statistics rows <var>pNamespace</var> holds for the probe's statement, <code>-1</code> when they cannot be read.</p>
ClassMethod StatsRowCount(pNamespace As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT COUNT(*) FROM %SYS_PTools.StatsSQLView WHERE NameSpace = ? AND QueryText [ ?")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute($ZConvert(pNamespace, "U"), ..#STATSTOKEN)
            If tResult.%Next() Set tCount = tResult.%GetData(1)
        }
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>Remove the runtime statistics of the statements carrying <var>pToken</var> from <var>pNamespace</var> by routine, never the namespace's other
/// rows, and answer how many rows it removed, or <code>-1</code> when a removal failed (Story 21.26).</p>
ClassMethod RemoveStats(pNamespace As %String, pToken As %String = {..#STATSTOKEN}) As %Integer
{
    Set tRemoved = 0
    Set tOrigNS = $NAMESPACE
    Set tList = ..StatsRoutines(pNamespace, pToken)
    Try {
        For tI = 1:1:$Length(tList, ",") {
            Set tRoutine = $Piece(tList, ",", tI)
            If tRoutine = "" Continue
            Set tCleared = ##class(%SYS.PTools.StatsSQL).clearStatsSQL(pNamespace, tRoutine, , 1, , 1)
            If '$Match(tCleared, "^[0-9]+$") Set tRemoved = -1 Quit
            Set tRemoved = tRemoved + tCleared
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tRemoved = -1
    }
    Quit tRemoved
}

/// <p>Run the statement over OcuPilot's own table in <var>pNamespace</var>, the install namespace, and answer its hash.</p>
ClassMethod MakeOwn(pNamespace As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tHash = ""
    Try {
        Set $NAMESPACE = pNamespace
        Do ..Run(..#OWNQUERY)
        Set $NAMESPACE = tOrigNS
        Set tHash = ..HashOf(pNamespace, "PROBE216", "OCUPILOT_KERNEL_STATE.VERSION")
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHash
}

/// <p>Put the own statement <var>pHash</var> back in <var>pNamespace</var>: unfrozen, with no plan error and no statistics, through the vendor
/// calls that change them.</p>
ClassMethod RemoveOwn(pNamespace As %String, pHash As %String)
{
    If pHash = "" Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If $Extract(..Facts(pNamespace, pHash).PlanState, 1, 7) = "Frozen/" Do $SYSTEM.SQL.Statement.UnfreezeStatement(pHash)
        Do UpdateSQLIndex^%SYS.SQLSRV(pHash, "")
        Do $SYSTEM.SQL.Statement.ClearStatement(pHash)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

}
