/// <p>The key-file rules (AD-55, Story 18.7) both callers answer before any vendor call: the key
/// length, the administrator names and the passwords, each violation named by its argument.
/// <class>OcuPilot.Port.EncryptionPort</class> asks them at the write, the key-file tools'
/// <code>ArgumentProblem</code> at the mint over the arguments the agent may supply, and
/// <class>OcuPilot.Area.Security.EncryptionKeyFileSave</class> before its write.</p>
/// <p>Measured at Story 18.7's Task 0: the vendor refuses a key length other than 128, 192 or 256, an
/// empty name or password, and a password under three characters, and it accepts names of thousands
/// of characters and descriptions of any length; the classic pages cap a name at 50, which these rules
/// keep. A description is free text and has no rule.</p>
Class OcuPilot.Area.Security.EncryptionRules Extends %RegisteredObject
{

/// <p>The longest administrator name, the classic create page's <code>maxlength</code>.</p>
Parameter NAMEMAXLENGTH As INTEGER = 50;

/// <p>The shortest password the vendor accepts (#1209, measured).</p>
Parameter PASSWORDMINLENGTH As INTEGER = 3;

/// <p>The key lengths, in bits.</p>
Parameter KEYLENGTHS = "128,192,256";

/// <p>The name and password arguments, comma-separated.</p>
Parameter NAMEFIELDS = "AdminName,OldAdminName,NewAdminName";

Parameter PASSWORDFIELDS = "AdminPassword,OldAdminPassword,NewAdminPassword";

Parameter KEYLENFIELD = "KeyLen";

/// <p>Add to <var>pViolations</var> (<code>pViolations(n) = $ListBuild(field, code)</code>, count in
/// <code>pViolations</code>) one violation for each field of <var>pFields</var> that
/// <var>pValues</var> breaks a rule on; a field the values do not carry is empty.</p>
ClassMethod Violations(pValues As %DynamicObject, pFields As %List, ByRef pViolations)
{
    Set pViolations = +$Get(pViolations)
    For tI = 1:1:$ListLength(pFields) {
        Set tField = $List(pFields, tI)
        Set tCode = ..FieldCode(tField, ..Value(pValues, tField))
        If tCode '= "" Set pViolations($Increment(pViolations)) = $ListBuild(tField, tCode)
    }
}

/// <p>The code <var>pValue</var> breaks as field <var>pField</var>, or <code>""</code>.</p>
ClassMethod FieldCode(pField As %String, pValue As %String) As %String
{
    If pField = ..#KEYLENFIELD {
        If '$ListFind($ListFromString(..#KEYLENGTHS), pValue) Quit ##class(OcuPilot.Api.EncryptionError).#KEYFILEKEYLEN
        Quit ""
    }
    If $ListFind($ListFromString(..#NAMEFIELDS), pField) {
        If ($ZStrip(pValue, "<>W") = "") || ($Length(pValue) > ..#NAMEMAXLENGTH) || ..Wide(pValue) Quit ##class(OcuPilot.Api.EncryptionError).#KEYFILEADMINNAME
        Quit ""
    }
    If $ListFind($ListFromString(..#PASSWORDFIELDS), pField) {
        If ($Length(pValue) < ..#PASSWORDMINLENGTH) || ..Wide(pValue) Quit ##class(OcuPilot.Api.EncryptionError).#KEYFILEPASSWORD
        Quit ""
    }
    Quit ""
}

/// <p>The first rule <var>pArgs</var> breaks over <var>pFields</var>, as one sentence naming its
/// argument, or <code>""</code>: a tool's <code>ArgumentProblem</code>.</p>
ClassMethod Problem(pArgs As %DynamicObject, pFields As %List) As %String
{
    Kill tViolations
    Do ..Violations(pArgs, pFields, .tViolations)
    If +$Get(tViolations) = 0 Quit ""
    Set tField = $List(tViolations(1), 1)
    Quit "'" _ tField _ "': " _ ##class(OcuPilot.Api.EncryptionError).ReasonFor($List(tViolations(1), 2))
}

/// <p><var>pValues</var>'s scalar <var>pField</var> as text, or <code>""</code>.</p>
ClassMethod Value(pValues As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pValues) || 'pValues.%IsA("%Library.DynamicObject") Quit ""
    Set tType = pValues.%GetTypeOf(pField)
    If (tType '= "string") && (tType '= "number") Quit ""
    Quit pValues.%Get(pField) _ ""
}

/// <p>Whether <var>pValue</var> holds a character above <code>$Char(255)</code>, which the vendor's
/// message #1211 says it refuses in a name or a password (inference: read in the message dictionary, not
/// measured).</p>
ClassMethod Wide(pValue As %String) As %Boolean
{
    Set tWide = 0
    For tI = 1:1:$Length(pValue) {
        If $Ascii(pValue, tI) > 255 Set tWide = 1 Quit
    }
    Quit tWide
}

/// <p>The 422 fault for <var>pViolations</var>: the envelope code
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILEVALIDATION</parameter> when there are several, the one
/// violation's own code otherwise, with <code>detail.violations</code> naming each.</p>
ClassMethod Fault(ByRef pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tRows = []
    For tI = 1:1:+$Get(pViolations) {
        Set tCode = $List(pViolations(tI), 2)
        Set tReason = ##class(OcuPilot.Api.EncryptionError).ReasonFor(tCode)
        If tReason = "" Set tReason = ##class(OcuPilot.Api.Error).ReasonForPath(tCode)
        Do tRows.%Push({"field": ($List(pViolations(tI), 1)), "code": (tCode), "reason": (tReason)})
    }
    Set tCode = $Select(+$Get(pViolations) = 1: $List(pViolations(1), 2), 1: ##class(OcuPilot.Api.EncryptionError).#KEYFILEVALIDATION)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tCode, ##class(OcuPilot.Api.EncryptionError).ReasonFor(tCode))
    Do pFault.%Set("detail", {"violations": (tRows)})
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Render <var>pViolations</var> as one 422
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILEVALIDATION</parameter> envelope.</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tRows = []
    For tI = 1:1:+$Get(pViolations) {
        Set tCode = $List(pViolations(tI), 2)
        Set tReason = ##class(OcuPilot.Api.EncryptionError).ReasonFor(tCode)
        If tReason = "" Set tReason = ##class(OcuPilot.Api.Error).ReasonForPath(tCode)
        Do tRows.%Push({"field": ($List(pViolations(tI), 1)), "code": (tCode), "reason": (tReason)})
    }
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.EncryptionError).#REASONKEYFILEVALIDATION, ##class(OcuPilot.Api.EncryptionError).#KEYFILEVALIDATION, {"violations": (tRows)})
}

}
