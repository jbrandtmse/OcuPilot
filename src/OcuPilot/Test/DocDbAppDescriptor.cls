/// <p>Pins Story 18.30's declarations: the Doc DB applications list and editor descriptors, the three write tools'
/// kinds, port, pairs, permitted fields, mint and id grammar, the entity type and its exact id, the reviewed
/// classification, the three baseline keys, and the codes and their sentences.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class, and the class needs nothing from the environment.</p>
Class OcuPilot.Test.DocDbAppDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.DocDbAppList";

Parameter FORM = "OcuPilot.Screen.Descriptor.DocDbAppForm";

Parameter CREATE = "OcuPilot.Screen.Tool.DocDbAppCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.DocDbAppUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.DocDbAppDelete";

Parameter ERRORS = "OcuPilot.Api.DocDbAppError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The three settings a create or an edit admits, sorted.</p>
Parameter THREE = "Description,Enabled,Resource";

/// <p>The list is the Web applications area's fourth listed <code>list</code> over the record read, with the area's
/// two pairs and no own pair, a composite id of namespace and name, Create and Delete, three prompts and the classic
/// list page; its read, context and table carry the five fields.</p>
/// <p>Mutation (Rule 19): change the list's <code>sideBarPosition</code> to 5 -- the position leg goes red.</p>
Method TestTheListIsDeclaredAsTheSpecPlacesIt()
{
    Set tClass = ..#LIST
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "web-applications/docdb-applications", "the route")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "web-applications 4", "the Web applications area's fourth entry")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list", "a list")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.Applications.DocDBList", "the classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "webapp.docdbapps", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), "docdb-application instance", "the Doc DB application entity")
    Set tId = $ClassMethod(tClass, "Field", "id")
    Do $$$AssertEquals(tId.%Get("kind") _ " " _ tId.%Get("parts").%Get(0) _ " " _ tId.%Get("parts").%Get(1), "composite Namespace Name", "a composite id: the namespace, then the name")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "the area's two pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", "and no own pair")
    Set tActions = $ClassMethod(tClass, "Field", "rowActions")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "primaryAction").%Get("id") _ " " _ tActions.%Get(0).%Get("id") _ " " _ tActions.%Size(), "create delete 1", "Create, and Delete alone as a row action")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertEquals(tRead.%Get("source").%Get("port") _ " " _ tRead.%Get("source").%Get("endpoint") _ " " _ tRead.%Get("source").%Get("type"), "admin DocDB LIST", "the records list read")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "Name,Namespace,Enabled,Resource,Description", "the five list fields")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "context").%Get("fields")), "Name,Namespace,Enabled,Resource,Description", "and the same context")
    Set tColumns = $ClassMethod(tClass, "Field", "table").%Get("columns")
    Do $$$AssertEquals(tColumns.%Get(0).%Get("field") _ ":" _ tColumns.%Get(0).%Get("kind") _ " " _ tColumns.%Size(), "Name:name 5", "the name column first, five columns")
}

/// <p>The side bar lists the screen in the Web applications area after the entry at position 3, derived from the
/// registry, and does not list the editor.</p>
Method TestTheSideBarListsTheScreenAfterTheAreasOtherEntries()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).ListedScreensForArea("web-applications", .tListed)
    Do $$$AssertStatusOK(tSC, "the area's listed screens are read")
    Set tPosition = $ListFind(tListed, ..#LIST)
    Do $$$AssertTrue(tPosition > 1, "the list is listed after another entry")
    Do $$$AssertEquals($ListFind(tListed, ..#FORM), 0, "the editor is not listed")
    Do $$$AssertEquals($ClassMethod($List(tListed, tPosition - 1), "SideBarPosition"), 3, "after the entry at position 3")
}

/// <p>The editor is an unlisted <code>form-page</code> with the list's id and pairs, three prompts, no read of its
/// own and the classic editor's key.</p>
Method TestTheEditorIsAnUnlistedFormPage()
{
    Set tClass = ..#FORM
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "web-applications/docdb-applications/edit", "the route is the list's with /edit")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "web-applications 0", "unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "form-page", "a form page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.Applications.DocDB", "the classic editor")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "docdb-application", "the same entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "id").%Get("kind"), "composite", "the same composite id")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "the list's pairs")
}

