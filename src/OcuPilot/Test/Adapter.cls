/// <p>Story 10.1's two translators: the locked cross-vendor JSON-Schema subset, both directions of
/// both dialects, the correlation rules a <code>tool_result</code> travels under, the error each
/// translation failure answers, the clamp's boundary cases, and the canonical family staying a
/// passthrough.</p>
/// <p><b>Needs nothing of the environment but a writable protected database.</b> The transport is
/// <class>OcuPilot.Test.AdapterProvider</class> over
/// <class>OcuPilot.Test.ProviderStub</class>'s recording seam, so no socket is opened; the port
/// entry is <class>OcuPilot.Test.ProviderPortProbe</class>, whose catalog is
/// <class>OcuPilot.Test.CatalogProbe</class>. The one stored row each port leg needs is created and
/// removed by this class, and nothing instance-level is touched.</p>
Class OcuPilot.Test.Adapter Extends %UnitTest.TestCase
{

/// <p>The message translator under test.</p>
Parameter MESSAGES = "OcuPilot.Kernel.Provider.MessageAdapter";

/// <p>The tool-definition translator under test.</p>
Parameter TOOLDEFS = "OcuPilot.Kernel.Provider.ToolDefAdapter";

/// <p>The registry whose emitted subset both translators must keep.</p>
Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

/// <p>The retry class declaring the clamp.</p>
Parameter RETRY = "OcuPilot.Kernel.Provider.Retry";

/// <p>The distinctive phrase the clamp's own log line carries, so the assertion reads the line
/// rather than the condition that produced it.</p>
Parameter CLAMPMARK = "was lowered to keep one provider call";

/// <p>The probe catalog whose two dialect rows drive the port legs.</p>
Parameter CATALOG = "OcuPilot.Test.CatalogProbe";

/// <p>The fixture adapter those rows name.</p>
Parameter ADAPTER = "OcuPilot.Test.AdapterProvider";

/// <p>The port entry, with its switched catalog, gate, credential class and TLS answer.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>The locked rule's top-level keyword list, written here as the harvest plan writes it so the
/// registry cannot agree with itself.</p>
Parameter RULETOPKEYWORDS = "type,properties,required,additionalProperties";

/// <p>The locked rule's property-level keyword list, likewise.</p>
Parameter RULEKEYWORDS = "type,description,enum,items,minimum,maximum,minItems,maxItems";

/// <p>OpenAI's published tool-name grammar, as both translator class doc comments cite it. Gemini's
/// is not the same -- it additionally requires a leading letter or underscore, and admits dots -- so
/// what keeps a wire name inside both is the canonical grammar below, not this one.</p>
Parameter VENDORNAMEPATTERN = "^[a-zA-Z0-9_-]{1,64}$";

/// <p>The grammar asserted of every wire name. It is <b>inside</b> both vendors' published
/// grammars rather than their intersection: OpenAI admits a leading digit, hyphen or underscore
/// and Gemini a leading underscore, and this admits none of them. The narrower form costs nothing,
/// because <parameter>OcuPilot.Screen.Tool.Registry.TOOLNAMEPATTERN</parameter> already refuses a
/// canonical name whose first segment does not begin with a lower-case letter. The 64-character
/// cap is OpenAI's published one; no reference in this tree publishes Gemini's (inference).</p>
/// <p>Spelled here rather than read from
/// <parameter>OcuPilot.Screen.Tool.Registry.WIRENAMEPATTERN</parameter>, which is OpenAI's alone:
/// reading it would make the assertion agree with whatever that gate says rather than with what
/// the vendors publish.</p>
Parameter SHAREDNAMEPATTERN = "^[a-zA-Z][a-zA-Z0-9_-]{0,63}$";

/// <p>The canonical tool-name grammar the registry admits. Every segment begins with a lowercase
/// letter, so the wire form -- each dot an underscore -- is inside both families' grammars.</p>
Parameter CANONICALNAMEPATTERN = "^[a-z][a-z0-9]*\.[a-z][a-z0-9]*\.[a-z][a-z0-9]*$";

/// <p>A value seeded into a response before a refusing translator is called, so "nothing is
/// reported as a reply" is an assertion that can fail -- an empty <property>Text</property> on a
/// fresh response is the only value it could have had.</p>
Parameter UNTOUCHED = "seeded, never a reply";

/// <p>A tool schema using every keyword the rule admits, at the top level and in a property and
/// its <code>items</code>, so a translator that dropped or renamed one is visible.</p>
Parameter TOOLSCHEMA = "{""type"":""object"",""properties"":{""name"":{""type"":""string"",""description"":""the name"",""enum"":[""a"",""b""]},""count"":{""type"":""integer"",""description"":""how many"",""minimum"":1,""maximum"":10},""tags"":{""type"":""array"",""description"":""labels"",""items"":{""type"":""string"",""description"":""one label""},""minItems"":1,""maxItems"":5}},""required"":[""name""],""additionalProperties"":false}";

/// <p>The wire name of the one tool every request leg advertises.</p>
Parameter TOOLNAME = "logs_errors_read";

/// <p>An OpenAI reply carrying text, one tool call whose arguments are a JSON string, a stop
/// reason and both usage figures.</p>
Parameter OPENAIREPLY = "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":""looking"",""tool_calls"":[{""id"":""call1"",""type"":""function"",""function"":{""name"":""logs_errors_read"",""arguments"":""{\""maxRows\"":5}""}}]},""finish_reason"":""tool_calls""}],""usage"":{""prompt_tokens"":31,""completion_tokens"":7}}";

/// <p>A Gemini reply carrying text and <b>two</b> calls to one function, so the correlation the
/// next request makes is exercised where the dialect carries no call id.</p>
Parameter GEMINIREPLY = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""looking""},{""functionCall"":{""name"":""logs_errors_read"",""args"":{""maxRows"":5}}},{""functionCall"":{""name"":""logs_errors_read"",""args"":{""maxRows"":9}}}]},""finishReason"":""STOP""}],""usageMetadata"":{""promptTokenCount"":41,""candidatesTokenCount"":11}}";

/// <p>An OpenAI reply whose <code>function.arguments</code> is a JSON array rather than the object
/// text the dialect declares, so the reply direction's object rule is driven by a body it can
/// actually receive.</p>
Parameter OPENAIARRAYARGSREPLY = "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""tool_calls"":[{""id"":""call1"",""type"":""function"",""function"":{""name"":""logs_errors_read"",""arguments"":[1,2]}}]},""finish_reason"":""tool_calls""}]}";

/// <p>A Gemini reply whose <code>functionCall.args</code> is a JSON array, likewise.</p>
Parameter GEMINIARRAYARGSREPLY = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""functionCall"":{""name"":""logs_errors_read"",""args"":[1,2]}}]},""finishReason"":""STOP""}]}";

/// <p>An OpenAI reply whose one tool call carries no <code>id</code>, which no later request could
/// answer.</p>
Parameter OPENAIIDLESSREPLY = "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""tool_calls"":[{""type"":""function"",""function"":{""name"":""logs_errors_read"",""arguments"":""{}""}}]},""finish_reason"":""tool_calls""}]}";

/// <p>A Gemini reply whose one <code>functionCall</code> part names no function.</p>
Parameter GEMININAMELESSREPLY = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""functionCall"":{""args"":{}}}]},""finishReason"":""STOP""}]}";

/// <p>The system prompt every request leg sends.</p>
Parameter SYSTEMPROMPT = "you are a probe";

/// <p>The credential the probe rows' prefix gate accepts.</p>
Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>The endpoint every stored probe definition names. The address policy is not what these
/// legs exercise; it is <class>OcuPilot.Test.Egress</class>'s.</p>
Parameter ENDPOINT = "https://api.anthropic.com/v1/messages";

/// <p>Arm a clean port, a clean stub, a canonical dialect and a resolvable credential.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.AdapterProvider).Forget()
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit $$$OK
}

/// <p>Leave no switch and no stored row for the next method, or the next class, to read.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.AdapterProvider).Forget()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Set tRemoved = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tRemoved, "every probe definition this method created is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The canonical history every request leg translates: a plain user message, an assistant echo
/// carrying text and <b>two</b> calls to one tool, and a user message carrying both results and a
/// further question.</p>
ClassMethod Canonical(Output pMessages)
{
    Kill pMessages
    Set pMessages = 3
    Set pMessages(1, "role") = "user"
    Set pMessages(1, "content") = "what is on this screen"
    Set pMessages(2, "role") = "assistant"
    Set pMessages(2, "blocks") = "[{""type"":""text"",""text"":""checking""},{""type"":""tool_use"",""id"":""call1"",""name"":""" _ ..#TOOLNAME _ """,""input"":{""maxRows"":5}},{""type"":""tool_use"",""id"":""call2"",""name"":""" _ ..#TOOLNAME _ """,""input"":{""maxRows"":9}}]"
    Set pMessages(3, "role") = "user"
    Set pMessages(3, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""call1"",""content"":""first""},{""type"":""tool_result"",""tool_use_id"":""call2"",""content"":""second""},{""type"":""text"",""text"":""and now""}]"
}

/// <p>The canonical history with one <code>tool_result</code> answering a call nothing made.</p>
ClassMethod Unmatched(Output pMessages)
{
    Kill pMessages
    Set pMessages = 1
    Set pMessages(1, "role") = "user"
    Set pMessages(1, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""callnobodymade"",""content"":""first""}]"
}

/// <p>The canonical tool array every request leg advertises: one tool whose schema is
/// <parameter>TOOLSCHEMA</parameter>.</p>
ClassMethod Tools(Output pTools)
{
    Kill pTools
    Set pTools = 1
    Set pTools(1, "name") = ..#TOOLNAME
    Set pTools(1, "description") = "read the error log"
    Set pTools(1, "inputSchema") = ..#TOOLSCHEMA
}

