/// <p>Pins Story 21.5's writes on both permitted callers (AC3, AC4, AC5, AC6; AD-4, AD-6, AD-10, AD-22, AD-51, AD-53, AD-58): a node's value edited by the
/// screen's own action and read back, refused when the node changed since the dialog opened, is gone, or is not plain text; a node killed with everything
/// below it; a whole global deleted by the screen and by the agent's confirmed proposal, the agent's refused by governance while its key ships disabled;
/// OcuPilot's own and protected globals and OcuPilot's code globals refused before any write by the kernel's arm, at the arm over every directory and on
/// both callers against the instance's own protected global; a vendor <code>&lt;PROTECT&gt;</code> answered 403; and an import judged by the globals it
/// names (DW-2607).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, and a
/// <code>USER</code> namespace. Each test makes its own global <code>^ZZOcuGlb&lt;pid&gt;</code> in <code>HSCUSTOM</code> (one also in <code>USER</code>) and kills it, and snapshots the stored
/// governance policy before and puts it back after. It writes no protected global.</p>
Class OcuPilot.Test.GlobalWrite Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.GlobalPort";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.ExplorerGlobalDelete";

Parameter SAVETOOL = "OcuPilot.Screen.Tool.ExplorerGlobalNodeSave";

Parameter NODEDELETETOOL = "OcuPilot.Screen.Tool.ExplorerGlobalNodeDelete";

Parameter LISTSCREEN = "explorer.globals";

Parameter NODESCREEN = "explorer.globalnodes";

Parameter NAMESPACE = "HSCUSTOM";

/// <p>The name of the test's own global, without <code>^</code>.</p>
Property PreparedName As %String;

Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedName = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedName = "ZZOcuGlb" _ $Job
    Do ..Remove()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ..Remove()
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Reset()
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Kill the test's global, and its copy in <code>USER</code>.</p>
Method Remove()
{
    Set tRoot = "^" _ ..PreparedName
    Kill @tRoot
    Set tRoot = "^|""USER""|" _ ..PreparedName
    Kill @tRoot
}

/// <p>The test's global: two plain nodes, a <code>$ListBuild</code> node, a node whose value is over a display's length, and a node with a node below it.</p>
Method Make()
{
    Set tRoot = "^" _ ..PreparedName
    Set @tRoot@(1) = "v1"
    Set @tRoot@(2) = "v2"
    Set @tRoot@("l") = $ListBuild(1, 2)
    Set @tRoot@("long") = $Translate($Justify("", 1500), " ", "x")
    Set @tRoot@("t") = "top"
    Set @tRoot@("t", 1) = "a"
    Set @tRoot@("t", 2) = "b"
}

/// <p>The canonical reference of the test's node <var>pSubscripts</var> (the text inside the parentheses, <code>""</code> for the root).</p>
Method Ref(pSubscripts As %String = "") As %String
{
    Quit "^" _ ..PreparedName _ $Select(pSubscripts = "": "", 1: "(" _ pSubscripts _ ")")
}

