/// <p>Pins Data browser's route over the wire (Story 19.7): <code>POST /explorer/sql/data</code>
/// answering one JSON envelope -- a page's shape, NULL beside an empty value, a column grant's
/// columns with no total, a view a view-only grantee reads, bad input refused 400, the screen's gate
/// naming its pair ahead of the body's shape, an unknown table answered 404, and, as the suite's
/// <code>%All</code> account in the install namespace, a table in an OcuPilot schema and a view over
/// OcuPilot's own table each refused <code>PROHIBITED.OCUPILOTSQL</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace. It creates and
/// removes <class>OcuPilot.Test.SqlBrowseProbe</class>'s objects, data included, and its principals,
/// so it runs on a throwaway only: <method>OnBeforeAllTests</method> refuses unless
/// <method>OcuPilot.Test.SqlConsoleProbe.Armed</method> reads 1.</p>
Class OcuPilot.Test.SqlDataRoutes Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlBrowseProbe";

Parameter DATA = "/api/ocupilot/explorer/sql/data";

/// <p>The principals' password for this run.</p>
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
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlDataRoutes creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter("OcuPilot.Test.SqlConsoleProbe", "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe197" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

/// <p>POST <var>pBody</var> in namespace <var>pNamespace</var> as <var>pUser</var> (the suite's own
/// account when <code>""</code>), answering the status, the parsed answer and the content type.</p>
Method Post(pBody, Output pStatus As %Integer, Output pAnswer, Output pType As %String, pNamespace As %String = "USER", pUser As %String = "")
{
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#DATA _ "?ns=" _ pNamespace, tUser, tPassword, .pStatus, .tBody, .tHeaders, tText, "application/json")
    Set pType = $Piece($Get(tHeaders("CONTENT-TYPE")), ";", 1)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = $Get(tBody)
    }
}

/// <p>A refusal as one line: the status, the envelope's code and the pair it names.</p>
ClassMethod Code(pStatus As %Integer, pAnswer) As %String
{
    If '$IsObject($Get(pAnswer)) Quit $Get(pStatus) _ " " _ $Get(pAnswer)
    Quit $Get(pStatus) _ " " _ pAnswer.%Get("code") _ $Select(pAnswer.%GetTypeOf("detail") = "object": " " _ pAnswer.detail.%Get("failedPair"), 1: "")
}

/// <p>A page answers 200 as JSON with its outcome, table, columns, key, rows, offset, size, more,
/// total and truncated, and a cell's NULL as <code>null</code>.</p>
Method TestAPageAnswersItsShape()
{
    Do ..Post({"schema": "OcuProbe197", "table": "Keyed", "sort": {"column": "Code", "direction": "desc"}, "size": 50}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    Do $$$AssertEquals(tType, "application/json", "with CONTENT-TYPE application/json")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer), "{""outcome"":""rows"",""table"":{""schema"":""OcuProbe197"",""name"":""Keyed"",""type"":""table""},""columns"":[{""name"":""Code"",""type"":""varchar"",""kind"":""text"",""nullable"":false,""key"":true},{""name"":""Name"",""type"":""varchar"",""kind"":""text"",""nullable"":true,""key"":false}],""key"":[""Code""],""rows"":[[""c3"",""three""],[""c2"",""two""],[""c1"",""one""]],""offset"":0,""size"":50,""more"":false,""total"":3,""truncated"":false}", "the page's whole shape")
    Do ..Post({"schema": "OcuProbe197", "table": "Plain", "filters": {"Name": "n4*"}, "sort": {"column": "Num", "direction": "asc"}}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")): tStatus _ " " _ tAnswer.rows.%Size() _ " " _ tAnswer.rows.%Get(0).%Get(0) _ " " _ tAnswer.total, 1: tStatus), "200 1 n40 1", "a filtered page")
}

