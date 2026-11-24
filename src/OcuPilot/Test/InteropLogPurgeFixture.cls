/// <p>The probe business rule log entries, business processes and principals Story 24.17 Batch 2's tests arrange. Every probe rule log entry carries <parameter>MARKER</parameter> as its rule
/// name, saved in <code>USER</code> (<parameter>SOURCE</parameter>) or <code>HSCUSTOM</code>, and every probe business process is an
/// <class>EnsLib.MsgRouter.RoutingEngine</class> (<parameter>PROCESSCLASS</parameter>, the concrete class both namespaces hold) whose configuration name is the marker; each is back-dated by
/// whole days. <method>DropProbes</method> removes every probe from both namespaces and answers whether none is left, <method>Foreign</method> counts the rows a purge of
/// <parameter>KEEPDAYS</parameter> days would delete that are not probes, and <method>RuleCount</method> and <method>ProcessCount</method> count the rows of a namespace. It starts no
/// production.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropLogPurgeFixture Extends %RegisteredObject
{

Parameter MARKER = "OcuProbe2417";

Parameter SOURCE = "USER";

Parameter OTHER = "HSCUSTOM";

/// <p>The class that creates and removes the principals.</p>
Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The concrete business process class a probe is saved as.</p>
Parameter PROCESSCLASS = "EnsLib.MsgRouter.RoutingEngine";

/// <p>How old a probe a purge is meant to delete is made, in days, and the days to keep such a purge is run with.</p>
Parameter OLDDAYS = 7300;

Parameter KEEPDAYS = 3650;

/// <p>The instance's own UTC time <var>pDays</var> days before now, as the vendor stores it: <code>YYYY-MM-DD HH:MM:SS.fff</code>.</p>
ClassMethod UtcAgo(pDays As %Integer) As %String
{
    Quit $ZDateTime(($Piece($ZTimeStamp, ",", 1) - pDays) _ "," _ $Piece($ZTimeStamp, ",", 2), 3, , 3)
}

/// <p>Store a probe rule log entry in <var>pNamespace</var>, made <var>pDays</var> days ago, an error when <var>pError</var> is set, with a debug row when <var>pDebug</var> is set, and
/// answer its id, or 0. <var>pName</var> is its rule name, the marker unless a test gives another.</p>
ClassMethod ProbeRule(pNamespace As %String = {..#SOURCE}, pDays As %Integer = {..#OLDDAYS}, pError As %Boolean = 0, pDebug As %Boolean = 0, pName As %String = {..#MARKER}) As %Integer
{
    Set tId = 0
    Set tStamp = ..UtcAgo(pDays)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tDebugId = ""
        If pDebug {
            Set tDebugId = ##class(Ens.Rule.DebugLog).GetNextDebugId()
            Do ##class(Ens.Rule.DebugLog).Log(tDebugId, "i", "probe", "debug message")
        }
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "INSERT INTO Ens_Rule.Log (SessionId, TimeExecuted, RuleName, RuleSet, Reason, ReturnValue, IsError, DebugId, ConfigName) VALUES (?,?,?,?,?,?,?,?,?)", 7, tStamp, pName, "probe set", "probe reason", "probe value", +pError, tDebugId, ..#MARKER _ "Host")
        If tResult.%SQLCODE = 0 Set tId = tResult.%ROWID
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Store a probe business process in <var>pNamespace</var>, created <var>pDays</var> days ago and completed when <var>pCompleted</var> is set, and answer its id, or 0.</p>
ClassMethod ProbeProcess(pNamespace As %String = {..#SOURCE}, pDays As %Integer = {..#OLDDAYS}, pCompleted As %Boolean = 1) As %Integer
{
    Set tId = 0
    Set tStamp = ..UtcAgo(pDays)
    Set tClass = ..#PROCESSCLASS
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStamp = ##class(Ens.DataType.UTC).Normalize(tStamp)
        Set tProcess = $ClassMethod(tClass, "%New", ..#MARKER)
        Set tProcess.%TimeCreated = tStamp
        Set tProcess.%IsCompleted = ''pCompleted
        If pCompleted Set tProcess.%TimeCompleted = tStamp
        Set tProcess.%SessionId = 7
        If $$$ISOK(tProcess.%Save()) Set tId = tProcess.%Id()
        Set tProcess = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Whether the rule log entry <var>pId</var> of <var>pNamespace</var> exists.</p>
ClassMethod RuleExists(pNamespace As %String, pId As %String) As %Boolean
{
    Quit ..One(pNamespace, "SELECT COUNT(*) FROM Ens_Rule.Log WHERE ID = ?", pId) > 0
}

/// <p>Whether the business process <var>pId</var> of <var>pNamespace</var> exists.</p>
ClassMethod ProcessExists(pNamespace As %String, pId As %String) As %Boolean
{
    Quit ..One(pNamespace, "SELECT COUNT(*) FROM Ens.BusinessProcess WHERE ID = ?", pId) > 0
}

/// <p>How many debug rows <var>pNamespace</var> holds for the rule log entry <var>pId</var>.</p>
ClassMethod DebugRows(pNamespace As %String, pId As %String) As %Integer
{
    Set tDebugId = ..One(pNamespace, "SELECT DebugId FROM Ens_Rule.Log WHERE ID = ?", pId)
    If tDebugId = "" Quit 0
    Quit ..One(pNamespace, "SELECT COUNT(*) FROM Ens_Rule.DebugLog WHERE DebugId = ?", tDebugId)
}

/// <p>The first column of the first row of <var>pSql</var> in <var>pNamespace</var> with <var>pArg</var> bound, or <code>""</code>; -1 when it cannot be read.</p>
ClassMethod One(pNamespace As %String, pSql As %String, pArg As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    Set tValue = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = $Select(pArg = "": ##class(%SQL.Statement).%ExecDirectNoPriv(, pSql), 1: ##class(%SQL.Statement).%ExecDirectNoPriv(, pSql, pArg))
        If tResult.%SQLCODE < 0 {
            Set tValue = -1
        } Else {
            Set tValue = $Select(tResult.%Next(): tResult.%GetData(1), 1: "")
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = -1
    }
    Quit tValue
}

/// <p>How many rule log entries <var>pNamespace</var> holds: <code>1</code> the probes, <code>0</code> every one; -1 when it cannot be read.</p>
ClassMethod RuleCount(pNamespace As %String, pMarked As %Boolean = 0) As %Integer
{
    Quit $Select(pMarked: ..One(pNamespace, "SELECT COUNT(*) FROM Ens_Rule.Log WHERE RuleName = ?", ..#MARKER), 1: ..One(pNamespace, "SELECT COUNT(*) FROM Ens_Rule.Log"))
}

/// <p>How many business processes <var>pNamespace</var> holds: <code>1</code> the probes, <code>0</code> every one; -1 when it cannot be read.</p>
ClassMethod ProcessCount(pNamespace As %String, pMarked As %Boolean = 0) As %Integer
{
    Quit $Select(pMarked: ..One(pNamespace, "SELECT COUNT(*) FROM Ens.BusinessProcess WHERE %ConfigName = ?", ..#MARKER), 1: ..One(pNamespace, "SELECT COUNT(*) FROM Ens.BusinessProcess"))
}

/// <p>How many rows <var>pNamespace</var> holds that a purge keeping <parameter>KEEPDAYS</parameter> days would delete and that are not probes: rule log entries and completed
/// business processes older than that. A class that purges at that age refuses to start beside any; -1 when they cannot be read.</p>
ClassMethod Foreign(pNamespace As %String) As %Integer
{
    Set tCutoff = ..UtcAgo(..#KEEPDAYS)
    Set tRules = ..Two(pNamespace, "SELECT COUNT(*) FROM Ens_Rule.Log WHERE TimeExecuted < ? AND RuleName <> ?", tCutoff, ..#MARKER)
    Set tProcesses = ..Two(pNamespace, "SELECT COUNT(*) FROM Ens.BusinessProcess WHERE %IsCompleted = 1 AND %TimeCreated < ? AND %ConfigName <> ?", tCutoff, ..#MARKER)
    If (tRules < 0) || (tProcesses < 0) Quit -1
    Quit tRules + tProcesses
}

/// <p>The first column of the first row of <var>pSql</var> in <var>pNamespace</var> with <var>pArg1</var> and <var>pArg2</var> bound; -1 when it cannot be read.</p>
ClassMethod Two(pNamespace As %String, pSql As %String, pArg1 As %String, pArg2 As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tValue = -1
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, pSql, pArg1, pArg2)
        If tResult.%SQLCODE >= 0 Set tValue = $Select(tResult.%Next(): tResult.%GetData(1), 1: "")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = -1
    }
    Quit tValue
}

/// <p>Remove every probe rule log entry and business process from both namespaces; answer <code>1</code> when none is left in either.</p>
ClassMethod DropProbes() As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tLeft = 0
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            Do ##class(%SQL.Statement).%ExecDirectNoPriv(, "DELETE FROM Ens_Rule.Log WHERE RuleName = ?", ..#MARKER)
            Kill tIds
            Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens.BusinessProcess WHERE %ConfigName = ?", ..#MARKER)
            While tResult.%Next() {
                Set tIds(tResult.%GetData(1)) = ""
            }
            Set tId = ""
            For {
                Set tId = $Order(tIds(tId))
                If tId = "" Quit
                Do $ClassMethod(..#PROCESSCLASS, "%DeleteId", tId)
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
        If (..RuleCount(tNamespace, 1) '= 0) || (..ProcessCount(tNamespace, 1) '= 0) Set tLeft = tLeft + 1
    }
    Quit 'tLeft
}

/// <p>Grant SELECT on both log tables to the role <var>pRole</var> in <var>pNamespace</var>, which the classic pages' own queries need: a direct grant, as a database administrator makes it.</p>
ClassMethod GrantSelect(pRole As %String, pNamespace As %String = {..#SOURCE}) As %Boolean
{
    Quit ..Sql(pNamespace, "GRANT SELECT ON Ens_Rule.Log, Ens.BusinessProcess TO " _ pRole)
}

/// <p>Take the grant <method>GrantSelect</method> makes back.</p>
ClassMethod RevokeSelect(pRole As %String, pNamespace As %String = {..#SOURCE}) As %Boolean
{
    Quit ..Sql(pNamespace, "REVOKE SELECT ON Ens_Rule.Log, Ens.BusinessProcess FROM " _ pRole)
}

/// <p>Run the statement <var>pSql</var> in <var>pNamespace</var>; <code>1</code> when it was answered without an error.</p>
ClassMethod Sql(pNamespace As %String, pSql As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tOk = 0
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, pSql)
        Set tOk = (tResult.%SQLCODE = 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOk
}

/// <p>Give <var>pUser</var> the role <var>pRole</var>.</p>
ClassMethod AddRole(pUser As %String, pRole As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).AddRoles(pUser, pRole)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create <var>pUser</var> with the role <code>%All</code> and the password <var>pPassword</var>.</p>
ClassMethod CreateAll(pUser As %String, pPassword As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(pUser) Do ##class(Security.Users).Delete(pUser)
        Set tSC = ##class(Security.Users).Create(pUser, "%All", pPassword, "OcuPilot test principal (throwaway)", "", "", "", 0, 1, "Created by an OcuPilot gate test; deleted when it ends")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove <var>pUser</var>.</p>
ClassMethod DropUser(pUser As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(pUser) Set tSC = ##class(Security.Users).Delete(pUser)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
