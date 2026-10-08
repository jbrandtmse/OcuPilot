/// <p>Test-only helper for Stories 18.9's and 18.28's suites: the probe user and role (<parameter>USER</parameter>,
/// <parameter>ROLE</parameter>, made in <code>%SYS</code>), the probe schema's two tables, a view and a stored
/// procedure (<parameter>SCHEMA</parameter>, made in <parameter>NAMESPACE</parameter>), the privileges a test
/// sets up as the running account, the instance's own list of a grantee's privileges, and the agent's mint through
/// a tool's own class. It holds no assertions.</p>
/// <p><b>Only <parameter>PREFIX</parameter> is ever touched.</b> Every principal and object is named from it and
/// removed by exact name; a privilege row is removed when its grantee carries the prefix. <method>RemoveAll</method>
/// revokes the privileges the instance lists for the probe user and role in each namespace the suites use, drops
/// the objects and principals, deletes any privilege row of a probe grantee that is left (the admin privilege sets
/// included), cleans the namespace's statement index and clears the system monitor, which the vendor's severity-2
/// refusals raise.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SqlPrivilegeProbe Extends %RegisteredObject
{

/// <p>What every probe principal and schema name begins with, case included.</p>
Parameter PREFIX = "OcuSqlPrivProbe";

Parameter USER = "OcuSqlPrivProbeU";

Parameter ROLE = "OcuSqlPrivProbeR";

/// <p>The probe schema, in <parameter>NAMESPACE</parameter>.</p>
Parameter SCHEMA = "OcuSqlPrivProbe";

Parameter NAMESPACE = "USER";

Parameter TABLE = "OcuSqlPrivProbe.T1";

Parameter TABLE2 = "OcuSqlPrivProbe.T2";

Parameter VIEW = "OcuSqlPrivProbe.V1";

Parameter PROCEDURE = "OcuSqlPrivProbe.P1";

Parameter ENDPOINT = "Security.SQLPrivilege.Standard";

Parameter COLUMNENDPOINT = "Security.SQLPrivilege.Column";

Parameter ADMINENDPOINT = "Security.SQLPrivilege.Admin";

Parameter PASSWORD = "OcuProbe189Pw!Aa9x";

/// <p>Make the probe user, created disabled so that it can never sign in, and the probe role, then the schema's
/// objects.</p>
ClassMethod Seed() As %Status
{
    Set tSC = ..RemoveAll()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#ROLE, "OcuPilot Story 18.9 probe (throwaway)", "", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#USER, "", ..#PASSWORD, "OcuPilot Story 18.9 probe (throwaway)", "", "", "", 0, 0, "Created by OcuPilot.Test.SqlPrivilegeProbe")
        Set $NAMESPACE = ..#NAMESPACE
        For tSql = "CREATE TABLE " _ ..#TABLE _ " (ID INT)", "CREATE TABLE " _ ..#TABLE2 _ " (ID INT)", "CREATE VIEW " _ ..#VIEW _ " AS SELECT ID FROM " _ ..#TABLE, "CREATE PROCEDURE " _ ..#PROCEDURE _ "() LANGUAGE SQL BEGIN SELECT 1; END" {
            If $$$ISERR(tSC) Quit
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, tSql)
            If tResult.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the probe object could not be made: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The namespaces whose SQL privileges the suites set for a probe principal: <parameter>NAMESPACE</parameter>
/// and the install namespace, where a test grants on OcuPilot's own table.</p>
ClassMethod Namespaces() As %List
{
    Quit $ListBuild(..#NAMESPACE, ##class(OcuPilot.Install.Installer).ResolveNamespace())
}

/// <p>Revoke, as the running account and one grantor at a time, every <code>Direct</code> privilege the probe user
/// and role hold in <var>pNamespace</var>, read from the instance's own list, which spells <code>ALTER</code> as
/// <code>%ALTER</code>; the vendor call takes <code>ALTER</code>. A privilege on an object the namespace no longer
/// holds cannot be revoked, so this runs before the objects are dropped.</p>
ClassMethod RevokeAll(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    For tGrantee = ..#USER, ..#ROLE {
        Kill tQuery, tRows
        Set tQuery("namespace") = pNamespace
        Set tQuery("grantee") = tGrantee
        Set tQuery("includeSystem") = 1
        Set tQuery("maxRows") = 100000
        Set tListSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tListSC) || '$IsObject($Get(tRows)) Continue
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("GrantedVia") '= "Direct" Continue
            Set tOrigNS = $NAMESPACE
            Try {
                Set $NAMESPACE = pNamespace
                Set tAction = $Select(tRow.%Get("Action") = "%ALTER": "ALTER", 1: tRow.%Get("Action"))
                Set tRevoke = $SYSTEM.SQL.Security.RevokePrivilege(tAction, tRow.%Get("Object"), tRow.%Get("Type"), tGrantee, 0, 0, tRow.%Get("GrantedBy"))
                Set $NAMESPACE = tOrigNS
            } Catch {
                Set $NAMESPACE = tOrigNS
            }
        }
        Set tSC = $$$ADDSC(tSC, ..RevokeColumns(pNamespace, tGrantee, tRows))
        Set tSC = $$$ADDSC(tSC, ..RevokeAdmin(pNamespace, tGrantee))
    }
    Quit tSC
}

