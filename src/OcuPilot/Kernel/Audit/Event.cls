/// <p>The one place OcuPilot writes a row into the IRIS audit database (AD-15). Every accepted
/// configuration change reaches it through its slice's own <code>LogChange</code> seam; nothing
/// else calls <code>$System.Security.Audit</code> except the installer's role-grant marker.</p>
/// <p><b>The roster is declared here and registered by the installer.</b>
/// <method>OcuPilot.Install.Installer.EnsureAuditEvents</method> reads <method>Names</method> and
/// registers each triple, so the set this class can emit and the set registration carries are one
/// declaration. An unregistered triple makes <code>$System.Security.Audit</code> return an error
/// status and drop the event silently, which is what makes that single source load-bearing.</p>
/// <p><b>Two names for a change, not one per verb.</b> <parameter>EVENTCONFIG</parameter> and
/// <parameter>EVENTSECURITY</parameter> split on the <code>securityChange</code> boolean the write
/// path already computes, so AD-42's "audited as a security change" is filterable on the row's own
/// event name while the roster stays closed as screens are added. A name outside that split is
/// added only for something that is not a change: <parameter>EVENTLEDGERREAD</parameter> is.</p>
/// <p><b>Emission never fails the write it records</b> (AD-15, Conventions: Logging).
/// <method>Record</method> never throws: it returns the status
/// <code>$System.Security.Audit</code> gave it and logs a failure through
/// <class>OcuPilot.Kernel.Audit.Log</class>, and its callers swallow the result.</p>
/// <p><b>No secret reaches a row.</b> The payload goes through
/// <method>OcuPilot.Kernel.Audit.Log.Redact</method>, the same backstop the log line passes
/// through (AD-35), before it is serialized.</p>
Class OcuPilot.Kernel.Audit.Event Extends %RegisteredObject
{

/// <p>The event name a change that touched no security field is recorded under.</p>
Parameter EVENTCONFIG = "ConfigChange";

/// <p>The event name a change that touched one is recorded under (AD-42).</p>
Parameter EVENTSECURITY = "SecurityChange";

/// <p>The event name a cross-user read of the agent ledger is recorded under (Story 4.9, AD-15,
/// AD-46). A read rather than a change, and its own name rather than a verb on one of the two
/// above, so an administrator's view of another user's agent activity is filterable on the row.</p>
Parameter EVENTLEDGERREAD = "LedgerRead";

/// <p>The event name a confirmed agent write is marked with (Story 5.6, AD-15, FR-21, FR-22). A
/// marker rather than a change: the vendor writes its own <code>%System/%Security/*Change</code>
/// row for the same operation, and this one says the agent made it.</p>
Parameter EVENTAGENTWRITE = "AgentWrite";

/// <p>The subsystem a failed emission is logged under.</p>
Parameter LOGSUBSYSTEM = "audit-event";

/// <p>The <code>Description</code> registered for, and written with,
/// <parameter>EVENTCONFIG</parameter>. Read against the shipped classes: it is stored as
/// <code>Security.Events.Description</code>, <code>%String(MAXLEN = 256)</code>, and repeated on
/// each row as <code>%SYS.Audit.Description</code>, <code>%Binary(MAXLEN = 128)</code> -- so 128
/// is the bound that matters.</p>
Parameter DESCRIPTIONCONFIG = "OcuPilot configuration change";

/// <p>The <code>Description</code> registered for, and written with,
/// <parameter>EVENTSECURITY</parameter>.</p>
Parameter DESCRIPTIONSECURITY = "OcuPilot security-relevant configuration change";

/// <p>The <code>Description</code> registered for the installer's own grant marker.</p>
Parameter DESCRIPTIONGRANT = "OcuPilot administrative role granted";

/// <p>The <code>Description</code> registered for, and written with,
/// <parameter>EVENTLEDGERREAD</parameter>.</p>
Parameter DESCRIPTIONLEDGERREAD = "OcuPilot agent ledger read of another user's rows";

/// <p>The <code>Description</code> registered for, and written with,
/// <parameter>EVENTAGENTWRITE</parameter>. Within the 128 characters
/// <parameter>DESCRIPTIONCONFIG</parameter>'s note gives as the bound that matters.</p>
Parameter DESCRIPTIONAGENTWRITE = "OcuPilot agent confirmed write";

/// <p>The log message a dropped configuration-change emission reports
/// (<method>LogFailure</method>).</p>
Parameter DROPPEDCONFIG = "the configuration change was made and no audit row was written";

/// <p>The log message a dropped <parameter>EVENTAGENTWRITE</parameter> emission reports. The write
/// has already been applied when the marker is emitted, so this is the only trace of the drop
/// besides the ledger row's own <code>AuditMarked</code>.</p>
Parameter DROPPEDAGENTWRITE = "the confirmed write was applied and no audit row was written";

/// <p>The reason a dropped <parameter>EVENTAGENTWRITE</parameter> emission reports.
/// <code>$System.Security.Audit</code> answers a boolean and names no cause, so this states the
/// answer it gave and asserts nothing about why -- the instance flag, the registration and a
/// per-call failure all look the same from here.</p>
Parameter DROPPEDANSWER = "$System.Security.Audit answered 0 and wrote no row";

/// <p>The log message a dropped <parameter>EVENTLEDGERREAD</parameter> emission reports. A read is
/// not a change, and saying it was one sends an operator looking for a configuration edit that
/// never happened.</p>
Parameter DROPPEDLEDGERREAD = "the agent ledger read was answered and no audit row was written";

/// <p>The log message a dropped <parameter>EVENTSECURITY</parameter> emission reports (DW-1171). A
/// security-relevant change reported as a configuration one sends an operator looking in the wrong
/// place for the row that is missing, and this is the only trace such a drop leaves.</p>
Parameter DROPPEDSECURITY = "the security-relevant change was made and no audit row was written";

/// <p>The verb a confirmed agent write's marker records.</p>
Parameter VERBWRITE = "write";

/// <p>The log message a failed <method>RecordMarking</method> reports.</p>
Parameter REFRESHFAILED = "the observed audit-marking state could not be recorded";

/// <p>The audit Source every OcuPilot row carries. Read from
/// <class>OcuPilot.Kernel.State.Base</class>, which declares the triple's Source and Type once
/// for the installer, the smoke check and this emitter alike.</p>
ClassMethod Source() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#AUDITSOURCE
}

