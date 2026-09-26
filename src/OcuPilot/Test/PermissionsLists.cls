/// <p>The Roles, Resources and Services lists (Story 6.2): each descriptor's declaration against the
/// grammar, the classic-link rule, the registry and the Permissions area's pair set; each read's
/// fields against the raw LIST row <class>OcuPilot.Port.AdminPort</class> answers; each read over
/// the wire as the configured test principal (<class>OcuPilot.Test.Http</class>), whole and at a cap
/// of one; and each derived read tool, which answers the route's rows narrowed by the context cap.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code>, and both the test principal and
/// the process running this class holding <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>: the key-set and tool tests call the port in process. It issues reads
/// only and creates nothing; the pair set's denials are
/// <class>OcuPilot.Test.WireSecurityRead</class>'s.</p>
Class OcuPilot.Test.PermissionsLists Extends %UnitTest.TestCase
{

/// <p>The screen read route's prefix.</p>
Parameter READPATH = "/api/ocupilot/screens/";

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

/// <p>The three screens as <code>$ListBuild(descriptor, route, tool, side-bar position, entity type,
/// classic page, read fields as JSON, a boolean field every row carries)</code>.</p>
ClassMethod Screens() As %List
{
    Set tScreens = ""
    Set tScreens = tScreens _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.RoleList", "permissions/roles", "permissions.roles", 2, "role", "%CSP.UI.Portal.Roles", "[""Name"",""Description"",""CreatedBy"",""EscalationOnly""]", "EscalationOnly"))
    Set tScreens = tScreens _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.ResourceList", "permissions/resources", "permissions.resources", 3, "resource", "%CSP.UI.Portal.Resources", "[""Name"",""Description"",""PublicPermission"",""ResourceType"",""AllowDelete""]", "AllowDelete"))
    Set tScreens = tScreens _ $ListBuild($ListBuild("OcuPilot.Screen.Descriptor.ServiceList", "permissions/services", "permissions.services", 4, "service", "%CSP.UI.Portal.Services", "[""Name"",""Enabled"",""Public"",""AuthenticationMethods"",""AllowedConnections"",""Description"",""HttpOnlyCookies"",""TwoFactorEnabled""]", "Enabled"))
    Quit tScreens
}

/// <p>Request <var>pTool</var>'s read at <var>pMaxRows</var> as the test principal. <var>pAnswer</var>
/// is the parsed body, or <code>""</code>, and a body that does not parse is a failed assertion.</p>
Method Read(pTool As %String, pMaxRows As %Integer, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#READPATH _ pTool _ "/read?maxRows=" _ pMaxRows, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .pHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Do $$$AssertTrue($IsObject(pAnswer), pTool _ ": the body parses as JSON")
    Quit tSC
}

/// <p>The first row of <var>pRows</var> whose <code>Name</code> is <var>pName</var>, or
/// <code>""</code>.</p>
ClassMethod RowNamed(pRows As %DynamicArray, pName As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Name = pName {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>The keys of <var>pRow</var>, in order, as a JSON array.</p>
ClassMethod KeysOf(pRow As %DynamicObject) As %String
{
    Set tKeys = []
    Set tIterator = pRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Quit tKeys.%ToJSON()
}

/// <p>What is wrong with <var>pRows</var>, or <code>""</code>: every row carries a non-empty string
/// <code>Name</code> and a JSON boolean <var>pBoolean</var>. The key set is not checked here, because
/// the read projects every row onto the declared fields;
/// <method>TestEachReadsFieldsAreTheLiveRowsWholeKeySet</method> holds the declaration to the raw
/// row.</p>
ClassMethod RowShapeProblem(pRows As %DynamicArray, pBoolean As %String) As %String
{
    Set tBad = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.%GetTypeOf("Name") '= "string") || (tRow.Name = "") {
            Set tBad = "row " _ tIndex _ " has no Name string"
        } ElseIf tRow.%GetTypeOf(pBoolean) '= "boolean" {
            Set tBad = tRow.Name _ " has a " _ pBoolean _ " that is " _ tRow.%GetTypeOf(pBoolean)
        }
        If tBad '= "" Quit
    }
    Quit tBad
}

