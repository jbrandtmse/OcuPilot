/// <p><code>shell.namespaces.read</code>: the namespaces the caller may read, as
/// <method>OcuPilot.Kernel.Shell.Namespaces.Payload</method> builds them for
/// <code>GET /api/ocupilot/namespaces</code>. In a turn job <code>scope</code> is the scope the
/// turn was started under, which <method>OcuPilot.Kernel.Agent.Job.Run</method> sets.</p>
Class OcuPilot.Kernel.Shell.NamespacesRead Extends OcuPilot.Kernel.Shell.ReadTool
{

Parameter TOOLNAME = "shell.namespaces.read";

Parameter DESCRIPTION = "Read the namespaces this account may read on this instance, whether each is writable, and the privilege pair that blocks writing where one does.";

ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Kernel.Shell.Namespaces).Payload(.pObject)
}

/// <p><code>{scope, namespaces}</code>, each namespace <code>{name, writable}</code> plus
/// <code>failedPair</code> where a privilege blocks writing.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "scope": {"type": "string", "description": "The namespace the read was scoped to."},
            "namespaces": {
                "type": "array",
                "description": "One entry per readable namespace.",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "writable": {"type": "boolean"},
                        "failedPair": {"type": "string"}
                    },
                    "required": ["name", "writable"],
                    "additionalProperties": false
                }
            }
        },
        "required": ["scope", "namespaces"],
        "additionalProperties": false
    }
}

}
