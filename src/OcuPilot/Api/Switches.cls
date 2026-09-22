/// <p>The handler behind the <code>/agent/switches</code> routes and the ungated
/// <code>/agent/restraint</code> read (FR-19, FR-20, FR-29). One envelope, one gate, and one seam
/// the audit row is written from.</p>
/// <p><b>Who may see what.</b> Every caller that reaches here has cleared
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>. On top of that, <b>reading and writing the
/// switches</b> and <b>every hold route</b> require OcuPilot's own administrative resource, checked
/// server-side at the moment of the call through
/// <method>OcuPilot.Api.Definitions.IsAdministrator</method> -- the same gate, not a second copy of
/// it. <code>GET /agent/restraint</code> does not: it answers the calling user their own verdict,
/// which is what the panel renders its banners and its footer line from, and it is ungated for the
/// reason <method>OcuPilot.Api.Definitions.HandleList</method> is -- a refusal is not an answer, and
/// the audience for the kill-switch banner is precisely the people who cannot change it.</p>
/// <p><b>No gate lives here.</b> Whether a write may happen is
/// <method>OcuPilot.Kernel.Restraint.Verdict</method>'s alone (AD-30, AD-40); this class projects
/// the verdict onto the wire and computes no part of it.</p>
/// <p><b>A hold's user is a weak reference</b> (AD-37). The stored name reads back verbatim; whether
/// it still resolves on this instance is answered here, where the <code>%SYS</code> switch AD-16
/// requires is allowed, and travels as the row's <code>present</code> flag so the screen renders
/// rather than fails.</p>
/// <p><b>Every accepted write is audited.</b> Each hands its changed-field set to this class's own
/// <method>LogChange</method>, which writes the structured log line and the IRIS audit row --
/// through <class>OcuPilot.Kernel.Audit.Event</class>, beside the one
/// <class>OcuPilot.Api.Definitions</class> gives the definition routes (AD-15, FR-29).</p>
Class OcuPilot.Api.Switches Extends %RegisteredObject
{

/// <p>The subsystem every switch change is logged under.</p>
Parameter LOGSUBSYSTEM = "agent-switch";

/// <p>The <class>OcuPilot.Kernel.EntityType</class> value an audit row's target triple carries
/// (AD-13, AD-14). One value for the instance switches and the per-user holds alike -- one screen
/// administers both, and a hold is not a thing of its own outside it.</p>
Parameter ENTITYTYPE = "agent-switch";

/// <p>The id half of that triple. The switches are instance state with no identity of their own,
/// so the id is the scope's own literal; which user a hold is about travels in the change set.</p>
Parameter ENTITYID = "instance";

/// <p>The verb <code>PUT /agent/switches</code> records under.</p>
Parameter SWITCHESVERB = "switches";

/// <p>The verb a per-user hold's creation records under.</p>
Parameter HOLDVERB = "hold";

/// <p>The verb a per-user hold's removal records under.</p>
Parameter RELEASEVERB = "release";

/// <p>The field table for the instance-wide switches: one entry per wire field, as
/// <code>$ListBuild(field, property, kind, security)</code>. Every one of them is writable; the
/// timestamp is the state class's and is projected, never accepted.</p>
/// <p><code>security</code> is 1 for a field that decides whether the agent may act or what leaves
/// the instance, which is what <method>IsSecurityChange</method> classifies a write by.
/// <code>killSwitchReason</code> is 0: it is the operator's copy for the banner, and moving it
/// changes no restraint.</p>
ClassMethod Fields() As %List
{
    Quit $ListBuild($ListBuild("killSwitch", "KillSwitch", "boolean", 1), $ListBuild("killSwitchReason", "KillSwitchReason", "string", 0), $ListBuild("enforcedReadOnly", "EnforcedReadOnly", "boolean", 1), $ListBuild("shareContextByDefault", "ShareContextByDefault", "boolean", 1), $ListBuild("contextRowCap", "ContextRowCap", "integer", 1))
}

/// <p>The wire names of the switch fields whose change is a security change, derived from
/// <method>Fields</method> so the classification has one declaration.</p>
ClassMethod SecurityFieldNames() As %List
{
    Set tNames = ""
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        If $List(tEntry, 4) Set tNames = tNames _ $ListBuild($List(tEntry, 1))
    }
    Quit tNames
}

