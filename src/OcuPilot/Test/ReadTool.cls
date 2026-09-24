/// <p>The tool registry's discovery and validation half and the read tool's view (AD-5, AD-22,
/// AD-36): which tools a registry lists and of which kind, the kind refusal, the argument
/// validator's rows, the view's cap and secret stripping, and the read declaration's refusals.</p>
/// <p>Tools come from <class>OcuPilot.Test.Read.ToolRegistry</class>; canned rows from
/// <class>OcuPilot.Test.EndpointFixture</class> through <class>OcuPilot.Test.PortFixture</class>;
/// the route rows the view is compared with through <class>OcuPilot.Test.Dispatch</class> with
/// <class>OcuPilot.Test.ScreenGate</class>'s declared privileges. Reads only.</p>
Class OcuPilot.Test.ReadTool Extends %UnitTest.TestCase
{

/// <p>The canned read-declaring descriptor.</p>
Parameter CANNED = "OcuPilot.Test.Read.Canned";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>AC3 -- each read-declaring descriptor yields exactly one tool
/// <code>&lt;toolIdentifier&gt;.read</code> of kind <code>read</code> with no class of its own, a
/// readless descriptor yields none, a concrete tool two levels down is found with its
/// inherited kind, and the production registry holds exactly the tools the roster assertion names.
/// The application error log, the three shell reads and the navigation tool declare no descriptor
/// read, so their tools come from the registry's other source -- classes of their own -- and carry
/// no descriptor.</p>
/// <p>Mutations: name the read tool from <method>OcuPilot.Screen.Descriptor.Base.Route</method>
/// in <method>OcuPilot.Screen.Tool.Read.NameFor</method> -> the name assertions go red. Replace
/// <code>%Extends</code> with superclass equality in
/// <method>OcuPilot.Screen.Tool.Registry.ToolClasses</method> -> the <code>Leaf</code> assertions
/// go red.</p>
Method TestTheRegistryListsDescriptorReadsAndInheritedKinds()
{
    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the fixture tools list")
    Kill tByName
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tByName(tTool.name) = tTool
    }
    Do $$$AssertEquals(tTools.%Size(), 3, "two read tools and one class tool")

    For tPair = $ListBuild("webapp.canned.read", ..#CANNED), $ListBuild("webapp.probe.read", "OcuPilot.Test.Read.WebApps") {
        Set tName = $List(tPair, 1)
        Do $$$AssertTrue($Data(tByName(tName)), tName _ " is registered")
        If '$Data(tByName(tName)) Continue
        Do $$$AssertEquals(tByName(tName).kind, "read", tName _ " is of kind read")
        Do $$$AssertEquals(tByName(tName).descriptor, $List(tPair, 2), tName _ " is derived from its descriptor")
        Do $$$AssertEquals(tByName(tName).class, "OcuPilot.Test.Read.ToolFixture", tName _ " is answered by the one read tool class, not a class of its own")
    }
    Do $$$AssertEquals($Data(tByName("webapp.readless.read")), 0, "a descriptor with no read yields no tool")

    Do $$$AssertTrue($Data(tByName("test.leaf.write")), "a concrete tool below an abstract middle class is found")
    If $Data(tByName("test.leaf.write")) {
        Do $$$AssertEquals(tByName("test.leaf.write").kind, "write", "with the kind it inherits")
        Do $$$AssertEquals(tByName("test.leaf.write").class, "OcuPilot.Test.Read.Tool.Leaf", "and its own class")
    }

    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).Resolve("webapp.canned.read", .tResolved)
    Do $$$AssertStatusOK(tSC, "resolution runs")
    Do $$$AssertTrue($IsObject(tResolved) && (tResolved.descriptor = ..#CANNED), "a listed name resolves to its entry")
    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).Resolve("webapp.nosuch.read", .tMissing)
    Do $$$AssertEquals(tMissing, "", "an unlisted name resolves to nothing")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tProduction)
    Do $$$AssertStatusOK(tSC, "the production registry lists")
    Kill tProductionByName
    Set tIterator = tProduction.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tProductionByName(tTool.name) = tTool
    }
    Set tNames = ""
    Set tName = $Order(tProductionByName(""))
    While tName '= "" {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
        Set tName = $Order(tProductionByName(tName))
    }
    Do $$$AssertEquals(tProduction.%Size(), 83, "the production registry holds eighty-three tools, fixtures excluded: Epic 6's thirty-seven reads and Story 7.4's three, Epic 4's three shell reads and its navigation tool, and the thirty-nine write tools Stories 5.5, 5.9, 5.10, 5.11, 5.12, 5.13, 7.1, 7.2, 7.3, 7.5, 7.6, 7.8, 7.11, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.8 and 12.2 landed")
    Do $$$AssertEquals(tNames, "agent.definitions.read,logs.alerts.read,logs.applicationerrors.delete,logs.applicationerrors.read,logs.audit.read,logs.messages.read,osmgmt.databasedetails.read,osmgmt.databasefreespace.read,osmgmt.databases.read,osmgmt.databasevolumes.read,osmgmt.devices.create,osmgmt.devices.delete,osmgmt.devices.read,osmgmt.devices.update,osmgmt.locks.read,osmgmt.processdetails.read,osmgmt.processes.read,osmgmt.processes.resume,osmgmt.processes.suspend,osmgmt.processes.terminate,osmgmt.processes.terminatewitherror,osmgmt.systemusage.read,permissions.resources.create,permissions.resources.delete,permissions.resources.read,permissions.resources.update,permissions.roles.create,permissions.roles.delete,permissions.roles.read,permissions.services.read,permissions.users.create,permissions.users.delete,permissions.users.password,permissions.users.read,permissions.users.revoketokens,permissions.users.update,security.auditing.read,security.auditing.update,security.auditsystemevents.read,security.auditsystemevents.reset,security.auditsystemevents.update,security.audituserevents.delete,security.audituserevents.read,security.audituserevents.reset,security.audituserevents.update,security.ldap.read,security.oauthclients.delete,security.oauthclients.read,security.oauthresourceservers.read,security.oauthserver.read,security.oauthserverclients.delete,security.oauthserverclients.read,security.oauthserverdescriptions.read,security.secrets.create,security.secrets.read,security.secrets.update,security.ssl.read,security.wallet.read,security.x509.delete,security.x509.import,security.x509.read,security.x509.update,shell.instance.read,shell.namespaces.read,shell.privileges.read,shell.screen.open,tasks.history.read,tasks.ondemand.read,tasks.ondemand.run,tasks.schedule.delete,tasks.schedule.read,tasks.schedule.resume,tasks.schedule.run,tasks.schedule.suspend,tasks.taskdetails.read,tasks.taskhistory.read,tasks.upcoming.read,webapp.list.create,webapp.list.delete,webapp.list.read,webapp.list.update,webapp.openapi.read,webapp.restapis.read", "every descriptor-declared read of the six areas, the application error log's own class tool, the three shell reads, the navigation tool and the thirty-nine write tools -- the last forty-four class tools of their own, with no descriptor-derived read")
    For tPair = $ListBuild("shell.instance.read", "OcuPilot.Kernel.Shell.InstanceRead"), $ListBuild("shell.namespaces.read", "OcuPilot.Kernel.Shell.NamespacesRead"), $ListBuild("shell.privileges.read", "OcuPilot.Kernel.Shell.PrivilegesRead") {
        Set tName = $List(tPair, 1)
        If '$Data(tProductionByName(tName)) Continue
        Do $$$AssertEquals(tProductionByName(tName).class _ "|" _ tProductionByName(tName).descriptor _ "|" _ tProductionByName(tName).kind, $List(tPair, 2) _ "||read", tName _ " is a read tool with a class of its own and no descriptor")
    }
    ; The one tool with a class of its own: it names no descriptor, because nothing about it is
    ; derived from one (OcuPilot.Screen.Tool.Registry's "two sources, one list").
    Do $$$AssertEquals(tProductionByName("logs.applicationerrors.read").class, "OcuPilot.Screen.Tool.ErrorRead", "the application error log's tool is answered by its own class")
    Do $$$AssertEquals(tProductionByName("logs.applicationerrors.read").descriptor, "", "and is derived from no descriptor")
    Do $$$AssertEquals(tProductionByName("logs.applicationerrors.read").kind, "read", "declaring its kind at definition time (AD-22)")
    ; The two write tools: each a class of its own, each declaring its kind at definition time.
    Do $$$AssertEquals(tProductionByName("webapp.list.update").class, "OcuPilot.Screen.Tool.WebAppUpdate", "the web applications write tool is answered by its own class")
    Do $$$AssertEquals(tProductionByName("webapp.list.update").descriptor, "", "and is derived from no descriptor")
    Do $$$AssertEquals(tProductionByName("webapp.list.update").kind, "write", "declaring its kind at definition time (AD-22)")
    Do $$$AssertEquals(tProductionByName("permissions.users.update").class, "OcuPilot.Screen.Tool.UserUpdate", "the users write tool is answered by its own class")
    Do $$$AssertEquals(tProductionByName("permissions.users.update").descriptor, "", "and is derived from no descriptor")
    Do $$$AssertEquals(tProductionByName("permissions.users.update").kind, "write", "declaring its kind at definition time (AD-22)")
    For tPair = $ListBuild("agent.definitions.read", "OcuPilot.Screen.Descriptor.AgentDefinitionList"), $ListBuild("logs.alerts.read", "OcuPilot.Screen.Descriptor.LogAlertViewer"), $ListBuild("logs.messages.read", "OcuPilot.Screen.Descriptor.LogMessageViewer"), $ListBuild("logs.audit.read", "OcuPilot.Screen.Descriptor.AuditList"), $ListBuild("osmgmt.databases.read", "OcuPilot.Screen.Descriptor.DatabaseList"), $ListBuild("osmgmt.databasefreespace.read", "OcuPilot.Screen.Descriptor.DatabaseFreeSpace"), $ListBuild("osmgmt.databasedetails.read", "OcuPilot.Screen.Descriptor.DatabaseDetails"), $ListBuild("osmgmt.databasevolumes.read", "OcuPilot.Screen.Descriptor.DatabaseVolumeList"), $ListBuild("osmgmt.devices.read", "OcuPilot.Screen.Descriptor.DeviceList"), $ListBuild("osmgmt.locks.read", "OcuPilot.Screen.Descriptor.LockList"),$ListBuild("osmgmt.processdetails.read", "OcuPilot.Screen.Descriptor.ProcessDetails"), $ListBuild("osmgmt.processes.read", "OcuPilot.Screen.Descriptor.ProcessList"), $ListBuild("osmgmt.systemusage.read", "OcuPilot.Screen.Descriptor.SystemUsage"), $ListBuild("permissions.resources.read", "OcuPilot.Screen.Descriptor.ResourceList"), $ListBuild("permissions.roles.read", "OcuPilot.Screen.Descriptor.RoleList"), $ListBuild("permissions.services.read", "OcuPilot.Screen.Descriptor.ServiceList"), $ListBuild("permissions.users.read", "OcuPilot.Screen.Descriptor.UserList"), $ListBuild("security.ssl.read", "OcuPilot.Screen.Descriptor.SslConfigList"), $ListBuild("security.x509.read", "OcuPilot.Screen.Descriptor.X509CredentialList"), $ListBuild("security.ldap.read", "OcuPilot.Screen.Descriptor.LdapConfigList"), $ListBuild("security.oauthserverdescriptions.read", "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab"), $ListBuild("security.oauthclients.read", "OcuPilot.Screen.Descriptor.OAuthClientTab"), $ListBuild("security.oauthresourceservers.read", "OcuPilot.Screen.Descriptor.OAuthResourceServerTab"), $ListBuild("security.oauthserver.read", "OcuPilot.Screen.Descriptor.OAuthServerTab"), $ListBuild("security.oauthserverclients.read", "OcuPilot.Screen.Descriptor.OAuthServerClientTab"), $ListBuild("security.wallet.read", "OcuPilot.Screen.Descriptor.WalletCollectionList"), $ListBuild("security.secrets.read", "OcuPilot.Screen.Descriptor.WalletSecretList"), $ListBuild("tasks.schedule.read", "OcuPilot.Screen.Descriptor.TaskScheduleList"), $ListBuild("tasks.taskdetails.read", "OcuPilot.Screen.Descriptor.TaskDetails"), $ListBuild("tasks.ondemand.read", "OcuPilot.Screen.Descriptor.TaskOnDemandList"), $ListBuild("tasks.upcoming.read", "OcuPilot.Screen.Descriptor.TaskUpcomingList"), $ListBuild("tasks.history.read", "OcuPilot.Screen.Descriptor.TaskHistoryList"), $ListBuild("tasks.taskhistory.read", "OcuPilot.Screen.Descriptor.TaskRunList"), $ListBuild("webapp.list.read", "OcuPilot.Screen.Descriptor.WebAppList"), $ListBuild("webapp.openapi.read", "OcuPilot.Screen.Descriptor.OpenApiViewer"), $ListBuild("webapp.restapis.read", "OcuPilot.Screen.Descriptor.RestApiList") {
        Set tName = $List(tPair, 1)
        If '$Data(tProductionByName(tName)) Continue
        Do $$$AssertEquals(tProductionByName(tName).kind, "read", tName _ " is of kind read")
        Do $$$AssertEquals(tProductionByName(tName).descriptor, $List(tPair, 2), tName _ " is derived from its descriptor")
        Do $$$AssertEquals(tProductionByName(tName).class, "OcuPilot.Screen.Tool.Read", tName _ " is answered by the one read tool class")
    }
}

