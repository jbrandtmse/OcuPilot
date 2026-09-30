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
/// <code>$$$InvalidPasswordPattern</code>. The change's text for any other code is never rendered
/// (AD-39); a refusal the password validator confirms carries the validator's own text instead
/// (<method>ClassifyRefusal</method>).</p>
Parameter POLICYCODES = "845,958";

/// <p>The embedded code for an account the change could not find
/// (<code>$$$UserDoesNotExist</code>). A refusal carrying it is answered 500 without consulting the
/// password validator.</p>
Parameter NOSUCHUSERCODE = 838;

/// <p>The code a password validation routine's refusal carries, with the routine's own sentence as
/// its text (<code>$$$GeneralError</code>).</p>
Parameter ROUTINEREFUSALCODE = 5001;

/// <p>Answer <code>POST /account/password {"currentPassword","newPassword"}</code>: change the
/// calling user's own password and answer <code>200 {}</code>.</p>
/// <p>A body carrying anything but exactly those two string members is refused 422
/// <parameter>OcuPilot.Api.Error.ACCOUNTPASSWORDBODY</parameter> before the change is attempted, and
/// a body the server could not read or decode answers 500 <code>INTERNAL</code>. A refused change
/// is one 422 <parameter>OcuPilot.Api.Error.ACCOUNTVALIDATION</parameter> carrying one violation --
/// on <code>currentPassword</code> when the old password was wrong, on <code>newPassword</code> when
/// the instance's policy or its password validation routine refused the new one, with the
/// instance's own sentence as that violation's <code>reason</code>. Any other outcome is a 500
/// whose detail reaches the log alone (<method>ClassifyRefusal</method>).</p>
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
        ; The iterator holds its own reference to the parsed body, so dropping tRequestBody alone
        ; would not release the two values.
        Set tIterator = ""
        If tExtra || (tRequestBody.%GetTypeOf("currentPassword") '= "string") || (tRequestBody.%GetTypeOf("newPassword") '= "string") {
            Set tSC = ..RenderBodyRefusal("shape")
            Quit
        }

        Set tCurrent = tRequestBody.%Get("currentPassword")
        Set tNew = tRequestBody.%Get("newPassword")
        Set tRequestBody = ""
        Set tChanged = $System.Security.ChangePassword(..CallerUsername(), tNew, tCurrent, .tChangeSC)
        If tChanged {
            Set tCurrent = ""
            Set tNew = ""
            Set tSC = ##class(OcuPilot.Api.Response).JSON({})
            Quit
        }
        Set tHttpStatus = ..ClassifyRefusal($Get(tChangeSC, $$$OK), tCurrent, tNew, ..CallerUsername(), .tField, .tCode, .tReason, .tLogged)
        ; Cleared here rather than after the render: nothing below this line needs either value,
        ; and the renders can raise.
        Set tCurrent = ""
        Set tNew = ""
        Set tSC = ..RenderChangeRefusal(tHttpStatus, tField, tCode, tReason, tLogged)
    } Catch ex {
        Set tCurrent = ""
        Set tNew = ""
        Set tIgnored = ""
        Set tIterator = ""
        Set tRequestBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Set tCurrent = ""
    Set tNew = ""
    Set tIgnored = ""
    Set tIterator = ""
    Set tRequestBody = ""
    Quit tSC
}

/// <p>Refuse the body with 422 <parameter>OcuPilot.Api.Error.ACCOUNTPASSWORDBODY</parameter>, and
/// log a status composed here naming <var>pStage</var> alone. A <code>read</code> or
/// <code>decode</code> fault is the server's, not the client's, and answers 500
/// <code>INTERNAL</code> instead, with the same composed status as its logged detail.</p>
/// <p><b>Not <method>OcuPilot.Api.Definitions.RenderBadBody</method>.</b> That path logs the
/// read's own <class>%Status</class> through <method>OcuPilot.Kernel.Fault.LogRaw</method>, and
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> folds the parser's exception -- which can
/// quote the document it failed on -- into that text. On this route the document is two passwords
/// (AD-35).</p>
ClassMethod RenderBodyRefusal(pStage As %String) As %Status [ Private ]
{
    Set tLogged = $$$ERROR($$$GeneralError, "the password-change body was refused at the " _ pStage _ " stage")
    If (pStage = "read") || (pStage = "decode") {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tLogged))
    }
    Do ##class(OcuPilot.Kernel.Fault).LogRaw("account", "password change body refused", tLogged, ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDBODY)
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDBODY, ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDBODY)
}

