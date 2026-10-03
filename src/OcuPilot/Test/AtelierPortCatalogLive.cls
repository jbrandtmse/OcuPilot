/// <p>Pins the SQL catalog live (AD-36, AD-61 rule 7): through the production port, and through the
/// read executor for the cap, on <class>OcuPilot.Test.ExplorerSqlProbe</class>'s objects in
/// <parameter>PROBENAMESPACE</parameter> -- the four lists with and without system items and one
/// schema's, a table's five tabs, a global temporary table listed and opened, its name resolved
/// without regard to case, an absent and an
/// ambiguous name refused, the cap reported -- and, as a purpose-built principal granted SELECT on
/// one probe table alone, the other absent from the tables and not found on every tab.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace, where each test
/// creates the probe objects and removes them after, failing if any is left. It creates a role and a
/// user and grants it SELECT on a probe table, so it runs on a throwaway container only, and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does not
/// arm it. The principal holds <code>%Development:USE</code> and READ on the install namespace's and
/// <code>USER</code>'s code databases; its password is generated for the run, and it and its role
/// are deleted in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.AtelierPortCatalogLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ExplorerSqlProbe";

Parameter PROBENAMESPACE = "USER";

/// <p>The principal granted SELECT on the visible probe table alone, and its role.</p>
Parameter PROBEUSER = "OcuProbe195User";

Parameter PROBEROLE = "OcuProbe195Role";

/// <p>Whether <method>OnBeforeAllTests</method> read back the principal's resources.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Refuse to run unless this instance is armed for throwaway principals, then create the principal
/// and read its resources back.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortCatalogLive creates and deletes an IRIS user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#PROBENAMESPACE, .tOther, .tOtherGlobals, .tOtherMapped, .tOtherResolved)
        If 'tResolved || 'tOtherResolved {
            Set tSC = $$$ERROR($$$GeneralError, "the namespaces' code databases could not be resolved")
            Quit
        }
        Set tPassword = "OcuProbe195" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tResources = "%Development:U," _ tHome _ ":R," _ tOther _ ":R"
        If ##class(Security.Roles).Exists(..#PROBEROLE, .tR, .tRS) {
            Set tModify("Resources") = tResources
            Set tModify("GrantedRoles") = ""
            Set tSC = ##class(Security.Roles).Modify(..#PROBEROLE, .tModify)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, "OcuPilot test: SQL catalog principal role (throwaway)", tResources, "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#PROBEUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#PROBEUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#PROBEUSER, ..#PROBEROLE, tPassword, "OcuPilot SQL catalog test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AtelierPortCatalogLive; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#PROBEUSER, "%Development", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PROBEUSER, tOther, "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PROBEUSER, "%All", "USE") '= 1)
        If '..PreparedSetupOk Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal's resources")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the principal and its role, and return a failing status if either survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#PROBEUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#PROBEUSER)
        If ##class(Security.Users).Exists(..#PROBEUSER, .tU2, .tUS2) Set tLeft = tLeft _ " user " _ ..#PROBEUSER
        If ##class(Security.Roles).Exists(..#PROBEROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#PROBEROLE)
        If ##class(Security.Roles).Exists(..#PROBEROLE, .tR2, .tRS2) Set tLeft = tLeft _ " role " _ ..#PROBEROLE
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortCatalogLive teardown left the instance changed:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#PROBENAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe objects are created in " _ ..#PROBENAMESPACE)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe object is removed")
    Quit $$$OK
}

/// <p>The production port's rows for <var>pEndpoint</var> in the probe namespace with the criteria
/// <var>pCriteria</var> (<code>name=value</code>, comma-separated) at cap <var>pMax</var>.</p>
ClassMethod Rows(pEndpoint As %String, pCriteria As %String, pMax As %Integer, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Kill tQuery
    Set tQuery("namespace") = ..#PROBENAMESPACE
    Set tQuery("maxRows") = pMax
    For tI = 1:1:$Length(pCriteria, ",") {
        Set tPair = $Piece(pCriteria, ",", tI)
        If tPair '= "" Set tQuery($Piece(tPair, "=", 1)) = $Piece(tPair, "=", 2, *)
    }
    Set pFault = ""
    Set tRows = ""
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke(pEndpoint, "LIST", .tQuery, "", .tRows, .pHttp, .pFault)
    Quit $Select($IsObject(tRows): tRows, 1: [])
}