/// <p>DW-271 -- every case in <class>OcuPilot.Test.DeclarationCorpus</class> gets its exact
/// sentence, or none, from <method>OcuPilot.Screen.Registry.DeclarationProblem</method>, the same
/// corpus <file>ui/tools/screen-mirror.test.mjs</file> runs through
/// <code>declarationProblem</code>; and every shipped descriptor passes.</p>
/// <p>Mutation: make the check a presence check -&gt; the seven dropped-key cases go red. Refuse a
/// <class>%DynamicArray</class> as an unknown key rather than as "not an object" -&gt; the array
/// assertion goes red and the two engines stop agreeing.</p>
/// <p><b>This method's own assertions call the rule directly</b>, so deleting the
/// <method>DeclarationProblem</method> call from <method>OcuPilot.Screen.Registry.Validate</method>
/// reddens nothing here -- the shipped roster is sound either way. That deletion in
/// <file>ui/tools/screen-mirror.mjs</file> reddens <code>screen-mirror.test.mjs</code>'s
/// hostile-generator case; the instance-side half of the same wiring is
/// <class>OcuPilot.Test.DeclarationRegistry</class>'s, over <class>OcuPilot.Test.Declaration.Bad</class>
/// (DW-306).</p>
Method TestEveryDeclarationCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.DeclarationCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.DeclarationCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)

    ; Shapes the corpus cannot express, because its cases add and drop keys on an object. Both
    ; engines answer the same sentence, which is what the two-engine rule requires.
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem([]), "the declaration is not an object", "an array is not a declaration")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(""), "the declaration is not an object", "and neither is a string")

    ; The corpus's sound declaration exercises the whole vocabulary, so the closed set cannot drift
    ; by one without a case going red.
    Set tKeys = 0
    Set tKeyIterator = tCorpus.declaration.%GetIterator()
    While tKeyIterator.%GetNext(.tKey, .tValue) { Set tKeys = tKeys + 1 }
    Do $$$AssertEquals(tKeys, $ListLength($ListFromString(##class(OcuPilot.Screen.Registry).#DECLARATIONKEYS)), "the corpus declaration carries exactly the declared vocabulary")

    ; Every shipped descriptor passes the rule, so the closed set refuses nothing that ships. That
    ; Validate calls the rule at all is TestAnUnknownTopLevelKeyIsRefusedThroughValidate's, over a
    ; roster that carries a misspelt key; this assertion is the sound-roster half of that pair.
    Set tListSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tRoster)
    Do $$$AssertStatusOK(tListSC, "the shipped roster reads")
    If $$$ISOK(tListSC) {
        For tI = 1:1:$ListLength(tRoster) {
            Set tClass = $List(tRoster, tI)
            Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tShipped)
            Do $$$AssertStatusOK(tDeclSC, tClass _ ": the declaration reads")
            If $$$ISERR(tDeclSC) Continue
            Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tShipped), "", tClass _ ": its top-level keys are the declared vocabulary")
        }
    }
    Set tRosterSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tRosterSC, "the shipped roster validates: " _ tProblem)
}

/// <p>DW-306 -- <method>OcuPilot.Screen.Registry.Validate</method>'s own call to
/// <method>DeclarationProblem</method>, demonstrated over a roster rather than over a value.
/// <method>TestEveryDeclarationCorpusCaseGetsItsSentence</method> calls the rule directly, so
/// deleting the call from <method>Validate</method> reddened nothing there; this is the fixture
/// registry that call site's own wiring needed, the same way
/// <class>OcuPilot.Test.BannerRegistry</class> closes it for <method>BannerProblem</method>.</p>
/// <p>Mutation: delete the <method>OcuPilot.Screen.Registry.DeclarationProblem</method> call from
/// <method>OcuPilot.Screen.Registry.Validate</method> -&gt; this assertion goes red naming the same
/// class and sentence, while <method>TestEveryDeclarationCorpusCaseGetsItsSentence</method> and the
/// shipped roster both stay green.</p>
Method TestAnUnknownTopLevelKeyIsRefusedThroughValidate()
{
    Set tSC = ##class(OcuPilot.Test.DeclarationRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying an unknown top-level key is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.Declaration.Bad", "the refusal names the offending class: " _ tProblem)
    Do $$$AssertTrue(tProblem [ "the declaration declares the unknown key 'banners'", "and the sentence DeclarationProblem returns: " _ tProblem)
}

/// <p>Story 2.6 AC5 -- every case in <class>OcuPilot.Test.RowGetCorpus</class> gets its exact
/// sentence, or none, from <method>OcuPilot.Screen.Registry.ReadProblem</method>, the same corpus
/// <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>readProblem</code>; and the users
/// list's own detail call passes, and so does the X.509 list's <code>CERTINFO</code> one.</p>
/// <p>Mutation: accept any <code>rule</code> in
/// <method>OcuPilot.Screen.Registry.RowGetProblem</method> -> the <code>afterToday</code> case goes
/// red.</p>
Method TestEveryRowGetCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.RowGetCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Set tDeclaration = ##class(OcuPilot.Test.RowGetCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), tExpected, tCase.name)
    }
    Set tSC = ##class(OcuPilot.Screen.Descriptor.UserList).DeclarationJson(.tUsers)
    Do $$$AssertStatusOK(tSC, "the users list's declaration reads")
    If $$$ISOK(tSC) Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tUsers), "", "and its detail call passes")
    Set tSC = ##class(OcuPilot.Screen.Descriptor.X509CredentialList).DeclarationJson(.tX509)
    Do $$$AssertStatusOK(tSC, "the X.509 list's declaration reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tX509.read.source.rowGet.type, "CERTINFO", "the X.509 list declares its certificate read")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tX509), "", "and that detail call passes")
}