/// <p>Every keyword <var>pSchema</var> carries at any depth, counted into <var>pSeen</var> by
/// name -- the top level, every property, and every <code>items</code> below one.</p>
ClassMethod Keywords(pSchema As %DynamicAbstractObject, ByRef pSeen)
{
    If '$IsObject(pSchema) Quit
    If 'pSchema.%IsA("%Library.DynamicObject") Quit
    Set tIterator = pSchema.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set pSeen(tKey) = +$Get(pSeen(tKey)) + 1
        If tKey = "items" {
            Do ..Keywords(tValue, .pSeen)
            Continue
        }
        If tKey '= "properties" Continue
        If '$IsObject(tValue) Continue
        Set tPropertyIterator = tValue.%GetIterator()
        While tPropertyIterator.%GetNext(.tName, .tProperty) {
            Do ..Keywords(tProperty, .pSeen)
        }
    }
}

/// <p>The scalar <var>pPath</var> -- dotted keys, with a whole number for an array index -- reaches
/// in <var>pRoot</var>, or <code>""</code> when any step of it is missing, and
/// <code>"(object)"</code> when the path ends on one.</p>
/// <p>Read through here rather than by chained property access so an assertion on a body of the
/// wrong shape <b>fails</b> naming the path it wanted, instead of raising
/// <code>&lt;INVALID OREF&gt;</code> and hiding every assertion after it.</p>
ClassMethod Path(pRoot As %RawString = "", pPath As %String) As %String
{
    Set tNode = pRoot
    For tI = 1:1:$Length(pPath, ".") {
        If '$IsObject(tNode) {
            Set tNode = ""
            Quit
        }
        Set tStep = $Piece(pPath, ".", tI)
        Set tNode = $Select(tStep?1.N: tNode.%Get(+tStep), 1: tNode.%Get(tStep))
    }
    If $IsObject(tNode) Quit "(object)"
    Quit tNode
}

/// <p><var>pSeen</var>'s subscripts joined by commas in collating order, so a keyword set reads as
/// one comparable string.</p>
ClassMethod Joined(ByRef pSeen) As %String
{
    Set tJoined = ""
    Set tKey = $Order(pSeen(""))
    While tKey '= "" {
        Set tJoined = tJoined _ $Select(tJoined = "": "", 1: ",") _ tKey
        Set tKey = $Order(pSeen(tKey))
    }
    Quit tJoined
}

/// <p>The same list built from a comma-separated parameter, so a rule's own list and a translated
/// schema's keywords are compared in one order.</p>
ClassMethod Sorted(pList As %String) As %String
{
    Kill tSeen
    For tI = 1:1:$Length(pList, ",") {
        Set tSeen($Piece(pList, ",", tI)) = 1
    }
    Quit ..Joined(.tSeen)
}

/// <p>Every type value <var>pSchema</var> names at any depth, joined by commas in the order they
/// were met.</p>
ClassMethod Types(pSchema As %DynamicAbstractObject) As %String
{
    Set tTypes = ""
    If '$IsObject(pSchema) Quit tTypes
    If 'pSchema.%IsA("%Library.DynamicObject") Quit tTypes
    If pSchema.%GetTypeOf("type") '= "unassigned" Set tTypes = pSchema.%Get("type")
    If pSchema.%GetTypeOf("properties") = "object" {
        Set tIterator = pSchema.%Get("properties").%GetIterator()
        While tIterator.%GetNext(.tName, .tProperty) {
            Set tTypes = tTypes _ "," _ ..Types(tProperty)
        }
    }
    If pSchema.%GetTypeOf("items") = "object" Set tTypes = tTypes _ "," _ ..Types(pSchema.%Get("items"))
    Quit tTypes
}

/// <p>Create one enabled probe definition naming provider <var>pProvider</var> and hand back its
/// id. Written straight through the state class, as
/// <method>OcuPilot.Test.AgentFixture.CreateDefinition</method> does, because
/// <method>OcuPilot.Kernel.AgentRules.Validate</method> admits only the shipped provider key and a
/// probe family has none.</p>
/// <p>The name carries
/// <parameter>OcuPilot.Test.AgentFixture.PROBEPREFIX</parameter>, so this class's teardown removes
/// it through the shared fixture.</p>
Method StoredDefinition(pProvider As %String) As %String
{
    Set tId = ""
    Try {
        Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
        Set tRow.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Dialect" _ $Translate(pProvider, "-", "")
        Set tRow.Provider = pProvider
        Set tRow.Model = "probe-model-1"
        Set tRow.EndpointUrl = ..#ENDPOINT
        Set tRow.CredType = "env"
        Set tRow.EnvVarName = "OCUPILOT" _ "_PROBE_LOCAL_KEY"
        Set tRow.CredentialName = ""
        Set tRow.MaxTokens = 4000
        Set tRow.Temperature = 0
        Set tRow.Enabled = 1
        Set tRow.ConnectionVerified = 1
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
        Do $$$AssertStatusOK(tSC, "the probe definition for '" _ pProvider _ "' is stored")
        If $$$ISERR(tSC) Quit
        Set tId = tRow.%Id()
        Set tRow = ""
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "storing the probe definition for '" _ pProvider _ "' did not raise")
    }
    Quit tId
}

/// <p>The body the stub recorded on call <var>pCall</var>, parsed.</p>
ClassMethod Recorded(pCall As %Integer = 1) As %DynamicObject
{
    Set tBody = ""
    Try {
        Set tText = ##class(OcuPilot.Test.ProviderStub).Recorded("body", pCall)
        If tText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tText, "I", "UTF8"))
        If $IsObject(tParsed) Set tBody = tParsed
    } Catch ex {
        Set tBody = ""
    }
    Quit tBody
}

