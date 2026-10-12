/// <p>Pins Story 20.6's host test declarations (AD-5, AD-8, AD-35, AD-39, AD-44, AD-51, AD-53, AD-54, AD-59, AD-62): the Test tab of a
/// production item and its place in the item's tab strip; the send tool's shape, pairs, governance key and credential redaction; the
/// port's <code>ItemTest</code> endpoint, its pairs, the types it serves and the write it composes; every test code resolving to its
/// sentence; the script form with a quote and a control character kept inside its literals; and the answer a person or a card shows,
/// which never carries an <code>outcome</code> member.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries, an interoperability-enabled <code>USER</code> namespace and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the script leg compiles the probe request class of
/// <class>OcuPilot.Test.InteropTestFixture</class> in <code>USER</code>. It starts no production.</p>
Class OcuPilot.Test.InteropTestDescriptor Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter FIXTURE = "OcuPilot.Test.InteropTestFixture";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter TAB = "OcuPilot.Screen.Descriptor.InteropItemTestTab";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemTestSend";

Parameter ERROR = "OcuPilot.Api.InteropError";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropTestDescriptor compiles the probe classes in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so it will not run.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURE, "Create")
}

/// <p>Remove the probe and the fixture's classes and what they left.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Remove")
    Set tRemoved = $ClassMethod(..#PROBE, "Remove")
    Quit $Select($$$ISERR(tSC): tSC, 1: tRemoved)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The tab is declared as the spec places it: a built detail screen under Production items with the item's route id as its one
/// criterion, the classic Testing Service page's pairs with <code>%Ens_TestingService:USE</code> as its own, the Test action as its
/// primary and its one row action, no refresh, seven table columns, three prompts and the port's <code>ItemTest</code> list; it is
/// the item strip's seventh tab; and it passes the registry.</p>
/// <p>Mutation (Rule 19): change the tab's <code>position</code> to 6 -- the strip leg goes red.</p>
Method TestTheTabIsDeclaredAsTheSpecPlacesIt()
{
    Set tSC = $ClassMethod(..#TAB, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration reads")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.area _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.built _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.parentScope, "interoperability/productions/items/test|interoperability|detail|1|namespace|interoperability/productions/items", "a built detail screen under Production items")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON(), "production-item|composite|[""RequestClass"",""Field""]", "its entity type and the composite its rows name")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON() _ "|" _ tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_TestingService"",""permission"":""USE""}]|[{""resource"":""%Ens_TestingService"",""permission"":""USE""}]", "the Testing Service page's pairs, and its own the one the menu does not hold")
    Do $$$AssertEquals(tDeclaration.refreshes _ "|" _ tDeclaration.refreshRates.%Size(), "0|0", "it does not refresh")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Size() _ tDeclaration.rowActions.%Get(0).id, "EnsPortal.TestingService|interop.itemtest|test|1test", "its classic page, tool identifier, primary action and its one row action")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "interop|ItemTest|LIST", "read through the interop port's ItemTest endpoint")
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Size() _ "|" _ tDeclaration.read.criteria.fields.%Get(0).param, "1|item", "one criterion, the item")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Production"",""Item"",""RequestClass"",""Kind"",""Field"",""Type"",""Required"",""MaxLength"",""Values"",""Secret""]", "its rows carry the ten fields the matrix names")
    Do $$$AssertEquals(tDeclaration.table.columns.%Size() _ "|" _ tDeclaration.suggestedPrompts.%Size(), "7|3", "seven columns and three prompts")
    Do $$$AssertEquals(tDeclaration.tab.group _ "|" _ tDeclaration.tab.position _ "|" _ tDeclaration.tab.labelKey, "interoperability/productions/items/document|7|serverFlagTest", "it is the item strip's seventh tab")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read passes the registry")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so do its criteria")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown(tDeclaration.entityType), "its entity type is in the kernel's vocabulary")
}

