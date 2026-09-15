/// <p>The handler behind the seven <code>/agent/definitions</code> routes -- the first mutating
/// surface in OcuPilot's API. One handler, one envelope, one gate, and one place Story 3.8 has to
/// reach to add the audit row.</p>
/// <p><b>Who may see what.</b> Every caller that reaches here has already cleared
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>: authenticated, and holding at least one
/// <code>%Admin_*</code> resource. On top of that, <b>reading one definition and every write</b>
/// require OcuPilot's own administrative resource, checked server-side through
/// <method>OcuPilot.Screen.Gate.HoldsPrivilege</method> at the moment of the call. The
/// <b>list</b> does not: it answers the selection projection -- name, provider, model, enabled,
/// default -- which is what the switcher needs and what every portal user may see (AD-46).</p>
/// <p><b>No response here ever carries a credential value</b> (AD-35). The full projection
/// carries the credential's <i>type</i> and its <i>name</i>, which is what the schema stores;
/// there is no property, no argument and no key that could carry the secret. The one route that
/// takes a key -- <method>HandleStoreCredential</method> -- is write-only and answers
/// <code>{"stored":true}</code>, so there is no read to pre-fill a field from.</p>
/// <p><b>A create takes the class's own defaults, and then the provider row's canonical values
/// for the four columns the catalog declares them for</b> -- model, endpoint, maximum tokens and
/// temperature -- but only for keys the body did not carry. A key sent as <code>""</code> is an
/// explicit empty value and is taken verbatim. An <b>update merges</b>: a key the body omits
/// keeps its stored value, so editing one field is a one-key body and cannot silently wipe the
/// rest.</p>
/// <p><b>This story emits no <code>$System.Security.Audit()</code> call.</b> An audit event whose
/// triple was never registered is dropped silently (AD-15), and Story 3.8 owns registration and
/// emission together. What every accepted write does here is compute the changed-field set and
/// hand it to <method>LogChange</method> -- the one seam 3.8 wires up, so that story adds the
/// audit row in one place rather than retrofitting six handlers.</p>
Class OcuPilot.Api.Definitions Extends %RegisteredObject
{

/// <p>The permission OcuPilot's administrative resource is required at.</p>
Parameter ADMINPERMISSION = "USE";

/// <p>The subsystem every definition change is logged under, and the name Story 3.8's audit
/// event type will carry.</p>
Parameter LOGSUBSYSTEM = "agent-definition";

/// <p>The one body member <code>POST /agent/definitions/:id/credential</code> reads, and the field
/// every one of its refusals lands on. Not a <method>Fields</method> entry: the definition has no
/// property to map it to, which is the absence AC1 pins.</p>
Parameter KEYFIELD = "apiKey";

/// <p>The verb a credential store's change record carries, and the one verb
/// <method>LogChange</method> classifies as a security change on its own account.</p>
Parameter CREDENTIALVERB = "credential";

/// <p>The field table: one entry per wire field, as
/// <code>$ListBuild(field, property, kind, writable)</code>. It is the single declaration of
/// which wire name maps to which property, how the value is typed on the wire
/// (<code>string</code> / <code>number</code> / <code>boolean</code>), and whether a request body
/// may set it.</p>
/// <p><code>connectionVerified</code>, <code>createdAt</code> and <code>updatedAt</code> are
/// <b>not writable</b>: the first is Story 3.4's alone, and the two timestamps are the state
/// class's. <code>id</code> and <code>default</code> are not here at all -- the id is the row's,
/// and the marker moves through its own route.</p>
ClassMethod Fields() As %List
{
    Quit $ListBuild($ListBuild("name", "Name", "string", 1), $ListBuild("provider", "Provider", "string", 1), $ListBuild("model", "Model", "string", 1), $ListBuild("endpointUrl", "EndpointUrl", "string", 1), $ListBuild("markedLocal", "MarkedLocal", "boolean", 1), $ListBuild("credType", "CredType", "string", 1), $ListBuild("envVarName", "EnvVarName", "string", 1), $ListBuild("credentialName", "CredentialName", "string", 1), $ListBuild("maxTokens", "MaxTokens", "number", 1), $ListBuild("temperature", "Temperature", "number", 1), $ListBuild("maxIterationsPerTurn", "MaxIterationsPerTurn", "number", 1), $ListBuild("systemPromptOverride", "SystemPromptOverride", "string", 1), $ListBuild("readOnly", "ReadOnly", "boolean", 1), $ListBuild("retentionDays", "RetentionDays", "number", 1), $ListBuild("enabled", "Enabled", "boolean", 1), $ListBuild("connectionVerified", "ConnectionVerified", "boolean", 0), $ListBuild("createdAt", "CreatedAt", "string", 0), $ListBuild("updatedAt", "UpdatedAt", "string", 0))
}

/// <p>The wire names of the fields whose change disables a definition -- the property names
/// <method>OcuPilot.Kernel.State.Agent.SecurityFields</method> declares, translated through
/// <method>Fields</method>.</p>
/// <p><b>Derived rather than written down</b>, so a field added to the state class's own list is a
/// security field here too. A property with no wire field is skipped: it cannot appear in a change
/// set, so it cannot classify one.</p>
ClassMethod SecurityFieldNames() As %List
{
    Set tNames = ""
    Set tSecurity = ##class(OcuPilot.Kernel.State.Agent).SecurityFields()
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        If $ListFind(tSecurity, $List(tEntry, 2)) Set tNames = tNames _ $ListBuild($List(tEntry, 1))
    }
    Quit tNames
}

