/// <p>The tool registry (AD-5, AD-22, AD-36): which tools exist, what each is called and of which
/// kind, the tool array a provider request advertises, whether a set of arguments satisfies a
/// tool's input schema, and the one call into a tool, <method>InvokeTool</method>. Its one caller is
/// <class>OcuPilot.Kernel.Agent.Dispatch</class>, which checks the governance gate, the restraint
/// verdict, the privilege pairs and the arguments first; nothing here checks any of them.</p>
/// <p><b>Wire names.</b> A provider's tool-name grammar refuses dots, so a tool is advertised under
/// <method>WireName</method>, every dot an underscore, and resolved by comparing wire names
/// (<method>ResolveWire</method>). The dotted name stays canonical everywhere else; a canonical
/// name holds no underscore, so the mapping is reversible (Conventions, Tool naming).</p>
/// <p><b>Two sources, one list.</b> A tool with a class of its own is every compiled, non-abstract
/// class in <method>ToolPackage</method> that <code>%Extends</code>
/// <class>OcuPilot.Screen.Tool.Base</class>, however many abstract classes stand between them, so
/// an inherited <parameter>KIND</parameter> counts. A read tool has no class of its own: every
/// descriptor <method>ScreenRegistryClass</method> enumerates that declares a read yields
/// <code>&lt;toolIdentifier&gt;.read</code>, answered by <method>ReadToolClass</method>. A name two
/// sources claim is refused rather than resolved to either.</p>
/// <p><b>The registry reads no kernel state</b> (the dependency direction in the spine): a cap or
/// a policy a tool is called under is its caller's to supply.</p>
Class OcuPilot.Screen.Tool.Registry Extends %RegisteredObject
{

/// <p>The package tool classes are discovered in, trailing dot included.</p>
Parameter TOOLPACKAGE = "OcuPilot.";

/// <p>The package excluded from discovery: test fixtures are never tools.</p>
Parameter EXCLUDEDPACKAGE = "OcuPilot.Test.";

/// <p>The base every tool class extends.</p>
Parameter BASECLASS = "OcuPilot.Screen.Tool.Base";

/// <p>A class tool's name: area, screen and verb, lower case, dots only.</p>
Parameter TOOLNAMEPATTERN = "^[a-z][a-z0-9]*\.[a-z][a-z0-9]*\.[a-z][a-z0-9]*$";

/// <p>The two kinds a tool may declare (AD-22).</p>
Parameter KINDS = "read,write";

/// <p>The schema keywords the argument validator admits. A schema using any other keyword is
/// refused, because a keyword the validator does not enforce would read as a constraint it never
/// checked -- so every name here is enforced by <method>ValueProblem</method>, including
/// <code>maxLength</code>, which a read tool publishes on every declared criterion (DW-279).</p>
Parameter SCHEMAKEYWORDS = "type,properties,required,additionalProperties,description,enum,minimum,maximum,maxLength,items,minItems,maxItems";

/// <p>The JSON types a schema may name.</p>
Parameter SCHEMATYPES = "string,integer,number,boolean,array,object";

/// <p>The keywords an advertised schema's top level carries, and no others: the cross-vendor
/// subset every provider adapter accepts.</p>
Parameter EMITTEDTOPKEYWORDS = "type,properties,required,additionalProperties";

/// <p>The keywords an advertised schema's property carries, and no others -- the harvested subset
/// verbatim. <code>maxLength</code>, which the validator enforces, is moved into the property's
/// description by <method>EmitSchema</method> rather than advertised as a keyword.</p>
Parameter EMITTEDKEYWORDS = "type,description,enum,items,minimum,maximum,minItems,maxItems";

/// <p>The tool-name grammar of a provider request.</p>
Parameter WIRENAMEPATTERN = "^[a-zA-Z0-9_-]{1,64}$";

/// <p>The package tool classes are discovered in. Overridable so a fixture registry can point at
/// fixture tools; production never overrides it.</p>
ClassMethod ToolPackage() As %String
{
    Quit ..#TOOLPACKAGE
}

/// <p>The package excluded from <method>ToolPackage</method>, or <code>""</code> for none.
/// Overridable for the same fixture; production never overrides it.</p>
ClassMethod ExcludedPackage() As %String
{
    Quit ..#EXCLUDEDPACKAGE
}

/// <p>The screen registry whose descriptors yield read tools. Overridable for the same fixture;
/// production never overrides it.</p>
ClassMethod ScreenRegistryClass() As %String
{
    Quit "OcuPilot.Screen.Registry"
}

/// <p>The class that answers every descriptor-derived read tool. Overridable so a fixture's read
/// tools reach <class>OcuPilot.Test.PortFixture</class>; production never overrides it.</p>
ClassMethod ReadToolClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Read"
}

