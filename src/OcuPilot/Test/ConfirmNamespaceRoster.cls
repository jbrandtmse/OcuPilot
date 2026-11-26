/// <p>Pins that every registered write tool that can reach more than one namespace keeps, in the payload its proposal would store
/// from a read that answers its declared namespace field, that namespace, so that a confirm sent from another namespace asks its
/// port in the first one (AD-52, AD-62). Whether each port's real read answers that field is not asked here.</p>
/// <p>For each tool outside the declared exemptions (<code>Exemptions</code>) it sets the request scope to one sentinel, builds the
/// payload the mint stores (the tool's <code>MergeUpdate</code> over a read that answers every <code>READANSWERS</code> field, narrowed
/// by its fingerprint subject, or its <code>ComposeCreate</code>), sets the scope to a second sentinel, builds the confirm's port query
/// with <method>OcuPilot.Kernel.Proposal.Operation.Query</method> and asks that the query names the first under the port's own
/// namespace key. The mint of three creates puts the namespace into the arguments it hands <code>ComposeCreate</code>;
/// <parameter>MINTARGUMENT</parameter> names them.</p>
/// <p>An exemption names a port class or a tool. A port entry exempts the tools that reach that port and declare instance scope; a
/// tool entry exempts one instance-scoped tool; a person entry exempts a tool that mints no proposal. Every entry must match a
/// registered write tool, and the port of a port or tool entry must not read the request scope in any method it compiles.</p>
/// <p><b>What it needs from the environment:</b> nothing is written and no variable arms it; it sets the request scope and puts it
/// back.</p>
Class OcuPilot.Test.ConfirmNamespaceRoster Extends %UnitTest.TestCase
{

/// <p>The namespace the mint is taken to read in.</p>
Parameter MINTSCOPE = "OcuProbeMintNs";

/// <p>The namespace the confirming request is taken to be scoped to.</p>
Parameter CONFIRMSCOPE = "OcuProbeConfirmNs";

/// <p>The target a create's payload is composed for.</p>
Parameter PROBENAME = "OcuProbeRoster";

/// <p>The creates whose mint puts the namespace into the arguments it hands <code>ComposeCreate</code>.</p>
Parameter MINTARGUMENT = "OcuPilot.Screen.Tool.ExplorerClassCreate,OcuPilot.Screen.Tool.ExplorerRoutineCreate,OcuPilot.Screen.Tool.RestServiceCreate";

/// <p>How many entries <code>Exemptions</code> holds.</p>
Parameter EXEMPTIONCOUNT = 43;

/// <p>The fewest write tools the walk must ask, so an exemption that takes tools out of the check is seen.</p>
Parameter CHECKEDFLOOR = 161;

/// <p>The source texts that read the request scope, comma-separated.</p>
Parameter SCOPEREADERS = "Kernel.Scope,OcuPilotScope";

/// <p>One exemption to a line, <code>&lt;kind&gt;|&lt;key&gt;|&lt;reason&gt;</code>: <code>port</code> keys a port class,
/// <code>tool</code> and <code>person</code> a tool's name.</p>
XData Exemptions [ MimeType = text/plain ]
{
port|OcuPilot.Port.AdminPort|the vendor's admin API addresses instance-wide objects and the port never reads the request scope
port|OcuPilot.Port.AdvisorPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.AllowListPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.BackgroundTaskPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.BackupPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.ConfigPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.DatabasePort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.DocDbAppPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.EcpPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.EncryptionPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.JournalPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.LanguageServerPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.LicensePort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.LocalePort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.LockPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.LogSourcePort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.MftPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.MonitorPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.NamespacePort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.OAuthAuthorizationServerPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.OAuthClientPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.OAuthRegisteredClientPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.OAuthResourceServerPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.OAuthServerPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.PctAccessPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.PhoneProviderPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.ProcessPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.RemoteDatabasePort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.ResourceTransferPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.ScreenAccessPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.SqlActivityPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.SuperserverPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.TaskPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.TaskTransferPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.TokenPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.UserCopyPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.WalletPort|the port never reads the request scope and its tools are instance-scoped
port|OcuPilot.Port.PortalResourcePort|the port never reads the request scope and its tools are instance-scoped (page resources are %SYS's)
tool|security.auditing.export|the audit log is the instance's and no namespace names it; the audit port's one tool that carries a namespace is the copy
tool|security.auditing.purge|the audit log is the instance's and no namespace names it; the audit port's one tool that carries a namespace is the copy
person|explorer.classmethod.run|a person's alone: it mints no proposal, so nothing is stored
person|explorer.command.run|a person's alone: it mints no proposal, so nothing is stored
person|explorer.unittests.run|a person's alone: it mints no proposal, so nothing is stored
}

/// <p>The exemptions of <code>Exemptions</code> in <var>pRoster</var>, subscripted by kind and key with the reason as the value, and how
/// many there are in <var>pCount</var>.</p>
ClassMethod LoadRoster(Output pRoster, Output pCount As %Integer) As %Status
{
    Kill pRoster
    Set pCount = 0
    Set tXData = ##class(%Dictionary.CompiledXData).%OpenId($ClassName() _ "||Exemptions")
    If '$IsObject(tXData) Quit $$$ERROR($$$GeneralError, "the exemption roster could not be read")
    Set tStream = tXData.Data
    Do tStream.Rewind()
    While 'tStream.AtEnd {
        Set tLine = $ZStrip(tStream.ReadLine(), "<>W")
        If tLine = "" Continue
        Set pRoster($Piece(tLine, "|", 1), $Piece(tLine, "|", 2)) = $Piece(tLine, "|", 3, *)
        Set pCount = pCount + 1
    }
    Quit $$$OK
}

/// <p>The kind of exemption that covers the write tool <var>pName</var> of class <var>pClass</var>, <code>person</code> first, then
/// <code>tool</code>, then <code>port</code>, or <code>""</code> when none does. Every entry that matches is counted in
/// <var>pMatched</var>.</p>
ClassMethod ExemptionOf(pClass As %String, pName As %String, pRoster, ByRef pMatched) As %String
{
    Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(pClass, $Parameter("OcuPilot.Screen.Tool.Write", "PORTCLASS"))
    Set tKind = ""
    For tCandidate = "person|" _ pName, "tool|" _ pName, "port|" _ tPort {
        If '$Data(pRoster($Piece(tCandidate, "|", 1), $Piece(tCandidate, "|", 2))) Continue
        Set pMatched($Piece(tCandidate, "|", 1), $Piece(tCandidate, "|", 2)) = $Get(pMatched($Piece(tCandidate, "|", 1), $Piece(tCandidate, "|", 2))) + 1
        If tKind = "" Set tKind = $Piece(tCandidate, "|", 1)
    }
    Quit tKind
}

/// <p>What is wrong with exempting the tool <var>pClass</var> under <var>pKind</var>, or <code>""</code>: a <code>person</code> tool
/// declares a person's gate; any other declares instance scope, and its port reads no request scope
/// (<method>ScopeReader</method>, remembered in <var>pSeen</var>).</p>
ClassMethod ExemptionProblem(pClass As %String, pKind As %String, ByRef pSeen) As %String
{
    If pKind = "person" {
        If $Parameter(pClass, "PERSONGATE") = "" Quit "it is exempt as a person's alone and declares no person's gate"
        Quit ""
    }
    Set tScope = ""
    Try {
        Set tScope = $ClassMethod($Parameter(pClass, "DESCRIPTORCLASS"), "Scope")
    } Catch {
        Set tScope = ""
    }
    If tScope '= ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE Quit "it is exempt as instance-scoped and its descriptor declares '" _ tScope _ "'"
    Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(pClass, $Parameter("OcuPilot.Screen.Tool.Write", "PORTCLASS"))
    Set tReader = ..ScopeReader(tPort, .pSeen)
    If tReader '= "" Quit "it is exempt as namespace-free and its port " _ tPort _ " " _ tReader
    Quit ""
}

/// <p>How the port <var>pPort</var> reads the request scope, or <code>""</code> when no method it compiles from an OcuPilot class
/// names any text of <parameter>SCOPEREADERS</parameter>. A method whose source cannot be read is reported, never taken as clean.
/// Each port and method is read once, remembered in <var>pSeen</var>.</p>
ClassMethod ScopeReader(pPort As %String, ByRef pSeen) As %String
{
    If $Data(pSeen("port", pPort), tFound) Quit tFound
    Set tFound = ""
    Set tNeedles = $ListFromString(..#SCOPEREADERS)
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare("SELECT Name, Origin FROM %Dictionary.CompiledMethod WHERE parent = ?")
    If $$$ISERR(tSC) Quit "could not have its methods listed"
    Set tResult = tStatement.%Execute(pPort)
    Set tListed = 0
    While (tFound = "") && tResult.%Next() {
        Set tListed = tListed + 1
        Set tOrigin = tResult.%Get("Origin")
        If $Extract(tOrigin, 1, 9) '= "OcuPilot." Continue
        Set tKey = tOrigin _ "||" _ tResult.%Get("Name")
        If '$Data(pSeen("method", tKey), tHit) {
            Set tHit = "its method " _ tKey _ " could not be read"
            Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId(tKey)
            If $IsObject(tMethod) {
                Set tHit = ""
                Set tStream = tMethod.Implementation
                Do tStream.Rewind()
                While (tHit = "") && 'tStream.AtEnd {
                    Set tLine = tStream.ReadLine()
                    For tAt = 1:1:$ListLength(tNeedles) {
                        If tLine [ $List(tNeedles, tAt) Set tHit = "reads the request scope in " _ tKey
                    }
                }
            }
            Set pSeen("method", tKey) = tHit
        }
        Set tFound = tHit
    }
    If (tFound = "") && (tListed = 0) Set tFound = "compiles no method"
    Set pSeen("port", pPort) = tFound
    Quit tFound
}

/// <p>Whether a member of <var>pObject</var> holds <var>pValue</var>.</p>
ClassMethod HoldsValue(pObject As %DynamicObject, pValue As %String) As %Boolean
{
    If '$IsObject(pObject) Quit 0
    Set tHolds = 0
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$IsObject(tValue) && (tValue = pValue) {
            Set tHolds = 1
            Quit
        }
    }
    Quit tHolds
}

