/// <p>Test-only helper for Story 18.9's suites: the probe user and role (<parameter>USER</parameter>,
/// <parameter>ROLE</parameter>, made in <code>%SYS</code>), the probe schema's two tables, a view and a stored
/// procedure (<parameter>SCHEMA</parameter>, made in <parameter>NAMESPACE</parameter>), the privileges a test
/// sets up as the running account, the instance's own list of a grantee's privileges, and the agent's mint through
/// a tool's own class. It holds no assertions.</p>
/// <p><b>Only <parameter>PREFIX</parameter> is ever touched.</b> Every principal and object is named from it and
/// removed by exact name. <method>RemoveAll</method> drops the objects and principals, cleans the namespace's
/// statement index and clears the system monitor, which the vendor's severity-2 refusals raise.</p>
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

/// <p>Drop the schema's objects, delete the probe principals, clean the namespace's statement index and clear the
/// system monitor.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tSql = "DROP VIEW " _ ..#VIEW, "DROP PROCEDURE " _ ..#PROCEDURE, "DROP TABLE " _ ..#TABLE, "DROP TABLE " _ ..#TABLE2 {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, tSql)
        }
        Do $SYSTEM.SQL.Statement.Clean()
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#USER) Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete(..#USER))
        If ##class(Security.Roles).Exists(..#ROLE) Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(..#ROLE))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Do $SYSTEM.Monitor.Clear()
    Quit tSC
}

/// <p>How many probe principals and schema objects the instance still holds.</p>
ClassMethod Remaining() As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#USER) Set tCount = tCount + 1
        If ##class(Security.Roles).Exists(..#ROLE) Set tCount = tCount + 1
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
