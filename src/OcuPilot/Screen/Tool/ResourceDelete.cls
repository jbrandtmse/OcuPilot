/// <p>The Resources list's delete tool (AD-6, AD-51): propose removing one resource. It reads the
/// resource fresh through the vendor's own <code>Security.Resource</code> <code>GET</code> and mints
/// a proposal whose card lists what would go. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code>, so <code>DELETE</code> reads no body, the tool admits no settable
/// field, and its field list is empty by derivation (AD-3).</p>
/// <p><b>Its fingerprint covers the whole read</b>: the description and the public permission. The
/// public permission is its precondition, because what every user loses is what the confirm must
/// still find. The identity is outside the subject (AD-13, AD-51).</p>
/// <p><b>Two refusals.</b> A system resource, one the vendor's own <code>AllowDelete</code> answers
/// false for, is refused at the mint (<method>ArgumentProblem</method>) and on the screen's Delete
/// (<method>ScreenActionDelta</method>). OcuPilot's own two
/// resources are the prohibited set's, refused at the write whatever the caller (AD-10).</p>
Class OcuPilot.Screen.Tool.ResourceDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.resources.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter DESCRIPTION = "Propose deleting one resource from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the resource exactly as the resources list reports it. A resource this instance does not hold, a system resource (the list shows it as not deletable) and OcuPilot's own resources are all refused.";

Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type: <code>Security.Resource</code>'s
/// <code>RunDelete</code>, which answers 409 for a system resource and 404 for an absent one.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted resource is gone, and every role's grant of it with it.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The Resources list's row action this write carries out (AD-53): Delete, bodyless.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off the vendor's
/// <code>ObjToJson</code> on this build.</p>
Parameter READANSWERS = "Description,PublicPermission";

Parameter PRECONDITIONFIELD = "PublicPermission";

Parameter FINGERPRINTSUBJECT = "Description,PublicPermission";

/// <p>The list request type and filter <method>ArgumentProblem</method> reads the vendor's
/// <code>AllowDelete</code> through: the single-object read does not answer it.</p>
Parameter LISTTYPE = "LIST";

Parameter LISTFILTER = "names";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Resource"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The resource to delete, exactly as this instance's own resources list reports it. A system resource, which the list shows as not deletable, is refused.", "string")
    Quit tSchema
}

/// <p>A system resource is <var>pProblem</var>, in the published <code>RESOURCE.NAME.SYSTEM</code>
/// sentence (<method>IsUndeletable</method>). A name the list does not carry is no problem here;
/// the mint's fresh read refuses it. A list that cannot be read is an error.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ..IsUndeletable(pIdValue, .tUndeletable)
    If $$$ISERR(tSC) Quit tSC
    If tUndeletable Set pProblem = "'" _ ..IdArgument() _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#RESOURCENAMESYSTEM)
    Quit $$$OK
}

/// <p>Whether <var>pName</var> is a system resource, in <var>pUndeletable</var>: the row this
/// tool's port lists for it answers <code>AllowDelete</code> other than <code>true</code>. A name
/// the list does not carry answers 0. A list that cannot be read is an error status.</p>
ClassMethod IsUndeletable(pName As %String, Output pUndeletable As %Boolean) As %Status
{
    Set pUndeletable = 0
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery(..#LISTFILTER) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..#LISTTYPE, .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRows) || 'tRows.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            If $ZConvert(tRow.%Get("Name"), "U") '= $ZConvert(pName, "U") Continue
            Set pUndeletable = (##class(OcuPilot.Kernel.Proposal.Mint).Display(tRow.%Get("AllowDelete"), tRow.%GetTypeOf("AllowDelete")) '= "true")
            Quit
        }
    } Catch ex {
        Set pUndeletable = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The screen's Delete (AD-53): the Resources list's row action reaches this write without the
/// mint's <method>ArgumentProblem</method>, so a system resource (<method>IsUndeletable</method>),
/// named by <var>pValues</var>' id argument, is refused here with the bare published
/// <code>RESOURCE.NAME.SYSTEM</code> sentence -- the one the row draws before a click. Every other
/// action is the base's.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) Quit tSC
    If (pActionId '= "delete") || '$IsObject(pValues) Quit $$$OK
    Set tSC = ..IsUndeletable(pValues.%Get(..IdArgument()), .tUndeletable)
    If $$$ISERR(tSC) Quit tSC
    If tUndeletable {
        Set pArgs = {}
        Set pProblem = ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#RESOURCENAMESYSTEM)
    }
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the fresh <code>GET</code>
/// <var>pFresh</var>: one per subject field, carrying the value the instance holds and no
/// after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that resource's public permission, and a resource whose permission is unknown is not one to delete"
            Quit
        }
        Set tSubject = ..FingerprintSubject()
        For tI = 1:1:$ListLength(tSubject) {
            Set tField = $List(tSubject, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