/// <p>Answer <code>GET /agent/switches</code>: the switches in force and every per-user hold.</p>
ClassMethod HandleRead() As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues)
        If $$$ISERR(tReadSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            Quit
        }
        Set tHoldSC = ..Holds(.tHolds)
        If $$$ISERR(tHoldSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tHoldSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(..Projection(.tValues, tHolds))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /agent/switches</code>: merge the body over the stored switches, validate,
/// then save. A key the body omits keeps its stored value, so turning the kill switch on is a
/// two-key body and cannot silently clear enforced read-only (AD-4).</p>
ClassMethod HandleUpdate() As %Status
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
        If '##class(OcuPilot.Api.Definitions).BodyIsReadable(tBody) {
            Set tSC = ..RenderBadBody(##class(OcuPilot.Api.Definitions).NotAnObject())
            Quit
        }
        ; The version is read BEFORE the values the merge is built on, and that order is the
        ; whole guarantee. A writer landing between the two reads then leaves this request holding
        ; a version older than the row, and the conditional save below is refused. Read the values
        ; first and the same writer leaves a version that still matches while the merge carries
        ; the values it superseded -- which is the lost update this closes, not a case it catches.
        ; Read from the store, never taken from the request: no version token crosses the wire.
        Set tVersionSC = ##class(OcuPilot.Kernel.State.Switch).GuardedVersion(.tVersion)
        If $$$ISERR(tVersionSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tVersionSC))
            Quit
        }
        Set tResolveSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tBefore)
        If $$$ISERR(tResolveSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tResolveSC))
            Quit
        }
        Kill tValues
        Merge tValues = tBefore
        Do ..MergeBody(tBody, .tValues)
        If ##class(OcuPilot.Kernel.SwitchRules).ValidateSwitches(.tValues, .tViolations) {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        Set tSaveSC = ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues, tVersion)
        If ##class(OcuPilot.Kernel.State.Base).IsStaleSave(tSaveSC) {
            Set tSC = ..RenderConflict()
            Quit
        }
        If $$$ISERR(tSaveSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The agent switches could not be saved", ##class(%Exception.StatusException).CreateFromStatus(tSaveSC))
            Quit
        }
        Set tAfterSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tAfter)
        If $$$ISERR(tAfterSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tAfterSC))
            Quit
        }
        Do ..LogChange(..#SWITCHESVERB, .tBefore, .tAfter)
        Set tHoldSC = ..Holds(.tHolds)
        If $$$ISERR(tHoldSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tHoldSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(..Projection(.tAfter, tHolds))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /agent/switches/holds</code>: switch the agent off for one user, with the
/// reason that user's banner carries. Answers 201 with the created row.</p>
/// <p><b>The user name is stripped of surrounding whitespace before anything reads it.</b> The
/// stored name is matched against <code>$Username</code> by
/// <method>OcuPilot.Kernel.State.Hold.GuardedForUser</method>, so a name pasted with a leading or
/// trailing space would be stored as a hold that never matches the user it names -- a kill switch
/// that silently does nothing. Stripping here is what makes the duplicate check, the unique index,
/// the stored row and the verdict's lookup all read one value.</p>
ClassMethod HandleHoldCreate() As %Status
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
        If '##class(OcuPilot.Api.Definitions).BodyIsReadable(tBody) {
            Set tSC = ..RenderBadBody(##class(OcuPilot.Api.Definitions).NotAnObject())
            Quit
        }
        Set tValues("userName") = $ZStrip(..StringMember(tBody, "userName"), "<>W")
        Set tValues("reason") = ..StringMember(tBody, "reason")
        Set tHeldSC = ##class(OcuPilot.Kernel.State.Hold).GuardedIdForUser(tValues("userName"), .tExistingId)
        If $$$ISERR(tHeldSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tHeldSC))
            Quit
        }
        If ##class(OcuPilot.Kernel.SwitchRules).ValidateHold(.tValues, tExistingId '= "", .tViolations) {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        Set tCreateSC = ##class(OcuPilot.Kernel.State.Hold).GuardedCreate(tValues("userName"), tValues("reason"), .tId)
        If $$$ISERR(tCreateSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The user could not be switched off", ##class(%Exception.StatusException).CreateFromStatus(tCreateSC))
            Quit
        }
        Kill tBeforeHold
        Set tAfterHold("userName") = tValues("userName")
        Set tAfterHold("reason") = tValues("reason")
        Do ..LogChange(..#HOLDVERB, .tBeforeHold, .tAfterHold)
        Set tRow = {}
        Do tRow.%Set("id", tId, "string")
        Do tRow.%Set("userName", tValues("userName"), "string")
        Do tRow.%Set("reason", tValues("reason"), "string")
        Do tRow.%Set("present", $Select(..UserExists(tValues("userName")): 1, 1: 0), "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, tRow)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>DELETE /agent/switches/holds/:id</code>: switch the agent back on for that user.
/// An id no row holds is a 404 carrying
/// <parameter>OcuPilot.Api.Error.AGENTHOLDNOTFOUND</parameter>, never an empty 200.</p>
ClassMethod HandleHoldDelete(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsAdministrator() {
            Set tSC = ..RenderForbidden()
            Quit
        }
        Set tOpenSC = ##class(OcuPilot.Kernel.State.Hold).GuardedExistsId(pId, .tExists)
        If $$$ISERR(tOpenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tOpenSC))
            Quit
        }
        If 'tExists {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "No switched-off user with that identifier exists on this instance", ##class(OcuPilot.Api.Error).#AGENTHOLDNOTFOUND)
            Quit
        }
        Set tRowSC = ##class(OcuPilot.Kernel.State.Hold).GuardedOpenId(pId, .tRow)
        If $$$ISOK(tRowSC) && $IsObject(tRow) {
            Set tBeforeHold("userName") = tRow.UserName
            Set tBeforeHold("reason") = tRow.Reason
            Set tRow = ""
        }
        Set tDeleteSC = ##class(OcuPilot.Kernel.State.Hold).GuardedDeleteId(pId)
        If $$$ISERR(tDeleteSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("The user could not be switched back on", ##class(%Exception.StatusException).CreateFromStatus(tDeleteSC))
            Quit
        }
        Kill tAfterHold
        Do ..LogChange(..#RELEASEVERB, .tBeforeHold, .tAfterHold)
        Set tBody = {}
        Do tBody.%Set("id", pId, "string")
        Do tBody.%Set("deleted", 1, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /agent/restraint</code>: the calling user's own verdict, as
/// <method>OcuPilot.Kernel.Restraint.Resolved</method> answers it, plus
/// <code>writesMarked</code> -- whether the instance was marking agent writes when that was last
/// observed (AD-15). <b>No OcuPilot administrative privilege required</b> -- see the class
/// header.</p>
/// <p><code>writesMarked</code> is a recorded fact rather than a live read, and the panel renders
/// only its <b>false</b> arm: nothing anywhere says marking is working, so the fact being stale
/// for one window costs a reader nothing they were told.</p>
/// <p>A verdict that could not be read is a 500 rather than a body: the client renders banners and a
/// footer line from this, and a permissive-looking answer over an unreadable store is the one thing
/// it must not be handed.</p>
ClassMethod HandleRestraint() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tVerdictSC = ##class(OcuPilot.Kernel.Restraint).Resolved(..CallerUsername(), .tVerdict)
        If $$$ISERR(tVerdictSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tVerdictSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("blocked", $Select(+tVerdict("blocked"): 1, 1: 0), "boolean")
        Do tBody.%Set("code", tVerdict("code"), "string")
        Do tBody.%Set("reason", tVerdict("reason"), "string")
        Do tBody.%Set("footerKey", tVerdict("footerKey"), "string")
        Do tBody.%Set("killSwitch", $Select(+tVerdict("killSwitch"): 1, 1: 0), "boolean")
        Do tBody.%Set("killSwitchAudience", tVerdict("killSwitchAudience"), "string")
        Do tBody.%Set("killSwitchReason", tVerdict("killSwitchReason"), "string")
        Do tBody.%Set("enforcedReadOnly", $Select(+tVerdict("enforcedReadOnly"): 1, 1: 0), "boolean")
        ; Not part of the verdict: marking is not a restraint (AD-30), so Kernel.Restraint does not
        ; answer it and the agent is not blocked by it. It rides this route because the panel
        ; already reads it on every load, and because the banner it feeds is shown to every user.
        Do tBody.%Set("writesMarked", $Select(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(): 1, 1: 0), "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The identity the verdict is resolved for: the authenticated caller of this request.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>The switch state and its holds, as the object both reads answer.</p>
ClassMethod Projection(ByRef pValues, pHolds As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        Set tField = $List(tEntry, 1)
        Set tValue = $Get(pValues(tField))
        If $List(tEntry, 3) = "boolean" {
            Do tOut.%Set(tField, $Select(+tValue: 1, 1: 0), "boolean")
        } ElseIf $List(tEntry, 3) = "integer" {
            Do tOut.%Set(tField, +tValue, "number")
        } Else {
            Do tOut.%Set(tField, tValue, "string")
        }
    }
    Do tOut.%Set("updatedAt", $Get(pValues("updatedAt")), "string")
    Do tOut.%Set("holds", pHolds)
    Quit tOut
}

/// <p>Every hold, each row carrying whether the user it names still resolves on this instance
/// (AD-37).</p>
ClassMethod Holds(Output pHolds As %DynamicArray) As %Status
{
    Set pHolds = []
    Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedScreenRows(.tRows)
    If $$$ISERR(tSC) Quit tSC
    For tI = 0:1:(tRows.%Size() - 1) {
        Set tRow = tRows.%Get(tI)
        Do tRow.%Set("present", $Select(..UserExists(tRow.%Get("userName")): 1, 1: 0), "boolean")
        Do pHolds.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>Whether <var>pUserName</var> is a user this instance still holds.</p>
/// <p><class>Security.Users</class> lives only in <code>%SYS</code>, so the namespace is switched by
/// explicit save and restore with the restore as the first line of the <code>Catch</code> (AD-16);
/// <code>New $NAMESPACE</code> is never used on a dispatch path. A name that cannot be resolved for
/// any reason answers <b>no</b>, which renders the row as a reference that no longer resolves rather
/// than failing the screen (AD-37).</p>
/// <p><b>The restore is a direct assignment, not
/// <method>OcuPilot.Kernel.Utils.RestoreNamespace</method></b> -- the idiom
/// <method>OcuPilot.Port.LogSourcePort.ErrorsRead</method> already uses. No <code>OcuPilot</code>
/// class is mapped into <code>%SYS</code>, so a call back into one from inside the switched frame
/// raises <code>&lt;CLASS DOES NOT EXIST&gt;</code>, which on the error path leaves the process in
/// <code>%SYS</code> and answers 500. Measured on this build.</p>
ClassMethod UserExists(pUserName As %String) As %Boolean
{
    Set tExists = 0
    Set tOriginal = $NAMESPACE
    Try {
        If pUserName = "" Quit
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Users).Exists(pUserName)
    } Catch ex {
        Set $NAMESPACE = tOriginal
        Set tExists = 0
    }
    Set $NAMESPACE = tOriginal
    Quit tExists
}

/// <p>Overwrite <var>pValues</var> with every switch field <var>pBody</var> actually carries. A key
/// the body omits is left alone, which is what makes the update a merge.</p>
/// <p><b>A flag sent as anything but a JSON boolean is ignored</b>, for the reason
/// <method>OcuPilot.Api.Definitions.MergeBody</method> records: <code>+"true"</code> and
/// <code>+"false"</code> are both 0 in ObjectScript, so a quoted flag would arrive as 0 whatever the
/// caller meant -- and on <code>killSwitch</code> 0 is the permissive answer. So is a value that is
/// a JSON object or an array, which would reach a string column as an OREF's stringification.</p>
/// <p><b>A string field takes only a JSON string</b>, the same strictness
/// <method>StringMember</method> applies on the hold routes: a number or a boolean sent as
/// <code>killSwitchReason</code> would otherwise reach the published banner as the operator's
/// reason.</p>
ClassMethod MergeBody(pBody As %DynamicObject, ByRef pValues)
{
    If '$IsObject(pBody) Quit
    Set tFields = ..Fields()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        Set tField = $List(tEntry, 1)
        If 'pBody.%IsDefined(tField) Continue
        Set tType = pBody.%GetTypeOf(tField)
        If $ListFind($ListBuild("object", "array"), tType) Continue
        If ($List(tEntry, 3) = "boolean") && (tType '= "boolean") Continue
        If ($List(tEntry, 3) = "string") && (tType '= "string") Continue
        Set tValue = pBody.%Get(tField)
        If $List(tEntry, 3) = "boolean" Set tValue = $Select(+tValue: 1, 1: 0)
        ; An integer field takes a JSON number only (AD-4). A boolean or a numeric string would
        ; otherwise read back as a plausible value by the time ValidateSwitches's regex sees it, so
        ; any other type becomes "" and meets that rule's empty-value refusal.
        If ($List(tEntry, 3) = "integer") && (tType '= "number") Set tValue = ""
        Set pValues(tField) = tValue
    }
}

/// <p>One string member of <var>pBody</var>, or <code>""</code> for a member that is absent or is
/// not a JSON string -- so a nested object never reaches a column as an OREF's stringification.</p>
ClassMethod StringMember(pBody As %DynamicObject, pKey As %String) As %String [ Private ]
{
    If '$IsObject(pBody) Quit ""
    If 'pBody.%IsDefined(pKey) Quit ""
    If pBody.%GetTypeOf(pKey) '= "string" Quit ""
    Quit pBody.%Get(pKey)
}

/// <p>Whether the calling process holds OcuPilot's administrative resource. Delegates to
/// <method>OcuPilot.Api.Definitions.IsAdministrator</method>, which is the one gate the agent routes
/// share rather than a second copy of it.</p>
ClassMethod IsAdministrator() As %Boolean
{
    Quit ##class(OcuPilot.Api.Definitions).IsAdministrator()
}

/// <p>Refuse with the 403 the definition routes already publish copy for: the
/// <parameter>OcuPilot.Api.Error.AUTHNOPRIVILEGE</parameter> code and the failed
/// <code>(resource, permission)</code> pair in <code>detail.failedPair</code> (AD-8).</p>
ClassMethod RenderForbidden() As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).RenderForbidden()
}

/// <p>Refuse a save whose row moved after this request read it, through
/// <method>OcuPilot.Api.Definitions.RenderConflict</method> -- the shape this class's other
/// refusals already take, so one refusal is worded once (AD-12, AD-39).</p>
ClassMethod RenderConflict() As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).RenderConflict()
}

/// <p>Refuse with 400 and <parameter>OcuPilot.Api.Error.AGENTBADBODY</parameter>, carrying
/// <parameter>OcuPilot.Api.Error.REASONAGENTBADBODY</parameter> alone; <var>pStatus</var>'s raw
/// text reaches the log only (AD-39).</p>
ClassMethod RenderBadBody(pStatus As %Status) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).RenderBadBody(pStatus)
}

/// <p>Refuse with <b>one</b> 422 carrying every violation as <code>detail.violations</code>, each a
/// <code>{field, code, reason}</code> object in declared rule order (AD-39). Nothing has been
/// written by the time this is called.</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Quit ##class(OcuPilot.Api.Definitions).RenderViolations(.pViolations, "The agent switches were refused")
}

