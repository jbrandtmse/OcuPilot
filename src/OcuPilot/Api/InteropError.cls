/// <p>The interoperability codes and sentences (AD-29, AD-39, AD-62, Story 20.2): every
/// <code>INTEROP.*</code> code <class>OcuPilot.Port.InteropPort</class> answers with, the four
/// consequence codes the production tools' proposals carry, and the sentence each carries. Each sentence
/// is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/interop.test.mjs</file>. They
/// live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290).</p>
/// <p>Every refusal is rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409:
/// the vendor would have answered each as a success or a refusal that leaves the production as it was.</p>
Class OcuPilot.Api.InteropError Extends %RegisteredObject
{

/// <p>The route's namespace does not run interoperability productions.</p>
Parameter NAMESPACE = "INTEROP.NAMESPACE";

Parameter REASONNAMESPACE = "This namespace does not run interoperability productions.";

/// <p>Start of a production that is running.</p>
Parameter RUNNING = "INTEROP.PRODUCTION.RUNNING";

Parameter REASONRUNNING = "This production is already running.";

/// <p>Start of a production while another is current in the namespace (running, suspended or
/// troubled).</p>
Parameter OTHER = "INTEROP.PRODUCTION.OTHER";

Parameter REASONOTHER = "Another production is running, suspended or troubled in this namespace, and a namespace runs one production at a time.";

/// <p>Start of a production that did not shut down cleanly.</p>
Parameter TROUBLED = "INTEROP.PRODUCTION.TROUBLED";

Parameter REASONTROUBLED = "This production did not shut down cleanly. Recover it first; once it reads Suspended it can be started.";

/// <p>Stop, restart or update of a production that is not running.</p>
Parameter NOTRUNNING = "INTEROP.PRODUCTION.NOTRUNNING";

Parameter REASONNOTRUNNING = "This production is not running.";

/// <p>Update of a production with nothing pending.</p>
Parameter UPTODATE = "INTEROP.PRODUCTION.UPTODATE";

Parameter REASONUPTODATE = "This production is up to date, so there is nothing to update.";

/// <p>Recover of a production that is not troubled.</p>
Parameter NOTTROUBLED = "INTEROP.PRODUCTION.NOTTROUBLED";

Parameter REASONNOTTROUBLED = "Only a troubled production can be recovered.";

/// <p>The vendor refused a stop, restart or update because the production's work in progress did not
/// finish within the wait; the production is as it was.</p>
Parameter BUSY = "INTEROP.PRODUCTION.BUSY";

Parameter REASONBUSY = "The production's work in progress did not finish within 15 seconds, so it was left as it was.";

/// <p>The production's state is not one of Running, Stopped, Suspended and Troubled.</p>
Parameter STATE = "INTEROP.PRODUCTION.STATE";

Parameter REASONSTATE = "This production's state does not allow that action here.";

/// <p>The consequence codes the stop, restart, update and recover proposals carry. The client maps each
/// to its warning sentence (<file>ui/src/app/core/proposal-view.ts</file>).</p>
Parameter STOP = "INTEROP.STOP";

Parameter REASONSTOP = "Stopping this production waits up to 15 seconds for its work in progress to finish. If it takes longer, nothing is stopped; if a job then takes longer than 15 seconds to stop, the production is left partly stopped.";

Parameter RESTART = "INTEROP.RESTART";

Parameter REASONRESTART = "Restarting this production stops it and starts it again. If its work in progress takes longer than 15 seconds to finish, nothing is stopped; if a job then takes longer than 15 seconds to stop, the production is left partly stopped.";

Parameter UPDATE = "INTEROP.UPDATE";

Parameter REASONUPDATE = "Updating this production restarts only the items whose settings changed, and starts or stops the items enabled or disabled since it started. If an item takes longer than 15 seconds to finish its work, the update is refused and the production keeps running.";

Parameter RECOVER = "INTEROP.RECOVER";

Parameter REASONRECOVER = "Recover is the first response to a troubled production: it returns it to Suspended so it can be started again, marking messages it cannot keep queued as Discarded or Suspended and deleting none. Clean, which deletes queued messages, is a last resort OcuPilot does not offer.";

/// <p>A stop that answered success while messages still queued left the production Suspended rather than
/// Stopped. The stop was applied.</p>
Parameter SUSPENDED = "INTEROP.PRODUCTION.SUSPENDED";

Parameter REASONSUSPENDED = "The production stopped, but messages still queued left it Suspended rather than Stopped. Start it to process them.";

/// <p>A stop or restart whose jobs outlasted the wait after the production quiesced: the vendor answers
/// <code>ErrJobsNotStopped</code> and the production reads Running with only the stuck jobs.</p>
Parameter PARTSTOPPED = "INTEROP.PRODUCTION.PARTSTOPPED";

Parameter REASONPARTSTOPPED = "Some of the production's jobs did not stop within 15 seconds, so it is left partly stopped and still reads Running. Stop it again to finish, or update it to start its jobs again.";

/// <p>An item write on an item that is already enabled.</p>
Parameter ITEMENABLED = "INTEROP.ITEM.ENABLED";

Parameter REASONITEMENABLED = "This item is already enabled.";

/// <p>An item write on an item that is already disabled.</p>
Parameter ITEMDISABLED = "INTEROP.ITEM.DISABLED";

Parameter REASONITEMDISABLED = "This item is already disabled.";

/// <p>An enable or disable of an item whose <code>Enabled</code> a system default setting supplies: the
/// vendor would change the default's row and leave the production alone.</p>
Parameter ITEMDEFAULTSETTING = "INTEROP.ITEM.DEFAULTSETTING";

Parameter REASONITEMDEFAULTSETTING = "A system default setting decides whether this item is enabled, so change it in System Default Settings.";

/// <p>A disable of a business process that runs in the production's shared actor pool.</p>
Parameter ITEMPOOLZERO = "INTEROP.ITEM.POOLZERO";

Parameter REASONITEMPOOLZERO = "This business process runs in the production's shared actor pool, so it cannot be disabled.";

/// <p>An add of a name the production already holds.</p>
Parameter ITEMTAKEN = "INTEROP.ITEM.TAKEN";

Parameter REASONITEMTAKEN = "This production already holds an item of that name.";

/// <p>A write on a name the production holds more than once.</p>
Parameter ITEMAMBIGUOUS = "INTEROP.ITEM.AMBIGUOUS";

Parameter REASONITEMAMBIGUOUS = "This production holds more than one item of that name, so change it in the classic production configuration page.";

/// <p>Violation code (422), on <code>ClassName</code>: not a business service, process or operation class
/// compiled in the namespace.</p>
Parameter ITEMCLASS = "INTEROP.ITEM.CLASS";

Parameter REASONITEMCLASS = "Name a business service, business process or business operation class compiled in this namespace.";

/// <p>Violation code (422), on <code>Name</code>: a name the configuration refuses. The rule is
/// <method>OcuPilot.Port.InteropPort.NameProblem</method>'s.</p>
Parameter ITEMNAME = "INTEROP.ITEM.NAME";

Parameter REASONITEMNAME = "An item name is 1 to 128 characters with no control character and no space at either end. It cannot contain a vertical bar, a semicolon, a comma or an opening bracket, begin with a hyphen or an underscore, end with a hyphen, an exclamation mark or a dollar sign, or be an asterisk.";

/// <p>Violation code (422): a value the item's own property refuses (pool size, category or comment).</p>
Parameter ITEMVALUE = "INTEROP.ITEM.VALUE";

Parameter REASONITEMVALUE = "A production item does not accept this value for that field.";

/// <p>A remove of an item that is enabled.</p>
Parameter ITEMENABLEDREMOVE = "INTEROP.ITEM.ENABLEDREMOVE";

Parameter REASONITEMENABLEDREMOVE = "Disable this item before removing it.";

/// <p>Every item write in a namespace under source control.</p>
Parameter ITEMSOURCECONTROL = "INTEROP.ITEM.SOURCECONTROL";

Parameter REASONITEMSOURCECONTROL = "This namespace uses source control, so change this production's items in the classic production configuration page.";

/// <p>The consequence codes the enable, disable and add proposals, and the remove proposal, carry.</p>
Parameter ITEMPENDING = "INTEROP.ITEM.PENDING";

Parameter REASONITEMPENDING = "The change takes effect when this production next starts or, while it runs, when it is updated on Productions.";

Parameter ITEMREMOVE = "INTEROP.ITEM.REMOVE";

Parameter REASONITEMREMOVE = "Removing this item deletes it and every setting it holds from the production.";

/// <p>The refusals the port answers with, as a <class>%List</class>: every code that is not a
/// consequence.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#NAMESPACE, ..#RUNNING, ..#OTHER, ..#TROUBLED, ..#NOTRUNNING, ..#UPTODATE, ..#NOTTROUBLED, ..#BUSY, ..#STATE, ..#SUSPENDED, ..#PARTSTOPPED) _ ..ItemCodes()
}

