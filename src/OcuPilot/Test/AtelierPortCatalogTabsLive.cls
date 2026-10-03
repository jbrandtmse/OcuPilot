/// <p>Pins the SQL catalog's remaining tabs live (AD-36, AD-61 rules 3 and 7): through the production
/// port, and through the read executor for a long text, on <class>OcuPilot.Test.ExplorerSqlProbe</class>'s
/// objects in <parameter>PROBENAMESPACE</parameter> -- a partitioned table's partitions and partition
/// mappings, a plain table's none, a table's cached queries and SQL statements with the probe's kept
/// literal, a view's information, fields and statements, a query procedure's information and
/// statements and a function's information, names resolved without regard to case, absent and
/// ambiguous names refused, a long view text and description read whole and a long statement's text
/// cut and marked -- and, as a purpose-built principal granted
/// SELECT on one probe view and EXECUTE on one probe procedure, the ungranted view's and procedure's
/// tabs not found.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace, where each test
/// creates the probe objects and removes them after, failing if any is left. It creates a role and a
/// user and grants it privileges on probe objects, so it runs on a throwaway container only, and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does not
/// arm it. The principal holds <code>%Development:USE</code> and READ on the install namespace's and
/// <code>USER</code>'s code databases; its password is generated for the run, and it and its role
/// are deleted in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.AtelierPortCatalogTabsLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ExplorerSqlProbe";

Parameter PROBENAMESPACE = "USER";

/// <p>The principal granted SELECT on the visible probe table and view and EXECUTE on the query
/// procedure, and its role.</p>
Parameter PROBEUSER = "OcuProbe1914User";

Parameter PROBEROLE = "OcuProbe1914Role";

/// <p>A statement row's fields, which never include a user name, client, address, application or
/// call stack.</p>
Parameter STATEMENTFIELDS = "Statement,PlanState,NewPlan,Executions,TotalTime,AverageTime,StdDevTime,RowCount,Commands,FirstSeen,Location";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortCatalogTabsLive creates and deletes an IRIS user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
        Set tPassword = "OcuProbe1914" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tResources = "%Development:U," _ tHome _ ":R," _ tOther _ ":R"
        If ##class(Security.Roles).Exists(..#PROBEROLE, .tR, .tRS) {
            Set tModify("Resources") = tResources
            Set tModify("GrantedRoles") = ""
            Set tSC = ##class(Security.Roles).Modify(..#PROBEROLE, .tModify)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, "OcuPilot test: SQL catalog tabs principal role (throwaway)", tResources, "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#PROBEUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#PROBEUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#PROBEUSER, ..#PROBEROLE, tPassword, "OcuPilot SQL catalog tabs test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AtelierPortCatalogTabsLive; deleted in OnAfterAllTests")
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
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AtelierPortCatalogTabsLive teardown left the instance changed:" _ tLeft)
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

/// <p>The production port's rows for <var>pEndpoint</var> in the probe namespace with criterion
/// <var>pKey</var> set to <var>pValue</var>.</p>
ClassMethod Rows(pEndpoint As %String, pKey As %String, pValue As %String, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Quit ##class(OcuPilot.Test.AtelierPortCatalogLive).Rows(pEndpoint, pKey _ "=" _ pValue, 100, .pHttp, .pFault)
}

