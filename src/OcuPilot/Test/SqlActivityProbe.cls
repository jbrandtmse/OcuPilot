/// <p>The Story 19.10 fixture: a long-running probe statement in a job of its own
/// (<method>Start</method>, <method>Stop</method>), the vendor's <code>Protect</code> audit rows counted
/// (<method>ProtectCount</method>), throwaway principals (<method>EnsurePrincipals</method>,
/// <method>RemovePrincipals</method>), and a child process that reads as a principal
/// (<method>Probe</method>).</p>
/// <p>A probe job runs one CPU-bound dictionary cross join that keeps its literal in
/// <code>((...))</code>, so the statement's text carries it, and binds its value, so only the vendor's
/// <code>Parameters</code> does. It ends itself after <parameter>BOUNDSECONDS</parameter>. Every pid
/// <method>Start</method> starts is recorded under <code>^IRIS.Temp.OcuPilotSqlActivityProbe</code>, and
/// <method>Stop</method> terminates no other process.</p>
/// <p>The principal helpers refuse unless <parameter>PRINCIPALSVARIABLE</parameter> reads 1.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SqlActivityProbe Extends %RegisteredObject
{

/// <p>The environment variable that arms the principal helpers, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The seconds after which a probe job ends itself, should nothing stop it.</p>
Parameter BOUNDSECONDS As INTEGER = 600;

/// <p>The seconds <method>Start</method> waits for its row and <method>Stop</method> for its end.</p>
Parameter WAITSECONDS As INTEGER = 30;

/// <p>The prefix every principal's name carries.</p>
Parameter PRINCIPALPREFIX = "OcuP1910";

/// <p>The probe statement keeping <var>pLiteral</var> as a literal and binding one value.</p>
ClassMethod ProbeText(pLiteral As %String) As %String
{
    Quit "SELECT COUNT(*) FROM %Dictionary.CompiledClass a, %Dictionary.CompiledClass b, %Dictionary.CompiledClass c WHERE a.Name || b.Name || c.Name <> ((' " _ $Replace(pLiteral, "'", "''") _ " ')) || ?"
}

/// <p>Start a probe job running <method>ProbeText</method> of <var>pLiteral</var>, bound to
/// <var>pValue</var>, in <var>pNamespace</var>, inside <var>pLevel</var> open transactions, and wait
/// until the instance lists its statement; <var>pPid</var> is the job's pid. A job that is not listed in
/// time is stopped and refused.</p>
ClassMethod Start(pNamespace As %String, pLiteral As %String, pValue As %String, Output pPid As %Integer, pLevel As %Integer = 0) As %Status
{
    Set pPid = ""
    Set tSC = $$$OK
    Try {
        Job ##class(OcuPilot.Test.SqlActivityProbe).Run(pNamespace, ..ProbeText(pLiteral), pValue, ..#BOUNDSECONDS, +pLevel)::10
        If '$Test {
            Set tSC = $$$ERROR($$$GeneralError, "the probe job did not start")
            Quit
        }
        Set pPid = $ZChild
        Set ^IRIS.Temp.OcuPilotSqlActivityProbe(pPid) = pLiteral
        Set tDeadline = $ZHorolog + ..#WAITSECONDS
        While '..Listed(pPid, 0.01) {
            If $ZHorolog > tDeadline {
                Set tSC = $$$ERROR($$$GeneralError, "the probe job " _ pPid _ " was not listed within " _ ..#WAITSECONDS _ " seconds")
                Quit
            }
            Hang 0.2
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) && (pPid '= "") {
        Do ..Stop(pPid)
        Set pPid = ""
    }
    Quit tSC
}

/// <p>The probe job's body: run <var>pText</var> bound to <var>pValue</var> in <var>pNamespace</var>,
/// inside <var>pLevel</var> open transactions that write nothing, until it ends or <var>pBound</var>
/// seconds pass. It calls no class of its own once switched.</p>
ClassMethod Run(pNamespace As %String, pText As %String, pValue As %String, pBound As %Integer, pLevel As %Integer = 0)
{
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:pLevel {
            TSTART
        }
        Do $System.Alarm.Set(pBound)
        Set tStatement = ##class(%SQL.Statement).%New()
        If $$$ISOK(tStatement.%Prepare(pText)) {
            Set tRS = tStatement.%Execute(pValue)
            Do tRS.%Next()
        }
        Do $System.Alarm.Clear()
    } Catch {
    }
    If $TLevel > 0 TROLLBACK
}

/// <p>Whether the instance lists a statement of process <var>pPid</var> that has run for at least
/// <var>pSeconds</var>.</p>
ClassMethod Listed(pPid As %Integer, pSeconds As %Numeric = 0) As %Boolean
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.CURRENT_STATEMENTS WHERE ProcessID = ? AND ExecutionDuration >= ?", pPid, pSeconds)
    If tRS.%SQLCODE < 0 Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRS.%SQLCODE, tRS.%Message)
    Quit (tRS.%Next() && (tRS.%GetData(1) > 0))
}

