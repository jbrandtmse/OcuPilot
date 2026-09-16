/// <p>The credential ladder (AD-42): a definition's stored credential <i>reference</i> resolved to
/// the secret itself.</p>
/// <p><b>It returns a <class>%String</class>, never a <class>%Status</class>, and that is the
/// point.</b> A status carries text, and text written from a failed resolution is text that names
/// what it was resolving -- which on this path is a credential. So the value answer is
/// <code>""</code> for unresolved, and the caller turns that into
/// <code>PROVIDER.CREDENTIAL</code> naming the reference. Nothing on the resolution path builds a
/// message, and nothing on it writes to a log (AD-35).</p>
/// <p><b>An <code>Output %Boolean</code> says whether the <code>""</code> was an absence or a
/// failure</b> (DW-343). A flag carries no text, so the reason the value answer is a bare string
/// survives intact; what it buys is that a locked row, or a store that raised, is no longer
/// indistinguishable from a reference nothing holds -- the confusion that let a transient fault
/// disable a working definition.</p>
/// <p><b>Both rungs ship.</b> <code>env</code> reads an environment variable and answers in any
/// namespace; <code>creds</code> reads an <code>Ens.Config.Credentials</code> row and answers only
/// where the rung is reachable, <code>""</code> otherwise. <method>Store</method> and
/// <method>Clear</method> are the write paths, and they exist only for the <code>creds</code>
/// rung: <class>%SYSTEM.Util</class> publishes <method>GetEnviron</method> and no setter, so the
/// <code>env</code> rung's store is the operating system and the operator owns it.</p>
/// <p><b><parameter>CREDSCLASS</parameter> is named through <code>$ClassMethod</code> and
/// late-bound property access, never <code>##class(...)</code></b>, so the tree compiles on an
/// edition without Interoperability -- which is what CI's <code>images</code> leg does. The one
/// literal is the parameter itself.</p>
/// <p><b><method>Store</method> and <method>Clear</method> are the only methods here that return a
/// <class>%Status</class> or write a log line</b>, and neither carries a value: the status each
/// answers is OcuPilot's own and names the reference alone, and what reaches the log is the vendor
/// status's error <i>codes</i>, never its text.</p>
Class OcuPilot.Kernel.Secret.Ladder Extends %RegisteredObject
{

/// <p>The credential class the <code>creds</code> rung reads and writes. The single literal naming
/// it; every use goes through dynamic dispatch, so a namespace without it still compiles.</p>
Parameter CREDSCLASS = "Ens.Config.Credentials";

/// <p>The class the rung predicate asks whether this namespace is interoperability-enabled.
/// Named the way <parameter>CREDSCLASS</parameter> is, and reached the same way, so an edition
/// without it still compiles this tree.</p>
Parameter ENSEMBLEMGRCLASS = "%Library.EnsembleMgr";

/// <p>The <method>$System.License.GetFeature</method> index for interoperability.</p>
Parameter INTEROPFEATURE As %Integer = 1;

/// <p>The subsystem <method>Store</method>'s and <method>Clear</method>'s log lines are written
/// under.</p>
Parameter LOGSUBSYSTEM = "agent-credential";

/// <p><method>Clear</method>'s outcome: the entry was there and is gone.</p>
Parameter CLEARREMOVED = "removed";

/// <p><method>Clear</method>'s outcome: no entry holds the reference, so there was nothing to
/// remove.</p>
Parameter CLEARABSENT = "absent";

/// <p><method>Clear</method>'s outcome: the rung is not reachable from this namespace, so whether
/// an entry exists was not learned and nothing was removed.</p>
Parameter CLEARUNREACHABLE = "unreachable";

/// <p><method>Clear</method>'s outcome: the store refused or raised on the delete.</p>
Parameter CLEARFAILED = "failed";

/// <p>The secret <var>pCredType</var> and its reference name resolve to, or <code>""</code>.</p>
/// <p><var>pEnvVarName</var> is read for <code>env</code> and <var>pCredentialName</var> for
/// <code>creds</code>; the XOR invariant
/// (<method>OcuPilot.Kernel.AgentRules.Normalize</method>) has already cleared whichever the type
/// did not select, so only one of them is ever populated.</p>
/// <p><b>The <code>env</code> arm consults no namespace and no rung predicate</b>, and leaves
/// before either is reached: an environment variable is readable wherever this instance runs, and
/// gating it on the credentials rung's availability would make it fail on the editions that rung is
/// absent from. <class>OcuPilot.Test.SecretProbe</class> can make the predicate raise, which is what
/// makes that falsifiable from one namespace.</p>
/// <p><b>Caller contract:</b> assign the result straight onto the holder that will use it --
/// <property>OcuPilot.Kernel.Provider.Base.ApiKey</property> -- and never into a local. An
/// <code>^%ETN</code> entry captures every local at every stack level (AD-48), and OcuPilot
/// renders that log (AD-35, AD-46).</p>
/// <p><code>$Char(0)</code> is normalized to <code>""</code>: an environment variable set to the
/// empty string reads back as the one-character sentinel on some paths, which every ordinary
/// emptiness guard passes.</p>
/// <p><var>pTransient</var> is 1 when a <code>""</code> came from a store that could not be read --
/// the rung is not reachable from this namespace, the rung predicate or the store raised, or the
/// row would not open -- and 0 when it came from an absence the store answered for: no reference,
/// no such entry, or an empty value. The <code>env</code> arm reports 0 always: an environment
/// variable that is not set and one set to nothing are the same state, and there is no store to
/// fail.</p>
ClassMethod Resolve(pCredType As %String, pEnvVarName As %String = "", pCredentialName As %String = "", Output pTransient As %Boolean) As %String
{
    Set pTransient = 0
    If pCredType = ##class(OcuPilot.Kernel.AgentRules).#CREDTYPEENV {
        If pEnvVarName = "" Quit ""
        Quit ..Environment(pEnvVarName)
    }
    If pCredType '= ##class(OcuPilot.Kernel.AgentRules).#CREDTYPECREDS Quit ""
    If pCredentialName = "" Quit ""
    ; The rung predicate is asked inside Credential's own Try, and only there. Asking it here as
    ; well would be the one call on this path outside a Catch, so a predicate that raised would
    ; leave Resolve by exception rather than by the "" the matrix specifies.
    Quit ..Credential(pCredentialName, .pTransient)
}