/// <p>The first row of <var>pRows</var> whose <var>pField</var> holds <var>pText</var>, or
/// <code>""</code>.</p>
ClassMethod RowHolding(pRows As %DynamicArray, pField As %String, pText As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If ("" _ tRow.%Get(pField)) [ pText {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p><var>pRow</var>'s keys, comma-separated in order.</p>
ClassMethod Keys(pRow As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

/// <p>Matrix (Table tabs), AC1, AC5: the partitioned probe table reads its partitions, one per
/// month and level as the classic query answers them, and no partition mapping, none being
/// configured; the visible table's cached queries and SQL statements each carry the probe's kept
/// literal, and a statement row carries exactly its declared fields.</p>
/// <p>Mutation (Rule 19): bind <code>Catalog.CachedQueries</code>' schema and name swapped in
/// <method>OcuPilot.Port.AtelierPort.CatalogRows</method> -&gt; the cached query assertion goes
/// red.</p>
Method TestTheTableTabsReadTheProbeTables()
{
    Set tParted = $Parameter(..#PROBE, "PARTED")
    Set tVisible = $Parameter(..#PROBE, "VISIBLE")
    Set tLiteral = $Parameter(..#PROBE, "LITERAL")
    Set tPartitions = ..Rows("Catalog.Partitions", "table", tParted, .tHttp)
    Set tIds = ##class(OcuPilot.Test.AtelierPortCatalogLive).Column(tPartitions, "Partition")
    Do $$$AssertEquals(tHttp _ " " _ tIds, "200 202601010000,202601010000||1,202603010000,202603010000||1", "Partitions reads each month's partition and its level")
    Do $$$AssertEquals($Select(tPartitions.%Size() > 0: ..Keys(tPartitions.%Get(0)) _ " " _ tPartitions.%Get(0).Rows _ " " _ tPartitions.%Get(0).Location, 1: ""), "Partition,Buckets,Rows,EstimatedSize,Location 1 " _ ..#PROBENAMESPACE, "each with its declared fields, one row in the namespace's database")
    Set tMappings = ..Rows("Catalog.PartitionMappings", "table", tParted, .tHttp)
    Do $$$AssertEquals(tHttp _ " " _ tMappings.%Size(), "200 0", "Partition mappings answers none, none being configured")
    Set tCached = ..RowHolding(..Rows("Catalog.CachedQueries", "table", tVisible, .tHttp), "Query", tLiteral)
    Do $$$AssertEquals(tHttp _ " " _ $IsObject(tCached), "200 1", "Cached queries carries the probe statement's cached query, its literal kept")
    If $IsObject(tCached) Do $$$AssertEquals(..Keys(tCached) _ " " _ tCached.Source _ " " _ ($Extract(tCached.CachedQuery, 1, 6) = "%sqlcq"), "CachedQuery,Query,Created,Source,QueryType,Features 0 1", "with its declared fields")
    Set tStatements = ..Rows("Catalog.TableStatements", "table", tVisible, .tHttp)
    Set tStatement = ..RowHolding(tStatements, "Statement", tLiteral)
    Do $$$AssertEquals(tHttp _ " " _ $IsObject(tStatement), "200 1", "SQL statements carries the probe statement, its literal kept")
    If $IsObject(tStatement) Do $$$AssertEquals(..Keys(tStatement) _ " " _ tStatement.PlanState, ..#STATEMENTFIELDS _ " Unfrozen", "with exactly its declared fields and no user name, client or call stack")
    If $IsObject(tStatement) Do $$$AssertEquals($Extract(tStatement.Location, 1, 7), "%sqlcq.", "and the cached query it runs from as its location")
}

/// <p>Matrix (Not partitioned), AC4: the visible table, which is not partitioned, reads no partition
/// and no partition mapping, answered without the vendor's refusal.</p>
Method TestAPlainTableReadsNoPartitions()
{
    For tEndpoint = "Catalog.Partitions", "Catalog.PartitionMappings" {
        Set tRows = ..Rows(tEndpoint, "table", $Parameter(..#PROBE, "VISIBLE"), .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ tRows.%Size() _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "200 0 ", tEndpoint _ " answers no rows for a plain table")
    }
}

/// <p>Matrix (View tabs), AC2: the probe view reads one information row naming its owner, class,
/// flags, type and text, its two fields with their types, and the statement on it with its kept
/// literal.</p>
/// <p>Mutation (Rule 19): drop the text merge from
/// <method>OcuPilot.Port.AtelierPort.CatalogRows</method> -&gt; the information row's text assertion
/// goes red.</p>
Method TestAViewReadsItsThreeTabs()
{
    Set tView = $Parameter(..#PROBE, "VIEW")
    Set tInfo = ..Rows("Catalog.View", "view", tView, .tHttp)
    Set tRow = $Select(tInfo.%Size() = 1: tInfo.%Get(0), 1: {})
    Do $$$AssertEquals(tHttp _ " " _ tInfo.%Size() _ " " _ (tRow.LastCompiled '= ""), "200 1 1", "View info is one row, with its compile time")
    Set tSelect = " SELECT Id, Name FROM " _ $Parameter(..#PROBE, "VISIBLE")
    Do $$$AssertEquals($Extract(tRow.%Get("Text"), 1, $Length(tSelect)), tSelect, "and its text, as the instance keeps it")
    Do tRow.%Remove("LastCompiled")
    Do tRow.%Remove("Text")
    Do $$$AssertEquals(tRow.%ToJSON(), "{""Owner"":""" _ $Username _ """,""ReadOnly"":false,""Updatable"":true,""Class"":""" _ tView _ """,""CheckOption"":"""",""ClassType"":""VIEW""}", "naming its owner, flags, class and type")
    Set tFields = ..Rows("Catalog.ViewFields", "view", tView, .tHttp)
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortCatalogLive).Column(tFields, "Field") _ " " _ ##class(OcuPilot.Test.AtelierPortCatalogLive).Column(tFields, "Type"), "200 Id,Name %Library.Integer,%Library.String", "Fields carries its two columns and their types")
    Set tStatement = ..RowHolding(..Rows("Catalog.ViewStatements", "view", tView, .tHttp), "Statement", $Parameter(..#PROBE, "VIEWLITERAL"))
    Do $$$AssertEquals(tHttp _ " " _ $IsObject(tStatement), "200 1", "SQL statements carries the statement on the view, its literal kept")
}

/// <p>Matrix (Procedure tabs), AC3: the query procedure reads one information row naming its class,
/// type, method, interface and result columns, and the statement selecting from it; the function's
/// row carries its HTML description as plain text, no tag left, beside its parameter and return
/// value.</p>
/// <p>Mutation (Rule 19): map <code>Description</code> without <code>plain</code> in
/// <parameter>OcuPilot.Port.AtelierPort.CATALOGPROCEDURECOLUMNS</parameter> -&gt; the description
/// assertion goes red.</p>
Method TestAProcedureReadsItsTwoTabs()
{
    Set tInfo = ..Rows("Catalog.Procedure", "procedure", $Parameter(..#PROBE, "QUERY"), .tHttp)
    Set tRow = $Select(tInfo.%Size() = 1: tInfo.%Get(0), 1: {})
    Do $$$AssertEquals(tHttp _ " " _ tRow.Class _ " " _ tRow.Type _ " " _ tRow.Method _ " " _ tRow.Interface _ " " _ tRow.Columns _ " " _ tRow.ResultColumns, "200 OcuProbe195.queryNames query Names 1 2 Id INTEGER, Name VARCHAR", "Stored procedure info is the query's one row")
    Set tStatement = ..RowHolding(..Rows("Catalog.ProcedureStatements", "procedure", $Parameter(..#PROBE, "QUERY"), .tHttp), "Statement", "NAMES")
    Do $$$AssertEquals(tHttp _ " " _ $IsObject(tStatement), "200 1", "SQL statements carries the statement selecting from it")
    Set tInfo = ..Rows("Catalog.Procedure", "procedure", $Parameter(..#PROBE, "DESCRIBED"), .tHttp)
    Set tRow = $Select(tInfo.%Size() = 1: tInfo.%Get(0), 1: {})
    Set tDescription = tRow.%Get("Description")
    Set tMark = $Parameter(..#PROBE, "DESCRIPTIONMARK")
    Do $$$AssertEquals(tHttp _ " " _ tRow.Type _ " " _ tRow.Inputs _ " " _ tRow.InputParameters _ " " _ tRow.Interface _ " " _ tRow.ReturnValue, "200 function 1 pValue INTEGER 2 _isc_sp_ret_val INTEGER", "the function's row carries its parameter and its return value")
    Do $$$AssertTrue(($Extract(tDescription, 1, $Length(tMark) + 11) = (tMark _ " tagged & d")) && (tDescription '[ "<") && ($Extract(tDescription, *-16, *) = "Second paragraph.") && ($Length(tDescription) > $Parameter(..#PROBE, "LONGLENGTH")), "and its description as plain text, no tag left: " _ $Extract(tDescription, 1, 60))
}

/// <p>Matrix (Case): a view and a procedure named in another case resolve to the same ones.</p>
Method TestNamesResolveWithoutRegardToCase()
{
    Set tView = ..Rows("Catalog.View", "view", $ZConvert($Parameter(..#PROBE, "VIEW"), "L"), .tHttp)
    Do $$$AssertEquals(tHttp _ " " _ tView.%Size() _ " " _ $Select(tView.%Size() = 1: tView.%Get(0).Class, 1: ""), "200 1 " _ $Parameter(..#PROBE, "VIEW"), "ocuprobe195.visiblenames reads OcuProbe195.VisibleNames")
    Set tProcedure = ..Rows("Catalog.Procedure", "procedure", $ZConvert($Parameter(..#PROBE, "QUERY"), "U"), .tHttp)
    Do $$$AssertEquals(tHttp _ " " _ tProcedure.%Size() _ " " _ $Select(tProcedure.%Size() = 1: tProcedure.%Get(0).Method, 1: ""), "200 1 Names", "and OCUPROBE195.NAMES reads the query procedure")
}

/// <p>Matrix (Absent, Ambiguous, Bad input): a view and a procedure no row answers are 404
/// <code>PORT.NOTFOUND</code>, a name two views or two procedures answer is 400
/// <code>PORT.VALIDATION</code> with its kind's reason, and a name with no dot is refused before the
/// resolve.</p>
Method TestAbsentAmbiguousAndMalformedNamesAreRefused()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    For tCase = $ListBuild("Catalog.ViewFields", "view", "OcuProbe195.Absent", "404 PORT.NOTFOUND " _ $Parameter(tPort, "REASONCATALOGVIEWNOTFOUND")), $ListBuild("Catalog.ProcedureStatements", "procedure", "OcuProbe195.Absent", "404 PORT.NOTFOUND " _ $Parameter(tPort, "REASONCATALOGPROCEDURENOTFOUND")), $ListBuild("Catalog.View", "view", $Parameter(..#PROBE, "DOTTEDVIEW"), "400 PORT.VALIDATION " _ $Parameter(tPort, "REASONCATALOGVIEWAMBIGUOUS")), $ListBuild("Catalog.Procedure", "procedure", $Parameter(..#PROBE, "DOTTEDPROCEDURE"), "400 PORT.VALIDATION " _ $Parameter(tPort, "REASONCATALOGPROCEDUREAMBIGUOUS")), $ListBuild("Catalog.View", "view", "NoDot", "400 PORT.VALIDATION " _ $Parameter(tPort, "REASONCATALOGVIEW")) {
        Set tRows = ..Rows($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), $List(tCase, 4), $List(tCase, 1) _ " " _ $List(tCase, 3) _ " is refused")
    }
}

/// <p>Matrix (Long text), AC2, AC3: through the read executor the long view's text and the function's
/// description read whole on the screen's answer, each past the field bound, and the long statement's
/// text is cut as the classic tab cuts it, to 1,021 characters and <code>...</code>.</p>
Method TestLongTextIsWholeThroughTheRead()
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
    For tCase = $ListBuild("ExplorerSqlView", "view", $Parameter(..#PROBE, "LONGVIEW"), "Text", $Parameter(..#PROBE, "LONGVIEWMARK")), $ListBuild("ExplorerSqlProcedure", "procedure", $Parameter(..#PROBE, "DESCRIBED"), "Description", $Parameter(..#PROBE, "DESCRIPTIONMARK")) {
        Kill tCriteria
        Set tCriteria($List(tCase, 2)) = $List(tCase, 3)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor." _ $List(tCase, 1), 100, .tResult, .tHttp, .tFault, .tCriteria)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " reads")
        If $$$ISERR(tSC) Continue
        Set tText = $Select(tResult.rows.%Size() = 1: tResult.rows.%Get(0).%Get($List(tCase, 4)), 1: "")
        Do $$$AssertTrue((tText [ $List(tCase, 5)) && ($Length(tText) > ($Parameter(..#PROBE, "LONGLENGTH") + $Length($List(tCase, 5)))), $List(tCase, 1) _ "'s " _ $List(tCase, 4) _ " reads whole: " _ $Length(tText) _ " characters")
    }
    Kill tCriteria
    Set tCriteria("table") = $Parameter(..#PROBE, "VISIBLE")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.ExplorerSqlTableStatements", 100, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "ExplorerSqlTableStatements reads")
    If $$$ISERR(tSC) Quit
    Set tRow = ..RowHolding(tResult.rows, "Statement", $Parameter(..#PROBE, "LONGLITERAL"))
    Do $$$AssertEquals($Select($IsObject(tRow): $Length(tRow.Statement) _ " " _ $Extract(tRow.Statement, *-2, *), 1: ""), "1024 ...", "and the long statement's text is cut to 1,021 characters and marked, past the field bound")
}

/// <p>AC6: a principal granted SELECT on the visible table and view and EXECUTE on the query
/// procedure, its grants read back, reads that view's and that procedure's tabs, and is answered not
/// found on every tab of the ungranted view and procedure.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.AtelierPort.CatalogResolve</method> for
/// <code>Catalog.View</code>, binding the caller's own split name -&gt; the hidden view's View info
/// leg answers its row and goes red.</p>
Method TestAPrincipalReadsOnlyTheViewAndProcedureItWasGranted()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal's resources")
    ; Read before the switch: the probe class is compiled in this namespace alone.
    Set tView = $Parameter(..#PROBE, "VIEW")
    Set tHidden = $Parameter(..#PROBE, "HIDDENVIEW")
    Set tQuery = $Parameter(..#PROBE, "QUERY")
    Set tEcho = $Parameter(..#PROBE, "PROCEDURE")
    Set tGrants = $ListBuild("GRANT SELECT ON " _ $Parameter(..#PROBE, "VISIBLE") _ " TO " _ ..#PROBEUSER, "GRANT SELECT ON " _ tView _ " TO " _ ..#PROBEUSER, "GRANT EXECUTE ON " _ $ClassMethod(..#PROBE, "QueryName") _ " TO " _ ..#PROBEUSER)
    Set tCodes = ""
    Set tChecks = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#PROBENAMESPACE
        For tI = 1:1:$ListLength(tGrants) {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, $List(tGrants, tI))
            Set tCodes = tCodes _ $Select(tI = 1: "", 1: " ") _ tResult.%SQLCODE
        }
        For tCheck = $ListBuild(3, tView, "s"), $ListBuild(3, tHidden, "s"), $ListBuild(9, tQuery, "e"), $ListBuild(9, tEcho, "e") {
            Set tChecks = tChecks _ $SYSTEM.SQL.Security.CheckPrivilege(..#PROBEUSER, $List(tCheck, 1), $List(tCheck, 2), $List(tCheck, 3), ..#PROBENAMESPACE)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do $$$AssertStatusOK(ex.AsStatus(), "the grants ran")
        Quit
    }
    Do $$$AssertEquals(tCodes _ " " _ tChecks, "0 0 0 1010", "the view and the query procedure are granted and the others not, read back")
    Set tProbe = ..ProbeAs(..#PROBEUSER)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("username"), ..#PROBEUSER, "as the principal")
    For tCase = $ListBuild(tView, "Catalog.View", "200  1"), $ListBuild(tView, "Catalog.ViewFields", "200  2"), $ListBuild(tQuery, "Catalog.Procedure", "200  1") {
        Set tLegs = tProbe.%Get($List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLegs): tLegs.%Get($List(tCase, 2)), 1: ""), $List(tCase, 3), $List(tCase, 2) _ " reads the granted " _ $List(tCase, 1))
    }
    For tCase = $ListBuild(tView, "Catalog.ViewStatements"), $ListBuild(tQuery, "Catalog.ProcedureStatements") {
        Set tLegs = tProbe.%Get($List(tCase, 1))
        Set tLeg = $Select($IsObject(tLegs): tLegs.%Get($List(tCase, 2)), 1: "")
        Do $$$AssertTrue(($Piece(tLeg, " ", 1) = 200) && ($Piece(tLeg, " ", 3) > 0), $List(tCase, 2) _ " reads the granted " _ $List(tCase, 1) _ "'s statements: " _ tLeg)
    }
    For tCase = $ListBuild(tHidden, "Catalog.View,Catalog.ViewFields,Catalog.ViewStatements"), $ListBuild(tEcho, "Catalog.Procedure,Catalog.ProcedureStatements") {
        Set tLegs = tProbe.%Get($List(tCase, 1))
        For tI = 1:1:$Length($List(tCase, 2), ",") {
            Set tEndpoint = $Piece($List(tCase, 2), ",", tI)
            Do $$$AssertEquals($Select($IsObject(tLegs): tLegs.%Get(tEndpoint), 1: ""), "404 PORT.NOTFOUND -1", tEndpoint _ " answers not found for the ungranted " _ $List(tCase, 1))
        }
    }
}

/// <p>Run <method>OcuPilot.Test.ExplorerSqlProbe.RunTabsAs</method> as <var>pUser</var> in a child
/// process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.ExplorerSqlProbe).RunTabsAs($Job, pUser, ..#PROBENAMESPACE)::10
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
