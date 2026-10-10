/// <p>Pins Story 18.26's declarations: the managed file transfer connections list and editor descriptors, the four
/// tools' kinds, ports, pairs, permitted fields (never <code>Service</code> on an edit) and the revoke's
/// precondition, the entity type and its exact id, the reviewed classification, the four baseline keys, and the
/// codes and their sentences.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class.</p>
Class OcuPilot.Test.MftConnectionDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.MftConnectionList";

Parameter FORM = "OcuPilot.Screen.Descriptor.MftConnectionForm";

Parameter CREATE = "OcuPilot.Screen.Tool.MftConnectionCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.MftConnectionUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.MftConnectionDelete";

Parameter REVOKE = "OcuPilot.Screen.Tool.MftConnectionRevoke";

Parameter ERRORS = "OcuPilot.Api.MftConnectionError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The five fields a create admits, sorted.</p>
Parameter FIVE = "ApplicationName,SSLConfiguration,Service,URL,Username";

/// <p>The four fields an edit admits, sorted: not <code>Service</code>.</p>
Parameter FOUR = "ApplicationName,SSLConfiguration,URL,Username";

/// <p>The list is Security's thirteenth <code>list</code> over the connections read, with Security's two pairs and
/// no own pair, a single id, Create, Delete and Revoke token, three prompts and the classic list page; its read,
/// context and table carry the three list fields.</p>
/// <p>Mutation (Rule 19): change the list's <code>sideBarPosition</code> to 12 -- the position leg goes red.</p>
Method TestTheListIsDeclaredAsTheSpecPlacesIt()
{
    Set tClass = ..#LIST
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "security/mft-connections", "the route")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "security 13", "Security's thirteenth listed screen")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list", "a list")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.MFT.ConnectionList", "the classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "security.mftconnections", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), "mft-connection instance", "the connection entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "id").%Get("kind"), "single", "a single id: the connection's name")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Security's two pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", "and no own pair")
    Set tActions = $ClassMethod(tClass, "Field", "rowActions")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "primaryAction").%Get("id") _ " " _ tActions.%Get(0).%Get("id") _ " " _ tActions.%Get(1).%Get("id"), "create delete revoke-token", "Create, Delete and Revoke token")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertEquals(tRead.%Get("source").%Get("port") _ " " _ tRead.%Get("source").%Get("endpoint") _ " " _ tRead.%Get("source").%Get("type"), "admin Security.MFT LIST", "the connections list read")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "Name,Service,IsAuthorized", "the three list fields")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "context").%Get("fields")), "Name,Service,IsAuthorized", "and the same context")
    Set tColumns = $ClassMethod(tClass, "Field", "table").%Get("columns")
    Do $$$AssertEquals(tColumns.%Get(0).%Get("field") _ ":" _ tColumns.%Get(0).%Get("kind") _ " " _ tColumns.%Get(1).%Get("kind") _ " " _ tColumns.%Get(2).%Get("kind"), "Name:name text text", "the name column, then two text columns")
}

/// <p>The editor is an unlisted <code>form-page</code> with the list's id and pairs, three prompts, no read of its
/// own and the classic editor's key.</p>
Method TestTheEditorIsAnUnlistedFormPage()
{
    Set tClass = ..#FORM
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "security/mft-connections/edit", "the route is the list's with /edit")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "security 0", "unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "form-page", "a form page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.MFT.Connection", "the classic editor")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "mft-connection", "the same entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "the list's pairs")
}

