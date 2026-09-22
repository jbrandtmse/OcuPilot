/// <p>The auditing configuration's write tool (AD-6, AD-10, FR-47): propose turning this instance's
/// auditing on or off. It reads the setting fresh through the vendor's own
/// <code>Security.Audit.Enabled</code> <code>GET</code>, merges the one argument over that object,
/// and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>It is declared destructive and is deliberately outside the prohibited set.</b> AD-10
/// refuses a write by effect, and turning auditing off is a change an operator is entitled to make
/// -- the product's answer to it is the card's warning, the recorded drop and the banner, not a
/// refusal. What the declaration buys is the card's destructive treatment now and Story 14.7's
/// typed-name field later, from one place rather than from a kernel list naming tools.</p>
/// <p><b>Its marker cannot land, and that is a physical constraint</b> (AD-15 as amended
/// 2026-09-21). The marker is emitted at one site in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> after the write reads OK, and by
/// then the database that would record it is closed. The drop is recorded rather than silent: the
/// ledger row reads not-marked, the tool-call line reads "done - audit not marked", and the panel
/// banner turns on until a re-enable's marker lands.</p>
/// <p><b>The target is a singleton, and the id argument exists to key the lock.</b>
/// <method>OcuPilot.Screen.Tool.Write.View</method> is <code>Final</code> and takes the target id
/// from a required schema property, so the model must send one;
/// <class>OcuPilot.Kernel.EntityRef</class>'s <code>singleton</code> rule folds every spelling to
/// one key, which is what gives AD-34's per-target lock and its sibling cancel one target to hold.
/// Measured on <code>ocupilot-ci</code>, 2026-09-21: the endpoint ignores query parameters
/// entirely, so the id reaches the vendor as nothing at all.</p>
/// <p><b>It admits the one field its classified field list carries</b>, the derived
/// <code>Enabled</code> boolean (AD-3). The field list for this endpoint was already committed by
/// Story 2.2's derivation; <class>OcuPilot.Screen.Tool.Classification</class> is where it becomes
/// <code>ordinary</code>.</p>
Class OcuPilot.Screen.Tool.AuditingUpdate Extends OcuPilot.Screen.Tool.Write
{

/// <p>Fixed by <parameter>OcuPilot.Kernel.Proposal.Mint.AUDITINGTOOL</parameter>, which is what the
/// kernel's auditing-off warning predicate matches on;
/// <class>OcuPilot.Test.ProposalWire</class> asserts the two equal against this parameter rather
/// than against the kernel's.</p>
Parameter TOOLNAME = "security.auditing.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter DESCRIPTION = "Propose turning this instance's auditing on or off. It changes nothing by itself: it answers a proposal the user reviews and confirms. Turning auditing off stops every change on this instance being recorded in the audit database, including the agent's own writes, so say so plainly in the rationale. The target is the instance's auditing configuration, which has exactly one instance.";

/// <p>The one derived top-level field this tool admits: the instance-wide auditing flag, which is
/// also the one field <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>
/// permits a change to for this entity type. A test asserts the two agree; the kernel is never read
/// from here.</p>
Parameter PERMITTEDFIELDS = "Enabled";

/// <p>The pair a change to the auditing configuration requires: <code>%Admin_Secure:USE</code>,
/// which is the vendor endpoint's own <code>ResourcesOR()</code> resource, and exactly the pair
/// <class>OcuPilot.Screen.Descriptor.AuditingConfig</class> already declares for itself -- so the
/// resolved set is the screen's two pairs and nothing else, and no permission an IRIS-shipped role
/// does not grant appears on the path (AD-8 as amended 2026-09-21).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>Declared destructive: turning auditing off removes the instance's own record of every change
/// made while it is off, and no later write puts those rows back.</p>
/// <p>This flag governs the <b>agent's proposal card</b>. The auditing screen's own confirm
/// dialog is a different surface, and EXPERIENCE.md's <code>confirm-dialog</code> row gives it a
/// <code>button-primary</code> warning rather than a destructive bar (Story 7.4); the two
/// statements are about two surfaces and both hold.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

ClassMethod Endpoint() As %String
{
    Quit "Security.Audit.Enabled"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level literals of this
/// tool's own field-list entry (AD-3), which is <parameter>PERMITTEDFIELDS</parameter>'s one
/// field.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a derived field the prohibited set has not
/// reviewed is absent from the schema and from <method>SettableFields</method> whether or not
/// anybody has thought to exclude it by name.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the identifying property's description replaced: the target is the
/// instance's one auditing configuration, and the value to send is
/// <parameter>OcuPilot.Kernel.EntityRef.RULESINGLETONID</parameter>.</p>
/// <p>The description guides the model; the id rule is what <b>guarantees</b> the key, because
/// every other spelling canonicalizes to the same one. A schema <code>enum</code> is deliberately
/// not used: whether <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method> honours one
/// has not been measured, and a constraint the validator ignores reads as a guarantee that is not
/// there.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one auditing configuration, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'. Any other spelling names the same configuration.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>, which unions the declared set with the
/// classic page's custom resource) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended only when
/// the screen does not already declare it so the ledger row's pair column records one check
/// once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