/// <p>Revoke, as the running account and one grantor at a time, every <code>Direct</code> column privilege
/// <var>pGrantee</var> holds in <var>pNamespace</var>: for each table or view the standard list
/// <var>pRows</var> flags with <code>HasColumnPriv</code>, the rows of the column list, revoked as the vendor's
/// own column call does.</p>
ClassMethod RevokeColumns(pNamespace As %String, pGrantee As %String, pRows As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    If '$IsObject($Get(pRows)) Quit tSC
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If 'tRow.%Get("HasColumnPriv") Continue
        Kill tQuery, tColumns
        Set tQuery("namespace") = pNamespace
        Set tQuery("grantee") = pGrantee
        Set tQuery("object") = tRow.%Get("Object")
        Set tQuery("includeSystem") = 1
        Set tQuery("maxRows") = 100000
        Set tListSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#COLUMNENDPOINT, "LIST", .tQuery, "", .tColumns, .tHttp, .tFault)
        If $$$ISERR(tListSC) || '$IsObject($Get(tColumns)) Continue
        Set tColIterator = tColumns.%GetIterator()
        While tColIterator.%GetNext(.tColIndex, .tColRow) {
            If tColRow.%Get("GrantedVia") '= "Direct" Continue
            Set tOrigNS = $NAMESPACE
            Try {
                Set $NAMESPACE = pNamespace
                Set tFields = $ListBuild(tColRow.%Get("Column"))
                Set tType = $Select(tRow.%Get("Type") = "VIEW": 3, 1: 1)
                Set tColSC = ##class(%SQL.Manager.API).SaveObjPriv($ZConvert($Extract(tColRow.%Get("Action")), "L"), tType, tRow.%Get("Object"), pGrantee, 0, 1, .tSqlCode, .tMsg, tColRow.%Get("GrantedBy"), .tFields)
                Set $NAMESPACE = tOrigNS
            } Catch {
                Set $NAMESPACE = tOrigNS
            }
        }
    }
    Quit tSC
}

/// <p>Revoke every <code>Direct</code> admin privilege <var>pGrantee</var> holds in <var>pNamespace</var>, read
/// from the admin list, as the vendor's own admin call does.</p>
ClassMethod RevokeAdmin(pNamespace As %String, pGrantee As %String) As %Status
{
    Kill tQuery, tRows
    Set tQuery("namespace") = pNamespace
    Set tQuery("grantee") = pGrantee
    Set tQuery("maxRows") = 100000
    Set tListSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ADMINENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tListSC) || '$IsObject($Get(tRows)) Quit $$$OK
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("GrantedVia") '= "Direct" Continue
        Set tOrigNS = $NAMESPACE
        Try {
            Kill tProperties
            Set tProperties("AdminPriv") = tRow.%Get("Privilege")
            Set tProperties("Grantee") = pGrantee
            Set tProperties("Namespace") = pNamespace
            Set $NAMESPACE = "%SYS"
            Set tRevoke = $SYSTEM.SQL.Security.RevokeAdminOne(.tProperties)
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Quit $$$OK
}

