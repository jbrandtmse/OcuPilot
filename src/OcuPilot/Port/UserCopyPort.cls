/// <p>The user copy's port (AD-27 named case, AD-52, Story 18.29): <class>OcuPilot.Port.AdminPort</class>
/// with one write carried out through <code>Security.Users.Copy</code> in <code>%SYS</code>, the
/// documented class the classic user page's Copy calls. The admin API has no route that copies a user.
/// Every other request is the admin port's own, unchanged.</p>
/// <p><b>Why a port.</b> Measured on <code>ocupilot-ci</code> (2026-10-08): the copy carries the source's
/// roles, escalation roles, settings and SQL privileges, and it answers #822 without
/// <code>%Admin_Secure</code>. The port therefore gates on the caller's own <code>%Admin_Secure:USE</code>
/// and adds no privilege. A copy always takes the password the caller supplies, never the source's hash.</p>
/// <p><b>Order of a copy</b> (<method>Copy</method>): the gate; the body's shape; the instance's password
/// verdict; the source read (absent, directory-service and delegated accounts are refused as
/// <code>USERCOPY.SOURCE</code>, and a read that fails otherwise is a fault); the source's roles and escalation roles, compared with the payload's as
/// sets without regard to case (<code>USERCOPY.SOURCECHANGED</code>); and then the one vendor call.</p>
/// <p><b>Vendor refusals</b> (<method>MapVendorRefusal</method>): #837 is <code>USER.NAME.TAKEN</code> on
/// <code>Name</code>, #838 is <code>USERCOPY.SOURCE</code> on <code>CopyFrom</code>, and #845 and #958 are
/// <code>USER.PASSWORD.POLICY</code> on <code>Password</code>. None of those four is logged, and the
/// vendor's text is never sent. Any other refusal is a logged 500.</p>
Class OcuPilot.Port.UserCopyPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint the copy is made on.</p>
Parameter USEREndpoint = "Security.User";

/// <p>The request type a copy is issued with (<code>OcuPilot.Screen.Tool.UserCopy.WRITETYPE</code>).</p>
Parameter COPYTYPE = "COPY";

/// <p>The vendor <code>Flags</code> bits of a directory-service (LDAP) account and of a delegated account
/// (<code>%sySecurity.inc</code>'s <code>LDAPUser</code> and <code>DelegatedUser</code>). The classic user
/// list does not offer either to copy.</p>
Parameter LDAPFLAG = 2;

/// <p>The delegated account's <code>Flags</code> bit (<parameter>LDAPFLAG</parameter> gives the source).</p>
Parameter DELEGATEDFLAG = 4;

/// <p>The pair set a copy requires, as <code>resource:permission</code>. Each resource is answered through
/// <method>HoldsResource</method>, the seam <method>Copy</method> evaluates it through (AD-29).</p>
Parameter PAIRS = "%Admin_Secure:USE";

/// <p>The admin port's call, except that <code>Security.User</code> <code>COPY</code> is the copy above.
/// <var>pBody</var> carries <code>CopyFrom</code>, <code>FullName</code>, <code>Roles</code>,
/// <code>EscalationRoles</code> and <code>Password</code>; the name is the query's <code>name</code>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s,
/// and <var>pQuery</var> is not modified.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint '= ..#USEREndpoint) || (pType '= ..#COPYTYPE) {
        Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    }
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Quit ..Copy($Get(pQuery("name")), pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Copy the source named in <var>pBody</var> to a new account <var>pName</var>, as the guarded sequence
/// the class description gives. On success <var>pResult</var> is the new account as the admin API reads it
/// (<method>AccountOf</method>) and <var>pHttpStatus</var> 200; the caller still runs its own read-back (AD-58).
/// A source read that fails for any reason but the account's absence is a fault, not a refusal of the source.</p>
ClassMethod Copy(pName As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If '..HoldsPairs() {
            Set tSC = ..Fail(..#USEREndpoint, 403, $$$OK, .pHttpStatus, .pFault)
            Quit
        }
        If '$IsObject(pBody) || (pBody.%GetTypeOf("CopyFrom") '= "string") || (pBody.%Get("CopyFrom") = "") || (pName = "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "A copy names the account to copy from and the new account's name", .pHttpStatus, .pFault)
            Quit
        }
        Set tFrom = pBody.%Get("CopyFrom")
        Set tFullName = $Select(pBody.%GetTypeOf("FullName") = "string": pBody.%Get("FullName"), 1: "")
        Set tPassword = $Select(pBody.%GetTypeOf("Password") = "string": pBody.%Get("Password"), 1: "")

        ; AD-35: the password verdict before the source is read or the vendor is called.
        Set tReason = ""
        If '##class(OcuPilot.Kernel.PasswordPolicy).Verdict(tPassword, pName, .tReason) {
            Set tSC = ..PolicyRefusal(tReason, .pHttpStatus, .pFault)
            Quit
        }

        Set tSource = ..SourceOf(tFrom, .tSourceHttp, .tSourceFault, .tSourceSC)
        If '$IsObject(tSource) {
            If tSourceHttp = 404 {
                Set tSC = ..SourceRefusal(.pHttpStatus, .pFault)
            } ElseIf $IsObject(tSourceFault) {
                ; AD-36: only the vendor's 404 is an absence. The admin read answered, and logged, its own fault.
                Set pHttpStatus = tSourceHttp
                Set pFault = tSourceFault
                Set tSC = tSourceSC
            } Else {
                Set tSC = ..Fail(..#USEREndpoint, 500, tSourceSC, .pHttpStatus, .pFault)
            }
            Quit
        }
        If ..Unsupported(tSource) {
            Set tSC = ..SourceRefusal(.pHttpStatus, .pFault)
            Quit
        }

        ; The source's roles are the payload's as the reviewed proposal named them, read again at the write.
        If '..SameNames(pBody.%Get("Roles"), tSource.%Get("Roles")) || '..SameNames(pBody.%Get("EscalationRoles"), tSource.%Get("EscalationRoles")) {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.UserCopyError).#SOURCECHANGED, ##class(OcuPilot.Api.UserCopyError).#REASONSOURCECHANGED, .pHttpStatus, .pFault)
            Quit
        }

        Set tCopySC = ..VendorCopy(tFrom, pName, tFullName, tPassword)
        If $$$ISOK(tCopySC) {
            Set pResult = ..AccountOf(pName)
            Set pHttpStatus = 200
            Quit
        }
        Set tSC = ..MapVendorRefusal(tCopySC, tFrom, pName, pBody, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        ; AD-35: logged through Fail with the body, so the status text is screened for the password.
        Set tSC = ..Fail(..#USEREndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault, "", pBody)
    }
    Quit tSC
}

