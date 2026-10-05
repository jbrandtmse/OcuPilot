/// <p>Pins Story 18.20's declarations (AC B1, B7): ECP data servers and its form -- their routes, side-bar
/// positions, pairs, classic pages, prompts, entity type, id rule and the caveat their doc comments
/// carry; the four tools' kinds, ports, fields, pairs and classic pages;
/// <class>OcuPilot.Api.EcpError</class>'s codes, fields and sentences; the baseline's four keys; the
/// delete's impact kind; and <class>OcuPilot.Port.EcpPort</class>'s script and license seam.</p>
/// <p>Story 18.21 adds ECP settings and ECP application servers' two tabs (C1, C4, C8): their declarations,
/// the four tools, the new codes and sentences, the four baseline keys, the two self-protection rules,
/// the settings script, the tools' copies of their sentences, and the guard that no test sends a
/// <code>MaxServerConn</code> change to the vendor.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and no custom resource assigned to
/// the replaced classic pages; for the settings script, no enabled <code>%ECPServer</code> and at most two
/// ECP data servers (a stock instance has neither). It writes nothing.</p>
Class OcuPilot.Test.EcpDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.EcpDataServerList";

Parameter FORM = "OcuPilot.Screen.Descriptor.EcpDataServerForm";

Parameter PORT = "OcuPilot.Port.EcpPort";

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

/// <p>The sentence both descriptors' doc comments carry for the caveat.</p>
Parameter CAVEAT = "These screens rely on the admin API's routes alone";

/// <p>Story 18.21's three descriptors.</p>
Parameter SETTINGS = "OcuPilot.Screen.Descriptor.EcpSettings";

Parameter APPTAB = "OcuPilot.Screen.Descriptor.EcpAppServerTab";

Parameter SSLTAB = "OcuPilot.Screen.Descriptor.EcpSslConnectionTab";

/// <p>The note the Connections read carries, <code>ecpDataServerStatusCaveat</code>'s value.</p>
Parameter NOTE = "Each status is what the instance reported when this list was read.";

/// <p>The test classes that may name <code>MaxServerConn</code>: the probe that reads and restores the
/// settings, the seam whose guard refuses a change, the write suite that sends one only through the seam,
/// this class, and Story 18.16's probe, whose snapshot reads it.</p>
Parameter MAXSERVERCONNCLASSES = "OcuPilot.Test.EcpDescriptor,OcuPilot.Test.EcpProbe,OcuPilot.Test.EcpSeamPort,OcuPilot.Test.EcpSettingsWrite,OcuPilot.Test.RemoteDatabaseProbe";

