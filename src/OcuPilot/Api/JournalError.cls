/// <p>The journal screens' codes (AD-39, Story 18.5): every <code>JOURNAL.*</code> code a journal call
/// answers, and the one sentence each carries. They live beside <class>OcuPilot.Api.Error</class>
/// rather than in it because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through
/// <method>ReasonFor</method>, so every caller still asks the one writer.</p>
Class OcuPilot.Api.JournalError Extends %RegisteredObject
{

/// <p>Envelope code: a journal file named other than as the instance's own journal file list spells
/// it (AD-21's eighth case). Rendered on the <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug
/// with 404, by <class>OcuPilot.Port.AdminPort</class>, before the call for the file is made; no
/// refusal names the file.</p>
Parameter FILEUNLISTED = "JOURNAL.FILE.UNLISTED";

/// <p>The sentence <parameter>FILEUNLISTED</parameter> carries.</p>
Parameter REASONFILEUNLISTED = "This instance's journal file list does not name that file.";

/// <p>Envelope code: the instance has one journal directory, so a directory switch has nowhere to go
/// and the vendor switched nothing. Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter>
/// slug with 409, by <class>OcuPilot.Port.JournalPort</class>.</p>
Parameter SWITCHDIRNOOTHER = "JOURNAL.SWITCHDIR.NOOTHER";

/// <p>The sentence <parameter>SWITCHDIRNOOTHER</parameter> carries.</p>
Parameter REASONSWITCHDIRNOOTHER = "This instance has one journal directory. Set a different alternate directory in Journal settings first.";

/// <p>Envelope code: the vendor answered a directory switch as made, and the file it answers sits in
/// the directory journaling wrote in before the call, so nothing moved. Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409, by
/// <class>OcuPilot.Port.JournalPort</class>.</p>
Parameter SWITCHDIRUNMOVED = "JOURNAL.SWITCHDIR.UNMOVED";

/// <p>The sentence <parameter>SWITCHDIRUNMOVED</parameter> carries; <method>Unmoved</method> fills
/// <code>&lt;directory&gt;</code>.</p>
Parameter REASONSWITCHDIRUNMOVED = "The journal did not move to the other directory. It is still written in <directory>.";

/// <p>Envelope code: a journal settings write refused on one or more of its fields (Story 18.18).
/// Rendered on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422, its
/// <code>detail.violations</code> naming each field with a <code>JOURNAL.*</code> or a
/// <code>PATH.*</code> code.</p>
Parameter VALIDATION = "JOURNAL.VALIDATION";

/// <p>The sentence <parameter>VALIDATION</parameter> carries.</p>
Parameter REASONVALIDATION = "The journal settings were refused.";

/// <p>Violation code: a journal directory resolved to a directory the instance does not hold, on its
/// path field.</p>
Parameter DIRECTORYABSENT = "JOURNAL.DIRECTORY.ABSENT";

Parameter REASONDIRECTORYABSENT = "That directory does not exist on the instance. Create it, then choose it.";

/// <p>Violation code: <code>FileSizeLimit</code> is not a whole number of megabytes from 0 to 4079,
/// the range <code>Config.Journal</code> declares and the vendor stores.</p>
Parameter FILESIZESHAPE = "JOURNAL.FILESIZE.SHAPE";

Parameter REASONFILESIZESHAPE = "Enter a whole number of megabytes from 0 to 4079.";

/// <p>Violation code: <code>DaysBeforePurge</code> is not a whole number from 0 to 100, or
/// <code>BackupsBeforePurge</code> not one from 0 to 10.</p>
Parameter PURGESHAPE = "JOURNAL.PURGE.SHAPE";

Parameter REASONPURGESHAPE = "Enter a whole number: up to 100 days, or up to 10 backups.";

/// <p>Violation code: <code>JournalFilePrefix</code> holds a character other than a letter, a digit,
/// a hyphen or an underscore, or more than 64 of them; the vendor refuses a dot.</p>
Parameter PREFIXSHAPE = "JOURNAL.PREFIX.SHAPE";

Parameter REASONPREFIXSHAPE = "Use up to 64 letters, digits, hyphens or underscores.";

/// <p>Violation code: one of the four journal flags is not a JSON boolean.</p>
Parameter BOOLEANSHAPE = "JOURNAL.BOOLEAN.SHAPE";

Parameter REASONBOOLEANSHAPE = "Choose on or off.";

/// <p>Envelope code: a journal record list's filter outside the classic record browser's closed sets
/// -- a column other than its eight, a comparison other than its six -- or a value with no column or
/// comparison (Story 18.19, AD-21). Rendered on the <parameter>OcuPilot.Api.Error.BADREQUEST</parameter>
/// slug with 400, by <class>OcuPilot.Port.AdminPort</class>, before any vendor call; no refusal echoes
/// the value.</p>
Parameter FILTERSHAPE = "JOURNAL.FILTER.SHAPE";

Parameter REASONFILTERSHAPE = "Choose a column and a comparison from the lists, and a value to compare.";

/// <p>Envelope code: a journal record list's offset, or a record's address, that is not a whole number
/// of at most 20 digits (Story 18.19). Rendered on the <parameter>OcuPilot.Api.Error.BADREQUEST</parameter>
/// slug with 400, by <class>OcuPilot.Port.AdminPort</class>, before any vendor call.</p>
Parameter OFFSETSHAPE = "JOURNAL.OFFSET.SHAPE";

Parameter REASONOFFSETSHAPE = "Enter a record offset as a whole number.";

/// <p>Envelope code: the journal record detail route found no record at that address, or one on a
/// database the caller cannot read (Story 18.19, AD-36). Rendered on the
/// <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug with 404, by
/// <class>OcuPilot.Area.OsMgmt.JournalRecordDetail</class>, from the port's
/// <code>PORT.NOTFOUND</code>.</p>
Parameter RECORDUNREADABLE = "JOURNAL.RECORD.UNREADABLE";

Parameter REASONRECORDUNREADABLE = "That record is not in this file, or its database is one you cannot read.";

/// <p>Every <code>JOURNAL.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#FILEUNLISTED, ..#SWITCHDIRNOOTHER, ..#SWITCHDIRUNMOVED, ..#VALIDATION, ..#DIRECTORYABSENT, ..#FILESIZESHAPE, ..#PURGESHAPE, ..#PREFIXSHAPE, ..#BOOLEANSHAPE, ..#FILTERSHAPE, ..#OFFSETSHAPE, ..#RECORDUNREADABLE)
}

