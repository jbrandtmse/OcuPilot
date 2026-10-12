/// <p>The Doc DB applications' port (AD-27, AD-52, Story 18.30): <class>OcuPilot.Port.NamespacePort</class> with the
/// vendor's <code>DocDB</code> endpoint as its one mapping endpoint, and every other call the admin port's own,
/// unchanged. It names no vendor class.</p>
/// <p><b>A record's composite id is split here.</b> <code>DocDB</code> addresses a record by the <code>namespace</code>
/// and <code>name</code> queries, while the product carries one id, <code>[Namespace, Name]</code> joined by
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, under <code>name</code>. The namespace part is sent
/// upper-cased, the spelling the instance stores, and the name part as it is, so a create stores the name exactly as
/// typed (measured at Story 18.30's plan: a <code>PUT</code> naming an existing record in another case changes it
/// and keeps its stored name). An id that is not exactly two non-empty parts names no record: 404
/// <code>PORT.NOTFOUND</code>, and the vendor is not called.</p>
/// <p><b>Caller contract:</b> <method>OcuPilot.Port.NamespacePort.Invoke</method>'s. A <code>LIST</code> carries no
/// <code>name</code> and is read through <class>OcuPilot.Port.AdminPort</class> (the screen's declared
/// read).</p>
Class OcuPilot.Port.DocDbAppPort Extends OcuPilot.Port.NamespacePort
{

/// <p>The endpoint whose composite id this port splits.</p>
Parameter MAPPINGENDPOINTS = "DocDB";

}
