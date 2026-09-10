/// <p>One row per fixture object <class>OcuPilot.Install.Fixture</class> created (AD-25,
/// DW-13) -- the inventory that lets uninstall remove exactly what install created and
/// never an operator's own object. Named scalars only, per the persistent-storage rule:
/// <property>Kind</property>, <property>Name</property> and <property>Scope</property>
/// are three independently-meaningful fields on one row, never a homogeneous collection.
/// Stored references are weak (AD-37): a row records the object's identity as data, not
/// as a foreign key, so a fixture an operator later deleted by hand is simply absent from
/// a fresh listing rather than corrupting removal.</p>
Class OcuPilot.Kernel.State.Demo Extends OcuPilot.Kernel.State.Base
{

/// <p>The install profile this row was created under: <code>""</code> for production or
/// <code>"probe"</code> for the disposable test seam. Reads back through SQL as
/// <code>NULL</code>, not <code>''</code>, for the production row --
/// see <class>OcuPilot.Kernel.State.Stamp</class>'s <property>Profile</property>.</p>
Property Profile As %String(MAXLEN = 16);

/// <p>What kind of object this row records, e.g. <code>webapp</code>,
/// <code>sslconfig</code>, <code>x509credential</code>, <code>task</code>,
/// <code>errorentry</code>. A closed, small vocabulary owned by
/// <class>OcuPilot.Install.Fixture</class>.</p>
Property Kind As %String(MAXLEN = 32);

/// <p>The object's own identifying name -- a web application path, an SSL/TLS
/// configuration name, an X.509 credential alias, or a task name. Never
/// <code>OcuPilot.Api</code>/<code>.Port</code>/<code>.Screen</code>/<code>.Area</code>
/// facing; this is pure data (AD-37).</p>
Property Name As %String(MAXLEN = 256);

/// <p>Where the object lives -- the install namespace for a namespace-scoped object, or
/// the literal <code>instance</code> for a configuration object that has none (the same
/// scope vocabulary AD-13 defines for entity references generally).</p>
Property Scope As %String(MAXLEN = 64);

/// <p>Remove every inventory row recorded for <var>pProfile</var>, through the escalated
/// frame -- called by <class>OcuPilot.Install.Fixture</class> only after the objects the
/// rows describe have themselves been removed. See
/// <method>OcuPilot.Kernel.State.Stamp.DeleteByProfile</method> for why passing
/// <code>""</code> is a deliberate no-op rather than a bug.</p>
ClassMethod DeleteByProfile(pProfile As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", pProfile)
}

/// <p>Whether an inventory row already exists for <var>pProfile</var>/<var>pKind</var>/
/// <var>pName</var>, through the escalated frame -- lets
/// <class>OcuPilot.Install.Fixture</class> stay guard-then-act on its own inventory
/// writes across a repeated install. <var>pProfile</var> selects between two literal
/// query texts (never concatenated into SQL) exactly as
/// <method>OcuPilot.Kernel.State.Version.GuardedCurrentForProfile</method> does, because
/// a production row's <property>Profile</property> reads back as SQL <code>NULL</code>,
/// never <code>''</code>.</p>
ClassMethod GuardedRowExists(pProfile As %String, pKind As %String, pName As %String, Output pExists As %Boolean) As %Status
{
    Set pExists = 0
    Set tSC = $$$OK
    Try {
        If pProfile = "" {
            Set tSC = ..GuardedOpenOneWhereTwoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Demo WHERE Kind = ? AND Name = ? AND Profile IS NULL", pKind, pName, .tObject)
        } Else {
            Set tSC = ..GuardedOpenOneWhereThreeParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Demo WHERE Kind = ? AND Name = ? AND Profile = ?", pKind, pName, pProfile, .tObject)
        }
        If $$$ISERR(tSC) Quit
        Set pExists = $IsObject(tObject)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every row id recorded for <var>pProfile</var>, through the escalated frame --
/// <class>OcuPilot.Install.Fixture</class>'s <method>Remove</method> opens each one
/// (via inherited <method>GuardedOpenId</method>) to read back what it must remove.
/// <var>pProfile</var> selects between the same two literal query texts
/// <method>GuardedRowExists</method> uses, for the identical NULL-vs-literal reason.</p>
ClassMethod GuardedIdsForProfile(pProfile As %String, Output pIds) As %Status
{
    If pProfile = "" {
        Quit ..GuardedIdsWhereNoParam("SELECT ID FROM OcuPilot_Kernel_State.Demo WHERE Profile IS NULL", .pIds)
    }
    Quit ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", pProfile, .pIds)
}

}