/// <p>Whether the source <var>pSource</var> (<method>SourceOf</method>'s read) is a directory-service or
/// delegated account, which the classic user list does not offer to copy.</p>
ClassMethod Unsupported(pSource As %DynamicObject) As %Boolean
{
    If '$IsObject(pSource) Quit 1
    Set tFlags = +pSource.%Get("Flags")
    Quit $ZBoolean(tFlags, ..#LDAPFLAG, 1) || $ZBoolean(tFlags, ..#DELEGATEDFLAG, 1)
}

/// <p>Whether the caller holds every pair <parameter>PAIRS</parameter> names, each through
/// <method>HoldsResource</method>; false when the set is empty, so a mis-edited parameter fails closed.</p>
ClassMethod HoldsPairs() As %Boolean
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#PAIRS)
    Set tHeld = $ListLength(tPairs) > 0
    For tI = 1:1:$ListLength(tPairs) {
        If '..HoldsResource($List($List(tPairs, tI), 1)) Set tHeld = 0 Quit
    }
    Quit tHeld
}

/// <p>The account <var>pName</var> as the admin API reads it now, which carries no password; an empty object when
/// the read fails.</p>
ClassMethod AccountOf(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#USEREndpoint, "GET", .tQuery, "", .tAccount, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject(tAccount) Quit {}
    Quit tAccount
}

/// <p>The vendor's copy, in <code>%SYS</code> by AD-16's explicit save and restore. <var>pPassword</var>
/// is the caller's own, never the source's.</p>
ClassMethod VendorCopy(pFrom As %String, pName As %String, pFullName As %String, pPassword As %String) As %Status [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Copy(pFrom, pName, pFullName, 1, 1, pPassword)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The source account's admin read with its <code>Flags</code> from <code>Security.Users.Get</code> in
/// <code>%SYS</code>, or <code>""</code> when it cannot be read. <var>pHttp</var> is 404 for an absent account
/// and the failing status otherwise (500 when none was answered); <var>pFault</var> is the admin read's own
/// fault when that read failed, and <var>pSC</var> the failure's status.</p>
ClassMethod SourceOf(pFrom As %String, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pSC As %Status) As %DynamicObject
{
    Set pHttp = 0
    Set pFault = ""
    Set pSC = $$$OK
    Kill tQuery
    Set tQuery("name") = pFrom
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#USEREndpoint, "GET", .tQuery, "", .tRead, .pHttp, .pFault)
    If $$$ISERR(tSC) || '$IsObject(tRead) {
        Set pSC = $Select($$$ISERR(tSC): tSC, 1: $$$ERROR($$$GeneralError, "the source account's read answered no account"))
        If +pHttp < 400 Set pHttp = 500
        Quit ""
    }
    Set tOrigNS = $NAMESPACE
    Set tProps = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tGetSC = ##class(Security.Users).Get(pFrom, .tProps)
    } Catch ex {
        Set tGetSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISERR(tGetSC) {
        Set pHttp = 500
        Set pFault = ""
        Set pSC = tGetSC
        Quit ""
    }
    Do tRead.%Set("Flags", +$Get(tProps("Flags")), "number")
    Quit tRead
}

