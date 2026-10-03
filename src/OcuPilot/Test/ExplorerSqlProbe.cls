/// <p>Stories 19.5's and 19.14's probe SQL objects, created in a namespace by the tests that read the
/// SQL catalog and removed by <method>Remove</method>: schema <parameter>SCHEMA</parameter>'s tables,
/// views, procedures and query, the class that projects <parameter>DESCRIBED</parameter>, the two
/// classes and one package definition that project <parameter>DOTTEDNAME</parameter> twice, and every
/// other class of package <parameter>SCHEMA</parameter>, a table another probe or a test made there
/// among them.</p>
/// <ul>
/// <li><parameter>VISIBLE</parameter> has a primary key, a unique field, an index, a foreign key to
/// <parameter>HIDDEN</parameter> and a trigger whose code holds <parameter>CODEMARK</parameter> on a
/// line longer than <parameter>LONGLENGTH</parameter> characters.</li>
/// <li><parameter>HIDDEN</parameter> has a primary key and a trigger of its own.</li>
/// <li><parameter>VIEW</parameter> selects from <parameter>VISIBLE</parameter>, and
/// <parameter>PROCEDURE</parameter> echoes its argument.</li>
/// <li><parameter>PARTED</parameter> is partitioned by month and holds two rows in two months.</li>
/// <li><parameter>LONGVIEW</parameter>'s text carries <parameter>LONGVIEWMARK</parameter> and runs
/// over <parameter>LONGLENGTH</parameter> characters, and <parameter>HIDDENVIEW</parameter> selects
/// from <parameter>HIDDEN</parameter>.</li>
/// <li><parameter>DESCRIBED</parameter> is a class method projected as a function, whose HTML
/// description carries <parameter>DESCRIPTIONMARK</parameter> and runs over
/// <parameter>LONGLENGTH</parameter> characters.</li>
/// <li><parameter>QUERY</parameter> is a query procedure over <parameter>VISIBLE</parameter>, its
/// name a reserved word and so delimited.</li>
/// <li>Four statements are run: two on <parameter>VISIBLE</parameter>, whose kept literals are
/// <parameter>LITERAL</parameter> and <parameter>LONGLITERAL</parameter> followed by
/// <parameter>LONGLENGTH</parameter> characters, one on <parameter>VIEW</parameter> whose kept literal
/// is <parameter>VIEWLITERAL</parameter>, and one selecting from <parameter>QUERY</parameter>. Their
/// statement-index rows outlive <method>Remove</method>, which the instance keeps.</li>
/// <li>Two tables answer <parameter>DOTTEDNAME</parameter> as <code>Schema.Table</code>: table
/// <code>A.B</code> in schema <parameter>SCHEMA</parameter> and table <code>B</code> in schema
/// <code>OcuProbe195.A</code>. SQL refuses a dot in a delimited name, so each is a class whose SQL
/// name holds one; its compile fails on its own extent query, as expected, after its table is
/// projected.</li>
/// <li>Two views answer <parameter>DOTTEDVIEW</parameter> and two procedures answer
/// <parameter>DOTTEDPROCEDURE</parameter> the same way, each pair projected by
/// <parameter>DOTTEDROUTINECLASSES</parameter> in schema <parameter>SCHEMA</parameter> and in the
/// dotted schema.</li>
/// </ul>
/// <p><method>RunAs</method> and <method>RunTabsAs</method> are the child processes a test starts to
/// read the catalog through the production port as a real principal.</p>
Class OcuPilot.Test.ExplorerSqlProbe Extends %RegisteredObject
{

Parameter SCHEMA = "OcuProbe195";

Parameter VISIBLE = "OcuProbe195.Visible";

Parameter HIDDEN = "OcuProbe195.Hidden";

Parameter VIEW = "OcuProbe195.VisibleNames";

Parameter PROCEDURE = "OcuProbe195.Echo";

/// <p>Story 19.14's partitioned table, views, function and query procedure, and the marks their text
/// carries.</p>
Parameter PARTED = "OcuProbe195.Parted";

Parameter LONGVIEW = "OcuProbe195.LongView";

Parameter HIDDENVIEW = "OcuProbe195.HiddenNames";

Parameter DESCRIBEDCLASS = "OcuProbe195.Described";

Parameter DESCRIBED = "OcuProbe195.Described_Stamp";

Parameter QUERY = "OcuProbe195.Names";

Parameter LONGVIEWMARK = "OcuProbe195View";

Parameter DESCRIPTIONMARK = "OcuProbe195Description";

/// <p>The literals the probe statements keep in their text.</p>
Parameter LITERAL = "OcuProbe195Literal";

Parameter VIEWLITERAL = "OcuProbe195ViewLiteral";

Parameter LONGLITERAL = "OcuProbe195LongLiteral";

/// <p>The name both dotted tables answer, the classes that project them, and the package definition
/// that gives the second its dotted schema.</p>
Parameter DOTTEDNAME = "OcuProbe195.A.B";

Parameter DOTTEDCLASSES = "OcuProbe195.Dotted,OcuProbe195.A.B";

Parameter DOTTEDPACKAGE = "OcuProbe195.A";

/// <p>The name both dotted views answer, the name both dotted procedures answer, and the classes that
/// project them: a view and a class method in schema <parameter>SCHEMA</parameter>, and the same in the
/// dotted schema.</p>
Parameter DOTTEDVIEW = "OcuProbe195.A.V";

Parameter DOTTEDPROCEDURE = "OcuProbe195.A.Q";

Parameter DOTTEDROUTINECLASSES = "OcuProbe195.DottedView,OcuProbe195.A.V,OcuProbe195.DottedRoutine,OcuProbe195.A.Routine";

/// <p>The text <parameter>VISIBLE</parameter>'s trigger code carries, and how many characters its long
/// comment line holds after it.</p>
Parameter CODEMARK = "OcuProbe195Code";

Parameter LONGLENGTH As INTEGER = 1500;

/// <p>Create every probe object in <var>pNamespace</var>, failing unless both dotted tables are
/// listed.</p>
ClassMethod Make(pNamespace As %String) As %Status
{
    Set tSC = ..Remove(pNamespace)
    If $$$ISERR(tSC) Quit tSC
    Set tLine = " ; " _ ..#CODEMARK _ " " _ $Translate($Justify("", ..#LONGLENGTH), " ", "x")
    Set tLong = $Translate($Justify("", ..#LONGLENGTH), " ", "v")
    Set tStatements = $ListBuild(
        "CREATE TABLE " _ ..#HIDDEN _ " (Id INT PRIMARY KEY, Label VARCHAR(40))",
        "CREATE TABLE " _ ..#VISIBLE _ " (Id INT PRIMARY KEY, Name VARCHAR(50) UNIQUE, Code VARCHAR(20), Parent INT, CONSTRAINT VisibleParent FOREIGN KEY (Parent) REFERENCES " _ ..#HIDDEN _ " (Id))",
        "CREATE INDEX VisibleCode ON " _ ..#VISIBLE _ " (Code)",
        "CREATE TRIGGER VisibleStamp BEFORE INSERT ON " _ ..#VISIBLE _ " LANGUAGE OBJECTSCRIPT {" _ $Char(10) _ tLine _ $Char(10) _ " Set {Code} = ""probe""" _ $Char(10) _ "}",
        "CREATE TRIGGER HiddenStamp BEFORE INSERT ON " _ ..#HIDDEN _ " LANGUAGE OBJECTSCRIPT { Set {Label} = ""hidden"" }",
        "CREATE VIEW " _ ..#VIEW _ " AS SELECT Id, Name FROM " _ ..#VISIBLE,
        "CREATE PROCEDURE " _ ..#PROCEDURE _ "(IN pValue INT) RETURNS INT LANGUAGE OBJECTSCRIPT { Quit pValue }",
        "CREATE TABLE " _ ..#PARTED _ " (Id INT PRIMARY KEY, D DATE, Label VARCHAR(20)) PARTITION BY RANGE (D) INTERVAL 1 MONTHS",
        "INSERT INTO " _ ..#PARTED _ " (Id, D, Label) VALUES (1, {d '2026-01-15'}, 'January')",
        "INSERT INTO " _ ..#PARTED _ " (Id, D, Label) VALUES (2, {d '2026-03-15'}, 'March')",
        "CREATE VIEW " _ ..#LONGVIEW _ " AS SELECT Id, Name FROM " _ ..#VISIBLE _ " WHERE Name <> '" _ ..#LONGVIEWMARK _ tLong _ "'",
        "CREATE VIEW " _ ..#HIDDENVIEW _ " AS SELECT Id, Label FROM " _ ..#HIDDEN,
        "CREATE QUERY " _ ..QueryName() _ "() PROCEDURE RESULTS (Id INT, Name VARCHAR(50)) LANGUAGE SQL BEGIN SELECT Id, Name FROM " _ ..#VISIBLE _ " ; END",
        "SELECT Name FROM " _ ..#VISIBLE _ " WHERE Code = (('" _ ..#LITERAL _ "'))",
        "SELECT Name FROM " _ ..#VISIBLE _ " WHERE Code <> (('" _ ..#LONGLITERAL _ tLong _ "'))",
        "SELECT Name FROM " _ ..#VIEW _ " WHERE Name = (('" _ ..#VIEWLITERAL _ "'))",
        "SELECT * FROM " _ ..QueryName() _ "()"
    )
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:$ListLength(tStatements) {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, $List(tStatements, tI))
            If tResult.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "probe statement " _ tI _ " failed: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
                Quit
            }
        }
        If $$$ISOK(tSC) Set tSC = ..MakeDescribed()
        If $$$ISOK(tSC) Set tSC = ..MakeDotted()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><parameter>QUERY</parameter> as a statement names it: delimited, since its name is a reserved
/// word.</p>
ClassMethod QueryName() As %String
{
    Quit $Piece(..#QUERY, ".", 1) _ ".""" _ $Piece(..#QUERY, ".", 2) _ """"
}

/// <p>Create and compile <parameter>DESCRIBEDCLASS</parameter> in the current namespace: one class
/// method projected as <parameter>DESCRIBED</parameter>, whose two-paragraph HTML description carries
/// a tag, an entity and <parameter>DESCRIPTIONMARK</parameter> followed by
/// <parameter>LONGLENGTH</parameter> characters.</p>
ClassMethod MakeDescribed() As %Status [ Private ]
{
    Set tCRLF = $Char(13, 10)
    Set tText = "Class " _ ..#DESCRIBEDCLASS _ " Extends %RegisteredObject" _ tCRLF _ "{" _ tCRLF _ tCRLF
    Set tText = tText _ "/// <p>" _ ..#DESCRIPTIONMARK _ " <b>tagged</b> &amp; " _ $Translate($Justify("", ..#LONGLENGTH), " ", "d") _ "</p>" _ tCRLF
    Set tText = tText _ "/// <p>Second paragraph.</p>" _ tCRLF
    Set tText = tText _ "ClassMethod Stamp(pValue As %Integer) As %Integer [ SqlProc ]" _ tCRLF _ "{" _ tCRLF _ " Quit pValue" _ tCRLF _ "}" _ tCRLF _ tCRLF _ "}" _ tCRLF
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString($NAMESPACE, ..#DESCRIBEDCLASS, tText)
    If $$$ISERR(tSC) Quit tSC
    Quit $System.OBJ.Compile(..#DESCRIBEDCLASS, "ck-d")
}

/// <p>Project <parameter>DOTTEDNAME</parameter> twice in the current namespace and confirm both rows
/// in the information schema.</p>
ClassMethod MakeDotted() As %Status [ Private ]
{
    Set tPackage = ##class(%Dictionary.PackageDefinition).%New(..#DOTTEDPACKAGE)
    Set tPackage.SQLName = ..#DOTTEDPACKAGE
    Set tSC = tPackage.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tCRLF = $Char(13, 10)
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString($NAMESPACE, $Piece(..#DOTTEDCLASSES, ",", 1), "Class " _ $Piece(..#DOTTEDCLASSES, ",", 1) _ " Extends %Persistent [ SqlTableName = ""A.B"" ]" _ tCRLF _ "{" _ tCRLF _ "Property X As %Integer;" _ tCRLF _ "}" _ tCRLF)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString($NAMESPACE, $Piece(..#DOTTEDCLASSES, ",", 2), "Class " _ $Piece(..#DOTTEDCLASSES, ",", 2) _ " Extends %Persistent" _ tCRLF _ "{" _ tCRLF _ "Property X As %Integer;" _ tCRLF _ "}" _ tCRLF)
    If $$$ISERR(tSC) Quit tSC
    ; The compile reports the extent query's refusal of the dotted name; the projection is what is
    ; wanted, and it is read back below.
    Do $System.OBJ.Compile(..#DOTTEDCLASSES, "ck-d")
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA || '.' || TABLE_NAME = ?", ..#DOTTEDNAME)
    Set tCount = $Select(tResult.%Next(): tResult.%GetData(1), 1: 0)
    If tCount '= 2 Quit $$$ERROR($$$GeneralError, ..#DOTTEDNAME _ " is listed " _ tCount _ " times, not twice")
    Quit ..MakeDottedRoutines()
}

/// <p>Project <parameter>DOTTEDVIEW</parameter> twice and <parameter>DOTTEDPROCEDURE</parameter> twice
/// in the current namespace, in <parameter>DOTTEDPACKAGE</parameter>'s schema and in schema
/// <parameter>SCHEMA</parameter>, and confirm each pair in the information schema.</p>
ClassMethod MakeDottedRoutines() As %Status [ Private ]
{
    Set tCRLF = $Char(13, 10)
    Set tQuery = " [ ClassType = view, DdlAllowed{name}, ViewQuery = { SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA } ]" _ tCRLF _ "{" _ tCRLF _ "}" _ tCRLF
    Set tMethod = "{" _ tCRLF _ "ClassMethod Q() As %Integer [ SqlName = {name}, SqlProc ]" _ tCRLF _ "{" _ tCRLF _ " Quit 1" _ tCRLF _ "}" _ tCRLF _ "}" _ tCRLF
    Set tView = $Piece(..#DOTTEDVIEW, ".", *)
    Set tProcedure = $Piece(..#DOTTEDPROCEDURE, ".", *)
    For tI = 1:1:4 {
        Set tClass = $Piece(..#DOTTEDROUTINECLASSES, ",", tI)
        If tI = 1 Set tText = "Class " _ tClass _ $Replace(tQuery, "{name}", ", SqlTableName = ""A." _ tView _ """")
        If tI = 2 Set tText = "Class " _ tClass _ $Replace(tQuery, "{name}", "")
        If tI = 3 Set tText = "Class " _ tClass _ " Extends %RegisteredObject" _ tCRLF _ $Replace(tMethod, "{name}", """A." _ tProcedure _ """")
        If tI = 4 Set tText = "Class " _ tClass _ " Extends %RegisteredObject" _ tCRLF _ $Replace(tMethod, "{name}", tProcedure)
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString($NAMESPACE, tClass, tText)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $System.OBJ.Compile(..#DOTTEDROUTINECLASSES, "ck-d")
    If $$$ISERR(tSC) Quit tSC
    For tPair = $ListBuild("SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA || '.' || TABLE_NAME = ?", ..#DOTTEDVIEW), $ListBuild("SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA || '.' || ROUTINE_NAME = ?", ..#DOTTEDPROCEDURE) {
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, $List(tPair, 1), $List(tPair, 2))
        Set tCount = $Select(tResult.%Next(): tResult.%GetData(1), 1: 0)
        If tCount '= 2 Set tSC = $$$ERROR($$$GeneralError, $List(tPair, 2) _ " is listed " _ tCount _ " times, not twice")
    }
    Quit tSC
}

/// <p>Remove every probe object from <var>pNamespace</var>; a failing status when any table, view,
/// procedure or class of schema <parameter>SCHEMA</parameter> survives.</p>
ClassMethod Remove(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do $System.OBJ.Delete(..#DOTTEDROUTINECLASSES, "-d")
        For tDrop = "DROP VIEW " _ ..#VIEW, "DROP VIEW " _ ..#LONGVIEW, "DROP VIEW " _ ..#HIDDENVIEW, "DROP QUERY " _ ..QueryName(), "DROP PROCEDURE " _ ..#PROCEDURE, "DROP TABLE " _ ..#PARTED, "DROP TABLE " _ ..#VISIBLE, "DROP TABLE " _ ..#HIDDEN {
            Do ##class(%SQL.Statement).%ExecDirect(, tDrop)
        }
        Do $System.OBJ.Delete(..#DOTTEDCLASSES _ "," _ ..#DESCRIBEDCLASS, "-d")
        If ##class(%Dictionary.PackageDefinition).%ExistsId(..#DOTTEDPACKAGE) Do ##class(%Dictionary.PackageDefinition).%DeleteId(..#DOTTEDPACKAGE)
        Do $System.OBJ.DeletePackage(..#SCHEMA, "-d")
        Set tLeft = ""
        For tQuery = "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", "SELECT TABLE_SCHEMA || '.' || TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA %STARTSWITH ?", "SELECT ROUTINE_SCHEMA || '.' || ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA %STARTSWITH ?" {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, tQuery, ..#SCHEMA _ $Select(tQuery [ "ClassDefinition": ".", 1: ""))
            While tResult.%Next() {
                Set tLeft = tLeft _ " " _ tResult.%GetData(1)
            }
        }
        If ##class(%Dictionary.PackageDefinition).%ExistsId(..#DOTTEDPACKAGE) Set tLeft = tLeft _ " package " _ ..#DOTTEDPACKAGE
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "probe SQL objects survive in " _ pNamespace _ ":" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The child process a test starts: log in as <var>pUsername</var>, read through the production
/// port in <var>pNamespace</var> the tables of schema <parameter>SCHEMA</parameter> and every tab of
/// <parameter>VISIBLE</parameter> and <parameter>HIDDEN</parameter>, and signal process
/// <var>pParent</var> <code>{username, tables, &lt;table&gt;: {&lt;endpoint&gt;: "http code rows"}}</code>,
/// or <code>{error}</code>.</p>
ClassMethod RunAs(pParent As %Integer, pUsername As %String, pNamespace As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Kill tQuery
        Set tQuery("namespace") = pNamespace
        Set tQuery("schema") = ..#SCHEMA
        Set tFault = ""
        Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Catalog.Tables", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Set tNames = ""
        If $IsObject(tRows) {
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Table
            }
        }
        Do tOut.%Set("tables", tHttp _ " " _ tNames)
        For tTable = ..#VISIBLE, ..#HIDDEN {
            Set tLegs = {}
            For tEndpoint = "Catalog.Table", "Catalog.Fields", "Catalog.Indices", "Catalog.Triggers", "Catalog.Constraints" {
                Kill tQuery
                Set tQuery("namespace") = pNamespace
                Set tQuery("table") = tTable
                Set tFault = ""
                Set tRows = ""
                Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
                Do tLegs.%Set(tEndpoint, tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ " " _ $Select($IsObject(tRows): tRows.%Size(), 1: -1))
            }
            Do tOut.%Set(tTable, tLegs)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>The child process Story 19.14's test starts: log in as <var>pUsername</var>, read through the
/// production port in <var>pNamespace</var> every tab of views <parameter>VIEW</parameter> and
/// <parameter>HIDDENVIEW</parameter> and of procedures <parameter>QUERY</parameter> and
/// <parameter>PROCEDURE</parameter>, and signal process <var>pParent</var>
/// <code>{username, &lt;object&gt;: {&lt;endpoint&gt;: "http code rows"}}</code>, or
/// <code>{error}</code>.</p>
ClassMethod RunTabsAs(pParent As %Integer, pUsername As %String, pNamespace As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tViews = "Catalog.View,Catalog.ViewFields,Catalog.ViewStatements"
        Set tProcedures = "Catalog.Procedure,Catalog.ProcedureStatements"
        For tCase = $ListBuild("view", ..#VIEW, tViews), $ListBuild("view", ..#HIDDENVIEW, tViews), $ListBuild("procedure", ..#QUERY, tProcedures), $ListBuild("procedure", ..#PROCEDURE, tProcedures) {
            Set tLegs = {}
            For tI = 1:1:$Length($List(tCase, 3), ",") {
                Set tEndpoint = $Piece($List(tCase, 3), ",", tI)
                Kill tQuery
                Set tQuery("namespace") = pNamespace
                Set tQuery($List(tCase, 1)) = $List(tCase, 2)
                Set tFault = ""
                Set tRows = ""
                Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
                Do tLegs.%Set(tEndpoint, tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ " " _ $Select($IsObject(tRows): tRows.%Size(), 1: -1))
            }
            Do tOut.%Set($List(tCase, 2), tLegs)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
