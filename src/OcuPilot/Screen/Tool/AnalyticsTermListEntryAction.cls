/// <p>What the term list editor's three entry writes share (AD-6, AD-51, AD-52, AD-53, AD-65, Story 24.2): a write of one entry of one term
/// list of the request's namespace through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Entries screen's Add entry
/// and its row actions Change entry and Remove entry, and the agent's proposal and confirmation. The target is the composite
/// <code>[TermList, Key]</code> (<class>OcuPilot.Screen.Tool.AnalyticsTermListEntryMint</class>), the key kept exactly (AD-13). A write takes
/// effect at once: <code>%Lookup</code> reads the node with no cache.</p>
/// <p><b>The fresh read is the port's <code>TERMLISTENTRY</code></b>: <code>{TermList, Key, Value, FieldValues, Fields, Namespace}</code>,
/// <code>FieldValues</code> one <code>{Field, Value}</code> per field of the list.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListEntryAction Extends OcuPilot.Screen.Tool.AnalyticsTermListAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsTermListEntryList";

Parameter READTYPE = "TERMLISTENTRY";

Parameter READANSWERS = "TermList,Key,Value,FieldValues,Fields,Namespace";

/// <p>The read field a stored payload carries and a call's arguments do not (<code>Fields</code> is the joined text, never an argument
/// of an entry tool).</p>
Parameter STATEMARKER = "Fields";

/// <p>The argument naming the term list the entry belongs to.</p>
Parameter LISTARGUMENT = "TermList";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTTERMLISTENTRIES
}

/// <p><class>OcuPilot.Screen.Tool.AnalyticsTermListEntryMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.AnalyticsTermListEntryMint"
}

/// <p>The entry's key, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Key"
}

/// <p>The entry's key, which the card titles it by.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Key") = "string") Quit pFresh.%Get("Key")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Key") = "string") Quit pArgs.%Get("Key")
    Quit ""
}

/// <p>What the schema says of the entry's key.</p>
ClassMethod NameDescription() As %String
{
    Quit "The entry's key, named exactly as the term list's entries list reports it in its Key column. An entry the list does not report is refused."
}

/// <p>The derived schema with the term list added and required, the key described, and <code>FieldValues</code> as an array of
/// <code>{Field, Value}</code> objects, which the port judges.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#LISTARGUMENT, {"type": "string", "description": "The term list the entry belongs to, named exactly as this namespace's Term lists list reports it in its Name column."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#LISTARGUMENT)
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    If tProperties.%GetTypeOf("FieldValues") = "object" {
        Do tProperties.%Set("FieldValues", {"type": "array", "items": {"type": "object", "description": "One field's value: {\"Field\": the field's name, \"Value\": its value as text, at most 32,000 characters}."}, "description": "Values for the entry's extra fields, each naming a field the term list holds. A field you leave out keeps its value."})
    }
    Quit tSchema
}

/// <p>The term list inside the composite id <var>pIdValue</var>, <code>""</code> for any other spelling.</p>
ClassMethod ListOf(pIdValue As %String) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 2 Quit ""
    Quit $List(tParts, 1)
}

/// <p>The key inside the composite id <var>pIdValue</var>, <code>""</code> for any other spelling.</p>
ClassMethod KeyOf(pIdValue As %String) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 2 Quit ""
    Quit $List(tParts, 2)
}

/// <p>The rules over the call, for the write <parameter>WRITETYPE</parameter>: <method>RuleProblem</method> over the id's list and key.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If ..#WRITETYPE = ##class(OcuPilot.Port.AnalyticsPort).#TYPEENTRYREMOVE Quit $$$OK
    Quit ..RuleProblem(..#WRITETYPE, ..ListOf(pIdValue), ..KeyOf(pIdValue), pArgs, .pProblem)
}

/// <p>The fields <var>pArgs</var> carries, over the entry's own, member by member: <var>pFresh</var>'s <code>FieldValues</code> with each
/// pair <var>pArgs</var> names put in place, so a field the call leaves out keeps its value. The pairs are rebuilt as
/// <code>{Field, Value}</code>, in the list's own order and spelling, with a field not yet held appended.</p>
ClassMethod OverlaidPairs(pFresh As %DynamicObject, pArgs As %DynamicObject) As %DynamicArray
{
    Set tPairs = []
    Set tUpper = ""
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("FieldValues") = "array") {
        Set tIterator = pFresh.%Get("FieldValues").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPair) {
            Do tPairs.%Push({"Field": (tPair.%Get("Field")), "Value": (tPair.%Get("Value"))})
            Set tUpper = tUpper _ $ListBuild($ZConvert(tPair.%Get("Field"), "U"))
        }
    }
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf("FieldValues") '= "array") Quit tPairs
    Set tIterator = pArgs.%Get("FieldValues").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tNew) {
        If '$IsObject(tNew) || (tNew.%GetTypeOf("Field") '= "string") || (tNew.%GetTypeOf("Value") '= "string") Continue
        Set tAt = $ListFind(tUpper, $ZConvert(tNew.%Get("Field"), "U"))
        If tAt {
            Do tPairs.%Get(tAt - 1).%Set("Value", tNew.%Get("Value"), "string")
        } Else {
            Do tPairs.%Push({"Field": (tNew.%Get("Field")), "Value": (tNew.%Get("Value"))})
            Set tUpper = tUpper _ $ListBuild($ZConvert(tNew.%Get("Field"), "U"))
        }
    }
    Quit tPairs
}

}