/// <p>Story 6.4 -- every case in <class>OcuPilot.Test.ReadSourceCorpus</class> gets its exact sentence,
/// or none, from <method>OcuPilot.Screen.Registry.ReadProblem</method>, the same corpus
/// <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>readProblem</code>: a source's
/// <code>LIST</code>, <code>GET</code> or <code>UPCOMING</code> type, its <code>forEach</code> parent
/// list and its fixed <code>query</code>.</p>
/// <p>Mutation: drop the <code>GET</code> arm's <code>rowGet</code> refusal from
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> -&gt; the "a GET with a detail call and no
/// criteria" case goes red.</p>
Method TestEveryReadSourceCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.ReadSourceCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.ReadSourceCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)
}

/// <p>Story 2.7 AC5 (DW-264) -- every case in <class>OcuPilot.Test.AdminPairCorpus</class> gets its
/// exact sentence, or none, from <method>OcuPilot.Screen.Registry.ReadProblem</method>, the same
/// corpus <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>readProblem</code>; and
/// every shipped admin-port list passes.</p>
/// <p>Mutation: make the admin-port arm of <method>OcuPilot.Screen.Registry.ReadProblem</method>
/// unreachable -> every refusing case goes red, while the shipped roster stays green either way.</p>
Method TestEveryAdminPairCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.AdminPairCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.AdminPairCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)

    For tClass = "OcuPilot.Screen.Descriptor.AuditList", "OcuPilot.Screen.Descriptor.ProcessList", "OcuPilot.Screen.Descriptor.SystemUsage", "OcuPilot.Screen.Descriptor.SslConfigList", "OcuPilot.Screen.Descriptor.TaskScheduleList", "OcuPilot.Screen.Descriptor.UserList", "OcuPilot.Screen.Descriptor.WebAppList", "OcuPilot.Screen.Descriptor.RestApiList", "OcuPilot.Screen.Descriptor.OpenApiViewer", "OcuPilot.Screen.Descriptor.RoleList", "OcuPilot.Screen.Descriptor.ResourceList", "OcuPilot.Screen.Descriptor.ServiceList", "OcuPilot.Screen.Descriptor.X509CredentialList", "OcuPilot.Screen.Descriptor.LdapConfigList", "OcuPilot.Screen.Descriptor.WalletCollectionList", "OcuPilot.Screen.Descriptor.WalletSecretList", "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab", "OcuPilot.Screen.Descriptor.OAuthClientTab", "OcuPilot.Screen.Descriptor.OAuthResourceServerTab", "OcuPilot.Screen.Descriptor.OAuthServerTab", "OcuPilot.Screen.Descriptor.OAuthServerClientTab", "OcuPilot.Screen.Descriptor.TaskOnDemandList", "OcuPilot.Screen.Descriptor.TaskUpcomingList", "OcuPilot.Screen.Descriptor.DatabaseList", "OcuPilot.Screen.Descriptor.DatabaseFreeSpace", "OcuPilot.Screen.Descriptor.DatabaseDetails", "OcuPilot.Screen.Descriptor.DatabaseVolumeList" {
        Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tShipped)
        Do $$$AssertStatusOK(tDeclSC, tClass _ ": the declaration reads")
        If $$$ISERR(tDeclSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tShipped), "", tClass _ ": its read declares the system database read")
    }
}

/// <p>Story 6.2 -- every case in <class>OcuPilot.Test.ColumnCorpus</class> gets its exact sentence,
/// or none, from <method>OcuPilot.Screen.Registry.ReadProblem</method>, the same corpus
/// <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>readProblem</code>: a column's
/// optional <code>emptyKey</code> is a non-empty string key or refused; and the Services list's
/// declared <code>emptyKey</code> passes.</p>
/// <p>Mutation: drop the <code>emptyKey</code> arm from
/// <method>OcuPilot.Screen.Registry.TableProblem</method> -&gt; the five refusing value cases go
/// red while the unknown-key case stays green.</p>
Method TestEveryColumnCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.ColumnCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.ColumnCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)

    Set tSC = ##class(OcuPilot.Screen.Descriptor.ServiceList).DeclarationJson(.tServices)
    Do $$$AssertStatusOK(tSC, "the services list's declaration reads")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tServices.table.columns.%Get(3).emptyKey, "serviceAllowedUnrestricted", "its Allowed IP addresses column declares the Unrestricted key")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tServices), "", "and that declaration passes")
}

/// <p>Story 2.10 AC7 -- every case in <class>OcuPilot.Test.CriteriaCorpus</class> gets its exact
/// sentence, or none, from <method>OcuPilot.Screen.Registry.CriteriaProblem</method>, the same
/// corpus <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>criteriaProblem</code>;
/// and every shipped descriptor passes, the ones that declare a criteria block included.</p>
/// <p>Mutation: drop the <code>options</code> arm from
/// <method>OcuPilot.Screen.Registry.CriteriaFieldsProblem</method> -> the four choice cases go red.
/// Admit any <code>kind</code> -> the <code>combobox</code> case goes red. Remove the
/// <code>refreshes</code> arm -> the auto-refresh case goes red and only it.</p>
Method TestEveryCriteriaCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.CriteriaCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.CriteriaCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)

    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tShippedList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Set tWithCriteria = 0
    For tI = 1:1:$ListLength(tShippedList) {
        Set tClass = $List(tShippedList, tI)
        Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tShipped)
        Do $$$AssertStatusOK(tDeclSC, tClass _ ": the declaration reads")
        If $$$ISERR(tDeclSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tShipped), "", tClass _ ": its criteria are the declared grammar")
        If $ListLength(##class(OcuPilot.Screen.Read).CriteriaParams(tClass)) > 0 Set tWithCriteria = tWithCriteria + 1
    }
    Do $$$AssertEquals(tWithCriteria, 10, "exactly ten shipped descriptors declare criteria: the audit database viewer's server search, the OpenAPI document viewer's application name, the Secrets list's parent collection, Process details' parent pid, the Upcoming tasks horizon, Task history's search and user-defined-only filter, History (one task)'s parent taskId, Task details' parent taskId, and Story 6.11's two -- Database details' parent dir and Database volumes' parent dir")
}

