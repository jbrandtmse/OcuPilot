/// <p>Story 19.8's probe SQL objects and principals, created by the data browser save's tests and
/// removed by <method>Remove</method> and <method>RemovePrincipals</method>. In <code>USER</code>,
/// schema <parameter>SCHEMA</parameter>: <parameter>EDIT</parameter>, keyed by <code>Code</code>, with
/// a column of every kind, a stream and a computed column, its rows put back by <method>Fill</method>;
/// <parameter>PAIR</parameter>, keyed by <code>A</code> and <code>B</code>;
/// <parameter>IDENT</parameter>, keyed by its identity column; <parameter>COMP</parameter>, keyless,
/// with a computed and a row-version column; <parameter>SLOW</parameter>, whose every update waits a
/// second in a trigger; and the view <parameter>EDITVIEW</parameter> over <parameter>EDIT</parameter>.
/// In the install namespace, the view <parameter>OWNVIEW</parameter> over OcuPilot's own proposal
/// table.</p>
/// <p>Each principal holds <class>OcuPilot.Test.SqlConsoleProbe</class>'s role pairs:
/// <parameter>UPUSER</parameter> SELECT and UPDATE on <parameter>EDIT</parameter>;
/// <parameter>COLUSER</parameter> SELECT and <code>UPDATE(Name)</code>; <parameter>INSUSER</parameter>
/// SELECT and <code>INSERT(Code, Name)</code>; <parameter>ROUSER</parameter> SELECT alone, and
/// <code>SELECT(Name)</code> on <parameter>PAIR</parameter>, which leaves out its key;
/// <parameter>NODEVUSER</parameter> no <code>%Development:USE</code>, with <code>%Admin_Operate:USE</code>
/// to clear the API's floor. They, and the resource <parameter>PAGERESOURCE</parameter> a test assigns
/// to the classic Open Table page, are created only where
/// <method>OcuPilot.Test.SqlConsoleProbe.Armed</method> reads 1, and the grants are read back.</p>
/// <p><method>RunAs</method> is the child process a test starts to call
/// <class>OcuPilot.Port.SqlPort</class>'s save as a real principal.</p>
Class OcuPilot.Test.SqlSaveProbe Extends %RegisteredObject
{

Parameter NAMESPACE = "USER";

Parameter SCHEMA = "OcuProbe198";

Parameter EDIT = "OcuProbe198.Edit";

Parameter PAIR = "OcuProbe198.Pair";

Parameter IDENT = "OcuProbe198.Ident";

Parameter COMP = "OcuProbe198.Comp";

Parameter SLOW = "OcuProbe198.Slow";

Parameter SLOWTRIGGER = "OcuProbe198.SlowHang";

Parameter EDITVIEW = "OcuProbe198.EditView";

/// <p>The view over OcuPilot's own proposal table, made in the install namespace.</p>
Parameter OWNVIEW = "OcuProbe198.OwnView";

/// <p>The probe principals; each holds the role named <code>&lt;user&gt;Role</code>.</p>
Parameter UPUSER = "OcuProbe198Up";

Parameter COLUSER = "OcuProbe198Col";

Parameter INSUSER = "OcuProbe198Ins";

Parameter ROUSER = "OcuProbe198Ro";

Parameter NODEVUSER = "OcuProbe198NoDev";

/// <p>The resource a test assigns to the classic Open Table page.</p>
Parameter PAGERESOURCE = "OcuProbe198Page";

/// <p>Whether this instance is armed for throwaway principals.</p>
ClassMethod Armed() As %Boolean
{
    Quit ##class(OcuPilot.Test.SqlConsoleProbe).Armed()
}

/// <p>Create every probe object, removing any left first.</p>
ClassMethod Make() As %Status
{
    Set tSC = ..Remove()
    If $$$ISERR(tSC) Quit tSC
    Set tStatements = $ListBuild(
        "CREATE TABLE " _ ..#EDIT _ " (Code VARCHAR(10) PRIMARY KEY, Name VARCHAR(50), Note VARCHAR(50), Num NUMERIC(6,2), Dbl DOUBLE, Born DATE, Stamp TIMESTAMP, Tm TIME, Flag BIT, Pt POSIXTIME, Memo LONGVARCHAR, Shout VARCHAR(50) COMPUTECODE { Set {*} = $ZConvert({Name}, ""U"") } COMPUTEONCHANGE (Name))",
        "CREATE TABLE " _ ..#PAIR _ " (A INTEGER, B INTEGER, Name VARCHAR(20), PRIMARY KEY (A, B))",
        "CREATE TABLE " _ ..#IDENT _ " (Id2 IDENTITY, Name VARCHAR(20))",
        "CREATE TABLE " _ ..#COMP _ " (N INTEGER, Twice INTEGER COMPUTECODE { Set {*} = {N} * 2 } COMPUTEONCHANGE (N), Ver ROWVERSION)",
        "CREATE TABLE " _ ..#SLOW _ " (K INTEGER PRIMARY KEY, Name VARCHAR(20))",
        "CREATE TRIGGER " _ ..#SLOWTRIGGER _ " BEFORE UPDATE ON " _ ..#SLOW _ " LANGUAGE OBJECTSCRIPT { Hang 1 }",
        "CREATE VIEW " _ ..#EDITVIEW _ " AS SELECT Code, Name FROM " _ ..#EDIT
    )
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ..Exec(tStatements)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) Set tSC = ..Fill()
    If $$$ISOK(tSC) Set tSC = ..Exec($ListBuild("CREATE VIEW " _ ..#OWNVIEW _ " AS SELECT ID FROM OcuPilot_Kernel_State.Proposal"))
    Quit tSC
}

/// <p>Put every probe table's rows back as <method>Make</method> made them: <parameter>EDIT</parameter>
/// rows <code>a</code> to <code>f</code>, row <code>a</code> carrying a value of every kind and
/// <code>e</code> a NULL name; <parameter>PAIR</parameter>'s two rows; <parameter>IDENT</parameter>'s
/// one; <parameter>COMP</parameter>'s one; and <parameter>SLOW</parameter>'s rows 1 to 4.</p>
ClassMethod Fill() As %Status
{
    Set tStatements = $ListBuild(
        "DELETE FROM " _ ..#EDIT, "DELETE FROM " _ ..#PAIR, "DELETE FROM " _ ..#IDENT, "DELETE FROM " _ ..#COMP, "DELETE FROM " _ ..#SLOW,
        "INSERT INTO " _ ..#EDIT _ " (Code, Name, Num, Dbl, Born, Stamp, Tm, Flag, Pt, Memo) VALUES ('a', 'abc', 1.5, .1, '2026-10-01', '2026-10-01 08:00:00', '13:45:00', 1, '2026-10-01 12:34:56.123456', 'memo')",
        "INSERT INTO " _ ..#EDIT _ " (Code, Name, Note, Num) VALUES ('b', 'bee', 'nb', 2)",
        "INSERT INTO " _ ..#EDIT _ " (Code, Name, Note, Num) VALUES ('c', 'sea', 'nc', 3)",
        "INSERT INTO " _ ..#EDIT _ " (Code, Name, Note, Num) VALUES ('d', 'dee', 'nd', 4)",
        "INSERT INTO " _ ..#EDIT _ " (Code, Note, Num) VALUES ('e', 'ne', 5)",
        "INSERT INTO " _ ..#EDIT _ " (Code, Name, Note, Num) VALUES ('f', 'eff', 'nf', 6)",
        "INSERT INTO " _ ..#PAIR _ " (A, B, Name) VALUES (1, 1, 'one-one')",
        "INSERT INTO " _ ..#PAIR _ " (A, B, Name) VALUES (1, 2, 'one-two')",
        "INSERT INTO " _ ..#IDENT _ " (Name) VALUES ('first')",
        "INSERT INTO " _ ..#COMP _ " (N) VALUES (1)",
        "INSERT INTO " _ ..#SLOW _ " (K, Name) VALUES (1, 'o1')",
        "INSERT INTO " _ ..#SLOW _ " (K, Name) VALUES (2, 'o2')",
        "INSERT INTO " _ ..#SLOW _ " (K, Name) VALUES (3, 'o3')",
        "INSERT INTO " _ ..#SLOW _ " (K, Name) VALUES (4, 'o4')"
    )
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ..Exec(tStatements)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Run each statement of <var>pStatements</var> in the current namespace, stopping at the first
/// that fails, named with its SQLCODE. Literals are read in the ODBC form. It calls no other class,
/// so it runs in any namespace.</p>
ClassMethod Exec(pStatements As %List) As %Status
{
    For tI = 1:1:$ListLength(pStatements) {
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tStatement.%SelectMode = 1
        Set tResult = tStatement.%ExecDirect(.tStatement, $List(pStatements, tI))
        If tResult.%SQLCODE < 0 Return $$$ERROR($$$GeneralError, "probe statement failed: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message _ ": " _ $Extract($List(pStatements, tI), 1, 80))
    }
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
            For tDrop = "DROP VIEW " _ ..#OWNVIEW, "DROP VIEW " _ ..#EDITVIEW, "DROP TRIGGER " _ ..#SLOWTRIGGER, "DROP TABLE " _ ..#EDIT _ " CASCADE", "DROP TABLE " _ ..#PAIR _ " CASCADE", "DROP TABLE " _ ..#IDENT _ " CASCADE", "DROP TABLE " _ ..#COMP _ " CASCADE", "DROP TABLE " _ ..#SLOW _ " CASCADE" {
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

/// <p>Create the five principals with password <var>pPassword</var> and the resource
/// <parameter>PAGERESOURCE</parameter>, grant the principals their SQL privileges, and read every grant
/// back. Refuses, creating nothing, unless <method>Armed</method>.</p>
ClassMethod EnsurePrincipals(pPassword As %String) As %Status
{
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlSaveProbe creates IRIS users, roles and a resource and runs on a throwaway container only. " _ $Parameter("OcuPilot.Test.SqlConsoleProbe", "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created.")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources($NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tUserCode, .tUserGlobals, .tUserMapped, .tUserResolved)
    If 'tResolved || 'tUserResolved || (tCode = "") || (tUserCode = "") Quit $$$ERROR($$$GeneralError, "the namespaces' code databases could not be resolved")
    Set tSC = ..RemovePrincipals()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPairs = tCode _ ":R,%Development:U," _ tUserCode _ ":RW"
        For tCase = $ListBuild(..#UPUSER, tPairs), $ListBuild(..#COLUSER, tPairs), $ListBuild(..#INSUSER, tPairs), $ListBuild(..#ROUSER, tPairs), $ListBuild(..#NODEVUSER, tCode _ ":R," _ tUserCode _ ":RW,%Admin_Operate:U") {
            Set tSC = ##class(Security.Roles).Create($List(tCase, 1) _ "Role", "OcuPilot test: data browser save principal role (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tCase, 1), $List(tCase, 1) _ "Role", pPassword, "OcuPilot data browser save test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.SqlSaveProbe")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISOK(tSC) Set tSC = ##class(Security.Resources).Create(..#PAGERESOURCE, "OcuPilot test: classic page resource (throwaway)", "", "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tGrants = $ListBuild(
        "GRANT SELECT, UPDATE ON " _ ..#EDIT _ " TO " _ ..#UPUSER,
        "GRANT SELECT ON " _ ..#EDIT _ " TO " _ ..#COLUSER _ ", " _ ..#INSUSER _ ", " _ ..#ROUSER _ ", " _ ..#NODEVUSER,
        "GRANT UPDATE (Name) ON " _ ..#EDIT _ " TO " _ ..#COLUSER,
        "GRANT INSERT (Code, Name) ON " _ ..#EDIT _ " TO " _ ..#INSUSER,
        "GRANT SELECT (Name) ON " _ ..#PAIR _ " TO " _ ..#ROUSER
    )
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ..Exec(tGrants)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tRead = ($SYSTEM.Security.CheckUserPermission(..#UPUSER, "%Development", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#NODEVUSER, "%Development", "USE") '= 1)
    Set tRead = tRead && ..Grants(..#UPUSER, "u") && ..Grants(..#ROUSER, "s") && '..Grants(..#ROUSER, "u") && '..Grants(..#ROUSER, "i") && '..Grants(..#COLUSER, "u") && '..Grants(..#INSUSER, "i") && '..Grants(..#INSUSER, "d")
    If 'tRead Quit $$$ERROR($$$GeneralError, "the data browser save principals' grants did not read back as declared")
    Quit $$$OK
}

/// <p>Whether <var>pUser</var> holds the table privilege <var>pPrivilege</var> (<code>s</code>,
/// <code>i</code>, <code>u</code> or <code>d</code>) on the whole of <parameter>EDIT</parameter>, as the
/// instance answers it.</p>
ClassMethod Grants(pUser As %String, pPrivilege As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHolds = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHolds = ($SYSTEM.SQL.Security.CheckPrivilege(pUser, 1, ..#EDIT, pPrivilege, ..#NAMESPACE) = 1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHolds = 0
    }
    Quit tHolds
}

/// <p>Delete the five principals, their roles and <parameter>PAGERESOURCE</parameter>; a failing
/// status when any survives.</p>
ClassMethod RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLeft = ""
        For tUser = ..#UPUSER, ..#COLUSER, ..#INSUSER, ..#ROUSER, ..#NODEVUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) Set tLeft = tLeft _ " user " _ tUser
            If ##class(Security.Roles).Exists(tUser _ "Role") Set tLeft = tLeft _ " role " _ tUser _ "Role"
        }
        If ##class(Security.Resources).Exists(..#PAGERESOURCE) Do ##class(Security.Resources).Delete(..#PAGERESOURCE)
        If ##class(Security.Resources).Exists(..#PAGERESOURCE) Set tLeft = tLeft _ " resource " _ ..#PAGERESOURCE
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "data browser save principals survive:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><parameter>EDIT</parameter>'s row <var>pCode</var> as <code>column=value</code> pairs joined by
/// <code>|</code> for the comma-separated <var>pColumns</var> (<code>Name</code>, <code>Note</code> and
/// <code>Num</code> when empty), each value as an ODBC-mode read answers it, <code>&lt;null&gt;</code>
/// for SQL NULL and <code>&lt;empty&gt;</code> for an empty string; <code>absent</code> when there is no
/// such row.</p>
ClassMethod Row(pCode As %String, pColumns As %String = "") As %String
{
    If pColumns = "" Set pColumns = $ListToString($ListBuild("Name", "Note", "Num"))
    Set tOrigNS = $NAMESPACE
    Set tText = "absent"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tStatement.%SelectMode = 1
        Set tSC = tStatement.%Prepare("SELECT " _ pColumns _ " FROM " _ ..#EDIT _ " WHERE Code = ?")
        Set tResult = tStatement.%Execute(pCode)
        If tResult.%Next() {
            Set tText = ""
            For tI = 1:1:$Length(pColumns, ",") {
                Set tValue = tResult.%GetData(tI)
                Set tText = tText _ $Select(tI = 1: "", 1: "|") _ $Piece(pColumns, ",", tI) _ "=" _ $Select(tValue = "": "<null>", tValue = $Char(0): "<empty>", 1: tValue)
            }
        }
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.Name
    }
    Quit tText
}

/// <p>Run <var>pText</var> in <parameter>NAMESPACE</parameter> as the caller; its SQLCODE.</p>
ClassMethod Run(pText As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCode = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tCode = ##class(%SQL.Statement).%ExecDirect(, pText).%SQLCODE
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCode = ex.Name
    }
    Quit tCode
}

/// <p>The first cell of the first row <var>pText</var> answers in <parameter>NAMESPACE</parameter>, read
/// in ODBC mode as the caller, or <code>absent</code> when it answers no row.</p>
ClassMethod Value(pText As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tValue = "absent"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tStatement.%SelectMode = 1
        Set tSC = tStatement.%Prepare(pText)
        Set tResult = tStatement.%Execute()
        If tResult.%Next() Set tValue = tResult.%GetData(1)
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tValue = "unread " _ ex.Name
    }
    Quit tValue
}

/// <p>Save <var>pChanges</var>, a <class>%DynamicArray</class>, to <var>pTable</var>
/// (<code>Schema.Name</code>) in <var>pNamespace</var> through <var>pPort</var>'s write path way in,
/// answering the port's answer, or its refusal as <code>{http, code, failedPair, problem}</code>.</p>
ClassMethod Save(pNamespace As %String, pTable As %String, pChanges As %DynamicArray, pPort As %String = "OcuPilot.Port.SqlPort") As %DynamicObject
{
    Kill tQuery
    Set tQuery("id") = "sql"
    Set tQuery("namespace") = pNamespace
    Set tQuery("schema") = $Piece(pTable, ".")
    Set tQuery("table") = $Piece(pTable, ".", 2, *)
    Set tQuery("changes") = $Select($IsObject(pChanges): pChanges.%ToJSON(), 1: pChanges)
    Set tSC = $ClassMethod(pPort, "Invoke", "SqlData", "RUN", .tQuery, "", .tAnswer, .tHttp, .tFault)
    If $$$ISOK(tSC) && $IsObject($Get(tAnswer)) Quit tAnswer
    Quit ..Refusal(.tHttp, .tFault)
}

/// <p><var>pTable</var>'s save plan in <var>pNamespace</var> through the write path's fresh read,
/// answering it, or its refusal as <method>Refusal</method> writes it.</p>
ClassMethod Plan(pNamespace As %String, pTable As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("id") = "sql"
    Set tQuery("namespace") = pNamespace
    Set tQuery("schema") = $Piece(pTable, ".")
    Set tQuery("table") = $Piece(pTable, ".", 2, *)
    Set tSC = ##class(OcuPilot.Port.SqlPort).Invoke("SqlData", "PLAN", .tQuery, "", .tAnswer, .tHttp, .tFault)
    If $$$ISOK(tSC) && $IsObject($Get(tAnswer)) Quit tAnswer
    Quit ..Refusal(.tHttp, .tFault)
}

/// <p>A refusal as <code>{http, code, failedPair, problem}</code>.</p>
ClassMethod Refusal(ByRef pHttp, ByRef pFault) As %DynamicObject
{
    Set tOut = ##class(OcuPilot.Test.SqlBrowseProbe).Refusal(.pHttp, .pFault)
    Do tOut.%Set("problem", $Select($IsObject($Get(pFault)) && $IsObject(pFault.%Get("detail")): pFault.%Get("detail").%Get("problem"), 1: ""), "string")
    Quit tOut
}

/// <p>An answer as one line for an assertion: a refusal's status, code and pair, or each row's index
/// and outcome, with its row count or SQLCODE, joined by <code>,</code>.</p>
ClassMethod Line(pAnswer As %DynamicObject) As %String
{
    If '$IsObject($Get(pAnswer)) Quit "no answer"
    If pAnswer.%IsDefined("http") Quit pAnswer.http _ " " _ pAnswer.code _ " " _ pAnswer.failedPair
    Set tOut = ""
    If pAnswer.%GetTypeOf("results") = "array" {
        Set tIterator = pAnswer.results.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tResult) {
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tResult.%Get("index") _ ":" _ tResult.%Get("outcome") _ $Select(tResult.%IsDefined("rowCount"): "/" _ tResult.%Get("rowCount"), 1: "") _ $Select(tResult.%GetTypeOf("sqlcode") = "number": "/" _ tResult.%Get("sqlcode"), 1: "")
        }
    }
    Quit pAnswer.%Get("outcome") _ " " _ tOut _ " saved=" _ pAnswer.%Get("saved") _ " failed=" _ pAnswer.%Get("failed")
}

/// <p>Run <var>pLegs</var> -- JSON text of an array of <code>{namespace, table, changes}</code>, each
/// saved through <method>Save</method> -- as <var>pUsername</var> in a child process, and answer what
/// it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUsername As %String, pLegs As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.SqlSaveProbe).RunAs($Job, pUsername, pLegs)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, save each leg
/// of <var>pLegs</var>, and signal <var>pParent</var> <code>{username, legs: [answer]}</code>, or
/// <code>{error}</code>.</p>
ClassMethod RunAs(pParent As %Integer, pUsername As %String, pLegs As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tLegs = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pLegs).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLeg) {
            Do tLegs.%Push(..Save(tLeg.%Get("namespace"), tLeg.%Get("table"), tLeg.%Get("changes")))
        }
        Do tOut.%Set("legs", tLegs)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Leg <var>pIndex</var> (0-based) of a probe answer as <method>Line</method> reads it.</p>
ClassMethod LegLine(pProbe As %DynamicObject, pIndex As %Integer) As %String
{
    If '$IsObject(pProbe) || (pProbe.%GetTypeOf("legs") '= "array") Quit "absent " _ $Select($IsObject(pProbe): pProbe.%Get("error"), 1: "")
    Quit ..Line(pProbe.%Get("legs").%Get(pIndex))
}

}
