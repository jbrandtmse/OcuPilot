/// <p>No Gemini function declaration carries a numeric <code>enum</code> member, because
/// Gemini's <code>Schema.enum</code> takes strings only. Over the whole registered tool set,
/// <method>OcuPilot.Kernel.Provider.ToolDefAdapter.ToGemini</method> writes each numeric member of
/// an <code>integer</code> or <code>number</code> property as its JSON text and keeps the property's
/// type; <class>OcuPilot.Kernel.Provider.MessageAdapter</class> reads a model's string back as the
/// number and writes it again in replayed history, on exactly the (tool, argument) pairs the request
/// respelled; and the Gemini adapter's recorded body carries no numeric member.</p>
/// <p><b>Needs nothing of the environment</b>: the registry is read in process, and the adapter leg
/// runs through <class>OcuPilot.Test.GeminiStub</class> with no socket opened. Its sibling for the
/// empty member is <class>OcuPilot.Test.GeminiEmptyEnum</class>, whose helpers this class reuses.</p>
Class OcuPilot.Test.GeminiNumericEnum Extends %UnitTest.TestCase
{

Parameter TOOLDEFS = "OcuPilot.Kernel.Provider.ToolDefAdapter";

Parameter MESSAGES = "OcuPilot.Kernel.Provider.MessageAdapter";

Parameter SIBLING = "OcuPilot.Test.GeminiEmptyEnum";

/// <p>A tool name no registry holds, standing for the probe schemas below.</p>
Parameter PROBETOOL = "probe_numeric_pick";

/// <p>The tools whose declarations carried numeric members when the service refused the roster.
/// <method>TestNoGeminiDeclarationCarriesANumericMember</method> floors the count as well, so a
/// later tool with such an enum is covered without an edit here.</p>
Parameter MEASUREDTOOLS = "security_secrets_creatersa,security_secrets_createsymmetric,security_secrets_replacersa,security_ssl_create,security_ssl_update";

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

/// <p>How many members of <var>pEnum</var> are JSON numbers.</p>
ClassMethod Numbers(pEnum As %DynamicArray) As %Integer
{
    Set tCount = 0
    Set tIterator = pEnum.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMember, .tType) {
        If tType = "number" Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The members of <var>pEnum</var> each written as a string, as JSON text.</p>
ClassMethod AsStrings(pEnum As %DynamicArray) As %String
{
    Set tOut = []
    Set tIterator = pEnum.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMember) {
        Do tOut.%Push(tMember _ "", "string")
    }
    Quit tOut.%ToJSON()
}

/// <p>The canonical schema of the tool <var>pName</var> in <var>pTools</var>, or an empty object.</p>
ClassMethod SchemaFor(ByRef pTools, pName As %String) As %DynamicObject
{
    For tI = 1:1:+$Get(pTools) {
        If $Get(pTools(tI, "name")) = pName Quit
    }
    If tI > +$Get(pTools) Quit {}
    Quit $ClassMethod(..#TOOLDEFS, "SchemaOf", $Get(pTools(tI, "inputSchema")))
}

/// <p>A one-tool canonical array whose schema holds each shape the map and the respelling
/// distinguish: an integer enum, an array of them, a number enum, a nested integer enum, and an
/// integer, a string enum and a bare integer that are left alone.</p>
ClassMethod ProbeTools(Output pTools)
{
    Kill pTools
    Set pTools = 1
    Set pTools(1, "name") = ..#PROBETOOL
    Set pTools(1, "description") = "probe"
    Set pTools(1, "inputSchema") = "{""type"":""object"",""properties"":{""size"":{""type"":""integer"",""enum"":[1,2]},""sizes"":{""type"":""array"",""items"":{""type"":""integer"",""enum"":[2048,16]}},""ratio"":{""type"":""number"",""enum"":[0.5,1.5]},""word"":{""type"":""string"",""enum"":[""a"",""b""]},""plain"":{""type"":""integer""},""nested"":{""type"":""object"",""properties"":{""deep"":{""type"":""integer"",""enum"":[7,8]}}}}}"
}

/// <p>Across every registered tool, no Gemini declaration carries a numeric <code>enum</code> member
/// at any depth; each enum that held one is written as the same members as strings, in order, on a
/// property that keeps its integer or number type; each measured tool carries one; at least five
/// tools do; and every respelled enum is a pair
/// <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiEmptyEnumArgs</method> names, so each one
/// decodes back.</p>
/// <p>Mutation: copy numeric members unchanged in
/// <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiEnum</method> -- red on the first
/// assertion.</p>
Method TestNoGeminiDeclarationCarriesANumericMember()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "the registry's provider tool set builds")
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tTools, .tDeclarations), "the Gemini translation builds")
    If '$IsObject($Get(tDeclarations)) || (tDeclarations.%Size() = 0) Quit
    Set tFunctions = tDeclarations.%Get(0).%Get("functionDeclarations")
    Set tMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tTools)
    Set tLeft = ""
    Set tMismatch = ""
    Set tRetyped = ""
    Set tUnmapped = ""
    Kill tCarrying
    For tI = 1:1:+tTools {
        Set tName = tTools(tI, "name")
        Kill tCanonical, tGemini
        Do $ClassMethod(..#SIBLING, "Enums", $ClassMethod(..#TOOLDEFS, "SchemaOf", $Get(tTools(tI, "inputSchema"))), "", .tCanonical)
        Do $ClassMethod(..#SIBLING, "Enums", tFunctions.%Get(tI - 1).%Get("parameters"), "", .tGemini)
        Set tPath = ""
        For {
            Set tPath = $Order(tGemini(tPath))
            If tPath = "" Quit
            If ..Numbers(tGemini(tPath)) Set tLeft = tLeft _ " " _ tName _ ":" _ tPath
        }
        For {
            Set tPath = $Order(tCanonical(tPath))
            If tPath = "" Quit
            If '..Numbers(tCanonical(tPath)) Continue
            Set tCarrying(tName) = $Get(tCarrying(tName)) + 1
            If '$Data(tGemini(tPath)) || (tGemini(tPath).%ToJSON() '= ..AsStrings(tCanonical(tPath))) Set tMismatch = tMismatch _ " " _ tName _ ":" _ tPath
            Set tArg = ""
            Set tKind = ""
            If $Match(tPath, "properties\.[^.]+\.enum") Set tArg = $Piece(tPath, ".", 2), tKind = "number"
            If $Match(tPath, "properties\.[^.]+\.items\.enum") Set tArg = $Piece(tPath, ".", 2), tKind = "numbers"
            Set tMapped = ""
            If (tArg '= "") && $IsObject(tMap.%Get(tName)) Set tMapped = tMap.%Get(tName).%Get(tArg)
            If (tKind = "") || (tMapped '= tKind) Set tUnmapped = tUnmapped _ " " _ tName _ ":" _ tPath
            Set tType = ##class(OcuPilot.Test.Adapter).Path(tFunctions.%Get(tI - 1), "parameters.properties." _ tArg _ $Select(tKind = "numbers": ".items", 1: "") _ ".type")
            If (tKind '= "") && '$ListFind($ListBuild("INTEGER", "NUMBER"), tType) Set tRetyped = tRetyped _ " " _ tName _ ":" _ tPath _ "=" _ tType
        }
    }
    Do $$$AssertEquals(tLeft, "", "no Gemini declaration carries a numeric enum member")
    Do $$$AssertEquals(tMismatch, "", "each numeric enum is written as its own members as strings, in order")
    Do $$$AssertEquals(tRetyped, "", "and its property keeps its integer or number type")
    Do $$$AssertEquals(tUnmapped, "", "every respelled numeric enum is a pair the map names, so none is respelled one way only")
    For tI = 1:1:$Length(..#MEASUREDTOOLS, ",") {
        Set tName = $Piece(..#MEASUREDTOOLS, ",", tI)
        Do $$$AssertTrue($Get(tCarrying(tName)) > 0, tName _ " declares a numeric enum and is respelled")
    }
    Set tTools = 0
    Set tName = ""
    For {
        Set tName = $Order(tCarrying(tName))
        If tName = "" Quit
        Set tTools = tTools + 1
    }
    Do $$$AssertTrue(tTools >= 5, "at least five tools declare a numeric enum, so the sweep is not a hand-kept roster: " _ tTools)
}

/// <p>The map names an integer or number argument whose <code>enum</code> holds numbers as kind
/// <code>number</code>, an array argument whose <code>items.enum</code> does as kind
/// <code>numbers</code>, and leaves a string enum and a bare integer out; the declaration writes
/// every such member as its JSON text -- one half as <code>0.5</code> -- at every depth, including
/// a nested property the map does not name, and leaves the string enum as it was.</p>
/// <p>Mutation: remove the <code>numbers</code> branch from
/// <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiEmptyEnumArgs</method> -- red on the map.</p>
Method TestTheMapAndTheDeclarationCoverEveryNumericShape()
{
    Do ..ProbeTools(.tTools)
    Set tMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tTools)
    Do $$$AssertEquals(tMap.%ToJSON(), "{""" _ ..#PROBETOOL _ """:{""size"":""number"",""sizes"":""numbers"",""ratio"":""number""}}", "the map names the three top-level numeric arguments and nothing else")
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tTools, .tDeclarations), "the Gemini translation builds")
    If '$IsObject($Get(tDeclarations)) || (tDeclarations.%Size() = 0) Quit
    Set tParameters = tDeclarations.%Get(0).%Get("functionDeclarations").%Get(0).%Get("parameters")
    Do $$$AssertEquals(tParameters.properties.size.enum.%ToJSON(), "[""1"",""2""]", "an integer enum is written as strings")
    Do $$$AssertEquals(tParameters.properties.size.type, "INTEGER", "and keeps its type")
    Do $$$AssertEquals(tParameters.properties.sizes.items.enum.%ToJSON(), "[""2048"",""16""]", "an array's items enum too, in order")
    Do $$$AssertEquals(tParameters.properties.ratio.enum.%ToJSON(), "[""0.5"",""1.5""]", "a number enum keeps the leading zero")
    Do $$$AssertEquals(tParameters.properties.nested.properties.deep.enum.%ToJSON(), "[""7"",""8""]", "a nested enum is respelled at its depth")
    Do $$$AssertEquals(tParameters.properties.word.enum.%ToJSON(), "[""a"",""b""]", "a string enum is left as it was")
    Do $$$AssertEquals(tParameters.properties.plain.%Get("enum"), "", "and a bare integer gains none")
}

/// <p>A model's string for a respelled member reaches the canonical input as the number, per
/// element for an array argument, on a mapped (tool, argument) pair and on no other; a string that
/// is not a number's JSON text, one naming a number too large to hold, and a value that is already
/// a number are left as they are; and the decoded arguments satisfy the registry's own validation
/// where the string does not.</p>
/// <p>Mutation: skip the numeric decode in
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.GeminiToCanonical</method> -- red on the length
/// and the array element.</p>
Method TestTheRespellingDecodesToANumberOnItsOwnPairsOnly()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "the registry's provider tool set builds")
    Set tName = $Piece(..#MEASUREDTOOLS, ",", 1)
    Set tSchema = ..SchemaFor(.tTools, tName)
    Set tMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tTools)
    Do ..ProbeTools(.tProbe)
    Set tProbeMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tProbe)
    Do tMap.%Set(..#PROBETOOL, tProbeMap.%Get(..#PROBETOOL))
    Set tCalls = []
    Set tCall = {"functionCall": {"name": "", "args": {"Name": "k", "Length": "3072"}}}
    Do tCall.functionCall.%Set("name", tName, "string")
    Do tCalls.%Push(tCall)
    Set tList = {"functionCall": {"name": "", "args": {"sizes": ["2048", "x", "16", 7]}}}
    Do tList.functionCall.%Set("name", ..#PROBETOOL, "string")
    Do tCalls.%Push(tList)
    Set tNumber = {"functionCall": {"name": "", "args": {"Name": "k", "Length": 4096}}}
    Do tNumber.functionCall.%Set("name", tName, "string")
    Do tCalls.%Push(tNumber)
    Set tOther = {"functionCall": {"name": "probe_other_tool", "args": {"Length": "3072"}}}
    Do tCalls.%Push(tOther)
    Set tHuge = {"functionCall": {"name": "", "args": {}}}
    Do tHuge.functionCall.%Set("name", ..#PROBETOOL, "string")
    Do tHuge.functionCall.args.%Set("size", "1" _ $Translate($Justify("", 400), " ", "0"), "string")
    Do tCalls.%Push(tHuge)
    Set tBody = {"candidates": [{"content": {"role": "model", "parts": []}, "finishReason": "STOP"}]}
    Do tBody.candidates.%Get(0).content.%Set("parts", tCalls)

    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", tBody.%ToJSON(), tResponse, tMap.%ToJSON()), "the reply reads")
    Set tUses = ##class(%DynamicArray).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tUses.%Get(0).input.%GetTypeOf("Length"), "number", "a mapped argument reaches the canonical input as a number")
    Do $$$AssertEquals(tUses.%Get(0).input.Length, 3072, "the number the model named")
    Do $$$AssertEquals(tUses.%Get(0).input.Name, "k", "and an unmapped argument of the same tool is as it was")
    Do $$$AssertEquals(tUses.%Get(1).input.sizes.%ToJSON(), "[2048,""x"",16,7]", "an array argument is decoded per element; a non-number string and a number stay as they were")
    Do $$$AssertEquals(tUses.%Get(2).input.%GetTypeOf("Length"), "number", "a value that is already a number stays a number")
    Do $$$AssertEquals(tUses.%Get(2).input.Length, 4096, "with its value")
    Do $$$AssertEquals(tUses.%Get(3).input.%GetTypeOf("Length"), "string", "the same argument name on an unmapped tool keeps the text verbatim")
    Do $$$AssertEquals(tUses.%Get(4).input.%GetTypeOf("size"), "string", "a numeric string too large to hold stays a string, and the reply still reads")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Screen.Tool.Registry", "ValidateArguments", tSchema, tUses.%Get(0).input, .tProblem), "the decoded arguments pass the registry's validation: " _ $Get(tProblem))

    Set tUnmapped = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", tBody.%ToJSON(), tUnmapped), "the reply reads with no map")
    Set tRaw = ##class(%DynamicArray).%FromJSON(tUnmapped.ToolCallsJson)
    Do $$$AssertEquals(tRaw.%Get(0).input.%GetTypeOf("Length"), "string", "and a caller with no map is unchanged")
    Do $$$AssertStatusNotOK($ClassMethod("OcuPilot.Screen.Tool.Registry", "ValidateArguments", tSchema, tRaw.%Get(0).input, .tRawProblem), "the string fails the validation the number passes: " _ $Get(tRawProblem))
}

/// <p>Replayed history writes a number back as its JSON text on the same pairs -- negative, zero, a
/// decimal below one and an integer past nineteen digits alike -- and the round trip closes:
/// decoding what was encoded gives back the canonical input.</p>
/// <p>Mutation: skip the numeric encode in
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.CanonicalToGemini</method> -- red on the replayed
/// length.</p>
Method TestReplayedHistoryRespellsTheSameNumbers()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "the registry's provider tool set builds")
    Set tName = $Piece(..#MEASUREDTOOLS, ",", 1)
    Set tMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tTools)
    Do ..ProbeTools(.tProbe)
    Set tProbeMap = $ClassMethod(..#TOOLDEFS, "GeminiEmptyEnumArgs", .tProbe)
    Do tMap.%Set(..#PROBETOOL, tProbeMap.%Get(..#PROBETOOL))
    Set tInput = {"Name": "k", "Length": 3072}
    Set tListInput = {"sizes": [2048, 16, -1, 0, -0.5, 0.0000001, 12345678901234567890], "ratio": 1.5}
    Set tBlocks = []
    Set tUse = {"type": "tool_use", "id": "c1"}
    Do tUse.%Set("name", tName, "string")
    Do tUse.%Set("input", tInput)
    Do tBlocks.%Push(tUse)
    Set tListUse = {"type": "tool_use", "id": "c2"}
    Do tListUse.%Set("name", ..#PROBETOOL, "string")
    Do tListUse.%Set("input", tListInput)
    Do tBlocks.%Push(tListUse)
    Kill tMessages
    Set tMessages = 3
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "make a key"
    Set tMessages(2, "role") = "assistant"
    Set tMessages(2, "blocks") = tBlocks.%ToJSON()
    Set tMessages(3, "role") = "user"
    Set tMessages(3, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""c1"",""content"":""ok""},{""type"":""tool_result"",""tool_use_id"":""c2"",""content"":""ok""}]"

    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tContents, .tSystem, tMap.%ToJSON()), "the history translates")
    Do $$$AssertEquals(##class(OcuPilot.Test.Adapter).Path(tContents, "1.parts.1.functionCall.args.sizes"), "(object)", "the replayed calls carry their arguments: " _ tContents.%ToJSON())
    If ##class(OcuPilot.Test.Adapter).Path(tContents, "1.parts.1.functionCall.args.sizes") '= "(object)" Quit
    Set tParts = tContents.%Get(1).parts
    Do $$$AssertEquals(tParts.%Get(0).functionCall.args.%GetTypeOf("Length"), "string", "the mapped number is written as the string the declaration carried")
    Do $$$AssertEquals(tParts.%Get(0).functionCall.args.Length, "3072", "with its JSON text")
    Do $$$AssertEquals(tParts.%Get(1).functionCall.args.sizes.%ToJSON(), "[""2048"",""16"",""-1"",""0"",""-0.5"",""0.0000001"",""12345678901234567890""]", "an array argument per element, each as its JSON text")
    Do $$$AssertEquals(tParts.%Get(1).functionCall.args.%GetTypeOf("ratio") _ ":" _ tParts.%Get(1).functionCall.args.ratio, "string:1.5", "and a decimal as its JSON text")

    Set tBody = {"candidates": [{"content": {"role": "model", "parts": []}, "finishReason": "STOP"}]}
    Do tBody.candidates.%Get(0).content.%Set("parts", tParts)
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", tBody.%ToJSON(), tResponse, tMap.%ToJSON()), "the replayed parts read back")
    Set tUses = ##class(%DynamicArray).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tUses.%Get(0).input.%ToJSON(), tInput.%ToJSON(), "the round trip gives back the canonical input")
    Do $$$AssertEquals(tUses.%Get(1).input.%ToJSON(), tListInput.%ToJSON(), "for the array argument and the decimal too")

    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tPlain, .tSystem), "the history translates with no map")
    Do $$$AssertEquals(tPlain.%Get(1).parts.%Get(0).functionCall.args.%GetTypeOf("Length"), "number", "and a caller with no map is unchanged")
}