/// <p>Each descriptor passes the read grammar and the classic-link rule; its route and tool
/// identifier resolve to it; its classic page is a class compiled on this instance under the
/// declaration's own case (AD-44); it is the declared side-bar entry of the Permissions area, on its
/// entity type and at instance scope, with no detail call, no action (the Roles list's Create
/// aside), no refresh and no secret field; its context fields are its read fields; its pair set is the Users list's set in the
/// Users list's order; and the Permissions area covers it.</p>
/// <p>Mutation: lower-case <code>classicPage</code> in
/// <class>OcuPilot.Screen.Descriptor.ResourceList</class> -&gt; its classic-page and compiled-class
/// assertions go red.</p>
Method TestEachListIsDeclaredAsThePermissionsAreaEntryItReplaces()
{
    Set tScreens = ..Screens()
    For tI = 1:1:$ListLength(tScreens) {
        Set tCase = $List(tScreens, tI)
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read and table are the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", tClass _ ": and it links out to nothing")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute($List(tCase, 2)), tClass, tClass _ ": the route resolves to it")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($List(tCase, 3)), tClass, tClass _ ": and so does its tool identifier")

        Set tPage = $ClassMethod(tClass, "ClassicPage")
        Do $$$AssertEquals(tPage, $List(tCase, 6), tClass _ ": the classic page is the vendor's own list")
        Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId(tPage)), tClass _ ": which is a compiled class on this instance, found under the declaration's own case")

        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "permissions", tClass _ ": in the Permissions area")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), $List(tCase, 4), tClass _ ": at its side-bar position")
        Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "list", tClass _ ": on the list archetype")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "EntityTypes")), $List(tCase, 5), tClass _ ": on its one entity type")
        Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", tClass _ ": at instance scope")
        Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "single", tClass _ ": keyed by its name alone")
        Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, tClass _ ": and it does not refresh")
        Do $$$AssertEquals(tDeclaration.read.source.%GetTypeOf("rowGet"), "unassigned", tClass _ ": it declares no detail call")
        Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), $List(tCase, 7), tClass _ ": its read fields are the key set this class holds the live LIST row to")
        Do $$$AssertEquals(tDeclaration.context.fields.%ToJSON(), tDeclaration.read.fields.%ToJSON(), tClass _ ": its context fields are its read fields")
        Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, tClass _ ": with no secret field")
        Do $$$AssertEquals(tDeclaration.read.sort.default _ ":" _ tDeclaration.read.sort.direction, "Name:asc", tClass _ ": sorting by name ascending")
        If tClass = "OcuPilot.Screen.Descriptor.RoleList" {
            ; Story 8.3: the Roles list's Create opens the Role form, so its empty state invites
            ; the agent instead of naming a next step.
            Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "create", tClass _ ": its primary action is Create")
            ; Story 9.3: Delete, and the four value actions the role editor sends.
            Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RowActionIds")), "delete,add-granted-role,remove-granted-role,set-resource-grant,remove-resource-grant", tClass _ ": and its row actions are Delete and the role editor's four")
            Do $$$AssertEquals(tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey, "|roleListEmptyAgent", tClass _ ": so its empty state invites the agent")
        } ElseIf tClass = "OcuPilot.Screen.Descriptor.ResourceList" {
            ; Story 8.4: the Resources list's Create opens the resource editor, so its empty state
            ; invites the agent instead of naming a next step.
            Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "create", tClass _ ": its primary action is Create")
            ; Story 9.3: Delete.
            Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RowActionIds")), "delete", tClass _ ": and its one row action is Delete")
            Do $$$AssertEquals(tDeclaration.table.emptyNextKey _ "|" _ tDeclaration.table.emptyAgentKey, "|resourceListEmptyAgent", tClass _ ": so its empty state invites the agent")
        } Else {
            Do $$$AssertEquals(tDeclaration.table.emptyNextKey, "tableReadOnlyEmptyNext", tClass _ ": its empty state names what to do next")
            Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, tClass _ ": because it declares no action")
        }
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Admin_Secure"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", tClass _ ": its pair set is the Users list's, in the same order")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("permissions", $ClassMethod(tClass, "PrivilegePairs")), "", tClass _ ": and the Permissions area covers it")
    }
}

