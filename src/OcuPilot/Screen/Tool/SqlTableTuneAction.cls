/// <p>The base of the statistics writes that take declared values (Story 21.25, AD-6, AD-10, AD-21, AD-51, AD-53, AD-56): the collection of every
/// table's statistics in a schema, through <class>OcuPilot.Port.SqlPort</class>'s <code>Tables</code> endpoint. Each value named in
/// <parameter>VALUENAMES</parameter> is a declared argument of the kind <method>OcuPilot.Screen.Tool.SqlStatementAction.ValueType</method> names, a
/// boolean here, <code>true</code> or <code>false</code>, which reaches the port in its query and is part of the fingerprint's subject, so a confirm
/// writes the values the person reviewed. Each is required unless <parameter>REQUIREDVALUES</parameter> names the required ones. The machinery that
/// carries the values is <class>OcuPilot.Screen.Tool.SqlStatementAction</class>'s.</p>
/// <p>The fresh read answers each value as <code>null</code>, so the merge of the arguments makes a row on the card for each value and the stored payload
/// carries every one.</p>
Class OcuPilot.Screen.Tool.SqlTableTuneAction Extends OcuPilot.Screen.Tool.SqlTableAction [ Abstract ]
{

/// <p>The arguments this tool admits, comma-separated, in the order the dialog draws them.</p>
Parameter VALUENAMES = "ClearValues";

/// <p>The description the input schema gives each of the arguments, as <code>name=description</code> entries separated by <code>|</code>.</p>
Parameter VALUEDESCRIPTIONS = "ClearValues=true also clears the fixed selectivity and extent size saved for each table, so the optimizer uses the collected ones.";

}
