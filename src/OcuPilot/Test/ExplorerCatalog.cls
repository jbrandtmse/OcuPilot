/// <p>Pins the SQL catalog's screens over the wire and through the agent (AD-5, AD-11, AD-24, AD-36,
/// AD-60): a list's, a table tab's and a view tab's reads over HTTP as the configured test principal
/// (<class>OcuPilot.Test.Http</class>) on <class>OcuPilot.Test.ExplorerSqlProbe</class>'s objects;
/// each of the eighteen <code>explorer.sql*.read</code> tools answered through the agent's dispatcher
/// as rows alone, a trigger's code, a view's text, a description and a statement's text past the
/// field bound cut and named in <code>truncatedFields</code>; a view's text, a description, a
/// statement's text and a cached query's text cut the same way in screen context; and the four lists'
/// criteria accepted on a navigation the agent proposes.</p>
/// <p><b>What it needs from the environment:</b> the API application installed in the install
/// namespace, the test principal holding <code>%Development:USE</code> and READ on
/// <code>USER</code>'s code databases and seeing the probe tables, and a <code>USER</code> namespace,
/// where each test creates the probe objects and removes them after, failing if any is left. The
/// dispatch leg seeds one completed turn and removes it and its ledger rows.</p>
Class OcuPilot.Test.ExplorerCatalog Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerSqlProbe";

/// <p>The agent's limits class.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe object is removed")
    Quit $$$OK
}

/// <p>Create the probe objects, asserting they are made.</p>
Method MakeProbes() As %Boolean
{
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#PROBENAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe objects are created in " _ ..#PROBENAMESPACE)
    Quit $$$ISOK(tSC)
}

