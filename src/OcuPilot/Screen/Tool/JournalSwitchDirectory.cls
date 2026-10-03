/// <p>Journals' Switch directory (Story 18.5, AD-51, AD-53): move journaling to the other configured
/// journal directory, through the vendor's <code>Journal.Settings</code> <code>SWITCHDIR</code>, which
/// reads no body and swaps between the primary and the alternate directory. A second switch moves it
/// back.</p>
/// <p><b>Its pairs are Journals' and <code>%DB_IRISSYS:WRITE</code> and
/// <code>%Admin_Manage:USE</code></b> (AD-8 as amended 2026-10-02): without the first the vendor's
/// switch fails <code>&lt;PROTECT&gt;</code>, and without the second it answers 200 having started a
/// new file in the same directory (measured on <code>ocupilot-b-ci</code>), which
/// <class>OcuPilot.Port.JournalPort</class> refuses
/// <parameter>OcuPilot.Api.JournalError.SWITCHDIRUNMOVED</parameter>. The second pair also reads the
/// settings, so the fresh read names the other directory, and an instance with one configured
/// directory is refused <parameter>OcuPilot.Api.JournalError.SWITCHDIRNOOTHER</parameter> before
/// anything is minted or sent.</p>
/// <p>The card's row is <code>CurrentDirectory</code> moving to that other directory. No vendor event
/// records the switch with auditing on (AD-15, AD-53).</p>
Class OcuPilot.Screen.Tool.JournalSwitchDirectory Extends OcuPilot.Screen.Tool.JournalSwitch
{

Parameter TOOLNAME = "osmgmt.journals.switchdirectory";

Parameter DESCRIPTION = "Propose switching this instance's journal directory: the instance starts writing its journal in the other configured journal directory, and a second switch moves it back. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'current' as the name. An instance with one configured journal directory is refused.";

Parameter SCREENACTIONS = "switchdirectory";

/// <p>The port-composed read: the file journaling writes now, its directory, and the directory a
/// switch moves to.</p>
Parameter READTYPE = "DIRSTATE";

Parameter WRITETYPE = "SWITCHDIR";

Parameter PRECONDITIONFIELD = "CurrentDirectory";

Parameter FINGERPRINTSUBJECT = "CurrentFile,CurrentDirectory,OtherDirectory";

Parameter STATEFIELD = "CurrentDirectory";

Parameter READANSWERS = "CurrentFile,CurrentDirectory,OtherDirectory";

Parameter EXTRAPAIRS = "%DB_IRISSYS:WRITE,%Admin_Manage:USE";

Parameter CLASSICPAGES = "%cspapp.op.utilsysjournalswitchdirectory";

/// <p>The client maps it to <code>journalSwitchDirectoryConsequence</code>.</p>
Parameter CONSEQUENCECODE = "JOURNAL.SWITCHDIRECTORY";

/// <p>The fresh read's refusal when the alternate is no longer a second directory (DW-1950): a confirm
/// reads it as the target having moved.</p>
Parameter PRECONDITIONCODES = "JOURNAL.SWITCHDIR.NOOTHER";

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>:
/// <code>CurrentDirectory</code> moving to <code>OtherDirectory</code>. A read naming neither is
/// refused.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tFrom = ""
    Set tTo = ""
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#STATEFIELD) = "string") Set tFrom = pFresh.%Get(..#STATEFIELD)
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("OtherDirectory") = "string") Set tTo = pFresh.%Get("OtherDirectory")
    If (tFrom = "") || (tTo = "") {
        Set pProblem = "this instance did not report the journal directory it writes in and the other one"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", tFrom, "string")
    Do tRow.%Set("after", tTo, "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
