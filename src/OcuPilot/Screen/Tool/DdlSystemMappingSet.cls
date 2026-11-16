/// <p>System DDL mappings' Set value (Story 21.13, AD-6, AD-51, AD-53, AD-58): change the datatype one system DDL mapping of this instance
/// maps its type to (<code>Config.SqlSysDatatypes</code>). The agent reaches it through a proposal the user confirms; System DDL mappings
/// reaches it through its <code>set</code> row action, which names the mapping and the datatype. Its rules, pairs and consequence are
/// <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
Class OcuPilot.Screen.Tool.DdlSystemMappingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.systemddlmappings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DdlSystemMappingList";

Parameter DESCRIPTION = "Propose changing the datatype one system DDL mapping of this instance maps its type to. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the mapping as the System DDL mappings list reports it, and give the new datatype as text in the form the list's Accepts column states: a datatype class name, with its parameters in parentheses if it takes any. A mapping the list does not report and a datatype that is not a class name are refused. A change takes effect for the next DDL statement that names the type.";

Parameter ENDPOINTNAME = "SystemDDL";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Config.SQLDataTypes,%CSP.UI.Portal.Config.SQLDataType";

ClassMethod NameDescription() As %String
{
    Quit "The system DDL mapping, named exactly as the System DDL mappings list reports it in its Name column. A mapping the list does not report is refused."
}

ClassMethod ValueDescription() As %String
{
    Quit "The datatype the mapping's type maps to, as text: a datatype class name, with its parameters in parentheses if it takes any, of up to 256 characters. A value that is not one is refused."
}

}
