/// <p>What the rule, BPL and DTL editor screens' agent reads share (AD-36, AD-60, Story 20.16): the class text the
/// screen's editor shows, as saved on the instance. It is <class>OcuPilot.Screen.Tool.ExplorerClassSource</class>
/// bound to the editor screen: the same text, cut, sanitizer and port, with no kind check, so it reaches exactly
/// what <code>explorer.class.source</code> reaches. The screen's pairs plus <code>%Development:USE</code>, which the
/// port checks, are required (<method>PrivilegePairs</method>).</p>
Class OcuPilot.Screen.Tool.InteropEditorSource Extends OcuPilot.Screen.Tool.ExplorerClassSource [ Abstract ]
{

/// <p>The sentence every editor tool's description carries: the same text as
/// <parameter>OcuPilot.Screen.Tool.InteropEditorSave.WARN</parameter>, which <class>OcuPilot.Test.InteropEditorTools</class>
/// pins equal.</p>
Parameter WARN = "The editor may hold changes that are not saved, which you cannot see: before you read or change the document, tell the person you work from what is saved and ask them to save the editor first, because confirming your change opens the document again and drops its unsaved changes.";

/// <p>The cut and the call-alone sentences, as <class>OcuPilot.Screen.Tool.ExplorerClassSource</class> gives them.</p>
Parameter CUTTEXT = "The text is whole lines, cut to fit 60,000 characters: when it is cut, truncated is true and linesSent counts the lines it carries; a first line longer than that is itself cut and counts as one. Call this alone in a reply: a result past what remains of the reply's 65,536 characters answers TOOL.RESULTTOOLARGE.";

/// <p>The screen's declared pairs and <code>%Development:USE</code>, each once (AD-8).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Set tPair = $ListBuild("%Development", "USE")
    If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
    Quit tPairs
}

}
