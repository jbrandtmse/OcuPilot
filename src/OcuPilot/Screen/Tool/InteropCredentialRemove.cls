/// <p>Interoperability's credential remove (AD-6, AD-10, AD-51, AD-53, AD-62, Story 24.15): remove one credential of the request's namespace with its
/// password. Anything that names the credential can no longer use it (<code>INTEROP.CREDENTIAL.REMOVE</code>).</p>
/// <p><b>It is destructive</b>: a removed credential and its password cannot be restored from OcuPilot, so its card draws the destructive treatment,
/// its row action types the credential's name, and its governance key ships disabled (AD-22). Its read-back reads the credential gone on the port's
/// 404.</p>
/// <p><b>An agent proposal for the credential an enabled agent definition reads its provider key from is refused</b> when proposed
/// (<method>RefusedBeforeState</method>); the person's Remove on the screen is not.</p>
/// <p>Two callers reach it: the list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.
/// Its state, fingerprint and refusals are <class>OcuPilot.Screen.Tool.InteropCredentialAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropCredentialRemove Extends OcuPilot.Screen.Tool.InteropCredentialAction
{

Parameter TOOLNAME = "interop.credentials.remove";

Parameter DESCRIPTION = "Propose removing one credential, with its password, from the namespace the user is working in, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the credential exactly as the Credentials list reports it. Anything that names the credential can no longer use it. A credential the namespace does not hold is refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVECREDENTIAL";

/// <p>Declared: a removed credential and its password cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.CREDENTIAL.REMOVE";

/// <p>The credential's name, user name and business partner: what the removal reviewed, so a credential edited since the review closes the proposal
/// target-changed; and its namespace, which the stored payload keeps so the confirm and the script form act where the proposal read.</p>
Parameter FINGERPRINTSUBJECT = "Name,Username,BusinessPartner,Namespace";

Parameter PRECONDITIONFIELD = "Username";

/// <p>The removal rows the card shows: what the removed credential held.</p>
Parameter REMOVALROWS = "Name,Username,BusinessPartner";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

/// <p>The agent's remove of the provider's own credential is refused as <parameter>OcuPilot.Kernel.Proposal.Prohibited.PROVIDERCREDENTIAL</parameter>
/// before the precondition below reads it (AD-10, Story 24.15); a person's call and another credential are not refused.</p>
ClassMethod RefusedBeforeState(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Quit ..RefusedForProvider(pIdValue, .pCode)
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying
/// the value the instance holds and no after-state. A read that answered no <code>Username</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Username") '= "string") {
            Set pProblem = "this instance did not report the credential, and a credential whose state is unknown is not one to remove"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
