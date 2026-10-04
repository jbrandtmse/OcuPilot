/// <p>Story 19.7's probe SQL objects and principals, created by the data browser's tests and removed
/// by <method>Remove</method> and <method>RemovePrincipals</method>. In <code>USER</code>, schema
/// <parameter>SCHEMA</parameter>: <parameter>PLAIN</parameter>, 40 keyless rows with a column of every
/// kind; <parameter>KEYED</parameter>, <parameter>PAIR</parameter> and <parameter>IDENT</parameter>,
/// with a single, a composite and an identity key, their rows inserted out of key order;
/// <parameter>TWO</parameter>, two columns; the view <parameter>OVER30</parameter> of
/// <parameter>PLAIN</parameter>'s rows numbered above 30; the function <parameter>SLOW</parameter>,
/// waiting 0.005 s a call, and the view <parameter>SLOWVIEW</parameter> that calls it once for each of
/// its 1,600 rows;
/// <parameter>PETS</parameter>, whose string column is NULL in 28 of 30 rows with its statistics
/// gathered; <parameter>WIDE</parameter>, <parameter>WIDEROWS</parameter> rows of three 1,500-character
/// streams, more than the answer's 1,000,000 characters hold once each cell is cut to 1,000; and
/// <parameter>BLOBS</parameter>, <parameter>BLOBROWS</parameter> rows of three 600-byte binary values,
/// which fit the answer as fetched but not once each is written as hex. In the install namespace, the
/// view <parameter>OWNVIEW</parameter> over OcuPilot's own proposal table.</p>
/// <p>Each principal holds <class>OcuPilot.Test.SqlConsoleProbe</class>'s role pairs:
/// <parameter>USER</parameter> SELECT on <parameter>PLAIN</parameter>, <parameter>PAIR</parameter> and
/// <parameter>IDENT</parameter>, and <code>SELECT(Name)</code> on <parameter>KEYED</parameter>, on
/// <parameter>TWO</parameter> and on <parameter>OVER30</parameter>; <parameter>VIEWUSER</parameter> SELECT on <parameter>OVER30</parameter>
/// alone; <parameter>NODEVUSER</parameter> no <code>%Development:USE</code>, with
/// <code>%Admin_Operate:USE</code> to clear the API's floor; <parameter>NOUSERUSER</parameter> no READ
/// on <code>USER</code>'s database. They are created only where
/// <method>OcuPilot.Test.SqlConsoleProbe.Armed</method> reads 1, and their grants are read back.</p>
/// <p><method>RunAs</method> is the child process a test starts to call
/// <class>OcuPilot.Port.SqlPort</class>'s data browser entry points as a real principal.</p>
Class OcuPilot.Test.SqlBrowseProbe Extends %RegisteredObject
{

Parameter NAMESPACE = "USER";

Parameter SCHEMA = "OcuProbe197";

Parameter PLAIN = "OcuProbe197.Plain";

Parameter KEYED = "OcuProbe197.Keyed";

Parameter PAIR = "OcuProbe197.Pair";

Parameter IDENT = "OcuProbe197.Ident";

Parameter TWO = "OcuProbe197.Two";

Parameter OVER30 = "OcuProbe197.Over30";

Parameter SLOW = "OcuProbe197.Slow";

Parameter SLOWVIEW = "OcuProbe197.SlowView";

Parameter PETS = "OcuProbe197.Pets";

Parameter WIDE = "OcuProbe197.Wide";

/// <p>The rows <parameter>WIDE</parameter> holds.</p>
Parameter WIDEROWS As INTEGER = 400;

Parameter BLOBS = "OcuProbe197.Blobs";

/// <p>The rows <parameter>BLOBS</parameter> holds.</p>
Parameter BLOBROWS As INTEGER = 400;

/// <p>The view over OcuPilot's own proposal table, made in the install namespace.</p>
Parameter OWNVIEW = "OcuProbe197.OwnView";

/// <p>The probe principals; each holds the role named <code>&lt;user&gt;Role</code>.</p>
Parameter USER = "OcuProbe197User";

Parameter VIEWUSER = "OcuProbe197View";

Parameter NODEVUSER = "OcuProbe197NoDev";

Parameter NOUSERUSER = "OcuProbe197NoUser";

/// <p>The rows <parameter>PLAIN</parameter> holds, numbered 1 to this; row 4's name is NULL, row 5's
/// empty and row 6's the literal <code>n%</code>, and every other row's <code>n</code> and its
/// number.</p>
Parameter PLAINROWS As INTEGER = 40;

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
        "CREATE TABLE " _ ..#PLAIN _ " (Name VARCHAR(50), Num INTEGER, Price NUMERIC(10,2), Flag BIT, Born DATE, Clock TIME, Stamp TIMESTAMP, Notes LONGVARCHAR, Blob VARBINARY(20), Image LONGVARBINARY)",
        "CREATE TABLE " _ ..#KEYED _ " (Code VARCHAR(10) PRIMARY KEY, Name VARCHAR(20))",
        "CREATE TABLE " _ ..#PAIR _ " (A INTEGER, B INTEGER, Name VARCHAR(20), PRIMARY KEY (A, B))",
        "CREATE TABLE " _ ..#IDENT _ " (Id2 IDENTITY, Name VARCHAR(20))",
        "CREATE TABLE " _ ..#TWO _ " (Name VARCHAR(20), Secret VARCHAR(20))",
        "CREATE TABLE " _ ..#PETS _ " (Num INTEGER, Name VARCHAR(50))",
        "CREATE TABLE " _ ..#WIDE _ " (N INTEGER, A LONGVARCHAR, B LONGVARCHAR, C LONGVARCHAR)",
        "CREATE TABLE " _ ..#BLOBS _ " (N INTEGER, A LONGVARBINARY, B LONGVARBINARY, C LONGVARBINARY)",
        "CREATE FUNCTION " _ ..#SLOW _ "(IN p INT) RETURNS INT LANGUAGE OBJECTSCRIPT { Hang 0.005 Quit p }"
    )
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ..Exec(tStatements)
        If $$$ISERR(tSC) Quit
        Set tInsert = ##class(%SQL.Statement).%New()
        Set tInsert.%SelectMode = 1
        For tN = 1:1:..#PLAINROWS {
            Set tName = $Case(tN, 4: "", 5: $Char(0), 6: "n%", : "n" _ tN)
            Set tBorn = $Select(tN = 1: "2026-10-01", 1: "2026-09-" _ $Translate($Justify(tN # 28 + 1, 2), " ", "0"))
            Set tNotes = $Select(tN = 2: $Translate($Justify("", 1500), " ", "x"), 1: "note" _ tN)
            Set tImage = $Select(tN = 3: $Translate($Justify("", 600), " ", $Char(171)), 1: $Char(1, 2))
            Set tResult = tInsert.%ExecDirect(.tInsert, "INSERT INTO " _ ..#PLAIN _ " (Name, Num, Price, Flag, Born, Clock, Stamp, Notes, Blob, Image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", $Select(tN = 4: "", 1: tName), tN, tN _ ".50", tN # 2, tBorn, "13:45:" _ $Translate($Justify(tN, 2), " ", "0"), tBorn _ " 08:00:00", tNotes, $Char(0, 255, tN), tImage)
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "probe row " _ tN _ " failed: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
                Quit
            }
        }
        If $$$ISERR(tSC) Quit
        Set tRows = $ListBuild(
            "INSERT INTO " _ ..#KEYED _ " (Code, Name) VALUES ('c3', 'three')",
            "INSERT INTO " _ ..#KEYED _ " (Code, Name) VALUES ('c1', 'one')",
            "INSERT INTO " _ ..#KEYED _ " (Code, Name) VALUES ('c2', 'two')",
            "INSERT INTO " _ ..#PAIR _ " (A, B, Name) VALUES (2, 1, 'two-one')",
            "INSERT INTO " _ ..#PAIR _ " (A, B, Name) VALUES (1, 2, 'one-two')",
            "INSERT INTO " _ ..#PAIR _ " (A, B, Name) VALUES (1, 1, 'one-one')",
            "INSERT INTO " _ ..#IDENT _ " (Name) VALUES ('first')",
            "INSERT INTO " _ ..#IDENT _ " (Name) VALUES ('second')",
            "INSERT INTO " _ ..#TWO _ " (Name, Secret) VALUES ('t1', 's1')",
            "INSERT INTO " _ ..#TWO _ " (Name, Secret) VALUES ('t2', 's2')",
            "CREATE VIEW " _ ..#OVER30 _ " AS SELECT Name, Num FROM " _ ..#PLAIN _ " WHERE Num > 30",
            "CREATE VIEW " _ ..#SLOWVIEW _ " AS SELECT a.Num AS Num, " _ ..#SLOW _ "(a.Num * 100 + b.Num) AS S FROM " _ ..#PLAIN _ " a, " _ ..#PLAIN _ " b"
        )
        Set tSC = ..Exec(tRows)
        If $$$ISERR(tSC) Quit
        For tN = 1:1:30 {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO " _ ..#PETS _ " (Num, Name) VALUES (?, ?)", tN, $Case(tN, 1: "nemo", 2: "n%x", : ""))
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "probe pet " _ tN _ " failed: SQLCODE " _ tResult.%SQLCODE)
                Quit
            }
        }
        If $$$ISOK(tSC) Set tSC = ..Exec($ListBuild("TUNE TABLE " _ ..#PETS))
        If $$$ISERR(tSC) Quit
        Set tLong = $Translate($Justify("", 1500), " ", "w")
        For tN = 1:1:..#WIDEROWS {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO " _ ..#WIDE _ " (N, A, B, C) VALUES (?, ?, ?, ?)", tN, tLong, tLong, tLong)
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "probe wide row " _ tN _ " failed: SQLCODE " _ tResult.%SQLCODE)
                Quit
            }
        }
        If $$$ISERR(tSC) Quit
        Set tBytes = $Translate($Justify("", 600), " ", "A")
        For tN = 1:1:..#BLOBROWS {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO " _ ..#BLOBS _ " (N, A, B, C) VALUES (?, ?, ?, ?)", tN, tBytes, tBytes, tBytes)
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "probe blob row " _ tN _ " failed: SQLCODE " _ tResult.%SQLCODE)
                Quit
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISOK(tSC) Set tSC = ..Exec($ListBuild("CREATE VIEW " _ ..#OWNVIEW _ " AS SELECT ID FROM OcuPilot_Kernel_State.Proposal"))
    Quit tSC
}

/// <p>Run each statement of <var>pStatements</var> in the current namespace, stopping at the first
/// that fails, named with its SQLCODE.</p>
ClassMethod Exec(pStatements As %List) As %Status
{
    For tI = 1:1:$ListLength(pStatements) {
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, $List(pStatements, tI))
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
            For tDrop = "DROP VIEW " _ ..#OWNVIEW, "DROP VIEW " _ ..#OVER30, "DROP VIEW " _ ..#SLOWVIEW, "DROP FUNCTION " _ ..#SLOW, "DROP TABLE " _ ..#PLAIN _ " CASCADE", "DROP TABLE " _ ..#KEYED _ " CASCADE", "DROP TABLE " _ ..#PAIR _ " CASCADE", "DROP TABLE " _ ..#IDENT _ " CASCADE", "DROP TABLE " _ ..#TWO _ " CASCADE", "DROP TABLE " _ ..#PETS _ " CASCADE", "DROP TABLE " _ ..#WIDE _ " CASCADE", "DROP TABLE " _ ..#BLOBS _ " CASCADE" {
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

/// <p>Create the four principals with password <var>pPassword</var>, grant them their SQL privileges,
/// and read every grant back. Refuses, creating nothing, unless <method>Armed</method>.</p>
ClassMethod EnsurePrincipals(pPassword As %String) As %Status
{
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlBrowseProbe creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter("OcuPilot.Test.SqlConsoleProbe", "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created.")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources($NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tUserCode, .tUserGlobals, .tUserMapped, .tUserResolved)
    If 'tResolved || 'tUserResolved || (tCode = "") || (tUserCode = "") Quit $$$ERROR($$$GeneralError, "the namespaces' code databases could not be resolved")
    Set tSC = ..RemovePrincipals()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPairs = tCode _ ":R,%Development:U," _ tUserCode _ ":RW"
        For tCase = $ListBuild(..#USER, tPairs), $ListBuild(..#VIEWUSER, tPairs), $ListBuild(..#NODEVUSER, tCode _ ":R," _ tUserCode _ ":RW,%Admin_Operate:U"), $ListBuild(..#NOUSERUSER, tCode _ ":R,%Development:U") {
            Set tSC = ##class(Security.Roles).Create($List(tCase, 1) _ "Role", "OcuPilot test: data browser principal role (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create($List(tCase, 1), $List(tCase, 1) _ "Role", pPassword, "OcuPilot data browser test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.SqlBrowseProbe")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tGrants = $ListBuild("GRANT SELECT ON " _ ..#PLAIN _ " TO " _ ..#USER, "GRANT SELECT (Name) ON " _ ..#KEYED _ " TO " _ ..#USER, "GRANT SELECT ON " _ ..#PAIR _ " TO " _ ..#USER, "GRANT SELECT ON " _ ..#IDENT _ " TO " _ ..#USER, "GRANT SELECT (Name) ON " _ ..#TWO _ " TO " _ ..#USER, "GRANT SELECT (Name) ON " _ ..#OVER30 _ " TO " _ ..#USER, "GRANT SELECT ON " _ ..#OVER30 _ " TO " _ ..#VIEWUSER, "GRANT SELECT ON " _ ..#PLAIN _ " TO " _ ..#NODEVUSER _ ", " _ ..#NOUSERUSER)
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
    Set tRead = ($SYSTEM.Security.CheckUserPermission(..#USER, "%Development", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#NODEVUSER, "%Development", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOUSERUSER, tUserCode, "READ") '= 1)
    Set tRead = tRead && ..Grants(..#USER, ..#PLAIN, 1) && '..Grants(..#USER, ..#KEYED, 1) && '..Grants(..#USER, ..#TWO, 1) && '..Grants(..#USER, ..#OVER30, 3)
    Set tRead = tRead && ..Grants(..#VIEWUSER, ..#OVER30, 3) && '..Grants(..#VIEWUSER, ..#PLAIN, 1)
    If 'tRead Quit $$$ERROR($$$GeneralError, "the data browser principals' grants did not read back as declared")
    Quit $$$OK
}

/// <p>Whether <var>pUser</var> holds SELECT on <var>pObject</var>, a table (<var>pType</var> 1) or a
/// view (3), in <parameter>NAMESPACE</parameter>, as the instance answers it.</p>
ClassMethod Grants(pUser As %String, pObject As %String, pType As %Integer) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tHolds = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHolds = ($SYSTEM.SQL.Security.CheckPrivilege(pUser, pType, pObject, "s", ..#NAMESPACE) = 1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHolds = 0
    }
    Quit tHolds
}

/// <p>Delete the four principals and their roles; a failing status when any survives.</p>
ClassMethod RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLeft = ""
        For tUser = ..#USER, ..#VIEWUSER, ..#NODEVUSER, ..#NOUSERUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) Set tLeft = tLeft _ " user " _ tUser
            If ##class(Security.Roles).Exists(tUser _ "Role") Set tLeft = tLeft _ " role " _ tUser _ "Role"
        }
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "data browser principals survive:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>A data browser request for <var>pTable</var> (<code>Schema.Name</code>) with
/// <var>pExtra</var>'s members added, as <method>OcuPilot.Port.SqlPort.BrowseRequest</method> reads
/// it, or <code>""</code> when it refuses the body.</p>
ClassMethod Request(pTable As %String, pExtra As %DynamicObject = "") As %DynamicObject
{
    Set tBody = {}
    Do tBody.%Set("schema", $Piece(pTable, "."), "string")
    Do tBody.%Set("table", $Piece(pTable, ".", 2, *), "string")
    If $IsObject(pExtra) {
        Set tIterator = pExtra.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If pExtra.%GetTypeOf(tKey) = "null" {
                Do tBody.%Set(tKey, "", "null")
            } Else {
                Do tBody.%Set(tKey, tValue)
            }
        }
    }
    If '##class(OcuPilot.Port.SqlPort).BrowseRequest(tBody, .tRequest) Quit ""
    Quit tRequest
}

/// <p>Plan and run <var>pRequest</var> in <var>pNamespace</var> through <var>pPort</var>, answering the
/// port's answer, or its refusal as <code>{http, code, failedPair}</code>.</p>
ClassMethod Browse(pNamespace As %String, pRequest As %DynamicObject, pPort As %String = "OcuPilot.Port.SqlPort") As %DynamicObject
{
    Set tSC = $ClassMethod(pPort, "BrowsePlan", pNamespace, pRequest, .tPlan, .tHttp, .tFault)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(pPort, "BrowseRun", pNamespace, tPlan, .tAnswer, .tHttp, .tFault)
    If $$$ISOK(tSC) && $IsObject($Get(tAnswer)) Quit tAnswer
    Quit ..Refusal(.tHttp, .tFault)
}

/// <p>A refusal as <code>{http, code, failedPair}</code>.</p>
ClassMethod Refusal(ByRef pHttp, ByRef pFault) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("http", +$Get(pHttp), "number")
    Do tOut.%Set("code", $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: ""), "string")
    Do tOut.%Set("failedPair", $Select($IsObject($Get(pFault)) && $IsObject(pFault.%Get("detail")): pFault.%Get("detail").%Get("failedPair"), 1: ""), "string")
    Quit tOut
}

/// <p>An answer as one line for an assertion: a refusal's status, code and pair, or the outcome, the
/// columns' names, the key, the first column's cells, <code>total</code> and <code>more</code>.</p>
ClassMethod Line(pAnswer As %DynamicObject) As %String
{
    If '$IsObject($Get(pAnswer)) Quit "no answer"
    If pAnswer.%IsDefined("http") Quit pAnswer.http _ " " _ pAnswer.code _ " " _ pAnswer.failedPair
    Set tNames = ""
    If pAnswer.%GetTypeOf("columns") = "array" {
        Set tIterator = pAnswer.columns.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tColumn) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tColumn.name
        }
    }
    Set tFirst = ""
    If pAnswer.%GetTypeOf("rows") = "array" {
        Set tIterator = pAnswer.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tFirst = tFirst _ $Select(tIndex = 0: "", 1: ",") _ $Select(tRow.%GetTypeOf(0) = "null": "<null>", 1: tRow.%Get(0))
        }
    }
    Quit pAnswer.outcome _ " [" _ tNames _ "] key=" _ $Select(pAnswer.%GetTypeOf("key") = "array": pAnswer.key.%ToJSON(), 1: "") _ " rows=" _ tFirst _ " total=" _ $Select(pAnswer.%GetTypeOf("total") = "null": "null", 1: pAnswer.%Get("total")) _ " more=" _ pAnswer.%Get("more")
}

