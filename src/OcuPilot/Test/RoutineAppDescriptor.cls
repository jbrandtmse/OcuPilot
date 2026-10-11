/// <p>Pins Stories 18.31's and 18.33's declarations: the privileged routine applications list and editor descriptors, the
/// list's six role and routine row actions, the three write tools' kinds, port, pairs, permitted and settable fields,
/// mint and id grammar, the entity type and its exact id, the reviewed classification, the three baseline keys, the codes
/// and their sentences, and the Doc DB rule set's unchanged defaults.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class, and the class needs nothing from the environment.</p>
Class OcuPilot.Test.RoutineAppDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.RoutineAppList";

Parameter FORM = "OcuPilot.Screen.Descriptor.RoutineAppForm";

Parameter CREATE = "OcuPilot.Screen.Tool.RoutineAppCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.RoutineAppDelete";

Parameter ERRORS = "OcuPilot.Api.RoutineAppError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The three settings a create or an edit admits, sorted.</p>
Parameter THREE = "Description,Enabled,Resource";

/// <p>The five fields the update tool settles and the kernel reviews for a change: the three settings and the two lists,
/// sorted.</p>
Parameter FIVE = "Description,Enabled,MatchRoles,Resource,Routines";

/// <p>The six row actions the editor's tabs send, beside the list's Delete.</p>
Parameter SIX = "add-application-role,remove-application-role,add-matching-role,remove-matching-role,add-routine,remove-routine";

/// <p>The list is the Web applications area's fifth listed <code>list</code> over the application read, with the area's
/// two pairs and no own pair, a single-name id, Create, six role and routine row actions and a Delete that each carry
/// the own-application rule, three prompts and the classic list page; its read declares the per-row <code>GET</code> that supplies <code>Enabled</code>
/// and <code>Description</code>, and its context and table carry the four fields.</p>
/// <p>Mutation (Rule 19): change the list's <code>sideBarPosition</code> to 6 -- the position leg goes red; drop the
/// <code>rowGet</code> from its read -- the read leg goes red and <class>OcuPilot.Test.RoutineAppRead</class> reads
/// <code>Enabled</code> false on every row.</p>
Method TestTheListIsDeclaredAsTheSpecPlacesIt()
{
    Set tClass = ..#LIST
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "web-applications/routine-applications", "the route")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "web-applications 5", "the Web applications area's fifth entry")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list", "a list")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.Applications.PrivRoutineList", "the classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "webapp.routineapps", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), "routine-application instance", "the routine application entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "id").%Get("kind") _ " " _ $ClassMethod(tClass, "Field", "id").%Get("parts").%Size(), "single 0", "a single-name id")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "the area's two pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", "and no own pair")
    Set tActions = $ClassMethod(tClass, "Field", "rowActions")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "primaryAction").%Get("id") _ " " _ tActions.%Size(), "create 7", "Create, and seven row actions")
    Set tSeen = ""
    Set tRules = ""
    Set tIterator = tActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tAction.%Get("id")
        If tAction.%Get("selfProtection") '= "ocupilot-routine-application" Set tRules = tRules _ tAction.%Get("id") _ " "
    }
    Do $$$AssertEquals(tSeen, ..#SIX _ ",delete", "the six role and routine actions, then Delete")
    Do $$$AssertEquals(tRules, "", "each carrying the own-application rule")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Set tRead = $ClassMethod(tClass, "Read")
    Set tSource = tRead.%Get("source")
    Do $$$AssertEquals(tSource.%Get("port") _ " " _ tSource.%Get("endpoint") _ " " _ tSource.%Get("type"), "admin Security.PrivilegedRoutine LIST", "the applications list read")
    Set tRowGet = tSource.%Get("rowGet")
    Do $$$AssertEquals($IsObject(tRowGet), 1, "which declares a per-row detail call")
    If $IsObject(tRowGet) Do $$$AssertEquals(tRowGet.%Get("key") _ " " _ tRowGet.%Get("param") _ " " _ ##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRowGet.%Get("fields")), "Name name Enabled,Description", "keyed by the name and supplying Enabled and Description, which the list does not carry")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "Name,Enabled,Resource,Description", "the four list fields")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "context").%Get("fields")), "Name,Enabled,Resource,Description", "and the same context")
    Set tColumns = $ClassMethod(tClass, "Field", "table").%Get("columns")
    Do $$$AssertEquals(tColumns.%Get(0).%Get("field") _ ":" _ tColumns.%Get(0).%Get("kind") _ " " _ tColumns.%Size(), "Name:name 4", "the name column first, four columns")
}

/// <p>The side bar lists the screen in the Web applications area after the entry at position 4, derived from the
/// registry, and does not list the editor.</p>
Method TestTheSideBarListsTheScreenAfterTheAreasOtherEntries()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).ListedScreensForArea("web-applications", .tListed)
    Do $$$AssertStatusOK(tSC, "the area's listed screens are read")
    Set tPosition = $ListFind(tListed, ..#LIST)
    Do $$$AssertTrue(tPosition > 1, "the list is listed after another entry")
    Do $$$AssertEquals($ListFind(tListed, ..#FORM), 0, "the editor is not listed")
    Do $$$AssertEquals($ClassMethod($List(tListed, tPosition - 1), "SideBarPosition"), 4, "after the entry at position 4")
}

/// <p>The editor is an unlisted <code>form-page</code> with the list's id and pairs, three prompts, no read of its own
/// and the classic editor's key.</p>
Method TestTheEditorIsAnUnlistedFormPage()
{
    Set tClass = ..#FORM
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "web-applications/routine-applications/edit", "the route is the list's with /edit")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "web-applications 0", "unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "form-page", "a form page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.Applications.PrivRoutine", "the classic editor")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "webapp.routineappform", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "routine-application", "the same entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "id").%Get("kind"), "single", "the same single-name id")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "the list's pairs")
}

