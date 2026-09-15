/// <p>A stand-in for <code>%request</code> that lets
/// <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> be driven through all three of its
/// outcomes without a live HTTP request (DW-24).</p>
/// <p><method>ReadRequestBody</method> reads exactly two things off <code>%request</code>:
/// <code>GetMimeData("BODY")</code> and the <code>Content</code> property. Both are
/// resolved at run time against whatever object the variable holds, so an ordinary
/// registered object with those two surfaces is enough. <code>Content</code> is reached
/// through <method>%DispatchGetProperty</method> rather than declared as a property,
/// because the case under test is a read that <b>throws</b> and a property accessor cannot
/// be made to.</p>
/// <p>Test-only, and used only by <class>OcuPilot.Test.Utils</class>.</p>
Class OcuPilot.Test.BodyRequest Extends %RegisteredObject
{

/// <p>When true, reading <code>Content</code> throws instead of returning a stream — the
/// DW-24 fault. When false, it returns <property>Payload</property>, which may itself be
/// empty, and that is the "no body at all" case.</p>
Property FaultOnContent As %Boolean [ InitialExpression = 0 ];

/// <p>What a non-faulting <code>Content</code> read yields. Empty means the request carried
/// no body.</p>
Property Payload As %Stream.Object;

/// <p>What <method>GetMimeData</method> yields. Empty means the MIME branch does not apply
/// and <property>Payload</property> is consulted instead.</p>
Property MimePayload As %Stream.Object;

/// <p>The <code>%request.GetMimeData("BODY")</code> surface. Returns
/// <property>MimePayload</property>, or the empty string when none is set — which is what
/// <method>ReadRequestBody</method>'s <code>'$IsObject</code> test looks for.</p>
Method GetMimeData(pName As %String = "") As %Stream.Object
{
    If $IsObject(..MimePayload) Quit ..MimePayload
    Quit ""
}

/// <p>Catches <code>%request.Content</code>. Throws when
/// <property>FaultOnContent</property> is set; otherwise hands back
/// <property>Payload</property>. Any other property name yields the empty string rather
/// than an error, so a later change to <method>ReadRequestBody</method> that reads one more
/// field fails on the assertion rather than on this stub.</p>
Method %DispatchGetProperty(pProperty As %String)
{
    If pProperty '= "Content" Quit ""
    If ..FaultOnContent {
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "OcuPilot test: the request content stream could not be read"))
    }
    If $IsObject(..Payload) Quit ..Payload
    Quit ""
}

}
