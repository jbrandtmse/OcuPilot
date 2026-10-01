/// <p>Pins Story 18.2's declarations: the Namespaces list and its editor, the three namespace write
/// tools' fields, kinds and pairs, and the Integration row -- <code>osmgmt.namespaces.read</code>
/// answers the rows the list's own read answers (AD-36).</p>
/// <p><b>What it needs from the environment:</b> the compiled registry and an installed instance
/// whose namespaces the admin API lists. Live-safe: it reads and writes nothing.</p>
Class OcuPilot.Test.NamespaceDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.NamespaceList";

Parameter FORM = "OcuPilot.Screen.Descriptor.NamespaceForm";

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

/// <p>The list: OS management's seventh entry over the vendor's namespace <code>LIST</code>, four
/// fields filtered and sorted alike, Name first, one Delete row action and a Create, the classic
/// Namespaces page.</p>
Method TestTheListDeclaresItsFourFieldsAndItsDelete()
{
    Set tClass = ..#LIST
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition"), "os-management:7", "OS management's seventh side-bar entry")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""Namespace.Namespace"",""type"":""LIST""}", "read through the vendor's namespace list")
    For tKey = "fields", "filter" {
        Do $$$AssertEquals(tDeclaration.read.%Get(tKey).%ToJSON(), "[""Name"",""Globals"",""Routines"",""TempGlobals""]", "read." _ tKey _ " is the four fields")
    }
    Do $$$AssertEquals(tDeclaration.read.sort.%ToJSON(), "{""fields"":[""Name"",""Globals"",""Routines"",""TempGlobals""],""default"":""Name"",""direction"":""asc""}", "sorted on the four, Name ascending by default")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the area's two pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind"), "namespace|instance|single", "one namespace per row, instance-scoped, keyed by its name")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "create", "Create")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RowActionIds")), "delete,copy-mappings,enable-interop", "and three row actions, Delete, Story 18.14's Copy mappings and Story 18.15's Enable interoperability")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Namespaces", "the classic list (AD-44)")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "it does not refresh (AD-43)")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/namespaces"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.namespaces"), tClass, "and so does its tool identifier")
    Set tColumns = ""
    Set tIterator = tDeclaration.table.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tColumn.field _ ":" _ tColumn.labelKey _ ":" _ tColumn.kind
    }
    Do $$$AssertEquals(tColumns, "Name:tableColumnName:name,Globals:namespaceColumnGlobals:identifier,Routines:namespaceColumnRoutines:identifier,TempGlobals:namespaceColumnTemp:identifier", "four columns, the databases as identifiers")
}

/// <p>The editor: built, unlisted, carrying the list's own pairs, over the classic editor, and every
/// namespace violation code its form read publishes carries a sentence and names its field.</p>
Method TestTheFormIsBuiltUnlistedWithTheListsPairs()
{
    Set tClass = ..#FORM
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition, "os-management/namespaces/edit|form-page|0", "a form page under the list's route, taking no side-bar position")
    Do $$$AssertEquals(tDeclaration.labelKey, "headerNamespaceLabel", "titled with the existing Namespace label")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the list's own pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.NamespaceEdit", "the classic editor (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "namespace", "over the namespace entity type")
    Do $$$AssertTrue(tDeclaration.suggestedPrompts.%Size() >= 3, "with three suggested prompts")
    Set tCodes = ##class(OcuPilot.Api.Error).NamespaceViolationCodes()
    Set tFields = ""
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a sentence")
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ ##class(OcuPilot.Area.OsMgmt.NamespaceRules).FieldOf($List(tCodes, tI))
    }
    Do $$$AssertEquals(tFields, "Name,Name,Name,Name,Globals,Routines,Globals,Routines,TempGlobals", "each code names its own field")
    Do $$$AssertEquals(##class(OcuPilot.Area.OsMgmt.NamespaceRules).Rules().%Size(), $ListLength(tCodes), "and the form read publishes one rule per code")
}

