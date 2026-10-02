/// <p>Pins Story 18.16's declarations: the Remote databases list and its form, the three remote
/// database tools' fields, kinds, ports, pairs and replaced classic pages, their baseline lines, and the
/// Integration row -- <code>osmgmt.remotedatabases.read</code> answers the rows the list's own read
/// answers, narrowed to remote configurations, and Local databases answers none of them (AD-36).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, no custom resource assigned to
/// the replaced classic pages, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because its Integration row defines a probe ECP data server (configuration only, never contacted)
/// and two probe remote configurations (<class>OcuPilot.Test.RemoteDatabaseProbe</class>), removed by
/// exact name before all, after each and after all.</p>
Class OcuPilot.Test.RemoteDatabaseDescriptor Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the Integration row, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter LIST = "OcuPilot.Screen.Descriptor.RemoteDatabaseList";

Parameter FORM = "OcuPilot.Screen.Descriptor.RemoteDatabaseForm";

Parameter PORT = "OcuPilot.Port.RemoteDatabasePort";

Parameter PROBE = "OcuPilot.Test.RemoteDatabaseProbe";

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RemoteDatabaseDescriptor defines a probe data server and remote databases on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>The list: OS management's twelfth entry over the vendor's configuration <code>LIST</code>
/// narrowed to remote databases, four fields filtered and sorted alike, Name first, a Create and one
/// Delete row action, the classic Remote Databases page, keyed by name over the configuration entity
/// type it shares with Local databases.</p>
/// <p>Mutation (Rule 19): the list's read drops <code>remoteOnly</code> -> the read leg and
/// <method>TestTheReadToolAnswersTheRemoteRowsAlone</method> go red.</p>
Method TestTheListIsOsManagementsTwelfthEntry()
{
    Set tClass = ..#LIST
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey, "os-management:12:remoteDatabaseListLabel", "OS management's twelfth side-bar entry")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""Database.ConfigCRUD"",""type"":""LIST"",""query"":{""remoteOnly"":""1""}}", "read through the vendor's configuration list, remote databases only")
    For tKey = "fields", "filter" {
        Do $$$AssertEquals(tDeclaration.read.%Get(tKey).%ToJSON(), "[""Name"",""Server"",""Directory"",""Status""]", "read." _ tKey _ " is the four fields")
    }
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the area's two pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind"), "database-configuration|instance|single", "one configuration per row, instance-scoped, keyed by its name, no new entity type")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "create|delete", "Create, and Delete on a row")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.RemoteDatabases", "the classic list (AD-44)")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "it does not refresh (AD-43)")
    Do $$$AssertEquals(tDeclaration.emptyStateKey _ "|" _ tDeclaration.table.emptyAgentKey, "remoteDatabaseListEmpty|remoteDatabaseListEmptyAgent", "its two empty-state keys")
    Do $$$AssertTrue(tDeclaration.suggestedPrompts.%Size() >= 3, "with three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/remote-databases") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.remotedatabases"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
    Set tColumns = ""
    Set tIterator = tDeclaration.table.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tColumn.field
    }
    Do $$$AssertEquals(tColumns, "Name,Server,Directory,Status", "four columns")
}

/// <p>The form: built, unlisted, carrying the list's own pairs, over the classic Remote Database
/// dialog, with no read of its own and three prompts.</p>
Method TestTheFormIsBuiltUnlistedWithTheListsPairs()
{
    Set tClass = ..#FORM
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition, "os-management/remote-databases/edit|form-page|0", "a form page under the list's route, taking no side-bar position")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the list's own pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ $ClassMethod(tClass, "PrimaryEntityType"), "%CSP.UI.Portal.Dialog.RemoteDatabase|database-configuration", "the classic dialog, over the configuration entity type (AD-44)")
    Do $$$AssertEquals($IsObject($ClassMethod(tClass, "Read")), 0, "and no read of its own")
    Do $$$AssertTrue(tDeclaration.suggestedPrompts.%Size() >= 3, "with three suggested prompts")
}

