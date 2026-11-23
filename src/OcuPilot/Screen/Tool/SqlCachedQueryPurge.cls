/// <p>The base of the cached-query purges (Story 21.6, AD-6, AD-10, AD-51, AD-52, AD-53, AD-58): an action-style write that purges the cached queries
/// of one query, of one table or of the namespace, through <class>OcuPilot.Port.SqlPort</class>. Two callers reach each: the Cached queries tab's
/// row action or the page's own, through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. A purge costs a
/// re-prepare and changes no data, and it is never refused for a table of OcuPilot's own.</p>
/// <p><b>It sends no body.</b> The port builds <code>PurgeQueries</code>' qualifiers from the target alone, <code>{}</code> for the namespace,
/// <code>{"table": [...]}</code> for a table and <code>{"class": [...]}</code> for one cached query
/// (<method>OcuPilot.Port.SqlPort.PurgeTarget</method>), and runs Story 21.4's purge in the namespace the proposal read. The fresh read is the
/// port's <code>PURGE</code>, which answers how many cached queries the target holds; the fingerprint covers that count and the namespace.</p>
/// <p><b>Its pairs</b> are its screen's, which hold the custom resource of the classic SQL page the screen replaces, and WRITE on the namespace's
/// routines database as an argument pair (<method>ArgumentPairs</method>), which the port checks again for the namespace it writes.</p>
Class OcuPilot.Screen.Tool.SqlCachedQueryPurge Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port every purge reaches its target through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPort";

/// <p>The port-composed fresh read: how many cached queries the target holds.</p>
Parameter READTYPE = "PURGE";

Parameter WRITETYPE = "PURGEQUERIES";

/// <p>No body: the port builds the qualifiers.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>A purged query is prepared again the next time it runs, so no data is lost.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

Parameter WRITERESOURCE = "%Development";

Parameter WRITEPERMISSION = "USE";

Parameter READANSWERS = "Namespace,Target,Kind,CachedQueries";

/// <p>The namespace and the count of cached queries the purge was reviewed against.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,CachedQueries";

/// <p>The read field the purge reads, which the subject must carry (AD-51): a purge holds no precondition of its own, and the count it was
/// reviewed against is what moving under it would change.</p>
Parameter PRECONDITIONFIELD = "CachedQueries";

/// <p>The card's state row: the target's cached queries, which read <code>0</code> afterwards.</p>
Parameter STATEFIELD = "CachedQueries";

Parameter STATEAFTER = "0";

Parameter NAMESPACEFIELD = "Namespace";

/// <p>The argument naming the target.</p>
Parameter IDARGUMENT;

/// <p>The description the input schema gives the identifying property.</p>
Parameter IDDESCRIPTION;

/// <p>The code the card and the dialog state their consequence by.</p>
Parameter CONSEQUENCECODE = "SQL.CACHEDQUERY.PURGE";

ClassMethod IdArgument() As %String
{
    Quit ..#IDARGUMENT
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#IDKEY
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTCACHEDQUERIES
}

/// <p>None: the tool admits no argument beyond the target.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The identifying property described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..#IDDESCRIPTION, "string")
    Quit tSchema
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>WRITE on the routines database of the namespace the stored payload names, else of the request's scope
/// (<method>OcuPilot.Screen.Tool.ExplorerSave.CodeWritePairs</method>).</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerSave).CodeWritePairs(pArgs, .pResolved)
}

/// <p>The namespace the stored payload <var>pPayload</var> was read in, under the port's own query key, so the confirm's re-read and write reach
/// the namespace the proposal read (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.SqlPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

/// <p>Why <var>pId</var> is not a target of this tool, or <code>""</code>. Every subclass answers the one shape it takes.</p>
ClassMethod IdProblem(pId As %String) As %String [ Abstract ]
{
    Quit ""
}

ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..IdProblem(pIdValue)
    Quit $$$OK
}

ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tId = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..IdArgument()) = "string") Set tId = pValues.%Get(..IdArgument())
    Set pProblem = ..IdProblem(tId)
    Quit $$$OK
}

/// <p>The one state row this proposal's card shows: the target's cached queries moving from the count the fresh read answered to
/// <parameter>STATEAFTER</parameter>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) Quit
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#STATEFIELD), pFresh.%GetTypeOf(..#STATEFIELD)), "string")
        Do tRow.%Set("after", ..#STATEAFTER, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><parameter>CONSEQUENCECODE</parameter>, the sentence the card and the dialog state.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
