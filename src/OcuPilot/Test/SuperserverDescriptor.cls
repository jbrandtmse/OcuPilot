/// <p>Pins Story 18.25's declarations (B0, B1, B5): the superservers list and editor descriptors, the three
/// tools' kinds, ports, pairs and permitted fields (never <code>SystemDefault</code>), the entity type and its
/// <code>portbind</code> id rule, the reviewed classification, the three baseline keys, the codes and their
/// sentences, and the kernel's serving-superserver refusal and its pinned sentence.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class.</p>
Class OcuPilot.Test.SuperserverDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.SuperserverList";

Parameter FORM = "OcuPilot.Screen.Descriptor.SuperserverForm";

Parameter CREATE = "OcuPilot.Screen.Tool.SuperserverCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.SuperserverUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.SuperserverDelete";

Parameter ERRORS = "OcuPilot.Api.SuperserverError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The fifteen settings the create and update tools admit, sorted.</p>
Parameter SETTINGS = "Description,EnableCSP,EnableCacheDirect,EnableClients,EnableDataCheck,EnableECP,EnableMirror,EnableNodeJS,EnableSNMP,EnableShadows,EnableSharding,EnableWebLink,Enabled,SSLConfig,SSLSupportLevel";

/// <p>B1, B5: the list is Security's twelfth <code>list</code> over the superservers read, with Security's two
/// pairs and no own pair, a composite id of the port and the bind address, Create and Delete, three prompts and
/// the classic list page; its read, context and table carry the four list fields.</p>
/// <p>Mutation (Rule 19): change the list's <code>sideBarPosition</code> to 13 -- the position leg goes red.</p>
Method TestTheListIsDeclaredAsTheSpecPlacesIt()
{
    Set tClass = ..#LIST
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "security/superservers", "the route")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "security 12", "Security's twelfth listed screen")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list", "a list")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.Servers", "the classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "security.superservers", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), "superserver instance", "the superserver entity")
    Set tId = $ClassMethod(tClass, "Field", "id")
    Do $$$AssertEquals(tId.%Get("kind") _ " " _ ##class(OcuPilot.Test.EncryptionKeyRead).Joined(tId.%Get("parts")), "composite Port,BindAddress", "the composite id")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Security's two pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", "and no own pair")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "primaryAction").%Get("id") _ " " _ $ClassMethod(tClass, "Field", "rowActions").%Get(0).%Get("id") _ " " _ $ClassMethod(tClass, "Field", "rowActions").%Get(0).%Get("selfProtection"), "create delete ", "Create and Delete, the delete with no row-level self-protection rule")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertEquals(tRead.%Get("source").%Get("port") _ " " _ tRead.%Get("source").%Get("endpoint") _ " " _ tRead.%Get("source").%Get("type"), "admin Security.Superserver LIST", "the superservers list read")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "Port,BindAddress,Enabled,SystemDefault", "the four list fields")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "context").%Get("fields")), "Port,BindAddress,Enabled,SystemDefault", "and the same context")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "table").%Get("columns").%Get(0).%Get("field") _ " " _ $ClassMethod(tClass, "Field", "table").%Get("columns").%Get(0).%Get("kind"), "Port name", "the port is the name column")
}

/// <p>B1: the editor is an unlisted <code>form-page</code> with the list's id and pairs, three prompts, no read
/// of its own and the classic editor's key.</p>
Method TestTheEditorIsAnUnlistedFormPage()
{
    Set tClass = ..#FORM
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "security/superservers/edit", "the route is the list's with /edit")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "security 0", "unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "form-page", "a form page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.Server", "the classic editor")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "superserver", "the same entity")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "id").%Get("parts")), "Port,BindAddress", "the same composite id")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, "three prompts")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "the list's pairs")
}

