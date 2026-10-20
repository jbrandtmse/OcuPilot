/// <p>Pins <class>OcuPilot.Port.AnalyticsPort</class>'s seven reads against the probe analytics objects in <code>USER</code>
/// (AD-29, AD-36, AD-65, Story 20.11): every endpoint answers the rows the vendor's own classes answer for the probe, a namespace
/// that does not report analytics is refused 409 <code>ANALYTICS.NAMESPACE</code> before any vendor call, the request shapes the
/// port refuses are refused, the cap bounds a list, and no read changes the MDX cache, the process's DeepSee session node, a
/// favorite, or the probe's term list or folder nodes.</p>
/// <p>This class runs as the unit-test process, which holds <code>%All</code>, so the probe's guarded cube and guarded dashboard
/// are visible to it; <class>OcuPilot.Test.AnalyticsGate</class> pins their absence for a caller who lacks the resource.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// <class>OcuPilot.Test.AnalyticsProbe</class> turns analytics on for <code>USER</code>'s default web application, compiles
/// classes and writes cubes, a term list and folder items there. It restores and removes all of it after the last test.</p>
Class OcuPilot.Test.AnalyticsPort Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter NAMESPACE = "USER";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPort turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create", $USERNAME)
}

/// <p>Remove the probe and restore USER's flags; a failing status when anything of it is left.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPort left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>One read of <var>pEndpoint</var> in <var>pNamespace</var>: the rows in <var>pRows</var>, the HTTP status and the fault.
/// <var>pKey</var> and <var>pValue</var> name the criterion of a cube tab or a term list's entries.</p>
ClassMethod Read(pEndpoint As %String, pNamespace As %String, pKey As %String = "", pValue As %String = "", pMax As %String = 100, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    If pMax '= "" Set tQuery("maxRows") = pMax
    If pKey '= "" Set tQuery(pKey) = pValue
    Set pRows = ""
    Set pFault = ""
    Quit $ClassMethod(..#PORT, "Invoke", pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>The rows of <var>pRows</var> whose <var>pField</var> starts with <var>pPrefix</var>, each as the <var>pFields</var> joined with
/// <code>|</code>, the rows joined with <code>;</code>.</p>
ClassMethod Flatten(pRows As %DynamicArray, pField As %String, pPrefix As %String, pFields As %String) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit tText
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get(pField), 1, $Length(pPrefix)) '= pPrefix Continue
        Set tLine = ""
        For tI = 1:1:$Length(pFields, ",") {
            Set tLine = tLine _ $Select(tI = 1: "", 1: "|") _ tRow.%Get($Piece(pFields, ",", tI))
        }
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tLine
    }
    Quit tText
}

