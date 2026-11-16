/// <p>Pins Story 21.13's refusals and write shapes (AC1, AC2, AC3, AC4, AC5; AD-4, AD-29, AD-39, AD-54, AD-55, AD-59): every refusal of a create, a set
/// and a delete of a DDL mapping, asked of the port through <class>OcuPilot.Test.ConfigGateSeam</class>, of the Save route through
/// <class>OcuPilot.Test.DdlMappingSaveSeam</class> and of the agent's mint, each with nothing sent to the vendor; the arguments each of the three vendor
/// calls is given; the delete consequence and the destructive treatment a minted delete carries; the sentences pinned equal to their strings; and the
/// script each write renders.</p>
/// <p><b>Live-safe:</b> no mapping is created, changed or deleted: the entries the seam holds are never stored, and the only write is a proposal row the
/// mint stores and the test removes. <b>What it needs from the environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.DdlMappingRules Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter SAVE = "OcuPilot.Test.DdlMappingSaveSeam";

Parameter ERROR = "OcuPilot.Api.ConfigError";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

/// <p>The vendor classes the two endpoints name.</p>
Parameter USERCLASS = "Config.SqlUserDatatypes";

Parameter SYSTEMCLASS = "Config.SqlSysDatatypes";

/// <p>The matrix rows as <code>endpoint|request|name|datatype|held|expected</code>, where <code>held</code> is 1 when the seam holds the entry with the
/// datatype <code>%Library.Integer</code>, and expected is the refusal code or <code>ok</code>. A name <code>LONGNAME</code> is 65 characters,
/// <code>MAXNAME</code> is 64, and a datatype <code>LONGTYPE</code> is 257 characters and <code>MAXTYPE</code> 256. Names that need a control
/// character, an edge space or a symbol are written by <method>NameOf</method>.</p>
Parameter ROWS = "UserDDL|CREATE|ZZOCU1|%Library.String(MAXLEN=%1)|0|ok;UserDDL|CREATE|ZZOCU1|%Library.Integer|1|CONFIG.MAPPING.TAKEN;UserDDL|CREATE|MAXNAME|%Library.String|0|ok;UserDDL|CREATE|LONGNAME|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|EQUALS|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|COMMA|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|STAR|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|CARET|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|CONTROL|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|LEADSPACE|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|TRAILSPACE|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|EMPTYNAME|%Library.String|0|CONFIG.MAPPING.NAME;UserDDL|CREATE|ZZOCU1||0|CONFIG.SETTING.VALUE;UserDDL|CREATE|ZZOCU1|not a class|0|CONFIG.SETTING.VALUE;UserDDL|CREATE|ZZOCU1|1Class|0|CONFIG.SETTING.VALUE;UserDDL|CREATE|ZZOCU1|%Library.String(MAXLEN=%1|0|CONFIG.SETTING.VALUE;UserDDL|CREATE|ZZOCU1|LONGTYPE|0|CONFIG.SETTING.VALUE;UserDDL|CREATE|ZZOCU1|MAXTYPE|0|ok;UserDDL|CREATE|ZZOCU1|User.Some.Class(1,2)|0|ok;UserDDL|CREATE|ZZOCU1|CONTROLTYPE|0|CONFIG.SETTING.VALUE;UserDDL|SET|ZZOCU1|%Library.String|1|ok;UserDDL|SET|ZZOCU1|%Library.String|0|CONFIG.SETTING.NOTFOUND;UserDDL|SET|ZZOCU1|not a class|1|CONFIG.SETTING.VALUE;UserDDL|SET|ZZOCU1||1|CONFIG.SETTING.VALUE;SystemDDL|SET|ZZOCU1|%Library.String(MAXLEN=%1)|1|ok;SystemDDL|SET|ZZOCU1|%Library.String|0|CONFIG.SETTING.NOTFOUND;SystemDDL|SET|ZZOCU1|LONGTYPE|1|CONFIG.SETTING.VALUE;SystemDDL|SET|ZZOCU1|x y|1|CONFIG.SETTING.VALUE;UserDDL|DELETE|ZZOCU1||1|ok;UserDDL|DELETE|ZZOCU1||0|CONFIG.SETTING.NOTFOUND;SystemDDL|DELETE|ZZOCU1||1|ok;SystemDDL|DELETE|ZZOCU1||0|CONFIG.SETTING.NOTFOUND;SystemDDL|CREATE|ZZOCU1|%Library.String|0|NOTIMPLEMENTED";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>Hold every pair the port's writes name, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The name this job's rows hold or find absent: <code>ZZOCU</code>, the job number and <code>M</code>, so no instance entry of another run can be it.</p>
ClassMethod Held() As %String
{
    Quit "ZZOCU" _ $Job _ "M"
}

