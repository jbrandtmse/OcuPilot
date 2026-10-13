/// <p>Pins Story 20.6's host test declarations and Story 20.27's data transformation test declarations (AD-5, AD-8, AD-35, AD-39, AD-44,
/// AD-51, AD-53, AD-54, AD-59, AD-62): the Test tab of a production item and its place in the item's tab strip; the send tool's shape,
/// pairs, governance key and credential redaction; the port's <code>ItemTest</code> endpoint, its pairs, the types it serves and the
/// write it composes; every test code resolving to its sentence; the script form with a quote and a control character kept inside its
/// literals; and the answer a person or a card shows, which never carries an <code>outcome</code> member. The same for the
/// transformation test: its tool, the <code>Transforms</code> endpoint's two types, its codes and its script.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries, an interoperability-enabled <code>USER</code> namespace and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the script legs compile the probe request class of
/// <class>OcuPilot.Test.InteropTestFixture</class> and the probe transformations of
/// <class>OcuPilot.Test.InteropTransformFixture</class> in <code>USER</code>. It starts no production.</p>
Class OcuPilot.Test.InteropTestDescriptor Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter FIXTURE = "OcuPilot.Test.InteropTestFixture";

Parameter TRANSFORMFIXTURE = "OcuPilot.Test.InteropTransformFixture";

Parameter TRANSFORMTOOL = "OcuPilot.Screen.Tool.InteropTransformTest";

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
    Set tSC = $ClassMethod(..#FIXTURE, "Create")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#TRANSFORMFIXTURE, "Create")
}

/// <p>Remove the probe and the fixtures' classes and what they left.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#TRANSFORMFIXTURE, "Remove")
    Set tFixture = $ClassMethod(..#FIXTURE, "Remove")
    If $$$ISOK(tSC) Set tSC = tFixture
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
/// the quote leg goes red; convert every value through <code>DisplayToLogical</code> -- the <code>ErrorStatus</code> leg goes red.</p>
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
    Set tQuery("requestClass") = "Ens.MessageHeader"
    Set tQuery("fields") = {"ErrorStatus": "1"}.%ToJSON()
    Set tText = $ClassMethod(..#PORT, "Snippet", "ItemTest", "SENDTEST", .tQuery).%Get(0).text
    Do $$$AssertTrue((tText [ "Set $Property(tRequest, ""ErrorStatus"") = ""1""") && (tText '[ "ErrorStatusDisplayToLogical"), "a field whose class has no DisplayToLogical is set to the typed value, as the send sets it: " _ tText)
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
/// member's path alone -- the <code>Credential.Value</code> leg goes red; read only object fields -- the JSON text legs go red.</p>
Method TestTheArgumentsAreBoundedAndACredentialMemberIsRedacted()
{
    Set tTool = ..#TOOL
    Set tBound = $Parameter("OcuPilot.Screen.Tool.ExplorerSave", "CHANGEMAXLENGTH")
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
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": "{\"Password\":\"p\"}"})), "Fields", "fields sent as JSON text are read the same way")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": "{\"Text\":\"x\"}"})), "", "and redact nothing when no member names a credential")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "CallSecretNames", {"Fields": "Password=p"})), "Fields", "while text that is not a JSON object is redacted whole")
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


