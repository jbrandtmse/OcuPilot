/// <p>A stand-in for the CSP response that records what <class>OcuPilot.Api.Response</class>'s heartbeat
/// does to it: the properties it sets and how many times it flushes. A flush marks the response
/// in progress, as the real one does, and a set after that is a mistake the real property refuses.</p>
Class OcuPilot.Test.ResponseProbe Extends %RegisteredObject
{

Property ContentType As %String;

Property GzipOutput As %Integer [ InitialExpression = 7 ];

Property AllowOutputFlush As %Integer [ InitialExpression = 7 ];

Property InProgress As %Integer [ InitialExpression = 0 ];

Property Flushes As %Integer [ InitialExpression = 0 ];

Method Flush() As %Status
{
    Set ..Flushes = ..Flushes + 1
    Set ..InProgress = 2
    Quit $$$OK
}

}