/// <p>Every tool, in name order, as a <class>%DynamicArray</class> of
/// <code>{name, kind, class, descriptor}</code>. <code>descriptor</code> is <code>""</code> for a
/// tool with a class of its own; <code>class</code> is <method>ReadToolClass</method> for a read
/// tool.</p>
/// <p>Refuses, with <var>pTools</var> empty: a tool class whose kind
/// <method>KindProblem</method> refuses or whose name is not <parameter>TOOLNAMEPATTERN</parameter>;
/// a read-declaring descriptor whose read <method>OcuPilot.Screen.Registry.ReadProblem</method>
/// refuses; and a name claimed twice. A discovery query that did not open or stopped early is an
/// error too, never a shorter list.</p>
ClassMethod ListTools(Output pTools As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pTools = ""
    Try {
        Kill tByName
        Set tSC = ..ToolClasses(.tClasses)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$ListLength(tClasses) {
            Set tClass = $List(tClasses, tI)
            Set tKind = $Parameter(tClass, "KIND")
            Set tProblem = ..KindProblem(tClass, tKind)
            If tProblem '= "" {
                Set tSC = $$$ERROR($$$GeneralError, tProblem)
                Quit
            }
            Set tName = $Parameter(tClass, "TOOLNAME")
            If '$Match(tName, ..#TOOLNAMEPATTERN) {
                Set tSC = $$$ERROR($$$GeneralError, tClass _ ": TOOLNAME '" _ tName _ "' is not <area>.<screen>.<verb> in lower case")
                Quit
            }
            Set tSC = ..Claim(.tByName, tName, tKind, tClass, "")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit

        Set tRegistry = ..ScreenRegistryClass()
        Set tSC = $ClassMethod(tRegistry, "Descriptors", .tDescriptors)
        If $$$ISERR(tSC) Quit
        Set tReadClass = ..ReadToolClass()
        For tI = 1:1:$ListLength(tDescriptors) {
            Set tDescriptor = $List(tDescriptors, tI)
            If '$IsObject($ClassMethod(tDescriptor, "Read")) Continue
            Set tSC = $ClassMethod(tDescriptor, "DeclarationJson", .tDeclaration)
            If $$$ISERR(tSC) Quit
            Set tProblem = $ClassMethod(tRegistry, "ReadProblem", tDeclaration)
            If tProblem '= "" {
                Set tSC = $$$ERROR($$$GeneralError, tDescriptor _ ": " _ tProblem)
                Quit
            }
            Set tSC = ..Claim(.tByName, $ClassMethod(tReadClass, "NameFor", tDescriptor), $Parameter(tReadClass, "KIND"), tReadClass, tDescriptor)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit

        Set pTools = []
        Set tName = ""
        For {
            Set tName = $Order(tByName(tName))
            If tName = "" Quit
            Do pTools.%Push(tByName(tName))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pTools = ""
    Quit tSC
}

/// <p>The tool named <var>pName</var> as <method>ListTools</method> lists it, or <code>""</code>
/// in <var>pTool</var> when no tool carries that name. The status is an error only when the list
/// itself could not be built.</p>
ClassMethod Resolve(pName As %String, Output pTool As %DynamicObject) As %Status
{
    Set pTool = ""
    Set tSC = ..ListTools(.tTools)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.name = pName {
            Set pTool = tEntry
            Quit
        }
    }
    Quit $$$OK
}

