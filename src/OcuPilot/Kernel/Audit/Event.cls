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

/// <p>The log message a dropped configuration-change emission reports
/// (<method>LogFailure</method>).</p>
Parameter DROPPEDCONFIG = "the configuration change was made and no audit row was written";

/// <p>The log message a dropped <parameter>EVENTLEDGERREAD</parameter> emission reports. A read is
/// not a change, and saying it was one sends an operator looking for a configuration edit that
/// never happened.</p>
Parameter DROPPEDLEDGERREAD = "the agent ledger read was answered and no audit row was written";

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
    Quit $ListBuild(##class(OcuPilot.Kernel.State.Base).#AUDITNAME, ..#EVENTCONFIG, ..#EVENTSECURITY, ..#EVENTLEDGERREAD)
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
    If $$$ISERR(tSC) Do ..LogFailure(pVerb, pType, pId, tSC, $Select(pEventName = ..#EVENTLEDGERREAD: ..#DROPPEDLEDGERREAD, 1: ..#DROPPEDCONFIG))
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
