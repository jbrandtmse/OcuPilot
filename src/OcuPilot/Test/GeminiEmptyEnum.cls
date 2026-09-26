/// <p>DW-1600: no Gemini function declaration carries an empty <code>enum</code> member. Over the
/// whole registered tool set, <method>OcuPilot.Kernel.Provider.ToolDefAdapter.ToGemini</method>
/// respells each <code>""</code> member as
/// <parameter>OcuPilot.Kernel.Provider.ToolDefAdapter.GEMINIEMPTYENUM</parameter> and keeps the
/// member count; <class>OcuPilot.Kernel.Provider.MessageAdapter</class> reads the respelling back
/// as <code>""</code> and writes it again in replayed history, on exactly the (tool, argument)
/// pairs the request respelled; and the Gemini adapter's recorded body carries no empty member.</p>
/// <p><b>Needs nothing of the environment</b>: the registry is read in process, and the adapter leg
/// runs through <class>OcuPilot.Test.GeminiStub</class> with no socket opened.</p>
Class OcuPilot.Test.GeminiEmptyEnum Extends %UnitTest.TestCase
{

Parameter TOOLDEFS = "OcuPilot.Kernel.Provider.ToolDefAdapter";

Parameter MESSAGES = "OcuPilot.Kernel.Provider.MessageAdapter";

/// <p>A tool name no registry holds, standing for an array-valued argument in the map.</p>
Parameter LISTTOOL = "probe_list_pick";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(##class(OcuPilot.Test.GeminiAdapter).#PROBEKEY)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Quit $$$OK
}

/// <p>The navigate tool's wire name.</p>
ClassMethod NavigateWire() As %String
{
    Quit ##class(OcuPilot.Screen.Tool.Registry).WireName(##class(OcuPilot.Screen.Tool.Navigate).#TOOLNAME)
}

/// <p>The respelling.</p>
ClassMethod Empty() As %String
{
    Quit $Parameter(..#TOOLDEFS, "GEMINIEMPTYENUM")
}

/// <p>Every <code>enum</code> array under <var>pNode</var>, at any depth, as
/// <code>pFound(path) = the array</code>, the path the dotted member names from
/// <var>pNode</var>.</p>
ClassMethod Enums(pNode As %RawString, pPath As %String, ByRef pFound)
{
    If '$IsObject(pNode) Quit
    Set tIterator = pNode.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tPath = $Select(pPath = "": tKey, 1: pPath _ "." _ tKey)
        If '$IsObject(tValue) Continue
        If (tKey = "enum") && tValue.%IsA("%Library.DynamicArray") {
            Set pFound(tPath) = tValue
            Continue
        }
        Do ..Enums(tValue, tPath, .pFound)
    }
}

/// <p>How many members of <var>pEnum</var> are the string <var>pValue</var>.</p>
ClassMethod Holding(pEnum As %DynamicArray, pValue As %String) As %Integer
{
    Set tCount = 0
    Set tIterator = pEnum.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMember, .tType) {
        If (tType = "string") && (tMember = pValue) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The map a request whose tools are the registry's own plus <parameter>LISTTOOL</parameter>
/// would carry, as JSON text.</p>
ClassMethod Map() As %String
{
    Set tMap = {}
    Set tNavigate = {}
    Do tNavigate.%Set("route", "value", "string")
    Do tMap.%Set(..NavigateWire(), tNavigate)
    Set tList = {}
    Do tList.%Set("names", "items", "string")
    Do tMap.%Set(..#LISTTOOL, tList)
    Quit tMap.%ToJSON()
}

/// <p>Across every registered tool, no Gemini declaration carries an empty <code>enum</code>
/// member; each enum that held one keeps its count and holds the respelling instead; navigate's
/// <code>route</code> is one of them; no registered enum already holds the respelling; and every
/// respelled enum is a pair <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiEmptyEnumArgs</method>
/// names, so each one decodes back.</p>
/// <p>Mutation: remove the <code>enum</code> branch from
/// <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiSchema</method> -- red on the first two
/// assertions over navigate's route.</p>
Method TestNoGeminiDeclarationCarriesAnEmptyMember()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "the registry's provider tool set builds")
    Do $$$AssertTrue(+$Get(tTools) > 0, "and is not empty: " _ +$Get(tTools))
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tTools, .tDeclarations), "the Gemini translation builds")
    If '$IsObject($Get(tDeclarations)) || (tDeclarations.%Size() = 0) Quit
    Set tFunctions = tDeclarations.%Get(0).%Get("functionDeclarations")
    Do $$$AssertEquals(tFunctions.%Size(), +tTools, "one declaration per tool")

    Set tMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tTools)
    Set tEnums = 0
    Set tRespelled = 0
    Set tUnmapped = ""
    Set tEmptyLeft = ""
    Set tAlreadyHeld = ""
    Set tNavigateRoute = ""
    For tI = 1:1:+tTools {
        Kill tCanonical, tGemini
        Do ..Enums($ClassMethod(..#TOOLDEFS, "SchemaOf", $Get(tTools(tI, "inputSchema"))), "", .tCanonical)
        Do ..Enums(tFunctions.%Get(tI - 1).%Get("parameters"), "", .tGemini)
        Set tPath = ""
        For {
            Set tPath = $Order(tCanonical(tPath))
            If tPath = "" Quit
            Set tEnums = tEnums + 1
            If ..Holding(tCanonical(tPath), ..Empty()) Set tAlreadyHeld = tAlreadyHeld _ " " _ tTools(tI, "name") _ ":" _ tPath
            If '$Data(tGemini(tPath)) {
                Set tEmptyLeft = tEmptyLeft _ " " _ tTools(tI, "name") _ ":" _ tPath _ "(missing)"
                Continue
            }
            If ..Holding(tGemini(tPath), "") Set tEmptyLeft = tEmptyLeft _ " " _ tTools(tI, "name") _ ":" _ tPath
            Set tEmpties = ..Holding(tCanonical(tPath), "")
            If 'tEmpties Continue
            Set tRespelled = tRespelled + 1
            Set tArg = ""
            Set tKind = ""
            If $Match(tPath, "properties\.[^.]+\.enum") Set tArg = $Piece(tPath, ".", 2), tKind = "value"
            If $Match(tPath, "properties\.[^.]+\.items\.enum") Set tArg = $Piece(tPath, ".", 2), tKind = "items"
            Set tMapped = ""
            If (tArg '= "") && $IsObject(tMap.%Get(tTools(tI, "name"))) Set tMapped = tMap.%Get(tTools(tI, "name")).%Get(tArg)
            If (tKind = "") || (tMapped '= tKind) Set tUnmapped = tUnmapped _ " " _ tTools(tI, "name") _ ":" _ tPath
            Do $$$AssertEquals(tGemini(tPath).%Size(), tCanonical(tPath).%Size(), tTools(tI, "name") _ ":" _ tPath _ " keeps its member count")
            Do $$$AssertEquals(..Holding(tGemini(tPath), ..Empty()), tEmpties, tTools(tI, "name") _ ":" _ tPath _ " holds the respelling where the empty member was")
            If (tTools(tI, "name") = ..NavigateWire()) && (tPath = "properties.route.enum") Set tNavigateRoute = tGemini(tPath).%ToJSON()
        }
    }
    Do $$$AssertTrue(tEnums > 0, "the sweep read enums rather than an empty roster: " _ tEnums)
    Do $$$AssertEquals(tEmptyLeft, "", "no Gemini declaration carries an empty enum member")
    Do $$$AssertTrue(tRespelled > 0, "at least one enum was respelled: " _ tRespelled)
    Do $$$AssertTrue(tNavigateRoute [ ("""" _ ..Empty() _ """"), "navigate's route enum carries the respelling: " _ tNavigateRoute)
    Do $$$AssertEquals(tAlreadyHeld, "", "no registered enum already holds the respelling, so decoding it is unambiguous")
    Do $$$AssertEquals(tUnmapped, "", "every respelled enum is a pair the map names, so none is respelled one way only")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tMap, ..NavigateWire() _ ".route"), "value", "and the map names navigate's route as respelled: " _ tMap.%ToJSON())
}

/// <p>A model's respelling reaches the canonical input as <code>""</code> on a mapped (tool,
/// argument) pair, per element for an array argument, and on no other.</p>
/// <p>Mutation: skip the decode in
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.GeminiToCanonical</method> -- red on the route
/// and the array element.</p>
Method TestTheRespellingDecodesOnItsOwnPairsOnly()
{
    Set tEmpty = ..Empty()
    Set tCalls = []
    Set tCall = {"functionCall": {"name": "", "args": {}}}
    Do tCall.functionCall.%Set("name", ..NavigateWire(), "string")
    Do tCall.functionCall.args.%Set("route", tEmpty, "string")
    Do tCall.functionCall.args.%Set("criterion", tEmpty, "string")
    Do tCalls.%Push(tCall)
    Set tList = {"functionCall": {"name": "", "args": {"names": []}}}
    Do tList.functionCall.%Set("name", ..#LISTTOOL, "string")
    Do tList.functionCall.args.names.%Push(tEmpty, "string")
    Do tList.functionCall.args.names.%Push("a", "string")
    Do tCalls.%Push(tList)
    Set tOther = {"functionCall": {"name": "probe_other_tool", "args": {}}}
    Do tOther.functionCall.args.%Set("route", tEmpty, "string")
    Do tCalls.%Push(tOther)
    Set tBody = {"candidates": [{"content": {"role": "model", "parts": []}, "finishReason": "STOP"}]}
    Do tBody.candidates.%Get(0).content.%Set("parts", tCalls)

    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", tBody.%ToJSON(), tResponse, ..Map()), "the reply reads")
    Set tUses = ##class(%DynamicArray).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tUses, "0.input.route"), "", "navigate's route reaches the canonical input as empty")
    Do $$$AssertEquals(tUses.%Get(0).input.%GetTypeOf("route"), "string", "as an empty string")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tUses, "0.input.criterion"), tEmpty, "an unmapped argument of the same tool keeps the text verbatim")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tUses, "1.input.names.0"), "", "an array argument is decoded per element")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tUses, "1.input.names.1"), "a", "and leaves the other elements alone")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tUses, "2.input.route"), tEmpty, "the same argument name on an unmapped tool keeps the text verbatim")

    Set tUnmapped = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", tBody.%ToJSON(), tUnmapped), "the reply reads with no map")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(##class(%DynamicArray).%FromJSON(tUnmapped.ToolCallsJson), "0.input.route"), tEmpty, "and a caller with no map is unchanged")
}