/// <p>Whether the <code>creds</code> rung can be reached from the calling namespace: three
/// conditions, all required (DW-350).</p>
/// <ol>
/// <li><parameter>CREDSCLASS</parameter> is compiled here, asked through
/// <method>%Dictionary.CompiledClass.%ExistsId</method>, which names no class outside
/// <package>%Dictionary</package> and so compiles on every edition.</li>
/// <li>This namespace is interoperability-enabled
/// (<method>%Library.EnsembleMgr.IsEnsembleNamespace</method>). A compiled class is not a usable
/// one: the credential entry's secondary store lives in the namespace's own interoperability
/// tables, and the vendor's <method>SecondaryDelete</method> checks more than
/// <method>SecondarySet</method> does (<file>irislib/%SYS/Ensemble.cls</file> :543 against :524),
/// so a namespace that can write an entry cannot necessarily remove one.</li>
/// <li>The instance is licensed for interoperability
/// (<code>$System.License.GetFeature(1)</code>), which is the other half of the same
/// question.</li>
/// </ol>
/// <p>This is what Story 3.3's own acceptance criterion already said, and what the delete path
/// added by Story 3.9 requires. Probed on this instance, HSCUSTOM, 2026-09-16: both new
/// conditions read 1, so narrowing the predicate does not switch the rung off here.</p>
/// <p><b>Named through <code>$ClassMethod</code></b>, like <parameter>CREDSCLASS</parameter> and
/// for the same reason: <class>%Library.EnsembleMgr</class> is not on every edition CI compiles
/// this tree on. A namespace that cannot reach it answers "not available", which is the
/// conservative direction.</p>
/// <p><b>Overridable</b> so a test can drive the unreachable arm on an instance where the class is
/// present, and drive the <code>env</code> arm with this predicate armed to raise. Production never
/// overrides it.</p>
ClassMethod CredentialsRungAvailable() As %Boolean
{
    Set tAvailable = 0
    Try {
        If '##class(%Dictionary.CompiledClass).%ExistsId(..#CREDSCLASS) Quit
        If '##class(%Dictionary.CompiledClass).%ExistsId(..#ENSEMBLEMGRCLASS) Quit
        If '$ClassMethod(..#ENSEMBLEMGRCLASS, "IsEnsembleNamespace") Quit
        If '$System.License.GetFeature(..#INTEROPFEATURE) Quit
        Set tAvailable = 1
    } Catch ex {
        Set tAvailable = 0
    }
    Quit tAvailable
}

