/// <p>System Explorer over the wire, against the live source code API:
/// <code>GET /api/ocupilot/screens/:screen/read</code> as the configured test principal
/// (<class>OcuPilot.Test.Http</class>) for both lists and both viewers, with the criteria the screen
/// opens on, a name pattern, the forms, a document the namespace does not hold and malformed
/// arguments; and each <code>explorer.*.read</code> answered through the agent's dispatcher, which
/// returns the rows, each field bounded, and never the document. Denials over the wire, by real
/// principals, are <class>OcuPilot.Test.AtelierPortDenial</class>'s.</p>
/// <p>Needs the API application installed in the install namespace and the test principal holding
/// <code>%Development:USE</code> and READ on the namespaces' code databases. It issues reads only;
/// the dispatch leg seeds one completed turn as the principal and removes it and its ledger rows.</p>
Class OcuPilot.Test.ExplorerWire Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

/// <p>The agent's limits class.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Request <var>pTool</var>'s read with query string <var>pQuery</var> as the test principal.
/// <var>pAnswer</var> is the parsed body, or <code>""</code>. The HTTP client has already decoded
/// the body from UTF-8, so it is parsed as it arrives.</p>
Method Read(pTool As %String, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ pTool _ "/read?" _ pQuery, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .pHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p><var>pRows</var>' <code>Name</code>s, comma-separated.</p>
ClassMethod Names(pRows As %DynamicArray) As %String
{
    Set tNames = ""
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Name
    }
    Quit tNames
}

/// <p>Matrix: the Classes list opens on the classic defaults -- no <code>%</code> names, no
/// generated classes, mapped ones included -- with the declared fields, at most the cap's rows and
/// <code>truncated</code> reported; a pattern narrows it case-sensitively to exactly its matches;
/// and the route's <code>ns</code> is the namespace read (AC1), so another namespace, which holds
/// none of OcuPilot's classes, answers none of them.</p>
/// <p>Mutation: hand the port <code>$Namespace</code> in place of the route's scope in
/// <method>OcuPilot.Screen.Read.Execute</method>'s atelier branch -&gt; the other-namespace
/// assertions go red.</p>
Method TestTheClassesListOpensOnTheClassicDefaults()
{
    Set tHere = $Namespace
    Set tSC = ..Read("explorer.classes", "maxRows=50&ns=" _ tHere, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the list is read")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Name"",""Modified"",""Database"",""Generated""]", "projecting the declared fields")
    Do $$$AssertEquals(tAnswer.criteria.%ToJSON(), "{""pattern"":""*"",""system"":""no"",""generated"":""no"",""mapped"":""yes"",""from"":"""",""to"":""""}", "reporting the defaults it applied")
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " " _ tAnswer.truncated, "50 1", "at most the cap's rows, reporting the cut")
    Set tSystem = 0
    Set tGenerated = 0
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.Name) = "%" Set tSystem = tSystem + 1
        If tRow.Generated Set tGenerated = tGenerated + 1
    }
    Do $$$AssertEquals(tSystem _ " " _ tGenerated, "0 0", "with no % name and no generated class")

    Set tSC = ..Read("explorer.classes", "pattern=OcuPilot.Kernel.Entity*&ns=" _ tHere, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ..Names(tAnswer.rows), "200 OcuPilot.Kernel.EntityId.cls,OcuPilot.Kernel.EntityRef.cls,OcuPilot.Kernel.EntityType.cls", "a pattern narrows the list to exactly its matches")
    Set tSC = ..Read("explorer.classes", "pattern=ocupilot.kernel.entity*&ns=" _ tHere, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.rows.%Size(), "200 0", "and matches case-sensitively, as the classic page does")

    Set tOther = $Select(tHere = "USER": "%SYS", 1: "USER")
    Set tSC = ..Read("explorer.classes", "pattern=OcuPilot.Kernel.Entity*&ns=" _ $Replace(tOther, "%", "%25"), .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")): tAnswer.rows.%Size(), 1: ""), "200 0", "the same pattern in " _ tOther _ " reads that namespace, which holds none of them")
    Set tSC = ..Read("explorer.class", "name=OcuPilot.Kernel.EntityId.cls&ns=" _ $Replace(tOther, "%", "%25"), .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "and so does a document read")
}