/// <p>Story 2.10 AC7 -- the read tool's schema carries one property per declared criterion, the
/// choice one as an <code>enum</code>, and stays closed; and a value outside that enum is refused
/// by the validator naming the argument, before any port is called.</p>
/// <p>This is the tool half of AD-21: the model sends the search the screen sends, and cannot send
/// a parameter the descriptor does not declare.</p>
/// <p>Mutation: stop calling <method>OcuPilot.Screen.Tool.Read.AddCriteria</method> from
/// <method>OcuPilot.Screen.Tool.Read.InputSchema</method> -> every property assertion goes red.
/// Drop the <code>enum</code> from the choice property -> the off-list refusal goes red alone.</p>
Method TestTheReadToolSchemaCarriesTheDeclaredCriteria()
{
    Set tClass = "OcuPilot.Screen.Descriptor.AuditList"
    Set tSchema = ##class(OcuPilot.Screen.Tool.Read).InputSchema(tClass)
    Do $$$AssertTrue($IsObject(tSchema), "the audit list's read tool has a schema")
    If '$IsObject(tSchema) Quit
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "the schema stays closed")
    Set tParams = ##class(OcuPilot.Screen.Read).CriteriaParams(tClass)
    For tI = 1:1:$ListLength(tParams) {
        Set tParam = $List(tParams, tI)
        Do $$$AssertEquals(tSchema.properties.%GetTypeOf(tParam), "object", tParam _ " is a declared tool property")
        Do $$$AssertEquals(tSchema.properties.%Get(tParam).%Get("type"), "string", "and it takes a string")
    }
    ; DW-279: the bound is published, not left implicit -- the caller is a model, and a limit it
    ; cannot see is one it exceeds and is then refused for. Compared against the declaration, so a
    ; bound published from somewhere else would not satisfy it.
    Set tDeclaredIterator = $ClassMethod(tClass, "Read").criteria.fields.%GetIterator()
    While tDeclaredIterator.%GetNext(.tDeclaredIndex, .tDeclaredField) {
        Set tDeclaredParam = tDeclaredField.%Get("param")
        Do $$$AssertEquals(tSchema.properties.%Get(tDeclaredParam).%Get("maxLength"), tDeclaredField.%Get("maxLength"), tDeclaredParam _ " publishes the maxLength its criterion declares")
    }
    Do $$$AssertEquals(tSchema.properties.authentication.enum.%Size(), 11, "the choice criterion publishes its eleven declared options as an enum")
    Do $$$AssertEquals(tSchema.properties.%GetTypeOf("jsonSearch"), "unassigned", "a vendor parameter the descriptor does not declare is not a tool property")

    ; The validator's own refusal, before the view is ever entered: an off-list value names the
    ; argument and the rule.
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"authentication": "Bogus"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "an authentication value outside the declared options is refused")
    Do $$$AssertTrue((tProblem [ "'authentication'") && (tProblem [ "(enum)"), "naming the argument and the rule: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"authentication": "Password"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "a declared one passes: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"jsonSearch": "x"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "and an undeclared parameter is refused by the closed schema")

    ; DW-279, the same refusal for a published bound: a keyword the validator admitted and never
    ; checked would read as a constraint it did not apply.
    Set tOverLong = $Translate($Justify("", 83), " ", "7")
    Do $$$AssertEquals($Length(tOverLong), 83, "the probe value is longer than the fifty pids accepts")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"pids": (tOverLong)}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "an over-long criterion argument is refused")
    Do $$$AssertTrue((tProblem [ "'pids'") && (tProblem [ "(maxLength)"), "naming the argument and the rule: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"pids": "1234,5678"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "while a value inside the bound passes: " _ tProblem)
}

/// <p>Story 2.10 AC7 -- the executor refuses a <code>choice</code> criterion outside its declared
/// options <b>before the port is called</b>, with 400 and <code>READ.CRITERION</code>, and seeds
/// only the criteria a caller supplied a non-empty value for.</p>
/// <p>This is the arm that makes the declared enum load-bearing rather than decorative: without it
/// the vendor's own <code>$$AuthenticationDisplayToLogical</code> answers <code>-1</code> for an
/// unknown name, and <code>-1</code> matches nearly every row instead of none.</p>
/// <p>Mutation: pass a <code>choice</code> value through <method>OcuPilot.Screen.Read.SeedCriteria</method>
/// without checking it -> the refusal assertions go red and the port is called. Seed an empty
/// criterion -> the omission assertion goes red.</p>
Method TestAnOffListChoiceIsRefusedBeforeThePortIsCalled()
{
    Set tRead = $ClassMethod("OcuPilot.Screen.Descriptor.AuditList", "Read")
    Do $$$AssertTrue($IsObject(tRead), "the audit list declares a read")
    If '$IsObject(tRead) Quit

    ; Empty criteria are omitted, so the vendor's own default stands for each of them.
    Kill tSupplied, tQuery
    Set tQuery("maxRows") = 6
    Set tSupplied("authentication") = ""
    Set tSupplied("eventSources") = ""
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).SeedCriteria(tRead, .tSupplied, .tQuery), "", "an empty criterion is sound")
    Do $$$AssertEquals($Data(tQuery("authentication")), 0, "and is omitted from the query")
    Do $$$AssertEquals($Data(tQuery("eventSources")), 0, "as is every other empty one")
    Do $$$AssertEquals(tQuery("maxRows"), 6, "while the row cap the read sends itself is untouched")

    ; A declared value is seeded under the vendor's own parameter name.
    Kill tSupplied, tQuery
    Set tSupplied("authentication") = "Password"
    Set tSupplied("eventSources") = "OcuPilot"
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).SeedCriteria(tRead, .tSupplied, .tQuery), "", "a declared choice value is sound")
    Do $$$AssertEquals($Get(tQuery("authentication")), "Password", "and is seeded under the vendor's own parameter name")
    Do $$$AssertEquals($Get(tQuery("eventSources")), "OcuPilot", "beside the text criteria")

    ; An off-list value is refused by name, and nothing is seeded.
    Kill tSupplied, tQuery
    Set tSupplied("authentication") = "Bogus"
    Set tSupplied("eventSources") = "OcuPilot"
    Set tProblem = ##class(OcuPilot.Screen.Read).SeedCriteria(tRead, .tSupplied, .tQuery)
    Do $$$AssertNotEquals(tProblem, "", "an off-list choice value is refused")
    Do $$$AssertTrue(tProblem [ "authentication", "naming the criterion: " _ tProblem)
    Do $$$AssertEquals($Data(tQuery("eventSources")), 0, "and no criterion is seeded, so the port is never called with half a search")

    ; The whole executor, through the arm the route and the tool both take, with the port armed so
    ; "no port was called" is a real observation rather than a vacuous one: 400 with the machine
    ; code, and the endpoint fixture records no construction.
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")
    Kill tCriteria
    Set tCriteria("authentication") = "Bogus"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute("OcuPilot.Screen.Descriptor.AuditList", 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusNotOK(tSC, "the read is refused")
    Do $$$AssertEquals(tHttp, 400, "with 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#READCRITERION, "and the READ.CRITERION machine code")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "and no endpoint was constructed, so no LIST was queued")

    ; The same call with a declared value does reach the port, which is what makes the assertion
    ; above a refusal rather than a fixture that was never armed.
    Kill tCriteria
    Set tCriteria("authentication") = "Password"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute("OcuPilot.Screen.Descriptor.AuditList", 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "a declared value is served")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "and the endpoint was constructed")
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
}

/// <p>DW-279 -- the executor refuses a criterion value longer than its declared
/// <code>maxLength</code> <b>before the port is called</b>, with 400, <code>READ.CRITERION</code>
/// and the parameter and its bound by name.</p>
/// <p>This is the arm that makes the declared bound load-bearing rather than decorative. An
/// unbounded value reaches the vendor's own property -- <code>pids</code> accepts fifty characters
/// -- and faults inside <class>OcuPilot.Port.AdminPort</class>, which answers a fault naming no
/// parameter at all; the caller is told an internal error occurred where the true answer is that
/// one field was too long. The length is checked ahead of the kind because it binds every kind.</p>
/// <p>Mutation: delete the <code>maxLength</code> branch from
/// <method>OcuPilot.Screen.Read.SeedCriteria</method> -&gt; the refusal assertions go red, the
/// endpoint is constructed, and the read reaches the port. Raise <code>pids</code>'
/// <code>maxLength</code> above 83 in <class>OcuPilot.Screen.Descriptor.AuditList</class> -&gt; the
/// same assertions go red while the within-bound leg stays green, which is what says the bound
/// rather than the length is what refuses.</p>
Method TestAnOverLongCriterionIsRefusedBeforeThePortIsCalled()
{
    Set tRead = $ClassMethod("OcuPilot.Screen.Descriptor.AuditList", "Read")
    Do $$$AssertTrue($IsObject(tRead), "the audit list declares a read")
    If '$IsObject(tRead) Quit

    Set tOverLong = $Translate($Justify("", 83), " ", "7")
    Do $$$AssertEquals($Length(tOverLong), 83, "the probe value is 83 characters")

    ; The refusal names the parameter and the bound, and nothing is seeded -- so the port cannot be
    ; called with half a search.
    Kill tSupplied, tQuery
    Set tSupplied("pids") = tOverLong
    Set tSupplied("eventSources") = "OcuPilot"
    Set tProblem = ##class(OcuPilot.Screen.Read).SeedCriteria(tRead, .tSupplied, .tQuery)
    Do $$$AssertNotEquals(tProblem, "", "an over-long criterion value is refused")
    Do $$$AssertTrue(tProblem [ "pids", "naming the criterion: " _ tProblem)
    Do $$$AssertTrue(tProblem [ "50", "and the bound it exceeded: " _ tProblem)
    Do $$$AssertEquals($Data(tQuery("eventSources")), 0, "and no criterion is seeded")

    ; The bound is the vendor's own, not one length: a value at the limit is sound, and the
    ; criterion whose limit is a thousand admits far more than fifty.
    Kill tSupplied, tQuery
    Set tSupplied("pids") = $Translate($Justify("", 50), " ", "7")
    Set tSupplied("eventSources") = $Translate($Justify("", 83), " ", "7")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Read).SeedCriteria(tRead, .tSupplied, .tQuery), "", "a value at its own bound is sound, and so is one well inside a wider bound")
    Do $$$AssertEquals($Length($Get(tQuery("pids"))), 50, "and both are seeded under the vendor's own parameter names")
    Do $$$AssertEquals($Length($Get(tQuery("eventSources"))), 83, "the wider criterion carrying its longer value")

    ; The whole executor, with the port armed so "no port was called" is a real observation: 400
    ; with the machine code, and the endpoint fixture records no construction.
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")
    Kill tCriteria
    Set tCriteria("pids") = tOverLong
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute("OcuPilot.Screen.Descriptor.AuditList", 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusNotOK(tSC, "the read is refused")
    Do $$$AssertEquals(tHttp, 400, "with 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#READCRITERION, "and the READ.CRITERION machine code")
    Do $$$AssertTrue($Select($IsObject(tFault): tFault.reason, 1: "") [ "pids", "the reason names the parameter: " _ $Select($IsObject(tFault): tFault.reason, 1: ""))
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "and no endpoint was constructed, so no LIST was queued")

    ; The same call inside the bound does reach the port, which is what makes the assertion above a
    ; refusal rather than a fixture that was never armed.
    Kill tCriteria
    Set tCriteria("pids") = "1234,5678"
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute("OcuPilot.Screen.Descriptor.AuditList", 5, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "a value inside the bound is served")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", "and the endpoint was constructed")
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
}

/// <p>Story 2.10 AC7 -- the declared criteria a model sends reach the <b>port's own query</b>
/// through <method>OcuPilot.Screen.Tool.Read.View</method>, under the vendor's parameter names and
/// beside the cap the read sends itself. This is the tool half of AD-36's "one read, two callers":
/// without it the tool could silently drop every criterion and answer the newest rows unfiltered
/// while the schema still advertised the search.</p>
/// <p>Mutation: delete the criteria loop from <method>OcuPilot.Screen.Tool.Read.View</method>, so it
/// calls <code>Execute</code> with none -> the two criterion assertions go red and only they;
/// <method>TestTheReadToolSchemaCarriesTheDeclaredCriteria</method> stays green, because it never
/// calls <method>View</method>.</p>
Method TestTheReadToolSendsItsDeclaredCriteriaToThePort()
{
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")

    Set tArgs = {"maxRows": 5, "eventSources": "OcuPilot", "authentication": "Password"}
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View("OcuPilot.Screen.Descriptor.AuditList", tArgs, 5, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the audit list's read tool answers")
    Set tParams = ##class(OcuPilot.Test.EndpointFixture).Recorded("params")
    Do $$$AssertTrue(tParams [ "eventSources=OcuPilot", "the text criterion reaches the port's query: " _ tParams)
    Do $$$AssertTrue(tParams [ "authentication=Password", "and so does the choice one: " _ tParams)
    Do $$$AssertTrue(tParams [ "maxRows=6", "beside the cap plus one the read sends itself: " _ tParams)

    ; A criterion left out is omitted rather than sent empty, so the vendor's own default stands --
    ; the same rule the route is held to.
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows("[]")
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View("OcuPilot.Screen.Descriptor.AuditList", {"maxRows": 5}, 5, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a tool call with no criterion answers")
    Set tBare = ##class(OcuPilot.Test.EndpointFixture).Recorded("params")
    Do $$$AssertEquals((tBare [ "eventSources"), 0, "and sends no criterion at all: " _ tBare)

    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
}

/// <p>Story 2.8 -- every case in <class>OcuPilot.Test.BannerCorpus</class> gets its exact sentence,
/// or none, from <method>OcuPilot.Screen.Registry.BannerProblem</method>, the same corpus
/// <file>ui/tools/screen-mirror.test.mjs</file> runs through <code>bannerProblem</code>; and every
/// shipped descriptor's banner, the one that declares a banner included, passes.</p>
/// <p>Mutation: admit any <code>severity</code> in
/// <method>OcuPilot.Screen.Registry.BannerProblem</method> -> the two severity cases go red.</p>
Method TestEveryBannerCorpusCaseGetsItsSentence()
{
    Set tSC = ##class(OcuPilot.Test.BannerCorpus).Corpus(.tCorpus)
    Do $$$AssertStatusOK(tSC, "the corpus reads")
    If '$IsObject(tCorpus) Quit
    Do $$$AssertTrue(tCorpus.cases.%Size() > 0, "the corpus carries cases: " _ tCorpus.cases.%Size())
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        If tExpected '= "" Set tRefusals = tRefusals + 1
        Set tDeclaration = ##class(OcuPilot.Test.BannerCorpus).DeclarationFor(tCorpus, tCase)
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), tExpected, tCase.name)
    }
    Do $$$AssertTrue(tRefusals > 0, "the corpus carries at least one refusing case: " _ tRefusals)

    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tShippedList)
    Do $$$AssertStatusOK(tSC, "the production descriptors list")
    Set tWithBanner = 0
    For tI = 1:1:$ListLength(tShippedList) {
        Set tClass = $List(tShippedList, tI)
        Set tDeclSC = $ClassMethod(tClass, "DeclarationJson", .tShipped)
        Do $$$AssertStatusOK(tDeclSC, tClass _ ": the declaration reads")
        If $$$ISERR(tDeclSC) Continue
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tShipped), "", tClass _ ": its banner is the declared grammar")
        If $IsObject($ClassMethod(tClass, "Banner")) Set tWithBanner = tWithBanner + 1
    }
    Do $$$AssertEquals(tWithBanner, 1, "exactly one shipped descriptor declares a banner, and it is the task schedule's")
}

/// <p>AC4's instance half -- <method>OcuPilot.Screen.Tool.Registry.KindProblem</method> admits
/// <code>read</code> and <code>write</code> and refuses everything else, the empty kind a class
/// declaring neither inherits from <class>OcuPilot.Screen.Tool.Base</class> included.</p>
Method TestAKindThatIsNeitherReadNorWriteIsRefused()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).KindProblem("X.Tool", "read"), "", "read is a kind")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).KindProblem("X.Tool", "write"), "", "and so is write")
    For tBad = "", "Read", "reads", "read,write" {
        Set tProblem = ##class(OcuPilot.Screen.Tool.Registry).KindProblem("X.Tool", tBad)
        Do $$$AssertTrue(tProblem [ "X.Tool", "kind '" _ tBad _ "' is refused naming the class")
    }
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.Base", "KIND"), "", "the base declares no kind")
    Do $$$AssertEquals($Parameter("OcuPilot.Test.Read.Tool.Leaf", "KIND"), "write", "and a subclass reads the nearest declared one")
}

