/// <p>Interoperability's business partner remove (AD-6, AD-10, AD-51, AD-53, AD-62, Story 20.26): remove one business partner of the
/// request's namespace with its description and both contacts. <b>A partner that any item of any production of the namespace names in
/// its Host Business partner setting is refused</b> (<code>INTEROP.PARTNER.NAMED</code>), running or not, so no item is left
/// pointing at nothing; once the setting is cleared on each of those items, the remove runs.</p>
/// <p><b>It is destructive</b>: a removed partner and its contacts cannot be restored from OcuPilot, so its card draws the destructive
/// treatment, its row action types the partner's name, and its governance key ships disabled (AD-22). Its read-back reads the partner
/// gone on the port's 404.</p>
/// <p>Two callers reach it: the partners list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation. Its state, fingerprint and refusals are <class>OcuPilot.Screen.Tool.InteropPartnerAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropPartnerRemove Extends OcuPilot.Screen.Tool.InteropPartnerAction
{

Parameter TOOLNAME = "interop.businesspartners.remove";

Parameter DESCRIPTION = "Propose removing one business partner, with its description and both contacts, from the namespace the user is working in, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the partner exactly as the Business partners list reports it. A partner that production items name in their Business partner setting is refused: clear that setting on each of those items first. A partner the namespace does not hold and a namespace under source control are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVEPARTNER";

/// <p>Declared: a removed partner and its contacts cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.PARTNER.REMOVE";

/// <p>The fourteen fields of the partner and how many items name it: what the removal reviewed, so a partner edited or newly named
/// since the review closes the proposal target-changed.</p>
Parameter FINGERPRINTSUBJECT = "Name,Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes,NamedBy";

Parameter PRECONDITIONFIELD = "NamedBy";

/// <p>The removal rows the card shows: what the removed partner held.</p>
Parameter REMOVALROWS = "Name,Description,PrimaryContact,AlternativeContact";

Parameter PRECONDITIONCODES = "INTEROP.PARTNER.NAMED,INTEROP.PARTNER.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state. A read that answered no
/// <code>Description</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Description") '= "string") {
            Set pProblem = "this instance did not report the business partner, and a partner whose state is unknown is not one to remove"
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