/// <p><var>pName</var> as a provider request spells it: every dot an underscore.</p>
ClassMethod WireName(pName As %String) As %String
{
    Quit $Translate(pName, ".", "_")
}

/// <p>The tool whose <method>WireName</method> is exactly <var>pWireName</var>, as
/// <method>ListTools</method> lists it, or <code>""</code> in <var>pTool</var> when none is. The
/// status is an error only when the list itself could not be built.</p>
ClassMethod ResolveWire(pWireName As %String, Output pTool As %DynamicObject) As %Status
{
    Set pTool = ""
    Set tSC = ..ListTools(.tTools)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If ..WireName(tEntry.name) = pWireName {
            Set pTool = tEntry
            Quit
        }
    }
    Quit $$$OK
}

/// <p>Every tool as a provider request advertises it, in <method>ListTools</method>'s name order:
/// <code>pTools(n, "name")</code> the wire name, <code>pTools(n, "description")</code> and
/// <code>pTools(n, "inputSchema")</code> the emitted schema as JSON text, with the count in
/// <code>pTools</code> -- the shape <class>OcuPilot.Kernel.Provider.Base</class> reads.</p>
/// <p>Refuses, with <var>pTools</var> 0: a list that cannot be built; a tool whose wire name breaks
/// <parameter>WIRENAMEPATTERN</parameter>, whose canonical name holds an underscore, or whose wire
/// name another tool shares; a tool with no description; an input or result schema the validator
/// does not admit; and an input schema <method>EmitSchema</method> refuses.</p>
ClassMethod ProviderTools(Output pTools) As %Status
{
    Set tSC = $$$OK
    Kill pTools
    Set pTools = 0
    Try {
        Set tSC = ..ListTools(.tList)
        If $$$ISERR(tSC) Quit
        Kill tSeen
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTool) {
            Set tName = tTool.%Get("name")
            Set tWire = ..WireName(tName)
            If (tName [ "_") || '$Match(tWire, ..#WIRENAMEPATTERN) {
                Set tSC = $$$ERROR($$$GeneralError, "tool '" _ tName _ "' has no reversible wire name matching " _ ..#WIRENAMEPATTERN)
                Quit
            }
            If $Data(tSeen(tWire)) {
                Set tSC = $$$ERROR($$$GeneralError, "tools '" _ tSeen(tWire) _ "' and '" _ tName _ "' share the wire name '" _ tWire _ "'")
                Quit
            }
            Set tSeen(tWire) = tName
            Set tDescription = ..DescriptionOf(tTool)
            If $ZStrip(tDescription, "<>W") = "" {
                Set tSC = $$$ERROR($$$GeneralError, "tool '" _ tName _ "' declares no description")
                Quit
            }
            Set tInput = ..InputSchemaOf(tTool)
            Set tProblem = ..SchemaProblem(tInput, tName _ " input schema", 1)
            If tProblem = "" Set tProblem = ..SchemaProblem(..ResultSchemaOf(tTool), tName _ " result schema", 1)
            If tProblem '= "" {
                Set tSC = $$$ERROR($$$GeneralError, tProblem)
                Quit
            }
            Set tEmitSC = ..EmitSchema(tInput, .tEmitted, .tProblem)
            If $$$ISERR(tEmitSC) {
                Set tSC = $$$ERROR($$$GeneralError, tName _ " input schema: " _ tProblem)
                Quit
            }
            Set pTools = pTools + 1
            Set pTools(pTools, "name") = tWire
            Set pTools(pTools, "description") = tDescription
            Set pTools(pTools, "inputSchema") = tEmitted.%ToJSON()
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Kill pTools
        Set pTools = 0
    }
    Quit tSC
}