/// <p>The create and update are advertised merge writes and the delete and revoke advertised action writes, each
/// on <class>OcuPilot.Port.MftPort</class> over Security's two pairs and no other; the create admits the five
/// fields and the update the four, <b>never <code>Service</code></b>; the create and update declare the classic
/// editor and the delete and revoke no classic page; the revoke reads the composed <code>STATE</code> and names its
/// precondition.</p>
/// <p>Mutation (Rule 19): add <code>Service</code> to the update's <code>PERMITTEDFIELDS</code> -- the field legs go
/// red.</p>
Method TestTheToolsDeclareTheirKindPortPairsAndFields()
{
    For tClass = ..#CREATE, ..#UPDATE, ..#DELETE, ..#REVOKE {
        Set tName = $Parameter(tClass, "TOOLNAME")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tEntry)
        Do $$$AssertTrue($IsObject($Get(tEntry)), tName _ " is registered")
        Do $$$AssertEquals($Parameter(tClass, "KIND") _ " " _ $ClassMethod(tClass, "Advertised"), "write 1", tName _ " is an advertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.MftPort", tName _ " reaches the instance through the connection port")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", tName _ " needs Security's two pairs and no other")
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), "Name connection", tName _ " names its target by the connection's name")
    }
    For tClass = ..#CREATE, ..#UPDATE {
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "%CSP.UI.Portal.MFT.Connection", $Parameter(tClass, "TOOLNAME") _ " declares the classic editor")
    }
    For tClass = ..#DELETE, ..#REVOKE {
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES") _ "|" _ $Parameter(tClass, "DESTRUCTIVE") _ "|" _ $ListToString($ClassMethod(tClass, "SettableFields")), "|1|", $Parameter(tClass, "TOOLNAME") _ " is destructive, names no classic page and admits no field")
    }
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#CREATE, "SettableFields"))), ..#FIVE, "the create admits the five fields")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#UPDATE, "SettableFields"))), ..#FOUR, "the update admits the four, never Service")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#UPDATE, "PermittedFields"))), ..#FOUR, "which it declares as its permitted fields")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedChangeFields", "mft-connection"))), ..#FOUR, "the kernel's reviewed few for a change are the same")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedCreateFields", "mft-connection"))), ..#FIVE, "and for a create the five")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "Creates") _ " " _ $ClassMethod(..#UPDATE, "Creates"), "1 0", "only the create creates")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "SendsBody") _ " " _ $ClassMethod(..#DELETE, "SendsBody") _ " " _ $ClassMethod(..#REVOKE, "SendsBody"), "1 0 0", "the delete and the revoke send no body")
    Do $$$AssertEquals($Parameter(..#DELETE, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(..#DELETE, "CONSEQUENCECODE") _ "|" _ $Parameter(..#DELETE, "SCREENACTIONS"), "ApplicationName|MFT.DELETE|delete", "the delete fingerprints the client it removes and states its consequence")
    Do $$$AssertEquals($Parameter(..#REVOKE, "READTYPE") _ " " _ $Parameter(..#REVOKE, "WRITETYPE") _ "|" _ $Parameter(..#REVOKE, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(..#REVOKE, "PRECONDITIONCODES") _ "|" _ $Parameter(..#REVOKE, "CONSEQUENCECODE") _ "|" _ $Parameter(..#REVOKE, "SCREENACTIONS"), "STATE REVOKE|ApplicationName,IsAuthorized|MFT.TOKEN.NONE|MFT.REVOKE|revoke-token", "the revoke reads the composed state, fingerprints the authorization and names its precondition")
    Do $$$AssertEquals($ListToString($ClassMethod(..#REVOKE, "PreconditionCodes")), $Parameter(..#ERRORS, "TOKENNONE"), "the precondition code is the error class's")
    Set tProperties = $ClassMethod(..#CREATE, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%IsDefined("Name") _ tProperties.%IsDefined("Service") _ tProperties.%IsDefined("ApplicationName"), "111", "the create's schema carries the name and the fields")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "InputSchema").%Get("properties").%IsDefined("Service"), 0, "the update's schema carries no Service")
}

/// <p>AD-3: the generated field lists hold the five rows classified ordinary for both bodies, and the delete and
/// the revoke have no entry.</p>
/// <p>Mutation (Rule 19): classify <code>Username</code> secret in the create's <code>ToolFields</code> entry -- the
/// rows leg goes red.</p>
Method TestTheClassificationIsReviewed()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Do tXData.Data.Rewind()
    Set tTools = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tExpected = ##class(OcuPilot.Test.SuperserverDescriptor).Classified("Service,URL,SSLConfiguration,Username,ApplicationName", "ordinary")
    For tTool = "security.mftconnections.create", "security.mftconnections.update" {
        Do $$$AssertEquals(..Sorted(##class(OcuPilot.Test.SuperserverDescriptor).Rows(tTools.%Get(tTool))), ..Sorted(tExpected), tTool _ "'s rows are the five, each ordinary")
    }
    Do $$$AssertEquals(+$IsObject(tTools.%Get("security.mftconnections.delete")) _ +$IsObject(tTools.%Get("security.mftconnections.revoketoken")), "00", "the delete and the revoke have no field entry")
}

/// <p>AD-13: <code>mft-connection</code> is a known entity type whose id is kept exactly -- <code>OcuMftProbeA</code>
/// and <code>ocumftprobea</code> stay two ids -- and the kernel covers it.</p>
/// <p>Mutation (Rule 19): give <code>mft-connection</code> a <code>foldcase</code> rule in
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter> -- the exactness leg goes red.</p>
Method TestTheEntityTypeKeepsItsIdExactly()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("mft-connection"), "a known entity type")
    Do $$$AssertEquals(+($Parameter("OcuPilot.Kernel.EntityRef", "IDRULES") [ "mft-connection:"), 0, "which has no id rule")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("mft-connection", "OcuMftProbeA"), "OcuMftProbeA", "OcuMftProbeA reads as written")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("mft-connection", "ocumftprobea"), "ocumftprobea", "and ocumftprobea reads as written")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("mft-connection", "instance", "OcuMftProbeA", .tUpper), "an id builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("mft-connection", "instance", "ocumftprobea", .tLower), "and so does its lower-case spelling")
    Do $$$AssertNotEquals(tUpper, tLower, "the two are two targets")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PROHIBITED, "CoveredTypes"), "mft-connection") > 0, "the prohibited set covers it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).Count(), 64, "sixty-four entity types")
}

/// <p>The delete's card lists the four settings the prohibited set reviews, each removed, the client
/// configuration's name among them and not <code>Service</code> (AD-10); the revoke's lists the token leaving its
/// authorized state; a read that answers no precondition field is refused with a problem and no row.</p>
/// <p>Mutation (Rule 19): drop <code>ApplicationName</code> from the delete's <code>REMOVALROWS</code> -- the
/// delete leg goes red.</p>
Method TestTheCardsListWhatTheActionsRemove()
{
    Set tFresh = {"Service": "Box", "URL": "https://h.invalid/", "SSLConfiguration": "OcuMftProbeClientTLS", "Username": "u@h.invalid", "ApplicationName": "OcuMftProbeAApp", "IsAuthorized": "Authorized"}
    Do $$$AssertStatusOK($ClassMethod(..#DELETE, "StateDiff", tFresh, .tRows, .tProblem), "the delete's card is built")
    Set tSeen = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.%Get("field") _ "=" _ tRow.%Get("before") _ ":" _ tRow.%Get("removed")
    }
    Do $$$AssertEquals(tSeen, "URL=https://h.invalid/:1,SSLConfiguration=OcuMftProbeClientTLS:1,Username=u@h.invalid:1,ApplicationName=OcuMftProbeAApp:1", "four removed rows, the client configuration's name among them")
    Do $$$AssertStatusOK($ClassMethod(..#REVOKE, "StateDiff", tFresh, .tRows, .tProblem), "the revoke's card is built")
    Do $$$AssertEquals(tRows.%Size() _ " " _ tRows.%Get(0).%Get("field") _ " " _ tRows.%Get(0).%Get("before") _ " " _ tRows.%Get(0).%Get("removed"), "1 AccessToken Authorized 1", "one row, the token leaving its authorized state")
    For tTool = ..#DELETE, ..#REVOKE {
        Do $$$AssertStatusOK($ClassMethod(tTool, "StateDiff", {"Service": "Box"}, .tRows, .tProblem), tTool _ " answers a read without its precondition field")
        Do $$$AssertTrue((tProblem '= "") && (tRows.%Size() = 0), tTool _ " refuses it with a problem and no row")
    }
}

/// <p>AD-22: the create and update keys are in the baseline and enabled, the delete's and the revoke's are listed
/// and disabled.</p>
/// <p>Mutation (Rule 19): set <code>security.mftconnections.delete</code> to true in the baseline -- this goes
/// red.</p>
Method TestTheBaselineKeysShipAsTheSpecSays()
{
    For tCase = $ListBuild("security.mftconnections.create", 1), $ListBuild("security.mftconnections.update", 1), $ListBuild("security.mftconnections.delete", 0), $ListBuild("security.mftconnections.revoketoken", 0) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed at " _ $List(tCase, 2))
    }
}

/// <p>AD-39: every <code>MFT.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches; each field-level code names its field; the token refusal is
/// the sentence the spec publishes.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Api.MftConnectionError.REASONURL</parameter> -- its sentence leg
/// goes red.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 9, "nine codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), 7, "seven of them are field codes")
    For tI = 1:1:$ListLength(tViolations) {
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    Do $$$AssertEquals($Parameter(tClass, "TOKENNONE") _ "|" _ $Parameter(tClass, "REASONTOKENNONE"), "MFT.TOKEN.NONE|This connection holds no access token to revoke.", "the token refusal and its published sentence")
}

/// <p><var>pFields</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pFields As %String) As %String
{
    Quit ##class(OcuPilot.Test.SuperserverDescriptor).Sorted(pFields)
}

}