/// <p>AC6 -- every tool-argument matrix row is refused naming the argument and the rule, and a
/// schema outside the subset is refused before any argument is read.</p>
/// <p>Mutation: drop the <code>additionalProperties</code> refusal from
/// <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method>'s object check -> the
/// <code>extra</code> row goes red.</p>
Method TestTheValidatorRefusesEveryArgumentRow()
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.Read).InputSchema(..#CANNED)
    Do $$$AssertTrue($IsObject(tSchema), "the canned read has a schema")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"maxRows": 5, "sort": "NameSpace", "direction": "desc", "filter": "csp"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "sound arguments pass")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {}, .tProblem)
    Do $$$AssertStatusOK(tSC, "no arguments pass, since none is required")

    Set tRows = $ListBuild(
        $ListBuild("{""maxRows"": ""5""}", "maxRows", "(type)"),
        $ListBuild("{""sort"": ""Enabled""}", "sort", "(enum)"),
        $ListBuild("{""direction"": ""up""}", "direction", "(enum)"),
        $ListBuild("{""extra"": 1}", "extra", "(additionalProperties: false)"),
        $ListBuild("{""maxRows"": 0}", "maxRows", "(minimum)"),
        $ListBuild("{""maxRows"": 2.5}", "maxRows", "(type)"))
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tRow, 1))
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, tArgs, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tRow, 1) _ " is refused")
        Do $$$AssertTrue((tProblem [ ("'" _ $List(tRow, 2) _ "'")) && (tProblem [ $List(tRow, 3)), $List(tRow, 1) _ " names the argument and the rule: " _ tProblem)
    }

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {"x": {"type": "string", "pattern": "^a"}}, "additionalProperties": false}, {"x": "a"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a schema using a keyword outside the subset is refused")
    Do $$$AssertTrue(tProblem [ "pattern", "naming the keyword")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {}}, {}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a top level not closed by additionalProperties: false is refused")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {"n": {"type": "array", "items": {"type": "integer", "maximum": 3}, "minItems": 1, "maxItems": 2}}, "required": ["n"], "additionalProperties": false}, {"n": [1, 4]}, .tProblem)
    Do $$$AssertTrue(tProblem [ "(maximum)", "items are validated against their own schema: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments({"type": "object", "properties": {"n": {"type": "array", "maxItems": 1}}, "required": ["n"], "additionalProperties": false}, {}, .tProblem)
    Do $$$AssertTrue(tProblem [ "(required)", "a required argument that is absent is refused: " _ tProblem)

    Set tSchema = {"type": "object", "properties": {"s": {"type": "string"}, "n": {"type": "number"}, "b": {"type": "boolean"}, "a": {"type": "array", "minItems": 1, "maxItems": 2}, "o": {"type": "object", "properties": {"x": {"type": "integer"}}, "additionalProperties": false}}, "additionalProperties": false}
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"s": "t", "n": 0.5, "b": false, "a": [1], "o": {"x": 2}}, .tProblem)
    Do $$$AssertStatusOK(tSC, "a value of every admitted type passes: " _ tProblem)
    Set tRows = $ListBuild(
        $ListBuild("{""s"": 1}", "s", "(type)"),
        $ListBuild("{""n"": ""1""}", "n", "(type)"),
        $ListBuild("{""b"": 0}", "b", "(type)"),
        $ListBuild("{""a"": {}}", "a", "(type)"),
        $ListBuild("{""o"": []}", "o", "(type)"),
        $ListBuild("{""a"": []}", "a", "(minItems)"),
        $ListBuild("{""a"": [1, 2, 3]}", "a", "(maxItems)"),
        $ListBuild("{""o"": {""x"": ""2""}}", "o.x", "(type)"),
        $ListBuild("{""o"": {""y"": 1}}", "o.y", "(additionalProperties: false)"))
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, ##class(%DynamicObject).%FromJSON($List(tRow, 1)), .tProblem)
        Do $$$AssertTrue((tProblem [ ("'" _ $List(tRow, 2) _ "'")) && (tProblem [ $List(tRow, 3)), $List(tRow, 1) _ " names the argument and the rule: " _ tProblem)
    }
}

/// <p>AC1 -- at <code>maxRows</code> 5 and a context cap of 5, the tool's view is the route's read
/// narrowed: its fields are the route's, and its rows are the view rule over the route's five rows.
/// Neither carries the secret field, which the one executor strips. The filter keeps four of the
/// five rows, and the read was cut at five of eight, so the view is truncated.</p>
/// <p>Mutation: pass no filter to <method>OcuPilot.Screen.Read.ApplyView</method> in
/// <method>OcuPilot.Screen.Tool.Read.View</method> -> the row assertion goes red.</p>
Method TestTheToolViewIsTheRouteReadNarrowed()
{
    Do ..ArmRows()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/screens/webapp.canned/read", "GET", {"maxRows": "5"}, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the route dispatches")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Set tRoute = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tRoute.rows.%Size(), 5, "the route answers five rows")

    Set tSC = ##class(OcuPilot.Test.Read.ToolRegistry).Resolve("webapp.canned.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the tool resolves")
    Set tArgs = {"maxRows": 5, "filter": "CSP/B", "sort": "Name", "direction": "desc"}
    Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, tArgs, 5, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool view runs")

    Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), "the tool's fields are the route's")
    Do $$$AssertEquals(tView.fields.%ToJSON(), "[""Name"",""NameSpace"",""Enabled""]", "and neither carries Secret")

    Set tNarrowed = ##class(OcuPilot.Screen.Read).ApplyView(tRoute.rows, $ClassMethod(..#CANNED, "Read"), "CSP/B", "Name", "desc")
    Do $$$AssertEquals(tNarrowed.%Size(), 4, "the view rule leaves four of the five rows")
    Do $$$AssertEquals(tView.rows.%ToJSON(), tNarrowed.%ToJSON(), "its rows are the view rule over the route's rows")
    Do $$$AssertEquals(tView.truncated, 1, "and truncation is reported")
    Do $$$AssertEquals((tView.%ToJSON() [ "secret"), 0, "no secret value reaches the tool")
}