/// <p><var>pField</var> of every row of <var>pRows</var>, comma-separated.</p>
ClassMethod Column(pRows As %DynamicArray, pField As %String) As %String
{
    Set tOut = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tIndex = 0: "", 1: ",") _ tRow.%Get(pField)
    }
    Quit tOut
}

/// <p>How many of <var>pRows</var>' <var>pField</var> values are a system item's: beginning with
/// <code>%</code> or naming <code>INFORMATION_SCHEMA</code>.</p>
ClassMethod SystemCount(pRows As %DynamicArray, pField As %String) As %Integer
{
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tValue = tRow.%Get(pField)
        If ($Extract(tValue) = "%") || ($Piece(tValue, ".", 1) = "INFORMATION_SCHEMA") Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Matrix (Lists, Schema), AC1: with system items left out, the schemas list the probe schema with
/// its tables, views and procedures, and no list carries a <code>%</code> or
/// <code>INFORMATION_SCHEMA</code> item; one schema's tables, views and procedures are the probe's
/// own.</p>
/// <p>Mutation (Rule 19): bind <code>system</code> as always <code>SYSTEM TABLE</code> in
/// <method>OcuPilot.Port.AtelierPort.CatalogRows</method> -&gt; the tables' system count goes
/// red.</p>
Method TestTheListsReadTheProbeObjectsWithoutSystemItems()
{
    Set tSchemas = ..Rows("Catalog.Schemas", "", 1000, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the schemas read")
    Set tProbe = ""
    Set tIterator = tSchemas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Schema = $Parameter(..#PROBE, "SCHEMA") Set tProbe = tRow.%ToJSON()
    }
    Do $$$AssertEquals(tProbe, "{""Schema"":""OcuProbe195"",""Tables"":true,""Views"":true,""Procedures"":true}", "the probe schema, with tables, views and procedures")
    For tCase = $ListBuild("Catalog.Schemas", "Schema"), $ListBuild("Catalog.Tables", "Table"), $ListBuild("Catalog.Views", "View"), $ListBuild("Catalog.Procedures", "Procedure") {
        Set tRows = ..Rows($List(tCase, 1), "system=no", 1000, .tHttp)
        Do $$$AssertTrue((tHttp = 200) && (tRows.%Size() > 0), $List(tCase, 1) _ " reads rows")
        Do $$$AssertEquals(..SystemCount(tRows, $List(tCase, 2)), 0, $List(tCase, 1) _ " carries no system item")
    }
    Set tSchema = "schema=" _ $Parameter(..#PROBE, "SCHEMA")
    Do $$$AssertEquals(..Column(..Rows("Catalog.Tables", tSchema, 100, .tHttp), "Table"), "OcuProbe195.A.B,OcuProbe195.Hidden,OcuProbe195.Visible", "the probe schema's tables, and no other's")
    Set tViews = ..Rows("Catalog.Views", tSchema, 100, .tHttp)
    Do $$$AssertEquals($Select(tViews.%Size() = 1: tViews.%Get(0).%ToJSON(), 1: tViews.%Size()), "{""View"":""OcuProbe195.VisibleNames"",""Schema"":""OcuProbe195"",""Name"":""VisibleNames"",""Class"":""OcuProbe195.VisibleNames"",""Owner"":""" _ $Username _ """,""Updatable"":true,""CheckOption"":""NONE""}", "its view, every declared field")
    Set tProcedures = ..Rows("Catalog.Procedures", tSchema, 100, .tHttp)
    Do $$$AssertEquals(..Column(tProcedures, "Procedure"), "OcuProbe195.Dotted_Extent,OcuProbe195.Echo,OcuProbe195.Hidden_Extent,OcuProbe195.Visible_Extent", "its procedure, beside the extent procedures its persistent classes project")
    Do $$$AssertEquals(..Column(tProcedures, "Type"), "PROCEDURE,FUNCTION,PROCEDURE,PROCEDURE", "the procedure created as a function reads as one")
    Do $$$AssertEquals(..Column(tProcedures, "Class") _ " " _ ..Column(tProcedures, "Method"), "OcuProbe195.Dotted,OcuProbe195.procEcho,OcuProbe195.Hidden,OcuProbe195.Visible Extent,Echo,Extent,Extent", "each naming the class and method that project it")
    Set tTables = ..Rows("Catalog.Tables", tSchema, 100, .tHttp)
    Do $$$AssertEquals($Select(tTables.%Size() = 3: tTables.%Get(2).%ToJSON(), 1: tTables.%Size()), "{""Table"":""OcuProbe195.Visible"",""Schema"":""OcuProbe195"",""Name"":""Visible"",""Class"":""OcuProbe195.Visible"",""Owner"":""" _ $Username _ """,""Sharded"":false,""Partitioned"":false}", "a table row's declared fields, its owner the account that created it")
}

/// <p>Matrix (System), AC1: with system items chosen, each list carries them as well.</p>
Method TestSystemItemsListWhenChosen()
{
    For tCase = $ListBuild("Catalog.Schemas", "Schema"), $ListBuild("Catalog.Tables", "Table"), $ListBuild("Catalog.Views", "View"), $ListBuild("Catalog.Procedures", "Procedure") {
        Set tRows = ..Rows($List(tCase, 1), "system=yes", 1000, .tHttp)
        Do $$$AssertTrue(..SystemCount(tRows, $List(tCase, 2)) > 0, $List(tCase, 1) _ " carries system items when they are chosen")
    }
    Do $$$AssertEquals(..Column(..Rows("Catalog.Tables", "system=yes,schema=%Dictionary", 1000, .tHttp), "Table") [ "%Dictionary.ClassDefinition", 1, "a system schema's tables read when chosen")
    Set tNone = ..Rows("Catalog.Tables", "system=no,schema=%Dictionary", 1000, .tHttp)
    Do $$$AssertEquals(tHttp _ " " _ tNone.%Size(), "200 0", "and none when they are not, in an answer")
}

/// <p>Matrix (Over the cap), AC1: through the read executor at a cap of two, the probe schema's three
/// tables read as two with the cut reported, and at three uncut.</p>
Method TestTheCapIsReportedThroughTheRead()
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
    Kill tCriteria
    Set tCriteria("schema") = $Parameter(..#PROBE, "SCHEMA")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.ExplorerSqlTables", 2, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the tables read")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.rows.%Size() _ " " _ tResult.truncated, "2 1", "exactly the cap in rows, and the cut reported")
    Do $$$AssertEquals(tResult.criteria.%ToJSON(), "{""system"":""no"",""schema"":""OcuProbe195""}", "with the criteria it applied")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.ExplorerSqlTables", 3, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(tResult.rows.%Size() _ " " _ tResult.truncated, "3 0", "and at a cap of three, all three uncut")
}

/// <p>Matrix (Table tabs), AC2: the visible probe table's information is one row naming its class,
/// read at a cap of one although its schema lists it last; its fields carry its four columns, its
/// maps and indices its index, its triggers its trigger with the code, and its constraints its
/// primary key, unique key and foreign key, each row's declared fields read from the vendor's
/// columns.</p>
/// <p>Mutation (Rule 19): bind the schema and table swapped for <code>Catalog.Fields</code> in
/// <method>OcuPilot.Port.AtelierPort.CatalogRows</method> -&gt; the fields assertion goes red.</p>
Method TestATableReadsItsFiveTabs()
{
    Set tTable = "table=" _ $Parameter(..#PROBE, "VISIBLE")
    Set tInfo = ..Rows("Catalog.Table", tTable, 1, .tHttp)
    Set tRow = $Select(tInfo.%Size() = 1: tInfo.%Get(0), 1: {})
    Do $$$AssertEquals(tHttp _ " " _ tInfo.%Size() _ " " _ (tRow.LastCompiled '= ""), "200 1 1", "Table info is the one row at a cap of one, with its compile time")
    Do tRow.%Remove("LastCompiled")
    Do $$$AssertEquals(tRow.%ToJSON(), "{""Name"":""Visible"",""Owner"":""" _ $Username _ """,""External"":false,""ReadOnly"":false,""Partitioned"":false,""Class"":""OcuProbe195.Visible"",""ExtentSize"":100000,""ExternalType"":""""}", "naming its class, owner and extent")
    Set tFieldRows = ..Rows("Catalog.Fields", tTable, 100, .tHttp)
    Set tFields = ..Column(tFieldRows, "Field")
    Do $$$AssertTrue(("," _ tFields _ ",") [ ",Id,Name,Code,Parent,", "Fields carries the table's columns in order: " _ tFields)
    Set tName = ""
    Set tIterator = tFieldRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Field = "Name" Set tName = tRow.%ToJSON()
    }
    Do $$$AssertEquals(tName, "{""Field"":""Name"",""Type"":""%Library.String"",""Column"":3,""Required"":false,""Unique"":true,""Collation"":""SQLUPPER"",""Hidden"":false,""MaxLength"":50,""MinValue"":"""",""MaxValue"":"""",""Stream"":false,""XdbcType"":""VARCHAR"",""ReferenceTo"":"""",""VersionColumn"":false,""Selectivity"":""1""}", "the Name column's declared fields")
    Set tIndex = ""
    Set tIterator = ..Rows("Catalog.Indices", tTable, 100, .tHttp).%GetIterator()
    While tIterator.%GetNext(.tIndex2, .tRow) {
        If tRow.Index = "VisibleCode" Set tIndex = tRow.Map _ "|" _ (tRow.Fields [ "Code") _ "|" _ tRow.Type _ "|" _ tRow.Inherited _ "|" _ ($Extract(tRow.Global) = "^") _ "|" _ tRow.Status
    }
    Do $$$AssertEquals(tIndex, "VisibleCode|1|Index|0|1|Selectable", "Maps/Indices carries its index's map, fields, type, global and status")
    Set tTriggers = ..Rows("Catalog.Triggers", tTable, 100, .tHttp)
    Do $$$AssertEquals(..Column(tTriggers, "Trigger") _ " " _ ..Column(tTriggers, "Event"), "VisibleStamp before insert", "Triggers carries its trigger")
    Do $$$AssertTrue((tTriggers.%Size() = 1) && (tTriggers.%Get(0).Code [ $Parameter(..#PROBE, "CODEMARK")) && ($Length(tTriggers.%Get(0).Code) > $Parameter(..#PROBE, "LONGLENGTH")), "with its whole code as a row field")
    Set tConstraints = ..Rows("Catalog.Constraints", tTable, 100, .tHttp)
    Set tTypes = ""
    Set tIterator = tConstraints.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Constraint = "VisibleParent" Set tTypes = tTypes _ " fk:" _ tRow.Type
        If tRow.Type = "PRIMARY KEY" Set tTypes = tTypes _ " pk"
        If (tRow.Type = "UNIQUE") && (tRow.Data = "(Name)") Set tTypes = tTypes _ " unique"
    }
    Do $$$AssertEquals(tTypes, " unique pk fk:FOREIGN KEY", "Constraints carries its unique key, primary key and foreign key")
}

/// <p>Matrix (Lists, Table tabs), AC1, AC2: a global temporary table in the probe schema lists among
/// its tables and opens to its information, as the classic page's table list shows it.</p>
/// <p>Mutation (Rule 19): drop <code>'GLOBAL TEMPORARY'</code> from
/// <parameter>OcuPilot.Port.AtelierPort.CATALOGTABLESQUERY</parameter>'s types and put
/// <code>TABLE_TYPE IN ('BASE TABLE', 'SYSTEM TABLE')</code> back in
/// <parameter>OcuPilot.Port.AtelierPort.CATALOGRESOLVEQUERY</parameter> -&gt; both assertions go
/// red.</p>
Method TestATemporaryTableListsAndOpens()
{
    Set tTemporary = $Parameter(..#PROBE, "SCHEMA") _ ".Scratch"
    Set tCode = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#PROBENAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "CREATE GLOBAL TEMPORARY TABLE " _ tTemporary _ " (Id INT PRIMARY KEY)")
        Set tCode = tResult.%SQLCODE
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCode = ex.DisplayString()
    }
    Do $$$AssertEquals(tCode, 0, "a global temporary table is created in the probe schema")
    Do $$$AssertEquals(..Column(..Rows("Catalog.Tables", "schema=" _ $Parameter(..#PROBE, "SCHEMA"), 100, .tHttp), "Table"), "OcuProbe195.A.B,OcuProbe195.Hidden,OcuProbe195.Scratch,OcuProbe195.Visible", "it lists among the schema's tables")
    Set tInfo = ..Rows("Catalog.Table", "table=" _ tTemporary, 100, .tHttp)
    Do $$$AssertEquals(tHttp _ " " _ tInfo.%Size() _ " " _ $Select(tInfo.%Size() = 1: tInfo.%Get(0).Name, 1: ""), "200 1 Scratch", "and opens to its information")
}

/// <p>Matrix (Case): the name typed in another case resolves to the same table.</p>
Method TestTheNameResolvesWithoutRegardToCase()
{
    Set tRows = ..Rows("Catalog.Table", "table=" _ $ZConvert($Parameter(..#PROBE, "VISIBLE"), "L"), 100, .tHttp)
    Do $$$AssertEquals(tHttp _ " " _ tRows.%Size() _ " " _ $Select(tRows.%Size() = 1: tRows.%Get(0).Name, 1: ""), "200 1 Visible", "ocuprobe195.visible reads OcuProbe195.Visible")
    Do $$$AssertEquals(..Column(..Rows("Catalog.Triggers", "table=" _ $ZConvert($Parameter(..#PROBE, "VISIBLE"), "U"), 100, .tHttp), "Trigger"), "VisibleStamp", "and so does its upper case, on another tab")
}

/// <p>Matrix (Absent, Ambiguous): a name no table answers is 404 <code>PORT.NOTFOUND</code>, and the
/// name two delimited tables answer is 400 <code>PORT.VALIDATION</code> with the port's reason.</p>
Method TestAbsentAndAmbiguousNamesAreRefused()
{
    Set tRows = ..Rows("Catalog.Fields", "table=OcuProbe195.Absent", 100, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "404 PORT.NOTFOUND", "an absent table is not found")
    Set tRows = ..Rows("Catalog.Fields", "table=" _ $Parameter(..#PROBE, "DOTTEDNAME"), 100, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "400 PORT.VALIDATION " _ ##class(OcuPilot.Port.AtelierPort).#REASONCATALOGAMBIGUOUS, "a name two tables answer is ambiguous")
}

/// <p>AC4: a principal granted SELECT on the visible probe table alone, its grants read back, lists
/// only that table in the probe schema, reads its tabs, and is answered not found on every tab of the
/// other.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AtelierPort.CatalogResolve</method> for
/// <code>Catalog.Triggers</code>, binding the caller's own split name -&gt; the hidden table's
/// Triggers leg answers its trigger and goes red.</p>
Method TestAPrincipalReadsOnlyTheTableItWasGranted()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal's resources")
    ; Read before the switch: the probe class is compiled in this namespace alone.
    Set tVisibleTable = $Parameter(..#PROBE, "VISIBLE")
    Set tHiddenTable = $Parameter(..#PROBE, "HIDDEN")
    Set tGranted = ""
    Set tVisible = ""
    Set tHidden = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#PROBENAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON " _ tVisibleTable _ " TO " _ ..#PROBEUSER)
        Set tGranted = tResult.%SQLCODE
        Set tVisible = $SYSTEM.SQL.Security.CheckPrivilege(..#PROBEUSER, 1, tVisibleTable, "s", ..#PROBENAMESPACE)
        Set tHidden = $SYSTEM.SQL.Security.CheckPrivilege(..#PROBEUSER, 1, tHiddenTable, "s", ..#PROBENAMESPACE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertStatusOK(ex.AsStatus(), "the grant ran")
        Quit
    }
    Do $$$AssertEquals(tGranted _ " " _ tVisible _ " " _ tHidden, "0 1 0", "SELECT is granted on the visible table and not on the hidden one, read back")
    Set tProbe = ..ProbeAs(..#PROBEUSER)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("username"), ..#PROBEUSER, "as the principal")
    Do $$$AssertEquals(tProbe.%Get("tables"), "200 OcuProbe195.Visible", "it lists the granted table alone")
    Set tVisibleLegs = tProbe.%Get($Parameter(..#PROBE, "VISIBLE"))
    Set tHiddenLegs = tProbe.%Get($Parameter(..#PROBE, "HIDDEN"))
    Do $$$AssertTrue($IsObject(tVisibleLegs) && $IsObject(tHiddenLegs), "both tables were read")
    If '$IsObject(tVisibleLegs) || '$IsObject(tHiddenLegs) Quit
    Do $$$AssertEquals(tVisibleLegs.%Get("Catalog.Table") _ "|" _ tVisibleLegs.%Get("Catalog.Triggers"), "200  1|200  1", "it reads the granted table's information and trigger")
    For tEndpoint = "Catalog.Table", "Catalog.Fields", "Catalog.Indices", "Catalog.Triggers", "Catalog.Constraints" {
        Do $$$AssertEquals(tHiddenLegs.%Get(tEndpoint), "404 PORT.NOTFOUND -1", tEndpoint _ " answers not found for the table it was not granted")
    }
}

/// <p>Run <method>OcuPilot.Test.ExplorerSqlProbe.RunAs</method> as <var>pUser</var> in a child
/// process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.ExplorerSqlProbe).RunAs($Job, pUser, ..#PROBENAMESPACE)::10
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

}
