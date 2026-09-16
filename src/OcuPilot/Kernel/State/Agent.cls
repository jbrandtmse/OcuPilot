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

/// <p>The provider endpoint. Absolute HTTPS, or absolute HTTP when
/// <property>MarkedLocal</property> licenses it; its resolved address is checked against AD-42's
/// refused ranges both here and again at the moment of the call.</p>
Property EndpointUrl As %String(MAXLEN = 512);

/// <p>Whether this definition's endpoint is declared to be a local address (AD-42). <b>It
/// licenses exactly two things</b>: a plain <code>http://</code> endpoint, and an endpoint whose
/// resolved address is loopback or one of this instance's own interface addresses. It licenses
/// nothing in the link-local range, which is refused whatever this flag says.</p>
/// <p>It is a request, not a grant: it takes effect only on a provider whose catalog row sets
/// <code>allowsLocal</code>, and Release 1's one row does not, so setting it on a shipped
/// definition is a validation failure rather than an escape.</p>
Property MarkedLocal As %Boolean [ InitialExpression = 0 ];

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

/// <p>Whether <b>OcuPilot</b> put the key behind <property>CredentialName</property> -- set when
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method> reports that it created the entry rather
/// than overwriting one that was already there.</p>
/// <p><b>It is the ownership half of AD-37's bounded exception</b>: an entry OcuPilot created is
/// removed when the last definition naming it goes, and an entry it did not create is never
/// touched. Without it the delete path cannot tell a reference an operator pointed at their own
/// credential entry from one this product minted, and the safe answer for the first is to leave it
/// alone.</p>
/// <p>It records provenance, never a value (AD-35): a flag has nowhere to put a secret.</p>
Property CredentialCreated As %Boolean [ InitialExpression = 0 ];

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
/// configured</b>. <method>GuardedSetVerification</method> is the only method that sets it, and
/// Story 3.4's route is its only caller; every other path here clears it.</p>
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

/// <p>The sentence <method>SetDefaultGuarded</method> refuses a disabled definition with (DW-330).
/// A parameter rather than a literal so the refusal and anything that checks for it name the same
/// text rather than two copies of it.</p>
Parameter DEFAULTDISABLEDREASON = "The default marker names the agent definition in force, and this one is not enabled";