/// <p>The create and update are advertised merge writes and the delete an advertised action write, each on
/// <class>OcuPilot.Port.DocDbAppPort</class> over the area's two pairs and no other, each minted by
/// <class>OcuPilot.Screen.Tool.MappingMint</class>; the create and update admit the three settings and declare the
/// classic editor; the delete admits none, declares no classic page, fingerprints the three settings and states no
/// consequence.</p>
/// <p>Mutation (Rule 19): drop <code>Resource</code> from the update's <code>PERMITTEDFIELDS</code> -- the field legs
/// go red; drop the push of <code>Namespace</code> onto <code>required</code> in
/// <method>OcuPilot.Screen.Tool.DocDbAppCreate.Described</method> -- the required legs go red.</p>
Method TestTheToolsDeclareTheirKindPortPairsAndFields()
{
    For tClass = ..#CREATE, ..#UPDATE, ..#DELETE {
        Set tName = $Parameter(tClass, "TOOLNAME")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tEntry)
        Do $$$AssertTrue($IsObject($Get(tEntry)), tName _ " is registered")
        Do $$$AssertEquals($Parameter(tClass, "KIND") _ " " _ $ClassMethod(tClass, "Advertised"), "write 1", tName _ " is an advertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.DocDbAppPort", tName _ " reaches the instance through the Doc DB application port")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", tName _ " needs the area's two pairs and no other")
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam") _ " " _ $ClassMethod(tClass, "Endpoint"), "Name name DocDB", tName _ " names its target by the composite id the port splits")
        Do $$$AssertEquals($ClassMethod(tClass, "MintClass"), "OcuPilot.Screen.Tool.MappingMint", tName _ " is minted by the mapping mint")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Set tProperties = tSchema.%Get("properties")
        Do $$$AssertEquals(tProperties.%IsDefined("Namespace") _ tProperties.%IsDefined("Name"), "11", tName _ "'s schema carries the namespace and the name")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tSchema.%Get("required")), "Name,Namespace", tName _ "'s schema requires both")
    }
    For tClass = ..#CREATE, ..#UPDATE {
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "%CSP.UI.Portal.Applications.DocDB", $Parameter(tClass, "TOOLNAME") _ " declares the classic editor")
        Set tEnabled = $ClassMethod(tClass, "InputSchema").%Get("properties").%Get("Enabled")
        Do $$$AssertEquals(tEnabled.%Get("type"), "boolean", $Parameter(tClass, "TOOLNAME") _ " types Enabled as the instance reads it")
        Do $$$AssertTrue(tEnabled.%Get("description") [ "true, false, 1, 0, ""1"" or ""0""", $Parameter(tClass, "TOOLNAME") _ " names the six values Enabled admits")
    }
    Do $$$AssertEquals($Parameter(..#DELETE, "CLASSICPAGES") _ "|" _ $Parameter(..#DELETE, "DESTRUCTIVE") _ "|" _ $ListToString($ClassMethod(..#DELETE, "SettableFields")), "|1|", "the delete is destructive, names no classic page and admits no field")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#CREATE, "SettableFields"))), ..#THREE, "the create admits the three settings")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#UPDATE, "SettableFields"))), ..#THREE, "the update admits the three settings")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#UPDATE, "PermittedFields"))), ..#THREE, "which it declares as its permitted fields")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedChangeFields", "docdb-application"))), ..#THREE, "the kernel's reviewed few for a change are the same")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedCreateFields", "docdb-application"))), ..#THREE, "and for a create")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "Creates") _ " " _ $ClassMethod(..#UPDATE, "Creates"), "1 0", "only the create creates")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "SendsBody") _ " " _ $ClassMethod(..#DELETE, "SendsBody"), "1 0", "the delete sends no body")
    Do $$$AssertEquals($Parameter(..#DELETE, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(..#DELETE, "READANSWERS") _ "|" _ $Parameter(..#DELETE, "CONSEQUENCECODE") _ "|" _ $Parameter(..#DELETE, "SCREENACTIONS"), "Description,Enabled,Resource|Description,Enabled,Resource||delete", "the delete fingerprints the three settings, states no consequence and is the list's Delete")
}

/// <p>AD-54: the create names its target as the caller typed it -- the namespace and name as written, joined -- and
/// every other tool reads the default, the <code>Name</code> member; a part that is not text, or is empty, names
/// nothing typed.</p>
/// <p>Mutation (Rule 19): drop the <code>TypedId</code> override from <class>OcuPilot.Screen.Tool.DocDbAppCreate</class>
/// -- the joined leg goes red, and the agent leg of <class>OcuPilot.Test.DocDbAppWrite</class> stores the name
/// lower-cased.</p>
Method TestTheCreateNamesItsTargetAsTyped()
{
    Set tJoined = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("user", "OcuProbe1830Mixed"))
    Do $$$AssertEquals($ClassMethod(..#CREATE, "TypedId", {"Namespace": "user", "Name": "OcuProbe1830Mixed"}), tJoined, "the create joins the namespace and name as typed")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "TypedId", {"Namespace": "user"}) _ $ClassMethod(..#CREATE, "TypedId", {"Name": "OcuProbe1830Mixed"}) _ $ClassMethod(..#CREATE, "TypedId", {"Namespace": 1, "Name": "x"}), "", "a missing or non-text part names nothing")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.WebAppCreate", "TypedId", {"Name": "/csp/OcuProbe1830"}), "/csp/OcuProbe1830", "a single-part id reads the default: the Name member")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "TypedId", {"Namespace": "user", "Name": "OcuProbe1830Mixed"}), "OcuProbe1830Mixed", "and the update keeps the default")
}

/// <p>AD-3: the generated field lists hold the three rows classified ordinary for both bodies, and the delete has no
/// entry.</p>
/// <p>Mutation (Rule 19): classify <code>Resource</code> secret in the create's <code>ToolFields</code> entry -- the
/// rows leg goes red.</p>
Method TestTheClassificationIsReviewed()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Do tXData.Data.Rewind()
    Set tTools = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tExpected = ##class(OcuPilot.Test.SuperserverDescriptor).Classified("Description,Enabled,Resource", "ordinary")
    For tTool = "webapp.docdbapps.create", "webapp.docdbapps.update" {
        Do $$$AssertEquals(..Sorted(##class(OcuPilot.Test.SuperserverDescriptor).Rows(tTools.%Get(tTool))), ..Sorted(tExpected), tTool _ "'s rows are the three, each ordinary")
    }
    Do $$$AssertEquals(+$IsObject(tTools.%Get("webapp.docdbapps.delete")), 0, "the delete has no field entry")
}

/// <p>AD-13: <code>docdb-application</code> is a known entity type whose composite id reads in any case --
/// <code>[USER, OcuProbe1830A]</code> and <code>[user, ocuprobe1830a]</code> are one key -- and the kernel covers
/// it.</p>
/// <p>Mutation (Rule 19): drop <code>docdb-application:foldcase</code> from
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter> -- the one-key leg goes red.</p>
Method TestTheEntityTypeKeepsOneKeyForAnyCase()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("docdb-application"), "a known entity type")
    Do $$$AssertTrue($Parameter("OcuPilot.Kernel.EntityRef", "IDRULES") [ "docdb-application:foldcase", "which takes foldcase")
    Set tUpper = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("USER", "OcuProbe1830A"))
    Set tLower = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("user", "ocuprobe1830a"))
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("docdb-application", tUpper), ##class(OcuPilot.Kernel.EntityRef).NormalizedId("docdb-application", tLower), "the two spellings read as one id")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("docdb-application", "instance", tUpper, .tUpperKey), "an id builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("docdb-application", "instance", tLower, .tLowerKey), "and so does its other spelling")
    Do $$$AssertEquals(tUpperKey, tLowerKey, "the two are one target")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PROHIBITED, "CoveredTypes"), "docdb-application") > 0, "the prohibited set covers it")
    Do $$$AssertNotEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("docdb-application", tUpper), tUpper, "and it folds the id it is given")
}

