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

/// <p>Written sentence for <parameter>AUTHNOPRIVILEGE</parameter> wherever the code carries one
/// rather than an envelope's <code>detail.failedPair</code> alone: a tool step's
/// <code>reason</code> (Story 4.5) and the ledger's cross-user 403 (Story 4.9). It names the
/// request, because the second of those is a read request the caller made directly and no tool
/// call is involved; <code>detail.failedPair</code> is what says which pair failed.</p>
Parameter REASONAUTHNOPRIVILEGE = "This account does not hold the privilege this request requires.";

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

/// <p>Machine code (AD-12, AD-27, AD-39): a vendor delete answered as made and a re-read found the
/// object still there (<parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter>). Rendered on
/// the <parameter>SERVERERROR</parameter> slug at 500 with <parameter>REASONPORTNOTAPPLIED</parameter>.</p>
Parameter PORTNOTAPPLIED = "PORT.NOTAPPLIED";

Parameter REASONPORTNOTAPPLIED = "The instance reported the change as made, and it is not there.";

/// <p>Machine code (AD-12, AD-39, AD-42): the provider layer could not be configured at all -- no
/// definition carries the id the caller named, the definition is not usable, or its provider's
/// catalog row names no adapter class this instance holds. Produced by
/// <class>OcuPilot.Port.ProviderPort</class> on the <parameter>UNAVAILABLE</parameter> slug.</p>
/// <p>The thirteen <code>PROVIDER.*</code> codes and the three endpoint violation codes below are
/// declared <b>here</b>, with their producers in other classes, for the reason the seven
/// <code>PORT.*</code> codes are: this class is the one home of the vocabulary.</p>
Parameter PROVIDERUNCONFIGURED = "PROVIDER.UNCONFIGURED";

/// <p>Machine code (AD-12, AD-39, AD-42, DW-21): the endpoint's <b>resolved</b> address, or the
/// configured proxy's, is one OcuPilot will not call -- loopback, link-local or one of this
/// instance's own interface addresses without the catalog row's local escape, or a name that
/// resolves to nothing at all. Produced by <class>OcuPilot.Port.ProviderPort</class>'s call-time
/// re-check on the <parameter>UNAVAILABLE</parameter> slug, which is what a name repointed after
/// the write was accepted arrives as; a refused proxy carries
/// <parameter>OcuPilot.Kernel.Provider.Base.REASONPROXYEGRESS</parameter> as its reason.</p>
/// <p>Distinct from <parameter>AGENTENDPOINTADDRESS</parameter>, which is the same judgement made
/// at <i>write</i> time on the field the operator typed.</p>
Parameter PROVIDEREGRESS = "PROVIDER.EGRESS";

/// <p>Machine code (AD-12, AD-35, AD-39): the definition's credential reference resolved to
/// nothing, so <b>no call is made</b>. The reason names the reference -- the credential type and
/// the variable or entry name -- and never a value.</p>
Parameter PROVIDERCREDENTIAL = "PROVIDER.CREDENTIAL";

/// <p>Machine code (AD-12, AD-35, AD-39, AD-42): the credential store the definition's reference
/// lives in could not be read -- the rung is not reachable from this namespace, or the read
/// failed -- so <b>no call is made and a stored definition is left enabled</b>. The reason names
/// the reference and never a value.</p>
/// <p>Distinct from <parameter>PROVIDERCREDENTIAL</parameter>, which is a reference the store
/// answered for and holds nothing behind, and which disables a stored definition: this one says
/// nothing about the reference, so a caller can tell a store it could not read from a reference
/// that resolves to nothing. It does not say the failure will pass: a namespace that is not
/// interoperability-enabled answers it on every call.</p>
Parameter PROVIDERCREDENTIALSTORE = "PROVIDER.CREDENTIALSTORE";

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

/// <p>Machine code (AD-12, AD-39, AD-42): Test connection waited its wall-clock bound and the
/// provider had not answered, on a definition that is not marked local. Produced by
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> through
/// <method>OcuPilot.Kernel.Provider.TestCall.TimeoutFault</method>, as 504 on the
/// <parameter>UNAVAILABLE</parameter> slug, with <code>detail.waitedSeconds</code> and
/// <code>detail.providerLabel</code>. Nothing is recorded verified.</p>
Parameter PROVIDERTESTTIMEOUT = "PROVIDER.TESTTIMEOUT";

/// <p>Machine code (AD-12, AD-39, AD-42): <parameter>PROVIDERTESTTIMEOUT</parameter>'s twin for a
/// definition marked local, whose reason says a local model may still be loading.</p>
Parameter PROVIDERTESTTIMEOUTLOCAL = "PROVIDER.TESTTIMEOUTLOCAL";

/// <p>Machine code (AD-12, AD-39, AD-42): the provider answered with the canonical
/// <code>refusal</code> stop reason -- the model declined to answer -- streamed or not. A turn ends
/// <code>failed</code> on it with no reply; produced by <class>OcuPilot.Kernel.Agent.Loop</class> on
/// the <parameter>UNAVAILABLE</parameter> slug.</p>
Parameter PROVIDERDECLINED = "PROVIDER.DECLINED";

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

/// <p>Machine code (AD-12, AD-39): the agent configuration the request submitted broke one or more
/// of the rules <class>OcuPilot.Kernel.AgentRules</class> (a definition) or
/// <class>OcuPilot.Kernel.SwitchRules</class> (the switches and the per-user holds) applies.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug by
/// <class>OcuPilot.Api.Definitions</class> and <class>OcuPilot.Api.Switches</class>, with
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
/// is nothing to validate. Rendered on the <parameter>BADREQUEST</parameter> slug with
/// <parameter>REASONAGENTBADBODY</parameter> alone.</p>
Parameter AGENTBADBODY = "AGENT.BADBODY";

/// <p>Written sentence for <parameter>AGENTBADBODY</parameter> (AD-39). The raw
/// <class>%Status</class> the read reported is written to the log and never to the wire, because
/// it is vendor-shaped text naming internal classes.</p>
Parameter REASONAGENTBADBODY = "The request body could not be read as JSON. Send a JSON object, or no body at all.";

/// <p>Machine code (Story 4.4, AD-39): <code>PUT /agent/context</code>'s body carries anything
/// other than exactly the boolean member <code>share</code> -- an absent, badly typed or extra
/// member. Rendered on the <parameter>VALIDATIONFAILED</parameter> slug by
/// <class>OcuPilot.Api.Context</class>; nothing is written.</p>
Parameter AGENTCONTEXTSHARE = "AGENT.CONTEXT.SHARE";

/// <p>The envelope's <code>reason</code> for <parameter>AGENTCONTEXTSHARE</parameter>.</p>
Parameter REASONAGENTCONTEXTSHARE = "The body must carry exactly one member, the boolean share.";

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

/// <p>Violation code: the credential type is <code>creds</code> in a namespace whose credentials
/// rung is unreachable (<method>OcuPilot.Kernel.Secret.Ladder.CredentialsRungAvailable</method>
/// answers 0), so the definition could never resolve its key.</p>
Parameter AGENTCREDTYPEUNAVAILABLE = "AGENT.CREDTYPE.UNAVAILABLE";

/// <p>Violation code (rule 6): the credential type is <code>env</code> and no environment
/// variable is named. Reported <b>after</b> the XOR invariant has normalized the pair, so a body
/// carrying a credential name instead is told what is actually missing.</p>
Parameter AGENTENVVARREQUIRED = "AGENT.ENVVAR.REQUIRED";

/// <p>Violation code (rule 7): the credential type is <code>creds</code> and no credential is
/// named.</p>
Parameter AGENTCREDNAMEREQUIRED = "AGENT.CREDNAME.REQUIRED";

/// <p>Violation code (DW-344): the credential type is <code>creds</code> and the credential entry
/// name is longer than <code>Ens.Config.Credentials.SystemName</code> stores. Produced by
/// <method>OcuPilot.Kernel.AgentRules.Validate</method> on the field <code>credentialName</code>,
/// and its violation reason states the bound.</p>
/// <p><b>A server rule rather than a client <code>maxlength</code></b>: without it the store
/// answered 500 for any caller, and an affordance on one form does not bind the API.</p>
Parameter AGENTCREDNAMELENGTH = "AGENT.CREDNAME.LENGTH";

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
/// (<code>169.254.0.0/16</code> or <code>fe80::/10</code>), or onto one of the published cloud
/// instance-metadata addresses outside it
/// (<parameter>OcuPilot.Kernel.Egress.METADATAADDRESSES</parameter>). Refused
/// <b>unconditionally</b> -- no catalog row and no marked-local flag opens it. That is where a
/// cloud instance's metadata service lives, and no local model lives there.</p>
Parameter AGENTENDPOINTLINKLOCAL = "AGENT.ENDPOINT.LINKLOCAL";

/// <p>Violation code (AD-42): the endpoint is a plain <code>http://</code> address and the
/// definition carries a credential, without the stored acknowledgment that the key crosses the
/// network unencrypted. Rendered on the field <code>httpAcknowledged</code>.</p>
/// <p>A <code>credType</code> of <code>none</code> never earns it: there is no key to expose.</p>
Parameter AGENTHTTPACKREQUIRED = "AGENT.HTTP.ACK.REQUIRED";

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

/// <p>Violation code (AD-37): the credential entry the definition names already exists and no
/// definition naming it exactly carries OcuPilot's ownership mark, so OcuPilot will not overwrite
/// it and <b>nothing is written</b>. Produced by
/// <method>OcuPilot.Api.Definitions.HandleStoreCredential</method> on the field <code>apiKey</code>
/// when <method>OcuPilot.Kernel.Secret.Ladder.Store</method> declines the overwrite.</p>
Parameter AGENTCREDENTIALNOTOWNED = "AGENT.CREDENTIAL.NOTOWNED";

/// <p>Violation code (AD-7, AD-8, AD-42): the caller does not hold a pair the vendor's credential
/// store needs to write an entry -- <code>%Ens_Credentials:WRITE</code>, which install never grants,
/// or write on the database the entry's row is saved in -- so <b>nothing is written</b>. Produced
/// by <method>OcuPilot.Api.Definitions.CredentialRefusal</method> on the field <code>apiKey</code>,
/// and its sentence names the pair that failed (<method>ReasonForCredentialPrivilege</method>).</p>
Parameter AGENTCREDENTIALNOPRIVILEGE = "AGENT.CREDENTIAL.NOPRIVILEGE";

/// <p>Violation code (FR-20): the kill switch was turned on with no reason. The published
/// kill-switch banner carries the operator's reason in front of everyone it affects, so a switch
/// with none would leave a sentence with a hole in it. Produced by
/// <method>OcuPilot.Kernel.SwitchRules.ValidateSwitches</method> on the field
/// <code>killSwitchReason</code>.</p>
Parameter AGENTSWITCHREASONREQUIRED = "AGENT.SWITCH.REASONREQUIRED";

/// <p>Violation code (Story 4.4, AD-24): <code>contextRowCap</code> is not a whole number from 1
/// to 1,000. Produced by <method>OcuPilot.Kernel.SwitchRules.ValidateSwitches</method> on the
/// field <code>contextRowCap</code>.</p>
Parameter AGENTSWITCHCONTEXTROWCAP = "AGENT.SWITCH.CONTEXTROWCAP";

/// <p>Violation code (FR-20): a per-user hold named no user. Produced by
/// <method>OcuPilot.Kernel.SwitchRules.ValidateHold</method> on the field <code>userName</code>.</p>
Parameter AGENTHOLDUSERREQUIRED = "AGENT.HOLD.USERREQUIRED";

/// <p>Violation code (FR-20): a per-user hold named no reason, which the banner shown to that user
/// needs for the same reason the instance-wide one does. Produced on the field
/// <code>reason</code>.</p>
Parameter AGENTHOLDREASONREQUIRED = "AGENT.HOLD.REASONREQUIRED";

/// <p>Violation code (FR-20): the agent is already switched off for that user. The unique index
/// refuses a second hold too; the rule answers first so the caller gets a field rather than
/// <code>#5808</code>. Produced on the field <code>userName</code>.</p>
Parameter AGENTHOLDDUPLICATE = "AGENT.HOLD.DUPLICATE";

/// <p>Machine code (AD-12, AD-39): no per-user hold on this instance carries the id the route
/// named. Rendered on the <parameter>NOTFOUND</parameter> slug by
/// <class>OcuPilot.Api.Switches</class>.</p>
Parameter AGENTHOLDNOTFOUND = "AGENT.HOLD.NOTFOUND";

/// <p>Machine code (AD-12, AD-39): a write to OcuPilot's own state was refused because the row
/// moved after this request read it (Consistency Conventions: concurrent writes to OcuPilot's own
/// state). Rendered on the <parameter>CONFLICT</parameter> slug, HTTP 409, by
/// <class>OcuPilot.Api.Switches</class> and <class>OcuPilot.Api.Definitions</class>.</p>
/// <p><b>It is a refusal, never a retry instruction.</b> The screen reloads and the person saves
/// again, which is the published sentence's own advice; nothing here re-submits.</p>
Parameter STATECONFLICT = "STATE.CONFLICT";

/// <p>The envelope reason <parameter>STATECONFLICT</parameter> carries. Server-authored, like
/// every other envelope reason: the client renders EXPERIENCE.md's published conflict sentence on
/// this code and never this text, which is why this one states the mechanism rather than the
/// remedy.</p>
Parameter REASONSTATECONFLICT = "This record changed on the instance after it was read, so the save was refused.";

/// <p>Restraint code (AD-30, FR-19): read-only is enforced on this instance, so no write may be
/// made through the agent. Produced by <method>OcuPilot.Kernel.Restraint.Verdict</method>, which is
/// the tree's only producer of a restraint code.</p>
/// <p>It wins over <parameter>AGENTREADONLYDEFINITION</parameter> when both sources are on:
/// precedence is broadest scope first.</p>
Parameter AGENTREADONLYENFORCED = "AGENT.READONLY.ENFORCED";

/// <p>Restraint code (AD-30, FR-19): the agent definition in force is itself restrained to reads
/// (<property>OcuPilot.Kernel.State.Agent.ReadOnly</property>).</p>
Parameter AGENTREADONLYDEFINITION = "AGENT.READONLY.DEFINITION";

/// <p>Restraint code (AD-30, FR-20): the kill switch is on for everyone on this instance.</p>
Parameter AGENTKILLSWITCHGLOBAL = "AGENT.KILLSWITCH.GLOBAL";

/// <p>Restraint code (AD-30, FR-20): the kill switch is on for the acting user alone.</p>
Parameter AGENTKILLSWITCHUSER = "AGENT.KILLSWITCH.USER";

/// <p>The written sentence one restraint code carries (AD-39), for the same reason
/// <method>ReasonForViolation</method> exists: one home, so the same refusal cannot be worded two
/// ways. A tool result renders the code; this is the sentence beside it.</p>
/// <p><b>Distinct from the panel's published banners and footer line</b>, which are the client's
/// own copy from EXPERIENCE.md's Fixed strings table and are chosen by the verdict's
/// <code>footerKey</code> rather than composed from this text.</p>
/// <p><code>""</code> for a code with no published sentence.</p>
ClassMethod ReasonForRestraint(pCode As %String) As %String
{
    If pCode = ..#AGENTREADONLYENFORCED Quit ..#REASONAGENTREADONLYENFORCED
    If pCode = ..#AGENTREADONLYDEFINITION Quit ..#REASONAGENTREADONLYDEFINITION
    If pCode = ..#AGENTKILLSWITCHGLOBAL Quit ..#REASONAGENTKILLSWITCHGLOBAL
    If pCode = ..#AGENTKILLSWITCHUSER Quit ..#REASONAGENTKILLSWITCHUSER
    Quit ""
}

