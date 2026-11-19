/// <p>The locale definitions' codes and sentences (AD-29, AD-39, Story 21.14): every <code>LOCALE.*</code> code
/// <class>OcuPilot.Port.LocalePort</class> and <class>OcuPilot.Area.OsMgmt.LocaleRules</class> answer with, and the one sentence each
/// carries. Each sentence is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key. They live beside <class>OcuPilot.Api.Error</class> rather than in it because that class
/// holds the compiler's limit of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through <method>ReasonFor</method>.</p>
/// <p><parameter>INSTALL</parameter>, <parameter>DELETE</parameter>, <parameter>LOAD</parameter> and <parameter>IMPORT</parameter> are not
/// refusals: they are the consequence codes the proposal card and the dialog of an install, a delete, a table load and an import carry.</p>
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

/// <p>400: a new locale's name is not <code>y</code>, two lowercase letters or digits and the last character of the locale it copies.</p>
Parameter COPYNAME = "LOCALE.COPY.NAME";

Parameter REASONCOPYNAME = "A new locale's name is y, two lowercase letters or digits, and the last character of the locale it copies: w for Unicode or 8 for 8-bit.";

/// <p>409: a copy names a locale the instance already lists.</p>
Parameter COPYTAKEN = "LOCALE.COPY.TAKEN";

Parameter REASONCOPYTAKEN = "A locale with that name already exists.";

/// <p>409: a change names a locale InterSystems ships.</p>
Parameter EDITSYSTEM = "LOCALE.EDIT.SYSTEM";

Parameter REASONEDITSYSTEM = "A locale InterSystems ships cannot be changed; copy it to a custom locale and change the copy.";

/// <p>409: a change names the instance's current locale.</p>
Parameter EDITCURRENT = "LOCALE.EDIT.CURRENT";

Parameter REASONEDITCURRENT = "The current locale cannot be changed; copy it, change the copy, and install it.";

/// <p>409: an added table is not one this instance holds for the locale's character set.</p>
Parameter TABLEUNAVAILABLE = "LOCALE.TABLE.UNAVAILABLE";

Parameter REASONTABLEUNAVAILABLE = "This instance holds no such table for this locale's character set.";

/// <p>409: an added table is one the locale already lists.</p>
Parameter TABLETAKEN = "LOCALE.TABLE.TAKEN";

Parameter REASONTABLETAKEN = "This locale already lists that table.";

/// <p>409: a removed table is a default of the locale.</p>
Parameter TABLEDEFAULT = "LOCALE.TABLE.DEFAULT";

Parameter REASONTABLEDEFAULT = "This table is a default of this locale; choose another default first.";

/// <p>409: a removal names a row that is not a table.</p>
Parameter TABLEROW = "LOCALE.TABLE.ROW";

Parameter REASONTABLEROW = "Only a table row can be removed.";

/// <p>409: a load names a row that is not a table the locale lists and the instance can load.</p>
Parameter TABLENOTLOADABLE = "LOCALE.TABLE.NOTLOADABLE";

Parameter REASONTABLENOTLOADABLE = "Only a table this locale lists that is not built in can be loaded.";

/// <p>The consequence code a table load's proposal card carries.</p>
Parameter LOAD = "LOCALE.LOAD";

Parameter REASONLOAD = "Loading makes this table available to every process on this instance until the next restart; on the current locale it can also change the instance's defaults.";

/// <p>409: an import file is not a locale or table export: it holds a document type declaration, is not well-formed, or holds no
/// locale, table or subtable record.</p>
Parameter IMPORTSHAPE = "LOCALE.IMPORT.SHAPE";

Parameter REASONIMPORTSHAPE = "This file is not a locale or table export.";

/// <p>409: an import file holds no custom record: every record's name is one InterSystems ships.</p>
Parameter IMPORTEMPTY = "LOCALE.IMPORT.EMPTY";

Parameter REASONIMPORTEMPTY = "This file holds no custom locale or table to import.";

/// <p>409: an import file would replace the current locale or a table it loads.</p>
Parameter IMPORTCURRENT = "LOCALE.IMPORT.CURRENT";

