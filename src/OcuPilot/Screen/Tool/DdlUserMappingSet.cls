/// <p>User DDL mappings' Set value (Story 21.13, AD-6, AD-51, AD-53, AD-58): change the datatype one user DDL mapping of this instance maps
/// its type to (<code>Config.SqlUserDatatypes</code>). The agent reaches it through a proposal the user confirms; User DDL mappings reaches
/// it through its <code>set</code> row action. It is <class>OcuPilot.Screen.Tool.DdlSystemMappingSet</class>'s shape over the other class.</p>
Class OcuPilot.Screen.Tool.DdlUserMappingSet Extends OcuPilot.Screen.Tool.DdlSystemMappingSet
{

Parameter TOOLNAME = "osmgmt.userddlmappings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DdlUserMappingList";

Parameter DESCRIPTION = "Propose changing the datatype one user DDL mapping of this instance maps its type to. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the mapping as the User DDL mappings list reports it, and give the new datatype as text in the form the list's Accepts column states: a datatype class name, with its parameters in parentheses if it takes any. A mapping the list does not report and a datatype that is not a class name are refused. A change takes effect for the next DDL statement that names the type.";

Parameter ENDPOINTNAME = "UserDDL";

ClassMethod NameDescription() As %String
{
    Quit "The user DDL mapping, named exactly as the User DDL mappings list reports it in its Name column. A mapping the list does not report is refused."
}

}
