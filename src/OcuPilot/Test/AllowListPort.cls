/// <p>Story 18.42's port (AD-21's tenth case, AD-29, AD-51, AD-15): <class>OcuPilot.Port.AllowListPort</class> adds, changes
/// and removes entries of the <code>%GUIFileSelector</code> allow-list through the real <code>FSAccess</code> endpoints,
/// every row of the matrix, the order of the vendor calls each sends, the refusals that send none, the gate that refuses
/// before any call, the <code>SecurityChange</code> row with the roots before and after, and what the list allows once a
/// remove has emptied it.</p>
/// <p>Each method records the allow-list before it runs and restores it exactly afterwards, failure included, through
/// <class>OcuPilot.Test.PathPortFixture</class>, which also counts and logs the calls the port makes; it creates its three
/// probe directories under the manager directory and removes them. Changing the instance's own allow-list is why
/// <method>OnBeforeAllTests</method> refuses unless <parameter>ARMINGVARIABLE</parameter> arms it. Needs OcuPilot installed
/// in the namespace it runs in and a process holding <code>%All</code>.</p>
Class OcuPilot.Test.AllowListPort Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>. Only
/// <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The port under test, with the seam that counts its calls.</p>
Parameter PORT = "OcuPilot.Test.AllowListPortFixture";

/// <p>The seam's allow-list helpers and the real port that reads the roots back.</p>
Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

Parameter PATHPORT = "OcuPilot.Port.PathPort";

/// <p>The purpose the list is.</p>
Parameter PURPOSE = "%GUIFileSelector";

/// <p>Whether the purpose existed before the method ran. Prefix deliberately not "Test".</p>
Property SavedExists As %Boolean [ InitialExpression = 0 ];

Property SavedRestricted As %Boolean [ InitialExpression = 0 ];

Property SavedPaths As %List;

Property SavedOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = 0
    Set ..SavedRestricted = 0
    Set ..SavedPaths = ""
    Set ..SavedOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AllowListPort changes this instance's %GUIFileSelector allow-list and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $ClassMethod(..#FIXTURE, "Snapshot", .tExists, .tRestricted, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = tExists
    Set ..SavedRestricted = tRestricted
    Set ..SavedPaths = tPaths
    Set ..SavedOk = 1
    For tSuffix = "a", "b", "c" Do ##class(%File).CreateDirectoryChain(..Dir(tSuffix))
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $$$OK
    If ..SavedOk {
        Set ..SavedOk = 0
        Set tSC = $ClassMethod(..#FIXTURE, "Restore", ..SavedExists, ..SavedRestricted, ..SavedPaths)
    }
    For tSuffix = "a", "b", "c" Do ##class(%File).RemoveDirectory(..Dir(tSuffix))
    Quit tSC
}

/// <p>Probe directory <var>pSuffix</var>, normalized, under the manager directory.</p>
ClassMethod Dir(pSuffix As %String) As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory()) _ "ocuprobe1842" _ pSuffix _ "/"
}

/// <p>The manager directory, normalized.</p>
ClassMethod Manager() As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
}

/// <p>One call to the port, the change named by <var>pAction</var>, <var>pDirectory</var> and <var>pNew</var>; the answer's
/// status, row and fault come back. A <var>pPurpose</var> other than the list's is sent as given.</p>
ClassMethod Call(pType As %String, pAction As %String, pDirectory As %String, pNew As %String, Output pHttp As %Integer, Output pRow As %DynamicObject, Output pFault As %DynamicObject, pPurpose As %String = {..#PURPOSE}) As %Status
{
    Kill tQuery
    Set tQuery("purpose") = pPurpose
    If pAction '= "" Set tQuery("Action") = pAction
    If pDirectory '= "" Set tQuery("Directory") = pDirectory
    If pNew '= "" Set tQuery("NewDirectory") = pNew
    Quit $ClassMethod(..#PORT, "Invoke", "AllowList", pType, .tQuery, "", .pRow, .pHttp, .pFault)
}

/// <p>The roots the real <class>OcuPilot.Port.PathPort</class> answers now, as a list, in the vendor's order.</p>
ClassMethod RootsNow() As %List
{
    Set tSC = $ClassMethod(..#PATHPORT, "Roots", 1000, .tRows, .tHttp, .tFault)
    Set tList = ""
    If $$$ISERR(tSC) Quit tList
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tList = tList _ $ListBuild(tRow.%Get("Directory"))
    }
    Quit tList
}

/// <p>The strings of the JSON array <var>pArray</var>, joined with <code>|</code>.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tText = tText _ $Select(tText = "": "", 1: "|") _ tValue
    }
    Quit tText
}

/// <p>The list of directories <var>pList</var> in the order the vendor answers them.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Quit $ListToString($ClassMethod(..#PORT, "Ordered", pList), "|")
}