/// <p>AC1 -- the locked subset is kept verbatim: the registry's two emitted lists are the rule's
/// own, an OpenAI declaration carries the emitted schema unchanged, and the only keyword a Gemini
/// declaration loses is the one its grammar refuses, which the translator names.</p>
/// <p>Mutation: add <code>pattern</code> to
/// <parameter>OcuPilot.Screen.Tool.Registry.EMITTEDKEYWORDS</parameter> -- the first two
/// assertions go red.</p>
Method TestTheLockedSubsetIsKeptVerbatimByBothTranslators()
{
    Do $$$AssertEquals($Parameter(..#REGISTRY, "EMITTEDTOPKEYWORDS"), ..#RULETOPKEYWORDS, "the registry's emitted top-level keywords are the locked rule's list")
    Do $$$AssertEquals($Parameter(..#REGISTRY, "EMITTEDKEYWORDS"), ..#RULEKEYWORDS, "and its emitted property keywords are the locked rule's list")

    Do ..Tools(.tTools)
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToOpenAi", .tTools, .tOpenAi), "the tool array translates into OpenAI declarations")
    Set tParameters = tOpenAi.%Get(0).%Get("function").%Get("parameters")
    Do $$$AssertEquals(tParameters.%ToJSON(), ..#TOOLSCHEMA, "the emitted schema reaches function.parameters unchanged, additionalProperties included")

    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tTools, .tGemini), "and into Gemini declarations")
    Set tGeminiParameters = tGemini.%Get(0).%Get("functionDeclarations").%Get(0).%Get("parameters")
    Kill tSeen
    Do ..Keywords(tGeminiParameters, .tSeen)
    Set tExpected = ..Sorted(..#RULETOPKEYWORDS _ "," _ ..#RULEKEYWORDS)
    Set tDropped = $Parameter(..#TOOLDEFS, "GEMINIDROPPED")
    For tI = 1:1:$Length(tDropped, ",") {
        Set tName = $Piece(tDropped, ",", tI)
        Do $$$AssertEquals(+$Get(tSeen(tName)), 0, "the keyword Gemini's grammar refuses is gone from its declaration: " _ tName)
        Kill tRemaining
        For tJ = 1:1:$Length(tExpected, ",") {
            If $Piece(tExpected, ",", tJ) = tName Continue
            Set tRemaining($Piece(tExpected, ",", tJ)) = 1
        }
        Set tExpected = ..Joined(.tRemaining)
    }
    Do $$$AssertEquals(..Joined(.tSeen), tExpected, "and every other emitted keyword survives, with none outside the subset introduced: " _ ..Joined(.tSeen))
    Do $$$AssertEquals(..Types(tGeminiParameters), "OBJECT,STRING,INTEGER,ARRAY,STRING", "the type values are Gemini's own vocabulary at every depth: " _ ..Types(tGeminiParameters))

    ; The chain the rule is actually about: the registry's own emitted schemas, not this class's
    ; fixture, through both translators.
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ProviderTools", .tLive), "the live tool array builds")
    Do $$$AssertTrue(+$Get(tLive) > 0, "and advertises at least one tool: " _ +$Get(tLive))
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToOpenAi", .tLive, .tLiveOpenAi), "the live array translates into OpenAI declarations")
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tLive, .tLiveGemini), "and into Gemini declarations")
    Do $$$AssertEquals(..Outside(tLiveOpenAi, 0), "", "no OpenAI declaration carries a keyword outside the emitted subset: " _ ..Outside(tLiveOpenAi, 0))
    Do $$$AssertEquals(..Outside(tLiveGemini, 1), "", "and no Gemini declaration does either: " _ ..Outside(tLiveGemini, 1))

    ; Two tool-name grammars, one inside the other: the wire pattern is OpenAI's published one, and
    ; the canonical pattern above it starts every segment with a letter, which is the one thing
    ; Gemini requires and OpenAI's does not. A later widening of either is what this pins.
    Do $$$AssertEquals($Parameter(..#REGISTRY, "WIRENAMEPATTERN"), ..#VENDORNAMEPATTERN, "the wire-name grammar is OpenAI's published one")
    Do $$$AssertEquals($Parameter(..#REGISTRY, "TOOLNAMEPATTERN"), ..#CANONICALNAMEPATTERN, "and every canonical name it admits begins with a letter, which is what Gemini additionally requires")
}

/// <p>Every keyword the schemas under <var>pDeclarations</var> carry, at any depth, that the locked
/// rule does not admit -- comma-separated, or <code>""</code> when there is none. <var>pGemini</var>
/// reads that dialect's shape, whose declarations sit under <code>functionDeclarations</code>.</p>
ClassMethod Outside(pDeclarations As %DynamicArray, pGemini As %Boolean) As %String
{
    Kill tSeen
    Set tList = pDeclarations
    If pGemini {
        If pDeclarations.%Size() = 0 Quit ""
        Set tList = pDeclarations.%Get(0).%Get("functionDeclarations")
    }
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tSchema = $Select(pGemini: tEntry.%Get("parameters"), 1: tEntry.%Get("function").%Get("parameters"))
        Do ..Keywords(tSchema, .tSeen)
    }
    Set tAdmitted = "," _ ..#RULETOPKEYWORDS _ "," _ ..#RULEKEYWORDS _ ","
    Set tOutside = ""
    Set tKey = $Order(tSeen(""))
    While tKey '= "" {
        If '(tAdmitted [ ("," _ tKey _ ",")) Set tOutside = tOutside _ $Select(tOutside = "": "", 1: ",") _ tKey
        Set tKey = $Order(tSeen(tKey))
    }
    Quit tOutside
}

/// <p>The matrix's OpenAI request row -- a leading <code>system</code> message, the assistant's
/// <code>tool_calls</code> carrying <code>id</code>, <code>type</code>, <code>function.name</code>
/// and <code>function.arguments</code> as JSON <b>text</b>, and one <code>tool</code> message per
/// result carrying <code>tool_call_id</code>.</p>
Method TestTheOpenAiRequestCarriesThatDialectsOwnFields()
{
    Do ..Canonical(.tMessages)
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToOpenAi", .tMessages, ..#SYSTEMPROMPT, .tOut), "the canonical history translates")
    Do $$$AssertEquals(tOut.%Get(0).%Get("role"), "system", "the system prompt leads the array as its own message")
    Do $$$AssertEquals(tOut.%Get(0).%Get("content"), ..#SYSTEMPROMPT, "carrying the prompt")
    Do $$$AssertEquals(tOut.%Get(1).%Get("role"), "user", "then the plain user message")
    Do $$$AssertEquals(tOut.%Get(1).%Get("content"), "what is on this screen", "with its content as a string")
    Set tAssistant = tOut.%Get(2)
    Do $$$AssertEquals(tAssistant.%Get("role"), "assistant", "then the assistant echo")
    Do $$$AssertEquals(tAssistant.%Get("content"), "checking", "whose text blocks became its content")
    Set tCalls = tAssistant.%Get("tool_calls")
    Do $$$AssertEquals(tCalls.%Size(), 2, "and whose two tool-use blocks became two tool calls")
    Do $$$AssertEquals(tCalls.%Get(0).%Get("id"), "call1", "the canonical id passes through")
    Do $$$AssertEquals(tCalls.%Get(0).%Get("type"), "function", "the call declares the function type")
    Do $$$AssertEquals(tCalls.%Get(0).%Get("function").%Get("name"), ..#TOOLNAME, "and names the tool")
    Do $$$AssertEquals(tCalls.%Get(0).%Get("function").%GetTypeOf("arguments"), "string", "the arguments are JSON text and not an object, which is what this dialect requires")
    Do $$$AssertEquals(tCalls.%Get(0).%Get("function").%Get("arguments"), "{""maxRows"":5}", "carrying the canonical input")
    Do $$$AssertEquals(tOut.%Get(3).%Get("role"), "tool", "each result is its own tool message")
    Do $$$AssertEquals(tOut.%Get(3).%Get("tool_call_id"), "call1", "keyed by the call it answers")
    Do $$$AssertEquals(tOut.%Get(3).%Get("content"), "first", "and carrying the result")
    Do $$$AssertEquals(tOut.%Get(4).%Get("tool_call_id"), "call2", "the second result answers the second call")
    Do $$$AssertEquals(tOut.%Get(5).%Get("role"), "user", "and the text the same canonical message carried follows its results")
    Do $$$AssertEquals(tOut.%Get(5).%Get("content"), "and now", "as an ordinary user message")
    Do $$$AssertEquals(tOut.%Size(), 6, "six messages and no more: " _ tOut.%ToJSON())
}

/// <p>The two OpenAI request shapes <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> itself
/// produces: an assistant message whose blocks are calls alone, and the user message whose blocks
/// are results alone. The first sends <code>content</code> JSON <code>null</code>; the second sends
/// its tool messages and no empty message beside them.</p>
/// <p>Mutation: send that <code>content</code> as a string, or drop the empty-companion
/// <code>Continue</code> -- this method goes red on each.</p>
Method TestTheOpenAiRequestSendsTheLoopsCallsOnlyAndResultsOnlyShapes()
{
    Kill tMessages
    Set tMessages = 2
    Set tMessages(1, "role") = "assistant"
    Set tMessages(1, "blocks") = "[{""type"":""tool_use"",""id"":""call1"",""name"":""" _ ..#TOOLNAME _ """,""input"":{""maxRows"":5}}]"
    Set tMessages(2, "role") = "user"
    Set tMessages(2, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":""call1"",""content"":""first""}]"
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToOpenAi", .tMessages, "", .tOut), "the loop's own two shapes translate")
    Do $$$AssertEquals(tOut.%Size(), 2, "into one assistant message and one tool message and nothing else: " _ tOut.%ToJSON())
    Do $$$AssertEquals(tOut.%Get(0).%Get("role"), "assistant", "the calls-only message keeps its role")
    Do $$$AssertEquals(tOut.%Get(0).%GetTypeOf("content"), "null", "and sends content null, which is what this dialect requires of a message that is calls alone")
    Do $$$AssertEquals(tOut.%Get(0).%Get("tool_calls").%Size(), 1, "carrying its one call")
    Do $$$AssertEquals(tOut.%Get(1).%Get("role"), "tool", "and the results-only message travels as its tool message alone")
    Do $$$AssertEquals(tOut.%Get(1).%Get("tool_call_id"), "call1", "keyed by the call it answers")
}

/// <p>A canonical <code>input</code>, and a reply's arguments, that is a JSON array is not an
/// object: no request carries array text where the dialect declares an object, and no canonical
/// <code>tool_use</code> leaves the reply direction with a non-object <code>input</code>, which is
/// what <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> reads off the block.</p>
/// <p>Mutation: accept any OREF in
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.ArgumentsObject</method> -- the OpenAI reply leg
/// goes red.</p>
Method TestAnArrayIsNeverSentAsArgumentsAndNeverBecomesACanonicalInput()
{
    Kill tMessages
    Set tMessages = 1
    Set tMessages(1, "role") = "assistant"
    Set tMessages(1, "blocks") = "[{""type"":""tool_use"",""id"":""call1"",""name"":""" _ ..#TOOLNAME _ """,""input"":[1,2]}]"
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToOpenAi", .tMessages, "", .tOut), "a history whose input is an array translates")
    Do $$$AssertEquals(tOut.%Get(0).%Get("tool_calls").%Get(0).%Get("function").%Get("arguments"), "{}", "and the OpenAI call carries an empty object rather than array text")
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tContents, .tSystem), "the Gemini direction translates it too")
    Do $$$AssertEquals(tContents.%Get(0).%Get("parts").%Get(0).%Get("functionCall").%GetTypeOf("args"), "object", "carrying an object for args and never the array")

    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set tResponse.Text = ..#UNTOUCHED
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", ..#OPENAIARRAYARGSREPLY, tResponse), "an arguments value that is an array is refused rather than carried into a canonical block")
    Do $$$AssertEquals(tResponse.Text, ..#UNTOUCHED, "with nothing reported as a reply")
    Do $$$AssertEquals(tResponse.ToolCallsJson, "", "and no canonical blocks")

    Set tGeminiResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", ..#GEMINIARRAYARGSREPLY, tGeminiResponse), "the Gemini reply reads")
    Set tGeminiBlocks = ##class(%DynamicAbstractObject).%FromJSON(tGeminiResponse.ToolCallsJson)
    Do $$$AssertEquals(tGeminiBlocks.%Get(0).%GetTypeOf("input"), "object", "and its canonical block carries an object input, never the array the model sent")
}

/// <p>A tool call the next request could never answer -- an OpenAI call with no <code>id</code>, a
/// Gemini <code>functionCall</code> naming no function -- is refused at the reply direction rather
/// than stored, because a canonical history carrying one refuses every later request in that
/// conversation.</p>
/// <p>Mutation: drop either guard in
/// <class>OcuPilot.Kernel.Provider.MessageAdapter</class> -- its leg goes red.</p>
Method TestAReplysUnanswerableToolCallIsRefusedRatherThanStored()
{
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set tResponse.Text = ..#UNTOUCHED
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", ..#OPENAIIDLESSREPLY, tResponse), "an OpenAI tool call carrying no id is refused")
    Do $$$AssertEquals(tResponse.Text, ..#UNTOUCHED, "with nothing reported as a reply")
    Do $$$AssertEquals(tResponse.ToolCallsJson, "", "and no canonical block stored for a later request to fail on")

    Set tGeminiResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set tGeminiResponse.Text = ..#UNTOUCHED
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", ..#GEMININAMELESSREPLY, tGeminiResponse), "a Gemini functionCall naming no function is refused too")
    Do $$$AssertEquals(tGeminiResponse.ToolCallsJson, "", "with no canonical block stored")
}

/// <p>The matrix's Gemini request row -- roles <code>user</code> and <code>model</code>, the
/// system prompt in <code>systemInstruction.parts[].text</code>, <code>functionCall</code> parts,
/// and <code>functionResponse</code> parts correlated by <b>name</b> in call order.</p>
Method TestTheGeminiRequestCarriesThatDialectsOwnFields()
{
    Do ..Canonical(.tMessages)
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, ..#SYSTEMPROMPT, .tContents, .tSystem), "the canonical history translates")
    Do $$$AssertEquals(tSystem.%Get("parts").%Get(0).%Get("text"), ..#SYSTEMPROMPT, "the system prompt travels as a system instruction rather than as a message")
    Do $$$AssertEquals(tContents.%Size(), 3, "one content per canonical message: " _ tContents.%ToJSON())
    Do $$$AssertEquals(tContents.%Get(0).%Get("role"), "user", "the user message keeps its role")
    Do $$$AssertEquals(tContents.%Get(0).%Get("parts").%Get(0).%Get("text"), "what is on this screen", "with its content as a text part")
    Set tModel = tContents.%Get(1)
    Do $$$AssertEquals(tModel.%Get("role"), "model", "the assistant message is this dialect's model role")
    Do $$$AssertEquals(tModel.%Get("parts").%Get(0).%Get("text"), "checking", "its text is a text part")
    Do $$$AssertEquals(tModel.%Get("parts").%Get(1).%Get("functionCall").%Get("name"), ..#TOOLNAME, "its first tool use is a functionCall part")
    Do $$$AssertEquals(tModel.%Get("parts").%Get(1).%Get("functionCall").%Get("args").%Get("maxRows"), 5, "carrying the canonical input as an object and not as text")
    Do $$$AssertEquals(tModel.%Get("parts").%Get(2).%Get("functionCall").%Get("args").%Get("maxRows"), 9, "and the second call its own")
    Set tResults = tContents.%Get(2).%Get("parts")
    Do $$$AssertEquals(tResults.%Get(0).%Get("functionResponse").%Get("name"), ..#TOOLNAME, "a result correlates by the function name its id resolved to")
    Do $$$AssertEquals(tResults.%Get(0).%Get("functionResponse").%Get("response").%Get("content"), "first", "carrying the first call's result")
    Do $$$AssertEquals(tResults.%Get(1).%Get("functionResponse").%Get("response").%Get("content"), "second", "and the second call's second, so two calls to one tool stay correlated by order")
    Do $$$AssertEquals(tResults.%Get(2).%Get("text"), "and now", "with the message's own text after them")
    Do $$$AssertEquals(tContents.%Get(2).%Get("role"), "user", "and the whole answering message is a user turn")
}

/// <p>AC4 -- a <code>tool_result</code> with no preceding <code>tool_use</code> is an error
/// <class>%Status</class> in both dialects, with nothing translated, rather than a result silently
/// dropped from the request.</p>
/// <p>Mutation: in <class>OcuPilot.Kernel.Provider.MessageAdapter</class>, raise instead of
/// answering <method>UnmatchedResult</method> -- these legs go red on the status.</p>
Method TestAnUnmatchedToolResultIsRefusedByBothRequestDirections()
{
    Do ..Unmatched(.tMessages)
    Set tOpenAiSC = $ClassMethod(..#MESSAGES, "CanonicalToOpenAi", .tMessages, "", .tOpenAi)
    Do $$$AssertStatusNotOK(tOpenAiSC, "the OpenAI direction refuses a result answering a call nothing made")
    Do $$$AssertEquals(tOpenAi.%Size(), 0, "and translates nothing, so no call can be made from it")
    Set tGeminiSC = $ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tContents, .tSystem)
    Do $$$AssertStatusNotOK(tGeminiSC, "the Gemini direction refuses it too")
    Do $$$AssertEquals(tContents.%Size(), 0, "translating nothing")
    Do $$$AssertEquals(tSystem, "", "and no system instruction either")

    ; A call carrying no id is registered as no call, so a result naming none is refused the same
    ; way rather than travelling as tool_call_id "" for the provider to reject.
    Kill tBlank
    Set tBlank = 2
    Set tBlank(1, "role") = "assistant"
    Set tBlank(1, "blocks") = "[{""type"":""tool_use"",""id"":"""",""name"":""" _ ..#TOOLNAME _ """,""input"":{}}]"
    Set tBlank(2, "role") = "user"
    Set tBlank(2, "blocks") = "[{""type"":""tool_result"",""tool_use_id"":"""",""content"":""first""}]"
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "CanonicalToOpenAi", .tBlank, "", .tBlankOpenAi), "an id-less call and the result naming it are refused, not correlated to each other")
    Do $$$AssertEquals(tBlankOpenAi.%Size(), 0, "with nothing translated")
}

/// <p>The matrix's OpenAI reply row -- text, canonical <code>tool_use</code> blocks whose
/// <code>input</code> is an object, the stop reason in the canonical vocabulary, and both token
/// counts from this dialect's own field names.</p>
Method TestTheOpenAiReplyBecomesCanonicalBlocks()
{
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", ..#OPENAIREPLY, tResponse), "the reply reads")
    Do $$$AssertEquals(tResponse.Text, "looking", "the message content is the reply's text")
    Set tBlocks = ##class(%DynamicAbstractObject).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tBlocks.%Size(), 1, "one canonical tool-use block")
    Do $$$AssertEquals(tBlocks.%Get(0).%Get("type"), "tool_use", "of the canonical type the loop reads")
    Do $$$AssertEquals(tBlocks.%Get(0).%Get("id"), "call1", "carrying the dialect's own call id")
    Do $$$AssertEquals(tBlocks.%Get(0).%Get("name"), ..#TOOLNAME, "and the tool's name")
    Do $$$AssertEquals(tBlocks.%Get(0).%GetTypeOf("input"), "object", "with the arguments parsed into an object, which is what the loop reads off it")
    Do $$$AssertEquals(tBlocks.%Get(0).%Get("input").%Get("maxRows"), 5, "carrying the argument")
    Do $$$AssertEquals(tResponse.StopReason, "tool_use", "the stop reason is the canonical one and not the dialect's spelling")
    Do $$$AssertEquals(tResponse.RequestTokens, 31, "the request tokens come from prompt_tokens")
    Do $$$AssertEquals(tResponse.ResponseTokens, 7, "and the reply tokens from completion_tokens")

    ; Every reason the dialect can send maps into the canonical vocabulary, and one it cannot is
    ; normalized rather than carried through.
    For tCase = "length:max_tokens", "content_filter:refusal", "stop:end_turn", "something_new:end_turn" {
        Set tBody = "{""choices"":[{""message"":{""content"":""x""},""finish_reason"":""" _ $Piece(tCase, ":", 1) _ """}]}"
        Set tMapped = ##class(OcuPilot.Kernel.Provider.Response).%New()
        Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", tBody, tMapped), "the reply reads for " _ tCase)
        Do $$$AssertEquals(tMapped.StopReason, $Piece(tCase, ":", 2), "the stop reason maps: " _ tCase)
    }
}

/// <p>The matrix's Gemini reply row -- text, canonical blocks with an adapter-synthesized id, and
/// the <b>round trip closing</b>: feeding those blocks back through the request direction resolves
/// each id to the function it came from.</p>
Method TestTheGeminiReplyBecomesCanonicalBlocksAndTheRoundTripCloses()
{
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", ..#GEMINIREPLY, tResponse), "the reply reads")
    Do $$$AssertEquals(tResponse.Text, "looking", "the text parts are concatenated")
    Set tBlocks = ##class(%DynamicAbstractObject).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tBlocks.%Size(), 2, "both function calls became canonical blocks")
    Do $$$AssertEquals(tBlocks.%Get(0).%Get("name"), ..#TOOLNAME, "each naming its function")
    Do $$$AssertTrue(tBlocks.%Get(0).%Get("id") '= "", "each carrying a synthesized id, because the dialect sends none")
    Do $$$AssertTrue(tBlocks.%Get(0).%Get("id") '= tBlocks.%Get(1).%Get("id"), "and the two ids differ, so the results cannot be confused: " _ tResponse.ToolCallsJson)
    Do $$$AssertEquals(tBlocks.%Get(1).%Get("input").%Get("maxRows"), 9, "with each call's own arguments as an object")
    Do $$$AssertEquals(tResponse.StopReason, "tool_use", "a reply that called a tool stops for that reason, whatever finishReason said")
    Do $$$AssertEquals(tResponse.RequestTokens, 41, "the request tokens come from promptTokenCount")
    Do $$$AssertEquals(tResponse.ResponseTokens, 11, "and the reply tokens from candidatesTokenCount")

    ; The round trip: the ids this reply synthesized are the ids the next request resolves.
    Kill tMessages
    Set tMessages = 2
    Set tMessages(1, "role") = "assistant"
    Set tMessages(1, "blocks") = tResponse.ToolCallsJson
    Set tResults = []
    For tI = 0:1:1 {
        Set tResult = {}
        Do tResult.%Set("type", "tool_result", "string")
        Do tResult.%Set("tool_use_id", tBlocks.%Get(tI).%Get("id"), "string")
        Do tResult.%Set("content", "row " _ tI, "string")
        Do tResults.%Push(tResult)
    }
    Set tMessages(2, "role") = "user"
    Set tMessages(2, "blocks") = tResults.%ToJSON()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tContents, .tSystem), "the next request translates, so the round trip closes")
    Set tAnswers = tContents.%Get(1).%Get("parts")
    Do $$$AssertEquals(tAnswers.%Get(0).%Get("functionResponse").%Get("name"), ..#TOOLNAME, "and each synthesized id resolved back to the function it came from")
    Do $$$AssertEquals(tAnswers.%Get(1).%Get("functionResponse").%Get("response").%Get("content"), "row 1", "in the order the results were given")

    ; Every reason the dialect can send, read on a reply that called no tool -- a reply that did
    ; call one is tool_use only where the vendor's reason said no more than that, asserted above.
    ; The three that refuse a tool call are its own vocabulary and map to one canonical refusal.
    For tCase = "MAX_TOKENS:max_tokens", "SAFETY:refusal", "SPII:refusal", "LANGUAGE:refusal", "MALFORMED_FUNCTION_CALL:refusal", "UNEXPECTED_TOOL_CALL:refusal", "TOO_MANY_TOOL_CALLS:refusal", "STOP:end_turn", "OTHER:end_turn", "SOMETHINGNEW:end_turn" {
        Set tBody = "{""candidates"":[{""content"":{""parts"":[{""text"":""x""}]},""finishReason"":""" _ $Piece(tCase, ":", 1) _ """}]}"
        Set tMapped = ##class(OcuPilot.Kernel.Provider.Response).%New()
        Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", tBody, tMapped), "the reply reads for " _ tCase)
        Do $$$AssertEquals(tMapped.StopReason, $Piece(tCase, ":", 2), "the stop reason maps: " _ tCase)
    }
    ; A reply that called a tool and was also truncated keeps the reason a caller can act on.
    Set tTruncated = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", "{""candidates"":[{""content"":{""parts"":[{""functionCall"":{""name"":""t"",""args"":{}}}]},""finishReason"":""MAX_TOKENS""}]}", tTruncated), "a truncated tool-calling reply reads")
    Do $$$AssertEquals(tTruncated.StopReason, "max_tokens", "and reports the truncation rather than losing it behind tool_use")
}

/// <p>A Gemini reply whose <b>first</b> function call carries the optional vendor <code>id</code>
/// and whose second does not, so one body exercises both halves of DW-1180.</p>
Parameter GEMINIVENDORIDREPLY = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""functionCall"":{""id"":""fc-42"",""name"":""logs_errors_read"",""args"":{""maxRows"":5}}},{""functionCall"":{""name"":""logs_errors_read"",""args"":{""maxRows"":9}}}]},""finishReason"":""STOP""}]}";

/// <p>Story 10.2's AC6 (DW-1180) -- a vendor <code>functionCall.id</code> survives into the
/// canonical block and is echoed on the <code>functionResponse</code> that answers it, while a call
/// the provider sent without one keeps the synthesized id, is answered by name, and echoes
/// nothing: a synthesized id names a correlation the provider never made.</p>
/// <p>mutation: make <method>OcuPilot.Kernel.Provider.MessageAdapter.GeminiToCanonical</method>
/// synthesize an id even where the reply carried one -- red on the echoed
/// <code>functionResponse.id</code>.</p>
Method TestAVendorGeminiCallIdSurvivesTheRoundTrip()
{
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", ..#GEMINIVENDORIDREPLY, tResponse), "the reply reads")
    Set tBlocks = ##class(%DynamicAbstractObject).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tBlocks.%Size(), 2, "both function calls became canonical blocks")
    Do $$$AssertEquals(tBlocks.%Get(0).%Get("id"), "fc-42", "the vendor's own call id is kept rather than replaced")
    Set tPrefix = $Parameter(..#MESSAGES, "GEMINICALLIDPREFIX")
    Do $$$AssertEquals($Extract(tBlocks.%Get(1).%Get("id"), 1, $Length(tPrefix)), tPrefix, "and the call that carried none gets a synthesized one: " _ tBlocks.%Get(1).%Get("id"))

    Kill tMessages
    Set tMessages = 2
    Set tMessages(1, "role") = "assistant"
    Set tMessages(1, "blocks") = tResponse.ToolCallsJson
    Set tResults = []
    For tI = 0:1:1 {
        Set tResult = {}
        Do tResult.%Set("type", "tool_result", "string")
        Do tResult.%Set("tool_use_id", tBlocks.%Get(tI).%Get("id"), "string")
        Do tResult.%Set("content", "row " _ tI, "string")
        Do tResults.%Push(tResult)
    }
    Set tMessages(2, "role") = "user"
    Set tMessages(2, "blocks") = tResults.%ToJSON()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "CanonicalToGemini", .tMessages, "", .tContents, .tSystem), "the next request translates")
    Set tAnswers = tContents.%Get(1).%Get("parts")
    Do $$$AssertEquals(tAnswers.%Get(0).%Get("functionResponse").%Get("id"), "fc-42", "and the functionResponse answering the vendor's call echoes its id")
    Do $$$AssertEquals(tAnswers.%Get(0).%Get("functionResponse").%Get("name"), ..#TOOLNAME, "beside the name the dialect requires")
    Do $$$AssertEquals(tAnswers.%Get(1).%Get("functionResponse").%GetTypeOf("id"), "unassigned", "while the one answering a synthesized id echoes no id at all")
    Do $$$AssertEquals(tAnswers.%Get(1).%Get("functionResponse").%Get("name"), ..#TOOLNAME, "and is correlated by name and order, as before")
    Do $$$AssertEquals(tAnswers.%Get(1).%Get("functionResponse").%Get("response").%Get("content"), "row 1", "carrying its own result")

    ; The call side of the same request: an answer carrying an id must answer a call carrying it,
    ; or the functionResponse names a call this request does not identify.
    Set tCalls = tContents.%Get(0).%Get("parts")
    Do $$$AssertEquals(tCalls.%Get(0).%Get("functionCall").%Get("id"), "fc-42", "the replayed functionCall carries the same id its answer echoes")
    Do $$$AssertEquals(tCalls.%Get(1).%GetTypeOf("functionCall"), "object", "and the second call is replayed too")
    Do $$$AssertEquals(tCalls.%Get(1).%Get("functionCall").%GetTypeOf("id"), "unassigned", "carrying no id, as its answer carries none: a call id travels on both parts or on neither")
}

/// <p>Story 10.2's AC7 -- every canonical tool the registry advertises has a wire name that fits
/// the grammar both vendors admit, asserted over
/// <method>OcuPilot.Screen.Tool.Registry.WireName</method>'s own output for every live canonical
/// name.</p>
/// <p><b>Asserted against the transform, not against
/// <method>OcuPilot.Screen.Tool.Registry.ProviderTools</method>'s output</b>: that method already
/// refuses a name failing <parameter>OcuPilot.Screen.Tool.Registry.WIRENAMEPATTERN</parameter> and
/// answers an error <class>%Status</class> instead of emitting it, so a grammar check over what it
/// emitted could not fail. The pattern is spelled here rather than read from the registry, so
/// widening both copies together still reddens.</p>
/// <p>mutation: have <method>OcuPilot.Screen.Tool.Registry.WireName</method> leave one dot in
/// place -- red on the per-name assertion, naming that tool.</p>
Method TestEveryWireToolNameFitsBothVendorGrammars()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tList), "the live canonical tool list builds")
    Do $$$AssertTrue($IsObject(tList) && (tList.%Size() > 0), "and advertises at least one tool")
    If '$IsObject(tList) Quit
    Set tOutside = ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tWire = $ClassMethod(..#REGISTRY, "WireName", tTool.%Get("name"))
        If $Match(tWire, ..#SHAREDNAMEPATTERN) Continue
        Set tOutside = tOutside _ $Select(tOutside = "": "", 1: ",") _ tTool.%Get("name") _ "->" _ tWire
    }
    Do $$$AssertEquals(tOutside, "", "every canonical name's wire name is inside both families' grammars -- letters, digits, underscore and hyphen, 1 to 64, and a leading letter, which is narrower than either: " _ tOutside)
}

/// <p>AC4 -- the three unreadable replies the matrix names are each an error
/// <class>%Status</class> and never a successful empty reply: an <code>arguments</code> string
/// that will not parse, a body with no <code>choices</code>, and a body with no
/// <code>candidates</code>.</p>
Method TestAnUnreadableReplyIsAnErrorAndNeverAnEmptyOne()
{
    Set tBadArguments = "{""choices"":[{""message"":{""tool_calls"":[{""id"":""c"",""type"":""function"",""function"":{""name"":""t"",""arguments"":""not json at all""}}]},""finish_reason"":""tool_calls""}]}"
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set tResponse.Text = ..#UNTOUCHED
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", tBadArguments, tResponse), "arguments that will not parse are refused")
    Do $$$AssertEquals(tResponse.Text, ..#UNTOUCHED, "and nothing is reported as a reply")
    Set tNoChoices = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", "{""object"":""chat.completion""}", tNoChoices), "a body with no choices array is refused")
    Set tNotObject = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", "[]", tNotObject), "and so is a body that is not an object at all")
    Set tNoMessage = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", "{""choices"":[{""index"":0,""finish_reason"":""stop""}]}", tNoMessage), "a first choice carrying no message is refused rather than answered as an empty reply")
    Set tNoCandidates = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set tNoCandidates.Text = ..#UNTOUCHED
    Do $$$AssertStatusNotOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", "{""usageMetadata"":{}}", tNoCandidates), "a Gemini body with no candidates array is refused")
    Do $$$AssertEquals(tNoCandidates.Text, ..#UNTOUCHED, "reporting no reply either")
    ; A candidate that carried no parts is an empty answer and not a failure: the model answered.
    Set tEmpty = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", "{""candidates"":[{""content"":{""role"":""model"",""parts"":[]}},{}],""usageMetadata"":{""promptTokenCount"":3}}", tEmpty), "a candidate with no parts is an empty reply rather than an error")
    Do $$$AssertEquals(tEmpty.StopReason, "end_turn", "with the default stop reason")
    Do $$$AssertEquals(tEmpty.RequestTokens, 3, "and the usage it did report")
}

/// <p>The matrix's two definition rows' error columns -- a schema that will not parse advertises
/// its tool with no properties in both dialects, and never fails the call, as
/// <method>OcuPilot.Kernel.Provider.Anthropic.SchemaOf</method> already does.</p>
Method TestASchemaThatWillNotParseStillAdvertisesItsTool()
{
    Kill tTools
    Set tTools = 1
    Set tTools(1, "name") = ..#TOOLNAME
    Set tTools(1, "description") = "read the error log"
    Set tTools(1, "inputSchema") = "{not json"
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToOpenAi", .tTools, .tOpenAi), "the OpenAI declarations are built anyway")
    Do $$$AssertEquals(tOpenAi.%Size(), 1, "the tool is still advertised")
    Do $$$AssertEquals(tOpenAi.%Get(0).%Get("function").%Get("parameters").%ToJSON(), "{}", "with no properties rather than none of the call")
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tTools, .tGemini), "and the Gemini declarations likewise")
    Do $$$AssertEquals(tGemini.%Get(0).%Get("functionDeclarations").%Get(0).%Get("parameters").%ToJSON(), "{}", "with no properties")
    ; An empty tool array sends no declarations at all, in either dialect.
    Kill tNone
    Set tNone = 0
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tNone, .tNoGemini), "an empty tool array translates")
    Do $$$AssertEquals(tNoGemini.%Size(), 0, "into no declaration entry, so a caller sends no tools rather than an empty list")
}

/// <p>Gap-fill (QA) -- <method>OcuPilot.Kernel.Provider.ToolDefAdapter.GeminiSchema</method>'s
/// corrected doc claim: a keyword outside the locked subset is copied through unchanged, because
/// keeping such a keyword out is <method>OcuPilot.Screen.Tool.Registry.EmitSchema</method>'s job
/// and not this method's.</p>
/// <p>Mutation: drop the method's fallback <code>Do tOut.%Set(tKey, tValue)</code> branch -- this
/// goes red on the copied-through keyword.</p>
Method TestGeminiSchemaCopiesAnUnrecognizedKeywordThroughUnchanged()
{
    Kill tTools
    Set tTools = 1
    Set tTools(1, "name") = ..#TOOLNAME
    Set tTools(1, "description") = "read the error log"
    Set tTools(1, "inputSchema") = "{""type"":""object"",""properties"":{""code"":{""type"":""string"",""pattern"":""^[A-Z]+$""}},""required"":[]}"
    Do $$$AssertStatusOK($ClassMethod(..#TOOLDEFS, "ToGemini", .tTools, .tGemini), "a schema carrying a keyword outside the locked subset still translates")
    Set tProperty = tGemini.%Get(0).%Get("functionDeclarations").%Get(0).%Get("parameters").%Get("properties").%Get("code")
    Do $$$AssertEquals(tProperty.%Get("pattern"), "^[A-Z]+$", "the keyword outside the subset is copied through unchanged rather than refused or dropped")
}

/// <p>AC3's arithmetic at its boundaries -- the work budget's own value, one second either side of
/// it, the divisor boundaries where the attempt count steps down, and a zero timeout, which bounds
/// nothing because such an attempt spends no time.</p>
Method TestTheClampAnswersItsBoundaryCases()
{
    Set tWork = $ClassMethod(..#RETRY, "WorkBudgetSec")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveTimeoutSec", tWork), tWork, "a timeout exactly the work budget is unchanged")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveTimeoutSec", tWork - 1), tWork - 1, "one second below it is unchanged")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveTimeoutSec", tWork + 1), tWork, "one second above it is cut to it")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveAttempts", 5, tWork), 1, "a timeout the whole budget holds once buys one attempt")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveAttempts", 5, tWork + 1), 1, "and so does one above it")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveAttempts", 5, tWork \ 2), 2, "a timeout it holds twice buys two")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveAttempts", 5, (tWork \ 2) + 1), 1, "one second more than that buys one, because a whole second attempt no longer fits")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveAttempts", 1, tWork \ 4), 1, "a stored count below what fits is never raised to it")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveAttempts", 0, 90), 1, "a stored count of zero still makes one attempt")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "EffectiveAttempts", 5, 0), 5, "a zero timeout bounds nothing, because such an attempt waits not at all")
}

/// <p>AC5 -- the canonical family is a passthrough: the body a call built before this story is the
/// body it builds now, byte for byte, and none of the other dialects' field names appears in
/// it.</p>
/// <p>Mutation: route <method>OcuPilot.Kernel.Provider.Anthropic.CallMessages</method> through
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.CanonicalToOpenAi</method> -- this goes red on
/// the body.</p>
Method TestTheCanonicalFamilyIsAByteIdenticalPassthrough()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":1}}")
    Do ..Canonical(.tMessages)
    Do ..Tools(.tTools)
    Do $ClassMethod("OcuPilot.Test.Provider", "Values", .tValues)
    Set tValues("model") = "probe-model-1"
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 1)
    Set tAdapter = ##class(OcuPilot.Test.AdapterProvider).%New()
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Set tSC = tAdapter.Invoke(.tValues, .tMessages, .tTools, ..#SYSTEMPROMPT, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Set tAdapter = ""
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Set tBody = $ZConvert(##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "I", "UTF8")
    Do $$$AssertEquals(tBody, ..#CANONICALBODY, "the canonical body is byte-identical to the one these inputs produced before the translators existed")
    For tForeign = "tool_calls", "tool_call_id", "contents", "functionCall", "functionResponse", "systemInstruction", "parameters", "functionDeclarations" {
        Do $$$AssertEquals(tBody [ tForeign, 0, "and carries no field of another dialect: " _ tForeign)
    }
}

/// <p>Story 10.4 -- the Anthropic reply mapping keeps a reply's whole <code>content</code> array in
/// <property>OcuPilot.Kernel.Provider.Response.ContentJson</property> when it carries a
/// <code>thinking</code> or <code>redacted_thinking</code> block, and leaves it <code>""</code>
/// otherwise; <property>Text</property> and <property>ToolCallsJson</property> read the same
/// either way.</p>
Method TestAnthropicKeepsAReasoningReplysContentVerbatim()
{
    Set tTail = ",{""type"":""text"",""text"":""looking""},{""type"":""tool_use"",""id"":""toolu_1"",""name"":""" _ ..#TOOLNAME _ """,""input"":{""maxRows"":5}}]"
    Set tAdapter = ##class(OcuPilot.Kernel.Provider.Anthropic).%New()
    For tLead = "{""type"":""thinking"",""thinking"":"""",""signature"":""Eq+ab/cd==""}", "{""type"":""redacted_thinking"",""data"":""Rm9v+YmFy/==""}" {
        Set tContent = "[" _ tLead _ tTail
        Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
        Do $$$AssertStatusOK(tAdapter.MapResponse("{""content"":" _ tContent _ ",""stop_reason"":""tool_use""}", tResponse), "the reasoning reply reads")
        Do $$$AssertEquals(tResponse.ContentJson, ##class(%DynamicAbstractObject).%FromJSON(tContent).%ToJSON(), "its whole content array is kept: " _ tLead)
        Do $$$AssertEquals(tResponse.Text, "looking", "the text is read as before")
        Do $$$AssertEquals(##class(%DynamicAbstractObject).%FromJSON(tResponse.ToolCallsJson).%Size(), 1, "and the tool calls hold the one tool-use block alone")
    }
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK(tAdapter.MapResponse("{""content"":[" _ $Extract(tTail, 2, *) _ ",""stop_reason"":""tool_use""}", tResponse), "a reply without reasoning reads")
    Do $$$AssertEquals(tResponse.ContentJson, "", "and keeps no content array")
    Do $$$AssertEquals(tResponse.Text, "looking", "its text is read")
    Do $$$AssertTrue(tResponse.ToolCallsJson [ """toolu_1""", "and its tool call")
}

/// <p>The canonical outbound body <method>TestTheCanonicalFamilyIsAByteIdenticalPassthrough</method>
/// pins, read from the request the shipped Anthropic adapter actually built on the development
/// instance for <method>Canonical</method>'s history and <method>Tools</method>'s array.</p>
Parameter CANONICALBODY = "{""model"":""probe-model-1"",""max_tokens"":4000,""system"":""you are a probe"",""messages"":[{""role"":""user"",""content"":""what is on this screen""},{""role"":""assistant"",""content"":[{""type"":""text"",""text"":""checking""},{""type"":""tool_use"",""id"":""call1"",""name"":""logs_errors_read"",""input"":{""maxRows"":5}},{""type"":""tool_use"",""id"":""call2"",""name"":""logs_errors_read"",""input"":{""maxRows"":9}}]},{""role"":""user"",""content"":[{""type"":""tool_result"",""tool_use_id"":""call1"",""content"":""first""},{""type"":""tool_result"",""tool_use_id"":""call2"",""content"":""second""},{""type"":""text"",""text"":""and now""}]}],""tools"":[{""name"":""logs_errors_read"",""description"":""read the error log"",""input_schema"":{""type"":""object"",""properties"":{""name"":{""type"":""string"",""description"":""the name"",""enum"":[""a"",""b""]},""count"":{""type"":""integer"",""description"":""how many"",""minimum"":1,""maximum"":10},""tags"":{""type"":""array"",""description"":""labels"",""items"":{""type"":""string"",""description"":""one label""},""minItems"":1,""maxItems"":5}},""required"":[""name""],""additionalProperties"":false}}]}";

/// <p>AC2 -- a family that exists only as a probe catalog row plus one adapter class: a caller
/// drives <method>OcuPilot.Port.ProviderPort.Invoke</method> through it, the call completes, and
/// the recorded outbound body is that family's own shape.</p>
/// <p>Mutation: point the probe row's <code>adapterClass</code> at
/// <class>OcuPilot.Kernel.Provider.Anthropic</class> -- the recorded body is the canonical shape
/// and the assertions on the target family's field names go red.</p>
Method TestAProbeFamilyIsOneCatalogRowPlusOneAdapter()
{
    For tCase = 1:1:2 {
        Do $ClassMethod(..#PORT, "Reset")
        Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
        Do $ClassMethod(..#PORT, "SetSslState", "present")
        Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
        Set tKey = $Select(tCase = 1: $Parameter(..#CATALOG, "OPENAIKEY"), 1: $Parameter(..#CATALOG, "GEMINIKEY"))
        Set tDialect = $Select(tCase = 1: $Parameter(..#ADAPTER, "DIALECTOPENAI"), 1: $Parameter(..#ADAPTER, "DIALECTGEMINI"))
        Do ##class(OcuPilot.Test.AdapterProvider).SetDialect(tDialect)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Select(tCase = 1: ..#OPENAIREPLY, 1: ..#GEMINIREPLY))
        Set tId = ..StoredDefinition(tKey)
        If tId = "" Continue
        Do ..Canonical(.tMessages)
        Do ..Tools(.tTools)
        Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, ..#SYSTEMPROMPT, .tResponse, .tHttpStatus, .tFault)
        Do $$$AssertStatusOK(tSC, tDialect _ ": the port returns $$$OK")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), $Parameter(..#ADAPTER, "STUBIDENTITY"), tDialect _ ": the call was served by the class the row's adapterClass column named")
        Do $$$AssertEquals(tResponse.StopReason, "tool_use", tDialect _ ": and the reply arrived as canonical blocks with a canonical stop reason")
        Do $$$AssertTrue(tResponse.ToolCallsJson [ """tool_use""", tDialect _ ": carrying canonical tool-use blocks: " _ tResponse.ToolCallsJson)
        Set tBody = ..Recorded(1)
        Do $$$AssertTrue($IsObject(tBody), tDialect _ ": the outbound body was recorded and is JSON")
        If '$IsObject(tBody) Continue
        If tCase = 1 {
            Do $$$AssertEquals(..Path(tBody, "messages.0.role"), "system", "openai: the outbound body is that dialect's shape, led by a system message")
            Do $$$AssertEquals(..Path(tBody, "tools.0.type"), "function", "openai: with function-typed tool declarations")
            Do $$$AssertEquals(..Path(tBody, "tools.0.function.name"), ..#TOOLNAME, "openai: naming the tool where that dialect names it")
            Do $$$AssertEquals(tBody.%GetTypeOf("contents"), "unassigned", "openai: and none of the other dialect's fields")
        } Else {
            Do $$$AssertEquals(..Path(tBody, "systemInstruction.parts.0.text"), ..#SYSTEMPROMPT, "gemini: the outbound body is that dialect's shape, with the prompt as a system instruction")
            Do $$$AssertEquals(..Path(tBody, "contents.1.role"), "model", "gemini: with the assistant turn as the model role")
            Do $$$AssertEquals(..Path(tBody, "tools.0.functionDeclarations.0.name"), ..#TOOLNAME, "gemini: and its own declaration shape")
            Do $$$AssertEquals(tBody.%GetTypeOf("messages"), "unassigned", "gemini: and none of the other dialect's fields")
        }
    }
}

/// <p>AC4 -- a translation failure met through the port is an ordinary turn error: the port
/// returns <code>$$$OK</code>, the stop reason is <code>error</code>, the fault carries a
/// <code>PROVIDER.*</code> code, and no vendor text and no part of the credential reaches the
/// fault.</p>
Method TestATranslationFailureIsATurnErrorAndNeverAThrow()
{
    Do ##class(OcuPilot.Test.AdapterProvider).SetDialect($Parameter(..#ADAPTER, "DIALECTOPENAI"))
    Set tId = ..StoredDefinition($Parameter(..#CATALOG, "OPENAIKEY"))
    If tId = "" Quit
    ; A request the translator cannot build: no call is made at all.
    Do ..Unmatched(.tMessages)
    Set tSC = $ClassMethod(..#PORT, "Invoke", tId, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, "an untranslatable request still returns $$$OK")
    Do $$$AssertEquals(tResponse.StopReason, "error", "reporting the failure through the stop reason")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no call was made")
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "the fault is PROVIDER.TRANSPORT, which is what a body the adapter could not build already answered")
    Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(..FaultCode(tFault)), "a well-formed machine code")
    Do ..AssertNoLeak(tFault, "the untranslatable request")

    ; A reply the translator cannot read: the call was made and the body refused.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""error"":{""message"":""the vendor's own words""}}")
    Do ..Canonical(.tMessages2)
    Set tSC2 = $ClassMethod(..#PORT, "Invoke", tId, .tMessages2, .tTools, "", .tResponse2, .tHttpStatus2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "an unreadable reply still returns $$$OK")
    Do $$$AssertEquals(tResponse2.StopReason, "error", "reporting the failure through the stop reason")
    Do $$$AssertEquals(tResponse2.Text, "", "with no reply text invented for it")
    Do $$$AssertEquals(..FaultCode(tFault2), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "the fault is PROVIDER.TRANSPORT")
    Do ..AssertNoLeak(tFault2, "the unreadable reply")
}

/// <p><var>pFault</var>'s machine code, or <code>""</code> when the call produced no fault. Read
/// through here so a call that unexpectedly succeeded reports a failed assertion rather than
/// raising <code>&lt;INVALID OREF&gt;</code>.</p>
ClassMethod FaultCode(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.code
}

/// <p>Assert that <var>pFault</var>'s whole rendered envelope carries no vendor message and no
/// part of the probe credential (AD-35, AD-39).</p>
Method AssertNoLeak(pFault As %RawString = "", pWhat As %String)
{
    Set tRendered = $Select($IsObject(pFault): pFault.%ToJSON(), 1: "")
    Do $$$AssertEquals(tRendered [ "the vendor's own words", 0, pWhat _ ": no vendor text reaches the fault (" _ tRendered _ ")")
    Do $$$AssertEquals(tRendered [ ..#PROBEKEY, 0, pWhat _ ": and no part of the credential does either")
    Do $$$AssertEquals(tRendered [ "probe-local-", 0, pWhat _ ": nor its prefix, which no reason on this path states")
}

/// <p>The matrix's clamp rows' logging half -- one informational line when a stored value was
/// lowered, and none at all when the shipped defaults were served, so an operator learns their
/// configuration was not honoured and every other call stays quiet.</p>
/// <p>Mutation: return from <method>OcuPilot.Kernel.Provider.Base.LogClamp</method> before it
/// logs -- the first assertion goes red.</p>
Method TestTheClampLogsOnceWhenItLoweredAValueAndIsSilentOtherwise()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter("OcuPilot.Test.Provider", "OKBODY"))
    Do $ClassMethod("OcuPilot.Test.Provider", "Values", .tValues)
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 3)
    Set tSettings("timeoutSeconds") = 3600
    Set tAdapter = ##class(OcuPilot.Test.AdapterProvider).%New()
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Do $$$AssertStatusOK(tAdapter.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the call with a stored 3600-second timeout returns $$$OK")
    Set tAdapter = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.AdapterProvider).Logged(..#CLAMPMARK), 1, "the clamp logged exactly one line for the call whose timeout and attempt count it lowered")

    ; The same call with the shipped defaults: nothing was lowered, so nothing is said about it.
    Do ##class(OcuPilot.Test.AdapterProvider).Forget()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter("OcuPilot.Test.Provider", "OKBODY"))
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tDefaults, $Parameter("OcuPilot.Kernel.State.Egress", "DEFAULTMAXATTEMPTS"))
    Set tDefaults("timeoutSeconds") = $Parameter("OcuPilot.Kernel.State.Egress", "DEFAULTTIMEOUT")
    Set tSecond = ##class(OcuPilot.Test.AdapterProvider).%New()
    Set tSecond.SecretClassName = "OcuPilot.Test.SecretProbe"
    Do $$$AssertStatusOK(tSecond.Invoke(.tValues, .tMessages, .tTools, "", .tDefaults, .tSecondResponse, .tSecondFault, .tSecondStatus), "the call with the shipped defaults returns $$$OK")
    Set tSecond = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.AdapterProvider).Logged(..#CLAMPMARK), 0, "and said nothing about a clamp, because it lowered nothing")
}

/// <p>Gap-fill (QA) -- the clamp stays silent for a stored attempt count of zero: the loop's own
/// floor (<method>OcuPilot.Kernel.Provider.Retry.EffectiveAttempts</method>) and
/// <method>OcuPilot.Kernel.Provider.Base.LogClamp</method>'s own floor both read zero as "at least
/// one attempt", so the two numbers agree and nothing was actually lowered.</p>
/// <p>Mutation: remove <method>LogClamp</method>'s own <code>tAsked &lt; 1</code> floor -- this
/// goes red on a spurious clamp line for the untouched timeout.</p>
Method TestTheClampStaysSilentForAStoredAttemptCountOfZero()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter("OcuPilot.Test.Provider", "OKBODY"))
    Do $ClassMethod("OcuPilot.Test.Provider", "Values", .tValues)
    Do $ClassMethod("OcuPilot.Test.Provider", "Messages", .tMessages)
    Do $ClassMethod("OcuPilot.Test.Provider", "Settings", .tSettings, 0)
    Set tAdapter = ##class(OcuPilot.Test.AdapterProvider).%New()
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Do $$$AssertStatusOK(tAdapter.Invoke(.tValues, .tMessages, .tTools, "", .tSettings, .tResponse, .tFault, .tHttpStatus), "the call with a stored attempt count of zero returns $$$OK")
    Set tAdapter = ""
    Do $$$AssertEquals(##class(OcuPilot.Test.AdapterProvider).Logged(..#CLAMPMARK), 0, "and the clamp says nothing, because the loop's own floor and the log's floor answer zero the same way")
}

/// <p>DW-1202 -- an OpenAI refusal reaches the canonical reply. The vendor answers 200 with a null
/// <code>content</code>, the model's reason under <code>refusal</code>, and
/// <code>finish_reason</code> still <code>stop</code>, so without reading that member the turn gets
/// an empty reply and is told the model ended normally.</p>
/// <p>mutation: stop reading <code>message.refusal</code> in
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.OpenAiToCanonical</method> -- red on both the
/// text and the stop-reason assertions.</p>
Method TestAnOpenAiRefusalReachesTheCanonicalReply()
{
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", "{""choices"":[{""index"":0,""message"":{""role"":""assistant"",""content"":null,""refusal"":""I cannot help with that""},""finish_reason"":""stop""}]}", tResponse), "the refusal reply reads, rather than failing as a body this adapter could not read")
    Do $$$AssertEquals(tResponse.Text, "I cannot help with that", "the refusal is the canonical reply's text")
    Do $$$AssertEquals(tResponse.StopReason, "refusal", "and the stop reason says the model would not answer, whatever finish_reason said")

    ; A reply carrying both keeps the refusal, which is the one a caller can act on.
    Set tBoth = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", "{""choices"":[{""message"":{""content"":""partial"",""refusal"":""no""},""finish_reason"":""stop""}]}", tBoth), "a reply carrying both reads")
    Do $$$AssertEquals(tBoth.Text _ "|" _ tBoth.StopReason, "no|refusal", "and reports the refusal")

    ; The control: an ordinary reply is unchanged, so the branch is not simply rewriting every
    ; reply's stop reason.
    Set tPlain = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "OpenAiToCanonical", "{""choices"":[{""message"":{""content"":""here it is""},""finish_reason"":""stop""}]}", tPlain), "an ordinary reply reads")
    Do $$$AssertEquals(tPlain.Text _ "|" _ tPlain.StopReason, "here it is|end_turn", "and is unchanged")
}

/// <p>DW-1202 -- a Gemini prompt-level block is a refusal and <b>not</b> a transport fault. The
/// vendor answers 200 carrying <code>promptFeedback.blockReason</code> and no candidates at all;
/// before this that body was "a reply carrying no candidates array", which
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> reports as
/// <code>PROVIDER.TRANSPORT</code>.</p>
/// <p>mutation: remove the <code>promptFeedback</code> branch from
/// <method>OcuPilot.Kernel.Provider.MessageAdapter.GeminiToCanonical</method> -- red on the stop
/// reason and on the assertion that the mapping did not fail.</p>
Method TestAGeminiPromptBlockIsARefusalNotATransportFault()
{
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set tMapSC = $ClassMethod(..#MESSAGES, "GeminiToCanonical", "{""promptFeedback"":{""blockReason"":""SAFETY""},""usageMetadata"":{""promptTokenCount"":7}}", tResponse)
    Do $$$AssertStatusOK(tMapSC, "the blocked reply reads, so the call is not reported as a fault the adapter could not read")
    Do $$$AssertEquals(tResponse.StopReason, "refusal", "the stop reason says the model would not answer")
    Do $$$AssertEquals(tResponse.Text, "SAFETY", "the block reason is the provider's own text")
    Do $$$AssertEquals(tResponse.RequestTokens, 7, "and the usage it reported is kept")

    ; A body with neither candidates nor a block reason is still an error, so the branch has not
    ; turned every unreadable Gemini reply into a refusal. This is also what carries "not a
    ; transport fault": a substring test over an OK status cannot fail, so the discriminating
    ; assertion is that THIS body maps and THAT one does not.
    Set tNeither = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set tNeitherSC = $ClassMethod(..#MESSAGES, "GeminiToCanonical", "{""promptFeedback"":{}}", tNeither)
    Do $$$AssertStatusNotOK(tNeitherSC, "a body naming neither candidates nor a block reason is refused as before")
    Do $$$AssertTrue($System.Status.GetErrorText(tMapSC) '= $System.Status.GetErrorText(tNeitherSC), "and the blocked body's outcome is not the unreadable body's")
}

/// <p>DW-1202 -- every Gemini <code>finishReason</code> the vendor declares maps, and
/// <code>IMAGE_SAFETY</code> is one of them. The map's other eleven entries are asserted by
/// <method>TestTheGeminiReplyBecomesCanonicalBlocksAndTheRoundTripCloses</method>; this method is
/// about the twelfth and about the map's shape.</p>
/// <p><b>What the count pins is the map, not the vendor's vocabulary</b> -- the map is this
/// project's copy of a list the vendor may extend, so a thirteenth reason the vendor ships is
/// unmapped until the parameter learns it and answers the default ending rather than a refusal
/// (inference: no live provider call is made here, per DW-1200). Read the count as "this map is
/// edited deliberately", never as "this is every reason there is".</p>
/// <p>mutation: remove <code>IMAGE_SAFETY</code> from
/// <parameter>OcuPilot.Kernel.Provider.MessageAdapter.GEMINISTOPREASONS</parameter> -- red on that
/// key alone, because an unmapped reason answers the default rather than a refusal.</p>
Method TestEveryGeminiStopReasonMapsAndImageSafetyIsARefusal()
{
    Set tMap = $Parameter(..#MESSAGES, "GEMINISTOPREASONS")
    Do $$$AssertEquals($Length(tMap, ","), 12, "the map declares twelve vendor reasons: " _ tMap)
    Set tRefusals = 0
    For tI = 1:1:$Length(tMap, ",") {
        If $Piece($Piece(tMap, ",", tI), ":", 2) = "refusal" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertEquals(tRefusals, 10, "ten of which mean the model would not answer")

    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(..#MESSAGES, "GeminiToCanonical", "{""candidates"":[{""content"":{""parts"":[{""text"":""x""}]},""finishReason"":""IMAGE_SAFETY""}]}", tResponse), "a reply finished IMAGE_SAFETY reads")
    Do $$$AssertEquals(tResponse.StopReason, "refusal", "and is a refusal rather than an ordinary ending")
}

/// <p>DW-1193 -- a vendor error body whose <code>error.message</code> is not a JSON string yields
/// <b>no</b> provider text, rather than the OREF's own stringification presented to a reader as the
/// provider's words.</p>
/// <p>Driven through every shipped adapter, because the method is now
/// <method>OcuPilot.Kernel.Provider.Base.ProviderMessage</method>'s one implementation and the four
/// families inherit it; a per-family copy is what produced four copies of the defect.</p>
/// <p>mutation: drop the <code>%GetTypeOf</code> test from
/// <method>OcuPilot.Kernel.Provider.Base.ProviderMessage</method> -- red on the empty-text
/// assertion, and specifically on its not containing <code>@%Library.DynamicObject</code>.</p>
Method TestANonStringProviderErrorMessageYieldsNoProviderText()
{
    For tFamily = "OcuPilot.Kernel.Provider.Anthropic", "OcuPilot.Kernel.Provider.OpenAI", "OcuPilot.Kernel.Provider.Gemini", "OcuPilot.Kernel.Provider.Compatible" {
        Set tAdapter = $ClassMethod(tFamily, "%New")
        Set tObjectText = tAdapter.ProviderMessage("{""error"":{""message"":{""code"":42,""detail"":""nested""}}}")
        Do $$$AssertEquals(tObjectText, "", tFamily _ ": an object error.message yields no provider text, got '" _ tObjectText _ "'")
        Do $$$AssertEquals(tObjectText [ "@%Library.DynamicObject", 0, tFamily _ ": and never the OREF's own stringification")
        Set tArrayText = tAdapter.ProviderMessage("{""error"":{""message"":[""one"",""two""]}}")
        Do $$$AssertEquals(tArrayText, "", tFamily _ ": an array error.message yields none either, got '" _ tArrayText _ "'")
        ; The control: a string message still reaches the fault's provider text.
        Do $$$AssertEquals(tAdapter.ProviderMessage("{""error"":{""message"":""the vendor's own words""}}"), "the vendor's own words", tFamily _ ": and a string message is carried")
        Do $$$AssertEquals(tAdapter.ProviderMessage("{""error"":{}}"), "", tFamily _ ": an error object naming no message yields none")
        Do $$$AssertEquals(tAdapter.ProviderMessage("not json"), "", tFamily _ ": and neither does a body that is not JSON")
        Set tAdapter = ""
    }
    ; One implementation, asserted structurally: behaviour cannot tell a shipped method from an
    ; identical copy of it, and four copies are what DW-1193 was.
    For tFamily = "OcuPilot.Kernel.Provider.Anthropic", "OcuPilot.Kernel.Provider.OpenAI", "OcuPilot.Kernel.Provider.Gemini", "OcuPilot.Kernel.Provider.Compatible" {
        Set tCompiled = ##class(%Dictionary.CompiledMethod).%OpenId(tFamily _ "||ProviderMessage", 0, .tOpenSC)
        Do $$$AssertTrue($IsObject(tCompiled), tFamily _ ": its compiled ProviderMessage is readable")
        If $IsObject(tCompiled) Do $$$AssertEquals(tCompiled.Origin, "OcuPilot.Kernel.Provider.Base", tFamily _ ": and originates in the base, so there is one type check rather than four")
        Set tCompiled = ""
    }
}

}
