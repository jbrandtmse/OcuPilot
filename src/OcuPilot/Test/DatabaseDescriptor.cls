/// <p>Pins Story 18.3's declarations: the Local databases list and its editor, the four database
/// write tools' fields, kinds, pairs, argument pairs and replaced classic pages, and the Integration
/// row -- <code>osmgmt.localdatabases.read</code> answers the rows the list's own read answers, leaving
/// out no local configuration (AD-36).</p>
/// <p><b>What it needs from the environment:</b> the compiled registry and an installed instance
/// whose database configurations the admin API lists, with no custom resource assigned to the
/// replaced classic pages. Live-safe: it reads and writes nothing.</p>
Class OcuPilot.Test.DatabaseDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

Parameter FORM = "OcuPilot.Screen.Descriptor.LocalDatabaseForm";

Parameter PORT = "OcuPilot.Port.DatabasePort";

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

/// <p>The list: OS management's eleventh entry over the vendor's configuration <code>LIST</code>
/// narrowed to local databases, three fields filtered and sorted alike, Name first, one Delete row
/// action and a Create, the classic Local Databases page; Epic 6's Databases re-fetches on its
/// entity type, and it on Database details' (AD-14).</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Descriptor.LocalDatabaseList</class> declares no
/// secondary entity type -> its re-fetch leg goes red.</p>
Method TestTheListIsOsManagementsEleventhEntryKeyedByName()
{
    Set tClass = ..#LIST
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey, "os-management:11:localDatabaseListLabel", "OS management's eleventh side-bar entry")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""Database.ConfigCRUD"",""type"":""LIST"",""query"":{""localOnly"":""1""}}", "read through the vendor's configuration list, local databases only")
    For tKey = "fields", "filter" {
        Do $$$AssertEquals(tDeclaration.read.%Get(tKey).%ToJSON(), "[""Name"",""Directory"",""Status""]", "read." _ tKey _ " is the three fields")
    }
    Do $$$AssertEquals(tDeclaration.read.sort.%ToJSON(), "{""fields"":[""Name"",""Directory"",""Status""],""default"":""Name"",""direction"":""asc""}", "sorted on the three, Name ascending by default")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the area's two pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind"), "database-configuration|instance|single", "one configuration per row, instance-scoped, keyed by its name")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("database-configuration"), "an entity type the kernel declares (AD-14)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "create|delete,expand", "Create, and Delete and Add a volume on a row (Story 18.4)")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SecondaryEntityTypes")), "database", "it re-fetches after a mount or dismount, which changes its Status (AD-14, Story 18.4)")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Databases", "the classic list (AD-44)")
    Do $$$AssertEquals(''$ClassMethod(tClass, "Refreshes"), 0, "it does not refresh (AD-43)")
    Do $$$AssertEquals(tDeclaration.emptyStateKey _ "|" _ tDeclaration.table.emptyAgentKey, "localDatabaseListEmpty|localDatabaseListEmptyAgent", "its two empty-state keys")
    Do $$$AssertTrue(tDeclaration.suggestedPrompts.%Size() >= 3, "with three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/local-databases"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.localdatabases"), tClass, "and so does its tool identifier")
    Set tColumns = ""
    Set tIterator = tDeclaration.table.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tColumn.field _ ":" _ tColumn.labelKey _ ":" _ tColumn.kind
    }
    Do $$$AssertEquals(tColumns, "Name:tableColumnName:name,Directory:lockColumnDirectory:identifier,Status:taskHistoryColumnStatus:text", "three columns, the directory as an identifier")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Descriptor.DatabaseList).SecondaryEntityTypes()), "database-configuration", "Databases listens for a configuration change, so it re-fetches after a create or delete (AD-14)")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database-configuration", "OcuProbe183X"), "ocuprobe183x", "a configuration name folds case, as the instance resolves it (AD-13)")
}