/// <p>The name a matrix row spells with <var>pToken</var>: a long one, one made of a symbol or a control character, one with a space at an edge, or the
/// token itself.</p>
ClassMethod NameOf(pToken As %String) As %String
{
    If pToken = "LONGNAME" Quit $Translate($Justify("", 65), " ", "q")
    If pToken = "MAXNAME" Quit $Translate($Justify("", 64), " ", "q")
    If pToken = "EQUALS" Quit "ZZ=OCU"
    If pToken = "COMMA" Quit "ZZ,OCU"
    If pToken = "STAR" Quit "ZZ*OCU"
    If pToken = "CARET" Quit "ZZ^OCU"
    If pToken = "CONTROL" Quit "ZZ" _ $Char(7) _ "OCU"
    If pToken = "LEADSPACE" Quit " ZZOCU"
    If pToken = "TRAILSPACE" Quit "ZZOCU "
    If pToken = "EMPTYNAME" Quit ""
    If pToken = "ZZOCU1" Quit ..Held()
    Quit pToken
}

/// <p>The datatype a matrix row spells with <var>pToken</var>.</p>
ClassMethod TypeOf(pToken As %String) As %String
{
    If pToken = "LONGTYPE" Quit "%Library." _ $Translate($Justify("", 248), " ", "x")
    If pToken = "MAXTYPE" Quit "%Library." _ $Translate($Justify("", 247), " ", "x")
    If pToken = "CONTROLTYPE" Quit "%Library.Str" _ $Char(9) _ "ing"
    Quit pToken
}

