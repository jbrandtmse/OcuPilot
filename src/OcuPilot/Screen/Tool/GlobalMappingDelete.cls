/// <p>The global mappings list's delete tool (Story 18.14): propose deleting one global mapping
/// (<class>OcuPilot.Screen.Tool.MappingDelete</class>).</p>
Class OcuPilot.Screen.Tool.GlobalMappingDelete Extends OcuPilot.Screen.Tool.MappingDelete
{

Parameter TOOLNAME = "osmgmt.globalmappings.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.GlobalMappingList";

Parameter DESCRIPTION = "Propose deleting one global mapping of one namespace. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the mapping as its global mappings list reports them. The namespace then reads what the mapping named from its default database again; no data is deleted.";

Parameter ENDPOINT = "Namespace.GlobalMappings";

Parameter MAPPINGKIND = "global";

/// <p>The top-level names the vendor's <code>GET</code> answers, read off its <code>ObjToJson</code>
/// on this build.</p>
Parameter READANSWERS = "Database,LockDatabase,Collation";

Parameter FINGERPRINTSUBJECT = "Database,LockDatabase,Collation";

}
