/// <p>The Web applications list's delete tool (AD-6, AD-51, FR-32): propose removing one web
/// application. It reads the application fresh through the vendor's own <code>WebApp.App</code>
/// <code>GET</code> and mints a proposal whose card lists what would go. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code>, so <code>DELETE</code> reads no body, the tool admits no settable
/// field, and its field list is empty by derivation rather than by hand (AD-3).</p>
/// <p><b>Its fingerprint covers a declared subject</b>, the four properties the list itself shows
/// beside the name: the namespace the application serves, the class that answers at it, the
/// resource that guards it and whether it is enabled. They are what the user reviewed, and an
/// application whose namespace or dispatch class moved between the proposal and the confirm is not
/// the one that was reviewed. The identity is deliberately outside the subject: which object this
/// is is the proposal's <code>TargetRef</code> (AD-13, AD-51), and this endpoint's <code>GET</code>
/// answers no name of its own to put there.</p>
/// <p><b>It is destructive</b>: a deleted web application cannot be proposed back.</p>
/// <p><b>Its self-protection is the prohibited set's, not its own.</b> OcuPilot's own applications
/// are refused at the write by <class>OcuPilot.Kernel.Proposal.Prohibited</class> whatever the
/// caller, so nothing here decides what may be deleted (AD-10, AD-53).</p>
Class OcuPilot.Screen.Tool.WebAppDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.list.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter DESCRIPTION = "Propose deleting one web application from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the application exactly as the web applications list reports it. An application this instance does not serve, and one OcuPilot is itself served through, are both refused.";

/// <p>The row action this tool carries out from the Web applications list (AD-5, AD-53). It sends
/// no argument, because it sends no body.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The vendor's own delete request type. Measured on this build 2026-09-22:
/// <code>WebApp.App</code>'s <code>TYPEDELETE</code> is 3, its <code>RunDelete</code> reaches
/// <code>Security.Applications.Delete</code> after an <code>Exists</code> check that answers 404,
/// its <code>NeedsRequestBody()</code> is <code>..IsTypePut()</code> and its
/// <code>ValidateQueryParams</code> requires the <code>name</code> query parameter for every
/// non-list type.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type, so nothing is sent, nothing is disclosed as
/// unchanged and the ledger names no field (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The AD-14 action this write performs: the target is removed, so a screen showing it drops
/// the row rather than re-reading one that moved.</p>
Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted web application is gone and no proposal puts it back. The card draws the
/// destructive treatment and its Confirm is <code>button-destructive</code>.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off the instance rather
/// than off the screen's own list (2026-09-22, <code>WebApp.App</code> <code>GET</code> for
/// <code>/csp/user</code>). They are not the list's spelling: the row spells the namespace
/// <code>Namespace</code> and this read spells it <code>NameSpace</code>, which is exactly the
/// gap this declaration exists for (DW-1475). <class>OcuPilot.Test.WebApp</class> pins the set
/// against the live read.</p>
Parameter READANSWERS = "AutheEnabled,AutoCompile,ChangePasswordPage,CookiePath,CorsAllowlist,CorsCredentialsAllowed,CorsHeadersList,CSPZENEnabled,CSRFToken,DeepSeeEnabled,Description,DispatchClass,Enabled,ErrorPage,EventClass,GroupById,iKnowEnabled,InbndWebServicesEnabled,IsNameSpaceDefault,JWTAuthEnabled,JWTAccessTokenTimeout,JWTRefreshTokenTimeout,LockCSPName,LoginPage,NameSpace,Package,Path,PermittedClasses,Recurse,RedirectEmptyPath,Resource,ServeFiles,ServeFilesTimeout,SuperClass,Timeout,TraceEnabled,TwoFactorEnabled,UseCookies,SessionScope,UserCookieScope,WSGIAppLocation,WSGIAppName,WSGICallable,WSGIDebug,WSGIType,MatchRoles";

/// <p>The read field this tool's precondition reads: an application whose namespace this instance
/// did not report is not one to delete. Every application this build serves reports one (measured
/// over all 45 on 2026-09-22), so an empty value means the read did not answer the application's
/// own record.</p>
Parameter PRECONDITIONFIELD = "NameSpace";

/// <p>The subject the fingerprint covers: what the list shows about the application beside its
/// name, which is what the user reviewed.</p>
Parameter FINGERPRINTSUBJECT = "NameSpace,DispatchClass,Resource,Enabled";

/// <p>The pair a delete requires: <code>%Admin_Secure:USE</code>, the vendor's own
/// <code>ResourcesOR()</code> resource for this endpoint and one
/// <class>OcuPilot.Screen.Descriptor.WebAppList</class> already declares -- so the resolved set is
/// the screen's own two pairs and nothing else (AD-8 as amended by DW-1208). Never
/// <code>:WRITE</code>: no shipped role grants an administrative resource at that permission.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "WebApp.App"
}

/// <p>None: the write sends no body, so <method>OcuPilot.Screen.Tool.Write.FieldRows</method>
/// answers no rows and the merge may set nothing (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced: the target is one
/// web application, named as this instance's own list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The web application to delete, exactly as this instance's own web applications list reports it. An application the list does not report is refused, and so is one OcuPilot is itself served through.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended only when
/// the screen does not already declare it so the ledger row's pair column records one check
/// once (DW-1208).</p>
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
/// and no after-state, which is what a delete's diff row is (EXPERIENCE.md's
/// <code>diff-row</code>).</p>
/// <p>A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>: an
/// application whose own record this instance did not report is not one to propose removing.</p>
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
            Set pProblem = "this instance did not report that web application's own record, and an application whose configuration is unknown is not one to delete"
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