/// <p>Every tool-argument matrix row, run through the view, is refused naming the argument and
/// reaches no port.</p>
Method TestARefusedArgumentReachesNoPort()
{
    Set tRows = $ListBuild(
        $ListBuild("{""maxRows"": ""5""}", "maxRows"),
        $ListBuild("{""sort"": ""Enabled""}", "sort"),
        $ListBuild("{""direction"": ""up""}", "direction"),
        $ListBuild("{""extra"": 1}", "extra"),
        $ListBuild("{""maxRows"": 0}", "maxRows"))
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Do ##class(OcuPilot.Test.EndpointFixture).Clear()
        Do ..ArmRows()
        Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, ##class(%DynamicObject).%FromJSON($List(tRow, 1)), 3, .tView, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $List(tRow, 1) _ ": the view is refused")
        Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ ("'" _ $List(tRow, 2) _ "'"), $List(tRow, 1) _ ": naming the argument")
        Do $$$AssertEquals(tView, "", $List(tRow, 1) _ ": with no result")
        Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", $List(tRow, 1) _ ": and the port was not called")
    }
}

/// <p>A read truncated by its own cap is truncated in the tool's view even when the context cap
/// cuts nothing.</p>
Method TestAFetchTruncationSurvivesTheView()
{
    Do ..ArmRows()
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"maxRows": 2}, 50, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the view runs")
    Do $$$AssertEquals(tView.rows.%Size(), 2, "two rows")
    Do $$$AssertEquals(tView.truncated, 1, "reported truncated because the read was")
}

/// <p>A <code>maxRows</code> above the context cap reads <code>maxRows</code>, so the read answers all
/// eight rows uncut; the context cap alone keeps three of them, and that cut alone reports the view
/// truncated.</p>
/// <p>Mutation: <method>OcuPilot.Screen.Tool.Read.View</method> sets <code>truncated</code> from the
/// read alone -> this goes red.</p>
Method TestAContextCapCutAloneIsTruncated()
{
    Do ..ArmRows()
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"maxRows": 50}, 3, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the view runs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("maxRows"), 51, "the read is asked for maxRows, so its eight rows come back uncut")
    Do $$$AssertEquals(tView.rows.%Size(), 3, "the context cap keeps three of the eight rows")
    Do $$$AssertEquals(tView.truncated, 1, "reported truncated, because the context cap cut rows")
}

/// <p>A view that neither the read's cap nor the context cap cuts is not truncated.</p>
Method TestAViewNothingCutsIsNotTruncated()
{
    Do ..ArmRows()
    Set tSC = ##class(OcuPilot.Test.Read.ToolFixture).View(..#CANNED, {"maxRows": 50}, 50, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the view runs")
    Do $$$AssertEquals(tView.rows.%Size(), 8, "every row")
    Do $$$AssertEquals(tView.%GetTypeOf("truncated"), "boolean", "truncated is a boolean")
    Do $$$AssertEquals(tView.truncated, 0, "and it is false")
}

/// <p>Story 2.8 -- the read tool's payload is <code>{fields, rows, truncated}</code> and carries no
/// <code>banner</code>. A banner is screen chrome rather than rows, so it rides in the screen read's
/// own response and never reaches the tool's view (AD-36) -- the claim
/// <class>OcuPilot.Screen.Descriptor.Base</class>, <class>OcuPilot.Screen.Read</class> and
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> each state in prose.</p>
/// <p>It holds because <method>OcuPilot.Screen.Tool.Read.View</method> builds its answer key by key
/// rather than returning the read's, so this is the assertion that keeps the prose true: the
/// descriptor under test is the one shipped descriptor that declares a banner, and its screen read
/// does carry the key.</p>
/// <p>Mutation: carry the read's <code>banner</code> into the payload
/// <method>OcuPilot.Screen.Tool.Read.View</method> builds -> the absence assertion goes red.</p>
Method TestTheToolPayloadCarriesNoBanner()
{
    Set tClass = "OcuPilot.Screen.Descriptor.TaskScheduleList"
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tClass, {"maxRows": 5}, 5, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the task schedule's tool view runs")
    If '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.%GetTypeOf("banner"), "unassigned", "the tool payload carries no banner key")
    Do $$$AssertTrue(tView.rows.%Size() > 0, "while it does carry rows: " _ tView.rows.%Size())

    ; The same descriptor's screen read does carry it, so the absence above is the tool's rule and
    ; not an accident of a descriptor that declares no banner.
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 5, .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and its screen read runs")
    If $IsObject(tRead) Do $$$AssertEquals(tRead.%GetTypeOf("banner"), "string", "carrying the banner key the tool drops")
}

