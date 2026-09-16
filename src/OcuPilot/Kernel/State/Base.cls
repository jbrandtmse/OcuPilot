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
