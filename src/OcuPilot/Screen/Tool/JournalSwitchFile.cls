/// <p>Journals' Switch file (Story 18.5, AD-51, AD-53): close the file journaling writes now and start
/// a new one, through the vendor's <code>Journal.Settings</code> <code>SWITCHFILE</code>, which reads
/// no body and answers the new file. Journals' own two pairs suffice (measured on
/// <code>ocupilot-b-ci</code>, 2026-10-02), and the classic Journals properties page is its replaced
/// page (AD-44).</p>
/// <p>The card's row is <code>CurrentFile</code> moving from the file journaling writes now to a new
/// file, which the card reads as its published word (<parameter>EMPTYKEYS</parameter>). No vendor
/// event records it with auditing on (AD-15, AD-53).</p>
Class OcuPilot.Screen.Tool.JournalSwitchFile Extends OcuPilot.Screen.Tool.JournalSwitch
{

Parameter TOOLNAME = "osmgmt.journals.switchfile";

Parameter DESCRIPTION = "Propose switching this instance's journal file: the instance closes the file it writes now and starts a new journal file. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'current' as the name.";

Parameter SCREENACTIONS = "switchfile";

/// <p>The port-composed read: the file journaling writes now and its directory.</p>
Parameter READTYPE = "STATE";

Parameter WRITETYPE = "SWITCHFILE";

Parameter PRECONDITIONFIELD = "CurrentFile";

Parameter FINGERPRINTSUBJECT = "CurrentFile";

Parameter STATEFIELD = "CurrentFile";

Parameter READANSWERS = "CurrentFile,CurrentDirectory";

Parameter CLASSICPAGES = "%cspapp.op.utilsysjournalproperties";

/// <p>The card reads an empty new file as "a new journal file".</p>
Parameter EMPTYKEYS = "CurrentFile=journalSwitchNewFile";

/// <p>The client maps it to <code>journalSwitchFileConsequence</code>.</p>
Parameter CONSEQUENCECODE = "JOURNAL.SWITCHFILE";

/// <p>The one row this proposal's card shows, from the fresh read <var>pFresh</var>:
/// <code>CurrentFile</code> from the file journaling writes now to a new one. A read naming no file
/// is refused.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tFile = ""
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#STATEFIELD) = "string") Set tFile = pFresh.%Get(..#STATEFIELD)
    If tFile = "" {
        Set pProblem = "this instance did not report the file journaling writes now"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", tFile, "string")
    Do tRow.%Set("after", "", "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