/// <p>Terminate probe job <var>pPid</var> and wait until neither it nor its statement is listed; a pid
/// <method>Start</method> did not record is refused and left alone.</p>
ClassMethod Stop(pPid As %Integer) As %Status
{
    Set tSC = $$$OK
    Try {
        If (pPid = "") || '$Data(^IRIS.Temp.OcuPilotSqlActivityProbe(pPid)) {
            Set tSC = $$$ERROR($$$GeneralError, "process " _ pPid _ " is not a probe job this fixture started")
            Quit
        }
        If $Data(^$JOB(pPid)) Do $SYSTEM.Process.Terminate(pPid)
        Set tDeadline = $ZHorolog + ..#WAITSECONDS
        While $Data(^$JOB(pPid)) || ..Listed(pPid) {
            If $ZHorolog > tDeadline {
                Set tSC = $$$ERROR($$$GeneralError, "the probe job " _ pPid _ " still runs after " _ ..#WAITSECONDS _ " seconds")
                Quit
            }
            Hang 0.2
        }
        If $$$ISOK(tSC) Kill ^IRIS.Temp.OcuPilotSqlActivityProbe(pPid)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Stop every probe job <method>Start</method> recorded; an error status names any that survives.</p>
ClassMethod StopAll() As %Status
{
    Set tSC = $$$OK
    Set tPid = ""
    For {
        Set tPid = $Order(^IRIS.Temp.OcuPilotSqlActivityProbe(tPid))
        If tPid = "" Quit
        Set tSC = $$$ADDSC(tSC, ..Stop(tPid))
    }
    Quit tSC
}

/// <p>How many probe jobs are recorded as running.</p>
ClassMethod Running() As %Integer
{
    Set tCount = 0
    Set tPid = ""
    For {
        Set tPid = $Order(^IRIS.Temp.OcuPilotSqlActivityProbe(tPid))
        If tPid = "" Quit
        Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>How many <code>%System/%Security/Protect</code> rows the audit database holds, in
/// <var>pCount</var>, counted with every index ignored.</p>
ClassMethod ProtectCount(Output pCount As %Integer) As %Status
{
    Set pCount = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %IGNOREINDEX * %SYS.Audit WHERE EventSource = '%System' AND EventType = '%Security' AND Event = 'Protect'")
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the audit rows could not be counted: SQLCODE " _ tRS.%SQLCODE)
        } ElseIf tRS.%Next() {
            Set pCount = +tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>An error status unless <parameter>PRINCIPALSVARIABLE</parameter> reads 1.</p>
ClassMethod Armed() As %Status
{
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlActivityProbe creates and deletes users and roles, on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Quit $$$OK
}

/// <p>Create each principal <var>pPrincipals</var> names -- <code>&lt;user&gt;:&lt;grants&gt;</code>
/// separated by <code>;</code>, each user carrying <parameter>PRINCIPALPREFIX</parameter> -- with a
/// role of its own holding its grants and READ on the install namespace's code database, and the
/// password <var>pPassword</var>.</p>
ClassMethod EnsurePrincipals(pPrincipals As %String, pPassword As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        If 'tResolved || (tHome = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the install namespace's code database could not be resolved")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(pPrincipals, ";") {
            Set tEntry = $Piece(pPrincipals, ";", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            If $Extract(tUser, 1, $Length(..#PRINCIPALPREFIX)) '= ..#PRINCIPALPREFIX {
                Set tSC = $$$ERROR($$$GeneralError, "'" _ tUser _ "' is not a probe principal name")
                Quit
            }
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the SQL activity port's gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, pPassword, "OcuPilot SQL activity test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.SqlActivityProbe")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete each principal <var>pPrincipals</var> names and its role; an error status names any that
/// survives.</p>
ClassMethod RemovePrincipals(pPrincipals As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(pPrincipals, ";") {
            Set tUser = $Piece($Piece(pPrincipals, ";", tI), ":", 1)
            If $Extract(tUser, 1, $Length(..#PRINCIPALPREFIX)) '= ..#PRINCIPALPREFIX Continue
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the principal or role of " _ tUser _ " survives"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The child process <class>OcuPilot.Test.SqlActivityGate</class> starts: log in as
/// <var>pUsername</var>, read the running statements through <class>OcuPilot.Port.SqlActivityPort</class>,
/// and signal process <var>pParent</var> <code>{loggedIn, username, http, code, failedPair, row, rows,
/// screen}</code>: <code>row</code> is the read's row for process <var>pPid</var>, or <code>null</code>;
/// <code>rows</code> the read's whole answer as JSON text; and <code>screen</code> the side bar's
/// <code>{allowed, failedPair}</code> for SQL activity. <code>{error}</code> when something raised. It
/// runs in its own process so the login never touches the test's own identity.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pPid As %Integer)
{
    Set tOut = {}
    Try {
        Set tSC = ..Armed()
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", $System.Status.GetErrorText(tSC))
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Kill tQuery
        Set tQuery("maxRows") = 100
        Set tHttp = 0
        Set tFault = ""
        Set tSC = ##class(OcuPilot.Port.SqlActivityPort).Invoke("CurrentStatements", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do tOut.%Set("http", +tHttp, "number")
        If $IsObject(tFault) {
            Do tOut.%Set("code", tFault.%Get("code"))
            If $IsObject(tFault.%Get("detail")) Do tOut.%Set("failedPair", tFault.detail.%Get("failedPair"))
        }
        Do tOut.%Set("row", "", "null")
        If $IsObject($Get(tRows)) {
            Do tOut.%Set("rows", tRows.%ToJSON())
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If tRow.%Get("ProcessID") = pPid Do tOut.%Set("row", tRow)
            }
        }
        Set tScreen = {}
        Set tAllowed = ##class(OcuPilot.Screen.Gate).Evaluate("OcuPilot.Screen.Descriptor.SqlActivityList", .tFailedPair)
        Do tScreen.%Set("allowed", ''tAllowed, "boolean")
        Do tScreen.%Set("failedPair", tFailedPair)
        Do tOut.%Set("screen", tScreen)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