/// <p>Each descriptor's read fields are the raw LIST row's whole key set, in the vendor's order: every
/// row <class>OcuPilot.Port.AdminPort</class> answers for the endpoint, before the read projects it,
/// carries exactly those keys. <class>OcuPilot.Test.ScreenRead</class> holds declared fields only to
/// a subset of the live keys, so a field left out or reordered is caught here.</p>
/// <p>Mutation: swap <code>Description</code> and <code>CreatedBy</code> in
/// <class>OcuPilot.Screen.Descriptor.RoleList</class>'s read and context fields -&gt; the roles key-set
/// assertion goes red.</p>
Method TestEachReadsFieldsAreTheLiveRowsWholeKeySet()
{
    Set tScreens = ..Screens()
    For tI = 1:1:$ListLength(tScreens) {
        Set tCase = $List(tScreens, tI)
        Set tClass = $List(tCase, 1)
        Set tRead = $ClassMethod(tClass, "Read")
        Set tEndpoint = tRead.source.endpoint
        Kill tQuery
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(tEndpoint, "LIST", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tClass _ ": the live " _ tEndpoint _ " LIST answers")
        If $$$ISERR(tSC) Continue
        Set tHasRows = $IsObject(tAnswer) && tAnswer.%IsA("%Library.DynamicArray") && (tAnswer.%Size() > 0)
        Do $$$AssertTrue(tHasRows, tClass _ ": with rows to hold the declared fields to")
        If 'tHasRows Continue
        Set tBad = ""
        Set tIterator = tAnswer.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If ..KeysOf(tRow) '= tRead.fields.%ToJSON() Set tBad = "row " _ tIndex _ " carries " _ ..KeysOf(tRow)
            If tBad '= "" Quit
        }
        Do $$$AssertEquals(tBad, "", tClass _ ": every raw row carries exactly the read fields " _ tRead.fields.%ToJSON() _ ", in that order")
        Do $$$AssertEquals(tRead.fields.%ToJSON(), $List(tCase, 7), tClass _ ": which are the fields this class pins")
    }
}

/// <p>Matrix "Roles" -- the whole read answers the four declared fields, untruncated, with the
/// <code>%All</code> row among its rows and a boolean <code>EscalationOnly</code> on every one.</p>
/// <p>Mutation: point <class>OcuPilot.Screen.Descriptor.RoleList</class>'s endpoint at
/// <code>Security.User</code> -&gt; the <code>%All</code> and row-shape assertions go red.</p>
Method TestTheRolesListReadsOverTheWire()
{
    Set tSC = ..Read("permissions.roles", 1000, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Set tFields = $List($List(..Screens(), 1), 7)
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), tFields, "fields are the four declared fields, in order")
    Do $$$AssertEquals(tAnswer.truncated, 0, "nothing is cut at 1,000")
    Do $$$AssertTrue($IsObject(..RowNamed(tAnswer.rows, "%All")), "the %All role is listed among " _ tAnswer.rows.%Size() _ " rows")
    Do $$$AssertEquals(..RowShapeProblem(tAnswer.rows, "EscalationOnly"), "", "every row carries a Name and a boolean EscalationOnly")
}

/// <p>Matrix "Resources" -- the whole read answers the five declared fields, untruncated; the
/// <code>%DB_IRISSYS</code> row reads <code>AllowDelete</code> false and at least one row reads it
/// true.</p>
/// <p>Mutation: drop <code>AllowDelete</code> from
/// <class>OcuPilot.Screen.Descriptor.ResourceList</class>'s read and table -&gt; the field-list and
/// deletable assertions go red.</p>
Method TestTheResourcesListReadsOverTheWire()
{
    Set tSC = ..Read("permissions.resources", 1000, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Set tFields = $List($List(..Screens(), 2), 7)
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), tFields, "fields are the five declared fields, in order")
    Do $$$AssertEquals(tAnswer.truncated, 0, "nothing is cut at 1,000")
    Do $$$AssertEquals(..RowShapeProblem(tAnswer.rows, "AllowDelete"), "", "every row carries a Name and a boolean AllowDelete")
    Set tSystem = ..RowNamed(tAnswer.rows, "%DB_IRISSYS")
    Do $$$AssertTrue($IsObject(tSystem), "the %DB_IRISSYS row is listed")
    If $IsObject(tSystem) Do $$$AssertTrue((tSystem.%GetTypeOf("AllowDelete") = "boolean") && 'tSystem.AllowDelete, "and it is not deletable")
    Set tDeletable = 0
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.%GetTypeOf("AllowDelete") = "boolean") && tRow.AllowDelete Set tDeletable = tDeletable + 1
    }
    Do $$$AssertTrue(tDeletable > 0, "while at least one resource is: " _ tDeletable)
}

