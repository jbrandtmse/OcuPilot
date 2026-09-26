/// <p>Pins AD-59 across every registered write tool, with no sample: the checked-in route table
/// equals a fresh derivation from the instance's dispatch map; every tool's port defines
/// <code>Snippet</code> and <code>SnippetForm</code> in the class that defines <code>Invoke</code>
/// and answers a script form for the tool's request type; a tool that overrides
/// <code>AfterWrite</code> defines <code>SnippetAfter</code>; no secret value reaches any rendered
/// script; and the draft renders the query and body the confirm hands its port.</p>
/// <p><b>What it needs from the environment:</b> the instance's administration API dispatch class,
/// OcuPilot's protected state and an account holding <code>%All</code>. The secrets leg renders from
/// synthetic rows and reads nothing. The parity legs mint through
/// <class>OcuPilot.Test.ProposalMint</class> and confirm through
/// <class>OcuPilot.Test.ConfirmFixture</class>, whose port is <class>OcuPilot.Test.ProposalFixture</class>,
/// so no write reaches the instance; their rows are removed by the turns they were minted on.</p>
Class OcuPilot.Test.DraftRegistry Extends %UnitTest.TestCase
{

Parameter ORIGIN = "https://draft.example:52773";

/// <p>The prefix every secret probe value starts with, which no rendered script may carry.</p>
Parameter SECRETPROBE = "OcuPilotDraftSecretProbe";

/// <p>The prefix every ordinary probe value starts with.</p>
Parameter FIELDPROBE = "OcuPilotDraftFieldProbe";

Parameter DEFAULTPORT = "OcuPilot.Port.AdminPort";

Parameter WRITEBASE = "OcuPilot.Screen.Tool.Write";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Synthetic values for subject fields whose stored shape is structured, as
/// <code>&lt;field&gt;=&lt;JSON&gt;</code> entries separated by <code>;</code>. Every other synthetic
/// field is a string probe.</p>
Parameter STRUCTUREDFIELDS = "entries=[{""date"":""2026-09-26"",""errorNumber"":1}];Mappings=[];Held={};PurgeBefore=""2026-09-01""";

/// <p>The synthetic target id: three parts, so an endpoint that reads a composite key finds each
/// part.</p>
Parameter TARGETID = "OcuPilotDraftSource/OcuPilotDraftType/OcuPilotDraftName";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Every registered write tool, as <code>pTools(name) = tool object</code>, with the count in
/// <var>pCount</var>.</p>
ClassMethod WriteTools(Output pTools, Output pCount As %Integer) As %Status
{
    Kill pTools
    Set pCount = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tList)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If tTool.%Get("kind") '= "write" Continue
        Set pTools(tTool.%Get("name")) = tTool
        Set pCount = pCount + 1
    }
    Quit $$$OK
}

/// <p>The checked-in route table equals <method>OcuPilot.Port.AdminPort.DeriveRoutes</method>'s
/// answer now, row for row, and is not empty.</p>
/// <p>Mutation (Rule 19): change one row's <code>url</code> in
/// <class>OcuPilot.Port.AdminRoutes</class>'s XData -- this goes red naming that row.</p>
Method TestTheRouteTableEqualsAFreshDerivation()
{
    Set tSC = ##class(OcuPilot.Port.AdminPort).DeriveRoutes(.tLive)
    Do $$$AssertStatusOK(tSC, "the routes derive from the instance: " _ $System.Status.GetErrorText(tSC))
    Set tSC = ##class(OcuPilot.Port.AdminRoutes).Rows(.tStored)
    Do $$$AssertStatusOK(tSC, "the checked-in table parses")
    Do $$$AssertTrue(tLive.%Size() > 0, "the derivation is not empty")
    Do $$$AssertEquals(tStored.%Size(), tLive.%Size(), "the table holds as many routes as the instance declares")
    Set tDrift = ""
    For tI = 0:1:tLive.%Size() - 1 {
        Set tLiveRow = tLive.%Get(tI).%ToJSON()
        Set tStoredRow = $Select($IsObject(tStored.%Get(tI)): tStored.%Get(tI).%ToJSON(), 1: "")
        If tLiveRow '= tStoredRow Set tDrift = tDrift _ "; instance " _ tLiveRow _ " table " _ tStoredRow
    }
    Do $$$AssertEquals(tDrift, "", "the table and the instance agree")
}

