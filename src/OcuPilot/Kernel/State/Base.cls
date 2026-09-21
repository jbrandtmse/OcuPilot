Include %occErrors

/// <p>The tree's <b>only</b> escalation point (AD-9). Abstract persistent base providing
/// guarded save / open / exists and guarded global access, each performing
/// <code>New $ROLES</code> and <code>$SYSTEM.Security.AddRoles(&lt;application&gt;)</code>
/// in the <b>same method frame</b> as the guarded access it protects -- never split across
/// a helper and its caller.</p>
/// <p><b>Golden example -- the frame constraint.</b> <code>New $ROLES</code> unwinds with
/// the <i>method</i> frame, not the block, so a helper that escalates and returns has
/// already lost the role before its caller does anything:</p>
/// <pre>
/// ; WRONG -- the role is gone the moment Escalate() returns.
/// Do ..Escalate()  Set tSC = pObject.%Save()
///
/// ; RIGHT -- escalation and the guarded access share one frame.
/// ClassMethod SaveGuarded(pObject As %Persistent) As %Status
/// {
///     Set tSC = $$$OK
///     New $ROLES
///     Try {
///         Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
///         If $$$ISERR(tSC) Quit
///         Set tSC = pObject.%Save()
///     }
///     Catch ex { Set tSC = ex.AsStatus() }
///     Quit tSC
/// }
/// </pre>
/// <p><b>Two ordering rules (AD-9), enforced mechanically by
/// <code>scripts/check-objectscript.py</code> (AC6) rather than by inference:</b></p>
/// <ol>
/// <li><b>Nothing is spawned from inside an escalated frame.</b> A <code>JOB</code>
/// inherits <code>$ROLES</code> at the moment of the spawn and keeps it for the child's
/// entire life -- a <code>New $ROLES</code> in this class's frame does not reach a child
/// already running. No method here contains a <code>JOB</code> command.</li>
/// <li><b>Nothing re-enters from inside an escalated frame.</b> A storage method never
/// calls a tool, the AdminPort, the ProviderPort, or any code that could -- no method
/// here references <code>OcuPilot.Api</code>, <code>OcuPilot.Port</code>,
/// <code>OcuPilot.Screen</code> or <code>OcuPilot.Area</code>.</li>
/// </ol>
/// <p>Role names normalize to upper case in <code>$ROLES</code> -- never compare
/// case-sensitively against it.</p>
Class OcuPilot.Kernel.State.Base Extends %Persistent [ Abstract ]
{

/// <p>Name of the privileged routine application every guarded method escalates
/// through. Kernel-visible (AD-10) so a later governance story, or
/// <class>OcuPilot.Install.Installer</class>, names it without inventing a second copy
/// of the string.</p>
Parameter APPLICATION As %String = "OcuPilotState";

/// <p>Name of OcuPilot's protected-state database (AD-9).</p>
Parameter DATABASENAME As %String = "OCUPILOT";

/// <p>Name of the <code>%DB_</code> resource guarding <parameter>DATABASENAME</parameter>
/// -- also the name of its auto-created implicit role, which is the role every guarded
/// method here obtains.</p>
/// <p><b>Must be kept as the literal <code>"%DB_" _ DATABASENAME</code></b> --
/// <method>OcuPilot.Install.Installer.Names</method> derives the probe profile's
/// equivalent value by that exact concatenation, so changing one without the other
/// silently diverges production from probe (AD-10).</p>
Parameter DBRESOURCE As %String = "%DB_OCUPILOT";

/// <p>Name of the OcuPilot administrative resource, and of the role of the same name
/// (AC2).</p>
Parameter ADMINRESOURCE As %String = "OcuPilotAdmin";

/// <p>Global-mapping prefix pattern for OcuPilot's protected globals (AC3).</p>
Parameter MAPPINGPATTERN As %String = "OcuPilot*";

/// <p>Name of the TLS configuration every outbound provider call is made through (AD-32).
/// Kernel-visible for the reason <parameter>APPLICATION</parameter> is: the installer creates
/// it, the provider port names it on the request, and the uninstall confirmation lists it, so
/// the three read one literal rather than three copies of it.</p>
/// <p>The probe profile's equivalent is this value with the profile suffix appended, by the
/// same derivation <method>OcuPilot.Install.Installer.Names</method> applies to every other
/// name here.</p>
Parameter SSLCONFIG As %String = "OcuPilotProvider";

/// <p>Audit event triple (AD-15) -- Source and Type. The event Name carries a
/// profile-specific suffix; see <method>OcuPilot.Install.Installer.Names</method>.</p>
Parameter AUDITSOURCE As %String = "OcuPilot";

Parameter AUDITTYPE As %String = "Security";

Parameter AUDITNAME As %String = "RoleGranted";

/// <p>The row's write counter, raised by one on every write that goes through
/// <method>GuardedSaveIfCurrent</method> (Consistency Conventions: concurrent writes to
/// OcuPilot's own state). It is never a wire field and never a client-supplied token: the window
/// it closes opens and closes inside one request.</p>
/// <p>Declared on the base so every store inherits one counter rather than each answering the
/// question again. Rows written before this property existed hold no value at all, which SQL
/// reads as <code>NULL</code>; <method>GuardedSaveIfCurrent</method>'s
/// <code>COALESCE(RowVersion, 0)</code> is what makes such a row compare equal to the 0 a caller
/// reads off it.</p>
Property RowVersion As %Integer [ InitialExpression = 0 ];

/// <p>The sentence a stale save is refused with. A parameter rather than a literal so the
/// refusal and <method>IsStaleSave</method> name the same text rather than two copies of it --
/// the idiom <parameter>OcuPilot.Kernel.State.Agent.DEFAULTDISABLEDREASON</parameter>
/// established.</p>
Parameter STALESAVEREASON = "the row changed on this instance after it was read, so the save was refused";

/// <p>Seconds <method>GuardedSaveWithinCap</method> waits for a bounded list's lock before
/// refusing. Short, because the critical section it guards is a count and a save.</p>
Parameter CAPLOCKTIMEOUT As %Integer = 5;

/// <p>The sentence a cap-bounded save is refused with when its critical section could not be
/// entered. A parameter rather than a literal, for <parameter>STALESAVEREASON</parameter>'s
/// reason: the refusal and <method>IsCapBusy</method> name one text rather than two copies.</p>
Parameter CAPBUSYREASON = "another write to this account's bounded list held it, so the save was refused";

/// <p>The declared length of the two route columns cut against it: the ledger's
/// <property>OcuPilot.Kernel.State.Ledger.Route</property> and the turn's
/// <property>OcuPilot.Kernel.State.Turn.ContextRoute</property>. Declared once here so the cap a
/// writer cuts at is not a literal repeated beside each column; the invariant that this equals
/// both <code>MAXLEN</code>s is asserted by <class>OcuPilot.Test.Ledger</class>, because a
/// property's <code>MAXLEN</code> cannot itself read a parameter.</p>
/// <p>Not every route column on this base: <property>OcuPilot.Kernel.State.Nav.Route</property> is
/// declared <code>MAXLEN = ""</code> and is cut nowhere, its value being a registry route the
/// directive echoes back rather than caller text.</p>
Parameter ROUTEMAXLENGTH As %Integer = 512;

/// <p>The window <method>BoundedWhere</method> applies when its caller asks for 0 hours.</p>
Parameter BOUNDEDDEFAULTHOURS As %Integer = 24;

/// <p>The widest window <method>BoundedWhere</method> admits, in hours: thirty days.</p>
Parameter BOUNDEDMAXHOURS As %Integer = 720;

/// <p>The window value that selects keyed mode: no time predicate, the caller's own keyed predicate
/// being the bound.</p>
Parameter BOUNDEDKEYED As %Integer = -1;

/// <p>The shape a time column name passed to <method>BoundedWhere</method> must take: a column, or
/// an alias and a column.</p>
Parameter BOUNDEDCOLUMNPATTERN = "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)?$";

/// <p>Save <var>pObject</var> -- any persistent instance of this class or a subclass --
/// through the escalated frame.</p>
ClassMethod GuardedSave(pObject As %Persistent) As %Status
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tSC = pObject.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Save <var>pObject</var> only while the row still carries the version
/// <var>pExpected</var> names -- the conditional write every store on this base funnels an edit
/// through (Consistency Conventions: concurrent writes to OcuPilot's own state; the idiom is
/// AD-34's, applied to the stores themselves).</p>
/// <p><b>Exactly one caller wins and the loser is told.</b> Inside one transaction the row's
/// <property>RowVersion</property> is raised by a conditional <code>UPDATE</code> that matches
/// only while it still reads <var>pExpected</var>; a row count of 0 means another writer got
/// there first, the transaction rolls back, nothing is written, and the answer is
/// <parameter>STALESAVEREASON</parameter> -- a refusal, never a retry and never a silent
/// overwrite. <method>IsStaleSave</method> is how a caller tells that refusal from a read
/// failure.</p>
/// <p><b>A row with no id yet is created</b> rather than refused: there is nothing for it to be
/// stale against. It takes version 1, so the first edit after it is conditional like any
/// other.</p>
/// <p><b>The table name is read from the class dictionary</b>, never transcribed and never taken
/// from a caller (AD-21): it is <property>%Dictionary.CompiledClass.SqlQualifiedNameQ</property>
/// for <var>pObject</var>'s own class, which is what makes one method serve every subclass. The
/// three values that vary are bound, not concatenated.</p>
/// <p><code>COALESCE(RowVersion, 0)</code> is load-bearing: a row written before the property
/// existed holds no value, SQL reads that as <code>NULL</code>, and <code>NULL = 0</code> is
/// never true -- so without it every pre-existing row would be permanently unsaveable.</p>
ClassMethod GuardedSaveIfCurrent(pObject As Base, pExpected As %Integer = 0) As %Status
{
    Set tSC = $$$OK
    Set tInTx = 0
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tNext = +pExpected + 1
        If pObject.%Id() = "" {
            Set pObject.RowVersion = 1
            Set tSC = pObject.%Save()
            Quit
        }
        Set tTable = ..QualifiedTableName(pObject.%ClassName(1))
        If tTable = "" {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedSaveIfCurrent found no SQL table for " _ pObject.%ClassName(1))
            Quit
        }
        TSTART
        Set tInTx = 1
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE " _ tTable _ " SET RowVersion = ? WHERE ID = ? AND COALESCE(RowVersion, 0) = ?", tNext, pObject.%Id(), +pExpected)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedSaveIfCurrent failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        If +tRS.%ROWCOUNT = 0 {
            Set tSC = $$$ERROR($$$GeneralError, ..#STALESAVEREASON)
            Quit
        }
        Set pObject.RowVersion = tNext
        Set tSC = pObject.%Save()
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

/// <p>Whether <var>pStatus</var> is <method>GuardedSaveIfCurrent</method>'s stale refusal rather
/// than a read or write failure. One check, so a handler mapping it to
/// <parameter>OcuPilot.Api.Error.STATECONFLICT</parameter> does not spell the sentence a second
/// time.</p>
ClassMethod IsStaleSave(pStatus As %Status) As %Boolean
{
    If $$$ISOK(pStatus) Quit 0
    Quit $System.Status.GetErrorText(pStatus) [ ..#STALESAVEREASON
}

/// <p>Whether <var>pStatus</var> is a unique-index violation -- a create whose key another
/// writer inserted between this caller's look-up and its save (DW-1327).</p>
/// <p>One check, so a store re-reading the row a race created does not spell the test twice.
/// Asked of the error code rather than of its text, which is localized.</p>
ClassMethod IsDuplicateKey(pStatus As %Status) As %Boolean
{
    If $$$ISOK(pStatus) Quit 0
    Quit $System.Status.Equals(pStatus, $$$KeyNotUnique)
}

/// <p>Whether <var>pStatus</var> is <method>GuardedSaveWithinCap</method>'s busy refusal rather
/// than a write failure.</p>
ClassMethod IsCapBusy(pStatus As %Status) As %Boolean
{
    If $$$ISOK(pStatus) Quit 0
    Quit $System.Status.GetErrorText(pStatus) [ ..#CAPBUSYREASON
}

/// <p>Save <var>pObject</var> only while <var>pCountSql</var> -- a whole SQL literal taking the
/// two key values as its parameters -- answers fewer than <var>pMax</var> rows.
/// <var>pAtLimit</var> is 1, and nothing is written, when it does not.</p>
/// <p><b>The count and the save are one critical section</b> (DW-1327). Both run inside this
/// frame's escalation while <code>^OcuPilotStateCap(pKey1, pKey2)</code> is held, so two adds of
/// different names cannot both read the bound as not-yet-reached and both write. A read-then-write
/// cap outside a lock stores <var>pMax</var> + 1; a transaction alone does not close it, because
/// a count takes no row lock. A caller that cannot enter the section is refused with
/// <parameter>CAPBUSYREASON</parameter> rather than writing past the bound.</p>
/// <p>The lock is released in this same frame, on every path.</p>
ClassMethod GuardedSaveWithinCap(pObject As Base, pKey1 As %String, pKey2 As %String, pCountSql As %String, pMax As %Integer, Output pAtLimit As %Boolean) As %Status [ Private ]
{
    Set pAtLimit = 0
    Set tSC = $$$OK
    Set tHeld = 0
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Lock +^OcuPilotStateCap(pKey1, pKey2):..#CAPLOCKTIMEOUT
        Set tHeld = $Test
        If 'tHeld {
            Set tSC = $$$ERROR($$$GeneralError, ..#CAPBUSYREASON)
            Quit
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pCountSql, pKey1, pKey2)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedSaveWithinCap failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        Set tCount = 0
        If tRS.%Next() Set tCount = +tRS.%GetData(1)
        Set tRS = ""
        If tCount >= +pMax {
            Set pAtLimit = 1
            Quit
        }
        Set tSC = pObject.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tHeld {
        Lock -^OcuPilotStateCap(pKey1, pKey2)
    }
    Quit tSC
}

/// <p>The SQL table <var>pClassName</var> projects to, qualified and quoted as the dictionary
/// spells it, or <code>""</code> for a class that projects to none.</p>
/// <p>Read from <class>%Dictionary.CompiledClass</class> rather than from a per-subclass literal:
/// a transcribed table name is a second source for something the compiler already owns, and the
/// one place it would be noticed wrong is a conditional update that silently matched nothing.</p>
ClassMethod QualifiedTableName(pClassName As %String) As %String [ Private ]
{
    Set tName = ""
    Try {
        Set tClass = ##class(%Dictionary.CompiledClass).%OpenId(pClassName, 0)
        If $IsObject(tClass) Set tName = tClass.SqlQualifiedNameQ
        Set tClass = ""
    } Catch ex {
        Set tName = ""
    }
    Quit tName
}

/// <p>Open by id through the escalated frame. Invoke as
/// <code>##class(&lt;ConcreteSubclass&gt;).GuardedOpenId(pId, .pObject)</code> -- this
/// relies on ordinary ObjectScript class-method inheritance, where the implementing
/// class is fixed by the call site, never on dynamic invocation by name (Story 1.1
/// declined that surface under AD-8; it is not reintroduced here).</p>
ClassMethod GuardedOpenId(pId As %String, Output pObject As Base) As %Status
{
    Set tSC = $$$OK
    Set pObject = $$$NULLOREF
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set pObject = ..%OpenId(pId, 0, .tSC)
        If $$$ISERR(tSC) Quit
        If '$IsObject(pObject) {
            Set tSC = $$$ERROR($$$GeneralError, "Object not found: " _ pId)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The text of stream property <var>pProperty</var> on already-open guarded object
/// <var>pObject</var>, escalated in this frame (AD-9). A stream is read lazily: the object's
/// scalar properties are already in memory once <method>GuardedOpenId</method> returns, but a
/// stream property's bytes are fetched from protected storage only when read, which is why this
/// exists as its own escalated call rather than being folded into the caller's own frame --
/// <code>AddRoles</code> authorizes by the calling routine's identity (AC6,
/// <file>scripts/check-objectscript.py</file>), never by who is holding the reference, so the
/// read has to happen inside a method compiled into this class's own routine. Answers
/// <code>""</code> for a null object, an unknown or non-stream property, or an empty stream.</p>
ClassMethod GuardedStreamText(pObject As Base, pProperty As %String, Output pText As %String) As %Status [ Private ]
{
    Set pText = ""
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        If '$IsObject(pObject) Quit
        Set tStream = $Property(pObject, pProperty)
        If '$IsObject(tStream) Quit
        If tStream.Size > 0 Set pText = tStream.Read(tStream.Size)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pId</var> exists, through the escalated frame.</p>
ClassMethod GuardedExistsId(pId As %String, Output pExists As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pExists = 0
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set pExists = ..%ExistsId(pId)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set one subscript of the fixed probe global <code>^OcuPilotKernelStateProbe</code>
/// through the escalated frame. This gives <class>OcuPilot.Test.State</class> a
/// global-side proof of AD-9 alongside <method>GuardedSave</method>'s table-side proof
/// (AC4, AC5) -- production code has no reason to call this outside that test.</p>
ClassMethod GuardedProbeSet(pKey As %String, pValue As %String) As %Status
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set ^OcuPilotKernelStateProbe(pKey) = pValue
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Read one subscript of <code>^OcuPilotKernelStateProbe</code> through the escalated
/// frame. Returns <code>""</code> via <var>pValue</var> when unset.</p>
ClassMethod GuardedProbeGet(pKey As %String, Output pValue As %String) As %Status
{
    Set tSC = $$$OK
    Set pValue = ""
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set pValue = $Get(^OcuPilotKernelStateProbe(pKey))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Take the turn slot lock <code>^OcuPilotTurnSlot(</code><var>pUser</var><code>)</code>,
/// waiting at most <var>pTimeout</var> seconds. <var>pHeld</var> is 1 when this process now holds
/// it. The lock outlives this frame and is released by <method>GuardedTurnSlotUnlock</method> or
/// by the process ending. Reach it through <code>..</code> dispatch from
/// <class>OcuPilot.Kernel.State.Turn</class>.</p>
ClassMethod GuardedTurnSlotLock(pUser As %String, pTimeout As %Integer, Output pHeld As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pHeld = 0
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Lock +^OcuPilotTurnSlot(pUser):+pTimeout
        Set pHeld = $Test
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Release one hold of the turn slot lock for <var>pUser</var>. Releasing a lock this process
/// does not hold changes nothing.</p>
ClassMethod GuardedTurnSlotUnlock(pUser As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Lock -^OcuPilotTurnSlot(pUser)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set the scalar signal node <code>^OcuPilotTurnSignal(</code><var>pKey</var><code>,
/// </code><var>pName</var><code>)</code> to <var>pValue</var>.</p>
ClassMethod GuardedTurnSignalSet(pKey As %String, pName As %String, pValue As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set ^OcuPilotTurnSignal(pKey, pName) = pValue
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Read the signal node <var>pKey</var>, <var>pName</var>; <code>""</code> when unset.</p>
ClassMethod GuardedTurnSignalGet(pKey As %String, pName As %String, Output pValue As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pValue = ""
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set pValue = $Get(^OcuPilotTurnSignal(pKey, pName))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every signal node of turn <var>pKey</var>.</p>
ClassMethod GuardedTurnSignalKill(pKey As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Kill ^OcuPilotTurnSignal(pKey)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Test-only introspection: returns the process's <code>$ROLES</code> as observed
/// from <b>inside</b> the escalation frame -- the same frame every guarded method above
/// uses -- so <class>OcuPilot.Test.State</class> can assert AD-9's ordering rule (the
/// guarding role is present inside the frame) without weakening the frame itself.
/// Production code never calls this.</p>
ClassMethod GuardedRolesSnapshot() As %String
{
    Set tRoles = ""
    New $ROLES
    Try {
        Do $SYSTEM.Security.AddRoles(..#APPLICATION)
        Set tRoles = $ROLES
    } Catch {
        Set tRoles = ""
    }
    Quit tRoles
}

/// <p>Execute a caller-supplied, single-parameter SQL statement through the escalated
/// frame -- for maintenance operations (e.g. <method>OcuPilot.Kernel.State.Stamp.DeleteByProfile</method>,
/// purging a disposable test profile's own bookkeeping) that
/// <method>GuardedSave</method> / <method>GuardedOpenId</method> /
/// <method>GuardedExistsId</method> do not cover. <var>pSql</var> must be a literal at
/// the caller's own call site, never built from caller-supplied text
/// (<file>.claude/rules/objectscript-basics.md</file>); <var>pParam</var> binds the
/// statement's one <code>?</code> placeholder.</p>
/// <p><b><code>Private</code> is load-bearing, not tidiness.</b> Every other guarded
/// method here takes typed data and runs a statement this class chose; this one takes the
/// statement itself, so as a public method it would be a general-purpose escalated SQL
/// executor callable from anywhere in the tree -- and AC6's mechanical checker gates the
/// <code>New $ROLES</code> / <code>AddRoles</code> tokens, not calls into the guarded
/// wrappers, so such a call site would be invisible to it. Private confines it to
/// <package>OcuPilot.Kernel.State</package>, which
/// <code>check_state_package_isolation</code> already polices as a whole. Callers inside
/// the package must use inherited (<code>..</code>) dispatch -- see
/// <method>OcuPilot.Kernel.State.Stamp.DeleteByProfile</method>.</p>
ClassMethod GuardedExecuteOneParam(pSql As %String, pParam As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pParam)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedExecuteOneParam failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Zero-parameter sibling of <method>GuardedExecuteOneParam</method>, for a maintenance
/// statement whose <code>WHERE</code> clause binds nothing at all -- the production-profile
/// branch of a per-profile delete, where <code>Profile IS NULL</code> has no <code>?</code>
/// to bind. Same call-site-literal and <code>Private</code> rules as
/// <method>GuardedExecuteOneParam</method>; see
/// <method>GuardedOpenOneWhereNoParam</method>'s header for why a statement with no
/// <code>?</code> at all must not be called with an unused bound parameter (review
/// finding: <class>OcuPilot.Kernel.State.Demo</class>'s own <method>DeleteByProfile</method>
/// had no zero-parameter form to call, so its production branch matched
/// <code>Profile = ''</code>, which never matches the SQL <code>NULL</code> a production
/// row actually reads back as).</p>
ClassMethod GuardedExecuteNoParam(pSql As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedExecuteNoParam failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Escalated: run <var>pSql</var> (a caller literal returning exactly one ID column,
/// binding at most one parameter) and open the first matching row through the calling
/// subclass's own inherited <method>%OpenId</method>, still inside the escalated frame.
/// <var>pObject</var> is <code>$$$NULLOREF</code> when no row matches -- never an error.
/// Added for <class>OcuPilot.Kernel.State.Version</class> (Story 1.4), which needs one
/// row per profile and so must find an existing row by <property>Profile</property>
/// before deciding whether to insert or update -- <method>GuardedSave</method> alone
/// only ever inserts. For the same reasons as <method>GuardedExecuteOneParam</method>,
/// <var>pSql</var> must be a call-site literal, never built from caller-supplied text,
/// and this is <code>Private</code> for the same reason that one is: reach it through
/// inherited (<code>..</code>) dispatch from a subclass in this package, never
/// <code>##class(Base)</code>.</p>
ClassMethod GuardedOpenOneWhere(pSql As %String, pParam As %String, Output pObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pObject = $$$NULLOREF
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pParam)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedOpenOneWhere failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        If tRS.%Next() {
            Set pObject = ..%OpenId(tRS.%GetData(1), 0, .tSC)
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Zero-parameter sibling of <method>GuardedOpenOneWhere</method>, for a query whose
/// <code>WHERE</code> clause binds nothing at all -- the production-profile branch,
/// where <code>Profile IS NULL</code> has no <code>?</code> to bind. <b>Verified live
/// against a genuinely fresh instance</b> (a throwaway container with no prior
/// production Version row): passing an unused parameter to <code>%ExecDirect</code> for
/// a statement with zero placeholders raises <code>SQLCODE -400</code> ("more parameter
/// values passed than are specified in the dynamic statement") -- silently on this
/// instance's own history, because every earlier test happened to exercise only the
/// <code>"probe"</code> profile's bound-parameter branch, never production's. Same
/// call-site-literal and <code>Private</code> rules as
/// <method>GuardedOpenOneWhere</method>.</p>
ClassMethod GuardedOpenOneWhereNoParam(pSql As %String, Output pObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pObject = $$$NULLOREF
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedOpenOneWhereNoParam failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        If tRS.%Next() {
            Set pObject = ..%OpenId(tRS.%GetData(1), 0, .tSC)
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Two-parameter sibling of <method>GuardedOpenOneWhere</method>, for a query whose
/// <code>WHERE</code> clause binds two values (<class>OcuPilot.Kernel.State.Demo</class>'s
/// inventory lookup by <code>Kind</code> and <code>Name</code>). Same call-site-literal
/// and <code>Private</code> rules apply.</p>
ClassMethod GuardedOpenOneWhereTwoParam(pSql As %String, pParam1 As %String, pParam2 As %String, Output pObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pObject = $$$NULLOREF
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pParam1, pParam2)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedOpenOneWhereTwoParam failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        If tRS.%Next() {
            Set pObject = ..%OpenId(tRS.%GetData(1), 0, .tSC)
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Three-parameter sibling of <method>GuardedOpenOneWhere</method>
/// (<class>OcuPilot.Kernel.State.Demo</class>'s inventory lookup, probe-profile branch,
/// where <code>Kind</code>, <code>Name</code> <b>and</b> <code>Profile</code> all bind).
/// Same call-site-literal and <code>Private</code> rules apply.</p>
ClassMethod GuardedOpenOneWhereThreeParam(pSql As %String, pParam1 As %String, pParam2 As %String, pParam3 As %String, Output pObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pObject = $$$NULLOREF
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pParam1, pParam2, pParam3)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedOpenOneWhereThreeParam failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        If tRS.%Next() {
            Set pObject = ..%OpenId(tRS.%GetData(1), 0, .tSC)
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>A bounded <code>WHERE</code> fragment, without the keyword, for a read over a time-indexed
/// table, so no search runs unbounded. It runs no SQL and does not escalate.</p>
/// <p><var>pWindowHours</var> selects the mode: <code>0</code> is the last
/// <parameter>BOUNDEDDEFAULTHOURS</parameter> hours; <code>1</code> to
/// <parameter>BOUNDEDMAXHOURS</parameter> is that many hours; <parameter>BOUNDEDKEYED</parameter>
/// is keyed mode, which emits no time predicate and requires at least one of
/// <var>pPredicates</var>. A windowed fragment leads with <code>&lt;pTimeColumn&gt; &gt; ?</code>
/// and pushes the cutoff -- UTC, <code>YYYY-MM-DDTHH:MM:SSZ</code>, the form OcuPilot's own time
/// columns store -- onto <var>pParams</var>, a <class>%DynamicArray</class> created when absent; the
/// cutoff is never in the text. Each non-empty entry of <var>pPredicates</var> follows in
/// parentheses, joined by <code>AND</code>, so an <code>OR</code> inside one cannot escape the
/// window.</p>
/// <p>Any other window, a <var>pTimeColumn</var> outside <parameter>BOUNDEDCOLUMNPATTERN</parameter>
/// in a windowed mode, or keyed mode with no predicate answers <code>""</code> with
/// <var>pProblem</var> naming the bound, and pushes nothing.</p>
/// <p><b>Caller contract:</b> <var>pTimeColumn</var> and every predicate are literals the caller
/// wrote, with <code>?</code> for each value, whose values the caller pushes onto
/// <var>pParams</var> after this returns (AD-21).</p>
ClassMethod BoundedWhere(pWindowHours As %String = 0, pTimeColumn As %String, ByRef pParams As %DynamicArray, Output pProblem As %String, pPredicates...) As %String
{
    Set pProblem = ""
    If '$IsObject($Get(pParams)) Set pParams = []
    Set tKeyed = (pWindowHours = ..#BOUNDEDKEYED) && $Match(pWindowHours, "^-1$")
    If 'tKeyed && '($Match(pWindowHours, "^(0|[1-9][0-9]*)$") && (pWindowHours <= ..#BOUNDEDMAXHOURS)) {
        Set pProblem = "the window must be " _ ..#BOUNDEDKEYED _ " for a keyed read, 0 for the last " _ ..#BOUNDEDDEFAULTHOURS _ " hours, or a whole number of hours from 1 to " _ ..#BOUNDEDMAXHOURS
        Quit ""
    }
    Set tPredicates = ""
    For tI = 1:1:$Get(pPredicates) {
        Set tPredicate = $Get(pPredicates(tI))
        If tPredicate = "" Continue
        Set tPredicates = tPredicates _ $ListBuild("(" _ tPredicate _ ")")
    }
    If tKeyed {
        If tPredicates = "" {
            Set pProblem = "a keyed read (window " _ ..#BOUNDEDKEYED _ ") needs a keyed predicate to bound it"
            Quit ""
        }
        Quit $ListToString(tPredicates, " AND ")
    }
    If '$Match(pTimeColumn, ..#BOUNDEDCOLUMNPATTERN) {
        Set pProblem = "the time column must be a column name, optionally qualified by one alias"
        Quit ""
    }
    Set tHours = $Select(+pWindowHours = 0: ..#BOUNDEDDEFAULTHOURS, 1: +pWindowHours)
    Set tNow = $ZTimeStamp
    Set tSeconds = ((+$Piece(tNow, ",", 1)) * 86400) + ($Piece(tNow, ",", 2) \ 1) - (tHours * 3600)
    Set tCutoff = $Translate($ZDateTime((tSeconds \ 86400) _ "," _ (tSeconds # 86400), 3, 1), " ", "T") _ "Z"
    Do pParams.%Push(tCutoff, "string")
    Quit $ListToString($ListBuild(pTimeColumn _ " > ?") _ tPredicates, " AND ")
}

/// <p>Escalated: run <var>pSql</var> (a caller literal returning exactly one ID column,
/// binding one parameter) and collect every matching id into <var>pIds</var>
/// (<code>pIds(1)</code>, <code>pIds(2)</code>, ...), rather than opening only the
/// first row the way <method>GuardedOpenOneWhere</method> does. Added for
/// <class>OcuPilot.Kernel.State.Demo</class>'s inventory, which
/// <class>OcuPilot.Install.Fixture</class> must enumerate in full to remove exactly what
/// install created (AD-25, DW-13). Returns no ids, never an error, when nothing matches.
/// Same call-site-literal and <code>Private</code> rules as
/// <method>GuardedExecuteOneParam</method>.</p>
ClassMethod GuardedIdsWhere(pSql As %String, pParam As %String, Output pIds) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pIds
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pParam)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedIdsWhere failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        While tRS.%Next() {
            Set pIds($Increment(pIds)) = tRS.%GetData(1)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Two-parameter sibling of <method>GuardedIdsWhere</method>, for a query whose
/// <code>WHERE</code> clause binds two values (<class>OcuPilot.Kernel.State.Turn</class>'s owner
/// lookup by turn key and user name). Same call-site-literal and <code>Private</code> rules.</p>
ClassMethod GuardedIdsWhereTwoParam(pSql As %String, pParam1 As %String, pParam2 As %String, Output pIds) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pIds
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pParam1, pParam2)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedIdsWhereTwoParam failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        While tRS.%Next() {
            Set pIds($Increment(pIds)) = tRS.%GetData(1)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Zero-parameter sibling of <method>GuardedIdsWhere</method> -- see
/// <method>GuardedOpenOneWhereNoParam</method>'s header for why a statement with no
/// <code>?</code> at all must not be called with an unused bound parameter.</p>
ClassMethod GuardedIdsWhereNoParam(pSql As %String, Output pIds) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pIds
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedIdsWhereNoParam failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        While tRS.%Next() {
            Set pIds($Increment(pIds)) = tRS.%GetData(1)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Escalated: run a bounded read assembled from three call-site literals and collect every
/// matching id into <var>pIds</var>, the way <method>GuardedIdsWhere</method> does. The statement is
/// joined <b>here</b> -- <code>pSelectPrefix _ " WHERE " _ pFragment _ " " _ pSuffix</code> -- so no
/// subclass concatenates SQL text of its own (AD-21), and <var>pFragment</var> is
/// <method>BoundedWhere</method>'s answer, which carries a <code>?</code> for every value and no
/// value at all.</p>
/// <p><b>Binding order is fixed:</b> <var>pMaxRows</var> first, then <var>pParams</var>'s members in
/// array order. So <var>pSelectPrefix</var> spells <code>SELECT TOP ?</code> ahead of the fragment's
/// own placeholders. A caller whose prefix names no placeholder passes <code>0</code> and binds
/// nothing; a prefix that <b>does</b> name one and a <var>pMaxRows</var> that is not positive are
/// refused rather than run, because dropping the first argument slides every predicate value up one
/// placeholder instead of dropping the cap.</p>
/// <p><b><method>BoundedWhere</method> pushes its cutoff last, while the fragment names it first</b>
/// -- so a caller passes an <b>empty</b> <var>pParams</var>, lets that method push the cutoff onto
/// index 1, and pushes its own predicate values only after it returns. Passing a pre-filled array
/// puts the cutoff behind values the fragment names after it.</p>
/// <p>A statement with no bound value at all takes the no-argument <code>%ExecDirect</code> branch:
/// passing an unused parameter raises <code>SQLCODE -400</code> (see
/// <method>GuardedOpenOneWhereNoParam</method>).</p>
/// <p>Same call-site-literal and <code>Private</code> rules as
/// <method>GuardedExecuteOneParam</method>: reach it through inherited (<code>..</code>) dispatch
/// from a subclass in this package.</p>
ClassMethod GuardedIdsBounded(pSelectPrefix As %String, pFragment As %String, pSuffix As %String, pMaxRows As %Integer, ByRef pParams As %DynamicArray, Output pIds) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pIds
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tSql = pSelectPrefix _ " WHERE " _ pFragment _ " " _ pSuffix
        Kill tArgs
        Set tArgs = 0
        ; A prefix that binds its own row cap must be given one: omitting the first argument would
        ; slide every predicate value up one placeholder instead of dropping the cap.
        If (+pMaxRows <= 0) && (pSelectPrefix [ "?") {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedIdsBounded needs a row cap above zero for a prefix that binds one: " _ pSelectPrefix)
            Quit
        }
        If +pMaxRows > 0 Set tArgs($Increment(tArgs)) = +pMaxRows
        If $IsObject($Get(pParams)) {
            For tI = 0:1:pParams.%Size() - 1 {
                Set tArgs($Increment(tArgs)) = pParams.%Get(tI)
            }
        }
        If tArgs = 0 {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSql)
        } Else {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSql, tArgs...)
        }
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "GuardedIdsBounded failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        While tRS.%Next() {
            Set pIds($Increment(pIds)) = tRS.%GetData(1)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pStatus</var> carries IRIS's own lock-timeout error (5803,
/// <code>$$$LockFailedToAcquireExclusive</code>) rather than any other failure. Public so
/// <class>OcuPilot.Test.Convo</class> can pin the classification directly against a status this
/// class's own error macro built, without needing genuine lock contention from a second process
/// (Test/Convo.cls is spawn-free) -- <method>GuardedOpenIdExclusive</method> uses this same
/// method rather than a second copy of the test.</p>
ClassMethod IsLockConflict(pStatus As %Status) As %Boolean
{
    If $$$ISOK(pStatus) Quit 0
    Quit $System.Status.Equals(pStatus, $$$ERRORCODE($$$LockFailedToAcquireExclusive))
}

/// <p>Open the row whose <code>%Id()</code> is <var>pId</var>, for the calling subclass, at
/// concurrency 4 (exclusive, retained), waiting up to <var>pTimeout</var> seconds for the row's
/// lock -- the primitive behind the harvested <code>Chat.History.LoadOrCreate</code>
/// per-conversation lock protocol (Story 4.5, <class>OcuPilot.Kernel.State.Convo</class>).</p>
/// <p><var>pObject</var> is <code>$$$NULLOREF</code> on any failure. <var>pLockConflict</var>
/// distinguishes IRIS's own lock-timeout status -- error 5803,
/// <code>$$$LockFailedToAcquireExclusive</code>, raised from inside <code>%OpenId</code>'s own
/// concurrency escalation (verified against <code>irislib/%occErrors.inc</code>) -- from every
/// other open failure, so a caller can tell a busy row from a persistence problem.</p>
/// <p><code>%OpenId</code> takes no timeout argument on this build (<code>%Library.Persistent</code>'s
/// signature is <code>%OpenId(id, concurrency, ByRef sc)</code>); the wait is bounded instead by
/// temporarily lowering the process's default object and SQL lock timeout -- <code>$ZUtil(115,4)</code>,
/// which <code>%OpenId</code>'s internal concurrency lock uses -- around the call, restoring it whatever the outcome. The same
/// save/set/restore idiom is already in the exported system source at
/// <code>irislib/Ens/DTL/Utils.cls</code>.</p>
ClassMethod GuardedOpenIdExclusive(pId As %String, pTimeout As %Integer, Output pObject, Output pLockConflict As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pObject = $$$NULLOREF
    Set pLockConflict = 0
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#APPLICATION)
        If $$$ISERR(tSC) Quit
        Set tSaved = $ZUtil(115, 4)
        Do $ZUtil(115, 4, +pTimeout)
        Try {
            Set pObject = ..%OpenId(pId, 4, .tSC)
        } Catch inner {
            Set tSC = inner.AsStatus()
        }
        Do $ZUtil(115, 4, tSaved)
        If $$$ISERR(tSC) || '$IsObject(pObject) {
            Set pObject = $$$NULLOREF
            If $$$ISERR(tSC) {
                Set pLockConflict = ..IsLockConflict(tSC)
            } Else {
                Set tSC = $$$ERROR($$$GeneralError, "the row could not be opened")
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pObject = $$$NULLOREF
    }
    Quit tSC
}

/// <p>Test-only: escalates, then throws, so <class>OcuPilot.Test.State</class> can
/// assert the same ordering rule on the exception path -- the guarding role is absent
/// immediately after the frame unwinds via an exception, not only on normal return.
/// Production code never calls this.</p>
ClassMethod GuardedRolesSnapshotThenThrow() As %Status
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Do $SYSTEM.Security.AddRoles(..#APPLICATION)
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "induced test exception inside the escalated frame"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
