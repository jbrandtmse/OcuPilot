/// <p>The handler behind <code>POST /account/password</code> (Story 15.1, FR-73, AD-49): the
/// signed-in user changes their own password.</p>
/// <p><b>Caller-own and ungated beyond the router</b>, like
/// <class>OcuPilot.Api.Context</class>. The change runs as <code>$Username</code> through
/// <code>$System.Security.ChangePassword</code> -- the call the Management Portal's own
/// self-service dialog makes -- in the calling process, with no service account, no
/// <code>New $ROLES</code> and no <code>%SYS</code> switch (AD-8, AD-16, AD-49). It mints no
/// proposal and emits no OcuPilot audit marker: IRIS raises <code>%System</code> /
/// <code>%Security</code> / <code>UserChange</code> for this operation itself, on failure as well
/// as success.</p>
/// <p><b>A password value exists only as a local on this stack.</b> Neither value enters a log
/// line, an exception, a <class>%Status</class>, a URL or an error message (NFR-5, AD-21, AD-35,
/// Conventions › Secrets), and they and the parsed body are cleared on every path before this
/// class returns. The body
/// refusal is rendered and logged from a status <b>this class composed</b>, naming the stage
/// alone, because the read's own status can quote the document it failed to parse.</p>
Class OcuPilot.Api.Account Extends %RegisteredObject
{

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it. The route accepts no user
/// name, so this is the only account the handler can reach.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>The embedded code for a current password that is not this account's
/// (<code>$$$InvalidPassword</code>, measured on this build).</p>
/// <p>Every code here is tested for by <b>containment</b> in
/// <method>%SYSTEM.Status.GetErrorCodes</method>' comma-separated list, never by equality:
/// <code>ERROR #1446</code> is always the outer code and identifies nothing on its own.</p>
Parameter WRONGPASSWORDCODE = 952;

/// <p>The two embedded codes whose own text is passed through as a policy refusal's
/// <code>reason</code>: <code>$$$UserPasswordInvalidFormat</code> and
/// <code>$$$InvalidPasswordPattern</code>. The allow-list is closed -- vendor text outside it is
/// never rendered (AD-39).</p>
Parameter POLICYCODES = "845,958";

/// <p>Answer <code>POST /account/password {"currentPassword","newPassword"}</code>: change the
/// calling user's own password and answer <code>200 {}</code>.</p>
/// <p>A body carrying anything but exactly those two string members is refused 422
/// <parameter>OcuPilot.Api.Error.ACCOUNTPASSWORDBODY</parameter> before the change is attempted. A
/// refused change is one 422 <parameter>OcuPilot.Api.Error.ACCOUNTVALIDATION</parameter> carrying
/// one violation -- on <code>currentPassword</code> when the old password was wrong, on
/// <code>newPassword</code> when the instance's policy refused the new one, with the instance's
/// own sentence as that violation's <code>reason</code>. Any other outcome is a 500 whose detail
/// reaches the log alone.</p>
ClassMethod HandlePasswordChange() As %Status
{
    Set tSC = $$$OK
    Set tCurrent = ""
    Set tNew = ""
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tRequestBody, .tStage)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderBodyRefusal(tStage)
            Quit
        }
        If '$IsObject(tRequestBody) || 'tRequestBody.%IsA("%Library.DynamicObject") {
            Set tSC = ..RenderBodyRefusal("shape")
            Quit
        }
        ; The iterator's value is bound to a variable nothing reads: it is one of the two password
        ; values, and %GetNext's second argument is where it lands whether or not it is wanted.
        Set tExtra = 0
        Set tIterator = tRequestBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tIgnored) {
            If (tKey '= "currentPassword") && (tKey '= "newPassword") Set tExtra = 1
        }
        Set tIgnored = ""
        If tExtra || (tRequestBody.%GetTypeOf("currentPassword") '= "string") || (tRequestBody.%GetTypeOf("newPassword") '= "string") {
            Set tSC = ..RenderBodyRefusal("shape")
            Quit
        }

        Set tCurrent = tRequestBody.%Get("currentPassword")
        Set tNew = tRequestBody.%Get("newPassword")
        Set tRequestBody = ""
        Set tChanged = $System.Security.ChangePassword(..CallerUsername(), tNew, tCurrent, .tChangeSC)
        ; Cleared here rather than after the render: nothing below this line needs either value,
        ; and the renders can raise.
        Set tCurrent = ""
        Set tNew = ""
        If tChanged {
            Set tSC = ##class(OcuPilot.Api.Response).JSON({})
            Quit
        }
        Set tSC = ..RenderChangeRefusal($Get(tChangeSC, $$$OK))
    } Catch ex {
        Set tCurrent = ""
        Set tNew = ""
        Set tRequestBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Set tCurrent = ""
    Set tNew = ""
    Set tRequestBody = ""
    Quit tSC
}

