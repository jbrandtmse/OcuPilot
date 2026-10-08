/// <p>The agent's read of one routine's or include file's source text (Story 20.19, AD-36, AD-60): the
/// text the routine viewer shows for <var>name</var>, in the turn's namespace, as whole lines. The
/// viewer's own read answers the routine's row; this tool answers its text, which the viewer keeps out
/// of the model's reach.</p>
/// <p>Its checks, pairs and read are <class>OcuPilot.Screen.Tool.ExplorerSourceRead</class>'s. A routine
/// the instance keeps only as object code answers 404 <code>PORT.NOTFOUND</code>.</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineSource Extends OcuPilot.Screen.Tool.ExplorerSourceRead
{

Parameter TOOLNAME = "explorer.routine.source";

Parameter DESCRIPTION = "Read one routine's or include file's source text in the namespace this turn is scoped to, as the routine viewer (explorer.routine) shows it. The text is whole lines, cut to fit 60,000 characters: when it is cut, truncated is true and linesSent is below lines. Call this alone in a reply: a result past what remains of the reply's 65,536 characters answers TOOL.RESULTTOOLARGE. explorer.routine.read answers the routine's type and fields.";

/// <p>The viewer whose pairs this tool requires and whose context lists it.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineDocument";

/// <p>The viewer's <code>name</code> hint, spelled as the routine list's own Name.</p>
Parameter NAMEHINT = "One routine or include file, as Name.mac, .int, .inc, .bas, .mvi or .mvb, spelled as explorer.routines.read answers its Name.";

/// <p>The routine document endpoint of the source code API port.</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINE
}

/// <p>Declared: none (AD-3). The name is a routine name, never a secret.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

}