/// <p>How many privilege rows the instance still holds for a probe principal or on the probe schema's objects,
/// whoever the grantee, in any namespace. An <code>EXECUTE</code> row on a table, which the admin API's list does
/// not show, outlives its grantee and its table.</p>
ClassMethod RemainingPrivileges() As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Security.SQLPrivileges WHERE Grantee %STARTSWITH ? OR SQLObject [ ?", ..#PREFIX, "," _ ..#SCHEMA _ ".")
        If tResult.%Next() Set tCount = tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Revoke every privilege the probe principals hold, drop the schema's objects, delete the probe principals,
/// remove any privilege row of a probe grantee that is left, clean the namespace's statement index and clear the
/// system monitor. The leftover rows are deleted from <class>Security.SQLPrivileges</class> directly, which the
/// vendor documents as not meant for object access: its revoke refuses a row whose object is gone, and its list
/// does not show an <code>EXECUTE</code> row on a table.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tList = ..Namespaces()
        For tI = 1:1:$ListLength(tList) {
            Set tSC = $$$ADDSC(tSC, ..RevokeAll($List(tList, tI)))
        }
        Set $NAMESPACE = ..#NAMESPACE
        For tSql = "DROP VIEW " _ ..#VIEW, "DROP PROCEDURE " _ ..#PROCEDURE, "DROP TABLE " _ ..#TABLE, "DROP TABLE " _ ..#TABLE2 {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, tSql)
        }
        Do $SYSTEM.SQL.Statement.Clean()
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#USER) Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete(..#USER))
        If ##class(Security.Roles).Exists(..#ROLE) Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(..#ROLE))
        Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Security.SQLPrivileges WHERE Grantee %STARTSWITH ?", ..#PREFIX)
        While tRows.%Next() {
            Set tSC = $$$ADDSC(tSC, ##class(Security.SQLPrivileges).%DeleteId(tRows.%GetData(1)))
        }
        Set tSets = ##class(%SQL.Statement).%ExecDirect(, "SELECT %ID FROM Security.SQLAdminPrivilegeSet WHERE $PIECE(%ID, '||', 2) %STARTSWITH ?", $ZConvert(..#PREFIX, "L"))
        While tSets.%Next() {
            Set tSC = $$$ADDSC(tSC, ##class(Security.SQLAdminPrivilegeSet).%DeleteId(tSets.%GetData(1)))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Do $SYSTEM.Monitor.Clear()
    Quit tSC
}

/// <p>How many admin privilege sets (<class>Security.SQLAdminPrivilegeSet</class>, keyed by namespace and
/// lower-case grantee) the instance holds for a probe grantee, in any namespace.</p>
ClassMethod RemainingAdminSets() As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSets = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Security.SQLAdminPrivilegeSet WHERE $PIECE(%ID, '||', 2) %STARTSWITH ?", $ZConvert(..#PREFIX, "L"))
        If tSets.%Next() Set tCount = tSets.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>How many probe principals, schema objects, privilege rows and admin privilege sets the instance still
/// holds.</p>
ClassMethod Remaining() As %Integer
{
    Set tCount = ..RemainingPrivileges()
    If tCount < 0 Quit -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#USER) Set tCount = tCount + 1
        If ##class(Security.Roles).Exists(..#ROLE) Set tCount = tCount + 1
        Set tSets = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Security.SQLAdminPrivilegeSet WHERE $PIECE(%ID, '||', 2) %STARTSWITH ?", $ZConvert(..#PREFIX, "L"))
        If tSets.%Next() Set tCount = tCount + tSets.%GetData(1)
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA %STARTSWITH ?", ..#PREFIX)
        If tResult.%Next() Set tCount = tCount + tResult.%GetData(1)
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA %STARTSWITH ?", ..#PREFIX)
        If tResult.%Next() Set tCount = tCount + tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Grant, as the running account, <var>pAction</var> on <var>pObject</var> of <var>pType</var> to
/// <var>pGrantee</var> in <parameter>NAMESPACE</parameter>, with the grant option when <var>pWithGrant</var>.</p>
ClassMethod Grant(pGrantee As %String, pType As %String, pObject As %String, pAction As %String, pWithGrant As %Boolean = 0, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = pNamespace
        If pWithGrant {
            Set tSC = $SYSTEM.SQL.Security.GrantPrivilegeWithGrant(pAction, pObject, pType, pGrantee)
        } Else {
            Set tSC = $SYSTEM.SQL.Security.GrantPrivilege(pAction, pObject, pType, pGrantee)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Revoke, as the running account, <var>pAction</var> on <var>pObject</var> of <var>pType</var> from
/// <var>pGrantee</var> in <var>pNamespace</var>.</p>
ClassMethod Revoke(pGrantee As %String, pType As %String, pObject As %String, pAction As %String, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = $SYSTEM.SQL.Security.RevokePrivilege(pAction, pObject, pType, pGrantee)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Give (<var>pOn</var> 1) or take away the probe user's <code>%All</code> role.</p>
ClassMethod GiveAll(pOn As %Boolean) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        If pOn {
            Set tSC = ##class(Security.Users).AddRoles(..#USER, "%All")
        } Else {
            Set tSC = ##class(Security.Users).RemoveRoles(..#USER, "%All")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Give the probe user the probe role.</p>
ClassMethod GiveRole() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).AddRoles(..#USER, ..#ROLE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe schema's rows of <var>pGrantee</var> in <parameter>NAMESPACE</parameter> as the vendor's own list
/// answers them, as lines <code>Type|Object|Action|GrantedBy|GrantOption|GrantedVia</code> sorted and
/// <code>;</code>-joined: the state a test must leave as it found it. The four rows every grantee holds on the
/// <code>Ens</code> procedures are left out.</p>
ClassMethod Rows(pGrantee As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("grantee") = pGrantee
    Set tQuery("includeSystem") = 1
    Set tQuery("maxRows") = 100000
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit "unreadable"
    Kill tLines
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ZConvert($Piece(tRow.%Get("Object"), ".", 1), "U") '= $ZConvert(..#SCHEMA, "U") Continue
        Set tLines(tRow.%Get("Type") _ "|" _ tRow.%Get("Object") _ "|" _ tRow.%Get("Action") _ "|" _ tRow.%Get("GrantedBy") _ "|" _ tRow.%Get("GrantOption") _ "|" _ tRow.%Get("GrantedVia")) = ""
    }
    Set tText = ""
    Set tLine = ""
    For {
        Set tLine = $Order(tLines(tLine))
        If tLine = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tLine
    }
    Quit tText
}

/// <p>Whether <var>pGrantee</var> holds a <code>Direct</code> row for <var>pAction</var> on <var>pObject</var>:
/// <code>0</code>, or <code>1</code>, or <code>2</code> when it holds it with the grant option.</p>
ClassMethod Direct(pGrantee As %String, pObject As %String, pAction As %String) As %Integer
{
    Set tHeld = 0
    Set tRows = ..Rows(pGrantee)
    For tI = 1:1:$Length(tRows, ";") {
        Set tRow = $Piece(tRows, ";", tI)
        If ($ZConvert($Piece(tRow, "|", 2), "U") = $ZConvert(pObject, "U")) && ($Piece(tRow, "|", 3) = pAction) && ($Piece(tRow, "|", 6) = "Direct") Set tHeld = 1 + ($Piece(tRow, "|", 5) = 1)
    }
    Quit tHeld
}

/// <p>Whether <var>pGrantee</var> holds a <code>Direct</code> column row for <var>pAction</var> on
/// <var>pColumn</var> of <var>pObject</var> (spelled as the instance spells it) in <parameter>NAMESPACE</parameter>:
/// <code>0</code>, <code>1</code>, or <code>2</code> when it holds it with the grant option. The column is
/// compared ignoring case.</p>
ClassMethod ColumnDirect(pGrantee As %String, pObject As %String, pColumn As %String, pAction As %String) As %Integer
{
    Kill tQuery, tRows
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("grantee") = pGrantee
    Set tQuery("object") = pObject
    Set tQuery("includeSystem") = 1
    Set tQuery("maxRows") = 100000
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#COLUMNENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit -1
    Set tHeld = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.%Get("GrantedVia") = "Direct") && ($ZConvert(tRow.%Get("Column"), "U") = $ZConvert(pColumn, "U")) && (tRow.%Get("Action") = pAction) Set tHeld = 1 + (tRow.%Get("GrantOption") = 1)
    }
    Quit tHeld
}

/// <p>The column rows of <var>pGrantee</var> on <var>pObject</var> as lines
/// <code>Column|Action|GrantedBy|GrantOption|GrantedVia</code>, sorted and <code>;</code>-joined, from the
/// instance's own column list.</p>
ClassMethod ColumnRows(pGrantee As %String, pObject As %String) As %String
{
    Kill tQuery, tRows
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("grantee") = pGrantee
    Set tQuery("object") = pObject
    Set tQuery("includeSystem") = 1
    Set tQuery("maxRows") = 100000
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#COLUMNENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit "unreadable"
    Kill tLines
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tLines(tRow.%Get("Column") _ "|" _ tRow.%Get("Action") _ "|" _ tRow.%Get("GrantedBy") _ "|" _ tRow.%Get("GrantOption") _ "|" _ tRow.%Get("GrantedVia")) = ""
    }
    Set tText = ""
    Set tLine = ""
    For {
        Set tLine = $Order(tLines(tLine))
        If tLine = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tLine
    }
    Quit tText
}

/// <p>Whether <var>pGrantee</var> holds the admin privilege <var>pPrivilege</var> directly in
/// <parameter>NAMESPACE</parameter>: <code>0</code>, <code>1</code>, or <code>2</code> when it holds it with the
/// admin option.</p>
ClassMethod AdminDirect(pGrantee As %String, pPrivilege As %String) As %Integer
{
    Kill tQuery, tRows
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("grantee") = pGrantee
    Set tQuery("maxRows") = 100000
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ADMINENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit -1
    Set tHeld = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.%Get("GrantedVia") = "Direct") && (tRow.%Get("Privilege") = pPrivilege) Set tHeld = 1 + (tRow.%Get("GrantOption") = 1)
    }
    Quit tHeld
}

/// <p>Give <var>pGrantee</var> the admin privilege <var>pPrivilege</var> in <parameter>NAMESPACE</parameter>, as
/// the running account, with the admin option when <var>pWithGrant</var>.</p>
ClassMethod GrantAdmin(pGrantee As %String, pPrivilege As %String, pWithGrant As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Kill tProperties
        Set tProperties("AdminPriv") = pPrivilege
        Set tProperties("Grantee") = pGrantee
        Set tProperties("Namespace") = ..#NAMESPACE
        Set tProperties("WithGrant") = pWithGrant
        Set $NAMESPACE = "%SYS"
        Set tSC = $SYSTEM.SQL.Security.GrantAdminOne(.tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Grant, as the running account, <var>pAction</var> on <var>pColumn</var> of <var>pObject</var> (a table, or a
/// view when <var>pView</var>) to <var>pGrantee</var> in <parameter>NAMESPACE</parameter>, with the grant option
/// when <var>pWithGrant</var>, through the same call the vendor's column endpoint makes. A column privilege on a
/// table the grantee already holds the whole of is stored as nothing.</p>
ClassMethod GrantColumn(pGrantee As %String, pObject As %String, pColumn As %String, pAction As %String, pWithGrant As %Boolean = 0, pView As %Boolean = 0) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tFields = $ListBuild(pColumn)
        Set tSC = ##class(%SQL.Manager.API).SaveObjPriv($ZConvert($Extract(pAction), "L"), $Select(pView: 3, 1: 1), pObject, pGrantee, pWithGrant, 0, .tSqlCode, .tMsg, , .tFields)
        If $$$ISOK(tSC) && ($Get(tSqlCode) < 0) Set tSC = $$$ERROR($$$GeneralError, "the column grant was refused: SQLCODE " _ tSqlCode _ " " _ $Get(tMsg))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Store an admin privilege set for <var>pGrantee</var> (a name that holds no account) in
/// <parameter>NAMESPACE</parameter>, directly, so that a test can show <method>RemoveAll</method> sweeps a set
/// whose principal is already gone. The name must begin <parameter>PREFIX</parameter>.</p>
ClassMethod SeedAdminSet(pGrantee As %String) As %Status
{
    If $ZConvert($Extract(pGrantee, 1, $Length(..#PREFIX)), "U") '= $ZConvert(..#PREFIX, "U") Quit $$$ERROR($$$GeneralError, "only a probe name is stored")
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSet = ##class(Security.SQLAdminPrivilegeSet).%New()
        Set tSet.Namespace = ..#NAMESPACE
        Set tSet.Grantee = $ZConvert(pGrantee, "L")
        Set tSet.CreateTable = 1
        Set tSC = tSet.%Save()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The mint arguments of a column privilege on the probe table (or <var>pObject</var>): as
/// <method>Args</method>, with <var>pColumn</var>.</p>
ClassMethod ColumnArgs(pGrantee As %String, pColumn As %String = "ID", pAction As %String = "SELECT", pObject As %String = {..#TABLE}, pType As %String = "TABLE") As %DynamicObject
{
    Set tArgs = ..Args(pGrantee, pObject, pAction, pType)
    Do tArgs.%Set("Column", pColumn, "string")
    Quit tArgs
}

/// <p>The mint arguments of an admin privilege in <parameter>NAMESPACE</parameter>: the privilege is the action
/// and there is no object.</p>
ClassMethod AdminArgs(pGrantee As %String, pPrivilege As %String = "%CREATE_TABLE") As %DynamicObject
{
    Quit {"Name": (pGrantee), "Namespace": (..#NAMESPACE), "Type": "ADMIN", "Action": (pPrivilege)}
}

/// <p>The rows of <var>pGrantee</var> in <var>pNamespace</var> on objects whose names begin
/// <var>pObjectPrefix</var>, as <method>Rows</method> words them, from the vendor's own list: the install
/// namespace's grants of OcuPilot's own schema to <code>%DB_OCUPILOT</code>, which a test must leave as it found
/// them.</p>
ClassMethod RowsOf(pGrantee As %String, pNamespace As %String, pObjectPrefix As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("grantee") = pGrantee
    Set tQuery("includeSystem") = 1
    Set tQuery("maxRows") = 100000
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit "unreadable"
    Kill tLines
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ZConvert($Extract(tRow.%Get("Object"), 1, $Length(pObjectPrefix)), "U") '= $ZConvert(pObjectPrefix, "U") Continue
        Set tLines(tRow.%Get("Type") _ "|" _ tRow.%Get("Object") _ "|" _ tRow.%Get("Action") _ "|" _ tRow.%Get("GrantedBy") _ "|" _ tRow.%Get("GrantOption") _ "|" _ tRow.%Get("GrantedVia")) = ""
    }
    Set tText = ""
    Set tLine = ""
    For {
        Set tLine = $Order(tLines(tLine))
        If tLine = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tLine
    }
    Quit tText
}

/// <p>Mint the proposal for the tool <var>pToolClass</var> over <var>pArgs</var> through the tool's own mint class,
/// as the agent's call does, naming the grantee <var>pGrantee</var>. <var>pProblem</var> is the refusal's problem or
/// code.</p>
ClassMethod Mint(pToolClass As %String, pGrantee As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, pUser As %String = {$Username}) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", $Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pGrantee, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>The arguments of a privilege on the probe table for a mint or a screen action: the probe namespace, a
/// <code>TABLE</code>, <var>pObject</var> and <var>pAction</var>, with the grantee as <code>Name</code>.</p>
ClassMethod Args(pGrantee As %String, pObject As %String = {..#TABLE}, pAction As %String = "SELECT", pType As %String = "TABLE") As %DynamicObject
{
    Quit {"Name": (pGrantee), "Namespace": (..#NAMESPACE), "Type": (pType), "Object": (pObject), "Action": (pAction)}
}

}
