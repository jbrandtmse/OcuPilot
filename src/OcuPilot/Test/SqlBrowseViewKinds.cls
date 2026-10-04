/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s data browser on a view that lists a stream and two
/// binary columns (Story 19.7): the view's base-table lookup, a select of its listed columns, plans
/// and reads its page and its cells through <method>OcuPilot.Port.SqlPort.BrowseRun</method> as
/// a principal holding SELECT on the whole view and as one holding only
/// <code>SELECT(Name, Notes, Blob)</code> on it. Each is answered 404 on the view's base table.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a <code>USER</code> namespace.
/// It creates and removes schema <parameter>SCHEMA</parameter>'s table and view, data included, and two
/// principals, so it runs on a throwaway only: <method>OnBeforeAllTests</method> refuses unless
/// <parameter>ARMINGVARIABLE</parameter> reads 1.</p>
Class OcuPilot.Test.SqlBrowseViewKinds Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlBrowseProbe";

Parameter NAMESPACE = "USER";

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCHEMA = "OcuProbe197K";

Parameter BASE = "OcuProbe197K.Base";

Parameter MIXED = "OcuProbe197K.Mixed";

Parameter FULLUSER = "OcuProbe197KFull";

Parameter COLUSER = "OcuProbe197KCol";

/// <p>The principals' password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlBrowseViewKinds creates IRIS users and roles and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuProbe197" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..MakeAll()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveAll()
}

