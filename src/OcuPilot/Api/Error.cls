/// <p>The failure half of OcuPilot's one response envelope (AD-12, AD-39).</p>
/// <p>This is the single entry point for every error response in the tree. Handlers
/// never construct an error envelope inline, and this class, together with
/// <class>OcuPilot.Api.Response</class>, is the only code permitted to <code>Write</code>
/// to the response device.</p>
/// <p>The wire shape is <code>{error, reason, code}</code>, plus <code>detail</code> only
/// when supplied — never <code>null</code>. <var>error</var> is a coarse slug drawn from
/// the closed enum below; <var>reason</var> is human text a screen renders and may be
/// reworded freely; <var>code</var> is a stable, dotted-uppercase machine identifier a
/// tool result renders and that is never reworded once shipped; <var>detail</var> is an
/// optional structured object. An unknown slug is refused outright — nothing is written
/// and an error <class>%Status</class> is returned — because the slug enum is closed.</p>
/// <p>For internal (500) failures: the full exception detail goes to
/// <class>OcuPilot.Kernel.Audit.Log</class> only. The client always gets a generic
/// reason and the machine code <code>INTERNAL</code> — see <method>RenderInternal</method>.</p>
Class OcuPilot.Api.Error Extends %RegisteredObject
{

/// <p>Error slug: malformed request.</p>
Parameter BADREQUEST = "bad_request";

/// <p>Error slug: authentication required.</p>
Parameter UNAUTHORIZED = "unauthorized";

/// <p>Error slug: authenticated but not permitted.</p>
Parameter FORBIDDEN = "forbidden";

/// <p>Error slug: resource not found.</p>
Parameter NOTFOUND = "not_found";

/// <p>Error slug: HTTP method not allowed on this route.</p>
Parameter METHODNOTALLOWED = "method_not_allowed";

/// <p>Error slug: the request conflicts with the resource's current state.</p>
Parameter CONFLICT = "conflict";

/// <p>Error slug: a stated precondition was not met.</p>
Parameter PRECONDITIONFAILED = "precondition_failed";

/// <p>Error slug: unsupported or missing content type.</p>
Parameter BADCONTENTTYPE = "bad_content_type";

/// <p>Error slug: the request body failed validation.</p>
Parameter VALIDATIONFAILED = "validation_failed";

/// <p>Error slug: an internal failure. The client-facing reason is always generic —
/// see <method>RenderInternal</method>.</p>
Parameter SERVERERROR = "server_error";

/// <p>Error slug: the feature is not implemented.</p>
Parameter NOTIMPLEMENTED = "not_implemented";

/// <p>Error slug: the service is temporarily unavailable.</p>
Parameter UNAVAILABLE = "unavailable";

/// <p>Machine code (AD-38, AD-39): install is still running. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug by <class>OcuPilot.Api.Router</class>'s
/// traffic gate -- never a new envelope field, never a number.</p>
Parameter INSTALLINSTALLING = "INSTALL.INSTALLING";

/// <p>Machine code (AD-38, AD-39): the stored schema version is behind the deployed
/// code and forward migration has not completed. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug by <class>OcuPilot.Api.Router</class>'s
/// traffic gate.</p>
Parameter INSTALLUPGRADEREQUIRED = "INSTALL.UPGRADEREQUIRED";

/// <p>Machine code (AD-38, AD-39): the last install attempt failed. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug by <class>OcuPilot.Api.Router</class>'s
/// traffic gate.</p>
Parameter INSTALLFAILED = "INSTALL.FAILED";

/// <p>Machine code (AD-38, AD-39): the gate cannot read OcuPilot's own install state at all, so
/// waiting will not help and install must run again. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug by <class>OcuPilot.Api.Router</class>'s traffic
/// gate.</p>
Parameter INSTALLUNREADABLE = "INSTALL.UNREADABLE";

/// <p>Machine code (AD-12, AD-39): the requested shell path is not one
/// <class>OcuPilot.Api.StaticHandler</class> will resolve to a file -- it carries a
/// literal <code>..</code>, a null, a backslash or a colon, or it normalizes outside the
/// bundle directory. Rendered on the <parameter>BADREQUEST</parameter> slug, and the
/// request text is never echoed back with it (AD-21, AD-47).</p>
Parameter STATICBADPATH = "STATIC.BADPATH";

/// <p>Machine code (AD-12, AD-39): the shell application is serving, but its bundle
/// directory holds no usable <code>index.html</code> -- the client was never built, or was
/// never copied in. Rendered on the <parameter>UNAVAILABLE</parameter> slug by
/// <class>OcuPilot.Api.StaticHandler</class>; install reports the same condition as a
/// <code>warn</code> and completes regardless.</p>
Parameter STATICNOBUNDLE = "STATIC.NOBUNDLE";

/// <p>Machine code (AD-12, AD-39): the caller is authenticated but holds no
/// <code>%Admin_*</code> resource at <code>USE</code>, so
/// <class>OcuPilot.Api.Router</class>'s administrative gate refuses before any route
/// runs. Rendered on the <parameter>FORBIDDEN</parameter> slug.</p>
Parameter AUTHNOADMIN = "AUTH.NOADMIN";

/// <p>Machine code (AD-12, AD-39): the caller holds an administrative resource and so cleared
/// <class>OcuPilot.Api.Router</class>'s instance-level gate, but does not hold one screen's own
/// <code>(resource, permission)</code> pair set (AD-8). Rendered on the
/// <parameter>FORBIDDEN</parameter> slug, with the failed pair as the envelope's
/// <code>detail</code>.</p>
/// <p><b>Distinct from <parameter>AUTHNOADMIN</parameter> on purpose.</b> That one means "this
/// account administers nothing on this instance" and drives a blocking notice whose only
/// control is Sign out; this one means "this account administers this instance but not this
/// screen" and drives an inline refusal beside a working shell. A client that read one for the
/// other would show the wrong surface.</p>
/// <p>Declared here, with no call site yet: the screen reads that render it are Epic 2's, and
/// Story 1.9 resolves a screen's gate from the navigation map rather than from a refused
/// request. The code is fixed now so the first of those reads does not mint a second one.</p>
Parameter AUTHNOPRIVILEGE = "AUTH.NOPRIVILEGE";

/// <p>Machine code (AD-12, AD-39): the request carried no authenticated caller, so
/// <class>OcuPilot.Api.Router</class>'s identity gate refuses before any route runs (AD-21).
/// Rendered on the <parameter>UNAUTHORIZED</parameter> slug.</p>
Parameter AUTHANONYMOUS = "AUTH.ANONYMOUS";

/// <p>Machine code (AD-12, AD-39): no route matched the request at all. Rendered on the
/// <parameter>NOTFOUND</parameter> slug by both framework-error overrides
/// (<class>OcuPilot.Api.Router</class> and <class>OcuPilot.Api.StaticHandler</class>).</p>
Parameter ROUTENOTFOUND = "ROUTE.NOTFOUND";

/// <p>Machine code (AD-12, AD-39): the path is mapped but not for this verb. Rendered on the
/// <parameter>METHODNOTALLOWED</parameter> slug by <method>Render405</method>, which also sets
/// the <code>Allow</code> header.</p>
/// <p>Equal to <method>CodeForStatus</method>(405) by construction, and
/// <class>OcuPilot.Test.Envelope</class> asserts it -- the two derivations of this one code
/// are held together rather than left to agree by eye.</p>
Parameter ROUTEMETHODNOTALLOWED = "ROUTE.METHODNOTALLOWED";

/// <p>Machine code (AD-12, AD-39): the route exists and the feature behind it does not yet.
/// Rendered on the <parameter>NOTIMPLEMENTED</parameter> slug by <method>Render501</method>.</p>
Parameter ROUTENOTIMPLEMENTED = "ROUTE.NOTIMPLEMENTED";

/// <p>Machine code (AD-12, AD-39): an internal failure. The one code a client ever sees for a
/// 500, because the detail goes to <class>OcuPilot.Kernel.Audit.Log</class> and the reason the
/// client gets is generic -- see <method>RenderInternal</method>.</p>
Parameter INTERNAL = "INTERNAL";

/// <p>Machine code (AD-12, AD-39): the request named a <code>?ns=</code> this instance has no
/// namespace for. Rendered on the <parameter>BADREQUEST</parameter> slug by
/// <class>OcuPilot.Api.Router</class>'s namespace gate, with no detail -- the caller supplied
/// the value and nothing about the instance is added to it.</p>
Parameter NSUNKNOWN = "NS.UNKNOWN";

/// <p>Machine code (AD-12, AD-39): the namespace the request named exists and the caller may not
/// enter it (AD-21, AD-48). Rendered on the <parameter>FORBIDDEN</parameter> slug by
/// <class>OcuPilot.Api.Router</class>'s namespace gate, with the failed
/// <code>(resource, permission)</code> pair as the envelope's <code>detail.failedPair</code> so
/// the shell can name what is missing (AD-8).</p>
Parameter NSDENIED = "NS.DENIED";

/// <p>Machine code (AD-12, AD-39): a vendor call refused the operation for this caller.
/// Produced by <class>OcuPilot.Kernel.Fault</class> on the <parameter>FORBIDDEN</parameter>
/// slug, from an HTTP 403 or from a status that denies access.</p>
/// <p>The seven <code>PORT.*</code> codes are declared <b>here</b>, with their producer in
/// another class, for the reason every other code is: this class is the one home of the
/// vocabulary. A code minted as a literal where it happens to be needed is how
/// <code>ROUTE.SERVER_ERROR</code> became a second spelling family.</p>
Parameter PORTACCESSDENIED = "PORT.ACCESSDENIED";

/// <p>Machine code (AD-12, AD-39): the item a vendor call named is not present on this
/// instance (AD-37). Rendered on the <parameter>NOTFOUND</parameter> slug.</p>
Parameter PORTNOTFOUND = "PORT.NOTFOUND";

/// <p>Machine code (AD-12, AD-39): a vendor call refused because the item already exists.
/// Rendered on the <parameter>CONFLICT</parameter> slug.</p>
Parameter PORTCONFLICT = "PORT.CONFLICT";

/// <p>Machine code (AD-12, AD-39): a vendor call refused one of the values supplied.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug.</p>
Parameter PORTVALIDATION = "PORT.VALIDATION";

/// <p>Machine code (AD-12, AD-39): this instance does not implement the operation a vendor
/// call named. Rendered on the <parameter>NOTIMPLEMENTED</parameter> slug.</p>
Parameter PORTNOTIMPLEMENTED = "PORT.NOTIMPLEMENTED";

/// <p>Machine code (AD-12, AD-27, AD-39): the port refused to call the instance's admin API
/// because the API does not report the version OcuPilot pins or its probe endpoint did not
/// answer. Rendered on the <parameter>UNAVAILABLE</parameter> slug.</p>
Parameter PORTUNAVAILABLE = "PORT.UNAVAILABLE";

/// <p>Machine code (AD-12, AD-26, AD-39): an asynchronous vendor task reached no terminal state
/// within the port's bounded wait. Rendered on the <parameter>UNAVAILABLE</parameter> slug.</p>
Parameter PORTTIMEOUT = "PORT.TIMEOUT";

/// <p>Machine code (AD-12, AD-39, AD-42): the provider layer could not be configured at all -- no
/// definition carries the id the caller named, the definition is not usable, or its provider's
/// catalog row names no adapter class this instance holds. Produced by
/// <class>OcuPilot.Port.ProviderPort</class> on the <parameter>UNAVAILABLE</parameter> slug.</p>
/// <p>The nine <code>PROVIDER.*</code> codes and the three endpoint violation codes below are
/// declared <b>here</b>, with their producers in other classes, for the reason the seven
/// <code>PORT.*</code> codes are: this class is the one home of the vocabulary.</p>
Parameter PROVIDERUNCONFIGURED = "PROVIDER.UNCONFIGURED";

/// <p>Machine code (AD-12, AD-39, AD-42, DW-21): the endpoint's <b>resolved</b> address is one
/// OcuPilot will not call -- loopback, link-local or one of this instance's own interface
/// addresses without the catalog row's local escape, or a name that resolves to nothing at all.
/// Produced by <class>OcuPilot.Port.ProviderPort</class>'s call-time re-check on the
/// <parameter>UNAVAILABLE</parameter> slug, which is what a name repointed after the write was
/// accepted arrives as.</p>
/// <p>Distinct from <parameter>AGENTENDPOINTADDRESS</parameter>, which is the same judgement made
/// at <i>write</i> time on the field the operator typed.</p>
Parameter PROVIDEREGRESS = "PROVIDER.EGRESS";

/// <p>Machine code (AD-12, AD-35, AD-39): the definition's credential reference resolved to
/// nothing, so <b>no call is made</b>. The reason names the reference -- the credential type and
/// the variable or entry name -- and never a value.</p>
Parameter PROVIDERCREDENTIAL = "PROVIDER.CREDENTIAL";

/// <p>Machine code (AD-12, AD-35, AD-39): the resolved credential does not start with the prefix
/// the provider's catalog row declares, so <b>no call is made</b>. The reason states the expected
/// prefix and never any part of the resolved value.</p>
/// <p>It exists because the harvested original read an unset environment variable's own name as a
/// value and sent whatever it found; a key-shaped gate turns that into a refusal naming the
/// reference rather than a request carrying a filesystem path.</p>
Parameter PROVIDERKEYSHAPE = "PROVIDER.KEYSHAPE";

/// <p>Machine code (AD-12, AD-39, AD-42): the provider answered a status that is not retryable --
/// it refused the request. The provider's own message rides in the fault's
/// <code>detail.providerText</code>; the raw body goes to
/// <method>OcuPilot.Kernel.Fault.LogRaw</method> and nowhere else.</p>
Parameter PROVIDERREFUSED = "PROVIDER.REFUSED";

/// <p>Machine code (AD-12, AD-39, AD-42): every attempt the stored bound allows answered a
/// retryable status, so the provider is not serving this call.</p>
Parameter PROVIDERUNAVAILABLE = "PROVIDER.UNAVAILABLE";

/// <p>Machine code (AD-12, AD-39, AD-42): the provider did not answer within the stored per-call
/// timeout. <b>Never retried</b>, for the reason a mid-flight throw is not: the request may
/// already have been processed.</p>
Parameter PROVIDERTIMEOUT = "PROVIDER.TIMEOUT";

/// <p>Machine code (AD-12, AD-39, AD-42): the request failed in transport -- the call raised, or
/// returned a status that is neither a timeout nor an HTTP answer. <b>Never retried.</b></p>
Parameter PROVIDERTRANSPORT = "PROVIDER.TRANSPORT";

/// <p>Machine code (AD-12, AD-32, AD-39): the named TLS configuration is not present on this
/// instance and the endpoint is HTTPS. The refusal names the configuration, because an
/// administrator can create it; OcuPilot never falls back to <code>DefaultSSL</code> and never
/// proceeds unencrypted.</p>
Parameter PROVIDERTLS = "PROVIDER.TLS";

/// <p>Machine code (AD-12, AD-36, AD-39): a screen read's <code>maxRows</code> is not a whole
/// number above zero. Rendered on the <parameter>BADREQUEST</parameter> slug by
/// <class>OcuPilot.Screen.Read</class>'s refusal, before the port is called.</p>
Parameter READMAXROWS = "READ.MAXROWS";

/// <p>Machine code (AD-12, AD-21, AD-36): a declared server-search criterion was supplied a value
/// its declaration does not admit -- a <code>choice</code> criterion outside its declared
/// <code>options</code>. Rendered on the <parameter>BADREQUEST</parameter> slug by
/// <class>OcuPilot.Screen.Read</class>'s refusal, before the port is called, so an unrecognized
/// value can never reach the vendor query and widen the search there.</p>
Parameter READCRITERION = "READ.CRITERION";

/// <p>Machine code (AD-12, AD-21): the log source named -- or, for a source the port serves in
/// levels, the level within it -- is not one <class>OcuPilot.Port.LogSourcePort</class>'s fixed
/// enum carries. Rendered on the <parameter>NOTFOUND</parameter> slug, before the port's gate and
/// before any file or query access.</p>
/// <p>Not reachable over the wire while every log route binds its own source key and its own
/// level; the first caller that can reach it is Story 2.12's, which passes a key of its own.</p>
Parameter LOGSOURCE = "LOG.SOURCE";

/// <p>Machine code (AD-12, AD-21): the log file the source resolves to is not present in the
/// instance's manager directory. Rendered on the <parameter>NOTFOUND</parameter> slug, and the
/// resolved path is never echoed with it.</p>
/// <p><b>Distinct from a 200 carrying no lines on purpose</b> (DW-19). That one means the file
/// is there and empty; this one means there is no file, and a viewer that showed them alike
/// would present a missing log as a log with nothing in it.</p>
Parameter LOGABSENT = "LOG.ABSENT";

/// <p>Machine code (AD-12, AD-39): the log file is present and the instance cannot read it --
/// the open failed, or the first read of it did. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug; the underlying status goes to
/// <method>OcuPilot.Kernel.Fault.LogRaw</method> alone.</p>
Parameter LOGUNREADABLE = "LOG.UNREADABLE";

/// <p>Machine code (AD-12, AD-21): the paging cursor is malformed -- an <code>offset</code>
/// without its <code>identity</code>, an <code>identity</code> without its <code>offset</code>,
/// or an offset that is not a whole number above zero. Rendered on the
/// <parameter>BADREQUEST</parameter> slug before the file is opened.</p>
Parameter LOGOFFSET = "LOG.OFFSET";

/// <p>Machine code (AD-12, AD-36): a log page's <code>maxBytes</code> is not a whole number
/// above zero and at or below the port's hard cap. Rendered on the
/// <parameter>BADREQUEST</parameter> slug before the file is opened.</p>
/// <p>A value above the cap is <b>refused</b>, never clamped and served, for the reason
/// <parameter>READMAXROWS</parameter> refuses one: a caller that asked for more than it was
/// given has to be told so, and a silently clamped page reads as a complete one.</p>
Parameter LOGMAXBYTES = "LOG.MAXBYTES";

/// <p>Machine code (AD-12, AD-21, AD-48): the namespace an application-error read named is not one
/// <code>SYS.ApplicationError</code>'s own <code>NamespaceList</code> answers with, so it names no
/// namespace this instance holds errors for. Rendered on the <parameter>NOTFOUND</parameter> slug
/// by <method>OcuPilot.Port.LogSourcePort.Errors</method>, before the per-namespace gate resolves
/// and before any query for that namespace runs.</p>
/// <p>The caller's string reaches no application-error query before that membership test, and none
/// after it either: the namespace a query is given is the one the instance's own enumeration
/// answered with. It does reach one thing first --
/// <method>OcuPilot.Api.Namespaces.GlobalDatabase</method>, to resolve the pair set the gate needs
/// -- which is a typed system lookup that answers 0 for a name the instance does not hold, not a
/// query and not a concatenation (AD-21).</p>
Parameter LOGNAMESPACE = "LOG.NAMESPACE";

/// <p>Machine code (AD-12, AD-21, AD-48): the date an application-error read named is not one
/// <code>SYS.ApplicationError</code>'s own <code>DateList</code> answers with for that namespace --
/// a date purged between one drill level and the next, or one a caller invented. Rendered on the
/// <parameter>NOTFOUND</parameter> slug.</p>
/// <p><b>A named refusal rather than an empty table</b>: the query validates nothing and answers
/// zero rows for a date it cannot resolve, so without this the screen would show "no errors" for a
/// date that has gone.</p>
Parameter LOGDATE = "LOG.DATE";

/// <p>Machine code (AD-12, AD-21, AD-48): the error number an application-error detail read named
/// is not one <code>SYS.ApplicationError</code>'s own <code>ErrorList</code> answers with for that
/// namespace and date. Rendered on the <parameter>NOTFOUND</parameter> slug, before the detail
/// query runs.</p>
Parameter LOGENTRY = "LOG.ENTRY";

/// <p>Machine code (AD-12, AD-36): an application-error read's <code>maxRows</code> is not a whole
/// number above zero. Rendered on the <parameter>BADREQUEST</parameter> slug by
/// <method>OcuPilot.Port.LogSourcePort.Errors</method>, before any query runs.</p>
/// <p><b>Declared rather than reusing <parameter>READMAXROWS</parameter></b>, whose own doc scopes
/// it to a screen read refused by <class>OcuPilot.Screen.Read</class>. This source has no declared
/// read to refuse; sharing the code would make that shipped sentence false. The shape is the same
/// -- absent means the default, anything else is a whole number above zero -- and there is no
/// ceiling, so a large value is honoured rather than refused.</p>
Parameter LOGMAXROWS = "LOG.MAXROWS";

/// <p>Machine code (AD-12, AD-39): an agent definition the request submitted broke one or more of
/// the rules <class>OcuPilot.Kernel.AgentRules</class> applies. Rendered on the
/// <parameter>VALIDATIONFAILED</parameter> slug by <class>OcuPilot.Api.Definitions</class>, with
/// every violation as a <code>{field, code}</code> entry in the envelope's
/// <code>detail.violations</code> -- one response for a submission that breaks four rules, never
/// four responses (AD-39: a slice adds no envelope field of its own, so the list rides inside
/// <code>detail</code>).</p>
/// <p>Distinct from <parameter>PORTVALIDATION</parameter>, which is a <b>vendor</b> refusal
/// normalized onto the same slug. This one is OcuPilot refusing OcuPilot's own input.</p>
Parameter AGENTVALIDATION = "AGENT.VALIDATION";

/// <p>Machine code (AD-12, AD-39): no agent definition on this instance carries the id the route
/// named. Rendered on the <parameter>NOTFOUND</parameter> slug by
/// <class>OcuPilot.Api.Definitions</class> -- never a 500, and never an empty 200.</p>
Parameter AGENTNOTFOUND = "AGENT.NOTFOUND";

/// <p>Machine code (AD-12, AD-39): the request body could not be read or parsed at all, so there
/// is nothing to validate. Rendered on the <parameter>BADREQUEST</parameter> slug, with the
/// <b>stage</b> <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> reported in the reason, so
/// a server-side read fault is never presented as malformed client JSON (DW-24).</p>
Parameter AGENTBADBODY = "AGENT.BADBODY";

/// <p>Violation code (rule 1): a definition needs a name of one to sixty-four characters.
/// Rendered inside <code>detail.violations</code> on the <parameter>VALIDATIONFAILED</parameter>
/// slug, on the field <code>name</code>. Covers both an absent name and one over the length the
/// column holds -- one code, because to the operator both are "the name is not usable".</p>
Parameter AGENTNAMEREQUIRED = "AGENT.NAME.REQUIRED";

/// <p>Violation code (rule 1): another definition already holds that name. The unique index
/// refuses it too; the rule answers first so the caller gets a field rather than
/// <code>#5808</code>.</p>
Parameter AGENTNAMEDUPLICATE = "AGENT.NAME.DUPLICATE";

/// <p>Violation code (rule 2): the provider is not a key
/// <class>OcuPilot.Kernel.Provider.Catalog</class> declares.</p>
Parameter AGENTPROVIDERUNKNOWN = "AGENT.PROVIDER.UNKNOWN";

/// <p>Violation code (rule 3): the maximum token count is not a whole number from 1 to 32000.</p>
Parameter AGENTMAXTOKENSRANGE = "AGENT.MAXTOKENS.RANGE";

/// <p>Violation code (rule 4): the temperature is not a number from 0 to 2.</p>
Parameter AGENTTEMPERATURERANGE = "AGENT.TEMPERATURE.RANGE";

/// <p>Violation code (rule 5): the credential type is neither <code>env</code> nor
/// <code>creds</code>.</p>
Parameter AGENTCREDTYPEUNKNOWN = "AGENT.CREDTYPE.UNKNOWN";

/// <p>Violation code (rule 6): the credential type is <code>env</code> and no environment
/// variable is named. Reported <b>after</b> the XOR invariant has normalized the pair, so a body
/// carrying a credential name instead is told what is actually missing.</p>
Parameter AGENTENVVARREQUIRED = "AGENT.ENVVAR.REQUIRED";

/// <p>Violation code (rule 7): the credential type is <code>creds</code> and no credential is
/// named.</p>
Parameter AGENTCREDNAMEREQUIRED = "AGENT.CREDNAME.REQUIRED";

/// <p>Violation code (rule 8): the provider's catalog row requires an endpoint and none was
/// given. Provider-name-free: the rule reads the row's column, so a family that needs one is a
/// catalog row rather than a branch.</p>
Parameter AGENTENDPOINTREQUIRED = "AGENT.ENDPOINT.REQUIRED";

/// <p>Violation code (AD-42, OcuPilot's own rather than harvested): the endpoint is not an
/// absolute <code>https://</code> URL. AD-42's local exception and its resolved-address check are
/// Story 3.2's; at this floor HTTPS is the only accepted scheme.</p>
Parameter AGENTENDPOINTSCHEME = "AGENT.ENDPOINT.SCHEME";

/// <p>Violation code (AD-42, DW-21): the endpoint's <b>resolved</b> address is loopback or one of
/// this instance's own interface addresses, without the catalog row's local escape. Rendered
/// inside <code>detail.violations</code> on the field <code>endpointUrl</code>.</p>
/// <p>A name that resolves to nothing is deliberately <b>not</b> this violation: whether a name
/// resolves is a property of the resolver at that instant rather than of the value the operator
/// typed. It is refused at call time as <parameter>PROVIDEREGRESS</parameter> instead -- see
/// <method>OcuPilot.Kernel.AgentRules.AddressViolation</method>.</p>
/// <p>Every literal is canonicalised through the resolver before it is range-tested, so
/// <code>https://2130706433/v1</code> and <code>https://127.1/v1</code> are refused as the
/// loopback addresses they are.</p>
Parameter AGENTENDPOINTADDRESS = "AGENT.ENDPOINT.ADDRESS";

/// <p>Violation code (AD-42, FR-27): the endpoint resolves into the link-local range
/// (<code>169.254.0.0/16</code> or <code>fe80::/10</code>), which is refused
/// <b>unconditionally</b> -- no catalog row and no marked-local flag opens it. That range is
/// where a cloud instance's metadata service lives, and no local model lives there.</p>
Parameter AGENTENDPOINTLINKLOCAL = "AGENT.ENDPOINT.LINKLOCAL";

/// <p>Violation code (AD-42): the definition is marked local on a provider whose catalog row does
/// not allow it. Rendered on the field <code>markedLocal</code>.</p>
/// <p>Provider-name-free, like rule 8: the escape is the row's <code>allowsLocal</code> column, so
/// a family that supports a local model is a row rather than a branch.</p>
Parameter AGENTLOCALUNSUPPORTED = "AGENT.LOCAL.UNSUPPORTED";

/// <p>Violation code (rule 9): the system-prompt override is longer than 8192 characters.</p>
Parameter AGENTSYSTEMPROMPTLENGTH = "AGENT.SYSTEMPROMPT.LENGTH";

/// <p>Violation code (rule 10): the retention period is not a whole number of days from 1 to
/// 365.</p>
Parameter AGENTRETENTIONRANGE = "AGENT.RETENTION.RANGE";

/// <p>Violation code (rule 11): the per-turn iteration ceiling is not a whole number from 1 to
/// 100.</p>
Parameter AGENTITERATIONSRANGE = "AGENT.ITERATIONS.RANGE";

/// <p>Violation code (AC5, OcuPilot's own rather than harvested): a definition cannot be enabled
/// while Test connection has not succeeded against it as currently configured. Story 3.4 is what
/// clears it, and this code is that story's reason to exist.</p>
Parameter AGENTENABLEUNVERIFIED = "AGENT.ENABLE.UNVERIFIED";

/// <p>Violation code (DW-330): an explicit set-default named a definition that is not enabled.
/// The marker means "the definition in force", and a disabled one is not in force. Produced by
/// <method>OcuPilot.Api.Definitions.HandleSetDefault</method> on the field <code>default</code>,
/// and refused again underneath it by
/// <method>OcuPilot.Kernel.State.Agent.SetDefaultGuarded</method>.</p>
/// <p>The marker <method>OcuPilot.Kernel.State.Agent.GuardedRebalanceDefault</method> places on a
/// disabled definition when no peer is enabled is unaffected: that is a placeholder, not a
/// claim.</p>
Parameter AGENTDEFAULTDISABLED = "AGENT.DEFAULT.DISABLED";

/// <p>Violation code (AD-35): the request to store a key named no key to store -- the body carries
/// no <code>apiKey</code> member, carries one that is not a JSON string, or carries an empty one.
/// Produced by <method>OcuPilot.Api.Definitions.CredentialRefusal</method> on the field
/// <code>apiKey</code>.</p>
Parameter AGENTCREDENTIALREQUIRED = "AGENT.CREDENTIAL.REQUIRED";

/// <p>Violation code (AD-35, AD-42): the definition reads its secret from an environment variable,
/// and OcuPilot cannot write one -- <class>%SYSTEM.Util</class> publishes
/// <method>GetEnviron</method> and no setter, so that rung's store is the operating system and the
/// operator owns it. Produced by <method>OcuPilot.Api.Definitions.CredentialRefusal</method> on the
/// field <code>apiKey</code>.</p>
Parameter AGENTCREDENTIALENVUNWRITABLE = "AGENT.CREDENTIAL.ENVUNWRITABLE";

/// <p>Violation code (AD-35, AD-42): the definition reads its secret from the credentials rung and
/// that rung is not reachable in this namespace, so there is nowhere to write. Produced by
/// <method>OcuPilot.Api.Definitions.CredentialRefusal</method> on the field <code>apiKey</code>,
/// and <b>nothing is written</b>.</p>
Parameter AGENTCREDENTIALRUNGUNAVAILABLE = "AGENT.CREDENTIAL.RUNGUNAVAILABLE";

/// <p>Violation code (AD-35): the key posted does not start with the prefix the provider's catalog
/// row declares, so <b>nothing is written</b>. Produced by
/// <method>OcuPilot.Api.Definitions.CredentialRefusal</method> on the field <code>apiKey</code>,
/// through the adapter's own argument-free
/// <method>OcuPilot.Kernel.Provider.Base.IsApiKeyShapeValid</method> seam.</p>
/// <p>Distinct from <parameter>PROVIDERKEYSHAPE</parameter>, which is the same judgement made at
/// <i>call</i> time on a key that was already stored.</p>
Parameter AGENTKEYSHAPE = "AGENT.KEY.SHAPE";

/// <p>The shape every machine code has: one or more dotted segments, each starting with a
/// letter and continuing with capitals and digits. No lower case, no underscore, no leading
/// digit, and therefore never a number.</p>
/// <p>Held as a parameter rather than inline in <method>IsValidCode</method> so
/// <class>OcuPilot.Test.Envelope</class> can assert the rule the writer enforces instead of a
/// second copy of it.</p>
Parameter CODEPATTERN = "^[A-Z][A-Z0-9]*(\.[A-Z][A-Z0-9]*)*$";

/// <p>The single entry point for every error response.</p>
/// <p>Sets the HTTP status and writes exactly one JSON envelope
/// <code>{error, reason, code}</code>, plus <var>pDetail</var> under the key
/// <code>detail</code> only when it is a supplied object — the key is omitted, never
/// <code>null</code>, when absent. Refuses an unknown <var>pSlug</var> or a malformed
/// <var>pCode</var> by returning an error <class>%Status</class> without writing
/// anything, so a caller that mistypes either fails loudly rather than shipping an
/// envelope the closed enum does not recognize.</p>
/// <p><b>The code's shape is an invariant of this writer, not a convention its call sites
/// keep.</b> "A stable dotted-uppercase identifier, never a number" (AD-39) was a comment here
/// and two assertions at two call sites; a third call site could mint <code>ROUTE.403</code> or
/// <code>route.notfound</code> with nothing red. <method>IsValidCode</method> now decides it in
/// the one place every error response passes through, and the <code>"string"</code> type hint
/// on the <code>code</code> key is the second half of the same guarantee: a value that looks
/// numeric is refused above, and could not serialize as a JSON number even if it were not.</p>
/// @param pStatus HTTP status code (e.g., 400, 404, 500)
/// @param pSlug Coarse error slug from the closed enum above
/// @param pReason Human-readable reason a screen may render and reword freely
/// @param pCode Stable dotted-uppercase machine identifier (e.g. "ROUTE.NOTFOUND")
/// @param pDetail Optional structured detail object
ClassMethod Render(pStatus As %Integer, pSlug As %String, pReason As %String, pCode As %String, pDetail As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsKnownSlug(pSlug) {
            Set tSC = $$$ERROR($$$GeneralError, "Unknown error slug: '" _ pSlug _ "'")
            Quit
        }
        If '..IsValidCode(pCode) {
            Set tSC = $$$ERROR($$$GeneralError, "Malformed error code: '" _ pCode _ "'")
            Quit
        }
        Set %response.Status = pStatus
        Set %response.ContentType = "application/json"
        Set tObj = {}
        Do tObj.%Set("error", pSlug)
        Do tObj.%Set("reason", pReason)
        ; The "string" type hint, always. Without it a %DynamicObject infers the type from the
        ; value, so a numeric-looking code would serialize as a JSON number and a client reading
        ; it would get 403 rather than "403" (AD-39: the code is an identifier, never a number).
        Do tObj.%Set("code", pCode, "string")
        If $IsObject(pDetail) {
            Do tObj.%Set("detail", pDetail)
        }
        Write tObj.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pCode</var> is a well-formed machine code. Three refusals, in the order a
/// caller is likeliest to trip them: empty, canonical-numeric, and anything the
/// <parameter>CODEPATTERN</parameter> shape does not admit.</p>
/// <p>The numeric test is not redundant with the pattern — the pattern already refuses
/// <code>403</code> — it is there because "never a number" is the rule AD-39 actually states
/// and a reviewer changing the pattern should have to delete it deliberately.</p>
ClassMethod IsValidCode(pCode As %String) As %Boolean
{
    If pCode = "" Quit 0
    If pCode = +pCode Quit 0
    Quit $Match(pCode, ..#CODEPATTERN)
}

/// <p>Render a 500 with safe client output. Full exception detail goes to
/// <class>OcuPilot.Kernel.Audit.Log</class>; the client always receives a generic
/// reason and the machine code <code>INTERNAL</code> — splitting logged detail from
/// client reason is exactly what keeps a stack trace off the wire.</p>
/// @param pReason Generic reason string sent to the client (defaults to a fixed generic message)
/// @param pException Optional exception object; its detail is logged, never sent to the client
ClassMethod RenderInternal(pReason As %String = "An internal error occurred", pException As %Exception.AbstractException = "") As %Status
{
    Set tSC = $$$OK
    Try {
        If $IsObject(pException) {
            Do ..LogError("router", "Internal error", {"detail": (pException.DisplayString())})
        }
        Set tSC = ..Render(500, ..#SERVERERROR, pReason, ..#INTERNAL)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The single audit-log seam <method>RenderInternal</method> writes through. Exists as
/// its own overridable method for one reason: <method>RenderInternal</method> used to name
/// <class>OcuPilot.Kernel.Audit.Log</class> by hard class name, which no test could
/// intercept — the same problem <class>OcuPilot.Kernel.Audit.Log.WriteConsole</class> was
/// given this seam treatment for. <class>OcuPilot.Test.ErrorProbe</class> overrides this
/// method to capture the three arguments exactly as <method>RenderInternal</method> passes
/// them, so <class>OcuPilot.Test.Envelope</class> can assert the wiring itself.</p>
/// <p>Production never overrides this — it forwards, unchanged, to
/// <class>OcuPilot.Kernel.Audit.Log</class>.</p>
/// @param pSubsystem Subsystem name passed to Log.Error
/// @param pMessage Message passed to Log.Error
/// @param pData Optional structured detail object passed to Log.Error
ClassMethod LogError(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Kernel.Audit.Log).Error(pSubsystem, pMessage, pData)
}

/// <p>Render a 405 Method Not Allowed response, setting the <code>Allow</code> header
/// to the supported verbs.</p>
/// @param pAllowedMethods Comma-separated list of allowed HTTP methods (e.g., "GET, HEAD")
ClassMethod Render405(pAllowedMethods As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Do %response.SetHeader("Allow", pAllowedMethods)
        ; "This route allows only X, Y", not "Only X, Y is allowed" — pAllowedMethods is
        ; a comma-separated list whenever more than one verb is mapped, and the client
        ; renders this reason verbatim.
        Set tSC = ..Render(405, ..#METHODNOTALLOWED, "This route allows only " _ pAllowedMethods, ..#ROUTEMETHODNOTALLOWED)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Render a 501 Not Implemented response.</p>
/// @param pReason Reason string naming the unimplemented subsystem or feature
ClassMethod Render501(pReason As %String) As %Status
{
    Quit ..Render(501, ..#NOTIMPLEMENTED, pReason, ..#ROUTENOTIMPLEMENTED)
}

/// <p>The machine code for an HTTP status whose only other identity is its number — the two
/// framework-error overrides' non-404 branch.</p>
/// <p><b>Why this exists at all.</b> The derivation was written out at two call sites, byte for
/// byte, in <class>OcuPilot.Api.Router</class> and <class>OcuPilot.Api.StaticHandler</class>,
/// and it produced a <i>second</i> spelling family: <code>$ZConvert</code> alone leaves the
/// slug's separator in, so <code>server_error</code> became <code>ROUTE.SERVER_ERROR</code>
/// while every hand-written code in this class is unseparated (<code>AUTH.NOADMIN</code>,
/// <code>INSTALL.UPGRADEREQUIRED</code>). A client matching on one family would not recognize
/// the other. The separator is stripped here, once, and both overrides call this.</p>
/// @param pStatusCode HTTP status code (e.g., 403, 500)
/// @return "ROUTE." followed by the status's slug, upper-cased and unseparated
ClassMethod CodeForStatus(pStatusCode As %Integer) As %String
{
    Quit "ROUTE." _ $Translate($ZConvert(..GetSlugForStatus(pStatusCode), "U"), "_")
}

/// <p>Map an HTTP status code to its default error slug. Used where only a status is
/// known — e.g. the router's framework-404 override.</p>
/// @param pStatusCode HTTP status code (e.g., 404, 409, 500)
/// @return The default error slug for that status; unknown codes default to server_error
ClassMethod GetSlugForStatus(pStatusCode As %Integer) As %String
{
    If pStatusCode = 400 Quit ..#BADREQUEST
    If pStatusCode = 401 Quit ..#UNAUTHORIZED
    If pStatusCode = 403 Quit ..#FORBIDDEN
    If pStatusCode = 404 Quit ..#NOTFOUND
    If pStatusCode = 405 Quit ..#METHODNOTALLOWED
    If pStatusCode = 409 Quit ..#CONFLICT
    If pStatusCode = 412 Quit ..#PRECONDITIONFAILED
    If pStatusCode = 415 Quit ..#BADCONTENTTYPE
    If pStatusCode = 422 Quit ..#VALIDATIONFAILED
    If pStatusCode = 500 Quit ..#SERVERERROR
    If pStatusCode = 501 Quit ..#NOTIMPLEMENTED
    If pStatusCode = 503 Quit ..#UNAVAILABLE
    Quit ..#SERVERERROR
}

/// <p>Whether <var>pSlug</var> is one of the twelve closed-enum slugs above. Private —
/// the enum is closed and this is the only code that needs to test membership in it.</p>
ClassMethod IsKnownSlug(pSlug As %String) As %Boolean [ Private ]
{
    Quit $ListFind($ListBuild(..#BADREQUEST, ..#UNAUTHORIZED, ..#FORBIDDEN, ..#NOTFOUND, ..#METHODNOTALLOWED, ..#CONFLICT, ..#PRECONDITIONFAILED, ..#BADCONTENTTYPE, ..#VALIDATIONFAILED, ..#SERVERERROR, ..#NOTIMPLEMENTED, ..#UNAVAILABLE), pSlug) > 0
}

}