/// <p><var>pSchema</var> as a provider request advertises it, as a copy in <var>pEmitted</var>:
/// the top level carries <parameter>EMITTEDTOPKEYWORDS</parameter> and is
/// <code>{type: "object", properties, required, additionalProperties: false}</code>; every property,
/// and every <code>items</code> below one, carries only <parameter>EMITTEDKEYWORDS</parameter>. A
/// property's <code>maxLength</code> is removed and stated at the end of its description as
/// <code>At most N characters.</code>. Any other keyword refuses the schema, naming it in
/// <var>pProblem</var>; <var>pSchema</var> itself is never changed.</p>
ClassMethod EmitSchema(pSchema As %DynamicObject, Output pEmitted As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pEmitted = ""
    Set pProblem = ""
    Try {
        If '$IsObject(pSchema) || 'pSchema.%IsA("%Library.DynamicObject") {
            Set pProblem = "the schema is not an object"
            Quit
        }
        Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pSchema.%ToJSON())
        Set tTop = $ListFromString(..#EMITTEDTOPKEYWORDS)
        Set tIterator = tCopy.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '$ListFind(tTop, tKey) {
                Set pProblem = "the top level uses keyword '" _ tKey _ "', which the emitted subset does not admit"
                Quit
            }
        }
        If pProblem '= "" Quit
        If (tCopy.%Get("type") '= "object") || (tCopy.%GetTypeOf("properties") '= "object") || (tCopy.%GetTypeOf("required") '= "array") || (tCopy.%GetTypeOf("additionalProperties") '= "boolean") || tCopy.%Get("additionalProperties") {
            Set pProblem = "the top level is not {type: object, properties, required, additionalProperties: false}"
            Quit
        }
        Set tIterator = tCopy.%Get("properties").%GetIterator()
        While tIterator.%GetNext(.tKey, .tProperty) {
            Set pProblem = ..EmitProperty(tProperty, "properties." _ tKey)
            If pProblem '= "" Quit
        }
        If pProblem '= "" Quit
        Set pEmitted = tCopy
    } Catch ex {
        Set pProblem = "the schema could not be emitted: " _ ex.DisplayString()
    }
    If pProblem = "" Quit $$$OK
    Set pEmitted = ""
    Quit $$$ERROR($$$GeneralError, pProblem)
}

/// <p>What <var>pProperty</var>, at <var>pPath</var>, carries that an emitted schema may not, or
/// <code>""</code> -- having moved its <code>maxLength</code> into its description, and its
/// <code>items</code>' likewise.</p>
ClassMethod EmitProperty(pProperty As %DynamicObject, pPath As %String) As %String [ Private ]
{
    If '$IsObject(pProperty) || 'pProperty.%IsA("%Library.DynamicObject") Quit pPath _ " is not a schema object"
    Set tAllowed = $ListFromString(..#EMITTEDKEYWORDS)
    Set tProblem = ""
    Set tIterator = pProperty.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey '= "maxLength") && '$ListFind(tAllowed, tKey) {
            Set tProblem = pPath _ " uses keyword '" _ tKey _ "', which the emitted subset does not admit"
            Quit
        }
    }
    If tProblem '= "" Quit tProblem
    If pProperty.%GetTypeOf("maxLength") '= "unassigned" {
        Set tSentence = "At most " _ pProperty.%Get("maxLength") _ " characters."
        Set tDescription = $Select(pProperty.%GetTypeOf("description") = "string": pProperty.%Get("description"), 1: "")
        Do pProperty.%Remove("maxLength")
        Do pProperty.%Set("description", $Select(tDescription = "": tSentence, 1: tDescription _ " " _ tSentence), "string")
    }
    If pProperty.%GetTypeOf("items") '= "unassigned" Set tProblem = ..EmitProperty(pProperty.%Get("items"), pPath _ ".items")
    Quit tProblem
}

/// <p><var>pTool</var>'s input schema, as its class answers it for its descriptor.</p>
ClassMethod InputSchemaOf(pTool As %DynamicObject) As %DynamicObject
{
    Quit $ClassMethod(pTool.%Get("class"), "InputSchema", pTool.%Get("descriptor"))
}

