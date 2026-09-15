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

/// <p>Audit event triple (AD-15) -- Source and Type. The event Name carries a
/// profile-specific suffix; see <method>OcuPilot.Install.Installer.Names</method>.</p>
Parameter AUDITSOURCE As %String = "OcuPilot";

Parameter AUDITTYPE As %String = "Security";

Parameter AUDITNAME As %String = "RoleGranted";

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
