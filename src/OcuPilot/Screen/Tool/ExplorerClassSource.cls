/// <p>The agent's read of one class's source text (Story 20.19, AD-36, AD-60): the text the class
/// viewer shows for <var>name</var>, in the turn's namespace, as whole lines. The viewer's own read
/// answers the class's members and type; this tool answers its text, which the viewer keeps out of
/// the model's reach.</p>
/// <p>Its checks, pairs and read are <class>OcuPilot.Screen.Tool.ExplorerSourceRead</class>'s.</p>
Class OcuPilot.Screen.Tool.ExplorerClassSource Extends OcuPilot.Screen.Tool.ExplorerSourceRead
{

Parameter TOOLNAME = "explorer.class.source";

Parameter DESCRIPTION = "Read one class's source text in the namespace this turn is scoped to, as the class viewer (explorer.class) shows it. The text is whole lines, cut to fit 60,000 characters: when it is cut, truncated is true and linesSent is below lines. Call this alone in a reply: a result past what remains of the reply's 65,536 characters answers TOOL.RESULTTOOLARGE. explorer.class.read answers the class's members and type.";

/// <p>The viewer whose pairs this tool requires and whose context lists it.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerClassDocument";

/// <p>The viewer's <code>name</code> hint, spelled as the class list's own Name.</p>
Parameter NAMEHINT = "One class, as Package.Name.cls, spelled as explorer.classes.read answers its Name.";

/// <p>The class document endpoint of the source code API port.</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASS
}

/// <p>Declared: none (AD-3). The name is a class name, never a secret.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

}