/// <p>Replayed history writes <code>""</code> back as the respelling on the same pairs, and the
/// round trip closes: decoding what was encoded gives back the canonical input.</p>
/// <p>Mutation: skip the encode in
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.CanonicalToGemini</method> -- red on the
/// replayed route.</p>
Method TestReplayedHistoryRespellsTheSamePairs()
{
    Set tEmpty = ..Empty()
    Set tInput = {"route": "", "criterion": ""}
    Set tListInput = {"names": ["", "a"]}
    Set tBlocks = []
    Set tUse = {"type": "tool_use", "id": "c1"}
    Do tUse.%Set("name", ..NavigateWire(), "string")
    Do tUse.%Set("input", tInput)
    Do tBlocks.%Push(tUse)
    Set tListUse = {"type": "tool_use", "id": "c2"}
    Do tListUse.%Set("name", ..#LISTTOOL, "string")
    Do tListUse.%Set("input", tListInput)
    Do tBlocks.%Push(tListUse)
    Kill tMessages
    Set tMessages = 3
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "go home"
    Set tMessages(2, "role") = "assistant"
    Set tMessages(2, "blocks") = tBlocks.%ToJSON()
    Set tMessages(3, "role") = "user"
    Set tMessages(3, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""c1"",""content"":""ok""},{""type"":""tool_result"",""tool_use_id"":""c2"",""content"":""ok""}]"

    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tContents, .tSystem, ..Map()), "the history translates")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tContents, "1.parts.1.functionCall.args.names"), "(object)", "the replayed calls carry their arguments: " _ tContents.%ToJSON())
    If ##class(OcuPilot.Test.Adapter).Path(tContents, "1.parts.1.functionCall.args.names") '= "(object)" Quit
    Set tParts = tContents.%Get(1).parts
    Do $$$AssertEquals(tParts.%Get(0).functionCall.args.route, tEmpty, "the mapped argument is written as the respelling the declaration carried")
    Do $$$AssertEquals(tParts.%Get(0).functionCall.args.criterion, "", "an unmapped argument is written as it is")
    Do $$$AssertEquals(tParts.%Get(1).functionCall.args.names.%ToJSON(), "[""" _ tEmpty _ """,""a""]", "and an array argument per element")
    Do $$$AssertEquals(tBlocks.%Get(0).input.route, "", "the canonical history itself is not changed")

    Set tBody = {"candidates": [{"content": {"role": "model", "parts": []}, "finishReason": "STOP"}]}
    Do tBody.candidates.%Get(0).content.%Set("parts", tParts)
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", tBody.%ToJSON(), tResponse, ..Map()), "the replayed parts read back")
    Set tUses = ##class(%DynamicArray).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tUses.%Get(0).input.%ToJSON(), tInput.%ToJSON(), "the round trip gives back the canonical input")
    Do $$$AssertEquals(tUses.%Get(1).input.%ToJSON(), tListInput.%ToJSON(), "for the array argument too")

    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tPlain, .tSystem), "the history translates with no map")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tPlain, "1.parts.0.functionCall.args.route"), "", "and a caller with no map is unchanged")
}

/// <p>Through the Gemini adapter with the registry's whole tool set: the recorded request carries
/// no empty enum member, and a reply choosing the respelled route reaches the turn as
/// <code>""</code>.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.Gemini.MapResponse</method> pass no map --
/// red on the route.</p>
Method TestTheGeminiAdapterSendsNoEmptyMember()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row("gemini", .tRow), 1, "the shipped gemini row is readable")
    If '$IsObject($Get(tRow)) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "the registry's provider tool set builds")
    Set tReply = {"candidates": [{"content": {"role": "model", "parts": [{"functionCall": {"name": "", "args": {}}}]}, "finishReason": "STOP"}]}
    Set tCall = tReply.candidates.%Get(0).content.parts.%Get(0).functionCall
    Do tCall.%Set("name", ..NavigateWire(), "string")
    Do tCall.args.%Set("route", ..Empty(), "string")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, tReply.%ToJSON())
    Do ##class(OcuPilot.Test.GeminiAdapter).DirectValues(tRow, .tValues)
    Do ##class(OcuPilot.Test.Provider).Messages(.tMessages)
    Do ##class(OcuPilot.Test.Provider).Settings(.tSettings, 1)
    Set tAdapter = ##class(OcuPilot.Test.GeminiAdapter).Adapter()
    Do $$$AssertStatusOK(tAdapter.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the call returns $$$OK")
    Set tAdapter = ""
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""), "", "with no fault")

    Set tSent = ##class(OcuPilot.Test.GeminiAdapter).RecordedBody(1)
    Do $$$AssertTrue($IsObject(tSent), "the request body was recorded")
    If '$IsObject(tSent) Quit
    Kill tFound
    Do ..Enums(tSent.%Get("tools"), "", .tFound)
    Set tLeft = ""
    Set tRespelled = 0
    Set tPath = ""
    For {
        Set tPath = $Order(tFound(tPath))
        If tPath = "" Quit
        If ..Holding(tFound(tPath), "") Set tLeft = tLeft _ " " _ tPath
        If ..Holding(tFound(tPath), ..Empty()) Set tRespelled = tRespelled + 1
    }
    Do $$$AssertEquals(tLeft, "", "the recorded request carries no empty enum member")
    Do $$$AssertTrue(tRespelled > 0, "and carries the respelling instead")
    If '$IsObject($Get(tResponse)) Quit
    Set tUses = ##class(%DynamicArray).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tUses.%Get(0).input.%GetTypeOf("route"), "string", "the model's navigate call reaches the turn")
    Do $$$AssertEquals(tUses.%Get(0).input.route, "", "with Home's empty route")
}

/// <p>The map names an array argument whose <code>items.enum</code> holds <code>""</code> as kind
/// <code>items</code>, and leaves an enum with no empty member out.</p>
/// <p>Mutation: remove the <code>items</code> branch from
/// <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiEmptyEnumArgs</method> -- red.</p>
Method TestTheMapNamesAnArrayArgument()
{
    Kill tTools
    Set tTools = 1
    Set tTools(1, "name") = ..#LISTTOOL
    Set tTools(1, "description") = "probe"
    Set tTools(1, "inputSchema") = "{""type"":""object"",""properties"":{""names"":{""type"":""array"",""items"":{""type"":""string"",""enum"":["""",""a""]}},""plain"":{""type"":""string"",""enum"":[""a"",""b""]}}}"
    Set tMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tTools)
    Do $$$AssertEquals(tMap.%ToJSON(), "{""" _ ..#LISTTOOL _ """:{""names"":""items""}}", "the array argument is named as kind items, and nothing else is named")
}