/// <p>Matrix "Services" and "Unrestricted service" -- the whole read answers the eight declared
/// fields, untruncated, with a boolean <code>Enabled</code> and both list fields arrays on every row,
/// and an unrestricted service's <code>AllowedConnections</code> is the vendor's empty array.</p>
Method TestTheServicesListReadsOverTheWire()
{
    Set tSC = ..Read("permissions.services", 1000, .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Set tFields = $List($List(..Screens(), 3), 7)
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), tFields, "fields are the eight declared fields, in order")
    Do $$$AssertEquals(tAnswer.truncated, 0, "nothing is cut at 1,000")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "the instance's services are listed: " _ tAnswer.rows.%Size())
    Do $$$AssertEquals(..RowShapeProblem(tAnswer.rows, "Enabled"), "", "every row carries a Name and a boolean Enabled")
    Set tBad = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        For tList = "AuthenticationMethods", "AllowedConnections" {
            If tRow.%GetTypeOf(tList) '= "array" Set tBad = tRow.Name _ " has a " _ tList _ " that is " _ tRow.%GetTypeOf(tList)
        }
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "and both list fields are arrays on every row")
    Do $$$AssertTrue(..UnrestrictedCount(tAnswer.rows) > 0, "and an unrestricted service reads [] on the read: " _ ..UnrestrictedCount(tAnswer.rows))
}

/// <p>How many of <var>pRows</var> carry <code>AllowedConnections</code> as an empty array.</p>
ClassMethod UnrestrictedCount(pRows As %DynamicArray) As %Integer
{
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.%GetTypeOf("AllowedConnections") = "array") && (tRow.AllowedConnections.%Size() = 0) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Matrix "Cap" -- each read at <code>maxRows=1</code> answers one row, reported truncated.</p>
Method TestEachListIsCutAtACapOfOne()
{
    Set tScreens = ..Screens()
    For tI = 1:1:$ListLength(tScreens) {
        Set tTool = $List($List(tScreens, tI), 3)
        Set tSC = ..Read(tTool, 1, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertStatusOK(tSC, tTool _ ": the capped request completes")
        Do $$$AssertEquals(tStatus, 200, tTool _ ": and answers")
        If (tStatus '= 200) || '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.rows.%Size(), 1, tTool _ ": one row at maxRows=1")
        Do $$$AssertEquals(tAnswer.truncated, 1, tTool _ ": reported truncated")
    }
}

/// <p>Matrix "Tool", and the integration AC -- the read tool over each screen, at a context cap of
/// three, answers only <code>fields</code>, <code>rows</code> and <code>truncated</code>: the route's
/// fields, the first three of the route's rows in the declared default order, and
/// <code>truncated</code> true. Every row it answers carries the screen's own boolean as a
/// boolean.</p>
/// <p>Mutation: point <class>OcuPilot.Screen.Descriptor.RoleList</class>'s endpoint at
/// <code>Security.User</code> -&gt; the roles tool's boolean assertion goes red.</p>
Method TestTheReadToolAnswersTheRoutesRowsNarrowedByItsCap()
{
    Set tScreens = ..Screens()
    For tI = 1:1:$ListLength(tScreens) {
        Set tCase = $List(tScreens, tI)
        Set tDescriptor = $List(tCase, 1)
        Set tTool = $List(tCase, 3) _ ".read"
        Set tCap = 3

        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tDescriptor, {}, tCap, .tView)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISERR(tSC) || '$IsObject(tView) Continue

        Set tSC = ..Read($List(tCase, 3), 1000, .tStatus, .tRoute, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers the same read")
        If (tStatus '= 200) || '$IsObject(tRoute) Continue
        Set tOrdered = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(tDescriptor, "Read"))
        Do $$$AssertTrue(tOrdered.%Size() > tCap, tTool _ ": the route has more rows than the cap: " _ tOrdered.%Size())
        Set tWanted = []
        For tJ = 0:1:(tCap - 1) Do tWanted.%Push(tOrdered.%Get(tJ))

        Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), tTool _ ": the route's fields")
        Do $$$AssertEquals(tView.rows.%ToJSON(), tWanted.%ToJSON(), tTool _ ": the route's rows in default order, narrowed by the cap")
        Do $$$AssertEquals(tView.truncated, 1, tTool _ ": reporting the cut")
        Do $$$AssertEquals(..RowShapeProblem(tView.rows, $List(tCase, 8)), "", tTool _ ": every row the tool answers carries the screen's own boolean")
        If tDescriptor = "OcuPilot.Screen.Descriptor.ServiceList" Do $$$AssertTrue(..UnrestrictedCount(tView.rows) > 0, tTool _ ": and an unrestricted service reads [] on the tool too")
        Set tKeys = ""
        Set tIterator = tView.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        Do $$$AssertEquals(tKeys, "fields,rows,truncated,rowsAvailable", tTool _ ": and nothing else")
    }
}

}