/// <p>The transformation test tool is declared as the spec names it: the composed <code>TRANSFORM</code> read and the
/// <code>TRANSFORMTEST</code> write over the interoperability port's <code>Transforms</code> endpoint, no body, not destructive, the
/// one <code>test</code> action carrying <code>content</code> (an empty one admitted, for the port to refuse on the field), the
/// subject that carries the precondition field and the message, the running consequence, a key that ships <code>true</code>, the
/// dialog's pair and the globals database's WRITE and no routines database, a read composed for the action from the call and for no
/// action from a stored payload, and an agent message of 1 to the card's width.</p>
/// <p>Mutation (Rule 19): set <parameter>DESTRUCTIVE</parameter> to 1, or <parameter>ROUTINESDATABASE</parameter> to 1, on
/// <class>OcuPilot.Screen.Tool.InteropTransformTest</class> -- the shape leg goes red.</p>
Method TestTheTransformToolIsDeclaredAsTheSpecNamesIt()
{
    Set tTool = ..#TRANSFORMTOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), "interop.transforms.test|TRANSFORMTEST|TRANSFORM|" _ ..#PORT _ "|Transforms", "its name, types, port and endpoint")
    Do $$$AssertEquals($ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "Destructive") _ "|" _ $ClassMethod(tTool, "ChangeAction") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $Parameter(tTool, "SCREENVALUES") _ "|" _ $Parameter(tTool, "SCREENEMPTY") _ "|" _ $ListToString($ClassMethod(tTool, "SettableFields")), "0|0|updated|test|test=content|test=content|content", "no body, not destructive, the update action, one screen action with its value")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")) _ "|" _ $ClassMethod(tTool, "PreconditionField") _ "|" _ $ClassMethod(tTool, "Consequence", {}, 0, ""), "Namespace,Name,SourceClass,SourceDocType,SourceKind,TargetClass,TargetDocType,TargetKind,Create,content|SourceClass|INTEROP.TRANSFORM.RUNS", "its subject, its precondition field and its consequence")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tTool), "", "it passes the subject's adequacy rule")
    Do $$$AssertTrue($Parameter(tTool, "ADVERTISED") = 1, "it is advertised")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed("interop.transforms.test", .tListed) _ "|" _ tListed, "1|1", "listed in the governance baseline, enabled")
    Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES") _ "|" _ ##class(%SYS.Portal.Resources).NormalizePage("EnsPortal.Dialog.TestTransform"), "EnsPortal.Dialog.TestTransform|EnsPortal.Dialog.TestTransform", "the classic page it declares is spelled as NormalizePage answers it (AD-44)")
    Do $$$AssertEquals($ClassMethod(tTool, "MintClass"), "OcuPilot.Screen.Tool.InteropTransformMint", "its mint refuses an unsound message before the instance is read")
    Set tCodes = $ClassMethod(tTool, "PreconditionCodes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Do $$$AssertTrue(($ListFind($ClassMethod(..#ERROR, "TransformPreconditionCodes"), tCode) > 0) || (tCode = ##class(OcuPilot.Api.InteropError).#NAMESPACE), tCode _ " is a declared refusal")
    }
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase("USER", .tGlobals, .tReadOnly)
    Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
    Set tText = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
    }
    Do $$$AssertEquals(tResolved _ "|" _ tText, "1|%Ens_Portal:USE,%Ens_Code:READ,%Ens_DTLTest:USE," _ tGlobals _ ":WRITE", "its pairs are the list's, the dialog's, then WRITE on the globals database alone")
    Do $$$AssertEquals($Parameter(tTool, "ROUTINESDATABASE") _ "|" _ $Parameter(tTool, "DATABASEPERMISSION"), "0|WRITE", "and it declares no routines database")
    Kill tQuery
    Do $ClassMethod(tTool, "PortQuery", {"Name": "N.cls", "content": "<a/>"}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("action")) _ "|" _ $Get(tQuery("content")), "TRANSFORMTEST|<a/>", "the read made from the call's arguments is composed for the test")
    Kill tQuery
    Do $ClassMethod(tTool, "PortQuery", {"SourceClass": "Ens.StringRequest", "Namespace": "USER", "content": "<a/>"}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("action")) _ "|" _ $Get(tQuery("namespace")) _ "|" _ $Get(tQuery("content")), "|USER|<a/>", "the read made from the stored payload names the payload's namespace and message and no action")
    Set tSchema = $ClassMethod(tTool, "InputSchema")
    Set tBound = $Parameter("OcuPilot.Screen.Tool.ExplorerSave", "CHANGEMAXLENGTH")
    Do $$$AssertEquals(tSchema.required.%ToJSON() _ "|" _ tSchema.properties.content.type _ "|" _ tSchema.properties.content.maxLength, "[""Name"",""content""]|string|" _ tBound, "the schema requires the transformation and a message within the card's width")
    For tCase = $ListBuild("", 0), $ListBuild("x", 0), $ListBuild($Justify("", tBound), 0), $ListBuild($Justify("", tBound + 1), 1) {
        Do $ClassMethod(tTool, "ArgumentProblem", "N.cls", {"Name": "N.cls", "content": ($List(tCase, 1))}, .tProblem)
        Do $$$AssertEquals((tProblem '= "") _ "", $Select($List(tCase, 1) = "": "1", 1: $List(tCase, 2) _ ""), "a message of " _ $Length($List(tCase, 1)) _ " characters is judged as the card's width says")
    }
    Do $ClassMethod(tTool, "ArgumentProblem", "N.cls", {"Name": "N.cls"}, .tProblem)
    Do $$$AssertTrue(tProblem [ "1 to " _ tBound, "and an absent one is refused")
}

/// <p>The hooks the confirm and a screen action ask of the transformation test: <code>ConfirmProblem</code> judges the message as the
/// mint's <code>ArgumentProblem</code> does, 1 to the card's width, and <code>ScreenActionDelta</code> carries a string
/// <code>content</code> as sent, an empty one included for the port to refuse on the field, and refuses a value of any other type and
/// an absent one.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropTransformTest.ConfirmProblem</method> answer no problem -- the confirm
/// leg goes red; make <method>OcuPilot.Screen.Tool.InteropTransformTest.ScreenActionDelta</method> carry a number -- the screen leg goes
/// red.</p>
Method TestTheTransformToolsConfirmAndScreenHooksJudgeTheMessage()
{
    Set tTool = ..#TRANSFORMTOOL
    Set tBound = $Parameter("OcuPilot.Screen.Tool.ExplorerSave", "CHANGEMAXLENGTH")
    For tCase = $ListBuild("", 1), $ListBuild("x", 0), $ListBuild($Justify("", tBound), 0), $ListBuild($Justify("", tBound + 1), 1) {
        Do $ClassMethod(tTool, "ConfirmProblem", "N.cls", {"Name": "N.cls", "content": ($List(tCase, 1))}, .tProblem)
        Do $$$AssertEquals((tProblem '= "") + 0, $List(tCase, 2), "a confirm of a message of " _ $Length($List(tCase, 1)) _ " characters is judged as the card's width says")
    }
    Do $ClassMethod(tTool, "ScreenActionDelta", "test", {"content": ""}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tArgs.%GetTypeOf("content") _ "|" _ tArgs.content, "|string|", "an empty message is carried to the port, which refuses it on the field")
    Do $ClassMethod(tTool, "ScreenActionDelta", "test", {"content": "<a/>"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tArgs.content, "|<a/>", "a message is carried as sent")
    For tJson = "{""content"":5}", "{}", "{""other"":""x""}" {
        Do $ClassMethod(tTool, "ScreenActionDelta", "test", ##class(%DynamicAbstractObject).%FromJSON(tJson), {}, .tArgs, .tProblem)
        Do $$$AssertTrue(tProblem [ "content", "a value that is not a string is refused: " _ tJson)
    }
}

/// <p>The port serves the <code>Transforms</code> endpoint's two typed calls and its list: the list needs the code pairs alone, the read
/// and the test add the dialog's resource, the test is a test write and a write at all and the read neither, the test is composed and
/// has a script form, and no other endpoint serves either type.</p>
/// <p>Mutation (Rule 19): drop <parameter>DTLTESTPAIR</parameter> from <method>OcuPilot.Port.InteropPort.Pairs</method> -- the pairs leg
/// goes red.</p>
Method TestThePortServesTheTransformsTypesWithTheDialogsPair()
{
    Do $$$AssertEquals($Parameter(..#PORT, "DTLTESTPAIR") _ "|" _ $Parameter(..#PORT, "CODEPAIRS"), "%Ens_DTLTest:USE|%Ens_Portal:USE,%Ens_Code:READ", "the dialog's pair and the code pairs")
    For tType = "LIST", "TRANSFORM", "TRANSFORMTEST" {
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", "Transforms", tType), "Transforms serves " _ tType)
        Set tPairs = $ClassMethod(..#PORT, "Pairs", "Transforms", tType)
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
        }
        Do $$$AssertEquals(tText, "%Ens_Portal:USE,%Ens_Code:READ" _ $Select(tType = "LIST": "", 1: ",%Ens_DTLTest:USE"), tType _ ": its pairs")
    }
    For tType = "ITEM", "STATE", "SENDTEST", "TESTTARGET", "EXPORT" {
        Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", "Transforms", tType), "Transforms does not serve " _ tType)
    }
    For tEndpoint = "Processes", "Rules", "ItemTest", "Items" {
        Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", tEndpoint, "TRANSFORMTEST") && '$ClassMethod(..#PORT, "Serves", tEndpoint, "TRANSFORM"), tEndpoint _ " serves neither")
    }
    Do $$$AssertTrue($ClassMethod(..#PORT, "IsTestWrite", "TRANSFORMTEST") && $ClassMethod(..#PORT, "IsAnyWrite", "TRANSFORMTEST"), "the test is a test write and a write")
    Do $$$AssertTrue('$ClassMethod(..#PORT, "IsTestWrite", "TRANSFORM") && '$ClassMethod(..#PORT, "IsAnyWrite", "TRANSFORM"), "the read is neither")
    Do $$$AssertTrue($Parameter(..#PORT, "COMPOSEDTYPES") [ "Transforms/TRANSFORMTEST", "the test is a composed type")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Transforms", "TRANSFORMTEST") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Transforms", "TRANSFORM") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Transforms", "LIST"), "objectscript||", "the test has a script form and the reads have none")
}

/// <p>Every transformation code resolves to its sentence through <class>OcuPilot.Api.InteropError</class>, as a refused tool call and
/// as a violation; the two formats are the test's preconditions, the content is a violation and not one, and the running consequence
/// is declared as a consequence and in the codes roster.</p>
/// <p>Mutation (Rule 19): drop <code>INTEROP.TRANSFORM.CONTENT</code> from <method>OcuPilot.Api.InteropError.TransformCodes</method> --
/// this goes red.</p>
Method TestEveryTransformCodeResolves()
{
    Set tCodes = $ClassMethod(..#ERROR, "TransformCodes")
    Do $$$AssertEquals($ListToString(tCodes), "INTEROP.TRANSFORM.SOURCEFORMAT,INTEROP.TRANSFORM.TARGETFORMAT,INTEROP.TRANSFORM.CONTENT", "two refusals and a violation")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(..#ERROR, "ReasonFor", tCode)
        Do $$$AssertTrue((tCode [ "INTEROP.TRANSFORM.") && (tReason '= ""), tCode _ ": a code and a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": a refused tool call carries it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": and a violation")
        Do $$$AssertTrue($ListFind($ClassMethod(..#ERROR, "Codes"), tCode) > 0, tCode _ " is in the codes roster")
    }
    Do $$$AssertEquals($ListToString($ClassMethod(..#ERROR, "TransformPreconditionCodes")), "INTEROP.TRANSFORM.SOURCEFORMAT,INTEROP.TRANSFORM.TARGETFORMAT", "the source then the target format are the preconditions, in the order they are checked")
    Set tConsequence = "INTEROP.TRANSFORM.RUNS"
    Do $$$AssertTrue($ListFind($ClassMethod(..#ERROR, "ConsequenceCodes"), tConsequence) > 0, tConsequence _ " is a consequence code")
    Do $$$AssertTrue($ClassMethod(..#ERROR, "ReasonFor", tConsequence) [ "code runs on this instance as you", "and its sentence says the transformation's code runs as the person")
    Do $$$AssertEquals($ClassMethod(..#TRANSFORMTOOL, "Consequence", {}, 0, ""), tConsequence, "the tool's consequence is that code")
    Do $$$AssertTrue($ClassMethod(..#ERROR, "ReasonFor", "INTEROP.TRANSFORM.CONTENT") [ $FNumber($Parameter("OcuPilot.Port.AtelierPort", "MAXIMPORTCHARACTERS"), ","), "the content sentence states the bound the port holds")
}

/// <p>The transformation test's script form (AD-59): an <code>objectscript</code> step that switches to the namespace, parses the
/// message as the source class the way the test does, creates the target for <code>existing</code>, calls <code>Transform</code> by
/// name and renders the target the way the test does; every name and the message are string literals, a quote doubled and a control
/// character spelled as <code>$Char</code>, and no line opens a block it does not close.</p>
/// <p>Mutation (Rule 19): drop the <code>Literal</code> from the message in <method>OcuPilot.Port.InteropPort.TransformSnippet</method>
/// -- the quote leg goes red.</p>
Method TestTheTransformScriptKeepsTheMessageInsideItsLiteral()
{
    Set tFixture = ..#TRANSFORMFIXTURE
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $Parameter(tFixture, "HL7") _ ".cls"
    Set tQuery("content") = "MSH|^~\&|A""B" _ $Char(13) _ "PID|1"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Transforms", "TRANSFORMTEST", .tQuery)
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).kind, 1: ""), "objectscript", "one ObjectScript step")
    Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "EnsLib.HL7.Message"", ""ImportFromString""") && (tText [ "IsMutable = 0") && (tText [ "OcuProbeDtl.Hl7"", ""Transform"", tSource, .tTarget") && (tText [ "OutputToLibraryStream(tStream, tSeparators)"), "it switches, parses, calls Transform and renders the raw view: " _ tText)
    Do $$$AssertTrue(tText [ "MSH|^~\&|A""""B""_$Char(13)_""PID|1", "a quote is doubled and a carriage return is spelled as $Char inside the message's literal")
    Set tOpens = 0
    For tLine = 1:1:$Length(tText, $Char(10)) {
        If $Extract($ZStrip($Piece(tText, $Char(10), tLine), "<>W"), *) = "{" Set tOpens = tOpens + 1
    }
    Do $$$AssertEquals(tOpens, 0, "no line opens a block it does not close")
    Set tQuery("id") = $Parameter(tFixture, "EXISTING") _ ".cls"
    Set tText = $ClassMethod(..#PORT, "Snippet", "Transforms", "TRANSFORMTEST", .tQuery).%Get(0).text
    Do $$$AssertTrue((tText [ "ObjectFromString(.tSource") && (tText [ """%New"")") && (tText [ "%XML.Writer") && (tText '[ "ImportFromString"), "an XML source is read by the XML reader, an existing target is created, and an XML target is written by the XML writer")
    Set tQuery("id") = $Parameter(tFixture, "X12") _ ".cls"
    Set tText = $ClassMethod(..#PORT, "Snippet", "Transforms", "TRANSFORMTEST", .tQuery).%Get(0).text
    Do $$$AssertTrue((tText [ "SegmentTerminator") && (tText '[ "%XML.Writer"), "an X12 target is written with its segment terminator")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "OcuProbeDtl.Missing.cls"
    Set tText = $ClassMethod(..#PORT, "Snippet", "Transforms", "TRANSFORMTEST", .tQuery).%Get(0).text
    Do $$$AssertTrue((tText [ "OcuProbeDtl.Missing"", ""Transform""") && (tText '[ "ImportFromString"), "a transformation the namespace does not hold gives the call alone")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "Transforms", "TRANSFORM", .tQuery).%Size(), 0, "a read has no script")
}

/// <p>What a transformation test shows is <code>{status, sourceClass, targetClass, lines, console, errors}</code> with the lines as text
/// and no <code>outcome</code> member, which the card would read as a SQL answer (AD-39's seventh exception); the card's rows are the
/// transformation, its two classes with their document types and the input with its line ends normalized; and an answer that is not a
/// test's shows nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropTransformTest.WriteOutput</method> add an <code>outcome</code> member
/// -- this goes red.</p>
Method TestTheTransformAnswerNeverCarriesAnOutcome()
{
    Set tWritten = {"status": "done", "sourceClass": "A.B", "targetClass": "C.D", "lines": ["<a>x</a>"], "console": ["w"], "errors": false, "extra": "kept out"}
    Set tOutput = $ClassMethod(..#TRANSFORMTOOL, "WriteOutput", tWritten)
    Do $$$AssertTrue($IsObject(tOutput), "a test's answer is shown")
    If '$IsObject(tOutput) Quit
    Do $$$AssertEquals(tOutput.%ToJSON(), "{""status"":""done"",""sourceClass"":""A.B"",""targetClass"":""C.D"",""lines"":[""<a>x</a>""],""console"":[""w""],""errors"":false}", "its six members, the markup left as the text it is")
    Do $$$AssertTrue('tOutput.%IsDefined("outcome"), "no outcome member")
    Do $$$AssertEquals($ClassMethod(..#TRANSFORMTOOL, "WriteOutput", {"status": "done", "lines": []}), "", "an answer with no console shows nothing")
    Do $$$AssertEquals($ClassMethod(..#TRANSFORMTOOL, "WriteOutput", "text"), "", "and neither does a text")
    Set tFresh = {"Name": "A.B.cls", "SourceClass": "EnsLib.HL7.Message", "SourceDocType": "2.5:ADT_A01", "TargetClass": "Ens.StringResponse", "TargetDocType": ""}
    Do tFresh.%Set("content", "MSH|a" _ $Char(13, 10) _ "PID|1" _ $Char(13) _ "PV1|1")
    Set tSC = $ClassMethod(..#TRANSFORMTOOL, "StateDiff", tFresh, .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tRows.%Size() _ "|" _ tRows.%Get(0).after _ "|" _ tRows.%Get(1).after _ "|" _ tRows.%Get(2).after _ "|" _ tRows.%Get(3).field _ "|" _ tRows.%Get(3).kind, "|4|A.B.cls|EnsLib.HL7.Message (2.5:ADT_A01)|Ens.StringResponse|Input|lines", "the card shows the transformation, its classes and the input")
    Do $$$AssertEquals(tRows.%Get(3).after, "MSH|a" _ $Char(10) _ "PID|1" _ $Char(10) _ "PV1|1" _ $Char(10), "with every line end a line feed")
    Do $ClassMethod(..#TRANSFORMTOOL, "StateDiff", {"Name": "A.B.cls"}, .tRows, .tProblem)
    Do $$$AssertTrue(tProblem [ "did not report", "a read that names no classes is not a card")
}

}
