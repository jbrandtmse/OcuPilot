/// <p>The instance's outbound-call settings (AD-32): the TLS configuration every provider call is
/// made through, the proxy it goes by, the per-call timeout and the attempt bound. <b>One row for
/// the whole instance</b>, updated in place, the way <class>OcuPilot.Kernel.State.Version</class>
/// holds one row per profile rather than a history.</p>
/// <p><b>Why these are stored rather than class parameters.</b> AD-32 reads "proxy settings are
/// configuration, not code", and the same argument binds the timeout and the attempt bound: an
/// operator behind a proxy, or on a slow link, changes a value here rather than editing a shipped
/// class. The port reads this on every call and never a parameter of its own.</p>
/// <p><b>No route renders it in Release 1.</b> Nothing in the API reads or writes this row, so on
/// a clean instance <method>Resolve</method> answers the defaults below and the row never exists.
/// <method>SetGuarded</method> is here so the values are settable from a session or a later
/// screen without a second write path being invented for them.</p>
/// <p>Named scalars only -- no <code>list Of</code> -- per the persistent-storage rule, and no
/// hand-written Storage.</p>
Class OcuPilot.Kernel.State.Egress Extends OcuPilot.Kernel.State.Base
{

/// <p>The per-call timeout, in seconds, an instance that has stored none is served. Above
/// <class>%Net.HttpRequest</class>'s own default of 30 on purpose: a model answering a full turn's
/// prompt routinely takes longer than thirty seconds, and a timeout shorter than the work is a
/// failure OcuPilot manufactures.</p>
Parameter DEFAULTTIMEOUT As %Integer = 90;

/// <p>The number of attempts -- the first call included -- an instance that has stored none is
/// served. Three means at most two retries, each only on a status
/// <class>OcuPilot.Kernel.Provider.Retry</class> declares retryable.</p>
Parameter DEFAULTMAXATTEMPTS As %Integer = 3;

/// <p>The proxy host provider calls are made through; <code>""</code> for a direct call.</p>
Property ProxyServer As %String(MAXLEN = 256);

/// <p>The proxy's port. Ignored while <property>ProxyServer</property> is <code>""</code>.</p>
Property ProxyPort As %Integer [ InitialExpression = 0 ];

/// <p>Whether the connection to the proxy itself is made over TLS
/// (<property>%Net.HttpRequest.ProxyHTTPS</property>).</p>
Property ProxyHttps As %Boolean [ InitialExpression = 0 ];

/// <p>Whether to tunnel through the proxy with HTTP <code>CONNECT</code> rather than asking it to
/// forward the request. Tunnelling is what keeps the TLS session end to end through a proxy.</p>
Property ProxyTunnel As %Boolean [ InitialExpression = 0 ];

/// <p>The per-call timeout in seconds; <code>0</code> means take
/// <parameter>DEFAULTTIMEOUT</parameter>, and that is the initial value on purpose. Seeding this
/// with today's default instead would freeze it into every row ever written, so an instance that
/// had once stored a proxy would stop following the shipped default when it moved.</p>
Property TimeoutSeconds As %Integer [ InitialExpression = 0 ];

/// <p>How many attempts one provider call may make in total; <code>0</code> means take
/// <parameter>DEFAULTMAXATTEMPTS</parameter>, for the same reason
/// <property>TimeoutSeconds</property> starts at zero.</p>
Property MaxAttempts As %Integer [ InitialExpression = 0 ];

/// <p>The TLS configuration name; <code>""</code> means take
/// <parameter>OcuPilot.Kernel.State.Base.SSLCONFIG</parameter>, which is the one the installer
/// creates.</p>
Property SslConfiguration As %String(MAXLEN = 64);

/// <p>The settings in force, as <var>pSettings</var> subscripted by
/// <code>proxyServer</code>, <code>proxyPort</code>, <code>proxyHttps</code>,
/// <code>proxyTunnel</code>, <code>timeoutSeconds</code>, <code>maxAttempts</code> and
/// <code>sslConfiguration</code>: the stored row's values where it holds one, the defaults
/// otherwise.</p>
/// <p>An instance with no row is the ordinary state, never an error -- nothing writes one on
/// install. A read that fails answers the defaults too, and says so through the error
/// <class>%Status</class>: the caller decides whether to proceed, and a provider call that cannot
/// read its own settings is better made with the shipped defaults than not made at all.</p>
ClassMethod Resolve(Output pSettings) As %Status
{
    Kill pSettings
    Set pSettings("proxyServer") = ""
    Set pSettings("proxyPort") = 0
    Set pSettings("proxyHttps") = 0
    Set pSettings("proxyTunnel") = 0
    Set pSettings("timeoutSeconds") = ..#DEFAULTTIMEOUT
    Set pSettings("maxAttempts") = ..#DEFAULTMAXATTEMPTS
    Set pSettings("sslConfiguration") = ..#SSLCONFIG
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedCurrent(.tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Quit
        Set pSettings("proxyServer") = ..Text(tRow.ProxyServer)
        Set pSettings("proxyPort") = +tRow.ProxyPort
        Set pSettings("proxyHttps") = ''tRow.ProxyHttps
        Set pSettings("proxyTunnel") = ''tRow.ProxyTunnel
        If +tRow.TimeoutSeconds > 0 Set pSettings("timeoutSeconds") = +tRow.TimeoutSeconds
        If +tRow.MaxAttempts > 0 Set pSettings("maxAttempts") = +tRow.MaxAttempts
        If ..Text(tRow.SslConfiguration) '= "" Set pSettings("sslConfiguration") = ..Text(tRow.SslConfiguration)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write <var>pValues</var> -- the same subscripts <method>Resolve</method> answers with -- to
/// the instance's one row, creating it when there is none. A subscript the caller omits keeps the
/// stored value, so setting the proxy alone does not clear the timeout.</p>
/// <p><b>The write is conditional on the version the row carried when it was read</b>
/// (Consistency Conventions: concurrent writes to OcuPilot's own state). Two callers that read the
/// same row and then both save no longer silently overwrite one another: the second is refused
/// with <method>OcuPilot.Kernel.State.Base.IsStaleSave</method>'s own sentence.</p>
/// <p><var>pExpectedVersion</var> is for a caller that read the row earlier than this call and
/// holds the version it saw. Left <code>""</code> -- which is every production call site today --
/// the version read a line below is used, which is the same window closed one read later.</p>
ClassMethod SetGuarded(ByRef pValues, pExpectedVersion As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedCurrent(.tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Set tRow = ..%New()
        Set tVersion = $Select(pExpectedVersion '= "": +pExpectedVersion, 1: +tRow.RowVersion)
        If $Data(pValues("proxyServer")) Set tRow.ProxyServer = pValues("proxyServer")
        If $Data(pValues("proxyPort")) Set tRow.ProxyPort = +pValues("proxyPort")
        If $Data(pValues("proxyHttps")) Set tRow.ProxyHttps = ''+pValues("proxyHttps")
        If $Data(pValues("proxyTunnel")) Set tRow.ProxyTunnel = ''+pValues("proxyTunnel")
        If $Data(pValues("timeoutSeconds")) Set tRow.TimeoutSeconds = +pValues("timeoutSeconds")
        If $Data(pValues("maxAttempts")) Set tRow.MaxAttempts = +pValues("maxAttempts")
        If $Data(pValues("sslConfiguration")) Set tRow.SslConfiguration = pValues("sslConfiguration")
        Set tSC = ..GuardedSaveIfCurrent(tRow, tVersion)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove the instance's settings row, so a test that wrote one leaves the defaults in force
/// again. Absent is never an error.</p>
ClassMethod DeleteGuarded() As %Status
{
    Quit ..GuardedExecuteNoParam("DELETE FROM OcuPilot_Kernel_State.Egress")
}

/// <p>The one row, or <code>$$$NULLOREF</code> when the instance holds none.</p>
/// <p>The lowest id wins, so a second row written by a concurrent create is ignored rather than
/// alternating with the first: the settings are instance-wide and there is nothing to choose
/// between two of them.</p>
ClassMethod GuardedCurrent(Output pObject) As %Status [ Private ]
{
    Quit ..GuardedOpenOneWhereNoParam("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Egress ORDER BY ID", .pObject)
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> of a
/// <code>%String</code> column reads back as normalized to <code>""</code>
/// (<file>.claude/rules/objectscript-basics.md</file>). Every write here goes through the object
/// layer, so the sentinel cannot arrive today; the normalization is at the read site because that
/// is where it stays correct if one ever does.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