/// <p>Remove the credential entry <var>pCredentialName</var> from this instance, through the
/// vendor's own <method>%DeleteId</method>, and report what happened in <var>pOutcome</var>:
/// <parameter>CLEARREMOVED</parameter>, <parameter>CLEARABSENT</parameter> (no such entry, or no
/// reference named), <parameter>CLEARUNREACHABLE</parameter> (the rung is not reachable from this
/// namespace, so nothing was looked for) or <parameter>CLEARFAILED</parameter>. The status is
/// <code>$$$OK</code> for every outcome but the last.</p>
/// <p><b>Bounded on both sides by the caller, not here</b> (AD-37). This method removes what it is
/// told to; deciding that OcuPilot created the entry and that no surviving definition names it is
/// <method>OcuPilot.Api.Definitions.ClearOwnedCredential</method>'s, which is the one place that
/// judgement is made.</p>
/// <p>It names the <b>reference</b> and never a value, in its status and in its log line alike
/// (AD-35, AD-42) -- the discipline <method>Store</method> follows, and for the same reason: the
/// log this writes is a log OcuPilot renders.</p>
ClassMethod Clear(pCredentialName As %String, Output pOutcome As %String) As %Status
{
    Set tSC = $$$OK
    Set pOutcome = ..#CLEARABSENT
    Try {
        If pCredentialName = "" Quit
        If '..CredentialsRungAvailable() {
            Set pOutcome = ..#CLEARUNREACHABLE
            Quit
        }
        If '$ClassMethod(..#CREDSCLASS, "%ExistsId", pCredentialName) Quit
        Set tDeleteSC = $ClassMethod(..#CREDSCLASS, "%DeleteId", pCredentialName)
        If $$$ISERR(tDeleteSC) {
            Set pOutcome = ..#CLEARFAILED
            Do ..LogCodes("the credential store refused the delete", tDeleteSC)
            Set tSC = $$$ERROR($$$GeneralError, "the credential store refused the delete for reference: " _ pCredentialName)
            Quit
        }
        Set pOutcome = ..#CLEARREMOVED
    } Catch ex {
        Set pOutcome = ..#CLEARFAILED
        Do ..LogCodes("the credential store raised on the delete", ex.AsStatus())
        Set tSC = $$$ERROR($$$GeneralError, "the credential store refused the delete for reference: " _ pCredentialName)
    }
    Quit tSC
}

