/// <p>Story 19.6's probe SQL objects and principals, created by the console's tests and removed by
/// <method>Remove</method> and <method>RemovePrincipals</method>: schema <parameter>SCHEMA</parameter>
/// in <code>USER</code> -- <parameter>GRANTED</parameter> (40 rows), <parameter>HIDDEN</parameter>
/// (2 rows), the function <parameter>SLOW</parameter> that waits 0.1 s a call, the procedure
/// <parameter>LEAVEOPEN</parameter> that starts a transaction and leaves it open, the procedure
/// <parameter>LISTING</parameter> that answers <parameter>GRANTED</parameter>'s rows as a result set,
/// the procedure <parameter>ECHO</parameter> that copies its input parameter to its output parameter,
/// and the function <parameter>HIDDENCOUNT</parameter>, which no principal may execute -- and, in
/// the install namespace, the view <parameter>OWNVIEW</parameter> over OcuPilot's own proposal
/// table.</p>
/// <p><parameter>USER</parameter> holds <code>%Development:USE</code>, <code>%DB_USER:RW</code>,
/// READ on the install namespace's code database and SQL SELECT on <parameter>GRANTED</parameter>
/// alone; <parameter>NODEVUSER</parameter> holds the same but <code>%Development:USE</code>, with
/// <code>%Admin_Operate:USE</code> to clear the API's administrative floor, and
/// <parameter>NOUSERUSER</parameter> the same but READ on <code>USER</code>'s database. Each is
/// created only where <parameter>ARMINGVARIABLE</parameter> reads <code>1</code>, and its grants are
/// read back.</p>
/// <p><method>RunAs</method> is the child process a test starts to call
/// <class>OcuPilot.Port.SqlPort</class> as a real principal.</p>
Class OcuPilot.Test.SqlConsoleProbe Extends %RegisteredObject
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter NAMESPACE = "USER";

Parameter SCHEMA = "OcuProbe196";

Parameter GRANTED = "OcuProbe196.Granted";

Parameter HIDDEN = "OcuProbe196.Hidden";

Parameter SLOW = "OcuProbe196.Slow";

Parameter LEAVEOPEN = "OcuProbe196.LeaveOpen";

Parameter LISTING = "OcuProbe196.Listing";

Parameter HIDDENCOUNT = "OcuProbe196.HiddenCount";

Parameter ECHO = "OcuProbe196.Echo";

/// <p>The view over OcuPilot's own proposal table, made in the install namespace.</p>
Parameter OWNVIEW = "OcuProbe196.OwnView";

/// <p>The probe principals and the role each holds, named <code>&lt;user&gt;Role</code>.</p>
Parameter USER = "OcuProbe196User";

Parameter NODEVUSER = "OcuProbe196NoDev";

Parameter NOUSERUSER = "OcuProbe196NoUser";

/// <p>The rows <parameter>GRANTED</parameter> holds, numbered 1 to this.</p>
Parameter GRANTEDROWS As INTEGER = 40;

/// <p>Whether this instance is armed for throwaway principals.</p>
ClassMethod Armed() As %Boolean
{
    Quit ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1)
}

/// <p>Create every probe object, removing any left first.</p>
ClassMethod Make() As %Status
{
    Set tSC = ..Remove()
    If $$$ISERR(tSC) Quit tSC
    Set tStatements = $ListBuild(
        "CREATE TABLE " _ ..#GRANTED _ " (Name VARCHAR(50), Num INTEGER)",
        "CREATE TABLE " _ ..#HIDDEN _ " (Name VARCHAR(50), Num INTEGER)",
        "INSERT INTO " _ ..#HIDDEN _ " (Name, Num) VALUES ('h1', 1)",
        "INSERT INTO " _ ..#HIDDEN _ " (Name, Num) VALUES ('h2', 2)",
        "CREATE FUNCTION " _ ..#SLOW _ "(IN p INT) RETURNS INT LANGUAGE OBJECTSCRIPT { Hang 0.1 Quit p }",
        "CREATE PROCEDURE " _ ..#LEAVEOPEN _ "() LANGUAGE OBJECTSCRIPT { TSTART }",
        "CREATE PROCEDURE " _ ..#LISTING _ "() DYNAMIC RESULT SETS 1 LANGUAGE OBJECTSCRIPT { Set tRows = ##class(%SQL.Statement).%ExecDirect(, ""SELECT Name, Num FROM " _ ..#GRANTED _ " ORDER BY Num"") Do %sqlcontext.AddResultSet(tRows) }",
        "CREATE FUNCTION " _ ..#HIDDENCOUNT _ "() RETURNS INT LANGUAGE OBJECTSCRIPT { Quit 0 }",
        "CREATE PROCEDURE " _ ..#ECHO _ "(IN pIn INT, OUT pOut INT) LANGUAGE OBJECTSCRIPT { Set pOut = pIn }"
    )
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:$ListLength(tStatements) {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, $List(tStatements, tI))
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "probe statement " _ tI _ " failed: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
                Quit
            }
        }
        If $$$ISOK(tSC) {
            For tN = 1:1:..#GRANTEDROWS {
                Set tResult = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO " _ ..#GRANTED _ " (Name, Num) VALUES (?, ?)", "n" _ tN, tN)
                If tResult.%SQLCODE < 0 {
                    Set tSC = $$$ERROR($$$GeneralError, "probe row " _ tN _ " failed: SQLCODE " _ tResult.%SQLCODE)
                    Quit
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) Set tSC = ..MakeOwnView()
    Quit tSC
}

