/// <p>The directory allow-list write's codes (AD-39, AD-21's tenth case, Story 18.42): every <code>ALLOWLIST.*</code>
/// code <code>POST /allowed-directories</code> and <class>OcuPilot.Port.AllowListPort</class> answer, and the one
/// sentence each carries. They live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds
/// the compiler's limit of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.AllowListError Extends %RegisteredObject
{

/// <p>Refusal (403): the governance key <code>security.alloweddirectories.update</code> is disabled, which is its
/// shipped value. Asked before any read.</p>
Parameter OFF = "ALLOWLIST.OFF";

Parameter REASONOFF = "Changing the allowed directories is switched off on this instance. An administrator can switch it on in Governance policy.";

/// <p>Violation code (400): a directory that is not absolute, is empty, holds a control character, or is longer than
/// <parameter>DIRECTORYMAX</parameter> characters once normalized, on <code>Directory</code> or
/// <code>NewDirectory</code>. Nothing is read or sent.</p>
Parameter PATH = "ALLOWLIST.PATH";

Parameter REASONPATH = "A directory is an absolute path of at most 1,024 characters with no control character.";

/// <p>Violation code (409): an add or a change names a directory the list already holds. Nothing is sent.</p>
Parameter LISTED = "ALLOWLIST.LISTED";

Parameter REASONLISTED = "That directory is already allowed.";

/// <p>Violation code (409): a change or a remove names a directory the list does not hold. Nothing is sent.</p>
Parameter NOTLISTED = "ALLOWLIST.NOTLISTED";

Parameter REASONNOTLISTED = "That directory is not one of the allowed directories.";

/// <p>Violation code (422): an add or a change names a directory that does not exist on the server. Nothing is
/// sent.</p>
Parameter NODIRECTORY = "ALLOWLIST.NODIRECTORY";

Parameter REASONNODIRECTORY = "No directory of that name exists on the server.";

/// <p>Violation code (409): a change or a remove names the manager directory while the list is unrestricted, when it
/// is the list's one entry. Nothing is sent.</p>
Parameter FALLBACK = "ALLOWLIST.FALLBACK";

Parameter REASONFALLBACK = "While the list is unrestricted its one entry is the manager directory, which cannot be changed or removed. Adding a directory restricts the list to that directory and the manager directory.";

/// <p>The longest directory the list stores, in characters of its normalized spelling, trailing separator included.</p>
Parameter DIRECTORYMAX = 1024;

/// <p>Every <code>ALLOWLIST.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#OFF, ..#PATH, ..#LISTED, ..#NOTLISTED, ..#NODIRECTORY, ..#FALLBACK)
}

/// <p>The codes a write's fresh read refuses with once the write has run: after an add the directory is listed, and
/// after a change or a remove the old one is not. The tool's
/// <method>OcuPilot.Screen.Tool.Write.PreconditionCodes</method> answers these, so the read-back after the write is
/// not read as an unreadable target.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit $ListBuild(..#LISTED, ..#NOTLISTED)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#OFF Quit ..#REASONOFF
    If pCode = ..#PATH Quit ..#REASONPATH
    If pCode = ..#LISTED Quit ..#REASONLISTED
    If pCode = ..#NOTLISTED Quit ..#REASONNOTLISTED
    If pCode = ..#NODIRECTORY Quit ..#REASONNODIRECTORY
    If pCode = ..#FALLBACK Quit ..#REASONFALLBACK
    Quit ""
}

}
