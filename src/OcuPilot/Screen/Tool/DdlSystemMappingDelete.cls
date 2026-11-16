/// <p>System DDL mappings' Delete (Story 21.13, AD-6, AD-10, AD-53): remove one system DDL mapping of this instance. Destructive; see
/// <class>OcuPilot.Screen.Tool.DdlMappingDelete</class>.</p>
Class OcuPilot.Screen.Tool.DdlSystemMappingDelete Extends OcuPilot.Screen.Tool.DdlMappingDelete
{

Parameter TOOLNAME = "osmgmt.systemddlmappings.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DdlSystemMappingList";

Parameter DESCRIPTION = "Propose deleting one system DDL mapping of this instance, which cannot be restored from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the mapping as the System DDL mappings list reports it. DDL that names the type afterwards no longer maps it to its datatype. A mapping the list does not report is refused.";

Parameter ENDPOINTNAME = "SystemDDL";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Config.SQLDataTypes,%CSP.UI.Portal.Config.SQLDataType";

}
