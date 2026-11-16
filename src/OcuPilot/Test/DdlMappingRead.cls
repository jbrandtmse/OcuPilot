/// <p>Pins Story 21.13's two reads, the gate and the governance defaults (AC1, AC2, AC4; AD-22, AD-29, AD-36): System DDL mappings and User DDL
/// mappings read through <class>OcuPilot.Port.ConfigPort</class> and the screens' own read executor, each row carrying the datatype class as its
/// value, the named read that never passes a caller's name to the vendor's list pattern, every read and write refused to a caller short of a pair
/// before any vendor call, the request types each endpoint serves, and the five write keys' baseline defaults.</p>
/// <p><b>Live-safe:</b> it reads, changes no mapping, and stores a governance policy only to restore it. <b>What it needs from the
/// environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.DdlMappingRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ERROR = "OcuPilot.Api.ConfigError";

/// <p>Each screen: descriptor, route, side-bar position, entity type, port endpoint, vendor class, set tool, delete tool and whether it offers New mapping.</p>
Parameter SCREENS = "DdlSystemMappingList|os-management/system-ddl-mappings|34|system-ddl-mapping|SystemDDL|Config.SqlSysDatatypes|DdlSystemMappingSet|DdlSystemMappingDelete|0;DdlUserMappingList|os-management/user-ddl-mappings|35|user-ddl-mapping|UserDDL|Config.SqlUserDatatypes|DdlUserMappingSet|DdlUserMappingDelete|1";