/// <p>The names in <var>pArray</var> as a <class>%List</class> of their upper-cased, distinct spellings:
/// an empty list for anything that is not an array.</p>
ClassMethod NamesOf(pArray As %DynamicAbstractObject) As %List
{
    Set tNames = ""
    If '$IsObject(pArray) || 'pArray.%IsA("%Library.DynamicArray") Quit tNames
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        If $IsObject(tValue) || (tValue = "") Continue
        Set tUpper = $ZConvert(tValue, "U")
        If '$ListFind(tNames, tUpper) Set tNames = tNames _ $ListBuild(tUpper)
    }
    Quit tNames
}

/// <p>Whether <var>pA</var> and <var>pB</var>, two name arrays, hold the same names as sets, without regard to
/// case.</p>
ClassMethod SameNames(pA As %DynamicAbstractObject, pB As %DynamicAbstractObject) As %Boolean
{
    Set tA = ..NamesOf(pA)
    Set tB = ..NamesOf(pB)
    If $ListLength(tA) '= $ListLength(tB) Quit 0
    Set tSame = 1
    For tI = 1:1:$ListLength(tA) {
        If '$ListFind(tB, $List(tA, tI)) Set tSame = 0 Quit
    }
    Quit tSame
}

/// <p>The 422 for a password the instance's policy refuses, on <code>Password</code>, unlogged.</p>
ClassMethod PolicyRefusal(pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..ViolationRefusal(##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY, "Password", pReason, .pHttpStatus, .pFault)
}

/// <p>The 422 for an absent or unsupported source, on <code>CopyFrom</code>, unlogged.</p>
ClassMethod SourceRefusal(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..ViolationRefusal(##class(OcuPilot.Api.UserCopyError).#SOURCE, "CopyFrom", ##class(OcuPilot.Api.UserCopyError).#REASONSOURCE, .pHttpStatus, .pFault)
}

/// <p>One 422 validation envelope naming <var>pField</var> with <var>pCode</var>; nothing is logged.</p>
ClassMethod ViolationRefusal(pCode As %String, pField As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", pReason, "string")
    Set tViolations = []
    Do tViolations.%Push(tViolation)
    Set tDetail = {}
    Do tDetail.%Set("violations", tViolations)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, pReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>Map a refused vendor copy to its own answer (<class>OcuPilot.Port.UserCopyPort</class> class
/// description). A code the port does not name is a logged 500 through <method>Fail</method>, which is given
/// the copy's body <var>pBody</var> so the logged text is screened for the password (AD-35).</p>
ClassMethod MapVendorRefusal(pVendorSC As %Status, pFrom As %String, pName As %String, pBody As %DynamicAbstractObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCodes = "," _ $System.Status.GetErrorCodes(pVendorSC) _ ","
    If tCodes [ (",837,") Quit ..ViolationRefusal(##class(OcuPilot.Api.Error).#USERNAMETAKEN, "Name", ##class(OcuPilot.Api.Error).#REASONUSERNAMETAKEN, .pHttpStatus, .pFault)
    If tCodes [ (",838,") Quit ..SourceRefusal(.pHttpStatus, .pFault)
    If (tCodes [ (",845,")) || (tCodes [ (",958,")) Quit ..PolicyRefusal(##class(OcuPilot.Api.Error).#REASONUSERPASSWORDPOLICY, .pHttpStatus, .pFault)
    Quit ..Fail(..#USEREndpoint, 500, pVendorSC, .pHttpStatus, .pFault, "", pBody)
}

/// <p><method>Invoke</method>'s copy as a script (AD-59): the vendor call with the password shown as
/// <code>&lt;Password&gt;</code>. Every other request is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint '= ..#USEREndpoint) || (pType '= ..#COPYTYPE) Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tFrom = ""
    Set tFull = ""
    If $IsObject(pBody) {
        Set tFrom = $Select(pBody.%GetTypeOf("CopyFrom") = "string": pBody.%Get("CopyFrom"), 1: "")
        Set tFull = $Select(pBody.%GetTypeOf("FullName") = "string": pBody.%Get("FullName"), 1: "")
    }
    Set tCall = "Set tSC = ##class(Security.Users).Copy(" _ ..Literal(tFrom) _ ", " _ ..Literal($Get(pQuery("name"))) _ ", " _ ..Literal(tFull) _ ", 1, 1, ""<Password>"")"
    Set tSteps = []
    Do tSteps.%Push(..ObjectScriptStep($ListBuild(tCall, "Do $System.Status.DisplayError(tSC)")))
    Quit tSteps
}

/// <p>The script step kind of <method>Snippet</method>'s copy: <code>objectscript</code>.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#USEREndpoint) && (pType = ..#COPYTYPE) Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

}