/// <p>The send tool declares what the spec names: the item test endpoint, its read and write types, the screen action and its two
/// values, no body, the not-destructive flag, the change action, the fingerprint subject and the consequence; it passes the subject's
/// adequacy rule, is advertised, is listed in the governance baseline enabled, and its pairs are the tab's, then WRITE on the
/// namespace's globals database and no routines database.</p>
/// <p>Mutation (Rule 19): set <code>interop.itemtest.send</code> <code>false</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- the key leg goes red; set <parameter>ROUTINESDATABASE</parameter> to 1 on the
/// tool -- the declaration leg goes red.</p>
Method TestTheSendToolIsDeclaredAsTheSpecNamesIt()
{
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), "interop.itemtest.send|SENDTEST|TESTTARGET|" _ ..#PORT _ "|ItemTest", "its name, types, port and endpoint")
    Do $$$AssertEquals($ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "ChangeAction") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $Parameter(tTool, "SCREENVALUES"), "0|0|updated|test|test=requestClass:fields", "no body, not destructive, the updated action, the screen's test and its two values")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")) _ "|" _ $ClassMethod(tTool, "Consequence", {}, 0, ""), "Namespace,Production,Name,Type,Enabled,State,Testing,RequestClass,Kind,Fields|INTEROP.TEST.SENDS", "its subject and its consequence")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tTool), "", "it passes the subject's adequacy rule")
    Do $$$AssertTrue($Parameter(tTool, "ADVERTISED") = 1, "it is advertised")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed("interop.itemtest.send", .tListed) _ "|" _ tListed, "1|1", "listed in the governance baseline, enabled")
    Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES") _ "|" _ ##class(%SYS.Portal.Resources).NormalizePage("EnsPortal.Dialog.TestingService"), "EnsPortal.Dialog.TestingService|EnsPortal.Dialog.TestingService", "the classic page it declares is spelled as NormalizePage answers it (AD-44)")
    Set tCodes = $ClassMethod(tTool, "PreconditionCodes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Do $$$AssertTrue(($ListFind($ClassMethod(..#ERROR, "TestPreconditionCodes"), tCode) > 0) || ($ListFind($ClassMethod(..#ERROR, "ItemPreconditionCodes"), tCode) > 0) || (tCode = ##class(OcuPilot.Api.InteropError).#NAMESPACE), tCode _ " is a declared refusal")
    }
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase("USER", .tGlobals, .tReadOnly)
    Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
    Set tText = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
    }
    Do $$$AssertEquals(tResolved _ "|" _ tText, "1|%Ens_Portal:USE,%Ens_TestingService:USE," _ tGlobals _ ":WRITE", "its pairs are the tab's, then WRITE on the globals database alone")
    Do $$$AssertEquals($Parameter(tTool, "ROUTINESDATABASE") _ "|" _ $Parameter(tTool, "DATABASEPERMISSION"), "0|WRITE", "and it declares the globals database's WRITE and no routines database")
    Kill tQuery
    Do $ClassMethod(tTool, "PortQuery", {"Name": "N", "RequestClass": "A.B", "Fields": {"Text": "x"}}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("action")) _ "|" _ $Get(tQuery("requestClass")) _ "|" _ $Get(tQuery("fields")), "SENDTEST|A.B|{""Text"":""x""}", "the read made from the call's arguments is composed for the send")
    Set tSchema = $ClassMethod(tTool, "InputSchema")
    Do $$$AssertEquals(tSchema.required.%ToJSON() _ "|" _ tSchema.properties.%Get("Fields").type, "[""Name"",""Production"",""RequestClass"",""Fields""]|object", "the schema requires the item, the class and the fields")
}

