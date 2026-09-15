/// <p>One agent definition -- the provider, model, endpoint, credential reference and tuning a
/// turn is run with -- held in OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods (AD-9).</p>
/// <p><b>The schema's defining feature is an absence: there is no <code>ApiKey</code>
/// property</b> (AD-35), and none of the methods here takes or returns a credential value.
/// What is stored is the credential's <i>type</i> and its <i>name</i>; resolving the name to a
/// secret is Story 3.3's ladder, and nothing on this class can be made to carry the secret
/// itself. <class>OcuPilot.Test.AgentSchema</class> locks the absence.</p>
/// <p>Named scalars only -- no <code>list Of</code>, no relationship, no property typed as a
/// persistent class -- per the persistent-storage rule, and no hand-written Storage: the
/// compiler owns that section. The credential reference is two scalars rather than an entity
/// reference key because its scope is implied and constant and it crosses no boundary (AD-37);
/// a name that no longer resolves must still read back verbatim.</p>
/// <p><b>The class name is 27 characters</b> against the 29-character cap
/// <file>scripts/check-objectscript.py</file> enforces on any class reaching
/// <class>%Persistent</class>. The more obvious <code>...State.AgentDef</code> is 30 and would
/// make the compiler hash this class's storage global.</p>
/// <p><b>Exactly one definition carries <property>DefaultMark</property>, enforced by a unique
/// index rather than by convention.</b> A <code>[ Unique ]</code> index accepts repeated
/// empty-string values and refuses the second non-empty duplicate (probed on this instance,
/// IRIS for Health 2026.2, 2026-09-15: three rows saved with <code>""</code> all succeeded and
/// the second row carrying <code>"1"</code> returned <code>ERROR #5808: Key not unique</code>).
/// So <code>""</code> for every ordinary definition and <code>"1"</code> for the default makes
/// "at most one" a storage-layer fact. "At least one" is
/// <method>GuardedRebalanceDefault</method>'s, and "which one is in force" is
/// <method>ResolveDefault</method>'s, which answers only while the marked definition is
/// enabled.</p>
Class OcuPilot.Kernel.State.Agent Extends OcuPilot.Kernel.State.Base
{

/// <p>The definition's name, unique across definitions. Also the name a later story renders
/// in the switcher, so it is the operator's own label rather than a generated key.</p>
Property Name As %String(MAXLEN = 64);

/// <p>The provider key -- a row key in <class>OcuPilot.Kernel.Provider.Catalog</class>, which is
/// the only place in the tree that spells one.</p>
Property Provider As %String(MAXLEN = 32);

/// <p>The model identifier sent to the provider. Free text validated only for length: a model
/// released after this build must be usable without a code change.</p>
Property Model As %String(MAXLEN = 128);

/// <p>The provider endpoint. Validated to absolute HTTPS at this floor; AD-42's local exception,
/// its <code>MarkedLocal</code> companion and the resolved-address check are Story 3.2's.</p>
Property EndpointUrl As %String(MAXLEN = 512);

/// <p><code>env</code> or <code>creds</code> -- which rung of the credential ladder this
/// definition's secret is read from. The choice is stored here; reading it is Story 3.3's.</p>
Property CredType As %String(MAXLEN = 8);

/// <p>The environment variable holding the secret, when <property>CredType</property> is
/// <code>env</code>; <code>""</code> otherwise (the XOR invariant clears the unselected one).</p>
Property EnvVarName As %String(MAXLEN = 128);

/// <p>The credential entry holding the secret, when <property>CredType</property> is
/// <code>creds</code>; <code>""</code> otherwise. A weak reference (AD-37): a name that resolves
/// to nothing on this instance still reads back verbatim and fails no read.</p>
Property CredentialName As %String(MAXLEN = 128);

/// <p>Maximum tokens per provider call, 1-32000.</p>
Property MaxTokens As %Integer [ InitialExpression = 32000 ];

/// <p>Sampling temperature, 0-2.</p>
Property Temperature As %Numeric(SCALE = 2) [ InitialExpression = 0 ];

/// <p>Maximum tool-calling iterations within one turn, 1-100.</p>
Property MaxIterationsPerTurn As %Integer [ InitialExpression = 10 ];

/// <p>An operator's replacement for the built-in system prompt, up to 8192 characters;
/// <code>""</code> leaves the built-in one in force.</p>
Property SystemPromptOverride As %String(MAXLEN = 8192);

/// <p>Whether this definition may only run read tools. <b>Stored here and enforced in Story
/// 3.7</b>, which is the single enforcement point; nothing here reads it as a gate.</p>
Property ReadOnly As %Boolean [ InitialExpression = 1 ];

/// <p>How many days of this definition's conversation history are kept, 1-365. Inert until
/// Story 14.4 enables the field and ships the purge task.</p>
Property RetentionDays As %Integer [ InitialExpression = 30 ];

/// <p>Whether this definition may serve a turn. A definition is created disabled, and a save
/// that changes a security-relevant field disables it again
/// (<method>GuardedUpdate</method>).</p>
Property Enabled As %Boolean [ InitialExpression = 0 ];

/// <p>Whether Test connection has succeeded against this definition <b>as currently
/// configured</b>. Story 3.4 is the only writer that sets it; every path here only ever clears
/// it.</p>
Property ConnectionVerified As %Boolean [ InitialExpression = 0 ];

/// <p><code>"1"</code> on the default definition and <code>""</code> on every other. Read
/// through <method>ResolveDefault</method>, never as a gate of its own.</p>
Property DefaultMark As %String(MAXLEN = 1);

/// <p>ISO-8601 UTC timestamp of creation (Consistency Conventions: Dates).</p>
Property CreatedAt As %String(MAXLEN = 32);

/// <p>ISO-8601 UTC timestamp of the last write to this row.</p>
Property UpdatedAt As %String(MAXLEN = 32);

Index NameIdx On Name [ Unique ];

Index DefaultIdx On DefaultMark [ Unique ];

/// <p>The fields whose change disables a definition (AC5): the provider, the endpoint and the
/// three that name where the secret comes from. Declared once, and read by both
/// <method>SnapshotSecurityFields</method> and <method>GuardedUpdate</method>, so the snapshot
/// and the comparison cannot drift apart.</p>
ClassMethod SecurityFields() As %List
{
    Quit $ListBuild("Provider", "EndpointUrl", "CredType", "EnvVarName", "CredentialName")
}

/// <p>Record <var>pObject</var>'s security-relevant values, before a caller edits it, into
/// <var>pSnapshot</var> subscripted by property name. <b>Caller contract:</b> take the snapshot
/// before applying any change, and hand the same array back to
/// <method>GuardedUpdate</method>.</p>
ClassMethod SnapshotSecurityFields(pObject As OcuPilot.Kernel.State.Agent, Output pSnapshot)
{
    Kill pSnapshot
    Set tFields = ..SecurityFields()
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
        Set pSnapshot(tField) = $Property(pObject, tField)
    }
}