/// <p>B2, B5: the create and update are advertised merge writes and the delete an advertised action write, each
/// on <class>OcuPilot.Port.SuperserverPort</class> over Security's two pairs and no other; the create and
/// update admit the fifteen settings and <b>never <code>SystemDefault</code></b>; the delete admits none and
/// declares no classic page.</p>
/// <p>Mutation (Rule 19): add <code>SystemDefault</code> to the update's <code>PERMITTEDFIELDS</code> -- the
/// settings legs go red.</p>
Method TestTheToolsDeclareTheirKindPortPairsAndFields()
{
    For tClass = ..#CREATE, ..#UPDATE, ..#DELETE {
        Set tName = $Parameter(tClass, "TOOLNAME")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tEntry)
        Do $$$AssertTrue($IsObject($Get(tEntry)), tName _ " is registered")
        Do $$$AssertEquals($Parameter(tClass, "KIND") _ " " _ $ClassMethod(tClass, "Advertised"), "write 1", tName _ " is an advertised write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.SuperserverPort", tName _ " reaches the instance through the superserver port")
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", tName _ " needs Security's two pairs and no other")
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), "Port port", tName _ " names its target by the port")
        Set tProperties = $ClassMethod(tClass, "InputSchema").%Get("properties")
        Do $$$AssertEquals(tProperties.%IsDefined("SystemDefault") _ tProperties.%IsDefined("BindAddress"), "01", tName _ "'s schema carries no SystemDefault and carries the bind address")
        Do $$$AssertEquals($ListFind($ClassMethod(tClass, "SettableFields"), "SystemDefault"), 0, tName _ " settles no SystemDefault")
    }
    For tClass = ..#CREATE, ..#UPDATE {
        Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(tClass, "SettableFields"))), ..Sorted(..#SETTINGS), $Parameter(tClass, "TOOLNAME") _ " admits the fifteen settings")
        Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(tClass, "PermittedFields"))), ..Sorted(..#SETTINGS), "which it declares as its permitted fields")
        Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedChangeFields", "superserver"))), ..Sorted(..#SETTINGS), "the kernel's reviewed few are the same")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "%CSP.UI.Portal.Server", "its classic page is the editor")
    }
    Do $$$AssertEquals(..Sorted($ListToString($ClassMethod(..#PROHIBITED, "PermittedCreateFields", "superserver"))), ..Sorted(..#SETTINGS), "and the create's")
    Do $$$AssertEquals($ClassMethod(..#CREATE, "Creates") _ " " _ $ClassMethod(..#UPDATE, "Creates"), "1 0", "only the create creates")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "SendsBody") _ " " _ $ClassMethod(..#DELETE, "SendsBody"), "1 0", "the delete sends no body")
    Do $$$AssertEquals($ListToString($ClassMethod(..#DELETE, "SettableFields")) _ "|" _ $Parameter(..#DELETE, "CLASSICPAGES") _ "|" _ $Parameter(..#DELETE, "DESTRUCTIVE") _ "|" _ $Parameter(..#DELETE, "FINGERPRINTSUBJECT"), "||1|SystemDefault", "the delete admits no field, names no classic page, is destructive and fingerprints SystemDefault")
}

/// <p>AD-3: the generated field lists hold the sixteen rows classified ordinary for both bodies, and the delete
/// has no entry.</p>
/// <p>Mutation (Rule 19): classify <code>Description</code> secret in the create's <code>ToolFields</code> entry --
/// the rows leg goes red.</p>
Method TestTheClassificationIsReviewed()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Do tXData.Data.Rewind()
    Set tTools = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tExpected = ..Classified(..#SETTINGS _ ",SystemDefault", "ordinary")
    For tTool = "security.superservers.create", "security.superservers.update" {
        Do $$$AssertEquals(..Sorted(..Rows(tTools.%Get(tTool))), ..Sorted(tExpected), tTool _ "'s rows are the sixteen, each ordinary")
    }
    Do $$$AssertEquals($IsObject(tTools.%Get("security.superservers.delete")), 0, "the delete has no field entry")
}

/// <p>AD-13, B5: <code>superserver</code> is a known entity type whose id reads in one spelling -- the port
/// plain decimal, an empty bind address <code>0.0.0.0</code>, the bind address in lower case -- and the kernel
/// covers it.</p>
/// <p>Mutation (Rule 19): answer the id unchanged for <code>portbind</code> in
/// <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> -- the canonical-form legs go red.</p>
Method TestTheEntityTypeCanonicalizesItsId()
{
    Set tSep = $Char(1)
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("superserver"), "a known entity type")
    Do $$$AssertTrue($Parameter("OcuPilot.Kernel.EntityRef", "IDRULES") [ "superserver:portbind", "its rule is portbind")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("superserver", "01985" _ tSep _ "0.0.0.0"), "1985" _ tSep _ "0.0.0.0", "01985 reads 1985")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("superserver", "1985" _ tSep), "1985" _ tSep _ "0.0.0.0", "an empty bind address reads 0.0.0.0")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("superserver", "1985"), "1985" _ tSep _ "0.0.0.0", "an id with no separator reads as [value, empty]")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("superserver", "+1985" _ tSep _ "LOCALHOST"), "1985" _ tSep _ "localhost", "LOCALHOST reads localhost")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PROHIBITED, "CoveredTypes"), "superserver") > 0, "the prohibited set covers it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).Count(), 60, "sixty entity types")
}

/// <p>B5, AD-22: the create and update keys are in the baseline and enabled, the delete's is listed and
/// disabled.</p>
/// <p>Mutation (Rule 19): set <code>security.superservers.delete</code> to true in the baseline -- this goes
/// red.</p>
Method TestTheBaselineKeysShipAsTheSpecSays()
{
    For tCase = $ListBuild("security.superservers.create", 1), $ListBuild("security.superservers.update", 1), $ListBuild("security.superservers.delete", 0) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed at " _ $List(tCase, 2))
    }
}

/// <p>AD-39: every <code>SUPERSERVER.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches; each field-level code names its field, bar the one that
/// names three; the kernel's refusal answers its parameter, names no caller and is the set's thirty-first code;
/// the serving-SSL consequence is the class's.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Api.SuperserverError.REASONPORT</parameter> -- its sentence leg
/// goes red.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 11, "eleven codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), 9, "nine of them are field codes")
    For tI = 1:1:$ListLength(tViolations) {
        If $List(tViolations, tI) = $Parameter(tClass, "SYSTEMONLY") Continue
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    Do $$$AssertEquals($Parameter(..#PROHIBITED, "EFFECTSERVINGSUPERSERVER"), $Parameter(tClass, "SERVESOCUPILOT"), "the kernel's effect is the class's consequence code")
    Set tCode = $Parameter(..#PROHIBITED, "SERVINGSUPERSERVER")
    Do $$$AssertEquals(tCode, "PROHIBITED.SERVINGSUPERSERVER", "the refusal's code")
    Do $$$AssertEquals($ClassMethod(..#PROHIBITED, "ReasonFor", tCode), $Parameter(..#PROHIBITED, "SERVINGSUPERSERVERREASON"), "answers its sentence")
    Do $$$AssertTrue($ZConvert($Parameter(..#PROHIBITED, "SERVINGSUPERSERVERREASON"), "L") '[ "the agent", "which names no caller")
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROHIBITED, "Codes")) _ " " _ $ListFind($ClassMethod(..#PROHIBITED, "Codes"), tCode), "31 31", "the set's thirty-first code")
}

/// <p><var>pFields</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pFields As %String) As %String
{
    For tI = 1:1:$Length(pFields, ",") {
        Set tNames($Piece(pFields, ",", tI)) = ""
    }
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
    }
    Quit tOut
}

/// <p>A tool's field rows as <code>path:class</code>, comma-joined in the entry's order.</p>
ClassMethod Rows(pEntry As %DynamicObject) As %String
{
    If '$IsObject(pEntry) Quit "(no entry)"
    Set tOut = ""
    Set tIterator = pEntry.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("path") _ ":" _ tRow.%Get("class")
    }
    Quit tOut
}

/// <p><var>pFields</var>, comma-separated, each as <code>name:class</code>.</p>
ClassMethod Classified(pFields As %String, pClass As %String) As %String
{
    Set tOut = ""
    For tI = 1:1:$Length(pFields, ",") {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Piece(pFields, ",", tI) _ ":" _ pClass
    }
    Quit tOut
}

}
