/// <p>The SQL object privileges' codes (AD-39, Story 18.9): every <code>SQLPRIV.*</code> code the Permissions
/// editors' SQL privileges tab, <code>permissions.sqlprivileges.read</code> and the four grant and revoke tools
/// answer, and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in
/// it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.SqlPrivilegeError Extends %RegisteredObject
{

/// <p>Envelope code: the privilege was refused on one or more of its fields, its
/// <code>detail.violations</code> naming each (422).</p>
Parameter VALIDATION = "SQLPRIV.VALIDATION";

Parameter REASONVALIDATION = "The privilege was refused.";

/// <p>Violation code, on <code>Namespace</code>, and the fault (404) a call naming no namespace, or one this
/// instance does not define, is refused with.</p>
Parameter NAMESPACE = "SQLPRIV.NAMESPACE";

Parameter REASONNAMESPACE = "The namespace must be one this instance defines.";

/// <p>Violation code, on <code>Name</code>, and the fault (400) a call naming no grantee is refused with.</p>
Parameter GRANTEE = "SQLPRIV.GRANTEE";

Parameter REASONGRANTEE = "The user or role is 1 to 160 characters, with no * and no comma.";

/// <p>Violation code, on <code>Type</code>.</p>
Parameter TYPE = "SQLPRIV.TYPE";

Parameter REASONTYPE = "The type is TABLE, VIEW, SCHEMA, STORED PROCEDURE, ML CONFIGURATION or FOREIGN SERVER.";

/// <p>Violation code, on <code>Object</code>.</p>
Parameter OBJECT = "SQLPRIV.OBJECT";

Parameter REASONOBJECT = "The object is one name for a schema or configuration, or schema.name for the rest, each part of letters, digits and _ @ # $.";

/// <p>Violation code, on <code>Action</code>.</p>
Parameter ACTION = "SQLPRIV.ACTION";

Parameter REASONACTION = "That action is not one this type takes.";

/// <p>Violation code, on <code>WithGrant</code>.</p>
Parameter WITHGRANT = "SQLPRIV.WITHGRANT";

Parameter REASONWITHGRANT = "With grant option is true or false.";

/// <p>Fault (400): a list or a wildcard, a <code>*</code> or a comma, in the grantee, object or action.</p>
Parameter LIST = "SQLPRIV.LIST";

Parameter REASONLIST = "A list or a wildcard is not accepted here: name one user or role, one object and one action.";

/// <p>Refusal (409): the grantee already holds the privilege with the grant option asked for or more. Nothing is
/// sent.</p>
Parameter HELD = "SQLPRIV.HELD";

Parameter REASONHELD = "The grantee already holds this privilege.";

/// <p>Refusal (409): the grantee holds no direct grant of the privilege, so there is nothing to revoke. Nothing is
/// sent.</p>
Parameter NOTHELD = "SQLPRIV.NOTHELD";

Parameter REASONNOTHELD = "The grantee holds no direct grant of this privilege, so there is nothing to revoke here.";

/// <p>Refusal (409): the grantee holds every privilege through %All, which the instance lists as a super-user
/// row only. Nothing is sent.</p>
Parameter SUPERUSER = "SQLPRIV.SUPERUSER";

Parameter REASONSUPERUSER = "The grantee holds every SQL privilege through %All, so a grant or revoke here shows nothing to change.";

/// <p>Refusal (409): the instance accepted the request and the grantee's privilege did not move.</p>
Parameter NOTAPPLIED = "SQLPRIV.NOTAPPLIED";

Parameter REASONNOTAPPLIED = "The instance accepted the request and the privilege did not change.";

/// <p>Refusal (403): the instance's grantor rule refused the request, because the caller does not hold the privilege
/// with the grant option.</p>
Parameter GRANTOR = "SQLPRIV.GRANTOR";

Parameter REASONGRANTOR = "Your account does not hold this privilege with the grant option, so it cannot grant or revoke it.";

/// <p>Refusal (404): the instance holds no such object of that type in the namespace.</p>
Parameter NOOBJECT = "SQLPRIV.NOOBJECT";

Parameter REASONNOOBJECT = "This namespace holds no such object of that type.";

/// <p>Refusal (404): the instance holds no such user or role.</p>
Parameter NOGRANTEE = "SQLPRIV.NOGRANTEE";

Parameter REASONNOGRANTEE = "This instance holds no such user or role.";

/// <p>The longest grantee the instance stores.</p>
Parameter GRANTEEMAX = 160;

/// <p>Every <code>SQLPRIV.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#NAMESPACE, ..#GRANTEE, ..#TYPE, ..#OBJECT, ..#ACTION, ..#WITHGRANT, ..#LIST, ..#HELD, ..#NOTHELD, ..#SUPERUSER, ..#NOTAPPLIED, ..#GRANTOR, ..#NOOBJECT, ..#NOGRANTEE)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAMESPACE, ..#GRANTEE, ..#TYPE, ..#OBJECT, ..#ACTION, ..#WITHGRANT)
}

/// <p>The argument a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If pCode = ..#NAMESPACE Quit "Namespace"
    If pCode = ..#GRANTEE Quit "Name"
    If pCode = ..#TYPE Quit "Type"
    If pCode = ..#OBJECT Quit "Object"
    If pCode = ..#ACTION Quit "Action"
    If pCode = ..#WITHGRANT Quit "WithGrant"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    If pCode = ..#GRANTEE Quit ..#REASONGRANTEE
    If pCode = ..#TYPE Quit ..#REASONTYPE
    If pCode = ..#OBJECT Quit ..#REASONOBJECT
    If pCode = ..#ACTION Quit ..#REASONACTION
    If pCode = ..#WITHGRANT Quit ..#REASONWITHGRANT
    If pCode = ..#LIST Quit ..#REASONLIST
    If pCode = ..#HELD Quit ..#REASONHELD
    If pCode = ..#NOTHELD Quit ..#REASONNOTHELD
    If pCode = ..#SUPERUSER Quit ..#REASONSUPERUSER
    If pCode = ..#NOTAPPLIED Quit ..#REASONNOTAPPLIED
    If pCode = ..#GRANTOR Quit ..#REASONGRANTOR
    If pCode = ..#NOOBJECT Quit ..#REASONNOOBJECT
    If pCode = ..#NOGRANTEE Quit ..#REASONNOGRANTEE
    Quit ""
}

}