/// <p>Refuse the body with 422 <parameter>OcuPilot.Api.Error.ACCOUNTPASSWORDBODY</parameter>, and
/// log a status composed here naming <var>pStage</var> alone.</p>
/// <p><b>Not <method>OcuPilot.Api.Definitions.RenderBadBody</method>.</b> That path logs the
/// read's own <class>%Status</class> through <method>OcuPilot.Kernel.Fault.LogRaw</method>, and
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> folds the parser's exception -- which can
/// quote the document it failed on -- into that text. On this route the document is two passwords
/// (AD-35).</p>
ClassMethod RenderBodyRefusal(pStage As %String) As %Status [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw("account", "password change body refused", $$$ERROR($$$GeneralError, "the password-change body was refused at the " _ pStage _ " stage"), ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDBODY)
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDBODY, ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDBODY)
}

/// <p>Map a refused change onto one violation, or onto a 500.</p>
/// <p>The wrong-old-password arm is tested first and is the only one that can answer on
/// <code>currentPassword</code>; a code outside both allow-lists renders
/// <method>OcuPilot.Api.Error.RenderInternal</method>'s generic reason, with <var>pStatus</var>
/// reaching <class>OcuPilot.Kernel.Audit.Log</class> alone (AD-39).</p>
ClassMethod RenderChangeRefusal(pStatus As %Status) As %Status [ Private ]
{
    Set tCodes = $System.Status.GetErrorCodes(pStatus)
    If ("," _ tCodes _ ",") [ ("," _ ..#WRONGPASSWORDCODE _ ",") {
        Set tViolations = 1
        Set tViolations(1) = $ListBuild("currentPassword", ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDCURRENT, "")
        Quit ..RenderViolations(.tViolations)
    }
    Set tPolicyText = ..PolicyText(pStatus, tCodes, .tIsPolicy)
    If tIsPolicy {
        Set tViolations = 1
        Set tViolations(1) = $ListBuild("newPassword", ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDPOLICY, tPolicyText)
        Quit ..RenderViolations(.tViolations)
    }
    Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pStatus))
}

/// <p>The instance's own sentence for the first allow-listed policy code in <var>pCodes</var>, and
/// <var>pMatched</var> 1 when one was named at all.</p>
/// <p>The two answers are separate because a matched code whose text is empty is still a policy
/// refusal: the caller renders it with the published fallback sentence rather than as a 500.</p>
/// <p><var>pCodes</var> is <method>%SYSTEM.Status.GetErrorCodes</method>'s comma-separated list, so
/// the position of the allow-listed code is also its index into the status, and
/// <method>%SYSTEM.Status.GetOneStatusText</method> answers that one error's inner text -- the
/// instance's words, without the <code>ERROR #nnn:</code> prefix OcuPilot would otherwise render
/// to a person. Both are documented <code>%SYSTEM.Status</code> methods, so no vendor-internal
/// routine entry point is called to unwrap the embedded error.</p>
ClassMethod PolicyText(pStatus As %Status, pCodes As %String, Output pMatched As %Boolean) As %String [ Private ]
{
    Set pMatched = 0
    Set tText = ""
    For tI = 1:1:$Length(pCodes, ",") {
        Set tCode = $Piece(pCodes, ",", tI)
        If '$ListFind($ListFromString(..#POLICYCODES, ","), tCode) Continue
        Set pMatched = 1
        Set tText = $System.Status.GetOneStatusText(pStatus, tI)
        Quit
    }
    Quit tText
}

/// <p>Refuse with <b>one</b> 422 carrying <var>pViolations</var> as
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
/// <p>It serializes through <method>OcuPilot.Kernel.AgentRules.ViolationsJson</method>, the tree's
/// one violation serializer, rather than through
/// <method>OcuPilot.Api.Definitions.RenderViolations</method>, which fixes the envelope's code at
/// <parameter>OcuPilot.Api.Error.AGENTVALIDATION</parameter>; this route's is
/// <parameter>OcuPilot.Api.Error.ACCOUNTVALIDATION</parameter>.</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONACCOUNTVALIDATION, ##class(OcuPilot.Api.Error).#ACCOUNTVALIDATION, tDetail)
}

}
