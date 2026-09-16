/// <p>The reviewed classification of every write tool's derived fields (AD-3). Hand-written, and
/// the only hand-written part of a write tool's field list: <file>ui/tools/field-lists.mjs</file>
/// joins each entry with the list it names in <class>OcuPilot.Screen.Tool.FieldLists</class> and
/// writes <class>OcuPilot.Screen.Tool.ToolFields</class>; <code>npm run build</code> fails on any
/// entry it refuses.</p>
/// <p><b>Grammar.</b> The block is one JSON object keyed by tool name
/// (<code>&lt;area&gt;.&lt;screen&gt;.&lt;verb&gt;</code>, lower case, dots only). Each entry holds
/// <code>fieldList</code>, a list key <class>OcuPilot.Screen.Tool.FieldLists</class> carries, and
/// <code>classification</code>, an object mapping a classifiable path of that list (a row no other
/// row's path extends) to <code>ordinary</code>, <code>secret</code> or <code>opaque</code>. The
/// keys <code>required</code>, <code>enum</code> and <code>description</code> are reserved for the
/// semantic half of a tool's schema and accept no content yet; no other key is accepted.</p>
/// <p><b>It fails closed.</b> A classifiable path the entry does not name is emitted
/// <code>secret</code>. <code>opaque</code> is for a member-less object or array only, and a
/// member-less object or array may not be <code>ordinary</code>. A string literal whose last path
/// segment matches the credential pattern (Conventions, Secrets) may be nothing but
/// <code>secret</code>.</p>
Class OcuPilot.Screen.Tool.Classification Extends %RegisteredObject
{

/// <p>The reviewed entries. No write tool exists yet.</p>
XData Entries
{
{
}
}

}