/// <p>The screen action <var>pAction</var> of <var>pScreen</var> on <var>pId</var> over HTTP, in namespace <var>pNamespace</var>, as the suite's account: the
/// status, and the parsed answer in <var>pAnswer</var>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "", pNamespace As %String = {..#NAMESPACE}, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ pScreen _ "/action?ns=" _ pNamespace, .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The status and refusal code an answer carries, as <code>status code</code>.</p>
ClassMethod Verdict(pStatus As %Integer, pAnswer As %DynamicObject) As %String
{
    Quit pStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The fresh read of node <var>pReference</var> through the port, as <code>Value|Editable</code>, or <code>(HTTP status)</code> when it answers none.</p>
Method Read(pReference As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("reference") = pReference
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Node", "GET", .tQuery, "", .tNode, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tNode)): tNode.Value _ "|" _ tNode.Editable, 1: "(" _ tHttp _ ")")
}

/// <p>Whether the arm answers prohibited, as <code>prohibits code</code>, for tool <var>pTool</var> over target <var>pType</var>/<var>pId</var> in
/// <var>pNamespace</var>, asked of <class>OcuPilot.Test.GlobalProhibited</class>, whose reads answer what the location seam was armed with.</p>
ClassMethod Arm(pTool As %String, pType As %String, pId As %String, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(pType, pNamespace, pId, .tRef)
    If $$$ISERR(tSC) Quit "key: " _ $System.Status.GetErrorText(tSC)
    Set tSC = ##class(OcuPilot.Test.GlobalProhibited).Prohibits(pTool, tRef, "{}", "[]", .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit "error"
    Quit tProhibits _ " " _ tCode
}

/// <p>The three tools declare what the story rules: names, port, endpoints, request types, who reaches each, the destructive ones, the values a screen
/// sends, the governance keys shipping disabled, and the pairs each requires (its screen's, and the classic edit page's for a node).</p>
/// <p>Mutation (Rule 19): set <code>ADVERTISED</code> 1 on the node save -> the unadvertised assertion goes red.</p>
Method TestTheToolsDeclareTheirWritePath()
{
    For tCase = $ListBuild(..#DELETETOOL, "explorer.globals.delete", "Globals", "1", "1", "DELETE"), $ListBuild(..#SAVETOOL, "explorer.globalnodes.save", "Node", "0", "0", "PUT"), $ListBuild(..#NODEDELETETOOL, "explorer.globalnodes.delete", "Node", "0", "1", "DELETE") {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), $List(tCase, 2) _ "|" _ ..#PORT _ "|" _ $List(tCase, 3), $List(tCase, 2) _ ": name, port and endpoint")
        Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 4) _ $List(tCase, 5) _ "0|" _ $List(tCase, 6), $List(tCase, 2) _ ": advertised, destructive, bodyless, write type")
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 2), .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve($List(tCase, 2), "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 0", $List(tCase, 2) _ ": its key is in the baseline and ships disabled")
    }
    Do $$$AssertEquals($ListToString($ClassMethod(..#DELETETOOL, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(..#SAVETOOL, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(..#NODEDELETETOOL, "ScreenActionIds")), "delete|save|delete", "each declares its row action")
    Do $$$AssertEquals($ListToString($ClassMethod(..#SAVETOOL, "ScreenActionValueNames", "save")) _ "|" _ $ListToString($ClassMethod(..#SAVETOOL, "SettableFields")), "Value,Was|Value", "the save's screen values are the new value and the value read; its one argument is the value")
    Do $$$AssertEquals($ClassMethod(..#DELETETOOL, "Consequence", {}) _ "|" _ $ClassMethod(..#NODEDELETETOOL, "Consequence", {}), ##class(OcuPilot.Api.GlobalError).#DELETE _ "|" _ ##class(OcuPilot.Api.GlobalError).#NODEDELETE, "the deletes carry their consequence codes")
    Set tPairs = $ClassMethod(..#NODEDELETETOOL, "PrivilegePairs", "", .tResolved)
    Do $$$AssertTrue(tResolved && ($ListFind(tPairs, $ListBuild("%Development", "USE")) > 0), "the node tools' pairs hold the node page's own")
    Set tListPairs = $ClassMethod(..#DELETETOOL, "PrivilegePairs", "", .tListResolved)
    Do $$$AssertTrue(tListResolved && ($ListLength(tListPairs) '> $ListLength(tPairs)), "and the node tools add the classic edit page's resource to the list's pairs")
    Do $$$AssertEquals(##class(OcuPilot.Api.GlobalError).ReasonFor("GLOBAL.NODE.NOTEDITABLE"), "Only a value of plain text, 1,000 characters at most, can be edited here.", "the refusals carry their ruled sentences")
}

/// <p>AC3. A plain-text node edited by the screen's action is set and the answer names the target, the verb and the read-back; the node as the dialog read it
/// (<code>Was</code>) is the guard: a node that holds another value now writes nothing and is refused, a node killed since is 404
/// <code>GLOBAL.NODE.NOTFOUND</code>, a node that is not plain text or is over 1,000 characters is 409 <code>GLOBAL.NODE.NOTEDITABLE</code>, a value that is
/// not plain text of 1,000 characters at most is 400 <code>GLOBAL.VALUE.SHAPE</code>, the empty string is a value, and a reference that is not canonical is
/// 400 <code>PORT.VALIDATION</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>Was</code> comparison in <method>OcuPilot.Screen.Tool.ExplorerGlobalNodeSave.ScreenActionDelta</method> -> the
/// changed-since leg goes red. The fingerprint subject's <code>Value</code> cannot be dropped to the same effect: the merge replaces it (Design Notes).
/// Set <code>READBACKPAYLOAD</code> 0 on the save tool -> the read-back assertion goes red.</p>
Method TestAnEditRoundTripsAndANodeChangedSinceIsNotWritten()
{
    Do ..Make()
    Set tRoot = "^" _ ..PreparedName
    Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(1), {"Value": "new", "Was": "v1"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "200|updated|global-node|" _ ..Ref(1), "the edit is answered with its verb and target: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(@tRoot@(1), "new", "the instance holds the new value")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.readBack): tAnswer.readBack.verdict, 1: ""), "matches", "and the answer's read-back compares the value sent with the value read and matches")
    Set @tRoot@(2) = "other"
    Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(2), {"Value": "x", "Was": "v2"}, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ @tRoot@(2), "409 STATE.CONFLICT|other", "a node that changed after the dialog opened is refused as a stale save and nothing is written")
    Kill @tRoot@(2)
    Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(2), {"Value": "x", "Was": "other"}, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Data(@tRoot@(2)), "404 GLOBAL.NODE.NOTFOUND|0", "a node killed since is gone, and no node is created")
    For tSubscript = """l""", """long""" {
        Set tShown = $Piece(..Read(..Ref(tSubscript)), "|", 1)
        Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(tSubscript), {"Value": "x", "Was": (tShown)}, , .tAnswer)
        Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "409 GLOBAL.NODE.NOTEDITABLE", tSubscript _ " is not editable")
    }
    Do $$$AssertEquals($Length(@tRoot@("long")) _ "|" _ (@tRoot@("l") = $ListBuild(1, 2)), "1500|1", "and neither value changed")
    For tCase = "a" _ $Char(1), $Translate($Justify("", 1001), " ", "x"), "tab" _ $Char(9) {
        Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(1), {"Value": (tCase), "Was": "new"}, , .tAnswer)
        Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ @tRoot@(1), "400 GLOBAL.VALUE.SHAPE|new", "a value with a control character or over 1,000 characters is refused")
    }
    Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(1), {"Value": "", "Was": "new"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Data(@tRoot@(1)) _ "|" _ @tRoot@(1), "200|1|", "the empty string is a value")
    Set tStatus = ..Act(..#NODESCREEN, "save", "^" _ ..PreparedName _ "(01)", {"Value": "x", "Was": ""}, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "400 PORT.VALIDATION", "a reference that is not canonical is refused")
}

/// <p>AC4 (node). A node killed by the screen's action takes everything below it: the node, its subscripts and nothing else; a node already gone is 404
/// <code>GLOBAL.NODE.NOTFOUND</code>. The screen's own action asks no governance key, so it runs although its key ships disabled.</p>
/// <p>Mutation (Rule 19): kill only the node's own value (<code>ZKill</code>) in <method>OcuPilot.Port.GlobalPort.VendorKillNode</method> -> the descendant
/// assertion goes red.</p>
Method TestANodeKillRemovesTheNodeAndEverythingBelowIt()
{
    Do ..Make()
    Set tRoot = "^" _ ..PreparedName
    Set tStatus = ..Act(..#NODESCREEN, "delete", ..Ref("""t"""), , , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type, 1: ""), "200|deleted|global-node", "the delete is answered with its verb and target")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer), "notFound", "and its read-back finds the node gone")
    Do $$$AssertEquals($Data(@tRoot@("t")) _ "|" _ $Data(@tRoot@("t", 1)) _ "|" _ $Data(@tRoot@(1)), "0|0|1", "the node and its descendants are gone and a sibling is not")
    Set tStatus = ..Act(..#NODESCREEN, "delete", ..Ref("""t"""), , , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "404 GLOBAL.NODE.NOTFOUND", "a node already gone is refused")
    Set tStatus = ..Act(..#NODESCREEN, "delete", "^" _ ..PreparedName _ "($$x())", , , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "400 PORT.VALIDATION", "and text that is not a reference reaches nothing")
}

/// <p>AC2, AD-36. A node's value saved by the screen's action, and the value of a node it kills, reach no stored row and no log line: after both, the
/// value is in no node of OcuPilot's own database or the audit database, and in none of the lines <code>messages.log</code> gained.</p>
/// <p>Mutation (Rule 19): log the new value in <method>OcuPilot.Screen.Tool.ExplorerGlobalNodeSave.PortQuery</method> -> the log assertion goes red.</p>
Method TestANodesValueReachesNoStoreAndNoLog()
{
    Do ..Make()
    Set tRoot = "^" _ ..PreparedName
    Set tMarker = "ZZOcuSecret" _ $Job _ $Random(1000000)
    Set tLog = $System.Util.ManagerDirectory() _ "messages.log"
    Set tLogSize = ##class(%File).GetFileSize(tLog)
    Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(1), {"Value": (tMarker), "Was": "v1"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ @tRoot@(1), "200|" _ tMarker, "the edit is written")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() '[ tMarker), "and its answer carries no value")
    Set @tRoot@("m") = tMarker
    Set tStatus = ..Act(..#NODESCREEN, "delete", ..Ref("""m"""), , , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Data(@tRoot@("m")), "200|0", "a node holding the value is killed")
    For tDatabase = ##class(OcuPilot.Kernel.State.Base).#DATABASENAME, "IRISAUDIT" {
        Do $$$AssertEquals(..Holding(tDatabase, tMarker), "", "the value is in no node of " _ tDatabase)
    }
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Do tStream.LinkToFile(tLog)
    Do tStream.MoveTo(tLogSize + 1)
    Set tFound = 0
    While 'tStream.AtEnd {
        If tStream.ReadLine() [ tMarker Set tFound = 1
    }
    Do $$$AssertTrue('tFound, "and in no line messages.log gained")
}

/// <p>The first node of database <var>pDatabase</var> whose reference or value holds <var>pText</var>, or <code>""</code>.</p>
ClassMethod Holding(pDatabase As %String, pText As %String) As %String
{
    Set tFound = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDirectory = ##class(Config.Databases).Open(pDatabase).Directory
        Set tRS = ##class(%ResultSet).%New("%SYS.GlobalQuery:DirectoryList")
        Do tRS.Execute(tDirectory, "", "*", 1)
        While (tFound = "") && tRS.Next() {
            Set tRef = "^|""^^" _ tDirectory _ """|" _ tRS.Get("Name")
            If $Get(@tRef) [ pText Set tFound = tRef
            For {
                Quit:tFound'=""
                Set tRef = $Query(@tRef)
                Quit:tRef=""
                ; A $List keeps a plain-text element's characters as they are, so one containment test reads both forms.
                If (tRef [ pText) || ($Get(@tRef) [ pText) Set tFound = tRef
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFound = "(could not be read: " _ ex.Name _ ")"
    }
    Quit tFound
}

/// <p>AC4 (global). A whole global deleted by the screen's action is gone, and the agent's proposal to delete it is refused by governance while its key ships
/// disabled; with the key enabled it is minted as a destructive proposal naming the global, confirmed, and the global is gone.</p>
/// <p>Mutation (Rule 19): set <code>explorer.globals.delete</code> <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the
/// governance leg goes red.</p>
Method TestAGlobalDeleteWorksOnTheScreenAndForTheAgentOnceItsKeyIsOn()
{
    Do ..Make()
    Set tRoot = "^" _ ..PreparedName
    Set tStatus = ..Act(..#LISTSCREEN, "delete", ..PreparedName, , , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: "") _ "|" _ $Data(@tRoot), "200|deleted|global|" _ ..PreparedName _ "|0", "the screen's delete answers and the global is gone")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer), "notFound", "and its read-back finds the global gone")
    Set tStatus = ..Act(..#LISTSCREEN, "delete", ..PreparedName, , , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "404 GLOBAL.NOTFOUND", "a global that holds nothing is refused as not found")
    Do ..Make()
    Set tSC = ##class(OcuPilot.Kernel.Governance.Gate).Decide(..DELETETOOLNAME(), "write", $Username, {"Name": (..PreparedName)}, .tDecision)
    Do $$$AssertEquals($Select($$$ISOK(tSC): +$Get(tDecision("allowed")), 1: -1), 0, "with the default baseline governance refuses the agent's proposal")
    Kill tSettings
    Set tSettings("explorer.globals.delete") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is enabled through its stored setting")
    Set tSC = ##class(OcuPilot.Kernel.Governance.Gate).Decide(..DELETETOOLNAME(), "write", $Username, {"Name": (..PreparedName)}, .tDecision)
    Do $$$AssertEquals($Select($$$ISOK(tSC): +$Get(tDecision("allowed")), 1: -1), 1, "with the key on it is allowed")
    Set ^||OcuPilotDatabaseWritePort = $Parameter(..#DELETETOOL, "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, ..PreparedName, {"Name": (..PreparedName)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.id, "global|" _ ..PreparedName, "it names the global")
    Do $$$AssertEquals($Data(@tRoot), 10, "and nothing is deleted by the mint")
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ $Data(@tRoot), "200 |0", "the confirm deletes it: " _ tConfirm)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)), "notFound", "and the confirm's read-back finds it gone")
}

/// <p>The delete tool's name, which the governance decision is asked about.</p>
ClassMethod DELETETOOLNAME() As %String
{
    Quit $Parameter(..#DELETETOOL, "TOOLNAME")
}

/// <p>AC3, AC4. A global of the test's own in <code>USER</code>, a namespace OcuPilot does not run in, is written as one in <code>HSCUSTOM</code> is: an
/// edit whose read-back matches, a node kill and the global's delete, each answered 200. The protected-location lookup never takes the request's
/// namespace for the one OcuPilot's own globals are mapped in.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.ProtectedDirectories</method> resolves OcuPilot's own global in <code>USER</code>
/// rather than <code>$NAMESPACE</code> -> every row answers 403 <code>PROHIBITED.PROTECTEDGLOBAL</code> and goes red.</p>
Method TestAnOrdinaryGlobalInAnotherNamespaceIsWritten()
{
    Set tRoot = "^|""USER""|" _ ..PreparedName
    Set @tRoot@(1) = "v1"
    Set @tRoot@("t") = "top"
    Set @tRoot@("t", 1) = "a"
    Set tStatus = ..Act(..#NODESCREEN, "save", ..Ref(1), {"Value": "new", "Was": "v1"}, "USER", .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ @tRoot@(1), "200 |new", "an edit in USER is answered 200 and the node holds the new value")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.readBack): tAnswer.readBack.verdict, 1: ""), "matches", "and its read-back matches")
    Set tStatus = ..Act(..#NODESCREEN, "delete", ..Ref("""t"""), , "USER", .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Data(@tRoot@("t")), "200 |0", "a node kill in USER is answered 200 and takes everything below the node")
    Set tStatus = ..Act(..#LISTSCREEN, "delete", ..PreparedName, , "USER", .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Data(@tRoot), "200 |0", "the global's delete in USER is answered 200 and the global is gone")
}

/// <p>AC5. The kernel's globals arm, asked about a global stored where a test says (<class>OcuPilot.Test.GlobalLocationSeam</class>), refuses before any
/// write: a name that begins with an OcuPilot stem in any case, a value edit of a node stored in OcuPilot's own database or a system database, a kill of a
/// node or a global any of whose mapping rows is stored in one, and a code global stored in the install namespace's routines database written whole, at a
/// node whose first subscript begins with an own stem, or anywhere in a nested one. A global stored where it is not protected is permitted, and a read that
/// fails refuses.</p>
/// <p>Mutation (Rule 19): drop the own-stem check from <method>OcuPilot.Kernel.Proposal.Prohibited.Global</method> -> the stem rows go red; drop the
/// directory comparison -> the directory rows go red.</p>
Method TestTheArmRefusesOwnAndProtectedGlobalsBeforeAnyWrite()
{
    Set tHome = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE), "^", 2)
    Set tOwn = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^OcuPilotTurnSignal"), "^", 2)
    Set tSystem = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^%ZZNever"), "^", 2)
    Set tUser = $Piece(##class(%SYS.Namespace).GetGlobalDest("USER"), "^", 2)
    Do $$$AssertTrue((tHome '= "") && (tOwn '= "") && (tSystem '= "") && (tUser '= "") && (tOwn '= tHome) && (tSystem '= tHome), "the directories the cases name are distinct: " _ tHome _ " " _ tOwn _ " " _ tSystem)
    Set tRefused = "1 PROHIBITED.PROTECTEDGLOBAL"
    Set tCode = "1 PROHIBITED.OCUPILOTCODE"
    Set tPermitted = "0 "
    Set tDelete = "explorer.globals.delete"
    Set tSave = "explorer.globalnodes.save"
    Set tKill = "explorer.globalnodes.delete"
    For tCase = $ListBuild($ListBuild(tHome), tDelete, "global", "ZZOcuGlbX", tPermitted, "a global stored in the install namespace's database is permitted"), $ListBuild($ListBuild(tHome), tDelete, "global", "ocupilotZ", tRefused, "a name beginning with ocupilot is refused, lower-case"), $ListBuild($ListBuild(tHome), tDelete, "global", "OCUPILOTZ", tRefused, "and upper-case"), $ListBuild($ListBuild(tHome), tDelete, "global", "OcuPilotZ", tRefused, "and mixed"), $ListBuild($ListBuild(tHome), tSave, "global-node", "^ocupilotZ(1)", tRefused, "a node of such a global is refused for an edit"), $ListBuild($ListBuild(tHome), tKill, "global-node", "^OcuPilotZ(1)", tRefused, "and for a kill"), $ListBuild($ListBuild(tHome, tOwn), tDelete, "global", "ZZOcuGlbX", tRefused, "a global any of whose mapping rows is stored in OcuPilot's database is refused a delete"), $ListBuild($ListBuild(tHome, tSystem), tDelete, "global", "ZZOcuGlbX", tRefused, "and one with a row in a system database"), $ListBuild($ListBuild(tOwn), tSave, "global-node", "^ZZOcuGlbX(1)", tRefused, "a node stored in OcuPilot's database is refused an edit"), $ListBuild($ListBuild(tSystem), tSave, "global-node", "^ZZOcuGlbX(1)", tRefused, "and one stored in a system database"), $ListBuild($ListBuild(tHome), tSave, "global-node", "^ZZOcuGlbX(1)", tPermitted, "a node stored in the install namespace's database is permitted an edit"), $ListBuild($ListBuild(tHome, tSystem), tKill, "global-node", "^ZZOcuGlbX(1)", tRefused, "a node kill reads every mapping row of its global"), $ListBuild($ListBuild(tHome), tKill, "global-node", "^ZZOcuGlbX(1)", tPermitted, "and is permitted where none is protected") {
        Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($List(tCase, 1))
        Do $$$AssertEquals(..Arm($List(tCase, 2), $List(tCase, 3), $List(tCase, 4)), $List(tCase, 5), $List(tCase, 6) _ ": " _ $List(tCase, 4))
    }
    For tCase = $ListBuild(tDelete, "global", "oddDEF", tCode, "a code global is refused whole"), $ListBuild(tKill, "global-node", "^oddDEF(""OcuPilot.Api.Router"")", tCode, "and at a node whose first subscript is OcuPilot's"), $ListBuild(tKill, "global-node", "^oddDEF(""ocupilot.api.router"")", tCode, "in any case"), $ListBuild(tKill, "global-node", "^oddDEF(""User.Thing"")", tPermitted, "a node of another package is permitted"), $ListBuild(tKill, "global-node", "^oddDEP(""User.Thing"",1)", tCode, "any node of a nested code global is refused"), $ListBuild(tSave, "global-node", "^rOBJ(""OcuPilot.Api.Router"")", tCode, "an edit of an own routine's node is refused"), $ListBuild(tSave, "global-node", "^rOBJ(""User.Thing"")", tPermitted, "and of another's permitted") {
        Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($ListBuild(tHome))
        Do $$$AssertEquals(..Arm($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)), $List(tCase, 4), $List(tCase, 5) _ ": " _ $List(tCase, 3))
    }
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($ListBuild(tUser))
    Do $$$AssertEquals(..Arm(tDelete, "global", "oddDEF"), tPermitted, "a code global stored in another namespace's own database is not the install namespace's code")
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($ListBuild(tHome), 1)
    Do $$$AssertEquals(..Arm(tDelete, "global", "ZZOcuGlbX"), "error", "a read that fails refuses the write")
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Reset()
}

/// <p>AC5, on both callers. A global of the instance's own that no caller may write -- <code>^oddDEF</code> in <code>USER</code>, whose class dictionary lives in a
/// system database -- is refused <code>PROHIBITED.PROTECTEDGLOBAL</code> with the published sentence before any write: a node edited and a node killed by the screen,
/// and the whole global's delete by the screen and by the agent's confirmed proposal with its key on. Nothing of it is changed.</p>
/// <p>Mutation (Rule 19): drop the directory comparison in <method>OcuPilot.Kernel.Proposal.Prohibited.Global</method> -> every leg goes red.</p>
Method TestTheInstancesProtectedGlobalIsRefusedOnBothCallers()
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "USER"
    Set tNode = $Query(^oddDEF)
    Set tBefore = $Data(^oddDEF) _ "|" _ $Get(@tNode)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tNode '= "", "USER holds a node of oddDEF: " _ tNode)
    Set tLibrary = $Piece(##class(%SYS.Namespace).GetGlobalDest("USER", "^%qZZOcuGlb"), "^", 2)
    Set tStored = $Piece(##class(%SYS.Namespace).GetGlobalDest("USER", "^oddDEF", ##class(OcuPilot.Port.GlobalPort).SubscriptText(tNode)), "^", 2)
    Do $$$AssertTrue((tStored '= "") && (tStored = tLibrary), "that node is stored in the read-only system library, so a regressed arm meets the instance's own refusal: " _ tStored)
    If (tStored = "") || (tStored '= tLibrary) Quit
    Set tSentence = ##class(OcuPilot.Kernel.Proposal.Prohibited).#PROTECTEDGLOBALREASON
    Set tStatus = ..Act(..#NODESCREEN, "save", tNode, {"Value": "x", "Was": ($Piece(..ReadIn("USER", tNode), "|", 1))}, "USER", .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "403 PROHIBITED.PROTECTEDGLOBAL|" _ tSentence, "an edit of its node is refused with the published sentence")
    Set tStatus = ..Act(..#NODESCREEN, "delete", tNode, , "USER", .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "403 PROHIBITED.PROTECTEDGLOBAL", "and so is a kill of its node")
    Set tStatus = ..Act(..#LISTSCREEN, "delete", "oddDEF", , "USER", .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "403 PROHIBITED.PROTECTEDGLOBAL", "and the screen's delete of the whole global")
    Kill tSettings
    Set tSettings("explorer.globals.delete") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the agent's key is on")
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set ^||OcuPilotDatabaseWritePort = $Parameter(..#DELETETOOL, "PORTCLASS")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, "oddDEF", {"Name": "oddDEF"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's proposal is minted: " _ $Get(tProblem))
    If $IsObject($Get(tProposal)) {
        Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
        Do $$$AssertEquals(tConfirm, "403 PROHIBITED.PROTECTEDGLOBAL", "and refused at its confirm")
    }
    Set $NAMESPACE = "USER"
    Set tAfter = $Data(^oddDEF) _ "|" _ $Get(@tNode)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tAfter, tBefore, "nothing of it changed")
}

/// <p>The fresh read of node <var>pReference</var> in <var>pNamespace</var> through the port, as <code>Value|Editable</code>.</p>
ClassMethod ReadIn(pNamespace As %String, pReference As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("reference") = pReference
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Node", "GET", .tQuery, "", .tNode, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tNode)): tNode.Value _ "|" _ tNode.Editable, 1: "(" _ tHttp _ ")")
}

/// <p>A write the caller's database refuses is the instance's own refusal: the port answers 403 <code>PORT.ACCESSDENIED</code> for a vendor
/// <code>&lt;PROTECT&gt;</code> on a set, a node kill and a global kill, and logs nothing of the reference (<class>OcuPilot.Test.GlobalProtectSeam</class>).</p>
/// <p>Mutation (Rule 19): drop the <code>&lt;PROTECT&gt;</code> branch of <method>OcuPilot.Port.GlobalPort.Mapped</method> -> the three rows answer 500 and go red.</p>
Method TestAVendorProtectIsAnsweredAsAnAccessRefusal()
{
    Do ..Make()
    For tCase = $ListBuild("Node", "PUT", "reference", ..Ref(1)), $ListBuild("Node", "DELETE", "reference", ..Ref(1)), $ListBuild("Globals", "DELETE", "name", ..PreparedName) {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery($List(tCase, 3)) = $List(tCase, 4)
        If $List(tCase, 2) = "PUT" Set tQuery("value") = "x"
        Set tSC = ##class(OcuPilot.Test.GlobalProtectSeam).Invoke($List(tCase, 1), $List(tCase, 2), .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403|PORT.ACCESSDENIED", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is answered as an access refusal")
    }
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertEquals($Data(@tRoot) _ "|" _ @tRoot@(1), "10|v1", "and nothing is written")
}

/// <p>AC6 (DW-2607). An import is judged by the global documents its reviewed file names, after its code: a code global or a <code>%</code>-global, in any case of
/// the extension, is <code>PROHIBITED.PROTECTEDGLOBAL</code>, and a global whose name begins with an OcuPilot stem, in any case, is refused by the code arm before it; an ordinary global of the namespace, or a file naming classes alone, is not refused by this clause;
/// a code global is refused although its file also names ordinary documents; and a read that fails refuses.</p>
/// <p>Mutation (Rule 19): drop the <code>.gbl</code> clause from the import branch of <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -> the
/// refused rows go red.</p>
Method TestAnImportIsJudgedByTheGlobalsItNames()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("class", ..#NAMESPACE, "import", .tImportRef), "the import's target key is built")
    For tCase = $ListBuild("oddDEP.gbl new", "1 PROHIBITED.PROTECTEDGLOBAL"), $ListBuild("%ZZOcuGlb.gbl new", "1 PROHIBITED.PROTECTEDGLOBAL"), $ListBuild("ZZOcuGlb.gbl new", "0 "), $ListBuild("ZZOcuGlb.GBL replaces 2026-11-15 10:00:00.5", "0 "), $ListBuild("oddDEF.GBL new", "1 PROHIBITED.PROTECTEDGLOBAL"), $ListBuild("Foo.Bar.cls new, ZZOcuGlb.gbl new", "0 "), $ListBuild("Foo.Bar.cls new, oddDEP.gbl new", "1 PROHIBITED.PROTECTEDGLOBAL"), $ListBuild("Foo.Bar.cls new", "0 "), $ListBuild("ocupilotZZOcuGlb.gbl new", "1 PROHIBITED.OCUPILOTCODE") {
        Set tPayload = {}
        Do tPayload.%Set("documents", $List(tCase, 1), "string")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("explorer.classes.import", tImportRef, tPayload.%ToJSON(), "[]", .tProhibits, .tCode)
        Do $$$AssertEquals($Select($$$ISOK(tSC): tProhibits _ " " _ tCode, 1: "error"), $List(tCase, 2), $List(tCase, 1))
    }
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($ListBuild(""), 1)
    Set tSC = ##class(OcuPilot.Test.GlobalProhibited).Prohibits("explorer.classes.import", tImportRef, {"documents": "ZZOcuGlb.gbl new"}.%ToJSON(), "[]", .tProhibits, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a global whose mapping rows cannot be read refuses the import")
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Reset()
}

}