/// <p>Create <parameter>OWNVIEW</parameter> in the install namespace, over OcuPilot's own proposal
/// table.</p>
ClassMethod MakeOwnView() As %Status
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "CREATE VIEW " _ ..#OWNVIEW _ " AS SELECT ID FROM OcuPilot_Kernel_State.Proposal")
    If tResult.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the own view failed: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
    Quit $$$OK
}

/// <p>Remove every probe object, data included, from <parameter>NAMESPACE</parameter> and the
/// install namespace; a failing status when any class of package <parameter>SCHEMA</parameter>
/// survives in either.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tHome = $NAMESPACE
    Set tOrigNS = $NAMESPACE
    Try {
        For tNamespace = tHome, ..#NAMESPACE {
            Set $NAMESPACE = tNamespace
            For tDrop = "DROP VIEW " _ ..#OWNVIEW, "DROP FUNCTION " _ ..#SLOW, "DROP FUNCTION " _ ..#HIDDENCOUNT, "DROP PROCEDURE " _ ..#LEAVEOPEN, "DROP PROCEDURE " _ ..#LISTING, "DROP PROCEDURE " _ ..#ECHO, "DROP TABLE " _ ..#GRANTED _ " CASCADE", "DROP TABLE " _ ..#HIDDEN _ " CASCADE" {
                Do ##class(%SQL.Statement).%ExecDirect(, tDrop)
            }
            Do $System.OBJ.DeletePackage(..#SCHEMA, "-d")
            Set tLeft = ""
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", ..#SCHEMA _ ".")
            While tResult.%Next() {
                Set tLeft = tLeft _ " " _ tResult.%GetData(1)
            }
            If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "probe classes survive in " _ tNamespace _ ":" _ tLeft))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The rows <parameter>GRANTED</parameter> holds and the sum of their <code>Num</code>, as
/// <code>rows sum</code>; how a test reads a table back unchanged.</p>
ClassMethod Granted(pTable As %String = {..#GRANTED}) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*), SUM(Num) FROM " _ pTable)
        If tResult.%Next() Set tText = tResult.%GetData(1) _ " " _ tResult.%GetData(2)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.Name
    }
    Quit tText
}

