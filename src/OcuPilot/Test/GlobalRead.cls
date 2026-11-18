/// <p>Pins Story 21.5's reads (AC1, AC2; AD-21, AD-29, AD-36, AD-39): the Globals list and the agent's read of it answering the same capped rows with no
/// subscript-level mapping row; a node page over the test's own global walked once, in <code>$Query</code> order, by an explicit cursor, with long values and
/// references cut and flagged and no node value reaching a log line; every hostile reference and cursor refused 400 <code>PORT.VALIDATION</code> before
/// anything is read; the port's gate; and the screens' declared shape.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, and a
/// <code>USER</code> namespace. Each test makes its own global <code>^ZZOcuGlb&lt;pid&gt;</code> in <code>HSCUSTOM</code> and kills it.</p>
Class OcuPilot.Test.GlobalRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.GlobalPort";

Parameter LISTSCREEN = "OcuPilot.Screen.Descriptor.ExplorerGlobalList";

Parameter VIEWSCREEN = "OcuPilot.Screen.Descriptor.ExplorerGlobalView";

Parameter NAMESPACE = "HSCUSTOM";

Parameter ROUTE = "/explorer/globals/nodes";

/// <p>The name of the test's own global, without <code>^</code>.</p>
Property PreparedName As %String;

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
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Remove()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Kill the test's global.</p>
Method Remove()
{
    Set tRoot = "^" _ ..PreparedName
    Kill @tRoot
}

/// <p>The test's global: 49 numbered nodes, one whose reference is longer than a display holds (a subscript of 495 quotation marks, which the reference
/// spells doubled; a subscript holds 511 characters with the name), five more after it, and a few of the shapes the page flags: a value over a display's length, a <code>$ListBuild</code> value, a node with a node below it and a node holding only nodes below it.</p>
Method Make()
{
    Set tRoot = "^" _ ..PreparedName
    For tI = 1:1:49 Set @tRoot@(tI) = "v" _ tI
    Set @tRoot@($Translate($Justify("", 495), " ", $Char(34))) = "far"
    For tI = 1:1:5 Set @tRoot@("z" _ tI) = "w" _ tI
    Set @tRoot@("zbig") = $Translate($Justify("", 2000), " ", "x")
    Set @tRoot@("zlist") = $ListBuild(1, 2)
    Set @tRoot@("zup") = "top"
    Set @tRoot@("zup", 1) = "below"
    Set @tRoot@("zonly", 1) = "deep"
}

/// <p>The nodes of the test's global that hold a value, in <code>$Query</code> order, as a <code>%List</code> of references.</p>
Method Expected() As %List
{
    Set tList = ""
    Set tRoot = "^" _ ..PreparedName
    Set tNext = $Query(@tRoot)
    While tNext '= "" {
        Set tList = tList _ $ListBuild(tNext)
        Set tNext = $Query(@tNext)
    }
    Quit tList
}

/// <p><code>POST /explorer/globals/nodes</code> with <var>pBody</var>, as the suite's account: the HTTP status and the answer.</p>
ClassMethod Post(pBody As %DynamicObject, Output pAnswer As %DynamicObject) As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ROUTE, .tStatus, .pAnswer, pBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The descriptor declaration of <var>pClass</var>.</p>
ClassMethod Declaration(pClass As %String) As %DynamicObject
{
    Do $ClassMethod(pClass, "DeclarationJson", .tDeclaration)
    Quit tDeclaration
}