/// <p><var>pTool</var>'s result schema, as its class answers it for its descriptor.</p>
ClassMethod ResultSchemaOf(pTool As %DynamicObject) As %DynamicObject
{
    Quit $ClassMethod(pTool.%Get("class"), "ResultSchema", pTool.%Get("descriptor"))
}

/// <p><var>pTool</var>'s description, as its class answers it for its descriptor.</p>
ClassMethod DescriptionOf(pTool As %DynamicObject) As %String
{
    Quit $ClassMethod(pTool.%Get("class"), "Description", pTool.%Get("descriptor"))
}

/// <p>The <code>(resource, permission)</code> pairs <var>pTool</var> requires, as its class answers
/// them for its descriptor. <var>pResolved</var> is 0 when they could not be read, and a caller must
/// then refuse rather than read the empty list as "requires nothing".</p>
ClassMethod RequiredPairs(pTool As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 0
    Set tPairs = ""
    Try {
        Set tPairs = $ClassMethod(pTool.%Get("class"), "PrivilegePairs", pTool.%Get("descriptor"), .pResolved)
        If '$ListValid(tPairs) {
            Set tPairs = ""
            Set pResolved = 0
        }
    } Catch {
        Set tPairs = ""
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p>Call <var>pTool</var>'s view with <var>pArgs</var> under the row cap <var>pContextCap</var>,
/// in the calling process (AD-1). Outputs are the view's (<method>OcuPilot.Screen.Tool.Base.View</method>);
/// a view that throws answers an error status with <var>pFault</var> <code>""</code>.</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Kernel.Agent.Dispatch</class> alone, after its gate
/// point, restraint, pair and argument checks.</p>
ClassMethod InvokeTool(pTool As %DynamicObject, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = $ClassMethod(pTool.%Get("class"), "View", pTool.%Get("descriptor"), pArgs, pContextCap, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set pFault = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pSchema</var> is a top-level schema the validator admits (the checks
/// <method>ValidateArguments</method> makes before reading any argument). <var>pProblem</var> is
/// <code>""</code> exactly when the status is OK.</p>
ClassMethod ValidateSchema(pSchema As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Try {
        Set pProblem = ..SchemaProblem(pSchema, "schema", 1)
    } Catch ex {
        Set pProblem = "the schema could not be validated: " _ ex.DisplayString()
    }
    If pProblem = "" Quit $$$OK
    Quit $$$ERROR($$$GeneralError, pProblem)
}

/// <p>What is wrong with <var>pClass</var> declaring kind <var>pKind</var>, or <code>""</code>
/// (AD-22). A tool is <code>read</code> or <code>write</code>; anything else, the empty string
/// included, is refused here as <file>scripts/check-objectscript.py</file> refuses it in the
/// tree.</p>
ClassMethod KindProblem(pClass As %String, pKind As %String) As %String
{
    If (pKind '= "") && $ListFind($ListFromString(..#KINDS), pKind) Quit ""
    Quit pClass _ ": KIND '" _ pKind _ "' is neither 'read' nor 'write', and every tool declares its kind at definition time (AD-22)"
}

/// <p>Whether <var>pArgs</var> satisfies <var>pSchema</var>. <var>pProblem</var> names the
/// argument and the rule it broke, and is <code>""</code> exactly when the status is OK.</p>
/// <p>The schema is checked first, and refused when it steps outside the subset: a top level of
/// <code>{type: "object", properties, required, additionalProperties: false}</code>, property types
/// from <parameter>SCHEMATYPES</parameter>, and only the keywords
/// <parameter>SCHEMAKEYWORDS</parameter> names. Then the arguments: each value's JSON type
/// (<code>integer</code> is a number with no fraction), <code>enum</code>, <code>minimum</code>,
/// <code>maximum</code>, <code>maxLength</code> (on a string), <code>items</code>,
/// <code>minItems</code>, <code>maxItems</code>,
/// <code>required</code>, and <code>additionalProperties: false</code>.</p>
ClassMethod ValidateArguments(pSchema As %DynamicObject, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Try {
        Set pProblem = ..SchemaProblem(pSchema, "schema", 1)
        If pProblem '= "" Quit
        If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") {
            Set pProblem = "the arguments are not an object (type)"
            Quit
        }
        Set pProblem = ..ObjectProblem(pSchema, pArgs, "")
    } Catch ex {
        Set pProblem = "the arguments could not be validated: " _ ex.DisplayString()
    }
    If pProblem = "" Quit $$$OK
    Quit $$$ERROR($$$GeneralError, pProblem)
}

/// <p>The concrete tool classes in <method>ToolPackage</method>, outside
/// <method>ExcludedPackage</method>, in name order. Embedded SQL, for the reason
/// <method>OcuPilot.Screen.Registry.Descriptors</method> gives.</p>
ClassMethod ToolClasses(Output pList As %List) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pList = ""
    Try {
        Set tPackage = ..ToolPackage()
        Set tExcluded = ..ExcludedPackage()
        Set tBase = ..#BASECLASS
        Set tName = ""
        Set tAbstract = 0
        &sql(DECLARE OcuToolCur CURSOR FOR SELECT Name, Abstract INTO :tName, :tAbstract FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH :tPackage ORDER BY Name)
        &sql(OPEN OcuToolCur)
        If SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the tool query did not open: SQLCODE " _ SQLCODE)
            Quit
        }
        For {
            &sql(FETCH OcuToolCur)
            Quit:SQLCODE'=0
            If tAbstract Continue
            If (tExcluded '= "") && ($Extract(tName, 1, $Length(tExcluded)) = tExcluded) Continue
            Set tIsTool = 0
            Try {
                Set tIsTool = $ClassMethod(tName, "%Extends", tBase)
            } Catch {
                Set tIsTool = 0
            }
            If tIsTool Set pList = pList _ $ListBuild(tName)
        }
        Set tFetchCode = SQLCODE
        &sql(CLOSE OcuToolCur)
        If tFetchCode < 0 {
            Set pList = ""
            Set tSC = $$$ERROR($$$GeneralError, "the tool fetch stopped early: SQLCODE " _ tFetchCode)
        }
    } Catch ex {
        Set pList = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Record one tool under <var>pName</var>, refusing a name already claimed.</p>
ClassMethod Claim(ByRef pByName, pName As %String, pKind As %String, pClass As %String, pDescriptor As %String) As %Status [ Private ]
{
    If $Data(pByName(pName)) {
        Set tHeld = pByName(pName)
        Quit $$$ERROR($$$GeneralError, "tool name '" _ pName _ "' is claimed by " _ $Select(tHeld.descriptor '= "": tHeld.descriptor, 1: tHeld.class) _ " and by " _ $Select(pDescriptor '= "": pDescriptor, 1: pClass))
    }
    Set tEntry = {}
    Do tEntry.%Set("name", pName)
    Do tEntry.%Set("kind", pKind)
    Do tEntry.%Set("class", pClass)
    Do tEntry.%Set("descriptor", pDescriptor)
    Set pByName(pName) = tEntry
    Quit $$$OK
}

/// <p>What is wrong with schema node <var>pSchema</var> at <var>pPath</var>, or <code>""</code>.
/// <var>pTop</var> marks the top level, which must be an object schema closed by
/// <code>additionalProperties: false</code>.</p>
ClassMethod SchemaProblem(pSchema As %DynamicObject, pPath As %String, pTop As %Boolean = 0) As %String [ Private ]
{
    If '$IsObject(pSchema) || 'pSchema.%IsA("%Library.DynamicObject") Quit pPath _ " is not a schema object"
    Set tKeywords = $ListFromString(..#SCHEMAKEYWORDS)
    Set tProblem = ""
    Set tIterator = pSchema.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tKeywords, tKey) {
            Set tProblem = pPath _ " uses keyword '" _ tKey _ "', which the schema subset does not admit"
            Quit
        }
    }
    If tProblem '= "" Quit tProblem

    Set tType = pSchema.%Get("type")
    If (pSchema.%GetTypeOf("type") '= "string") || '$ListFind($ListFromString(..#SCHEMATYPES), tType) Quit pPath _ " declares type '" _ tType _ "', which is not one of " _ ..#SCHEMATYPES
    If pTop && (tType '= "object") Quit pPath _ " is not an object schema at its top level"
    If pTop && (pSchema.%GetTypeOf("additionalProperties") '= "boolean") Quit pPath _ " does not close its top level with additionalProperties: false"
    If pSchema.%GetTypeOf("additionalProperties") '= "unassigned" {
        If (pSchema.%GetTypeOf("additionalProperties") '= "boolean") || pSchema.%Get("additionalProperties") Quit pPath _ " declares additionalProperties other than false"
    }
    For tKey = "minimum", "maximum" {
        If (pSchema.%GetTypeOf(tKey) '= "unassigned") && (pSchema.%GetTypeOf(tKey) '= "number") Set tProblem = pPath _ "." _ tKey _ " is not a number"
    }
    If (pSchema.%GetTypeOf("maxLength") '= "unassigned") && '((pSchema.%GetTypeOf("maxLength") = "number") && $Match(pSchema.%Get("maxLength"), "^[1-9][0-9]*$")) Set tProblem = pPath _ ".maxLength is not a whole number above zero"
    For tKey = "minItems", "maxItems" {
        If (pSchema.%GetTypeOf(tKey) '= "unassigned") && '((pSchema.%GetTypeOf(tKey) = "number") && $Match(pSchema.%Get(tKey), "^[0-9]+$")) Set tProblem = pPath _ "." _ tKey _ " is not a whole number"
    }
    If tProblem '= "" Quit tProblem
    If (pSchema.%GetTypeOf("enum") '= "unassigned") && (pSchema.%GetTypeOf("enum") '= "array") Quit pPath _ ".enum is not an array"
    If (pSchema.%GetTypeOf("description") '= "unassigned") && (pSchema.%GetTypeOf("description") '= "string") Quit pPath _ ".description is not a string"

    If pSchema.%GetTypeOf("properties") '= "unassigned" {
        If pSchema.%GetTypeOf("properties") '= "object" Quit pPath _ ".properties is not an object"
        Set tIterator = pSchema.%Get("properties").%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tProblem = ..SchemaProblem(tValue, pPath _ ".properties." _ tKey)
            If tProblem '= "" Quit
        }
        If tProblem '= "" Quit tProblem
    }
    If pSchema.%GetTypeOf("required") '= "unassigned" {
        If pSchema.%GetTypeOf("required") '= "array" Quit pPath _ ".required is not an array"
        Set tProperties = pSchema.%Get("properties")
        Set tIterator = pSchema.%Get("required").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName, .tNameType) {
            If (tNameType '= "string") || '$IsObject(tProperties) || (tProperties.%GetTypeOf(tName) = "unassigned") {
                Set tProblem = pPath _ ".required names '" _ tName _ "', which is not a declared property"
                Quit
            }
        }
        If tProblem '= "" Quit tProblem
    }
    If pSchema.%GetTypeOf("items") '= "unassigned" {
        Set tProblem = ..SchemaProblem(pSchema.%Get("items"), pPath _ ".items")
    }
    Quit tProblem
}

/// <p>What is wrong with object <var>pValue</var> against object schema <var>pSchema</var>, or
/// <code>""</code>. <var>pPath</var> names the object, empty at the top level.</p>
ClassMethod ObjectProblem(pSchema As %DynamicObject, pValue As %DynamicObject, pPath As %String) As %String [ Private ]
{
    Set tProblem = ""
    Set tProperties = pSchema.%Get("properties")
    If '$IsObject(tProperties) Set tProperties = {}
    If $IsObject(pSchema.%Get("required")) {
        Set tIterator = pSchema.%Get("required").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            If pValue.%GetTypeOf(tName) = "unassigned" {
                Set tProblem = "argument '" _ pPath _ tName _ "' is missing (required)"
                Quit
            }
        }
        If tProblem '= "" Quit tProblem
    }
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tKey, .tIgnored) {
        If tProperties.%GetTypeOf(tKey) = "unassigned" {
            If pSchema.%GetTypeOf("additionalProperties") = "boolean" {
                Set tProblem = "argument '" _ pPath _ tKey _ "' is not a declared property (additionalProperties: false)"
                Quit
            }
            Continue
        }
        Set tProblem = ..ValueProblem(tProperties.%Get(tKey), pValue, tKey, pPath _ tKey)
        If tProblem '= "" Quit
    }
    Quit tProblem
}

/// <p>What is wrong with the value at <var>pKey</var> in container <var>pContainer</var> against
/// <var>pSchema</var>, or <code>""</code>. The container is passed rather than the value so the
/// value's JSON type can be read.</p>
ClassMethod ValueProblem(pSchema As %DynamicObject, pContainer As %DynamicAbstractObject, pKey As %String, pPath As %String) As %String [ Private ]
{
    Set tJsonType = pContainer.%GetTypeOf(pKey)
    Set tValue = pContainer.%Get(pKey)
    Set tType = pSchema.%Get("type")
    Set tTypeOk = $Case(tType,
        "string": (tJsonType = "string"),
        "number": (tJsonType = "number"),
        "integer": (tJsonType = "number") && (tValue = (tValue \ 1)),
        "boolean": (tJsonType = "boolean"),
        "array": (tJsonType = "array"),
        "object": (tJsonType = "object"),
        : 0)
    If 'tTypeOk Quit "argument '" _ pPath _ "' must be of type " _ tType _ " (type)"

    If $IsObject(pSchema.%Get("enum")) {
        Set tFound = 0
        Set tIterator = pSchema.%Get("enum").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tMember, .tMemberType) {
            If (tMemberType = tJsonType) && (tMember = tValue) {
                Set tFound = 1
                Quit
            }
        }
        If 'tFound Quit "argument '" _ pPath _ "' is not one of the permitted values (enum)"
    }
    If (pSchema.%GetTypeOf("minimum") = "number") && (tValue < pSchema.%Get("minimum")) Quit "argument '" _ pPath _ "' is below " _ pSchema.%Get("minimum") _ " (minimum)"
    If (pSchema.%GetTypeOf("maximum") = "number") && (tValue > pSchema.%Get("maximum")) Quit "argument '" _ pPath _ "' is above " _ pSchema.%Get("maximum") _ " (maximum)"
    ; DW-279: a read tool publishes the vendor property's own length on every criterion, and this
    ; is what enforces it -- a keyword the validator admitted and never checked would read as a
    ; constraint it did not apply.
    If (tType = "string") && (pSchema.%GetTypeOf("maxLength") = "number") && ($Length(tValue) > pSchema.%Get("maxLength")) Quit "argument '" _ pPath _ "' is longer than " _ pSchema.%Get("maxLength") _ " characters (maxLength)"

    If tType = "array" {
        If (pSchema.%GetTypeOf("minItems") = "number") && (tValue.%Size() < pSchema.%Get("minItems")) Quit "argument '" _ pPath _ "' has fewer than " _ pSchema.%Get("minItems") _ " items (minItems)"
        If (pSchema.%GetTypeOf("maxItems") = "number") && (tValue.%Size() > pSchema.%Get("maxItems")) Quit "argument '" _ pPath _ "' has more than " _ pSchema.%Get("maxItems") _ " items (maxItems)"
        If $IsObject(pSchema.%Get("items")) {
            Set tProblem = ""
            For tI = 0:1:tValue.%Size() - 1 {
                Set tProblem = ..ValueProblem(pSchema.%Get("items"), tValue, tI, pPath _ "[" _ tI _ "]")
                If tProblem '= "" Quit
            }
            If tProblem '= "" Quit tProblem
        }
    }
    If tType = "object" Quit ..ObjectProblem(pSchema, tValue, pPath _ ".")
    Quit ""
}

}
