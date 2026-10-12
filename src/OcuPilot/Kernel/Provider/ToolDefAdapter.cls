/// <p>The canonical tool array in each non-canonical family's declaration shape, request direction
/// only (AD-42). One tool array serves four families because the schema it carries is the locked
/// cross-vendor subset -- top level <code>{type: "object", properties, required,
/// additionalProperties: false}</code>, per property
/// <code>{type, description, enum?, items?, minimum?, maximum?, minItems?, maxItems?}</code>, never
/// <code>$ref</code>, <code>oneOf</code>, <code>anyOf</code>, <code>allOf</code> or
/// <code>pattern</code> -- which <method>OcuPilot.Screen.Tool.Registry.EmitSchema</method> is what
/// produces and this class carries through.</p>
/// <p><b>No method here branches on a provider name.</b> A translator is reached from inside the
/// family adapter that already knows its own dialect, and that adapter is reached from its catalog
/// row's <code>adapterClass</code> column (AD-42).</p>
/// <p><b>OpenAI loses nothing.</b> <method>ToOpenAi</method> puts the emitted schema into
/// <code>tools[].function.parameters</code> unchanged, <code>additionalProperties: false</code>
/// included. Wire contract:
/// <code>tools[] = {type: "function", function: {name, description, parameters}}</code>, function
/// names limited to letters, digits, underscores and dashes, at most 64 characters -- verified
/// against the Chat Completions reference and the function-calling guide at
/// <code>platform.openai.com/docs/guides/function-calling</code> (2026-09-18).</p>
/// <p><b>Gemini loses exactly one keyword: <code>additionalProperties</code></b>, because its
/// <code>Schema</code> type does not carry the field -- the <code>generateContent</code> reference
/// at <code>ai.google.dev/api/generate-content</code> lists
/// <code>type, format, description, nullable, enum, items, properties, required, minimum, maximum,
/// minItems, maxItems</code> and no <code>additionalProperties</code> (2026-09-18). The Vertex AI
/// <code>v1beta1</code> <code>Schema</code> does declare it, so the two references disagree;
/// dropping it is the safe reading either way, and it costs nothing OcuPilot relies on, because
/// <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method> refuses an undeclared argument
/// on the instance whatever the provider was told (AD-11). Wire contract:
/// <code>tools[0].functionDeclarations[] = {name, description, parameters}</code>, a name grammar
/// that is <b>not</b> OpenAI's -- it must start with a letter or an underscore, and admits dots --
/// and <code>Schema.type</code> in Gemini's own upper-case vocabulary
/// (<parameter>GEMINITYPES</parameter>). Every name
/// <method>OcuPilot.Screen.Tool.Registry.WireName</method> can produce satisfies both grammars,
/// because <parameter>OcuPilot.Screen.Tool.Registry.TOOLNAMEPATTERN</parameter> starts every
/// segment with a lowercase letter.</p>
/// <p><b>Gemini respells exactly two kinds of <code>enum</code> member.</b> Its function-declaration
/// validation refuses an empty member, which becomes <parameter>GEMINIEMPTYENUM</parameter>, and
/// takes <code>enum</code> as strings only, so a numeric member of an <code>integer</code> or
/// <code>number</code> property is written as its JSON text (<code>3072</code> as
/// <code>"3072"</code>) while the property keeps its type. No member is dropped, because an empty
/// value can be a real choice (Home's route is <code>""</code>) and dropping one would make what
/// the model can do depend on its family. Both respellings are reversible and scoped:
/// <method>GeminiEmptyEnumArgs</method> names each (tool, argument) pair a request respelled, and
/// <class>OcuPilot.Kernel.Provider.MessageAdapter</class> decodes the value back, to <code>""</code>
/// or to a number, on exactly those pairs in a reply, and encodes it again in replayed history --
/// the same idea as the reversible dot-to-underscore name mapping.</p>
Class OcuPilot.Kernel.Provider.ToolDefAdapter Extends %RegisteredObject
{

/// <p>Each canonical JSON-schema type and the literal Gemini <code>Schema.Type</code> value that
/// says the same thing, as <code>canonical:GEMINI</code> pairs. The canonical half is
/// <parameter>OcuPilot.Screen.Tool.Registry.SCHEMATYPES</parameter>, so a type the registry admits
/// has a translation here.</p>
Parameter GEMINITYPES = "string:STRING,integer:INTEGER,number:NUMBER,boolean:BOOLEAN,array:ARRAY,object:OBJECT";

/// <p>The emitted keywords Gemini's <code>Schema</code> grammar refuses, comma-separated, and so
/// the only keywords a Gemini declaration loses. Named here rather than left implicit in the
/// rewrite, so AC1's "the only keyword any family may lose is one its own grammar refuses" is a
/// list a test can read.</p>
Parameter GEMINIDROPPED = "additionalProperties";

/// <p>The spelling an empty <code>enum</code> member takes in a Gemini declaration. No registered
/// tool's enum holds it as a value of its own, which <class>OcuPilot.Test.GeminiEmptyEnum</class>
/// asserts, so decoding it back is unambiguous.</p>
Parameter GEMINIEMPTYENUM = "(empty)";

/// <p>Translate the canonical tool array <var>pTools</var> --
/// <code>pTools(n, "name")</code> / <code>("description")</code> / <code>("inputSchema")</code>
/// with the count in <code>pTools</code>, the shape
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> documents -- into
/// <var>pDeclarations</var>, the array an OpenAI request's <code>tools</code> carries.</p>
/// <p>The emitted schema reaches <code>function.parameters</code> unchanged. A schema that will
/// not parse advertises that tool with no properties rather than failing the call, exactly as
/// <method>OcuPilot.Kernel.Provider.Anthropic.SchemaOf</method> does.</p>
ClassMethod ToOpenAi(ByRef pTools, Output pDeclarations As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pDeclarations = []
    Try {
        For tI = 1:1:+$Get(pTools) {
            Set tFunction = {}
            Do tFunction.%Set("name", $Get(pTools(tI, "name")), "string")
            Do tFunction.%Set("description", $Get(pTools(tI, "description")), "string")
            Do tFunction.%Set("parameters", ..SchemaOf($Get(pTools(tI, "inputSchema"))))
            Set tEntry = {}
            Do tEntry.%Set("type", "function", "string")
            Do tEntry.%Set("function", tFunction)
            Do pDeclarations.%Push(tEntry)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pDeclarations = []
    Quit tSC
}

/// <p>Translate the same canonical tool array into <var>pDeclarations</var>, the array a Gemini
/// request's <code>tools</code> carries: <b>one</b> entry holding every declaration under
/// <code>functionDeclarations</code>, with each schema rewritten by
/// <method>GeminiSchema</method>. An empty tool array answers an empty array, so a caller sends no
/// <code>tools</code> at all rather than an empty declaration list.</p>
ClassMethod ToGemini(ByRef pTools, Output pDeclarations As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pDeclarations = []
    Try {
        Set tFunctions = []
        For tI = 1:1:+$Get(pTools) {
            Set tDeclaration = {}
            Do tDeclaration.%Set("name", $Get(pTools(tI, "name")), "string")
            Do tDeclaration.%Set("description", $Get(pTools(tI, "description")), "string")
            Do tDeclaration.%Set("parameters", ..GeminiSchema(..SchemaOf($Get(pTools(tI, "inputSchema")))))
            Do tFunctions.%Push(tDeclaration)
        }
        If tFunctions.%Size() > 0 {
            Set tEntry = {}
            Do tEntry.%Set("functionDeclarations", tFunctions)
            Do pDeclarations.%Push(tEntry)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pDeclarations = []
    Quit tSC
}

/// <p><var>pSchema</var> -- a tool's emitted JSON-schema text -- as the object a request body
/// carries, or an empty object when it is absent, will not parse, or is not a JSON object. The
/// object check is the one <method>OcuPilot.Kernel.Provider.MessageAdapter.BodyOf</method> makes,
/// so an array does not reach one family's <code>parameters</code> while the other silently gets
/// nothing.</p>
/// <p>A tool whose schema could not be read is still advertised, with no properties, because
/// failing the whole call would take every other tool down with it.</p>
ClassMethod SchemaOf(pSchema As %String) As %DynamicAbstractObject
{
    Set tSchema = {}
    Try {
        If pSchema = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pSchema)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tSchema = tParsed
    } Catch ex {
        Set tSchema = {}
    }
    Quit tSchema
}

/// <p><var>pSchema</var> as a copy in Gemini's <code>Schema</code> grammar: every
/// <parameter>GEMINIDROPPED</parameter> keyword removed, every <code>type</code> value translated
/// through <parameter>GEMINITYPES</parameter>, <code>properties</code> and <code>items</code>
/// rewritten the same way at every depth, every <code>enum</code> written as a copy whose
/// <code>""</code> members read <parameter>GEMINIEMPTYENUM</parameter> and, on an
/// <code>integer</code> or <code>number</code> schema, whose numeric members are strings, and every
/// other keyword copied verbatim -- so no keyword inside the emitted subset leaves except the
/// dropped one. Keeping a keyword <b>outside</b> that subset out is
/// <method>OcuPilot.Screen.Tool.Registry.EmitSchema</method>'s job and not this method's: an
/// unrecognized keyword is copied through, never refused.</p>
/// <p>A value this method does not rewrite -- a <code>required</code> list -- is set on the copy
/// by reference, so the two schemas share it. Neither is mutated after this returns; the canonical
/// <code>enum</code> is never mutated at all.</p>
ClassMethod GeminiSchema(pSchema As %DynamicAbstractObject) As %DynamicAbstractObject [ Private ]
{
    Set tOut = {}
    If '$IsObject(pSchema) Quit tOut
    If 'pSchema.%IsA("%Library.DynamicObject") Quit tOut
    Set tDropped = $ListFromString(..#GEMINIDROPPED)
    Set tIterator = pSchema.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(tDropped, tKey) Continue
        If tKey = "type" {
            Do tOut.%Set("type", ..GeminiType(tValue), "string")
            Continue
        }
        If tKey = "items" {
            Do tOut.%Set("items", ..GeminiSchema(tValue))
            Continue
        }
        If (tKey = "enum") && $IsObject(tValue) && tValue.%IsA("%Library.DynamicArray") {
            Do tOut.%Set("enum", ..GeminiEnum(tValue, ..IsNumericType(pSchema.%Get("type"))))
            Continue
        }
        If tKey = "properties" {
            Set tProperties = {}
            If $IsObject(tValue) {
                Set tPropertyIterator = tValue.%GetIterator()
                While tPropertyIterator.%GetNext(.tName, .tProperty) {
                    Do tProperties.%Set(tName, ..GeminiSchema(tProperty))
                }
            }
            Do tOut.%Set("properties", tProperties)
            Continue
        }
        Do tOut.%Set(tKey, tValue)
    }
    Quit tOut
}

/// <p>A copy of the enum array <var>pEnum</var> with every <code>""</code> string member written as
/// <parameter>GEMINIEMPTYENUM</parameter> and, when <var>pNumeric</var> is true, every numeric
/// member written as its JSON text (<method>NumberText</method>), in the same order and at the same
/// count.</p>
ClassMethod GeminiEnum(pEnum As %DynamicArray, pNumeric As %Boolean = 0) As %DynamicArray [ Private ]
{
    Set tOut = []
    Set tIterator = pEnum.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMember, .tType) {
        If (tType = "string") && (tMember = "") {
            Do tOut.%Push(..#GEMINIEMPTYENUM, "string")
            Continue
        }
        If pNumeric && (tType = "number") {
            Do tOut.%Push(..NumberText(tMember), "string")
            Continue
        }
        If $ListFind($ListBuild("string", "number", "boolean", "null"), tType) {
            Do tOut.%Push(tMember, tType)
            Continue
        }
        Do tOut.%Push(tMember)
    }
    Quit tOut
}

/// <p>The JSON text of the number <var>pNumber</var> -- <code>3072</code> as <code>3072</code> and
/// one half as <code>0.5</code>, where ObjectScript's own string conversion would drop the leading
/// zero. <class>OcuPilot.Kernel.Provider.MessageAdapter</class> uses it to write a replayed
/// numeric argument as the member the declaration carried.</p>
ClassMethod NumberText(pNumber As %Numeric) As %String
{
    Set tArray = []
    Do tArray.%Push(pNumber, "number")
    Set tText = tArray.%ToJSON()
    Quit $Extract(tText, 2, $Length(tText) - 1)
}

/// <p>The (tool, argument) pairs in the canonical tool array <var>pTools</var> whose declaration
/// <method>ToGemini</method> respells: <code>{&lt;wire name&gt;: {&lt;argument&gt;: kind}}</code>,
/// for each top-level property whose <code>enum</code> holds <code>""</code> (kind
/// <code>value</code>), whose <code>items.enum</code> does (kind <code>items</code>), whose
/// <code>enum</code> holds a numeric member on an <code>integer</code> or <code>number</code>
/// property (kind <code>number</code>), or whose <code>items.enum</code> does (kind
/// <code>numbers</code>). An empty object when no pair is respelled.</p>
ClassMethod GeminiEmptyEnumArgs(ByRef pTools) As %DynamicObject
{
    Set tMap = {}
    Try {
        For tI = 1:1:+$Get(pTools) {
            Set tSchema = ..SchemaOf($Get(pTools(tI, "inputSchema")))
            Set tProperties = tSchema.%Get("properties")
            If '$IsObject(tProperties) || 'tProperties.%IsA("%Library.DynamicObject") Continue
            Set tArgs = {}
            Set tIterator = tProperties.%GetIterator()
            While tIterator.%GetNext(.tName, .tProperty) {
                If '$IsObject(tProperty) || 'tProperty.%IsA("%Library.DynamicObject") Continue
                If ..HoldsEmptyMember(tProperty.%Get("enum")) {
                    Do tArgs.%Set(tName, "value", "string")
                    Continue
                }
                If ..HoldsNumericMember(tProperty) {
                    Do tArgs.%Set(tName, "number", "string")
                    Continue
                }
                Set tItems = tProperty.%Get("items")
                If $IsObject(tItems) && tItems.%IsA("%Library.DynamicObject") && ..HoldsEmptyMember(tItems.%Get("enum")) {
                    Do tArgs.%Set(tName, "items", "string")
                    Continue
                }
                If ..HoldsNumericMember(tItems) Do tArgs.%Set(tName, "numbers", "string")
            }
            If tArgs.%Size() > 0 Do tMap.%Set($Get(pTools(tI, "name")), tArgs)
        }
    } Catch ex {
        Set tMap = {}
    }
    Quit tMap
}

/// <p>Whether <var>pEnum</var> is an array holding a <code>""</code> string member.</p>
ClassMethod HoldsEmptyMember(pEnum As %RawString = "") As %Boolean [ Private ]
{
    If '$IsObject(pEnum) Quit 0
    If 'pEnum.%IsA("%Library.DynamicArray") Quit 0
    Set tHolds = 0
    Set tIterator = pEnum.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMember, .tType) {
        If (tType = "string") && (tMember = "") Set tHolds = 1
    }
    Quit tHolds
}

/// <p>Whether <var>pSchema</var> is an <code>integer</code> or <code>number</code> schema whose
/// <code>enum</code> array holds a numeric member -- the schemas <method>GeminiSchema</method>
/// respells.</p>
ClassMethod HoldsNumericMember(pSchema As %RawString = "") As %Boolean [ Private ]
{
    If '$IsObject(pSchema) Quit 0
    If 'pSchema.%IsA("%Library.DynamicObject") Quit 0
    If '..IsNumericType(pSchema.%Get("type")) Quit 0
    Set tEnum = pSchema.%Get("enum")
    If '$IsObject(tEnum) Quit 0
    If 'tEnum.%IsA("%Library.DynamicArray") Quit 0
    Set tHolds = 0
    Set tIterator = tEnum.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMember, .tType) {
        If tType = "number" Set tHolds = 1
    }
    Quit tHolds
}

/// <p>Whether the canonical schema type <var>pType</var> is <code>integer</code> or
/// <code>number</code>.</p>
ClassMethod IsNumericType(pType As %String = "") As %Boolean [ Private ]
{
    Quit ''$ListFind($ListBuild("integer", "number"), pType)
}

/// <p>The Gemini <code>Schema.Type</code> literal for the canonical type <var>pType</var>, or
/// <var>pType</var> as written when the vocabulary does not name it.</p>
/// <p>The fall-through is unreachable through the registry, which admits only
/// <parameter>OcuPilot.Screen.Tool.Registry.SCHEMATYPES</parameter>; carrying the value rather
/// than blanking it keeps a schema that reached here another way readable instead of silently
/// typeless.</p>
ClassMethod GeminiType(pType As %String) As %String [ Private ]
{
    Set tMapped = ""
    For tI = 1:1:$Length(..#GEMINITYPES, ",") {
        Set tPair = $Piece(..#GEMINITYPES, ",", tI)
        If $Piece(tPair, ":", 1) '= pType Continue
        Set tMapped = $Piece(tPair, ":", 2)
        Quit
    }
    If tMapped = "" Quit pType
    Quit tMapped
}

}