/// <p><parameter>REASONSWITCHDIRUNMOVED</parameter> naming <var>pDirectory</var>, inserted as it is.</p>
ClassMethod Unmoved(pDirectory As %String) As %String
{
    Quit $Piece(..#REASONSWITCHDIRUNMOVED, "<directory>", 1) _ pDirectory _ $Piece(..#REASONSWITCHDIRUNMOVED, "<directory>", 2, *)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#FILEUNLISTED Quit ..#REASONFILEUNLISTED
    If pCode = ..#SWITCHDIRNOOTHER Quit ..#REASONSWITCHDIRNOOTHER
    If pCode = ..#SWITCHDIRUNMOVED Quit ..#REASONSWITCHDIRUNMOVED
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#DIRECTORYABSENT Quit ..#REASONDIRECTORYABSENT
    If pCode = ..#FILESIZESHAPE Quit ..#REASONFILESIZESHAPE
    If pCode = ..#PURGESHAPE Quit ..#REASONPURGESHAPE
    If pCode = ..#PREFIXSHAPE Quit ..#REASONPREFIXSHAPE
    If pCode = ..#BOOLEANSHAPE Quit ..#REASONBOOLEANSHAPE
    If pCode = ..#FILTERSHAPE Quit ..#REASONFILTERSHAPE
    If pCode = ..#OFFSETSHAPE Quit ..#REASONOFFSETSHAPE
    If pCode = ..#RECORDUNREADABLE Quit ..#REASONRECORDUNREADABLE
    Quit ""
}

}
