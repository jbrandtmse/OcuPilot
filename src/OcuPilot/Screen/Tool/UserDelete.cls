/// <p>The Users list's delete tool (AD-6, AD-51, FR-37): propose removing one user account. It
/// reads the account fresh through the vendor's own <code>Security.User</code> <code>GET</code> and
/// mints a proposal whose card lists what would go. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> excludes
/// <code>DELETE</code>, so the tool sends no body, admits no settable field, and its field list is
/// empty by derivation (AD-3).</p>
/// <p><b>Its fingerprint covers a declared subject</b> -- whether the account is enabled, its full
/// name and its roles, which is what the list shows beside the name and what the user reviewed. The
/// identity is the proposal's <code>TargetRef</code> (AD-13, AD-51); this endpoint's
/// <code>GET</code> answers no name to put in the subject.</p>
/// <p><b>It is destructive</b>: a deleted account cannot be proposed back.</p>
/// <p><b>Its self-protection is the prohibited set's, not its own.</b> The signed-in account,
/// <code>_SYSTEM</code>, a service account and the last <code>%All</code> holder are refused at the
/// write by <class>OcuPilot.Kernel.Proposal.Prohibited</class> whatever the caller, because this
/// tool's declared action is <code>deleted</code> (AD-10, AD-53).</p>
Class OcuPilot.Screen.Tool.UserDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.users.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

Parameter DESCRIPTION = "Propose deleting one user account from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the account exactly as the users list reports it. The account the user is signed in as, _SYSTEM, an account the instance's own services run as and the last account holding %All are all refused.";

/// <p>The row action this tool carries out from the Users list (AD-5, AD-53). It sends no argument,
/// because it sends no body.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The vendor's own delete request type (<parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter>).</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The AD-14 action this write performs: the account is removed, so a screen showing it drops
/// the row. It is also what puts the account predicates in front of it (AD-10).</p>
Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted account is gone and no proposal puts it back.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The read field this tool's precondition reads: an account whose enabled flag this instance
/// did not report is one whose own record the read did not answer.</p>
Parameter PRECONDITIONFIELD = "Enabled";

/// <p>The subject the fingerprint covers: what the list shows about the account beside its name.</p>
Parameter FINGERPRINTSUBJECT = "Enabled,FullName,Roles";

/// <p>The pair a delete requires: <code>%Admin_Secure:USE</code>, the vendor's own
/// <code>ResourcesOR()</code> resource and one the screen already declares (AD-8 as amended by
/// DW-1208).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.User"
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The user account to delete, exactly as this instance's own users list reports it. An account the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each once.</p>
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
/// after-state (EXPERIENCE.md's <code>diff-row</code>). A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tReported = ""
        If $IsObject(pFresh) {
            Set tReported = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
        }
        If tReported = "" {
            Set pProblem = "this instance did not report that account's own record, and an account whose configuration is unknown is not one to delete"
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
