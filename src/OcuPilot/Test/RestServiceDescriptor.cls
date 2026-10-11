/// <p>Pins Story 18.32's declarations: the REST API explorer's row action and empty state, the two write tools' kinds,
/// port, pairs, schemas, read and write types, fingerprint subject and consequence, the entity type the kernel covers
/// without an id rule, the two baseline keys, the codes and their sentences, and the port's write pairs.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class; the pair legs read the stock <code>USER</code> and <code>HSCUSTOM</code> database mappings.</p>
Class OcuPilot.Test.RestServiceDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.RestApiList";

Parameter CREATE = "OcuPilot.Screen.Tool.RestServiceCreate";

Parameter DELETE = "OcuPilot.Screen.Tool.RestServiceDelete";

Parameter ERRORS = "OcuPilot.Api.RestServiceError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter PORT = "OcuPilot.Port.MgmntPort";

/// <p>The screen's two pairs, which every tool of it requires first.</p>
Parameter SCREENPAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ";

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

/// <p>The explorer keeps its read, route and pairs, and declares Delete as its one row action with no self-protection,
/// Create as its primary action with none, and the agent's invitation in place of the read-only line in its empty state;
/// its screen context lists the agent's create beside the delete.</p>
/// <p>Mutation (Rule 19): put <code>tableReadOnlyEmptyNext</code> back as <code>emptyNextKey</code> -- the empty-state
/// leg goes red; declare no primary action -- the primary-action and context-tools legs go red.</p>
Method TestTheExplorerDeclaresItsDeleteAndItsInvitation()
{
    Set tClass = ..#LIST
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ " " _ $ClassMethod(tClass, "Field", "toolIdentifier"), "web-applications/rest-apis webapp.restapis", "the route and the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), "rest-service namespace", "the REST service entity in the route's namespace")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), ..#SCREENPAIRS, "the area's two pairs")
    Set tActions = $ClassMethod(tClass, "Field", "rowActions")
    Do $$$AssertEquals(tActions.%Size() _ " " _ tActions.%Get(0).%Get("id") _ " [" _ tActions.%Get(0).%Get("selfProtection") _ "]", "1 delete []", "Delete alone, with no self-protection rule: the instance refuses a web application's row after the click")
    Set tPrimary = $ClassMethod(tClass, "Field", "primaryAction")
    Do $$$AssertEquals(tPrimary.%Get("id") _ " [" _ tPrimary.%Get("selfProtection") _ "]", "create []", "and Create as its primary action, with no self-protection rule: the person's create")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(tClass, .tTools), "the screen's context tools are built")
    Set tWires = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tWire) {
        Set tWires = tWires _ $ListBuild(tWire)
    }
    Do $$$AssertEquals($ListFind(tWires, ##class(OcuPilot.Screen.Tool.Registry).WireName($Parameter(..#CREATE, "TOOLNAME"))) > 0, 1, "which lists the agent's create beside the delete")
    Do $$$AssertEquals($ListFind(tWires, ##class(OcuPilot.Screen.Tool.Registry).WireName($Parameter(..#DELETE, "TOOLNAME"))) > 0, 1, "and the delete")
    Set tTable = $ClassMethod(tClass, "Field", "table")
    Do $$$AssertEquals("[" _ tTable.%Get("emptyNextKey") _ "] " _ tTable.%Get("emptyAgentKey"), "[] restApiListEmptyAgent", "the empty state invites the agent")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertEquals(tRead.%Get("source").%Get("port") _ " " _ tRead.%Get("source").%Get("endpoint") _ " " _ tRead.%Get("source").%Get("type"), "mgmnt Applications LIST", "the read is the management API's explorer list")
}

/// <p>The create is an advertised, non-destructive agent-only create and the delete an advertised, destructive action
/// write that is the explorer's Delete, each on <class>OcuPilot.Port.MgmntPort</class>'s <code>Service</code> endpoint,
/// over the screen's two pairs and <code>%Development:USE</code>, with WRITE on the routines database of the namespace
/// the call names as an argument pair; the create sends the package and the document and reads its absence by the state
/// type, the delete sends no body and reads the service it removes.</p>
/// <p>Mutation (Rule 19): drop <code>%Development</code> from
/// <parameter>OcuPilot.Screen.Tool.RestServiceWrite.WRITERESOURCE</parameter> -- the pairs legs go red; empty the
/// delete's <parameter>PRECONDITIONCODES</parameter> -- the precondition leg goes red.</p>
Method TestTheToolsDeclareTheirKindPortPairsAndFields()
{
    For tClass = ..#CREATE, ..#DELETE {
        Set tName = $Parameter(tClass, "TOOLNAME")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tEntry)
        Do $$$AssertTrue($IsObject($Get(tEntry)), tName _ " is registered")
        Do $$$AssertEquals($Parameter(tClass, "KIND") _ " " _ $ClassMethod(tClass, "Advertised"), "write 1", tName _ " is an advertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), ..#PORT _ " Service Name application", tName _ " reaches the instance through the management API port by the package")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs", "", .tResolved)), ..#SCREENPAIRS _ ",%Development:USE", tName _ " needs the screen's two pairs and the code editors' resource")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "", tName _ " replaces no classic page")
        Do ##class(OcuPilot.Kernel.Scope).Set("USER")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "ArgumentPairs", "", {}, .tResolved)) _ " " _ tResolved, "%DB_USER:WRITE 1", tName _ " requires WRITE on the scope's routines database")
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources("HSCUSTOM", .tRoutine, .tGlobal, .tMapped, .tHomeResolved)
        Set tWanted = $Select(tHomeResolved && (tRoutine '= ""): tRoutine _ ":WRITE", 1: "")
        Do $$$AssertNotEquals(tWanted, "%DB_USER:WRITE", "the install namespace's routines database is not USER's")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "ArgumentPairs", "", {"Namespace": "HSCUSTOM"}, .tResolved)) _ " " _ tResolved, tWanted _ " " _ ''(tHomeResolved && (tRoutine '= "")), tName _ " reads the namespace its stored arguments name instead of the scope's")
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertEquals($ClassMethod(tClass, "MintClass") _ " " _ $Parameter(tClass, "NAMESPACEFIELD"), $Select(tClass = ..#CREATE: "OcuPilot.Screen.Tool.RestServiceCreateMint", 1: "OcuPilot.Kernel.Proposal.Mint") _ " Namespace", tName _ " is minted by its own mint and keeps the namespace in its payload")
    }
    Set tSchema = $ClassMethod(..#CREATE, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("Name").%Get("type") _ " " _ tProperties.%Get("Document").%Get("type") _ " " _ tProperties.%IsDefined("Namespace"), "string object 0", "the create's schema carries the package and the document as an object, and no namespace")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tSchema.%Get("required")), "Name,Document", "and requires both")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties") _ " " _ tProperties.%Size(), "0 5", "it is closed over those two and the agent's three words")
    Set tDelete = $ClassMethod(..#DELETE, "InputSchema")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tDelete.%Get("required")) _ " " _ tDelete.%Get("properties").%Size(), "Name 4", "the delete's schema requires the package alone")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "Creates") _ " " _ $ClassMethod(..#DELETE, "Creates"), "1 0", "only the create creates")
    Do $$$AssertEquals($Parameter(..#CREATE, "CHANGEACTION") _ " " _ $Parameter(..#DELETE, "CHANGEACTION"), "created deleted", "and each declares its change event's action")
    Do $$$AssertEquals($Parameter(..#CREATE, "READTYPE") _ " " _ $Parameter(..#CREATE, "WRITETYPE") _ " " _ $Parameter(..#CREATE, "READBACKFIELDS") _ " " _ $Parameter(..#CREATE, "CONSEQUENCE"), "STATE POST Name RESTSERVICE.CREATE.COMPILES", "the create reads the state, posts, compares the package and states that it compiles")
    Do $$$AssertEquals($Parameter(..#CREATE, "SCREENACTIONS") _ "|" _ $ListToString($ClassMethod(..#CREATE, "SettableFields")), "|Name,Document", "the create is no screen action and sets the package and the document")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "Consequence", {}, 0, ""), "RESTSERVICE.CREATE.COMPILES", "which is the proposal's consequence code")
    Do $$$AssertEquals($Parameter(..#DELETE, "READTYPE") _ " " _ $Parameter(..#DELETE, "WRITETYPE") _ " " _ $ClassMethod(..#DELETE, "SendsBody") _ " " _ $Parameter(..#DELETE, "DESTRUCTIVE") _ " " _ $Parameter(..#DELETE, "SCREENACTIONS"), "SERVICE DELETE 0 1 delete", "the delete reads the service, sends no body, is destructive and is the explorer's Delete")
    Do $$$AssertEquals($Parameter(..#DELETE, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(..#DELETE, "READANSWERS") _ "|" _ $Parameter(..#DELETE, "PRECONDITIONFIELD") _ "|" _ $Parameter(..#DELETE, "PRECONDITIONCODES"), "Name,Namespace|Name,Namespace|Name|RESTSERVICE.DEPLOYED", "it fingerprints the package and the namespace and refuses a deployed service as the fresh read does")
    Do $$$AssertEquals($ListToString($ClassMethod(..#DELETE, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(..#CREATE, "ScreenActionIds")), "delete|", "only the delete is a screen action")
}

/// <p>The create's rules are the port's, in the port's order -- the package, then the document -- and its three classes
/// are held to the code saves' rules, in the specification, dispatch, implementation order: a package in <code>%SYS</code>,
/// or stored in another database, or holding a percent sign, is refused for the first class it reaches.</p>
/// <p>Mutation (Rule 19): drop <code>impl</code> from <parameter>OcuPilot.Screen.Tool.RestServiceCreate.CLASSPARTS</parameter>
/// -- the three-classes leg goes red. (A package's classes share one database, so no input tells the three apart; the
/// roster is what the leg pins.)</p>
Method TestTheCreatesRulesAreThePortsAndTheCodeSaves()
{
    Set tClass = ..#CREATE
    Do $ClassMethod(tClass, "ArgumentProblem", "Bad Name", {"Document": {"swagger": "2.0"}}, .tProblem)
    Do $$$AssertEquals(tProblem, ##class(OcuPilot.Api.RestServiceError).#REASONNAME, "a package that is no package is refused with the port's sentence")
    Do $ClassMethod(tClass, "ArgumentProblem", "OcuProbe1832Z", {"Document": {"swagger": "3.0"}}, .tProblem)
    Do $$$AssertEquals(tProblem, ##class(OcuPilot.Api.RestServiceError).#REASONDOCUMENT, "a document that is not 2.0 with the port's other")
    Do $ClassMethod(tClass, "ArgumentProblem", "OcuProbe1832Z", {"Document": {"swagger": "2.0"}}, .tProblem)
    Do $$$AssertEquals(tProblem, "", "and a package and a document that meet them are not")
    Do $$$AssertEquals($Parameter(tClass, "CLASSPARTS"), "spec,disp,impl", "the three classes a create builds are the specification, the dispatch and the implementation class")
    Do $$$AssertEquals($ClassMethod(tClass, "AgentProblems", "USER", "OcuProbe1832Z"), "", "a free package in USER may be created by the agent")
    Do $$$AssertTrue($ClassMethod(tClass, "AgentProblems", "%SYS", "OcuProbe1832Z") [ "%SYS", "a package in %SYS is refused")
    Do $$$AssertTrue($ClassMethod(tClass, "AgentProblems", "USER", "Ens.OcuProbe1832Z") [ "ENSLIB", "a package stored in another database is refused naming it")
    Do $$$AssertTrue($ClassMethod(tClass, "AgentProblems", "USER", "%OcuProbe1832Z") [ "holds %", "and so is one holding a percent sign")
    Do $$$AssertTrue($ClassMethod(tClass, "AgentProblems", "", "OcuProbe1832Z") [ "namespace", "and a call with no namespace")
}

/// <p>The delete's card names the service it removes, once, as removed; a read that answers nothing leaves it empty.</p>
/// <p>Mutation (Rule 19): drop <code>removed</code> from the delete's <method>StateDiff</method> -- this goes red.</p>
Method TestTheDeleteCardNamesWhatTheActionRemoves()
{
    Do $$$AssertStatusOK($ClassMethod(..#DELETE, "StateDiff", {"Name": "OcuProbe1832Z", "Namespace": "USER", "Implementation": "OcuProbe1832Z.impl"}, .tRows, .tProblem), "the delete's card is built")
    Do $$$AssertEquals(tRows.%ToJSON() _ "|" _ tProblem, "[{""field"":""Name"",""before"":""OcuProbe1832Z"",""after"":"""",""removed"":true}]|", "one removed row, the package")
}

/// <p>AD-13: <code>rest-service</code> is a known entity type whose id the instance resolves in any case and which
/// therefore keeps no id rule, so the id is the package as typed, and the kernel covers it.</p>
/// <p>Mutation (Rule 19): add <code>rest-service:foldcase</code> to <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter>
/// -- the as-typed leg goes red.</p>
Method TestTheEntityTypeKeepsTheIdAsTyped()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("rest-service"), "a known entity type")
    Do $$$AssertTrue($Parameter("OcuPilot.Kernel.EntityRef", "IDRULES") '[ "rest-service", "which takes no id rule")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("rest-service", "OcuProbe1832Z"), "OcuProbe1832Z", "so its id is the package as typed")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PROHIBITED, "CoveredTypes"), "rest-service") > 0, "and the prohibited set covers it")
}

/// <p>AD-22: the create's key is in the baseline and enabled, the delete's is listed and disabled.</p>
/// <p>Mutation (Rule 19): set <code>webapp.restapis.delete</code> to true in the baseline -- this goes red.</p>
Method TestTheBaselineKeysShipAsTheSpecSays()
{
    For tCase = $ListBuild("webapp.restapis.create", 1), $ListBuild("webapp.restapis.delete", 0) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed at " _ $List(tCase, 2))
    }
}

/// <p>AD-39: every <code>RESTSERVICE.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches; each field-level code names its field, and the envelope's and the
/// delete's refusal name none.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Api.RestServiceError.REASONDEPLOYED</parameter> -- its sentence leg
/// goes red.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals($Extract(tCode, 1, 12), "RESTSERVICE.", tCode _ " is in the family")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), $ListLength(tCodes) - 2, "every code but the envelope's and the delete's refusal is a field code")
    For tI = 1:1:$ListLength(tViolations) {
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    Do $$$AssertEquals($ClassMethod(tClass, "FieldOf", "RESTSERVICE.DEPLOYED") _ "|" _ $ClassMethod(tClass, "FieldOf", "RESTSERVICE.VALIDATION"), "|", "the refusal and the envelope name no field")
    Do $$$AssertEquals(##class(OcuPilot.Api.DocDbAppError).ReasonFor("RESTSERVICE.NAME"), "", "another family's class answers none of them")
}

/// <p>The port declares the pair its writes add, <code>%Development:USE</code>, and WRITE on the routines database of
/// the namespace a write names (AD-8).</p>
/// <p>Mutation (Rule 19): change <parameter>OcuPilot.Port.MgmntPort.WRITEPAIRS</parameter> -- this goes red.</p>
Method TestThePortDeclaresItsWritePairs()
{
    Do $$$AssertEquals($Parameter(..#PORT, "WRITEPAIRS") _ "|" _ $Parameter(..#PORT, "PAIRS"), "%Development:USE|" _ ..#SCREENPAIRS, "the added pair and the screen's two")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(..#PORT, "WritePairs", "USER")), "%Development:USE,%DB_USER:WRITE", "its write pairs for USER are the added pair and WRITE on its routines database")
}

}