/// <p>The editor: built, unlisted, carrying the list's own pairs, over the classic database page,
/// with no read of its own; every database violation code its form read publishes carries a
/// sentence and names its field.</p>
Method TestTheFormIsBuiltUnlistedWithTheListsPairs()
{
    Set tClass = ..#FORM
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition, "os-management/local-databases/edit|form-page|0", "a form page under the list's route, taking no side-bar position")
    Do $$$AssertEquals(tDeclaration.labelKey, "systemInfoDatabase", "titled with the existing Database label")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the list's own pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Database", "the classic database page (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "IdKind"), "database-configuration|single", "over the configuration entity type, keyed by its name")
    Do $$$AssertEquals($IsObject($ClassMethod(tClass, "Read")), 0, "and no read of its own")
    Do $$$AssertEquals(tDeclaration.toolIdentifier, "osmgmt.localdatabaseform", "its tool identifier")
    Do $$$AssertTrue(tDeclaration.suggestedPrompts.%Size() >= 3, "with three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/local-databases/edit"), tClass, "the route resolves to it")
    Set tCodes = ##class(OcuPilot.Api.Error).DatabaseViolationCodes()
    Set tFields = ""
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a sentence")
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ ##class(OcuPilot.Area.OsMgmt.DatabaseRules).FieldOf($List(tCodes, tI))
    }
    Do $$$AssertEquals(tFields, "Name,Name,Name,Name,path,Size,MaxSize,ExpansionSize,NewVolumeThreshold,NewVolumeThreshold,ResourceName,ResourceName,TargetSize,TargetFreeSpace,Size,InitialSize,Databases,Globals,Globals,Server,Server,Directory,Directory,Directory", "each code names its own field, Story 18.4's operation arguments, DW-1860's threshold and Story 18.16's remote fields among them")
    Do $$$AssertEquals(##class(OcuPilot.Area.OsMgmt.DatabaseRules).Rules().%Size(), $ListLength(tCodes), "and the form read publishes one rule per code")
    For tCode = "DATABASE.INUSE", "DATABASE.REMOTE", "DATABASE.LOCAL" {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "", tCode _ ": the envelope code carries a sentence too")
    }
}