/// <p>The governance policy as it stood before each test.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>The entries of the vendor class <var>pClass</var> as <code>name</code> to datatype in <var>pEntries</var>, read through its own
/// <code>List</code> query with <code>*</code> in <code>%SYS</code>, with no product class called while there; the count answered.</p>
ClassMethod VendorEntries(pClass As %String, Output pEntries) As %Integer
{
    Kill pEntries
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%ResultSet).%New(pClass _ ":List")
        Set tSC = tResult.Execute("*")
        While tResult.Next() {
            Set pEntries(tResult.Get("Name")) = tResult.Get("Datatype")
            Set tCount = tCount + 1
        }
    } Catch {
        Set tCount = -1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The screen's rows by name through the shipped executor, in <var>pRows</var>; the count answered.</p>
ClassMethod RowsOf(pDescriptor As %String, Output pRows) As %Integer
{
    Kill pRows
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor." _ pDescriptor, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit -1
    Quit ##class(OcuPilot.Test.ConfigSettingRead).RowsByName(tResult, .pRows)
}

/// <p>The code and status a failed call answered, as <code>status|code</code>.</p>
ClassMethod Answered(pHttp As %Integer, pFault As %DynamicObject) As %String
{
    Quit pHttp _ "|" _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The stored state of <var>pProposal</var> as the propose row holds it, in <var>pValues</var>.</p>
ClassMethod Stored(pProposal As %DynamicObject, Output pValues) As %Boolean
{
    Kill pValues
    If '$IsObject(pProposal) Quit 0
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .pValues)
    Quit $$$ISOK(tSC) && $Get(tFound)
}

/// <p><b>AC1, AC2.</b> Each screen answers one row per entry its vendor class lists, valued with the entry's datatype class, and the port's rows
/// are exactly the seven members of the settings-table shape: <code>Kind</code> <code>datatype</code>, the one <code>Accepts</code> sentence, and
/// neither read-only, restart nor purging. The count and the entries are derived from the instance, never written here, and an instance
/// with no user mapping answers the empty list.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>CollectNamed</code> reads <code>Name</code> where it reads
/// <code>Datatype</code> -> the value assertions go red.</p>
Method TestEachReadAnswersTheEntriesTheVendorClassLists()
{
    Set tSentence = $Parameter(..#ERROR, "ACCEPTSDATATYPE")
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tScreen = $Piece(..#SCREENS, ";", tI)
        Set tCount = ..VendorEntries($Piece(tScreen, "|", 6), .tEntries)
        Set tRows = ..RowsOf($Piece(tScreen, "|", 1), .tByName)
        Do $$$AssertEquals(tRows, tCount, $Piece(tScreen, "|", 1) _ ": one row per entry the class lists (" _ tCount _ ")")
        Set tSame = 1
        Set tName = ""
        For {
            Set tName = $Order(tEntries(tName))
            If tName = "" Quit
            If '$Data(tByName(tName)) || (tByName(tName).Value '= tEntries(tName)) Set tSame = 0
        }
        Do $$$AssertEquals(tSame, 1, $Piece(tScreen, "|", 1) _ ": every entry reads with its own datatype")
        Set tShape = 1
        Set tName = ""
        For {
            Set tName = $Order(tByName(tName))
            If tName = "" Quit
            Set tRow = tByName(tName)
            If (##class(OcuPilot.Test.LicenseKey).Keys(tRow) '= "Accepts,Kind,Name,Purges,ReadOnly,Restart,Value") || (tRow.Kind '= "datatype") || (tRow.Accepts '= tSentence) || tRow.Restart || tRow.ReadOnly || tRow.Purges Set tShape = 0
        }
        Do $$$AssertEquals(tShape, 1, $Piece(tScreen, "|", 1) _ ": every row has the seven members, kind datatype, the one accepts sentence and no flag")
    }
    Set tSystem = ..VendorEntries("Config.SqlSysDatatypes", .tSys)
    Do $$$AssertTrue(tSystem > 0, "the instance ships system mappings, so the system list is not an empty list that would pass vacuously")
}

/// <p><b>AC1, AC3.</b> A <code>GET</code> reads one entry through the vendor's own <code>Get</code> of its exact name, never through the list
/// query's pattern: a name that holds <code>*</code> or <code>,</code>, a prefix of a held name and a held name in another letter case each read
/// absent, 404 <code>CONFIG.SETTING.NOTFOUND</code>; a held name reads as the list's row does.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>CollectNamed</code> passes the caller's name to the list query ->
/// the prefix and wildcard rows go red.</p>
Method TestANamedReadComparesTheNameExactlyAndNeverPassesItToTheListPattern()
{
    Set tCount = ..VendorEntries("Config.SqlSysDatatypes", .tEntries)
    Set tHeld = $Order(tEntries(""))
    Do $$$AssertTrue(tHeld '= "", "the instance holds a system mapping to read")
    If tHeld = "" Quit
    Kill tQuery
    Set tQuery("name") = tHeld
    Set tSC = $ClassMethod(..#PORT, "Invoke", "SystemDDL", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRow.Name _ "|" _ tRow.Value, "200|" _ tHeld _ "|" _ tEntries(tHeld), "a held name reads its own row")
    Do ..RowsOf("DdlSystemMappingList", .tByName)
    Do $$$AssertEquals(tRow.%ToJSON(), tByName(tHeld).%ToJSON(), "and it is the row the list answers")
    For tName = "*", $Extract(tHeld, 1, 1) _ "*", $Extract(tHeld, 1, 2) _ "," _ tHeld, $Extract(tHeld, 1, $Length(tHeld) - 1), $ZConvert(tHeld, "L") _ "x", "" {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "SystemDDL", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(..Answered(tHttp, tFault), "404|CONFIG.SETTING.NOTFOUND", "'" _ tName _ "' is no entry's exact name")
    }
    Set tLower = $ZConvert(tHeld, "L")
    If tLower '= tHeld {
        Set tQuery("name") = tLower
        Set tSC = $ClassMethod(..#PORT, "Invoke", "SystemDDL", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(..Answered(tHttp, tFault), "404|CONFIG.SETTING.NOTFOUND", "'" _ tLower _ "' is the held name in another case, which the vendor treats as another name")
    }
    Kill tQuery
    Set tQuery("name") = "NoSuchMapping"
    Set tQuery("action") = "CREATE"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "UserDDL", "GET", .tQuery, "", .tFree, .tHttp, .tFault)
    Do $$$AssertEquals(..Answered(tHttp, tFault), "404|CONFIG.SETTING.NOTFOUND", "the absence read of a create answers the 404 a create expects for a free name")
    Set tQuery("name") = tHeld
    Set tSC = $ClassMethod(..#PORT, "Invoke", "SystemDDL", "GET", .tQuery, "", .tTaken, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "while the same query on an endpoint that is asked no create is the plain read")
}

/// <p><b>AC1, AC3.</b> Every read of the two is refused to a caller short of a pair, naming the first one missing, with no rows answered; and every
/// write type is refused to a caller holding the read pairs, naming <code>%DB_IRISSYS:WRITE</code>, with nothing sent to the vendor.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>Admit</code> answers OK without evaluating the pairs -> the denial
/// assertions go red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfItsPairs()
{
    For tEndpoint = "SystemDDL", "UserDDL" {
        Kill tQuery
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|%Admin_Manage:USE|0", tEndpoint _ ": a caller holding nothing is refused naming the first pair")
        For tAction = "", "CREATE" {
            Kill tQuery
            Set tQuery("name") = "VARCHAR"
            If tAction '= "" Set tQuery("action") = tAction
            Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "GET", .tQuery, "", .tRow, .tHttp, .tFault)
            Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
            Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $IsObject(tRow), "403|%Admin_Manage:USE|0", tEndpoint _ ": a named read" _ $Select(tAction = "": "", 1: " for a create") _ " is refused to that caller too, answering no row")
        }
    }
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    For tEndpoint = "SystemDDL", "UserDDL" {
        Kill tQuery
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": a caller holding the two read pairs reads it, without %Admin_Secure:USE")
    }
    For tCase = $ListBuild("SystemDDL", "SET"), $ListBuild("SystemDDL", "DELETE"), $ListBuild("UserDDL", "SET"), $ListBuild("UserDDL", "CREATE"), $ListBuild("UserDDL", "DELETE") {
        Kill tQuery
        Set tQuery("name") = "ZZOCU1"
        Set tBody = $Select($List(tCase, 2) = "DELETE": "", 1: {"Value": "%Library.String"})
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, tBody, .tOut, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $ClassMethod(..#SEAM, "Entries"), "403|%DB_IRISSYS:WRITE|", $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": refused naming the write pair, and nothing is sent")
    }
}

/// <p><b>AC2.</b> The port serves <code>CREATE</code> on the user mappings alone and <code>DELETE</code> on both, none of the other endpoints
/// serves either, and a create of a system mapping, asked of a caller holding every pair, is 501 <code>PORT.NOTIMPLEMENTED</code> with nothing sent.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>Serves</code> admits <code>CREATE</code> on <code>SystemDDL</code> -> the
/// roster row and the 501 row go red.</p>
Method TestOnlyTheUserMappingsServeCreateAndNoOtherEndpointServesEither()
{
    Set tWant = "SystemDDL|CREATE|0;UserDDL|CREATE|1;SystemDDL|DELETE|1;UserDDL|DELETE|1;Startup|CREATE|0;SQL|DELETE|0;SQLShell|DELETE|0;TSQL|CREATE|0;ISQL|DELETE|0;Memory|CREATE|0;Compatibility|DELETE|0;SystemDDL|SET|1;UserDDL|SET|1;SystemDDL|LIST|1;UserDDL|GET|1;Nothing|DELETE|0"
    For tI = 1:1:$Length(tWant, ";") {
        Set tRow = $Piece(tWant, ";", tI)
        Do $$$AssertEquals(''$ClassMethod(..#PORT, "Serves", $Piece(tRow, "|", 1), $Piece(tRow, "|", 2)), $Piece(tRow, "|", 3), $Piece(tRow, "|", 1) _ " serves " _ $Piece(tRow, "|", 2) _ ": " _ $Piece(tRow, "|", 3))
    }
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Kill tQuery
    Set tQuery("name") = "ZZOCU1"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "SystemDDL", "CREATE", .tQuery, {"Value": "%Library.String"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(..Answered(tHttp, tFault) _ "|" _ $ClassMethod(..#SEAM, "Entries"), "501|PORT.NOTIMPLEMENTED|", "a create of a system mapping is 501 and sends nothing")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "DELETE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(..Answered(tHttp, tFault) _ "|" _ $ClassMethod(..#SEAM, "Entries"), "501|PORT.NOTIMPLEMENTED|", "and so is a delete on an endpoint that has no entries")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "SystemDDL", "CREATE") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "UserDDL", "CREATE") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "SystemDDL", "DELETE") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "UserDDL", "GET"), "|objectscript|objectscript|", "only a served write renders a script")
}

/// <p>AC1, AC2, AC4, AD-5, AD-44, AD-53. The two screens declare the classic pages, positions 34 and 35, the config read source, the read pairs
/// alone, and the row actions Set value and Delete, with New mapping on the user list alone; their tools declare their name, their screen action, their
/// port and endpoint, the classic pages they replace, and the write each makes: a merge that reads its value back, a create that is not a merge, and a
/// destructive delete that sends nothing and names the delete consequence.</p>
/// <p>Mutation (Rule 19): <code>DdlUserMappingDelete</code> declares <code>DESTRUCTIVE</code> 0 -> the declaration assertion goes red.</p>
Method TestTheScreensAndToolsDeclareTheirPagesPairsAndActions()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tScreen = $Piece(..#SCREENS, ";", tI)
        Set tClass = "OcuPilot.Screen.Descriptor." _ $Piece(tScreen, "|", 1)
        Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), tClass _ ": the declaration parses")
        Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), $Piece(tScreen, "|", 2) _ "|os-management|" _ $Piece(tScreen, "|", 3), tClass _ ": its route, area and side-bar position")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Config.SQLDataTypes", tClass _ ": its classic page")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")) _ "|" _ $ClassMethod(tClass, "PrimaryActionId"), $Piece(tScreen, "|", 4) _ "|set,delete|" _ $Select($Piece(tScreen, "|", 9): "add", 1: ""), tClass _ ": its entity type, its two row actions and its primary action only on the user list")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "config|" _ $Piece(tScreen, "|", 5) _ "|LIST", tClass _ ": it reads through the config port")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read is the declared grammar")
        Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && '$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), tClass _ ": it requires the classic page's pairs and not the write pair")
        Set tSet = "OcuPilot.Screen.Tool." _ $Piece(tScreen, "|", 7)
        Set tDelete = "OcuPilot.Screen.Tool." _ $Piece(tScreen, "|", 8)
        Do $$$AssertEquals($ListToString($ClassMethod(tSet, "ScreenActionIds")) _ "|" _ $ClassMethod(tSet, "PortClass") _ "|" _ $ClassMethod(tSet, "Endpoint") _ "|" _ ''$ClassMethod(tSet, "SendsBody") _ ''$ClassMethod(tSet, "Destructive") _ ''$ClassMethod(tSet, "Creates") _ "|" _ $ListToString($ClassMethod(tSet, "ReadBackFields")), "set|" _ ..#PORT _ "|" _ $Piece(tScreen, "|", 5) _ "|100|Value", tSet _ ": a merge write that reads its value back, through the config port")
        Do $$$AssertEquals($ListToString($ClassMethod(tDelete, "ScreenActionIds")) _ "|" _ $ClassMethod(tDelete, "PortClass") _ "|" _ $ClassMethod(tDelete, "Endpoint") _ "|" _ ''$ClassMethod(tDelete, "SendsBody") _ ''$ClassMethod(tDelete, "Destructive") _ ''$ClassMethod(tDelete, "Creates") _ "|" _ $ClassMethod(tDelete, "WriteType") _ "|" _ $ClassMethod(tDelete, "ChangeAction"), "delete|" _ ..#PORT _ "|" _ $Piece(tScreen, "|", 5) _ "|010|DELETE|deleted", tDelete _ ": a destructive delete that sends no body")
        Do $$$AssertEquals($ListToString($ClassMethod(tDelete, "FingerprintSubject")) _ "|" _ $ClassMethod(tDelete, "PreconditionField") _ "|" _ $ListToString($ClassMethod(tDelete, "ReadBackFields")), "Name,Value|Value|", tDelete _ ": its fingerprint covers the entry and its read-back reads it gone")
        Do $$$AssertEquals($Parameter(tDelete, "CONSEQUENCECODE"), $Parameter(..#ERROR, "MAPPINGDELETE"), tDelete _ ": its consequence is the ConfigError sentence's code")
        Do $$$AssertEquals($Parameter(tSet, "CLASSICPAGES"), "%CSP.UI.Portal.Config.SQLDataTypes,%CSP.UI.Portal.Config.SQLDataType", tSet _ ": the classic pages it replaces")
        Do $$$AssertEquals($Parameter(tDelete, "CLASSICPAGES"), $Parameter(tSet, "CLASSICPAGES"), tDelete _ ": the same pages")
        For tName = "SQLDataTypes", "SQLDataType" {
            Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert("%CSP.UI.Portal.Config." _ tName, "O", "URL")), "%CSP.UI.Portal.Config." _ tName, "the portal's own resolver recognises " _ tName _ " (AD-44)")
        }
    }
    Set tCreate = "OcuPilot.Screen.Tool.DdlUserMappingCreate"
    Do $$$AssertEquals($Parameter(tCreate, "TOOLNAME") _ "|" _ ''$ClassMethod(tCreate, "Creates") _ "|" _ $ClassMethod(tCreate, "WriteType") _ "|" _ $ClassMethod(tCreate, "ChangeAction") _ "|" _ $ListToString($ClassMethod(tCreate, "ScreenActionIds")) _ "|" _ $ClassMethod(tCreate, "Endpoint") _ "|" _ $ListToString($ClassMethod(tCreate, "ReadBackFields")), "osmgmt.userddlmappings.create|1|CREATE|created||UserDDL|Value", "the create tool creates and has no screen action: its screen caller is the Save route")
    Do $$$AssertEquals($ListToString($ClassMethod(tCreate, "PreconditionCodes")), $Parameter(..#ERROR, "MAPPINGTAKEN"), tCreate _ ": a name taken since the review reads as a changed target, not a fault")
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Tool.DdlSystemMappingDelete", "ScreenActionIds")) _ "|" _ $Parameter("OcuPilot.Screen.Tool.DdlSystemMappingSet", "TOOLNAME") _ "|" _ $Parameter("OcuPilot.Screen.Tool.DdlSystemMappingDelete", "TOOLNAME"), "delete|osmgmt.systemddlmappings.set|osmgmt.systemddlmappings.delete", "the system list's tool names")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.OsMgmt.DdlMappingSave", "CREATETOOL") _ "|" _ $Parameter("OcuPilot.Area.OsMgmt.DdlMappingSave", "PRODUCTIONMEMBER") _ "|" _ $Parameter("OcuPilot.Area.OsMgmt.DdlMappingSave", "TAKENCODE") _ "|" _ $Parameter("OcuPilot.Area.OsMgmt.DdlMappingSave", "TAKENREASON"), tCreate _ "||" _ $Parameter(..#ERROR, "MAPPINGTAKEN") _ "|" _ $Parameter(..#ERROR, "REASONMAPPINGTAKEN"), "the Save names the create tool, no parent, and the ConfigError code and sentence of a taken name")
}

/// <p>AC4. The create and the two sets ship enabled and the two deletes ship disabled, so with none stored the agent's call mints a proposal for
/// the create and the system set and is refused <code>GOVERNANCE.DISABLED</code> at dispatch for each delete, before anything is minted.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.userddlmappings.delete</code> set <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class>
/// -> the baseline assertion and the refusal assertion go red for that key.</p>
Method TestTheBaselineDefaultsAndTheAgentsDispatch()
{
    Set tRead = "OcuPilot.Test.ConfigSettingRead"
    Set tMarker = "ZZOCU" _ $Job
    Do ..VendorEntries("Config.SqlSysDatatypes", .tEntries)
    Set tHeld = $Order(tEntries(""))
    For tCase = $ListBuild("osmgmt.userddlmappings.create", tMarker, "%Library.String(MAXLEN=%1)", "minted"), $ListBuild("osmgmt.systemddlmappings.set", tHeld, "%Library.Integer", "minted"), $ListBuild("osmgmt.systemddlmappings.delete", tHeld, "", "refused"), $ListBuild("osmgmt.userddlmappings.delete", tMarker, "", "refused") {
        Set tKey = $List(tCase, 1)
        Set tEnabled = $Select($Extract(tKey, *-5, *) = "delete": "0|baseline", 1: "1|baseline")
        Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(tKey), tEnabled, tKey _ " ships as the baseline says")
        Set tInput = {"Name": ($List(tCase, 2)), "rationale": "probe", "expectedImpact": "probe"}
        If $List(tCase, 3) '= "" Do tInput.%Set("Value", $List(tCase, 3), "string")
        Set tAnswer = $ClassMethod(tRead, "Dispatched", tKey, tInput, .tContent)
        Do $$$AssertEquals(tAnswer, $List(tCase, 4), tKey _ ": the agent's call is " _ $List(tCase, 4) _ " under the baseline: " _ tContent)
        If $Extract(tKey, *-5, *) = "delete" {
            Do $$$AssertTrue(tContent [ "GOVERNANCE.DISABLED", tKey _ ": a delete is refused by governance, not by the target: " _ tContent)
        }
    }
    Kill tSettings
    Set tSettings("osmgmt.systemddlmappings.set") = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the system set key is stored disabled")
    Set tInput = {"Name": (tHeld), "Value": "%Library.Integer", "rationale": "probe", "expectedImpact": "probe"}
    Do $$$AssertEquals($ClassMethod(tRead, "Dispatched", "osmgmt.systemddlmappings.set", tInput, .tContent), "refused", "a disabled key refuses the same call at dispatch")
}

}
