/// <p>The Roles list's SQL privilege revoke tool (AD-6, AD-51, AD-52, AD-53, Story 18.9): propose revoking one SQL object
/// privilege from a role. Its state, fingerprint, pairs and refusals are
/// <class>OcuPilot.Screen.Tool.SqlPrivilegeWrite</class>'s; the role editor's SQL privileges tab reaches it as the
/// row action <code>revoke-sql</code> (<parameter>SCREENACTIONS</parameter>).</p>
Class OcuPilot.Screen.Tool.RoleSqlRevoke Extends OcuPilot.Screen.Tool.SqlPrivilegeWrite
{

Parameter TOOLNAME = "permissions.roles.revokesql";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoleList";

Parameter DESCRIPTION = "Propose revoking one direct SQL privilege on a table, view, stored procedure, schema, ML configuration or foreign server, on one column of a table or view, or an SQL admin privilege (Type ADMIN, the privilege in Action), in one namespace from a role, as the role editor's SQL privileges tab does once confirmed. The revoke is sent once for each user that granted it directly. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the role exactly as the roles list reports it, one object (none for ADMIN), one optional column and one action, never a list or a wildcard. A privilege the role holds only through a role, a schema or ownership, a role holding every privilege through %All, and any privilege on OcuPilot's own tables or for OcuPilot's own roles are refused.";

Parameter GRANTEEKIND = "role";

/// <p>The row action this tool carries out, with the values it takes from the tab (AD-53, AD-56 (ii)).</p>
Parameter SCREENACTIONS = "revoke-sql";

Parameter SCREENVALUES = "revoke-sql=Namespace:Type:Object:Action:Column";

Parameter READTYPE = "REVOKESTATE";

Parameter WRITETYPE = "REVOKE";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Type,Object,Action,Column,Held,GrantOption,GrantedBy,Rows";

/// <p>The arguments travel in the payload for the confirm to send, and the state is what the user reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Type,Object,Action,Column,Held,GrantOption,GrantedBy,Rows";

/// <p>The refusals the port's read answers with when the state is not the one this write moves out of.</p>
Parameter PRECONDITIONCODES = "SQLPRIV.NOTHELD,SQLPRIV.SUPERUSER";

/// <p>The classic pages whose operations this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Role,%CSP.UI.Portal.Dialog.ColumnPriv";

}