/// <p>The audit Type every OcuPilot row carries.</p>
ClassMethod Type() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#AUDITTYPE
}

/// <p>The roster's base event names, in registration order: the installer's grant marker first,
/// then this class's own change names and the ledger-read name. A story that needs another adds it
/// here, and the installer registers it without an edit of its own.</p>
ClassMethod Roster() As %List
{
    Quit $ListBuild(##class(OcuPilot.Kernel.State.Base).#AUDITNAME, ..#EVENTCONFIG, ..#EVENTSECURITY, ..#EVENTLEDGERREAD, ..#EVENTAGENTWRITE)
}

/// <p>The roster with <var>pSuffix</var> appended to every name -- the profile suffix
/// <method>OcuPilot.Install.Installer.Names</method> applies (<code>""</code> for production,
/// <code>Probe</code> for the disposable test profile), so both profiles register and emit the
/// same shape under distinct names.</p>
ClassMethod Names(pSuffix As %String = "") As %List
{
    Set tNames = ""
    Set tRoster = ..Roster()
    For tI = 1:1:$ListLength(tRoster) {
        Set tNames = tNames _ $ListBuild($List(tRoster, tI) _ pSuffix)
    }
    Quit tNames
}

/// <p>The <code>Description</code> a roster entry is registered with, keyed by its <b>base</b>
/// name -- the unsuffixed value <method>Roster</method> declares. A base name with no arm here
/// names itself, so a roster entry added without a description is visible in the registration
/// rather than wearing another entry's sentence.</p>
ClassMethod Description(pBaseName As %String) As %String
{
    If pBaseName = ..#EVENTCONFIG Quit ..#DESCRIPTIONCONFIG
    If pBaseName = ..#EVENTSECURITY Quit ..#DESCRIPTIONSECURITY
    If pBaseName = ##class(OcuPilot.Kernel.State.Base).#AUDITNAME Quit ..#DESCRIPTIONGRANT
    If pBaseName = ..#EVENTLEDGERREAD Quit ..#DESCRIPTIONLEDGERREAD
    If pBaseName = ..#EVENTAGENTWRITE Quit ..#DESCRIPTIONAGENTWRITE
    ; A name with no arm is a roster entry whose description nobody wrote. Said out loud rather
    ; than answered with the grant marker's description, which would register a later entry under
    ; a sentence about something else.
    Quit "OcuPilot audit event " _ pBaseName _ " (no description declared)"
}

/// <p>The event name a change carries: <parameter>EVENTSECURITY</parameter> when
/// <var>pSecurityChange</var> is true, otherwise <parameter>EVENTCONFIG</parameter>.</p>
ClassMethod EventNameFor(pSecurityChange As %Boolean, pSuffix As %String = "") As %String
{
    Quit $Select(+pSecurityChange: ..#EVENTSECURITY, 1: ..#EVENTCONFIG) _ pSuffix
}

/// <p>The identity a row records as its actor: the authenticated caller of the request that made
/// the change. Its own method so a test can drive the payload without authenticating.</p>
ClassMethod Actor() As %String
{
    Quit $Username
}

/// <p>Write one audit row for an accepted configuration change.</p>
/// <p><var>pType</var> is a value of <class>OcuPilot.Kernel.EntityType</class>'s closed
/// vocabulary and <var>pId</var> the changed object's id; together with the instance scope they
/// are the <code>(entity type, scope, id)</code> triple every reference that crosses a boundary
/// carries (AD-13, AD-14). <var>pChanges</var> is the changed-field set the write path computed,
/// as <code>{&lt;field&gt;: {old, new}}</code>; <var>pSecurityChange</var> selects the event name.</p>
/// <p><var>pEffects</var>, when it is an object, is written as the payload's <code>effects</code>
/// member: what the write did beyond the fields it changed -- the definitions it disabled, what
/// became of a credential entry, which key a test call carried. It is absent from the row when
/// not supplied, and passes through the same redaction as the rest of the payload. A caller puts
/// ids and outcome words in it, never a credential reference or a value.</p>
/// <p><var>pEventName</var>, when supplied, is the roster name the row is written under instead of
/// the one <var>pSecurityChange</var> selects, with that name's own
/// <method>Description</method> -- what <parameter>EVENTLEDGERREAD</parameter> uses to record a
/// read rather than a change (Story 4.9). A name the roster does not carry is dropped by the
/// instance with no row, which is the same fail-closed behaviour every other name here has.</p>
/// <p><b>Caller contract:</b> call after the write has succeeded, and ignore the returned status
/// -- a write that happened must never be reported as a failure because the record of it could
/// not be written (AD-15). The status is returned so a test can observe the drop an unregistered
/// triple produces.</p>
/// <p><b>No namespace switch.</b> <code>$System.Security.Audit</code> is a
/// <code>%SYSTEM</code> method and writes the row from the install namespace, and entering
/// <code>%SYS</code> to make the call needs <code>%DB_IRISSYS</code> READ -- which an OcuPilot
/// administrator built to least privilege does not hold. Measured on this build: a principal
/// holding the install namespace's code resource, <code>OcuPilotAdmin</code> and
/// <code>%Admin_Operate</code>, and no <code>%DB_IRISSYS</code>, got <code>&lt;PROTECT&gt;</code>
/// on the switch and wrote no row, while the same call made without the switch returned
/// <code>$$$OK</code> and landed one. Since the failure is swallowed (AD-15), the switch made
/// every configuration change such a principal accepted go unaudited with only a log line.
/// The row records the namespace the change was made in, which is the one that means something.</p>
ClassMethod Record(pVerb As %String, pType As %String, pId As %String, pChanges As %DynamicObject = "", pSecurityChange As %Boolean = 0, pEffects As %DynamicObject = "", pEventName As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSource = ..Source()
        Set tType = ..Type()
        Set tName = $Select(pEventName '= "": pEventName, 1: ..EventNameFor(pSecurityChange))
        Set tDescription = $Select(pEventName '= "": ..Description(pEventName), 1: $Select(+pSecurityChange: ..#DESCRIPTIONSECURITY, 1: ..#DESCRIPTIONCONFIG))
        Set tRefSC = ##class(OcuPilot.Kernel.EntityRef).Wire(pType, ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, pId, .tTarget)
        If $$$ISERR(tRefSC) {
            Set tSC = tRefSC
            Quit
        }
        Set tPayload = {}
        Do tPayload.%Set("actor", ..Actor(), "string")
        Do tPayload.%Set("target", tTarget)
        Do tPayload.%Set("verb", pVerb, "string")
        Do tPayload.%Set("securityChange", $Select(+pSecurityChange: 1, 1: 0), "boolean")
        Do tPayload.%Set("changes", $Select($IsObject(pChanges): pChanges, 1: {}))
        If $IsObject(pEffects) Do tPayload.%Set("effects", pEffects)
        Set tText = ##class(OcuPilot.Kernel.Audit.Log).Redact(tPayload).%ToJSON()
        Set tSC = $System.Security.Audit(tSource, tType, tName, tText, tDescription)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFailure(pVerb, pType, pId, tSC, $Select(pEventName = ..#EVENTLEDGERREAD: ..#DROPPEDLEDGERREAD, +pSecurityChange: ..#DROPPEDSECURITY, 1: ..#DROPPEDCONFIG))
    Quit tSC
}

/// <p>Mark one confirmed agent write in the audit database (AD-15, FR-21, FR-22).</p>
/// <p><var>pTargetRef</var> is the <b>canonical</b> reference key the proposal stored
/// (<method>OcuPilot.Kernel.EntityRef.Key</method>, AD-13 as amended by DW-1359), never the
/// spelling the agent typed. It is parsed rather than rebuilt, so the scope a namespace-scoped
/// target carries reaches the row -- which is why this is not <method>Record</method>, whose
/// scope is hardcoded to the instance.</p>
/// <p>The payload carries <code>actor</code>, <code>target</code>, <code>verb</code>,
/// <code>proposalId</code>, <code>tool</code>, <code>writtenAt</code> and <code>fields</code>:
/// the join to the vendor's own change row for the same operation is the pair
/// <i>(scoped target, user)</i> inside the window <var>pWrittenAt</var> opens, and the proposal id
/// is what lets the ledger row and this row name each other. <var>pFields</var> is the list of
/// field names the write actually sent, secret-declared names already excluded by the caller
/// (AD-3) -- no value of any field reaches the row.</p>
/// <p><b>Caller contract:</b> call after <b>and only after</b> the write has succeeded, and never
/// let the returned status change the caller's own. The status is returned so the executor can
/// record the outcome on the ledger row and answer <code>auditMarked</code>; a write that happened
/// is never reported as a failure because its marker was dropped (AD-15).</p>
/// <p><var>pEmitted</var> is 1 only when <code>$System.Security.Audit</code> was actually called,
/// and it is a <b>different</b> question from the returned status: a reference that will not parse
/// fails this method without asking the instance anything. Only an answer the instance gave is
/// evidence about the instance, so <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method>
/// refreshes <method>RecordMarking</method> from <var>pEmitted</var> and never from the status
/// alone (DW-1379). The write's own card still reads the status, because that is a per-write
/// fact.</p>
/// <p><b>No namespace switch</b>, for the reason <method>Record</method>'s header gives.</p>
ClassMethod RecordAgentWrite(pProposalId As %String, pToolName As %String, pTargetRef As %String, pUser As %String, pWrittenAt As %String, pFields As %List = "", Output pEmitted As %Boolean) As %Status
{
    Set pEmitted = 0
    Set tSC = $$$OK
    Try {
        Set tRefSC = ##class(OcuPilot.Kernel.EntityRef).Parse(pTargetRef, .tType, .tScope, .tId)
        If $$$ISERR(tRefSC) {
            Set tSC = tRefSC
            Quit
        }
        Set tWireSC = ##class(OcuPilot.Kernel.EntityRef).Wire(tType, tScope, tId, .tTarget)
        If $$$ISERR(tWireSC) {
            Set tSC = tWireSC
            Quit
        }
        Set tPayload = {}
        Do tPayload.%Set("actor", pUser, "string")
        Do tPayload.%Set("target", tTarget)
        Do tPayload.%Set("verb", ..#VERBWRITE, "string")
        Do tPayload.%Set("proposalId", pProposalId, "string")
        Do tPayload.%Set("tool", pToolName, "string")
        Do tPayload.%Set("writtenAt", pWrittenAt, "string")
        Set tFields = []
        For tI = 1:1:$ListLength(pFields) {
            Do tFields.%Push($List(pFields, tI), "string")
        }
        Do tPayload.%Set("fields", tFields)
        Set tText = ##class(OcuPilot.Kernel.Audit.Log).Redact(tPayload).%ToJSON()
        Set pEmitted = 1
        Set tSC = $System.Security.Audit(..Source(), ..Type(), ..#EVENTAGENTWRITE, tText, ..#DESCRIPTIONAGENTWRITE)
        ; The call answers a boolean, not a %Status, so a dropped emission reaches LogFailure as 0
        ; and $System.Status.GetErrorText(0) renders "ERROR #00: (no error description)" -- a
        ; reason that says nothing on the one line AD-15 leaves behind. Say what is known and no
        ; more: the call was made and wrote nothing. Why it wrote nothing is not readable here.
        If 'tSC Set tSC = $$$ERROR($$$GeneralError, ..#DROPPEDANSWER)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFailure(..#VERBWRITE, $Get(tType, ""), $Get(tId, pTargetRef), tSC, ..#DROPPEDAGENTWRITE)
    Quit tSC
}

/// <p>Whether the instance was marking agent writes when that was last observed
/// (<property>OcuPilot.Kernel.State.Switch.WritesMarked</property>).</p>
/// <p><b>A recorded fact, not a live read.</b> "Is auditing on" lives in
/// <class>Security.System</class> and "is this event enabled" in <class>Security.Events</class>,
/// both <code>%SYS</code>-only, and reading either from the ungated restraint route would need a
/// third privileged routine application, which AD-8 and AD-9 do not carry. So the fact is written
/// by the parties that can see it -- install, the confirm executor and a screen action whose tool
/// moves the marking (AD-53) -- and read here. A read
/// that fails answers the default, because the banner this feeds must never be shown on an
/// unreadable store: its absence is never a claim that marking works.</p>
ClassMethod WritesMarked() As %Boolean
{
    Set tMarked = 1
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues)
        If $$$ISERR(tSC) Quit
        Set tMarked = ''$Get(tValues("writesMarked"), 1)
    } Catch ex {
        Set tMarked = 1
    }
    Quit tMarked
}

/// <p>Record what <var>pMarked</var> observed about whether this instance marks agent writes.</p>
/// <p><b>A value that is already the answer writes nothing.</b>
/// <class>OcuPilot.Kernel.State.Switch</class> is a store whose defaults are parameters, so an
/// instance nobody has configured holds no row at all -- and that property is what
/// <method>OcuPilot.Install.Smoke.CheckAgentSwitches</method> reads to tell an install that wrote
/// no switches from one that did. Writing the default on every install, and again on every
/// confirmed write, would destroy it for a fact that had not changed. The row is created the first
/// time the observation differs from what is recorded, and updated only when it changes again.</p>
/// <p><b>Never propagates</b> (AD-15): a refresh that could not be written is logged and the
/// caller carries on, because the write it records has already happened.</p>
ClassMethod RecordMarking(pMarked As %Boolean) As %Status
{
    Set tSC = $$$OK
    Try {
        If ..WritesMarked() = ''pMarked Quit
        Kill tValues
        Set tValues("writesMarked") = ''pMarked
        Set tSC = ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set tData = {}
        Do tData.%Set("writesMarked", ''pMarked, "boolean")
        Do tData.%Set("reason", $System.Status.GetErrorText(tSC), "string")
        Do ##class(OcuPilot.Kernel.Audit.Log).Error(..#LOGSUBSYSTEM, ..#REFRESHFAILED, tData)
    }
    Quit tSC
}

/// <p>Observe, through <var>pPortClass</var> and with the caller's own privileges, whether this
/// instance marks agent writes: <var>pMarked</var> is 1 when the instance auditing flag
/// (<code>Security.Audit.Enabled</code> <code>GET</code>) <b>and</b> OcuPilot's marker event
/// (<code>Security.Audit.Event</code> <code>GET</code> for <method>Source</method>,
/// <method>Type</method> and <parameter>EVENTAGENTWRITE</parameter>) are both enabled -- the rule
/// <method>OcuPilot.Install.Installer.ObserveAuditMarking</method> applies at install. Auditing
/// off is not marked whatever the event says, so the event is read only when auditing is on, and
/// a marker event that is not registered (a 404) is not marked, as at install.</p>
/// <p><b>Caller contract:</b> an error status means nothing was observed and <var>pMarked</var>
/// is not an answer; a failed read is never read as "off". The screen's caller of an auditing
/// write calls this after the write and records <var>pMarked</var> only on OK (AD-53).</p>
ClassMethod ObserveMarking(pPortClass As %String, Output pMarked As %Boolean) As %Status
{
    Set pMarked = 0
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tSC = $ClassMethod(pPortClass, "Invoke", "Security.Audit.Enabled", "GET", .tQuery, "", .tSystem, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tSystem) || (tSystem.%GetTypeOf("Enabled") '= "boolean") {
            Set tSC = $$$ERROR($$$GeneralError, "the instance auditing flag was not answered as a boolean")
            Quit
        }
        If 'tSystem.%Get("Enabled") Quit
        Kill tQuery
        Set tQuery("source") = ..Source()
        Set tQuery("type") = ..Type()
        Set tQuery("name") = ..#EVENTAGENTWRITE
        Set tHttp = ""
        Set tSC = $ClassMethod(pPortClass, "Invoke", "Security.Audit.Event", "GET", .tQuery, "", .tEvent, .tHttp, .tFault)
        If $$$ISERR(tSC) && (tHttp = 404) {
            Set tSC = $$$OK
            Quit
        }
        If $$$ISERR(tSC) Quit
        If '$IsObject(tEvent) || (tEvent.%GetTypeOf("Enabled") '= "boolean") {
            Set tSC = $$$ERROR($$$GeneralError, "the marker event's flag was not answered as a boolean")
            Quit
        }
        Set pMarked = tSystem.%Get("Enabled") && tEvent.%Get("Enabled")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pMarked = 0
    Quit tSC
}

/// <p>Report an emission that produced no row. The operation it records has already succeeded, so
/// this is the only trace of the drop -- and OcuPilot renders its own structured log on its own
/// log screens (AD-46), which is where an operator finds it.</p>
/// <p><var>pMessage</var> names what was done, because not every emission records a change:
/// <method>Record</method> passes <parameter>DROPPEDLEDGERREAD</parameter> for
/// <parameter>EVENTLEDGERREAD</parameter> and <parameter>DROPPEDCONFIG</parameter> otherwise. It is
/// trailing and defaults, so a caller that does not answer reports the configuration-change
/// sentence.</p>
/// <p>Its own method so a test can capture what a failed emission reports; production never
/// overrides it.</p>
ClassMethod LogFailure(pVerb As %String, pType As %String, pId As %String, pStatus As %Status, pMessage As %String = {..#DROPPEDCONFIG})
{
    Set tData = {}
    Do tData.%Set("verb", pVerb, "string")
    Do tData.%Set("entityType", pType, "string")
    Do tData.%Set("id", pId, "string")
    Do tData.%Set("reason", $System.Status.GetErrorText(pStatus), "string")
    Do ##class(OcuPilot.Kernel.Audit.Log).Error(..#LOGSUBSYSTEM, pMessage, tData)
}

}