/// <p>The consequence codes, as a <class>%List</class>.</p>
ClassMethod ConsequenceCodes() As %List
{
    Quit $ListBuild(..#STOP, ..#RESTART, ..#UPDATE, ..#RECOVER, ..#ITEMPENDING, ..#ITEMREMOVE)
}

/// <p>The item codes, as a <class>%List</class>: the refusals an item read or write answers with.</p>
ClassMethod ItemCodes() As %List
{
    Quit $ListBuild(..#ITEMENABLED, ..#ITEMDISABLED, ..#ITEMDEFAULTSETTING, ..#ITEMPOOLZERO, ..#ITEMTAKEN, ..#ITEMAMBIGUOUS, ..#ITEMCLASS, ..#ITEMNAME, ..#ITEMVALUE, ..#ITEMENABLEDREMOVE, ..#ITEMSOURCECONTROL)
}

/// <p>The item refusals an item tool's fresh read answers when the action does not fit the item, as a
/// <class>%List</class>; the field violations (<parameter>ITEMCLASS</parameter>, <parameter>ITEMNAME</parameter>
/// and <parameter>ITEMVALUE</parameter>) are an add's body and are not among them.</p>
ClassMethod ItemPreconditionCodes() As %List
{
    Quit $ListBuild(..#ITEMENABLED, ..#ITEMDISABLED, ..#ITEMDEFAULTSETTING, ..#ITEMPOOLZERO, ..#ITEMTAKEN, ..#ITEMAMBIGUOUS, ..#ITEMENABLEDREMOVE, ..#ITEMSOURCECONTROL)
}

/// <p>The codes a production tool's fresh read refuses with when the action's precondition does not
/// hold, as a <class>%List</class>: <class>OcuPilot.Screen.Tool.Write</class>'s
/// <code>PRECONDITIONCODES</code>.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit $ListBuild(..#RUNNING, ..#OTHER, ..#TROUBLED, ..#NOTRUNNING, ..#UPTODATE, ..#NOTTROUBLED, ..#STATE)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    If pCode = ..#RUNNING Quit ..#REASONRUNNING
    If pCode = ..#OTHER Quit ..#REASONOTHER
    If pCode = ..#TROUBLED Quit ..#REASONTROUBLED
    If pCode = ..#NOTRUNNING Quit ..#REASONNOTRUNNING
    If pCode = ..#UPTODATE Quit ..#REASONUPTODATE
    If pCode = ..#NOTTROUBLED Quit ..#REASONNOTTROUBLED
    If pCode = ..#BUSY Quit ..#REASONBUSY
    If pCode = ..#STATE Quit ..#REASONSTATE
    If pCode = ..#STOP Quit ..#REASONSTOP
    If pCode = ..#RESTART Quit ..#REASONRESTART
    If pCode = ..#UPDATE Quit ..#REASONUPDATE
    If pCode = ..#RECOVER Quit ..#REASONRECOVER
    If pCode = ..#SUSPENDED Quit ..#REASONSUSPENDED
    If pCode = ..#PARTSTOPPED Quit ..#REASONPARTSTOPPED
    If pCode = ..#ITEMENABLED Quit ..#REASONITEMENABLED
    If pCode = ..#ITEMDISABLED Quit ..#REASONITEMDISABLED
    If pCode = ..#ITEMDEFAULTSETTING Quit ..#REASONITEMDEFAULTSETTING
    If pCode = ..#ITEMPOOLZERO Quit ..#REASONITEMPOOLZERO
    If pCode = ..#ITEMTAKEN Quit ..#REASONITEMTAKEN
    If pCode = ..#ITEMAMBIGUOUS Quit ..#REASONITEMAMBIGUOUS
    If pCode = ..#ITEMCLASS Quit ..#REASONITEMCLASS
    If pCode = ..#ITEMNAME Quit ..#REASONITEMNAME
    If pCode = ..#ITEMVALUE Quit ..#REASONITEMVALUE
    If pCode = ..#ITEMENABLEDREMOVE Quit ..#REASONITEMENABLEDREMOVE
    If pCode = ..#ITEMSOURCECONTROL Quit ..#REASONITEMSOURCECONTROL
    If pCode = ..#ITEMPENDING Quit ..#REASONITEMPENDING
    If pCode = ..#ITEMREMOVE Quit ..#REASONITEMREMOVE
    Quit ""
}

}