/// <p>ISO-8601 UTC, e.g. <code>2026-09-15T10:30:45Z</code> -- <code>$ZTimeStamp</code>, never
/// <code>$Horolog</code>, and never raw <code>$ZDateTime</code>, which is space-separated.</p>
ClassMethod Timestamp() As %String
{
    Quit $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
}

/// <p>Save <var>pObject</var> as a new definition through the escalated frame, stamp its two
/// timestamps, and settle the default marker afterwards. A definition is never created marked:
/// <method>GuardedRebalanceDefault</method> decides, so the first definition on an instance
/// takes the marker and a later one does not.</p>
/// <p><var>pObject</var>'s <property>DefaultMark</property> reads the stored truth when this
/// returns, so a caller can project the row without re-reading it.</p>
ClassMethod GuardedCreate(pObject As OcuPilot.Kernel.State.Agent) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tNow = ..Timestamp()
        Set pObject.CreatedAt = tNow
        Set pObject.UpdatedAt = tNow
        Set pObject.DefaultMark = ""
        Set tSC = ..GuardedSave(pObject)
        If $$$ISERR(tSC) Quit
        Set tSC = ..GuardedRebalanceDefault()
        If $$$ISERR(tSC) Quit
        Set tSC = ..RefreshMark(pObject)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Save <var>pObject</var>'s edits through the escalated frame. <var>pSnapshot</var> is what
