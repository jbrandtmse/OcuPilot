/// <p>Story 18.12's completeness test over Epic 18's screens and write tools: every Stage 2 screen reaches the agent
/// through its descriptor alone, with no hand-written dispatch or field list (AD-3, AD-5, AD-53).</p>
/// <p><b>Screens.</b> The <code>Roster</code> names one row per screen Epic 18 added, by kind, and the
/// <code>Elsewhere</code> block every other screen the registry holds: the two together are every registered screen,
/// each once, so a screen added later reddens this class until it takes a roster row (an Epic 18 screen) or an
/// <code>Elsewhere</code> row (any other). A <code>form</code> declares no read, no action and binds no write tool, and
/// its <code>list</code> reads and binds one. A <code>read-only</code>
/// screen reads and declares no action and binds no tool, and carries the reason. A <code>writes</code> screen reads and
/// binds at least one write tool. A reading screen's <code>&lt;toolIdentifier&gt;.read</code> is listed and bound to it.</p>
/// <p><b>Actions.</b> Each row action of a <code>writes</code> screen resolves, by the rule
/// <class>OcuPilot.Api.ScreenAction</class> applies (a write tool whose <code>DESCRIPTORCLASS</code> is the screen and whose
/// <code>SCREENACTIONS</code> holds the id), to exactly one tool. The primary action does too, or resolves to the one
/// bound tool that creates. Every bound tool is advertised but AD-53's three.</p>
/// <p>A <code>writes</code> row that names a <code>route</code> is the exception (Story 18.46): its actions are sent to
/// <code>POST /&lt;route&gt;</code>, which the router's URL map holds, not to the screen action route; the screen binds one
/// tool, which is unadvertised and declares no <code>SCREENACTIONS</code>, so that route reaches none of its actions.</p>
/// <p><b>Fields.</b> For every bound tool, and every <code>&lt;tool/&gt;</code> row (a tool Epic 18 bound to an earlier
/// screen): the registry lists it as a write of its own class, every field its generated list admits is settable, and
/// every other settable name but the id argument is the first path segment of its generated entry, or the tool's port is
/// not the admin port (AD-51, AD-52). A failure names <code>tool:name</code>.</p>
/// <p>Needs a compiled instance; makes no request and writes nothing.</p>
Class OcuPilot.Test.StageTwoTools Extends %UnitTest.TestCase
{

/// <p>The package every screen descriptor sits in; roster rows name a descriptor without it.</p>
Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The three write tools AD-53 keeps off the agent's list.</p>
Parameter UNADVERTISED = "osmgmt.licensekey.activate,security.secrets.replacesymmetric,security.alloweddirectories.update";

Parameter ADMINPORT = "OcuPilot.Port.AdminPort";

Parameter FIELDSCLASS = "OcuPilot.Screen.Tool.ToolFields";

/// <p>The roster. A <code>&lt;screen/&gt;</code> row names a screen, its kind and, for a form, the list it is the form
/// of, or, for a read-only screen, why it has no write. A <code>&lt;tool/&gt;</code> row names a write tool Epic 18
/// bound to an earlier screen.</p>
XData Roster
{
<roster>
<screen name="AllowedDirectoryList" kind="writes" route="allowed-directories"/>
<screen name="AuthOptions" kind="writes"/>
<screen name="DataElementEncryption" kind="writes"/>
<screen name="DatabaseEncryption" kind="writes"/>
<screen name="DocDbAppList" kind="writes"/>
<screen name="EcpDataServerList" kind="writes"/>
<screen name="EcpSettings" kind="writes"/>
<screen name="EcpSslConnectionTab" kind="writes"/>
<screen name="EncryptionKeyFile" kind="writes"/>
<screen name="EncryptionKeyFileAdminList" kind="writes"/>
<screen name="EncryptionStartup" kind="writes"/>
<screen name="GlobalMappingList" kind="writes"/>
<screen name="JournalList" kind="writes"/>
<screen name="JournalSettings" kind="writes"/>
<screen name="LicenseKey" kind="writes"/>
<screen name="LicenseServerList" kind="writes"/>
<screen name="LocalDatabaseList" kind="writes"/>
<screen name="MftConnectionList" kind="writes"/>
<screen name="NamespaceList" kind="writes"/>
<screen name="PackageMappingList" kind="writes"/>
<screen name="RemoteDatabaseList" kind="writes"/>
<screen name="RoutineAppList" kind="writes"/>
<screen name="RoutineMappingList" kind="writes"/>
<screen name="SuperserverList" kind="writes"/>
<screen name="WebAppPctAccessList" kind="writes"/>
<screen name="DatabaseIntegrity" kind="form" list="DatabaseList"/>
<screen name="DocDbAppForm" kind="form" list="DocDbAppList"/>
<screen name="EcpDataServerForm" kind="form" list="EcpDataServerList"/>
<screen name="EncryptionKeyFileForm" kind="form" list="EncryptionKeyFile"/>
<screen name="GlobalMappingForm" kind="form" list="GlobalMappingList"/>
<screen name="LicenseServerForm" kind="form" list="LicenseServerList"/>
<screen name="LocalDatabaseForm" kind="form" list="LocalDatabaseList"/>
<screen name="MftConnectionForm" kind="form" list="MftConnectionList"/>
<screen name="NamespaceForm" kind="form" list="NamespaceList"/>
<screen name="PackageMappingForm" kind="form" list="PackageMappingList"/>
<screen name="RemoteDatabaseForm" kind="form" list="RemoteDatabaseList"/>
<screen name="RoutineAppForm" kind="form" list="RoutineAppList"/>
<screen name="RoutineMappingForm" kind="form" list="RoutineMappingList"/>
<screen name="SuperserverForm" kind="form" list="SuperserverList"/>
<screen name="DatabaseIntegrityLog" kind="read-only" reason="the output of an integrity check, which the instance writes"/>
<screen name="EcpAppServerTab" kind="read-only" reason="the connection state of the ECP application servers"/>
<screen name="JournalFileDatabaseList" kind="read-only" reason="the databases one journal file holds records for"/>
<screen name="JournalFileDetails" kind="read-only" reason="one journal file's properties, which the instance writes"/>
<screen name="JournalRecordList" kind="read-only" reason="a browser over journaled records, which no write changes"/>
<screen name="MetricsList" kind="read-only" reason="the instance's metrics, which no write changes"/>
<screen name="SqlAdminPrivilegeList" kind="read-only" reason="the grants are the user and role tools' writes"/>
<screen name="SqlColumnPrivilegeList" kind="read-only" reason="the grants are the user and role tools' writes"/>
<screen name="SqlPrivilegeList" kind="read-only" reason="the grants are the user and role tools' writes"/>
<screen name="DashboardEcp" kind="read-only" reason="a drill-down of the Dashboard's statistics"/>
<screen name="DashboardGlobals" kind="read-only" reason="a drill-down of the Dashboard's statistics"/>
<screen name="DashboardProcesses" kind="read-only" reason="a drill-down of the Dashboard's statistics"/>
<screen name="DashboardResources" kind="read-only" reason="a drill-down of the Dashboard's statistics"/>
<screen name="InteropUsageTab" kind="read-only" reason="the interoperability usage the instance records, which no write changes"/>
<screen name="InteropUsageVolumeTab" kind="read-only" reason="the interoperability usage the instance records, which no write changes"/>
<screen name="InteropUsageImpactTab" kind="read-only" reason="the interoperability usage the instance records, which no write changes"/>
<screen name="RoutineAppRoleList" kind="read-only" reason="a list the application's update tool replaces whole"/>
<screen name="RoutineAppRoutineList" kind="read-only" reason="a list the application's update tool replaces whole"/>
<screen name="WebAppRoleList" kind="read-only" reason="a list the application's update tool replaces whole"/>
<tool name="osmgmt.databasedetails.mount"/>
<tool name="osmgmt.databasedetails.dismount"/>
<tool name="osmgmt.databasedetails.truncate"/>
<tool name="osmgmt.databasedetails.compact"/>
<tool name="osmgmt.databasedetails.defragment"/>
<tool name="osmgmt.databases.integrity"/>
<tool name="permissions.users.copy"/>
<tool name="permissions.users.grantsql"/>
<tool name="permissions.users.revokesql"/>
<tool name="permissions.roles.grantsql"/>
<tool name="permissions.roles.revokesql"/>
<tool name="security.secrets.creatersa"/>
<tool name="security.secrets.createsymmetric"/>
<tool name="security.secrets.replacersa"/>
<tool name="security.secrets.replacesymmetric"/>
<tool name="webapp.restapis.create"/>
<tool name="webapp.restapis.delete"/>
</roster>
}

/// <p>Every registered screen another epic added, one row each: with the roster's screens, every screen the registry
/// holds (<method>TestTheRosterAndElsewhereAreEveryRegisteredScreen</method>).</p>
XData Elsewhere
{
<elsewhere>
<screen name="AgentDefinitionForm"/>
<screen name="AgentDefinitionList"/>
<screen name="AgentGovernance"/>
<screen name="AgentGuardrails"/>
<screen name="AgentLedger"/>
<screen name="AgentScreenPermissions"/>
<screen name="AgentSwitches"/>
<screen name="AgentTranscript"/>
<screen name="AgentTranscripts"/>
<screen name="AnalyticsAnalyzerLink"/>
<screen name="AnalyticsArchitectLink"/>
<screen name="AnalyticsCubeDimensionsTab"/>
<screen name="AnalyticsCubeList"/>
<screen name="AnalyticsCubeMeasuresTab"/>
<screen name="AnalyticsCubeRelationshipsTab"/>
<screen name="AnalyticsFolderItemList"/>
<screen name="AnalyticsTermListEntryList"/>
<screen name="AnalyticsTermListList"/>
<screen name="AnalyticsUserPortalLink"/>
<screen name="AuditList"/>
<screen name="AuditSystemEventList"/>
<screen name="AuditUserEventList"/>
<screen name="AuditingConfig"/>
<screen name="BackgroundTaskList"/>
<screen name="Dashboard"/>
<screen name="DatabaseDetails"/>
<screen name="DatabaseFreeSpace"/>
<screen name="DatabaseList"/>
<screen name="DatabaseVolumeList"/>
<screen name="DeviceForm"/>
<screen name="DeviceList"/>
<screen name="ExplorerClassDocument"/>
<screen name="ExplorerClassEditor"/>
<screen name="ExplorerClassList"/>
<screen name="ExplorerCompare"/>
<screen name="ExplorerDocDbList"/>
<screen name="ExplorerMacro"/>
<screen name="ExplorerRoutineDocument"/>
<screen name="ExplorerRoutineEditor"/>
<screen name="ExplorerRoutineList"/>
<screen name="ExplorerSearch"/>
<screen name="ExplorerSqlCachedQueries"/>
<screen name="ExplorerSqlConstraints"/>
<screen name="ExplorerSqlData"/>
<screen name="ExplorerSqlFields"/>
<screen name="ExplorerSqlIndices"/>
<screen name="ExplorerSqlPartitionMappings"/>
<screen name="ExplorerSqlPartitions"/>
<screen name="ExplorerSqlProcedure"/>
<screen name="ExplorerSqlProcedureStatements"/>
<screen name="ExplorerSqlProcedures"/>
<screen name="ExplorerSqlQuery"/>
<screen name="ExplorerSqlSchemas"/>
<screen name="ExplorerSqlTable"/>
<screen name="ExplorerSqlTableStatements"/>
<screen name="ExplorerSqlTables"/>
<screen name="ExplorerSqlTriggers"/>
<screen name="ExplorerSqlView"/>
<screen name="ExplorerSqlViewFields"/>
<screen name="ExplorerSqlViewStatements"/>
<screen name="ExplorerSqlViews"/>
<screen name="Home"/>
<screen name="InteropBusinessPartnerList"/>
<screen name="InteropItemJobTab"/>
<screen name="InteropItemList"/>
<screen name="InteropItemLogTab"/>
<screen name="InteropItemMessageTab"/>
<screen name="InteropItemQueueTab"/>
<screen name="InteropItemSettingList"/>
<screen name="InteropItemStatusTab"/>
<screen name="InteropItemTestTab"/>
<screen name="InteropJobList"/>
<screen name="InteropLookupEntryList"/>
<screen name="InteropLookupTableList"/>
<screen name="InteropMessageContentsTab"/>
<screen name="InteropMessageHeaderTab"/>
<screen name="InteropMessageList"/>
<screen name="InteropMessageTraceTab"/>
<screen name="InteropMonitorList"/>
<screen name="InteropProcessEditor"/>
<screen name="InteropProcessList"/>
<screen name="InteropProductionDiagram"/>
<screen name="InteropProductionList"/>
<screen name="InteropQueueList"/>
<screen name="InteropQueueMessageList"/>
<screen name="InteropRuleEditor"/>
<screen name="InteropRuleList"/>
<screen name="InteropSchemaViewer"/>
<screen name="InteropTransformEditor"/>
<screen name="InteropTransformList"/>
<screen name="LanguageServerActivity"/>
<screen name="LanguageServerForm"/>
<screen name="LanguageServerList"/>
<screen name="LdapConfigForm"/>
<screen name="LdapConfigList"/>
<screen name="LicenseDistributedTab"/>
<screen name="LicenseProcessTab"/>
<screen name="LicenseSummaryTab"/>
<screen name="LicenseUserTab"/>
<screen name="LockList"/>
<screen name="LogAlertViewer"/>
<screen name="LogAnalyticsViewer"/>
<screen name="LogErrorList"/>
<screen name="LogEventViewer"/>
<screen name="LogHub"/>
<screen name="LogMessageViewer"/>
<screen name="LogSqlDiagnosticsViewer"/>
<screen name="LogSystemMonitorViewer"/>
<screen name="LogTaskErrorViewer"/>
<screen name="LogXdbcViewer"/>
<screen name="OAuthClientForm"/>
<screen name="OAuthClientTab"/>
<screen name="OAuthResourceServerForm"/>
<screen name="OAuthResourceServerTab"/>
<screen name="OAuthServerClientForm"/>
<screen name="OAuthServerClientTab"/>
<screen name="OAuthServerDescriptionForm"/>
<screen name="OAuthServerDescriptionTab"/>
<screen name="OAuthServerForm"/>
<screen name="OAuthServerTab"/>
<screen name="OpenApiViewer"/>
<screen name="ProcessDetails"/>
<screen name="ProcessList"/>
<screen name="ResourceList"/>
<screen name="RestApiList"/>
<screen name="RoleForm"/>
<screen name="RoleList"/>
<screen name="ServiceForm"/>
<screen name="ServiceList"/>
<screen name="SqlActivityList"/>
<screen name="SslConfigList"/>
<screen name="SslForm"/>
<screen name="SystemUsage"/>
<screen name="TaskDetails"/>
<screen name="TaskForm"/>
<screen name="TaskHistoryList"/>
<screen name="TaskOnDemandList"/>
<screen name="TaskRunList"/>
<screen name="TaskScheduleList"/>
<screen name="TaskUpcomingList"/>
<screen name="UserForm"/>
<screen name="UserList"/>
<screen name="WalletCollectionList"/>
<screen name="WalletSecretForm"/>
<screen name="WalletSecretList"/>
<screen name="WebAppForm"/>
<screen name="WebAppList"/>
<screen name="WebSessionList"/>
<screen name="X509CredentialList"/>
<screen name="X509Form"/>
</elsewhere>
}

/// <p>Each roster screen is registered, built and its row's kind; every reading screen's read tool is listed and bound to
/// it.</p>
/// <p>Mutation (Rule 19): declare <code>"built": false</code> in
/// <class>OcuPilot.Screen.Descriptor.JournalFileDatabaseList</class> -- its row goes red.</p>
Method TestEachScreenIsItsRowsKind()
{
    Set tSC = ..Load(.tScreens, .tOrder, .tToolRows, .tWrites, .tReads, .tBound)
    Do $$$AssertStatusOK(tSC, "the roster and the registries are read")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tRegistered)
    Do $$$AssertStatusOK(tSC, "the screen registry lists")
    Do $$$AssertTrue($ListLength(tOrder) > 0, "the roster holds screens")
    For tI = 1:1:$ListLength(tOrder) {
        Set tName = $List(tOrder, tI)
        Set tKind = $List(tScreens(tName), 1)
        Set tClass = ..#DESCRIPTORPACKAGE _ tName
        Do $$$AssertTrue(($ListFind(tRegistered, tClass) > 0), tName _ " is registered")
        If '$ListFind(tRegistered, tClass) Continue
        Do $$$AssertEquals($ClassMethod(tClass, "IsBuilt"), 1, tName _ " is built")
        Set tReading = $IsObject($ClassMethod(tClass, "Read"))
        Set tBoundCount = ..Count(.tBound, tClass)
        If tKind = "form" {
            Do $$$AssertEquals(tReading, 0, tName _ " declares no read")
            Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "", tName _ " declares no primary action")
            Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 0, tName _ " declares no row action")
            Do $$$AssertEquals(tBoundCount, 0, tName _ " binds no write tool")
            Set tList = ..#DESCRIPTORPACKAGE _ $List(tScreens(tName), 2)
            Do $$$AssertTrue(($ListFind(tRegistered, tList) > 0), tName _ "'s list is registered")
            If '$ListFind(tRegistered, tList) Continue
            Do $$$AssertEquals($IsObject($ClassMethod(tList, "Read")), 1, tName _ "'s list reads")
            Do $$$AssertTrue(..Count(.tBound, tList) > 0, tName _ "'s list binds a write tool")
            Do $$$AssertTrue(..ReadTool(.tReads, tList) '= "", tName _ "'s list's read tool is listed")
        } ElseIf tKind = "read-only" {
            Do $$$AssertEquals(tReading, 1, tName _ " reads")
            Do $$$AssertNotEquals($List(tScreens(tName), 3), "", tName _ " carries the reason it has no write")
            Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId"), "", tName _ " declares no primary action")
            Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")), 0, tName _ " declares no row action")
            Do $$$AssertEquals(tBoundCount, 0, tName _ " binds no write tool")
        } Else {
            Do $$$AssertEquals(tReading, 1, tName _ " reads")
            Do $$$AssertTrue(tBoundCount > 0, tName _ " binds a write tool")
        }
        If tReading {
            Set tReadName = ..ReadTool(.tReads, tClass)
            Do $$$AssertEquals(tReadName, $ClassMethod(tClass, "ToolIdentifier") _ ".read", tName _ "'s read tool is its tool identifier's read")
        }
    }
}

