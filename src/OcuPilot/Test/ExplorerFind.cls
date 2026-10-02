/// <p>Pins Search and Macros over the wire and through the agent (AD-5, AD-11, AD-24, AD-36): the
/// two screens' reads over HTTP as the configured test principal
/// (<class>OcuPilot.Test.Http</class>) on <class>OcuPilot.Test.ExplorerFindProbe</class>'s
/// documents; <code>explorer.search.read</code> and <code>explorer.macro.read</code> answered
/// through the agent's dispatcher as rows alone, a match's line past the field bound cut and named
/// in <code>truncatedFields</code>; and both screens' criteria accepted on a navigation the agent
/// proposes.</p>
/// <p><b>What it needs from the environment:</b> the API application installed in the install
/// namespace, the test principal holding <code>%Development:USE</code> and READ on
/// <code>USER</code>'s code databases, and a <code>USER</code> namespace, where it creates the probe
/// documents and removes them after each test, failing if any is left. The dispatch legs seed one
/// completed turn and remove it and its ledger rows.</p>
Class OcuPilot.Test.ExplorerFind Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

/// <p>The namespace the probe documents are created in.</p>
Parameter PROBENAMESPACE = "USER";

Parameter PROBE = "OcuPilot.Test.ExplorerFindProbe";

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
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PROBENAMESPACE), "every probe document is removed")
    Quit $$$OK
}

