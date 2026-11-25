/// <p>The configuration settings' codes and sentences (AD-29, AD-39, Stories 21.3 and 21.4): every
/// <code>CONFIG.*</code> code <class>OcuPilot.Port.ConfigPort</class> and
/// <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> answer with, and the one sentence each carries, and the
/// sentences a row's <code>Accepts</code> reads. Each sentence is published once in EXPERIENCE.md's Fixed strings and
/// pinned equal to its <file>ui/src/app/core/strings.ts</file> key. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000
/// parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through <method>ReasonFor</method>.</p>
/// <p><parameter>SETTINGRESTART</parameter>, <parameter>SETTINGPURGE</parameter>, <parameter>MAPPINGDELETE</parameter> and <parameter>NLSRELOAD</parameter> are not refusals: each is the consequence
/// code the proposal card, the dialog and the Save of a setting that takes effect only at the next restart, that purges the
/// cached queries when it changes, of a delete of a DDL mapping, or of a set of the locale-format switch, carry.</p>
Class OcuPilot.Api.ConfigError Extends %RegisteredObject
{

/// <p>404: the class holds no setting of that name, or the screen does not list it.</p>
Parameter SETTINGNOTFOUND = "CONFIG.SETTING.NOTFOUND";

Parameter REASONSETTINGNOTFOUND = "There is no setting with that name.";

/// <p>409: the setting is shown and never changed.</p>
Parameter SETTINGREADONLY = "CONFIG.SETTING.READONLY";

Parameter REASONSETTINGREADONLY = "This setting is shown here and never changed here.";

/// <p>400: the value is not one the setting accepts.</p>
Parameter SETTINGVALUE = "CONFIG.SETTING.VALUE";

Parameter REASONSETTINGVALUE = "This setting does not accept that value.";

/// <p>400: a Task Manager email subject or message holds a <code>#(field)#</code> the Task Manager does not substitute (Story 21.19). The sentence
/// is published with <code>&lt;fields&gt;</code>, which <method>ReasonFor</method> replaces with the Task Manager's own fields.</p>
Parameter SETTINGSUBSTITUTION = "CONFIG.SETTING.SUBSTITUTION";

Parameter REASONSETTINGSUBSTITUTION = "Use only these fields between #( and )#: <fields>.";

/// <p>The consequence code of a set of a setting that takes effect only at the next restart.</p>
Parameter SETTINGRESTART = "CONFIG.SETTING.RESTART";

Parameter REASONSETTINGRESTART = "Takes effect at the next restart.";

/// <p>The consequence code of a set of a setting whose change purges the cached queries of every namespace.</p>
Parameter SETTINGPURGE = "CONFIG.SETTING.PURGE";

Parameter REASONSETTINGPURGE = "Changing this setting purges the cached queries in every namespace.";

/// <p>409: a create names a user DDL mapping the instance already holds (Story 21.13).</p>
Parameter MAPPINGTAKEN = "CONFIG.MAPPING.TAKEN";

Parameter REASONMAPPINGTAKEN = "This instance already holds a user DDL mapping of that name.";

/// <p>400: a create names a DDL type the vendor's own limits or the characters the instance's pattern syntax uses rule out.</p>
Parameter MAPPINGNAME = "CONFIG.MAPPING.NAME";

Parameter REASONMAPPINGNAME = "A name is 1 to 64 characters, with no =, comma, *, ^, control character, or space at either end.";

/// <p>The consequence code of a delete of a DDL mapping.</p>
Parameter MAPPINGDELETE = "CONFIG.MAPPING.DELETE";

Parameter REASONMAPPINGDELETE = "DDL that names this type no longer maps it to this datatype.";

/// <p>The consequence code of a set of the locale-format switch, which reloads the current locale (Story 21.14).</p>
Parameter NLSRELOAD = "CONFIG.NLS.RELOAD";

Parameter REASONNLSRELOAD = "Changing this reloads the current locale, so new processes take its date, time and number formats.";

/// <p>409: the stop or the level after the stop of the runtime statistics collection is set while collection is off (Story 21.26).</p>
Parameter SQLSTATSNOSTOP = "CONFIG.SQLSTATS.NOSTOP";

Parameter REASONSQLSTATSNOSTOP = "Collection must be on before its stop can be set.";

/// <p>What a row's <code>Accepts</code> reads, one sentence per kind. <code>%1</code> and <code>%2</code> are replaced
/// by <method>Accepting</method>.</p>
Parameter ACCEPTSBOOLEAN = "0 (off) or 1 (on).";

Parameter ACCEPTSRANGE = "A whole number from %1 to %2.";

Parameter ACCEPTSMINIMUM = "A whole number of at least %1.";

Parameter ACCEPTSCHOICE = "One of %1.";

Parameter ACCEPTSTEXT = "Text of up to %1 characters.";

Parameter ACCEPTSBLOCKSIZES = "Block sizes from 4096, 8192, 16384, 32768 and 65536, separated by commas; 8192 is required.";

Parameter ACCEPTSREADONLY = "Shown here and never changed here.";

Parameter ACCEPTSDATATYPE = "A datatype class name, with its parameters in parentheses if it takes any, of up to 256 characters.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#SETTINGNOTFOUND Quit ..#REASONSETTINGNOTFOUND
    If pCode = ..#SETTINGREADONLY Quit ..#REASONSETTINGREADONLY
    If pCode = ..#SETTINGVALUE Quit ..#REASONSETTINGVALUE
    If pCode = ..#SETTINGSUBSTITUTION Quit ..SubstitutionReason()
    If pCode = ..#SETTINGRESTART Quit ..#REASONSETTINGRESTART
    If pCode = ..#SETTINGPURGE Quit ..#REASONSETTINGPURGE
    If pCode = ..#MAPPINGTAKEN Quit ..#REASONMAPPINGTAKEN
    If pCode = ..#MAPPINGNAME Quit ..#REASONMAPPINGNAME
    If pCode = ..#MAPPINGDELETE Quit ..#REASONMAPPINGDELETE
    If pCode = ..#NLSRELOAD Quit ..#REASONNLSRELOAD
    If pCode = ..#SQLSTATSNOSTOP Quit ..#REASONSQLSTATSNOSTOP
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 404, 409 or 400, and 0 for a code that is no refusal (a consequence code is none).</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If pCode = ..#SETTINGNOTFOUND Quit 404
    If pCode = ..#SETTINGREADONLY Quit 409
    If pCode = ..#MAPPINGTAKEN Quit 409
    If pCode = ..#SQLSTATSNOSTOP Quit 409
    If pCode = ..#SETTINGVALUE Quit 400
    If pCode = ..#SETTINGSUBSTITUTION Quit 400
    If pCode = ..#MAPPINGNAME Quit 400
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    Set tHttp = ..HttpStatusFor(pCode)
    If tHttp = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    If tHttp = 400 Quit ##class(OcuPilot.Api.Error).#BADREQUEST
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

/// <p><parameter>REASONSETTINGSUBSTITUTION</parameter> with <code>&lt;fields&gt;</code> replaced by the fields
/// <code>%SYS.Task.Config.SubstitutionFields()</code> lists, comma and space apart.</p>
ClassMethod SubstitutionReason() As %String
{
    Quit $Replace(..#REASONSETTINGSUBSTITUTION, "<fields>", $Replace(##class(%SYS.Task.Config).SubstitutionFields(), ",", ", "))
}

/// <p>The sentence <var>pTemplate</var> (one of the <code>ACCEPTS*</code> parameters) reads with <var>pFirst</var> in
/// place of <code>%1</code> and <var>pSecond</var> in place of <code>%2</code>.</p>
ClassMethod Accepting(pTemplate As %String, pFirst As %String = "", pSecond As %String = "") As %String
{
    Quit $Replace($Replace(pTemplate, "%1", pFirst), "%2", pSecond)
}

}