/// <p>The delete's card lists the three settings the instance holds, each removed; a read that answers no precondition
/// field is refused with a problem and no row.</p>
/// <p>Mutation (Rule 19): drop <code>Resource</code> from the delete's <code>READANSWERS</code> -- the card leg goes
/// red.</p>
Method TestTheDeleteCardListsWhatTheActionRemoves()
{
    Set tFresh = {"Description": "probe", "Enabled": true, "Resource": "OcuProbe1830Res"}
    Do $$$AssertStatusOK($ClassMethod(..#DELETE, "StateDiff", tFresh, .tRows, .tProblem), "the delete's card is built")
    Set tSeen = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.%Get("field") _ "=" _ tRow.%Get("before") _ ":" _ tRow.%Get("removed")
    }
    Do $$$AssertEquals(tSeen, "Description=probe:1,Enabled=true:1,Resource=OcuProbe1830Res:1", "three removed rows")
    Do $$$AssertStatusOK($ClassMethod(..#DELETE, "StateDiff", {"Description": "x"}, .tRows, .tProblem), "a read without the precondition field is answered")
    Do $$$AssertTrue((tProblem '= "") && (tRows.%Size() = 0), "with a problem and no row")
}

/// <p>AD-22: the create and update keys are in the baseline and enabled, the delete's is listed and disabled.</p>
/// <p>Mutation (Rule 19): set <code>webapp.docdbapps.delete</code> to true in the baseline -- this goes red.</p>
Method TestTheBaselineKeysShipAsTheSpecSays()
{
    For tCase = $ListBuild("webapp.docdbapps.create", 1), $ListBuild("webapp.docdbapps.update", 1), $ListBuild("webapp.docdbapps.delete", 0) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed at " _ $List(tCase, 2))
    }
}

/// <p>AD-39: every <code>DOCDBAPP.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches, and each field-level code names its field. <code>DOCDB.*</code>
/// is another story's family and answers nothing here.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Api.DocDbAppError.REASONENABLED</parameter> -- its sentence leg
/// goes red.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals($Extract(tCode, 1, 9), "DOCDBAPP.", tCode _ " is in the family")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), $ListLength(tCodes) - 1, "every code but the envelope's is a field code")
    For tI = 1:1:$ListLength(tViolations) {
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.DocDbError).ReasonFor("DOCDBAPP.NAME"), "", "the document databases' class answers none of them")
}

/// <p><var>pFields</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pFields As %String) As %String
{
    Quit ##class(OcuPilot.Test.SuperserverDescriptor).Sorted(pFields)
}

}