/// <p>B1: ECP data servers is OS management's seventeenth entry, a list over the vendor's
/// <code>ECP.DataServer</code> <code>LIST</code> with its seven fields, keyed by name with
/// <code>foldcase</code>, with Create, Change status and Delete, its seven columns, its two empty-state
/// keys, three prompts and the caveat in its doc comment.</p>
/// <p>Mutation (Rule 19): the read drops <code>Status</code> -- the fields leg goes red.</p>
Method TestEcpDataServersIsOsManagementsSeventeenthEntry()
{
    Set tClass = ..#LIST
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey _ ":" _ tDeclaration.archetype, "os-management:17:ecpDataServerListLabel:list", "OS management's seventeenth side-bar entry, a list")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""ECP.DataServer"",""type"":""LIST""}", "read through the vendor's data server LIST")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""Name"",""RemoteAddress"",""RemotePort"",""Status"",""MirrorConnection"",""SSLConfig"",""BatchMode""]", "its seven fields, the status among them")
    Do $$$AssertEquals(..Columns(tDeclaration), "Name:name,RemoteAddress:identifier,RemotePort:number,Status:status,MirrorConnection:status,SSLConfig:status,BatchMode:status", "its seven columns")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "OS management's two pairs")
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("ownPrivileges"), "unassigned", "and no own pair")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ $ClassMethod(tClass, "IdKind") _ "|" _ ##class(OcuPilot.Kernel.EntityRef).NormalizedId("ecp-data-server", "OcuProbeEcpA"), "ecp-data-server|instance|single|ocuprobeecpa", "one data server per row, keyed by its name in any case (AD-13)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "create|changestatus,delete", "Create, and Change status and Delete on a row")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.ECPDataServers", "the classic ECP Data Servers page (AD-44)")
    Do $$$AssertEquals(tDeclaration.emptyStateKey _ "|" _ tDeclaration.table.emptyAgentKey, "ecpDataServerListEmpty|ecpDataServerListEmptyAgent", "its two empty-state keys")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "with three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/ecp-data-servers") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.ecpdataservers"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
    Do $$$AssertTrue(..Description(tClass) [ ..#CAVEAT, "its doc comment carries the caveat")
}

/// <p>The form: built, unlisted, under the list's route, with the list's pairs, the classic data server
/// dialog, three prompts, no read of its own and the caveat in its doc comment.</p>
/// <p>Mutation (Rule 19): <code>sideBarPosition</code> 17 -- the position leg goes red.</p>
Method TestTheFormIsBuiltUnlistedWithTheListsPairs()
{
    Set tClass = ..#FORM
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.sideBarPosition, "os-management/ecp-data-servers/edit|form-page|0", "a form page under the list's route, taking no side-bar position")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), ..#SCREENPAIRS, "the list's own pairs")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ $ClassMethod(tClass, "PrimaryEntityType"), "%CSP.UI.Portal.Dialog.ECPDataServer|ecp-data-server", "the classic data server dialog, over the data server entity type")
    Do $$$AssertEquals($IsObject($ClassMethod(tClass, "Read")), 0, "and no read of its own")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "with three suggested prompts")
    Do $$$AssertEquals(tDeclaration.toolIdentifier, "osmgmt.ecpdataserverform", "its tool identifier")
    Do $$$AssertTrue(..Description(tClass) [ ..#CAVEAT, "its doc comment carries the caveat")
}

/// <p>The four tools: their descriptor, port, fields, request types, body, kind, advertisement, pairs
/// and classic pages (AD-8, AD-44, measured at Task 0).</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.EcpDataServerDelete.PrivilegePairs</method> -- the pairs leg goes red.</p>
Method TestTheToolsDeclareTheirKindsPortsAndPairs()
{
    Set tScreen = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Set tWrite = tScreen _ $ListBuild($ListBuild("%DB_IRISSYS", "WRITE"))
    Set tOperate = tScreen _ $ListBuild($ListBuild("%Admin_Operate", "USE"))
    ; name, settable, endpoint|write type|body|destructive|creates|change action|advertised, pairs, classic pages
    Set tCases = $ListBuild($ListBuild("osmgmt.ecpdataservers.create", "Address,Port,MirrorConnection,SSLConfig,BatchMode", "ECP.DataServer|PUT|1|0|1|created|1", tWrite, "%CSP.UI.Portal.Dialog.ECPDataServer"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.ecpdataservers.update", "Address,Port,MirrorConnection,SSLConfig,BatchMode", "ECP.DataServer|PUT|1|0|0|updated|1", tWrite, "%CSP.UI.Portal.Dialog.ECPDataServer"))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.ecpdataservers.delete", "", "ECP.DataServer|DELETE|0|1|0|deleted|1", tWrite, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.ecpdataservers.changestatus", "Status", "ECP.DataServer|SERVERACTION|0|1|0|updated|1", tOperate, "%CSP.UI.Portal.Dialog.ECPDataServer"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tName = $List(tCase, 1)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass"), "write|" _ ..#LIST _ "|" _ ..#PORT, tName _ ": a write on its screen, through the ECP port")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 2), tName _ " admits exactly its fields")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Advertised"), $List(tCase, 3), tName _ ": endpoint, request type, body, destructive, creates, change action and advertisement")
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertEquals(tResolved _ " " _ ..PairsText(tPairs), "1 " _ ..PairsText($List(tCase, 4)), tName _ " requires its pairs")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), $List(tCase, 5), tName _ " names its classic page beyond its descriptor's own (AD-44)")
    }
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.EcpDataServerChangeStatus", "READTYPE") _ "|" _ $Parameter("OcuPilot.Screen.Tool.EcpDataServerChangeStatus", "READROWKEY") _ "|" _ $Parameter("OcuPilot.Screen.Tool.EcpDataServerChangeStatus", "FINGERPRINTSUBJECT") _ "|" _ $Parameter("OcuPilot.Screen.Tool.EcpDataServerChangeStatus", "SCREENVALUES"), "LIST|Name|Status|changestatus=Status", "the status change reads the LIST row by name, its subject the status, its one value from the dialog")
    Set tSchema = ##class(OcuPilot.Screen.Tool.EcpDataServerChangeStatus).InputSchema()
    Do $$$AssertEquals($Select($IsObject(tSchema): tSchema.properties.Status.enum.%ToJSON() _ " " _ tSchema.required.%ToJSON(), 1: ""), "[""notconnected"",""disabled"",""normal""] [""Name"",""Status""]", "its Status is a required enum of the port's three statuses")
    For tCase = $ListBuild("notconnected", "ECP.STATUS.DISCONNECT"), $ListBuild("disabled", "ECP.STATUS.DISCONNECT"), $ListBuild("normal", "ECP.STATUS.CONNECT") {
        Set tPayload = {}
        Do tPayload.%Set("Status", $List(tCase, 1), "string")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.EcpDataServerChangeStatus).Consequence(tPayload), $List(tCase, 2), $List(tCase, 1) _ "'s consequence")
    }
    For tPage = "%CSP.UI.Portal.ECPDataServers", "%CSP.UI.Portal.Dialog.ECPDataServer" {
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(tPage), tPage _ " is a compiled classic page")
    }
}