/// <p>Request <var>pTool</var>'s read with query string <var>pQuery</var> in the probe namespace as
/// the test principal. <var>pAnswer</var> is the parsed body, or <code>""</code>.</p>
Method Read(pTool As %String, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ pTool _ "/read?" _ pQuery _ "&ns=" _ ..#PROBENAMESPACE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>Answer <var>pTool</var> called with <var>pInput</var> (JSON) through the agent's dispatcher
/// in turn <var>pTurnKey</var>: <var>pIsError</var> and the parsed content.</p>
Method Dispatch(pTurnKey As %String, pTool As %String, pInput As %String, Output pIsError As %Boolean) As %DynamicObject
{
    Set pIsError = 1
    Set tUse = {"type": "tool_use", "id": "toolu_catalog"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pTool), "string")
    Do tUse.%Set("input", ##class(%DynamicObject).%FromJSON(pInput))
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do $$$AssertStatusOK(tSC, pTool _ ": the dispatch answers")
    If $$$ISERR(tSC) Quit {}
    Set pIsError = tResults.%Get(0).%Get("is_error")
    Quit ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
}

/// <p>AC1, AC2: the SQL tables screen's read answers the probe schema's tables with the declared
/// fields and the criteria it applied; the Triggers tab's read answers the visible table's trigger,
/// and refuses a missing table <code>PORT.VALIDATION</code> and an absent one
/// <code>PORT.NOTFOUND</code>.</p>
Method TestAListAndATabReadOverTheWire()
{
    If '..MakeProbes() Quit
    Set tSC = ..Read("explorer.sqltables", "schema=OcuProbe195", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the tables read")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Table"",""Schema"",""Name"",""Class"",""Owner"",""Sharded"",""Partitioned""]", "projecting the declared fields")
    Do $$$AssertEquals(tAnswer.criteria.%ToJSON(), "{""system"":""no"",""schema"":""OcuProbe195""}", "reporting the criteria it applied")
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " " _ tAnswer.truncated _ " " _ tAnswer.%IsDefined("document"), "4 0 0", "four tables, uncut, and no document")

    Set tSC = ..Read("explorer.sqltriggers", "table=" _ $Parameter(..#PROBE, "VISIBLE"), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the Triggers tab reads")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON() _ " " _ tAnswer.rows.%Size(), "[""Trigger"",""Event"",""Order"",""Code""] 1", "its one trigger, with the declared fields")
    Do $$$AssertTrue($Length(tAnswer.rows.%Get(0).Code) > $Parameter(..#PROBE, "LONGLENGTH"), "the screen's row carries the whole code")
    Set tSC = ..Read("explorer.sqltriggers", "maxRows=5", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 PORT.VALIDATION", "a tab with no table is refused")
    Set tSC = ..Read("explorer.sqltriggers", "table=OcuProbe195.Absent", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "and an absent table is not found")
}

/// <p>Story 19.14 AC2: the View info tab's read answers the long view's one row over HTTP with the
/// declared fields and its whole text, and an absent view is not found.</p>
Method TestAViewTabReadsOverTheWire()
{
    If '..MakeProbes() Quit
    Set tSC = ..Read("explorer.sqlview", "view=" _ $Parameter(..#PROBE, "LONGVIEW"), .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the View info tab reads")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON() _ " " _ tAnswer.rows.%Size() _ " " _ tAnswer.criteria.%ToJSON(), "[""Owner"",""LastCompiled"",""ReadOnly"",""Updatable"",""Class"",""CheckOption"",""ClassType"",""Text""] 1 {""view"":""" _ $Parameter(..#PROBE, "LONGVIEW") _ """}", "its one row, with the declared fields and the criterion it applied")
    Do $$$AssertTrue($Length(tAnswer.rows.%Get(0).Text) > $Parameter(..#PROBE, "LONGLENGTH"), "the screen's row carries the whole text")
    Set tSC = ..Read("explorer.sqlview", "view=OcuProbe195.Absent", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "and an absent view is not found")
}

/// <p>AC5 and Story 19.14 AC7: each of the eighteen read tools answered through the agent's dispatcher
/// returns rows and no document -- Partition mappings answering none, since the partitioned probe table
/// has no mapping configured -- and a trigger's code, a view's text, a procedure's description and a
/// statement's text longer than the field bound reach the model cut to it, ending in U+2026, each named
/// in <code>truncatedFields</code>.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Kernel.Agent.Bound.Apply</method>'s per-field cut
/// -&gt; the bound assertions go red.</p>
Method TestTheReadToolsAnswerBoundedRowsAlone()
{
    If '..MakeProbes() Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        Do ##class(OcuPilot.Kernel.Scope).Set(..#PROBENAMESPACE)
        Set tTable = "{""table"":""" _ $Parameter(..#PROBE, "VISIBLE") _ """}"
        Set tParted = "{""table"":""" _ $Parameter(..#PROBE, "PARTED") _ """}"
        Set tView = "{""view"":""" _ $Parameter(..#PROBE, "VIEW") _ """}"
        Set tQuery = "{""procedure"":""" _ $Parameter(..#PROBE, "QUERY") _ """}"
        For tCase = $ListBuild("explorer.sqlschemas.read", "{}"), $ListBuild("explorer.sqltables.read", "{""schema"":""OcuProbe195""}"), $ListBuild("explorer.sqlviews.read", "{""schema"":""OcuProbe195""}"), $ListBuild("explorer.sqlprocedures.read", "{""schema"":""OcuProbe195""}"), $ListBuild("explorer.sqltable.read", tTable), $ListBuild("explorer.sqlfields.read", tTable), $ListBuild("explorer.sqlindices.read", tTable), $ListBuild("explorer.sqltriggers.read", tTable), $ListBuild("explorer.sqlconstraints.read", tTable), $ListBuild("explorer.sqlpartitions.read", tParted), $ListBuild("explorer.sqlpartitionmappings.read", tParted, 0), $ListBuild("explorer.sqlcachedqueries.read", tTable), $ListBuild("explorer.sqltablestatements.read", tTable), $ListBuild("explorer.sqlview.read", tView), $ListBuild("explorer.sqlviewfields.read", tView), $ListBuild("explorer.sqlviewstatements.read", tView), $ListBuild("explorer.sqlprocedure.read", tQuery), $ListBuild("explorer.sqlprocedurestatements.read", tQuery) {
            Set tContent = ..Dispatch(tTurnKey, $List(tCase, 1), $List(tCase, 2), .tIsError)
            Set tRows = tContent.%Get("rows")
            If $ListGet(tCase, 3, 1) {
                Do $$$AssertTrue('tIsError && $IsObject(tRows) && (tRows.%Size() > 0), $List(tCase, 1) _ " answers rows: " _ $Extract(tContent.%ToJSON(), 1, 200))
            } Else {
                Do $$$AssertTrue('tIsError && $IsObject(tRows) && (tRows.%Size() = 0), $List(tCase, 1) _ " answers an empty rows: " _ $Extract(tContent.%ToJSON(), 1, 200))
            }
            Do $$$AssertTrue('tContent.%IsDefined("document"), $List(tCase, 1) _ " answers no document")
        }
        Set tContent = ..Dispatch(tTurnKey, "explorer.sqltriggers.read", tTable, .tIsError)
        Set tRows = tContent.%Get("rows")
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: -1), 1, "the Triggers tool answers the one trigger")
        If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit
        Set tCode = tRows.%Get(0).Code
        Do $$$AssertEquals($Length(tCode) _ " " _ ($Extract(tCode, *) = $Char(8230)), "1000 1", "the trigger's code is cut to the field bound, marked")
        Do $$$AssertEquals($Select($IsObject(tContent.%Get("truncatedFields")): tContent.truncatedFields.%ToJSON(), 1: ""), "[""Code""]", "and Code is named in truncatedFields")

        Set tContent = ..Dispatch(tTurnKey, "explorer.sqlview.read", "{""view"":""" _ $Parameter(..#PROBE, "LONGVIEW") _ """}", .tIsError)
        Set tRows = tContent.%Get("rows")
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: -1), 1, "the View info tool answers the long view's one row")
        If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit
        Set tText = tRows.%Get(0).Text
        Do $$$AssertEquals($Length(tText) _ " " _ ($Extract(tText, *) = $Char(8230)), "1000 1", "the view's text is cut to the field bound, marked")
        Do $$$AssertEquals($Select($IsObject(tContent.%Get("truncatedFields")): tContent.truncatedFields.%ToJSON(), 1: ""), "[""Text""]", "and Text is named in truncatedFields")

        Set tContent = ..Dispatch(tTurnKey, "explorer.sqlprocedure.read", "{""procedure"":""" _ $Parameter(..#PROBE, "DESCRIBED") _ """}", .tIsError)
        Set tRows = tContent.%Get("rows")
        Set tText = $Select($IsObject(tRows) && (tRows.%Size() = 1): tRows.%Get(0).Description, 1: "")
        Do $$$AssertEquals($Length(tText) _ " " _ ($Extract(tText, *) = $Char(8230)) _ " " _ ($Extract(tText, 1, $Length($Parameter(..#PROBE, "DESCRIPTIONMARK"))) = $Parameter(..#PROBE, "DESCRIPTIONMARK")), "1000 1 1", "the function's plain-text description is cut to the field bound, marked")
        Do $$$AssertEquals($Select($IsObject(tContent.%Get("truncatedFields")): tContent.truncatedFields.%ToJSON(), 1: ""), "[""Description""]", "and Description is named in truncatedFields")

        Set tContent = ..Dispatch(tTurnKey, "explorer.sqltablestatements.read", tTable, .tIsError)
        Set tRows = tContent.%Get("rows")
        Set tText = ""
        If $IsObject(tRows) {
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If tRow.Statement [ $Parameter(..#PROBE, "LONGLITERAL") Set tText = tRow.Statement
            }
        }
        Do $$$AssertEquals($Length(tText) _ " " _ ($Extract(tText, *) = $Char(8230)), "1000 1", "the long statement's text is cut to the field bound, marked")
        Do $$$AssertTrue($IsObject(tContent.%Get("truncatedFields")) && (tContent.truncatedFields.%ToJSON() [ """Statement"""), "and Statement is named in truncatedFields")

        Set tContent = ..Dispatch(tTurnKey, "explorer.sqlfields.read", "{}", .tIsError)
        Do $$$AssertEquals(tIsError _ " " _ tContent.%Get("code"), "1 PORT.VALIDATION", "a tab called with no table is refused")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the dispatch leg ran")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertEquals(tRemaining, 0, "the seeded turn is removed")
}

/// <p>Story 19.14 AC7, Matrix (Long text): a view's text, a procedure's description, a statement's
/// text and a cached query's text longer than the field bound are cut in screen context, ending in
/// U+2026, and named in <code>truncatedFields</code>.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Kernel.Agent.Bound.Apply</method>'s per-field cut
/// -&gt; every leg goes red.</p>
Method TestTheScreenContextCutsTheLongTexts()
{
    Set tLong = $Translate($Justify("", 1500), " ", "x")
    For tCase = $ListBuild("system-explorer/sql-views/document", "Text"), $ListBuild("system-explorer/sql-procedures/document", "Description"), $ListBuild("system-explorer/sql-tables/statements", "Statement"), $ListBuild("system-explorer/sql-tables/cached-queries", "Query") {
        Set tField = $List(tCase, 2)
        Set tRow = {}
        Do tRow.%Set(tField, tLong, "string")
        Set tContext = {"view": {"rows": [(tRow)]}}
        Do tContext.%Set("route", $List(tCase, 1), "string")
        Do tContext.%Set("namespace", ##class(OcuPilot.Kernel.Scope).Current(), "string")
        Set tSC = ##class(OcuPilot.Api.Turn).BoundedContext(tContext, 0, 200, "OcuPilot.Kernel.Agent.Limits", .tJson)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the payload builds")
        If $$$ISERR(tSC) Continue
        Set tPayload = ##class(%DynamicObject).%FromJSON(tJson)
        Set tText = $Select($IsObject(tPayload.%Get("rows")) && (tPayload.rows.%Size() = 1): tPayload.rows.%Get(0).%Get(tField), 1: "")
        Do $$$AssertEquals($Length(tText) _ " " _ ($Extract(tText, *) = $Char(8230)), "1000 1", $List(tCase, 1) _ ": " _ tField _ " is cut to the field bound, marked")
        Do $$$AssertEquals($Select($IsObject(tPayload.%Get("truncatedFields")): tPayload.truncatedFields.%ToJSON(), 1: ""), "[""" _ tField _ """]", $List(tCase, 1) _ ": and " _ tField _ " is named in truncatedFields")
    }
}

/// <p>AD-11, AD-36: a navigation to each of the four lists carrying its declared criteria validates
/// and carries them on the directive, and a system choice its read refuses is refused by name.</p>
Method TestTheListsAcceptTheirArrivalCriteria()
{
    Set tTool = "OcuPilot.Screen.Tool.Navigate"
    For tCase = $ListBuild("system-explorer/sql-schemas", "{""system"":""yes""}"), $ListBuild("system-explorer/sql-tables", "{""system"":""no"",""schema"":""OcuProbe195""}"), $ListBuild("system-explorer/sql-views", "{""schema"":""OcuProbe195""}"), $ListBuild("system-explorer/sql-procedures", "{""system"":""yes"",""schema"":""%Library""}") {
        Set tArgs = {}
        Do tArgs.%Set("route", $List(tCase, 1), "string")
        Do tArgs.%Set("criteria", ##class(%DynamicObject).%FromJSON($List(tCase, 2)))
        Set tSC = $ClassMethod(tTool, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tCriterion, .tCriteria)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": its criteria validate")
        Do $$$AssertEquals(tRoute _ " " _ $Select($IsObject(tCriteria): tCriteria.%ToJSON(), 1: ""), $List(tCase, 1) _ " " _ $List(tCase, 2), $List(tCase, 1) _ ": and travel on the directive")
    }
    Set tArgs = {"route": "system-explorer/sql-tables", "criteria": {"system": "maybe"}}
    Set tSC = $ClassMethod(tTool, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tCriterion, .tCriteria)
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code _ " " _ tFault.detail.criterion, 1: ""), ##class(OcuPilot.Api.Error).#NAVCRITERIONINVALID _ " system", "a system choice outside its options is refused by name")
}

}