/// <p>Matrix row "Declaration" -- a filter field outside the fields, a secret field in the sort
/// fields, cursor paging, and a three-segment tool identifier are each refused; and a roster
/// carrying one is refused naming the class, as is a roster in which two descriptors declare one
/// tool identifier.</p>
Method TestAReadDeclarationOutsideTheGrammarIsRefused()
{
    Set tSC = $ClassMethod(..#CANNED, "DeclarationJson", .tSound)
    Do $$$AssertStatusOK(tSC, "the canned declaration reads")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tSound), "", "the canned read is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.filter.%Push("Missing")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "Missing", "a filter field outside fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.fields.%Push("Secret")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "secret field 'Secret'", "a secret field in sort.fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.%Set("paging", "cursor")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "cursor", "cursor paging is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("toolIdentifier", "security.nosuch.detail")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "security.nosuch.detail", "a three-segment tool identifier with a read is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.%Set("default", "Enabled")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a sort default outside sort.fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.fields.%Push("Name")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a repeated field is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.source.%Set("port", "metrics")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a port outside the four the vocabulary names is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.filter.%Push("Secret")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.filter names the secret field 'Secret'", "a secret field in filter is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.%Set("direction", "up")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "direction 'up'", "a sort direction other than asc or desc is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.source.%Set("type", "POST")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "type 'POST' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'", "a source type other than LIST, GET, UPCOMING, HISTORY or VOLUMELIST is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.%Set("fields", [])
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.fields is empty", "empty fields are refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.context.secretFields.%Push("Other")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context.secretFields names 'Other'", "a secret field outside fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.context.%Set("secretfields", tCase.context.secretFields)
    Do tCase.context.%Remove("secretFields")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context declares the unknown key 'secretfields'", "a misspelt secretFields is refused, not read as no secret field")

    Set tCase = ..Mutated(tSound)
    Do tCase.context.%Remove("secretFields")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context.secretFields is not an array", "an undeclared secretFields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Remove("context")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "context is not an object", "a read with no context is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.%Set("secretFields", ["Secret"])
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read declares the unknown key 'secretFields'", "an unknown key in read is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.source.%Set("maxRows", 5)
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.source declares the unknown key 'maxRows'", "an unknown key in read.source is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.read.sort.%Set("dir", "asc")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read.sort declares the unknown key 'dir'", "an unknown key in read.sort is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("read", "WebApp.App")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tCase) [ "read is a string", "a read that is not an object is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("read", "", "null")
    Do tCase.%Set("table", "", "null")
    Do tCase.%Set("toolIdentifier", "security.nosuch.detail")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tCase), "", "a null read is a screen with no read, whatever its identifier")

    Set tSC = ##class(OcuPilot.Test.ReadBadRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster carrying cursor paging is refused")
    Do $$$AssertTrue(tProblem [ "OcuPilot.Test.ReadBad.Cursor", "naming the class")
    Set tSC = ##class(OcuPilot.Test.Read.Registry).Validate(.tProblem)
    Do $$$AssertEquals(tProblem, "", "while the read fixtures' roster is sound")

    Set tSC = ##class(OcuPilot.Test.ReadTwinRegistry).Validate(.tProblem)
    Do $$$AssertStatusNotOK(tSC, "a roster in which two descriptors declare one tool identifier is refused")
    Do $$$AssertTrue((tProblem [ "OcuPilot.Test.ReadTwin.One") && (tProblem [ "OcuPilot.Test.ReadTwin.Two") && (tProblem [ "webapp.twin"), "naming both classes and the identifier: " _ tProblem)
    Set tSC = ##class(OcuPilot.Test.ReadTwinToolRegistry).ListTools(.tTools)
    Do $$$AssertStatusNotOK(tSC, "the tool registry refuses the read tool name the two claim")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "webapp.twin.read", "naming the tool")
    Do $$$AssertEquals(tTools, "", "and lists nothing")
}

/// <p>Matrix row "Grammar" -- a read with no table, a column field outside the read's fields, two
/// name columns, an unknown kind, an <code>emptyNextKey</code> on a write-capable descriptor and a
/// composite id part outside the fields are each refused, as are a table with no read, an unknown
/// table key and an empty <code>emptyStateKey</code>; the agent key on a write-capable descriptor
/// is sound.</p>
/// <p>Mutation: drop the exactly-one-name check from
/// <method>OcuPilot.Screen.Registry.TableProblem</method> -> the two-name-columns assertion goes
/// red.</p>
Method TestATableOutsideTheGrammarIsRefused()
{
    Set tSC = $ClassMethod(..#CANNED, "DeclarationJson", .tSound)
    Do $$$AssertStatusOK(tSC, "the canned declaration reads")
    Set tRegistry = "OcuPilot.Screen.Registry"
    Do $$$AssertEquals($ClassMethod(tRegistry, "ReadProblem", tSound), "", "the canned table is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Remove("table")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table is not an object", "a read with no table is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("field", "Missing")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "field 'Missing' is not one of read.fields", "a column field outside the read's fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(1).%Set("kind", "name")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "2 name column(s)", "two name columns are refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("kind", "identifier")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "0 name column(s)", "no name column is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(2).%Set("kind", "boolean")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "kind 'boolean'", "an unknown kind is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Push({"field": "Name", "labelKey": "fieldUserName", "kind": "text"})
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "names the field 'Name' twice", "a field shown twice is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Push({"field": "Secret", "labelKey": "fieldUserName", "kind": "text"})
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "field 'Secret' is a secret field", "a column over a secret field is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("rowActions", [{"id": "disable", "selfProtection": ""}])
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyNextKey is declared on a write-capable descriptor", "emptyNextKey on a write-capable descriptor is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("primaryAction", {"id": "create", "selfProtection": ""})
    Do tCase.table.%Set("emptyNextKey", "")
    Do tCase.table.%Set("emptyAgentKey", "classicLinkCardCaption")
    Do $$$AssertEquals($ClassMethod(tRegistry, "ReadProblem", tCase), "", "the agent key on a write-capable descriptor is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("emptyAgentKey", "classicLinkCardCaption")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyAgentKey is declared on a descriptor with no primary or row action", "emptyAgentKey on a read-only descriptor is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("primaryAction", {"id": "create", "selfProtection": ""})
    Do tCase.table.%Set("emptyNextKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyAgentKey is empty on a write-capable descriptor", "a write-capable descriptor with no agent key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("emptyNextKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.emptyNextKey is empty", "a read-only descriptor with no next-step key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("labelKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "labelKey is empty", "an empty column label key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("columns", [])
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table.columns is empty", "a table with no column is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.columns.%Get(0).%Set("width", 3)
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "declares the unknown key 'width'", "an unknown column key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("id", {"kind": "composite", "parts": ["NameSpace", "Path"]})
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "id.parts names 'Path'", "a composite part outside the read's fields is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("id", {"kind": "composite", "parts": ["NameSpace", "Name"]})
    Do $$$AssertEquals($ClassMethod(tRegistry, "ReadProblem", tCase), "", "a composite id over declared fields is sound")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("emptyStateKey", "")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "emptyStateKey is empty", "an empty emptyStateKey is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.table.%Set("sort", "Name")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table declares the unknown key 'sort'", "an unknown table key is refused")

    Set tCase = ..Mutated(tSound)
    Do tCase.%Set("read", "", "null")
    Do $$$AssertTrue($ClassMethod(tRegistry, "ReadProblem", tCase) [ "table is declared while read is not", "a table with no read is refused")
}

/// <p>Story 2.12 AC5 -- the application error log's read tool carries the five AD-48 summary
/// fields and <b>nothing else</b>. The screen-only <code>username</code> and <code>process</code>
/// are dropped, and the captured variable table is not filtered out but never fetched: the tool
/// reads the list level, which calls <code>ErrorList</code>, whose row structurally carries no
/// variable table at all.</p>
/// <p>The key set is compared as an <b>equality</b> rather than as a membership test, which is what
/// makes a widened projection red rather than merely un-asserted.</p>
/// <p>Mutation: add <code>username</code> to
/// <parameter>OcuPilot.Screen.Tool.ErrorRead.SUMMARYFIELDS</parameter> -&gt; both the field-list and
/// the row key-set assertions go red. Mutation: make the tool read the detail level -&gt; the schema
/// no longer matches what the port expects and the row assertions go red. Mutation: replace
/// <method>OcuPilot.Screen.Tool.ErrorRead.View</method>'s
/// <code>Set tTruncated = ''tAnswer.%Get("truncated")</code> with a constant -&gt; the last
/// assertion goes red, because it compares the tool's flag with the port's own answer to the same
/// arguments rather than with a value the context cap produced. Mutation: delete
/// <code>Set tTruncated = 1</code> from that method's context-cap branch -&gt; the stub-driven cap
/// leg goes red, and only that one.</p>
Method TestTheErrorReadToolCarriesTheSummaryFieldsOnly()
{
    Set tTool = "OcuPilot.Screen.Tool.ErrorRead"
    Set tSchema = $ClassMethod(tTool, "InputSchema")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"namespace": "X", "date": "Y"}, .tProblem), 1, "the schema is one the argument validator admits: " _ tProblem)
    Set tKeys = ""
    Set tIterator = tSchema.properties.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "namespace,date,maxRows", "three properties: the namespace and date the caller drilled to, and the cap")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"namespace": "X"}, .tProblem2), "the date is required: this source has no default scope")

    ; The instance's own newest entry, found through the port the tool reads through.
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("namespaces", "", "", "", "", .tNamespaces, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 200, "the namespaces level answers")
    If tStatus '= 200 Quit
    Set tNamespace = ""
    Set tDate = ""
    Set tNsIterator = tNamespaces.rows.%GetIterator()
    While tNsIterator.%GetNext(.tIndex, .tRow) {
        If tNamespace '= "" Continue
        Set tDateSC = ##class(OcuPilot.Port.LogSourcePort).Errors("dates", tRow.namespace, "", "", "", .tDates, .tDateStatus, .tFault)
        If (tDateStatus = 200) && (tDates.rows.%Size() > 0) {
            Set tNamespace = tRow.namespace
            Set tDate = tDates.rows.%Get(0).date
        }
    }
    Do $$$AssertNotEquals(tNamespace, "", "this instance records at least one application error to read")
    If tNamespace = "" Quit

    Set tSC = $ClassMethod(tTool, "View", "", {"namespace": (tNamespace), "date": (tDate)}, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""errorNumber"",""time"",""errorText"",""routine"",""line""]", "the five AD-48 summary fields, and no others: " _ tResult.fields.%ToJSON())
    Do $$$AssertTrue(tResult.rows.%Size() > 0, "with rows: " _ tResult.rows.%Size())
    If tResult.rows.%Size() = 0 Quit
    Set tRowKeys = []
    Set tRowIterator = tResult.rows.%Get(0).%GetIterator()
    While tRowIterator.%GetNext(.tKey, .tValue) {
        Do tRowKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tRowKeys.%ToJSON(), "[""errorNumber"",""time"",""errorText"",""routine"",""line""]", "and every row carries exactly those keys: " _ tRowKeys.%ToJSON())
    Do $$$AssertEquals(tResult.rows.%Get(0).%IsDefined("username"), 0, "the screen-only user is not among them")
    Do $$$AssertEquals(tResult.rows.%Get(0).%IsDefined("process"), 0, "nor the screen-only process")
    Do $$$AssertEquals(tResult.rows.%Get(0).%IsDefined("variables"), 0, "and no captured variable table reaches the model (AD-48)")

    ; The CONTEXT cap is the caller's, and View reports it when it cuts -- driven through
    ; OcuPilot.Test.ErrorReadStub, which answers three rows whatever maxRows it is handed and, once
    ; armed, an untruncated port flag. Against the live instance this leg could not exist:
    ; BoundedMaxRows asks the port for min(model maxRows, context cap), so a context cap of 1 makes
    ; the port cut to one row and View's own cap branch never runs -- the flag read there was the
    ; port's, and whether it was 1 depended on how many errors that date happened to hold (DW-1091).
    Do ##class(OcuPilot.Test.ErrorReadStub).Clear()
    Do ##class(OcuPilot.Test.ErrorReadStub).ArmUntruncated()
    Set tSC = ##class(OcuPilot.Test.ErrorReadStub).View("", {"namespace": (tNamespace), "date": (tDate)}, 1, .tCapped, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a context cap of one answers")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorReadStub).Recorded("maxRows"), 1, "the port was asked for the cap")
    Do $$$AssertEquals(tCapped.rows.%Size(), 1, "one row of the stub's three")
    Do $$$AssertEquals(''tCapped.truncated, 1, "and reports that the cap cut rows (AD-24, AD-36), the port having answered untruncated")
    Do ##class(OcuPilot.Test.ErrorReadStub).Clear()

    ; The PORT's truncation, carried rather than swallowed: a model told "complete" about a read the
    ; port cut at its 1,000-row default is the case AD-24 exists for. Asserted as an equality
    ; against the port's own answer to the same arguments, so it holds on a date of any size: where
    ; the date carries more than one entry both read 1 and a swallowed flag goes red, where it
    ; carries one both read 0 and a hard-coded flag goes red. The row count is in the message, so
    ; which direction this run exercised is readable rather than assumed.
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("list", tNamespace, tDate, "", 1, .tPortAnswer, .tPortStatus, .tFault)
    Do $$$AssertEquals(tPortStatus, 200, "the port answers the same read the tool makes")
    If tPortStatus '= 200 Quit
    Set tSC = $ClassMethod(tTool, "View", "", {"namespace": (tNamespace), "date": (tDate), "maxRows": 1}, 5, .tPortCut, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a port cap of one under a context cap of five answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tPortCut.rows.%Size(), tPortAnswer.rows.%Size(), "the same rows the port answered, uncut by the context cap")
    Do $$$AssertEquals(''tPortCut.truncated, ''tPortAnswer.truncated, "and the port's own truncation flag, which the port answered as " _ ''tPortAnswer.truncated _ " for this date at a port cap of 1 (AD-24, AD-36)")
}

