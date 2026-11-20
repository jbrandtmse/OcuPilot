/// <p>The mint <class>OcuPilot.Screen.Tool.SqlActivityCancel</class> declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13): <class>OcuPilot.Screen.Tool.BackgroundTaskMint</class>,
/// joining the agent's <code>server</code>, process id and <code>statementHash</code> as one composite target id, the grammar
/// the screen sends. Everything else is that mint's, unchanged.</p>
/// <p>Refused before anything is read, with 400 <code>TOOL.ARGUMENTS</code>: an argument carrying
/// <code>$Char(1)</code>, the composite separator, which would let one argument stand for two parts.</p>
Class OcuPilot.Screen.Tool.SqlActivityMint Extends OcuPilot.Screen.Tool.BackgroundTaskMint
{

/// <p>The argument naming the row's server.</p>
Parameter SERVERARGUMENT = "server";

/// <p>The argument naming the row's statement hash.</p>
Parameter HASHARGUMENT = "statementHash";

/// <p>The composite target id's parts: the row's server, its process id <var>pIdValue</var> and its statement hash.</p>
ClassMethod CompositeParts(pArgs As %DynamicObject, pIdValue As %String, Output pProblem As %String) As %List
{
    Set pProblem = ""
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
    Set tServer = ""
    Set tHash = ""
    If $IsObject(pArgs) {
        Set tServer = pArgs.%Get(..#SERVERARGUMENT)
        Set tHash = pArgs.%Get(..#HASHARGUMENT)
    }
    If $IsObject(tServer) || $IsObject(tHash) || (tServer [ tSeparator) || (tHash [ tSeparator) || (pIdValue [ tSeparator) {
        Set pProblem = "'server', 'processId' or 'statementHash' carries the character U+0001, which no running statement's server, process id or statement hash holds"
        Quit ""
    }
    Quit $ListBuild(tServer, pIdValue, tHash)
}

}