/// <p>The three tools: each a write on the Remote databases list through
/// <class>OcuPilot.Port.RemoteDatabasePort</class>, admitting exactly its fields, with its request type,
/// body, kind and change action; each requiring the list's pairs and <code>%DB_IRISSYS:WRITE</code>, and
/// naming its replaced classic page, a compiled class spelled exactly (AD-8, AD-44); the delete's
/// subject and its impact kind; and their baseline lines, the delete disabled (AD-22).</p>
Method TestTheToolsDeclareTheirFieldsKindsAndPairs()
{
    Set tScreen = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Set tWrite = $ListBuild("%DB_IRISSYS", "WRITE")
    ; name, settable, endpoint|write type|body|destructive|creates|change action, classic page
    Set tCases = $ListBuild($ListBuild("osmgmt.remotedatabases.create", "Server,Directory", "Database.ConfigCRUD|PUT|1|0|1|created", "%CSP.UI.Portal.Dialog.RemoteDatabase"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.remotedatabases.update", "Server,Directory", "Database.ConfigCRUD|PUT|1|0|0|updated", "%CSP.UI.Portal.Dialog.RemoteDatabase"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.remotedatabases.delete", "", "Database.ConfigCRUD|DELETE|0|1|0|deleted", "%CSP.UI.Portal.Dialog.DatabaseDelete"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tName = $List(tCase, 1)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass") _ "|" _ $ClassMethod(tClass, "ReadType"), "write|" _ ..#LIST _ "|" _ ..#PORT _ "|GET", tName _ " is a write on the Remote databases list, through the remote database port, reading GET")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 2), tName _ " admits exactly its fields")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction"), $List(tCase, 3), tName _ ": endpoint, request type, body, destructive, creates and change action")
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
        Do $$$AssertTrue(tResolved && (tPairs = (tScreen _ $ListBuild(tWrite))), tName _ ": the list's pairs, then the system database's WRITE")
        Set tPage = $Parameter(tClass, "CLASSICPAGES")
        Do $$$AssertEquals(tPage, $List(tCase, 4), tName _ ": the classic page it replaces (AD-44)")
        Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
        Do $$$AssertTrue($IsObject(tCompiled) && (tCompiled.Name = tPage), tName _ ": " _ tPage _ " is a compiled class spelled exactly")
        Set tCompiled = ""
    }
    Set tDelete = "OcuPilot.Screen.Tool.RemoteDatabaseDelete"
    Do $$$AssertEquals($ListToString($ClassMethod(tDelete, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(tDelete, "ScreenActionValueNames", "delete")), "delete|", "the delete carries the list's Delete with no value")
    Do $$$AssertEquals($ListToString($ClassMethod(tDelete, "FingerprintSubject")) _ "|" _ $ClassMethod(tDelete, "PreconditionField") _ "|" _ $Parameter(tDelete, "REMOVALROWS"), "Server,Directory|Server|Server,Directory", "fingerprinting and removing the data server and the directory (AD-51)")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tDelete), "", "which the registration guard accepts")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Impact).KindOf("osmgmt.remotedatabases.delete", {}, {}), "remote-database-delete", "its removal names its impact (AD-8)")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.RemoteDatabaseCreate", "InputSchema").required.%ToJSON(), "[""Name"",""Server"",""Directory""]", "the create requires the name, the data server and the directory")
    Set tSeeds = ""
    For tKey = "osmgmt.remotedatabases.create", "osmgmt.remotedatabases.delete", "osmgmt.remotedatabases.update" {
        Set tSeeds = tSeeds _ $Select(tSeeds = "": "", 1: ",") _ ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed) _ tListed
    }
    Do $$$AssertEquals(tSeeds, "11,01,11", "the baseline lists all three, the delete disabled (AD-22)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields("database-configuration")), "root,path,Size,GlobalJournalState,ResourceName,Server,Directory", "the prohibited set reviews a remote create's data server and directory")
    For tTool = "OcuPilot.Screen.Tool.RemoteDatabaseCreate", "OcuPilot.Screen.Tool.RemoteDatabaseUpdate" {
        Do $$$AssertTrue($Parameter(tTool, "DESCRIPTION") [ ("up to " _ $Parameter(..#PORT, "LISTSECONDS") _ " seconds"), tTool _ ": its description states the listing's bound, LISTSECONDS")
    }
}

/// <p>The copy-out draft of a remote create or re-point (AD-59) lists the data server before it writes,
/// as the port does: a <code>GET</code> of the listing route naming the body's data server, then the
/// configuration <code>PUT</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.RemoteDatabasePort.Snippet</method> answer the
/// database port's script for a <code>PUT</code> -> the listing step goes and this goes red.</p>
Method TestTheDraftListsTheServerBeforeItWrites()
{
    Kill tQuery
    Set tQuery("name") = "OCUPROBE1816C"
    Set tSteps = ##class(OcuPilot.Port.RemoteDatabasePort).Snippet("Database.ConfigCRUD", "PUT", .tQuery, {"Server": "OCUPROBE1816SRV", "Directory": "/ocuprobe1816x/"}, {"origin": "https://instance.example", "user": "probe"})
    Do $$$AssertTrue($IsObject(tSteps) && (tSteps.%Size() = 2), "two steps, the listing then the write: " _ $Select($IsObject(tSteps): tSteps.%ToJSON(), 1: ""))
    If '$IsObject(tSteps) || (tSteps.%Size() '= 2) Quit
    Set tList = tSteps.%Get(0).%Get("text")
    Do $$$AssertTrue((tList [ " -X GET ") && (tList [ "/api/admin/v2/ecp/data-server/databases?name=OCUPROBE1816SRV"), "the first lists the body's data server: " _ tList)
    Do $$$AssertTrue(tSteps.%Get(1).%Get("text") [ " -X PUT ", "the second sends the configuration PUT: " _ tSteps.%Get(1).%Get("text"))
}

/// <p>The Integration row (AD-36): with two probe remote configurations,
/// <code>osmgmt.remotedatabases.read</code> answers exactly the rows the list's own read answers, field
/// for field, both probes among them with their data server, directory and status, and no local
/// configuration; Local databases' read answers neither probe.</p>
Method TestTheReadToolAnswersTheRemoteRowsAlone()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816R"), "a probe remote database")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816S"), "and a second")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list's read answers")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.remotedatabases.read", .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), "the read tool is registered")
    If '$IsObject($Get(tTool)) Quit
    Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers")
    If '$IsObject($Get(tView)) Quit
    Do $$$AssertEquals(tView.fields.%ToJSON(), "[""Name"",""Server"",""Directory"",""Status""]", "the tool's fields are the four")
    Do $$$AssertEquals(..Rows(tView.rows), ..Rows(tResult.rows), "the tool answers the list's rows, field for field")
    Set tProbes = ""
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertTrue(tRow.%Get("Server") '= "", tRow.%Get("Name") _ " names a data server")
        If $Extract(tRow.%Get("Name"), 1, 12) = "OCUPROBE1816" Set tProbes = tProbes _ $Select(tProbes = "": "", 1: ",") _ tRow.%Get("Name") _ ":" _ tRow.%Get("Server") _ ":" _ tRow.%Get("Directory") _ ":" _ (tRow.%Get("Status") '= "")
    }
    Do $$$AssertEquals(tProbes, "OCUPROBE1816R:OCUPROBE1816SRV:/ocuprobe1816r/:1,OCUPROBE1816S:OCUPROBE1816SRV:/ocuprobe1816s/:1", "both probes, each with its data server, directory and status")
    Set tLocal = $ClassMethod(..#PROBE, "ListText", "OcuPilot.Screen.Descriptor.LocalDatabaseList", "Name")
    Do $$$AssertTrue((tLocal '= "") && '(tLocal [ ",OCUPROBE1816R,") && '(tLocal [ ",OCUPROBE1816S,"), "and Local databases answers, naming neither")
}

/// <p><var>pRows</var> as one sorted comparable string, each row its four fields joined.</p>
ClassMethod Rows(pRows As %DynamicArray) As %String
{
    Kill tSorted
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSorted(tRow.%Get("Name") _ "|" _ tRow.%Get("Server") _ "|" _ tRow.%Get("Directory") _ "|" _ tRow.%Get("Status")) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tKey
    }
    Quit tOut
}

}
