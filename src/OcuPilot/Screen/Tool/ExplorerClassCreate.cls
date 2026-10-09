/// <p>The Classes list's create (Story 20.20, <class>OcuPilot.Screen.Tool.ExplorerCreate</class>): the agent
/// proposes one new class in the turn's namespace.</p>
Class OcuPilot.Screen.Tool.ExplorerClassCreate Extends OcuPilot.Screen.Tool.ExplorerCreate
{

Parameter TOOLNAME = "explorer.classes.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerClassList";

/// <p>A class name with a package: <code>Package.Name.cls</code>. A package-less class is stored as
/// <code>User.&lt;Name&gt;</code>, so it is refused.</p>
Parameter KINDPATTERN = "^%?[A-Za-z][A-Za-z0-9]*(\.%?[A-Za-z][A-Za-z0-9]*)+\.cls$";

Parameter REASONKIND = "'Names' names one new class with a package, as Package.Name.cls, and a class without a package is not created";

Parameter DESCRIPTION = "Propose one new class in the turn's namespace, which the user confirms. Confirm saves the text and then compiles it as the user, and the card shows the outcome, which this tool never answers. Send Names, the class's name with its package as Package.Name.cls, and Text, the whole class in UDL form, starting Class Package.Name, at most 30,000 characters. A name the namespace already holds, in any letter case, is refused, and so is a class whose name begins with % or OcuPilot, a class in %SYS, and a name the namespace stores in another database. To change an existing class, use explorer.classes.save.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES
}

}
