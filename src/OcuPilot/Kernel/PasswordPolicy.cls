/// <p>The instance's password policy as one verdict (AD-35, Story 18.29). Every administrator path that
/// sets a password asks <method>Verdict</method>: the user create rules, the set-password guard in
/// <class>OcuPilot.Port.AdminPort</class>, the user copy, and the password-check route.</p>
/// <p><b>The verdict is <code>$SYSTEM.Security.ValidatePassword</code>'s</b>, called in the caller's
/// process, so the instance's own pattern and validation routine decide. A refusal's reason is the
/// routine's first error text when that error is one of <parameter>POLICYCODES</parameter>; any other
/// refusal, an empty reason, or a reason that quotes the password is replaced by the published
/// sentence <class>OcuPilot.Api.Error</class>'s <parameter>USERPASSWORDPOLICY</parameter> carries.</p>
/// <p>The password is never logged, returned or stored by this class: it leaves only through the
/// boolean answer and the reason, and the reason never carries it (AD-35).</p>
Class OcuPilot.Kernel.PasswordPolicy Extends %RegisteredObject
{

/// <p>The validator's error codes whose own text is a sentence the user may read: 5001 is the
/// routine's refusal, 845 the pattern and length refusal and 958 the history refusal.</p>
Parameter POLICYCODES = "5001,845,958";

/// <p>Whether <var>pPassword</var> is acceptable for account <var>pUser</var> under the instance's
/// policy. <var>pReason</var> is <code>""</code> when it is, and otherwise the sentence the user sees.
/// An empty password is refused with the required sentence.</p>
ClassMethod Verdict(pPassword As %String, pUser As %String, Output pReason As %String) As %Boolean
{
    Set pReason = ""
    If pPassword = "" {
        Set pReason = ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDREQUIRED
        Quit 0
    }
    Set tSC = $System.Security.ValidatePassword(pPassword, pUser)
    If $$$ISOK(tSC) Quit 1
    Set tFirst = $Piece($System.Status.GetErrorCodes(tSC), ",", 1)
    If $ListFind($ListFromString(..#POLICYCODES, ","), tFirst) {
        Set pReason = $System.Status.GetOneStatusText(tSC, 1)
    }
    If (pReason = "") || ((pPassword '= "") && (pReason [ pPassword)) {
        Set pReason = ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDPOLICY
    }
    Set tSC = ""
    Quit 0
}

}