/// <p>The four catalog columns a create falls back to when the body omits the field, as
/// <code>$ListBuild(field, catalogColumn)</code>. Declared here rather than inline so the set a
/// create defaults is one list a reader can check against
/// <class>OcuPilot.Kernel.Provider.Catalog</class>'s own columns.</p>
ClassMethod CatalogDefaults() As %List
{
    Quit $ListBuild($ListBuild("model", "defaultModel"), $ListBuild("endpointUrl", "defaultEndpoint"), $ListBuild("maxTokens", "canonicalMaxTokens"), $ListBuild("temperature", "canonicalTemperature"))
}

/// <p>The catalog class <method>ApplyCatalogDefaults</method> reads its canonical values from.
/// <b>Overridable</b> so a test can drive the fallback against a provider row whose canonical
/// tuning differs from the state class's own <code>InitialExpression</code>s -- against the
/// shipped row two of the four fallbacks land on the value the class already held, and a
/// fallback that cannot change anything cannot be shown to run. Production never overrides
/// it.</p>
ClassMethod CatalogClass() As %String
{
    Quit "OcuPilot.Kernel.Provider.Catalog"
}

/// <p>Answer <code>GET /agent/definitions</code>: every definition in creation order, each as the
/// selection projection. <b>No OcuPilot administrative privilege required</b> -- see the class
/// header.</p>
ClassMethod HandleList() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedList(.tIds)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tList = []
        For tI = 1:1:+$Get(tIds) {
            Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tIds(tI), .tRow)
            If $$$ISERR(tOpenSC) || '$IsObject(tRow) Continue
            Do tList.%Push(..SelectionProjection(tRow))
        }
        Set tBody = {}
        Do tBody.%Set("definitions", tList)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /agent/definitions/:id</code>: the full projection of one definition.</p>
ClassMethod HandleRead(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tSC = ..OpenDefinition(pId, .tRow, .tFound)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound(pId)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(..FullProjection(tRow))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /agent/definitions</code>: validate, then create. A definition is
/// <b>created disabled and unverified</b>, and takes the default marker only when it is the first
/// definition on the instance.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderBadBody(tReadSC)
            Quit
        }
        If '..BodyIsReadable(tBody) {
            Set tSC = ..RenderBadBody(..NotAnObject())
            Quit
        }
        Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
        Do ..ValuesFromRow(tRow, .tDefaults)
        Kill tValues
        Merge tValues = tDefaults
        Do ..MergeBody(tBody, .tValues, .tPresent)
        Do ..ApplyCatalogDefaults(.tValues, .tPresent)
        ; Server-owned on a create: only Story 3.4 ever sets this. Fields() already declares
        ; connectionVerified unwritable, so this is the braces to that belt, not the only guard.
        Set tValues("connectionVerified") = 0
        Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)
        If ##class(OcuPilot.Kernel.AgentRules).Validate(.tValues, "", .tViolations) {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        Do ..ApplyValues(tRow, .tValues)
        Set tCreateSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
        If $$$ISERR(tCreateSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The agent definition could not be saved", ##class(%Exception.StatusException).CreateFromStatus(tCreateSC))
            Quit
        }
        Do ..ValuesFromRow(tRow, .tAfter)
        Do ..LogChange("create", tRow.%Id(), .tDefaults, .tAfter)
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, ..FullProjection(tRow))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /agent/definitions/:id</code>: merge the body over the stored definition,
/// validate, then save. A change to the provider, the endpoint or any of the three credential
/// fields clears <code>connectionVerified</code> and <code>enabled</code>
/// (<method>OcuPilot.Kernel.State.Agent.GuardedUpdate</method>); a change to anything else leaves
/// both alone.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tOpenSC = ..OpenDefinition(pId, .tRow, .tFound)
        If $$$ISERR(tOpenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tOpenSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound(pId)
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderBadBody(tReadSC)
            Quit
        }
        If '..BodyIsReadable(tBody) {
            Set tSC = ..RenderBadBody(..NotAnObject())
            Quit
        }
        Do ..ValuesFromRow(tRow, .tBefore)
        Kill tValues
        Merge tValues = tBefore
        Do ..MergeBody(tBody, .tValues, .tPresent)
        ; Server-owned: the enable rule reads the definition's stored verification. Fields()
        ; already declares connectionVerified unwritable, so this is the braces to that belt.
        Set tValues("connectionVerified") = $Get(tBefore("connectionVerified"))
        Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)
        If ##class(OcuPilot.Kernel.AgentRules).Validate(.tValues, pId, .tViolations) {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
        Do ..ApplyValues(tRow, .tValues)
        Set tSaveSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
        If $$$ISERR(tSaveSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The agent definition could not be saved", ##class(%Exception.StatusException).CreateFromStatus(tSaveSC))
            Quit
        }
        Do ..ValuesFromRow(tRow, .tAfter)
        Do ..LogChange("update", pId, .tBefore, .tAfter)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(..FullProjection(tRow))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>DELETE /agent/definitions/:id</code>. When the deleted definition carried the