/// <p>The vendor writes the port has sent since the method began, each as <code>endpoint/type</code> and its root path, in
/// order, as one string.</p>
ClassMethod WriteLog() As %String
{
    Set tText = ""
    Set tLog = $ClassMethod(..#FIXTURE, "Log")
    For tI = 1:1:$ListLength(tLog) {
        Set tEntry = $List(tLog, tI)
        Set tType = $Piece($Piece(tEntry, " ", 1), "/", 2)
        If (tType = "GET") || (tType = "LIST") Continue
        Set tText = tText _ $Select(tText = "": "", 1: "; ") _ $Replace(tEntry, ..Manager(), "<mgr>")
    }
    Quit tText
}

/// <p>The one audit row an accepted write of verb <var>pVerb</var> recorded since <var>pSince</var>, or <code>""</code>.</p>
ClassMethod AuditRow(pSince As %String, pVerb As %String, Output pRows As %Integer) As %DynamicObject
{
    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(pSince, 1, ..#PURPOSE, pVerb, .pRows)
    If pRows '= 1 Quit ""
    Quit ##class(%DynamicAbstractObject).%FromJSON(tData)
}

/// <p>An add to a restricted list sends one <code>Path</code> <code>PUT</code> and nothing else; the roots the real port
/// answers hold the directory at once, the answer says so, and one <code>SecurityChange</code> row records the roots before
/// and after.</p>
/// <p>Mutation (Rule 19): drop the <code>Event.Record</code> call from <method>OcuPilot.Port.AllowListPort.Audit</method> --
/// the audit leg goes red.</p>
Method TestAnAddToARestrictedListSendsOnePutAndRecordsTheRoots()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"))), "the list is restricted to one probe directory")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Call("PUT", "add", ..Dir("b"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusOK(tSC, "the add is accepted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(..WriteLog(), "FSAccess.Path/PUT " _ $Replace(..Dir("b"), ..Manager(), "<mgr>"), "exactly one write: the directory's Path PUT")
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Sorted($ListBuild(..Dir("a"), ..Dir("b"))), "the real roots hold both at once")
    Do $$$AssertEquals(..Joined(tRow.Roots), $ListToString(..RootsNow(), "|"), "and the answer's roots are the roots it left")
    Set tAudit = ..AuditRow(tSince, "added", .tRows)
    Do $$$AssertEquals(tRows, 1, "one SecurityChange row records the add: " _ tRows)
    If tRows = 1 {
        Do $$$AssertEquals(..Joined(tAudit.changes.roots.old), ..Dir("a"), "naming the roots before")
        Do $$$AssertEquals(..Joined(tAudit.changes.roots.new), ..Sorted($ListBuild(..Dir("a"), ..Dir("b"))), "and the roots after")
    }
}

