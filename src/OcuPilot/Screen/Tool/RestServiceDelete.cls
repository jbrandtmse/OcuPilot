/// <p>The spec-based REST services' delete (AD-6, AD-51, AD-53, Story 18.32): remove one service of the request's
/// namespace, its <code>&lt;Name&gt;.spec</code> and <code>.disp</code> classes. Two callers reach it: the list's Delete
/// row action through <class>OcuPilot.Api.ScreenAction</class>, after its typed-name dialog, and the agent's proposal
/// and confirmation.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and <class>OcuPilot.Port.MgmntPort</class> removes the
/// service its query names in the namespace the proposal read. Its fingerprint covers the service's name and that
/// namespace. The <code>.impl</code> class is kept: the vendor's delete does not remove it, so the code a service's
/// author wrote survives.</p>
/// <p><b>It refuses a deployed service</b>: a web application that dispatches to <code>&lt;Name&gt;.disp</code>, and a
/// row that is itself a web application (an id starting <code>/</code>), are 409
/// <parameter>OcuPilot.Api.RestServiceError.DEPLOYED</parameter> from the fresh read
/// (<parameter>PRECONDITIONCODES</parameter>), so no vendor delete is sent. A package beginning with
/// <code>OcuPilot</code> is refused by the kernel on both callers
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>).</p>
/// <p><b>It is destructive</b>, and its governance key ships disabled (AD-22), so the agent's proposal is refused at
/// dispatch until an administrator enables it, while the screen's Delete works. Its read-back reads the service gone on
/// the port's 404. No vendor event records the delete (AD-15's twenty-first named case), and no classic page deletes a
/// REST service, so it declares no classic page (AD-44).</p>
Class OcuPilot.Screen.Tool.RestServiceDelete Extends OcuPilot.Screen.Tool.RestServiceWrite
{

Parameter TOOLNAME = "webapp.restapis.delete";

Parameter DESCRIPTION = "Propose deleting one spec-based REST service from this namespace: its <Name>.spec and <Name>.disp classes. The <Name>.impl class is kept. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the service as this namespace's REST API explorer reports it, exactly; a name it does not report is refused. A service a web application dispatches to is refused, and so is a web application's path, and so is a name whose class begins with OcuPilot.";

/// <p>The fresh read: the service, exactly as listed, when no web application dispatches to it.</p>
Parameter READTYPE = "SERVICE";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the port removes the service the query names (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared: a deleted service's specification and dispatch classes are gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>The list's Delete, which admits no value.</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Namespace";

/// <p>A delete acts on the service as it was reviewed.</p>
Parameter PRECONDITIONFIELD = "Name";

/// <p>The code the fresh read refuses a deployed service with: the target is not in the state the delete acts on.</p>
Parameter PRECONDITIONCODES = "RESTSERVICE.DEPLOYED";

Parameter FINGERPRINTSUBJECT = "Name,Namespace";

/// <p>The card's removal rows: what the deleted service held.</p>
Parameter REMOVALROWS = "Name";

/// <p>None: the tool admits no argument beyond the name.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>What the schema says of the name.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The service to delete, named exactly as this namespace's REST API explorer reports it: the package, in the letter case listed. A name the explorer does not list is refused, and so is a service a web application dispatches to.", "string")
    }
    Quit tSchema
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tNames = $ListFromString(..#REMOVALROWS)
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", $Select($IsObject(pFresh): pFresh.%Get(tField) _ "", 1: ""), "string")
        Do tRow.%Set("after", "", "string")
        Do tRow.%Set("removed", 1, "boolean")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

}
