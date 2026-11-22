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
                Do UpdateSQLIndex^%SYS.SQLSRV(tHash, "")
                Do $SYSTEM.SQL.Statement.ClearStatement(tHash)
            }
        }
        Do $SYSTEM.SQL.PurgeQueries({"table": [(..#FIRST), (..#SECOND)]})
        Do ..Run("DROP TABLE " _ ..#FIRST)
        Do ..Run("DROP TABLE " _ ..#SECOND)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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

/// <p>Give <var>pHash</var> three recorded runs in the current namespace: the instance writes a statement's statistics into the statement index
/// on its own schedule, so the probe writes the same node.</p>
ClassMethod SetStatistics(pHash As %String)
{
    Set ^rINDEXSQL("sqlidx", 5, pHash, "stat") = $ListBuild(3, 0.3, 0, +$Horolog, 3, 30)
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

/// <p>Put the own statement <var>pHash</var> back in <var>pNamespace</var>: unfrozen and with no plan error, through the vendor calls that change
/// them.</p>
ClassMethod RemoveOwn(pNamespace As %String, pHash As %String)
{
    If pHash = "" Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If $Extract(..Facts(pNamespace, pHash).PlanState, 1, 7) = "Frozen/" Do $SYSTEM.SQL.Statement.UnfreezeStatement(pHash)
        Do UpdateSQLIndex^%SYS.SQLSRV(pHash, "")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

}