/// <p>The secret the credential entry <var>pName</var> holds, or <code>""</code> -- for an empty
/// name, a rung this namespace cannot reach, a row this instance does not hold, an entry whose
/// value is empty, or a failure of the store. <var>pTransient</var> is 1 for an unreachable rung
/// and for a failure, and 0 for the other three, so a caller can tell a reference that resolves to
/// nothing from a store it could not read.</p>
/// <p><b>An unreachable rung is transient, not absent.</b> The predicate answers 0 both for a
/// namespace the rung does not serve and for a check that raised inside its own
/// <code>Try</code>; neither says anything about whether the entry exists, and reading either as
/// an absence would disable a definition whose reference is fine.</p>
/// <p><b>Never through the vendor's <method>GetValue</method></b>, which builds dynamic SQL and
/// answers a <code>&lt;N/A ...&gt;</code> <i>string</i> on failure: a caller would treat that
/// placeholder as a key and send it. The row is opened and its <property>Password</property> read
/// instead, so a failure is an absence.</p>
/// <p><b>The vendor's <method>PasswordGet</method> is not a pure read on every row.</b> A row
/// still holding its password in the old in-row column is migrated to the secondary store on the
/// first read -- <method>PasswordSet</method> and <method>%Save</method>, from inside the getter --
/// which needs <code>%Ens_Credentials:WRITE</code> and, failing, resolves to <code>""</code>. No
/// row OcuPilot creates is in that shape; one an operator points a definition at may be.</p>
/// <p><b>No named local ever holds the value.</b> It is returned straight out of the property
/// read, which is why this uses <code>Return</code> rather than an argumented <code>Quit</code>
/// (not allowed inside <code>Try</code>, ERROR #1043).</p>
/// <p><code>$Char(0)</code> is normalized to <code>""</code>, as
/// <method>Environment</method> does it, so the sentinel a SQL-updated empty column reads back as
/// is an unresolved reference rather than a one-character key.</p>
ClassMethod Credential(pName As %String, Output pTransient As %Boolean) As %String
{
    Set pTransient = 0
    Try {
        If pName = "" Return ""
        If '..CredentialsRungAvailable() {
            Set pTransient = 1
            Return ""
        }
        If '$ClassMethod(..#CREDSCLASS, "%ExistsId", pName) Return ""
        Set tRow = $ClassMethod(..#CREDSCLASS, "%OpenId", pName)
        If '$IsObject(tRow) {
            ; The entry exists and would not open: a lock, a privilege, a store that answered
            ; nothing. Transient, not absent -- the distinction DW-343 exists for.
            Set pTransient = 1
            Return ""
        }
        ; Read twice rather than held in a local, and normalized the way Environment() is: a
        ; %String column a SQL UPDATE set to '' reads back through the object layer as the
        ; one-character $Char(0) sentinel, which every ordinary emptiness guard passes -- including
        ; the one in Base.Invoke that turns "" into PROVIDER.CREDENTIAL.
        If $Property(tRow, "Password") = $Char(0) Return ""
        Return $Property(tRow, "Password")
    } Catch ex {
        ; A raise anywhere on the read -- the predicate, the existence test, the open, the
        ; property read -- is a failure of the store, never evidence that the reference names
        ; nothing.
        Set pTransient = 1
        Return ""
    }
    Quit ""
}