/// default marker, the marker moves to the lowest-id enabled definition, or to the lowest-id
/// remaining one when none is enabled (DW-20).</p>
ClassMethod HandleDelete(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tOpenSC = ..OpenDefinition(pId, .tRow, .tFound)
        If $$$ISERR(tOpenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tOpenSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound(pId)
            Quit
        }
        Do ..ValuesFromRow(tRow, .tBefore)
        Set tRow = ""
        Set tDeleteSC = ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(pId)
        If $$$ISERR(tDeleteSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The agent definition could not be deleted", ##class(%Exception.StatusException).CreateFromStatus(tDeleteSC))
            Quit
        }
        Kill tAfter
        Do ..LogChange("delete", pId, .tBefore, .tAfter)
        Set tBody = {}
        Do tBody.%Set("id", pId, "string")
        Do tBody.%Set("deleted", 1, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /agent/definitions/:id/default</code>: move the default marker to this
/// definition, cleared on the old row before it is set on the new one, in one transaction.</p>
ClassMethod HandleSetDefault(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tOpenSC = ..OpenDefinition(pId, .tRow, .tFound)
        If $$$ISERR(tOpenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tOpenSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound(pId)
            Quit
        }
        Do ..ValuesFromRow(tRow, .tBefore)
        Set tMarkSC = ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(pId)
        If $$$ISERR(tMarkSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The default agent definition could not be changed", ##class(%Exception.StatusException).CreateFromStatus(tMarkSC))
            Quit
        }
        Do ..ValuesFromRow(tRow, .tAfter)
        Do ..LogChange("default", pId, .tBefore, .tAfter)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(..FullProjection(tRow))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /agent/definitions/:id/credential</code>: put the key the body carries into
/// the credential store this definition's rung names, and answer <code>{"stored":true}</code>.</p>
/// <p><b>Write-only. No route ever returns a stored key</b>, and this one returns nothing of what it
/// was given (AD-35) -- which is what makes Story 3.5's never-pre-filled field possible.</p>
/// <p><b>The store clears <property>OcuPilot.Kernel.State.Agent.Enabled</property> and
/// <property>ConnectionVerified</property></b>, the same rule a change to the credential
/// <i>reference</i> already carries: the definition was verified against the key that was there
/// before, so Test connection must pass again.</p>
/// <p>The four refusals are evaluated in the order
/// <method>CredentialRefusal</method> declares, each a <code>{field, code}</code> violation on
/// <parameter>KEYFIELD</parameter> in the envelope Story 3.1 established. Nothing is written by the
/// time any of them answers.</p>
ClassMethod HandleStoreCredential(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tOpenSC = ..OpenDefinition(pId, .tRow, .tFound)
        If $$$ISERR(tOpenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tOpenSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound(pId)
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderBadBody(tReadSC)
            Quit
        }
        If '..BodyIsReadable(tBody) {
            Set tSC = ..RenderBadBody(..NotAnObject())
            Quit
        }
        Set tCode = ..CredentialRefusal(tRow, tBody)
        If tCode '= "" {
            Set tSC = ..RenderCredentialRefusal(tCode, $Select(tCode = ##class(OcuPilot.Api.Error).#AGENTKEYSHAPE: ..KeyPrefixOf(tRow.Provider), 1: ""))
            Quit
        }
        Set tStoreSC = $ClassMethod(..SecretClass(), "Store", tRow.CredentialName, tBody, ..#KEYFIELD)
        If $$$ISERR(tStoreSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The credential could not be stored", ##class(%Exception.StatusException).CreateFromStatus(tStoreSC))
            Quit
        }
        Do ..ValuesFromRow(tRow, .tBefore)
        ; Dropped before the flags are cleared and re-read afterwards, so the projection the change
        ; record diffs is the stored truth rather than whichever in-memory instance %OpenId handed
        ; back (.claude/rules/objectscript-basics.md).
        Set tRow = ""
        Set tClearSC = ##class(OcuPilot.Kernel.State.Agent).GuardedClearVerification(pId)
        If $$$ISERR(tClearSC) {
            ; The key is already behind the reference, so this is not "nothing was saved": the
            ; definition is still enabled against the key it replaced, and the reason says so
            ; rather than reading as a write that did not happen.
            Do ..LogChange(..#CREDENTIALVERB, pId, .tBefore, .tBefore)
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The key was stored, and the agent definition could not be disabled; run Test connection against it", ##class(%Exception.StatusException).CreateFromStatus(tClearSC))
            Quit
        }
        Kill tAfter
        Set tReopenSC = ..OpenDefinition(pId, .tAfterRow, .tAfterFound)
        If $$$ISOK(tReopenSC) && tAfterFound {
            Do ..ValuesFromRow(tAfterRow, .tAfter)
        } Else {
            ; A re-read that did not answer leaves the change record describing what the clear did,
            ; not an empty projection -- which would diff every field to "" and report the
            ; credential reference itself as blanked, on the one write that must not say that.
            Merge tAfter = tBefore
            Set tAfter("enabled") = 0
            Set tAfter("connectionVerified") = 0
        }
        Set tAfterRow = ""
        ; No value and no key-bearing field: the change set is built from the definition's own
        ; projection, which has nowhere to put a secret (AD-35).
        Do ..LogChange(..#CREDENTIALVERB, pId, .tBefore, .tAfter)
        Set tAnswer = {}
        Do tAnswer.%Set("stored", 1, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The violation code <var>pBody</var> earns against the definition <var>pRow</var>, or
/// <code>""</code> when the key may be stored. Declared order, and the order is the
/// implementation:</p>
/// <ol>
/// <li><code>AGENT.CREDENTIAL.REQUIRED</code> -- no <parameter>KEYFIELD</parameter> member, one
/// that is not a JSON string, or an empty one. An absent body names no field, which is how Story
/// 3.1 reads one.</li>
/// <li><code>AGENT.CREDENTIAL.ENVUNWRITABLE</code> -- the definition reads its secret from an
/// environment variable, and IRIS publishes no setter for one.</li>
/// <li><code>AGENT.CREDENTIAL.RUNGUNAVAILABLE</code> -- the credentials rung is not reachable from
/// this namespace, so there is nowhere to write.</li>
/// <li><code>AGENT.KEY.SHAPE</code> -- <b>last, because it needs a value and a reachable store</b>.
/// </li>
/// </ol>
/// <p>Its own public method rather than inline in the handler so
/// <class>OcuPilot.Test.AgentCredential</class> can drive the rung-unavailable row on an instance
/// whose rung is present -- which no request can reach.</p>
ClassMethod CredentialRefusal(pRow As OcuPilot.Kernel.State.Agent, pBody As %DynamicObject) As %String
{
    If '$IsObject(pBody) Quit ##class(OcuPilot.Api.Error).#AGENTCREDENTIALREQUIRED
    If 'pBody.%IsDefined(..#KEYFIELD) Quit ##class(OcuPilot.Api.Error).#AGENTCREDENTIALREQUIRED
    If pBody.%GetTypeOf(..#KEYFIELD) '= "string" Quit ##class(OcuPilot.Api.Error).#AGENTCREDENTIALREQUIRED
    ; Tested inside the comparison: the member is the key, and a local holding it is what an
    ; ^%ETN entry captures (AD-48).
    ; Stripped inside the comparison, never into a local: a pasted blank names no key, and the
    ; prefix gate below would pass one on a provider row that declares no prefix.
    If $ZStrip(pBody.%Get(..#KEYFIELD), "<>W") = "" Quit ##class(OcuPilot.Api.Error).#AGENTCREDENTIALREQUIRED
    If pRow.CredType = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPEENV Quit ##class(OcuPilot.Api.Error).#AGENTCREDENTIALENVUNWRITABLE
    If '$ClassMethod(..SecretClass(), "CredentialsRungAvailable") Quit ##class(OcuPilot.Api.Error).#AGENTCREDENTIALRUNGUNAVAILABLE
    If '..KeyShapeAccepted(pRow.Provider, pBody) Quit ##class(OcuPilot.Api.Error).#AGENTKEYSHAPE
    Quit ""
}

/// <p>Whether the key <var>pBody</var> carries has the shape <var>pProvider</var>'s adapter
/// requires, asked of the adapter itself through
/// <method>OcuPilot.Kernel.Provider.Base.IsApiKeyShapeValid</method>.</p>
/// <p><b>The seam is argument-free by design, and is reused rather than widened</b>: the credential
/// is read from the adapter's own property inside the comparison, so no frame binds it to a local
/// (AD-48). This method moves it member to property the same way, and clears the property on every
/// exit including the throwing one -- <method>OcuPilot.Kernel.Provider.Base.Invoke</method>'s
/// discipline, copied rather than re-invented.</p>
/// <p><b>A provider whose catalog row or adapter cannot be resolved refuses.</b> Rule 2 makes such
/// a definition unstorable, so this is the fail-closed answer to a state that should not exist
/// rather than a path an operator reaches.</p>
ClassMethod KeyShapeAccepted(pProvider As %String, pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set tValid = 0
    Set tAdapter = ""
    Try {
        If '$ClassMethod(..CatalogClass(), "Row", pProvider, .tRow) Quit
        If tRow.adapterClass = "" Quit
        If '##class(%Dictionary.CompiledClass).%ExistsId(tRow.adapterClass) Quit
        Set tAdapter = $ClassMethod(tRow.adapterClass, "%New")
        If '$IsObject(tAdapter) Quit
        If 'tAdapter.%IsA("OcuPilot.Kernel.Provider.Base") Quit
        Set tAdapter.KeyPrefix = tRow.keyPrefix
        Set tAdapter.ApiKey = pBody.%Get(..#KEYFIELD)
        Set tValid = tAdapter.IsApiKeyShapeValid()
        Set tAdapter.ApiKey = ""
    } Catch ex {
        Set tValid = 0
    }
    ; Runs on every exit, the throwing one included.
    Try {
        If $IsObject(tAdapter) Set tAdapter.ApiKey = ""
    } Catch clearEx {
    }
    Set tAdapter = ""
    Quit tValid
}

/// <p>The key prefix <var>pProvider</var>'s catalog row declares, or <code>""</code>. A table
/// entry, not a secret -- which is why the shape refusal may state it.</p>
ClassMethod KeyPrefixOf(pProvider As %String) As %String [ Private ]
{
    If '$ClassMethod(..CatalogClass(), "Row", pProvider, .tRow) Quit ""
    Quit tRow.keyPrefix
}

/// <p>Refuse a credential store with one <code>{field, code}</code> violation on
/// <parameter>KEYFIELD</parameter>, in the same 422 envelope every other refusal here uses.</p>
/// <p><var>pPrefix</var>, where there is one, puts the expected prefix in the envelope's reason --
/// the shape a key for this provider has, which is a catalog value and never any part of the value
/// posted (AD-35). The wording of the field-level message is Story 3.5's, keyed by the code.</p>
ClassMethod RenderCredentialRefusal(pCode As %String, pPrefix As %String = "") As %Status [ Private ]
{
    Kill tViolations
    Set tViolations($Increment(tViolations)) = $ListBuild(..#KEYFIELD, pCode)
    If pPrefix = "" Quit ..RenderViolations(.tViolations, "The key was refused")
    Quit ..RenderViolations(.tViolations, "The key was refused: keys for this provider begin with " _ pPrefix)
}

/// <p>The class a credential reference is resolved through, and the one this handler stores
/// through. <b>Overridable</b> so <class>OcuPilot.Test.DefinitionsProbe</class> can answer the
/// rung-unavailable refusal on an instance whose rung is present; production never overrides
/// it.</p>
ClassMethod SecretClass() As %String
{
    Quit "OcuPilot.Kernel.Secret.Ladder"
}

/// <p>Whether the calling process holds OcuPilot's administrative resource. The resource name is
/// read from <class>OcuPilot.Kernel.State.Base</class>, which declares it once for the installer,
/// the protected database and this gate alike.</p>
ClassMethod IsAdministrator() As %Boolean
{
    Quit ##class(OcuPilot.Screen.Gate).HoldsPrivilege(##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE, ..#ADMINPERMISSION)
}

/// <p>Refuse with the 403 Story 3.0 already published copy for: the
/// <parameter>OcuPilot.Api.Error.AUTHNOPRIVILEGE</parameter> code and the failed
/// <code>(resource, permission)</code> pair in <code>detail.failedPair</code> (AD-8), so the
/// client renders "You need ... " from the row it already carries and this story mints no new
/// code and no new string-table row.</p>
ClassMethod RenderForbidden() As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ ":" _ ..#ADMINPERMISSION)
    Quit ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, "This account does not hold OcuPilot's administrative privilege", ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, tDetail)
}

/// <p>Refuse with 404 and <parameter>OcuPilot.Api.Error.AGENTNOTFOUND</parameter>. The id is not
/// echoed back into the reason -- it came from the caller, and nothing about the instance is
/// added to it (AD-21, AD-47).</p>
ClassMethod RenderNotFound(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "No agent definition with that identifier exists on this instance", ##class(OcuPilot.Api.Error).#AGENTNOTFOUND)
}

/// <p>Refuse with 400 and <parameter>OcuPilot.Api.Error.AGENTBADBODY</parameter>, naming the
/// stage <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> reported. That method separates
/// its three failures -- read, decode, parse -- precisely so a server-side read fault is never
/// presented as malformed client JSON (DW-24), and the stage text is what carries that
/// distinction to the caller.</p>
ClassMethod RenderBadBody(pStatus As %Status) As %Status
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, "The request body could not be read: " _ $System.Status.GetErrorText(pStatus), ##class(OcuPilot.Api.Error).#AGENTBADBODY)
}

/// <p>Whether <var>pBody</var> is a shape <method>MergeBody</method> can read: a JSON object, or
/// no body at all.</p>
/// <p>A top-level JSON <b>array</b> is neither. It is an object to <code>$IsObject</code> but
/// answers <method>%IsDefined</method> for every key with its element 0, so an array body would
/// set every writable field to the same value -- which is why it is refused here rather than
/// validated field by field.</p>
/// <p><b>An absent body is read as naming no field</b>, not as a fault.
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> reports it as success precisely so that
/// a server-side read fault stays distinguishable from an empty body (DW-24), and refusing it
/// here would collapse that distinction again: a create with no body falls to the rules and
/// answers the violations, an update with no body changes nothing.</p>
ClassMethod BodyIsReadable(pBody As %DynamicAbstractObject) As %Boolean
{
    If '$IsObject(pBody) Quit 1
    Quit pBody.%IsA("%Library.DynamicObject")
}

/// <p>The status <method>RenderBadBody</method> renders for a body that parsed but is not a JSON
/// object.</p>
ClassMethod NotAnObject() As %Status
{
    Quit $$$ERROR($$$GeneralError, "the JSON body is not an object")
}

/// <p>Refuse with <b>one</b> 422 carrying every violation, as
/// <code>detail.violations</code>, each a <code>{field, code}</code> object in declared rule
/// order. Nothing has been written by the time this is called.</p>
/// <p><var>pReason</var> replaces the envelope's own sentence where a refusal has something to say
/// that the field-level code cannot carry -- the key-shape refusal states the prefix expected. It
/// never carries a violation's own wording, which stays the client's (Story 3.5), and it never
/// carries any value the caller sent (AD-35).</p>
ClassMethod RenderViolations(ByRef pViolations, pReason As %String = "The agent definition was refused") As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pReason, ##class(OcuPilot.Api.Error).#AGENTVALIDATION, tDetail)
}

/// <p>Open definition <var>pId</var> through the guarded frame. <var>pFound</var> is 0 for an id
/// no row holds -- an ordinary answer the caller turns into a 404, never an error status, so a
/// missing definition and a failed read stay distinguishable.</p>
ClassMethod OpenDefinition(pId As %String, Output pRow, Output pFound As %Boolean) As %Status
{
    Set pRow = ""
    Set pFound = 0
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedExistsId(pId, .tExists)
    If $$$ISERR(tSC) Quit tSC
    If 'tExists Quit $$$OK
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .pRow)
    If $$$ISERR(tSC) Quit tSC
    Set pFound = $IsObject(pRow)
    Quit $$$OK
}

/// <p>Read <var>pObject</var>'s values into <var>pValues</var>, subscripted by wire field name,
/// plus the derived <code>default</code>. This is the shape
/// <class>OcuPilot.Kernel.AgentRules</class> validates and the shape
/// <method>ChangeSet</method> diffs.</p>
ClassMethod ValuesFromRow(pObject As OcuPilot.Kernel.State.Agent, Output pValues)
{
    Kill pValues
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        Set pValues($List(tEntry, 1)) = $Property(pObject, $List(tEntry, 2))
    }
    Set pValues("default") = $Select(pObject.DefaultMark = "1": 1, 1: 0)
}

/// <p>Overwrite <var>pValues</var> with every writable field <var>pBody</var> actually carries,
/// and record which those were in <var>pPresent</var>. A key the body omits is left alone, which
/// is what makes an update a merge and a create fall back to the catalog.</p>
/// <p>A body key that is not a writable field is ignored rather than refused: the wire shape a
/// later client sends is not this story's to police, and the fields it may set are the closed set
/// <method>Fields</method> declares.</p>
/// <p><b>A field whose value is a JSON object or array is ignored the same way.</b> Every field
/// here is a scalar, and a nested value read out of a <class>%DynamicObject</class> arrives as an
/// OREF that stringifies to <code>&lt;n&gt;@%Library.DynamicObject</code> -- twenty-seven
/// characters that pass a length rule and would be stored as the definition's name. The body
/// itself is refused before this point unless it is a JSON object or absent
/// (<method>BodyIsReadable</method>).</p>
/// <p><b>So is a flag sent as anything but a JSON boolean.</b> <code>+"true"</code> and
/// <code>+"false"</code> are both 0 in ObjectScript, so a quoted flag would arrive as 0 whatever
/// the caller meant -- and on <code>readOnly</code>, whose default is 1 and whose enforcement is
/// Story 3.7's, 0 is the permissive answer. Ignoring the key leaves the stored value standing
/// instead of quietly clearing it.</p>
ClassMethod MergeBody(pBody As %DynamicObject, ByRef pValues, Output pPresent)
{
    Kill pPresent
    If '$IsObject(pBody) Quit
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        Set tField = $List(tEntry, 1)
        If '$List(tEntry, 4) Continue
        If 'pBody.%IsDefined(tField) Continue
        If $ListFind($ListBuild("object", "array"), pBody.%GetTypeOf(tField)) Continue
        If ($List(tEntry, 3) = "boolean") && (pBody.%GetTypeOf(tField) '= "boolean") Continue
        Set pPresent(tField) = 1
        Set tValue = pBody.%Get(tField)
        If $List(tEntry, 3) = "boolean" Set tValue = $Select(+tValue: 1, 1: 0)
        Set pValues(tField) = tValue
    }
}

/// <p>For each of <method>CatalogDefaults</method>'s four fields the body did not carry, take the
/// provider row's canonical value. An unknown provider has no row and changes nothing -- rule 2
/// is what refuses it.</p>
ClassMethod ApplyCatalogDefaults(ByRef pValues, ByRef pPresent)
{
    If '$ClassMethod(..CatalogClass(), "Row", $Get(pValues("provider")), .tRow) Quit
    Set tDefaults = ..CatalogDefaults()
    For tI = 1:1:$ListLength(tDefaults) {
        Set tEntry = $List(tDefaults, tI)
        Set tField = $List(tEntry, 1)
        If $Get(pPresent(tField)) Continue
        Set pValues(tField) = tRow.%Get($List(tEntry, 2))
    }
}

/// <p>Write every <b>writable</b> field of <var>pValues</var> onto <var>pObject</var>. The
/// read-only fields -- the verification flag and the two timestamps -- are the state class's and
/// are never written from here.</p>
ClassMethod ApplyValues(pObject As OcuPilot.Kernel.State.Agent, ByRef pValues)
{
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        If '$List(tEntry, 4) Continue
        Set $Property(pObject, $List(tEntry, 2)) = $Get(pValues($List(tEntry, 1)))
    }
}

/// <p>The full projection of one definition: every field, the derived <code>default</code>, and
/// the id. <b>No credential value</b> -- the credential's type and its name are what the schema
/// holds, and both are scoped identity data rather than a secret (AD-35, AD-37).</p>
ClassMethod FullProjection(pObject As OcuPilot.Kernel.State.Agent) As %DynamicObject
{
    Set tOut = {}
    Do tOut.%Set("id", pObject.%Id(), "string")
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        Do ..SetTyped(tOut, $List(tEntry, 1), $Property(pObject, $List(tEntry, 2)), $List(tEntry, 3))
    }
    Do tOut.%Set("default", $Select(pObject.DefaultMark = "1": 1, 1: 0), "boolean")
    Quit tOut
}

/// <p>The selection projection: the six keys a list needs -- id, name, provider, model, enabled
/// and default -- and nothing else. This is what the switcher and the Definitions list read, and
/// it is what a caller holding no OcuPilot administrative privilege is served.</p>
/// <p>Each key is written with the JSON type its field declares, the same way
/// <method>FullProjection</method> writes it: without the hint a name or model that reads as a
/// number is emitted as a JSON number here and as a string there, and a client typing one
/// projection against the other meets the difference.</p>
ClassMethod SelectionProjection(pObject As OcuPilot.Kernel.State.Agent) As %DynamicObject
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

/// <p>Set one key on <var>pOut</var> with the JSON type its field declares, so a number arrives
/// as a number and a flag as a boolean rather than as text a client has to coerce.</p>
ClassMethod SetTyped(pOut As %DynamicObject, pKey As %String, pValue As %String, pKind As %String) [ Private ]
{
    If pKind = "number" {
        Do pOut.%Set(pKey, +pValue, "number")
    } ElseIf pKind = "boolean" {
        Do pOut.%Set(pKey, $Select(+pValue: 1, 1: 0), "boolean")
    } Else {
        Do pOut.%Set(pKey, pValue, "string")
    }
}

/// <p>Every field whose value differs between <var>pBefore</var> and <var>pAfter</var>, as
/// <code>{&lt;field&gt;: {old, new}}</code> -- the changed-field set an accepted write records,
/// and the shape Story 3.8's audit row is built from.</p>
/// <p><b>Keyed by the field name rather than carrying it as a value</b>, and that is
/// load-bearing: <method>OcuPilot.Kernel.Audit.Log.Redact</method> masks by key name, so a
/// credential reference only reaches the log as <code>[redacted]</code> when
/// <code>credentialName</code> is the key. An entry shaped
/// <code>{"field": "credentialName", ...}</code> would sail past the backstop.</p>
ClassMethod ChangeSet(ByRef pBefore, ByRef pAfter) As %DynamicObject
{
    Set tChanges = {}
    Set tFields = ..Fields() _ $ListBuild($ListBuild("default", "DefaultMark", "boolean", 0))
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List($List(tFields, tI), 1)
        Set tOld = $Get(pBefore(tField))
        Set tNew = $Get(pAfter(tField))
        If tOld = tNew Continue
        Set tEntry = {}
        Do tEntry.%Set("old", tOld, "string")
        Do tEntry.%Set("new", tNew, "string")
        Do tChanges.%Set(tField, tEntry)
    }
    Quit tChanges
}

/// <p>Record one accepted write. <b>The single seam Story 3.8 wires to
/// <code>$System.Security.Audit()</code></b> once it has registered the event triple -- until
/// then this is a structured log line and nothing else, because an unregistered triple is dropped
/// with no error and no log entry (AD-15).</p>
/// <p>It swallows its own failure: a definition that was saved must not be reported as a failure
/// because the record of it could not be written.</p>
/// <p><code>securityChange</code> is 1 when the change set touched any field
/// <method>SecurityFieldNames</method> declares -- the provider, the endpoint, the marked-local
/// flag or the credential reference (AD-42's "audited as a security change"). It is computed here,
/// once, so Story 3.8 keys its audit event off a classification the write path already made rather
/// than recomputing one from the change set.</p>
ClassMethod LogChange(pVerb As %String, pId As %String, ByRef pBefore, ByRef pAfter)
{
    Try {
        Set tData = {}
        Do tData.%Set("id", pId, "string")
        Set tChanges = ..ChangeSet(.pBefore, .pAfter)
        Do tData.%Set("changes", tChanges)
        ; The credential verb is a security change by what it does, not by what it changed: a
        ; store alters no field SecurityFieldNames lists, and it is the one write that puts a
        ; secret on the instance (AD-42). Story 3.8 keys its audit event off this classification.
        Do tData.%Set("securityChange", $Select(pVerb = ..#CREDENTIALVERB: 1, 1: ..IsSecurityChange(tChanges)), "boolean")
        Do ..LogInfo(..#LOGSUBSYSTEM, pVerb, tData)
    } Catch ex {
    }
}

/// <p>Whether <var>pChanges</var> -- a <method>ChangeSet</method> object -- carries any field
/// <method>SecurityFieldNames</method> names.</p>
ClassMethod IsSecurityChange(pChanges As %DynamicObject) As %Boolean
{
    Set tFound = 0
    Try {
        If '$IsObject(pChanges) Quit
        Set tNames = ..SecurityFieldNames()
        For tI = 1:1:$ListLength(tNames) {
            If pChanges.%IsDefined($List(tNames, tI)) {
                Set tFound = 1
                Quit
            }
        }
    } Catch ex {
        ; A classification that could not be computed is reported as a security change: the
        ; conservative direction, since Story 3.8 audits on it.
        Set tFound = 1
    }
    Quit tFound
}

/// <p>The one call this class makes into <class>OcuPilot.Kernel.Audit.Log</class>. Its own method
/// so a test can capture what <method>LogChange</method> actually emits -- the same seam treatment
/// <method>OcuPilot.Api.Error.LogError</method> has, and for the same reason: a hard class name is
/// something no test can intercept. Production never overrides it.</p>
ClassMethod LogInfo(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Kernel.Audit.Log).Info(pSubsystem, pMessage, pData)
}

}
