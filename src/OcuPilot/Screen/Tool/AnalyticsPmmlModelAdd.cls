/// <p>Analytics' PMML definition create (AD-3, AD-6, AD-54, AD-55, AD-61, AD-65, Story 24.14 Batch 3): make one class that defines PMML models, from PMML text, in the request's namespace. Two callers
/// reach it: the PMML models screen's New PMML definition dialog through <class>OcuPilot.Area.Analytics.PmmlDefinitionSave</class>, and the agent's proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find neither the class nor a class of its package, and a name taken since the mint closes the proposal target-changed. The proposal's target is the
/// class, named by its full name and kept exactly (AD-13). The port refuses a class that is OcuPilot's own, malformed or a <code>%</code> name, a held name or package, and a text that is empty,
/// too long, or holds a document type declaration or a <code>}</code>, each by its own code before anything is saved; the vendor parses the text, in the compile, and nothing else of OcuPilot's reads it as code
/// (AD-11, AD-60). Its fields are declared here (<method>FieldRows</method>, AD-3), and its read-back compares each (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
/// <p>It extends <class>OcuPilot.Screen.Tool.AnalyticsListingGroupAction</class> as the quality measure tools do, with the definition's own destination global
/// (<code>^oddDEF</code>, the database that holds class definitions), classic page, read and port rules. Its fresh read is the port's plain <code>PMMLDEFINITION</code>, which carries no write
/// action: a held class reads as a row and a free name as 404.</p>
Class OcuPilot.Screen.Tool.AnalyticsPmmlModelAdd Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction
{

Parameter TOOLNAME = "analytics.pmmlmodels.add";

Parameter DESCRIPTION = "Propose creating one PMML definition in the namespace the user is working in: a class, made from PMML text, that defines one or more predictive models. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the new class's name and one PMML document. The class is saved and compiled, and the classes the compile generates are made in its package. A class or package the namespace already holds, a class name that is malformed or begins with % or OcuPilot, and a text that is empty, longer than 3,000,000 characters, or holds a document type declaration or a } character are refused.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsPmmlModelList";

Parameter DESTINATIONGLOBAL = "^oddDEF";

Parameter CLASSICPAGES = "%DeepSee.PMML.UI.ModelTester";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADD";

Parameter SENDSBODY As BOOLEAN = 1;

/// <p>The fresh read: one definition class.</p>
Parameter READTYPE = "PMMLDEFINITION";

Parameter READANSWERS = "Class,PMML,Models,Namespace";

Parameter READBACKFIELDS = "Class,PMML";

/// <p>The consequence the write states: the class is saved and compiled, and its generated classes are made in its package (published once in EXPERIENCE.md's Fixed strings).</p>
Parameter CONSEQUENCECODE = "ANALYTICS.PMML.SAVE";

/// <p>No SQL consequence: a definition's text is parsed by the vendor, never run as SQL by OcuPilot.</p>
Parameter SQLCONSEQUENCECODE = "";

Parameter PRECONDITIONCODES = "ANALYTICS.PMML.TAKEN,ANALYTICS.PMML.READONLY,ANALYTICS.NAMESPACE";

Parameter VIOLATIONSMETHOD = "PmmlDefinitionViolations";

Parameter PROBLEMMETHOD = "PmmlDefinitionProblem";

Parameter FIELDS = "Class,PMML";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTPMMLMODELS
}

/// <p>The definition class's name, which the rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Class"
}

/// <p>The pairs the PMML screens declare beyond the source code API's: the portal's and the classic Model Tester's resource.</p>
ClassMethod EditPairs() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#PMMLPAIRS
}

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The fields as the rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 2
    Set pRows(1) = $ListBuild("Class", "string", 0)
    Set pRows(2) = $ListBuild("PMML", "string", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Class").%Set("description", "The new class that holds the definition: dotted letters and digits with a package, beginning with neither % nor OcuPilot. A class the namespace already holds, or one whose package holds a class, is refused, compared without regard to case.", "string")
    Do tProperties.%Get("PMML").%Set("description", "One PMML document, as text, of at most 3,000,000 characters, with no document type declaration and no } character. The instance parses it when it compiles the class.", "string")
    Quit tSchema
}

/// <p>The create's absence question (AD-54) is asked of the arguments, which carry no namespace yet: the read then answers 409 for a held class or package and 404 for a free name, so both callers are
/// refused a held name with <code>ANALYTICS.PMML.TAKEN</code>. The composed payload carries the namespace, and its read, the confirm's re-read and the read-back, answers a held class as its row.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "unassigned" Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#ACTIONKEY) = ..#WRITETYPE
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

/// <p>The text with its line endings as the class stores them (line feeds), so the payload both callers send reads back as sent (AD-58).</p>
ClassMethod TextNormalized(pArgs As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") Quit pArgs
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If tArgs.%GetTypeOf("PMML") = "string" Do tArgs.%Set("PMML", $Replace($Replace(tArgs.%Get("PMML"), $Char(13, 10), $Char(10)), $Char(13), $Char(10)), "string")
    Quit tArgs
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(..TextNormalized(pArgs), pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The class the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Class") '= "string") Quit ""
    Quit pWritten.%Get("Class")
}

}
