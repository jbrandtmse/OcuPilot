/// <p>Interoperability's credential password tool (AD-35, AD-51, AD-56 (i), AD-58, AD-59, AD-62, Story 24.15): propose setting the password of one
/// credential of the request's namespace. It reads the credential fresh and mints a proposal whose card asks for the password at the confirm. It
/// writes nothing. Whatever signs in with the credential uses the new password from its next connection (<code>INTEROP.CREDENTIAL.CHANGE</code>).</p>
/// <p><b>Its body is its declared secret and nothing else</b> (<parameter>SECRETBODY</parameter>): the kernel carries the password as the screen's
/// declaration and supplies it at the write (<method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method>); the model can never supply it, because
/// the tool admits no settable field and the mint refuses a declared secret outright. An empty password is not a password supplied, so the write is
/// refused and nothing is cleared.</p>
/// <p><b>Its fingerprint covers the user name and business partner</b>; the password is never part of it, and no read answers more than whether one is
/// stored. Its read-back reports the password written and never reads it.</p>
/// <p><b>An agent proposal for the credential an enabled agent definition reads its provider key from is refused</b> when proposed
/// (<method>RefusedBeforeState</method>); the person's Set password on the screen is not.</p>
Class OcuPilot.Screen.Tool.InteropCredentialPassword Extends OcuPilot.Screen.Tool.InteropCredentialAction
{

Parameter TOOLNAME = "interop.credentials.password";

Parameter DESCRIPTION = "Propose setting a new password for one credential of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews, and the user types the password on the card when confirming. Never send a password: name the credential exactly as the Credentials list reports it, and nothing else. A credential the namespace does not hold is refused.";

Parameter WRITETYPE = "PASSWORDCREDENTIAL";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "Password";

/// <p>The card's one row is labelled <code>Password</code>, which names the secret the card asks for rather than a field the payload carries.</p>
Parameter STATEFIELD = "Password";

Parameter PRECONDITIONFIELD = "Username";

Parameter FINGERPRINTSUBJECT = "Username,BusinessPartner,Namespace";

Parameter CHANGEACTION = "updated";

Parameter CONSEQUENCECODE = "INTEROP.CREDENTIAL.CHANGE";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

Parameter SCREENACTIONS = "password";

/// <p>The dialog sends the password alone, and never an empty one.</p>
Parameter SCREENVALUES = "password=Password";

/// <p>None: the write sends no merge body.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The agent's change of the provider's own credential is refused as <parameter>OcuPilot.Kernel.Proposal.Prohibited.PROVIDERCREDENTIAL</parameter>
/// before the precondition below reads it (AD-10, Story 24.15); a person's call and another credential are not refused.</p>
ClassMethod RefusedBeforeState(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Quit ..RefusedForProvider(pIdValue, .pCode)
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "Password", before: "", after: ""}</code>. It names the declared
/// secret, so the card masks it and asks for it; neither side carries a value, because no read returns one and the new one is supplied at the
/// confirm. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
            Set pProblem = "this instance did not report the credential, and a credential whose state is unknown is not one to set a password for"
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
