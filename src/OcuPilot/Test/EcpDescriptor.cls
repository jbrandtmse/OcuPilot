/// <p>Pins Story 18.20's declarations (AC B1, B7): ECP data servers and its form -- their routes, side-bar
/// positions, pairs, classic pages, prompts, entity type, id rule and the caveat their doc comments
/// carry; the four tools' kinds, ports, fields, pairs and classic pages;
/// <class>OcuPilot.Api.EcpError</class>'s codes, fields and sentences; the baseline's four keys; the
/// delete's impact kind; and <class>OcuPilot.Port.EcpPort</class>'s script and license seam.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and no custom resource assigned to
/// the replaced classic pages. It writes nothing.</p>
Class OcuPilot.Test.EcpDescriptor Extends %UnitTest.TestCase
{

Parameter LIST = "OcuPilot.Screen.Descriptor.EcpDataServerList";

Parameter FORM = "OcuPilot.Screen.Descriptor.EcpDataServerForm";

Parameter PORT = "OcuPilot.Port.EcpPort";

Parameter SCREENPAIRS = "[{""resource"":""%Admin_Manage"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]";

/// <p>The sentence both descriptors' doc comments carry for the caveat.</p>
Parameter CAVEAT = "These screens rely on the admin API's routes alone";

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
    Do $$$AssertEquals($ListToString(tCodes), "ECP.LICENSE,ECP.STATUS.SAME,ECP.STATUS.REFUSED,ECP.DATASERVER.VALIDATION,ECP.DATASERVER.NAME.SHAPE,ECP.DATASERVER.NAME.TAKEN,ECP.DATASERVER.ADDRESS,ECP.DATASERVER.PORT,ECP.DATASERVER.MIRROR,ECP.DATASERVER.SSLCLIENT,ECP.DATASERVER.INUSE,ECP.SERVER.LIMIT", "twelve codes")
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
    Do $$$AssertEquals(tFields, "Status,Status,Name,Name,Address,Port,MirrorConnection,SSLConfig", "each violation code names its field")
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