/// <p>An add to an unrestricted list stores the manager directory first (unless it is stored), then the directory, and
/// restricts last, so the roots keep the manager directory and gain the new one. A path the purpose already stores
/// becomes a root with them, and the read's <code>Result</code> names it before the write.</p>
/// <p>Mutation (Rule 19): drop the manager directory's <code>put</code> step from
/// <method>OcuPilot.Port.AllowListPort.Plan</method> -- the keep-root leg goes red.</p>
Method TestAnAddToAnUnrestrictedListKeepsTheManagerDirectoryAndRestrictsLast()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent")
    Set tSC = ..Call("PUT", "add", ..Dir("a"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusOK(tSC, "the add is accepted")
    Do $$$AssertEquals(..WriteLog(), "FSAccess.Path/PUT <mgr>; FSAccess.Path/PUT " _ $Replace(..Dir("a"), ..Manager(), "<mgr>") _ "; FSAccess.Purpose/PUT", "the manager directory, the directory, then the restriction")
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Sorted($ListBuild(..Manager(), ..Dir("a"))), "the roots are the manager directory and the new one")
    Do $$$AssertEquals(tRow.Restricted, 1, "and the list is restricted")

    ; The manager directory stored already, the purpose present and unrestricted: it is not stored again.
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 0, $ListBuild(..Manager())), "the purpose holds the manager directory, unrestricted")
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = ..Call("PUT", "add", ..Dir("b"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusOK(tSC, "the second add is accepted")
    Do $$$AssertEquals(..WriteLog(), "FSAccess.Path/PUT " _ $Replace(..Dir("b"), ..Manager(), "<mgr>") _ "; FSAccess.Purpose/PUT", "the stored manager directory is not stored again")

    ; A path the purpose stores while unrestricted becomes a root with them, and the read names it before the write.
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 0, $ListBuild(..Dir("c"))), "the purpose stores a probe directory, unrestricted")
    Set tSC = ..Call("GET", "add", ..Dir("a"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): ..Joined(tRow.Result), 1: ""), ..Sorted($ListBuild(..Manager(), ..Dir("a"), ..Dir("c"))), "the read's result names the stored directory beside the manager directory and the new one")
    Set tSC = ..Call("PUT", "add", ..Dir("a"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusOK(tSC, "the third add is accepted")
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Sorted($ListBuild(..Manager(), ..Dir("a"), ..Dir("c"))), "and the roots are those three")
}

