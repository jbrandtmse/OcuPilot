/// <p>What Document databases' create and drop share (AD-6, AD-13, AD-52, AD-53, AD-55, Story 19.17): a
/// write of one document database of the request's namespace, reached by two callers -- the screen's
/// own Save or Drop, and the agent's proposal and confirmation.</p>
/// <p><b>The target is the database's name</b>, entity type <code>docdb-database</code>, which keeps
/// AD-13's <code>foldcase</code>: the instance resolves a name in any case. The fresh read is
/// <class>OcuPilot.Port.DocDbPort</class>'s <code>DATABASE</code>, which answers the namespace it read;
/// that namespace travels in the port query (<method>PortQuery</method>), so a confirm writes where the
/// proposal read.</p>
/// <p><b>It declares WRITE on the namespace's routines and globals databases</b> beyond the screen's
/// pairs (AD-8 as amended by Story 19.17), resolved for the request's scope at each gate call; the port
/// checks the same pairs for the namespace it writes, before any vendor call. A database whose class
/// begins with <code>OcuPilot</code> is refused by the kernel
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>) on both callers.</p>
Class OcuPilot.Screen.Tool.ExplorerDocDbWrite Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerDocDbList";

/// <p>The port that reads, creates and drops a document database (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DocDbPort";

/// <p>The fresh read: one database's row and the namespace it was read in.</p>
Parameter READTYPE = "DATABASE";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Class,DocumentType,Resource,Namespace";

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The permission a write requires on the resources guarding its namespace's routines and globals
/// databases.</p>
Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.DocDbPort).#ENDPOINT
}

/// <p>The database's name.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The query key the port reads the name from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.DocDbPort).#NAMEKEY
}

/// <p>The name refused by <method>OcuPilot.Port.DocDbPort.NameProblem</method>, as the screen's Save
/// refuses it (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Port.DocDbPort).NameProblem(pIdValue)
    Quit $$$OK
}

/// <p>The derived schema with the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p>What the schema says of the name. Empty here; each tool says it for its own write.</p>
ClassMethod NameDescription() As %String
{
    Quit ""
}

/// <p>The screen's own pairs, then WRITE on the routines database and on the globals database of the
/// namespace the request is scoped to (<method>OcuPilot.Kernel.Scope.Current</method>), each pair once
/// (AD-8). <var>pResolved</var> is 0 when the namespace's routines database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(##class(OcuPilot.Kernel.Scope).Current(), .tRoutine, .tGlobal, .tMapped, .tResolved)
    If tRoutine = "" {
        Set pResolved = 0
        Quit ""
    }
    For tResource = tRoutine, tGlobal {
        If tResource = "" Continue
        Set tOwn = $ListBuild(tResource, ..#WRITEPERMISSION)
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The namespace the stored payload <var>pPayload</var> was read or composed in, under the port's
/// own query key, so the confirm's re-read and write and every read-back reach the namespace the
/// proposal named (AD-52). A fresh read, whose payload is empty, is scoped by the port.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.DocDbPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