/// <p>The two screens declare the shape the story rules: the list a server-criteria list of globals at the next free System Explorer position, whose read
/// is the global source with the two criteria and whose one row action is <code>delete</code>; the node page a form with no declared read, off the side
/// bar, whose actions are <code>save</code> and <code>delete</code>.</p>
/// <p>Mutation (Rule 19): change the list's source port to <code>atelier</code> -> the source assertion goes red.</p>
Method TestTheScreensDeclareTheirShape()
{
    Set tList = ..Declaration(..#LISTSCREEN)
    Set tView = ..Declaration(..#VIEWSCREEN)
    Do $$$AssertEquals(tList.route _ "|" _ tList.sideBarPosition _ "|" _ tList.entityType _ "|" _ tList.scope _ "|" _ tList.toolIdentifier, "system-explorer/globals|15|global|namespace|explorer.globals", "the list's route, position, entity type, scope and identifier")
    Do $$$AssertEquals(tList.read.source.port _ "|" _ tList.read.source.endpoint _ "|" _ tList.read.source.type, "global|Globals|LIST", "its read is the global source's list")
    Set tParams = ""
    Set tIterator = tList.read.criteria.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tParams = tParams _ $Select(tParams = "": "", 1: ",") _ tField.param _ "=" _ tField.default
    }
    Do $$$AssertEquals(tParams, "pattern=*,system=no", "its criteria are the pattern, default *, and system, default no")
    Set tActions = ""
    Set tIterator = tList.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Do $$$AssertEquals(tActions, "delete,export,export-browser,import,import-local", "its row actions are delete, and the export and import actions Story 21.17 adds")
    Do $$$AssertEquals(tList.classicPage, "%CSP.UI.Portal.GlobalList", "it replaces the classic Globals page")
    Do $$$AssertEquals(tView.route _ "|" _ tView.sideBarPosition _ "|" _ tView.entityType _ "|" _ tView.archetype _ "|" _ tView.toolIdentifier, "system-explorer/globals/document|0|global-node|form-page|explorer.globalnodes", "the node page's route, position, entity type, archetype and identifier")
    Do $$$AssertEquals(tView.%GetTypeOf("read"), "unassigned", "the node page declares no read")
    Do $$$AssertEquals(tView.rowActions.%Get(0).id _ "," _ tView.rowActions.%Get(1).id, "save,delete", "its actions are save and delete")
    Do $$$AssertEquals(tView.classicPage, "%cspapp.exp.utilexpglobalview", "it replaces the classic Global view page")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.globals.read", .tListTool, 1), "the registry resolves")
    Do $$$AssertTrue($IsObject($Get(tListTool)), "and it registers the Globals list's read tool")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.globalnodes.read", .tTool, 1)
    Do $$$AssertTrue('$IsObject($Get(tTool)), "and no read tool of the node page is registered")
}

/// <p>AC1. The screen's read and the agent's read answer the same rows for the same criteria: the test's own global is listed once with the directory it is
/// stored in, and a read in <code>USER</code> of <code>oddDEF</code>, whose subscript-level mappings the instance lists beside it, answers the one global and no
/// row of a mapping. A read capped at one row answers one and says it is truncated.</p>
/// <p>Mutation (Rule 19): drop the <code>(</code> filter in <method>OcuPilot.Port.GlobalPort.VendorList</method> -> the subscript-row assertions go red.</p>
Method TestTheListAndTheAgentsReadAnswerTheSameRowsWithNoMappingRow()
{
    Do ..Make()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Kill tCriteria
    Set tCriteria("pattern") = ..PreparedName
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LISTSCREEN, "", .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the read answers (" _ $Get(tHttp) _ ")")
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit
    Set tDirectory = $Piece(##class(%SYS.Namespace).GetGlobalDest(..#NAMESPACE, "^" _ ..PreparedName), "^", 2)
    Do $$$AssertEquals(tResult.rows.%Size() _ "|" _ tResult.rows.%Get(0).Name _ "|" _ tResult.rows.%Get(0).Database, "1|" _ ..PreparedName _ "|" _ tDirectory, "the test's global is listed once, with the directory it is stored in")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#LISTSCREEN, {"pattern": (..PreparedName)}, 100, .tView, .tToolHttp, .tToolFault)
    Do $$$AssertStatusOK(tSC, "the agent's read answers (" _ $Get(tToolHttp) _ ")")
    If $IsObject($Get(tView)) Do $$$AssertEquals(tView.rows.%Size() _ "|" _ tView.rows.%Get(0).Name, "1|" _ ..PreparedName, "and answers the same row")
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tRaw = ..VendorRowNames("USER", "oddDEF")
    Do $$$AssertTrue(tRaw [ "(", "the instance lists subscript-level rows of oddDEF in USER: " _ $Extract(tRaw, 1, 120))
    Kill tCriteria
    Set tCriteria("pattern") = "oddDEF"
    Set tCriteria("system") = "yes"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LISTSCREEN, "", .tScreen, .tHttp, .tFault, .tCriteria)
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#LISTSCREEN, {"pattern": "oddDEF", "system": "yes"}, 100, .tAgent, .tToolHttp, .tToolFault)
    Set tScreenNames = ..Names(tScreen)
    Set tAgentNames = ..Names(tAgent)
    Do $$$AssertEquals(tScreenNames, "oddDEF", "the screen lists the global and no row of a subscript-level mapping")
    Do $$$AssertEquals(tAgentNames, tScreenNames, "and the agent's read answers the same names")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Kill tCriteria
    Set tCriteria("pattern") = "*"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LISTSCREEN, 1, .tCapped, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals($Select($IsObject($Get(tCapped)): tCapped.rows.%Size() _ "|" _ tCapped.truncated, 1: "none"), "1|1", "a read capped at one row answers one and says it is truncated")
}

/// <p>The names of the rows <var>pResult</var> answers, comma-joined.</p>
ClassMethod Names(pResult As %DynamicObject) As %String
{
    Set tNames = ""
    If '$IsObject(pResult) Quit "(none)"
    Set tIterator = pResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Name
    }
    Quit tNames
}

/// <p>The names the vendor's own list answers for <var>pPattern</var> in <var>pNamespace</var>, system globals shown, comma-joined: the baseline the
/// screen's rows are held against.</p>
ClassMethod VendorRowNames(pNamespace As %String, pPattern As %String) As %String
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%ResultSet).%New("%SYS.GlobalQuery:NameSpaceList")
        Do tRS.Execute(pNamespace, pPattern, 1, , , 1)
        While tRS.Next() {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRS.Get("Name")
        }
    } Catch {
        Set tNames = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>AC2. A node page walked by its cursor holds every node once, in <code>$Query</code> order: the pages of fifty rows chain by <code>next</code>, the
/// first ends with the node whose reference is longer than a display, cut and flagged and not editable, its cursor naming it whole; a value over a display's
/// length is cut and flagged, and a <code>$ListBuild</code> value is shown as the vendor shows it and is not editable; a node with a node below it says
/// so, and a node holding only nodes below it is not a row.</p>
/// <p>Mutation (Rule 19): make the cursor inclusive (start the walk at the cursor itself) in <method>OcuPilot.Port.GlobalPort.VendorWalk</method> -> the
/// once-each assertion goes red.</p>
Method TestAPageWalksTheGlobalOnceInOrderWithLongValuesCut()
{
    Do ..Make()
    Set tExpected = ..Expected()
    Set tSeen = ""
    Set tAfter = ""
    Set tPages = 0
    Set tCuts = 0
    Set tEditable = ""
    Set tBelow = ""
    For {
        Set tBody = {"global": (..PreparedName), "pageSize": 50}
        If tAfter '= "" Do tBody.%Set("after", tAfter, "string")
        Set tStatus = ..Post(tBody, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, "page " _ (tPages + 1) _ " answers")
        If (tStatus '= 200) || '$IsObject(tAnswer) Quit
        Set tPages = tPages + 1
        Set tIterator = tAnswer.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tSeen = tSeen _ $ListBuild(tRow.reference)
            If tRow.cut Set tCuts = tCuts + 1
            If tRow.editable Set tEditable = tEditable _ $ListBuild(tRow.reference)
            If tRow.below Set tBelow = tBelow _ $ListBuild(tRow.reference)
        }
        If tAnswer.next = "" Quit
        Set tAfter = tAnswer.next
        If tPages > 5 Quit
    }
    Do $$$AssertEquals($ListLength(tSeen), $ListLength(tExpected), "every node holding a value appears")
    Set tSame = 1
    For tI = 1:1:$ListLength(tExpected) {
        Set tWant = $List(tExpected, tI)
        If $List(tSeen, tI) '= $Extract(tWant, 1, 1000) Set tSame = 0
    }
    Do $$$AssertTrue(tSame, "each once, in $Query order (the long reference shown cut at 1,000 characters)")
    Do $$$AssertEquals(tPages, 2, "the 60 nodes took two pages of at most fifty")
    Do $$$AssertEquals(tCuts, 2, "exactly the long reference and the long value are flagged cut")
    Set tRoot = "^" _ ..PreparedName
    Do $$$AssertTrue($ListFind(tEditable, tRoot _ "(1)") && '$ListFind(tEditable, tRoot _ "(""zbig"")") && '$ListFind(tEditable, tRoot _ "(""zlist"")"), "a plain value is editable, a long one and a $ListBuild value are not")
    Do $$$AssertTrue($ListFind(tBelow, tRoot _ "(""zup"")") && '$ListFind(tBelow, tRoot _ "(1)") && '$ListFind(tSeen, tRoot _ "(""zonly"")"), "a node with a node below it says so, and one holding only nodes below it is no row")
    Set tStatus = ..Post({"global": (..PreparedName), "pageSize": 100}, .tBig)
    Do $$$AssertEquals($Select($IsObject(tBig): tBig.rows.%Size() _ "|" _ tBig.next, 1: tStatus), "60|", "one page of a hundred holds all 60 and no cursor")
    Set tBigValue = ""
    If $IsObject(tBig) {
        Set tIterator = tBig.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.reference = (tRoot _ "(""zbig"")") Set tBigValue = tRow.value
        }
    }
    Do $$$AssertEquals($Length(tBigValue), 1000, "a long value is shown cut at 1,000 characters")
}

