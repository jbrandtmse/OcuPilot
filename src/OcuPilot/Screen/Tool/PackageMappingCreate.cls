/// <p>The package mappings list's create tool (Story 18.14): propose a new package mapping in one
/// namespace (<class>OcuPilot.Screen.Tool.MappingCreate</class>).</p>
Class OcuPilot.Screen.Tool.PackageMappingCreate Extends OcuPilot.Screen.Tool.MappingCreate
{

Parameter TOOLNAME = "osmgmt.packagemappings.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PackageMappingList";

Parameter DESCRIPTION = "Propose a new package mapping in one namespace, so the namespace reads the named package from another database. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace, the package to map and the database.";

Parameter ENDPOINT = "Namespace.PackageMappings";

Parameter MAPPINGKIND = "package";

Parameter PERMITTEDFIELDS = "Database";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Mappings.Package";

}
