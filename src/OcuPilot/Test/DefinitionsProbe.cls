/// <p>Test-only <class>OcuPilot.Api.Definitions</class> subclass that replaces all four of the
/// handler's seams: the change record goes into <class>OcuPilot.Test.LogProbe</class>'s capture
/// instead of the console log, and the catalog a create falls back to is
/// <class>OcuPilot.Test.CatalogProbe</class>.</p>
/// <p><b>The audit seam is deliberately NOT overridden.</b> This class replaces the console-log
/// seam only, so a driver reaching <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>
/// through it -- <class>OcuPilot.Test.AgentConnection</class>, and through that
/// <class>OcuPilot.Test.AuditRecord</class>'s Test-connection legs -- gets the real
/// <class>OcuPilot.Kernel.Audit.Event</class> row to read back. The rows such a driver writes
/// name the definitions the driver itself created.</p>
/// <p>The record the audit row is built from is emitted from inside the HTTP worker
/// process, where a process-private capture cannot reach it. Overriding the log seam
/// <method>OcuPilot.Api.Definitions.LogChange</method> writes through lets a test call the real
/// <method>LogChange</method> -- the real change-set computation, the real subsystem name, the
/// real redaction -- and read back exactly the line it produced.</p>
/// <p>The catalog seam is there for the same reason: against the shipped provider row two of the
/// four canonical fallbacks land on the value the state class's own
/// <code>InitialExpression</code> already held, so they could be deleted from
/// <method>OcuPilot.Api.Definitions.CatalogDefaults</method> without moving an assertion. The
/// probe row's tuning differs from both, which makes the fallback observable.</p>
/// <p>The credential seam is the third, and it is there because the rung-unavailable refusal cannot
/// be reached over the wire on an instance that <i>has</i> the rung:
/// <class>OcuPilot.Test.SecretProbe</class> can answer the availability predicate with a switch.
/// It is switchable (<method>SetSecretClass</method>) so
/// <class>OcuPilot.Test.SecretDeletingStore</class> can also reach the arm that runs when the key
/// was written and the definition could not then be disabled -- through the seam the handler
/// already publishes, which is what DW-352 asked for instead of a seam of its own.</p>
/// <p><method>OpenDefinition</method> is overridden here too, and only to count and to answer
/// "not found" on a nominated call. The handler re-reads the definition after the write it has
/// already committed, and that re-read's fallback is a branch no arrangement of real state can
/// reach: a row that is gone fails the <i>first</i> open as well.</p>
/// <p>The port seam is the fourth: <class>OcuPilot.Test.ProviderPortProbe</class> drives Test
/// connection's provider call through the probe catalog's stub adapter, so every leg of it runs in
/// process with no socket opened.</p>
Class OcuPilot.Test.DefinitionsProbe Extends OcuPilot.Api.Definitions
{

ClassMethod LogInfo(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Test.LogProbe).Info(pSubsystem, pMessage, pData)
}

ClassMethod CatalogClass() As %String
{
    Quit "OcuPilot.Test.CatalogProbe"
}

/// <p>The switched credential class, or <class>OcuPilot.Test.SecretProbe</class> when no test set
/// one -- the unset-falls-through shape every other probe here uses.</p>
ClassMethod SecretClass() As %String
{
    If $Get(^||OcuPilotDefinitionsProbe("secretClass")) '= "" Quit ^||OcuPilotDefinitionsProbe("secretClass")
    Quit "OcuPilot.Test.SecretProbe"
}

/// <p>Resolve and store credentials through <var>pClass</var> from now on; <code>""</code> restores
/// <class>OcuPilot.Test.SecretProbe</class>.</p>
ClassMethod SetSecretClass(pClass As %String)
{
    Set ^||OcuPilotDefinitionsProbe("secretClass") = pClass
}

/// <p>Forget every switch and every count.</p>
ClassMethod Forget()
{
    Kill ^||OcuPilotDefinitionsProbe
}

/// <p>How many times <method>OpenDefinition</method> has been entered since the last
/// <method>Forget</method>.</p>
ClassMethod Opens() As %Integer
{
    Quit +$Get(^||OcuPilotDefinitionsProbe("opens"))
}

/// <p>Answer "no such definition" on the <var>pNth</var> call into <method>OpenDefinition</method>
/// from now on. <code>0</code> disarms.</p>
/// <p><b>Counted rather than named</b>: what the arm below is about is the <i>second</i> open --
/// the re-read a handler makes after a write it has already committed -- and a switch keyed on the
/// id would make both opens fail, which is a different branch.</p>
ClassMethod ArmMissingOpen(pNth As %Integer)
{
    Set ^||OcuPilotDefinitionsProbe("missingOpen") = pNth
}

/// <p>The shipped open, counted, and answering "not found" on the armed call.</p>
/// <p><b>The status stays <code>$$$OK</code></b> on the armed call, because that is the shape the
/// handler reads as "this id holds no row" -- an error status is a failed read, which is a
/// different branch again.</p>
ClassMethod OpenDefinition(pId As %String, Output pRow, Output pFound As %Boolean) As %Status
{
    Set tCall = $Increment(^||OcuPilotDefinitionsProbe("opens"))
    If tCall = +$Get(^||OcuPilotDefinitionsProbe("missingOpen")) {
        Set pRow = ""
        Set pFound = 0
        Quit $$$OK
    }
    Quit ##super(pId, .pRow, .pFound)
}

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProviderPortProbe"
}

/// <p>The in-process call, so the port probe's process-private stubs answer it.</p>
ClassMethod TestCallClass() As %String
{
    Quit "OcuPilot.Test.AgentConnectionInline"
}

}
