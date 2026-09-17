/// <p><code>shell.privileges.read</code>: every area and built screen with whether the caller may
/// reach it, as <method>OcuPilot.Api.Navigation.Payload</method> answers
/// <code>GET /api/ocupilot/navigation</code>, evaluated in the calling process (AD-8).</p>
Class OcuPilot.Screen.Tool.ShellPrivileges Extends OcuPilot.Screen.Tool.Shell
{

Parameter TOOLNAME = "shell.privileges.read";

Parameter DESCRIPTION = "Read every area and screen of this portal, whether this account may reach each one, and the privilege pair that blocks each one it may not.";

ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Api.Navigation).Payload(.pObject)
}

/// <p><code>{areas}</code>, each area carrying its screens, and each area and screen carrying
/// <code>allowed</code> plus <code>failedPair</code> where it is refused.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "areas": {
                "type": "array",
                "description": "Every area, in rail order.",
                "items": {
                    "type": "object",
                    "properties": {
                        "key": {"type": "string"},
                        "labelKey": {"type": "string"},
                        "railPosition": {"type": "integer"},
                        "navigates": {"type": "boolean"},
                        "pinBottom": {"type": "boolean"},
                        "allowed": {"type": "boolean"},
                        "failedPair": {"type": "string"},
                        "screens": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "route": {"type": "string"},
                                    "labelKey": {"type": "string"},
                                    "sideBarPosition": {"type": "integer"},
                                    "allowed": {"type": "boolean"},
                                    "failedPair": {"type": "string"}
                                },
                                "required": ["route", "labelKey", "sideBarPosition", "allowed"],
                                "additionalProperties": false
                            }
                        }
                    },
                    "required": ["key", "labelKey", "railPosition", "navigates", "pinBottom", "allowed", "screens"],
                    "additionalProperties": false
                }
            }
        },
        "required": ["areas"],
        "additionalProperties": false
    }
}

}