/// <p>Every <code>ECP.*</code> code carries its one published sentence through both of
/// <class>OcuPilot.Api.Error</class>'s resolvers, each field-level code names its field, and the limit's
/// sentence names the instance's number.</p>
/// <p>Mutation (Rule 19): drop the <code>ECP.</code> dispatch line from
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -- every sentence leg goes red.</p>
Method TestTheEcpCodesCarryTheirSentences()
{
    Set tCodes = ##class(OcuPilot.Api.EcpError).Codes()
    Do $$$AssertEquals($ListToString(tCodes), "ECP.LICENSE,ECP.STATUS.SAME,ECP.STATUS.REFUSED,ECP.DATASERVER.VALIDATION,ECP.DATASERVER.NAME.SHAPE,ECP.DATASERVER.NAME.TAKEN,ECP.DATASERVER.ADDRESS,ECP.DATASERVER.PORT,ECP.DATASERVER.MIRROR,ECP.DATASERVER.SSLCLIENT,ECP.DATASERVER.INUSE,ECP.SERVER.LIMIT,ECP.SETTINGS.VALIDATION,ECP.SETTINGS.COUNT,ECP.SETTINGS.RECOVERY,ECP.SETTINGS.INTERVAL,ECP.SETTINGS.TROUBLE,ECP.SETTINGS.SSL.SHAPE,ECP.SETTINGS.SSLSERVER,ECP.SETTINGS.SERVERS,ECP.SETTINGS.RESTART,ECP.SSL.AUTHORIZE,ECP.SSL.REJECT", "twelve codes, then Story 18.21's eleven")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.EcpError).ReasonFor(tCode)
        Do $$$AssertTrue(tReason '= "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ ": the violation resolver answers it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ ": and so does the tool-result resolver")
    }
    Set tFields = ""
    Set tViolations = ##class(OcuPilot.Api.EcpError).ViolationCodes()
    For tI = 1:1:$ListLength(tViolations) Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ ##class(OcuPilot.Api.EcpError).FieldOf($List(tViolations, tI))
    Do $$$AssertEquals(tFields, "Status,Status,Name,Name,Address,Port,MirrorConnection,SSLConfig,AppServerSettings.MaxServers,DataServerSettings.MaxServerConn,AppServerSettings.ClientReconnectDuration,AppServerSettings.ClientReconnectInterval,DataServerSettings.ServerTroubleDuration,DataServerSettings.SSLECPServer,DataServerSettings.SSLECPServer,AppServerSettings.MaxServers", "each violation code names its field")
    For tCase = $ListBuild("LICENSE", "This instance's license does not include ECP."), $ListBuild("STATUSSAME", "The data server already has that status."), $ListBuild("STATUSREFUSED", "The instance refused that status change."), $ListBuild("NAMESHAPE", "Use up to 64 letters, digits, hyphens and underscores, starting with a letter or digit."), $ListBuild("NAMETAKEN", "An ECP data server of that name already exists."), $ListBuild("ADDRESS", "Enter the data server's host name or IP address."), $ListBuild("PORT", "Enter a port from 1 to 65535."), $ListBuild("MIRROR", "A data server's mirror connection cannot be turned off once it is set."), $ListBuild("SSLCLIENT", "Create and enable the %ECPClient SSL/TLS configuration before using SSL/TLS."), $ListBuild("INUSE", "Remote databases use this data server. Delete them or move them to another data server first."), $ListBuild("SERVERLIMIT", "This instance allows no more ECP data servers. Delete one, or raise the limit in ECP settings, first."), $ListBuild("DATASERVERVALIDATION", "The ECP data server was refused.") {
        Do $$$AssertEquals($Parameter("OcuPilot.Api.EcpError", "REASON" _ $List(tCase, 1)), $List(tCase, 2), $List(tCase, 1) _ "'s published sentence")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.EcpError).Limit(2), "This instance allows at most 2 ECP data servers. Delete one, or raise the limit in ECP settings, first.", "the limit's sentence names the instance's number")
}

/// <p>The baseline lists the four keys, the delete and the status change disabled (AD-22).</p>
/// <p>Mutation (Rule 19): drop <code>osmgmt.ecpdataservers.changestatus</code> from the baseline -- this
/// goes red.</p>
Method TestTheBaselineListsTheFourKeys()
{
    For tCase = $ListBuild("osmgmt.ecpdataservers.changestatus", 0), $ListBuild("osmgmt.ecpdataservers.create", 1), $ListBuild("osmgmt.ecpdataservers.delete", 0), $ListBuild("osmgmt.ecpdataservers.update", 1) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed " _ $Select($List(tCase, 2): "enabled", 1: "disabled"))
    }
}

/// <p>B3: the delete's impact is its own kind, and no other data server tool's is.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Impact.KindOf</method> omits the data server
/// delete -- this goes red.</p>
Method TestTheDeleteHasItsImpactKind()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Impact).KindOf("osmgmt.ecpdataservers.delete", {}, {}), "ecp-data-server-delete", "the data server delete names its impact")
    For tName = "osmgmt.ecpdataservers.create", "osmgmt.ecpdataservers.update", "osmgmt.ecpdataservers.changestatus" {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Impact).KindOf(tName, {}, {}), "", tName _ " has no impact kind")
    }
}