/// <p>Create the probe documents, asserting they are made.</p>
Method MakeProbes() As %Boolean
{
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#PROBENAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe documents are created in " _ ..#PROBENAMESPACE)
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
    Set tUse = {"type": "tool_use", "id": "toolu_find"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pTool), "string")
    Do tUse.%Set("input", ##class(%DynamicObject).%FromJSON(pInput))
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(pTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do $$$AssertStatusOK(tSC, pTool _ ": the dispatch answers")
    If $$$ISERR(tSC) Quit {}
    Set pIsError = tResults.%Get(0).%Get("is_error")
    Quit ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
}

/// <p>AC1: the Search screen's read answers one row per match with the declared fields and the
/// criteria it applied, and an absent text is refused <code>PORT.VALIDATION</code>; AC5: the Macros
/// screen's read answers the definition and location found in the document's context, no row for a
/// macro nothing there defines, and <code>PORT.NOTFOUND</code> for an absent document.</p>
Method TestBothScreensReadOverTheWire()
{
    If '..MakeProbes() Quit
    Set tNeedle = $Parameter(..#PROBE, "NEEDLE")
    Set tSC = ..Read("explorer.search", "text=" _ tNeedle _ "&case=yes", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the search reads")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Order"",""Document"",""Member"",""Line"",""Attribute"",""Text""]", "projecting the declared fields")
    Do $$$AssertEquals(tAnswer.criteria.%ToJSON(), "{""text"":""" _ tNeedle _ """,""scope"":""all"",""case"":""yes""}", "reporting the criteria it applied")
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " " _ tAnswer.truncated _ " " _ tAnswer.%IsDefined("document"), "4 0 0", "four matches, uncut, and no document")
    Set tSC = ..Read("explorer.search", "scope=classes", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "400 PORT.VALIDATION", "a search with no text is refused")

    Set tSC = ..Read("explorer.macro", "document=OcuProbe194.Child.cls&macro=%24%24%24OcuProbe194Value", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the lookup reads")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.rows.%ToJSON(), "[{""Macro"":""OcuProbe194Value"",""Document"":""OcuProbe194Inc.inc"",""Line"":1,""Definition"":""OcuProbe194Value 42""}]", "one row naming the definition and where it is")
    Set tSC = ..Read("explorer.macro", "document=OcuProbe194.Child.cls&macro=OcuProbe194None", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")): tAnswer.rows.%Size(), 1: ""), "200 0", "an undefined macro reads as no row")
    Set tSC = ..Read("explorer.macro", "document=OcuProbe194.Absent.cls&macro=OcuProbe194Value", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "an absent document is refused")
}

/// <p>AC6: each read tool answered through the agent's dispatcher returns rows and no document, and
/// a match's line longer than the field bound reaches the model cut to it, ending in U+2026, with
/// <code>Text</code> named in <code>truncatedFields</code>.</p>
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
        Set tContent = ..Dispatch(tTurnKey, "explorer.search.read", "{""text"":""" _ $Parameter(..#PROBE, "LONGNEEDLE") _ """}", .tIsError)
        Do $$$AssertEquals(tIsError, 0, "the search tool answers: " _ $Extract(tContent.%ToJSON(), 1, 300))
        Set tRows = tContent.%Get("rows")
        Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() = 1), "with the one long match")
        Do $$$AssertTrue('tContent.%IsDefined("document"), "and no document")
        If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit
        Set tText = tRows.%Get(0).Text
        Do $$$AssertEquals($Length(tText) _ " " _ ($Extract(tText, *) = $Char(8230)), "1000 1", "the match's line is cut to the field bound, marked")
        Do $$$AssertEquals($Select($IsObject(tContent.%Get("truncatedFields")): tContent.truncatedFields.%ToJSON(), 1: ""), "[""Text""]", "and Text is named in truncatedFields")

        Set tContent = ..Dispatch(tTurnKey, "explorer.macro.read", "{""document"":""OcuProbe194.Parent.cls"",""macro"":""OcuProbe194Value""}", .tIsError)
        Do $$$AssertEquals(tIsError, 0, "the macro tool answers: " _ $Extract(tContent.%ToJSON(), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tContent.%Get("rows")): tContent.rows.%ToJSON(), 1: ""), "[{""Macro"":""OcuProbe194Value"",""Document"":""OcuProbe194Inc.inc"",""Line"":1,""Definition"":""OcuProbe194Value 42""}]", "its one row")
        Do $$$AssertTrue('tContent.%IsDefined("document"), "and no document")

        Set tContent = ..Dispatch(tTurnKey, "explorer.search.read", "{}", .tIsError)
        Do $$$AssertEquals(tIsError _ " " _ tContent.%Get("code"), "1 PORT.VALIDATION", "an empty search call is refused")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the dispatch leg ran")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertEquals(tRemaining, 0, "the seeded turn is removed")
}

/// <p>AD-11, AD-36: a navigation to either screen carrying its declared criteria validates and
/// carries them on the directive, and a value its read refuses is refused by name.</p>
Method TestBothScreensAcceptTheirArrivalCriteria()
{
    Set tTool = "OcuPilot.Screen.Tool.Navigate"
    Set tSearch = {"text": "TODO", "scope": "routines", "case": "yes"}
    Set tArgs = {"route": "system-explorer/search"}
    Do tArgs.%Set("criteria", tSearch)
    Set tSC = $ClassMethod(tTool, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tCriterion, .tCriteria)
    Do $$$AssertStatusOK(tSC, "a search's criteria validate")
    Do $$$AssertEquals(tRoute _ " " _ $Select($IsObject(tCriteria): tCriteria.%ToJSON(), 1: ""), "system-explorer/search " _ tSearch.%ToJSON(), "and travel on the directive")
    Set tMacro = {"document": "OcuProbe194.Parent.cls"}
    Do tMacro.%Set("macro", "$$" _ "$OK", "string")
    Set tArgs = {"route": "system-explorer/macros"}
    Do tArgs.%Set("criteria", tMacro)
    Set tSC = $ClassMethod(tTool, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tCriterion, .tCriteria)
    Do $$$AssertStatusOK(tSC, "a lookup's criteria validate")
    Do $$$AssertEquals(tRoute _ " " _ $Select($IsObject(tCriteria): tCriteria.%ToJSON(), 1: ""), "system-explorer/macros " _ tMacro.%ToJSON(), "and travel on the directive")
    Set tArgs = {"route": "system-explorer/search", "criteria": {"scope": "files"}}
    Set tSC = $ClassMethod(tTool, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tCriterion, .tCriteria)
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code _ " " _ tFault.detail.criterion, 1: ""), ##class(OcuPilot.Api.Error).#NAVCRITERIONINVALID _ " scope", "a scope outside its options is refused by name")
}

}