/// <p>AC3 and AC6 over the wire: a NULL cell is JSON <code>null</code> and an empty one
/// <code>""</code>, and a column grantee's page lists only its column with <code>total</code>
/// <code>null</code>.</p>
Method TestCellsAndAColumnGrantOverTheWire()
{
    Do ..Post({"schema": "OcuProbe197", "table": "Plain", "sort": {"column": "Num", "direction": "asc"}, "size": 50}, .tStatus, .tAnswer, .tType)
    Set tRows = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("rows") = "array"): tAnswer.rows, 1: "")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Get(3).%GetTypeOf(0) _ " " _ tRows.%Get(4).%GetTypeOf(0) _ " [" _ tRows.%Get(4).%Get(0) _ "]", 1: ..Code(tStatus, tAnswer)), "null string []", "NULL is null and an empty value """"")
    Do ..Post({"schema": "OcuProbe197", "table": "Two"}, .tStatus, .tAnswer, .tType, "USER", $Parameter(..#PROBE, "USER"))
    Do $$$AssertEquals($Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("columns") = "array"): tStatus _ " " _ tAnswer.columns.%Size() _ " " _ tAnswer.columns.%Get(0).name _ " " _ tAnswer.rows.%Size() _ " " _ tAnswer.%GetTypeOf("total"), 1: ..Code(tStatus, tAnswer)), "200 1 Name 2 null", "a column grant's one column, its rows and no total")
}

/// <p>AC6: the view-only grantee reads the view's ten rows over the wire and is answered 404 on its
/// base table.</p>
Method TestAViewOnlyGranteeReadsTheView()
{
    Set tUser = $Parameter(..#PROBE, "VIEWUSER")
    Do ..Post({"schema": "OcuProbe197", "table": "Over30"}, .tStatus, .tAnswer, .tType, "USER", tUser)
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")): tStatus _ " " _ tAnswer.table.type _ " " _ tAnswer.rows.%Size() _ " " _ tAnswer.total, 1: ..Code(tStatus, tAnswer)), "200 view 10 10", "the view's ten rows")
    Do ..Post({"schema": "OcuProbe197", "table": "Plain"}, .tStatus, .tAnswer, .tType, "USER", tUser)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 EXPLORER.DATA.NOTFOUND", "and 404 on its base table")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONDATANOTFOUND, "with the published sentence")
}

/// <p>Matrix row Bad input: an unknown key, a page size of 70, an offset of -1, a filter of 1,001
/// characters, the direction <code>up</code>, a filter on an unlisted column, a body that is not
/// JSON, and a stream column's filter are each refused 400 <code>EXPLORER.DATA.INPUT</code>.</p>
Method TestBadInputIsRefused()
{
    Set tBodies = [
        {"schema": "OcuProbe197", "table": "Plain", "extra": true},
        {"schema": "OcuProbe197", "table": "Plain", "size": 70},
        {"schema": "OcuProbe197", "table": "Plain", "offset": -1},
        {"schema": "OcuProbe197", "table": "Plain", "filters": {"Name": ($Translate($Justify("", 1001), " ", "x"))}},
        {"schema": "OcuProbe197", "table": "Plain", "sort": {"column": "Num", "direction": "up"}},
        {"schema": "OcuProbe197", "table": "Plain", "filters": {"Nope": "x"}},
        {"schema": "OcuProbe197", "table": "Plain", "filters": {"Notes": "x*"}},
        "{"
    ]
    Set tIterator = tBodies.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tBody) {
        Do ..Post(tBody, .tStatus, .tAnswer, .tType)
        Do $$$AssertEquals(..Code(tStatus, tAnswer), "400 EXPLORER.DATA.INPUT", "body " _ tIndex)
    }
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONDATAINPUT, "with the published sentence")
}

/// <p>The screen's gate: without <code>%Development:USE</code> the route refuses 403
/// <code>AUTH.NOPRIVILEGE</code> naming it, a body outside the route's shape included, since the gate
/// comes first; an unknown table is 404.</p>
/// <p>Mutation (Rule 19): read the body before the gate in
/// <method>OcuPilot.Area.Explorer.SqlData.HandleBrowse</method> -- the bad body's leg answers 400 and
/// goes red.</p>
Method TestTheGateAndAnUnknownTable()
{
    Do ..Post({"schema": "OcuProbe197", "table": "Plain"}, .tStatus, .tAnswer, .tType, "USER", $Parameter(..#PROBE, "NODEVUSER"))
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE %Development:USE", "without %Development:USE")
    Do ..Post({"schema": "OcuProbe197", "table": "Plain", "extra": true}, .tStatus, .tAnswer, .tType, "USER", $Parameter(..#PROBE, "NODEVUSER"))
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE %Development:USE", "and the gate refuses before the body's shape is read")
    Do ..Post({"schema": "OcuProbe197", "table": "NoSuchTable"}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 EXPLORER.DATA.NOTFOUND", "an unknown table")
}

/// <p>AC7: as the suite's <code>%All</code> account in the install namespace, a table in an OcuPilot
/// schema is refused before any statement, and a view over OcuPilot's proposal table before any row,
/// each 403 <code>PROHIBITED.OCUPILOTSQL</code> with its published sentence.</p>
/// <p>Mutation (Rule 19): drop the check on the requested name from
/// <method>OcuPilot.Area.Explorer.SqlData.HandleBrowse</method> -- the own-table leg goes red.</p>
Method TestOcuPilotsOwnTablesAreRefused()
{
    Set tView = $Parameter(..#PROBE, "OWNVIEW")
    For tBody = {"schema": "OcuPilot_Kernel_State", "table": "Turn"}, {"schema": "OcuPilot_Kernel_State", "table": "NoSuchTable"}, {"schema": ($Piece(tView, ".")), "table": ($Piece(tView, ".", 2))} {
        Do ..Post(tBody, .tStatus, .tAnswer, .tType, $NAMESPACE)
        Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), "403 PROHIBITED.OCUPILOTSQL " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTSQLREASON, tBody.%ToJSON())
    }
}

}
