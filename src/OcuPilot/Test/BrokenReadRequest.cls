/// <p>A <class>%Net.HttpRequest</class> whose <method>Post</method> opens no socket and fails the
/// way a read that broke mid-response does: it builds the response object the vendor's
/// <code>Send</code> builds before reading, sets the status line only when
/// <property>BrokenStatusLine</property> is non-empty, and answers <code>ERROR #6097</code>. It lets
/// a test run the shipped <method>OcuPilot.Kernel.Provider.Base.IssueHttpsPost</method> over both
/// shapes of a broken read without a server.</p>
Class OcuPilot.Test.BrokenReadRequest Extends %Net.HttpRequest
{

/// <p>The status line read before the break, as <code>HTTP/1.1 200 OK</code>, or <code>""</code>
/// when the connection broke before one arrived.</p>
Property BrokenStatusLine As %String;

/// <p>Answer a broken read without sending anything.</p>
Method Post(pLocation As %String = "", pTest As %Integer = 0, pReset As %Boolean = 1, pResetHeaderOnRedirect As %Boolean = 0) As %Status
{
    Set tResponse = ##class(%Net.HttpResponse).%New()
    If ..BrokenStatusLine '= "" {
        Set tResponse.StatusLine = ..BrokenStatusLine
        Set tResponse.StatusCode = +$Piece(..BrokenStatusLine, " ", 2)
    }
    Set ..HttpResponse = tResponse
    Quit $$$ERROR($$$TCPIPError, "<READ>", 0)
}

}
