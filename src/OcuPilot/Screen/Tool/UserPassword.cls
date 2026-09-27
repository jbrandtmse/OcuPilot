/// <p>The Users list's set-password tool (AD-51, AD-56, FR-37): propose setting one account's
/// password, as an administrator sets another user's. It reads the account fresh through the
/// vendor's own <code>Security.User</code> <code>GET</code> and mints a proposal whose card asks for
/// the new password at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b> (AD-56 (i)): the vendor's
/// <code>CHANGEPWD</code> request type takes exactly <code>{NewPassword}</code> and sets only the
/// password. The kernel carries the secret as the descriptor's one declaration,
/// <code>Password</code> (<parameter>SECRETBODY</parameter>), supplies it at the write
/// (<method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method>), and the port renames it on the
/// wire (<parameter>OcuPilot.Port.AdminPort.RENAMEDTYPES</parameter>). The model can never supply
/// it: the tool admits no settable field, and the mint refuses a declared secret outright.</p>
/// <p><b>The change-on-login flag is not this tool's</b>: the vendor type cannot carry it, so it is
/// its own <class>OcuPilot.Screen.Tool.UserUpdate</class> write, sent first. This write clears it,
/// so <method>AfterWrite</method> sets it again when the fresh read found it set (AD-56).</p>
/// <p><b>Its fingerprint covers <code>Enabled</code></b>, the state the precondition reads; the
/// password is never part of it, and no read answers one.</p>
/// <p>AD-49 does not apply: this is an administrator setting another account's password through the
/// admin API, not a person changing their own.</p>
Class OcuPilot.Screen.Tool.UserPassword Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.users.password";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

Parameter DESCRIPTION = "Propose setting a new password for one user account on this instance. It changes nothing by itself: it answers a proposal the user reviews, and the user types the new password on the card when confirming. Never send a password: name the account exactly as the users list reports it, and nothing else.";

/// <p>The row action this tool carries out from the Users list, and the one value it admits: the
/// password, which the route hands to the write alone (AD-56 (ii)).</p>
Parameter SCREENACTIONS = "set-password";

Parameter SCREENVALUES = "set-password=Password";

/// <p>The vendor's own change-password request type.</p>
Parameter WRITETYPE = "CHANGEPWD";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The declared secret the write's body is made of.</p>
Parameter SECRETBODY = "Password";

/// <p>The card's one row is labelled <code>Password</code>, which names the secret the card asks
/// for rather than a field the payload carries (AD-10, AD-51).</p>
Parameter STATEFIELD = "Password";

Parameter PRECONDITIONFIELD = "Enabled";

Parameter FINGERPRINTSUBJECT = "Enabled";

/// <p>The flag the vendor's password change clears, and the merge request type that sets it again
/// (<method>AfterWrite</method>).</p>
Parameter CHANGEPASSWORDFIELD = "ChangePassword";

Parameter FLAGWRITETYPE = "PUT";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.User"
}

/// <p>None: the write sends no merge body.</p>
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The user account whose password is to be set, exactly as this instance's own users list reports it. The new password is typed by the user at confirmation and is never an argument.", "string")
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

/// <p>Re-apply the change-on-login flag the vendor's password change clears (AD-56 (i) as amended
/// 2026-09-23): when the fresh read taken before the write, <var>pFresh</var>, had
/// <code>ChangePassword</code> set, re-read the account through the same port and <code>PUT</code>
/// its complete property set with the flag set. A flag that was not set is left alone.</p>
/// <p>Both callers reach it through <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method>, so
/// a flag proposal confirmed before this write ends set either way. A failed re-read or re-apply is
/// an error status with the port's own fault; the password has been set.</p>
ClassMethod AfterWrite(pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#CHANGEPASSWORDFIELD) '= "boolean") Quit $$$OK
    If 'pFresh.%Get(..#CHANGEPASSWORDFIELD) Quit $$$OK
    Kill tQuery
    Set tQuery(pIdParam) = pIdValue
    Set tSC = $ClassMethod(pPort, "Invoke", pEndpoint, "GET", .tQuery, "", .tNow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tNow)) || 'tNow.%IsA("%Library.DynamicObject") {
        Set pHttpStatus = 404
        Quit $$$ERROR($$$GeneralError, "the account could not be re-read to restore its change-on-login flag")
    }
    If tNow.%Get(..#CHANGEPASSWORDFIELD) Quit $$$OK
    Do tNow.%Set(..#CHANGEPASSWORDFIELD, 1, "boolean")
    Quit $ClassMethod(pPort, "Invoke", pEndpoint, ..#FLAGWRITETYPE, .tQuery, tNow, .tWritten, .pHttpStatus, .pFault)
}

/// <p><method>AfterWrite</method> as a copy-out script step (AD-59): the change-on-login flag the
/// vendor's password change clears, set again on account <var>pIdValue</var> through
/// <class>Security.Users</class> in <code>%SYS</code>, which changes that one property. A stored
/// read <var>pStoredPayload</var> that carries the flag decides: set, one step; clear, none. A read
/// that does not carry it -- the proposal stores only its fingerprint subject -- answers the step
/// guarded by the <code>&lt;ChangeAtNextLogin&gt;</code> placeholder, the condition
/// <method>AfterWrite</method> tests, which the person fills in with 1 or 0.</p>
ClassMethod SnippetAfter(pEndpoint As %String, pIdParam As %String, pIdValue As %String, pStoredPayload As %DynamicObject, pContext As %DynamicObject = "") As %DynamicArray
{
    Set tSteps = []
    Set tKnown = $IsObject(pStoredPayload) && (pStoredPayload.%GetTypeOf(..#CHANGEPASSWORDFIELD) = "boolean")
    If tKnown && 'pStoredPayload.%Get(..#CHANGEPASSWORDFIELD) Quit tSteps
    Set tLines = $ListBuild("Kill tProps", "Set tProps(" _ ##class(OcuPilot.Port.AdminPort).Literal(..#CHANGEPASSWORDFIELD) _ ") = 1", "Set tSC = ##class(Security.Users).Modify(" _ ##class(OcuPilot.Port.AdminPort).Literal(pIdValue) _ ", .tProps)", "Do $System.Status.DisplayError(tSC)")
    If 'tKnown {
        ; One line, so the guard holds when the step is pasted into a terminal line by line.
        Set tLines = $ListBuild("; <ChangeAtNextLogin>: 1 when the account had to change its password at next login before this change, else 0", "If <ChangeAtNextLogin> { " _ $ListToString(tLines, "  ") _ " }")
    }
    Do tSteps.%Push(##class(OcuPilot.Port.AdminPort).ObjectScriptStep(tLines))
    Quit tSteps
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "Password",
/// before: "", after: ""}</code>. It names the declared secret, so the card masks it and asks for
/// it; neither side carries a value, because no read returns one and the new one is supplied at
/// confirm. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
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
            Set pProblem = "this instance did not report that account's own record, and an account whose configuration is unknown is not one to set a password for"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", "", "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
