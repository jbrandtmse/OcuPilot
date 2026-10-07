/// <p>The authentication options' rules (AD-39, AD-55, Story 18.8): the one rule set
/// <class>OcuPilot.Screen.Tool.AuthOptionsUpdate</class>'s mint, confirm and merge and
/// <class>OcuPilot.Area.Security.AuthOptionsSave</class>'s Save apply before any vendor call
/// (<method>Check</method>, <method>Problem</method>), and the form's read (<method>HandleForm</method>).</p>
/// <p><b>The rules are the instance's own, decided here so a refusal costs no vendor call</b>: the vendor
/// refuses Always try Delegated without Delegated, LDAP cache without LDAP, and two-factor SMS without an
/// SMTP server and a from address (500 #1460, #1438 and #1417, measured at Task 0), and it stores a
/// negative or fractional timeout. Every sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, from
/// <class>OcuPilot.Api.WebAuthError</class>.</p>
Class OcuPilot.Area.Security.AuthOptionsRules Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuthOptions";

/// <p>The tool whose port the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AuthOptionsUpdate";

/// <p>The fourteen method flags, each a JSON boolean.</p>
Parameter BOOLEANS = "AutheUnauthenticated,AutheOS,AutheOSDelegated,AutheOSLDAP,AutheCache,AutheDelegated,AutheAlwaysTryDelegated,AutheKB,AutheLDAP,AutheLDAPCache,AutheOAuth2,AutheLoginToken,AutheTwoFactorSMS,AutheTwoFactorPW";

/// <p>The two timeouts, each a whole number of seconds, 0 or more.</p>
Parameter TIMEOUTS = "LoginCookieTimeout,TwoFactorTimeout";

/// <p>The five text settings, each a JSON string.</p>
Parameter STRINGS = "SMTPServer,SMTPUsername,TwoFactorFrom,JWTIssuer,JWTSigAlg";