/// <p>Create the table, its three rows, the view and the two principals with their grants.</p>
Method MakeAll() As %Status
{
    Set tSC = ..RemoveAll()
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources($NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tUserCode, .tUserGlobals, .tUserMapped, .tUserResolved)
    If 'tResolved || 'tUserResolved || (tCode = "") || (tUserCode = "") Quit $$$ERROR($$$GeneralError, "the namespaces' code databases could not be resolved")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#FULLUSER, ..#COLUSER {
            Set tSC = ##class(Security.Roles).Create(tUser _ "Role", "OcuPilot test: view kinds principal role (throwaway)", tCode _ ":R,%Development:U," _ tUserCode _ ":RW", "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tUser _ "Role", ..PreparedPassword, "OcuPilot view kinds test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.SqlBrowseViewKinds")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = ..#NAMESPACE
        Set tDdl = $ListBuild("CREATE TABLE " _ ..#BASE _ " (Name VARCHAR(20), Num INTEGER, Notes LONGVARCHAR, Blob VARBINARY(20), Image LONGVARBINARY, Secret VARCHAR(20))", "CREATE VIEW " _ ..#MIXED _ " AS SELECT Name, Num, Notes, Blob, Image FROM " _ ..#BASE)
        If $$$ISOK(tSC) Set tSC = ..Exec(tDdl)
        If $$$ISOK(tSC) {
            For tN = 1:1:3 {
                Set tNotes = $Select(tN = 2: $Translate($Justify("", 1500), " ", "x"), 1: "note" _ tN)
                Set tResult = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO " _ ..#BASE _ " (Name, Num, Notes, Blob, Image, Secret) VALUES (?, ?, ?, ?, ?, ?)", "a" _ tN, tN, tNotes, $Char(0, 255, tN), $Char(1, 2), "s" _ tN)
                If tResult.%SQLCODE < 0 {
                    Set tSC = $$$ERROR($$$GeneralError, "view kinds row " _ tN _ " failed: SQLCODE " _ tResult.%SQLCODE)
                    Quit
                }
            }
        }
        Set tGrants = $ListBuild("GRANT SELECT ON " _ ..#MIXED _ " TO " _ ..#FULLUSER, "GRANT SELECT (Name, Notes, Blob) ON " _ ..#MIXED _ " TO " _ ..#COLUSER)
        If $$$ISOK(tSC) Set tSC = ..Exec(tGrants)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Run each statement of <var>pStatements</var> in the current namespace (<code>USER</code> holds no
/// OcuPilot class), stopping at the first that fails, named with its SQLCODE.</p>
ClassMethod Exec(pStatements As %List) As %Status
{
    For tI = 1:1:$ListLength(pStatements) {
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, $List(pStatements, tI))
        If tResult.%SQLCODE < 0 Return $$$ERROR($$$GeneralError, "view kinds statement failed: SQLCODE " _ tResult.%SQLCODE _ " " _ tResult.%Message)
    }
    Quit $$$OK
}

/// <p>Remove the view, the table and the principals; a failing status when any survives.</p>
Method RemoveAll() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(%SQL.Statement).%ExecDirect(, "DROP VIEW " _ ..#MIXED)
        Do ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE " _ ..#BASE _ " CASCADE")
        Do $System.OBJ.DeletePackage(..#SCHEMA, "-d")
        Set $NAMESPACE = "%SYS"
        Set tLeft = ""
        For tUser = ..#FULLUSER, ..#COLUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tLeft = tLeft _ " " _ tUser
        }
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "view kinds principals survive:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Legs for <method>OcuPilot.Test.SqlBrowseProbe.ProbeAs</method>: the view sorted by
/// <var>pSort</var> ascending, then the base table.</p>
Method Legs(pSort As %String) As %String
{
    Set tLegs = [
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197K", "table": "Mixed", "sort": {"column": (pSort), "direction": "asc"}}},
        {"op": "browse", "namespace": (..#NAMESPACE), "request": {"schema": "OcuProbe197K", "table": "Base"}}
    ].%ToJSON()
    Quit tLegs
}

/// <p>The view's plan names the view and its base table, so the self-protection check sees what the
/// page reads, though the view lists a stream and two binary columns.</p>
/// <p>Mutation (Rule 19): stop pushing a view's base tables in
/// <method>OcuPilot.Port.SqlPort.BrowsePlan</method> -- this goes red.</p>
Method TestTheViewPlanRecordsItsBaseTable()
{
    Set tRequest = $ClassMethod(..#PROBE, "Request", ..#MIXED)
    Set tSC = ##class(OcuPilot.Port.SqlPort).BrowsePlan(..#NAMESPACE, tRequest, .tPlan, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the view is planned")
    If $$$ISERR(tSC) Quit
    Set tNames = ""
    Set tIterator = tPlan.tables.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTable) {
        Set tNames = tNames _ "|" _ $ZConvert(tTable, "U")
    }
    Do $$$AssertTrue(tNames [ "|OCUPROBE197K.MIXED", "the view is named: " _ tNames)
    Do $$$AssertTrue(tNames [ "|OCUPROBE197K.BASE", "and so is its base table: " _ tNames)
}

/// <p>A full grant on the view reads its five columns with their kinds, the stream cut at 1,000
/// characters ending U+2026 and the binary as <code>0x</code> hex; the base table is 404.</p>
/// <p>Mutation (Rule 19): stop pushing a view's base tables in
/// <method>OcuPilot.Port.SqlPort.BrowsePlan</method> -- the plan test goes red; map the stream kind
/// to text in <method>OcuPilot.Port.SqlPort.KindOfType</method> -- the kinds leg goes red.</p>
Method TestAFullGrantOnAViewWithStreamAndBinaryColumns()
{
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", ..#FULLUSER, ..Legs("Num"))
    Do $$$AssertEquals($Select($IsObject(tProbe): tProbe.%Get("username"), 1: ""), ..#FULLUSER, "the probe ran as the principal: " _ $Select($IsObject(tProbe): tProbe.%ToJSON(), 1: ""))
    Set tAnswer = $Select($IsObject(tProbe) && (tProbe.%GetTypeOf("legs") = "array"): tProbe.legs.%Get(0), 1: "")
    If '$IsObject(tAnswer) || (tAnswer.%GetTypeOf("rows") '= "array") {
        Do $$$AssertTrue(0, "the page reads: " _ $ClassMethod(..#PROBE, "LegLine", tProbe, 0))
        Quit
    }
    Set tKinds = ""
    Set tIterator = tAnswer.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tKinds = tKinds _ $Select(tKinds = "": "", 1: ",") _ tColumn.name _ ":" _ tColumn.kind
    }
    Do $$$AssertEquals(tKinds, "Name:text,Num:number,Notes:stream,Blob:binary,Image:binary", "the five listed columns and their kinds")
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " " _ tAnswer.total, "3 3", "three rows and a count")
    Set tNotes = tAnswer.rows.%Get(1).%Get(2)
    Do $$$AssertEquals($Length(tNotes) _ " " _ $Ascii($Extract(tNotes, *)), "1000 8230", "a stream cell cut at 1,000 characters ending U+2026")
    Do $$$AssertEquals(tAnswer.rows.%Get(0).%Get(2), "note1", "a short stream cell whole")
    Do $$$AssertEquals(tAnswer.rows.%Get(0).%Get(3) _ " " _ tAnswer.rows.%Get(0).%Get(4), "0x00FF01 0x0102", "binary cells as hex")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 1), "404 EXPLORER.DATA.NOTFOUND ", "and the base table is 404")
}

/// <p>A column grant on the view lists and reads only the granted columns, stream and binary among
/// them, with no count and no -99; the base table is 404.</p>
/// <p>Mutation (Rule 19): prepare the lookup with a <code>SELECT *</code> in
/// <method>OcuPilot.Port.SqlPort.BrowsePlan</method> -- the principal is answered -99 and this goes
/// red.</p>
Method TestAColumnGrantOnAViewWithStreamAndBinaryColumns()
{
    Set tProbe = $ClassMethod(..#PROBE, "ProbeAs", ..#COLUSER, ..Legs("Name"))
    Set tAnswer = $Select($IsObject(tProbe) && (tProbe.%GetTypeOf("legs") = "array"): tProbe.legs.%Get(0), 1: "")
    If '$IsObject(tAnswer) || (tAnswer.%GetTypeOf("rows") '= "array") {
        Do $$$AssertTrue(0, "the page reads: " _ $ClassMethod(..#PROBE, "LegLine", tProbe, 0))
        Quit
    }
    Set tNames = ""
    Set tIterator = tAnswer.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tColumn.name _ ":" _ tColumn.kind
    }
    Do $$$AssertEquals(tNames, "Name:text,Notes:stream,Blob:binary", "only the granted columns")
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " " _ tAnswer.%GetTypeOf("total"), "3 null", "three rows and no count")
    Set tNotes = tAnswer.rows.%Get(1).%Get(1)
    Do $$$AssertEquals($Length(tNotes) _ " " _ $Ascii($Extract(tNotes, *)), "1000 8230", "the stream cell is cut")
    Do $$$AssertEquals(tAnswer.rows.%Get(0).%Get(0) _ " " _ tAnswer.rows.%Get(0).%Get(2), "a1 0x00FF01", "a text cell and a binary cell")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LegLine", tProbe, 1), "404 EXPLORER.DATA.NOTFOUND ", "and the base table is 404")
}

}