/// <p>AC4: every registered write tool's port defines <code>Snippet</code> and
/// <code>SnippetForm</code> in the class that defines <code>Invoke</code>, and answers a form for
/// the tool's own endpoint and request type; a tool that overrides <code>AfterWrite</code> defines
/// <code>SnippetAfter</code>. A failure names the tool.</p>
Method TestEveryWriteToolHasAScriptForm()
{
    Set tSC = ..WriteTools(.tTools, .tCount)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    Do $$$AssertTrue(tCount > 0, "and lists write tools to check: " _ tCount)
    Set tMissing = ""
    Set tName = ""
    For {
        Set tName = $Order(tTools(tName), 1, tTool)
        If tName = "" Quit
        Set tClass = tTool.%Get("class")
        Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(tClass, ..#DEFAULTPORT)
        Set tInvoke = ..Origin(tPort, "Invoke")
        If (tInvoke = "") || (..Origin(tPort, "Snippet") '= tInvoke) || (..Origin(tPort, "SnippetForm") '= tInvoke) {
            Set tMissing = tMissing _ "; " _ tName _ " (" _ tPort _ " defines Invoke in " _ tInvoke _ " but Snippet in " _ ..Origin(tPort, "Snippet") _ " and SnippetForm in " _ ..Origin(tPort, "SnippetForm") _ ")"
            Continue
        }
        Set tEndpoint = $ClassMethod(tClass, "Endpoint")
        Set tType = ##class(OcuPilot.Kernel.Proposal.Operation).WriteType(tClass)
        If $ClassMethod(tPort, "SnippetForm", tEndpoint, tType) = "" Set tMissing = tMissing _ "; " _ tName _ " (" _ tEndpoint _ "/" _ tType _ " has no script form in " _ tPort _ ")"
        If (..Origin(tClass, "AfterWrite") '= ..#WRITEBASE) && (..Origin(tClass, "SnippetAfter") = "") Set tMissing = tMissing _ "; " _ tName _ " (overrides AfterWrite and defines no SnippetAfter)"
    }
    Do $$$AssertEquals(tMissing, "", "every write tool has a script form" _ tMissing)
}

/// <p>The class that defines <var>pClass</var>'s compiled method <var>pMethod</var>, or
/// <code>""</code>.</p>
ClassMethod Origin(pClass As %String, pMethod As %String) As %String
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId(pClass _ "||" _ pMethod)
    If '$IsObject(tMethod) Quit ""
    Quit tMethod.Origin
}

/// <p>AC2: for every registered write tool, a synthetic stored row -- each field of its field list,
/// each fingerprint subject field and each secret name set to a unique probe -- renders at least
/// one step; no secret probe appears in any step; and each secret the tool declares that the
/// composed body carries reads as its <code>&lt;Name&gt;</code> placeholder in the script. A failure names the
/// tool.</p>
Method TestNoSecretReachesAnyRenderedScript()
{
    Set tSC = ..WriteTools(.tTools, .tCount)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    Do $$$AssertTrue(tCount > 0, "and lists write tools to render: " _ tCount)
    Set tProblems = ""
    Set tRendered = 0
    Set tName = ""
    For {
        Set tName = $Order(tTools(tName), 1, tTool)
        If tName = "" Quit
        Set tProblem = ..SecretProblem(tTool)
        If tProblem '= "" {
            Set tProblems = tProblems _ "; " _ tName _ ": " _ tProblem
            Continue
        }
        Set tRendered = tRendered + 1
    }
    Do $$$AssertEquals(tProblems, "", "every script renders with its secrets as placeholders" _ tProblems)
    Do $$$AssertEquals(tRendered, tCount, "every write tool rendered")
}

/// <p>AC2's backstop: a name no tool declares secret but the credential pattern matches
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>) reads as its placeholder wherever
/// it sits in the body, and in the query; a flag under such a name, and an ordinary name, are left
/// as they are.</p>
/// <p>Mutation (Rule 19): drop the <code>IsCredentialName</code> clause from
/// <method>OcuPilot.Kernel.Proposal.Draft.Mask</method> -- this goes red.</p>
Method TestTheCredentialPatternMasksAnUndeclaredName()
{
    Set tProbe = ..#SECRETPROBE
    Set tBody = {"SmtpPassword": (tProbe _ "1"), "Nested": {"ApiToken": (tProbe _ "2")}, "Items": [{"ClientSecret": (tProbe _ "3")}], "Description": "kept", "UseToken": true}
    Set tPlaceholders = []
    Kill tSeen
    Do ##class(OcuPilot.Kernel.Proposal.Draft).Mask(tBody, "", tPlaceholders, .tSeen)
    Set tText = tBody.%ToJSON()
    Do $$$AssertTrue(tText '[ tProbe, "no undeclared credential survives the mask: " _ tText)
    Do $$$AssertEquals(tBody.%Get("SmtpPassword"), "<SmtpPassword>", "a top-level credential name reads as its placeholder")
    Do $$$AssertEquals(tBody.%Get("Nested").%Get("ApiToken"), "<ApiToken>", "and a nested one")
    Do $$$AssertEquals(tBody.%Get("Items").%Get(0).%Get("ClientSecret"), "<ClientSecret>", "and one inside an array")
    Do $$$AssertEquals(tBody.%Get("Description"), "kept", "an ordinary name is left as it is")
    Do $$$AssertEquals(tBody.%GetTypeOf("UseToken"), "boolean", "and so is a flag under a credential name")
    Do $$$AssertEquals(tPlaceholders.%ToJSON(), "[""SmtpPassword"",""ApiToken"",""ClientSecret""]", "each masked name is listed once")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Draft).IsSecretName("ClientSecret", ""), "a query parameter the pattern matches is a secret")
    Do $$$AssertTrue('##class(OcuPilot.Kernel.Proposal.Draft).IsSecretName("name", ""), "and an ordinary one is not")
}

