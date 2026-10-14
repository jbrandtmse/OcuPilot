/// <p>What the rule, BPL and DTL editor screens' agent reads share (AD-36, AD-60, Story 20.16): the class text the
/// screen's editor shows, as saved on the instance. It is <class>OcuPilot.Screen.Tool.ExplorerClassSource</class>
/// bound to the editor screen: the same text, cut, sanitizer and port, with no kind check, so it reaches exactly
/// what <code>explorer.class.source</code> reaches. The screen's pairs plus <code>%Development:USE</code>, which the
/// port checks, are required (<method>PrivilegePairs</method>).</p>
Class OcuPilot.Screen.Tool.InteropEditorSource Extends OcuPilot.Screen.Tool.ExplorerClassSource [ Abstract, DependsOn = OcuPilot.Screen.Tool.InteropEditorSave ]
{

/// <p>The sentence every editor tool's description carries, <parameter>OcuPilot.Screen.Tool.InteropEditorSave.WARN</parameter>.</p>
Parameter WARN = {##class(OcuPilot.Screen.Tool.InteropEditorSave).#WARN};

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