/// <p>Run <var>pLegs</var> -- JSON text of an array of <code>{op, namespace, request?, plan?}</code>,
/// <code>op</code> <code>browse</code> (<method>Browse</method> of <code>request</code>, which the
/// child reads through <method>OcuPilot.Port.SqlPort.BrowseRequest</method>) or <code>run</code>
/// (<method>OcuPilot.Port.SqlPort.BrowseRun</method> of a plan another account composed, its budget
/// restarted) -- as <var>pUsername</var> in a child process, and answer what it signalled, or an
/// object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUsername As %String, pLegs As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.SqlBrowseProbe).RunAs($Job, pUsername, pLegs)::10
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
/// of <var>pLegs</var>, and signal <var>pParent</var> <code>{username, legs: [answer]}</code>, each
/// answer a port answer or a refusal (<method>Browse</method>), or <code>{error}</code>.</p>
ClassMethod RunAs(pParent As %Integer, pUsername As %String, pLegs As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tLegs = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pLegs).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLeg) {
            If tLeg.%Get("op") = "run" {
                Set tPlan = tLeg.%Get("plan")
                Do tPlan.%Set("start", $ZHorolog, "number")
                Set tSC = ##class(OcuPilot.Port.SqlPort).BrowseRun(tLeg.%Get("namespace"), tPlan, .tAnswer, .tHttp, .tFault)
                Do tLegs.%Push($Select($$$ISOK(tSC) && $IsObject($Get(tAnswer)): tAnswer, 1: ..Refusal(.tHttp, .tFault)))
            } ElseIf ##class(OcuPilot.Port.SqlPort).BrowseRequest(tLeg.%Get("request"), .tRequest) {
                Do tLegs.%Push(..Browse(tLeg.%Get("namespace"), tRequest))
            } Else {
                Do tLegs.%Push({"http": 400, "code": "request", "failedPair": ""})
            }
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
