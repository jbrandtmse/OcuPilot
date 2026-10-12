/// <p>What Interoperability's four item writes share (AD-6, AD-51, AD-52, AD-53, AD-54, AD-62, Story 20.3): a
/// write of one item of one production of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Production items row action or
/// Add, and the agent's proposal and confirmation. Every item write changes the stored production
/// configuration and the production class and nothing else: it never updates, starts or stops a production,
/// so a running production reads update pending until Productions' confirmed Update applies the change.</p>
/// <p><b>The target is the composite <code>[Production, Name]</code></b>
/// (<class>OcuPilot.Screen.Tool.InteropItemMint</class>), never the vendor's integer item id, which a
/// recompile renumbers. The fresh read is the port's <code>ITEM</code>, composed for the action at the mint
/// and at a screen action (<method>PortQuery</method>): a state the vendor would store twice, answer as a
/// silent success or change in the wrong place is refused by the port with the action's own
/// <code>INTEROP.ITEM.*</code> code, 409 (<parameter>PRECONDITIONCODES</parameter>). The confirm's re-read is
/// not composed for the action, so an item that moved closes the proposal through the fingerprint, and the
/// write itself refuses again by the same codes.</p>
/// <p><b>The namespace travels in the payload</b> (AD-52): a confirm writes in the namespace the proposal
/// read, whatever the confirming request is scoped to.</p>
/// <p><b>It declares</b> <code>%Ens_ProductionConfig:WRITE</code> and WRITE on the namespace's globals and
/// routines databases beyond the screen's pairs (AD-8, AD-62), each refused by name before any port call,
/// then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-44). It does not declare
/// <code>%Ens_ProductionRun:USE</code>: no item write touches a running job.</p>
Class OcuPilot.Screen.Tool.InteropItemAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropItemList";

/// <p>The fresh read: one item, composed for the action.</p>
Parameter READTYPE = "ITEM";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Production,Name,ClassName,Type,Enabled,EnabledSource,PoolSize,Category,Comment,Namespace,Count";

/// <p>The routines database is written too: the production class is saved.</p>
Parameter ROUTINESDATABASE As BOOLEAN = 1;

/// <p>The item read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Enabled";

/// <p>The argument naming the production the item belongs to.</p>
Parameter PRODUCTIONARGUMENT = "Production";

/// <p>The consequence code the proposal carries. The client maps it to its published sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.ITEM.PENDING";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTITEMS
}

/// <p><class>OcuPilot.Screen.Tool.InteropItemMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropItemMint"
}

/// <p>The target's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>The derived schema with the production added and required, and the item's name described: the target
/// is one item, named as the Production items list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#PRODUCTIONARGUMENT, {"type": "string", "description": "The production the item belongs to, named exactly as this namespace's Productions list reports it (its class name, case included). A production the list does not report is refused."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#PRODUCTIONARGUMENT)
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p>What the schema says of the item's name. The item write the tool makes states it.</p>
ClassMethod NameDescription() As %String
{
    Quit "The item, named exactly as this production's Production items list reports it. An item the list does not report is refused."
}

/// <p>The one row an enable or a disable shows, from the fresh read <var>pFresh</var>: <code>Enabled</code>
/// moving from the item's value to its opposite. A read that answered no <code>Enabled</code> is
/// <var>pProblem</var>, since an item nobody established is not one to act on. A remove overrides it.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Enabled") '= "boolean") {
            Set pProblem = "this instance did not report the item's state"
            Quit
        }
        Set tBefore = pFresh.%Get("Enabled")
        Set tRow = {}
        Do tRow.%Set("field", "Enabled", "string")
        Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(tBefore, "boolean"), "string")
        Do tRow.%Set("after", ##class(OcuPilot.Kernel.Proposal.Mint).Display('tBefore, "boolean"), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