/// <p>Through the Gemini adapter, history that replays a navigate call to Home is sent with the
/// respelling the declaration carries, never with <code>""</code>.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.Gemini.CallMessages</method> pass no map to
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.CanonicalToGemini</method> -- red on the replayed
/// route.</p>
Method TestTheGeminiAdapterReplaysTheRespelling()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row("gemini", .tRow), 1, "the shipped gemini row is readable")
    If '$IsObject($Get(tRow)) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "the registry's provider tool set builds")
    Set tUse = {"type": "tool_use", "id": "c1", "input": {"route": ""}}
    Do tUse.%Set("name", ..NavigateWire(), "string")
    Set tBlocks = []
    Do tBlocks.%Push(tUse)
    Kill tMessages
    Set tMessages = 3
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "go home"
    Set tMessages(2, "role") = "assistant"
    Set tMessages(2, "blocks") = tBlocks.%ToJSON()
    Set tMessages(3, "role") = "user"
    Set tMessages(3, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""c1"",""content"":""ok""}]"
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""home""}]},""finishReason"":""STOP""}]}")
    Do ##class(OcuPilot.Test.GeminiAdapter).DirectValues(tRow, .tValues)
    Do ##class(OcuPilot.Test.Provider).Settings(.tSettings, 1)
    Set tAdapter = ##class(OcuPilot.Test.GeminiAdapter).Adapter()
    Do $$$AssertStatusOK(tAdapter.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the call returns $$$OK")
    Set tAdapter = ""
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""), "", "with no fault")
    Set tSent = ##class(OcuPilot.Test.GeminiAdapter).RecordedBody(1)
    Do $$$AssertTrue($IsObject(tSent), "the request body was recorded")
    If '$IsObject(tSent) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tSent, "contents.1.parts.0.functionCall.args.route"), ..Empty(), "the replayed navigate call carries the respelling: " _ tSent.%Get("contents").%ToJSON())
}

}