/// <p>AD-59's rule over the whole port package: every class under <code>OcuPilot.Port.</code> that
/// defines <code>Invoke</code> defines <code>Snippet</code> and <code>SnippetForm</code> itself,
/// whether or not a registered write tool declares it. A failure names the class.</p>
/// <p>Mutation (Rule 19): delete <code>OcuPilot.Port.ProviderPort</code>'s <code>Snippet</code>
/// -- this goes red naming that class.</p>
Method TestEveryPortThatDefinesInvokeDefinesASnippet()
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT parent FROM %Dictionary.CompiledMethod WHERE Name = 'Invoke' AND parent %STARTSWITH 'OcuPilot.Port.' AND Origin = parent")
    Set tCount = 0
    Set tMissing = ""
    While tRS.%Next() {
        Set tClass = tRS.%GetData(1)
        Set tCount = tCount + 1
        If (..Origin(tClass, "Snippet") '= tClass) || (..Origin(tClass, "SnippetForm") '= tClass) Set tMissing = tMissing _ " " _ tClass
    }
    Do $$$AssertTrue(tCount > 0, "the port package defines Invoke somewhere: " _ tCount)
    Do $$$AssertEquals(tMissing, "", "every port that defines Invoke defines Snippet and SnippetForm:" _ tMissing)
}