/// <p>The request <var>pRequest</var> of <var>pEndpoint</var> for the entry <var>pName</var> with the datatype <var>pType</var>, through the seam,
/// answering <code>status|code</code>.</p>
ClassMethod Send(pEndpoint As %String, pRequest As %String, pName As %String, pType As %String, Output pFault As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tBody = $Select(pRequest = "DELETE": "", 1: {"Value": (pType)})
    Set tSC = $ClassMethod(..#SEAM, "Invoke", pEndpoint, pRequest, .tQuery, tBody, .tOut, .tHttp, .pFault)
    Quit tHttp _ "|" _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The call the seam records for an accepted <var>pRequest</var> of <var>pEndpoint</var>, as <code>operation|class|name|datatype</code>.</p>
ClassMethod Recorded(pEndpoint As %String, pRequest As %String, pName As %String, pType As %String) As %String
{
    Set tClass = $Select(pEndpoint = "SystemDDL": ..#SYSTEMCLASS, 1: ..#USERCLASS)
    Quit $Case(pRequest, "CREATE": "CREATE", "SET": "MODIFY", : "DELETE") _ "|" _ tClass _ "|" _ pName _ "|" _ $Select(pRequest = "DELETE": "", 1: pType)
}

/// <p><b>AC1, AC2, AC3.</b> Every row of the matrix at the port: a held name, an absent name, a name or a datatype the rules refuse and a create of a
/// system mapping are each answered on the code and status the matrix names with nothing sent, and everything else is sent once, as the vendor call
/// its request makes, with the name and the datatype as the caller typed them.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>'s <code>NameCode</code> admits <code>*</code> -> the <code>STAR</code>
/// row goes red, with a vendor call recorded.</p>
Method TestEveryMatrixRowIsAnsweredOnItsCodeAndSendsNothingWhenRefused()
{
    Do ..HoldAll()
    For tI = 1:1:$Length(..#ROWS, ";") {
        Set tRow = $Piece(..#ROWS, ";", tI)
        Do $ClassMethod(..#SEAM, "Reset")
        Set tEndpoint = $Piece(tRow, "|", 1)
        Set tRequest = $Piece(tRow, "|", 2)
        Set tName = ..NameOf($Piece(tRow, "|", 3))
        Set tType = ..TypeOf($Piece(tRow, "|", 4))
        Set tExpected = $Piece(tRow, "|", 6)
        If $Piece(tRow, "|", 5) Do $ClassMethod(..#SEAM, "HoldEntry", tName, "%Library.Integer")
        Set tAnswer = ..Send(tEndpoint, tRequest, tName, tType, .tFault)
        Set tLabel = tEndpoint _ " " _ tRequest _ " '" _ $Extract($ZStrip(tName, "*C"), 1, 20) _ "' " _ $Extract(tType, 1, 24)
        If tExpected = "ok" {
            Do $$$AssertEquals(tAnswer, "200|", tLabel _ ": accepted")
            Do $$$AssertEquals($ClassMethod(..#SEAM, "Entries"), ..Recorded(tEndpoint, tRequest, tName, tType), tLabel _ ": sent once, as the vendor call its request makes")
        } ElseIf tExpected = "NOTIMPLEMENTED" {
            Do $$$AssertEquals(tAnswer _ "|" _ $ClassMethod(..#SEAM, "Entries"), "501|PORT.NOTIMPLEMENTED|", tLabel _ ": 501 and nothing sent")
        } Else {
            Do $$$AssertEquals(tAnswer, $ClassMethod(..#ERROR, "HttpStatusFor", tExpected) _ "|" _ tExpected, tLabel _ ": " _ tExpected)
            Do $$$AssertEquals($ClassMethod(..#SEAM, "Entries"), "", tLabel _ ": nothing reached the vendor")
        }
    }
}

/// <p><b>AC1.</b> A set sends the complete property set the vendor's <code>Get</code> answered with the datatype changed, and nothing else changed: the
/// keys sent are exactly the keys read, and a vendor refusal of a value the rules passed is answered 400 <code>CONFIG.SETTING.VALUE</code> for each of the
/// three calls, with the raw status in the log and not on the wire.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>ModifyEntry</code> sends the fresh read's datatype instead of the new one ->
/// the recorded datatype assertion goes red.</p>
Method TestASetSendsGetsPropertySetWithTheDatatypeChangedAndAVendorRefusalIs400()
{
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "HoldEntry", ..Held(), "%Library.Integer", "Flags")
    Set tAnswer = ..Send("UserDDL", "SET", ..Held(), "%Library.String", .tFault)
    Do $$$AssertEquals(tAnswer _ "|" _ $ClassMethod(..#SEAM, "Entries") _ "|" _ $ClassMethod(..#SEAM, "SentEntryKeys"), "200||MODIFY|Config.SqlUserDatatypes|" _ ..Held() _ "|%Library.String|Datatype,Flags", "the set sends the entry's own property set, every key the read answered, with the new datatype")
    For tRequest = "SET", "CREATE", "DELETE" {
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "VendorRefuses")
        If tRequest '= "CREATE" Do $ClassMethod(..#SEAM, "HoldEntry", ..Held(), "%Library.Integer")
        Set tAnswer = ..Send("UserDDL", tRequest, ..Held(), "%Library.String", .tFault)
        Do $$$AssertEquals(tAnswer _ "|" _ tFault.%Get("reason"), "400|CONFIG.SETTING.VALUE|" _ $Parameter(..#ERROR, "REASONSETTINGVALUE"), tRequest _ ": a vendor refusal is answered on the published sentence, not the vendor's")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Faults"), "CONFIG.SETTING.VALUE|error", tRequest _ ": and the raw status reached the log")
    }
}

/// <p><b>AC3.</b> The Save route's order and refusals: a name or a datatype the rules refuse is a violation on its own field, a datatype that is not text is
/// <code>PORT.FIELD.SHAPE</code>, a member the create tool does not settle is 400 <code>PORT.FIELD.UNEXPECTED</code>, a held name is 409
/// <code>CONFIG.MAPPING.TAKEN</code>, none of them sends anything, and a good one sends the create once.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.DdlMappingSave</class>'s <code>Violations</code> asks no name rule -> the name rows go red.</p>
Method TestTheSaveRouteRefusesOnTheFieldAndSendsNothingWhenRefused()
{
    Do ..HoldAll()
    For tCase = $ListBuild("", "%Library.String", "Name|CONFIG.MAPPING.NAME"), $ListBuild("ZZ*OCU", "%Library.String", "Name|CONFIG.MAPPING.NAME"), $ListBuild(..Held(), "not a class", "Value|CONFIG.SETTING.VALUE"), $ListBuild("ZZ,OCU", "x y", "Name|CONFIG.MAPPING.NAME,Value|CONFIG.SETTING.VALUE") {
        Set tFields = {"Value": ($List(tCase, 2))}
        Set tSC = $ClassMethod(..#SAVE, "Create", "", $List(tCase, 1), tFields, .tHttp, .tFault, .tViolations, .tReadBack)
        Set tSeen = ""
        For tV = 1:1:+$Get(tViolations) Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ $List(tViolations(tV), 1) _ "|" _ $List(tViolations(tV), 2)
        Do $$$AssertEquals(tSeen _ "|" _ $ClassMethod(..#SEAM, "Entries"), $List(tCase, 3) _ "|", "'" _ $List(tCase, 1) _ "' with '" _ $List(tCase, 2) _ "': refused on its field, nothing sent")
    }
    Set tSC = $ClassMethod(..#SAVE, "Create", "", ..Held(), {"Value": 5}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertEquals($Get(tViolations) _ "|" _ $List(tViolations(1), 1) _ "|" _ $List(tViolations(1), 2), "1|Value|PORT.FIELD.SHAPE", "a datatype that is not text is a shape violation on Value")
    Set tSC = $ClassMethod(..#SAVE, "Create", "", ..Held(), {"Value": "%Library.String", "Comments": "x"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ $ClassMethod(..#SEAM, "Entries"), "400|PORT.FIELD.UNEXPECTED|", "a member the create tool does not settle is refused before anything is sent")
    Do $ClassMethod(..#SEAM, "HoldEntry", ..Held(), "%Library.Integer")
    Set tSC = $ClassMethod(..#SAVE, "Create", "", ..Held(), {"Value": "%Library.String"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ tFault.%Get("reason") _ "|" _ $ClassMethod(..#SEAM, "Entries"), "409|CONFIG.MAPPING.TAKEN|" _ $Parameter(..#ERROR, "REASONMAPPINGTAKEN") _ "|", "a held name is 409 on the published sentence, nothing sent")
    Do $ClassMethod(..#SEAM, "Reset")
    Set tSC = $ClassMethod(..#SAVE, "Create", "", ..Held(), {"Value": "%Library.String(MAXLEN=%1)"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tViolations) _ "|" _ $ClassMethod(..#SEAM, "Entries"), "1|0|CREATE|Config.SqlUserDatatypes|" _ ..Held() _ "|%Library.String(MAXLEN=%1)", "a good mapping sends the create once: " _ $System.Status.GetErrorText(tSC))
}

/// <p><b>AC3, AC4, AC5.</b> The agent's mint refuses what the port refuses, each on its published sentence, before a proposal is stored: a name or a datatype
/// the rules refuse for a create, a datatype for a set, an absent entry for a set and for a delete; and a good call mints, the delete's card destructive
/// and carrying the delete consequence, the create's and the set's carrying none.</p>
/// <p>Mutation (Rule 19): <code>DdlMappingDelete</code> declares <code>DESTRUCTIVE</code> 0 -> the destructive assertion goes red.</p>
Method TestTheMintRefusesOnTheSentenceAndAGoodCallMintsItsCard()
{
    Do ##class(OcuPilot.Test.ConfigSettingRead).RowsByName(##class(OcuPilot.Test.ConfigSettingRead).Read("DdlSystemMappingList"), .tRows)
    Set tHeld = $Order(tRows(""))
    Do $$$AssertTrue(tHeld '= "", "the instance holds a system mapping the mint can read")
    If tHeld = "" Quit
    Set tCreate = "OcuPilot.Screen.Tool.DdlUserMappingCreate"
    For tCase = $ListBuild("ZZ*OCU", "%Library.String", $Parameter(..#ERROR, "REASONMAPPINGNAME")), $ListBuild(..Held(), "not a class", $Parameter(..#ERROR, "REASONSETTINGVALUE")), $ListBuild($Translate($Justify("", 65), " ", "q"), "%Library.String", $Parameter(..#ERROR, "REASONMAPPINGNAME")) {
        Set tArgs = {"Name": ($List(tCase, 1))}
        Do tArgs.%Set("Value", $List(tCase, 2), "string")
        Set tSC = $ClassMethod(..#AGENT, "Mint", tCreate, $List(tCase, 1), tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ tProblem, "0|" _ $List(tCase, 3), "a create of '" _ $Extract($List(tCase, 1), 1, 12) _ "' with '" _ $List(tCase, 2) _ "' is refused: " _ tProblem)
    }
    Set tSystemSet = "OcuPilot.Screen.Tool.DdlSystemMappingSet"
    Set tArgs = {"Name": (tHeld), "Value": "not a class"}
    Set tSC = $ClassMethod(..#AGENT, "Mint", tSystemSet, tHeld, tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ tProblem, "0|" _ $Parameter(..#ERROR, "REASONSETTINGVALUE"), "a set to a datatype that is not a class is refused on its sentence: " _ tProblem)
    Set tArgs = {"Name": "ZZNOSUCHMAPPING", "Value": "%Library.String"}
    Set tSC = $ClassMethod(..#AGENT, "Mint", tSystemSet, "ZZNOSUCHMAPPING", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ tProblem, "0|'ZZNOSUCHMAPPING' is not present on this instance", "a set of an entry the instance does not hold is refused on the mint's own sentence: " _ tProblem)
    Set tArgs = {"Name": "ZZNOSUCHMAPPING"}
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.DdlUserMappingDelete", "ZZNOSUCHMAPPING", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ tProblem, "0|'ZZNOSUCHMAPPING' is not present on this instance", "a delete of an entry the instance does not hold is refused on the mint's own sentence: " _ tProblem)
    Set tArgs = {"Name": (..Held())}
    Do tArgs.%Set("Value", "%Library.String(MAXLEN=%1)", "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", tCreate, ..Held(), tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ ##class(OcuPilot.Test.EcpSettingsWrite).Consequence($Get(tProposal)), "1|", "a good create mints a card that states no consequence: " _ tProblem)
    Do $$$AssertEquals(##class(OcuPilot.Test.DdlMappingRead).Stored($Get(tProposal), .tValues) _ "|" _ $Get(tValues("destructive")), "1|0", "and is not destructive")
    Set tArgs = {"Name": (tHeld), "Value": "%Library.Integer"}
    Set tSC = $ClassMethod(..#AGENT, "Mint", tSystemSet, tHeld, tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject($Get(tProposal)) _ "|" _ ##class(OcuPilot.Test.EcpSettingsWrite).Consequence($Get(tProposal)), "1|", "a good set mints a card that states no consequence: " _ tProblem)
    For tDelete = "OcuPilot.Screen.Tool.DdlSystemMappingDelete" {
        Set tArgs = {"Name": (tHeld)}
        Set tSC = $ClassMethod(..#AGENT, "Mint", tDelete, tHeld, tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($IsObject($Get(tProposal)), 1, "a delete of a held entry mints, whatever its governance key says, because the key is asked at dispatch: " _ tProblem)
        Do $$$AssertEquals(##class(OcuPilot.Test.DdlMappingRead).Stored($Get(tProposal), .tValues) _ "|" _ $Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence")), "1|1|" _ $Parameter(..#ERROR, "MAPPINGDELETE"), "and is destructive and carries the delete consequence")
        Set tDiff = ##class(%DynamicArray).%FromJSON($Get(tValues("diff")))
        Set tFields = ""
        For tD = 0:1:tDiff.%Size() - 1 Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tDiff.%Get(tD).%Get("field") _ "=" _ tDiff.%Get(tD).%Get("removed")
        Do $$$AssertEquals(tFields, "Name=1,Value=1", "its card lists what the entry held, both rows removed")
    }
}

/// <p>AD-29, AD-39, AC5. The three codes carry their published sentences, the two refusals their statuses, the delete consequence none, the dispatches by
/// prefix reach them, the delete tools and the Save name the codes, and the datatype sentence is the one a row's <code>Accepts</code> reads.</p>
Method TestTheMappingCodesArePublished()
{
    For tCase = $ListBuild("CONFIG.MAPPING.TAKEN", "This instance already holds a user DDL mapping of that name.", 409), $ListBuild("CONFIG.MAPPING.NAME", "A name is 1 to 64 characters, with no =, comma, *, ^, control character, or space at either end.", 400), $ListBuild("CONFIG.MAPPING.DELETE", "DDL that names this type no longer maps it to this datatype.", 0) {
        Set tCode = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", tCode) _ "|" _ $ClassMethod(..#ERROR, "HttpStatusFor", tCode), $List(tCase, 2) _ "|" _ $List(tCase, 3), tCode _ ": its sentence and its status")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode) _ "|" _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), $List(tCase, 2) _ "|" _ $List(tCase, 2), tCode _ ": and both dispatches reach it")
    }
    Do $$$AssertEquals($ClassMethod(..#ERROR, "SlugFor", "CONFIG.MAPPING.TAKEN") _ "|" _ $ClassMethod(..#ERROR, "SlugFor", "CONFIG.MAPPING.NAME"), ##class(OcuPilot.Api.Error).#CONFLICT _ "|" _ ##class(OcuPilot.Api.Error).#BADREQUEST, "the taken name is a conflict and the bad name a bad request")
    Do $$$AssertEquals($ClassMethod(..#PORT, "AcceptsOf", $ClassMethod(..#PORT, "DatatypeLimits")), $Parameter(..#ERROR, "ACCEPTSDATATYPE"), "a row's accepts line is the datatype sentence")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.OsMgmt.DdlMappingSave", "NAMEEMPTYCODE"), $Parameter(..#ERROR, "MAPPINGNAME"), "the Save's empty-name code is the name code")
}

/// <p>AD-59. A create, a set and a delete render as the vendor's own calls with the name and the datatype as string literals: <code>Create</code> with the
/// property array, <code>Get</code>, the key and <code>Modify</code>, and <code>Delete</code>; a name or a datatype holding a quote or a control character is
/// escaped, a read renders none, and the script of a create of a system mapping, which the port does not serve, renders none.</p>
Method TestEachWriteRendersItsVendorCallsAsAScript()
{
    Set tHead = " Set $NAMESPACE = ""%SYS"""
    Kill tQuery
    Set tQuery("name") = "ZZOCU1"
    Set tText = $ClassMethod(..#PORT, "Snippet", "UserDDL", "CREATE", .tQuery, {"Value": "%Library.String(MAXLEN=%1)"}).%Get(0).%Get("text")
    Do $$$AssertEquals(tText, tHead _ $Char(10) _ " Set tProps(""Datatype"") = ""%Library.String(MAXLEN=%1)""" _ $Char(10) _ " Set tSC = ##class(Config.SqlUserDatatypes).Create(""ZZOCU1"", .tProps)", "a create is the property and the Create")
    Set tText = $ClassMethod(..#PORT, "Snippet", "SystemDDL", "SET", .tQuery, {"Value": "%Library.Integer"}).%Get(0).%Get("text")
    Do $$$AssertEquals(tText, tHead _ $Char(10) _ " Set tSC = ##class(Config.SqlSysDatatypes).Get(""ZZOCU1"", .tProps)" _ $Char(10) _ " Set tProps(""Datatype"") = ""%Library.Integer""" _ $Char(10) _ " Set tSC = ##class(Config.SqlSysDatatypes).Modify(""ZZOCU1"", .tProps)", "a set is Get, the one key and Modify")
    Set tText = $ClassMethod(..#PORT, "Snippet", "UserDDL", "DELETE", .tQuery, "").%Get(0).%Get("text")
    Do $$$AssertEquals(tText, tHead _ $Char(10) _ " Set tSC = ##class(Config.SqlUserDatatypes).Delete(""ZZOCU1"")", "a delete is the Delete")
    Set tQuery("name") = "Z""Q" _ $Char(7)
    Set tText = $ClassMethod(..#PORT, "Snippet", "UserDDL", "DELETE", .tQuery, "").%Get(0).%Get("text")
    Do $$$AssertEquals(tText, tHead _ $Char(10) _ " Set tSC = ##class(Config.SqlUserDatatypes).Delete(""Z""""Q""_$Char(7)_"""")", "a hostile name is a string literal, so nothing the query carries runs as code")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "SystemDDL", "CREATE", .tQuery, {"Value": "x"}).%Size() _ "|" _ $ClassMethod(..#PORT, "Snippet", "UserDDL", "GET", .tQuery).%Size(), "0|0", "a create the port does not serve and a read render none")
}

}