/// <p>AD-59: the status change's script is one <code>rest</code> step posting <code>{"Action":n}</code>
/// to the vendor's action route for the data server, except Normal on an instance whose license enables
/// no ECP, which is one <code>comment</code> step carrying the license sentence and no call; a status
/// outside the three renders nothing; a <code>PUT</code> and a <code>DELETE</code> are the admin port's
/// steps; and the port's license is the remote database port's.</p>
/// <p>Mutation (Rule 19): drop the unlicensed branch from
/// <method>OcuPilot.Port.EcpPort.Snippet</method> -- the Normal leg renders a call and goes red.</p>
Method TestTheScriptMirrorsEveryBranch()
{
    Set tContext = {"origin": "https://instance.example", "user": "<User>"}
    Kill tQuery
    Set tQuery("name") = "OCUPROBEECPA"
    Set tQuery("Status") = "disabled"
    Set tText = ..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.DataServer", "SERVERACTION", .tQuery, "", tContext))
    Do $$$AssertTrue(($Length(tText, " | ") = 1) && ($Piece(tText, ":", 1) = "rest") && (tText [ "-X POST") && (tText [ "/ecp/data-server/action?name=OCUPROBEECPA") && (tText [ "{""Action"":2}") && (tText '[ "Status"), "Disabled is one POST of {""Action"":2} to the action route: " _ tText)
    Set tQuery("Status") = "notconnected"
    Do $$$AssertTrue(..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.DataServer", "SERVERACTION", .tQuery, "", tContext)) [ "{""Action"":1}", "Not connected posts {""Action"":1}")
    Set tQuery("Status") = "normal"
    Do $$$AssertEquals(##class(OcuPilot.Port.EcpPort).NetworkEnabled(), 0, "this instance's license enables no ECP")
    Do $$$AssertEquals(..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.DataServer", "SERVERACTION", .tQuery, "", tContext)), "comment:" _ ##class(OcuPilot.Api.EcpError).#REASONLICENSE, "so Normal renders no call, only the license sentence")
    Set ^||OcuPilotRemoteLicensed = 1
    Set tText = ..StepsText(##class(OcuPilot.Test.EcpSeamPort).Snippet("ECP.DataServer", "SERVERACTION", .tQuery, "", tContext))
    Kill ^||OcuPilotRemoteLicensed
    Do $$$AssertTrue(($Piece(tText, ":", 1) = "rest") && (tText [ "{""Action"":3}"), "on a licensed instance Normal posts {""Action"":3}: " _ tText)
    Set tQuery("Status") = "running"
    Do $$$AssertEquals(..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.DataServer", "SERVERACTION", .tQuery, "", tContext)), "", "a status outside the three renders nothing")
    Kill tQuery
    Set tQuery("name") = "OCUPROBEECPA"
    Set tText = ..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.DataServer", "PUT", .tQuery, {"Address": "192.0.2.10", "Port": 1972}, tContext))
    Do $$$AssertTrue((tText [ "-X PUT") && (tText [ "/ecp/data-server?name=OCUPROBEECPA") && (tText [ """Port"":1972"), "a PUT is the admin port's step: " _ tText)
    Set tText = ..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.DataServer", "DELETE", .tQuery, "", tContext))
    Do $$$AssertTrue((tText [ "-X DELETE") && (tText [ "/ecp/data-server?name=OCUPROBEECPA"), "and so is a DELETE: " _ tText)
    Do $$$AssertEquals(##class(OcuPilot.Port.EcpPort).NetworkEnabled(), ##class(OcuPilot.Port.RemoteDatabasePort).NetworkEnabled(), "the port's license is the remote database port's")
    Set ^||OcuPilotRemoteLicensed = 1
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSeamPort).NetworkEnabled(), 1, "and the seam stands in for a licensed instance")
    Kill ^||OcuPilotRemoteLicensed
}

/// <p>C1, C8: ECP settings is OS management's eighteenth entry, a form page over the vendor's
/// <code>ECP.Settings</code> <code>GET</code> with the six member fields, a singleton, declaring
/// <code>%Admin_Secure:USE</code> as its own pair beside OS management's two, with three prompts and the
/// caveat in its doc comment.</p>
/// <p>Mutation (Rule 19): the read drops <code>DataServerSettings.SSLECPServer</code> -- the fields leg
/// goes red.</p>
Method TestEcpSettingsIsOsManagementsEighteenthEntry()
{
    Set tClass = ..#SETTINGS
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "including its read")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ ":" _ $ClassMethod(tClass, "SideBarPosition") _ ":" _ tDeclaration.labelKey _ ":" _ tDeclaration.archetype _ ":" _ tDeclaration.route, "os-management:18:ecpSettingsLabel:form-page:os-management/ecp-settings", "OS management's eighteenth side-bar entry, a form page")
    Do $$$AssertEquals(tDeclaration.read.source.%ToJSON(), "{""port"":""admin"",""endpoint"":""ECP.Settings"",""type"":""GET""}", "read through the vendor's settings GET")
    Do $$$AssertEquals(tDeclaration.read.fields.%ToJSON(), "[""AppServerSettings.MaxServers"",""AppServerSettings.ClientReconnectDuration"",""AppServerSettings.ClientReconnectInterval"",""DataServerSettings.MaxServerConn"",""DataServerSettings.ServerTroubleDuration"",""DataServerSettings.SSLECPServer""]", "its six member fields")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON() _ " " _ tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%Admin_Secure"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}] [{""resource"":""%Admin_Secure"",""permission"":""USE""}]", "OS management's two pairs and its own %Admin_Secure:USE, in that order")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "Scope") _ "|" _ ##class(OcuPilot.Kernel.EntityRef).NormalizedId("ecp-settings", "anything"), "ecp-settings|instance|SYSTEM", "the singleton (AD-13)")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ tDeclaration.toolIdentifier, "%CSP.UI.Portal.ECP|osmgmt.ecpsettings", "the classic ECP Settings page (AD-44) and its tool identifier")
    Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, "with three suggested prompts")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/ecp-settings") _ "|" _ ##class(OcuPilot.Screen.Registry).DescriptorForTool("osmgmt.ecpsettings"), tClass _ "|" _ tClass, "its route and tool identifier resolve to it")
    Do $$$AssertTrue(..Description(tClass) [ ..#CAVEAT, "its doc comment carries the caveat")
    Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("%CSP.UI.Portal.ECP"), "%CSP.UI.Portal.ECP is a compiled classic page")
}

/// <p>C4, C8: ECP application servers is OS management's nineteenth entry, a tab group: Connections, the
/// listed first tab over <code>ECP.AppServerList</code> <code>LIST</code>, whose four fields are the
/// vendor query's columns as the endpoint maps them, with its status note and no action; and SSL/TLS
/// authorizations, an unlisted second tab over <code>ECP.AppServerSSLConnection</code> <code>LIST</code>,
/// keyed by the name kept exactly, whose Authorize, Reject and Delete name their self-protection
/// rules.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Descriptor.EcpAppServerTab</class> drops its
/// <code>read.note</code> -- the note leg goes red.</p>
Method TestEcpApplicationServersIsOsManagementsNineteenthEntry()
{
    Set tSC = $ClassMethod(..#APPTAB, "DeclarationJson", .tApp)
    Do $$$AssertStatusOK(tSC, "Connections' declaration parses")
    Set tSC = $ClassMethod(..#SSLTAB, "DeclarationJson", .tSsl)
    Do $$$AssertStatusOK(tSC, "and SSL/TLS authorizations'")
    If '$IsObject($Get(tApp)) || '$IsObject($Get(tSsl)) Quit
    For tDeclaration = tApp, tSsl {
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration) _ ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tDeclaration.route _ " validates")
        Do $$$AssertEquals(tDeclaration.privileges.%ToJSON() _ " " _ tDeclaration.archetype _ " " _ tDeclaration.classicPage, ..#SCREENPAIRS _ " detail %CSP.UI.Portal.ECPAppServers", tDeclaration.route _ ": OS management's two pairs, a detail tab, the classic Application Servers page")
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), 3, tDeclaration.route _ " carries three prompts")
    }
    Do $$$AssertEquals(tApp.route _ "|" _ tApp.sideBarPosition _ "|" _ tApp.tab.%ToJSON() _ "|" _ tApp.labelKey, "os-management/ecp-application-servers|19|{""group"":""os-management/ecp-application-servers"",""position"":1,""labelKey"":""sslPromptGroupConnections""}|ecpAppServersLabel", "Connections is the nineteenth entry and the group's first tab")
    Do $$$AssertEquals(tSsl.route _ "|" _ tSsl.sideBarPosition _ "|" _ tSsl.tab.%ToJSON(), "os-management/ecp-application-servers/ssl|0|{""group"":""os-management/ecp-application-servers"",""position"":2,""labelKey"":""ecpSslConnectionsLabel""}", "SSL/TLS authorizations is the unlisted second tab")
    Do $$$AssertEquals(tApp.read.source.%ToJSON() _ " " _ tApp.entityType _ " " _ tApp.id.kind _ " " _ tApp.rowActions.%Size(), "{""port"":""admin"",""endpoint"":""ECP.AppServerList"",""type"":""LIST""}  none 0", "Connections reads the application server list, administers nothing and has no action")
    Do $$$AssertEquals(tApp.read.fields.%ToJSON(), ..MappedClientColumns(), "its fields are the vendor query's columns as the endpoint maps them")
    Do $$$AssertEquals(..Columns(tApp), "ClientName:name,Status:status,IPAddress:identifier,IPPort:number", "its four columns")
    Do $$$AssertEquals($Select(tApp.read.%GetTypeOf("note") = "object": tApp.read.note.%ToJSON(), 1: ""), "{""key"":""ecpDataServerStatusCaveat"",""text"":""" _ ..#NOTE _ """}", "and its status note")
    Do $$$AssertEquals(tApp.emptyStateKey _ "|" _ tApp.table.emptyNextKey, "ecpAppServerListEmpty|tableReadOnlyEmptyNext", "its empty state, read-only")
    Do $$$AssertEquals(tSsl.read.source.%ToJSON() _ " " _ tSsl.read.fields.%ToJSON(), "{""port"":""admin"",""endpoint"":""ECP.AppServerSSLConnection"",""type"":""LIST""} [""SSLComputerName"",""ClientIP"",""Status""]", "SSL/TLS authorizations reads the vendor's SSL/TLS list")
    Do $$$AssertEquals(..Columns(tSsl), "SSLComputerName:name,ClientIP:identifier,Status:status", "its three columns")
    Do $$$AssertEquals(tSsl.rowActions.%ToJSON(), "[{""id"":""authorize"",""selfProtection"":""ecp-ssl-pending""},{""id"":""reject"",""selfProtection"":""ecp-ssl-pending""},{""id"":""delete"",""selfProtection"":""ecp-ssl-authorized""}]", "Authorize and Reject under ecp-ssl-pending, Delete under ecp-ssl-authorized")
    Do $$$AssertEquals(tSsl.entityType _ "|" _ ##class(OcuPilot.Kernel.EntityRef).NormalizedId("ecp-ssl-connection", "cn=OcuProbeEcpA"), "ecp-ssl-connection|cn=OcuProbeEcpA", "keyed by the name kept exactly (AD-13)")
    Do $$$AssertEquals(tSsl.emptyStateKey _ "|" _ tSsl.table.emptyAgentKey, "ecpSslConnectionListEmpty|ecpSslConnectionListEmptyAgent", "its two empty-state keys")
    Set tRules = $ListFromString($Parameter("OcuPilot.Screen.Registry", "SELFPROTECTIONRULES"))
    Do $$$AssertTrue($ListFind(tRules, "ecp-ssl-pending") && $ListFind(tRules, "ecp-ssl-authorized"), "the registry declares both rules")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).IsKnown("ecp-settings") _ ##class(OcuPilot.Kernel.EntityType).IsKnown("ecp-ssl-connection"), "11", "both entity types are in the closed vocabulary")
    For tClass = ..#APPTAB, ..#SSLTAB Do $$$AssertTrue(..Description(tClass) [ ..#CAVEAT, tClass _ "'s doc comment carries the caveat")
    Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("%CSP.UI.Portal.ECPAppServers"), "%CSP.UI.Portal.ECPAppServers is a compiled classic page")
}

/// <p>The four tools: descriptor, port, fields, request types, body, kind, pairs and classic pages (AD-8,
/// AD-44, measured at Task 0); the SSL/TLS tools' row read, exact key and subject; and each tool's copy
/// of its sentence or consequence equal to <class>OcuPilot.Api.EcpError</class>'s.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.EcpSslConnectionDelete.PrivilegePairs</method> -- the pairs leg goes
/// red.</p>
Method TestTheStoryTwentyOneToolsDeclareTheirKindsPortsAndPairs()
{
    Set tScreen = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%DB_IRISSYS", "READ"))
    Set tSecure = $ListBuild($ListBuild("%Admin_Manage", "USE"), $ListBuild("%Admin_Secure", "USE"), $ListBuild("%DB_IRISSYS", "READ"), $ListBuild("%DB_IRISSYS", "WRITE"))
    Set tWrite = tScreen _ $ListBuild($ListBuild("%DB_IRISSYS", "WRITE"))
    ; name, descriptor, settable, endpoint|write type|body|destructive|creates|change action|advertised, pairs
    Set tCases = $ListBuild($ListBuild("osmgmt.ecpsettings.update", ..#SETTINGS, "AppServerSettings,DataServerSettings", "ECP.Settings|PUT|1|0|0|updated|1", tSecure))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.ecpsslconnections.authorize", ..#SSLTAB, "", "ECP.AppServerSSLConnection|AUTHORIZE|0|0|0|updated|1", tWrite))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.ecpsslconnections.reject", ..#SSLTAB, "", "ECP.AppServerSSLConnection|REJECT|0|0|0|updated|1", tWrite))
    Set tCases = tCases _ $ListBuild($ListBuild("osmgmt.ecpsslconnections.delete", ..#SSLTAB, "", "ECP.AppServerSSLConnection|DELETE|0|1|0|deleted|1", tWrite))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Set tName = $List(tCase, 1)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), tName _ " is registered")
        If '$IsObject($Get(tTool)) Continue
        Set tClass = tTool.class
        Do $$$AssertEquals(tTool.kind _ "|" _ $Parameter(tClass, "DESCRIPTORCLASS") _ "|" _ $ClassMethod(tClass, "PortClass"), "write|" _ $List(tCase, 2) _ "|" _ ..#PORT, tName _ ": a write on its screen, through the ECP port")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), $List(tCase, 3), tName _ " admits exactly its fields")
        Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "|" _ $ClassMethod(tClass, "WriteType") _ "|" _ $ClassMethod(tClass, "SendsBody") _ "|" _ $ClassMethod(tClass, "Destructive") _ "|" _ $ClassMethod(tClass, "Creates") _ "|" _ $ClassMethod(tClass, "ChangeAction") _ "|" _ $ClassMethod(tClass, "Advertised"), $List(tCase, 4), tName _ ": endpoint, request type, body, destructive, creates, change action and advertisement")
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertEquals(tResolved _ " " _ ..PairsText(tPairs), "1 " _ ..PairsText($List(tCase, 5)), tName _ " requires its pairs")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "", tName _ " names no classic page beyond its descriptor's own (AD-44)")
    }
    For tClass = "OcuPilot.Screen.Tool.EcpSslConnectionAuthorize", "OcuPilot.Screen.Tool.EcpSslConnectionReject", "OcuPilot.Screen.Tool.EcpSslConnectionDelete" {
        Do $$$AssertEquals($Parameter(tClass, "READTYPE") _ "|" _ $Parameter(tClass, "READROWKEY") _ "|" _ $ClassMethod(tClass, "ReadRowKeyExact") _ "|" _ $Parameter(tClass, "FINGERPRINTSUBJECT") _ "|" _ $Parameter(tClass, "PRECONDITIONFIELD") _ "|" _ $ClassMethod(tClass, "IdArgument"), "LIST|SSLComputerName|1|Status|Status|SSLComputerName", tClass _ " reads the LIST row by its exact name, its subject the status")
    }
    For tCase = $ListBuild("OcuPilot.Screen.Tool.EcpSslConnectionAuthorize", "NOTPENDINGREASON", "REASONSSLNOTPENDING"), $ListBuild("OcuPilot.Screen.Tool.EcpSslConnectionReject", "NOTPENDINGREASON", "REASONSSLNOTPENDING"), $ListBuild("OcuPilot.Screen.Tool.EcpSslConnectionDelete", "NOTAUTHORIZEDREASON", "REASONSSLNOTAUTHORIZED"), $ListBuild("OcuPilot.Screen.Tool.EcpSslConnectionAuthorize", "CONSEQUENCECODE", "SSLAUTHORIZE"), $ListBuild("OcuPilot.Screen.Tool.EcpSslConnectionReject", "CONSEQUENCECODE", "SSLREJECT"), $ListBuild("OcuPilot.Screen.Tool.EcpSettingsUpdate", "RESTARTCONSEQUENCE", "SETTINGSRESTART") {
        Do $$$AssertEquals($Parameter($List(tCase, 1), $List(tCase, 2)), $Parameter("OcuPilot.Api.EcpError", $List(tCase, 3)), $List(tCase, 1) _ "." _ $List(tCase, 2) _ " is EcpError's " _ $List(tCase, 3))
    }
    For tCase = $ListBuild("OcuPilot.Screen.Tool.EcpSslConnectionAuthorize", "ECP.SSL.AUTHORIZE"), $ListBuild("OcuPilot.Screen.Tool.EcpSslConnectionReject", "ECP.SSL.REJECT") {
        Do $$$AssertEquals($ClassMethod($List(tCase, 1), "Consequence", {}), $List(tCase, 2), $List(tCase, 1) _ "'s consequence")
    }
    For tCase = $ListBuild("Pending", "OcuPilot.Screen.Tool.EcpSslConnectionAuthorize", ""), $ListBuild("Authorized", "OcuPilot.Screen.Tool.EcpSslConnectionAuthorize", ##class(OcuPilot.Api.EcpError).#REASONSSLNOTPENDING), $ListBuild("Authorized", "OcuPilot.Screen.Tool.EcpSslConnectionDelete", ""), $ListBuild("Pending", "OcuPilot.Screen.Tool.EcpSslConnectionDelete", ##class(OcuPilot.Api.EcpError).#REASONSSLNOTAUTHORIZED) {
        Set tFresh = {"SSLComputerName": "CN=OCUPROBEECPX", "ClientIP": ""}
        Do tFresh.%Set("Status", $List(tCase, 1), "string")
        Set tSC = $ClassMethod($List(tCase, 2), "StateDiff", tFresh, .tRows, .tProblem)
        Do $$$AssertEquals(tProblem, $List(tCase, 3), $List(tCase, 2) _ " on a " _ $List(tCase, 1) _ " row")
    }
}

/// <p>C8: the baseline lists the four keys, the SSL/TLS delete disabled (AD-22, Decision 7).</p>
/// <p>Mutation (Rule 19): drop <code>osmgmt.ecpsslconnections.delete</code> from the baseline -- this
/// goes red.</p>
Method TestTheBaselineListsTheStoryTwentyOneKeys()
{
    For tCase = $ListBuild("osmgmt.ecpsettings.update", 1), $ListBuild("osmgmt.ecpsslconnections.authorize", 1), $ListBuild("osmgmt.ecpsslconnections.delete", 0), $ListBuild("osmgmt.ecpsslconnections.reject", 1) {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 1), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 " _ $List(tCase, 2), $List(tCase, 1) _ " is listed " _ $Select($List(tCase, 2): "enabled", 1: "disabled"))
    }
}

/// <p>AD-59: a settings <code>PUT</code>'s script is one <code>PUT /ecp/settings</code> step with the body
/// and no query; one asking for SSL/TLS while <code>%ECPServer</code> is not enabled renders no call and
/// one <code>comment</code> step carrying its sentence; and the SSL/TLS actions are the admin port's
/// steps.</p>
/// <p>Mutation (Rule 19): drop the refusal branch from <method>OcuPilot.Port.EcpPort.Snippet</method> --
/// the SSL/TLS leg renders a call and goes red.</p>
Method TestTheSettingsScriptMirrorsEveryBranch()
{
    Set tContext = {"origin": "https://instance.example", "user": "<User>"}
    Kill tQuery
    Set tQuery("name") = "SYSTEM"
    Set tBody = {"AppServerSettings": {"MaxServers": 2, "ClientReconnectDuration": 1200, "ClientReconnectInterval": 6}, "DataServerSettings": {"MaxServerConn": 1, "ServerTroubleDuration": 60, "SSLECPServer": 0}}
    Set tText = ..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.Settings", "PUT", .tQuery, tBody, tContext))
    Do $$$AssertTrue(($Length(tText, " | ") = 1) && ($Piece(tText, ":", 1) = "rest") && (tText [ "-X PUT") && (tText [ "/ecp/settings") && (tText '[ "name=SYSTEM") && (tText [ """ClientReconnectInterval"":6"), "a settings PUT is one PUT of the body with no query: " _ tText)
    Do tBody.DataServerSettings.%Set("SSLECPServer", 1, "number")
    Do $$$AssertEquals(..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.Settings", "PUT", .tQuery, tBody, tContext)), "comment:" _ ##class(OcuPilot.Api.EcpError).#REASONSETTINGSSSLSERVER, "SSL/TLS without an enabled %ECPServer renders no call, only its sentence")
    Kill tQuery
    Set tQuery("name") = "CN=OCUPROBEECPA"
    For tType = "AUTHORIZE", "REJECT", "DELETE" {
        Set tText = ..StepsText(##class(OcuPilot.Port.EcpPort).Snippet("ECP.AppServerSSLConnection", tType, .tQuery, "", tContext))
        Do $$$AssertTrue(($Piece(tText, ":", 1) = "rest") && (tText [ "/ecp/application-server-ssl-connection") && (tText [ "name="), tType _ " is the admin port's step: " _ tText)
    }
}

/// <p>The guard (Task 0's halt, the orchestrator's option (b)): no test sends a <code>MaxServerConn</code>
/// change to the vendor, because a real one leaves the instance pending a restart that no restore clears.
/// Only <parameter>MAXSERVERCONNCLASSES</parameter> name <code>MaxServerConn</code> among the test
/// classes, and every method of a <class>%UnitTest.TestCase</class> among them that writes it as a body
/// key -- an object literal's <code>"MaxServerConn":</code>, a JSON string's
/// <code>""MaxServerConn"":</code> or a <code>%Set("MaxServerConn", ...)</code> -- arms the seam's
/// <code>ecpserver</code> mode, which records the <code>PUT</code> and never sends it; the seam's own
/// guard refuses one sent any other way. The helpers on the roster are named one by one, so adding a
/// class that names the member is an edit here. The browser specs' twin is in
/// <file>ui/tools/ci.test.mjs</file>.</p>
/// <p>Mutation (Rule 19): remove the <code>ecpserver</code> arm from
/// <method>OcuPilot.Test.EcpSettingsWrite.TestARestartSettingIsStatedAndNeverSentForReal</method> --
/// this goes red.</p>
Method TestNoTestSendsMaxServerConnToTheVendor()
{
    Set tMember = "MaxServer" _ "Conn"
    Set tSent = $ListBuild($Char(34) _ tMember _ $Char(34) _ ":", $Char(34, 34) _ tMember _ $Char(34, 34) _ ":", "%Set(" _ $Char(34) _ tMember _ $Char(34))
    Set tArm = $Char(34) _ "ecp" _ "server" _ $Char(34)
    Set tNaming = ""
    Set tUnarmed = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ? ORDER BY Name", "OcuPilot.Test.")
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the test classes are listed")
    While tRS.%Next() {
        Set tClass = tRS.%Get("Name")
        Set tText = ""
        Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, tClass, .tText)
        If $$$ISERR(tSC) || '(tText [ tMember) Continue
        Set tNaming = tNaming _ $ListBuild(tClass)
        ; This class writes nothing: its bodies are scripts and the seam's own question, never sent.
        If tClass = $ClassName() Continue
        If '$ClassMethod(tClass, "%Extends", "%UnitTest.TestCase") Continue
        Set tDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(tClass)
        If '$IsObject(tDefinition) Continue
        For tI = 1:1:tDefinition.Methods.Count() {
            Set tMethod = tDefinition.Methods.GetAt(tI)
            Set tCode = ""
            Do tMethod.Implementation.Rewind()
            While 'tMethod.Implementation.AtEnd { Set tCode = tCode _ tMethod.Implementation.Read(32000) }
            Set tSends = 0
            For tP = 1:1:$ListLength(tSent) If tCode [ $List(tSent, tP) Set tSends = 1
            If tSends && '(tCode [ tArm) Set tUnarmed = tUnarmed _ $ListBuild(tClass _ ":" _ tMethod.Name)
        }
        Set tDefinition = ""
    }
    Do $$$AssertEquals($ListToString(tNaming), ..#MAXSERVERCONNCLASSES, "only the probes, the seam, the settings write suite and this class name it")
    Do $$$AssertEquals($ListToString(tUnarmed), "", "and every method sending it as a body member arms the seam's ecpserver mode")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSeamPort).ChangesMaxServerConn({"DataServerSettings": {"MaxServerConn": 254}}) _ ##class(OcuPilot.Test.EcpSeamPort).ChangesMaxServerConn({"DataServerSettings": {"ServerTroubleDuration": 60}}), "10", "the seam's guard tells a change from a body without one")
}

/// <p>The columns <code>SYS.ECP</code>'s <code>ClientList</code> query declares, each renamed as the
/// vendor's <code>ECP.AppServerList</code> endpoint renames it (the <code>MapColumnName</code> calls in its
/// compiled <code>Run</code>, resolved through the port, AD-27), as a JSON array of strings. A column the
/// endpoint does not rename keeps the query's name.</p>
ClassMethod MappedClientColumns() As %String
{
    Set tOut = []
    Kill tRename
    Set tEndpointClass = ##class(OcuPilot.Port.AdminPort).EndpointClass("ECP.AppServerList")
    If tEndpointClass '= "" {
        Set tMethod = ##class(%Dictionary.CompiledMethod).IDKEYOpen(tEndpointClass, "Run", , .tOpenSC)
        If $IsObject(tMethod) {
            Do tMethod.Implementation.Rewind()
            Set tSource = tMethod.Implementation.Read(32000)
            Set tMatcher = ##class(%Regex.Matcher).%New("MapColumnName\(""([^""]+)"",\s*""([^""]+)""\)", tSource)
            While tMatcher.Locate() { Set tRename(tMatcher.Group(1)) = tMatcher.Group(2) }
        }
        Set tMethod = ""
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tQuery = ##class(%Dictionary.CompiledQuery).%OpenId("SYS.ECP||ClientList")
        Set tSpec = ""
        If $IsObject(tQuery) Set tSpec = tQuery.Parameters.GetAt("ROWSPEC")
        Set tQuery = ""
        Set $NAMESPACE = tOrigNS
        For tI = 1:1:$Length(tSpec, ",") {
            Set tColumn = $Piece($Piece(tSpec, ",", tI), ":", 1)
            If tColumn '= "" Do tOut.%Push($Get(tRename(tColumn), tColumn))
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOut.%ToJSON()
}

/// <p>The steps <var>pSteps</var> as <code>kind:text</code>, joined with <code> | </code>.</p>
ClassMethod StepsText(pSteps As %DynamicArray) As %String
{
    If '$IsObject(pSteps) Quit ""
    Set tOut = ""
    Set tIterator = pSteps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: " | ") _ tStep.%Get("kind") _ ":" _ tStep.%Get("text")
    }
    Quit tOut
}

/// <p><var>pDeclaration</var>'s table columns as <code>field:kind</code>, comma-joined.</p>
ClassMethod Columns(pDeclaration As %DynamicObject) As %String
{
    Set tOut = ""
    Set tIterator = pDeclaration.table.columns.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tColumn.field _ ":" _ tColumn.kind
    }
    Quit tOut
}

/// <p>The doc comment of class <var>pClass</var>.</p>
ClassMethod Description(pClass As %String) As %String
{
    Set tDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(pClass)
    If '$IsObject(tDefinition) Quit ""
    Quit tDefinition.Description
}

/// <p><var>pPairs</var>, a list of <code>$ListBuild(resource, permission)</code>, as text.</p>
ClassMethod PairsText(pPairs As %List) As %String
{
    Quit ##class(OcuPilot.Test.LicenseDescriptor).PairsText(pPairs)
}

}