/// <p>Why <var>pTool</var>'s synthetic row fails the secrets leg, or <code>""</code>.</p>
ClassMethod SecretProblem(pTool As %DynamicObject) As %String
{
    Set tClass = pTool.%Get("class")
    Set tSecrets = ##class(OcuPilot.Kernel.Proposal.Draft).SecretNamesOf(pTool, ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(pTool, .tDeclared))
    Set tBodyNames = $ClassMethod(tClass, "SecretBodyNames")
    For tI = 1:1:$ListLength(tBodyNames) {
        If '$ListFind(tSecrets, $List(tBodyNames, tI)) Set tSecrets = tSecrets _ $ListBuild($List(tBodyNames, tI))
    }
    Set tPayload = {}
    Set tN = 0
    Set tSC = $ClassMethod(tClass, "FieldRows", .tRows)
    If $$$ISERR(tSC) Quit "its field list does not read: " _ $System.Status.GetErrorText(tSC)
    For tI = 1:1:+$Get(tRows) {
        Do ..SetProbe(tPayload, $List(tRows(tI), 1), $List(tRows(tI), 2), $List(tRows(tI), 3), .tN)
    }
    Set tSubject = $ClassMethod(tClass, "FingerprintSubject")
    For tI = 1:1:$ListLength(tSubject) {
        If tPayload.%GetTypeOf($List(tSubject, tI)) = "unassigned" Do ..SetProbe(tPayload, $List(tSubject, tI), "string", 0, .tN)
    }
    For tI = 1:1:$ListLength(tSecrets) {
        Set tN = tN + 1
        Do tPayload.%Set($List(tSecrets, tI), ..#SECRETPROBE _ tN, "string")
    }
    Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), ..#TARGETID, .tRef)
    If $$$ISERR(tSC) Quit "no target reference: " _ $System.Status.GetErrorText(tSC)
    Kill tRow
    Set tRow("targetRef") = tRef
    Set tRow("payload") = tPayload.%ToJSON()
    Set tRow("arguments") = tPayload.%ToJSON()
    Set tRow("diff") = "[]"
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Render(pTool, .tRow, ..#ORIGIN, "OcuPilotDraftProbeUser", .tDraft, .tBody, .tQuery)
    If $$$ISERR(tSC) Quit "the draft does not render: " _ $System.Status.GetErrorText(tSC)
    If '$IsObject(tDraft) Quit "no script form"
    Set tText = ..Text(tDraft)
    If tDraft.%Get("steps").%Size() = 0 Quit "no step rendered"
    If tText [ ..#SECRETPROBE Quit "a secret probe reached the script"
    Set tMissing = ""
    Set tDeclaredNames = ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(pTool, .tDeclared) _ tBodyNames
    If $IsObject(tBody) && tBody.%IsA("%Library.DynamicObject") {
        For tI = 1:1:$ListLength(tDeclaredNames) {
            Set tSecret = $List(tDeclaredNames, tI)
            If tBody.%GetTypeOf(tSecret) '= "string" Continue
            If tText '[ ("<" _ tSecret _ ">") Set tMissing = tMissing _ " " _ tSecret
        }
    }
    If tMissing '= "" Quit "the script names no placeholder for" _ tMissing
    Quit ""
}

/// <p>Set <var>pName</var> on <var>pPayload</var> to a probe of the shape its template type
/// declares, or the shape <parameter>STRUCTUREDFIELDS</parameter> names.</p>
ClassMethod SetProbe(pPayload As %DynamicObject, pName As %String, pTemplateType As %String, pIsArray As %Boolean, ByRef pN)
{
    Set pN = pN + 1
    For tI = 1:1:$Length(..#STRUCTUREDFIELDS, ";") {
        Set tEntry = $Piece(..#STRUCTUREDFIELDS, ";", tI)
        If $Piece(tEntry, "=", 1) '= pName Continue
        Set tWrapped = ##class(%DynamicObject).%FromJSON("{""v"":" _ $Piece(tEntry, "=", 2, *) _ "}")
        If $IsObject(tWrapped.%Get("v")) {
            Do pPayload.%Set(pName, tWrapped.%Get("v"))
        } Else {
            Do pPayload.%Set(pName, tWrapped.%Get("v"), tWrapped.%GetTypeOf("v"))
        }
        Quit
    }
    If pPayload.%GetTypeOf(pName) '= "unassigned" Quit
    If pIsArray {
        Do pPayload.%Set(pName, [(..#FIELDPROBE _ pN)])
        Quit
    }
    If pTemplateType = "boolean" {
        Do pPayload.%Set(pName, 1, "boolean")
        Quit
    }
    If pTemplateType = "number" {
        Do pPayload.%Set(pName, pN, "number")
        Quit
    }
    Do pPayload.%Set(pName, ..#FIELDPROBE _ pN, "string")
}

/// <p>Every step of <var>pDraft</var>'s text, joined by line feeds.</p>
ClassMethod Text(pDraft As %DynamicObject) As %String
{
    Set tText = ""
    If '$IsObject(pDraft) Quit tText
    Set tIterator = pDraft.%Get("steps").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tStep.%Get("text")
    }
    Quit tText
}

/// <p>[Spec gate] Draft/Confirm parity, merge write: the steps the draft renders for a
/// <code>webapp.list.update</code> proposal equal the steps the tool's port renders for the query
/// and body the confirm hands it.</p>
/// <p>Mutation (Rule 19): drop the <code>WithSecrets</code> line from
/// <method>OcuPilot.Kernel.Proposal.Draft.Render</method>'s composition -- the draft's body is the
/// secret-only one and this goes red.</p>
Method TestTheDraftOfAMergeWriteIsTheBodyConfirmSends()
{
    Set tArgs = {"Name": "/csp/ocupilotprobedraft", "Description": "after"}
    Do ..AssertParity("OcuPilot.Screen.Tool.WebAppUpdate", "/csp/ocupilotprobedraft", tArgs, "{""Name"":""/csp/ocupilotprobedraft"",""Description"":""before"",""Enabled"":true,""NameSpace"":""HSCUSTOM""}", "", "")
}

/// <p>Parity for a create (AD-54), whose body is composed from the arguments and whose server
/// derives a field (<method>OcuPilot.Screen.Tool.Write.DerivedFields</method>).</p>
Method TestTheDraftOfACreateIsTheBodyConfirmSends()
{
    Set tArgs = ##class(OcuPilot.Test.ProposalCreate).Args()
    Do tArgs.%Set("Name", "/csp/ocupilotprobedraftcreate", "string")
    Do ..AssertParity("OcuPilot.Screen.Tool.WebAppCreate", "/csp/ocupilotprobedraftcreate", tArgs, "", "{""Name"":""/csp/ocupilotprobedraftcreate"",""Enabled"":true}", "")
}

/// <p>Parity for a secret-only body (AD-56): the draft's <code>&lt;Password&gt;</code>, put back as
/// the value the confirm was supplied, is the body the confirm hands its port.</p>
/// <p>Mutation (Rule 19): drop the <code>SecretBody</code> line from
/// <method>OcuPilot.Kernel.Proposal.Draft.Render</method>'s composition -- this goes red.</p>
Method TestTheDraftOfASecretOnlyBodyIsTheBodyConfirmSends()
{
    Set tArgs = {"Name": "ocupilotprobedraftuser"}
    Do ..AssertParity("OcuPilot.Screen.Tool.UserPassword", "ocupilotprobedraftuser", tArgs, "{""Name"":""ocupilotprobedraftuser"",""Enabled"":true,""FullName"":""probe""}", "", "{""Password"":""" _ ..#SECRETPROBE _ "1""}")
}

/// <p>Mint <var>pToolClass</var>'s proposal of <var>pArgs</var> against <var>pId</var> over the
/// fixture's armed read <var>pFresh</var> (<code>""</code> for an absent target), render its draft,
/// confirm it with <var>pSecrets</var> through the fixture port, and assert that the port's own
/// script of what the confirm handed it equals the draft's steps with each placeholder put back as
/// the value supplied.</p>
Method AssertParity(pToolClass As %String, pId As %String, pArgs As %DynamicObject, pFresh As %String, pWritten As %String, pSecrets As %String)
{
    If pFresh = "" {
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    } Else {
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(pFresh)
    }
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tDescriptor = $Parameter(pToolClass, "DESCRIPTORCLASS")
    Set tToolName = $Parameter(pToolClass, "TOOLNAME")
    Set tSC = $ClassMethod(..#MINT, "Mint", tDescriptor, tToolName, $Username, "", tTurnKey, pArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pId, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    Do $$$AssertStatusOK(tSC, tToolName _ " mints: " _ $System.Status.GetErrorText(tSC) _ " " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tRow)
    Do ##class(OcuPilot.Screen.Tool.Registry).Resolve(tToolName, .tTool)
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Render(tTool, .tRow, ..#ORIGIN, $Username, .tDraft, .tBody, .tQuery)
    Do $$$AssertStatusOK(tSC, "the draft renders")
    If '$IsObject($Get(tDraft)) {
        Do $$$AssertTrue(0, "the draft has a script form")
        Quit
    }

    If pWritten '= "" Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(pWritten)
    Set tSupplied = ""
    If pSecrets '= "" Set tSupplied = ##class(%DynamicObject).%FromJSON(pSecrets)
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, tSupplied, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm writes through the fixture: " _ tCode)
    If $$$ISERR(tSC) Quit
    Kill tSentQuery
    Merge tSentQuery = ^||OcuPilotProposalFixture("query")
    Set tSentBody = ""
    If ##class(OcuPilot.Test.ProposalFixture).LastWriteBody() '= "" Set tSentBody = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProposalFixture).LastWriteBody())
    Set tContext = {"origin": (..#ORIGIN), "user": ($Username)}
    Do tContext.%Set("creates", ##class(OcuPilot.Kernel.Proposal.Mint).CreatesOf(pToolClass), "boolean")
    Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(pToolClass, ..#DEFAULTPORT)
    Set tExpected = $ClassMethod(tPort, "Snippet", $Get(^||OcuPilotProposalFixture("endpoint")), ##class(OcuPilot.Test.ProposalFixture).LastType(), .tSentQuery, tSentBody, tContext)
    Do $$$AssertTrue(tExpected.%Size() > 0, "the confirm's own call renders")
    If '##class(%Dictionary.CompiledMethod).%ExistsId(pToolClass _ "||SnippetAfter") Do $$$AssertEquals(tDraft.%Get("steps").%Size(), tExpected.%Size(), tToolName _ ": the draft renders no step the confirm's call does not")

    Set tDrafted = ""
    For tI = 0:1:tExpected.%Size() - 1 {
        Set tStep = tDraft.%Get("steps").%Get(tI)
        Set tDrafted = tDrafted _ $Select(tI = 0: "", 1: $Char(10)) _ $Select($IsObject(tStep): tStep.%Get("text"), 1: "")
    }
    If $IsObject(tSupplied) {
        Set tIterator = tSupplied.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            Set tDrafted = $Replace(tDrafted, "<" _ tName _ ">", tValue)
        }
    }
    Do $$$AssertEquals(tDrafted, ..Text({"steps": (tExpected)}), tToolName _ ": the draft is the script of what the confirm sends")
}

}