/// <p>Put the key <var>pBody</var> carries under <var>pField</var> into the credential entry
/// <var>pCredentialName</var>, creating the entry when this instance does not hold one.</p>
/// <p><b>An existing entry is overwritten only when <var>pMayOverwrite</var> is 1</b> (AD-37). The
/// default refuses: the entry is not opened, nothing is written, <var>pDeclined</var> is 1 and the
/// status is an error naming the reference. Whether OcuPilot owns the entry is the caller's
/// judgement; this method only honours it.</p>
/// <p><b>The value moves member to property and is never bound to a local</b>: the
/// <class>%DynamicObject</class> member is read straight into the assignment onto the row's
/// <property>Password</property>, because <code>^%ETN</code> captures the local symbol table and
/// not an object's properties (AD-48, AD-35).</p>
/// <p><b>Caller contract:</b> the caller has already decided that this definition's rung is
/// <code>creds</code>, that the rung is reachable, that the value is shaped like a key for the
/// provider, and whether an existing entry may be overwritten -- this method makes none of those
/// judgements and writes whatever it is given.</p>
/// <p>On a vendor failure it answers an OcuPilot-written status naming the <b>reference</b> alone,
/// and sends the vendor status's <method>$System.Status.GetErrorCodes</method> to the log. The
/// vendor's own text is discarded: it is written about a credential write, and OcuPilot renders the
/// log it writes (AD-35, AD-46).</p>
/// <p><var>pCreated</var> is 1 when this call brought the entry into being and 0 when it wrote
/// over one that was already there. It is the ownership mark
/// <property>OcuPilot.Kernel.State.Agent.CredentialCreated</property> records, and AD-37's bounded
/// deletion turns on it: OcuPilot removes what OcuPilot created and never an operator's own
/// entry.</p>
ClassMethod Store(pCredentialName As %String, pBody As %DynamicObject, pField As %String, Output pCreated As %Boolean, pMayOverwrite As %Boolean = 0, Output pDeclined As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set tRow = ""
    Set pCreated = 0
    Set pDeclined = 0
    Try {
        If pCredentialName = "" {
            Set tSC = $$$ERROR($$$GeneralError, "no credential reference was named")
            Quit
        }
        If '..CredentialsRungAvailable() {
            Set tSC = $$$ERROR($$$GeneralError, "the credential store is not reachable from this namespace, so nothing was written for reference: " _ pCredentialName)
            Quit
        }
        If '$IsObject(pBody) {
            Set tSC = $$$ERROR($$$GeneralError, "no key was supplied for reference: " _ pCredentialName)
            Quit
        }
        If $ClassMethod(..#CREDSCLASS, "%ExistsId", pCredentialName) {
            If 'pMayOverwrite {
                Set pDeclined = 1
                Set tSC = $$$ERROR($$$GeneralError, "an existing credential entry holds reference " _ pCredentialName _ " and the caller may not overwrite it, so nothing was written")
                Quit
            }
            Set tRow = $ClassMethod(..#CREDSCLASS, "%OpenId", pCredentialName)
        } Else {
            Set pCreated = 1
            Set tRow = $ClassMethod(..#CREDSCLASS, "%New")
            ; The entry's name is its id, and it is set before the value: the vendor's own
            ; PasswordSet reads the name to decide where to persist, and an unnamed row holds the
            ; value in its own column instead of the secondary store.
            If $IsObject(tRow) Set $Property(tRow, "SystemName") = pCredentialName
        }
        If '$IsObject(tRow) {
            Set tSC = $$$ERROR($$$GeneralError, "the credential store would not open reference: " _ pCredentialName)
            Quit
        }
        Set $Property(tRow, "Password") = pBody.%Get(pField)
        Set tSaveSC = tRow.%Save()
        Set tRow = ""
        If $$$ISERR(tSaveSC) {
            ; Nothing was created, whatever the branch above intended: an ownership mark recorded
            ; against a row that was never written would license a delete of somebody else's entry
            ; if one later appeared under that name.
            Set pCreated = 0
            Do ..LogCodes("the credential store refused the write", tSaveSC)
            Set tSC = $$$ERROR($$$GeneralError, "the credential store refused the write for reference: " _ pCredentialName)
        }
    } Catch ex {
        Set tRow = ""
        Set pCreated = 0
        Do ..LogCodes("the credential store raised on the write", ex.AsStatus())
        Set tSC = $$$ERROR($$$GeneralError, "the credential store refused the write for reference: " _ pCredentialName)
    }
    Quit tSC
}

/// <p>Send <var>pStatus</var>'s error <b>codes</b> to the log, under a status this class wrote, so
/// the vendor's own text never reaches a log line OcuPilot renders (AD-35, AD-39, AD-46).</p>
/// <p><b>Overridable</b>, for the reason <method>OcuPilot.Kernel.Fault.LogError</method> is: the
/// claim is about what does <i>not</i> reach the log, and a hard class name leaves a test nothing to
/// intercept. <class>OcuPilot.Test.SecretProbe</class> captures the pair.
/// Production never overrides it.</p>
ClassMethod LogCodes(pMessage As %String, pStatus As %Status)
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, $$$ERROR($$$GeneralError, ..LogReason(pStatus)))
}

/// <p>The text a store failure's log line carries for <var>pStatus</var>: the vendor status's error
/// <b>codes</b> and none of its message (AD-35, AD-39).</p>
/// <p>Its own method for the reason <method>OcuPilot.Kernel.Provider.Base.ReasonFor</method> is
/// one: the claim is about what the line does not say, and a test that rebuilt the string itself
/// would assert a copy. <class>OcuPilot.Test.Secret</class> asserts this composition against a real
/// vendor refusal.</p>
ClassMethod LogReason(pStatus As %Status) As %String
{
    Quit "vendor status codes: " _ $System.Status.GetErrorCodes(pStatus)
}

/// <p>One environment variable's value, or <code>""</code>. The single seam a test overrides to
/// put a canary in play without setting a variable on the instance; production never overrides
/// it.</p>
/// <p>Read twice rather than held in a local: the value is the secret, and a frame that holds it
/// in a local is a frame whose symbol table an <code>^%ETN</code> entry would capture (AD-48).</p>
ClassMethod Environment(pName As %String) As %String
{
    If $System.Util.GetEnviron(pName) = $Char(0) Quit ""
    Quit $System.Util.GetEnviron(pName)
}

}