/// <p>The fields whose change disables a definition (AC5): the provider, the endpoint, the flag
/// that licenses where that endpoint may point, and the three that name where the secret comes
/// from. Declared once, and read by both <method>SnapshotSecurityFields</method> and
/// <method>GuardedUpdate</method>, so the snapshot and the comparison cannot drift apart.</p>
/// <p><property>MarkedLocal</property> belongs here because it changes which addresses the
/// endpoint may resolve to: turning it on widens the definition's egress, and a definition whose
/// egress widened has not been verified as configured.</p>
ClassMethod SecurityFields() As %List
{
    Quit $ListBuild("Provider", "EndpointUrl", "MarkedLocal", "CredType", "EnvVarName", "CredentialName")
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
/// <p><b>The save is conditional on the row's version</b> (Consistency Conventions: concurrent
/// writes to OcuPilot's own state). <var>pExpectedVersion</var> is for a caller that read the row
/// earlier than this call and held the version it saw across slow work -- Test connection's
/// provider call is the one that does. Left <code>""</code> the version <var>pObject</var> itself
/// carries is used, which is the version the open that produced it read.</p>
ClassMethod GuardedUpdate(pObject As OcuPilot.Kernel.State.Agent, ByRef pSnapshot, pExpectedVersion As %String = "") As %Status
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
        ; The ownership mark belongs to the reference it was recorded against. A definition
        ; repointed at another entry owns nothing behind the new name until a store there says so,
        ; and a mark carried over would license removing an entry OcuPilot never created (AD-37).
        If pObject.CredentialName '= $Get(pSnapshot("CredentialName")) Set pObject.CredentialCreated = 0
        Set pObject.UpdatedAt = ..Timestamp()
        Set tSC = ..GuardedSaveIfCurrent(pObject, $Select(pExpectedVersion '= "": +pExpectedVersion, 1: +pObject.RowVersion))
        If $$$ISERR(tSC) Quit
        Set tSC = ..GuardedRebalanceDefault()
        If $$$ISERR(tSC) Quit
        Set tSC = ..RefreshMark(pObject)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Clear definition <var>pId</var>'s <property>ConnectionVerified</property> and
/// <property>Enabled</property>, so it serves no turn until Test connection succeeds against it
/// again.</p>
/// <p>Two callers, one home: <method>OcuPilot.Api.Definitions.HandleStoreCredential</method>, which
/// stored a new key behind the reference the definition was verified with, and
/// <method>OcuPilot.Port.ProviderPort.Invoke</method>, which found the reference no longer resolves
/// (DW-22). It goes through <method>GuardedUpdate</method> with the security snapshot taken first,
/// so the timestamp and the default rebalance stay where every other write puts them and no field
/// reads as changed.</p>
/// <p><b>This is a write to OcuPilot's own protected state, not a mutation of the instance</b>
/// (AD-7 as amended, AD-9). A caller holding no administrative privilege can reach it through a
/// turn, which is intended: a definition whose credential cannot be resolved serves nobody.</p>
ClassMethod GuardedClearVerification(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedOpenId(pId, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) {
            Set tSC = $$$ERROR($$$GeneralError, "No agent definition with id " _ pId)
            Quit
        }
        Do ..SnapshotSecurityFields(tRow, .tSnapshot)
        Set tRow.ConnectionVerified = 0
        Set tRow.Enabled = 0
        Set tSC = ..GuardedUpdate(tRow, .tSnapshot)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Record that Test connection succeeded against definition <var>pId</var> as it is stored:
/// set <property>ConnectionVerified</property>, leaving every other field as it was.</p>
/// <p>The mirror of <method>GuardedClearVerification</method>, and written the same way -- open,
/// snapshot the security fields, set the flag, save through <method>GuardedUpdate</method> -- so
/// the timestamp and the default rebalance stay where every other write puts them and no field
/// reads as changed.</p>
/// <p><b>It never touches <property>Enabled</property>.</b> Enabling is a separate act the
/// operator takes, which the enable rule then permits
/// (<method>OcuPilot.Kernel.AgentRules.Validate</method>).</p>
/// <p><b>Caller contract:</b> the values tested must be the stored ones. A test of edited values
/// says nothing about the row, so <method>OcuPilot.Api.Definitions.HandleTest</method> compares
/// the merged values against the row before it calls this.</p>
/// <p><b><var>pExpectedVersion</var> is what makes "the values tested must be the stored ones"
/// hold across the call rather than only before it</b> (DW-362). A caller that read the row,
/// spent a provider round trip and then arrived here hands back the version it read; a row that
/// moved in between refuses, so no verification is recorded against a definition somebody edited
/// while the call was in flight. Left <code>""</code> the row's current version is used, which
/// checks nothing and is the pre-existing behaviour.</p>
ClassMethod GuardedSetVerification(pId As %String, pExpectedVersion As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedOpenId(pId, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) {
            Set tSC = $$$ERROR($$$GeneralError, "No agent definition with id " _ pId)
            Quit
        }
        Do ..SnapshotSecurityFields(tRow, .tSnapshot)
        Set tRow.ConnectionVerified = 1
        Set tSC = ..GuardedUpdate(tRow, .tSnapshot, pExpectedVersion)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Record that OcuPilot created the credential entry definition <var>pId</var> names: set
/// <property>CredentialCreated</property>, leaving every other field as it was.</p>
/// <p>Written the way <method>GuardedSetVerification</method> is -- open, snapshot the security
/// fields, set the flag, save through <method>GuardedUpdate</method> -- so the timestamp and the
/// default rebalance stay where every other write puts them and no field reads as changed.</p>
/// <p><b>Caller contract:</b> call it only where
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method> reported that it brought the entry into
/// being. This method records the claim; it does not check it.</p>
ClassMethod GuardedMarkCredentialCreated(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedOpenId(pId, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) {
            Set tSC = $$$ERROR($$$GeneralError, "No agent definition with id " _ pId)
            Quit
        }
        Do ..SnapshotSecurityFields(tRow, .tSnapshot)
        Set tRow.CredentialCreated = 1
        Set tSC = ..GuardedUpdate(tRow, .tSnapshot)
        Set tRow = ""
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

/// <p>The ids of every definition <b>other than</b> <var>pExceptId</var> whose
/// <property>CredentialName</property> is <var>pName</var> -- the sibling query AD-37's bounded
/// exception turns on: an entry a surviving definition still names is never removed.</p>
/// <p><var>pIds</var> comes back as <code>pIds(1)</code>, <code>pIds(2)</code>, ... and is simply
/// absent when no sibling names the reference, which is the ordinary answer rather than an
/// error.</p>
/// <p><b>Matched the way the store matches</b>: IRIS SQL folds case by default, and the credential
/// entry's own id does too, so two definitions whose references differ only in case name the same
/// entry and are siblings here.</p>
/// <p>It runs over <method>OcuPilot.Kernel.State.Base.GuardedIdsWhere</method>, the one-parameter
/// id query the package already has; <var>pExceptId</var> is dropped from the answer here rather
/// than bound into a second placeholder, so no seam is widened for one caller. An empty
/// <var>pName</var> matches nothing and is answered without a query.</p>
ClassMethod GuardedIdsByCredentialName(pName As %String, pExceptId As %String = "", Output pIds) As %Status
{
    Kill pIds
    If pName = "" Quit $$$OK
    Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Agent WHERE CredentialName = ? ORDER BY ID", pName, .tAll)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tAll) {
        If tAll(tI) = pExceptId Continue
        Set pIds($Increment(pIds)) = tAll(tI)
    }
    Quit tSC
}

/// <p>The version definition <var>pId</var> currently carries, or <code>""</code> when no row
/// holds that id. The snapshot a caller that reads, does slow work and then writes hands back to
/// <method>GuardedSetVerification</method>.</p>
ClassMethod GuardedVersion(pId As %String, Output pVersion As %String) As %Status
{
    Set pVersion = ""
    Set tSC = ..GuardedExistsId(pId, .tExists)
    If $$$ISERR(tSC) Quit tSC
    If 'tExists Quit $$$OK
    Set tSC = ..GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tRow) Set pVersion = +tRow.RowVersion
    Set tRow = ""
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

/// <p>The six keys a screen row and the selection projection both carry -- id, name, provider,
/// model, enabled and default -- and <b>no more</b>.</p>
/// <p><b>This is the one declaration of that shape.</b>
/// <method>OcuPilot.Api.Definitions.SelectionProjection</method> answers it for the list route and
/// <method>GuardedScreenRows</method> answers it for the declared read (AD-36), so the switcher,
/// the Definitions list and its read tool cannot disagree about what a definition row is. It is
/// here rather than in the handler because the dependency only runs one way: the API may name the
/// kernel, and the screen layer may not name the API.</p>
/// <p>Each key is written with its JSON type, so a name or a model that reads as a number is a
/// JSON string in every projection rather than a number in one of them.</p>
/// <p><b>Nothing here can carry a secret</b> (AD-35): the six are identity, configuration
/// vocabulary and two flags, and the class has no property holding a credential value at all.</p>
ClassMethod ScreenRow(pObject As OcuPilot.Kernel.State.Agent) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("id", pObject.%Id(), "string")
    Do tOut.%Set("name", pObject.Name, "string")
    Do tOut.%Set("provider", pObject.Provider, "string")
    Do tOut.%Set("model", pObject.Model, "string")
    Do tOut.%Set("enabled", $Select(pObject.Enabled: 1, 1: 0), "boolean")
    Do tOut.%Set("default", $Select(pObject.DefaultMark = "1": 1, 1: 0), "boolean")
    Quit tOut
}

/// <p>Every definition as a <method>ScreenRow</method>, in the order
/// <method>GuardedList</method> answers -- the rows a descriptor-declared read over OcuPilot's own
/// protected state resolves to (AD-9, AD-36).</p>
/// <p><b>The contract a state-backed read source is resolved through.</b>
/// <method>OcuPilot.Screen.Read.Execute</method> asks a kernel store for this and applies the same
/// field projection, filter, sort, row cap and truncation signal it applies to a port answer, so
/// the second source kind changes where the rows come from and nothing else. A store that wants a
/// declared read implements this method and declares nothing else.</p>
/// <p><b>A row that cannot be opened is skipped rather than failing the read</b>, the way
/// <method>OcuPilot.Api.Definitions.HandleList</method> skips it: the id came from this instance's
/// own enumeration a moment ago, so a row that has gone was deleted between the two calls and is
/// not on the list any more.</p>
ClassMethod GuardedScreenRows(Output pRows As %DynamicArray) As %Status
{
    Set pRows = ""
    Set tSC = ..GuardedList(.tIds)
    If $$$ISERR(tSC) Quit tSC
    Set pRows = []
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) || '$IsObject(tRow) Continue
        Do pRows.%Push(..ScreenRow(tRow))
        Set tRow = ""
    }
    Quit $$$OK
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
/// <p><b>A definition that is not enabled is refused</b> (DW-330), with
/// <parameter>DEFAULTDISABLEDREASON</parameter> so a caller can tell this refusal from a read
/// failure. The marker means "the definition in force": <method>ResolveDefault</method> already
/// answers <code>""</code> for a disabled one, and <method>GuardedRebalanceDefault</method>'s
/// second case would move it away again on the next unrelated write, so an explicit set here
/// would record a claim the instance does not honour and does not keep. The marker that method
/// places on a disabled definition when no peer is enabled is a placeholder rather than a claim,
/// and is unaffected.</p>
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
        Set tSC = ..GuardedOpenId(pId, .tTarget)
        If $$$ISERR(tSC) Quit
        Set tOpened = $IsObject(tTarget)
        Set tEnabled = $Select(tOpened: ''tTarget.Enabled, 1: 0)
        Set tTarget = ""
        ; A row deleted between the existence check and this open is "no such definition", never
        ; "not enabled": the two refusals are what the reason below exists to keep apart.
        If 'tOpened {
            Set tSC = $$$ERROR($$$GeneralError, "No such agent definition: " _ pId)
            Quit
        }
        If 'tEnabled {
            Set tSC = $$$ERROR($$$GeneralError, ..#DEFAULTDISABLEDREASON)
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
