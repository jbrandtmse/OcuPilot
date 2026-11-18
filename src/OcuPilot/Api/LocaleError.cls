/// <p>The locale definitions' codes and sentences (AD-29, AD-39, Story 21.14): every <code>LOCALE.*</code> code
/// <class>OcuPilot.Port.LocalePort</class> and <class>OcuPilot.Area.OsMgmt.LocaleRules</class> answer with, and the one sentence each
/// carries. Each sentence is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key. They live beside <class>OcuPilot.Api.Error</class> rather than in it because that class
/// holds the compiler's limit of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through <method>ReasonFor</method>.</p>
/// <p><parameter>INSTALL</parameter> and <parameter>DELETE</parameter> are not refusals: they are the consequence codes the proposal card
/// and the dialog of an install and of a delete carry.</p>
Class OcuPilot.Api.LocaleError Extends %RegisteredObject
{

/// <p>404: the instance lists no locale of that name.</p>
Parameter NOTFOUND = "LOCALE.NOTFOUND";

Parameter REASONNOTFOUND = "There is no locale with that name.";

/// <p>409: the vendor's own check refuses to install the locale.</p>
Parameter NOTINSTALLABLE = "LOCALE.NOTINSTALLABLE";

Parameter REASONNOTINSTALLABLE = "This locale cannot be installed on this instance.";

/// <p>409: a delete names a locale InterSystems ships, whose name does not start with <code>y</code>.</p>
Parameter SYSTEM = "LOCALE.SYSTEM";

Parameter REASONSYSTEM = "A locale InterSystems ships cannot be deleted; only a custom locale, whose name starts with y, can.";

/// <p>409: a delete names the instance's current locale.</p>
Parameter CURRENT = "LOCALE.CURRENT";

Parameter REASONCURRENT = "The current locale cannot be deleted.";

/// <p>The consequence code an install's proposal card carries.</p>
Parameter INSTALL = "LOCALE.INSTALL";

Parameter REASONINSTALL = "Installing makes this locale the instance's current locale, purges every cached query, and can change IRISTEMP's default collation.";

/// <p>The consequence code a delete's proposal card carries.</p>
Parameter DELETE = "LOCALE.DELETE";

Parameter REASONDELETE = "The locale and its definition are removed from this instance.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NOTFOUND Quit ..#REASONNOTFOUND
    If pCode = ..#NOTINSTALLABLE Quit ..#REASONNOTINSTALLABLE
    If pCode = ..#SYSTEM Quit ..#REASONSYSTEM
    If pCode = ..#CURRENT Quit ..#REASONCURRENT
    If pCode = ..#INSTALL Quit ..#REASONINSTALL
    If pCode = ..#DELETE Quit ..#REASONDELETE
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 404 or 409, and 0 for a code that is no refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If pCode = ..#NOTFOUND Quit 404
    If (pCode = ..#NOTINSTALLABLE) || (pCode = ..#SYSTEM) || (pCode = ..#CURRENT) Quit 409
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    If ..HttpStatusFor(pCode) = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

}
