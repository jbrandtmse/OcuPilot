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
/// <code>tools[0].functionDeclarations[] = {name, description, parameters}</code>, the same
/// 64-character name grammar, and <code>Schema.type</code> in Gemini's own upper-case vocabulary
/// (<parameter>GEMINITYPES</parameter>).</p>
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
/// rewritten the same way at every depth, and every other keyword copied verbatim -- so no keyword
/// inside the emitted subset leaves except the dropped one. Keeping a keyword <b>outside</b> that
/// subset out is <method>OcuPilot.Screen.Tool.Registry.EmitSchema</method>'s job and not this
/// method's: an unrecognized keyword is copied through, never refused.</p>
/// <p>A value this method does not rewrite -- an <code>enum</code> or a <code>required</code> list
/// -- is set on the copy by reference, so the two schemas share it. Neither is mutated after this
/// returns.</p>
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