/// <p>Every restraint code, as a <class>%List</class>. Exists so a test can hold
/// <method>ReasonForRestraint</method> to the vocabulary without re-spelling either, which is what
/// catches a code added with no sentence behind it.</p>
ClassMethod RestraintCodes() As %List
{
    Quit $ListBuild(..#AGENTREADONLYENFORCED, ..#AGENTREADONLYDEFINITION, ..#AGENTKILLSWITCHGLOBAL, ..#AGENTKILLSWITCHUSER)
}

/// <p>Written sentence for <parameter>AGENTREADONLYENFORCED</parameter>.</p>
Parameter REASONAGENTREADONLYENFORCED = "Read-only mode is enforced on this instance, so no write can be made through the agent.";

/// <p>Written sentence for <parameter>AGENTREADONLYDEFINITION</parameter>.</p>
Parameter REASONAGENTREADONLYDEFINITION = "The agent definition in force is read-only, so no write can be made through the agent.";

/// <p>Written sentence for <parameter>AGENTKILLSWITCHGLOBAL</parameter>.</p>
Parameter REASONAGENTKILLSWITCHGLOBAL = "The agent is switched off on this instance.";

/// <p>Written sentence for <parameter>AGENTKILLSWITCHUSER</parameter>.</p>
Parameter REASONAGENTKILLSWITCHUSER = "The agent is switched off for this user.";

/// <p>Machine code (AD-7, AD-12): the turn request's body is absent, not JSON, or not a JSON
/// object. Rendered on the <parameter>BADREQUEST</parameter> slug by
/// <class>OcuPilot.Api.Turn</class>; nothing is reserved.</p>
Parameter TURNBADBODY = "TURN.BADBODY";

/// <p>Violation code (AD-39): the turn request carries no <code>message</code>, one that is not a
/// JSON string, or one with nothing in it but whitespace. Rendered as the envelope code on the
/// <parameter>VALIDATIONFAILED</parameter> slug, with the same code on the field
/// <code>message</code> in <code>detail.violations</code>.</p>
Parameter TURNMESSAGEREQUIRED = "TURN.MESSAGE.REQUIRED";

/// <p>Violation code (AD-31): the message is longer than
/// <parameter>OcuPilot.Kernel.Agent.Limits.MESSAGEMAXLENGTH</parameter>. Rendered the way
/// <parameter>TURNMESSAGEREQUIRED</parameter> is; the producer appends the bound.</p>
Parameter TURNMESSAGELENGTH = "TURN.MESSAGE.LENGTH";

/// <p>Violation code (Story 4.4, AD-24): the turn request's <code>context</code> is not shaped as
/// <code>{route, namespace, entity?, view?}</code> declares, a member carries the wrong JSON type,
/// <code>view.rowsAvailable</code> is negative or below the number of rows sent, or
/// <code>namespace</code> differs from the request's resolved scope
/// (<method>OcuPilot.Kernel.Scope.Current</method>). Rendered the way
/// <parameter>TURNMESSAGEREQUIRED</parameter> is, on the field <code>context</code>; nothing is
/// reserved.</p>
Parameter TURNCONTEXTINVALID = "TURN.CONTEXT.INVALID";

/// <p>Violation code (Story 4.5): the turn request carries no <code>conversationId</code>, or one
/// that is not a JSON string. Rendered the way <parameter>TURNMESSAGEREQUIRED</parameter> is, on
/// the field <code>conversationId</code>; nothing is reserved. Checked before
/// <parameter>TURNCONVERSATIONNOTFOUND</parameter> and before the turn slot is reserved.</p>
Parameter TURNCONVERSATIONREQUIRED = "TURN.CONVERSATION.REQUIRED";

/// <p>Machine code (Story 4.5): the request's <code>conversationId</code> does not name a
/// conversation the caller owns. Rendered on the <parameter>NOTFOUND</parameter> slug, HTTP 404 --
/// the same envelope shape an unknown turn id answers -- and nothing is reserved.</p>
Parameter TURNCONVERSATIONNOTFOUND = "TURN.CONVERSATION.NOTFOUND";

/// <p>Machine code (AD-41): the caller already has a queued or running turn. Rendered on the
/// <parameter>CONFLICT</parameter> slug, HTTP 409.</p>
Parameter TURNBUSY = "TURN.BUSY";

/// <p>Machine code (AD-33): no turn with that id belongs to the caller. Rendered on the
/// <parameter>NOTFOUND</parameter> slug for an unknown id and for another user's alike.</p>
Parameter TURNNOTFOUND = "TURN.NOTFOUND";

/// <p>Machine code (AD-7): the turn could not be run on this instance -- the job did not spawn,
/// did not start as its caller, or failed outside the provider call.</p>
Parameter TURNUNAVAILABLE = "TURN.UNAVAILABLE";

/// <p>Terminal code (AD-7): the owner stopped the turn.</p>
Parameter TURNSTOPPED = "TURN.STOPPED";

/// <p>Terminal code (AD-30): enforced read-only changed while the turn ran.</p>
Parameter TURNABANDONEDREADONLY = "TURN.ABANDONED.READONLY";

/// <p>Terminal code (AD-31): the owner no longer holds any of the resources the turn is checked
/// against, or no longer exists.</p>
Parameter TURNABANDONEDPRIVILEGE = "TURN.ABANDONED.PRIVILEGE";

/// <p>Terminal code (AD-31): no authenticated poll by the owner renewed the turn within the
/// lease.</p>
Parameter TURNABANDONEDLEASE = "TURN.ABANDONED.LEASE";

/// <p>Terminal code (AD-31): the owner signed out through OcuPilot.</p>
Parameter TURNABANDONEDSIGNOUT = "TURN.ABANDONED.SIGNOUT";

/// <p>Terminal code (AD-7): no live process held the turn's slot.</p>
Parameter TURNABANDONEDJOBLOST = "TURN.ABANDONED.JOBLOST";

/// <p>Terminal code (AD-31, AD-41): the turn reached its wall-clock limit.</p>
Parameter TURNLIMITDURATION = "TURN.LIMIT.DURATION";

/// <p>Terminal code (AD-41): the turn reached its provider token limit.</p>
Parameter TURNLIMITTOKENS = "TURN.LIMIT.TOKENS";

/// <p>Tool-result code (AD-11): the tool could not be answered on this instance -- the registry,
/// the caller's identity, the gate, the restraint verdict or the tool itself could not be read.
/// Carried as the content of an error tool result, never as an envelope.</p>
Parameter TOOLUNAVAILABLE = "TOOL.UNAVAILABLE";

/// <p>Tool-result code (AD-11): the model named a tool no registered tool is advertised as.</p>
Parameter TOOLUNKNOWN = "TOOL.UNKNOWN";

/// <p>Tool-result code (AD-22): the governance gate point refused the call. The tool stays
/// advertised.</p>
Parameter TOOLDENIED = "TOOL.DENIED";

/// <p>Tool-result code (AD-11): the call's input is not an object, or does not satisfy the tool's
/// input schema. <code>detail.problem</code> names the argument and the rule.</p>
Parameter TOOLARGUMENTS = "TOOL.ARGUMENTS";

/// <p>Tool-result code (AD-24): the result exceeds the size cap and has no rows to drop.</p>
Parameter TOOLRESULTTOOLARGE = "TOOL.RESULTTOOLARGE";

/// <p>Tool-result code (Story 4.7, AD-5, AD-11 rule 3): <code>shell.screen.open</code>'s
/// <code>route</code> passed the tool's own enum but <class>OcuPilot.Screen.Registry</class> no
/// longer names a built screen at it -- the enum and the registry have disagreed. Refused by the
/// tool body's own <code>Directive</code> before any announcement exists, so no announce step and
/// no directive are ever written.</p>
Parameter NAVROUTEUNKNOWN = "NAV.ROUTEUNKNOWN";

/// <p>Tool-result code (Story 4.7, AD-5): the call named an <code>entityId</code> against a
/// screen whose <code>id.kind</code> is <code>none</code> or <code>composite</code>. Refused by
/// the tool body before any announcement exists, because the tool never invents a second composite
/// id grammar (AD-5).</p>
Parameter NAVENTITYNOTALLOWED = "NAV.ENTITYNOTALLOWED";

/// <p>Tool-result code (Story 5.8, AD-21): the call named a <code>criterion</code> the target
/// screen's own descriptor does not declare as a flag -- a name it declares nothing under, a
/// criterion field whose value a person types, or a name carrying a value the caller supplied.
/// Refused by the tool body before any announcement exists, because a navigation names a declared
/// criterion and never supplies its value.</p>
Parameter NAVCRITERIONUNKNOWN = "NAV.CRITERIONUNKNOWN";

/// <p>Terminal tool-result code for the navigation announce step (Story 4.7, AD-11 invariant 3):
/// the departing <code>form-page</code> was dirty and the operator declined "Leave without
/// saving?". The announcement is withdrawn, and the call's own <code>tool_result</code> is an
/// ordinary refusal, <code>is_error</code> false.</p>
Parameter NAVREFUSEDUNSAVED = "NAV.REFUSEDUNSAVED";

/// <p>Terminal tool-result code for the navigation announce step (Story 4.7, AD-11 invariant 3):
/// no browser answered the directive within <code>NAVWAITSECONDS</code>. The announcement is
/// withdrawn, and the call's own <code>tool_result</code> is an ordinary refusal, <code>is_error</code>
/// false -- never a hang and never an error.</p>
Parameter NAVUNAVAILABLE = "NAV.UNAVAILABLE";

/// <p>Tool-result code (Story 4.7, AD-11 rule 3): a client-fulfilled tool's <code>View</code> was
/// invoked on the instance, which is a mis-wiring the tool refuses loudly rather than serving
/// silently in the wrong place. Never reachable while <code>FULFILMENT</code> reads
/// <code>client</code>, since <class>OcuPilot.Kernel.Agent.Dispatch</class> never calls
/// <code>InvokeTool</code> for such a tool.</p>
Parameter NAVNOTINSTANCE = "NAV.NOTINSTANCE";

/// <p>Machine code (Story 4.7): <code>POST /turn/:id/navigation</code>'s body carries an
/// <code>outcome</code> or <code>code</code> outside the closed vocabulary
/// <code>{"opened","refused"}</code> / <code>{"NAV.REFUSEDUNSAVED", null}</code>, or no
/// <code>seq</code>. Rendered on the <parameter>VALIDATIONFAILED</parameter> slug, HTTP 422 -- the
/// closed vocabulary is what keeps the client from ever authoring model-visible text.</p>
Parameter TURNNAVIGATIONINVALID = "TURN.NAVIGATION.INVALID";

/// <p>Written sentence for <parameter>TURNBADBODY</parameter>.</p>
Parameter REASONTURNBADBODY = "The request body is not a JSON object carrying a message.";

/// <p>Written sentence for <parameter>TURNMESSAGEREQUIRED</parameter>.</p>
Parameter REASONTURNMESSAGEREQUIRED = "Type a message before sending it.";

/// <p>Written sentence for <parameter>TURNMESSAGELENGTH</parameter>; the producer appends the
/// bound.</p>
Parameter REASONTURNMESSAGELENGTH = "That message is longer than a turn accepts";

/// <p>Written sentence for <parameter>TURNCONTEXTINVALID</parameter>.</p>
Parameter REASONTURNCONTEXTINVALID = "The screen context is not shaped as the turn expects.";

/// <p>Written sentence for <parameter>TURNCONVERSATIONREQUIRED</parameter>.</p>
Parameter REASONTURNCONVERSATIONREQUIRED = "Start or choose a conversation before sending a message.";

/// <p>Written sentence for <parameter>TURNCONVERSATIONNOTFOUND</parameter>.</p>
Parameter REASONTURNCONVERSATIONNOTFOUND = "No conversation with that identifier exists for this account.";

/// <p>Written sentence for <parameter>TURNBUSY</parameter>: EXPERIENCE.md's lock banner.</p>
Parameter REASONTURNBUSY = "A turn is in progress. Wait for it to finish before sending another message.";

/// <p>Written sentence for <parameter>TURNNOTFOUND</parameter>.</p>
Parameter REASONTURNNOTFOUND = "No turn with that identifier exists for this account.";

/// <p>Written sentence for <parameter>TURNUNAVAILABLE</parameter>.</p>
Parameter REASONTURNUNAVAILABLE = "The turn could not be run on this instance.";

/// <p>Written sentence for <parameter>TURNSTOPPED</parameter>.</p>
Parameter REASONTURNSTOPPED = "The turn was stopped.";

/// <p>Written sentence for <parameter>TURNABANDONEDREADONLY</parameter>.</p>
Parameter REASONTURNABANDONEDREADONLY = "Read-only mode changed while the turn was running, so the turn was abandoned.";

/// <p>Written sentence for <parameter>TURNABANDONEDPRIVILEGE</parameter>.</p>
Parameter REASONTURNABANDONEDPRIVILEGE = "This account no longer holds the privilege the turn runs with, so the turn was abandoned.";

/// <p>Written sentence for <parameter>TURNABANDONEDLEASE</parameter>.</p>
Parameter REASONTURNABANDONEDLEASE = "Nothing checked on this turn for too long, so it was abandoned.";

/// <p>Written sentence for <parameter>TURNABANDONEDSIGNOUT</parameter>.</p>
Parameter REASONTURNABANDONEDSIGNOUT = "The turn was abandoned because its owner signed out.";

/// <p>Written sentence for <parameter>TURNABANDONEDJOBLOST</parameter>.</p>
Parameter REASONTURNABANDONEDJOBLOST = "The process running this turn ended unexpectedly, so the turn was abandoned.";

/// <p>Written sentence for <parameter>TURNLIMITDURATION</parameter>.</p>
Parameter REASONTURNLIMITDURATION = "The turn ran as long as a turn may, so it was abandoned.";

/// <p>Written sentence for <parameter>TURNLIMITTOKENS</parameter>.</p>
Parameter REASONTURNLIMITTOKENS = "The turn spent as many provider tokens as a turn may, so it was abandoned.";

/// <p>Written sentence for <parameter>TURNNAVIGATIONINVALID</parameter>.</p>
Parameter REASONTURNNAVIGATIONINVALID = "The navigation outcome is not one this instance accepts.";

/// <p>Written sentence for <parameter>TOOLUNAVAILABLE</parameter>.</p>
Parameter REASONTOOLUNAVAILABLE = "That tool could not be answered on this instance.";

/// <p>Written sentence for <parameter>TOOLUNKNOWN</parameter>.</p>
Parameter REASONTOOLUNKNOWN = "No tool by that name is available to this turn.";

/// <p>Written sentence for <parameter>TOOLDENIED</parameter>.</p>
Parameter REASONTOOLDENIED = "That tool is not permitted on this instance.";

/// <p>Written sentence for <parameter>TOOLARGUMENTS</parameter>.</p>
Parameter REASONTOOLARGUMENTS = "The tool call's arguments do not match what the tool accepts.";

/// <p>Written sentence for <parameter>TOOLRESULTTOOLARGE</parameter>.</p>
Parameter REASONTOOLRESULTTOOLARGE = "The tool's result is larger than a tool result may be.";

/// <p>Written sentence for <parameter>NAVROUTEUNKNOWN</parameter>.</p>
Parameter REASONNAVROUTEUNKNOWN = "That route is not one this instance's screens declare.";

/// <p>Written sentence for <parameter>NAVENTITYNOTALLOWED</parameter>.</p>
Parameter REASONNAVENTITYNOTALLOWED = "This screen does not take a selected row.";

/// <p>Written sentence for <parameter>NAVCRITERIONUNKNOWN</parameter>.</p>
Parameter REASONNAVCRITERIONUNKNOWN = "This screen declares no such filter.";

/// <p>Written sentence for <parameter>NAVREFUSEDUNSAVED</parameter>.</p>
Parameter REASONNAVREFUSEDUNSAVED = "The screen was left with unsaved changes, so the move was not made.";

/// <p>Written sentence for <parameter>NAVUNAVAILABLE</parameter>.</p>
Parameter REASONNAVUNAVAILABLE = "No open browser answered the navigation in time.";

/// <p>Written sentence for <parameter>NAVNOTINSTANCE</parameter>.</p>
Parameter REASONNAVNOTINSTANCE = "This tool is fulfilled by the browser and has no view of its own on the instance.";

/// <p>Machine code (Story 4.9, AD-24): <code>GET /agent/ledger</code>'s <code>windowHours</code> is
/// not a whole number of hours the bounded read admits
/// (<method>OcuPilot.Kernel.State.Base.BoundedWhere</method>). Rendered on the
/// <parameter>BADREQUEST</parameter> slug, HTTP 400.</p>
Parameter LEDGERWINDOWINVALID = "LEDGER.WINDOW.INVALID";

/// <p>Machine code (Story 4.9, AD-24): <code>maxRows</code> is not a whole number above zero and at
/// or below <parameter>OcuPilot.Kernel.Agent.Limits.LEDGERVIEWMAXROWS</parameter>. Rendered the way
/// <parameter>LEDGERWINDOWINVALID</parameter> is.</p>
Parameter LEDGERMAXROWSINVALID = "LEDGER.MAXROWS.INVALID";

/// <p>Machine code (Story 4.9, AD-21, AD-37): the <code>user</code> parameter is not shaped like an
/// account name. The value is never concatenated into anything -- the read binds it (AD-21) -- so
/// this refuses a malformed request rather than defending the query. Rendered the way
/// <parameter>LEDGERWINDOWINVALID</parameter> is.</p>
Parameter LEDGERUSERINVALID = "LEDGER.USER.INVALID";

/// <p>Machine code (Story 4.9, AD-9): the ledger store could not be read. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug, HTTP 503, with the detail logged and nothing of it on
/// the wire.</p>
Parameter LEDGERUNAVAILABLE = "LEDGER.UNAVAILABLE";

/// <p>Written sentence for <parameter>LEDGERWINDOWINVALID</parameter>; the producer appends the
/// bound.</p>
Parameter REASONLEDGERWINDOWINVALID = "That window is not one the ledger reads over";

/// <p>Written sentence for <parameter>LEDGERMAXROWSINVALID</parameter>; the producer appends the
/// bound.</p>
Parameter REASONLEDGERMAXROWSINVALID = "That row count is not one the ledger answers";

/// <p>Written sentence for <parameter>LEDGERUSERINVALID</parameter>.</p>
Parameter REASONLEDGERUSERINVALID = "That is not the shape of an account name on this instance.";

/// <p>Written sentence for <parameter>LEDGERUNAVAILABLE</parameter>.</p>
Parameter REASONLEDGERUNAVAILABLE = "The agent ledger could not be read on this instance.";

/// <p>Every <code>LEDGER.*</code> code, as a <class>%List</class>, so a test can hold
/// <method>ReasonForLedger</method> to the vocabulary -- the model
/// <method>TurnCodes</method>/<method>ReasonForTurn</method> set.</p>
ClassMethod LedgerCodes() As %List
{
    Quit $ListBuild(..#LEDGERWINDOWINVALID, ..#LEDGERMAXROWSINVALID, ..#LEDGERUSERINVALID, ..#LEDGERUNAVAILABLE)
}

/// <p>The written sentence a <code>LEDGER.*</code> code carries, or <code>""</code> for any other
/// code.</p>
ClassMethod ReasonForLedger(pCode As %String) As %String
{
    If pCode = ..#LEDGERWINDOWINVALID Quit ..#REASONLEDGERWINDOWINVALID
    If pCode = ..#LEDGERMAXROWSINVALID Quit ..#REASONLEDGERMAXROWSINVALID
    If pCode = ..#LEDGERUSERINVALID Quit ..#REASONLEDGERUSERINVALID
    If pCode = ..#LEDGERUNAVAILABLE Quit ..#REASONLEDGERUNAVAILABLE
    Quit ""
}

/// <p>Every <code>NAV.*</code> code, as a <class>%List</class>, so a test can hold
/// <method>ReasonForNav</method> to the vocabulary.</p>
ClassMethod NavCodes() As %List
{
    Quit $ListBuild(..#NAVROUTEUNKNOWN, ..#NAVENTITYNOTALLOWED, ..#NAVCRITERIONUNKNOWN, ..#NAVREFUSEDUNSAVED, ..#NAVUNAVAILABLE, ..#NAVNOTINSTANCE)
}

/// <p>The written sentence a <code>NAV.*</code> code carries, or <code>""</code> for any other
/// code. Mirrors <method>ReasonForRestraint</method> for the navigation tool's own vocabulary.</p>
ClassMethod ReasonForNav(pCode As %String) As %String
{
    If pCode = ..#NAVROUTEUNKNOWN Quit ..#REASONNAVROUTEUNKNOWN
    If pCode = ..#NAVENTITYNOTALLOWED Quit ..#REASONNAVENTITYNOTALLOWED
    If pCode = ..#NAVCRITERIONUNKNOWN Quit ..#REASONNAVCRITERIONUNKNOWN
    If pCode = ..#NAVREFUSEDUNSAVED Quit ..#REASONNAVREFUSEDUNSAVED
    If pCode = ..#NAVUNAVAILABLE Quit ..#REASONNAVUNAVAILABLE
    If pCode = ..#NAVNOTINSTANCE Quit ..#REASONNAVNOTINSTANCE
    Quit ""
}

/// <p>Every <code>TURN.*</code> code, as a <class>%List</class>, so a test can hold
/// <method>ReasonForTurn</method> to the vocabulary.</p>
ClassMethod TurnCodes() As %List
{
    Quit $ListBuild(..#TURNBADBODY, ..#TURNMESSAGEREQUIRED, ..#TURNMESSAGELENGTH, ..#TURNCONTEXTINVALID, ..#TURNCONVERSATIONREQUIRED, ..#TURNCONVERSATIONNOTFOUND, ..#TURNBUSY, ..#TURNNOTFOUND, ..#TURNUNAVAILABLE, ..#TURNSTOPPED, ..#TURNABANDONEDREADONLY, ..#TURNABANDONEDPRIVILEGE, ..#TURNABANDONEDLEASE, ..#TURNABANDONEDSIGNOUT, ..#TURNABANDONEDJOBLOST, ..#TURNLIMITDURATION, ..#TURNLIMITTOKENS, ..#TURNNAVIGATIONINVALID)
}

/// <p>The written sentence a <code>TURN.*</code> code carries, or <code>""</code> for any other
/// code.</p>
ClassMethod ReasonForTurn(pCode As %String) As %String
{
    If pCode = ..#TURNBADBODY Quit ..#REASONTURNBADBODY
    If pCode = ..#TURNMESSAGEREQUIRED Quit ..#REASONTURNMESSAGEREQUIRED
    If pCode = ..#TURNMESSAGELENGTH Quit ..#REASONTURNMESSAGELENGTH
    If pCode = ..#TURNCONTEXTINVALID Quit ..#REASONTURNCONTEXTINVALID
    If pCode = ..#TURNCONVERSATIONREQUIRED Quit ..#REASONTURNCONVERSATIONREQUIRED
    If pCode = ..#TURNCONVERSATIONNOTFOUND Quit ..#REASONTURNCONVERSATIONNOTFOUND
    If pCode = ..#TURNBUSY Quit ..#REASONTURNBUSY
    If pCode = ..#TURNNOTFOUND Quit ..#REASONTURNNOTFOUND
    If pCode = ..#TURNUNAVAILABLE Quit ..#REASONTURNUNAVAILABLE
    If pCode = ..#TURNSTOPPED Quit ..#REASONTURNSTOPPED
    If pCode = ..#TURNABANDONEDREADONLY Quit ..#REASONTURNABANDONEDREADONLY
    If pCode = ..#TURNABANDONEDPRIVILEGE Quit ..#REASONTURNABANDONEDPRIVILEGE
    If pCode = ..#TURNABANDONEDLEASE Quit ..#REASONTURNABANDONEDLEASE
    If pCode = ..#TURNABANDONEDSIGNOUT Quit ..#REASONTURNABANDONEDSIGNOUT
    If pCode = ..#TURNABANDONEDJOBLOST Quit ..#REASONTURNABANDONEDJOBLOST
    If pCode = ..#TURNLIMITDURATION Quit ..#REASONTURNLIMITDURATION
    If pCode = ..#TURNLIMITTOKENS Quit ..#REASONTURNLIMITTOKENS
    If pCode = ..#TURNNAVIGATIONINVALID Quit ..#REASONTURNNAVIGATIONINVALID
    Quit ""
}

/// <p>Every <code>TOOL.*</code> code, as a <class>%List</class>, so a test can hold
/// <method>ReasonForTool</method> to the vocabulary.</p>
ClassMethod ToolCodes() As %List
{
    Quit $ListBuild(..#TOOLUNAVAILABLE, ..#TOOLUNKNOWN, ..#TOOLDENIED, ..#TOOLARGUMENTS, ..#TOOLRESULTTOOLARGE)
}

/// <p>The written sentence a <code>TOOL.*</code> code carries, or <code>""</code> for any other
/// code. A tool result renders the code alone (AD-39); this is the sentence a screen shows beside
/// it.</p>
ClassMethod ReasonForTool(pCode As %String) As %String
{
    If pCode = ..#TOOLUNAVAILABLE Quit ..#REASONTOOLUNAVAILABLE
    If pCode = ..#TOOLUNKNOWN Quit ..#REASONTOOLUNKNOWN
    If pCode = ..#TOOLDENIED Quit ..#REASONTOOLDENIED
    If pCode = ..#TOOLARGUMENTS Quit ..#REASONTOOLARGUMENTS
    If pCode = ..#TOOLRESULTTOOLARGE Quit ..#REASONTOOLRESULTTOOLARGE
    Quit ""
}

/// <p>The sentence a tool step's <code>reason</code> carries for <var>pCode</var> (Story 4.5),
/// whichever family produced it: a <code>TOOL.*</code> code, <code>AUTH.NOPRIVILEGE</code>, or a
/// restraint code (a blocked write tool's verdict is passed through as the tool result code
/// unchanged). Mirrors <method>ReasonForTurnError</method> for the tool-result vocabulary, so
/// <class>OcuPilot.Kernel.Agent.Dispatch</class> and <class>OcuPilot.Kernel.Agent.Loop</class>
/// name no family's resolver of their own.</p>
ClassMethod ReasonForToolCode(pCode As %String) As %String
{
    If pCode = "" Quit ""
    If pCode = ..#AUTHNOPRIVILEGE Quit ..#REASONAUTHNOPRIVILEGE
    Set tReason = ..ReasonForTool(pCode)
    If tReason '= "" Quit tReason
    Set tReason = ..ReasonForRestraint(pCode)
    If tReason '= "" Quit tReason
    Set tReason = ..ReasonForNav(pCode)
    If tReason '= "" Quit tReason
    Quit ..#REASONTOOLUNAVAILABLE
}

/// <p>The sentence a turn's terminal <code>error.reason</code> carries for <var>pCode</var>,
/// whichever family the code is from: a <code>TURN.*</code> code, a restraint code, or a
/// <code>PROVIDER.*</code> fault. One lookup, so the progress handler names no family's resolver
/// of its own.</p>
ClassMethod ReasonForTurnError(pCode As %String) As %String
{
    If pCode = "" Quit ""
    Set tReason = ..ReasonForTurn(pCode)
    If tReason '= "" Quit tReason
    Set tReason = ..ReasonForRestraint(pCode)
    If tReason '= "" Quit tReason
    If $Extract(pCode, 1, 9) = "PROVIDER." Quit ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(pCode)
    Quit ..#REASONTURNUNAVAILABLE
}

/// <p>The refusal sentence one field-level violation code carries (AD-39).</p>
/// <p><b>Every field-level code has one, and this class is where they live</b> -- beside the codes
/// themselves and beside the envelope reasons the rest of the tree renders, for the reason the
/// thirteen <code>PROVIDER.*</code> sentences live together in
/// <method>OcuPilot.Kernel.Provider.Base.ReasonFor</method>: one home, so the same refusal cannot
/// be worded two ways. The envelope's own <code>reason</code> for a validation failure is generic
/// -- it names no rule, because it stands for a list of them -- so the sentence a form renders on
/// the field is this one, carried in <code>detail.violations[].reason</code>.</p>
/// <p><b>The client publishes none of this copy.</b> Server-authored refusal text is data, like
/// the envelope's <code>reason</code>; <file>ui/tools/strings.test.mjs</file> admits only what
/// EXPERIENCE.md's Fixed strings table authorizes, and a per-code string table in the client would
/// be a second source for a sentence the instance already writes (AD-39).</p>
/// <p>None of them names a credential value, a pasted key or any part of a caller's input
/// (AD-35); where a bound or a prefix belongs in the sentence, the producing rule appends it to
/// this base rather than spelling a second sentence.</p>
/// <p><code>""</code> for a code with no published sentence, which is how a caller tells "there is
/// no sentence for this" from "the sentence is empty".</p>
ClassMethod ReasonForViolation(pCode As %String) As %String
{
    If $Extract(pCode, 1, 6) = "OAUTH." Quit ..ReasonForOAuth(pCode)
    If pCode = ..#AGENTNAMEREQUIRED Quit ..#REASONAGENTNAMEREQUIRED
    If pCode = ..#AGENTNAMEDUPLICATE Quit ..#REASONAGENTNAMEDUPLICATE
    If pCode = ..#AGENTPROVIDERUNKNOWN Quit ..#REASONAGENTPROVIDERUNKNOWN
    If pCode = ..#AGENTMAXTOKENSRANGE Quit ..#REASONAGENTMAXTOKENSRANGE
    If pCode = ..#AGENTTEMPERATURERANGE Quit ..#REASONAGENTTEMPERATURERANGE
    If pCode = ..#AGENTCREDTYPEUNKNOWN Quit ..#REASONAGENTCREDTYPEUNKNOWN
    If pCode = ..#AGENTCREDTYPEUNAVAILABLE Quit ..#REASONAGENTCREDTYPEUNAVAILABLE
    If pCode = ..#AGENTENVVARREQUIRED Quit ..#REASONAGENTENVVARREQUIRED
    If pCode = ..#AGENTCREDNAMEREQUIRED Quit ..#REASONAGENTCREDNAMEREQUIRED
    If pCode = ..#AGENTCREDNAMELENGTH Quit ..#REASONAGENTCREDNAMELENGTH
    If pCode = ..#AGENTENDPOINTREQUIRED Quit ..#REASONAGENTENDPOINTREQUIRED
    If pCode = ..#AGENTENDPOINTSCHEME Quit ..#REASONAGENTENDPOINTSCHEME
    If pCode = ..#AGENTENDPOINTADDRESS Quit ..#REASONAGENTENDPOINTADDRESS
    If pCode = ..#AGENTENDPOINTLINKLOCAL Quit ..#REASONAGENTENDPOINTLINKLOCAL
    If pCode = ..#AGENTHTTPACKREQUIRED Quit ..#REASONAGENTHTTPACKREQUIRED
    If pCode = ..#AGENTLOCALUNSUPPORTED Quit ..#REASONAGENTLOCALUNSUPPORTED
    If pCode = ..#AGENTSYSTEMPROMPTLENGTH Quit ..#REASONAGENTSYSTEMPROMPTLENGTH
    If pCode = ..#AGENTRETENTIONRANGE Quit ..#REASONAGENTRETENTIONRANGE
    If pCode = ..#AGENTITERATIONSRANGE Quit ..#REASONAGENTITERATIONSRANGE
    If pCode = ..#AGENTENABLEUNVERIFIED Quit ..#REASONAGENTENABLEUNVERIFIED
    If pCode = ..#AGENTDEFAULTDISABLED Quit ..#REASONAGENTDEFAULTDISABLED
    If pCode = ..#AGENTCREDENTIALREQUIRED Quit ..#REASONAGENTCREDENTIALREQUIRED
    If pCode = ..#AGENTCREDENTIALENVUNWRITABLE Quit ..#REASONAGENTCREDENTIALENVUNWRITABLE
    If pCode = ..#AGENTCREDENTIALRUNGUNAVAILABLE Quit ..#REASONAGENTCREDENTIALRUNGUNAVAILABLE
    If pCode = ..#AGENTKEYSHAPE Quit ..#REASONAGENTKEYSHAPE
    If pCode = ..#AGENTCREDENTIALNOTOWNED Quit ..#REASONAGENTCREDENTIALNOTOWNED
    If pCode = ..#AGENTCREDENTIALNOPRIVILEGE Quit ..#REASONAGENTCREDENTIALNOPRIVILEGE
    If pCode = ..#AGENTSWITCHREASONREQUIRED Quit ..#REASONAGENTSWITCHREASONREQUIRED
    If pCode = ..#AGENTSWITCHCONTEXTROWCAP Quit ..#REASONAGENTSWITCHCONTEXTROWCAP
    If pCode = ..#AGENTHOLDUSERREQUIRED Quit ..#REASONAGENTHOLDUSERREQUIRED
    If pCode = ..#AGENTHOLDREASONREQUIRED Quit ..#REASONAGENTHOLDREASONREQUIRED
    If pCode = ..#AGENTHOLDDUPLICATE Quit ..#REASONAGENTHOLDDUPLICATE
    If pCode = ..#ACCOUNTPASSWORDCURRENT Quit ..#REASONACCOUNTPASSWORDCURRENT
    If pCode = ..#ACCOUNTPASSWORDPOLICY Quit ..#REASONACCOUNTPASSWORDPOLICY
    If pCode = ..#PREFERENCESROUTE Quit ..#REASONPREFERENCESROUTE
    If pCode = ..#PREFERENCESLIMIT Quit ..#REASONPREFERENCESLIMIT
    If pCode = ..#HELPROUTE Quit ..#REASONHELPROUTE
    If pCode = ..#PREFERENCESVALUE Quit ..#REASONPREFERENCESVALUE
    If pCode = ..#PREFERENCESNAME Quit ..#REASONPREFERENCESNAME
    If pCode = ..#PREFERENCESCHOICE Quit ..#REASONPREFERENCESCHOICE
    If pCode = ..#WEBAPPNAMEREQUIRED Quit ..#REASONWEBAPPNAMEREQUIRED
    If pCode = ..#WEBAPPNAMESHAPE Quit ..#REASONWEBAPPNAMESHAPE
    If pCode = ..#WEBAPPNAMETAKEN Quit ..#REASONWEBAPPNAMETAKEN
    If pCode = ..#WEBAPPNAMESPACEREQUIRED Quit ..#REASONWEBAPPNAMESPACEREQUIRED
    If pCode = ..#WEBAPPAUTHEREQUIRED Quit ..#REASONWEBAPPAUTHEREQUIRED
    If pCode = ..#WEBAPPAUTHEUNKNOWN Quit ..#REASONWEBAPPAUTHEUNKNOWN
    If pCode = ..#WEBAPPDISPATCHREQUIRED Quit ..#REASONWEBAPPDISPATCHREQUIRED
    If pCode = ..#WEBAPPWSGIAPPNAME Quit ..#REASONWEBAPPWSGIAPPNAME
    If pCode = ..#WEBAPPWSGILOCATION Quit ..#REASONWEBAPPWSGILOCATION
    If pCode = ..#WEBAPPWSGITYPE Quit ..#REASONWEBAPPWSGITYPE
    If pCode = ..#WEBAPPTYPECONFLICT Quit ..#REASONWEBAPPTYPECONFLICT
    If pCode = ..#WEBAPPFIELDLENGTH Quit ..#REASONWEBAPPFIELDLENGTH
    If pCode = ..#WEBAPPWSGIAPPLOCATIONSHAPE Quit ..#REASONWEBAPPWSGIAPPLOCATIONSHAPE
    If pCode = ..#WEBAPPMATCHROLESSHAPE Quit ..#REASONWEBAPPMATCHROLESSHAPE
    If pCode = ..#WEBAPPMATCHROLESUNKNOWN Quit ..#REASONWEBAPPMATCHROLESUNKNOWN
    If pCode = ..#USERNAMEREQUIRED Quit ..#REASONUSERNAMEREQUIRED
    If pCode = ..#USERNAMESHAPE Quit ..#REASONUSERNAMESHAPE
    If pCode = ..#USERNAMETAKEN Quit ..#REASONUSERNAMETAKEN
    If pCode = ..#USERPASSWORDREQUIRED Quit ..#REASONUSERPASSWORDREQUIRED
    If pCode = ..#USERPASSWORDPOLICY Quit ..#REASONUSERPASSWORDPOLICY
    If pCode = ..#USERFULLNAMELENGTH Quit ..#REASONUSERFULLNAMELENGTH
    If pCode = ..#USEREXPIRATIONDATESHAPE Quit ..#REASONUSEREXPIRATIONDATESHAPE
    If pCode = ..#USERNAMESPACEUNKNOWN Quit ..#REASONUSERNAMESPACEUNKNOWN
    If pCode = ..#USERROUTINENAMESPACE Quit ..#REASONUSERROUTINENAMESPACE
    If pCode = ..#USERROUTINELENGTH Quit ..#REASONUSERROUTINELENGTH
    If pCode = ..#USERROLESUNKNOWN Quit ..#REASONUSERROLESUNKNOWN
    If pCode = ..#USERROLESSHAPE Quit ..#REASONUSERROLESSHAPE
    If pCode = ..#USERCOMMENTLENGTH Quit ..#REASONUSERCOMMENTLENGTH
    If pCode = ..#USEREMAILADDRESSLENGTH Quit ..#REASONUSEREMAILADDRESSLENGTH
    If pCode = ..#USERPHONENUMBERLENGTH Quit ..#REASONUSERPHONENUMBERLENGTH
    If pCode = ..#USERPHONEPROVIDERLENGTH Quit ..#REASONUSERPHONEPROVIDERLENGTH
    If pCode = ..#USERTWOFACTORBOTH Quit ..#REASONUSERTWOFACTORBOTH
    If pCode = ..#USERAUTHEENABLEDSCOPE Quit ..#REASONUSERAUTHEENABLEDSCOPE
    If pCode = ..#ROLENAMEREQUIRED Quit ..#REASONROLENAMEREQUIRED
    If pCode = ..#ROLENAMELENGTH Quit ..#REASONROLENAMELENGTH
    If pCode = ..#ROLENAMESHAPE Quit ..#REASONROLENAMESHAPE
    If pCode = ..#ROLENAMETAKEN Quit ..#REASONROLENAMETAKEN
    If pCode = ..#ROLENAMESYSTEM Quit ..#REASONROLENAMESYSTEM
    If pCode = ..#ROLEDESCRIPTIONLENGTH Quit ..#REASONROLEDESCRIPTIONLENGTH
    If pCode = ..#ROLERESOURCESSHAPE Quit ..#REASONROLERESOURCESSHAPE
    If pCode = ..#ROLERESOURCESUNKNOWN Quit ..#REASONROLERESOURCESUNKNOWN
    If pCode = ..#ROLERESOURCESPERMISSIONS Quit ..#REASONROLERESOURCESPERMISSIONS
    If pCode = ..#ROLERESOURCESDUPLICATE Quit ..#REASONROLERESOURCESDUPLICATE
    If pCode = ..#ROLERESOURCESWRITEONLY Quit ..#REASONROLERESOURCESWRITEONLY
    If pCode = ..#ROLEGRANTEDROLESSHAPE Quit ..#REASONROLEGRANTEDROLESSHAPE
    If pCode = ..#ROLEGRANTEDROLESUNKNOWN Quit ..#REASONROLEGRANTEDROLESUNKNOWN
    If pCode = ..#RESOURCENAMEREQUIRED Quit ..#REASONRESOURCENAMEREQUIRED
    If pCode = ..#RESOURCENAMELENGTH Quit ..#REASONRESOURCENAMELENGTH
    If pCode = ..#RESOURCENAMESHAPE Quit ..#REASONRESOURCENAMESHAPE
    If pCode = ..#RESOURCENAMETAKEN Quit ..#REASONRESOURCENAMETAKEN
    If pCode = ..#RESOURCENAMESYSTEM Quit ..#REASONRESOURCENAMESYSTEM
    If pCode = ..#RESOURCENAMEABSENT Quit ..#REASONRESOURCENAMEABSENT
    If pCode = ..#RESOURCEDESCRIPTIONLENGTH Quit ..#REASONRESOURCEDESCRIPTIONLENGTH
    If pCode = ..#RESOURCEPUBLICPERMISSIONSHAPE Quit ..#REASONRESOURCEPUBLICPERMISSIONSHAPE
    If pCode = ..#RESOURCEPUBLICPERMISSIONLETTERS Quit ..#REASONRESOURCEPUBLICPERMISSIONLETTERS
    If pCode = ..#X509ALIASREQUIRED Quit ..#REASONX509ALIASREQUIRED
    If pCode = ..#X509ALIASLENGTH Quit ..#REASONX509ALIASLENGTH
    If pCode = ..#X509ALIASSHAPE Quit ..#REASONX509ALIASSHAPE
    If pCode = ..#X509ALIASTAKEN Quit ..#REASONX509ALIASTAKEN
    If pCode = ..#X509ALIASABSENT Quit ..#REASONX509ALIASABSENT
    If pCode = ..#X509CERTIFICATEREQUIRED Quit ..#REASONX509CERTIFICATEREQUIRED
    If pCode = ..#X509CERTIFICATESHAPE Quit ..#REASONX509CERTIFICATESHAPE
    If pCode = ..#X509CERTIFICATEEXPIRED Quit ..#REASONX509CERTIFICATEEXPIRED
    If pCode = ..#X509PRIVATEKEYSHAPE Quit ..#REASONX509PRIVATEKEYSHAPE
    If pCode = ..#X509PRIVATEKEYMISMATCH Quit ..#REASONX509PRIVATEKEYMISMATCH
    If pCode = ..#X509PRIVATEKEYPASSWORDWRONG Quit ..#REASONX509PRIVATEKEYPASSWORDWRONG
    If pCode = ..#X509PRIVATEKEYPASSWORDWITHOUTKEY Quit ..#REASONX509PRIVATEKEYPASSWORDWITHOUTKEY
    If pCode = ..#X509PRIVATEKEYPASSWORDLENGTH Quit ..#REASONX509PRIVATEKEYPASSWORDLENGTH
    If pCode = ..#WALLETNAMEREQUIRED Quit ..#REASONWALLETNAMEREQUIRED
    If pCode = ..#WALLETNAMESHAPE Quit ..#REASONWALLETNAMESHAPE
    If pCode = ..#WALLETNAMELENGTH Quit ..#REASONWALLETNAMELENGTH
    If pCode = ..#WALLETNAMETAKEN Quit ..#REASONWALLETNAMETAKEN
    If pCode = ..#WALLETNAMEABSENT Quit ..#REASONWALLETNAMEABSENT
    If pCode = ..#WALLETCOLLECTIONABSENT Quit ..#REASONWALLETCOLLECTIONABSENT
    If pCode = ..#WALLETSECRETREQUIRED Quit ..#REASONWALLETSECRETREQUIRED
    If pCode = ..#WALLETSECRETLENGTH Quit ..#REASONWALLETSECRETLENGTH
    If pCode = ..#WALLETUSAGERANGE Quit ..#REASONWALLETUSAGERANGE
    If pCode = ..#WALLETALLOWEDHOSTSSHAPE Quit ..#REASONWALLETALLOWEDHOSTSSHAPE
    If pCode = ..#WALLETTYPEUNSUPPORTED Quit ..#REASONWALLETTYPEUNSUPPORTED
    If pCode = ..#DEVICENAMEREQUIRED Quit ..#REASONDEVICENAMEREQUIRED
    If pCode = ..#DEVICENAMELENGTH Quit ..#REASONDEVICENAMELENGTH
    If pCode = ..#DEVICENAMESHAPE Quit ..#REASONDEVICENAMESHAPE
    If pCode = ..#DEVICENAMETAKEN Quit ..#REASONDEVICENAMETAKEN
    If pCode = ..#DEVICENAMEABSENT Quit ..#REASONDEVICENAMEABSENT
    If pCode = ..#DEVICEPHYSICALDEVICEREQUIRED Quit ..#REASONDEVICEPHYSICALDEVICEREQUIRED
    If pCode = ..#DEVICEPHYSICALDEVICELENGTH Quit ..#REASONDEVICEPHYSICALDEVICELENGTH
    If pCode = ..#DEVICEPHYSICALDEVICESHAPE Quit ..#REASONDEVICEPHYSICALDEVICESHAPE
    If pCode = ..#DEVICETYPEREQUIRED Quit ..#REASONDEVICETYPEREQUIRED
    If pCode = ..#DEVICETYPEVALUE Quit ..#REASONDEVICETYPEVALUE
    If pCode = ..#DEVICESUBTYPEREQUIRED Quit ..#REASONDEVICESUBTYPEREQUIRED
    If pCode = ..#DEVICESUBTYPEABSENT Quit ..#REASONDEVICESUBTYPEABSENT
    If pCode = ..#DEVICEOPENPARAMETERSLENGTH Quit ..#REASONDEVICEOPENPARAMETERSLENGTH
    If pCode = ..#DEVICEOPENPARAMETERSSHAPE Quit ..#REASONDEVICEOPENPARAMETERSSHAPE
    If pCode = ..#DEVICEDESCRIPTIONLENGTH Quit ..#REASONDEVICEDESCRIPTIONLENGTH
    If pCode = ..#DEVICEDESCRIPTIONSHAPE Quit ..#REASONDEVICEDESCRIPTIONSHAPE
    If pCode = ..#DEVICEALTERNATEDEVICELENGTH Quit ..#REASONDEVICEALTERNATEDEVICELENGTH
    If pCode = ..#DEVICEALTERNATEDEVICESHAPE Quit ..#REASONDEVICEALTERNATEDEVICESHAPE
    If pCode = ..#DEVICEALIASSHAPE Quit ..#REASONDEVICEALIASSHAPE
    If pCode = ..#DEVICEALIASTAKEN Quit ..#REASONDEVICEALIASTAKEN
    If pCode = ..#DEVICEALIASSAME Quit ..#REASONDEVICEALIASSAME
    If pCode = ..#DEVICEPROMPTVALUE Quit ..#REASONDEVICEPROMPTVALUE
    If pCode = ..#PORTFIELDREQUIRED Quit ..#REASONPORTFIELDREQUIRED
    If pCode = ..#PORTFIELDUNEXPECTED Quit ..#REASONPORTFIELDUNEXPECTED
    If pCode = ..#PORTFIELDSHAPE Quit ..#REASONPORTFIELDSHAPE
    If pCode = ..#ROLEESCALATIONONLYSHAPE Quit ..#REASONROLEESCALATIONONLYSHAPE
    If $Extract(pCode, 1, 4) = "SSL." Quit ..ReasonForSsl(pCode)
    If $Extract(pCode, 1, 5) = "TASK." Quit ..ReasonForTask(pCode)
    If $Extract(pCode, 1, 8) = "SERVICE." Quit ..ReasonForService(pCode)
    If $Extract(pCode, 1, 5) = "LDAP." Quit ..ReasonForLdap(pCode)
    If $Extract(pCode, 1, 11) = "AUDITEVENT." Quit ..ReasonForAuditEvent(pCode)
    Quit ""
}

/// <p>Every <code>WEBAPP.*</code> and <code>PORT.FIELD.*</code> field-level violation code, as a
/// <class>%List</class>, for the reason <method>ViolationCodes</method> exists: a test holds
/// <method>ReasonForViolation</method> to the vocabulary without re-spelling either, so a code
/// added with no sentence behind it reddens.</p>
ClassMethod WebAppViolationCodes() As %List
{
    Quit $ListBuild(..#WEBAPPNAMEREQUIRED, ..#WEBAPPNAMESHAPE, ..#WEBAPPNAMETAKEN, ..#WEBAPPNAMESPACEREQUIRED, ..#WEBAPPAUTHEREQUIRED, ..#WEBAPPAUTHEUNKNOWN, ..#WEBAPPDISPATCHREQUIRED, ..#WEBAPPWSGIAPPNAME, ..#WEBAPPWSGILOCATION, ..#WEBAPPWSGITYPE, ..#WEBAPPTYPECONFLICT, ..#WEBAPPFIELDLENGTH, ..#WEBAPPWSGIAPPLOCATIONSHAPE, ..#WEBAPPMATCHROLESSHAPE, ..#WEBAPPMATCHROLESUNKNOWN, ..#PORTFIELDREQUIRED, ..#PORTFIELDUNEXPECTED, ..#PORTFIELDSHAPE)
}

/// <p>Every <code>USER.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>WebAppViolationCodes</method> exists: a test holds
/// <method>ReasonForViolation</method> to the vocabulary, so a code added with no sentence behind
/// it reddens.</p>
ClassMethod UserViolationCodes() As %List
{
    Quit $ListBuild(..#USERNAMEREQUIRED, ..#USERNAMESHAPE, ..#USERNAMETAKEN, ..#USERPASSWORDREQUIRED, ..#USERPASSWORDPOLICY, ..#USERFULLNAMELENGTH, ..#USEREXPIRATIONDATESHAPE, ..#USERNAMESPACEUNKNOWN, ..#USERROUTINENAMESPACE, ..#USERROUTINELENGTH, ..#USERROLESUNKNOWN, ..#USERROLESSHAPE, ..#USERCOMMENTLENGTH, ..#USEREMAILADDRESSLENGTH, ..#USERPHONENUMBERLENGTH, ..#USERPHONEPROVIDERLENGTH, ..#USERTWOFACTORBOTH, ..#USERAUTHEENABLEDSCOPE)
}

/// <p>Every <code>ROLE.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod RoleViolationCodes() As %List
{
    Quit $ListBuild(..#ROLENAMEREQUIRED, ..#ROLENAMELENGTH, ..#ROLENAMESHAPE, ..#ROLENAMETAKEN, ..#ROLENAMESYSTEM, ..#ROLEDESCRIPTIONLENGTH, ..#ROLERESOURCESSHAPE, ..#ROLERESOURCESUNKNOWN, ..#ROLERESOURCESPERMISSIONS, ..#ROLERESOURCESDUPLICATE, ..#ROLERESOURCESWRITEONLY, ..#ROLEGRANTEDROLESSHAPE, ..#ROLEGRANTEDROLESUNKNOWN, ..#ROLEESCALATIONONLYSHAPE)
}

/// <p>Every <code>RESOURCE.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod ResourceViolationCodes() As %List
{
    Quit $ListBuild(..#RESOURCENAMEREQUIRED, ..#RESOURCENAMELENGTH, ..#RESOURCENAMESHAPE, ..#RESOURCENAMETAKEN, ..#RESOURCENAMESYSTEM, ..#RESOURCENAMEABSENT, ..#RESOURCEDESCRIPTIONLENGTH, ..#RESOURCEPUBLICPERMISSIONSHAPE, ..#RESOURCEPUBLICPERMISSIONLETTERS)
}

/// <p>Every <code>X509.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod X509ViolationCodes() As %List
{
    Quit $ListBuild(..#X509ALIASREQUIRED, ..#X509ALIASLENGTH, ..#X509ALIASSHAPE, ..#X509ALIASTAKEN, ..#X509ALIASABSENT, ..#X509CERTIFICATEREQUIRED, ..#X509CERTIFICATESHAPE, ..#X509CERTIFICATEEXPIRED, ..#X509PRIVATEKEYSHAPE, ..#X509PRIVATEKEYMISMATCH, ..#X509PRIVATEKEYPASSWORDWRONG, ..#X509PRIVATEKEYPASSWORDWITHOUTKEY, ..#X509PRIVATEKEYPASSWORDLENGTH)
}

/// <p>Every <code>WALLET.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod WalletViolationCodes() As %List
{
    Quit $ListBuild(..#WALLETNAMEREQUIRED, ..#WALLETNAMESHAPE, ..#WALLETNAMELENGTH, ..#WALLETNAMETAKEN, ..#WALLETNAMEABSENT, ..#WALLETCOLLECTIONABSENT, ..#WALLETSECRETREQUIRED, ..#WALLETSECRETLENGTH, ..#WALLETUSAGERANGE, ..#WALLETALLOWEDHOSTSSHAPE, ..#WALLETTYPEUNSUPPORTED)
}

/// <p>Every <code>DEVICE.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod DeviceViolationCodes() As %List
{
    Quit $ListBuild(..#DEVICENAMEREQUIRED, ..#DEVICENAMELENGTH, ..#DEVICENAMESHAPE, ..#DEVICENAMETAKEN, ..#DEVICENAMEABSENT, ..#DEVICEPHYSICALDEVICEREQUIRED, ..#DEVICEPHYSICALDEVICELENGTH, ..#DEVICEPHYSICALDEVICESHAPE, ..#DEVICETYPEREQUIRED, ..#DEVICETYPEVALUE, ..#DEVICESUBTYPEREQUIRED, ..#DEVICESUBTYPEABSENT, ..#DEVICEOPENPARAMETERSLENGTH, ..#DEVICEOPENPARAMETERSSHAPE, ..#DEVICEDESCRIPTIONLENGTH, ..#DEVICEDESCRIPTIONSHAPE, ..#DEVICEALTERNATEDEVICELENGTH, ..#DEVICEALTERNATEDEVICESHAPE, ..#DEVICEALIASSHAPE, ..#DEVICEALIASTAKEN, ..#DEVICEALIASSAME, ..#DEVICEPROMPTVALUE)
}

/// <p>Every <code>AGENT.*</code> field-level violation code that carries a sentence, as a
/// <class>%List</class>. Exists so a test can hold <method>ReasonForViolation</method> to the code
/// vocabulary without re-spelling either, which is what catches a code added with no sentence
/// behind it. The list is <code>AGENT.*</code> only because its test sweeps that prefix; the two
/// <code>ACCOUNT.*</code> field codes are held instead by
/// <class>OcuPilot.Test.AccountPasswordWire</class>, which asserts each sentence over the wire.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#AGENTNAMEREQUIRED, ..#AGENTNAMEDUPLICATE, ..#AGENTPROVIDERUNKNOWN, ..#AGENTMAXTOKENSRANGE, ..#AGENTTEMPERATURERANGE, ..#AGENTCREDTYPEUNKNOWN, ..#AGENTCREDTYPEUNAVAILABLE, ..#AGENTENVVARREQUIRED, ..#AGENTCREDNAMEREQUIRED, ..#AGENTCREDNAMELENGTH, ..#AGENTENDPOINTREQUIRED, ..#AGENTENDPOINTSCHEME, ..#AGENTENDPOINTADDRESS, ..#AGENTENDPOINTLINKLOCAL, ..#AGENTHTTPACKREQUIRED, ..#AGENTLOCALUNSUPPORTED, ..#AGENTSYSTEMPROMPTLENGTH, ..#AGENTRETENTIONRANGE, ..#AGENTITERATIONSRANGE, ..#AGENTENABLEUNVERIFIED, ..#AGENTDEFAULTDISABLED, ..#AGENTCREDENTIALREQUIRED, ..#AGENTCREDENTIALENVUNWRITABLE, ..#AGENTCREDENTIALRUNGUNAVAILABLE, ..#AGENTKEYSHAPE, ..#AGENTCREDENTIALNOTOWNED, ..#AGENTCREDENTIALNOPRIVILEGE, ..#AGENTSWITCHREASONREQUIRED, ..#AGENTSWITCHCONTEXTROWCAP, ..#AGENTHOLDUSERREQUIRED, ..#AGENTHOLDREASONREQUIRED, ..#AGENTHOLDDUPLICATE)
}

/// <p>Refusal sentence for <parameter>AGENTNAMEREQUIRED</parameter>.</p>
Parameter REASONAGENTNAMEREQUIRED = "Give the definition a name of 1 to 64 characters.";

/// <p>Refusal sentence for <parameter>AGENTNAMEDUPLICATE</parameter>.</p>
Parameter REASONAGENTNAMEDUPLICATE = "Another agent definition already carries that name. Choose a different one.";

/// <p>Refusal sentence for <parameter>AGENTPROVIDERUNKNOWN</parameter>.</p>
Parameter REASONAGENTPROVIDERUNKNOWN = "That provider is not one this instance offers. Choose one from the list.";

/// <p>Refusal sentence for <parameter>AGENTMAXTOKENSRANGE</parameter>.</p>
Parameter REASONAGENTMAXTOKENSRANGE = "Maximum tokens is a whole number from 1 to 32000.";

/// <p>Refusal sentence for <parameter>AGENTTEMPERATURERANGE</parameter>.</p>
Parameter REASONAGENTTEMPERATURERANGE = "Temperature is a number from 0 to 2.";

/// <p>Refusal sentence for <parameter>AGENTCREDTYPEUNKNOWN</parameter>.</p>
Parameter REASONAGENTCREDTYPEUNKNOWN = "Choose where the key is read from: an environment variable, or a credential entry.";

/// <p>Refusal sentence for <parameter>AGENTCREDTYPEUNAVAILABLE</parameter>.</p>
Parameter REASONAGENTCREDTYPEUNAVAILABLE = "The credential store is not available in this namespace. Read the key from an environment variable instead.";

/// <p>Refusal sentence for <parameter>AGENTENVVARREQUIRED</parameter>.</p>
Parameter REASONAGENTENVVARREQUIRED = "Name the environment variable the key is read from.";

/// <p>Refusal sentence for <parameter>AGENTCREDNAMEREQUIRED</parameter>.</p>
Parameter REASONAGENTCREDNAMEREQUIRED = "Name the credential entry the key is stored in.";

/// <p>Refusal sentence for <parameter>AGENTCREDNAMELENGTH</parameter>. The bound is appended by
/// the rule that produces it, so the number is declared once, where it is measured.</p>
Parameter REASONAGENTCREDNAMELENGTH = "That credential entry name is longer than the credential store accepts";

/// <p>Refusal sentence for <parameter>AGENTENDPOINTREQUIRED</parameter>.</p>
Parameter REASONAGENTENDPOINTREQUIRED = "This provider needs an endpoint. Enter the address its API is served at.";

/// <p>Refusal sentence for <parameter>AGENTENDPOINTSCHEME</parameter>.</p>
Parameter REASONAGENTENDPOINTSCHEME = "The endpoint is an absolute https:// address with no user name in it.";

/// <p>Refusal sentence for <parameter>AGENTENDPOINTADDRESS</parameter>.</p>
Parameter REASONAGENTENDPOINTADDRESS = "That endpoint resolves to this instance or to a loopback address, which OcuPilot will not call.";

/// <p>Refusal sentence for <parameter>AGENTENDPOINTLINKLOCAL</parameter>.</p>
Parameter REASONAGENTENDPOINTLINKLOCAL = "That endpoint resolves to a link-local or cloud instance-metadata address, which OcuPilot never calls.";

/// <p>Refusal sentence for <parameter>AGENTHTTPACKREQUIRED</parameter>.</p>
Parameter REASONAGENTHTTPACKREQUIRED = "This endpoint is not encrypted, so the key travels across the network in clear; acknowledge that to save it.";

/// <p>Refusal sentence for <parameter>AGENTLOCALUNSUPPORTED</parameter>.</p>
Parameter REASONAGENTLOCALUNSUPPORTED = "This provider serves no local model, so the definition cannot be marked local.";

/// <p>Refusal sentence for <parameter>AGENTSYSTEMPROMPTLENGTH</parameter>.</p>
Parameter REASONAGENTSYSTEMPROMPTLENGTH = "The system prompt override is 8192 characters or fewer.";

/// <p>Refusal sentence for <parameter>AGENTRETENTIONRANGE</parameter>.</p>
Parameter REASONAGENTRETENTIONRANGE = "Retention is a whole number of days from 1 to 365.";

/// <p>Refusal sentence for <parameter>AGENTITERATIONSRANGE</parameter>.</p>
Parameter REASONAGENTITERATIONSRANGE = "Maximum iterations is a whole number from 1 to 100.";

/// <p>Refusal sentence for <parameter>AGENTENABLEUNVERIFIED</parameter>.</p>
Parameter REASONAGENTENABLEUNVERIFIED = "Run Test connection and let it pass before enabling this definition.";

/// <p>Refusal sentence for <parameter>AGENTDEFAULTDISABLED</parameter>.</p>
Parameter REASONAGENTDEFAULTDISABLED = "Enable this definition before making it the default.";

/// <p>Refusal sentence for <parameter>AGENTCREDENTIALREQUIRED</parameter>.</p>
Parameter REASONAGENTCREDENTIALREQUIRED = "Paste the API key before storing it.";

/// <p>Refusal sentence for <parameter>AGENTCREDENTIALENVUNWRITABLE</parameter>.</p>
Parameter REASONAGENTCREDENTIALENVUNWRITABLE = "This definition reads its key from an environment variable, which an operator sets on the host; OcuPilot cannot write one.";

/// <p>Refusal sentence for <parameter>AGENTCREDENTIALRUNGUNAVAILABLE</parameter>.</p>
Parameter REASONAGENTCREDENTIALRUNGUNAVAILABLE = "The credential store is not available in this namespace, so there is nowhere to put the key.";

/// <p>Refusal sentence for <parameter>AGENTKEYSHAPE</parameter>. The expected prefix is appended
/// by the refusal that produces it, from the provider's own catalog row.</p>
Parameter REASONAGENTKEYSHAPE = "That key is not shaped like a key for this provider";

/// <p>Refusal sentence for <parameter>AGENTCREDENTIALNOTOWNED</parameter>.</p>
Parameter REASONAGENTCREDENTIALNOTOWNED = "OcuPilot did not create this credential entry, so it will not overwrite it. Choose an unused reference, or change the entry where it was created.";

/// <p>Refusal sentence for <parameter>AGENTCREDENTIALNOPRIVILEGE</parameter>, naming the first pair
/// the store needs. <method>ReasonForCredentialPrivilege</method> names whichever pair failed.</p>
Parameter REASONAGENTCREDENTIALNOPRIVILEGE = "Storing a key needs %Ens_Credentials:WRITE, which this account does not hold. Ask an administrator to grant it.";

/// <p>The <parameter>AGENTCREDENTIALNOPRIVILEGE</parameter> sentence naming <var>pPair</var>, the
/// <code>resource:permission</code> pair that failed (AD-8): the one sentence, with
/// <var>pPair</var> in place of the pair it is written with. An empty <var>pPair</var> answers the
/// sentence as written.</p>
ClassMethod ReasonForCredentialPrivilege(pPair As %String = "") As %String
{
    If pPair = "" Quit ..#REASONAGENTCREDENTIALNOPRIVILEGE
    Quit $Replace(..#REASONAGENTCREDENTIALNOPRIVILEGE, "%Ens_Credentials:WRITE", pPair)
}

/// <p>Refusal sentence for <parameter>AGENTSWITCHREASONREQUIRED</parameter>.</p>
Parameter REASONAGENTSWITCHREASONREQUIRED = "Give a reason for switching the agent off. Everyone it affects is shown it.";

/// <p>Refusal sentence for <parameter>AGENTSWITCHCONTEXTROWCAP</parameter>.</p>
Parameter REASONAGENTSWITCHCONTEXTROWCAP = "Context rows sent with a turn is a whole number from 1 to 1,000.";

/// <p>Refusal sentence for <parameter>AGENTHOLDUSERREQUIRED</parameter>.</p>
Parameter REASONAGENTHOLDUSERREQUIRED = "Name the user the agent is switched off for.";

/// <p>Refusal sentence for <parameter>AGENTHOLDREASONREQUIRED</parameter>.</p>
Parameter REASONAGENTHOLDREASONREQUIRED = "Give a reason for switching the agent off for that user. They are shown it.";

/// <p>Refusal sentence for <parameter>AGENTHOLDDUPLICATE</parameter>.</p>
Parameter REASONAGENTHOLDDUPLICATE = "The agent is already switched off for that user.";

/// <p>Machine code (Story 15.1, AD-49): the caller's own password change was refused on a field.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug by
/// <class>OcuPilot.Api.Account</class>, with the field-level codes below in
/// <code>detail.violations</code>. <code>ACCOUNT.*</code> rather than <code>AGENT.*</code>
/// because a self-service account action is outside the agent write path.</p>
Parameter ACCOUNTVALIDATION = "ACCOUNT.VALIDATION";

/// <p>The envelope's <code>reason</code> for <parameter>ACCOUNTVALIDATION</parameter>. Generic,
/// like every validation envelope's: it stands for the list of violations beside it.</p>
Parameter REASONACCOUNTVALIDATION = "The password change was refused.";

/// <p>Violation code (Story 15.1): the current password the caller sent is not this account's.
/// Produced on the field <code>currentPassword</code>.</p>
/// <p>It never distinguishes a wrong password from an account that does not exist -- the change
/// runs as <code>$Username</code>, so the account is always the caller's own, and one code for
/// both is what keeps the refusal from answering a question nobody asked.</p>
Parameter ACCOUNTPASSWORDCURRENT = "ACCOUNT.PASSWORD.CURRENT";

/// <p>Refusal sentence for <parameter>ACCOUNTPASSWORDCURRENT</parameter>.</p>
Parameter REASONACCOUNTPASSWORDCURRENT = "That is not the current password for this account. Enter it again.";

/// <p>Violation code (Story 15.1): the new password does not satisfy this instance's own password
/// policy. Produced on the field <code>newPassword</code>.</p>
/// <p>Its <code>reason</code> is <b>the instance's own text</b>, passed through from the one
/// allow-listed embedded status, because the policy is the operator's and OcuPilot cannot restate
/// a rule it does not hold. The sentence below is the fallback for a refusal that names none.</p>
Parameter ACCOUNTPASSWORDPOLICY = "ACCOUNT.PASSWORD.POLICY";

/// <p>Refusal sentence for <parameter>ACCOUNTPASSWORDPOLICY</parameter>.</p>
Parameter REASONACCOUNTPASSWORDPOLICY = "The new password does not meet this instance's password policy.";

/// <p>Machine code (Story 15.1): the password-change body is not exactly the two string members
/// the route accepts. Rendered on the <parameter>VALIDATIONFAILED</parameter> slug with
/// <parameter>REASONACCOUNTPASSWORDBODY</parameter> alone and no <code>detail</code>.</p>
Parameter ACCOUNTPASSWORDBODY = "ACCOUNT.PASSWORD.BODY";

/// <p>The envelope's <code>reason</code> for <parameter>ACCOUNTPASSWORDBODY</parameter>. It names
/// the two members and never a value the caller sent (AD-35).</p>
Parameter REASONACCOUNTPASSWORDBODY = "The body must carry exactly two members, the strings currentPassword and newPassword.";

/// <p>Machine code (Story 15.2, AD-50): the preferences body is not the members the route
/// accepts. Rendered on the <parameter>VALIDATIONFAILED</parameter> slug with
/// <parameter>REASONPREFERENCESBODY</parameter> alone and no <code>detail</code>, because no field
/// was reached.</p>
Parameter PREFERENCESBODY = "PREFERENCES.BODY";

/// <p>The envelope's <code>reason</code> for <parameter>PREFERENCESBODY</parameter>. It names the
/// members and their vocabularies, never a value the caller sent.</p>
Parameter REASONPREFERENCESBODY = "The body must carry the strings kind (favorite, recent, view, refresh or shell) and action (add or remove for a list, set for a remembered value, clear for either); route names the screen, name names the shell member, and value is carried by a set alone.";

/// <p>Machine code (Story 15.2): the submitted route is not a built screen's route, or is longer
/// than <parameter>OcuPilot.Kernel.State.Base.ROUTEMAXLENGTH</parameter>. Rendered on the
/// <parameter>VALIDATIONFAILED</parameter> slug with one violation on <code>route</code>.</p>
Parameter PREFERENCESROUTE = "PREFERENCES.ROUTE";

/// <p>Refusal sentence for <parameter>PREFERENCESROUTE</parameter>.</p>
Parameter REASONPREFERENCESROUTE = "That is not a screen this instance serves, so it cannot be remembered.";

/// <p>Machine code (Story 15.2): the caller already holds as many favorites as the instance keeps,
/// so another cannot be added. Rendered on the <parameter>VALIDATIONFAILED</parameter> slug with
/// one violation on <code>route</code>.</p>
Parameter PREFERENCESLIMIT = "PREFERENCES.LIMIT";

/// <p>Refusal sentence for <parameter>PREFERENCESLIMIT</parameter>. It names no number: the bound
/// is <parameter>OcuPilot.Kernel.State.Pref.FAVORITEMAX</parameter>, declared once where it is
/// enforced, and a sentence carrying a second copy of it is a second thing to keep equal.</p>
Parameter REASONPREFERENCESLIMIT = "This account already holds as many favorites as the instance keeps. Remove one before adding another.";

/// <p>Machine code (Story 15.3): the <code>route</code> the help read was asked for is not a route
/// the screen registry's roster carries, or is longer than
/// <parameter>OcuPilot.Kernel.State.Base.ROUTEMAXLENGTH</parameter>. Rendered on the
/// <parameter>VALIDATIONFAILED</parameter> slug with one violation on <code>route</code>.</p>
Parameter HELPROUTE = "HELP.ROUTE";

/// <p>Refusal sentence for <parameter>HELPROUTE</parameter>. It names no route the caller sent.</p>
Parameter REASONHELPROUTE = "That is not a screen this instance serves, so there is no help address for it.";

/// <p>Machine code (Story 15.5, AD-50): a preference write carried no usable <code>value</code> --
/// absent, empty, or longer than
/// <parameter>OcuPilot.Kernel.State.Pref.VALUEMAXLENGTH</parameter>. Rendered on the
/// <parameter>VALIDATIONFAILED</parameter> slug with one violation on <code>value</code>.</p>
/// <p>An empty one is refused rather than stored because IRIS stores an empty <code>%String</code>
/// as SQL <code>NULL</code>, which the key look-up never matches again.</p>
Parameter PREFERENCESVALUE = "PREFERENCES.VALUE";

/// <p>Refusal sentence for <parameter>PREFERENCESVALUE</parameter>. It names no number and no
/// value the caller sent: the bound is declared once where it is enforced.</p>
Parameter REASONPREFERENCESVALUE = "That preference needs a value, and one short enough for the instance to keep.";

/// <p>Machine code (Story 15.5, AD-50): the <code>name</code> a shell preference write carried is
/// outside the closed set <method>OcuPilot.Kernel.State.Pref.IsShellMember</method> answers.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug with one violation on
/// <code>name</code>.</p>
Parameter PREFERENCESNAME = "PREFERENCES.NAME";

/// <p>Refusal sentence for <parameter>PREFERENCESNAME</parameter>. It names no value the caller
/// sent (AD-35).</p>
Parameter REASONPREFERENCESNAME = "That is not a piece of shell state this instance remembers.";

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

/// <p>Machine code (AD-12, AD-39): the request to create a web application broke one or more of
/// the rules <class>OcuPilot.Area.WebApp.Create</class> applies before the port is touched.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug, with every violation as a
/// <code>{field, code, reason}</code> entry in the envelope's <code>detail.violations</code> --
/// one response for a submission that breaks four rules, never four responses (AD-39).</p>
Parameter WEBAPPVALIDATION = "WEBAPP.VALIDATION";

/// <p>The envelope's <code>reason</code> for <parameter>WEBAPPVALIDATION</parameter>, which the
/// screen renders only where no violation named a field.</p>
Parameter REASONWEBAPPVALIDATION = "The web application was refused.";

/// <p>Violation code: no name was supplied. A web application is identified by the URL path it
/// answers at, and that path is the vendor's <code>name</code> query parameter rather than a body
/// field, so an absent one is refused here rather than by the endpoint.</p>
Parameter WEBAPPNAMEREQUIRED = "WEBAPP.NAME.REQUIRED";

Parameter REASONWEBAPPNAMEREQUIRED = "Give the application the URL path it answers at, such as /csp/myapp.";

/// <p>Violation code: the name is not a path this instance can serve. Checked before the port so
/// the sentence names the field rather than arriving as a vendor status about an internal class.</p>
Parameter WEBAPPNAMESHAPE = "WEBAPP.NAME.SHAPE";

Parameter REASONWEBAPPNAMESHAPE = "An application name starts with / and is at most 64 characters, with no space and no percent sign.";

/// <p>Violation code: a web application already answers that name. It is a <b>read</b> rather than
/// a validation -- <code>GET /web-applications/name</code> answers the same question on blur -- and
/// it matters more than the rest, because the vendor's own PUT is an upsert (AD-54).</p>
Parameter WEBAPPNAMETAKEN = "WEBAPP.NAME.TAKEN";

Parameter REASONWEBAPPNAMETAKEN = "This instance already has a web application with that name. Choose a different one.";

/// <p>Violation code: no namespace was supplied. <method>%Api.Admin.Endpoints.WebApp.App.ValidateRequest</method>
/// adds <code>NameSpace</code> to its required set only when the application does not already
/// exist, so this is the create path's own rule and OcuPilot states it on the field.</p>
Parameter WEBAPPNAMESPACEREQUIRED = "WEBAPP.NAMESPACE.REQUIRED";

Parameter REASONWEBAPPNAMESPACEREQUIRED = "Choose the namespace this application runs in.";

/// <p>Violation code: no authentication method was chosen.
/// <property>Security.Applications.AutheEnabled</property> carries
/// <code>InitialExpression = 64</code> (Unauthenticated), so an omitted value would create an
/// application anyone can reach without signing in. The field is always sent explicitly and an
/// empty one is refused.</p>
Parameter WEBAPPAUTHEREQUIRED = "WEBAPP.AUTHE.REQUIRED";

Parameter REASONWEBAPPAUTHEREQUIRED = "Choose at least one authentication method. An application with none is reachable without signing in.";

/// <p>Violation code: the value carries a bit outside the ones this instance itself has enabled
/// for a web application (<method>OcuPilot.Area.WebApp.FormRules.Methods</method>).</p>
Parameter WEBAPPAUTHEUNKNOWN = "WEBAPP.AUTHE.UNKNOWN";

Parameter REASONWEBAPPAUTHEUNKNOWN = "That authentication method is not one this instance offers for a web application.";

/// <p>Violation code: a REST application names no dispatch class. The vendor accepts the
/// combination and serves nothing at the address, which is why the rule is OcuPilot's.</p>
Parameter WEBAPPDISPATCHREQUIRED = "WEBAPP.DISPATCH.REQUIRED";

Parameter REASONWEBAPPDISPATCHREQUIRED = "A REST application names the class that answers its requests.";

/// <p>Violation code: a WSGI or ASGI application names no callable file.</p>
Parameter WEBAPPWSGIAPPNAME = "WEBAPP.WSGI.APPNAME";

Parameter REASONWEBAPPWSGIAPPNAME = "A WSGI or ASGI application names the file that holds its callable.";

/// <p>Violation code: a WSGI or ASGI application names no directory. It is also what
/// <method>OcuPilot.Screen.Tool.WebAppCreate.DerivedFields</method> derives the physical path
/// from, so an empty one would leave the application serving from nowhere.</p>
Parameter WEBAPPWSGILOCATION = "WEBAPP.WSGI.LOCATION";

Parameter REASONWEBAPPWSGILOCATION = "A WSGI or ASGI application names the directory its application is in.";

/// <p>Violation code: the Python protocol type is neither of the two
/// <property>Security.Applications.WSGIType</property> publishes. It travels as its display string
/// because the endpoint runs <code>WSGITypeDisplayToLogical</code> over it.</p>
Parameter WEBAPPWSGITYPE = "WEBAPP.WSGI.TYPE";

Parameter REASONWEBAPPWSGITYPE = "The Python protocol type is WSGI or ASGI.";

/// <p>Violation code: the body names both a dispatch class and the fields of a Python callable.
/// An application answers one way or the other, and the vendor's own editor expresses that as one
/// radio group rather than as two independent sets of fields.</p>
Parameter WEBAPPTYPECONFLICT = "WEBAPP.TYPE.CONFLICT";

Parameter REASONWEBAPPTYPECONFLICT = "An application is either a REST application with a dispatch class or a Python application with a callable, not both.";

/// <p>Violation code: the value is longer than the instance stores for that field. The bound is
/// the property's own <code>MAXLEN</code>, served to the form by
/// <method>OcuPilot.Area.WebApp.FormRules.Lengths</method> so the sentence and the control agree.</p>
Parameter WEBAPPFIELDLENGTH = "WEBAPP.FIELD.LENGTH";

Parameter REASONWEBAPPFIELDLENGTH = "That value is longer than this instance stores for the field.";

/// <p>Violation code: a WSGI or ASGI application's directory is not one directory name that
/// resolves under this instance's own WSGI root (AD-21, <class>OcuPilot.Area.WebApp.Location</class>).
/// A path, a <code>..</code> and a name outside the pattern are each refused rather than sent.</p>
Parameter WEBAPPWSGIAPPLOCATIONSHAPE = "WEBAPP.WSGIAPPLOCATION.SHAPE";

Parameter REASONWEBAPPWSGIAPPLOCATIONSHAPE = "Name one directory of letters, digits, dots, dashes and underscores, at most 64 characters; it is placed in this instance's own WSGI directory. Any other location is set in the classic portal.";

/// <p>Violation code: the application roles are not a list of <code>{MatchRole, TargetRoles}</code>
/// entries, each a matching role (empty for every request) and a list of role names.</p>
Parameter WEBAPPMATCHROLESSHAPE = "WEBAPP.MATCHROLES.SHAPE";

Parameter REASONWEBAPPMATCHROLESSHAPE = "Each application-role entry names a matching role, or none, and the roles it grants.";

/// <p>Violation code: an application-role entry names a role this instance does not hold.</p>
Parameter WEBAPPMATCHROLESUNKNOWN = "WEBAPP.MATCHROLES.UNKNOWN";

Parameter REASONWEBAPPMATCHROLESUNKNOWN = "One of those roles does not exist on this instance.";

/// <p>Machine code (AD-12, AD-39): the request to create a user broke one or more of the rules
/// <class>OcuPilot.Area.Permissions.UserCreateRules</class> applies before the port is touched.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug with every violation in
/// <code>detail.violations</code>, the shape <parameter>WEBAPPVALIDATION</parameter> takes.</p>
Parameter USERVALIDATION = "USER.VALIDATION";

/// <p>The envelope's <code>reason</code> for <parameter>USERVALIDATION</parameter>, which the
/// screen renders only where no violation named a field.</p>
Parameter REASONUSERVALIDATION = "The user was refused.";

/// <p>Violation code: no name was supplied. A user's name is the vendor's <code>name</code> query
/// parameter rather than a body field.</p>
Parameter USERNAMEREQUIRED = "USER.NAME.REQUIRED";

Parameter REASONUSERNAMEREQUIRED = "Give the account a name.";

/// <p>Violation code: the name is not one this instance can hold -- longer than
/// <class>%Library.Username</class> stores, or carrying a control character, a <code>*</code> or an
/// <code>@</code>.</p>
Parameter USERNAMESHAPE = "USER.NAME.SHAPE";

Parameter REASONUSERNAMESHAPE = "A user name is at most 160 characters, with no control character, no * and no @ sign.";

/// <p>Violation code: an account already carries that name. <class>Security.Users</class> keys on
/// the lower-cased name, so a name taken in any case is taken. A read rather than a validation --
/// <code>GET /users/name</code> answers it on blur.</p>
Parameter USERNAMETAKEN = "USER.NAME.TAKEN";

Parameter REASONUSERNAMETAKEN = "This instance already has a user with that name. Choose a different one.";

/// <p>Violation code: no password was supplied. The vendor's create requires one.</p>
Parameter USERPASSWORDREQUIRED = "USER.PASSWORD.REQUIRED";

Parameter REASONUSERPASSWORDREQUIRED = "Give the account a password.";

/// <p>Violation code: the password does not match <property>Security.System.PasswordPattern</property>.
/// The sentence names the policy, never the value (AD-35).</p>
Parameter USERPASSWORDPOLICY = "USER.PASSWORD.POLICY";

Parameter REASONUSERPASSWORDPOLICY = "The password does not meet this instance's password policy.";

/// <p>Violation code: the full name is longer than <property>Security.Users.FullName</property>
/// stores.</p>
Parameter USERFULLNAMELENGTH = "USER.FULLNAME.LENGTH";

Parameter REASONUSERFULLNAMELENGTH = "That full name is longer than this instance stores.";

/// <p>Violation code: the expiration date is not a real date in the <code>YYYY-MM-DD</code> form
/// <property>Security.Users.ExpirationDate</property> is set from.</p>
Parameter USEREXPIRATIONDATESHAPE = "USER.EXPIRATIONDATE.SHAPE";

Parameter REASONUSEREXPIRATIONDATESHAPE = "An expiration date is a real date, written YYYY-MM-DD.";

/// <p>Violation code: the startup namespace is not a namespace this instance holds.</p>
Parameter USERNAMESPACEUNKNOWN = "USER.NAMESPACE.UNKNOWN";

Parameter REASONUSERNAMESPACEUNKNOWN = "That is not a namespace on this instance.";

/// <p>Violation code: a startup routine was named with no startup namespace to run it in.</p>
Parameter USERROUTINENAMESPACE = "USER.ROUTINE.NAMESPACE";

Parameter REASONUSERROUTINENAMESPACE = "A startup routine runs in a startup namespace, so choose one as well.";

/// <p>Violation code: the startup routine is longer than <property>Security.Users.Routine</property>
/// stores.</p>
Parameter USERROUTINELENGTH = "USER.ROUTINE.LENGTH";

Parameter REASONUSERROUTINELENGTH = "A startup tag^routine is at most 64 characters.";

/// <p>Violation code: a role named is not one this instance holds.
/// <method>Security.Users.Create</method> accepts an unknown role silently, so the rule is
/// OcuPilot's.</p>
Parameter USERROLESUNKNOWN = "USER.ROLES.UNKNOWN";

Parameter REASONUSERROLESUNKNOWN = "One of those roles does not exist on this instance.";

/// <p>Violation code: the roles are not a list of role names.</p>
Parameter USERROLESSHAPE = "USER.ROLES.SHAPE";

Parameter REASONUSERROLESSHAPE = "Roles are a list of role names.";

/// <p>Violation code: the comment is longer than <property>Security.Users.Comment</property>
/// stores.</p>
Parameter USERCOMMENTLENGTH = "USER.COMMENT.LENGTH";

Parameter REASONUSERCOMMENTLENGTH = "That comment is longer than this instance stores.";

/// <p>Violation code: the email address is longer than
/// <property>Security.Users.EmailAddress</property> stores.</p>
Parameter USEREMAILADDRESSLENGTH = "USER.EMAILADDRESS.LENGTH";

Parameter REASONUSEREMAILADDRESSLENGTH = "That email address is longer than this instance stores.";

/// <p>Violation code: the mobile phone number is longer than
/// <property>Security.Users.PhoneNumber</property> stores.</p>
Parameter USERPHONENUMBERLENGTH = "USER.PHONENUMBER.LENGTH";

Parameter REASONUSERPHONENUMBERLENGTH = "That phone number is longer than this instance stores.";

/// <p>Violation code: the mobile phone service provider is longer than
/// <property>Security.Users.PhoneProvider</property> stores.</p>
Parameter USERPHONEPROVIDERLENGTH = "USER.PHONEPROVIDER.LENGTH";

Parameter REASONUSERPHONEPROVIDERLENGTH = "That service provider name is longer than this instance stores.";

/// <p>Violation code: both two-factor methods are on, SMS text and a time-based one-time
/// password.</p>
Parameter USERTWOFACTORBOTH = "USER.TWOFACTOR.BOTH";

Parameter REASONUSERTWOFACTORBOTH = "Choose SMS text or a time-based one-time password for two-factor sign-in, not both.";

/// <p>Violation code: the change to <code>AutheEnabled</code> moves a bit other than the two
/// two-factor ones, or is not a whole number.</p>
Parameter USERAUTHEENABLEDSCOPE = "USER.AUTHEENABLED.SCOPE";

Parameter REASONUSERAUTHEENABLEDSCOPE = "Only the two-factor settings of how this account signs in can be changed here.";

/// <p>Machine code (AD-12, AD-39): the user an edit or its form read names is not one this
/// instance holds. Rendered on the <parameter>NOTFOUND</parameter> slug.</p>
Parameter USERNAMEABSENT = "USER.NAME.ABSENT";

Parameter REASONUSERNAMEABSENT = "This instance has no user with that name.";

/// <p>Machine code (AD-12, AD-39): the request to create a role broke one or more of the rules
/// <class>OcuPilot.Area.Permissions.RoleCreateRules</class> applies before the port is touched.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug with every violation in
/// <code>detail.violations</code>, the shape <parameter>USERVALIDATION</parameter> takes.</p>
Parameter ROLEVALIDATION = "ROLE.VALIDATION";

/// <p>The envelope's <code>reason</code> for <parameter>ROLEVALIDATION</parameter>, which the
/// screen renders only where no violation named a field.</p>
Parameter REASONROLEVALIDATION = "The role was refused.";

/// <p>Violation code: no name was supplied. A role's name is the vendor's <code>name</code> query
/// parameter, which its body refuses.</p>
Parameter ROLENAMEREQUIRED = "ROLE.NAME.REQUIRED";

Parameter REASONROLENAMEREQUIRED = "Give the role a name.";

/// <p>Violation code: the name is longer than <class>Security.Roles</class> stores.</p>
Parameter ROLENAMELENGTH = "ROLE.NAME.LENGTH";

Parameter REASONROLENAMELENGTH = "A role name is at most 64 characters.";

/// <p>Violation code: the name carries a control character, a comma or a colon, which
/// <class>Security.Roles</class> refuses.</p>
Parameter ROLENAMESHAPE = "ROLE.NAME.SHAPE";

Parameter REASONROLENAMESHAPE = "A role name has no control character, no comma and no colon.";

/// <p>Violation code: a role already carries that name. A role name is compared without regard to
/// case, so a name taken in any case is taken. A read rather than a validation --
/// <code>GET /roles/name</code> answers it on blur.</p>
Parameter ROLENAMETAKEN = "ROLE.NAME.TAKEN";

Parameter REASONROLENAMETAKEN = "This instance already has a role with that name. Choose a different one.";

/// <p>Violation code: the name begins with <code>%</code>, which only the instance's own predefined
/// roles do. Refused on a create, and on a delete, where the vendor endpoint would drop a
/// predefined role and report success.</p>
Parameter ROLENAMESYSTEM = "ROLE.NAME.SYSTEM";

Parameter REASONROLENAMESYSTEM = "A name beginning with % belongs to one of the instance's own roles.";

/// <p>Violation code: the description is longer than <class>Security.Roles</class> stores.</p>
Parameter ROLEDESCRIPTIONLENGTH = "ROLE.DESCRIPTION.LENGTH";

Parameter REASONROLEDESCRIPTIONLENGTH = "A role description is at most 256 characters.";

/// <p>Violation code: the resource grants are not a list of <code>{Name, Permissions}</code> objects
/// each naming a resource.</p>
Parameter ROLERESOURCESSHAPE = "ROLE.RESOURCES.SHAPE";

Parameter REASONROLERESOURCESSHAPE = "Each resource grant names one resource and its permissions.";

/// <p>Violation code: a grant names a resource this instance does not hold.</p>
Parameter ROLERESOURCESUNKNOWN = "ROLE.RESOURCES.UNKNOWN";

Parameter REASONROLERESOURCESUNKNOWN = "One of those resources does not exist on this instance.";

/// <p>Violation code: a grant carries no permission, repeats one, or carries a letter its resource
/// does not admit (<method>OcuPilot.Area.Permissions.RoleCreateRules.AdmissiblePermissions</method>,
/// the classic grant dialog's own rule).</p>
Parameter ROLERESOURCESPERMISSIONS = "ROLE.RESOURCES.PERMISSIONS";

Parameter REASONROLERESOURCESPERMISSIONS = "Grant each resource only the permissions it offers: Read and Write for a database; Use alone for a service, an administrative resource or another system resource the Management Portal limits to Use, such as %Development or %System_; and Read, Write or Use for any other.";

/// <p>Violation code: two grants name the same resource.</p>
Parameter ROLERESOURCESDUPLICATE = "ROLE.RESOURCES.DUPLICATE";

Parameter REASONROLERESOURCESDUPLICATE = "Grant each resource once.";

/// <p>Violation code: a database's resource is granted Write without Read. The classic grant dialog
/// ticks and locks Read when Write is ticked (<code>RoleResourceEdit.writeChanged</code>), so the
/// form does the same and the rule refuses what a caller sends otherwise.</p>
Parameter ROLERESOURCESWRITEONLY = "ROLE.RESOURCES.WRITEONLY";

Parameter REASONROLERESOURCESWRITEONLY = "A database grant that includes Write includes Read as well.";

/// <p>Violation code: the granted roles are not a list of role names.</p>
Parameter ROLEGRANTEDROLESSHAPE = "ROLE.GRANTEDROLES.SHAPE";

Parameter REASONROLEGRANTEDROLESSHAPE = "Granted roles are a list of role names.";

/// <p>Violation code: a granted role is not one this instance holds.</p>
Parameter ROLEGRANTEDROLESUNKNOWN = "ROLE.GRANTEDROLES.UNKNOWN";

Parameter REASONROLEGRANTEDROLESUNKNOWN = "One of those roles does not exist on this instance.";

/// <p>Machine code (AD-12, AD-39): a resource create or edit broke one or more of the rules
/// <class>OcuPilot.Area.Permissions.ResourceRules</class> applies before the port is touched.
/// Rendered on the <parameter>VALIDATIONFAILED</parameter> slug with every violation in
/// <code>detail.violations</code>, the shape <parameter>ROLEVALIDATION</parameter> takes.</p>
Parameter RESOURCEVALIDATION = "RESOURCE.VALIDATION";

/// <p>The envelope's <code>reason</code> for <parameter>RESOURCEVALIDATION</parameter>, which the
/// screen renders only where no violation named a field.</p>
Parameter REASONRESOURCEVALIDATION = "The resource was refused.";

/// <p>Violation code: no name was supplied. A resource's name is the vendor's <code>name</code>
/// query parameter, which its body refuses.</p>
Parameter RESOURCENAMEREQUIRED = "RESOURCE.NAME.REQUIRED";

Parameter REASONRESOURCENAMEREQUIRED = "Give the resource a name.";

/// <p>Violation code: the name is longer than <class>Security.Resources</class> stores.</p>
Parameter RESOURCENAMELENGTH = "RESOURCE.NAME.LENGTH";

Parameter REASONRESOURCENAMELENGTH = "A resource name is at most 64 characters.";

/// <p>Violation code: the name carries a control character, a comma or a colon, which
/// <class>Security.Resources</class> refuses.</p>
Parameter RESOURCENAMESHAPE = "RESOURCE.NAME.SHAPE";

Parameter REASONRESOURCENAMESHAPE = "A resource name has no control character, no comma and no colon.";

/// <p>Violation code: a resource already carries that name, compared without regard to case.
/// <code>GET /resources/name</code> answers it on blur.</p>
Parameter RESOURCENAMETAKEN = "RESOURCE.NAME.TAKEN";

Parameter REASONRESOURCENAMETAKEN = "This instance already has a resource with that name. Choose a different one.";

/// <p>Violation code: the resource is a system resource, one the vendor's own
/// <code>AllowDelete</code> answers false for, which IRIS refuses to delete.</p>
Parameter RESOURCENAMESYSTEM = "RESOURCE.NAME.SYSTEM";

Parameter REASONRESOURCENAMESYSTEM = "This is a system resource. IRIS does not allow it to be deleted.";

/// <p>Violation code: an edit, a form read or an update names a resource this instance does not
/// hold. Rendered at 404.</p>
Parameter RESOURCENAMEABSENT = "RESOURCE.NAME.ABSENT";

Parameter REASONRESOURCENAMEABSENT = "This instance has no resource with that name.";

/// <p>Violation code: the description is longer than <class>Security.Resources</class> stores.</p>
Parameter RESOURCEDESCRIPTIONLENGTH = "RESOURCE.DESCRIPTION.LENGTH";

Parameter REASONRESOURCEDESCRIPTIONLENGTH = "A resource description is at most 256 characters.";

/// <p>Violation code: the public permission is not a string of the letters R, W and U, each at most
/// once.</p>
Parameter RESOURCEPUBLICPERMISSIONSHAPE = "RESOURCE.PUBLICPERMISSION.SHAPE";

Parameter REASONRESOURCEPUBLICPERMISSIONSHAPE = "A public permission is some of the letters R, W and U, each at most once.";

/// <p>Violation code: the public permission carries a letter the resource does not offer
/// (<method>OcuPilot.Area.Permissions.ResourceRules.AdmissibleLetters</method>, the classic resource
/// dialog's own rule).</p>
Parameter RESOURCEPUBLICPERMISSIONLETTERS = "RESOURCE.PUBLICPERMISSION.LETTERS";

Parameter REASONRESOURCEPUBLICPERMISSIONLETTERS = "Give this resource only the public permissions it offers: Read and Write for a database; Use alone for a service, an administrative resource or another system resource the Management Portal limits to Use, such as %Development or %System_; and Read, Write or Use for any other.";

/// <p>Envelope code (AD-39): an X.509 credential's import or edit broke one or more of the rules
/// <class>OcuPilot.Area.Security.X509Rules</class> applies before the port is touched. Rendered on
/// the <parameter>VALIDATIONFAILED</parameter> slug with every violation in
/// <code>detail.violations</code>. No sentence in this block names or quotes a certificate, a key
/// or a password (AD-35).</p>
Parameter X509VALIDATION = "X509.VALIDATION";

Parameter REASONX509VALIDATION = "The X.509 credential was refused.";

/// <p>Violation code: no alias was supplied.</p>
Parameter X509ALIASREQUIRED = "X509.ALIAS.REQUIRED";

Parameter REASONX509ALIASREQUIRED = "Give the credential an alias.";

/// <p>Violation code: the alias is longer than <class>%SYS.X509Credentials</class> stores.</p>
Parameter X509ALIASLENGTH = "X509.ALIAS.LENGTH";

Parameter REASONX509ALIASLENGTH = "An alias is at most 150 characters.";

/// <p>Violation code: the alias carries a control character or a slash, which cannot travel as one
/// path segment (AD-13).</p>
Parameter X509ALIASSHAPE = "X509.ALIAS.SHAPE";

Parameter REASONX509ALIASSHAPE = "An alias has no control character and no slash.";

/// <p>Violation code: a credential already carries that alias, compared exactly, case included.
/// <code>GET /x509/name</code> answers it on blur.</p>
Parameter X509ALIASTAKEN = "X509.ALIAS.TAKEN";

Parameter REASONX509ALIASTAKEN = "This instance already has a credential with that alias. Choose a different one.";

/// <p>Violation code: an edit, a form read or an update names an alias this instance does not hold.
/// Rendered at 404.</p>
Parameter X509ALIASABSENT = "X509.ALIAS.ABSENT";

Parameter REASONX509ALIASABSENT = "This instance has no X.509 credential with that alias.";

/// <p>Violation code: an import carried no certificate.</p>
Parameter X509CERTIFICATEREQUIRED = "X509.CERTIFICATE.REQUIRED";

Parameter REASONX509CERTIFICATEREQUIRED = "Paste or load the certificate.";

/// <p>Violation code: the certificate is not one PEM <code>CERTIFICATE</code> block of at most
/// 65,536 characters that decodes to an X.509 certificate.</p>
Parameter X509CERTIFICATESHAPE = "X509.CERTIFICATE.SHAPE";

Parameter REASONX509CERTIFICATESHAPE = "The certificate must be one PEM block that begins -----BEGIN CERTIFICATE----- and is at most 64 KB.";

/// <p>Violation code: the certificate's validity has ended, which the vendor refuses.</p>
Parameter X509CERTIFICATEEXPIRED = "X509.CERTIFICATE.EXPIRED";

Parameter REASONX509CERTIFICATEEXPIRED = "This certificate has expired. Import one that is still valid.";

/// <p>Violation code: the private key is not one PEM private-key block, or it is a legacy encrypted
/// key whose line breaks were lost.</p>
Parameter X509PRIVATEKEYSHAPE = "X509.PRIVATEKEY.SHAPE";

Parameter REASONX509PRIVATEKEYSHAPE = "The private key must be one PEM private-key block of at most 64 KB, with its line breaks kept if it is a legacy encrypted key.";

/// <p>Violation code: the private key does not belong to the certificate.</p>
Parameter X509PRIVATEKEYMISMATCH = "X509.PRIVATEKEY.MISMATCH";

Parameter REASONX509PRIVATEKEYMISMATCH = "This private key does not belong to the certificate.";

/// <p>Violation code: the password does not decrypt the private key.</p>
Parameter X509PRIVATEKEYPASSWORDWRONG = "X509.PRIVATEKEYPASSWORD.WRONG";

Parameter REASONX509PRIVATEKEYPASSWORDWRONG = "This password does not decrypt the private key.";

/// <p>Violation code: a password was supplied with no private key.</p>
Parameter X509PRIVATEKEYPASSWORDWITHOUTKEY = "X509.PRIVATEKEYPASSWORD.WITHOUTKEY";

Parameter REASONX509PRIVATEKEYPASSWORDWITHOUTKEY = "A password is only for an encrypted private key. Remove it, or add the key.";

/// <p>Violation code: the password is longer than <class>%SYS.X509Credentials</class> stores.</p>
Parameter X509PRIVATEKEYPASSWORDLENGTH = "X509.PRIVATEKEYPASSWORD.LENGTH";

Parameter REASONX509PRIVATEKEYPASSWORDLENGTH = "A private key password is at most 128 characters.";

/// <p>Envelope code (AD-39): a wallet secret's create or edit broke one or more of the rules
/// <class>OcuPilot.Area.Security.WalletRules</class> applies before the port is touched. Rendered on
/// the <parameter>VALIDATIONFAILED</parameter> slug with every violation in
/// <code>detail.violations</code>. No sentence in this block quotes a secret's value (AD-35).</p>
Parameter WALLETVALIDATION = "WALLET.VALIDATION";

Parameter REASONWALLETVALIDATION = "The secret was refused.";

/// <p>Violation code: no name was supplied.</p>
Parameter WALLETNAMEREQUIRED = "WALLET.NAME.REQUIRED";

Parameter REASONWALLETNAMEREQUIRED = "Give the secret a name.";

/// <p>Violation code: the name is not a collection, a dot and a secret name of letters, digits,
/// dots, hyphens and underscores.</p>
Parameter WALLETNAMESHAPE = "WALLET.NAME.SHAPE";

Parameter REASONWALLETNAMESHAPE = "A secret's name uses only letters, digits, dots, hyphens and underscores, after its collection's name and a dot.";

/// <p>Violation code: the full name, collection included, is longer than
/// <class>%Wallet.Secret</class> stores.</p>
Parameter WALLETNAMELENGTH = "WALLET.NAME.LENGTH";

Parameter REASONWALLETNAMELENGTH = "A secret's full name, its collection's name included, is at most 128 characters.";

/// <p>Violation code: the collection already holds a secret with that exact name, case included.
/// <code>GET /wallet/secret/name</code> answers it on blur.</p>
Parameter WALLETNAMETAKEN = "WALLET.NAME.TAKEN";

Parameter REASONWALLETNAMETAKEN = "This collection already has a secret with that name. Choose a different one.";

/// <p>Violation code: an edit, a form read or a read names a secret this instance does not hold.
/// Rendered at 404.</p>
Parameter WALLETNAMEABSENT = "WALLET.NAME.ABSENT";

Parameter REASONWALLETNAMEABSENT = "This instance has no wallet secret with that name.";

/// <p>Violation code: the name's collection does not exist on this instance. Rendered at 404 on a
/// read and at 422 on a Save.</p>
Parameter WALLETCOLLECTIONABSENT = "WALLET.COLLECTION.ABSENT";

Parameter REASONWALLETCOLLECTIONABSENT = "This instance has no wallet collection with that name.";

/// <p>Violation code: a create carried no value.</p>
Parameter WALLETSECRETREQUIRED = "WALLET.SECRET.REQUIRED";

Parameter REASONWALLETSECRETREQUIRED = "Enter the value to store.";

/// <p>Violation code: the value is longer than the form accepts.</p>
Parameter WALLETSECRETLENGTH = "WALLET.SECRET.LENGTH";

Parameter REASONWALLETSECRETLENGTH = "A value is at most 32,768 characters.";

/// <p>Violation code: the uses are not a whole number from 0 to 15.</p>
Parameter WALLETUSAGERANGE = "WALLET.USAGE.RANGE";

Parameter REASONWALLETUSAGERANGE = "Usage is a whole number from 0 to 15: HTTP 1, SQL gateway 2, SOAP 4 and Custom 8, added together.";

/// <p>Violation code: the allowed hosts are not a list of host names, or one of them is empty,
/// longer than 255 characters, or holds whitespace or a comma.</p>
Parameter WALLETALLOWEDHOSTSSHAPE = "WALLET.ALLOWEDHOSTS.SHAPE";

Parameter REASONWALLETALLOWEDHOSTSSHAPE = "Each allowed host is a name or address of at most 255 characters, with no space or comma.";

/// <p>Violation code: an edit names a secret that is not a key-value secret, which this form does
/// not change.</p>
Parameter WALLETTYPEUNSUPPORTED = "WALLET.TYPE.UNSUPPORTED";

Parameter REASONWALLETTYPEUNSUPPORTED = "Only key-value secrets are edited here.";

/// <p>Envelope code (AD-39): a device's create or edit broke one or more of the rules
/// <class>OcuPilot.Area.OsMgmt.DeviceRules</class> applies before the port is touched, or the
/// instance could not read its open parameters. Rendered on the <parameter>VALIDATIONFAILED</parameter>
/// slug with every violation in <code>detail.violations</code>.</p>
Parameter DEVICEVALIDATION = "DEVICE.VALIDATION";

Parameter REASONDEVICEVALIDATION = "The device was refused.";

/// <p>Violation code: no name was supplied.</p>
Parameter DEVICENAMEREQUIRED = "DEVICE.NAME.REQUIRED";

Parameter REASONDEVICENAMEREQUIRED = "Give the device a name.";

/// <p>Violation code: the name is longer than <class>Config.Devices</class> stores.</p>
Parameter DEVICENAMELENGTH = "DEVICE.NAME.LENGTH";

Parameter REASONDEVICENAMELENGTH = "A device name is at most 64 characters.";

/// <p>Violation code: the name holds a <code>^</code>, an <code>=</code> or a control character,
/// which the instance writes raw into its configuration file.</p>
Parameter DEVICENAMESHAPE = "DEVICE.NAME.SHAPE";

Parameter REASONDEVICENAMESHAPE = "A device name has no ^, no = and no control character.";

/// <p>Violation code: a device already carries that name, compared exactly, case included.
/// <code>GET /device/name</code> answers it on blur.</p>
Parameter DEVICENAMETAKEN = "DEVICE.NAME.TAKEN";

Parameter REASONDEVICENAMETAKEN = "This instance already has a device with that name. Choose a different one.";

/// <p>Violation code: an edit or a form read names a device this instance does not hold. Rendered at
/// 404.</p>
Parameter DEVICENAMEABSENT = "DEVICE.NAME.ABSENT";

Parameter REASONDEVICENAMEABSENT = "This instance has no device with that name.";

/// <p>Violation code: a create carried no physical device name, or an edit emptied it.</p>
Parameter DEVICEPHYSICALDEVICEREQUIRED = "DEVICE.PHYSICALDEVICE.REQUIRED";

Parameter REASONDEVICEPHYSICALDEVICEREQUIRED = "Give the physical device name.";

/// <p>Violation code: the physical device name is longer than <class>Config.Devices</class>
/// stores.</p>
Parameter DEVICEPHYSICALDEVICELENGTH = "DEVICE.PHYSICALDEVICE.LENGTH";

Parameter REASONDEVICEPHYSICALDEVICELENGTH = "A physical device name is at most 128 characters.";

/// <p>Violation code: the physical device name holds a <code>^</code> or a control character.</p>
Parameter DEVICEPHYSICALDEVICESHAPE = "DEVICE.PHYSICALDEVICE.SHAPE";

Parameter REASONDEVICEPHYSICALDEVICESHAPE = "A physical device name has no ^ and no control character.";

/// <p>Violation code: a create carried no type, or an edit emptied it.</p>
Parameter DEVICETYPEREQUIRED = "DEVICE.TYPE.REQUIRED";

Parameter REASONDEVICETYPEREQUIRED = "Choose the device's type.";

/// <p>Violation code: the type is not one of the six the classic device page offers.</p>
Parameter DEVICETYPEVALUE = "DEVICE.TYPE.VALUE";

Parameter REASONDEVICETYPEVALUE = "A device's type is one of TRM, SPL, MT, BT, IPC or OTH.";

/// <p>Violation code: a create carried no subtype, or an edit emptied it.</p>
Parameter DEVICESUBTYPEREQUIRED = "DEVICE.SUBTYPE.REQUIRED";

Parameter REASONDEVICESUBTYPEREQUIRED = "Choose the device's subtype.";

/// <p>Violation code: the subtype is not one this instance defines.</p>
Parameter DEVICESUBTYPEABSENT = "DEVICE.SUBTYPE.ABSENT";

Parameter REASONDEVICESUBTYPEABSENT = "This instance has no subtype with that name. Choose one from the list.";

/// <p>Violation code: the open parameters are longer than <class>Config.Devices</class> stores.</p>
Parameter DEVICEOPENPARAMETERSLENGTH = "DEVICE.OPENPARAMETERS.LENGTH";

Parameter REASONDEVICEOPENPARAMETERSLENGTH = "Open parameters are at most 128 characters.";

/// <p>Violation code: the open parameters hold a <code>^</code> or a control character, or the
/// instance could not parse them (its error 644, mapped at the port).</p>
Parameter DEVICEOPENPARAMETERSSHAPE = "DEVICE.OPENPARAMETERS.SHAPE";

Parameter REASONDEVICEOPENPARAMETERSSHAPE = "This instance cannot use these open parameters. Write them as the OPEN command takes them, with no ^ and no control character.";

/// <p>Violation code: the description is longer than <class>Config.Devices</class> stores.</p>
Parameter DEVICEDESCRIPTIONLENGTH = "DEVICE.DESCRIPTION.LENGTH";

Parameter REASONDEVICEDESCRIPTIONLENGTH = "A description is at most 256 characters.";

/// <p>Violation code: the description holds a <code>^</code> or a control character.</p>
Parameter DEVICEDESCRIPTIONSHAPE = "DEVICE.DESCRIPTION.SHAPE";

Parameter REASONDEVICEDESCRIPTIONSHAPE = "A description has no ^ and no control character.";

/// <p>Violation code: the alternate device is longer than <class>Config.Devices</class> stores.</p>
Parameter DEVICEALTERNATEDEVICELENGTH = "DEVICE.ALTERNATEDEVICE.LENGTH";

Parameter REASONDEVICEALTERNATEDEVICELENGTH = "An alternate device is at most 128 characters.";

/// <p>Violation code: the alternate device holds a <code>^</code> or a control character.</p>
Parameter DEVICEALTERNATEDEVICESHAPE = "DEVICE.ALTERNATEDEVICE.SHAPE";

Parameter REASONDEVICEALTERNATEDEVICESHAPE = "An alternate device has no ^ and no control character.";

/// <p>Violation code: the alias is not a whole number of at least 1. The instance would store a
/// fraction truncated.</p>
Parameter DEVICEALIASSHAPE = "DEVICE.ALIAS.SHAPE";

Parameter REASONDEVICEALIASSHAPE = "An alias is a whole number of at least 1.";

/// <p>Violation code: another device already carries that alias. <class>Config.Devices</class>
/// requires aliases to be unique and does not enforce it.</p>
Parameter DEVICEALIASTAKEN = "DEVICE.ALIAS.TAKEN";

Parameter REASONDEVICEALIASTAKEN = "Another device already has that alias. Choose a different one.";

/// <p>Violation code: the alias equals the physical device name, which the instance refuses.</p>
Parameter DEVICEALIASSAME = "DEVICE.ALIAS.SAME";

Parameter REASONDEVICEALIASSAME = "An alias cannot be the same as the physical device name.";

/// <p>Violation code: the prompt is not empty, 1 or 2.</p>
Parameter DEVICEPROMPTVALUE = "DEVICE.PROMPT.VALUE";

Parameter REASONDEVICEPROMPTVALUE = "Choose one of the prompt options.";

/// <p>Machine code (Story 12.4): the server description editor refused a Save; the envelope's
/// <code>detail.violations</code> names each field and its rule (AD-39).</p>
Parameter OAUTHVALIDATION = "OAUTH.VALIDATION";

Parameter REASONOAUTHVALIDATION = "The server description was refused.";

/// <p>Violation code: no issuer endpoint.</p>
Parameter OAUTHISSUERENDPOINTREQUIRED = "OAUTH.ISSUERENDPOINT.REQUIRED";

Parameter REASONOAUTHISSUERENDPOINTREQUIRED = "Give the issuer endpoint.";

/// <p>Violation code: the issuer endpoint is not an absolute <code>http</code> or
/// <code>https</code> URL.</p>
Parameter OAUTHISSUERENDPOINTSHAPE = "OAUTH.ISSUERENDPOINT.SHAPE";

Parameter REASONOAUTHISSUERENDPOINTSHAPE = "The issuer endpoint is an absolute http or https URL with no query or fragment.";

/// <p>Violation code: another server description already carries that issuer endpoint, which the
/// vendor keeps unique.</p>
Parameter OAUTHISSUERENDPOINTTAKEN = "OAUTH.ISSUERENDPOINT.TAKEN";

Parameter REASONOAUTHISSUERENDPOINTTAKEN = "This instance already has a server description with that issuer endpoint. Choose a different one.";

/// <p>Machine code: no server description carries that issuer endpoint (404).</p>
Parameter OAUTHISSUERENDPOINTABSENT = "OAUTH.ISSUERENDPOINT.ABSENT";

Parameter REASONOAUTHISSUERENDPOINTABSENT = "This instance has no server description with that issuer endpoint.";

/// <p>Violation code: no SSL/TLS configuration.</p>
Parameter OAUTHSSLCONFIGURATIONREQUIRED = "OAUTH.SSLCONFIGURATION.REQUIRED";

Parameter REASONOAUTHSSLCONFIGURATIONREQUIRED = "Choose the SSL/TLS configuration.";

/// <p>Violation code: no authorization endpoint, which the vendor's definition requires.</p>
Parameter OAUTHAUTHORIZATIONENDPOINTREQUIRED = "OAUTH.AUTHORIZATIONENDPOINT.REQUIRED";

Parameter REASONOAUTHAUTHORIZATIONENDPOINTREQUIRED = "Give the authorization endpoint.";

/// <p>Violation code: no token endpoint, which the vendor's definition requires.</p>
Parameter OAUTHTOKENENDPOINTREQUIRED = "OAUTH.TOKENENDPOINT.REQUIRED";

Parameter REASONOAUTHTOKENENDPOINTREQUIRED = "Give the token endpoint.";

/// <p>Violation code: the X.509 credential named is not one this instance holds for the caller.</p>
Parameter OAUTHSERVERCREDENTIALSABSENT = "OAUTH.SERVERCREDENTIALS.ABSENT";

Parameter REASONOAUTHSERVERCREDENTIALSABSENT = "This instance has no X.509 credential with that name that you can use.";

/// <p>Violation code: a metadata member the server description does not store.</p>
Parameter OAUTHMETADATAUNKNOWN = "OAUTH.METADATA.UNKNOWN";

Parameter REASONOAUTHMETADATAUNKNOWN = "That is not a metadata member this instance stores.";

/// <p>Violation code: a metadata member's value is not the member's shape.</p>
Parameter OAUTHMETADATASHAPE = "OAUTH.METADATA.SHAPE";

Parameter REASONOAUTHMETADATASHAPE = "That metadata member takes a different kind of value: a URL or text as text, a list as an array of text, a number as a whole number, or a flag as true or false.";

/// <p>Machine code (409): a client configuration still uses the server description, which the
/// vendor refuses to delete.</p>
Parameter OAUTHSERVERINUSE = "OAUTH.SERVERINUSE";

Parameter REASONOAUTHSERVERINUSE = "Client configurations still use this server description. Delete them first.";

/// <p>Machine code (409): the server description stores no JWKS URL to refresh from.</p>
Parameter OAUTHNOJWKSURI = "OAUTH.NOJWKSURI";

Parameter REASONOAUTHNOJWKSURI = "This server description has no JWKS URL.";

/// <p>Machine code (422): the key set could not be fetched. The producer replaces
/// <code>{url}</code> with the stored JWKS URL.</p>
Parameter OAUTHJWKSFAILED = "OAUTH.JWKSFAILED";

Parameter REASONOAUTHJWKSFAILED = "The key set could not be fetched from {url}.";

/// <p>Machine codes (422): the four causes a discovery fails for. The producer replaces
/// <code>{issuer}</code>, <code>{status}</code> and <code>{claim}</code>.</p>
Parameter OAUTHDISCOVERYUNREACHABLE = "OAUTH.DISCOVERY.UNREACHABLE";

Parameter REASONOAUTHDISCOVERYUNREACHABLE = "{issuer} could not be reached.";

Parameter OAUTHDISCOVERYSTATUS = "OAUTH.DISCOVERY.STATUS";

Parameter REASONOAUTHDISCOVERYSTATUS = "{issuer} answered HTTP {status}.";

Parameter OAUTHDISCOVERYCONTENT = "OAUTH.DISCOVERY.CONTENT";

Parameter REASONOAUTHDISCOVERYCONTENT = "{issuer} did not answer JSON.";

Parameter OAUTHDISCOVERYISSUER = "OAUTH.DISCOVERY.ISSUER";

Parameter REASONOAUTHDISCOVERYISSUER = "The document names a different issuer: {claim}.";

/// <p>The sentence for an <code>OAUTH.*</code> code, placeholders unfilled, or <code>""</code>.</p>
ClassMethod ReasonForOAuth(pCode As %String) As %String
{
    If pCode = ..#OAUTHVALIDATION Quit ..#REASONOAUTHVALIDATION
    If pCode = ..#OAUTHISSUERENDPOINTREQUIRED Quit ..#REASONOAUTHISSUERENDPOINTREQUIRED
    If pCode = ..#OAUTHISSUERENDPOINTSHAPE Quit ..#REASONOAUTHISSUERENDPOINTSHAPE
    If pCode = ..#OAUTHISSUERENDPOINTTAKEN Quit ..#REASONOAUTHISSUERENDPOINTTAKEN
    If pCode = ..#OAUTHISSUERENDPOINTABSENT Quit ..#REASONOAUTHISSUERENDPOINTABSENT
    If pCode = ..#OAUTHSSLCONFIGURATIONREQUIRED Quit ..#REASONOAUTHSSLCONFIGURATIONREQUIRED
    If pCode = ..#OAUTHAUTHORIZATIONENDPOINTREQUIRED Quit ..#REASONOAUTHAUTHORIZATIONENDPOINTREQUIRED
    If pCode = ..#OAUTHTOKENENDPOINTREQUIRED Quit ..#REASONOAUTHTOKENENDPOINTREQUIRED
    If pCode = ..#OAUTHSERVERCREDENTIALSABSENT Quit ..#REASONOAUTHSERVERCREDENTIALSABSENT
    If pCode = ..#OAUTHMETADATAUNKNOWN Quit ..#REASONOAUTHMETADATAUNKNOWN
    If pCode = ..#OAUTHMETADATASHAPE Quit ..#REASONOAUTHMETADATASHAPE
    If pCode = ..#OAUTHSERVERINUSE Quit ..#REASONOAUTHSERVERINUSE
    If pCode = ..#OAUTHNOJWKSURI Quit ..#REASONOAUTHNOJWKSURI
    If pCode = ..#OAUTHJWKSFAILED Quit ..#REASONOAUTHJWKSFAILED
    If pCode = ..#OAUTHDISCOVERYUNREACHABLE Quit ..#REASONOAUTHDISCOVERYUNREACHABLE
    If pCode = ..#OAUTHDISCOVERYSTATUS Quit ..#REASONOAUTHDISCOVERYSTATUS
    If pCode = ..#OAUTHDISCOVERYCONTENT Quit ..#REASONOAUTHDISCOVERYCONTENT
    If pCode = ..#OAUTHDISCOVERYISSUER Quit ..#REASONOAUTHDISCOVERYISSUER
    Quit ..ReasonForOAuthClient(pCode)
}

/// <p>Every <code>OAUTH.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod OAuthViolationCodes() As %List
{
    Quit $ListBuild(..#OAUTHISSUERENDPOINTREQUIRED, ..#OAUTHISSUERENDPOINTSHAPE, ..#OAUTHISSUERENDPOINTTAKEN, ..#OAUTHSSLCONFIGURATIONREQUIRED, ..#OAUTHAUTHORIZATIONENDPOINTREQUIRED, ..#OAUTHTOKENENDPOINTREQUIRED, ..#OAUTHSERVERCREDENTIALSABSENT, ..#OAUTHMETADATAUNKNOWN, ..#OAUTHMETADATASHAPE)
}

/// <p>Machine code (Story 12.5): the client configuration editor refused a Save, the envelope's
/// <code>detail.violations</code> naming each field and its rule (AD-39); also the 422 the port
/// answers when the vendor refuses a client configuration write with a 500.</p>
Parameter OAUTHCLIENTVALIDATION = "OAUTH.CLIENTVALIDATION";

Parameter REASONOAUTHCLIENTVALIDATION = "This instance refused the client configuration.";

/// <p>Violation code: no application name.</p>
Parameter OAUTHAPPLICATIONNAMEREQUIRED = "OAUTH.APPLICATIONNAME.REQUIRED";

Parameter REASONOAUTHAPPLICATIONNAMEREQUIRED = "Give the application name.";

/// <p>Violation code: the application name is longer than 128 characters or carries a control
/// character.</p>
Parameter OAUTHAPPLICATIONNAMESHAPE = "OAUTH.APPLICATIONNAME.SHAPE";

Parameter REASONOAUTHAPPLICATIONNAMESHAPE = "The application name is 1 to 128 characters with no control character.";

/// <p>Violation code: a client configuration already carries that application name.</p>
Parameter OAUTHAPPLICATIONNAMETAKEN = "OAUTH.APPLICATIONNAME.TAKEN";

Parameter REASONOAUTHAPPLICATIONNAMETAKEN = "This instance already has a client configuration with that application name. Choose a different one.";

/// <p>Machine code: no client configuration carries that application name (404).</p>
Parameter OAUTHAPPLICATIONNAMEABSENT = "OAUTH.APPLICATIONNAME.ABSENT";

Parameter REASONOAUTHAPPLICATIONNAMEABSENT = "This instance has no client configuration with that application name.";

/// <p>Violation code: no server description.</p>
Parameter OAUTHSERVERDEFINITIONREQUIRED = "OAUTH.SERVERDEFINITION.REQUIRED";

Parameter REASONOAUTHSERVERDEFINITIONREQUIRED = "Choose the server description.";

/// <p>Violation code: the server description named is not one this instance holds.</p>
Parameter OAUTHSERVERDEFINITIONABSENT = "OAUTH.SERVERDEFINITION.ABSENT";

Parameter REASONOAUTHSERVERDEFINITIONABSENT = "This instance has no server description with that ID.";

/// <p>Violation code: a client type outside the vendor's three.</p>
Parameter OAUTHCLIENTTYPEVALUE = "OAUTH.CLIENTTYPE.VALUE";

Parameter REASONOAUTHCLIENTTYPEVALUE = "Choose confidential, public or resource.";

/// <p>Violation code: no redirect URL on a client that is not a resource server.</p>
Parameter OAUTHREDIRECTIONENDPOINTREQUIRED = "OAUTH.REDIRECTIONENDPOINT.REQUIRED";

Parameter REASONOAUTHREDIRECTIONENDPOINTREQUIRED = "Give the redirect URL. Only a resource server has none.";

/// <p>Violation code: the redirect URL is not an absolute <code>http</code> or <code>https</code>
/// URL with a host.</p>
Parameter OAUTHREDIRECTIONENDPOINTSHAPE = "OAUTH.REDIRECTIONENDPOINT.SHAPE";

Parameter REASONOAUTHREDIRECTIONENDPOINTSHAPE = "The redirect URL is an absolute http or https URL with a host.";

/// <p>Violation code: the X.509 credential named is not one the caller can use, or has no private
/// key.</p>
Parameter OAUTHCLIENTCREDENTIALSABSENT = "OAUTH.CLIENTCREDENTIALS.ABSENT";

Parameter REASONOAUTHCLIENTCREDENTIALSABSENT = "This instance has no X.509 credential with that name and a private key that you can use.";

/// <p>Violation code: the JWT interval is not a whole number.</p>
Parameter OAUTHJWTINTERVALSHAPE = "OAUTH.JWTINTERVAL.SHAPE";

Parameter REASONOAUTHJWTINTERVALSHAPE = "The JWT interval is a whole number of seconds.";

/// <p>Violation code: a metadata member with a fixed set of values was given another.</p>
Parameter OAUTHMETADATAVALUE = "OAUTH.METADATA.VALUE";

Parameter REASONOAUTHMETADATAVALUE = "Choose one of that member's values.";

/// <p>Machine code (422): a secrets write carried no secret, which the vendor would answer by saving
/// the configuration unchanged.</p>
Parameter OAUTHCLIENTNOSECRET = "OAUTH.CLIENTNOSECRET";

Parameter REASONOAUTHCLIENTNOSECRET = "Enter at least one secret.";

/// <p>Machine code (409): the client's keys come from its X.509 credential, and the vendor answers a
/// rotation of them 200 while changing nothing.</p>
Parameter OAUTHCLIENTKEYSFROMCREDENTIALS = "OAUTH.CLIENTKEYSFROMCREDENTIALS";

Parameter REASONOAUTHCLIENTKEYSFROMCREDENTIALS = "This client's keys come from its X.509 credential. Rotate that credential instead.";

/// <p>Machine code (409): the client already has a client ID or a registration URI.</p>
Parameter OAUTHCLIENTREGISTERED = "OAUTH.CLIENTREGISTERED";

Parameter REASONOAUTHCLIENTREGISTERED = "This client is already registered.";

/// <p>Machine code (409): the client's server description publishes no registration endpoint.</p>
Parameter OAUTHCLIENTNOREGISTRATIONENDPOINT = "OAUTH.CLIENTNOREGISTRATIONENDPOINT";

Parameter REASONOAUTHCLIENTNOREGISTRATIONENDPOINT = "The server description has no registration endpoint.";

/// <p>Machine code (422): the authorization server did not register the client. The producer
/// replaces <code>{issuer}</code>.</p>
Parameter OAUTHCLIENTREGISTRATIONFAILED = "OAUTH.CLIENTREGISTRATIONFAILED";

Parameter REASONOAUTHCLIENTREGISTRATIONFAILED = "{issuer} did not register this client.";

/// <p>The reason a Save of a registered client carries when the client saved on this instance and
/// the authorization server's copy of its registration was not updated.</p>
Parameter REASONOAUTHCLIENTREGISTRATIONNOTUPDATED = "It could not be reached, or it refused the change.";

/// <p>The sentence for a Story 12.5 <code>OAUTH.*</code> code, placeholders unfilled, or
/// <code>""</code>.</p>
ClassMethod ReasonForOAuthClient(pCode As %String) As %String
{
    If pCode = ..#OAUTHCLIENTVALIDATION Quit ..#REASONOAUTHCLIENTVALIDATION
    If pCode = ..#OAUTHAPPLICATIONNAMEREQUIRED Quit ..#REASONOAUTHAPPLICATIONNAMEREQUIRED
    If pCode = ..#OAUTHAPPLICATIONNAMESHAPE Quit ..#REASONOAUTHAPPLICATIONNAMESHAPE
    If pCode = ..#OAUTHAPPLICATIONNAMETAKEN Quit ..#REASONOAUTHAPPLICATIONNAMETAKEN
    If pCode = ..#OAUTHAPPLICATIONNAMEABSENT Quit ..#REASONOAUTHAPPLICATIONNAMEABSENT
    If pCode = ..#OAUTHSERVERDEFINITIONREQUIRED Quit ..#REASONOAUTHSERVERDEFINITIONREQUIRED
    If pCode = ..#OAUTHSERVERDEFINITIONABSENT Quit ..#REASONOAUTHSERVERDEFINITIONABSENT
    If pCode = ..#OAUTHCLIENTTYPEVALUE Quit ..#REASONOAUTHCLIENTTYPEVALUE
    If pCode = ..#OAUTHREDIRECTIONENDPOINTREQUIRED Quit ..#REASONOAUTHREDIRECTIONENDPOINTREQUIRED
    If pCode = ..#OAUTHREDIRECTIONENDPOINTSHAPE Quit ..#REASONOAUTHREDIRECTIONENDPOINTSHAPE
    If pCode = ..#OAUTHCLIENTCREDENTIALSABSENT Quit ..#REASONOAUTHCLIENTCREDENTIALSABSENT
    If pCode = ..#OAUTHJWTINTERVALSHAPE Quit ..#REASONOAUTHJWTINTERVALSHAPE
    If pCode = ..#OAUTHMETADATAVALUE Quit ..#REASONOAUTHMETADATAVALUE
    If pCode = ..#OAUTHCLIENTNOSECRET Quit ..#REASONOAUTHCLIENTNOSECRET
    If pCode = ..#OAUTHCLIENTKEYSFROMCREDENTIALS Quit ..#REASONOAUTHCLIENTKEYSFROMCREDENTIALS
    If pCode = ..#OAUTHCLIENTREGISTERED Quit ..#REASONOAUTHCLIENTREGISTERED
    If pCode = ..#OAUTHCLIENTNOREGISTRATIONENDPOINT Quit ..#REASONOAUTHCLIENTNOREGISTRATIONENDPOINT
    If pCode = ..#OAUTHCLIENTREGISTRATIONFAILED Quit ..#REASONOAUTHCLIENTREGISTRATIONFAILED
    Quit ..ReasonForOAuthResourceServer(pCode)
}

/// <p>Every field-level violation code the client configuration editor's rules produce, as a
/// <class>%List</class>, for its form read (Story 12.5).</p>
ClassMethod OAuthClientViolationCodes() As %List
{
    Quit $ListBuild(..#OAUTHAPPLICATIONNAMEREQUIRED, ..#OAUTHAPPLICATIONNAMESHAPE, ..#OAUTHAPPLICATIONNAMETAKEN, ..#OAUTHSERVERDEFINITIONREQUIRED, ..#OAUTHSERVERDEFINITIONABSENT, ..#OAUTHCLIENTTYPEVALUE, ..#OAUTHSSLCONFIGURATIONREQUIRED, ..#OAUTHREDIRECTIONENDPOINTREQUIRED, ..#OAUTHREDIRECTIONENDPOINTSHAPE, ..#OAUTHCLIENTCREDENTIALSABSENT, ..#OAUTHJWTINTERVALSHAPE, ..#OAUTHMETADATAUNKNOWN, ..#OAUTHMETADATASHAPE, ..#OAUTHMETADATAVALUE)
}

/// <p>Machine code (Story 12.6): the resource server editor refused a Save, the envelope's
/// <code>detail.violations</code> naming each field and its rule (AD-39); also the 422 the port
/// answers for any other vendor 500 on a resource server's <code>PUT</code>.</p>
Parameter OAUTHRESOURCESERVERVALIDATION = "OAUTH.RESOURCESERVERVALIDATION";

Parameter REASONOAUTHRESOURCESERVERVALIDATION = "This instance refused the resource server.";

/// <p>Machine code (422): a client secret write carrying no secret, which the vendor would store as
/// an empty secret.</p>
Parameter OAUTHRESOURCESERVERNOSECRET = "OAUTH.RESOURCESERVERNOSECRET";

Parameter REASONOAUTHRESOURCESERVERNOSECRET = "Enter the client secret.";

/// <p>Violation codes: the resource server's name.</p>
Parameter OAUTHRESOURCESERVERNAMEREQUIRED = "OAUTH.RESOURCESERVERNAME.REQUIRED";

Parameter REASONOAUTHRESOURCESERVERNAMEREQUIRED = "Give the resource server a name.";

Parameter OAUTHRESOURCESERVERNAMESHAPE = "OAUTH.RESOURCESERVERNAME.SHAPE";

Parameter REASONOAUTHRESOURCESERVERNAMESHAPE = "A resource server name is 1 to 128 characters with no control character.";

Parameter OAUTHRESOURCESERVERNAMETAKEN = "OAUTH.RESOURCESERVERNAME.TAKEN";

Parameter REASONOAUTHRESOURCESERVERNAMETAKEN = "This instance already has a resource server with that name. Choose a different one.";

/// <p>Machine code (404): no resource server carries that name.</p>
Parameter OAUTHRESOURCESERVERNAMEABSENT = "OAUTH.RESOURCESERVERNAME.ABSENT";

Parameter REASONOAUTHRESOURCESERVERNAMEABSENT = "This instance has no resource server with that name.";

/// <p>Violation codes: the audiences.</p>
Parameter OAUTHAUDIENCESREQUIRED = "OAUTH.AUDIENCES.REQUIRED";

Parameter REASONOAUTHAUDIENCESREQUIRED = "Add at least one audience.";

Parameter OAUTHAUDIENCESSHAPE = "OAUTH.AUDIENCES.SHAPE";

Parameter REASONOAUTHAUDIENCESSHAPE = "An audience is 1 to 256 characters with no control character.";

Parameter OAUTHAUDIENCESDUPLICATE = "OAUTH.AUDIENCES.DUPLICATE";

Parameter REASONOAUTHAUDIENCESDUPLICATE = "Each audience is listed once.";

/// <p>Violation codes: the two bounded texts, the introspection method and the four flags.</p>
Parameter OAUTHDESCRIPTIONLENGTH = "OAUTH.DESCRIPTION.LENGTH";

Parameter REASONOAUTHDESCRIPTIONLENGTH = "Use 256 characters or fewer for the description.";

Parameter OAUTHSCOPEREQUIREDLENGTH = "OAUTH.SCOPEREQUIRED.LENGTH";

Parameter REASONOAUTHSCOPEREQUIREDLENGTH = "Use 256 characters or fewer for the required scope.";

Parameter OAUTHINTROSPECTIONAUTHMETHODVALUE = "OAUTH.INTROSPECTIONAUTHMETHOD.VALUE";

Parameter REASONOAUTHINTROSPECTIONAUTHMETHODVALUE = "Choose HTTP Basic, Form post or none.";

Parameter OAUTHFLAGVALUE = "OAUTH.FLAG.VALUE";

Parameter REASONOAUTHFLAGVALUE = "This setting is on or off.";

/// <p>Violation codes: the authenticator's namespace, class and settings. A setting whose name is a
/// credential's (Conventions, Secrets) is never read or sent from OcuPilot.</p>
Parameter OAUTHAUTHENTICATORNAMESPACE = "OAUTH.AUTHENTICATOR.NAMESPACE";

Parameter REASONOAUTHAUTHENTICATORNAMESPACE = "Choose a namespace you can read.";

Parameter OAUTHAUTHENTICATORIMPLEMENTATION = "OAUTH.AUTHENTICATOR.IMPLEMENTATION";

Parameter REASONOAUTHAUTHENTICATORIMPLEMENTATION = "Choose an authenticator class compiled in that namespace.";

Parameter OAUTHAUTHENTICATORSETTING = "OAUTH.AUTHENTICATOR.SETTING";

Parameter REASONOAUTHAUTHENTICATORSETTING = "This authenticator has no such setting, or the value is not the setting's kind.";

Parameter OAUTHAUTHENTICATORSECRET = "OAUTH.AUTHENTICATOR.SECRET";

Parameter REASONOAUTHAUTHENTICATORSECRET = "Set this setting in the classic portal.";

/// <p>Violation codes: a service mapping's service and key, and a removal of a mapping this
/// resource server does not hold.</p>
Parameter OAUTHMAPPINGSERVICEVALUE = "OAUTH.MAPPINGSERVICE.VALUE";

Parameter REASONOAUTHMAPPINGSERVICEVALUE = "Choose the Web Gateway or ODBC/JDBC service.";

Parameter OAUTHMAPPINGKEYABSENT = "OAUTH.MAPPINGKEY.ABSENT";

Parameter REASONOAUTHMAPPINGKEYABSENT = "Choose * or a web application or namespace this instance has.";

Parameter OAUTHMAPPINGABSENT = "OAUTH.MAPPINGABSENT";

Parameter REASONOAUTHMAPPINGABSENT = "This resource server does not hold that service mapping.";

/// <p>The sentence for a Story 12.6 <code>OAUTH.*</code> code, or <code>""</code>.</p>
ClassMethod ReasonForOAuthResourceServer(pCode As %String) As %String
{
    If pCode = ..#OAUTHRESOURCESERVERVALIDATION Quit ..#REASONOAUTHRESOURCESERVERVALIDATION
    If pCode = ..#OAUTHRESOURCESERVERNOSECRET Quit ..#REASONOAUTHRESOURCESERVERNOSECRET
    If pCode = ..#OAUTHRESOURCESERVERNAMEREQUIRED Quit ..#REASONOAUTHRESOURCESERVERNAMEREQUIRED
    If pCode = ..#OAUTHRESOURCESERVERNAMESHAPE Quit ..#REASONOAUTHRESOURCESERVERNAMESHAPE
    If pCode = ..#OAUTHRESOURCESERVERNAMETAKEN Quit ..#REASONOAUTHRESOURCESERVERNAMETAKEN
    If pCode = ..#OAUTHRESOURCESERVERNAMEABSENT Quit ..#REASONOAUTHRESOURCESERVERNAMEABSENT
    If pCode = ..#OAUTHAUDIENCESREQUIRED Quit ..#REASONOAUTHAUDIENCESREQUIRED
    If pCode = ..#OAUTHAUDIENCESSHAPE Quit ..#REASONOAUTHAUDIENCESSHAPE
    If pCode = ..#OAUTHAUDIENCESDUPLICATE Quit ..#REASONOAUTHAUDIENCESDUPLICATE
    If pCode = ..#OAUTHDESCRIPTIONLENGTH Quit ..#REASONOAUTHDESCRIPTIONLENGTH
    If pCode = ..#OAUTHSCOPEREQUIREDLENGTH Quit ..#REASONOAUTHSCOPEREQUIREDLENGTH
    If pCode = ..#OAUTHINTROSPECTIONAUTHMETHODVALUE Quit ..#REASONOAUTHINTROSPECTIONAUTHMETHODVALUE
    If pCode = ..#OAUTHFLAGVALUE Quit ..#REASONOAUTHFLAGVALUE
    If pCode = ..#OAUTHAUTHENTICATORNAMESPACE Quit ..#REASONOAUTHAUTHENTICATORNAMESPACE
    If pCode = ..#OAUTHAUTHENTICATORIMPLEMENTATION Quit ..#REASONOAUTHAUTHENTICATORIMPLEMENTATION
    If pCode = ..#OAUTHAUTHENTICATORSETTING Quit ..#REASONOAUTHAUTHENTICATORSETTING
    If pCode = ..#OAUTHAUTHENTICATORSECRET Quit ..#REASONOAUTHAUTHENTICATORSECRET
    If pCode = ..#OAUTHMAPPINGSERVICEVALUE Quit ..#REASONOAUTHMAPPINGSERVICEVALUE
    If pCode = ..#OAUTHMAPPINGKEYABSENT Quit ..#REASONOAUTHMAPPINGKEYABSENT
    If pCode = ..#OAUTHMAPPINGABSENT Quit ..#REASONOAUTHMAPPINGABSENT
    Quit ..ReasonForOAuthAuthorizationServer(pCode)
}

/// <p>Every field-level violation code the resource server editor's rules produce, as a
/// <class>%List</class>, for its form read (Story 12.6).</p>
ClassMethod OAuthResourceServerViolationCodes() As %List
{
    Quit $ListBuild(..#OAUTHRESOURCESERVERNAMEREQUIRED, ..#OAUTHRESOURCESERVERNAMESHAPE, ..#OAUTHRESOURCESERVERNAMETAKEN, ..#OAUTHISSUERENDPOINTREQUIRED, ..#OAUTHISSUERENDPOINTABSENT, ..#OAUTHAUDIENCESREQUIRED, ..#OAUTHAUDIENCESSHAPE, ..#OAUTHAUDIENCESDUPLICATE, ..#OAUTHDESCRIPTIONLENGTH, ..#OAUTHSCOPEREQUIREDLENGTH, ..#OAUTHINTROSPECTIONAUTHMETHODVALUE, ..#OAUTHFLAGVALUE, ..#OAUTHAUTHENTICATORNAMESPACE, ..#OAUTHAUTHENTICATORIMPLEMENTATION, ..#OAUTHAUTHENTICATORSETTING, ..#OAUTHAUTHENTICATORSECRET, ..#OAUTHMAPPINGSERVICEVALUE, ..#OAUTHMAPPINGKEYABSENT, ..#OAUTHMAPPINGABSENT)
}

/// <p>Machine code (Story 12.7): the authorization server editor refused a Save, the envelope's
/// <code>detail.violations</code> naming each field and its rule (AD-39); also the 422 the port
/// answers for any other vendor 500 on the configuration's writes.</p>
Parameter OAUTHSERVERVALIDATION = "OAUTH.SERVERVALIDATION";

Parameter REASONOAUTHSERVERVALIDATION = "This instance refused the authorization server configuration.";

/// <p>Machine code (422): a create while a configuration exists; the instance has one.</p>
Parameter OAUTHSERVERCONFIGTAKEN = "OAUTH.SERVERCONFIG.TAKEN";

Parameter REASONOAUTHSERVERCONFIGTAKEN = "This instance already has an authorization server configuration. Open it to change it.";

/// <p>Machine code (404): an edit or a rotation while the instance has no configuration.</p>
Parameter OAUTHSERVERCONFIGABSENT = "OAUTH.SERVERCONFIG.ABSENT";

Parameter REASONOAUTHSERVERCONFIGABSENT = "This instance has no authorization server configuration.";

/// <p>Machine code (422): a key password write carrying no password, which the vendor would store as
/// an empty one.</p>
Parameter OAUTHSERVERNOPASSWORD = "OAUTH.SERVERNOPASSWORD";

Parameter REASONOAUTHSERVERNOPASSWORD = "Enter the private key password.";

/// <p>Machine code (409): a key rotation on a configuration whose keys come from its server
/// credentials.</p>
Parameter OAUTHSERVERKEYSCREDENTIALS = "OAUTH.SERVERKEYS.CREDENTIALS";

Parameter REASONOAUTHSERVERKEYSCREDENTIALS = "This authorization server's keys come from its server credentials, so there is nothing to rotate. Its next save rebuilds them.";

/// <p>Violation codes: the issuer endpoint.</p>
Parameter OAUTHSERVERISSUERREQUIRED = "OAUTH.SERVERISSUER.REQUIRED";

Parameter REASONOAUTHSERVERISSUERREQUIRED = "Enter the issuer endpoint.";

Parameter OAUTHSERVERISSUERSHAPE = "OAUTH.SERVERISSUER.SHAPE";

Parameter REASONOAUTHSERVERISSUERSHAPE = "Enter an https URL: a host, an optional port and an optional path, with no query or fragment.";

/// <p>Violation code: an interval that is not a whole number of seconds within its bound.</p>
Parameter OAUTHINTERVALVALUE = "OAUTH.INTERVAL.VALUE";

Parameter REASONOAUTHINTERVALVALUE = "Enter a whole number of seconds: at least 1, or at least 0 for the session and client secret intervals.";

/// <p>Violation codes: the supported scopes and the default scope.</p>
Parameter OAUTHSCOPESREQUIRED = "OAUTH.SCOPES.REQUIRED";

Parameter REASONOAUTHSCOPESREQUIRED = "Add at least one supported scope.";

Parameter OAUTHSCOPESSHAPE = "OAUTH.SCOPES.SHAPE";

Parameter REASONOAUTHSCOPESSHAPE = "A scope is at least one character with no space or control character.";

Parameter OAUTHSCOPESDUPLICATE = "OAUTH.SCOPES.DUPLICATE";

Parameter REASONOAUTHSCOPESDUPLICATE = "Each scope is listed once.";

Parameter OAUTHDEFAULTSCOPESHAPE = "OAUTH.DEFAULTSCOPE.SHAPE";

Parameter REASONOAUTHDEFAULTSCOPESHAPE = "Separate default scopes with spaces, and use no control character.";

/// <p>Violation codes: the description, the refresh token policy, the grant types, the metadata the
/// editor sets and the documentation URLs.</p>
Parameter OAUTHSERVERDESCRIPTIONLENGTH = "OAUTH.SERVERDESCRIPTION.LENGTH";

Parameter REASONOAUTHSERVERDESCRIPTIONLENGTH = "Use 1024 characters or fewer for the description.";

Parameter OAUTHRETURNREFRESHTOKENVALUE = "OAUTH.RETURNREFRESHTOKEN.VALUE";

Parameter REASONOAUTHRETURNREFRESHTOKENVALUE = "Choose when a refresh token is returned from the list.";

Parameter OAUTHGRANTTYPESREQUIRED = "OAUTH.GRANTTYPES.REQUIRED";

Parameter REASONOAUTHGRANTTYPESREQUIRED = "Choose at least one grant type.";

Parameter OAUTHGRANTTYPESVALUE = "OAUTH.GRANTTYPES.VALUE";

Parameter REASONOAUTHGRANTTYPESVALUE = "Choose grant types from the list.";

Parameter OAUTHSERVERMETADATAMEMBER = "OAUTH.SERVERMETADATA.MEMBER";

Parameter REASONOAUTHSERVERMETADATAMEMBER = "Only the grant types, the front-channel logout settings and the three documentation URLs are set here.";

Parameter OAUTHMETADATAURLSHAPE = "OAUTH.METADATAURL.SHAPE";

Parameter REASONOAUTHMETADATAURLSHAPE = "Enter an absolute http or https URL, or leave it empty.";

/// <p>Violation codes: the three JWT algorithms.</p>
Parameter OAUTHALGORITHMVALUE = "OAUTH.ALGORITHM.VALUE";

Parameter REASONOAUTHALGORITHMVALUE = "Choose an algorithm from the list, or none.";

Parameter OAUTHENCRYPTIONPAIR = "OAUTH.ENCRYPTION.PAIR";

Parameter REASONOAUTHENCRYPTIONPAIR = "Choose both a key management algorithm and a content encryption algorithm, or neither.";

/// <p>Violation codes: the customization namespace, classes and roles.</p>
Parameter OAUTHCUSTOMIZATIONNAMESPACEABSENT = "OAUTH.CUSTOMIZATIONNAMESPACE.ABSENT";

Parameter REASONOAUTHCUSTOMIZATIONNAMESPACEABSENT = "Choose a namespace you can read.";

Parameter OAUTHCUSTOMIZATIONCLASSREQUIRED = "OAUTH.CUSTOMIZATIONCLASS.REQUIRED";

Parameter REASONOAUTHCUSTOMIZATIONCLASSREQUIRED = "Enter the class name.";

Parameter OAUTHCUSTOMIZATIONCLASSABSENT = "OAUTH.CUSTOMIZATIONCLASS.ABSENT";

Parameter REASONOAUTHCUSTOMIZATIONCLASSABSENT = "Enter a class compiled in the customization namespace, in 256 characters or fewer.";

Parameter OAUTHCUSTOMIZATIONROLESREQUIRED = "OAUTH.CUSTOMIZATIONROLES.REQUIRED";

Parameter REASONOAUTHCUSTOMIZATIONROLESREQUIRED = "Choose at least one role.";

Parameter OAUTHCUSTOMIZATIONROLESABSENT = "OAUTH.CUSTOMIZATIONROLES.ABSENT";

Parameter REASONOAUTHCUSTOMIZATIONROLESABSENT = "Choose roles from the list.";

/// <p>Violation codes: the SSL/TLS configuration, and server credentials whose private key this
/// instance could not use.</p>
Parameter OAUTHSSLCONFIGURATIONABSENT = "OAUTH.SSLCONFIGURATION.ABSENT";

Parameter REASONOAUTHSSLCONFIGURATIONABSENT = "Choose an SSL/TLS configuration from the list, or none.";

Parameter OAUTHSERVERCREDENTIALSKEY = "OAUTH.SERVERCREDENTIALS.KEY";

Parameter REASONOAUTHSERVERCREDENTIALSKEY = "This instance could not use that credential's private key. Choose a credential with a private key. If its key needs a password, save the key password first, without the credential, then choose the credential.";

/// <p>The sentence for a Story 12.7 <code>OAUTH.*</code> code, or <code>""</code>.</p>
ClassMethod ReasonForOAuthAuthorizationServer(pCode As %String) As %String
{
    If pCode = ..#OAUTHSERVERVALIDATION Quit ..#REASONOAUTHSERVERVALIDATION
    If pCode = ..#OAUTHSERVERCONFIGTAKEN Quit ..#REASONOAUTHSERVERCONFIGTAKEN
    If pCode = ..#OAUTHSERVERCONFIGABSENT Quit ..#REASONOAUTHSERVERCONFIGABSENT
    If pCode = ..#OAUTHSERVERNOPASSWORD Quit ..#REASONOAUTHSERVERNOPASSWORD
    If pCode = ..#OAUTHSERVERKEYSCREDENTIALS Quit ..#REASONOAUTHSERVERKEYSCREDENTIALS
    If pCode = ..#OAUTHSERVERISSUERREQUIRED Quit ..#REASONOAUTHSERVERISSUERREQUIRED
    If pCode = ..#OAUTHSERVERISSUERSHAPE Quit ..#REASONOAUTHSERVERISSUERSHAPE
    If pCode = ..#OAUTHINTERVALVALUE Quit ..#REASONOAUTHINTERVALVALUE
    If pCode = ..#OAUTHSCOPESREQUIRED Quit ..#REASONOAUTHSCOPESREQUIRED
    If pCode = ..#OAUTHSCOPESSHAPE Quit ..#REASONOAUTHSCOPESSHAPE
    If pCode = ..#OAUTHSCOPESDUPLICATE Quit ..#REASONOAUTHSCOPESDUPLICATE
    If pCode = ..#OAUTHDEFAULTSCOPESHAPE Quit ..#REASONOAUTHDEFAULTSCOPESHAPE
    If pCode = ..#OAUTHSERVERDESCRIPTIONLENGTH Quit ..#REASONOAUTHSERVERDESCRIPTIONLENGTH
    If pCode = ..#OAUTHRETURNREFRESHTOKENVALUE Quit ..#REASONOAUTHRETURNREFRESHTOKENVALUE
    If pCode = ..#OAUTHGRANTTYPESREQUIRED Quit ..#REASONOAUTHGRANTTYPESREQUIRED
    If pCode = ..#OAUTHGRANTTYPESVALUE Quit ..#REASONOAUTHGRANTTYPESVALUE
    If pCode = ..#OAUTHSERVERMETADATAMEMBER Quit ..#REASONOAUTHSERVERMETADATAMEMBER
    If pCode = ..#OAUTHMETADATAURLSHAPE Quit ..#REASONOAUTHMETADATAURLSHAPE
    If pCode = ..#OAUTHALGORITHMVALUE Quit ..#REASONOAUTHALGORITHMVALUE
    If pCode = ..#OAUTHENCRYPTIONPAIR Quit ..#REASONOAUTHENCRYPTIONPAIR
    If pCode = ..#OAUTHCUSTOMIZATIONNAMESPACEABSENT Quit ..#REASONOAUTHCUSTOMIZATIONNAMESPACEABSENT
    If pCode = ..#OAUTHCUSTOMIZATIONCLASSREQUIRED Quit ..#REASONOAUTHCUSTOMIZATIONCLASSREQUIRED
    If pCode = ..#OAUTHCUSTOMIZATIONCLASSABSENT Quit ..#REASONOAUTHCUSTOMIZATIONCLASSABSENT
    If pCode = ..#OAUTHCUSTOMIZATIONROLESREQUIRED Quit ..#REASONOAUTHCUSTOMIZATIONROLESREQUIRED
    If pCode = ..#OAUTHCUSTOMIZATIONROLESABSENT Quit ..#REASONOAUTHCUSTOMIZATIONROLESABSENT
    If pCode = ..#OAUTHSSLCONFIGURATIONABSENT Quit ..#REASONOAUTHSSLCONFIGURATIONABSENT
    If pCode = ..#OAUTHSERVERCREDENTIALSKEY Quit ..#REASONOAUTHSERVERCREDENTIALSKEY
    Quit ..ReasonForOAuthServerClient(pCode)
}

/// <p>Every field-level violation code the authorization server editor's rules produce, as a
/// <class>%List</class>, for its form read (Story 12.7).</p>
ClassMethod OAuthAuthorizationServerViolationCodes() As %List
{
    Quit $ListBuild(..#OAUTHSERVERCONFIGTAKEN, ..#OAUTHSERVERISSUERREQUIRED, ..#OAUTHSERVERISSUERSHAPE, ..#OAUTHINTERVALVALUE, ..#OAUTHSCOPESREQUIRED, ..#OAUTHSCOPESSHAPE, ..#OAUTHSCOPESDUPLICATE, ..#OAUTHDEFAULTSCOPESHAPE, ..#OAUTHSERVERDESCRIPTIONLENGTH, ..#OAUTHRETURNREFRESHTOKENVALUE, ..#OAUTHGRANTTYPESREQUIRED, ..#OAUTHGRANTTYPESVALUE, ..#OAUTHSERVERMETADATAMEMBER, ..#OAUTHMETADATAURLSHAPE, ..#OAUTHFLAGVALUE, ..#OAUTHALGORITHMVALUE, ..#OAUTHENCRYPTIONPAIR, ..#OAUTHCUSTOMIZATIONNAMESPACEABSENT, ..#OAUTHCUSTOMIZATIONCLASSREQUIRED, ..#OAUTHCUSTOMIZATIONCLASSABSENT, ..#OAUTHCUSTOMIZATIONROLESREQUIRED, ..#OAUTHCUSTOMIZATIONROLESABSENT, ..#OAUTHSSLCONFIGURATIONABSENT, ..#OAUTHSERVERCREDENTIALSABSENT, ..#OAUTHSERVERCREDENTIALSKEY)
}

/// <p>Machine code (Story 12.8): the server client description editor refused a Save, the
/// envelope's <code>detail.violations</code> naming each field and its rule (AD-39); also the 422 the
/// port answers for any other vendor 500 on a client's writes.</p>
Parameter OAUTHSERVERCLIENTVALIDATION = "OAUTH.SERVERCLIENTVALIDATION";

Parameter REASONOAUTHSERVERCLIENTVALIDATION = "This instance refused the server client description.";

/// <p>Violation codes: the client's name.</p>
Parameter OAUTHSERVERCLIENTNAMEREQUIRED = "OAUTH.SERVERCLIENTNAME.REQUIRED";

Parameter REASONOAUTHSERVERCLIENTNAMEREQUIRED = "Enter the client's name.";

Parameter OAUTHSERVERCLIENTNAMETAKEN = "OAUTH.SERVERCLIENTNAME.TAKEN";

Parameter REASONOAUTHSERVERCLIENTNAMETAKEN = "A client is already registered with that name. Choose another name, or open that client to change it.";

/// <p>Violation code: a client type other than the three the instance stores.</p>
Parameter OAUTHSERVERCLIENTTYPEVALUE = "OAUTH.SERVERCLIENTTYPE.VALUE";

Parameter REASONOAUTHSERVERCLIENTTYPEVALUE = "Choose confidential, public or resource server.";

/// <p>Violation codes: the redirect URLs.</p>
Parameter OAUTHREDIRECTURLREQUIRED = "OAUTH.REDIRECTURL.REQUIRED";

Parameter REASONOAUTHREDIRECTURLREQUIRED = "Add at least one redirect URL.";

Parameter OAUTHREDIRECTURLSHAPE = "OAUTH.REDIRECTURL.SHAPE";

Parameter REASONOAUTHREDIRECTURLSHAPE = "Enter each redirect URL as an absolute URL with a scheme and a host, such as https://app.example.com/callback.";

/// <p>Violation codes: the client's grant types, response types and authentication type.</p>
Parameter OAUTHCLIENTGRANTTYPESREQUIRED = "OAUTH.CLIENTGRANTTYPES.REQUIRED";

Parameter REASONOAUTHCLIENTGRANTTYPESREQUIRED = "Choose at least one grant type this client uses.";

Parameter OAUTHCLIENTGRANTTYPESVALUE = "OAUTH.CLIENTGRANTTYPES.VALUE";

Parameter REASONOAUTHCLIENTGRANTTYPESVALUE = "Choose the client's grant types from the list.";

Parameter OAUTHCLIENTGRANTTYPESUNSUPPORTED = "OAUTH.CLIENTGRANTTYPES.UNSUPPORTED";

Parameter REASONOAUTHCLIENTGRANTTYPESUNSUPPORTED = "The authorization server does not support one of these grant types. Choose grant types its configuration supports.";

Parameter OAUTHRESPONSETYPESREQUIRED = "OAUTH.RESPONSETYPES.REQUIRED";

Parameter REASONOAUTHRESPONSETYPESREQUIRED = "Choose at least one response type.";

Parameter OAUTHRESPONSETYPESVALUE = "OAUTH.RESPONSETYPES.VALUE";

Parameter REASONOAUTHRESPONSETYPESVALUE = "Choose response types from the list.";

Parameter OAUTHAUTHMETHODVALUE = "OAUTH.AUTHMETHOD.VALUE";

Parameter REASONOAUTHAUTHMETHODVALUE = "Choose an authentication type from the list.";

/// <p>Violation codes: the client's information URLs, contacts, default max age and launch URL.</p>
Parameter OAUTHCLIENTURLHOST = "OAUTH.CLIENTURL.HOST";

Parameter REASONOAUTHCLIENTURLHOST = "Use the scheme and host of one of the redirect URLs.";

Parameter OAUTHCONTACTSSHAPE = "OAUTH.CONTACTS.SHAPE";

Parameter REASONOAUTHCONTACTSSHAPE = "Separate contact email addresses with commas, each like name@example.com.";

Parameter OAUTHMAXAGEVALUE = "OAUTH.MAXAGE.VALUE";

Parameter REASONOAUTHMAXAGEVALUE = "Enter a whole number of seconds, 0 or more, or leave it empty.";

Parameter OAUTHLAUNCHURLSHAPE = "OAUTH.LAUNCHURL.SHAPE";

Parameter REASONOAUTHLAUNCHURLSHAPE = "Enter an absolute URL with a scheme and a host, or leave it empty.";

/// <p>Violation code: a create's client secret, which every type but a public client needs.</p>
Parameter OAUTHSERVERCLIENTSECRETREQUIRED = "OAUTH.SERVERCLIENTSECRET.REQUIRED";

Parameter REASONOAUTHSERVERCLIENTSECRETREQUIRED = "Enter or generate a client secret. Only a public client needs none.";

/// <p>Violation code: a server client's X.509 credentials name no credential the caller can use. The
/// credential holds the client's certificate, which verifies its signatures, so no private key is
/// asked of it.</p>
Parameter OAUTHSERVERCLIENTCREDENTIALSABSENT = "OAUTH.SERVERCLIENTCREDENTIALS.ABSENT";

Parameter REASONOAUTHSERVERCLIENTCREDENTIALSABSENT = "This instance has no X.509 credential with that name that you can use.";

/// <p>Machine code (422): a secret write carrying no secret, which the vendor would store as an empty
/// one and so clear the stored secret.</p>
Parameter OAUTHSERVERCLIENTNOSECRET = "OAUTH.SERVERCLIENTNOSECRET";

Parameter REASONOAUTHSERVERCLIENTNOSECRET = "Enter the client secret.";

/// <p>Machine codes: an Update JWKS on a client with no JWKS URL (409), on one whose URL is neither
/// <code>https</code> nor <code>http</code> (422), and a fetch that failed (422). The fetch's sentence
/// names the URL in place of <code>{url}</code>.</p>
Parameter OAUTHSERVERCLIENTJWKSNOURI = "OAUTH.SERVERCLIENTJWKS.NOURI";

Parameter REASONOAUTHSERVERCLIENTJWKSNOURI = "This client has no JWKS URL.";

Parameter OAUTHSERVERCLIENTJWKSSCHEME = "OAUTH.SERVERCLIENTJWKS.SCHEME";

Parameter REASONOAUTHSERVERCLIENTJWKSSCHEME = "The JWKS URL must begin with https:// or http://.";

Parameter OAUTHSERVERCLIENTJWKSFETCH = "OAUTH.SERVERCLIENTJWKS.FETCH";

Parameter REASONOAUTHSERVERCLIENTJWKSFETCH = "The client's public keys could not be fetched from {url}. Check that it answers and, for an https URL, that OcuPilot's own SSL/TLS configuration trusts its certificate.";

/// <p>Machine code (422): a write the vendor refused because this instance has no authorization server
/// configuration.</p>
Parameter OAUTHSERVERCLIENTCONFIGABSENT = "OAUTH.SERVERCLIENTCONFIG.ABSENT";

Parameter REASONOAUTHSERVERCLIENTCONFIGABSENT = "This instance has no authorization server configuration. Create it before registering a client.";

/// <p>Machine code (404): an edit, a form read or an action naming a client id the instance does not
/// hold.</p>
Parameter OAUTHSERVERCLIENTABSENT = "OAUTH.SERVERCLIENT.ABSENT";

Parameter REASONOAUTHSERVERCLIENTABSENT = "This instance has no server client description with that client ID.";

/// <p>The sentence for a Story 12.8 <code>OAUTH.*</code> code, or <code>""</code>.</p>
ClassMethod ReasonForOAuthServerClient(pCode As %String) As %String
{
    If pCode = ..#OAUTHSERVERCLIENTVALIDATION Quit ..#REASONOAUTHSERVERCLIENTVALIDATION
    If pCode = ..#OAUTHSERVERCLIENTNAMEREQUIRED Quit ..#REASONOAUTHSERVERCLIENTNAMEREQUIRED
    If pCode = ..#OAUTHSERVERCLIENTNAMETAKEN Quit ..#REASONOAUTHSERVERCLIENTNAMETAKEN
    If pCode = ..#OAUTHSERVERCLIENTTYPEVALUE Quit ..#REASONOAUTHSERVERCLIENTTYPEVALUE
    If pCode = ..#OAUTHREDIRECTURLREQUIRED Quit ..#REASONOAUTHREDIRECTURLREQUIRED
    If pCode = ..#OAUTHREDIRECTURLSHAPE Quit ..#REASONOAUTHREDIRECTURLSHAPE
    If pCode = ..#OAUTHCLIENTGRANTTYPESREQUIRED Quit ..#REASONOAUTHCLIENTGRANTTYPESREQUIRED
    If pCode = ..#OAUTHCLIENTGRANTTYPESVALUE Quit ..#REASONOAUTHCLIENTGRANTTYPESVALUE
    If pCode = ..#OAUTHCLIENTGRANTTYPESUNSUPPORTED Quit ..#REASONOAUTHCLIENTGRANTTYPESUNSUPPORTED
    If pCode = ..#OAUTHRESPONSETYPESREQUIRED Quit ..#REASONOAUTHRESPONSETYPESREQUIRED
    If pCode = ..#OAUTHRESPONSETYPESVALUE Quit ..#REASONOAUTHRESPONSETYPESVALUE
    If pCode = ..#OAUTHAUTHMETHODVALUE Quit ..#REASONOAUTHAUTHMETHODVALUE
    If pCode = ..#OAUTHCLIENTURLHOST Quit ..#REASONOAUTHCLIENTURLHOST
    If pCode = ..#OAUTHCONTACTSSHAPE Quit ..#REASONOAUTHCONTACTSSHAPE
    If pCode = ..#OAUTHMAXAGEVALUE Quit ..#REASONOAUTHMAXAGEVALUE
    If pCode = ..#OAUTHLAUNCHURLSHAPE Quit ..#REASONOAUTHLAUNCHURLSHAPE
    If pCode = ..#OAUTHSERVERCLIENTSECRETREQUIRED Quit ..#REASONOAUTHSERVERCLIENTSECRETREQUIRED
    If pCode = ..#OAUTHSERVERCLIENTCREDENTIALSABSENT Quit ..#REASONOAUTHSERVERCLIENTCREDENTIALSABSENT
    If pCode = ..#OAUTHSERVERCLIENTNOSECRET Quit ..#REASONOAUTHSERVERCLIENTNOSECRET
    If pCode = ..#OAUTHSERVERCLIENTJWKSNOURI Quit ..#REASONOAUTHSERVERCLIENTJWKSNOURI
    If pCode = ..#OAUTHSERVERCLIENTJWKSSCHEME Quit ..#REASONOAUTHSERVERCLIENTJWKSSCHEME
    If pCode = ..#OAUTHSERVERCLIENTJWKSFETCH Quit ..#REASONOAUTHSERVERCLIENTJWKSFETCH
    If pCode = ..#OAUTHSERVERCLIENTCONFIGABSENT Quit ..#REASONOAUTHSERVERCLIENTCONFIGABSENT
    If pCode = ..#OAUTHSERVERCLIENTABSENT Quit ..#REASONOAUTHSERVERCLIENTABSENT
    Quit ""
}

/// <p>Every field-level violation code the server client description editor's rules produce, as a
/// <class>%List</class>, for its form read (Story 12.8).</p>
ClassMethod OAuthServerClientViolationCodes() As %List
{
    Quit $ListBuild(..#OAUTHSERVERCLIENTNAMEREQUIRED, ..#OAUTHSERVERCLIENTNAMETAKEN, ..#OAUTHSERVERCLIENTTYPEVALUE, ..#OAUTHREDIRECTURLREQUIRED, ..#OAUTHREDIRECTURLSHAPE, ..#OAUTHCLIENTGRANTTYPESREQUIRED, ..#OAUTHCLIENTGRANTTYPESVALUE, ..#OAUTHCLIENTGRANTTYPESUNSUPPORTED, ..#OAUTHRESPONSETYPESREQUIRED, ..#OAUTHRESPONSETYPESVALUE, ..#OAUTHAUTHMETHODVALUE, ..#OAUTHALGORITHMVALUE, ..#OAUTHENCRYPTIONPAIR, ..#OAUTHCLIENTURLHOST, ..#OAUTHMETADATAURLSHAPE, ..#OAUTHCONTACTSSHAPE, ..#OAUTHMAXAGEVALUE, ..#OAUTHLAUNCHURLSHAPE, ..#OAUTHDEFAULTSCOPESHAPE, ..#OAUTHFLAGVALUE, ..#OAUTHSERVERCLIENTCREDENTIALSABSENT, ..#OAUTHSERVERCLIENTSECRETREQUIRED, ..#OAUTHMETADATAUNKNOWN)
}

/// <p>Violation code (AD-39): the vendor refused the request because a body field it requires was
/// absent. Produced at the port boundary by <method>ViolationsFromVendor</method>, on the field the
/// vendor's own status names, so a refusal lands on the field it is about.</p>
Parameter PORTFIELDREQUIRED = "PORT.FIELD.REQUIRED";

Parameter REASONPORTFIELDREQUIRED = "This instance requires a value for that field.";

/// <p>Violation code (AD-39): the vendor refused the request because the body carried a field its
/// own template does not declare.</p>
Parameter PORTFIELDUNEXPECTED = "PORT.FIELD.UNEXPECTED";

Parameter REASONPORTFIELDUNEXPECTED = "This instance does not accept that field on this request.";

/// <p>Violation code (AD-39): the vendor refused the request because the field carried a value of
/// the wrong shape -- an object where it wanted a literal, or a value outside the set it names.</p>
Parameter PORTFIELDSHAPE = "PORT.FIELD.SHAPE";

Parameter REASONPORTFIELDSHAPE = "This instance expects a different kind of value for that field.";

/// <p>The vendor status codes whose <b>first</b> parameter is the dotted name of the body field
/// they are about, comma-separated, each paired with the OcuPilot violation code it maps onto
/// (AD-39).</p>
/// <p><b>Read off the instance, not recalled</b>: <code>%Api.Admin.Util.RequestValidator</code>
/// raises exactly these, each as <code>$$$ERROR(&lt;code&gt;, name)</code> where <code>name</code>
/// is the field path with <code>.</code> between members and <code>[0]</code> for an array's first
/// element. 40301 is <code>MissingRequestBodyField</code>, 40307 is
/// <code>UnexpectedRequestBodyField</code>, 40302 to 40306 are its value-set refusals and 40308 and
/// 40309 its two shape refusals.</p>
Parameter VENDORFIELDCODES = "40301=PORT.FIELD.REQUIRED,40302=PORT.FIELD.SHAPE,40303=PORT.FIELD.SHAPE,40304=PORT.FIELD.SHAPE,40305=PORT.FIELD.SHAPE,40306=PORT.FIELD.SHAPE,40307=PORT.FIELD.UNEXPECTED,40308=PORT.FIELD.SHAPE,40309=PORT.FIELD.SHAPE";

/// <p>The <code>detail.violations</code> rows a vendor status carries, as a
/// <class>%DynamicArray</class> of <code>{field, code, reason}</code>, or <code>[]</code> when it
/// names no field (AD-39).</p>
/// <p><b>It is the port boundary's job, and it is what makes a vendor refusal land on the field it
/// names.</b> The vendor's own text is written for a portal developer and never reaches either
/// consumer; what crosses is the field name it carried, OcuPilot's stable code for that kind of
/// refusal, and OcuPilot's own sentence. The field is the vendor's <b>first</b> parameter, taken
/// verbatim including its dots and its <code>[0]</code>, so a refusal about
/// <code>MatchRoles[0].MatchRole</code> names that path rather than its last segment.</p>
/// <p>A status carrying several such errors answers one row each, in the order
/// <method>$System.Status.DecomposeStatus</method> reports them.</p>
ClassMethod ViolationsFromVendor(pStatus As %Status) As %DynamicArray
{
    Set tRows = []
    Try {
        If $$$ISOK(pStatus) Quit
        Do $System.Status.DecomposeStatus(pStatus, .tErrors, "-d")
        For tI = 1:1:+$Get(tErrors) {
            Set tCode = ..VendorFieldCode($Get(tErrors(tI, "code")))
            If tCode = "" Continue
            Set tField = $Get(tErrors(tI, "param", 1))
            If tField = "" Continue
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("code", tCode, "string")
            Do tRow.%Set("reason", ..ReasonForViolation(tCode), "string")
            Do tRows.%Push(tRow)
        }
    } Catch {
        Set tRows = []
    }
    Quit tRows
}

/// <p>The OcuPilot violation code <parameter>VENDORFIELDCODES</parameter> pairs with the vendor
/// status code <var>pVendorCode</var>, or <code>""</code> for a code that names no field.</p>
ClassMethod VendorFieldCode(pVendorCode As %String) As %String [ Private ]
{
    Set tFound = ""
    If pVendorCode = "" Quit tFound
    For tI = 1:1:$Length(..#VENDORFIELDCODES, ",") {
        Set tPair = $Piece(..#VENDORFIELDCODES, ",", tI)
        If $Piece(tPair, "=", 1) = pVendorCode Set tFound = $Piece(tPair, "=", 2) Quit
    }
    Quit tFound
}

/// <p>Whether <var>pSlug</var> is one of the twelve closed-enum slugs above. Private —
/// the enum is closed and this is the only code that needs to test membership in it.</p>
ClassMethod IsKnownSlug(pSlug As %String) As %Boolean [ Private ]
{
    Quit $ListFind($ListBuild(..#BADREQUEST, ..#UNAUTHORIZED, ..#FORBIDDEN, ..#NOTFOUND, ..#METHODNOTALLOWED, ..#CONFLICT, ..#PRECONDITIONFAILED, ..#BADCONTENTTYPE, ..#VALIDATIONFAILED, ..#SERVERERROR, ..#NOTIMPLEMENTED, ..#UNAVAILABLE), pSlug) > 0
}

/// <p>Machine code (Story 15.6, AD-50): a shell preference write carried a <code>value</code>
/// outside the fixed set its member takes -- for <code>theme</code>, anything but
/// <code>light</code> or <code>dark</code>
/// (<method>OcuPilot.Kernel.State.Pref.IsThemeValue</method>). Rendered on the
/// <parameter>VALIDATIONFAILED</parameter> slug with one violation on <code>value</code>.</p>
Parameter PREFERENCESCHOICE = "PREFERENCES.CHOICE";

/// <p>Refusal sentence for <parameter>PREFERENCESCHOICE</parameter>. It names no value the
/// caller sent.</p>
Parameter REASONPREFERENCESCHOICE = "That preference takes one of a fixed set of values.";

/// <p>Machine code (AD-12, AD-39): the web application an edit or its form read names is not one
/// this instance holds. Rendered on the <parameter>NOTFOUND</parameter> slug.</p>
Parameter WEBAPPNAMEABSENT = "WEBAPP.NAME.ABSENT";

Parameter REASONWEBAPPNAMEABSENT = "This instance has no web application with that name.";

/// <p>Machine code (AD-12, AD-39): the role an edit or its form read names is not one this
/// instance holds (Story 9.3). Rendered on the <parameter>NOTFOUND</parameter> slug.</p>
Parameter ROLENAMEABSENT = "ROLE.NAME.ABSENT";

Parameter REASONROLENAMEABSENT = "This instance has no role with that name.";

/// <p>Violation code: an edit's <code>EscalationOnly</code> is not a boolean (Story 9.3).</p>
Parameter ROLEESCALATIONONLYSHAPE = "ROLE.ESCALATIONONLY.SHAPE";

Parameter REASONROLEESCALATIONONLYSHAPE = "Escalation only is either on or off.";

/// <p>Envelope code (AD-39): an SSL/TLS configuration's create or edit broke one or more of the
/// rules <class>OcuPilot.Area.Security.SslRules</class> applies before the port is touched, or the
/// vendor refused a value the port maps to a field
/// (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>). Rendered on the
/// <parameter>VALIDATIONFAILED</parameter> slug with every violation in
/// <code>detail.violations</code>. No sentence in this block names a file path or quotes a private
/// key password (AD-21, AD-35).</p>
Parameter SSLVALIDATION = "SSL.VALIDATION";

Parameter REASONSSLVALIDATION = "The SSL/TLS configuration was refused.";

/// <p>Violation code: a create supplied no name.</p>
Parameter SSLNAMEREQUIRED = "SSL.NAME.REQUIRED";

Parameter REASONSSLNAMEREQUIRED = "Give the configuration a name.";

/// <p>Violation code: the name is longer than <class>Security.SSLConfigs</class> stores, or carries
/// a control character, a slash or a backslash.</p>
Parameter SSLNAMESHAPE = "SSL.NAME.SHAPE";

Parameter REASONSSLNAMESHAPE = "A name is at most 64 characters, with no control character, slash or backslash.";

/// <p>Violation code: a create names a configuration this instance already holds.</p>
Parameter SSLNAMETAKEN = "SSL.NAME.TAKEN";

Parameter REASONSSLNAMETAKEN = "This instance already has an SSL/TLS configuration with that name. Choose a different one.";

/// <p>Machine code (AD-12, AD-39): the configuration a form read, an edit or a Test connection names
/// is not one this instance holds. Rendered on the <parameter>NOTFOUND</parameter> slug.</p>
Parameter SSLNAMEABSENT = "SSL.NAME.ABSENT";

Parameter REASONSSLNAMEABSENT = "This instance has no SSL/TLS configuration with that name.";

/// <p>Violation code: a create omits its type, its peer verification or whether it is enabled,
/// which the vendor requires of a new configuration.</p>
Parameter SSLFIELDREQUIRED = "SSL.FIELD.REQUIRED";

Parameter REASONSSLFIELDREQUIRED = "A new configuration needs its type, its peer verification and whether it is enabled.";

/// <p>Violation code: the description is not text, or is longer than the vendor stores.</p>
Parameter SSLDESCRIPTIONLENGTH = "SSL.DESCRIPTION.LENGTH";

Parameter REASONSSLDESCRIPTIONLENGTH = "A description is at most 256 characters.";

/// <p>Violation code: <code>Enabled</code> is not a boolean.</p>
Parameter SSLENABLEDSHAPE = "SSL.ENABLED.SHAPE";

Parameter REASONSSLENABLEDSHAPE = "Enabled is either on or off.";

/// <p>Violation code: the type is neither client (0) nor server (1).</p>
Parameter SSLTYPEVALUE = "SSL.TYPE.VALUE";

Parameter REASONSSLTYPEVALUE = "The type is client or server.";

/// <p>Violation code: the type is server while the configuration names no certificate file or no
/// private key file (vendor error 982). A create names neither, so a create is always a client.</p>
Parameter SSLTYPESERVERFILES = "SSL.TYPE.SERVERFILES";

Parameter REASONSSLTYPESERVERFILES = "A server configuration needs a certificate file and a private key file, and only the classic portal's SSL/TLS Configuration page sets them.";

/// <p>Violation code: the peer verification level is not one this type offers -- none or require
/// for a client; none, request or require for a server (vendor error 725).</p>
Parameter SSLVERIFYPEERVALUE = "SSL.VERIFYPEER.VALUE";

Parameter REASONSSLVERIFYPEERVALUE = "Choose one of the peer verification levels this type offers.";

/// <p>Violation code: peer verification is on and the configuration names no trusted certificates
/// (vendor error 986).</p>
Parameter SSLVERIFYPEERCAREQUIRED = "SSL.VERIFYPEER.CAREQUIRED";

Parameter REASONSSLVERIFYPEERCAREQUIRED = "Verifying the peer needs trusted certificates: choose the operating system's store, or keep the file this configuration names.";

/// <p>Violation code: the verification depth is not a whole number of 0 or more.</p>
Parameter SSLVERIFYDEPTHSHAPE = "SSL.VERIFYDEPTH.SHAPE";

Parameter REASONSSLVERIFYDEPTHSHAPE = "The verification depth is a whole number, 0 or more.";

/// <p>Violation code: the trusted certificates name a location other than the operating system's
/// store or the file the configuration already names. No caller names a path (AD-21).</p>
Parameter SSLCAFILEPATH = "SSL.CAFILE.PATH";

Parameter REASONSSLCAFILEPATH = "Trusted certificates are none, the operating system's store, or the file this configuration already names. Another file is set on the classic portal.";

/// <p>Violation code: the minimum TLS version is not one the vendor offers (vendor error 899).</p>
Parameter SSLTLSMINVERSIONVALUE = "SSL.TLSMINVERSION.VALUE";

Parameter REASONSSLTLSMINVERSIONVALUE = "Choose one of the listed minimum TLS versions.";

/// <p>Violation code: the maximum TLS version is not one the vendor offers (vendor error 899).</p>
Parameter SSLTLSMAXVERSIONVALUE = "SSL.TLSMAXVERSION.VALUE";

Parameter REASONSSLTLSMAXVERSIONVALUE = "Choose one of the listed maximum TLS versions.";

/// <p>Violation code: the maximum TLS version is lower than the minimum (vendor error 899).</p>
Parameter SSLTLSMAXVERSIONORDER = "SSL.TLSMAXVERSION.ORDER";

Parameter REASONSSLTLSMAXVERSIONORDER = "The maximum TLS version cannot be lower than the minimum.";

/// <p>Violation code: the Diffie-Hellman key size is not one the vendor offers.</p>
Parameter SSLDIFFIEHELLMANBITSVALUE = "SSL.DIFFIEHELLMANBITS.VALUE";

Parameter REASONSSLDIFFIEHELLMANBITSVALUE = "Choose one of the listed Diffie-Hellman key sizes.";

/// <p>Violation code: an entry of the TLS 1.2 cipher list is empty or carries a colon or a space.</p>
Parameter SSLCIPHERLISTSHAPE = "SSL.CIPHERLIST.SHAPE";

Parameter REASONSSLCIPHERLISTSHAPE = "Each TLS 1.2 cipher entry is one name, with no colon and no space.";

/// <p>Violation code: the TLS 1.2 cipher list is longer than the vendor stores once joined.</p>
Parameter SSLCIPHERLISTLENGTH = "SSL.CIPHERLIST.LENGTH";

Parameter REASONSSLCIPHERLISTLENGTH = "The TLS 1.2 cipher list is at most 4096 characters once joined.";

/// <p>Violation code: the TLS 1.2 cipher list selects no cipher (vendor error 726, mapped by the
/// port).</p>
Parameter SSLCIPHERLISTEXPANDSEMPTY = "SSL.CIPHERLIST.EXPANDSEMPTY";

Parameter REASONSSLCIPHERLISTEXPANDSEMPTY = "This cipher list selects no cipher. Add an entry that names at least one.";

/// <p>Violation code: an entry of the TLS 1.3 cipher suites is empty or carries a colon or a
/// space.</p>
Parameter SSLCIPHERSUITESSHAPE = "SSL.CIPHERSUITES.SHAPE";

Parameter REASONSSLCIPHERSUITESSHAPE = "Each TLS 1.3 cipher suite is one name, with no colon and no space.";

/// <p>Violation code: the TLS 1.3 cipher suites are longer than the vendor stores once joined.</p>
Parameter SSLCIPHERSUITESLENGTH = "SSL.CIPHERSUITES.LENGTH";

Parameter REASONSSLCIPHERSUITESLENGTH = "The TLS 1.3 cipher suites are at most 128 characters once joined.";

/// <p>Violation code: a TLS 1.3 cipher suite is not one this instance knows (vendor error 746,
/// mapped by the port).</p>
Parameter SSLCIPHERSUITESUNKNOWN = "SSL.CIPHERSUITES.UNKNOWN";

Parameter REASONSSLCIPHERSUITESUNKNOWN = "This instance does not know one of these TLS 1.3 cipher suites.";

/// <p>Violation code: OCSP is neither off (0) nor on (1).</p>
Parameter SSLOCSPVALUE = "SSL.OCSP.VALUE";

Parameter REASONSSLOCSPVALUE = "OCSP is either on or off.";

/// <p>Violation code: the OCSP timeout is not a whole number of 0 or more.</p>
Parameter SSLOCSPTIMEOUTSHAPE = "SSL.OCSPTIMEOUT.SHAPE";

Parameter REASONSSLOCSPTIMEOUTSHAPE = "The OCSP timeout is a whole number of seconds, 0 or more.";

/// <p>Violation code: a private key password was given for a configuration that names no private
/// key file (vendor error 985).</p>
Parameter SSLPRIVATEKEYPASSWORDKEYFILE = "SSL.PRIVATEKEYPASSWORD.KEYFILE";

Parameter REASONSSLPRIVATEKEYPASSWORDKEYFILE = "A private key password needs a private key file, and only the classic portal sets one.";

/// <p>Violation code: the private key password is longer than the vendor stores. Refused before the
/// save, whose datatype refusal would quote the value.</p>
Parameter SSLPRIVATEKEYPASSWORDLENGTH = "SSL.PRIVATEKEYPASSWORD.LENGTH";

Parameter REASONSSLPRIVATEKEYPASSWORDLENGTH = "A private key password is at most 255 characters.";

/// <p>Violation code: the private key password does not decrypt the configuration's private key file
/// (vendor error 732, mapped by the port, whose own text names the file and is logged alone).</p>
Parameter SSLPRIVATEKEYPASSWORDWRONG = "SSL.PRIVATEKEYPASSWORD.WRONG";

Parameter REASONSSLPRIVATEKEYPASSWORDWRONG = "This password does not decrypt the configuration's private key.";

/// <p>Violation code: a Test connection host is empty, longer than 255 characters, or carries a
/// space or a scheme.</p>
Parameter SSLTESTHOST = "SSL.TEST.HOST";

Parameter REASONSSLTESTHOST = "Give a host name or address of at most 255 characters, with no space and no scheme.";

/// <p>Violation code: a Test connection port is not a whole number from 1 to 65535.</p>
Parameter SSLTESTPORT = "SSL.TEST.PORT";

Parameter REASONSSLTESTPORT = "The port is a whole number from 1 to 65535.";

/// <p>The sentence an <code>SSL.*</code> violation code carries, or <code>""</code> for any other
/// code; <method>ReasonForViolation</method> delegates the family here.</p>
ClassMethod ReasonForSsl(pCode As %String) As %String
{
    If '$ListFind(..SslViolationCodes(), pCode) Quit ""
    Quit $Parameter($ClassName(), "REASON" _ $Translate(pCode, "."))
}

/// <p>Every <code>SSL.*</code> field-level violation code, as a <class>%List</class>, for the reason
/// <method>UserViolationCodes</method> exists.</p>
ClassMethod SslViolationCodes() As %List
{
    Quit $ListBuild(..#SSLNAMEREQUIRED, ..#SSLNAMESHAPE, ..#SSLNAMETAKEN, ..#SSLNAMEABSENT, ..#SSLFIELDREQUIRED, ..#SSLDESCRIPTIONLENGTH, ..#SSLENABLEDSHAPE, ..#SSLTYPEVALUE, ..#SSLTYPESERVERFILES, ..#SSLVERIFYPEERVALUE, ..#SSLVERIFYPEERCAREQUIRED, ..#SSLVERIFYDEPTHSHAPE, ..#SSLCAFILEPATH, ..#SSLTLSMINVERSIONVALUE, ..#SSLTLSMAXVERSIONVALUE, ..#SSLTLSMAXVERSIONORDER, ..#SSLDIFFIEHELLMANBITSVALUE, ..#SSLCIPHERLISTSHAPE, ..#SSLCIPHERLISTLENGTH, ..#SSLCIPHERLISTEXPANDSEMPTY, ..#SSLCIPHERSUITESSHAPE, ..#SSLCIPHERSUITESLENGTH, ..#SSLCIPHERSUITESUNKNOWN, ..#SSLOCSPVALUE, ..#SSLOCSPTIMEOUTSHAPE, ..#SSLPRIVATEKEYPASSWORDKEYFILE, ..#SSLPRIVATEKEYPASSWORDLENGTH, ..#SSLPRIVATEKEYPASSWORDWRONG, ..#SSLTESTHOST, ..#SSLTESTPORT)
}

/// <p>Envelope code (AD-39): a task create broke one or more of the rules
/// <class>OcuPilot.Area.Task.TaskRules</class> applies before the port is touched, or the vendor
/// refused a value on a field. <code>detail.violations</code> carries each.</p>
Parameter TASKVALIDATION = "TASK.VALIDATION";

Parameter REASONTASKVALIDATION = "The task was refused.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKNAMEREQUIRED = "TASK.NAME.REQUIRED";

Parameter REASONTASKNAMEREQUIRED = "Give the task a name.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKNAMESHAPE = "TASK.NAME.SHAPE";

Parameter REASONTASKNAMESHAPE = "A task name is at most 50 characters and starts with a letter.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKNAMETAKEN = "TASK.NAME.TAKEN";

Parameter REASONTASKNAMETAKEN = "This instance already has a task with that name. Choose a different one.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDESCRIPTIONLENGTH = "TASK.DESCRIPTION.LENGTH";

Parameter REASONTASKDESCRIPTIONLENGTH = "A description is at most 100 characters.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKNAMESPACEUNKNOWN = "TASK.NAMESPACE.UNKNOWN";

Parameter REASONTASKNAMESPACEUNKNOWN = "Choose a namespace you can read on this instance.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTASKCLASSREQUIRED = "TASK.TASKCLASS.REQUIRED";

Parameter REASONTASKTASKCLASSREQUIRED = "Choose a task type.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTASKCLASSUNKNOWN = "TASK.TASKCLASS.UNKNOWN";

Parameter REASONTASKTASKCLASSUNKNOWN = "That task type is not available in the chosen namespace.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTASKCLASSPERMISSION = "TASK.TASKCLASS.PERMISSION";

Parameter REASONTASKTASKCLASSPERMISSION = "This task type needs a privilege you do not hold.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSETTINGUNKNOWN = "TASK.SETTING.UNKNOWN";

Parameter REASONTASKSETTINGUNKNOWN = "The chosen task type has no such setting.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSETTINGINVALID = "TASK.SETTING.INVALID";

Parameter REASONTASKSETTINGINVALID = "The task type does not accept this value.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSETTINGREQUIRED = "TASK.SETTING.REQUIRED";

Parameter REASONTASKSETTINGREQUIRED = "The task type needs this setting.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSETTINGSECRET = "TASK.SETTING.SECRET";

Parameter REASONTASKSETTINGSECRET = "This setting holds a credential, and only the classic portal's Task Scheduler Wizard sets it.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSETTINGCLASSICONLY = "TASK.SETTING.CLASSICONLY";

Parameter REASONTASKSETTINGCLASSICONLY = "This setting is a list, and only the classic portal's Task Scheduler Wizard sets it.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTIMEPERIODVALUE = "TASK.TIMEPERIOD.VALUE";

Parameter REASONTASKTIMEPERIODVALUE = "Choose how often the task runs.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTIMEPERIODEVERYRANGE = "TASK.TIMEPERIODEVERY.RANGE";

Parameter REASONTASKTIMEPERIODEVERYRANGE = "The interval is 1 to 7 days, 1 to 5 weeks, or 1 to 12 months, as the schedule reads it.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTIMEPERIODDAYVALUE = "TASK.TIMEPERIODDAY.VALUE";

Parameter REASONTASKTIMEPERIODDAYVALUE = "Choose the day or days this schedule runs on.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKRUNAFTERGUIDUNKNOWN = "TASK.RUNAFTERGUID.UNKNOWN";

Parameter REASONTASKRUNAFTERGUIDUNKNOWN = "Choose a task on this instance to run after.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYFREQUENCYVALUE = "TASK.DAILYFREQUENCY.VALUE";

Parameter REASONTASKDAILYFREQUENCYVALUE = "Choose whether the task runs once or several times a day.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYFREQUENCYTIMEREQUIRED = "TASK.DAILYFREQUENCYTIME.REQUIRED";

Parameter REASONTASKDAILYFREQUENCYTIMEREQUIRED = "Choose whether the interval is in minutes or hours.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYINCREMENTREQUIRED = "TASK.DAILYINCREMENT.REQUIRED";

Parameter REASONTASKDAILYINCREMENTREQUIRED = "Give how long to wait between runs.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYINCREMENTRANGE = "TASK.DAILYINCREMENT.RANGE";

Parameter REASONTASKDAILYINCREMENTRANGE = "The interval is 1 to 1440 minutes, or 1 to 24 hours.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYSTARTTIMESHAPE = "TASK.DAILYSTARTTIME.SHAPE";

Parameter REASONTASKDAILYSTARTTIMESHAPE = "Give a time as HH:MM, from 00:00 to 23:59.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYENDTIMESHAPE = "TASK.DAILYENDTIME.SHAPE";

Parameter REASONTASKDAILYENDTIMESHAPE = "Give the last run's time as HH:MM, from 00:00 to 23:59.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYENDTIMEORDER = "TASK.DAILYENDTIME.ORDER";

Parameter REASONTASKDAILYENDTIMEORDER = "The last run's time must be later than the first.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSTARTDATEREQUIRED = "TASK.STARTDATE.REQUIRED";

Parameter REASONTASKSTARTDATEREQUIRED = "Give the date of the first run.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSTARTDATESHAPE = "TASK.STARTDATE.SHAPE";

Parameter REASONTASKSTARTDATESHAPE = "Give a date as YYYY-MM-DD.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSTARTDATEPAST = "TASK.STARTDATE.PAST";

Parameter REASONTASKSTARTDATEPAST = "The first run must be later than now on this instance's clock.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKENDDATESHAPE = "TASK.ENDDATE.SHAPE";

Parameter REASONTASKENDDATESHAPE = "Give the end date as YYYY-MM-DD, or leave it empty.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKENDDATEORDER = "TASK.ENDDATE.ORDER";

Parameter REASONTASKENDDATEORDER = "The end date must be later than the start date.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKEXPIRESDAYSRANGE = "TASK.EXPIRESDAYS.RANGE";

Parameter REASONTASKEXPIRESDAYSRANGE = "Days is a whole number from 0 to 999.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKEXPIRESHOURSRANGE = "TASK.EXPIRESHOURS.RANGE";

Parameter REASONTASKEXPIRESHOURSRANGE = "Hours is a whole number from 0 to 24.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKEXPIRESMINUTESRANGE = "TASK.EXPIRESMINUTES.RANGE";

Parameter REASONTASKEXPIRESMINUTESRANGE = "Minutes is a whole number from 0 to 60.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKRUNASUSERSECURE = "TASK.RUNASUSER.SECURE";

Parameter REASONTASKRUNASUSERSECURE = "Running a task as another account needs %Admin_Secure:USE, which you do not hold.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKRUNASUSERUNKNOWN = "TASK.RUNASUSER.UNKNOWN";

Parameter REASONTASKRUNASUSERUNKNOWN = "This instance has no account with that name.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKRUNASUSERDISABLED = "TASK.RUNASUSER.DISABLED";

Parameter REASONTASKRUNASUSERDISABLED = "That account is disabled, so a task cannot run as it.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKPRIORITYVALUE = "TASK.PRIORITY.VALUE";

Parameter REASONTASKPRIORITYVALUE = "Choose Normal, Low or High.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKMIRRORSTATUSVALUE = "TASK.MIRRORSTATUS.VALUE";

Parameter REASONTASKMIRRORSTATUSVALUE = "Choose Primary, Non-Primary or Any.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKOUTPUTFILENAMESHAPE = "TASK.OUTPUTFILENAME.SHAPE";

Parameter REASONTASKOUTPUTFILENAMESHAPE = "Give one file name ending in .txt, of letters, digits, dots, dashes and underscores, with no folder.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKEMAILONCOMPLETIONSHAPE = "TASK.EMAILONCOMPLETION.SHAPE";

Parameter REASONTASKEMAILONCOMPLETIONSHAPE = "Give email addresses separated by commas, each like name@example.com.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKEMAILONERRORSHAPE = "TASK.EMAILONERROR.SHAPE";

Parameter REASONTASKEMAILONERRORSHAPE = "Give email addresses separated by commas, each like name@example.com.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKEMAILONEXPIRATIONSHAPE = "TASK.EMAILONEXPIRATION.SHAPE";

Parameter REASONTASKEMAILONEXPIRATIONSHAPE = "Give email addresses separated by commas, each like name@example.com.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKFIELDSHAPE = "TASK.FIELD.SHAPE";

Parameter REASONTASKFIELDSHAPE = "This value is not the kind this field takes.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKRUNASUSERREFUSED = "TASK.RUNASUSER.REFUSED";

Parameter REASONTASKRUNASUSERREFUSED = "The instance refused to run the task as this account.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYINCREMENTREFUSED = "TASK.DAILYINCREMENT.REFUSED";

Parameter REASONTASKDAILYINCREMENTREFUSED = "The instance refused this interval.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYENDTIMEREFUSED = "TASK.DAILYENDTIME.REFUSED";

Parameter REASONTASKDAILYENDTIMEREFUSED = "The instance refused this last run's time.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKENDDATEREFUSED = "TASK.ENDDATE.REFUSED";

Parameter REASONTASKENDDATEREFUSED = "The instance refused this end date.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTIMEPERIODDAYREFUSED = "TASK.TIMEPERIODDAY.REFUSED";

Parameter REASONTASKTIMEPERIODDAYREFUSED = "The instance refused these run days.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKOUTPUTFILENAMEREFUSED = "TASK.OUTPUTFILENAME.REFUSED";

Parameter REASONTASKOUTPUTFILENAMEREFUSED = "The instance refused this output file.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTASKCLASSREFUSED = "TASK.TASKCLASS.REFUSED";

Parameter REASONTASKTASKCLASSREFUSED = "The instance refused this task type, or a privilege it needs is missing.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKTIMEPERIODEVERYREFUSED = "TASK.TIMEPERIODEVERY.REFUSED";

Parameter REASONTASKTIMEPERIODEVERYREFUSED = "The instance refused this interval between runs.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKDAILYFREQUENCYTIMEREFUSED = "TASK.DAILYFREQUENCYTIME.REFUSED";

Parameter REASONTASKDAILYFREQUENCYTIMEREFUSED = "The instance refused this interval's unit.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKRUNAFTERGUIDREFUSED = "TASK.RUNAFTERGUID.REFUSED";

Parameter REASONTASKRUNAFTERGUIDREFUSED = "The instance refused the task to run after.";

/// <p>Violation code (Story 9.7).</p>
Parameter TASKSTARTDATEREFUSED = "TASK.STARTDATE.REFUSED";

Parameter REASONTASKSTARTDATEREFUSED = "The instance refused this start, which must be later than now.";

/// <p>Envelope code (Story 9.8): the task an edit names is not on this instance.</p>
Parameter TASKABSENT = "TASK.ABSENT";

Parameter REASONTASKABSENT = "This task no longer exists.";

/// <p>Violation code (Story 9.8): the task writes its output to a directory OcuPilot never sets.</p>
Parameter TASKOUTPUTFILENAMECLASSICONLY = "TASK.OUTPUTFILENAME.CLASSICONLY";

Parameter REASONTASKOUTPUTFILENAMECLASSICONLY = "This task writes its output to a folder only the classic portal's Task Scheduler Wizard sets, so change its output file there.";

/// <p>The sentence a <code>TASK.*</code> violation code carries, or <code>""</code> for any other
/// code; <method>ReasonForViolation</method> delegates the family here.</p>
ClassMethod ReasonForTask(pCode As %String) As %String
{
    If '$ListFind(..TaskViolationCodes(), pCode) Quit ""
    Quit $Parameter($ClassName(), "REASON" _ $Translate(pCode, "."))
}

/// <p>Every <code>TASK.*</code> field-level violation code, as a <class>%List</class>, for the reason
/// <method>UserViolationCodes</method> exists.</p>
ClassMethod TaskViolationCodes() As %List
{
    Quit $ListBuild(..#TASKNAMEREQUIRED, ..#TASKNAMESHAPE, ..#TASKNAMETAKEN, ..#TASKDESCRIPTIONLENGTH, ..#TASKNAMESPACEUNKNOWN, ..#TASKTASKCLASSREQUIRED, ..#TASKTASKCLASSUNKNOWN, ..#TASKTASKCLASSPERMISSION, ..#TASKSETTINGUNKNOWN, ..#TASKSETTINGINVALID, ..#TASKSETTINGREQUIRED, ..#TASKSETTINGSECRET, ..#TASKSETTINGCLASSICONLY, ..#TASKTIMEPERIODVALUE, ..#TASKTIMEPERIODEVERYRANGE, ..#TASKTIMEPERIODDAYVALUE, ..#TASKRUNAFTERGUIDUNKNOWN, ..#TASKDAILYFREQUENCYVALUE, ..#TASKDAILYFREQUENCYTIMEREQUIRED, ..#TASKDAILYINCREMENTREQUIRED, ..#TASKDAILYINCREMENTRANGE, ..#TASKDAILYSTARTTIMESHAPE, ..#TASKDAILYENDTIMESHAPE, ..#TASKDAILYENDTIMEORDER, ..#TASKSTARTDATEREQUIRED, ..#TASKSTARTDATESHAPE, ..#TASKSTARTDATEPAST, ..#TASKENDDATESHAPE, ..#TASKENDDATEORDER, ..#TASKEXPIRESDAYSRANGE, ..#TASKEXPIRESHOURSRANGE, ..#TASKEXPIRESMINUTESRANGE, ..#TASKRUNASUSERSECURE, ..#TASKRUNASUSERUNKNOWN, ..#TASKRUNASUSERDISABLED, ..#TASKPRIORITYVALUE, ..#TASKMIRRORSTATUSVALUE, ..#TASKOUTPUTFILENAMESHAPE, ..#TASKEMAILONCOMPLETIONSHAPE, ..#TASKEMAILONERRORSHAPE, ..#TASKEMAILONEXPIRATIONSHAPE, ..#TASKFIELDSHAPE, ..#TASKRUNASUSERREFUSED, ..#TASKDAILYINCREMENTREFUSED, ..#TASKDAILYENDTIMEREFUSED, ..#TASKENDDATEREFUSED, ..#TASKTIMEPERIODDAYREFUSED, ..#TASKOUTPUTFILENAMEREFUSED, ..#TASKTASKCLASSREFUSED, ..#TASKTIMEPERIODEVERYREFUSED, ..#TASKDAILYFREQUENCYTIMEREFUSED, ..#TASKRUNAFTERGUIDREFUSED, ..#TASKSTARTDATEREFUSED, ..#TASKABSENT, ..#TASKOUTPUTFILENAMECLASSICONLY)
}

/// <p>Envelope code (Story 9.9): one 422 carrying every broken rule of a service Save.</p>
Parameter SERVICEVALIDATION = "SERVICE.VALIDATION";

Parameter REASONSERVICEVALIDATION = "The service change was refused.";

/// <p>Envelope code (Story 9.9): the service a form read or a Save names is not on this instance.</p>
Parameter SERVICEABSENT = "SERVICE.ABSENT";

Parameter REASONSERVICEABSENT = "This service no longer exists.";

/// <p>Violation code (Story 9.9): an allowed-connection entry that is empty or holds whitespace or a
/// semicolon, which the vendor splits into two entries (measured).</p>
Parameter SERVICEADDRESSSHAPE = "SERVICE.ADDRESS.SHAPE";

Parameter REASONSERVICEADDRESSSHAPE = "An allowed connection is one address, with no spaces or semicolons.";

/// <p>Violation code (Story 9.9): an allowed-connection entry names a role this instance does not
/// hold, which the vendor accepts silently (measured).</p>
Parameter SERVICEADDRESSROLE = "SERVICE.ADDRESS.ROLE";

Parameter REASONSERVICEADDRESSROLE = "A role named for this address does not exist on this instance.";

/// <p>Violation code (Story 9.9): an authentication method the service does not support, which the
/// vendor masks away and answers 200 (measured).</p>
Parameter SERVICEAUTHEUNSUPPORTED = "SERVICE.AUTHE.UNSUPPORTED";

Parameter REASONSERVICEAUTHEUNSUPPORTED = "This service does not support one of the authentication methods chosen.";

/// <p>Envelope code (Story 9.9): one 422 carrying every broken rule of an LDAP configuration Save.</p>
Parameter LDAPVALIDATION = "LDAP.VALIDATION";

Parameter REASONLDAPVALIDATION = "The LDAP configuration change was refused.";

/// <p>Envelope code (Story 9.9): the LDAP configuration a form read or a Save names is not on this
/// instance.</p>
Parameter LDAPABSENT = "LDAP.ABSENT";

Parameter REASONLDAPABSENT = "This LDAP configuration no longer exists.";

/// <p>Violation code (Story 9.9): a setting <class>Security.LDAPConfigs</class> declares
/// <code>Required</code> sent empty.</p>
Parameter LDAPFIELDREQUIRED = "LDAP.FIELD.REQUIRED";

Parameter REASONLDAPFIELDREQUIRED = "This LDAP setting cannot be empty.";

/// <p>Violation code (Story 9.9): an empty host entry, or one holding whitespace; the vendor joins
/// host names with a space.</p>
Parameter LDAPHOSTSHAPE = "LDAP.HOST.SHAPE";

Parameter REASONLDAPHOSTSHAPE = "A host name is one name, optionally followed by :port, with no spaces.";

/// <p>Violation code (Story 9.9): <code>LDAPFlags</code> outside the whole numbers 0 to 255.</p>
Parameter LDAPFLAGSVALUE = "LDAP.FLAGS.VALUE";

Parameter REASONLDAPFLAGSVALUE = "The LDAP flags are a whole number from 0 to 255.";

/// <p>Violation code (Story 9.9): a description longer than the vendor's 128 characters.</p>
Parameter LDAPDESCRIPTIONLENGTH = "LDAP.DESCRIPTION.LENGTH";

Parameter REASONLDAPDESCRIPTIONLENGTH = "An LDAP configuration's description is at most 128 characters.";

/// <p>The sentence a <code>SERVICE.*</code> violation code carries, or <code>""</code> for any other
/// code; <method>ReasonForViolation</method> delegates the family here.</p>
ClassMethod ReasonForService(pCode As %String) As %String
{
    If '$ListFind(..ServiceViolationCodes(), pCode) Quit ""
    Quit $Parameter($ClassName(), "REASON" _ $Translate(pCode, "."))
}

/// <p>Every <code>SERVICE.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod ServiceViolationCodes() As %List
{
    Quit $ListBuild(..#SERVICEADDRESSSHAPE, ..#SERVICEADDRESSROLE, ..#SERVICEAUTHEUNSUPPORTED, ..#SERVICEABSENT)
}

/// <p>The sentence an <code>LDAP.*</code> violation code carries, or <code>""</code> for any other
/// code; <method>ReasonForViolation</method> delegates the family here.</p>
ClassMethod ReasonForLdap(pCode As %String) As %String
{
    If '$ListFind(..LdapViolationCodes(), pCode) Quit ""
    Quit $Parameter($ClassName(), "REASON" _ $Translate(pCode, "."))
}

/// <p>Every <code>LDAP.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod LdapViolationCodes() As %List
{
    Quit $ListBuild(..#LDAPFIELDREQUIRED, ..#LDAPHOSTSHAPE, ..#LDAPFLAGSVALUE, ..#LDAPDESCRIPTIONLENGTH, ..#LDAPABSENT)
}

/// <p>Envelope code (Story 9.10): one 422 carrying every broken rule of a user audit event Save.</p>
Parameter AUDITEVENTVALIDATION = "AUDITEVENT.VALIDATION";

Parameter REASONAUDITEVENTVALIDATION = "The audit event was refused.";

/// <p>Violation code (Story 9.10): an empty Source, Type or Name, which the vendor answers
/// <code>&lt;SUBSCRIPT&gt;</code> (measured).</p>
Parameter AUDITEVENTPARTREQUIRED = "AUDITEVENT.PART.REQUIRED";

Parameter REASONAUDITEVENTPARTREQUIRED = "Enter a value. An audit event is named by its source, type and name.";

/// <p>Violation code (Story 9.10): a Source, Type or Name over the vendor's 64 characters.</p>
Parameter AUDITEVENTPARTLENGTH = "AUDITEVENT.PART.LENGTH";

Parameter REASONAUDITEVENTPARTLENGTH = "Use 64 characters or fewer.";

/// <p>Violation code (Story 9.10): a <code>/</code> in a Source, Type or Name, which the vendor refuses
/// or fails on (measured).</p>
Parameter AUDITEVENTPARTSLASH = "AUDITEVENT.PART.SLASH";

Parameter REASONAUDITEVENTPARTSLASH = "Remove the slash. An event's source, type and name are joined with slashes, so none of them can contain one.";

/// <p>Violation code (Story 9.10): a Source or Type beginning with <code>%</code>, which the vendor
/// refuses #851 (measured).</p>
Parameter AUDITEVENTPARTRESERVED = "AUDITEVENT.PART.RESERVED";

Parameter REASONAUDITEVENTPARTRESERVED = "Start with a character other than %. A source or type beginning with % is reserved for the instance's own system events.";

/// <p>Violation code (Story 9.10): a Description over the vendor's 256 characters.</p>
Parameter AUDITEVENTDESCRIPTIONLENGTH = "AUDITEVENT.DESCRIPTION.LENGTH";

Parameter REASONAUDITEVENTDESCRIPTIONLENGTH = "Use 256 characters or fewer.";

/// <p>Violation code (Story 9.10): an event id that is not exactly three <code>/</code>-separated
/// parts.</p>
Parameter AUDITEVENTEVENTNAMESHAPE = "AUDITEVENT.EVENTNAME.SHAPE";

Parameter REASONAUDITEVENTEVENTNAMESHAPE = "Name the event as source/type/name: three parts, none containing a slash.";

/// <p>Violation and envelope code (Story 9.10): a user event tool given a system event.</p>
Parameter AUDITEVENTSYSTEM = "AUDITEVENT.SYSTEM";

Parameter REASONAUDITEVENTSYSTEM = "This is one of the instance's own system events. Change it on the System events list.";

/// <p>Violation code (Story 9.10): a system event tool given a user event.</p>
Parameter AUDITEVENTUSER = "AUDITEVENT.USER";

Parameter REASONAUDITEVENTUSER = "This is a user event. Change it on the User events list.";

/// <p>Violation code (Story 9.10): a create whose event the instance already holds, in any case.</p>
Parameter AUDITEVENTTAKEN = "AUDITEVENT.TAKEN";

Parameter REASONAUDITEVENTTAKEN = "This instance already has an audit event with this source, type and name.";

/// <p>Violation and envelope code (Story 9.10): the event a form read or an edit names is not on this
/// instance.</p>
Parameter AUDITEVENTABSENT = "AUDITEVENT.ABSENT";

Parameter REASONAUDITEVENTABSENT = "This audit event no longer exists.";

/// <p>The sentence an <code>AUDITEVENT.*</code> violation code carries, or <code>""</code> for any
/// other code; <method>ReasonForViolation</method> delegates the family here.</p>
ClassMethod ReasonForAuditEvent(pCode As %String) As %String
{
    If '$ListFind(..AuditEventViolationCodes(), pCode) Quit ""
    Quit $Parameter($ClassName(), "REASON" _ $Translate(pCode, "."))
}

/// <p>Every <code>AUDITEVENT.*</code> field-level violation code, as a <class>%List</class>, for the
/// reason <method>UserViolationCodes</method> exists.</p>
ClassMethod AuditEventViolationCodes() As %List
{
    Quit $ListBuild(..#AUDITEVENTPARTREQUIRED, ..#AUDITEVENTPARTLENGTH, ..#AUDITEVENTPARTSLASH, ..#AUDITEVENTPARTRESERVED, ..#AUDITEVENTDESCRIPTIONLENGTH, ..#AUDITEVENTEVENTNAMESHAPE, ..#AUDITEVENTSYSTEM, ..#AUDITEVENTUSER, ..#AUDITEVENTTAKEN, ..#AUDITEVENTABSENT)
}

/// <p>Machine code (AD-12, AD-39, AD-42): the provider ended the reply because the model's tool call
/// could not be completed -- malformed, not one it was offered, or more calls than the request
/// allowed -- mapped from the canonical
/// <parameter>OcuPilot.Kernel.Provider.MessageAdapter.TOOLCALLFAILEDSTOPREASON</parameter>. A turn
/// ends <code>failed</code> on it with no reply; produced by
/// <class>OcuPilot.Kernel.Agent.Loop</class> on the <parameter>UNAVAILABLE</parameter> slug, with
/// its sentence in <method>OcuPilot.Kernel.Provider.Base.ReasonFor</method>.</p>
Parameter PROVIDERTOOLCALLFAILED = "PROVIDER.TOOLCALLFAILED";

}