/// <p>Matrix: the Routines list opens on <code>*.mac</code> with generated routines included.</p>
Method TestTheRoutinesListOpensOnMacRoutines()
{
    Set tSC = ..Read("explorer.routines", "maxRows=100&ns=" _ $Namespace, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the list is read")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.criteria.pattern _ " " _ tAnswer.criteria.generated _ " " _ tAnswer.criteria.mapped, "*.mac yes yes", "on the classic routine defaults")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "with rows")
    Set tOther = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ZConvert($Piece(tRow.Name, ".", $Length(tRow.Name, ".")), "L") '= "mac" Set tOther = tOther _ " " _ tRow.Name
    }
    Do $$$AssertEquals(tOther, "", "every row a .mac routine")
}

/// <p>Matrix: the class viewer answers the class row and its members with the document beside them,
/// in each form, non-ASCII text intact; a class with no intermediate code answers
/// <code>available</code> false.</p>
/// <p>Mutation: read the index route's file back with <code>TranslateTable</code>
/// <code>RAW</code> in <method>OcuPilot.Port.AtelierPort.Route</method> -&gt; the documentation's
/// non-ASCII assertion goes red.</p>
Method TestTheClassViewerAnswersRowsAndTheDocument()
{
    Set tHere = $Namespace
    Set tSC = ..Read("explorer.class", "name=OcuPilot.Kernel.EntityId.cls&ns=" _ tHere, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the class is read")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Set tFirst = tAnswer.rows.%Get(0)
    Do $$$AssertEquals(tFirst.Kind _ " " _ tFirst.Name _ " " _ tFirst.Type _ " " _ tFirst.Database, "class OcuPilot.Kernel.EntityId.cls %Library.RegisteredObject " _ tHere, "the class row first")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 1, "then its members")
    Set tDocument = tAnswer.%Get("document")
    Do $$$AssertTrue($IsObject(tDocument), "the document rides beside the rows")
    If '$IsObject(tDocument) Quit
    Do $$$AssertEquals(tDocument.name _ " " _ tDocument.form _ " " _ tDocument.available _ " " _ tDocument.generates.%ToJSON(), "OcuPilot.Kernel.EntityId.cls udl 1 [""OcuPilot.Kernel.EntityId.1.int""]", "in the source form, naming its generated code")
    Do $$$AssertTrue(tDocument.content.%Size() > 0, "with its source lines")
    ; EntityId's doc comment carries U+2014: the index route's file and the text route's capture
    ; each carry it through as one character.
    Do $$$AssertTrue(tFirst.Description [ $Char(8212), "the class's documentation keeps its non-ASCII text: " _ $Extract(tFirst.Description, 1, 200))
    Set tSource = ""
    Set tIterator = tDocument.content.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tSource = tSource _ tLine _ $Char(10)
    }
    Do $$$AssertTrue(tSource [ $Char(8212), "and so does its source")

    For tCase = $ListBuild("xml", "<?xml"), $ListBuild("int", "ROUTINE OcuPilot.Kernel.EntityId.1") {
        Set tSC = ..Read("explorer.class", "name=OcuPilot.Kernel.EntityId.cls&form=" _ $List(tCase, 1) _ "&ns=" _ tHere, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ $Extract($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("document")): tAnswer.document.content.%Get(0), 1: ""), 1, $Length($List(tCase, 2))), "200 " _ $List(tCase, 2), "form " _ $List(tCase, 1) _ " answers its own text")
    }
    Set tSC = ..Read("explorer.class", "name=%25Library.String.cls&form=int&ns=" _ tHere, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("document")): tAnswer.document.available _ " " _ tAnswer.document.content.%Size(), 1: ""), "200 0 0", "a class with no intermediate code answers none, without a fault")
}

/// <p>Matrix: the routine viewer answers the routine's one row; its intermediate code and its XML
/// are read.</p>
Method TestTheRoutineViewerAnswersItsRowAndForms()
{
    Set tSC = ..Read("explorer.routine", "name=HS.HC.Info.mac&form=int&ns=" _ $Namespace, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the routine is read")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Set tRow = tAnswer.rows.%Get(0)
    Do $$$AssertEquals(tAnswer.rows.%Size() _ " " _ tRow.Kind _ " " _ tRow.Type _ " " _ tRow.Generates, "1 routine mac HS.HC.Info.int", "one routine row naming the code it generates")
    Do $$$AssertEquals($Extract(tAnswer.document.content.%Get(0), 1, 18), "ROUTINE HS.HC.Info", "whose intermediate code is read")
    Set tSC = ..Read("explorer.routine", "name=HS.HC.Info.mac&form=xml&ns=" _ $Namespace, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.document.available, 1: ""), "200 1", "and so is its XML")
}

