/// <p><code>shell.instance.read</code>: the instance the shell identifies itself with, as
/// <method>OcuPilot.Kernel.Shell.Instance.Payload</method> builds it for
/// <code>GET /api/ocupilot/instance</code>.</p>
Class OcuPilot.Kernel.Shell.InstanceRead Extends OcuPilot.Kernel.Shell.ReadTool
{

Parameter TOOLNAME = "shell.instance.read";

Parameter DESCRIPTION = "Read this instance's name, IRIS version, admin API version, build identity, system mode, licensee and host node.";

ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Kernel.Shell.Instance).Payload(.pObject)
}

/// <p>The payload's seven keys, every one always present.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "adminApiVersion": {"type": "integer", "description": "The admin API version the instance reports; 2 is the one OcuPilot uses."},
            "instanceName": {"type": "string", "description": "The instance's configured name."},
            "instanceVersion": {"type": "string", "description": "The IRIS version banner."},
            "buildIdentity": {"type": "string", "description": "The OcuPilot build installed, or empty."},
            "serverFlag": {"type": "string", "description": "The system mode, or empty."},
            "licensedTo": {"type": "string", "description": "The licence key's customer name, or empty."},
            "serverName": {"type": "string", "description": "The host node, or empty."}
        },
        "required": ["adminApiVersion", "instanceName", "instanceVersion", "buildIdentity", "serverFlag", "licensedTo", "serverName"],
        "additionalProperties": false
    }
}

}