/// <method>SnapshotSecurityFields</method> recorded before the edit.</p>
/// <p><b>A change to any field <method>SecurityFields</method> names clears both
/// <property>ConnectionVerified</property> and <property>Enabled</property></b> (AC5). That is
/// the outcome, not a refusal: an operator who repoints a definition at another provider,
/// endpoint or credential gets a definition that no longer serves turns until Story 3.4's Test
/// connection clears it again. A change to anything else -- the model among them -- leaves both
/// flags alone.</p>
ClassMethod GuardedUpdate(pObject As OcuPilot.Kernel.State.Agent, ByRef pSnapshot) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tChanged = 0
        Set tFields = ..SecurityFields()
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            If $Property(pObject, tField) '= $Get(pSnapshot(tField)) Set tChanged = 1
        }
        If tChanged {
            Set pObject.ConnectionVerified = 0
            Set pObject.Enabled = 0
        }
        Set pObject.UpdatedAt = ..Timestamp()
        Set tSC = ..GuardedSave(pObject)
        If $$$ISERR(tSC) Quit
        Set tSC = ..GuardedRebalanceDefault()
        If $$$ISERR(tSC) Quit
        Set tSC = ..RefreshMark(pObject)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the definition <var>pId</var> through the escalated frame and settle the marker
/// afterwards, so "exactly one is marked while any definition exists" survives the deletion of
/// the marked one (DW-20).</p>
ClassMethod GuardedDeleteId(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Agent WHERE ID = ?", pId)
        If $$$ISERR(tSC) Quit
        Set tSC = ..GuardedRebalanceDefault()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every definition's id, in creation order, through the escalated frame.
/// <var>pIds</var> comes back as <code>pIds(1)</code>, <code>pIds(2)</code>, ... and is simply
/// absent when the instance holds no definitions -- the configuration-empty state, never an
/// error.</p>
ClassMethod GuardedList(Output pIds) As %Status
{
    Quit ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.Agent ORDER BY ID", .pIds)
}

/// <p>The id of the definition named <var>pName</var>, or <code>""</code> when none holds it.</p>
/// <p><b>Matched the way the unique index matches</b>, which is case-insensitively: IRIS SQL
/// string comparison folds case by default and <code>NameIdx</code> collates the same way, so a
/// name differing only in case is the duplicate the index would refuse. That is what lets the
/// duplicate rule answer first, with a field the caller can act on, instead of leaving the save
/// to fail with <code>#5808</code>.</p>
ClassMethod GuardedByName(pName As %String, Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = ..GuardedIdsWhere("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Agent WHERE Name = ? ORDER BY ID", pName, .tIds)
    If $$$ISOK(tSC) Set pId = $Get(tIds(1), "")
    Quit tSC
}

/// <p>Move the default marker to <var>pId</var>, in one transaction, <b>clearing the old marker
/// before setting the new one</b>. The other order collides with
/// <code>DefaultIdx</code> and raises <code>#5808</code> on a legitimate request, so the order
/// is the implementation rather than a preference.</p>
ClassMethod SetDefaultGuarded(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tInTx = 0
    Try {
        Set tSC = ..GuardedExistsId(pId, .tExists)
        If $$$ISERR(tSC) Quit
        If 'tExists {
            Set tSC = $$$ERROR($$$GeneralError, "No such agent definition: " _ pId)
            Quit
        }
        Set tSC = ..GuardedMarkedId(.tMarked)
        If $$$ISERR(tSC) Quit
        If tMarked = pId Quit
        TSTART
        Set tInTx = 1
        If tMarked '= "" {
            Set tSC = ..MarkRow(tMarked, "")
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ..MarkRow(pId, "1")
        If $$$ISERR(tSC) Quit
        TCOMMIT
        Set tInTx = 0
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tInTx {
        TROLLBACK 1
    }
    Quit tSC
}

/// <p>The definition in force: the marked one, and only while it is enabled.
/// <var>pId</var> is <code>""</code> when nothing is marked, or when the marked definition is
/// disabled -- the configuration-empty state Story 3.6's first-login gate triggers on, never a
/// failure.</p>
ClassMethod ResolveDefault(Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = ..GuardedIdsWhereNoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1' AND Enabled = 1 ORDER BY ID", .tIds)
    If $$$ISOK(tSC) Set pId = $Get(tIds(1), "")
    Quit tSC
}

/// <p>Settle the default marker after a create, an update or a delete (DW-20). Three outcomes,
/// and the tie-break is the <b>lowest id</b> -- creation order, which needs no extra column and
/// is the same rule a reader can verify from a list:</p>
/// <ol>
/// <li>Nothing is marked and at least one definition exists: the lowest-id enabled definition
/// takes the marker, or, when none is enabled, the lowest-id definition of any kind. That is
/// what makes the first definition on an instance the default without a separate act, and what
/// moves the marker when the marked definition is deleted.</li>
/// <li>The marked definition is disabled and an enabled peer exists: the marker moves to the
/// lowest-id enabled peer.</li>
/// <li>The marked definition is disabled and no peer is enabled: <b>the marker stays</b> and
/// <method>ResolveDefault</method> answers <code>""</code>. Not a failure -- it is precisely the
/// configuration-empty state, and it is why default and enabled are orthogonal flags rather than
/// one.</li>
/// </ol>
ClassMethod GuardedRebalanceDefault() As %Status
{
    Set tSC = $$$OK
    Set tInTx = 0
    Try {
        Set tTarget = ""
        Set tClear = ""
        Set tSC = ..GuardedMarkedId(.tMarked)
        If $$$ISERR(tSC) Quit
        If tMarked = "" {
            Set tSC = ..GuardedFirstEnabledId(.tTarget)
            If $$$ISERR(tSC) Quit
            If tTarget = "" {
                Set tSC = ..GuardedFirstId(.tTarget)
                If $$$ISERR(tSC) Quit
            }
        } Else {
            Set tSC = ..GuardedOpenId(tMarked, .tMarkedRow)
            If $$$ISERR(tSC) Quit
            If tMarkedRow.Enabled Quit
            Set tSC = ..GuardedFirstEnabledId(.tTarget)
            If $$$ISERR(tSC) Quit
            If tTarget = "" Quit
            Set tClear = tMarked
        }
        If tTarget = "" Quit
        TSTART
        Set tInTx = 1
        If tClear '= "" {
            Set tSC = ..MarkRow(tClear, "")
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ..MarkRow(tTarget, "1")
        If $$$ISERR(tSC) Quit
        TCOMMIT
        Set tInTx = 0
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tInTx {
        TROLLBACK 1
    }
    Quit tSC
}

/// <p>Set <var>pObject</var>'s <property>DefaultMark</property> to what the instance actually
/// holds, so a caller that just created or updated a definition can project the row without
/// re-reading it and without depending on which in-memory instance
/// <method>%OpenId</method> handed back.</p>
ClassMethod RefreshMark(pObject As OcuPilot.Kernel.State.Agent) As %Status [ Private ]
{
    Set tSC = ..GuardedMarkedId(.tMarked)
    If $$$ISERR(tSC) Quit tSC
    Set pObject.DefaultMark = $Select(tMarked = pObject.%Id(): "1", 1: "")
    Quit tSC
}

/// <p>Write <var>pMark</var> to definition <var>pId</var>'s marker through the object layer, not
/// through SQL: a <code>%String</code> column set to <code>''</code> by a SQL
/// <code>UPDATE</code> reads back through the object layer as <code>$Char(0)</code>, which is a
/// non-empty one-character string that every ordinary emptiness guard passes
/// (<file>.claude/rules/objectscript-basics.md</file>).</p>
ClassMethod MarkRow(pId As %String, pMark As %String) As %Status [ Private ]
{
    Set tSC = ..GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    Set tRow.DefaultMark = pMark
    Set tRow.UpdatedAt = ..Timestamp()
    Quit ..GuardedSave(tRow)
}

/// <p>The id carrying the default marker, or <code>""</code>. Says nothing about whether that
/// definition is enabled -- <method>ResolveDefault</method> is the method that answers that.</p>
ClassMethod GuardedMarkedId(Output pId As %String) As %Status [ Private ]
{
    Set pId = ""
    Set tSC = ..GuardedIdsWhereNoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1' ORDER BY ID", .tIds)
    If $$$ISOK(tSC) Set pId = $Get(tIds(1), "")
    Quit tSC
}

/// <p>The lowest-id enabled definition's id, or <code>""</code> when none is enabled.</p>
ClassMethod GuardedFirstEnabledId(Output pId As %String) As %Status [ Private ]
{
    Set pId = ""
    Set tSC = ..GuardedIdsWhereNoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Agent WHERE Enabled = 1 ORDER BY ID", .tIds)
    If $$$ISOK(tSC) Set pId = $Get(tIds(1), "")
    Quit tSC
}

/// <p>The lowest-id definition's id, enabled or not, or <code>""</code> when the instance holds
/// none.</p>
ClassMethod GuardedFirstId(Output pId As %String) As %Status [ Private ]
{
    Set pId = ""
    Set tSC = ..GuardedIdsWhereNoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Agent ORDER BY ID", .tIds)
    If $$$ISOK(tSC) Set pId = $Get(tIds(1), "")
    Quit tSC
}

}