/// <p>Classify the refused change <var>pStatus</var>: answer 422 with the one violation's
/// <var>pField</var>, <var>pCode</var> and <var>pReason</var> (<code>""</code> for the code's
/// published sentence), or 500 with <var>pLogged</var>, the status the log receives.</p>
/// <p>In order: a wrong current password is a violation on <code>currentPassword</code>; an
/// allow-listed policy code is one on <code>newPassword</code> carrying that code's own text; an
/// account the change could not find is a 500. Any other refusal is put to
/// <method>%SYSTEM.Security.ValidatePassword</method> for <var>pNew</var> and
/// <var>pUsername</var>, in the caller's process (AD-49): when it refuses -- its status carries
/// <parameter>ROUTINEREFUSALCODE</parameter> or a <parameter>POLICYCODES</parameter> code -- the
/// violation is on <code>newPassword</code> with the validator's first error text; when it answers
/// OK, or fails any other way (a routine that raises an error answers 5002, naming its own line),
/// the refusal is unconfirmed and stays a 500. The change's own text is never rendered.</p>
/// <p>Neither password leaves through the validator's text or the logged status: the first is
/// replaced by the published sentence when it is empty or contains <var>pCurrent</var> or
/// <var>pNew</var>, and a logged status whose text contains either is replaced by one naming the
/// codes alone (AD-35).</p>
ClassMethod ClassifyRefusal(pStatus As %Status, pCurrent As %String, pNew As %String, pUsername As %String, Output pField As %String, Output pCode As %String, Output pReason As %String, Output pLogged As %Status) As %Integer
{
    Set pField = ""
    Set pCode = ""
    Set pReason = ""
    Set pLogged = $$$OK
    Set tCodes = $System.Status.GetErrorCodes(pStatus)
    If ("," _ tCodes _ ",") [ ("," _ ..#WRONGPASSWORDCODE _ ",") {
        Set pField = "currentPassword"
        Set pCode = ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDCURRENT
        Quit 422
    }
    Set tPolicyText = ..PolicyText(pStatus, tCodes, .tIsPolicy)
    If tIsPolicy {
        Set pField = "newPassword"
        Set pCode = ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDPOLICY
        Set pReason = tPolicyText
        Quit 422
    }
    If '(("," _ tCodes _ ",") [ ("," _ ..#NOSUCHUSERCODE _ ",")) {
        Set tValidSC = $System.Security.ValidatePassword(pNew, pUsername)
        Set tValidCodes = "," _ $System.Status.GetErrorCodes(tValidSC) _ ","
        Set tRefusalCodes = ..#ROUTINEREFUSALCODE _ "," _ ..#POLICYCODES
        Set tRefused = 0
        For tI = 1:1:$Length(tRefusalCodes, ",") {
            If tValidCodes [ ("," _ $Piece(tRefusalCodes, ",", tI) _ ",") Set tRefused = 1
        }
        If tRefused {
            Set pField = "newPassword"
            Set pCode = ##class(OcuPilot.Api.Error).#ACCOUNTPASSWORDPOLICY
            Set pReason = $System.Status.GetOneStatusText(tValidSC, 1)
            Set tValidSC = ""
            If ..QuotesPassword(pReason, pCurrent, pNew) Set pReason = ""
            Quit 422
        }
    }
    Set pLogged = pStatus
    If ..QuotesPassword($System.Status.GetErrorText(pStatus), pCurrent, pNew) {
        Set pLogged = $$$ERROR($$$GeneralError, "the password change was refused with codes " _ tCodes)
    }
    Quit 500
}

/// <p>Whether <var>pText</var> contains <var>pCurrent</var> or <var>pNew</var>, ignoring either
/// when it is empty.</p>
ClassMethod QuotesPassword(pText As %String, pCurrent As %String, pNew As %String) As %Boolean [ Private ]
{
    If (pCurrent '= "") && (pText [ pCurrent) Quit 1
    If (pNew '= "") && (pText [ pNew) Quit 1
    Quit 0
}

/// <p>Render <method>ClassifyRefusal</method>'s answer: one violation for a 422, and otherwise
/// <method>OcuPilot.Api.Error.RenderInternal</method>'s generic reason, with <var>pLogged</var>
/// reaching <class>OcuPilot.Kernel.Audit.Log</class> alone (AD-39).</p>
ClassMethod RenderChangeRefusal(pHttpStatus As %Integer, pField As %String, pCode As %String, pReason As %String, pLogged As %Status) As %Status [ Private ]
{
    If pHttpStatus = 422 {
        Set tViolations = 1
        Set tViolations(1) = $ListBuild(pField, pCode, pReason)
        Quit ..RenderViolations(.tViolations)
    }
    Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pLogged))
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
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39). It
/// delegates to <method>OcuPilot.Api.Definitions.RenderViolations</method> with this route's code,
/// <parameter>OcuPilot.Api.Error.ACCOUNTVALIDATION</parameter>, and this route's reason.</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Definitions).RenderViolations(.pViolations, ##class(OcuPilot.Api.Error).#REASONACCOUNTVALIDATION, ##class(OcuPilot.Api.Error).#ACCOUNTVALIDATION)
}

}