/// <p>A step that fails stops the sequence before the restriction and the roots stay as they were: a first step that fails
/// stores nothing and records no row, and a restriction that fails after the puts records the paths they stored.</p>
/// <p>Mutation (Rule 19): drop the stored-paths clause from <method>OcuPilot.Port.AllowListPort.Invoke</method>'s audit
/// condition -- the second leg's row count goes red.</p>
Method TestAFailedStepStopsBeforeTheRestrictionAndLeavesTheRoots()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent")
    Do $ClassMethod(..#FIXTURE, "Script", "FSAccess.Path", "PUT", 500)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Call("PUT", "add", ..Dir("a"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the add fails")
    Do $$$AssertEquals(tHttp, 500, "with the vendor's status")
    Do $$$AssertEquals(..WriteLog(), "FSAccess.Path/PUT <mgr>", "it sent the first PUT only, never the restriction")
    Do $ClassMethod(..#FIXTURE, "Reset")
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Manager(), "the roots are the manager directory alone, unrestricted")
    Do $$$AssertEquals(..AuditRow(tSince, "added", .tRows), "", "and no row is recorded")
    Do $$$AssertEquals(tRows, 0, "none at all: " _ tRows)

    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the purpose is absent again")
    Do $ClassMethod(..#FIXTURE, "Script", "FSAccess.Purpose", "PUT", 500)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Call("PUT", "add", ..Dir("a"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a restriction the vendor refuses fails the add")
    Do $ClassMethod(..#FIXTURE, "Reset")
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Manager(), "the roots are still the manager directory alone")
    Do ..AuditRow(tSince, "added", .tRows)
    Do $$$AssertEquals(tRows, 1, "and one row records the paths the puts stored: " _ tRows)
}

/// <p>A change stores the new directory, then deletes the old; a delete that fails after the put leaves both and still
/// records the roots it moved.</p>
Method TestAChangeStoresTheNewThenDeletesTheOld()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"), ..Dir("b"))), "the list holds two probe directories")
    Set tFirstSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Call("PUT", "change", ..Dir("a"), ..Dir("c"), .tHttp, .tRow, .tFault)
    Do $$$AssertStatusOK(tSC, "the change is accepted")
    Set tFirstAudit = ..AuditRow(tFirstSince, "changed", .tFirstRows)
    Do $$$AssertEquals(tFirstRows, 1, "one SecurityChange row records the change: " _ tFirstRows)
    If tFirstRows = 1 {
        Do $$$AssertEquals(..Joined(tFirstAudit.changes.roots.old), ..Sorted($ListBuild(..Dir("a"), ..Dir("b"))), "naming the roots before")
        Do $$$AssertEquals(..Joined(tFirstAudit.changes.roots.new), ..Sorted($ListBuild(..Dir("b"), ..Dir("c"))), "and the roots after")
    }
    Do $$$AssertEquals(..WriteLog(), "FSAccess.Path/PUT " _ $Replace(..Dir("c"), ..Manager(), "<mgr>") _ "; FSAccess.Path/DELETE " _ $Replace(..Dir("a"), ..Manager(), "<mgr>"), "the new directory's PUT, then the old one's DELETE")
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Sorted($ListBuild(..Dir("b"), ..Dir("c"))), "the roots hold the new directory and not the old")

    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"), ..Dir("b"))), "the list holds two again")
    Do $ClassMethod(..#FIXTURE, "Reset")
    Do $ClassMethod(..#FIXTURE, "Script", "FSAccess.Path", "DELETE", 500)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Call("PUT", "change", ..Dir("a"), ..Dir("c"), .tHttp, .tRow, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a delete the vendor refuses fails the change")
    Do $ClassMethod(..#FIXTURE, "Reset")
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Sorted($ListBuild(..Dir("a"), ..Dir("b"), ..Dir("c"))), "the new directory was stored and the old one stays")
    Set tAudit = ..AuditRow(tSince, "changed", .tRows)
    Do $$$AssertEquals(tRows, 1, "and the roots that moved are recorded: " _ tRows)
}

/// <p>A remove deletes one entry; removing the last leaves a restricted list with no root, which allows nothing -- the
/// real port answers no root and refuses every path <code>PATH.ROOT</code>, the manager directory's included, and the
/// vendor's own check allows no directory (C2b).</p>
/// <p>Mutation (Rule 19): send <code>Purpose</code> <code>PUT {Restricted: false}</code> after a remove's <code>DELETE</code>
/// in <method>OcuPilot.Port.AllowListPort.Execute</method> -- the emptied-list leg goes red.</p>
Method TestRemovingTheLastEntryLeavesAListThatAllowsNothing()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(..Dir("a"), ..Dir("b"))), "the list holds two probe directories")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ..Call("PUT", "remove", ..Dir("a"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusOK(tSC, "the first remove is accepted")
    Set tAudit = ..AuditRow(tSince, "removed", .tRows)
    Do $$$AssertEquals(tRows, 1, "one SecurityChange row records the remove: " _ tRows)
    If tRows = 1 {
        Do $$$AssertEquals(..Joined(tAudit.changes.roots.old), ..Sorted($ListBuild(..Dir("a"), ..Dir("b"))), "naming the roots before")
        Do $$$AssertEquals(..Joined(tAudit.changes.roots.new), ..Dir("b"), "and the roots after")
    }
    Do $$$AssertEquals($ListToString(..RootsNow(), "|"), ..Dir("b"), "one root remains")
    Set tSC = ..Call("PUT", "remove", ..Dir("b"), "", .tHttp, .tRow, .tFault)
    Do $$$AssertStatusOK(tSC, "the last remove is accepted")
    Do $$$AssertEquals(tRow.Restricted _ "|" _ tRow.Roots.%Size(), "1|0", "the answer says restricted, with no root")
    Do $$$AssertEquals($ListLength(..RootsNow()), 0, "the real roots are none")
    Do $ClassMethod(..#FIXTURE, "Snapshot", .tExists, .tRestricted, .tPaths)
    Do $$$AssertEquals(tExists _ "|" _ tRestricted _ "|" _ $ListLength(tPaths), "1|1|0", "the purpose is kept, restricted, holding no path")
    For tWhere = ..Dir("b"), ..Manager() {
        Set tSC = $ClassMethod(..#PATHPORT, "Resolve", tWhere, "x.txt", "file", "root", "path", .tResolved, .tResolveHttp, .tResolveFault, 0, 0)
        Do $$$AssertEquals(tResolveHttp _ "|" _ $Select($IsObject($Get(tResolveFault)): tResolveFault.code, 1: ""), "400|PATH.ROOT", "a path under " _ $Replace(tWhere, ..Manager(), "<mgr>") _ " is refused PATH.ROOT")
    }
    Set tAllowed = $ClassMethod("%CSP.Portal.Utils", "IsDirectoryAllowed", ..Dir("b"))
    Do $$$AssertEquals(tAllowed, 0, "and the vendor's own check allows no directory")
}

/// <p>Every refusal of the matrix, as the read and the write both answer it: status, code and the field it concerns, with no
/// vendor write sent. The list is restricted to the first probe directory unless the case says otherwise.</p>
/// <p>Mutation (Rule 19): drop the <code>LISTED</code> check from the restricted add in
/// <method>OcuPilot.Port.AllowListPort.Plan</method> -- the first case goes red.</p>
Method TestEveryRefusalIsExactAndSendsNoWrite()
{
    Set tManager = ..Manager()
    Set tLong = tManager _ $Justify("", 1100)
    Set tCases = ""
    ; restricted to a: add, change, remove
    Set tCases = tCases _ $ListBuild($ListBuild(1, "add", ..Dir("a"), "", 409, "ALLOWLIST.LISTED", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "add", tManager _ "ocuprobe1842missing/", "", 422, "ALLOWLIST.NODIRECTORY", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "add", "relative/dir", "", 400, "ALLOWLIST.PATH", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "add", ..Dir("b") _ $Char(7), "", 400, "ALLOWLIST.PATH", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "add", tLong, "", 400, "ALLOWLIST.PATH", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "change", ..Dir("b"), ..Dir("c"), 409, "ALLOWLIST.NOTLISTED", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "change", ..Dir("a"), ..Dir("a"), 409, "ALLOWLIST.LISTED", "NewDirectory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "change", ..Dir("a"), tManager _ "ocuprobe1842missing/", 422, "ALLOWLIST.NODIRECTORY", "NewDirectory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "change", ..Dir("a"), "relative/dir", 400, "ALLOWLIST.PATH", "NewDirectory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "remove", ..Dir("b"), "", 409, "ALLOWLIST.NOTLISTED", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "change", ..Dir("a"), "", 400, "TOOL.ARGUMENTS", ""))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "add", ..Dir("b"), ..Dir("c"), 400, "TOOL.ARGUMENTS", ""))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "bogus", ..Dir("b"), "", 400, "TOOL.ARGUMENTS", ""))
    ; unrestricted: the manager directory is the one entry
    Set tCases = tCases _ $ListBuild($ListBuild(0, "remove", tManager, "", 409, "ALLOWLIST.FALLBACK", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(0, "change", tManager, ..Dir("a"), 409, "ALLOWLIST.FALLBACK", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(0, "remove", ..Dir("a"), "", 409, "ALLOWLIST.NOTLISTED", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(0, "change", ..Dir("a"), ..Dir("b"), 409, "ALLOWLIST.NOTLISTED", "Directory"))
    Set tCases = tCases _ $ListBuild($ListBuild(0, "add", tManager _ "ocuprobe1842missing/", "", 422, "ALLOWLIST.NODIRECTORY", "Directory"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do $ClassMethod(..#FIXTURE, "SetUp", $List(tCase, 1), $Select($List(tCase, 1): $ListBuild(..Dir("a")), 1: ""))
        Do $ClassMethod(..#FIXTURE, "Reset")
        Set tLabel = tI _ " " _ $List(tCase, 2) _ " restricted " _ $List(tCase, 1)
        For tType = "GET", "PUT" {
            Set tSC = ..Call(tType, $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), .tHttp, .tRow, .tFault)
            Set tField = ""
            If $IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object") && (tFault.detail.%GetTypeOf("violations") = "array") Set tField = tFault.detail.violations.%Get(0).field
            Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: "") _ "|" _ tField, $List(tCase, 5) _ "|" _ $List(tCase, 6) _ "|" _ $List(tCase, 7), tType _ " case " _ tLabel)
        }
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Writes"), 0, "case " _ tLabel _ " sent no vendor write")
    }
}

/// <p>The gate is <class>OcuPilot.Port.PathPort</class>'s and answers before any call: a caller short of a pair is refused
/// <code>PORT.ACCESSDENIED</code> naming it, on the read and on the write, even for a change that is not valid, with no
/// <code>FSAccess</code> call made; and a purpose other than the list's is refused before any call too.</p>
/// <p>Mutation (Rule 19): skip the <code>Gate</code> call in <method>OcuPilot.Port.AllowListPort.Invoke</method> -- the
/// invalid change is refused <code>TOOL.ARGUMENTS</code> instead and the gate leg goes red.</p>
Method TestTheGateAndAnotherPurposeRefuseBeforeAnyCall()
{
    Set tPair = $Piece($Parameter(..#PATHPORT, "PAIRS"), ",", 1)
    Do $ClassMethod(..#FIXTURE, "Deny", tPair)
    For tType = "GET", "PUT" {
        Set tSC = ..Call(tType, "add", ..Dir("a"), "", .tHttp, .tRow, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code _ "|" _ tFault.detail.failedPair, "403|PORT.ACCESSDENIED|" _ tPair, tType _ ": refused naming the pair")
        Set tSC = ..Call(tType, "bogus", ..Dir("a"), "", .tHttp, .tRow, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "403|PORT.ACCESSDENIED", tType _ ": the gate answers before the change is even checked")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Calls"), 0, "with no call made")
    Do $ClassMethod(..#FIXTURE, "Reset")
    For tType = "GET", "PUT" {
        Set tSC = ..Call(tType, "add", ..Dir("a"), "", .tHttp, .tRow, .tFault, "SomeOtherPurpose")
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "400|TOOL.ARGUMENTS", tType _ ": another purpose is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Calls"), 0, "before any call")
}

/// <p>A directory is admitted only absolute, bounded, clean and normalized.</p>
Method TestNormalizedAdmitsOnlyAbsoluteBoundedCleanDirectories()
{
    Set tPort = ..#PORT
    Do $$$AssertEquals($ClassMethod(tPort, "Normalized", "/tmp/ocuprobe1842x"), "/tmp/ocuprobe1842x/", "the trailing separator is added")
    Do $$$AssertEquals($ClassMethod(tPort, "Normalized", "/tmp/a/../ocuprobe1842x/"), "/tmp/ocuprobe1842x/", "and a dot-dot is resolved")
    For tBad = "", "relative", "./relative/", "tmp/", "/tmp/" _ $Char(0), "/tmp/" _ $Char(31), "/tmp/" _ $Char(127), "/" _ $Justify("", 1100) {
        Do $$$AssertEquals($ClassMethod(tPort, "Normalized", tBad), "", "'" _ $Translate($Extract(tBad, 1, 12), $Char(0, 31, 127), "???") _ "' is refused")
    }
    Set tFits = "/" _ $Translate($Justify("", 1021), " ", "a") _ "/"
    Do $$$AssertEquals($ClassMethod(tPort, "Normalized", tFits), tFits, "a directory of 1,023 characters is admitted")
    Set tEdge = "/" _ $Translate($Justify("", 1022), " ", "a") _ "/"
    Do $$$AssertEquals($ClassMethod(tPort, "Normalized", tEdge), tEdge, "and one of exactly 1,024 characters is admitted")
    Set tNormalOver = "/" _ $Translate($Justify("", 1023), " ", "a")
    Do $$$AssertEquals($ClassMethod(tPort, "Normalized", tNormalOver), "", "and one of 1,024 whose normalized spelling adds the separator is not")
    If $System.Version.GetOS() '= "Windows" {
        For tForeign = "C:/ocuprobe1842x/", "C:\ocuprobe1842x\", "\\srv\share\" Do $$$AssertEquals($ClassMethod(tPort, "Normalized", tForeign), "", "'" _ tForeign _ "' is not absolute on UNIX and is refused")
    }
}

/// <p>The script form (AD-59): the write renders the vendor calls of the change as <code>rest</code> steps, a change that
/// would be refused renders a comment, and the read has none.</p>
Method TestTheScriptFormRendersTheVendorCallsOfTheChange()
{
    Set tPort = ..#PORT
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "AllowList", "PUT") _ "|" _ $ClassMethod(tPort, "SnippetForm", "AllowList", "GET"), "rest|", "the write has a script form and the read none")
    Kill tQuery
    Set tQuery("purpose") = ..#PURPOSE
    Set tQuery("Action") = "change"
    Set tQuery("Directory") = ..Dir("a")
    Set tQuery("NewDirectory") = ..Dir("c")
    Set tSteps = $ClassMethod(tPort, "Snippet", "AllowList", "PUT", .tQuery, "", {"origin": "http://localhost", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size(), 2, "a change is two steps")
    If tSteps.%Size() = 2 {
        Do $$$AssertTrue((tSteps.%Get(0).text [ "-X PUT") && (tSteps.%Get(0).text [ "fs-access-purpose/path") && (tSteps.%Get(0).text [ "ocuprobe1842c"), "the new directory's PUT first")
        Do $$$AssertTrue((tSteps.%Get(1).text [ "-X DELETE") && (tSteps.%Get(1).text [ "ocuprobe1842a"), "then the old one's DELETE")
    }
    Set tQuery("Action") = "add"
    Kill tQuery("NewDirectory")
    Set tSteps = $ClassMethod(tPort, "Snippet", "AllowList", "PUT", .tQuery, "", {"origin": "http://localhost", "user": "u"})
    Set tNote = $Select(tSteps.%Size() > 1: tSteps.%Get(1).kind _ "|" _ tSteps.%Get(1).text, 1: "")
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ tNote, "2|comment|" _ $Parameter(tPort, "UNRESTRICTEDNOTE"), "an add is its PUT, then the note naming the calls a list not yet restricted also takes")
    Set tQuery("Action") = "change"
    Set tQuery("NewDirectory") = ..Dir("c")
    Set tQuery("Directory") = "relative"
    Set tSteps = $ClassMethod(tPort, "Snippet", "AllowList", "PUT", .tQuery, "", {"origin": "http://localhost", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ tSteps.%Get(0).kind _ "|" _ tSteps.%Get(0).text, "1|comment|" _ ##class(OcuPilot.Api.AllowListError).#REASONPATH, "a refused change renders one comment carrying its sentence and no call")
}

/// <p>The six codes are one vocabulary: each carries its sentence through the error mappers a tool result and a violation
/// read, and the codes a write's read-back may meet are two of them.</p>
Method TestTheCodesAreOneVocabularyThroughTheErrorMappers()
{
    Set tCodes = ##class(OcuPilot.Api.AllowListError).Codes()
    Do $$$AssertEquals($ListLength(tCodes), 6, "six codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tSentence = ##class(OcuPilot.Api.AllowListError).ReasonFor(tCode)
        Do $$$AssertTrue(tSentence '= "", tCode _ " has a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tSentence, tCode _ ": a tool result renders it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tSentence, tCode _ ": a violation renders it")
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), tCode _ " matches the machine-code pattern")
    }
    Set tPrecondition = ##class(OcuPilot.Api.AllowListError).PreconditionCodes()
    Do $$$AssertEquals($ListToString(tPrecondition), "ALLOWLIST.LISTED,ALLOWLIST.NOTLISTED", "the read-back's two are LISTED and NOTLISTED")
}

}