/// <p>Whether <parameter>NAMESPACE</parameter> holds a table named <var>pTable</var>.</p>
ClassMethod HoldsTable(pTable As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHolds = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA || '.' || TABLE_NAME = ?", pTable)
        If tResult.%Next() Set tHolds = (tResult.%GetData(1) > 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p>Whether <parameter>NAMESPACE</parameter> holds a routine (a procedure or a function) named
/// <var>pRoutine</var>.</p>
ClassMethod HoldsRoutine(pRoutine As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHolds = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA || '.' || ROUTINE_NAME = ?", pRoutine)
        If tResult.%Next() Set tHolds = (tResult.%GetData(1) > 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p>Prepare each statement of <var>pTexts</var> in <parameter>NAMESPACE</parameter> as the caller
/// and hold it open in <var>pHeld</var> until <method>Release</method>, so its cached compile stays
/// in the namespace: another account's statement, prepared first. Answers how many prepared.</p>
ClassMethod Hold(pTexts As %List, Output pHeld) As %Integer
{
    Kill pHeld
    Set tPrepared = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:$ListLength(pTexts) {
            Set pHeld(tI) = ##class(%SQL.Statement).%New()
            If $$$ISOK(pHeld(tI).%Prepare($List(pTexts, tI), 1)) Set tPrepared = tPrepared + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tPrepared
}

/// <p>Release the statements <method>Hold</method> held, in <parameter>NAMESPACE</parameter>, where
/// each purges its cached compile as it closes.</p>
ClassMethod Release(ByRef pHeld)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill pHeld
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Kill pHeld
    }
}

/// <p>Prepare <var>pText</var> in <var>pNamespace</var> with privilege checks on, outside the port,
/// releasing the statement there: <code>{outcome: prepared}</code> or <code>{outcome: error,
/// sqlcode}</code>.</p>
ClassMethod PreparedIn(pNamespace As %String, pText As %String) As %DynamicObject
{
    Set tAnswer = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare(pText, 1)
        Set tStatement = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tSC) {
            Do tAnswer.%Set("outcome", "prepared", "string")
        } Else {
            Set tMessage = ""
            Do tAnswer.%Set("outcome", "error", "string")
            Do tAnswer.%Set("sqlcode", $System.Status.StatusToSQLCODE(tSC, .tMessage), "number")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tAnswer.%Set("outcome", "raised " _ ex.Name, "string")
    }
    Quit tAnswer
}

/// <p>How many statement-index rows <parameter>NAMESPACE</parameter> holds whose text carries
/// <var>pMark</var>, or <code>-1</code> when the read failed.</p>
ClassMethod IndexRows(pMark As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tRows = -1
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATEMENTS WHERE Statement [ ?", pMark)
        If (tResult.%SQLCODE >= 0) && tResult.%Next() Set tRows = +tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRows
}

/// <p>Create the three principals with password <var>pPassword</var>, grant <parameter>USER</parameter>
/// and the other two SELECT on <parameter>GRANTED</parameter>, and read every grant back. Refuses,
/// creating nothing, unless <method>Armed</method>.</p>
ClassMethod EnsurePrincipals(pPassword As %String) As %Status
{
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlConsoleProbe creates IRIS users and roles and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources($NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tUserCode, .tUserGlobals, .tUserMapped, .tUserResolved)
    If 'tResolved || 'tUserResolved || (tCode = "") || (tUserCode = "") Quit $$$ERROR($$$GeneralError, "the namespaces' code databases could not be resolved")
    Set tSC = ..RemovePrincipals()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tCase = $ListBuild(..#USER, tCode _ ":R,%Development:U," _ tUserCode _ ":RW"), $ListBuild(..#NODEVUSER, tCode _ ":R," _ tUserCode _ ":RW,%Admin_Operate:U"), $ListBuild(..#NOUSERUSER, tCode _ ":R,%Development:U") {
            Set tSC = ##class(Security.Roles).Create($List(tCase, 1) _ "Role", "OcuPilot test: SQL console principal role (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tCase, 1), $List(tCase, 1) _ "Role", pPassword, "OcuPilot SQL console test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.SqlConsoleProbe")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    For tUser = ..#USER, ..#NODEVUSER, ..#NOUSERUSER {
        Set tSC = ..Grant(tUser)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tRead = ($SYSTEM.Security.CheckUserPermission(..#USER, "%Development", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#USER, tUserCode, "WRITE") = 1)
    Set tRead = tRead && ($SYSTEM.Security.CheckUserPermission(..#NODEVUSER, "%Development", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOUSERUSER, tUserCode, "READ") '= 1)
    Set tRead = tRead && ..Grants(..#USER, ..#GRANTED) && '..Grants(..#USER, ..#HIDDEN)
    If 'tRead Quit $$$ERROR($$$GeneralError, "the SQL console principals' grants did not read back as declared")
    Quit $$$OK
}

/// <p>Grant <var>pUser</var> SELECT on <parameter>GRANTED</parameter> in <parameter>NAMESPACE</parameter>.</p>
ClassMethod Grant(pUser As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON " _ ..#GRANTED _ " TO " _ pUser)
        If tResult.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the grant failed: SQLCODE " _ tResult.%SQLCODE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pUser</var> holds SELECT on <var>pTable</var> in <parameter>NAMESPACE</parameter>,
/// as the instance answers it.</p>
ClassMethod Grants(pUser As %String, pTable As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHolds = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHolds = ($SYSTEM.SQL.Security.CheckPrivilege(pUser, 1, pTable, "s", ..#NAMESPACE) = 1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHolds = 0
    }
    Quit tHolds
}

/// <p>Delete the three principals and their roles; a failing status when any survives.</p>
ClassMethod RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLeft = ""
        For tUser = ..#USER, ..#NODEVUSER, ..#NOUSERUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) Set tLeft = tLeft _ " user " _ tUser
            If ##class(Security.Roles).Exists(tUser _ "Role") Set tLeft = tLeft _ " role " _ tUser _ "Role"
        }
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "SQL console principals survive:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Run <var>pLegs</var> -- JSON text of an array of <code>{op, namespace, statement, values?,
/// maxRows?}</code>, <code>op</code> one of <code>classify</code>, <code>query</code>,
/// <code>write</code> and <code>plan</code>, through <class>OcuPilot.Port.SqlPort</class>, or
/// <code>prepare</code>, outside it (<method>PreparedIn</method>) -- as <var>pUsername</var> in a
/// child process, and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUsername As %String, pLegs As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.SqlConsoleProbe).RunAs($Job, pUsername, pLegs)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each leg
/// of <var>pLegs</var>, and signal <var>pParent</var> <code>{username, legs: [{http, code, failedPair,
/// outcome, sqlcode, kind}]}</code>, or <code>{error}</code>.</p>
ClassMethod RunAs(pParent As %Integer, pUsername As %String, pLegs As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tLegs = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pLegs).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLeg) {
            Set tAnswer = ""
            Set tHttp = 0
            Set tFault = ""
            Set tValues = $Select(tLeg.%GetTypeOf("values") = "array": tLeg.%Get("values"), 1: [])
            Set tOp = tLeg.%Get("op")
            If tOp = "classify" {
                Set tSC = ##class(OcuPilot.Port.SqlPort).Classify(tLeg.%Get("namespace"), tLeg.%Get("statement"), .tAnswer, .tHttp, .tFault)
            } ElseIf tOp = "prepare" {
                Set tAnswer = ..PreparedIn(tLeg.%Get("namespace"), tLeg.%Get("statement"))
                Set tSC = $$$OK
            } ElseIf tOp = "plan" {
                Set tSC = ##class(OcuPilot.Port.SqlPort).Plan(tLeg.%Get("namespace"), tLeg.%Get("statement"), .tAnswer, .tHttp, .tFault)
            } Else {
                Set tSC = ##class(OcuPilot.Port.SqlPort).Run(tLeg.%Get("namespace"), tLeg.%Get("statement"), tValues, 10, tOp, .tAnswer, .tHttp, .tFault)
            }
            Set tRow = {}
            Do tRow.%Set("http", $Select($$$ISOK(tSC): 200, 1: +tHttp), "number")
            Do tRow.%Set("code", $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "string")
            Do tRow.%Set("failedPair", $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("failedPair"), 1: ""), "string")
            Set tError = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("error") = "object"): tAnswer.%Get("error"), 1: "")
            Do tRow.%Set("outcome", $Select($IsObject(tError): "error", $IsObject(tAnswer): tAnswer.%Get("outcome"), 1: ""), "string")
            Do tRow.%Set("sqlcode", $Select($IsObject(tError): tError.%Get("sqlcode"), $IsObject(tAnswer): tAnswer.%Get("sqlcode"), 1: ""), "string")
            Do tRow.%Set("kind", $Select($IsObject(tAnswer): $Select(tAnswer.%IsDefined("Kind"): tAnswer.%Get("Kind"), 1: tAnswer.%Get("kind")), 1: ""), "string")
            Do tLegs.%Push(tRow)
        }
        Do tOut.%Set("legs", tLegs)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Leg <var>pIndex</var> (0-based) of a probe answer as <code>http code failedPair outcome
/// sqlcode</code>.</p>
ClassMethod LegText(pProbe As %DynamicObject, pIndex As %Integer) As %String
{
    If '$IsObject(pProbe) || (pProbe.%GetTypeOf("legs") '= "array") Quit "absent " _ $Select($IsObject(pProbe): pProbe.%Get("error"), 1: "")
    Set tLeg = pProbe.%Get("legs").%Get(pIndex)
    If '$IsObject(tLeg) Quit "absent"
    Quit tLeg.http _ " " _ tLeg.code _ " " _ tLeg.failedPair _ " " _ tLeg.outcome _ " " _ tLeg.sqlcode
}

}