/// <p>Matrix: a document the namespace does not hold is 404 <code>PORT.NOTFOUND</code>; a malformed
/// name is 400 <code>PORT.VALIDATION</code>; a criterion outside its declaration, by length or by
/// option, is 400 <code>READ.CRITERION</code>.</p>
Method TestRefusalsOverTheWire()
{
    For tCase = $ListBuild("explorer.class", "name=No.Such.Class.cls", "404 PORT.NOTFOUND"), $ListBuild("explorer.class", "name=HS.HC.Info.mac", "400 PORT.VALIDATION"), $ListBuild("explorer.class", "name=A.cls%3BB", "400 PORT.VALIDATION"), $ListBuild("explorer.classes", "system=mayb", "400 READ.CRITERION"), $ListBuild("explorer.classes", "system=yep", "400 READ.CRITERION"), $ListBuild("explorer.classes", "from=2026-09-30", "400 READ.CRITERION"), $ListBuild("explorer.classes", "pattern=a%20b", "400 PORT.VALIDATION") {
        Set tSC = ..Read($List(tCase, 1), $List(tCase, 2) _ "&ns=" _ $Namespace, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2))
    }
}

/// <p>Integration (AC3): each <code>explorer.*.read</code> answered through the agent's dispatcher
/// returns the rows the screen reads, under the same defaults the screen opens on, each field
/// bounded by the context cap, and never the document; an empty call on a viewer's read is refused
/// <code>PORT.VALIDATION</code>.</p>
/// <p>Mutations: copy <code>document</code> into <method>OcuPilot.Screen.Tool.Read.View</method>'s
/// result -&gt; the no-document assertion goes red; seed every declared criterion in
/// <method>OcuPilot.Screen.Tool.Read.View</method>, the omitted ones as empty -&gt; the defaults
/// assertion goes red.</p>
Method TestTheReadToolsAnswerRowsAndNeverTheDocument()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Try {
        For tCase = $ListBuild("explorer.classes.read", "{}", "Name", "{""pattern"":""*"",""system"":""no"",""generated"":""no"",""mapped"":""yes"",""from"":"""",""to"":""""}"), $ListBuild("explorer.routines.read", "{}", "Name", "{""pattern"":""*.mac"",""system"":""no"",""generated"":""yes"",""mapped"":""yes"",""from"":"""",""to"":""""}"), $ListBuild("explorer.class.read", "{""name"":""OcuPilot.Kernel.Agent.Limits.cls""}", "Description", "{""name"":""OcuPilot.Kernel.Agent.Limits.cls"",""form"":""udl""}"), $ListBuild("explorer.routine.read", "{""name"":""HS.HC.Info.mac""}", "Type", "{""name"":""HS.HC.Info.mac"",""form"":""udl""}") {
            Set tUse = {"type": "tool_use", "id": "toolu_explorer"}
            Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName($List(tCase, 1)), "string")
            Do tUse.%Set("input", ##class(%DynamicObject).%FromJSON($List(tCase, 2)))
            Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
            Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the dispatch answers")
            If $$$ISERR(tSC) Continue
            Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, $List(tCase, 1) _ ": without error: " _ $Extract(tResults.%Get(0).%Get("content"), 1, 300))
            Set tContent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
            Do $$$AssertTrue($IsObject(tContent.%Get("rows")) && (tContent.rows.%Size() > 0), $List(tCase, 1) _ ": returns rows")
            Do $$$AssertTrue('tContent.%IsDefined("document"), $List(tCase, 1) _ ": and no document")
            Do $$$AssertEquals($Select($IsObject(tContent.%Get("criteria")): tContent.criteria.%ToJSON(), 1: ""), $List(tCase, 4), $List(tCase, 1) _ ": under the defaults the screen opens on")
            If '$IsObject(tContent.%Get("rows")) Continue
            Set tLongest = 0
            Set tIterator = tContent.rows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If $Length(tRow.%Get($List(tCase, 3))) > tLongest Set tLongest = $Length(tRow.%Get($List(tCase, 3)))
            }
            Do $$$AssertTrue(tLongest <= 1000, $List(tCase, 1) _ ": each " _ $List(tCase, 3) _ " within the field bound: " _ tLongest)
        }
        Set tUse = {"type": "tool_use", "id": "toolu_empty", "input": {}}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.class.read"), "string")
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
        Set tContent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
        Do $$$AssertEquals(tResults.%Get(0).%Get("is_error") _ " " _ tContent.%Get("code"), "1 PORT.VALIDATION", "an empty call on the class viewer's read is refused")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the dispatch leg ran")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertEquals(tRemaining, 0, "the seeded turn is removed")
}

}
