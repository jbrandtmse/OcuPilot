/// <p>The package mappings list's delete tool (Story 18.14): propose deleting one package mapping
/// (<class>OcuPilot.Screen.Tool.MappingDelete</class>).</p>
Class OcuPilot.Screen.Tool.PackageMappingDelete Extends OcuPilot.Screen.Tool.MappingDelete
{

Parameter TOOLNAME = "osmgmt.packagemappings.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PackageMappingList";

Parameter DESCRIPTION = "Propose deleting one package mapping of one namespace. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the mapping as its package mappings list reports them. The namespace then reads what the mapping named from its default database again; no data is deleted.";

Parameter ENDPOINT = "Namespace.PackageMappings";

Parameter MAPPINGKIND = "package";

/// <p>The top-level names the vendor's <code>GET</code> answers, read off its <code>ObjToJson</code>
/// on this build.</p>
Parameter READANSWERS = "Database";

Parameter FINGERPRINTSUBJECT = "Database";

}