/// <p>The create and update are advertised merge writes and the delete an advertised action write, each on
/// <class>OcuPilot.Port.AdminPort</class> over the area's two pairs and no other, each minted by the kernel's
/// <class>OcuPilot.Kernel.Proposal.Mint</class>, naming its target by the name alone with no namespace in its schema;
/// the create admits the three settings and the update those and the two lists, both declaring the classic editor; the delete admits none, declares no
/// classic page, fingerprints the three settings and the two lists and states no consequence.</p>
/// <p>Mutation (Rule 19): drop <code>Resource</code> from the update's <code>PERMITTEDFIELDS</code> -- the field legs go
/// red; leave <code>Namespace</code> in the schema <method>OcuPilot.Screen.Tool.RoutineAppCreate.Described</method>
/// answers -- the schema legs go red.</p>
Method TestTheToolsDeclareTheirKindPortPairsAndFields()
{
    For tClass = ..#CREATE, ..#UPDATE, ..#DELETE {
        Set tName = $Parameter(tClass, "TOOLNAME")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tEntry)
        Do $$$AssertTrue($IsObject($Get(tEntry)), tName _ " is registered")
        Do $$$AssertEquals($Parameter(tClass, "KIND") _ " " _ $ClassMethod(tClass, "Advertised"), "write 1", tName _ " is an advertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.AdminPort", tName _ " reaches the instance through the admin port")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", tName _ " needs the area's two pairs and no other")
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam") _ " " _ $ClassMethod(tClass, "Endpoint"), "Name name Security.PrivilegedRoutine", tName _ " names its target by the application's name")
        Do $$$AssertEquals($ClassMethod(tClass, "MintClass"), "OcuPilot.Kernel.Proposal.Mint", tName _ " is minted by the kernel's mint")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Set tProperties = tSchema.%Get("properties")
        Do $$$AssertEquals(tProperties.%IsDefined("Namespace") _ tProperties.%IsDefined("Name"), "01", tName _ "'s schema carries the name and no namespace")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tSchema.%Get("required")), "Name", tName _ "'s schema requires the name alone")
        Do $$$AssertEquals(tProperties.%IsDefined("MatchRoles") _ tProperties.%IsDefined("Routines"), $Select(tClass = ..#UPDATE: "11", 1: "00"), tName _ "'s schema admits " _ $Select(tClass = ..#UPDATE: "both lists", 1: "neither list"))
    }
    Set tProperties = $ClassMethod(..#UPDATE, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("MatchRoles").%Get("type") _ " " _ tProperties.%Get("Routines").%Get("type"), "array array", "the update admits each list as an array")
    Do $$$AssertTrue($Parameter(..#UPDATE, "DESCRIPTION") [ "complete list", "which its description says is the complete list")
    For tClass = ..#CREATE, ..#UPDATE {
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "%CSP.UI.Portal.Applications.PrivRoutine", $Parameter(tClass, "TOOLNAME") _ " declares the classic editor")
        Set tEnabled = $ClassMethod(tClass, "InputSchema").%Get("properties").%Get("Enabled")
        Do $$$AssertEquals(tEnabled.%Get("type"), "boolean", $Parameter(tClass, "TOOLNAME") _ " types Enabled as the instance reads it")
        Do $$$AssertTrue(tEnabled.%Get("description") [ "true, false, 1, 0, ""1"" or ""0""", $Parameter(tClass, "TOOLNAME") _ " names the six values Enabled admits")
    }
    Do $$$AssertEquals($Parameter(..#DELETE, "CLASSICPAGES") _ "|" _ $Parameter(..#DELETE, "DESTRUCTIVE") _ "|" _ $ListToString($ClassMethod(..#DELETE, "SettableFields")), "|1|", "the delete is destructive, names no classic page and admits no field")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#CREATE, "SettableFields"))), ..#THREE, "the create admits the three settings")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#UPDATE, "SettableFields"))), ..#FIVE, "the update admits the three settings and the two lists")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#UPDATE, "PermittedFields"))), ..#THREE, "which it declares as its permitted fields")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedChangeFields", "routine-application"))), ..#FIVE, "the kernel's reviewed few for a change are the update's five")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedCreateFields", "routine-application"))), ..#THREE, "and for a create the three")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedChangeFields", "docdb-application"))), ..#THREE, "while the Doc DB record's change fields stay the three")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "Creates") _ " " _ $ClassMethod(..#UPDATE, "Creates"), "1 0", "only the create creates")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "SendsBody") _ " " _ $ClassMethod(..#DELETE, "SendsBody"), "1 0", "the delete sends no body")
    Do $$$AssertEquals($Parameter(..#DELETE, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(..#DELETE, "READANSWERS") _ "|" _ $Parameter(..#DELETE, "CONSEQUENCECODE") _ "|" _ $Parameter(..#DELETE, "SCREENACTIONS"), "Description,Enabled,Resource,MatchRoles,Routines|Description,Enabled,Resource,MatchRoles,Routines||delete", "the delete fingerprints the three settings and the two lists, states no consequence and is the list's Delete")
    Do $$$AssertEquals($Parameter(..#CREATE, "RULES") _ " " _ $Parameter(..#UPDATE, "RULES"), "OcuPilot.Area.WebApp.RoutineAppRules OcuPilot.Area.WebApp.RoutineAppRules", "the create and the update apply the routine application rules")
}

/// <p>AD-54: the create names its target as the caller typed it -- the name as written -- and every other tool reads the
/// default, the <code>Name</code> member; a name that is not text names nothing typed.</p>
/// <p>Mutation (Rule 19): drop the <code>TypedId</code> override from <class>OcuPilot.Screen.Tool.RoutineAppCreate</class>
/// -- the inherited Doc DB join answers "" for an argument list with no namespace and this goes red.</p>
Method TestTheCreateNamesItsTargetAsTyped()
{
    Do $$$AssertEquals($ClassMethod(..#CREATE, "TypedId", {"Name": "OcuProbe1831Mixed"}), "OcuProbe1831Mixed", "the create reads the name as typed")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "TypedId", {"Name": 1}) _ $ClassMethod(..#CREATE, "TypedId", {}) _ $ClassMethod(..#CREATE, "TypedId", ""), "", "a name that is not text, or none, names nothing typed")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "TypedId", {"Name": "OcuProbe1831Mixed"}), "OcuProbe1831Mixed", "and the update keeps the default")
}

/// <p>AD-3: the generated field lists hold the three settings classified ordinary for both bodies and the two lists'
/// members classified secret, and the delete has no entry.</p>
/// <p>Mutation (Rule 19): classify <code>Resource</code> secret in the create's <code>ToolFields</code> entry -- the rows
/// leg goes red.</p>
Method TestTheClassificationIsReviewed()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Do tXData.Data.Rewind()
    Set tTools = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tExpected = ##class(OcuPilot.Test.SuperserverDescriptor).Classified("Description,Enabled,Resource", "ordinary") _ "," _ ##class(OcuPilot.Test.SuperserverDescriptor).Classified("Routines[].Db,Routines[].RoutineOrClass,Routines[].Type,MatchRoles[].MatchRole,MatchRoles[].TargetRoles[]", "secret")
    For tTool = "webapp.routineapps.create", "webapp.routineapps.update" {
        Do $$$AssertEquals(..Sorted(##class(OcuPilot.Test.SuperserverDescriptor).Rows(tTools.%Get(tTool))), ..Sorted(tExpected), tTool _ "'s rows are the three settings ordinary and the lists' members secret")
    }
    Do $$$AssertEquals(+$IsObject(tTools.%Get("webapp.routineapps.delete")), 0, "the delete has no field entry")
}

/// <p>AD-13: <code>routine-application</code> is a known entity type whose id is its name, read in any case --
/// <code>OcuProbe1831A</code> and <code>ocuprobe1831a</code> are one key -- and the kernel covers it.</p>
/// <p>Mutation (Rule 19): drop <code>routine-application:foldcase</code> from
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter> -- the one-key leg goes red.</p>
Method TestTheEntityTypeKeepsOneKeyForAnyCase()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("routine-application"), "a known entity type")
    Do $$$AssertTrue($Parameter("OcuPilot.Kernel.EntityRef", "IDRULES") [ "routine-application:foldcase", "which takes foldcase")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("routine-application", "OcuProbe1831A"), ##class(OcuPilot.Kernel.EntityRef).NormalizedId("routine-application", "ocuprobe1831a"), "the two spellings read as one id")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("routine-application", "instance", "OcuProbe1831A", .tUpperKey), "an id builds a key")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("routine-application", "instance", "ocuprobe1831a", .tLowerKey), "and so does its other spelling")
    Do $$$AssertEquals(tUpperKey, tLowerKey, "the two are one target")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PROHIBITED, "CoveredTypes"), "routine-application") > 0, "the prohibited set covers it")
    Do $$$AssertNotEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("routine-application", "OcuProbe1831A"), "OcuProbe1831A", "and it folds the id it is given")
}

/// <p>The delete's card lists what the instance holds and the action removes -- the three settings and the two lists,
/// each removed; a read that answers no precondition field is refused with a problem and no row.</p>
/// <p>Mutation (Rule 19): drop <code>Routines</code> from the delete's <code>READANSWERS</code> -- the card leg goes
/// red.</p>
Method TestTheDeleteCardListsWhatTheActionRemoves()
{
    Set tFresh = {"Description": "probe", "Enabled": true, "Resource": "OcuProbe1831Res", "MatchRoles": [], "Routines": [{"RoutineOrClass": "OcuProbe1831.Routine"}]}
    Do $$$AssertStatusOK($ClassMethod(..#DELETE, "StateDiff", tFresh, .tRows, .tProblem), "the delete's card is built")
    Set tSeen = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.%Get("field") _ "=" _ tRow.%Get("before") _ ":" _ tRow.%Get("removed")
    }
    Do $$$AssertEquals(tSeen, "Description=probe:1,Enabled=true:1,Resource=OcuProbe1831Res:1,MatchRoles=[]:1,Routines=[{""RoutineOrClass"":""OcuProbe1831.Routine""}]:1", "five removed rows")
    Do $$$AssertStatusOK($ClassMethod(..#DELETE, "StateDiff", {"Description": "x"}, .tRows, .tProblem), "a read without the precondition field is answered")
    Do $$$AssertTrue((tProblem '= "") && (tRows.%Size() = 0), "with a problem and no row")
}

/// <p>AD-22: the create and update keys are in the baseline and enabled, the delete's is listed and disabled.</p>
/// <p>Mutation (Rule 19): set <code>webapp.routineapps.delete</code> to true in the baseline -- this goes red.</p>
Method TestTheBaselineKeysShipAsTheSpecSays()
{
    For tCase = $ListBuild("webapp.routineapps.create", 1), $ListBuild("webapp.routineapps.update", 1), $ListBuild("webapp.routineapps.delete", 0) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed at " _ $List(tCase, 2))
    }
}

/// <p>AD-39, DW-2262: every <code>PRIVROUTINE.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches, each field-level code names its field, and
/// <code>PRIVROUTINE.TYPE</code> is the privileged routine family's, not the class access entries'.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Api.RoutineAppError.REASONENABLED</parameter> -- its sentence leg goes
/// red; repoint <method>OcuPilot.Api.Error.ReasonForViolation</method>'s <code>PRIVROUTINE.</code> line at
/// <class>OcuPilot.Api.PctAccessError</class> -- the dispatch legs go red.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 9, "nine codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals($Extract(tCode, 1, 12), "PRIVROUTINE.", tCode _ " is in the family")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), $ListLength(tCodes) - 3, "every code but the envelope's and the two refusals' is a field code")
    For tI = 1:1:$ListLength(tViolations) {
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    Do $$$AssertEquals($Parameter(tClass, "TYPE"), "PRIVROUTINE.TYPE", "the type refusal keeps its code string")
    Do $$$AssertEquals(##class(OcuPilot.Api.PctAccessError).ReasonFor("PRIVROUTINE.TYPE"), "", "the class access entries' class no longer answers it")
    Do $$$AssertEquals(##class(OcuPilot.Api.DocDbAppError).ReasonFor("PRIVROUTINE.NAME"), "", "nor does the Doc DB applications' class answer any of the family")
    Do $$$AssertEquals($ClassMethod(tClass, "ReasonFor", "DOCDBAPP.NAME"), "", "and this class answers none of theirs")
}

/// <p>AD-39, DW-2262: the nine codes keep their published strings, in the order
/// <method>OcuPilot.Api.RoutineAppError.Codes</method> lists them -- the envelope, the six field codes, the web
/// application refusal and the type refusal -- because a client keys on the string, not on the parameter's name.</p>
/// <p>Mutation (Rule 19): change <parameter>OcuPilot.Api.RoutineAppError.WEBAPP</parameter> to
/// <code>PRIVROUTINE.WEBAPPS</code> -- this goes red alone.</p>
Method TestTheCodeStringsAreThePublishedOnes()
{
    Do $$$AssertEquals($ListToString($ClassMethod(..#ERRORS, "Codes")), "PRIVROUTINE.VALIDATION,PRIVROUTINE.NAME,PRIVROUTINE.DESCRIPTION,PRIVROUTINE.ENABLED,PRIVROUTINE.RESOURCE,PRIVROUTINE.ROUTINES,PRIVROUTINE.TAKEN,PRIVROUTINE.WEBAPP,PRIVROUTINE.TYPE", "the codes read as published")
}

/// <p>Story 18.33 (C6): the update tool carries the six row actions, each with the values it admits; the editor's Save
/// admits the three settings alone, so a list in its body is not one of its fields; and the routines code names its
/// field and carries its published sentence.</p>
/// <p>Mutation (Rule 19): drop <code>add-routine</code> from <parameter>OcuPilot.Screen.Tool.RoutineAppUpdate.SCREENACTIONS</parameter>
/// -- this goes red; drop the <code>SaveFields</code> override from <class>OcuPilot.Area.WebApp.RoutineAppSave</class> --
/// this goes red; drop <code>FieldOf</code>'s routines line from <class>OcuPilot.Api.RoutineAppError</class> -- this and
/// <method>TestTheCodesAnswerTheirSentences</method> go red.</p>
Method TestTheSixRowActionsAreTheUpdatesAndTheSaveAdmitsTheThreeSettings()
{
    Set tUpdate = ..#UPDATE
    Do $$$AssertEquals($ListToString($ClassMethod(tUpdate, "ScreenActionIds")), ..#SIX, "the update carries the six row actions")
    Do $$$AssertEquals($ListToString($ClassMethod(tUpdate, "ScreenActionValueNames", "add-application-role")) _ "|" _ $ListToString($ClassMethod(tUpdate, "ScreenActionValueNames", "remove-matching-role")) _ "|" _ $ListToString($ClassMethod(tUpdate, "ScreenActionValueNames", "add-routine")) _ "|" _ $ListToString($ClassMethod(tUpdate, "ScreenActionValueNames", "remove-routine")), "Role|MatchRole,Role|RoutineOrClass,Db,Type|RoutineOrClass,Db,Type", "each admitting the values the tab sends")
    Do $$$AssertEquals($ListToString($ClassMethod(tUpdate, "ScreenActionValueNames", "delete")), "", "and no value on a name it does not carry")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod("OcuPilot.Area.WebApp.RoutineAppSave", "SaveFields", tUpdate))), ..#THREE, "the editor's Save admits the three settings for the update")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod("OcuPilot.Area.WebApp.RoutineAppSave", "SaveFields", ..#CREATE))), ..#THREE, "and for the create")
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod("OcuPilot.Area.WebApp.DocDbAppSave", "SaveFields", "OcuPilot.Screen.Tool.DocDbAppUpdate"))), ..#THREE, "while Doc DB's Save keeps its tool's own list")
    Set tCode = ##class(OcuPilot.Api.RoutineAppError).#ROUTINES
    Do $$$AssertEquals(tCode _ " " _ ##class(OcuPilot.Api.RoutineAppError).FieldOf(tCode), "PRIVROUTINE.ROUTINES Routines", "the routines code names its field")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "Each routine entry names a routine or class, a database this instance defines and its type, Routine or Class.", "and carries its published sentence")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Api.RoutineAppError).ViolationCodes(), tCode) > 0, "which is one of the field codes")
}

/// <p>Rule 31: the Doc DB rule set and Save keep their own error class and their namespace key, and the routine
/// application ones extend them with theirs.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Area.WebApp.DocDbAppRules.NAMESPACED</parameter> to 0 -- the Doc DB legs
/// go red and <class>OcuPilot.Test.DocDbAppWrite</class> loses its namespace rule.</p>
Method TestTheDocDbRuleSetKeepsItsDefaultsAndTheRoutineOnesExtendIt()
{
    Set tDocDb = "OcuPilot.Area.WebApp.DocDbAppRules"
    Set tRoutine = "OcuPilot.Area.WebApp.RoutineAppRules"
    Do $$$AssertEquals($Parameter(tDocDb, "ERRORCLASS") _ " " _ $Parameter(tDocDb, "NAMESPACED"), "OcuPilot.Api.DocDbAppError 1", "Doc DB's rules answer its own codes and are keyed by namespace")
    Do $$$AssertEquals($Parameter(tRoutine, "ERRORCLASS") _ " " _ $Parameter(tRoutine, "NAMESPACED"), "OcuPilot.Api.RoutineAppError 0", "the routine application rules answer theirs and are keyed by the name")
    Do $$$AssertTrue($ClassMethod(tRoutine, "%Extends", tDocDb), "which extend Doc DB's")
    Do $$$AssertTrue($ClassMethod("OcuPilot.Area.WebApp.RoutineAppSave", "%Extends", "OcuPilot.Area.WebApp.DocDbAppSave"), "as the routine application Save extends Doc DB's")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Area.WebApp.DocDbAppSave", "Namespaced") _ $ClassMethod("OcuPilot.Area.WebApp.RoutineAppSave", "Namespaced"), "10", "Doc DB's Save is keyed by namespace and the routine application's is not")
    Do $$$AssertEquals($ClassMethod(tRoutine, "IdOf", "ignored", "OcuProbe1831A") _ "|" _ $ListLength(##class(OcuPilot.Kernel.EntityId).SplitComposite($ClassMethod(tDocDb, "IdOf", "USER", "OcuProbe1830A"))), "OcuProbe1831A|2", "the routine application's id is its name and Doc DB's the composite")
    Do $$$AssertEquals($ClassMethod(tRoutine, "IsName", "") _ $ClassMethod(tRoutine, "IsName", "a") _ $ClassMethod(tRoutine, "IsName", $Translate($Justify("", 64), " ", "n")) _ $ClassMethod(tRoutine, "IsName", $Translate($Justify("", 65), " ", "n")), "0110", "a name is 1 to 64 characters")
}

/// <p><var>pFields</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pFields As %String) As %String
{
    Quit ##class(OcuPilot.Test.SuperserverDescriptor).Sorted(pFields)
}

}