Parameter REASONIMPORTCURRENT = "This file would replace the current locale or a table it loads, so it cannot be imported.";

/// <p>409: the file, or the records it would replace, changed after the import was reviewed.</p>
Parameter IMPORTCHANGED = "LOCALE.IMPORT.CHANGED";

Parameter REASONIMPORTCHANGED = "The file or the locales changed after the import was reviewed, so nothing was imported. Review the import again.";

/// <p>409: an import file, or a locale exported to this browser, holds more characters than a locale file may.</p>
Parameter TOOLARGE = "LOCALE.TOOLARGE";

Parameter REASONTOOLARGE = "A locale file holds at most 3,000,000 characters, and this one holds more.";

/// <p>The consequence code an import's proposal card carries.</p>
Parameter IMPORT = "LOCALE.IMPORT";

Parameter REASONIMPORT = "Importing replaces any custom locale or table with the same name. This cannot be undone.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#IMPORTSHAPE Quit ..#REASONIMPORTSHAPE
    If pCode = ..#IMPORTEMPTY Quit ..#REASONIMPORTEMPTY
    If pCode = ..#IMPORTCURRENT Quit ..#REASONIMPORTCURRENT
    If pCode = ..#IMPORTCHANGED Quit ..#REASONIMPORTCHANGED
    If pCode = ..#TOOLARGE Quit ..#REASONTOOLARGE
    If pCode = ..#IMPORT Quit ..#REASONIMPORT
    If pCode = ..#NOTFOUND Quit ..#REASONNOTFOUND
    If pCode = ..#NOTINSTALLABLE Quit ..#REASONNOTINSTALLABLE
    If pCode = ..#SYSTEM Quit ..#REASONSYSTEM
    If pCode = ..#CURRENT Quit ..#REASONCURRENT
    If pCode = ..#INSTALL Quit ..#REASONINSTALL
    If pCode = ..#DELETE Quit ..#REASONDELETE
    If pCode = ..#COPYNAME Quit ..#REASONCOPYNAME
    If pCode = ..#COPYTAKEN Quit ..#REASONCOPYTAKEN
    If pCode = ..#EDITSYSTEM Quit ..#REASONEDITSYSTEM
    If pCode = ..#EDITCURRENT Quit ..#REASONEDITCURRENT
    If pCode = ..#TABLEUNAVAILABLE Quit ..#REASONTABLEUNAVAILABLE
    If pCode = ..#TABLETAKEN Quit ..#REASONTABLETAKEN
    If pCode = ..#TABLEDEFAULT Quit ..#REASONTABLEDEFAULT
    If pCode = ..#TABLEROW Quit ..#REASONTABLEROW
    If pCode = ..#TABLENOTLOADABLE Quit ..#REASONTABLENOTLOADABLE
    If pCode = ..#LOAD Quit ..#REASONLOAD
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 400, 404 or 409, and 0 for a code that is no refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If pCode = ..#NOTFOUND Quit 404
    If pCode = ..#COPYNAME Quit 400
    If (pCode = ..#NOTINSTALLABLE) || (pCode = ..#SYSTEM) || (pCode = ..#CURRENT) || (pCode = ..#COPYTAKEN) || (pCode = ..#EDITSYSTEM) || (pCode = ..#EDITCURRENT) Quit 409
    If (pCode = ..#TABLEUNAVAILABLE) || (pCode = ..#TABLETAKEN) || (pCode = ..#TABLEDEFAULT) || (pCode = ..#TABLEROW) || (pCode = ..#TABLENOTLOADABLE) Quit 409
    If (pCode = ..#IMPORTSHAPE) || (pCode = ..#IMPORTEMPTY) || (pCode = ..#IMPORTCURRENT) || (pCode = ..#IMPORTCHANGED) || (pCode = ..#TOOLARGE) Quit 409
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    If ..HttpStatusFor(pCode) = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    If ..HttpStatusFor(pCode) = 400 Quit ##class(OcuPilot.Api.Error).#BADREQUEST
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

}
