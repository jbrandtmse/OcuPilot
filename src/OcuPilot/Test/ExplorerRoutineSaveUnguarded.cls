/// <p>The Routines save with the agent guard lifted, so <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class>
/// reaches its read of a vendor routine that <method>OcuPilot.Screen.Tool.ExplorerSave.AgentProblem</method>
/// refuses first (<class>OcuPilot.Test.ExplorerSaveFlow</class>). It is not a tool: the registry excludes
/// this package.</p>
Class OcuPilot.Test.ExplorerRoutineSaveUnguarded Extends OcuPilot.Screen.Tool.ExplorerRoutineSave
{

/// <p>Nothing is refused: the save of any document reaches the mint's read.</p>
ClassMethod AgentProblem(pNamespace As %String, pName As %String, pCreate As %Boolean = 0) As %String
{
    Quit ""
}

}
