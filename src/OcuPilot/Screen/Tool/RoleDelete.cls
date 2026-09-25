/// <p>The Roles list's delete tool (AD-6, AD-51, FR-39): propose removing one role. It reads the
/// role fresh through the vendor's own <code>Security.Role</code> <code>GET</code> and mints a
/// proposal whose card lists what would go. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code>, so <code>DELETE</code> reads no body, the tool admits no settable
/// field, and its field list is empty by derivation rather than by hand (AD-3).</p>
/// <p><b>Its fingerprint covers the whole read</b>: the description, the roles it grants, whether it
/// is escalation-only and its resource grants -- everything a holder of the role loses. The
/// identity is outside the subject: which role this is is the proposal's <code>TargetRef</code>
/// (AD-13, AD-51), and the <code>GET</code> answers no name.</p>
/// <p><b>It is destructive</b>: a deleted role, and every holder's grant of it, cannot be proposed
/// back.</p>
/// <p><b>Three refusals.</b> A name beginning <code>%</code> is refused at the mint
/// (<method>ArgumentProblem</method>) and on the screen's Delete (<method>ScreenActionDelta</method>),
/// because the vendor endpoint drops a predefined role and reports success. One of OcuPilot's own roles, and a role whose removal leaves no counted
/// <code>%All</code> holder, are the prohibited set's, refused at the write whatever the caller
/// (AD-10). A vendor answer that reports the drop and leaves the role in place fails the confirm in
/// the port (<parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter>).</p>
Class OcuPilot.Screen.Tool.RoleDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.roles.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoleList";

Parameter DESCRIPTION = "Propose deleting one role from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the role exactly as the roles list reports it. A role this instance does not hold, one of the instance's own roles (a name beginning %), one of OcuPilot's own roles, and the role through which the last account holding %All holds it, are all refused.";

/// <p>The vendor's own delete request type: <code>Security.Role</code>'s <code>RunDelete</code>,
/// which answers 404 for an absent role.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type, so nothing is sent, nothing is disclosed as
/// unchanged and the ledger names no field (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The AD-14 action this write performs: the target is removed, so a screen showing it drops
/// the row rather than re-reading one that moved.</p>
Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted role is gone and no proposal puts it back. The card draws the destructive
/// treatment and its Confirm is <code>button-destructive</code>.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The Roles list's row action this write carries out (AD-53): Delete, bodyless.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off the vendor's
/// <code>PropsToJson</code> on this build. The screen's list answers <code>CreatedBy</code> and
/// <code>Name</code> and not <code>GrantedRoles</code> or <code>Resources</code>, which is the gap
/// this declaration exists for (DW-1475).</p>
Parameter READANSWERS = "Description,GrantedRoles,EscalationOnly,Resources";

/// <p>The read field this tool's precondition reads: what every holder of the role loses is what the
/// confirm must still find.</p>
Parameter PRECONDITIONFIELD = "Resources";

/// <p>The subject the fingerprint covers: the whole read, which is what the card shows and what the
/// user reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Description,GrantedRoles,EscalationOnly,Resources";

/// <p>The pair a delete requires: <code>%Admin_Secure:USE</code>, the vendor's own
/// <code>ResourcesOR()</code> resource for this endpoint and one
/// <class>OcuPilot.Screen.Descriptor.RoleList</class> already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The prefix only the instance's own predefined roles carry.</p>
Parameter SYSTEMPREFIX = "%";

ClassMethod Endpoint() As %String
{
    Quit "Security.Role"
}

/// <p>None: the write sends no body, so <method>OcuPilot.Screen.Tool.Write.FieldRows</method>
/// answers no rows and the merge may set nothing (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced: the target is one
/// role, named as this instance's own list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The role to delete, exactly as this instance's own roles list reports it. A name beginning % is one of the instance's own roles and is refused.", "string")
    Quit tSchema
}

/// <p>A name beginning <parameter>SYSTEMPREFIX</parameter> is <var>pProblem</var>, in the published
/// <code>ROLE.NAME.SYSTEM</code> sentence: the classic Roles list refuses Delete for those names,
/// and the vendor endpoint would drop one and report success.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If ..IsSystemRole(pIdValue) {
        Set pProblem = "'" _ ..IdArgument() _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#ROLENAMESYSTEM)
    }
    Quit $$$OK
}

/// <p>Whether <var>pName</var> is one of the instance's own predefined roles: it begins
/// <parameter>SYSTEMPREFIX</parameter>.</p>
ClassMethod IsSystemRole(pName As %String) As %Boolean
{
    Quit $Extract($ZStrip(pName, "<W"), 1) = ..#SYSTEMPREFIX
}

/// <p>The screen's Delete (AD-53): the Roles list's row action reaches this write without the
/// mint's <method>ArgumentProblem</method>, so a predefined role (<method>IsSystemRole</method>),
/// named by <var>pValues</var>' id argument, is refused here with the bare published
/// <code>ROLE.NAME.SYSTEM</code> sentence -- the one the row draws before a click. Every other
/// action is the base's.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) Quit tSC
    If (pActionId = "delete") && $IsObject(pValues) && ..IsSystemRole(pValues.%Get(..IdArgument())) {
        Set pArgs = {}
        Set pProblem = ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#ROLENAMESYSTEM)
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
/// <var>pFresh</var>: one per subject field, carrying the field and the value the instance holds
/// and no after-state, which is what a delete's diff row is.</p>
/// <p>A read that answered no <parameter>PRECONDITIONFIELD</parameter> array is
/// <var>pProblem</var>: a role whose grants this instance did not report is not one to propose
/// removing.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "array") {
            Set pProblem = "this instance did not report that role's resource grants, and a role whose grants are unknown is not one to delete"
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
