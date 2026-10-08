/// <p>The Users list's SQL privilege grant tool (AD-6, AD-51, AD-52, AD-53, Story 18.9): propose granting one SQL object
/// privilege to a user. Its state, fingerprint, pairs and refusals are
/// <class>OcuPilot.Screen.Tool.SqlPrivilegeWrite</class>'s; the user editor's SQL privileges tab reaches it as the
/// row action <code>grant-sql</code> (<parameter>SCREENACTIONS</parameter>).</p>
Class OcuPilot.Screen.Tool.UserSqlGrant Extends OcuPilot.Screen.Tool.SqlPrivilegeWrite
{

Parameter TOOLNAME = "permissions.users.grantsql";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

Parameter DESCRIPTION = "Propose granting one SQL privilege on a table, view, stored procedure, schema, ML configuration or foreign server, on one column of a table or view, or an SQL admin privilege (Type ADMIN, the privilege in Action), in one namespace to a user, as the user editor's SQL privileges tab does once confirmed; with the grant option when asked. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the user exactly as the users list reports it, one object (none for ADMIN), one optional column and one action, never a list or a wildcard. A privilege the user already holds, a user holding every privilege through %All, and any privilege on OcuPilot's own tables or for OcuPilot's own roles are refused.";

Parameter GRANTEEKIND = "user";

/// <p>The row action this tool carries out, with the values it takes from the tab (AD-53, AD-56 (ii)).</p>
Parameter SCREENACTIONS = "grant-sql";

Parameter SCREENVALUES = "grant-sql=Namespace:Type:Object:Action:Column:WithGrant";

Parameter READTYPE = "GRANTSTATE";

Parameter WRITETYPE = "GRANT";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Namespace,Type,Object,Action,Column,WithGrant,Held,GrantOption,GrantedBy,Rows";

/// <p>The arguments travel in the payload for the confirm to send, and the state is what the user reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Type,Object,Action,Column,WithGrant,Held,GrantOption,GrantedBy,Rows";

/// <p>The refusals the port's read answers with when the state is not the one this write moves out of.</p>
Parameter PRECONDITIONCODES = "SQLPRIV.HELD,SQLPRIV.SUPERUSER";

/// <p>The classic pages whose operations this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.User,%CSP.UI.Portal.Dialog.SchemaPriv,%CSP.UI.Portal.Dialog.MLConfigurationPriv,%CSP.UI.Portal.Dialog.ColumnPriv";

}