/// <p>Story 6.13 AC10 -- the alerts.log screen's derived read tool answers the same bounded tail
/// the screen's declared read answers, against the live instance, projected into the three declared
/// fields and nothing else. <b>The port's page envelope is not in its view</b>: a declared read
/// answers rows, so the cursor the screen's own route pages by -- <code>lines</code>,
/// <code>offset</code>, <code>identity</code> -- reaches no agent.</p>
/// <p>Mutation: give each row a fourth key in
/// <method>OcuPilot.Port.LogSourcePort.Entries</method> -&gt; the row-key assertion reddens.</p>
Method TestTheAlertReadToolCarriesTheTailsRowsAndNotItsCursor()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("logs.alerts.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the tool roster reads back")
    Do $$$AssertTrue($IsObject(tTool), "the alerts.log screen's read tool is registered")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.descriptor, "OcuPilot.Screen.Descriptor.LogAlertViewer", "derived from its descriptor")

    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View("OcuPilot.Screen.Descriptor.LogAlertViewer", {}, 5, .tResult)
    Do $$$AssertStatusOK(tSC, "the tool answers against the live instance")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""time"",""severity"",""text""]", "the three declared fields, and no others: " _ tResult.fields.%ToJSON())
    Do $$$AssertTrue(tResult.%IsDefined("rows"), "with rows")
    Do $$$AssertEquals(tResult.%IsDefined("lines"), 0, "and no lines key, which is the port page's own")
    Do $$$AssertEquals(tResult.%IsDefined("offset"), 0, "nor the page's cursor")
    Do $$$AssertEquals(tResult.%IsDefined("identity"), 0, "nor the page's file identity")

    If tResult.rows.%Size() = 0 Quit
    Set tRowKeys = []
    Set tRowIterator = tResult.rows.%Get(0).%GetIterator()
    While tRowIterator.%GetNext(.tKey, .tValue) {
        Do tRowKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tRowKeys.%ToJSON(), "[""time"",""severity"",""text""]", "and every row carries exactly those keys: " _ tRowKeys.%ToJSON())
}

/// <p>Story 6.14 AC2 -- the messages.log screen's derived read tool answers the <b>console log's</b>
/// bounded tail, projected into the three declared fields, with no page envelope and <b>no
/// <class>OcuPilot.Screen.Tool</class> class of its own</b> -- which is what closes DW-1100:
/// <method>OcuPilot.Screen.Read.Execute</method>'s <code>logsource</code> arm is endpoint-generic,
/// so the declaration alone is the whole screen.</p>
/// <p><b>Which file it reads is asserted, not assumed.</b> The tool's rows are compared to the
/// port's own answer for the <code>messages</code> key, so a declaration pointing at the other
/// endpoint answers the other file's rows -- or, on an instance that has raised no alert, none at
/// all -- and this reddens where
/// <method>TestTheAlertReadToolCarriesTheTailsRowsAndNotItsCursor</method> stays green.</p>
/// <p>Mutation: change <class>OcuPilot.Screen.Descriptor.LogMessageViewer</class>'s
/// <code>read.source.endpoint</code> to <code>alerts</code> and recompile -&gt; the row-source
/// assertion goes red.</p>
Method TestTheMessagesReadToolCarriesTheConsoleLogsRowsAndNotItsCursor()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("logs.messages.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the tool roster reads back")
    Do $$$AssertTrue($IsObject(tTool), "the messages.log screen's read tool is registered")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.descriptor, "OcuPilot.Screen.Descriptor.LogMessageViewer", "derived from its descriptor")
    Do $$$AssertEquals(tTool.class, "OcuPilot.Screen.Tool.Read", "and answered by the one shared read tool class, never a class of its own (DW-1100)")

    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View("OcuPilot.Screen.Descriptor.LogMessageViewer", {}, 5, .tResult)
    Do $$$AssertStatusOK(tSC, "the tool answers against the live instance")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.fields.%ToJSON(), "[""time"",""severity"",""text""]", "the three declared fields, and no others: " _ tResult.fields.%ToJSON())
    Do $$$AssertEquals(tResult.%IsDefined("lines"), 0, "no lines key, which is the port page's own")
    Do $$$AssertEquals(tResult.%IsDefined("offset"), 0, "nor the page's cursor")
    Do $$$AssertEquals(tResult.%IsDefined("identity"), 0, "nor the page's file identity")
    Do $$$AssertTrue(tResult.rows.%Size() > 0, "the console log always has lines, so the tool answers rows: " _ tResult.rows.%Size())
    Do $$$AssertTrue(tResult.rows.%Size() <= 5, "bounded by the cap: " _ tResult.rows.%Size())
    If tResult.rows.%Size() = 0 Quit

    Set tRowKeys = []
    Set tRowIterator = tResult.rows.%Get(0).%GetIterator()
    While tRowIterator.%GetNext(.tKey, .tValue) {
        Do tRowKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tRowKeys.%ToJSON(), "[""time"",""severity"",""text""]", "and every row carries exactly those keys: " _ tRowKeys.%ToJSON())

    ; The file the rows came from, read at the same cap one call apart. A console write landing
    ; between the two reads shifts EVERY position in a cap-bounded newest-first window, the last as
    ; much as the first, so no index is immune; the comparison holds because the two calls are
    ; adjacent and nothing in this class writes to the file. What it discriminates is the file: the
    ; other endpoint answers another file's rows, or none at all.
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Rows("messages", 5, .tPortRows, .tPortStatus, .tPortFault)
    Do $$$AssertEquals(tPortStatus, 200, "the port answers the same key directly")
    If tPortStatus '= 200 Quit
    Do $$$AssertTrue(tPortRows.%Size() > 0, "with rows of its own: " _ tPortRows.%Size())
    If tPortRows.%Size() = 0 Quit
    Do $$$AssertEquals(tResult.rows.%Get(tResult.rows.%Size() - 1).%Get("text"), tPortRows.%Get(tPortRows.%Size() - 1).%Get("text"), "and the tool's oldest row in the window is the console log's, not another file's")
}

/// <p>Story 2.12 AC5 -- the tool never reaches <code>ErrorDetail</code>, observed on the fixture's
/// own counter rather than asserted from the payload's shape. A projection that fetched the detail
/// and then dropped it would answer the same five fields.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Tool.ErrorRead.View</method> read the detail level
/// before projecting -&gt; the counter reads non-zero and this goes red alone.</p>
Method TestTheErrorReadToolNeverReachesTheDetailQuery()
{
    Do ##class(OcuPilot.Test.ErrorLogFixture).Clear()
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("namespaces", "", "", "", "", .tNamespaces, .tStatus, .tFault)
    ; Asserted, not merely guarded: an early Quit with no assertion behind it records zero
    ; assertions, and %UnitTest grades a method by its failures -- so this method would report
    ; green on a run where the tool was never called at all, and AC5's tool-path witness would be
    ; verified by nothing.
    Do $$$AssertEquals(tStatus, 200, "the namespaces level answers, so there is a subject for the tool to read")
    If tStatus '= 200 Quit
    Set tNamespace = ""
    Set tDate = ""
    Set tNsIterator = tNamespaces.rows.%GetIterator()
    While tNsIterator.%GetNext(.tIndex, .tRow) {
        If tNamespace '= "" Continue
        Set tDateSC = ##class(OcuPilot.Port.LogSourcePort).Errors("dates", tRow.namespace, "", "", "", .tDates, .tDateStatus, .tFault)
        If (tDateStatus = 200) && (tDates.rows.%Size() > 0) {
            Set tNamespace = tRow.namespace
            Set tDate = tDates.rows.%Get(0).date
        }
    }
    Do $$$AssertNotEquals(tNamespace, "", "this instance records at least one application error to read")
    If tNamespace = "" Quit

    Do ##class(OcuPilot.Test.ErrorLogFixture).ClearCounts()
    Set tSC = ##class(OcuPilot.Test.ErrorReadProbe).View("", {"namespace": (tNamespace), "date": (tDate)}, 5, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool answers through the counting port")
    Do $$$AssertTrue(##class(OcuPilot.Test.ErrorLogFixture).Queries() > 0, "through the supported queries: " _ ##class(OcuPilot.Test.ErrorLogFixture).Queries())
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogFixture).Details(), 0, "and never through ErrorDetail (AD-48)")
    Do ##class(OcuPilot.Test.ErrorLogFixture).Clear()
}

/// <p>A copy of <var>pDeclaration</var> to mutate.</p>
ClassMethod Mutated(pDeclaration As %DynamicObject) As %DynamicObject
{
    Quit ##class(%DynamicObject).%FromJSON(pDeclaration.%ToJSON())
}

/// <p>Arm eight canned rows whose names sort and filter distinctly, each with a secret value.</p>
ClassMethod ArmRows()
{
    Set tRows = []
    For tName = "/csp/b1", "/csp/a1", "/csp/b3", "/CSP/b2", "/csp/B5", "/csp/c1", "/csp/b4", "/other/b6" {
        Do tRows.%Push({"Name": (tName), "NameSpace": "USER", "Enabled": true, "Secret": ("secret-" _ tName)})
    }
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("list")
    Do ##class(OcuPilot.Test.EndpointFixture).SetRows(tRows.%ToJSON())
}

}
