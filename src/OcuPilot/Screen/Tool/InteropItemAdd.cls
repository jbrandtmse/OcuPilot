/// <p>Interoperability's item add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 20.3): add one item to a production
/// of the request's namespace. Two callers reach it: the Production items list's Add dialog through
/// <class>OcuPilot.Area.Interop.ItemSave</class>, and the agent's proposal and confirmation. It changes the
/// stored configuration and the production class only; a running production starts the item, when it is
/// enabled, only at Productions' confirmed Update.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no item of that name, and a name taken since the mint
/// reads present at the confirm's re-read and closes the proposal target-changed. The vendor stores a
/// duplicate name and a class that is no business host, so the port's refusals
/// (<method>OcuPilot.Port.InteropPort.AddViolations</method>) are OcuPilot's guarantee.</p>
/// <p><b>Its payload</b> is the six fields the caller supplies and the namespace the add was composed in
/// (<method>ComposeCreate</method>); the production is the id's first part. The port has no body template to
/// derive a field list from, so the fields are declared here (<method>FieldRows</method>, AD-3) and its
/// read-back compares them (<parameter>READBACKFIELDS</parameter>, AD-58). <code>Enabled</code> defaults to
/// false: an added item starts disabled unless the caller says otherwise.</p>
/// <p>It declares the three classic add-host dialogs (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropItemAdd Extends OcuPilot.Screen.Tool.InteropItemAction
{

Parameter TOOLNAME = "interop.items.add";

Parameter DESCRIPTION = "Propose adding one item to a production of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it, the new item's name, and the business service, business process or business operation class that runs it. PoolSize, Category and Comment are optional, and Enabled defaults to false, so the item starts disabled. The change is stored in the production's configuration; a running production starts an enabled item only when it is next updated or started. A name the production already holds in any letter case, an illegal name, a class that is not a business host compiled in this namespace, a value the item refuses and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADD";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends (AD-58).</p>
Parameter READBACKFIELDS = "Name,ClassName,PoolSize,Enabled,Category,Comment";

/// <p>The read-back re-reads the created item through the enable's single-object read, because the add's own
/// read asks for the add and answers a held name as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropItemEnable";

/// <p>The three classic add-host dialogs whose operation the add performs, spelled as
/// <code>NormalizePage</code> answers them (AD-44, measured at Story 20.3's Task 0).</p>
Parameter CLASSICPAGES = "EnsPortal.Dialog.ProductionAddService,EnsPortal.Dialog.ProductionAddProcess,EnsPortal.Dialog.ProductionAddOperation";

Parameter PRECONDITIONCODES = "INTEROP.ITEM.TAKEN,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Name,ClassName,PoolSize,Enabled,Category,Comment";

/// <p>The six fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The six fields as the field rows the input schema is derived from: name, class, category and comment
/// strings, a pool size number and an enabled boolean (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 6
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("ClassName", "string", 0)
    Set pRows(3) = $ListBuild("PoolSize", "number", 0)
    Set pRows(4) = $ListBuild("Enabled", "boolean", 0)
    Set pRows(5) = $ListBuild("Category", "string", 0)
    Set pRows(6) = $ListBuild("Comment", "string", 0)
    Quit $$$OK
}

/// <p>What the schema says of the new item's name and the fields beside it.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new item's name: 1 to 128 characters with no control character, no space at either end and none of | ; , [; it does not begin with - or _, end with -, ! or $, or read *. A name this production already holds, in any letter case, is refused, so check its Production items list first."
}

/// <p>The derived schema with the class, pool size, enabled flag, category and comment described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tDescriptions("ClassName") = "The business service, business process or business operation class that runs the item, compiled in this namespace. A class that is no business host is refused. Required."
    Set tDescriptions("PoolSize") = "How many jobs run the item, a whole number from 0. Omit it to take the class's own default: 0 for a business process that shares the production's actor pool, 1 for most others."
    Set tDescriptions("Enabled") = "Whether the item starts enabled. Omit it for false: a new item starts disabled."
    Set tDescriptions("Category") = "Optional display categories, comma-separated. They do not change how the item behaves."
    Set tDescriptions("Comment") = "Optional comment shown beside the item."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push("ClassName")
    Quit tSchema
}

/// <p>The composed payload and diff of the create (AD-54): the six fields the caller supplied, as the
/// kernel's <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them (the item's name is the id's
/// and is not a payload field), the namespace the request is scoped to, which the port query and the
/// prohibited set read, and an explicit <code>Enabled</code> of false when the caller sent none, so the
/// read-back reads the item the add left. The last two add no diff row. An add that names no
/// <code>ClassName</code> is <var>pProblem</var>.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    If pPayload.%GetTypeOf("Enabled") '= "boolean" Do pPayload.%Set("Enabled", 0, "boolean")
    Quit tSC
}

/// <p>The composite id of the item the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("Production") '= "string") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("Production"), pWritten.%Get("Name")))
}

/// <p>The rules over the caller's fields and the production, as one sentence naming each field and its
/// published sentence, or <code>""</code> (AD-55): <method>OcuPilot.Port.InteropPort.AddViolations</method>
/// and a production the namespace holds, in the namespace <var>pArgs</var> carries under
/// <parameter>NAMESPACEFIELD</parameter> (the mint stores it, <class>OcuPilot.Screen.Tool.InteropItemMint</class>),
/// else the request's. The screen's Save and the mint apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pArgs.%Get(..#NAMESPACEFIELD) '= "") Set tNamespace = pArgs.%Get(..#NAMESPACEFIELD)
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If '$ClassMethod(..#PORTCLASS, "ProductionHeld", tNamespace, $ListGet(tParts, 1)) {
        Set pProblem = "'" _ ..#PRODUCTIONARGUMENT _ "' names no production of this namespace"
        Quit $$$OK
    }
    Set tSC = $ClassMethod(..#PORTCLASS, "AddViolations", tNamespace, $ListGet(tParts, 2), pArgs, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

/// <p>The same rules again at the write, in the namespace the proposal read, so a confirm is refused what the
/// mint would now refuse -- a class compiled away since -- before the claim, leaving the proposal live, whatever
/// namespace the confirming request is scoped to (AD-6, AD-40, AD-52).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The add always asks its read for the add (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>):
/// present is <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the
/// confirm alike. The namespace is the payload's, else the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