/// <p>Each row action of a <code>writes</code> screen resolves to exactly one write tool of its own descriptor, its
/// primary action to one or to the one tool that creates, and every bound tool is advertised but AD-53's three.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.RoutineAppDelete.SCREENACTIONS</parameter> -- the
/// application list's <code>delete</code> resolves to no tool and goes red; give
/// <class>OcuPilot.Screen.Tool.AllowedDirectoryUpdate</class> a <code>SCREENACTIONS</code> of <code>add</code> -- the
/// Allowed directories row goes red.</p>
Method TestEachDeclaredActionResolvesToExactlyOneWriteTool()
{
    Set tSC = ..Load(.tScreens, .tOrder, .tToolRows, .tWrites, .tReads, .tBound)
    Do $$$AssertStatusOK(tSC, "the roster and the registries are read")
    If $$$ISERR(tSC) Quit
    Set tActions = 0
    For tI = 1:1:$ListLength(tOrder) {
        Set tName = $List(tOrder, tI)
        If $List(tScreens(tName), 1) '= "writes" Continue
        Set tClass = ..#DESCRIPTORPACKAGE _ tName
        Set tIds = $ClassMethod(tClass, "RowActionIds")
        If $List(tScreens(tName), 4) '= "" {
            Set tActions = tActions + ..CheckRouted(.tBound, .tWrites, tClass, tName, $List(tScreens(tName), 4))
            Continue
        }
        For tJ = 1:1:$ListLength(tIds) {
            Set tActions = tActions + 1
            Set tId = $List(tIds, tJ)
            Do $$$AssertEquals(..Resolving(.tBound, tClass, tId), 1, tName _ ":" _ tId _ " resolves to exactly one write tool")
        }
        Set tPrimary = $ClassMethod(tClass, "PrimaryActionId")
        If tPrimary = "" Continue
        Set tActions = tActions + 1
        Set tClaiming = ..Resolving(.tBound, tClass, tPrimary)
        Do $$$AssertTrue(tClaiming <= 1, tName _ ":" _ tPrimary _ " is claimed by at most one write tool")
        If tClaiming '= 0 Continue
        Do $$$AssertEquals(..Creating(.tBound, tClass), 1, tName _ ":" _ tPrimary _ " resolves to no tool by id and so to the one bound tool that creates")
    }
    Do $$$AssertTrue(tActions > 0, "the roster declares actions")
    Set tName = ""
    For {
        Set tName = $Order(tWrites(tName))
        If tName = "" Quit
        If '..IsBoundToRoster(.tBound, .tScreens, .tToolRows, tName) Continue
        Set tAdvertised = ''##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tWrites(tName))
        Do $$$AssertEquals(tAdvertised, '$ListFind($ListFromString(..#UNADVERTISED), tName), tName _ " is advertised unless AD-53 keeps it off the agent's list")
    }
    For tI = 1:1:$Length(..#UNADVERTISED, ",") {
        Set tName = $Piece(..#UNADVERTISED, ",", tI)
        Do $$$AssertTrue($Data(tWrites(tName)), tName _ " is a listed write tool")
    }
}

/// <p>Each bound tool and each <code>&lt;tool/&gt;</code> row is listed as a write of its own class, its admitted fields
/// are settable, and each other settable name but its id argument is authored on one of its generated entry's paths or
/// belongs to a tool whose port is not the admin port.</p>
/// <p>Mutation (Rule 19): add <code>Bogus</code> to <method>OcuPilot.Screen.Tool.RoutineAppUpdate.SettableFields</method>
/// -- <code>webapp.routineapps.update:Bogus</code> goes red; make
/// <parameter>OcuPilot.Screen.Tool.LocalDatabaseCreate.PORTCLASS</parameter> the admin port -- its authored names go red.</p>
Method TestEverySettableNameComesFromTheGeneratedFieldList()
{
    Set tSC = ..Load(.tScreens, .tOrder, .tToolRows, .tWrites, .tReads, .tBound)
    Do $$$AssertStatusOK(tSC, "the roster and the registries are read")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Entries(.tEntries)
    Do $$$AssertStatusOK(tSC, "the generated field lists are read")
    If $$$ISERR(tSC) Quit
    Set tChecked = 0
    Set tName = ""
    For {
        Set tName = $Order(tToolRows(tName))
        If tName = "" Quit
        Do $$$AssertTrue($Data(tWrites(tName)), tName _ " is a listed write tool, so its roster row names a tool")
    }
    Set tName = ""
    For {
        Set tName = $Order(tWrites(tName))
        If tName = "" Quit
        If '..IsBoundToRoster(.tBound, .tScreens, .tToolRows, tName) Continue
        Set tClass = tWrites(tName).class
        Set tChecked = tChecked + 1
        Do $$$AssertEquals($Parameter(tClass, "TOOLNAME"), tName, tName _ " is a write of its own class " _ tClass)
        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tAdmitted = $ClassMethod(tClass, "AdmittedFields")
        Set tAdminPort = ($ClassMethod(tClass, "PortClass") = ..#ADMINPORT)
        For tK = 1:1:$ListLength(tAdmitted) {
            Set tField = $List(tAdmitted, tK)
            Do $$$AssertTrue($ListFind(tSettable, tField) > 0, tName _ ":" _ tField _ " is admitted from the generated list and is settable")
        }
        Set tIdArgument = $ClassMethod(tClass, "IdArgument")
        For tK = 1:1:$ListLength(tSettable) {
            Set tField = $List(tSettable, tK)
            If (tField = tIdArgument) || $ListFind(tAdmitted, tField) Continue
            Do $$$AssertTrue('tAdminPort || $Data(tEntries(tName, tField)), tName _ ":" _ tField _ " is authored on a path of its generated entry, or its port is not the admin port")
        }
    }
    Do $$$AssertTrue(tChecked > 0, "the roster binds write tools")
}

/// <p>The roster's screens and the <code>Elsewhere</code> rows are every screen the registry holds, each once: a
/// registered screen on neither list, a screen on both, and a row naming no registered screen each go red naming it.</p>
/// <p>Mutation (Rule 19): delete the <code>RoutineAppRoleList</code> roster row -- it goes red as a registered screen on
/// neither list.</p>
Method TestTheRosterAndElsewhereAreEveryRegisteredScreen()
{
    Set tSC = ..Load(.tScreens, .tOrder, .tToolRows, .tWrites, .tReads, .tBound)
    Do $$$AssertStatusOK(tSC, "the roster and the registries are read")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Elsewhere(.tElsewhere)
    Do $$$AssertStatusOK(tSC, "the Elsewhere rows are read")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.SurfaceCoverage).DeriveScreens(.tRegistered)
    Do $$$AssertStatusOK(tSC, "the registered screens derive from the screen registry")
    If $$$ISERR(tSC) Quit
    Set tCount = 0
    Set tName = ""
    For {
        Set tName = $Order(tRegistered(tName))
        If tName = "" Quit
        Set tCount = tCount + 1
        Do $$$AssertTrue($Data(tScreens(tName)) || $Data(tElsewhere(tName)), tName _ " is registered, so it takes a roster row (a screen Epic 18 added) or an Elsewhere row (any other)")
    }
    Do $$$AssertTrue(tCount > 0, "the registry holds screens; a run over none would pass having checked nothing")
    Set tName = ""
    For {
        Set tName = $Order(tScreens(tName))
        If tName = "" Quit
        Do $$$AssertTrue('$Data(tElsewhere(tName)), tName _ " is on the roster and not also Elsewhere")
    }
    Set tName = ""
    For {
        Set tName = $Order(tElsewhere(tName))
        If tName = "" Quit
        Do $$$AssertTrue($Data(tRegistered(tName)) > 0, tName _ " has an Elsewhere row, so it names a registered screen")
    }
}

/// <p>The roster, the tool listing and the bound-tool index. <var>pScreens</var>(name) is
/// <code>$ListBuild(kind, list, reason, route)</code> and <var>pOrder</var> the names in roster order; <var>pToolRows</var>
/// holds the <code>&lt;tool/&gt;</code> names; <var>pWrites</var>(name) is a write tool's listing entry and
/// <var>pReads</var>(descriptor) a descriptor's read tool's name; <var>pBound</var>(descriptor, name) is a write tool's class.</p>
ClassMethod Load(Output pScreens, Output pOrder, Output pToolRows, Output pWrites, Output pReads, Output pBound) As %Status
{
    Set tSC = $$$OK
    Kill pScreens, pToolRows, pWrites, pReads, pBound
    Set pOrder = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Roster", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Roster XData block could not be opened")
            Quit
        }
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            Set tName = ..Attribute(tLine, "name")
            If tLine [ "<screen " {
                Set tKind = ..Attribute(tLine, "kind")
                If (tName = "") || '$ListFind($ListBuild("writes", "form", "read-only"), tKind) || $Data(pScreens(tName)) || (tKind = "form" && (..Attribute(tLine, "list") = "")) {
                    Set tSC = $$$ERROR($$$GeneralError, "a roster screen row is malformed or repeated: " _ tLine)
                    Quit
                }
                Set pScreens(tName) = $ListBuild(tKind, ..Attribute(tLine, "list"), ..Attribute(tLine, "reason"), ..Attribute(tLine, "route"))
                Set pOrder = pOrder _ $ListBuild(tName)
            } ElseIf tLine [ "<tool " {
                If (tName = "") || $Data(pToolRows(tName)) {
                    Set tSC = $$$ERROR($$$GeneralError, "a roster tool row is malformed or repeated: " _ tLine)
                    Quit
                }
                Set pToolRows(tName) = ""
            }
        }
        Set tXData = ""
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tTools) || (tTools.%Size() = 0) {
            Set tSC = $$$ERROR($$$GeneralError, "the tool registry listed nothing, which is a failed derivation rather than no tools")
            Quit
        }
        Set tIterator = tTools.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTool) {
            If tTool.kind = "read" {
                If tTool.descriptor '= "" Set pReads(tTool.descriptor) = tTool.name
                Continue
            }
            If (tTool.kind '= "write") || (tTool.class = "") Continue
            Set pWrites(tTool.name) = tTool
            Set tDescriptor = $Parameter(tTool.class, "DESCRIPTORCLASS")
            If tDescriptor '= "" Set pBound(tDescriptor, tTool.name) = tTool.class
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The <code>Elsewhere</code> rows as <var>pNames</var>(name). A row with no name, or a name twice, is an error.</p>
ClassMethod Elsewhere(Output pNames) As %Status
{
    Set tSC = $$$OK
    Kill pNames
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Elsewhere", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Elsewhere XData block could not be opened")
            Quit
        }
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            If tLine '[ "<screen " Continue
            Set tName = ..Attribute(tLine, "name")
            If (tName = "") || $Data(pNames(tName)) {
                Set tSC = $$$ERROR($$$GeneralError, "an Elsewhere row is malformed or repeated: " _ tLine)
                Quit
            }
            Set pNames(tName) = ""
        }
        Set tXData = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The check a routed <code>writes</code> row gets (Story 18.46): <var>pRoute</var> is a <code>POST</code> route of the