/// <p>The port serves the endpoint the spec names with the tab's pairs: <code>ItemTest</code> joins the endpoint roster after the
/// business partners, serves the list, the composed read and the send and no other type, its pairs are
/// <parameter>TESTPAIRS</parameter>, the send is the one write that is a test write and a write at all, and it is composed.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_TestingService:USE</code> from <parameter>TESTPAIRS</parameter> -- the pairs leg goes red;
/// set <parameter>TESTWAIT</parameter> to 600 -- the wait leg goes red.</p>
Method TestThePortServesTheItemTestEndpointWithTheTestingServicePairs()
{
    Do $$$AssertEquals($ListFind($ClassMethod(..#PORT, "Endpoints"), "ItemTest") _ "|" _ $Piece($Parameter(..#PORT, "ENDPOINTS"), ",", *), $ListLength($ClassMethod(..#PORT, "Endpoints")) _ "|ItemTest", "the roster ends with the endpoint")
    Do $$$AssertEquals($Parameter(..#PORT, "TESTPAIRS"), "%Ens_Portal:USE,%Ens_TestingService:USE", "the Testing Service page's pairs")
    Do $$$AssertEquals($ClassMethod(..#PORT, "TestWait"), 15, "a test waits at most AD-62's 15 seconds")
    For tType = "LIST", "TESTTARGET", "SENDTEST" {
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", "ItemTest", tType), "it serves " _ tType)
    }
    For tType = "ITEM", "STATE", "START", "ENABLE", "TRANSFORM", "EXPORT" {
        Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", "ItemTest", tType), "it does not serve " _ tType)
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", "Items", "SENDTEST") && '$ClassMethod(..#PORT, "Serves", "Productions", "SENDTEST"), "no other endpoint serves the send")
    For tType = "LIST", "SENDTEST" {
        Set tPairs = $ClassMethod(..#PORT, "Pairs", "ItemTest", tType)
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
        }
        Do $$$AssertEquals(tText, "%Ens_Portal:USE,%Ens_TestingService:USE", tType _ ": its pairs")
    }
    Do $$$AssertTrue($ClassMethod(..#PORT, "IsTestWrite", "SENDTEST") && $ClassMethod(..#PORT, "IsAnyWrite", "SENDTEST"), "the send is a test write and a write")
    Do $$$AssertTrue('$ClassMethod(..#PORT, "IsTestWrite", "TESTTARGET") && '$ClassMethod(..#PORT, "IsAnyWrite", "TESTTARGET") && '$ClassMethod(..#PORT, "IsTestWrite", "ENABLE"), "the composed read and an item write are not")
    Do $$$AssertTrue($Parameter(..#PORT, "COMPOSEDTYPES") [ "ItemTest/SENDTEST", "the send is a composed type")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "ItemTest", "SENDTEST") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "ItemTest", "LIST") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "ItemTest", "TESTTARGET"), "objectscript||", "the send has a script form and the reads have none")
}

/// <p>Every test code resolves to its sentence through <class>OcuPilot.Api.InteropError</class>, as a refused tool call and as a
/// violation; the six refusals are the test's preconditions, the three violations are not, and the sending consequence is declared as
/// a consequence.</p>
/// <p>Mutation (Rule 19): drop <code>INTEROP.TEST.SECRET</code> from <method>OcuPilot.Api.InteropError.TestCodes</method> -- this goes
/// red.</p>
Method TestEveryTestCodeResolves()
{
    Set tCodes = $ClassMethod(..#ERROR, "TestCodes")
    Do $$$AssertEquals($ListLength(tCodes), 8, "three violations and five refusals")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(..#ERROR, "ReasonFor", tCode)
        Do $$$AssertTrue((tCode [ "INTEROP.TEST.") && (tReason '= ""), tCode _ ": a code and a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": a refused tool call carries it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": and a violation")
    }
    Set tPre = $ClassMethod(..#ERROR, "TestPreconditionCodes")
    Do $$$AssertEquals($ListToString(tPre), "INTEROP.PRODUCTION.NOTRUNNING,INTEROP.TEST.DISABLED,INTEROP.TEST.TARGETTYPE,INTEROP.TEST.TARGETDISABLED,INTEROP.TEST.REQUESTTYPE,INTEROP.TEST.SECRET", "the production-not-running refusal and the five test refusals, in the order they are checked")
    For tCode = "INTEROP.TEST.FIELD", "INTEROP.TEST.VALUE", "INTEROP.TEST.REQUEST" {
        Do $$$AssertTrue($ListFind(tCodes, tCode) && '$ListFind(tPre, tCode), tCode _ " is a violation, not a refusal")
    }
    Set tConsequence = "INTEROP.TEST.SENDS"
    Do $$$AssertTrue($ListFind($ClassMethod(..#ERROR, "ConsequenceCodes"), tConsequence) > 0, tConsequence _ " is a consequence code")
    Do $$$AssertTrue($ClassMethod(..#ERROR, "ReasonFor", tConsequence) [ "real message", "and its sentence says the test sends a real message")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Consequence", {}, 0, ""), tConsequence, "the tool's consequence is that code")
    Do $$$AssertEquals($ListFind($ClassMethod(..#ERROR, "Codes"), "INTEROP.TEST.FIELD") > 0, 1, "and the codes roster holds the violations")
}

/// <p>The script form (AD-59): an <code>objectscript</code> step that switches to the namespace, builds the request from the fields
/// it is given, validates and saves it, and calls the testing service by the item's name; every name and value is a string literal,
/// a quote doubled and a control character spelled as <code>$Char</code>, so nothing the query carries runs as code, and no line opens
/// a block it does not close. A document class is its text imported.</p>
/// <p>Mutation (Rule 19): drop the <code>Literal</code> from the value in <method>OcuPilot.Port.InteropPort.TestSnippet</method> --
/// the quote leg goes red.</p>
Method TestTheScriptKeepsEveryValueInsideItsLiteral()
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $Parameter(..#PROBE, "PRODUCTION") _ $Char(1) _ "Op ""Q"""
    Set tQuery("requestClass") = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tQuery("fields") = {"Text": ("say ""hi""" _ $Char(9) _ "now"), "Count": "5", "Address.City": "Berlin"}.%ToJSON()
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "ItemTest", "SENDTEST", .tQuery)
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).kind, 1: ""), "objectscript", "one ObjectScript step")
    Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "SendTestRequest(") && (tText [ "%ValidateObject()") && (tText [ "%Save()"), "it switches, validates, saves and sends: " _ tText)
    Do $$$AssertTrue(tText [ "SendTestRequest(""Op """"Q"""""", tRequest", "the item's name is the call's first literal, its quote doubled")
    Do $$$AssertTrue(tText [ "say """"hi""""""_$Char(9)_""now""", "a quote is doubled and a control character is spelled as $Char inside the value's literal")
    Do $$$AssertTrue((tText [ "tPart1") && (tText [ """City"""), "a serial field is reached along its path, through its own object")
    Set tOpens = 0
    For tLine = 1:1:$Length(tText, $Char(10)) {
        If $Extract($ZStrip($Piece(tText, $Char(10), tLine), "<>W"), *) = "{" Set tOpens = tOpens + 1
    }
    Do $$$AssertEquals(tOpens, 0, "no line opens a block it does not close")
    Set tQuery("requestClass") = $Parameter(..#FIXTURE, "DOCUMENTCLASS")
    Set tQuery("fields") = {"content": ("MSH|^~\&|A" _ $Char(13) _ "PID|1")}.%ToJSON()
    Set tText = $ClassMethod(..#PORT, "Snippet", "ItemTest", "SENDTEST", .tQuery).%Get(0).text
    Do $$$AssertTrue((tText [ "ImportFromString") && (tText [ """_$Char(13)_""") && (tText '[ "%ValidateObject"), "a document is its text imported, a carriage return spelled as $Char")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "ItemTest", "TESTTARGET", .tQuery).%Size(), 0, "a read has no script")
}

/// <p>The arguments are judged as the spec says: the class is 1 to 255 characters, the fields an object of text values within the
/// JSON bound, and a screen's fields are JSON text of an object within the import bound; the card shows the class and the fields; and
/// a call naming a member like a credential has its <code>Fields</code> redacted, whatever the member's path.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropItemTestSend.CallSecretNames</method> test the last segment of a
/// member's path alone -- the <code>Credential.Value</code> leg goes red.</p>
Method TestTheArgumentsAreBoundedAndACredentialMemberIsRedacted()
{
    Set tTool = ..#TOOL
    Set tBound = $Parameter(tTool, "FIELDSBOUND")
    Set tOk = {"RequestClass": "A.B", "Fields": {"Text": "x"}}
    Do $ClassMethod(tTool, "ArgumentProblem", "", tOk, .tProblem)
    Do $$$AssertEquals(tProblem, "", "a class and text fields are sound")
    ; a $List serializes an object, so each case is its JSON text, parsed at the call
    For tCase = $ListBuild("{""RequestClass"":"""",""Fields"":{}}", "class"), $ListBuild("{""RequestClass"":""A.B""}", "an object of text values"), $ListBuild("{""RequestClass"":""A.B"",""Fields"":{""Count"":5}}", "text values"), $ListBuild("{""RequestClass"":""A.B"",""Fields"":{""Text"":""" _ $Translate($Justify("", tBound + 1), " ", "x") _ """}}", "characters of JSON") {
        Do $ClassMethod(tTool, "ArgumentProblem", "", ##class(%DynamicObject).%FromJSON($List(tCase, 1)), .tProblem)
        Do $$$AssertTrue(tProblem [ $List(tCase, 2), "refused: " _ $List(tCase, 2) _ ": " _ tProblem)
    }
    Set tValues = {"requestClass": "A.B"}
    Do tValues.%Set("fields", "{""Text"":""x""}")
    Do $ClassMethod(tTool, "ScreenActionDelta", "test", tValues, {}, .tArgs, .tScreenProblem)
    Do $$$AssertEquals(tScreenProblem _ "|" _ $Select($IsObject($Get(tArgs)): tArgs.RequestClass _ tArgs.Fields.Text, 1: ""), "|A.Bx", "the screen's text becomes the call's arguments")
    Do tValues.%Set("fields", "[1]")
    Do $ClassMethod(tTool, "ScreenActionDelta", "test", tValues, {}, .tArgs, .tScreenProblem)
    Do $$$AssertTrue(tScreenProblem [ "JSON object", "a screen's fields that are not an object are refused")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": {"Text": "x", "Count": "5"}})), "", "ordinary members redact nothing")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": {"Text": "x", "Password": "p"}})), "Fields", "a credential member redacts Fields")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": {"Login.Password": "p"}})), "Fields", "and so does one inside an embedded object")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": {"Credential.Value": "p"}})), "Fields", "and one under an embedded object that is named like a credential, as the port refuses it")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": {"Address.City": "Berlin"}})), "", "while an embedded object's ordinary member redacts nothing")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", "text")), "", "an input that is not an object redacts nothing")
    Set tFresh = {"RequestClass": "A.B", "Kind": "object"}
    Do tFresh.%Set("Fields", "{""Text"":""x""}")
    Set tSC = $ClassMethod(tTool, "StateDiff", tFresh, .tRows, .tDiffProblem)
    Do $$$AssertEquals(tRows.%Size() _ "|" _ tRows.%Get(0).field _ "|" _ tRows.%Get(1).field _ "|" _ tDiffProblem, "2|RequestClass|Fields|", "the card shows the request class and the fields, and nothing else")
}

/// <p>What a test shows is <code>{status, sessionId, responseClass, lines, errors}</code> with the lines as text and no
/// <code>outcome</code> member, which the card would read as a SQL answer (AD-39's seventh exception); an answer that is not a test's
/// shows nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropItemTestSend.WriteOutput</method> add an <code>outcome</code> member
/// -- this goes red.</p>
Method TestTheAnswerNeverCarriesAnOutcome()
{
    Set tWritten = {"status": "done", "sessionId": "12", "responseClass": "Ens.StringResponse", "lines": ["StringValue: echo:<b>x</b>"], "errors": false, "extra": "kept out"}
    Set tOutput = $ClassMethod(..#TOOL, "WriteOutput", tWritten)
    Do $$$AssertTrue($IsObject(tOutput), "a test's answer is shown")
    If '$IsObject(tOutput) Quit
    Do $$$AssertEquals(tOutput.%ToJSON(), "{""status"":""done"",""sessionId"":""12"",""responseClass"":""Ens.StringResponse"",""lines"":[""StringValue: echo:<b>x</b>""],""errors"":false}", "its five members, the markup left as the text it is")
    Do $$$AssertTrue('tOutput.%IsDefined("outcome"), "no outcome member")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteOutput", {"status": "done"}), "", "an answer with no lines shows nothing")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteOutput", "text"), "", "and neither does a text")
}

}