/// <p>The vendor's own answers in <code>USER</code>, by explicit save and restore of the namespace.</p>
ClassMethod Vendor(pWhat As %String, pArg As %String = "") As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If pWhat = "facts" {
            Set tText = ##class(%DeepSee.Utils).%GetCubeFactCount(pArg)
        } ElseIf pWhat = "class" {
            Set tText = ##class(%DeepSee.Utils).%GetCubeClass(pArg)
        } ElseIf pWhat = "build" {
            Set tText = $Extract(##class(%DeepSee.CubeManager.Utils).GetLastUpdate(pArg, "build"), 1, 19)
        } ElseIf pWhat = "cubes" {
            Set tSC = ##class(%DeepSee.Utils).%GetCubeList(.tList, "cubes", 1)
            Set tKey = ""
            For {
                Set tKey = $Order(tList(tKey))
                If tKey = "" Quit
                Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List(tList(tKey), 1)
            }
        } ElseIf pWhat = "related" {
            Set tText = ##class(%DeepSee.Utils).%GetRelatedCube($Piece(pArg, "|", 1), $Piece(pArg, "|", 2))
        } ElseIf pWhat = "type" {
            Set tExists = ##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(pArg, .tId)
            Set tItem = $Select(tExists: ##class(%DeepSee.UserLibrary.FolderItem).%OpenId(tId), 1: "")
            Set tText = $Select($IsObject(tItem): tItem.%GetTypeName(), 1: "")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "ERROR " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>AC1: Cubes answers one row per cube the vendor shows the caller, {Name, Caption, Class, LastBuild, Facts}, each equal to the
/// vendor's own answer: the class <code>%GetCubeClass</code> gives, the fact count <code>%GetCubeFactCount</code> gives (1,000 for
/// Visits and 5 for the other two), and the last build <code>GetLastUpdate</code> gives, cut to the second.</p>
/// <p>Mutation (Rule 19): make the Cubes read answer <code>Facts</code> as 0 -- this goes red on the 1,000 and the 5.</p>
Method TestCubesEqualTheVendorsAnswer()
{
    Set tSC = ..Read("Cubes", ..#NAMESPACE, , , , .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "Cubes reads")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Set tNames = ..Vendor("cubes")
    Set tExpected = ""
    For tI = 1:1:$Length(tNames, ",") {
        Set tName = $Piece(tNames, ",", tI)
        If $Extract(tName, 1, 13) '= "OcuPilotProbe" Continue
        Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ";") _ tName _ "|" _ ..Vendor("class", tName) _ "|" _ ..Vendor("facts", tName) _ "|" _ ..Vendor("build", tName)
    }
    Do $$$AssertEquals(..Flatten(tRows, "Name", "OcuPilotProbe", "Name,Class,Facts,LastBuild"), tExpected, "the probe cubes are the vendor's, with its class, fact count and last build")
    Do $$$AssertEquals(..Flatten(tRows, "Name", "OcuPilotProbe", "Name,Class,Facts"), "OcuPilotProbeCategories|OcuPilotProbe.Analytics.CategoriesCube|5;OcuPilotProbeGuarded|OcuPilotProbe.Analytics.GuardedCube|5;OcuPilotProbeVisits|OcuPilotProbe.Analytics.VisitsCube|1000", "and the probe built three cubes of 5, 5 and 1,000 facts; the guarded one is visible to a caller holding %All")
    Set tVisits = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Name = "OcuPilotProbeVisits" Set tVisits = tRow
    }
    Do $$$AssertTrue($IsObject(tVisits), "the Visits cube is listed")
    If $IsObject(tVisits) {
        Do $$$AssertEquals(tVisits.Caption, "OcuPilot probe visits", "its caption is the cube's displayName")
        Do $$$AssertTrue($Match(tVisits.LastBuild, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), "its last build reads as YYYY-MM-DD HH:MM:SS: " _ tVisits.LastBuild)
        Do $$$AssertEquals(tVisits.%GetTypeOf("Facts"), "number", "and its facts are a number")
    }
}

/// <p>AC1, AC2: a cube's three tabs answer from the vendor's model: the Visits cube's three measures (the count, an amount and a
/// hidden average), its three levels in model order from position 1, and its relationship to the Categories cube, which
/// <code>%GetRelatedCube</code> names; the Categories cube names the inverse. A cube the vendor does not know, or a name in another letter
/// case, reads as the vendor reads it.</p>
/// <p>The tabs' refusal of a cube the vendor hides is pinned by <class>OcuPilot.Test.AnalyticsGate</class>: the guarded cube is visible
/// to this process, which holds <code>%All</code>.</p>
Method TestTheCubeTabsAnswerTheModel()
{
    Set tSC = ..Read("Measures", ..#NAMESPACE, "cube", "OcuPilotProbeVisits", , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Measures reads")
    Do $$$AssertEquals(..Flatten(tRows, "Name", "", "Name,Caption,Type,Hidden"), "%COUNT|Count|integer|0;Amount|Amount|number|0;Minutes|Minutes|integer|1", "the cube's measures, the hidden one marked")
    Set tSC = ..Read("Dimensions", ..#NAMESPACE, "cube", "OcuPilotProbeVisits", , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Dimensions reads")
    Do $$$AssertEquals(..Flatten(tRows, "Dimension", "", "Position,Dimension,Hierarchy,Level"), "1|Seen|H1|Year;2|Seen|H1|Month;3|Place|H1|Category", "one row per level, in model order, counted from 1")
    Set tSC = ..Read("Relationships", ..#NAMESPACE, "cube", "OcuPilotProbeVisits", , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Relationships reads")
    Do $$$AssertEquals(..Flatten(tRows, "Name", "", "Name,RelatedCube"), "CategoryRel|" _ ..Vendor("related", "OcuPilotProbeVisits|CategoryRel"), "the relationship and the cube the vendor says it relates to")
    Do $$$AssertEquals(..Vendor("related", "OcuPilotProbeVisits|CategoryRel"), "OcuPilotProbeCategories", "which is the Categories cube")
    Set tSC = ..Read("Relationships", ..#NAMESPACE, "cube", "OcuPilotProbeCategories", , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(..Flatten(tRows, "Name", "", "Name,RelatedCube"), "Visits|OcuPilotProbeVisits", "the Categories cube names the inverse")
    Set tSC = ..Read("Measures", ..#NAMESPACE, "cube", "ocupilotprobevisits", , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(..Flatten(tRows, "Name", "", "Name"), "%COUNT;Amount;Minutes", "a cube name in another letter case reads as the vendor reads it")
    For tEndpoint = "Measures", "Dimensions", "Relationships" {
        Set tSC = ..Read(tEndpoint, ..#NAMESPACE, "cube", "NoSuchCube", , .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|0", tEndpoint _ ": a cube no one holds reads zero rows")
    }
}

/// <p>AC1, AC2: Term lists answers the probe's list with its caption and the date it was last changed, and its entries answer
/// {TermList, Key, Value, Fields} with the extra <code>Note</code> field joined as <code>Note: &lt;value&gt;</code>; a term list no one holds reads
/// zero rows.</p>
/// <p>Mutation (Rule 19): stop joining <code>%ToObj</code>'s extra fields into <code>Fields</code> -- the entries leg goes red.</p>
Method TestTermListsAndEntriesAnswerTheVendorsList()
{
    Set tSC = ..Read("TermLists", ..#NAMESPACE, , , , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Term lists reads")
    Do $$$AssertEquals(..Flatten(tRows, "Name", "OcuPilotProbe", "Name,Caption"), "OcuPilotProbeTerms|OcuPilot probe terms", "the probe's term list and its caption")
    Set tModified = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Name = "OcuPilotProbeTerms" Set tModified = tRow.Modified
    }
    Do $$$AssertTrue($Match(tModified, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") && (tModified '] $ZDate($Horolog, 3)), "last changed no later than today, as a YYYY-MM-DD date: " _ tModified)
    Set tSC = ..Read("TermListEntries", ..#NAMESPACE, "termlist", "OcuPilotProbeTerms", , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the entries read")
    Do $$$AssertEquals(..Flatten(tRows, "Key", "", "TermList,Key,Value,Fields"), "OcuPilotProbeTerms|k1|Alpha|Note: first note;OcuPilotProbeTerms|k2|Beta|Note: second note;OcuPilotProbeTerms|k3|Gamma|Note: third note", "three entries, each with its value and its Note field")
    Set tSC = ..Read("TermListEntries", ..#NAMESPACE, "termlist", "NoSuchTermList", , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|0", "a term list no one holds reads zero rows")
}

/// <p>AC1: Folder items answers the probe's three items with their types, owner and local modified time, and marks as a favorite the
/// pivot this process's user has marked, and no other; the favorite that names no item does not appear.</p>
/// <p>Mutation (Rule 19): read the favorites through <code>%GetFavoritesForUser</code> -- the dangling favorite is deleted and
/// <method>TestTheReadsWriteNothing</method> goes red.</p>
Method TestFolderItemsAnswerTheVendorsList()
{
    Set tSC = ..Read("FolderItems", ..#NAMESPACE, , , , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "Folder items reads")
    Set tPivotType = ..Vendor("type", "OcuPilotProbe/Visits.pivot")
    Set tBoardType = ..Vendor("type", "OcuPilotProbe/Board.dashboard")
    Do $$$AssertNotEquals(tPivotType, "", "the vendor names the pivot's type")
    Do $$$AssertEquals(..Flatten(tRows, "Name", "OcuPilotProbe/", "Name,Type,Owner,Favorite"), "OcuPilotProbe/Board.dashboard|" _ tBoardType _ "|_SYSTEM|0;OcuPilotProbe/Guarded.dashboard|" _ tBoardType _ "|_SYSTEM|0;OcuPilotProbe/Visits.pivot|" _ tPivotType _ "|_SYSTEM|1", "the probe's items with their types and owner, the pivot alone a favorite, and the guarded dashboard visible to a caller holding %All")
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.Name, 1, 14) '= "OcuPilotProbe/" Continue
        Do $$$AssertTrue($Match(tRow.Modified, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), tRow.Name _ ": modified reads as YYYY-MM-DD HH:MM:SS: " _ tRow.Modified)
        Do $$$AssertEquals(tRow.%GetTypeOf("Favorite"), "boolean", tRow.Name _ ": its favorite flag is a boolean")
    }
    Do $$$AssertEquals(..Flatten(tRows, "Name", "OcuPilotProbe/Gone", "Name"), "", "the favorite that names no item is not a row")
}

/// <p>The caller's shapes the port refuses: an endpoint or type it does not serve is 501, a cap that is not a whole number above
/// zero and a namespace of the wrong shape are 400 <code>PORT.VALIDATION</code>, a cube tab or an entries read with no criterion is
/// 400, and a cap bounds a list to that many rows.</p>
Method TestTheRequestShapesTheGateAndThePortRefuse()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Nothing", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "501|PORT.NOTIMPLEMENTED", "an endpoint the port does not serve")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Cubes", "GET", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "501|PORT.NOTIMPLEMENTED", "and a type other than LIST")
    For tMax = "0", "-1", "ten", "1.5" {
        Set tSC = ..Read("Cubes", ..#NAMESPACE, , , tMax, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "400|PORT.VALIDATION", "a cap of " _ tMax)
    }
    Set tSC = ..Read("Cubes", "not a namespace", , , , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "400|PORT.VALIDATION", "a namespace of the wrong shape")
    For tEndpoint = "Measures", "Dimensions", "Relationships" {
        Set tSC = ..Read(tEndpoint, ..#NAMESPACE, , , , .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "400|PORT.VALIDATION", tEndpoint _ " with no cube")
    }
    Set tSC = ..Read("TermListEntries", ..#NAMESPACE, , , , .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.code, "400|PORT.VALIDATION", "the entries with no term list")
    Set tSC = ..Read("Cubes", ..#NAMESPACE, , , 2, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|2", "a cap of two bounds Cubes to two rows")
    Set tSC = ..Read("Dimensions", ..#NAMESPACE, "cube", "OcuPilotProbeVisits", 2, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|2", "and Dimensions to two")
    Set tSC = ..Read("TermListEntries", ..#NAMESPACE, "termlist", "OcuPilotProbeTerms", 1, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|1", "and the entries to one")
    Set tSC = ..Read("Measures", ..#NAMESPACE, "cube", "OcuPilotProbeVisits", 2, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|2", "and Measures to two")
    Set tSC = ..Read("FolderItems", ..#NAMESPACE, , , 2, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%Size(), "200|2", "and Folder items, whose vendor read opens every item, to two")
}

/// <p>AC3: a namespace that does not report analytics is refused 409 <code>ANALYTICS.NAMESPACE</code> with its one sentence on every
/// endpoint, before any vendor call.</p>
/// <p>Mutation (Rule 19): drop the analytics check from <method>OcuPilot.Port.AnalyticsPort.Admit</method> -- this goes red, because
/// the read then answers 200 with no rows.</p>
Method TestANamespaceWithoutAnalyticsIsRefusedOnEveryEndpoint()
{
    Set tNamespace = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Do $$$AssertTrue('##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("analytics", tNamespace), tNamespace _ " reports no analytics")
    For tEndpoint = "Cubes", "Measures", "Dimensions", "Relationships", "TermLists", "TermListEntries", "FolderItems" {
        Set tSC = ..Read(tEndpoint, tNamespace, $Select(tEndpoint = "TermListEntries": "termlist", $Find("Measures,Dimensions,Relationships", tEndpoint) > 0: "cube", 1: ""), "x", , .tRows, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tEndpoint _ " is refused in " _ tNamespace)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code _ "|" _ tFault.reason, "409|ANALYTICS.NAMESPACE|Analytics is not enabled in this namespace.", tEndpoint _ ": 409 with its sentence")
    }
}

/// <p>End this process's DeepSee session: the process variable the vendor reuses once it holds one, and the session's node in
/// <code>USER</code>. A read that opens a session writes its node only the first time, so every comparison starts without one.</p>
ClassMethod ForgetSession()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill %DeepSeeSession
        Kill ^DeepSee.Session($Job)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Whether global reference <var>pNode</var> is <var>pRoot</var> or below it: the same global, and <var>pRoot</var>'s subscripts
/// lead <var>pNode</var>'s.</p>
ClassMethod Under(pNode As %String, pRoot As %String) As %Boolean
{
    If $QLength(pNode) < $QLength(pRoot) Quit 0
    For tI = 0:1:$QLength(pRoot) {
        If $QSubscript(pNode, tI) '= $QSubscript(pRoot, tI) Quit
    }
    Quit (tI > $QLength(pRoot))
}

/// <p>AC1: the two time shapes the port answers are the instance's local <code>YYYY-MM-DD HH:MM:SS</code>. A last build is the vendor's
/// local stamp cut to the second, and empty for the vendor's <code>0</code> or an empty answer (a cube never built); a folder item's modified time,
/// which the vendor stores as UTC, reads as the local time of the same instant and as nothing for a value that is not a stamp. Two
/// sessions started with <code>TZ</code> set, one west of Greenwich with daylight saving and one east, read fixed UTC stamps in their
/// own zones, so the conversion is pinned whatever zone this instance runs in.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.LocalStamp</method> answer its input unchanged -- the two zone legs go red
/// on any instance, and the invalid leg goes red too.</p>
Method TestTheTimeShapesAreTheInstancesLocalTime()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "BuildStamp", 0), "", "a cube never built reads empty from the vendor's 0")
    Do $$$AssertEquals($ClassMethod(..#PORT, "BuildStamp", ""), "", "and from an empty answer")
    Do $$$AssertEquals($ClassMethod(..#PORT, "BuildStamp", "2026-10-20 10:39:17.884"), "2026-10-20 10:39:17", "a recorded build is cut to the second")
    Set tUtc = $ZDateTime($ZTimeStamp, 3)
    Set tLocal = $ClassMethod(..#PORT, "LocalStamp", tUtc)
    Do $$$AssertTrue($Match(tLocal, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), "a UTC stamp reads as a local one: " _ tLocal)
    Set tHere = $ZDateTimeH($ZDateTime($Horolog, 3), 3)
    Set tThere = $ZDateTimeH(tLocal, 3)
    Do $$$AssertTrue($ZAbs(($Piece(tThere, ",", 1) * 86400 + $Piece(tThere, ",", 2)) - ($Piece(tHere, ",", 1) * 86400 + $Piece(tHere, ",", 2))) <= 2, "the local reading of now is the instance's local now, within two seconds: " _ tLocal)
    Do $$$AssertEquals($ClassMethod(..#PORT, "LocalStamp", ""), "", "an empty modified time reads empty")
    Do $$$AssertEquals($ClassMethod(..#PORT, "LocalStamp", "not a stamp at all, no"), "", "and so does a value that is not a stamp")
    Do $$$AssertEquals(..InZone("America/Los_Angeles"), "2026-01-20 04:00:00|2026-10-20 05:00:00", "eight hours west in January and seven in October, a stored UTC noon reads as 04:00:00 and 05:00:00")
    Do $$$AssertEquals(..InZone("Asia/Tokyo"), "2026-01-20 21:00:00|2026-10-20 21:00:00", "and nine hours east all year, as 21:00:00 twice")
}

/// <p>The local readings of the UTC noons of 2026-01-20 and 2026-10-20 in this process's zone, joined with <code>|</code>, saved
/// between markers to <var>pFile</var> by the session <method>InZone</method> starts, which then halts.</p>
ClassMethod ZoneStamps(pFile As %String)
{
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSC = tStream.LinkToFile(pFile)
    If $$$ISOK(tSC) {
        Do tStream.Write("ZONE-STAMPS:" _ $ClassMethod(..#PORT, "LocalStamp", "2026-01-20 12:00:00") _ "|" _ $ClassMethod(..#PORT, "LocalStamp", "2026-10-20 12:00:00") _ ":ZONE-END")
        Set tSC = tStream.%Save()
    }
    Halt
}

/// <p>What <method>ZoneStamps</method> saves in a new session, in the caller's namespace, whose environment sets <code>TZ</code> to
/// <var>pZone</var>; <code>ERROR ...</code> when the session saved nothing readable.</p>
ClassMethod InZone(pZone As %String) As %String
{
    Set tFile = ##class(%File).TempFilename("txt")
    Set tText = ""
    Try {
        Set tCode = $ZF(-100, "/STDOUT=""" _ tFile _ ".out"" /STDERR=""" _ tFile _ ".err""", "/usr/bin/env", "TZ=" _ pZone, $System.Util.BinaryDirectory() _ "iris", "session", ##class(%SYS.System).GetInstanceName(), "-U", $NAMESPACE, "##class(" _ $ClassName() _ ").ZoneStamps(""" _ tFile _ """)")
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(tFile)
        Set tAll = $Select($$$ISOK(tSC): tStream.Read(100000), 1: "")
        Set tStream = ""
        Set tText = $Piece($Piece(tAll, "ZONE-STAMPS:", 2), ":ZONE-END", 1)
        If tText = "" Set tText = "ERROR the session saved no stamps, code " _ tCode
    } Catch ex {
        Set tText = "ERROR " _ ex.DisplayString()
    }
    Set tDeleted = ##class(%File).Delete(tFile)
    Set tDeleted = ##class(%File).Delete(tFile _ ".out")
    Set tDeleted = ##class(%File).Delete(tFile _ ".err")
    Quit tText
}

/// <p>The nodes the reads must leave as they found them, in <code>USER</code>, as one digest: every <code>^DeepSee.Cache</code>
/// global, this process's <code>^DeepSee.Session</code> node, the signed-in user's favorites, the probe's term list, and the folder
/// and folder item globals.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Set tError = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill tRefs
        Set tRefs("^DeepSee.Session(" _ $Job _ ")") = ""
        Set tRefs("^DeepSee.UserPreferences(""" _ $USERNAME _ """,""favorite"")") = ""
        Set tRefs("^DeepSee.TermList(""OCUPILOTPROBETERMS"")") = ""
        Set tRefs("^DeepSee.FolderItemD") = ""
        Set tRefs("^DeepSee.FolderItemI") = ""
        Set tRefs("^DeepSee.FolderD") = ""
        Set tRefs("^DeepSee.FolderI") = ""
        Set tGlobal = "^DeepSee.Cache"
        Set tGlobal = $Order(^$GLOBAL(tGlobal))
        While (tGlobal '= "") && ($Extract(tGlobal, 1, 14) = "^DeepSee.Cache") {
            Set tRefs(tGlobal) = ""
            Set tGlobal = $Order(^$GLOBAL(tGlobal))
        }
        Set tRef = ""
        For {
            Set tRef = $Order(tRefs(tRef))
            If tRef = "" Quit
            Set tText = tText _ "#" _ tRef _ ":" _ $Data(@tRef)
            If $Data(@tRef) # 2 Set tText = tText _ "=" _ @tRef
            Set tNode = $Query(@tRef)
            While (tNode '= "") && ..Under(tNode, tRef) {
                Set tText = tText _ "|" _ tNode _ "=" _ @tNode
                Set tNode = $Query(@tNode)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tError = "ERROR " _ ex.DisplayString()
    }
    If tError '= "" Quit tError
    Quit $System.Encryption.Base64Encode($System.Encryption.SHA1Hash(tText)) _ " (" _ $Length(tText) _ " characters)"
}

/// <p>AC1: no read changes the MDX cache, this process's DeepSee session node, the signed-in user's favorites (the favorite that names no
/// item included), the probe's term list, or the folder and folder item globals. The snapshot is taken around every endpoint, and
/// the first of them must name a non-empty favorites node, or the comparison would pass having read nothing.</p>
/// <p>Mutation (Rule 19): read the Dimensions through <code>%GetMemberTree</code> -- the session node leg goes red; read the favorites through
/// <code>%GetFavoritesForUser</code> -- the Folder items leg goes red, the dangling favorite being deleted.</p>
Method TestTheReadsWriteNothing()
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tFavorites = $Order(^DeepSee.UserPreferences($USERNAME, "favorite", ""))
    Set tDangling = $Data(^DeepSee.UserPreferences($USERNAME, "favorite", "OcuPilotProbe/Gone.pivot"))
    Set $NAMESPACE = tOrigNS
    Do $$$AssertNotEquals(tFavorites, "", "the signed-in user holds a favorite, so the favorites node is not empty")
    Do $$$AssertEquals(tDangling, 1, "among them the one that names no folder item")
    For tCase = $ListBuild("Cubes", "", ""), $ListBuild("Measures", "cube", "OcuPilotProbeVisits"), $ListBuild("Dimensions", "cube", "OcuPilotProbeVisits"), $ListBuild("Relationships", "cube", "OcuPilotProbeVisits"), $ListBuild("TermLists", "", ""), $ListBuild("TermListEntries", "termlist", "OcuPilotProbeTerms"), $ListBuild("FolderItems", "", "") {
        Do ..ForgetSession()
        Set tBefore = ..Snapshot()
        Do $$$AssertTrue($Extract(tBefore, 1, 5) '= "ERROR", "the snapshot before " _ $List(tCase, 1) _ " was taken: " _ tBefore)
        Set tSC = ..Read($List(tCase, 1), ..#NAMESPACE, $List(tCase, 2), $List(tCase, 3), , .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, $List(tCase, 1) _ " reads")
        Do $$$AssertEquals(..Snapshot(), tBefore, $List(tCase, 1) _ " changes none of the cache, session, favorites, term list or folder nodes")
    }
    Set $NAMESPACE = ..#NAMESPACE
    Set tDangling = $Data(^DeepSee.UserPreferences($USERNAME, "favorite", "OcuPilotProbe/Gone.pivot"))
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tDangling, 1, "and the favorite that names no folder item is still there")
}

/// <p>AD-39: a vendor failure is answered in the port's own words and the vendor's text stays in the log. A <code>&lt;PROTECT&gt;</code>
/// status, a status carrying the vendor's refusal code and a raised <code>&lt;PROTECT&gt;</code> are answered 403
/// <code>PORT.ACCESSDENIED</code>; a plain failed status and a raised exception that is not an access failure are 500
/// <code>INTERNAL</code> under the generic reason. In each the vendor's text is nowhere in the fault and is in the captured log line (the
/// vendor's refusal code carries a fixed sentence of its own, so that case is checked by the code in the line).</p>
/// <p>Mutation (Rule 19): put the status text into <code>Fail</code>'s reason in <method>OcuPilot.Port.AnalyticsPort.Fail</method> -- the wire
/// leg of the 500 cases goes red.</p>
Method TestAVendorFailureIsAnsweredInThePortsWordsAndLoggedWhole()
{
    Set tSeam = "OcuPilot.Test.AnalyticsGateSeam"
    Set tGlobals = ""
    Do $$$AssertTrue($ClassMethod("OcuPilot.Kernel.Shell.Namespaces", "GlobalDatabase", ..#NAMESPACE, .tGlobals) && (tGlobals '= ""), "the namespace names its database resource: " _ tGlobals)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(tSeam, "Reset")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold(tGlobals, "READ")
    Do $ClassMethod(tSeam, "Arm", "capture")
    For tCase = $ListBuild("protect", 403, "PORT.ACCESSDENIED"), $ListBuild("denied", 403, "PORT.ACCESSDENIED"), $ListBuild("systemprotect", 403, "PORT.ACCESSDENIED"), $ListBuild("status", 500, "INTERNAL"), $ListBuild("exception", 500, "INTERNAL") {
        Set tMode = $List(tCase, 1)
        Do $ClassMethod(tSeam, "Arm", "collect", tMode)
        Kill ^||OcuPilotAnalyticsSeam("log")
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tSC = $ClassMethod(tSeam, "Invoke", "Cubes", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tMode _ ": the read is refused")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), $List(tCase, 2) _ "|" _ $List(tCase, 3), tMode _ ": answered in the port's own code")
        Do $$$AssertTrue($IsObject(tFault) && ($ZConvert(tFault.%ToJSON(), "L") '[ $ZConvert($Parameter(tSeam, "VENDORTEXT"), "L")), tMode _ ": the vendor's text is not on the wire")
        If tMode '= "denied" Do $$$AssertTrue($Get(^||OcuPilotAnalyticsSeam("log")) [ $Parameter(tSeam, "VENDORTEXT"), tMode _ ": and is in the log line: " _ $Get(^||OcuPilotAnalyticsSeam("log")))
        If tMode = "denied" Do $$$AssertTrue($Get(^||OcuPilotAnalyticsSeam("log")) [ "[PORT.ACCESSDENIED]", tMode _ ": and the refusal is in the log line: " _ $Get(^||OcuPilotAnalyticsSeam("log")))
        If $List(tCase, 3) = "INTERNAL" Do $$$AssertEquals(tFault.reason, $Parameter("OcuPilot.Kernel.Fault", "DEFAULTREASON"), tMode _ ": under the generic reason")
    }
    Do $ClassMethod(tSeam, "Reset")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

}