/// <p>The four tools: each a write on the Local databases list through
/// <class>OcuPilot.Port.DatabasePort</class>, admitting exactly its fields and arguments, with its
/// request type, body, kind and change action; each requiring the list's pairs and the extras AD-8
/// names for it, and the pairs its arguments add; each naming the classic pages it replaces, every
/// one a compiled class spelled exactly (AD-44).</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_FileSystemAccess</code> from
/// <method>OcuPilot.Screen.Tool.LocalDatabaseCreate.PrivilegePairs</method> -> the create's pair
/// assertion goes red.</p>
Method TestTheToolsDeclareTheirFieldsKindsAndPairs()
{
    Set tScreen = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Set tWrite = $ListBuild("%DB_IRISSYS", "WRITE")
    Set tSecure = $ListBuild("%Admin_Secure", "USE")
    Set tFiles = $ListBuild("%Admin_FileSystemAccess", "USE")
    Set tOperate = $ListBuild("%Admin_Operate", "USE")
    ; name, settable, endpoint|write type|body|destructive|creates|change action, own pairs, classic pages
    Set tCases = $ListBuild($ListBuild("osmgmt.localdatabases.create", "root,path,Size,GlobalJournalState,ResourceName", "Database.ConfigCRUD|PUT|1|0|1|created", $ListBuild(tWrite, tSecure, tFiles), "%CSP.UI.Portal.Dialog.DatabaseWizard"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.localdatabases.updatemount", "ClusterMountMode,MountAtStartup,MountRequired", "Database.ConfigCRUD|PUT|1|0|0|updated", $ListBuild(tWrite), "%CSP.UI.Portal.Database"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.localdatabases.update", "MaxSize,ExpansionSize,NewVolumeThreshold,ResourceName,NewGlobalIsKeep,GlobalJournalState,ReadOnly,volumeRoot,volumePath", "Database.SysCRUD|PUT|1|0|0|updated", "", "%CSP.UI.Portal.Database,%CSP.UI.Portal.DatabaseVolumes"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.localdatabases.delete", "DeleteFile", "Database.ConfigCRUD|DELETE|0|1|0|deleted", $ListBuild(tWrite), "%CSP.UI.Portal.Dialog.DatabaseDelete"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tName = $List(tCase, 1)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass") _ "|" _ $ClassMethod(tClass, "ReadType"), "write|" _ ..#LIST _ "|" _ ..#PORT _ "|GET", tName _ " is a write on the Local databases list, through the database port, reading GET")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 2), tName _ " admits exactly its fields and arguments")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction"), $List(tCase, 3), tName _ ": endpoint, request type, body, destructive, creates and change action")
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
        Do $$$AssertTrue(tResolved && (tPairs = (tScreen _ $List(tCase, 4))), tName _ ": the list's pairs, then its own (" _ ..Names(tPairs) _ ")")
        Set tAdded = ##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tTool, {}, .tResolved)
        Do $$$AssertTrue(tResolved && (tAdded = ""), tName _ ": no argument adds a pair when none is sent")
        Set tPages = $Parameter(tClass, "CLASSICPAGES")
        Do $$$AssertEquals(tPages, $List(tCase, 5), tName _ ": the classic pages it replaces (AD-44)")
        For tI = 1:1:$Length(tPages, ",") {
            Set tPage = $Piece(tPages, ",", tI)
            Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
            Do $$$AssertTrue($IsObject(tCompiled) && (tCompiled.Name = tPage), tName _ ": " _ tPage _ " is a compiled class spelled exactly")
            Set tCompiled = ""
        }
    }
    ; The argument pairs (AD-8 as amended 2026-09-29).
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.localdatabases.updatemount", .tMount, 1)
    If $IsObject($Get(tMount)) {
        Do $$$AssertEquals(..Names(##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tMount, {"MountRequired": true}, .tResolved)), "%Admin_Operate:USE", "the mounting edit adds %Admin_Operate:USE when it sets MountRequired true")
        Do $$$AssertEquals(..Names(##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tMount, {"MountRequired": false, "MountAtStartup": true}, .tResolved)), "", "and nothing when it sets it false")
    }
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.localdatabases.update", .tUpdate, 1)
    If $IsObject($Get(tUpdate)) {
        Do $$$AssertEquals(..Names(##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tUpdate, {"ResourceName": "%DB_USER"}, .tResolved)), "%Admin_Secure:USE", "the file edit adds %Admin_Secure:USE when it sends a resource")
        Do $$$AssertEquals(..Names(##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tUpdate, {"volumeRoot": "/probe/", "volumePath": "ocuprobe183v"}, .tResolved)), "%Admin_FileSystemAccess:USE", "and %Admin_FileSystemAccess:USE when it sends a new volume directory")
        Do $$$AssertEquals(..Names(##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tUpdate, {"MaxSize": 0, "ReadOnly": false}, .tResolved)), "", "and nothing for any other field")
    }
    ; The create (AD-54): the name's absence is its fingerprint, its arguments are the payload.
    Set tCreate = "OcuPilot.Screen.Tool.LocalDatabaseCreate"
    Do $$$AssertEquals($ListToString($ClassMethod(tCreate, "ExcludedFields")), "Server,Directory,StreamLocation,ClusterMountMode,MountAtStartup,MountRequired", "the create admits no configuration template field")
    Set tSchema = $ClassMethod(tCreate, "InputSchema")
    Do $$$AssertEquals(tSchema.required.%ToJSON(), "[""Name"",""root""]", "and requires the name and the root")
    For tArgument = "root", "path", "Size", "GlobalJournalState", "ResourceName" {
        Do $$$AssertEquals(tSchema.properties.%GetTypeOf(tArgument), "object", "the create describes its argument " _ tArgument)
    }
    Kill tQuery
    Do $ClassMethod(tCreate, "PortQuery", {"Name": "OCUPROBE183D", "root": "/probe/", "path": "ocuprobe183d", "Size": 2, "GlobalJournalState": false}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("root")) _ "|" _ $Get(tQuery("path")) _ "|" _ $Get(tQuery("Size")) _ "|" _ $Get(tQuery("GlobalJournalState")) _ "|" _ $Data(tQuery("ResourceName")), "/probe/|ocuprobe183d|2|0|0", "and hands its arguments to the port as its query, an unsent resource left out (AD-52)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedCreateFields("database-configuration")), "root,path,Size,GlobalJournalState,ResourceName,Server,Directory", "the prohibited set reviews the create's five, and a remote create's two (Story 18.16)")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("database-configuration")), "MountAtStartup,MountRequired,ClusterMountMode,MaxSize,ExpansionSize,ResourceName,NewGlobalIsKeep,GlobalJournalState,ReadOnly,NewVolumeThreshold,volumeRoot,volumePath,Server,Directory", "and the two edits' settable fields for a change, with a remote re-point's two (Story 18.16)")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.LocalDatabaseUpdate).InputSchema().required.%ToJSON() _ "|" _ ##class(OcuPilot.Screen.Tool.LocalDatabaseUpdateMount).InputSchema().required.%ToJSON(), "[""Name""]|[""Name""]", "each edit requires the name alone")
}

/// <p>The delete (AD-51, AD-53, AD-56 (ii)): it carries the list's Delete with one value,
/// <code>DeleteFile</code>, which it requires of the agent, passes to the port as its query and
/// fingerprints with the directory and the data server; a screen value other than
/// <code>true</code> or <code>false</code> is refused. Its baseline line is <code>false</code> and
/// the other three <code>true</code> (AD-22), and its removal names its impact (AD-8).</p>
Method TestTheDeleteCarriesItsValueAndItsSubject()
{
    Set tClass = "OcuPilot.Screen.Tool.LocalDatabaseDelete"
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "delete")), "delete|DeleteFile", "it carries the list's Delete, its one value the file choice")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ReadAnswers")), "Directory,Server,MountAtStartup,MountRequired,DeleteFile", "what its read answers through the port")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")) _ "|" _ $ClassMethod(tClass, "PreconditionField"), "Directory,Server,DeleteFile|Directory", "fingerprinting the directory, the data server and the file choice (AD-51)")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard accepts")
    Do $$$AssertEquals($ClassMethod(tClass, "InputSchema").required.%ToJSON(), "[""Name"",""DeleteFile""]", "the agent must say whether the file goes too")
    Kill tQuery
    Do $ClassMethod(tClass, "PortQuery", {"Name": "OCUPROBE183D", "DeleteFile": true}, .tQuery)
    Do $$$AssertEquals($Get(tQuery($Parameter(..#PORT, "DELETEFILEQUERY"))), "1", "the choice reaches the port as its query (AD-52)")
    Set tSC = $ClassMethod(tClass, "ScreenActionDelta", "delete", {"DeleteFile": "true"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tProblem _ "|" _ $Select($IsObject($Get(tArgs)): tArgs.%ToJSON(), 1: ""), "1||{""DeleteFile"":true}", "a screen's true is the argument true (AD-56 (ii))")
    Set tSC = $ClassMethod(tClass, "ScreenActionDelta", "delete", {"DeleteFile": "maybe"}, {}, .tArgs, .tProblem)
    Do $$$AssertTrue($$$ISOK(tSC) && (tProblem '= ""), "and any other spelling is refused")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Impact).KindOf("osmgmt.localdatabases.delete", {}, {}), "database-delete", "its removal names its impact (AD-8)")
    Set tSeeds = ""
    For tKey = "osmgmt.localdatabases.create", "osmgmt.localdatabases.delete", "osmgmt.localdatabases.update", "osmgmt.localdatabases.updatemount" {
        Set tSeeds = tSeeds _ $Select(tSeeds = "": "", 1: ",") _ ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed) _ tListed
    }
    Do $$$AssertEquals(tSeeds, "11,01,11,11", "the baseline lists all four, the delete disabled (AD-22)")
}

/// <p>The Integration row (AD-36): <code>osmgmt.localdatabases.read</code> answers exactly the rows
/// the Local databases list's own read answers, field for field, and no configuration the vendor's
/// unnarrowed list reports with no data server is left out; the instance's own databases and
/// OcuPilot's are among them. That a remote configuration is left out is
/// <method>OcuPilot.Test.DatabaseRefusals.TestARemoteDatabaseIsRefused</method>'s, which creates
/// one.</p>
/// <p>Mutation (Rule 19): drop <code>Status</code> from the list's read -> the tool's fields and rows
/// differ and this goes red.</p>
Method TestTheReadToolAnswersTheListsRowsAllLocal()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list's read answers")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.localdatabases.read", .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), "the read tool is registered")
    If '$IsObject($Get(tTool)) Quit
    Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers")
    If '$IsObject($Get(tView)) Quit
    Do $$$AssertEquals(tView.fields.%ToJSON(), "[""Name"",""Directory"",""Status""]", "the tool's fields are the three")
    Do $$$AssertEquals(..Rows(tView.rows), ..Rows(tResult.rows), "the tool answers the list's rows, field for field")
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.ConfigCRUD", "LIST", .tQuery, "", .tAll, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the vendor's unnarrowed configuration list answers")
    If '$IsObject($Get(tAll)) Quit
    Kill tLocal
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("Server") = "") Set tLocal($ZConvert(tRow.%Get("Name"), "U")) = ""
    }
    Do $$$AssertTrue($Data(tLocal) > 0, "the vendor reports configurations with no data server")
    Set tNames = ..Rows(tResult.rows, "Name")
    Set tMissing = ""
    Set tName = ""
    For {
        Set tName = $Order(tLocal(tName))
        If tName = "" Quit
        If '(("," _ $ZConvert(tNames, "U") _ ",") [ ("," _ tName _ ",")) Set tMissing = tMissing _ " " _ tName
    }
    Do $$$AssertEquals(tMissing, "", "the list leaves out no configuration with no data server")
    For tWanted = "IRISSYS", "IRISLIB", $ZConvert(##class(OcuPilot.Kernel.State.Base).#DATABASENAME, "U") {
        Do $$$AssertTrue(("," _ tNames _ ",") [ ("," _ tWanted _ ","), tWanted _ " is listed")
    }
}

/// <p><var>pRows</var> as one sorted comparable string, each row its three fields joined, or with
/// <var>pField</var> that field alone.</p>
/// <p>Every code <class>OcuPilot.Api.DatabaseError</class> declares is a <code>DATABASE.*</code> code
/// with a sentence the one writer answers (AD-39), and each field-level code is among
/// <method>OcuPilot.Api.DatabaseError.ViolationCodes</method>, so the form read's rules carry it; only
/// the nine envelope codes stay out, Story 18.4's five state codes and Story 18.16's local refusal among them.</p>
/// <p>Mutation (Rule 19): drop a code from <method>OcuPilot.Api.DatabaseError.ViolationCodes</method>
/// -> this goes red.</p>
Method TestEveryDatabaseCodeIsSaidAndListed()
{
    Set tEnvelopes = $ListBuild(##class(OcuPilot.Api.DatabaseError).#VALIDATION, ##class(OcuPilot.Api.DatabaseError).#INUSE, ##class(OcuPilot.Api.DatabaseError).#REMOTE, ##class(OcuPilot.Api.DatabaseError).#MOUNTED, ##class(OcuPilot.Api.DatabaseError).#DISMOUNTED, ##class(OcuPilot.Api.DatabaseError).#READONLY, ##class(OcuPilot.Api.DatabaseError).#VOLUMEDIRECTORYNONE, ##class(OcuPilot.Api.DatabaseError).#VOLUMEDIRECTORYMANAGER, ##class(OcuPilot.Api.DatabaseError).#LOCAL)
    Set tListed = ##class(OcuPilot.Api.DatabaseError).ViolationCodes()
    Set tCount = 0
    Set tWrong = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledParameter WHERE parent = ? AND Origin = ?", "OcuPilot.Api.DatabaseError", "OcuPilot.Api.DatabaseError")
    While tRS.%Next() {
        Set tKey = tRS.%Get("Name")
        If $Extract(tKey, 1, 6) = "REASON" Continue
        Set tCode = $Parameter("OcuPilot.Api.DatabaseError", tKey)
        Set tCount = tCount + 1
        If '$Match(tCode, "DATABASE(\.[A-Z]+)+") || (##class(OcuPilot.Api.Error).ReasonForViolation(tCode) = "") Set tWrong = tWrong _ " " _ tKey _ "=" _ tCode
        If '$ListFind(tEnvelopes, tCode) && '$ListFind(tListed, tCode) Set tWrong = tWrong _ " unlisted:" _ tCode
    }
    Do $$$AssertTrue(tCount > 3, "the class declares its codes (" _ tCount _ ")")
    Do $$$AssertEquals(tWrong, "", "each is a DATABASE code with its sentence, and each field-level code is listed")
    Do $$$AssertEquals($ListLength(tListed), tCount - $ListLength(tEnvelopes), "and the list holds no code the class does not declare")
}

/// <p>Story 18.4's two screens: Check integrity, a form page under Databases carrying the list's own
/// pairs over the database entity, and the Integrity log, a log viewer carrying the log's two pairs and
/// reading the integrity source; both built, each over its classic page, Check integrity unlisted and the
/// Integrity log OS management's fifth side-bar entry, right after Databases. The Databases list
/// offers Check integrity as its primary action and on a row, and Database details its five
/// operations.</p>
Method TestTheIntegrityScreensAreBuilt()
{
    For tCase = $ListBuild("OcuPilot.Screen.Descriptor.DatabaseIntegrity", "os-management/databases/integrity|form-page|0", "databaseIntegrityLabel", ..#SCREENPAIRS, "database|single", "%CSP.UI.Portal.Dialog.Integ", "osmgmt.databaseintegrity"), $ListBuild("OcuPilot.Screen.Descriptor.DatabaseIntegrityLog", "os-management/databases/integrity-log|log-viewer|5", "databaseIntegrityLogLabel", "[{""resource"":""%Admin_Operate"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "log-entry|none", "%CSP.UI.Portal.Dialog.IntegLog", "osmgmt.integritylog") {
        Set tClass = $List(tCase, 1)
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ ": the declaration parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tClass _ ": the declaration validates")
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition, $List(tCase, 2), tClass _ ": its route, archetype and side-bar position")
        Do $$$AssertEquals(tDeclaration.labelKey, $List(tCase, 3), tClass _ ": its label key")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), $List(tCase, 4), tClass _ ": its pairs")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "IdKind"), $List(tCase, 5), tClass _ ": its entity type and id")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), $List(tCase, 6), tClass _ ": its classic page (AD-44)")
        Do $$$AssertEquals(tDeclaration.toolIdentifier, $List(tCase, 7), tClass _ ": its tool identifier")
        Do $$$AssertTrue(tDeclaration.suggestedPrompts.%Size() >= 3, tClass _ ": with three suggested prompts")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute($Piece($List(tCase, 2), "|", 1)), tClass, tClass _ ": the route resolves to it")
    }
    Set tLog = "OcuPilot.Screen.Descriptor.DatabaseIntegrityLog"
    Do $$$AssertEquals($ClassMethod(tLog, "Read").source.%ToJSON(), "{""port"":""logsource"",""endpoint"":""integrity"",""type"":""LIST""}", "the Integrity log reads the integrity source")
    Set tSC = $ClassMethod(tLog, "DeclarationJson", .tDeclaration)
    Do $$$AssertEquals($Select($IsObject($Get(tDeclaration)): tDeclaration.emptyStateKey, 1: ""), "databaseIntegrityNone", "and says so when no check was run")
    Do $$$AssertEquals(..Names(##class(OcuPilot.Port.LogSourcePort).PairsFor("integrity")), "%Admin_Operate:USE,%DB_IRISSYS:READ", "the port's own pairs for the source are the screen's")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Descriptor.DatabaseList).PrimaryActionId() _ "|" _ $ListToString(##class(OcuPilot.Screen.Descriptor.DatabaseList).RowActionIds()), "integrity|integrity", "the Databases list offers Check integrity, declared on its rows too for the action route")
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Descriptor.DatabaseDetails).RowActionIds()), "mount,dismount,truncate,compact,defragment", "Database details offers its five operations")
}