/// <p>Record one accepted write: the structured log line, and the audit row
/// <class>OcuPilot.Kernel.Audit.Event</class> writes beside it -- the shape
/// <method>OcuPilot.Api.Definitions.LogChange</method> records one for the definition routes.</p>
/// <p>It swallows its own failure, and emission never fails the write it records (AD-15).</p>
/// <p><code>updatedAt</code> is not a change. <method>OcuPilot.Kernel.State.Switch.SetGuarded</method>
/// re-stamps it on every write, so carrying it would make a request that altered nothing
/// indistinguishable from one that did.</p>
ClassMethod LogChange(pVerb As %String, ByRef pBefore, ByRef pAfter)
{
    Try {
        Set tData = {}
        Set tChanges = {}
        Set tSeen = ""
        Set tField = $Order(pBefore(""))
        While tField '= "" {
            Set tSeen = tSeen _ $ListBuild(tField)
            Set tField = $Order(pBefore(tField))
        }
        Set tField = $Order(pAfter(""))
        While tField '= "" {
            If '$ListFind(tSeen, tField) Set tSeen = tSeen _ $ListBuild(tField)
            Set tField = $Order(pAfter(tField))
        }
        For tI = 1:1:$ListLength(tSeen) {
            Set tField = $List(tSeen, tI)
            If tField = "updatedAt" Continue
            Set tOld = $Get(pBefore(tField))
            Set tNew = $Get(pAfter(tField))
            If tOld = tNew Continue
            Set tEntry = {}
            Do tEntry.%Set("old", tOld, "string")
            Do tEntry.%Set("new", tNew, "string")
            Do tChanges.%Set(tField, tEntry)
        }
        Do tData.%Set("changes", tChanges)
        Set tSecurity = ..IsSecurityChange(pVerb, tChanges)
        Do tData.%Set("securityChange", tSecurity, "boolean")
        Do ..LogInfo(..#LOGSUBSYSTEM, pVerb, tData)
        Do ..RecordAudit(pVerb, tChanges, tSecurity)
    } Catch ex {
    }
}

