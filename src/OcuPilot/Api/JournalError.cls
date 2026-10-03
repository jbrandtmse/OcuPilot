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

/// <p>Every <code>JOURNAL.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#FILEUNLISTED, ..#SWITCHDIRNOOTHER, ..#SWITCHDIRUNMOVED)
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
    Quit ""
}

}
