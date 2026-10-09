/// <p>The Routines list's create (Story 20.20, <class>OcuPilot.Screen.Tool.ExplorerCreate</class>): the agent
/// proposes one new routine, include file or intermediate routine in the turn's namespace.</p>
Class OcuPilot.Screen.Tool.ExplorerRoutineCreate Extends OcuPilot.Screen.Tool.ExplorerCreate
{

Parameter TOOLNAME = "explorer.routines.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerRoutineList";

/// <p>A routine (<code>.mac</code>), include file (<code>.inc</code>) or intermediate routine
/// (<code>.int</code>).</p>
Parameter KINDPATTERN = "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)*\.(mac|int|inc)$";

Parameter REASONKIND = "'Names' names one new routine or include file, as Name.mac, Name.int or Name.inc";

Parameter DESCRIPTION = "Propose one new routine, include file or intermediate routine in the turn's namespace, which the user confirms. Confirm saves the text and then compiles it as the user, and the card shows the outcome, which this tool never answers. Send Names, the document's name as Name.mac, Name.int or Name.inc, and Text, the whole document in UDL form: ROUTINE Name, with [Type=INC] or [Type=INT] for an include file or an intermediate routine, at most 30,000 characters. A name the namespace holds is refused, and so is a routine or intermediate routine whose base name another routine of the namespace uses in the same case, because compiling replaces that name's intermediate code. Also refused: a name beginning with % or OcuPilot, a routine in %SYS, and a name the namespace stores in another database. To change an existing routine, use explorer.routines.save.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES
}

}