/// <p>Whether this write is a security change, computed per verb rather than declared constant.</p>
/// <p>A hold and a release are security changes by what they do: each decides whether one named
/// user may make the agent act at all (AD-30). A <code>switches</code> write is one when the change
/// set touched a field <method>SecurityFieldNames</method> declares -- so turning the kill switch
/// on is a security change and reworded banner copy is not.</p>
/// <p>A classification that could not be computed answers yes: the conservative direction, since
/// this selects the registered event name the row is written under.</p>
ClassMethod IsSecurityChange(pVerb As %String, pChanges As %DynamicObject) As %Boolean
{
    Set tFound = 0
    Try {
        If (pVerb = ..#HOLDVERB) || (pVerb = ..#RELEASEVERB) {
            Set tFound = 1
            Quit
        }
        If '$IsObject(pChanges) Quit
        Set tNames = ..SecurityFieldNames()
        For tI = 1:1:$ListLength(tNames) {
            If pChanges.%IsDefined($List(tNames, tI)) {
                Set tFound = 1
                Quit
            }
        }
    } Catch ex {
        Set tFound = 1
    }
    Quit tFound
}

/// <p>The one call this class makes into <class>OcuPilot.Kernel.Audit.Event</class>, with the
/// switches' own entity type and the instance as the scoped target (AD-13). Its own method so the
/// call site is one line a reader can find. Not a capture seam --
/// <class>OcuPilot.Test.SwitchesProbe</class> leaves it alone, for the reason
/// <method>OcuPilot.Api.Definitions.RecordAudit</method>'s own comment gives.</p>
ClassMethod RecordAudit(pVerb As %String, pChanges As %DynamicObject, pSecurityChange As %Boolean)
{
    Do ##class(OcuPilot.Kernel.Audit.Event).Record(pVerb, ..#ENTITYTYPE, ..#ENTITYID, pChanges, pSecurityChange)
}

/// <p>The one call <method>LogChange</method> writes through, so a test can capture what it
/// actually emits -- the seam treatment <method>OcuPilot.Api.Definitions.LogInfo</method> carries,
/// and for the reason its own comment gives: a hard class name is something no test can intercept.
/// Production never overrides it.</p>
ClassMethod LogInfo(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Api.Definitions).LogInfo(pSubsystem, pMessage, pData)
}

}