/// <p>AC2. A page starts at the global's first node, at a start node that holds a value (included) or does not (the next node), or after a cursor
/// (excluded); the page size is 50 to 500; and no node page of a failing walk logs a node value: the port's log line carries the exception's name alone.</p>
/// <p>Mutation (Rule 19): log the exception's text in <method>OcuPilot.Port.GlobalPort.Mapped</method> for a page, or drop the quiet flag of
/// <method>OcuPilot.Port.GlobalPort.NodeState</method>'s call -> the matching log assertion goes red.</p>
Method TestAPageStartsWhereItIsToldAndLogsNoValue()
{
    Do ..Make()
    Set tRoot = "^" _ ..PreparedName
    Set tStatus = ..Post({"global": (..PreparedName), "start": (tRoot _ "(7)"), "pageSize": 50}, .tFrom)
    Do $$$AssertEquals($Select($IsObject(tFrom): tFrom.rows.%Get(0).reference, 1: tStatus), tRoot _ "(7)", "a start node holding a value is the first row")
    Set tStatus = ..Post({"global": ("^" _ ..PreparedName), "start": (tRoot _ "(""zonly"")"), "pageSize": 50}, .tGap)
    Do $$$AssertEquals($Select($IsObject(tGap): tGap.rows.%Get(0).reference, 1: tStatus), tRoot _ "(""zonly"",1)", "a start node holding none begins at the next node, and the name may carry its ^")
    Set tStatus = ..Post({"global": (..PreparedName), "after": (tRoot _ "(7)"), "pageSize": 50}, .tAfter)
    Do $$$AssertEquals($Select($IsObject(tAfter): tAfter.rows.%Get(0).reference, 1: tStatus), tRoot _ "(8)", "a cursor's node is excluded")
    For tSize = 49, 501, 0, "50", 1.5 {
        Set tBody = {"global": (..PreparedName)}
        Do tBody.%Set("pageSize", tSize, $Select(tSize = "50": "string", 1: "number"))
        Set tStatus = ..Post(tBody, .tBad)
        Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tBad): tBad.code, 1: ""), "400|PORT.VALIDATION", "a page size of " _ tSize _ " is refused")
    }
    Do ##class(OcuPilot.Test.GlobalSeamPort).Reset()
    Set tRequest = {"global": (..PreparedName), "start": "", "after": "", "pageSize": 50}
    Set tSC = ##class(OcuPilot.Test.GlobalSeamPort).Page(..#NAMESPACE, tRequest, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "500|INTERNAL", "a walk that fails answers the generic fault")
    Set tLogged = ##class(OcuPilot.Test.GlobalSeamPort).Logged()
    Do $$$AssertTrue((tLogged [ "UNDEFINED") && (tLogged '[ ##class(OcuPilot.Test.GlobalSeamPort).#SECRET), "and the log line names the exception and carries no node text: " _ tLogged)
    Do ##class(OcuPilot.Test.GlobalSeamPort).Reset()
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("reference") = tRoot _ "(7)"
    Set tSC = ##class(OcuPilot.Test.GlobalSeamPort).Invoke("Node", "GET", .tQuery, "", .tNode, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "500|INTERNAL", "a node read that fails answers the generic fault")
    Set tLogged = ##class(OcuPilot.Test.GlobalSeamPort).Logged()
    Do $$$AssertTrue((tLogged [ "UNDEFINED") && (tLogged '[ ##class(OcuPilot.Test.GlobalSeamPort).#SECRET), "and its log line carries no node text either: " _ tLogged)
    For tType = "PUT", "DELETE" {
        Do ##class(OcuPilot.Test.GlobalSeamPort).Reset()
        Do ##class(OcuPilot.Test.GlobalSeamPort).ArmWrites()
        Kill tQuery("value")
        If tType = "PUT" Set tQuery("value") = "x"
        Set tSC = ##class(OcuPilot.Test.GlobalSeamPort).Invoke("Node", tType, .tQuery, "", .tNode, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "500|INTERNAL", "a node " _ tType _ " that fails answers the generic fault")
        Set tLogged = ##class(OcuPilot.Test.GlobalSeamPort).Logged()
        Do $$$AssertTrue((tLogged [ "UNDEFINED") && (tLogged '[ ##class(OcuPilot.Test.GlobalSeamPort).#SECRET), "and its log line carries no node text: " _ tLogged)
    }
    Do ##class(OcuPilot.Test.GlobalSeamPort).Reset()
}

/// <p>AD-21. Every text that is not a canonical reference of a global is refused 400 <code>PORT.VALIDATION</code> as a node reference and as a cursor, before
/// anything is read: a function call, an operator, an environment, an unmatched quote, a local, an indirection, a name that is too long, a non-canonical
/// number, spaces, and an empty subscript list. The canonical spellings the instance writes parse and rebuild equal.</p>
/// <p>Mutation (Rule 19): drop the rebuilt-equals-given check in <method>OcuPilot.Port.GlobalPort.ParseReference</method> -> the environment and
/// non-canonical rows go red.</p>
Method TestEveryHostileTextIsRefusedBeforeAnythingIsRead()
{
    Do ..Make()
    Set tName = ..PreparedName
    For tText = "^G($$x())", "^G(1)_x", "^|""%SYS""|G", "^G(""a)", "G(1)", "^G(@x)", "^G(x)", "^G(1E2)", "^G(01)", "^G( 1 )", "^[""dir""]G(1)", "^G(1", "^" _ tName _ "(1)_x", "^" _ tName _ "(""a"")(2)", "^" _ $Translate($Justify("", 40), " ", "A"), "^", "", "^" _ tName _ "(" _ $Char(10) _ ")" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("reference") = tText
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Node", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400|PORT.VALIDATION", "'" _ tText _ "' is refused as a node reference")
        If tText = "" Continue
        ; The cursor names the page's own global, so only the parse can refuse it.
        Set tCursor = $Replace($Replace(tText, "|G", "|" _ tName), "G(", tName _ "(")
        Set tBody = {"global": (tName), "after": (tCursor), "pageSize": 50}
        Set tStatus = ..Post(tBody, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.code, 1: ""), "400|PORT.VALIDATION", "and as a cursor (an empty cursor is none)")
    }
    For tText = "^" _ tName, "^" _ tName _ "(1)", "^" _ tName _ "(""a"")", "^" _ tName _ "(1,""a b"",-3.5)", "^" _ tName _ "(""q""""r"")" {
        Do $$$AssertTrue($ClassMethod(..#PORT, "ParseReference", tText, .tParsed, .tRebuilt) && (tRebuilt = tText) && (tParsed = tName), "'" _ tText _ "' parses and rebuilds equal")
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "ParseReference", "^" _ tName _ "(1,2", .tParsed), "an unbalanced list does not parse")
    Do $$$AssertTrue('$ClassMethod(..#PORT, "PageRequest", {"global": (tName), "start": ("^" _ tName _ "(1)"), "after": ("^" _ tName _ "(2)")}, .tRequest), "a request holding a start and a cursor is refused")
    Do $$$AssertTrue('$ClassMethod(..#PORT, "PageRequest", {"global": (tName), "stray": 1}, .tRequest), "and so is one holding a key the page does not take")
    Do $$$AssertTrue('$ClassMethod(..#PORT, "PageRequest", {"global": "^Other", "after": ("^" _ tName _ "(2)")}, .tRequest), "and a cursor of another global")
}

/// <p>AD-29. The port's gate comes first, in order: a caller without the screen's pair is refused naming it before the namespace is read, one holding it but
/// not READ on the namespace's database is refused naming that pair, and a caller holding both reads. The route answers the page only to a caller who holds the
/// node page's pairs, and a global name or a cap of the wrong shape is refused before the vendor is called.</p>
/// <p>Mutation (Rule 19): drop the namespace's pairs from <method>OcuPilot.Port.GlobalPort.Admit</method> -> the second leg goes red.</p>
Method TestThePortGateComesFirst()
{
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(..#NAMESPACE)
    Do $$$AssertTrue(tPairs '= "", "the install namespace names its databases' pairs")
    Set tFirst = $List($List(tPairs, 1), 1) _ ":" _ $List($List(tPairs, 1), 2)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tSC = ##class(OcuPilot.Test.GlobalGateSeam).Invoke("Globals", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.detail.failedPair, 1: ""), "403|AUTH.NOPRIVILEGE|%Development:USE", "a caller holding nothing is refused naming %Development:USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tSC = ##class(OcuPilot.Test.GlobalGateSeam).Invoke("Globals", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.detail.failedPair, 1: ""), "403|" _ tFirst, "one holding it alone is refused naming the namespace's first pair")
    For tI = 1:1:$ListLength(tPairs) {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tPairs, tI), 1), $List($List(tPairs, tI), 2))
    }
    Set tQuery("maxRows") = "1"
    Set tQuery("pattern") = "ZZOcuNever"
    Set tSC = ##class(OcuPilot.Test.GlobalGateSeam).Invoke("Globals", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|0", "one holding both reads")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    For tCase = $ListBuild("maxRows", "0"), $ListBuild("maxRows", "x"), $ListBuild("pattern", "a;b"), $ListBuild("system", "maybe") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery($List(tCase, 1)) = $List(tCase, 2)
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400|PORT.VALIDATION", $List(tCase, 1) _ "=" _ $List(tCase, 2) _ " is refused")
    }
    Kill tQuery
    Set tQuery("namespace") = "no namespace"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a namespace of the wrong shape is refused")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = "^Bad"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "and a global name carrying a ^ at the port")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Globals", "PUT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 501, "an endpoint serves only its own request types")
}

/// <p>The route <code>POST /explorer/globals/nodes</code> answers JSON over the wire: 200 with the page's three members, a refusal in the one envelope with
/// its code and the published reason, and 401 for a request with no credentials, before anything is read.</p>
/// <p>Mutation (Rule 19): answer the page's <code>next</code> under another name in <method>OcuPilot.Port.GlobalPort.Page</method> -> the members assertion
/// goes red.</p>
Method TestTheNodeRouteAnswersJsonOverTheWire()
{
    Do ..Make()
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ROUTE
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBody = {"global": (..PreparedName), "pageSize": 50}.%ToJSON()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, tUser, tPassword, .tStatus, .tRaw, .tHeaders, tBody)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tAnswer), "cut,next,rows", "its body is the page's three members")
    Do $$$AssertEquals(tAnswer.rows.%Size(), 50, "and fifty rows")
    Set tBody = {"global": (..PreparedName), "after": "^G(01)"}.%ToJSON()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, tUser, tPassword, .tStatus, .tRaw, .tHeaders, tBody)
    Do $$$AssertEquals(tStatus, 400, "a cursor that is not canonical is 400: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "in the JSON envelope")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tRefusal.code _ "|" _ tRefusal.reason, "PORT.VALIDATION|" _ ##class(OcuPilot.Port.GlobalPort).#REASONPAGE, "carrying the code and the port's reason")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, "", "", .tStatus, .tRaw, .tHeaders, tBody)
    Do $$$AssertEquals(tStatus, 401, "a request with no credentials is refused before any read")
}

}
