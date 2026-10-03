/// <p>Story 19.5's probe SQL objects, created in a namespace by the tests that read the SQL catalog
/// and removed by <method>Remove</method>: schema <parameter>SCHEMA</parameter>'s tables, view and
/// procedure, the two classes and one package definition that project <parameter>DOTTEDNAME</parameter>
/// twice, and every other class of package <parameter>SCHEMA</parameter>, a table another probe or a
/// test made there among them.</p>
/// <ul>
/// <li><parameter>VISIBLE</parameter> has a primary key, a unique field, an index, a foreign key to
/// <parameter>HIDDEN</parameter> and a trigger whose code holds <parameter>CODEMARK</parameter> on a
/// line longer than <parameter>LONGLENGTH</parameter> characters.</li>
/// <li><parameter>HIDDEN</parameter> has a primary key and a trigger of its own.</li>
/// <li><parameter>VIEW</parameter> selects from <parameter>VISIBLE</parameter>, and
/// <parameter>PROCEDURE</parameter> echoes its argument.</li>
/// <li>Two tables answer <parameter>DOTTEDNAME</parameter> as <code>Schema.Table</code>: table
/// <code>A.B</code> in schema <parameter>SCHEMA</parameter> and table <code>B</code> in schema
/// <code>OcuProbe195.A</code>. SQL refuses a dot in a delimited name, so each is a class whose SQL
/// name holds one; its compile fails on its own extent query, as expected, after its table is
/// projected.</li>
/// </ul>
/// <p><method>RunAs</method> is the child process a test starts to read the catalog through the
/// production port as a real principal.</p>
Class OcuPilot.Test.ExplorerSqlProbe Extends %RegisteredObject
{

Parameter SCHEMA = "OcuProbe195";

Parameter VISIBLE = "OcuProbe195.Visible";

Parameter HIDDEN = "OcuProbe195.Hidden";

Parameter VIEW = "OcuProbe195.VisibleNames";

Parameter PROCEDURE = "OcuProbe195.Echo";

/// <p>The name both dotted tables answer, the classes that project them, and the package definition
/// that gives the second its dotted schema.</p>
Parameter DOTTEDNAME = "OcuProbe195.A.B";

Parameter DOTTEDCLASSES = "OcuProbe195.Dotted,OcuProbe195.A.B";

Parameter DOTTEDPACKAGE = "OcuProbe195.A";

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
    Set tStatements = $ListBuild(
        "CREATE TABLE " _ ..#HIDDEN _ " (Id INT PRIMARY KEY, Label VARCHAR(40))",
        "CREATE TABLE " _ ..#VISIBLE _ " (Id INT PRIMARY KEY, Name VARCHAR(50) UNIQUE, Code VARCHAR(20), Parent INT, CONSTRAINT VisibleParent FOREIGN KEY (Parent) REFERENCES " _ ..#HIDDEN _ " (Id))",
        "CREATE INDEX VisibleCode ON " _ ..#VISIBLE _ " (Code)",
        "CREATE TRIGGER VisibleStamp BEFORE INSERT ON " _ ..#VISIBLE _ " LANGUAGE OBJECTSCRIPT {" _ $Char(10) _ tLine _ $Char(10) _ " Set {Code} = ""probe""" _ $Char(10) _ "}",
        "CREATE TRIGGER HiddenStamp BEFORE INSERT ON " _ ..#HIDDEN _ " LANGUAGE OBJECTSCRIPT { Set {Label} = ""hidden"" }",
        "CREATE VIEW " _ ..#VIEW _ " AS SELECT Id, Name FROM " _ ..#VISIBLE,
        "CREATE PROCEDURE " _ ..#PROCEDURE _ "(IN pValue INT) RETURNS INT LANGUAGE OBJECTSCRIPT { Quit pValue }"
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
        If $$$ISOK(tSC) Set tSC = ..MakeDotted()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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
    Quit $$$OK
}

/// <p>Remove every probe object from <var>pNamespace</var>; a failing status when any table, view,
/// procedure or class of schema <parameter>SCHEMA</parameter> survives.</p>
ClassMethod Remove(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        For tDrop = "DROP VIEW " _ ..#VIEW, "DROP PROCEDURE " _ ..#PROCEDURE, "DROP TABLE " _ ..#VISIBLE, "DROP TABLE " _ ..#HIDDEN {
            Do ##class(%SQL.Statement).%ExecDirect(, tDrop)
        }
        Do $System.OBJ.Delete(..#DOTTEDCLASSES, "-d")
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

}