/// router, the screen binds exactly one write tool, which is unadvertised and declares no screen action, and the screen
/// declares at least one action, none of which the screen action route resolves. Answers how many actions it checked.</p>
Method CheckRouted(ByRef pBound, ByRef pWrites, pClass As %String, pName As %String, pRoute As %String) As %Integer [ Private ]
{
    Set tFound = 0
    Set tRoutes = ##class(OcuPilot.Test.SaveHoldCoverage).Routes()
    For tI = 1:1:$ListLength(tRoutes) {
        Set tRoute = $List(tRoutes, tI)
        If ($List(tRoute, 1) = ("/" _ pRoute)) && ($List(tRoute, 2) = "POST") Set tFound = 1
    }
    Do $$$AssertEquals(tFound, 1, pName _ ": POST /" _ pRoute _ " is a route of the router, which its actions are sent to")
    Do $$$AssertEquals(..Count(.pBound, pClass), 1, pName _ " binds exactly one write tool")
    Set tToolName = $Order(pBound(pClass, ""), 1, tToolClass)
    If tToolName = "" Quit 0
    Do $$$AssertEquals(''##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(pWrites(tToolName)), 0, pName _ ":" _ tToolName _ " is unadvertised, so no provider list carries it")
    Do $$$AssertEquals($ListLength($ClassMethod(tToolClass, "ScreenActionIds")), 0, pName _ ":" _ tToolName _ " declares no SCREENACTIONS, so the screen action route reaches no tool for it")
    Set tIds = $ClassMethod(pClass, "RowActionIds")
    Set tPrimary = $ClassMethod(pClass, "PrimaryActionId")
    Set tActions = $ListLength(tIds) + (tPrimary '= "")
    Do $$$AssertTrue(tActions > 0, pName _ " declares actions, which are sent through POST /" _ pRoute)
    For tI = 1:1:$ListLength(tIds) {
        Do $$$AssertEquals(..Resolving(.pBound, pClass, $List(tIds, tI)), 0, pName _ ":" _ $List(tIds, tI) _ " resolves to no tool on the screen action route, because it is sent through POST /" _ pRoute)
    }
    Quit tActions
}

/// <p>How many write tools are bound to <var>pDescriptor</var>.</p>
ClassMethod Count(ByRef pBound, pDescriptor As %String) As %Integer [ Private ]
{
    Set tCount = 0
    Set tName = ""
    For {
        Set tName = $Order(pBound(pDescriptor, tName))
        If tName = "" Quit
        Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>How many write tools of <var>pDescriptor</var> carry out the row action <var>pId</var>: the rule
/// <class>OcuPilot.Api.ScreenAction</class> resolves a tool by.</p>
ClassMethod Resolving(ByRef pBound, pDescriptor As %String, pId As %String) As %Integer [ Private ]
{
    Set tCount = 0
    Set tName = ""
    For {
        Set tName = $Order(pBound(pDescriptor, tName), 1, tClass)
        If tName = "" Quit
        If $ListFind($ClassMethod(tClass, "ScreenActionIds"), pId) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>How many write tools of <var>pDescriptor</var> create their target.</p>
ClassMethod Creating(ByRef pBound, pDescriptor As %String) As %Integer [ Private ]
{
    Set tCount = 0
    Set tName = ""
    For {
        Set tName = $Order(pBound(pDescriptor, tName), 1, tClass)
        If tName = "" Quit
        If $ClassMethod(tClass, "Creates") Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The read tool the registry lists for <var>pDescriptor</var>, or <code>""</code>.</p>
ClassMethod ReadTool(ByRef pReads, pDescriptor As %String) As %String [ Private ]
{
    Quit $Get(pReads(pDescriptor))
}

/// <p>Whether the write tool <var>pName</var> is bound to a roster <code>writes</code> screen or named by a
/// <code>&lt;tool/&gt;</code> row.</p>
ClassMethod IsBoundToRoster(ByRef pBound, ByRef pScreens, ByRef pToolRows, pName As %String) As %Boolean [ Private ]
{
    If $Data(pToolRows(pName)) Quit 1
    Set tFound = 0
    Set tScreen = ""
    For {
        Set tScreen = $Order(pScreens(tScreen), 1, tRow)
        If tScreen = "" Quit
        If ($List(tRow, 1) = "writes") && $Data(pBound(..#DESCRIPTORPACKAGE _ tScreen, pName)) {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>The generated field lists as <var>pEntries</var>(tool, first path segment), read from
/// <class>OcuPilot.Screen.Tool.ToolFields</class>' <code>Tools</code> block.</p>
ClassMethod Entries(Output pEntries) As %Status
{
    Set tSC = $$$OK
    Kill pEntries
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#FIELDSCLASS, "Tools", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the generated tool field lists are missing from " _ ..#FIELDSCLASS)
            Quit
        }
        Do tXData.Data.Rewind()
        Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        Set tIterator = tTools.%GetIterator()
        While tIterator.%GetNext(.tTool, .tEntry) {
            Set tFields = tEntry.%Get("fields").%GetIterator()
            While tFields.%GetNext(.tIndex, .tField) {
                Set pEntries(tTool, $Piece($Piece(tField.%Get("path"), ".", 1), "[", 1)) = ""
            }
        }
    } Catch ex {
        Kill pEntries
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One double-quoted attribute value out of a roster row, matched with the space that precedes its name.</p>
ClassMethod Attribute(pLine As %String, pName As %String) As %String [ Private ]
{
    Set tNeedle = " " _ pName _ "="""
    If pLine '[ tNeedle Quit ""
    Quit $Piece($Piece(pLine, tNeedle, 2), """", 1)
}

}