/// <p>Story 18.4's eight tools: each a write through <class>OcuPilot.Port.DatabasePort</class> reading
/// <code>STATE</code> and sending <code>Database.Actions</code>' own request type with no body of the
/// caller's (AD-51), neither destructive nor a create; each admitting exactly its one argument, or none;
/// each requiring its screen's pairs and then its own (AD-8); each naming the classic pages it replaces,
/// compiled classes spelled exactly (AD-44); each that can place a volume file fingerprinting the new
/// volume directory and threshold its precondition reads (AD-51); the compact and defragment adding read
/// on the target's own resource.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Secure</code> from
/// <class>OcuPilot.Screen.Tool.DatabaseMount</class> -> the mount's pairs go red.</p>
Method TestTheDiskOperationsDeclareTheirTypesArgumentsAndPairs()
{
    Set tDetails = "OcuPilot.Screen.Descriptor.DatabaseDetails"
    Set tDatabases = "OcuPilot.Screen.Descriptor.DatabaseList"
    Set tLocal = "OcuPilot.Screen.Descriptor.LocalDatabaseList"
    ; name, descriptor, write type, argument, pairs, classic pages, id argument/param
    Set tCases = $ListBuild($ListBuild("osmgmt.databasedetails.mount", tDetails, "MOUNT", "ReadOnly", "%Admin_Operate:USE,%DB_IRISSYS:READ,%Admin_Secure:USE", "%CSP.UI.Portal.Dialog.DBActions", "Directory/dir"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.databasedetails.dismount", tDetails, "DISMOUNT", "", "%Admin_Operate:USE,%DB_IRISSYS:READ,%Admin_Manage:USE", "", "Directory/dir"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.databasedetails.truncate", tDetails, "TRUNCATE", "TargetSize", "%Admin_Operate:USE,%DB_IRISSYS:READ", "%CSP.UI.Portal.Background.Dialog.DatabaseTruncate", "Directory/dir"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.databasedetails.compact", tDetails, "COMPACT", "TargetFreeSpace", "%Admin_Operate:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE", "%CSP.UI.Portal.Background.Dialog.DatabaseCompact", "Directory/dir"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.databasedetails.defragment", tDetails, "DEFRAGMENT", "", "%Admin_Operate:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE", "%CSP.UI.Portal.Background.Dialog.DatabaseDefragment", "Directory/dir"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.databases.integrity", tDatabases, "INTEGRITYCHECK", "Globals", "%Admin_Manage:USE,%DB_IRISSYS:READ,%Admin_Operate:USE,%DB_IRISSYS:WRITE", "%CSP.UI.Portal.Dialog.Integ,%CSP.UI.Portal.Dialog.IntegOutput", "Directory/dir"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.localdatabases.grow", tLocal, "MODIFYSIZE", "Size", "%Admin_Manage:USE,%DB_IRISSYS:READ,%Admin_Operate:USE", "%CSP.UI.Portal.Database", "Name/name"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.localdatabases.expand", tLocal, "EXPANDVOL", "InitialSize", "%Admin_Manage:USE,%DB_IRISSYS:READ,%Admin_Operate:USE", "%CSP.UI.Portal.DatabaseVolumes,%CSP.UI.Portal.Dialog.ExpandVolume", "Name/name"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tName = $List(tCase, 1)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass") _ "|" _ $ClassMethod(tClass, "ReadType"), "write|" _ $List(tCase, 2) _ "|" _ ..#PORT _ "|STATE", tName _ " is a write on its screen, through the database port, reading STATE")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction"), "Database.Actions|" _ $List(tCase, 3) _ "|0|0|0|updated", tName _ ": endpoint, request type, no body of its own, neither destructive nor a create")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 4), tName _ " admits exactly its argument")
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
        Do $$$AssertEquals($Select(tResolved: ..Names(tPairs), 1: "unresolved"), $List(tCase, 5), tName _ ": its screen's pairs, then its own")
        Set tPages = $Parameter(tClass, "CLASSICPAGES")
        Do $$$AssertEquals(tPages, $List(tCase, 6), tName _ ": the classic pages it replaces (AD-44)")
        For tI = 1:1:$Length(tPages, ",") {
            Set tPage = $Piece(tPages, ",", tI)
            If tPage = "" Continue
            Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tPage)
            Do $$$AssertTrue($IsObject(tCompiled) && (tCompiled.Name = tPage), tName _ ": " _ tPage _ " is a compiled class spelled exactly")
            Set tCompiled = ""
        }
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ "/" _ $ClassMethod(tClass, "IdParam"), $List(tCase, 7), tName _ ": names its database by its screen's id")
        If $ListFind($ListFromString($Parameter(..#PORT, "VOLUMETYPES") _ "," _ $Parameter(..#PORT, "THRESHOLDVOLUMETYPES")), $List(tCase, 3)) {
            Set tSubject = $ClassMethod(tClass, "FingerprintSubject")
            Do $$$AssertTrue($ListFind(tSubject, "NewVolumeDirectory") && $ListFind(tSubject, "NewVolumeThreshold"), tName _ ": fingerprints the new volume directory and threshold its precondition reads (AD-51)")
        }
    }
    Set tDirectory = ##class(OcuPilot.Test.DatabaseWriteProbe).Stored("IRISSYS", "Directory")
    For tName = "osmgmt.databasedetails.compact", "osmgmt.databasedetails.defragment" {
        Kill tTool
        Do ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        If '$IsObject($Get(tTool)) Continue
        Set tArgs = {}
        Do tArgs.%Set("Directory", tDirectory, "string")
        Do $$$AssertEquals(..Names(##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(tTool, tArgs, .tResolved)), "%DB_IRISSYS:READ", tName _ " adds read on the target's own resource")
    }
}

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
        Set tSorted(tRow.%Get("Name") _ "|" _ tRow.%Get("Directory") _ "|" _ tRow.%Get("Status")) = ""
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

/// <p><var>pPairs</var> spelled <code>resource:permission</code>, comma-separated.</p>
ClassMethod Names(pPairs As %List) As %String
{
    Set tOut = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $ListToString($List(pPairs, tI), ":")
    }
    Quit tOut
}

}