/// <p>Every rule over the settings <var>pBody</var> carries, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in <code>pViolations</code>: a
/// setting of the wrong kind is refused <code>PORT.FIELD.SHAPE</code> on its name, a timeout that is not
/// a whole number from 0 up, a signature algorithm outside the six and an issuer over 1,024 characters
/// each on its own field, and, with <var>pFull</var> 1, the three rules that read two settings together:
/// the flags Always try Delegated and LDAP cache need, and the SMTP server and from address two-factor SMS
/// needs. <var>pFull</var> is 1 over a complete body and 0 over the arguments of a call, which name only
/// the settings to change.</p>
ClassMethod Check(pBody As %DynamicObject, Output pViolations, pFull As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pBody) Quit
        Set tBooleans = $ListFromString(..#BOOLEANS)
        For tI = 1:1:$ListLength(tBooleans) {
            Set tName = $List(tBooleans, tI)
            If (pBody.%GetTypeOf(tName) '= "unassigned") && (pBody.%GetTypeOf(tName) '= "boolean") Do ..Add(.pViolations, tName, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        Set tTimeouts = $ListFromString(..#TIMEOUTS)
        For tI = 1:1:$ListLength(tTimeouts) {
            Set tName = $List(tTimeouts, tI)
            If (pBody.%GetTypeOf(tName) '= "unassigned") && '..IsWholeNumber(pBody, tName) Do ..Add(.pViolations, tName, $Select(tName = "LoginCookieTimeout": ##class(OcuPilot.Api.WebAuthError).#COOKIETIMEOUT, 1: ##class(OcuPilot.Api.WebAuthError).#TWOFACTORTIMEOUT))
        }
        Set tStrings = $ListFromString(..#STRINGS)
        For tI = 1:1:$ListLength(tStrings) {
            Set tName = $List(tStrings, tI)
            If (pBody.%GetTypeOf(tName) '= "unassigned") && (pBody.%GetTypeOf(tName) '= "string") Do ..Add(.pViolations, tName, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        If pBody.%GetTypeOf("JWTSigAlg") = "string" {
            If '$ListFind($ListFromString(##class(OcuPilot.Api.WebAuthError).#SIGALGS), pBody.%Get("JWTSigAlg")) Do ..Add(.pViolations, "JWTSigAlg", ##class(OcuPilot.Api.WebAuthError).#JWTSIGALG)
        }
        If (pBody.%GetTypeOf("JWTIssuer") = "string") && ($Length(pBody.%Get("JWTIssuer")) > ##class(OcuPilot.Api.WebAuthError).#ISSUERMAX) Do ..Add(.pViolations, "JWTIssuer", ##class(OcuPilot.Api.WebAuthError).#JWTISSUER)
        If 'pFull Quit
        If ..On(pBody, "AutheAlwaysTryDelegated") && '..On(pBody, "AutheDelegated") Do ..Add(.pViolations, "AutheAlwaysTryDelegated", ##class(OcuPilot.Api.WebAuthError).#DELEGATED)
        If ..On(pBody, "AutheLDAPCache") && '..On(pBody, "AutheLDAP") && '..On(pBody, "AutheOSLDAP") Do ..Add(.pViolations, "AutheLDAPCache", ##class(OcuPilot.Api.WebAuthError).#LDAPCACHE)
        If ..On(pBody, "AutheTwoFactorSMS") {
            If ..Text(pBody, "SMTPServer") = "" Do ..Add(.pViolations, "SMTPServer", ##class(OcuPilot.Api.WebAuthError).#SMSSERVER)
            If ..Text(pBody, "TwoFactorFrom") = "" Do ..Add(.pViolations, "TwoFactorFrom", ##class(OcuPilot.Api.WebAuthError).#SMSFROM)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><method>Check</method> as one problem sentence naming each field and its published sentence, or
/// <code>""</code>, in <var>pProblem</var>: what the tool's <code>ArgumentProblem</code> and
/// <code>MergeUpdate</code> answer.</p>
ClassMethod Problem(pBody As %DynamicObject, Output pProblem As %String, pFull As %Boolean = 1) As %Status
{
    Set pProblem = ""
    Set tSC = ..Check(pBody, .tViolations, pFull)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Render <var>pViolations</var> as one 422 <parameter>OcuPilot.Api.WebAuthError.VALIDATION</parameter>
/// envelope carrying every broken rule in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.WebAuthError).#REASONVALIDATION, ##class(OcuPilot.Api.WebAuthError).#VALIDATION, tDetail)
}

/// <p>Answer <code>GET /authentication-options/form</code>: <code>{locked, sigAlgs}</code>, where
/// <code>locked</code> is one <code>{field, code, reason}</code> for each flag whose turning off alone
/// would be refused <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTSIGNIN</parameter> on this
/// instance now (<method>OcuPilot.Kernel.Proposal.Prohibited.SignInLocks</method>, read through the update
/// tool's own port) and <code>sigAlgs</code> the signature algorithms the instance offers.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).SignInLocks($ClassMethod(..#UPDATETOOL, "PortClass"), .tFields)
        If $$$ISERR(tReadSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            Quit
        }
        Set tCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTSIGNIN
        Set tLocked = []
        Set tIterator = tFields.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            Do tLocked.%Push({"field": (tField), "code": (tCode), "reason": (##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))})
        }
        Set tAlgs = $ListFromString(##class(OcuPilot.Api.WebAuthError).#SIGALGS)
        Set tBody = {}
        Do tBody.%Set("locked", tLocked)
        Set tOptions = []
        For tI = 1:1:$ListLength(tAlgs) Do tOptions.%Push($List(tAlgs, tI))
        Do tBody.%Set("sigAlgs", tOptions)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Refuse a caller who does not hold the screen's declared pairs (AD-8): <var>pRefused</var> 1 means
/// the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Whether <var>pBody</var>'s <var>pName</var> is a JSON number holding a whole number from 0 up.</p>
ClassMethod IsWholeNumber(pBody As %DynamicObject, pName As %String) As %Boolean [ Private ]
{
    If pBody.%GetTypeOf(pName) '= "number" Quit 0
    Set tValue = pBody.%Get(pName)
    If '$IsValidNum(tValue) Quit 0
    If +tValue '= (tValue \ 1) Quit 0
    Quit (+tValue >= 0)
}

/// <p>Whether <var>pBody</var> carries <var>pName</var> as the JSON boolean true.</p>
ClassMethod On(pBody As %DynamicObject, pName As %String) As %Boolean [ Private ]
{
    If pBody.%GetTypeOf(pName) '= "boolean" Quit 0
    Quit ''pBody.%Get(pName)
}

/// <p><var>pBody</var>'s <var>pName</var> as text, <code>""</code> when it carries no string.</p>
ClassMethod Text(pBody As %DynamicObject, pName As %String) As %String [ Private ]
{
    If pBody.%GetTypeOf(pName) '= "string" Quit ""
    Quit pBody.%Get(pName)
}

/// <p>Append one violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