/// <p>The three tools: the create and the edit admit exactly the three template fields, the create
/// requiring two; the delete admits none, is destructive and bodyless, carries the list's Delete,
/// and fingerprints the three databases. Every write declares <code>%DB_IRISSYS:WRITE</code> beyond
/// the list's pairs, and the delete also <code>%Admin_Secure:USE</code> (AD-8).</p>
Method TestTheToolsDeclareTheirFieldsKindsAndPairs()
{
    Set tScreen = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Set tWrite = $ListBuild("%DB_IRISSYS", "WRITE")
    Set tSecure = $ListBuild("%Admin_Secure", "USE")
    For tCase = $ListBuild("osmgmt.namespaces.create", "Globals,Routines,TempGlobals", "PUT", 1, 0), $ListBuild("osmgmt.namespaces.update", "Globals,Routines,TempGlobals", "PUT", 1, 0), $ListBuild("osmgmt.namespaces.delete", "", "DELETE", 0, 1) {
        Set tName = $List(tCase, 1)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS"), "write|" _ ..#LIST, tName _ " is a write on the Namespaces list")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 2), tName _ " admits exactly its fields")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody"), "Namespace.Namespace|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), tName _ ": endpoint, request type and body")
        Do $$$AssertEquals($ClassMethod(tClass, "Destructive"), $List(tCase, 5), tName _ ": destructive only for the delete")
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
        Set tExpected = tScreen _ $ListBuild(tWrite) _ $Select($List(tCase, 5): $ListBuild(tSecure), 1: "")
        Do $$$AssertTrue(tResolved && (tPairs = tExpected), tName _ ": the list's pairs, then the write pair" _ $Select($List(tCase, 5): " and the application pair", 1: ""))
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.NamespaceCreate).Creates() _ "|" _ ##class(OcuPilot.Screen.Tool.NamespaceCreate).ChangeAction(), "1|created", "the create creates its target (AD-54)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields("namespace")), "Globals,Routines,TempGlobals", "the prohibited set reviews the same three for a create")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("namespace")), "Globals,Routines,TempGlobals", "and for a change")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.NamespaceDelete).FingerprintSubject()), "Globals,Routines,TempGlobals", "the delete fingerprints the three databases (AD-51)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.NamespaceDelete).ScreenActionIds()), "delete", "and carries the list's Delete (AD-53)")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("namespace", "OcuProbe182X"), "ocuprobe182x", "a namespace's id folds case (AD-13)")
    Set tSchema = ##class(OcuPilot.Screen.Tool.NamespaceCreate).InputSchema()
    Do $$$AssertEquals(tSchema.required.%ToJSON(), "[""Name"",""Globals"",""Routines""]", "the create requires the name and the globals and routines databases")
}

/// <p>The Integration row (AD-36): <code>osmgmt.namespaces.read</code> answers exactly the rows the
/// Namespaces list's own read answers, field for field, and the instance's own namespaces are among
/// them.</p>
/// <p>Mutation (Rule 19): drop <code>TempGlobals</code> from the list's read -> the field set and the
/// rows differ and this goes red.</p>
Method TestTheReadToolAnswersTheListsRows()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list's read answers")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.namespaces.read", .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), "the read tool is registered")
    If '$IsObject($Get(tTool)) Quit
    Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers")
    If '$IsObject($Get(tView)) Quit
    Do $$$AssertEquals(tView.fields.%ToJSON(), "[""Name"",""Globals"",""Routines"",""TempGlobals""]", "the tool's fields are the four")
    Do $$$AssertEquals(..Rows(tView.rows), ..Rows(tResult.rows), "the tool answers the list's rows, field for field")
    Set tNames = ..Rows(tView.rows, "Name")
    For tWanted = "%SYS", "USER", $ZConvert($NAMESPACE, "U") {
        Do $$$AssertTrue(("," _ tNames _ ",") [ ("," _ tWanted _ ","), tWanted _ " is listed")
    }
}

/// <p><var>pRows</var> as one sorted comparable string, each row its four fields joined, or with
/// <var>pField</var> that field alone.</p>
ClassMethod Rows(pRows As %DynamicArray, pField As %String = "") As %String
{
    Kill tSorted
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If pField '= "" {
            Set tSorted(tRow.%Get(pField)) = ""
            Continue
        }
        Set tSorted(tRow.%Get("Name") _ "|" _ tRow.%Get("Globals") _ "|" _ tRow.%Get("Routines") _ "|" _ tRow.%Get("TempGlobals")) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