/// <p>Through the Gemini adapter with the registry's whole tool set: the recorded request carries
/// no numeric enum member and does carry the respelling, and a reply naming a length as the string
/// <code>"3072"</code> reaches the turn as the number.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.Gemini.MapResponse</method> pass no map -- red
/// on the length.</p>
Method TestTheGeminiAdapterSendsNoNumericMember()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row("gemini", .tRow), 1, "the shipped gemini row is readable")
    If '$IsObject($Get(tRow)) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools), "the registry's provider tool set builds")
    Set tReply = {"candidates": [{"content": {"role": "model", "parts": [{"functionCall": {"name": "", "args": {"Name": "k", "Length": "3072"}}}]}, "finishReason": "STOP"}]}
    Do tReply.candidates.%Get(0).content.parts.%Get(0).functionCall.%Set("name", $Piece(..#MEASUREDTOOLS, ",", 1), "string")
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
    Do $ClassMethod(..#SIBLING, "Enums", tSent.%Get("tools"), "", .tFound)
    Set tLeft = ""
    Set tRespelled = 0
    Set tPath = ""
    For {
        Set tPath = $Order(tFound(tPath))
        If tPath = "" Quit
        If ..Numbers(tFound(tPath)) Set tLeft = tLeft _ " " _ tPath
        If $ClassMethod(..#SIBLING, "Holding", tFound(tPath), "3072") Set tRespelled = tRespelled + 1
    }
    Do $$$AssertEquals(tLeft, "", "the recorded request carries no numeric enum member")
    Do $$$AssertTrue(tRespelled > 0, "and carries the respelling instead")
    If '$IsObject($Get(tResponse)) Quit
    Set tUses = ##class(%DynamicArray).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tUses.%Get(0).input.%GetTypeOf("Length"), "number", "the model's call reaches the turn with a number")
    Do $$$AssertEquals(tUses.%Get(0).input.Length, 3072, "equal to the member it chose")
}

}
