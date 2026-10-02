/// <p>What Journals' three write tools share (Story 18.5, AD-51, AD-52, AD-53): an action-style write
/// on the <code>journal-file</code> type through <class>OcuPilot.Port.JournalPort</class>, which
/// composes the fresh read or builds the vendor body, reached by two callers -- the Journals page's
/// own action through <class>OcuPilot.Api.ScreenAction</class>, behind its warning dialog, and the
/// agent's proposal and confirmation. None sends a body of its own and none removes data.</p>
/// <p><b>Its pairs</b> are Journals' own, then each <parameter>EXTRAPAIRS</parameter> pair the set
/// lacks, then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44),
/// each refused by name before any port call.</p>
Class OcuPilot.Screen.Tool.JournalAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.JournalList";

/// <p>The port that composes the reads and builds the bodies (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.JournalPort";

/// <p>No body: the vendor's switches read none, and the port builds the check's.</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>The pair the write itself names: the vendor's <code>ResourcesOR()</code> for the switches and the
/// integrity check is <code>%Admin_Operate</code>, which Journals' set already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

/// <p>The pairs this tool requires beyond Journals' own, as comma-separated
/// <code>resource:permission</code> entries (AD-8), or <code>""</code>.</p>
Parameter EXTRAPAIRS;

/// <p>The consequence code the proposal carries, which the client maps to its published
/// sentence.</p>
Parameter CONSEQUENCECODE;

/// <p>A journal file is named by its full name, as the instance's journal file list spells it.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p><parameter>CONSEQUENCECODE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>What the caller must hold: Journals' own pairs, then <parameter>WRITERESOURCE</parameter> and
/// each <parameter>EXTRAPAIRS</parameter> pair the set lacks, then the custom resource of each
/// <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    For tI = 1:1:$Length(..#EXTRAPAIRS, ",") {
        Set tEntry = $ZStrip($Piece(..#EXTRAPAIRS, ",", tI), "<>W")
        If tEntry = "" Continue
        Set tPair = $ListBuild($Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2))
        If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
