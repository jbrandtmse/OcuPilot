/// <p>Where a streamed model call's text so far goes (AD-33, AD-42). The provider layer holds this
/// contract and never names the turn that implements it, so
/// <package>OcuPilot.Kernel.Provider</package> depends on nothing in
/// <package>OcuPilot.Kernel.Agent</package>.</p>
/// <p><b>Caller contract.</b> <method>Publish</method> is called from inside
/// <method>%Net.ChunkedReader.ReadChunk</method>, while the provider's socket is the current device:
/// an implementation does no device I/O, calls no tool, port or provider, and never raises past
/// its own frame. The text it receives is the whole text so far, never a delta.</p>
Class OcuPilot.Kernel.Provider.StreamSink Extends %RegisteredObject [ Abstract ]
{

/// <p>Take <var>pText</var>, the call's whole text so far. Whether and when to store it is the
/// implementation's choice.</p>
Method Publish(pText As %String) [ Abstract ]
{
    Quit
}

}