/// <p>The payload the mint stores for the create <var>pToolClass</var>, composed in the scope the caller has set, or <code>""</code> with
/// <var>pNote</var> saying why none could be composed. A create named by <parameter>MINTARGUMENT</parameter> is composed with the
/// namespace among its arguments, as its mint does, and <var>pBare</var> tells whether the same compose without it also carries the
/// namespace.</p>
ClassMethod ComposedCreate(pToolClass As %String, Output pNote As %String, Output pBare As %Boolean) As %DynamicObject
{
    Set pPayload = ""
    Set pNote = ""
    Set pBare = 0
    Set tIdArgument = $ClassMethod(pToolClass, "IdArgument")
    Set tSettable = $ClassMethod(pToolClass, "SettableFields")
    Set tField = $Parameter(pToolClass, "NAMESPACEFIELD")
    If tField = "" Set tField = "Namespace"
    Set tMint = $ListFind($ListFromString(..#MINTARGUMENT), pToolClass)
    For tAttempt = 1:1:2 {
        Set tArgs = {}
        If tMint || (tAttempt = 2) Do tArgs.%Set(tIdArgument, ..#PROBENAME, "string")
        If tMint Do tArgs.%Set(tField, ..#MINTSCOPE, "string")
        Set tPayload = ""
        Set tSC = $ClassMethod(pToolClass, "ComposeCreate", tArgs, tIdArgument, tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        Set pNote = $Get(tProblem)
        If $$$ISOK(tSC) && $IsObject(tPayload) && (pNote = "") {
            Set pPayload = tPayload
            Quit
        }
        If $$$ISERR(tSC) Set pNote = $System.Status.GetErrorText(tSC)
        If tMint Quit
    }
    If tMint && $IsObject(pPayload) {
        Set tBareArgs = {}
        Do tBareArgs.%Set(tIdArgument, ..#PROBENAME, "string")
        Set tBarePayload = ""
        Set tSC = $ClassMethod(pToolClass, "ComposeCreate", tBareArgs, tIdArgument, tSettable, .tBarePayload, .tDiff, .tUnchanged, .tProblem)
        Set pBare = $$$ISOK(tSC) && ..HoldsValue(tBarePayload, ..#MINTSCOPE)
    }
    Quit pPayload
}

/// <p>The payload the mint stores for the change <var>pToolClass</var>: its <code>MergeUpdate</code> over a read that answers every
/// field it declares, the namespace among them, narrowed to its fingerprint subject. <var>pNote</var> says why none could be built.</p>
ClassMethod MergedUpdate(pToolClass As %String, Output pNote As %String) As %DynamicObject
{
    Set pNote = ""
    Set tSubject = $ClassMethod(pToolClass, "FingerprintSubject")
    Set tAnswers = $ClassMethod(pToolClass, "ReadAnswers")
    Set tFresh = {}
    For tAt = 1:1:$ListLength(tAnswers) {
        Do tFresh.%Set($List(tAnswers, tAt), "x")
    }
    For tAt = 1:1:$ListLength(tSubject) {
        If tFresh.%GetTypeOf($List(tSubject, tAt)) = "unassigned" Do tFresh.%Set($List(tSubject, tAt), "x")
    }
    For tName = "Namespace", "namespace", $Parameter(pToolClass, "NAMESPACEFIELD") {
        If (tName '= "") && (tFresh.%GetTypeOf(tName) '= "unassigned") Do tFresh.%Set(tName, ..#MINTSCOPE, "string")
    }
    Set tSC = $ClassMethod(pToolClass, "MergeUpdate", tFresh, {}, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    If $$$ISERR(tSC) {
        Set pNote = $System.Status.GetErrorText(tSC)
        Quit ""
    }
    If '$IsObject($Get(tPayload)) {
        Set pNote = "no payload: " _ $Get(tProblem)
        Quit ""
    }
    If tSubject '= "" {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Projection(tPayload, tSubject, .tProjected)
        If $$$ISERR(tSC) {
            Set pNote = $System.Status.GetErrorText(tSC)
            Quit ""
        }
        Quit tProjected
    }
    Quit tPayload
}

/// <p>Whether the confirm's port query for <var>pToolClass</var> names the namespace its proposal was minted in, under the port's
/// own namespace key (its <code>NAMESPACEKEY</code>, else its <code>NAMESPACEQUERY</code>). The mint's request scope is
/// <parameter>MINTSCOPE</parameter> while the payload is built and <parameter>CONFIRMSCOPE</parameter> while the query is.
/// <var>pNote</var> says why the question could not be asked, and <var>pBare</var> is set for a create named by
/// <parameter>MINTARGUMENT</parameter> whose compose carries the namespace without being given it.</p>
ClassMethod Carries(pToolClass As %String, Output pNote As %String, Output pBare As %Boolean) As %Boolean
{
    Set pNote = ""
    Set pBare = 0
    Set tCarries = 0
    Try {
        Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(pToolClass, $Parameter("OcuPilot.Screen.Tool.Write", "PORTCLASS"))
        Set tKeyName = $Parameter(tPort, "NAMESPACEKEY")
        If tKeyName = "" Set tKeyName = $Parameter(tPort, "NAMESPACEQUERY")
        If tKeyName = "" {
            Set pNote = "its port " _ tPort _ " declares no namespace key"
            Quit
        }
        Set tIdParam = $ClassMethod(pToolClass, "IdParam")
        If tIdParam = "" Set tIdParam = "id"
        Do ##class(OcuPilot.Kernel.Scope).Set(..#MINTSCOPE)
        If $ClassMethod(pToolClass, "Creates") {
            Set tPayload = ..ComposedCreate(pToolClass, .pNote, .pBare)
        } Else {
            Set tPayload = ..MergedUpdate(pToolClass, .pNote)
        }
        Do ##class(OcuPilot.Kernel.Scope).Set(..#CONFIRMSCOPE)
        If '$IsObject(tPayload) {
            If pNote = "" Set pNote = "no payload was built"
            Quit
        }
        Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(pToolClass, tIdParam, "PROBEID", tPayload.%ToJSON(), .tQuery)
        Set tCarries = ($Get(tQuery(tKeyName)) = ..#MINTSCOPE)
    } Catch ex {
        Set pNote = "raised: " _ $System.Status.GetErrorText(ex.AsStatus())
    }
    Quit tCarries
}

/// <p>Walk the registry's write tools: how many there are in <var>pWalked</var>, how many an exemption covers in <var>pExempt</var>
/// and how many were asked in <var>pChecked</var>. <var>pLost</var> names the tools whose confirm query does not name the mint's
/// namespace, <var>pProblems</var> the tools that could not be asked or whose exemption does not hold,
/// <var>pUnmatched</var> the exemptions that match no registered write tool and <var>pNeedless</var> the
/// <parameter>MINTARGUMENT</parameter> entries whose compose carries the namespace without it. The request scope is put back.</p>
ClassMethod Walk(Output pWalked As %Integer, Output pExempt As %Integer, Output pChecked As %Integer, Output pLost As %String, Output pProblems As %String, Output pUnmatched As %String, Output pNeedless As %String) As %Status
{
    Set pWalked = 0
    Set pExempt = 0
    Set pChecked = 0
    Set (pLost, pProblems, pUnmatched, pNeedless) = ""
    Set tSC = ..LoadRoster(.tRoster, .tCount)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    If $$$ISERR(tSC) Quit tSC
    Set tHadScope = $Data(^||OcuPilotScope)
    Set tSavedScope = $Get(^||OcuPilotScope)
    Try {
        Set tIterator = tTools.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTool) {
            If tTool.kind '= "write" Continue
            Set pWalked = pWalked + 1
            Set tClass = tTool.class
            Set tName = tTool.name
            Set tKind = ..ExemptionOf(tClass, tName, .tRoster, .tMatched)
            If tKind '= "" {
                Set pExempt = pExempt + 1
                Set tProblem = ..ExemptionProblem(tClass, tKind, .tSeen)
                If tProblem '= "" Set pProblems = pProblems _ tName _ ": " _ tProblem _ "; "
                Continue
            }
            Set pChecked = pChecked + 1
            Set tCarries = ..Carries(tClass, .tNote, .tBare)
            If tNote '= "" {
                Set pProblems = pProblems _ tName _ ": " _ tNote _ "; "
            } ElseIf 'tCarries {
                Set pLost = pLost _ tName _ " (" _ tClass _ "); "
            }
            If tBare Set pNeedless = pNeedless _ tName _ "; "
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tHadScope {
        Do ##class(OcuPilot.Kernel.Scope).Set(tSavedScope)
    } Else {
        Do ##class(OcuPilot.Kernel.Scope).Clear()
    }
    Set tKind = ""
    For {
        Set tKind = $Order(tRoster(tKind))
        If tKind = "" Quit
        Set tKey = ""
        For {
            Set tKey = $Order(tRoster(tKind, tKey))
            If tKey = "" Quit
            If '$Get(tMatched(tKind, tKey)) Set pUnmatched = pUnmatched _ tKind _ " " _ tKey _ "; "
        }
    }
    Set tMint = $ListFromString(..#MINTARGUMENT)
    For tAt = 1:1:$ListLength(tMint) {
        Set tMintClass = $List(tMint, tAt)
        If '##class(%Dictionary.CompiledClass).%ExistsId(tMintClass) Set pUnmatched = pUnmatched _ "mint argument " _ tMintClass _ "; "
    }
    Quit tSC
}

/// <p>Every write tool outside the exemptions asks its port, in a confirm sent from another namespace, where its proposal was minted.</p>
/// <p>Mutation (Rule 19): take <code>Namespace</code> out of the <code>FINGERPRINTSUBJECT</code> of
/// <class>OcuPilot.Screen.Tool.InteropPartnerRemove</class>, <class>OcuPilot.Screen.Tool.InteropLookupEntryRemove</class> or
/// <class>OcuPilot.Screen.Tool.InteropLookupTableDelete</class> -- this goes red and names that tool. Exempt a port whose tools
/// carry the namespace -- this goes red on <parameter>CHECKEDFLOOR</parameter>.</p>
Method TestEveryWriteToolAsksItsPortInTheNamespaceItsProposalRead()
{
    Set tSC = ..Walk(.tWalked, .tExempt, .tChecked, .tLost, .tProblems, .tUnmatched, .tNeedless)
    Do $$$AssertStatusOK(tSC, "the registry's write tools are walked")
    Do $$$AssertTrue(tChecked >= ..#CHECKEDFLOOR, "at least " _ ..#CHECKEDFLOOR _ " write tools are asked: " _ tChecked)
    Do $$$AssertEquals(tLost, "", "no tool's confirm query loses the namespace its proposal read: " _ tLost)
    Do $$$AssertEquals(tProblems, "", "every tool outside the exemptions could be asked, and every exemption holds: " _ tProblems)
}

/// <p>Every exemption names a registered write tool, a port a registered write tool reaches or a create whose mint supplies the
/// namespace, and each tool it covers is instance-scoped or a person's alone.</p>
/// <p>Mutation (Rule 19): add an exemption that names no registered write tool -- this goes red and names it.</p>
Method TestEveryExemptionNamesARegisteredWriteTool()
{
    Set tSC = ..Walk(.tWalked, .tExempt, .tChecked, .tLost, .tProblems, .tUnmatched, .tNeedless)
    Do $$$AssertStatusOK(tSC, "the registry's write tools are walked")
    Do $$$AssertEquals(tUnmatched, "", "every exemption matches a registered write tool: " _ tUnmatched)
    Do $$$AssertEquals(tNeedless, "", "every create named as supplied by its mint needs the mint to supply it: " _ tNeedless)
}

/// <p>The walk is not empty and the roster has not grown or shrunk unseen: each count is above zero, the tools partition into the
/// exempt and the checked, and the roster holds the entries this class declares.</p>
/// <p>Mutation (Rule 19): drop an entry from <code>Exemptions</code> -- this goes red on the size.</p>
Method TestTheWalkIsNotEmptyAndTheRosterHasItsSize()
{
    Set tSC = ..Walk(.tWalked, .tExempt, .tChecked, .tLost, .tProblems, .tUnmatched, .tNeedless)
    Do $$$AssertStatusOK(tSC, "the registry's write tools are walked")
    Do $$$AssertTrue(tWalked > 0, "the registry holds write tools: " _ tWalked)
    Do $$$AssertTrue(tChecked > 0, "some are asked: " _ tChecked)
    Do $$$AssertTrue(tExempt > 0, "some are exempt: " _ tExempt)
    Do $$$AssertEquals(tExempt + tChecked, tWalked, "each write tool is exempt or asked")
    Set tSC = ..LoadRoster(.tRoster, .tCount)
    Do $$$AssertStatusOK(tSC, "the roster is read")
    Do $$$AssertEquals(tCount, ..#EXEMPTIONCOUNT, "the roster holds the entries this class declares")
}

}
