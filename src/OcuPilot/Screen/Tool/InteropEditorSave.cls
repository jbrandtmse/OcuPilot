/// <p>What the rule, BPL and DTL editor screens' agent saves share (AD-53, AD-62 item 14, Story 20.16): an agent's
/// proposal to change the class text behind the embedded editor, which the person confirms. It is
/// <class>OcuPilot.Screen.Tool.ExplorerClassSave</class> bound to the editor screen, and changes only these:</p>
/// <ul>
/// <li>Agent-only. The editor screen has no save action, so <parameter>SCREENACTIONS</parameter> and
/// <parameter>SCREENVALUES</parameter> are empty, and <parameter>SCREENLISTED</parameter> lists the tool in the
/// screen's context.</li>
/// <li>Only a class of the editor's kind is admitted (<parameter>KINDBASE</parameter>). <method>AgentProblem</method>
/// asks <method>OcuPilot.Port.InteropPort.IsCodeOfKind</method> after the class save's own rules, and Confirm asks
/// it again through <method>OcuPilot.Screen.Tool.ExplorerSave.ConfirmProblem</method>.</li>
/// <li>The pairs are the screen's, <code>%Development:USE</code> (which the port checks) and
/// <code>%Ens_Code:WRITE</code>, the resource the vendor editors write under (<method>PrivilegePairs</method>). The
/// WRITE on the routines database stays an argument pair.</li>
/// <li>The consequence is <code>INTEROP.EDITOR.RELOADS</code>: Confirm saves and compiles the text, and the editor
/// opens the document again.</li>
/// </ul>
/// <p><b>OcuPilot never reads the editor</b> (AD-63): the agent works from the saved class text, and
/// <parameter>WARN</parameter> tells the model to say so to the person before it reads or changes anything.</p>
Class OcuPilot.Screen.Tool.InteropEditorSave Extends OcuPilot.Screen.Tool.ExplorerClassSave [ Abstract ]
{

/// <p>Agent-only: the editor screen declares no action.</p>
Parameter SCREENACTIONS = "";

Parameter SCREENVALUES = "";

/// <p>Listed in the editor screen's context although no action carries it (AD-24).</p>
Parameter SCREENLISTED As BOOLEAN = 1;

/// <p>The proposal says confirming opens the document again in the editor.</p>
Parameter CONSEQUENCE = "INTEROP.EDITOR.RELOADS";

/// <p>The class an editor's document must descend from, set by each save.</p>
Parameter KINDBASE = "";

/// <p>What a document of the kind is called in a refusal, set by each save.</p>
Parameter KINDNOUN = "";

/// <p>The editor's read tool, which the <code>Edits</code> description tells the model to read with.</p>
Parameter READWITH = "";

/// <p>The sentence every editor tool's description carries: the model works from what is saved and says so
/// before it reads or changes anything.</p>
Parameter WARN = "The editor may hold changes that are not saved, which you cannot see: before you read or change the document, tell the person you work from what is saved and ask them to save the editor first, because confirming your change opens the document again and drops its unsaved changes.";

/// <p>The rule a match refusal states, naming the three editor reads.</p>
Parameter MATCHRULE = "Each Old is matched exactly, character for character, against the text this instance stores. The copy interop.ruleeditor.source, interop.processeditor.source and interop.transformeditor.source send can differ from it: control and invisible characters are removed, a key-shaped value reads [redacted], and the data delimiter's name is changed. Choose an Old that avoids those places.";

/// <p>The screen's declared pairs, <code>%Development:USE</code> and <code>%Ens_Code:WRITE</code>, each once.
/// <code>%Ens_Code:WRITE</code> is the one resource that admits a save in all three vendor editors (a holder of
/// only <code>%Ens_DTL</code>, <code>%Ens_BPL</code> or <code>%Ens_Rules</code> WRITE is refused). The WRITE on the
/// routines database is <method>OcuPilot.Screen.Tool.ExplorerSave.ArgumentPairs</method>'s.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    For tPair = $ListBuild("%Development", "USE"), $ListBuild("%Ens_Code", "WRITE") {
        If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
    }
    Quit tPairs
}

/// <p>What is wrong with saving class <var>pName</var> (<code>&lt;class&gt;.cls</code>) in namespace
/// <var>pNamespace</var> on the agent's behalf, or <code>""</code>: the class save's rules first, then that the
/// class descends from <parameter>KINDBASE</parameter> without being it. A kind that cannot be read refuses.
/// The mint asks it, and Confirm asks it again.</p>
ClassMethod AgentProblem(pNamespace As %String, pName As %String, pCreate As %Boolean = 0) As %String
{
    Set tProblem = ##super(pNamespace, pName, pCreate)
    If tProblem '= "" Quit tProblem
    Set tClass = $Piece(pName, ".", 1, $Length(pName, ".") - 1)
    Set tKind = ##class(OcuPilot.Port.InteropPort).IsCodeOfKind(pNamespace, tClass, ..#KINDBASE, .tRead)
    If 'tRead Quit "whether '" _ pName _ "' is " _ ..#KINDNOUN _ " could not be read, so the agent does not save it"
    If 'tKind Quit "'" _ pName _ "' is not " _ ..#KINDNOUN _ " in namespace " _ pNamespace _ ", so this editor's save does not change it; explorer.classes.save changes other classes"
    Quit ""
}

}
