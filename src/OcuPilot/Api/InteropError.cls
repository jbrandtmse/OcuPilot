/// <p>The interoperability codes and sentences (AD-29, AD-39, AD-62, Stories 20.2, 20.5, 20.6, 20.9, 20.27 and 20.31): every
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

/// <p>A copy whose source item the production does not hold (Story 20.40): a violation (422) on <code>CopyFrom</code> at a Save
/// (the mint and the confirm refuse it as an argument, 400 <code>TOOL.ARGUMENTS</code>), a refusal (409) at the write.</p>
Parameter ITEMCOPYSOURCE = "INTEROP.ITEM.COPYSOURCE";

Parameter REASONITEMCOPYSOURCE = "This production holds no item of that name to copy.";

/// <p>A change of class to one the item's Classes tab does not list (Story 20.41): not compiled, abstract, or of another kind.</p>
Parameter ITEMNEWCLASS = "INTEROP.ITEM.NEWCLASS";

Parameter REASONITEMNEWCLASS = "Choose a compiled class of this item's kind, as its Classes tab lists them.";

/// <p>A change of class to the class the item already has.</p>
Parameter ITEMSAMECLASS = "INTEROP.ITEM.SAMECLASS";

Parameter REASONITEMSAMECLASS = "This item already uses that class.";

/// <p>A change of class whose dropped settings moved after they were reviewed: nothing is written.</p>
Parameter ITEMREVIEWCHANGED = "INTEROP.ITEM.REVIEWCHANGED";

Parameter REASONITEMREVIEWCHANGED = "This item's settings changed after they were reviewed, so its class was not changed. Review it again.";

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

/// <p>The consequence code of an item change of class (Story 20.41).</p>
Parameter ITEMCHANGECLASS = "INTEROP.ITEM.CHANGECLASS";

Parameter REASONITEMCHANGECLASS = "Changing this item's class removes every setting the new class does not take, and they cannot be restored. The change takes effect when this production next starts or, while it runs, when it is updated on Productions.";

/// <p>The consequence code of an item copy (Story 20.40).</p>
Parameter ITEMCOPY = "INTEROP.ITEM.COPY";

Parameter REASONITEMCOPY = "The copy is added to this production disabled, with this item's class and settings. A business process that runs in the shared actor pool is copied with a pool size of 1. Enable the copy to run it.";

/// <p>A stop, start or restart of an item whose production is running, but which is disabled (Story 20.25): the vendor answers
/// success and does nothing.</p>
Parameter ITEMNOTENABLED = "INTEROP.ITEM.NOTENABLED";

Parameter REASONITEMNOTENABLED = "This item is disabled, so it is not running. Enable it instead.";

/// <p>A stop or restart of an item that is already stopped.</p>
Parameter ITEMTEMPSTOPPED = "INTEROP.ITEM.TEMPSTOPPED";

Parameter REASONITEMTEMPSTOPPED = "This item is already stopped. Start it to run it again.";

/// <p>A start of an item that was not stopped with Stop: the vendor answers success and does nothing.</p>
Parameter ITEMNOTTEMPSTOPPED = "INTEROP.ITEM.NOTTEMPSTOPPED";

Parameter REASONITEMNOTTEMPSTOPPED = "This item has not been stopped with Stop, so there is nothing to start.";

/// <p>A stop or restart of an item that runs no jobs of its own.</p>
Parameter ITEMNOJOBS = "INTEROP.ITEM.NOJOBS";

Parameter REASONITEMNOJOBS = "This item runs no jobs of its own now, so it cannot be stopped by itself. That is so for an item that runs in its callers' jobs or in the shared actor pool, and for one its schedule has stopped.";

/// <p>A start whose production update did not finish: the stop is cleared, and the next update starts the item.</p>
Parameter ITEMSTARTPENDING = "INTEROP.ITEM.STARTPENDING";

Parameter REASONITEMSTARTPENDING = "The production's work in progress did not finish within 15 seconds, so the item starts only when the production is next updated on Productions.";

/// <p>The consequence codes the item stop, start and restart proposals carry (Story 20.25).</p>
Parameter ITEMSTOP = "INTEROP.ITEM.STOP";

Parameter REASONITEMSTOP = "Stopping this item ends its jobs until it is started again, and updates the production now to apply it, along with any other change waiting for it. Messages sent to the item wait in its queue. The item stays enabled, and the stop ends when the production next restarts. If its jobs do not finish their current messages within 15 seconds, nothing is changed.";

Parameter ITEMSTART = "INTEROP.ITEM.START";

Parameter REASONITEMSTART = "Starting this item starts its jobs again, and updates the production now to apply it, along with any other change waiting for it.";

Parameter ITEMRESTART = "INTEROP.ITEM.RESTART";

Parameter REASONITEMRESTART = "Restarting this item stops its jobs and starts them again, updating the production twice, which also applies any other change waiting for it. If its jobs do not finish their current messages within 15 seconds, nothing is changed.";

/// <p>A set or reset of a setting whose name the credential pattern matches (Story 20.22): OcuPilot neither shows
/// nor sets such a value.</p>
Parameter SETTINGSECRET = "INTEROP.SETTING.SECRET";

Parameter REASONSETTINGSECRET = "This setting holds a secret, so OcuPilot neither shows nor sets it. Set it in the classic production configuration page, or point the item at a credentials entry.";

/// <p>A set or reset of a setting a system default or a service registry entry decides.</p>
Parameter SETTINGSUPPLIED = "INTEROP.SETTING.SUPPLIED";

Parameter REASONSETTINGSUPPLIED = "A system default setting or a service registry entry decides this setting's value, so change it there.";

/// <p>A set of a value the production already holds.</p>
Parameter SETTINGSAME = "INTEROP.SETTING.SAME";

Parameter REASONSETTINGSAME = "This setting already holds that value.";

/// <p>A reset of a setting that already takes its default.</p>
Parameter SETTINGDEFAULTED = "INTEROP.SETTING.DEFAULTED";

Parameter REASONSETTINGDEFAULTED = "This setting already takes its default value, so there is nothing to reset.";

/// <p>A reset of one of the item's own properties.</p>
Parameter SETTINGCORE = "INTEROP.SETTING.CORE";

Parameter REASONSETTINGCORE = "This is one of the item's own properties, which has no default to return to, so set the value you want instead.";

/// <p>Violation code (422), on <code>Value</code>: a value the declaring class refuses, or one with a space or a
/// control character at either end, which the vendor would store trimmed.</p>
Parameter SETTINGVALUE = "INTEROP.SETTING.VALUE";

Parameter REASONSETTINGVALUE = "The item's class does not accept this value for this setting.";

/// <p>The consequence code a set of a server-path setting carries.</p>
Parameter SETTINGLOCATION = "INTEROP.SETTING.LOCATION";

Parameter REASONSETTINGLOCATION = "<value> is a location on this server that the item reads or writes when it runs. The change takes effect when this production next starts or, while it runs, when it is updated on Productions.";

/// <p>A set or reset of <code>FilePath</code> or <code>SubdirectoryLevels</code> that lets an inbound file adapter
/// descend into the manager directory or the directory OcuPilot serves its files from.</p>
Parameter SETTINGDESCENT = "INTEROP.SETTING.DESCENT";

Parameter REASONSETTINGDESCENT = "This item also reads the directories below its file path, as many levels down as its subdirectory levels, and that would reach the manager directory or the directory OcuPilot serves its files from. Choose another file path or fewer subdirectory levels.";

/// <p>An abort of a queue that holds no waiting message (Story 20.23): the vendor answers success and does nothing.</p>
Parameter QUEUEEMPTY = "INTEROP.QUEUE.EMPTY";

Parameter REASONQUEUEEMPTY = "This queue holds no messages, so there is nothing to abort.";

/// <p>An abort of a queue whose messages are not the ones its read enumerated: nothing is aborted.</p>
Parameter QUEUECHANGED = "INTEROP.QUEUE.CHANGED";

Parameter REASONQUEUECHANGED = "The messages in this queue changed after they were reviewed, so nothing was aborted. Review the queue again.";

/// <p>An action on a job whose process has ended.</p>
Parameter JOBDEAD = "INTEROP.JOB.DEAD";

Parameter REASONJOBDEAD = "This job's process has already ended, so there is nothing to act on. Update the production on Productions to start its jobs again.";

/// <p>An abort or suspend of a job that is not retrying a message: the vendor answers success for any job and leaves the
/// request set.</p>
Parameter JOBNOTRETRYING = "INTEROP.JOB.NOTRETRYING";

Parameter REASONJOBNOTRETRYING = "This job is not retrying a message now, so there is no message to abort or suspend. Its message can be aborted or suspended only while the job waits to retry it.";

/// <p>A stop the vendor could not complete: the job did not stop within the wait, even after it was ended.</p>
Parameter JOBNOTSTOPPED = "INTEROP.JOB.NOTSTOPPED";

Parameter REASONJOBNOTSTOPPED = "The job did not stop within the wait, even after it was ended. Look at Jobs again, and update the production on Productions to start its jobs again.";

/// <p>The consequence codes the queue and job action proposals carry (Story 20.23). The client maps each to its
/// warning sentence (<file>ui/src/app/core/proposal-view.ts</file>).</p>
Parameter MESSAGEABORT = "INTEROP.MESSAGE.ABORT";

Parameter REASONMESSAGEABORT = "Aborting this message takes it off its queue and marks it Aborted, so it is never delivered, and a caller waiting for its reply receives an error instead. It cannot be undone.";

Parameter QUEUEABORT = "INTEROP.QUEUE.ABORT";

Parameter REASONQUEUEABORT = "Aborting all messages takes the messages waiting in this queue now, up to the first 10,000, off it and marks each Aborted, so none is delivered. A message that arrives later stays, and so does one a job is already working on. It cannot be undone.";

Parameter JOBABORT = "INTEROP.JOB.ABORT";

Parameter REASONJOBABORT = "Aborting this job's message marks the message it keeps retrying Aborted when its current retry wait ends, so it is never delivered, and the job moves on to its next message. It cannot be undone.";

Parameter JOBSUSPEND = "INTEROP.JOB.SUSPEND";

Parameter REASONJOBSUSPEND = "Suspending this job's message sets the message it keeps retrying aside as Suspended when its current retry wait ends, and the job moves on to its next message. A suspended message can be resent later.";

Parameter JOBSTOP = "INTEROP.JOB.STOP";

Parameter REASONJOBSTOP = "Stopping this job asks it to finish its current message within 15 seconds, or sooner when the production's update timeout is shorter. A job that does not is ended, and its message goes back on its queue. The item runs a job short until the production is updated on Productions.";

/// <p>An add of a key the lookup table already holds (Story 20.5).</p>
Parameter LOOKUPTAKEN = "INTEROP.LOOKUP.TAKEN";

Parameter REASONLOOKUPTAKEN = "This lookup table already holds an entry with that key.";

/// <p>An add into a table whose name differs only in letter case from one the namespace holds: table names are case
/// sensitive and the classic page treats them as one table.</p>
Parameter LOOKUPTABLECASE = "INTEROP.LOOKUP.TABLECASE";

Parameter REASONLOOKUPTABLECASE = "A lookup table whose name differs from this one only in letter case already exists. Use its spelling, or choose another name.";

/// <p>A set of the value the entry already holds.</p>
Parameter LOOKUPSAME = "INTEROP.LOOKUP.SAME";

Parameter REASONLOOKUPSAME = "This entry already holds that value.";

/// <p>An add or a set of an entry whose key the credential pattern matches: OcuPilot neither shows nor sets such a value.</p>
Parameter LOOKUPSECRET = "INTEROP.LOOKUP.SECRET";

Parameter REASONLOOKUPSECRET = "This key names a credential, so OcuPilot neither shows nor sets its value. Set it in the classic Lookup Tables page.";

/// <p>Every lookup write in a namespace under source control.</p>
Parameter LOOKUPSOURCECONTROL = "INTEROP.LOOKUP.SOURCECONTROL";

Parameter REASONLOOKUPSOURCECONTROL = "This namespace uses source control, so change lookup tables in the classic Lookup Tables page.";

/// <p>A lookup write while the vendor's own table lock is held past the wait.</p>
Parameter LOOKUPLOCKED = "INTEROP.LOOKUP.LOCKED";

Parameter REASONLOOKUPLOCKED = "Someone else is changing this lookup table right now, so nothing was written. Try again in a moment.";

/// <p>Violation codes (422): a table name, an entry key and an entry value the vendor's own limits refuse, and a table name and
/// key too long together for the instance to address (the key's violation). The rules are
/// <method>OcuPilot.Port.InteropPort.LookupViolations</method>'s.</p>
Parameter LOOKUPTABLENAME = "INTEROP.LOOKUP.TABLENAME";

Parameter REASONLOOKUPTABLENAME = "A lookup table name is 1 to 255 characters with no control character, within the length the instance can store.";

Parameter LOOKUPKEY = "INTEROP.LOOKUP.KEY";

Parameter REASONLOOKUPKEY = "An entry key is 1 to 255 characters with no control character, and with its table's name within the length the instance can store.";

Parameter LOOKUPVALUE = "INTEROP.LOOKUP.VALUE";

Parameter REASONLOOKUPVALUE = "An entry value is at most 32,000 characters.";

/// <p>An import file that is not exactly one lookup table with at least one entry and nothing else, or that holds another table than
/// the one named (Story 20.5).</p>
Parameter LOOKUPIMPORTSHAPE = "INTEROP.LOOKUP.IMPORTSHAPE";

Parameter REASONLOOKUPIMPORTSHAPE = "An import file must hold exactly one lookup table with at least one entry and nothing else, in the form the Export action writes.";

/// <p>An import whose file, or whose table, is not what it was reviewed as.</p>
Parameter LOOKUPIMPORTCHANGED = "INTEROP.LOOKUP.IMPORTCHANGED";

Parameter REASONLOOKUPIMPORTCHANGED = "The file or the table changed after the import was reviewed, so nothing was imported. Review the import again.";

/// <p>An export or an import file longer than <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters; the
/// sentence states that number, pinned by <file>ui/tools/interop.test.mjs</file>.</p>
Parameter LOOKUPTOOLARGE = "INTEROP.LOOKUP.TOOLARGE";

Parameter REASONLOOKUPTOOLARGE = "A lookup table file holds at most 3,000,000 characters, and this one holds more.";

/// <p>An export of a table whose name the vendor's export reads as a pattern, a path or a separator, so it cannot name the table's
/// own document (<method>OcuPilot.Port.InteropPort.LookupAddressable</method>).</p>
Parameter LOOKUPEXPORTNAME = "INTEROP.LOOKUP.EXPORTNAME";

Parameter REASONLOOKUPEXPORTNAME = "This lookup table cannot be exported: its name holds a character the export reads as a pattern or a path (* ? / or ;) or begins with an apostrophe.";

/// <p>The consequence code the import proposal carries.</p>
Parameter LOOKUPIMPORT = "INTEROP.LOOKUP.IMPORT";

Parameter REASONLOOKUPIMPORT = "Importing replaces the table's entries with the file's, and entries the file does not hold are removed.";

/// <p>The consequence codes the entry remove and the table delete proposals carry (Story 20.5). The client maps each to its
/// warning sentence (<file>ui/src/app/core/proposal-view.ts</file>).</p>
Parameter LOOKUPREMOVE = "INTEROP.LOOKUP.REMOVE";

Parameter REASONLOOKUPREMOVE = "Removing this entry cannot be undone from OcuPilot. When it is the table's last entry, the table is removed too.";

Parameter LOOKUPDELETE = "INTEROP.LOOKUP.DELETE";

Parameter REASONLOOKUPDELETE = "Deleting this lookup table removes every entry in it. Rules and transformations that read it then get their default value.";

/// <p>The business partner writes' refusals, violations and consequence (Story 20.26). An add of a name the namespace holds,
/// or holds in another letter case, and a remove of a partner an item names are each 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug; the two violations are 422.</p>
Parameter PARTNERTAKEN = "INTEROP.PARTNER.TAKEN";

Parameter REASONPARTNERTAKEN = "This namespace already holds a business partner of that name.";

Parameter PARTNERNAMECASE = "INTEROP.PARTNER.NAMECASE";

Parameter REASONPARTNERNAMECASE = "A business partner whose name differs from this one only in letter case already exists. Use its spelling, or choose another name.";

Parameter PARTNERNAMED = "INTEROP.PARTNER.NAMED";

Parameter REASONPARTNERNAMED = "Production items name this business partner in their Business partner setting, so it is not removed. Clear that setting on each of them first, then remove the partner.";

Parameter PARTNERSOURCECONTROL = "INTEROP.PARTNER.SOURCECONTROL";

Parameter REASONPARTNERSOURCECONTROL = "This namespace uses source control, so change business partners in the classic Business Partners page.";

Parameter PARTNERNAME = "INTEROP.PARTNER.NAME";

Parameter REASONPARTNERNAME = "A business partner name is 1 to 255 characters with no control character.";

Parameter PARTNERLENGTH = "INTEROP.PARTNER.LENGTH";

Parameter REASONPARTNERLENGTH = "This value is longer than a business partner keeps: at most 5,000 characters for a description, 1,000 for notes, 50 for a phone or mobile number and 255 for anything else.";

Parameter PARTNERREMOVE = "INTEROP.PARTNER.REMOVE";

Parameter REASONPARTNERREMOVE = "Removing this business partner deletes its description and both contacts, and it cannot be restored from OcuPilot.";

/// <p>The system default settings' refusals, violations and consequences (Story 24.15). <code>TAKEN</code>, <code>SECRET</code> and
/// <code>SOURCECONTROL</code> are 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, <code>RESTRICTED</code> is 403, and
/// <code>KEY</code> and <code>VALUE</code> are 422. <code>TOOMANY</code> is 409 on the comparison.</p>
Parameter DEFAULTSETTINGTAKEN = "INTEROP.DEFAULTSETTING.TAKEN";

Parameter REASONDEFAULTSETTINGTAKEN = "This namespace already has a default setting for that production, item, host class and setting.";

Parameter DEFAULTSETTINGSECRET = "INTEROP.DEFAULTSETTING.SECRET";

Parameter REASONDEFAULTSETTINGSECRET = "This setting names a credential, so OcuPilot neither shows nor sets its value. Set it in the classic System Default Settings page.";

Parameter DEFAULTSETTINGKEY = "INTEROP.DEFAULTSETTING.KEY";

Parameter REASONDEFAULTSETTINGKEY = "Production, item, host class and setting are each 1 to 255 characters, may be * for any, and may not contain two vertical bars.";

Parameter DEFAULTSETTINGVALUE = "INTEROP.DEFAULTSETTING.VALUE";

Parameter REASONDEFAULTSETTINGVALUE = "This value is not valid for that setting.";

Parameter DEFAULTSETTINGRESTRICTED = "INTEROP.DEFAULTSETTING.RESTRICTED";

Parameter REASONDEFAULTSETTINGRESTRICTED = "You may not change the default for this setting.";

Parameter DEFAULTSETTINGSOURCECONTROL = "INTEROP.DEFAULTSETTING.SOURCECONTROL";

Parameter REASONDEFAULTSETTINGSOURCECONTROL = "This namespace uses source control, so change default settings in the classic System Default Settings page.";

Parameter DEFAULTSETTINGTOOMANY = "INTEROP.DEFAULTSETTING.TOOMANY";

Parameter REASONDEFAULTSETTINGTOOMANY = "One of these namespaces has more default settings than one comparison covers.";

Parameter DEFAULTSETTINGREMOVE = "INTEROP.DEFAULTSETTING.REMOVE";

Parameter REASONDEFAULTSETTINGREMOVE = "Items that took this value use their own setting or the class default again, and it cannot be restored from OcuPilot.";

Parameter DEFAULTSETTINGPENDING = "INTEROP.DEFAULTSETTING.PENDING";

Parameter REASONDEFAULTSETTINGPENDING = "A running production uses the new value once it is updated.";

/// <p>The credentials' refusals, violations and consequences (Story 24.15). <code>TAKEN</code> is 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, and <code>NAME</code>, <code>PARTNER</code> and <code>VALUE</code> are 422.</p>
Parameter CREDENTIALTAKEN = "INTEROP.CREDENTIAL.TAKEN";

Parameter REASONCREDENTIALTAKEN = "This namespace already has a credential with that name, in some letter case.";

Parameter CREDENTIALNAME = "INTEROP.CREDENTIAL.NAME";

Parameter REASONCREDENTIALNAME = "A credential name is 1 to 50 characters and holds no control characters.";

Parameter CREDENTIALPARTNER = "INTEROP.CREDENTIAL.PARTNER";

Parameter REASONCREDENTIALPARTNER = "This namespace has no business partner with that name.";

Parameter CREDENTIALVALUE = "INTEROP.CREDENTIAL.VALUE";

Parameter REASONCREDENTIALVALUE = "The instance did not accept this user name.";

Parameter CREDENTIALREMOVE = "INTEROP.CREDENTIAL.REMOVE";

Parameter REASONCREDENTIALREMOVE = "Anything that names this credential can no longer use it. This cannot be undone.";

Parameter CREDENTIALCHANGE = "INTEROP.CREDENTIAL.CHANGE";

Parameter REASONCREDENTIALCHANGE = "Anything that signs in with this credential uses the change from its next connection.";

/// <p>The schedule specs' refusals, violations and consequences (Story 24.15). <code>TAKEN</code> and <code>SOURCECONTROL</code> are 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, and <code>NAME</code>, <code>SPEC</code> and <code>DESCRIPTION</code> are 422.</p>
Parameter SCHEDULETAKEN = "INTEROP.SCHEDULE.TAKEN";

Parameter REASONSCHEDULETAKEN = "This namespace already has a schedule spec with that name, in some letter case.";

Parameter SCHEDULENAME = "INTEROP.SCHEDULE.NAME";

Parameter REASONSCHEDULENAME = "A schedule spec name is 1 to 50 characters and holds no control characters.";

Parameter SCHEDULESPEC = "INTEROP.SCHEDULE.SPEC";

Parameter REASONSCHEDULESPEC = "This schedule is not valid. Each part is START or STOP, a colon and a date and time.";

Parameter SCHEDULEDESCRIPTION = "INTEROP.SCHEDULE.DESCRIPTION";

Parameter REASONSCHEDULEDESCRIPTION = "A description is at most 256 characters.";

Parameter SCHEDULESOURCECONTROL = "INTEROP.SCHEDULE.SOURCECONTROL";

Parameter REASONSCHEDULESOURCECONTROL = "This namespace uses source control, so change schedule specs in the classic Schedule Specs page.";

Parameter SCHEDULEREMOVE = "INTEROP.SCHEDULE.REMOVE";

Parameter REASONSCHEDULEREMOVE = "Items that name this schedule spec keep running until the production is next updated, and are then disabled and stopped until the schedule spec is added again. It cannot be restored from OcuPilot.";

Parameter SCHEDULECHANGE = "INTEROP.SCHEDULE.CHANGE";

Parameter REASONSCHEDULECHANGE = "A running production that uses this schedule spec follows a changed spec at once.";

/// <p>The workflow users' refusals, violations and consequences (Story 24.17 Batch 3a). <code>USERTAKEN</code> and <code>SOURCECONTROL</code> are 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, and <code>USERNAME</code> and <code>FULLNAME</code> are 422. <code>SOURCECONTROL</code> is shared with the
/// workflow roles' writes.</p>
Parameter WORKFLOWSOURCECONTROL = "INTEROP.WORKFLOW.SOURCECONTROL";

Parameter REASONWORKFLOWSOURCECONTROL = "This namespace uses source control, so change workflow users and roles in the classic Workflow Users and Workflow Roles pages.";

Parameter WORKFLOWUSERNAME = "INTEROP.WORKFLOW.USERNAME";

Parameter REASONWORKFLOWUSERNAME = "A new workflow user must be a user of this instance, named exactly as the user list spells it.";

Parameter WORKFLOWUSERTAKEN = "INTEROP.WORKFLOW.USERTAKEN";

Parameter REASONWORKFLOWUSERTAKEN = "This namespace already has a workflow user with that name, in some letter case.";

Parameter WORKFLOWFULLNAME = "INTEROP.WORKFLOW.FULLNAME";

Parameter REASONWORKFLOWFULLNAME = "A full name is at most 128 characters and holds no control characters.";

Parameter WORKFLOWUSERREMOVE = "INTEROP.WORKFLOW.USERREMOVE";

Parameter REASONWORKFLOWUSERREMOVE = "Removing this workflow user takes them out of every workflow role, deletes their worklist and leaves each task they hold unassigned. It cannot be restored from OcuPilot.";

Parameter WORKFLOWUSERINACTIVE = "INTEROP.WORKFLOW.USERINACTIVE";

Parameter REASONWORKFLOWUSERINACTIVE = "An inactive workflow user is sent no new tasks through their workflow roles; their worklist is deleted and each task they hold is left unassigned.";

/// <p>The workflow roles' and their members' refusals, violations and consequences (Story 24.17 Batch 3b). <code>ROLETAKEN</code> and <code>MEMBERTAKEN</code> are 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug and the others are 422; the source control refusal is <parameter>WORKFLOWSOURCECONTROL</parameter>.</p>
Parameter WORKFLOWROLENAME = "INTEROP.WORKFLOW.ROLENAME";

Parameter REASONWORKFLOWROLENAME = "A workflow role name is 1 to 128 characters and holds no control characters.";

Parameter WORKFLOWROLETAKEN = "INTEROP.WORKFLOW.ROLETAKEN";

Parameter REASONWORKFLOWROLETAKEN = "This namespace already has a workflow role with that name, in some letter case.";

Parameter WORKFLOWROLEDESCRIPTION = "INTEROP.WORKFLOW.ROLEDESCRIPTION";

Parameter REASONWORKFLOWROLEDESCRIPTION = "A description is at most 2,000 characters.";

Parameter WORKFLOWROLECAPACITY = "INTEROP.WORKFLOW.ROLECAPACITY";

Parameter REASONWORKFLOWROLECAPACITY = "Capacity is a whole number from 1 to 100.";

Parameter WORKFLOWMEMBERUSER = "INTEROP.WORKFLOW.MEMBERUSER";

Parameter REASONWORKFLOWMEMBERUSER = "This namespace has no workflow user with that name.";

Parameter WORKFLOWMEMBERTAKEN = "INTEROP.WORKFLOW.MEMBERTAKEN";

Parameter REASONWORKFLOWMEMBERTAKEN = "This workflow user is already a member of this role.";

Parameter WORKFLOWMEMBERRANK = "INTEROP.WORKFLOW.MEMBERRANK";

Parameter REASONWORKFLOWMEMBERRANK = "Rank is a whole number from 1 to 5.";

Parameter WORKFLOWMEMBERTITLE = "INTEROP.WORKFLOW.MEMBERTITLE";

Parameter REASONWORKFLOWMEMBERTITLE = "A title is at most 128 characters and holds no control characters.";

Parameter WORKFLOWROLEREMOVE = "INTEROP.WORKFLOW.ROLEREMOVE";

Parameter REASONWORKFLOWROLEREMOVE = "Removing this workflow role also removes each of its members from it. Tasks already sent through it are left as they are. It cannot be restored from OcuPilot.";

Parameter WORKFLOWMEMBERADD = "INTEROP.WORKFLOW.MEMBERADD";

Parameter REASONWORKFLOWMEMBERADD = "An active member is sent each unassigned task of this role.";

Parameter WORKFLOWMEMBERREMOVE = "INTEROP.WORKFLOW.MEMBERREMOVE";

Parameter REASONWORKFLOWMEMBERREMOVE = "Removing this member deletes their worklist for this role and leaves each task they hold through it unassigned.";

/// <p>The purge's refusals and consequences (Story 24.16). <code>DAYS</code> is 422 on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug and
/// <code>RUNNING</code> is 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug.</p>
Parameter PURGEDAYS = "INTEROP.PURGE.DAYS";

Parameter REASONPURGEDAYS = "Older than (days) is a whole number from 0 to 99999.";

Parameter PURGERUNNING = "INTEROP.PURGE.RUNNING";

Parameter REASONPURGERUNNING = "A purge is already running in this namespace. Try again when it has finished.";

Parameter PURGERUN = "INTEROP.PURGE.RUN";

Parameter REASONPURGERUN = "Deletes this namespace's event log entries, messages, completed business process records, business rule log entries, I/O log entries, host monitor data and managed alerts older than the days to keep, and their message bodies when Include message bodies is on. When Purge only completed sessions is on, a session with a message still in progress is kept whole, and so is an open managed alert. With 0 days, everything up to the end of today is deleted, except managed alerts from today. It cannot be undone.";

Parameter PURGEBITMAP = "INTEROP.PURGE.BITMAP";

Parameter REASONPURGEBITMAP = "Deletes this namespace's event log entries, messages, completed business process records, business rule log entries, I/O log entries, host monitor data and managed alerts older than the days to keep, and their message bodies when Include message bodies is on. When Purge only completed sessions is on, a session with a message still in progress is kept whole, and so is an open managed alert. With 0 days, everything up to the end of today is deleted, except managed alerts from today. It cannot be undone. Bitmap cleanup then runs over every class in this namespace with full system rights, and can take a long time. Those rights end when it finishes.";

/// <p>The consequences of the business rule log purge and the business process purge (Story 24.17 Batch 2); neither has a refusal of its own beyond
/// <parameter>PURGEDAYS</parameter>.</p>
Parameter RULELOGPURGE = "INTEROP.RULELOG.PURGE";

Parameter REASONRULELOGPURGE = "Deletes this namespace's business rule log entries older than the days to keep. With 0 days, everything up to the end of today is deleted. It cannot be undone.";

Parameter PROCESSLOGPURGE = "INTEROP.PROCESSLOG.PURGE";

Parameter REASONPROCESSLOGPURGE = "Deletes this namespace's completed business process records older than the days to keep; a business process still running is kept. With 0 days, every completed one up to the end of today is deleted. It cannot be undone.";

/// <p>The local archive manager's refusals and consequence (Story 24.16 Batch 4), each 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug: a run already
/// running, no other interoperability namespace to archive to, a namespace that archives with its own class, a namespace holding more messages than one run takes, and a
/// target that already holds an id the run would move. <parameter>ACCEPTSNOARCHIVETARGET</parameter> is what Archive to namespace accepts when no other namespace is
/// listed.</p>
Parameter ARCHIVERUNNING = "INTEROP.ARCHIVE.RUNNING";

Parameter REASONARCHIVERUNNING = "An archive is already running in this namespace. Try again when it has finished.";

Parameter ARCHIVENOTARGET = "INTEROP.ARCHIVE.NOTARGET";

Parameter REASONARCHIVENOTARGET = "Archive to namespace is not set to another interoperability namespace. Set it under Archive settings first.";

Parameter ARCHIVECLASS = "INTEROP.ARCHIVE.CLASS";

Parameter REASONARCHIVECLASS = "This namespace archives with its own archive manager class, which runs code OcuPilot does not run. Run it from the classic Archive Manager page.";

Parameter ARCHIVETOOMANY = "INTEROP.ARCHIVE.TOOMANY";

Parameter REASONARCHIVETOOMANY = "This namespace holds more messages than one archive run here can take. Purge older messages first, or run the archive from the classic Archive Manager page.";

Parameter ARCHIVETAKEN = "INTEROP.ARCHIVE.TAKEN";

Parameter REASONARCHIVETAKEN = "Archive to namespace already holds a message with the id of one this run would move, so nothing was archived. Choose a namespace kept for archives.";

Parameter ARCHIVERUN = "INTEROP.ARCHIVE.RUN";

Parameter REASONARCHIVERUN = "Archiving moves every message in this namespace older than the number of days before archiving, whatever its status, to the namespace set as Archive to namespace: its header is saved there under its own message id and its body as text, and then both are deleted here. A body that is not an EDI document or an object that can be written as XML is kept there only as its class name and id. With 0 days, everything up to the end of today is moved. The last run's history and error log are replaced. It cannot be undone.";

Parameter ACCEPTSNOARCHIVETARGET = "No other interoperability namespace on this instance.";

/// <p>The managed alert update's refusals and consequence (Story 24.17 Batch 1): an alert that is gone (404), a value outside its rule (422: the owner, the escalation level, the
/// next action time and the reason) and an update that would change nothing (409).</p>
Parameter ALERTNOTFOUND = "INTEROP.ALERT.NOTFOUND";

Parameter REASONALERTNOTFOUND = "This managed alert no longer exists.";

Parameter ALERTUNCHANGED = "INTEROP.ALERT.UNCHANGED";

Parameter REASONALERTUNCHANGED = "Nothing would change. Choose a new owner, open state, escalation level or next action time.";

Parameter ALERTOWNER = "INTEROP.ALERT.OWNER";

Parameter REASONALERTOWNER = "The owner must be unassigned, you, or a user who can work on managed alerts in this namespace.";

Parameter ALERTLEVEL = "INTEROP.ALERT.LEVEL";

Parameter REASONALERTLEVEL = "The escalation level moves one step up or down from its current level, and never below 0.";

Parameter ALERTNEXTACTION = "INTEROP.ALERT.NEXTACTION";

Parameter REASONALERTNEXTACTION = "Next action in (minutes) is a whole number from 1 to 20160.";

Parameter ALERTREASON = "INTEROP.ALERT.REASON";

Parameter REASONALERTREASON = "Give a reason of 1 to 500 characters, with no control characters.";

Parameter ALERTUPDATE = "INTEROP.ALERT.UPDATE";

Parameter REASONALERTUPDATE = "Updating saves each change in the alert's history with your username and the reason given. The alert can be updated again, and a closed alert can be opened again.";

/// <p>The startup settings' refusals, violations and consequences (Story 24.3): the auto-start production and a production's shutdown
/// group. <code>SAME</code> is 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, <code>ALLNAMESPACES</code> is 403,
/// <code>READONLY</code> is 409, and <code>PRIORITY</code>, <code>GROUP</code> and <code>NOPRIORITY</code> are 422.</p>
Parameter STARTUPSAME = "INTEROP.STARTUP.SAME";

Parameter REASONSTARTUPSAME = "This production is already set that way, so there is nothing to change.";

Parameter STARTUPPRIORITY = "INTEROP.STARTUP.PRIORITY";

Parameter REASONSTARTUPPRIORITY = "A startup priority is a whole number of at most nine digits, with a minus sign if it is negative.";

Parameter STARTUPGROUP = "INTEROP.STARTUP.GROUP";

Parameter REASONSTARTUPGROUP = "A shutdown group is a whole number of at most nine digits, with a minus sign if it is negative.";

Parameter STARTUPNOPRIORITY = "INTEROP.STARTUP.NOPRIORITY";

Parameter REASONSTARTUPNOPRIORITY = "A startup priority applies only to a production that starts with the instance.";

Parameter STARTUPALLNAMESPACES = "INTEROP.STARTUP.ALLNAMESPACES";

Parameter REASONSTARTUPALLNAMESPACES = "Changing a startup priority or a shutdown group needs read access to the settings of every namespace that runs interoperability on this instance.";

Parameter STARTUPREADONLY = "INTEROP.STARTUP.READONLY";

Parameter REASONSTARTUPREADONLY = "This namespace's database is mounted read-only, so this setting cannot be saved.";

Parameter AUTOSTART = "INTEROP.AUTOSTART";

Parameter REASONAUTOSTART = "A namespace starts at most one production with the instance, so this replaces any production set to start before.";

Parameter SHUTDOWNGROUP = "INTEROP.SHUTDOWNGROUP";

Parameter REASONSHUTDOWNGROUP = "A shutdown group other than 2 can make the instance take longer to stop, which matters where a failover must finish in time.";

/// <p>The host test's refusals and violations (Story 20.6). The first five refuse a test before a request is built, each 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, and the last three are the 422 violations of a request's fields.
/// <code>INTEROP.PRODUCTION.NOTRUNNING</code> is the production-not-running refusal, reused.</p>
Parameter TESTDISABLED = "INTEROP.TEST.DISABLED";

Parameter REASONTESTDISABLED = "Testing is not enabled for this production. Turn on Testing Enabled in the classic production settings, then update the production.";

Parameter TESTTARGETTYPE = "INTEROP.TEST.TARGETTYPE";

Parameter REASONTESTTARGETTYPE = "Only a business process or a business operation takes a test request.";

Parameter TESTTARGETDISABLED = "INTEROP.TEST.TARGETDISABLED";

Parameter REASONTESTTARGETDISABLED = "This item is disabled, so a test request would wait in its queue with no answer. Enable it first.";

Parameter TESTREQUESTTYPE = "INTEROP.TEST.REQUESTTYPE";

Parameter REASONTESTREQUESTTYPE = "This host does not take that request class. Its Test tab lists the ones it takes.";

Parameter TESTSECRET = "INTEROP.TEST.SECRET";

Parameter REASONTESTSECRET = "This field names a credential, so OcuPilot sends no value for it. Leave it empty, or test in the classic Testing Service page.";

Parameter TESTFIELD = "INTEROP.TEST.FIELD";

Parameter REASONTESTFIELD = "The request class has no such field that a test can set.";

Parameter TESTVALUE = "INTEROP.TEST.VALUE";

Parameter REASONTESTVALUE = "This value does not fit the field, or the field is required.";

Parameter TESTREQUEST = "INTEROP.TEST.REQUEST";

Parameter REASONTESTREQUEST = "The request could not be built from these values.";

/// <p>The consequence code the host test's proposal carries. The client maps it to its published sentence.</p>
Parameter TESTSENDS = "INTEROP.TEST.SENDS";

Parameter REASONTESTSENDS = "A test sends a real message through the running production. The target runs it, and anything it sends on, to another host or outside this instance, is sent too. The test's messages stay in the message store.";

/// <p>The data transformation test's refusals (Story 20.27). The first two refuse a transformation whose source or target class
/// OcuPilot cannot read or show as text, each 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, before anything is
/// parsed or run. <parameter>TRANSFORMCONTENT</parameter> is the 422 violation of the pasted source message, empty or past
/// <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter>. <code>INTEROP.NAMESPACE</code> is the namespace refusal,
/// reused.</p>
Parameter TRANSFORMSOURCEFORMAT = "INTEROP.TRANSFORM.SOURCEFORMAT";

Parameter REASONTRANSFORMSOURCEFORMAT = "OcuPilot reads a pasted source only as an HL7 or other EDI document's text, or as XML. This transformation's source is neither, so test it in the classic portal.";

Parameter TRANSFORMTARGETFORMAT = "INTEROP.TRANSFORM.TARGETFORMAT";

Parameter REASONTRANSFORMTARGETFORMAT = "OcuPilot shows a target only as an EDI document's text or as XML. This transformation's target is neither, so test it in the classic portal.";

Parameter TRANSFORMCONTENT = "INTEROP.TRANSFORM.CONTENT";

Parameter REASONTRANSFORMCONTENT = "Paste the source message, at most 3,000,000 characters.";

/// <p>The consequence code the data transformation test's proposal carries. The client maps it to its published sentence.</p>
Parameter TRANSFORMRUNS = "INTEROP.TRANSFORM.RUNS";

Parameter REASONTRANSFORMRUNS = "The transformation's code runs on this instance as you, on the input shown. Whatever it writes or sends, it writes or sends.";

/// <p>The message contents refusal (Story 20.9): a message body that is not text OcuPilot can draw, 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug. The contents read answers it only after the vendor's own
/// view audit row is written.</p>
Parameter MESSAGECONTENTS = "INTEROP.MESSAGE.CONTENTS";

Parameter REASONMESSAGECONTENTS = "OcuPilot cannot show this message body as text.";

/// <p>The message resend's refusals (Story 20.31), each 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug:
/// none of the messages named can be resent, and the messages changed after a person reviewed them.</p>
Parameter RESENDNONE = "INTEROP.RESEND.NONE";

Parameter REASONRESENDNONE = "None of these messages can be resent now.";

Parameter RESENDCHANGED = "INTEROP.RESEND.CHANGED";

Parameter REASONRESENDCHANGED = "These messages changed after they were reviewed, so nothing was resent. Review them again.";

/// <p>The edit-and-resend's refusals (Story 20.31): a body OcuPilot does not edit and an edit that changes nothing, each 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, and the three violations of the fields an edit supplies, each 422 on the
/// field: no such field, a credential-named field, and a value the field refuses.</p>
Parameter EDITNOTEDITABLE = "INTEROP.EDIT.NOTEDITABLE";

Parameter REASONEDITNOTEDITABLE = "OcuPilot can edit an HL7 v2 message or the plain fields of a message object, not this message's body. Use the classic Edit and Resend page for it.";

Parameter EDITNOCHANGE = "INTEROP.EDIT.NOCHANGE";

Parameter REASONEDITNOCHANGE = "This edit changes nothing in the message. Use Resend to send it again as it is.";

Parameter EDITFIELD = "INTEROP.EDIT.FIELD";

Parameter REASONEDITFIELD = "The message body has no such field that an edit can set.";

Parameter EDITSECRET = "INTEROP.EDIT.SECRET";

Parameter REASONEDITSECRET = "This field names a credential, so OcuPilot does not change it.";

Parameter EDITVALUE = "INTEROP.EDIT.VALUE";

Parameter REASONEDITVALUE = "This value is not valid for the field.";

/// <p>The consequence codes the resend and the edit-and-resend proposals and dialogs carry (Story 20.31). The client maps each to its
/// published sentence.</p>
Parameter MESSAGERESEND = "INTEROP.MESSAGE.RESEND";

Parameter REASONMESSAGERESEND = "Resending sends each message marked to be resent to its target again, as a new message in the same session. A message that was already delivered is delivered twice. It cannot be undone.";

Parameter MESSAGEEDITRESEND = "INTEROP.MESSAGE.EDITRESEND";

Parameter REASONMESSAGEEDITRESEND = "Edit and resend saves the edited body as a new copy and sends it to the message's target as a new message in the same session. The original message and body stay as they were. It cannot be undone.";

/// <p>The five verdicts a message reads before a resend (Story 20.31), in the order they are judged, and the words that say each
/// (<method>VerdictSentence</method>).</p>
Parameter VERDICTS = "gone,nobody,targetoff,noreplyqueue,resend";

Parameter VERDICTRESEND = "will be resent";

Parameter VERDICTGONE = "no longer exists";

Parameter VERDICTNOBODY = "its body no longer exists";

Parameter VERDICTTARGETOFF = "its target is not an enabled item of the running production";

Parameter VERDICTNOREPLYQUEUE = "the queue its reply would go to no longer exists";

/// <p>The words that follow a message id in the outcome of a resend (Story 20.31): <code>&lt;id&gt;: resent as &lt;new&gt;</code>
/// and <code>&lt;id&gt;: not resent: &lt;text&gt;</code>.</p>
Parameter OUTCOMERESENT = "resent as";

Parameter OUTCOMEFAILED = "not resent";

/// <p>The suspended messages' refusals (Story 24.16), each 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug: none of the messages
/// named can be acted on, and the messages changed after a person reviewed them.</p>
Parameter SUSPENDEDNONE = "INTEROP.SUSPENDED.NONE";

Parameter REASONSUSPENDEDNONE = "None of these messages can be acted on now. Each one's line says why.";

Parameter SUSPENDEDCHANGED = "INTEROP.SUSPENDED.CHANGED";

Parameter REASONSUSPENDEDCHANGED = "These messages changed after they were reviewed, so nothing was changed. Review them again.";

/// <p>The consequence codes the four suspended message proposals and dialogs carry (Story 24.16). The client maps each to its published sentence.</p>
Parameter SUSPENDEDRESUBMIT = "INTEROP.SUSPENDED.RESUBMIT";

Parameter REASONSUSPENDEDRESUBMIT = "Resubmitting puts each message marked to be resubmitted back on its target's queue under its own message id, and the running production processes it. It cannot be undone.";

Parameter SUSPENDEDEDIT = "INTEROP.SUSPENDED.EDIT";

Parameter REASONSUSPENDEDEDIT = "Edit and resubmit saves the edited body as a new copy and puts the message back on its target's queue with it, under its own message id. The original body is kept. It cannot be undone.";

Parameter SUSPENDEDDISCARD = "INTEROP.SUSPENDED.DISCARD";

Parameter REASONSUSPENDEDDISCARD = "Discarding marks each message marked to be discarded as Discarded, so it is no longer suspended and is not processed. The message and its body are kept, and it can still be resent from Messages.";

Parameter SUSPENDEDDELETE = "INTEROP.SUSPENDED.DELETE";

Parameter REASONSUSPENDEDDELETE = "Deleting removes each message marked to be deleted, its body when no other message uses it, and its search table entries. It cannot be undone.";

/// <p>The words of the verdicts a suspended message reads beyond <parameter>VERDICTS</parameter>' (Story 24.16): no longer suspended, and what each action will do.
/// <parameter>OcuPilot.Port.InteropPort.SUSPENDEDVERDICTS</parameter> lists every verdict a suspended action reads.</p>
Parameter VERDICTNOTSUSPENDED = "is no longer suspended";

Parameter VERDICTRESUBMIT = "will be resubmitted";

Parameter VERDICTDISCARD = "will be discarded";

Parameter VERDICTDELETE = "will be deleted";

/// <p>The words that follow a message id in the outcome of a suspended write (Story 24.16): <code>&lt;id&gt;: resubmitted</code> and
/// <code>&lt;id&gt;: not resubmitted: &lt;text&gt;</code>, and so for a discard and a delete.</p>
Parameter OUTCOMERESUBMITTED = "resubmitted";

Parameter OUTCOMENOTRESUBMITTED = "not resubmitted";

Parameter OUTCOMEDISCARDED = "discarded";

Parameter OUTCOMENOTDISCARDED = "not discarded";

Parameter OUTCOMEDELETED = "deleted";

Parameter OUTCOMENOTDELETED = "not deleted";

/// <p>The refusals and words of the message export (Story 24.16 Batch 3): no message that can be exported, a review the messages moved past, and a file over the
/// size OcuPilot sends, each 409; the consequence code the proposal and the dialog carry; the verdicts a message reads before an export
/// (<parameter>EXPORTVERDICTS</parameter>, in the order they are judged) and the words that follow a message id in an outcome line.</p>
Parameter EXPORTNONE = "INTEROP.EXPORT.NONE";

Parameter REASONEXPORTNONE = "None of these messages can be exported. Each one's line says why.";

Parameter EXPORTCHANGED = "INTEROP.EXPORT.CHANGED";

Parameter REASONEXPORTCHANGED = "These messages changed after they were reviewed, so nothing was exported. Review them again.";

Parameter EXPORTTOOLARGE = "INTEROP.EXPORT.TOOLARGE";

Parameter REASONEXPORTTOOLARGE = "The file is larger than OcuPilot imports or exports.";

Parameter MESSAGEEXPORT = "INTEROP.MESSAGE.EXPORT";

Parameter REASONMESSAGEEXPORT = "Exporting saves the body of each message marked to be exported to one file in this browser's downloads, in message id order, each marked off by the chosen separator. Each body exported is recorded in the audit log as viewed. Anyone who can open the file can read the messages.";

Parameter EXPORTVERDICTS = "gone,nobody,notext,export";

Parameter VERDICTEXPORT = "will be exported";

Parameter VERDICTNOTEXT = "its body cannot be exported as text";

Parameter OUTCOMEEXPORTED = "exported";

Parameter OUTCOMENOTEXPORTED = "not exported";

/// <p>The refusals the port answers with, as a <class>%List</class>: every code that is not a
/// consequence.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#NAMESPACE, ..#RUNNING, ..#OTHER, ..#TROUBLED, ..#NOTRUNNING, ..#UPTODATE, ..#NOTTROUBLED, ..#BUSY, ..#STATE, ..#SUSPENDED, ..#PARTSTOPPED) _ ..ItemCodes() _ ..SettingCodes() _ ..RuntimeCodes() _ ..LookupCodes() _ ..PartnerCodes() _ ..DefaultSettingCodes() _ ..CredentialCodes() _ ..ScheduleCodes() _ ..WorkflowCodes() _ ..PurgeCodes() _ ..ArchiveCodes() _ ..AlertCodes() _ ..SuspendedCodes() _ ..TestCodes() _ ..TransformCodes() _ ..MessageCodes() _ ..ExportCodes() _ ..StartupCodes()
}

/// <p>The consequence codes, as a <class>%List</class>.</p>
ClassMethod ConsequenceCodes() As %List
{
    Quit $ListBuild(..#STOP, ..#RESTART, ..#UPDATE, ..#RECOVER, ..#ITEMPENDING, ..#ITEMREMOVE, ..#ITEMCOPY, ..#ITEMCHANGECLASS, ..#SETTINGLOCATION, ..#MESSAGEABORT, ..#QUEUEABORT, ..#JOBABORT, ..#JOBSUSPEND, ..#JOBSTOP, ..#ITEMSTOP, ..#ITEMSTART, ..#ITEMRESTART, ..#LOOKUPREMOVE, ..#LOOKUPDELETE, ..#LOOKUPIMPORT, ..#PARTNERREMOVE, ..#TESTSENDS, ..#TRANSFORMRUNS, ..#MESSAGERESEND, ..#MESSAGEEDITRESEND, ..#AUTOSTART, ..#SHUTDOWNGROUP, ..#DEFAULTSETTINGREMOVE, ..#DEFAULTSETTINGPENDING, ..#CREDENTIALREMOVE, ..#CREDENTIALCHANGE, ..#SCHEDULEREMOVE, ..#SCHEDULECHANGE, ..#PURGERUN, ..#PURGEBITMAP, ..#ARCHIVERUN, ..#SUSPENDEDRESUBMIT, ..#SUSPENDEDEDIT, ..#SUSPENDEDDISCARD, ..#SUSPENDEDDELETE, ..#MESSAGEEXPORT, ..#ALERTUPDATE, ..#RULELOGPURGE, ..#PROCESSLOGPURGE, ..#WORKFLOWUSERREMOVE, ..#WORKFLOWUSERINACTIVE, ..#WORKFLOWROLEREMOVE, ..#WORKFLOWMEMBERADD, ..#WORKFLOWMEMBERREMOVE)
}

/// <p>The item codes, as a <class>%List</class>: the refusals an item read or write answers with.</p>
ClassMethod ItemCodes() As %List
{
    Quit $ListBuild(..#ITEMENABLED, ..#ITEMDISABLED, ..#ITEMDEFAULTSETTING, ..#ITEMPOOLZERO, ..#ITEMTAKEN, ..#ITEMAMBIGUOUS, ..#ITEMCLASS, ..#ITEMNAME, ..#ITEMVALUE, ..#ITEMENABLEDREMOVE, ..#ITEMSOURCECONTROL, ..#ITEMNOTENABLED, ..#ITEMTEMPSTOPPED, ..#ITEMNOTTEMPSTOPPED, ..#ITEMNOJOBS, ..#ITEMSTARTPENDING, ..#ITEMCOPYSOURCE, ..#ITEMNEWCLASS, ..#ITEMSAMECLASS, ..#ITEMREVIEWCHANGED)
}

/// <p>The item refusals an item tool's fresh read answers when the action does not fit the item, and a copy's source refusal, which the
/// write answers under the production's lock, as a
/// <class>%List</class>; the field violations (<parameter>ITEMCLASS</parameter>, <parameter>ITEMNAME</parameter>
/// and <parameter>ITEMVALUE</parameter>) are an add's body and are not among them.</p>
ClassMethod ItemPreconditionCodes() As %List
{
    Quit $ListBuild(..#ITEMENABLED, ..#ITEMDISABLED, ..#ITEMDEFAULTSETTING, ..#ITEMPOOLZERO, ..#ITEMTAKEN, ..#ITEMAMBIGUOUS, ..#ITEMENABLEDREMOVE, ..#ITEMSOURCECONTROL, ..#ITEMNOTENABLED, ..#ITEMTEMPSTOPPED, ..#ITEMNOTTEMPSTOPPED, ..#ITEMNOJOBS, ..#ITEMCOPYSOURCE, ..#ITEMNEWCLASS, ..#ITEMSAMECLASS)
}

/// <p>The setting codes (Story 20.22), as a <class>%List</class>: the refusals an item setting read or write answers
/// with, and the two violations of a set's value.</p>
ClassMethod SettingCodes() As %List
{
    Quit $ListBuild(..#SETTINGSECRET, ..#SETTINGSUPPLIED, ..#SETTINGSAME, ..#SETTINGDEFAULTED, ..#SETTINGCORE, ..#SETTINGVALUE, ..#SETTINGDESCENT)
}

/// <p>The setting refusals a setting tool's fresh read answers when the action does not fit the setting, as a
/// <class>%List</class>; the violations (<parameter>SETTINGVALUE</parameter> and <parameter>SETTINGDESCENT</parameter>)
/// and <parameter>SETTINGSAME</parameter>, which the write alone judges, are not among them.</p>
ClassMethod SettingPreconditionCodes() As %List
{
    Quit $ListBuild(..#SETTINGSECRET, ..#SETTINGSUPPLIED, ..#SETTINGDEFAULTED, ..#SETTINGCORE)
}

/// <p>The queue and job codes (Story 20.23), as a <class>%List</class>: the refusals a queue or job read composed for an
/// action answers with, and the vendor refusal of a stop. The five consequence codes are
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod RuntimeCodes() As %List
{
    Quit $ListBuild(..#QUEUEEMPTY, ..#QUEUECHANGED, ..#JOBDEAD, ..#JOBNOTRETRYING, ..#JOBNOTSTOPPED)
}

/// <p>The lookup codes (Story 20.5), as a <class>%List</class>: the refusals a lookup read or write answers with, the three
/// violations of an entry's table, key and value and the four refusals of an import file and an export. The three consequence
/// codes are <method>ConsequenceCodes</method>'s.</p>
ClassMethod LookupCodes() As %List
{
    Quit $ListBuild(..#LOOKUPTAKEN, ..#LOOKUPTABLECASE, ..#LOOKUPSAME, ..#LOOKUPSECRET, ..#LOOKUPSOURCECONTROL, ..#LOOKUPLOCKED, ..#LOOKUPTABLENAME, ..#LOOKUPKEY, ..#LOOKUPVALUE, ..#LOOKUPIMPORTSHAPE, ..#LOOKUPIMPORTCHANGED, ..#LOOKUPTOOLARGE, ..#LOOKUPEXPORTNAME)
}

/// <p>The lookup refusals an entry tool's fresh read answers when the action does not fit the entry, as a
/// <class>%List</class>; the violations and <parameter>LOOKUPLOCKED</parameter>, which the write alone judges, and
/// <parameter>LOOKUPSAME</parameter>, which the write and the set's mint judge, are not among them.</p>
ClassMethod LookupPreconditionCodes() As %List
{
    Quit $ListBuild(..#LOOKUPTAKEN, ..#LOOKUPTABLECASE, ..#LOOKUPSECRET, ..#LOOKUPSOURCECONTROL)
}

/// <p>The business partner codes (Story 20.26), as a <class>%List</class>: the four refusals a partner read or write answers
/// with, the source control refusal among them, and the two violations of its fields. The one consequence code is
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod PartnerCodes() As %List
{
    Quit $ListBuild(..#PARTNERTAKEN, ..#PARTNERNAMECASE, ..#PARTNERNAMED, ..#PARTNERSOURCECONTROL, ..#PARTNERNAME, ..#PARTNERLENGTH)
}

/// <p>The partner refusals a partner tool's fresh read answers when the action does not fit the partner, as a
/// <class>%List</class>; the two violations, which the write alone judges, are not among them.</p>
ClassMethod PartnerPreconditionCodes() As %List
{
    Quit $ListBuild(..#PARTNERTAKEN, ..#PARTNERNAMECASE, ..#PARTNERNAMED, ..#PARTNERSOURCECONTROL)
}

/// <p>The system default setting codes (Story 24.15), as a <class>%List</class>: the six refusals and violations a default setting read
/// or write answers with, and the comparison's refusal of a namespace with too many settings. The two consequence codes are
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod DefaultSettingCodes() As %List
{
    Quit $ListBuild(..#DEFAULTSETTINGTAKEN, ..#DEFAULTSETTINGSECRET, ..#DEFAULTSETTINGKEY, ..#DEFAULTSETTINGVALUE, ..#DEFAULTSETTINGRESTRICTED, ..#DEFAULTSETTINGSOURCECONTROL, ..#DEFAULTSETTINGTOOMANY)
}

/// <p>The default setting refusals a default setting tool's fresh read answers when the action does not fit the setting, as a
/// <class>%List</class>; the two violations, the restricted refusal and the comparison's refusal, which the write or the comparison
/// alone judges, are not among them.</p>
ClassMethod DefaultSettingPreconditionCodes() As %List
{
    Quit $ListBuild(..#DEFAULTSETTINGTAKEN, ..#DEFAULTSETTINGSECRET, ..#DEFAULTSETTINGSOURCECONTROL)
}

/// <p>The credential codes (Story 24.15), as a <class>%List</class>: the refusal of a name the namespace holds in some letter case and the
/// three violations. The two consequence codes are <method>ConsequenceCodes</method>'s.</p>
ClassMethod CredentialCodes() As %List
{
    Quit $ListBuild(..#CREDENTIALTAKEN, ..#CREDENTIALNAME, ..#CREDENTIALPARTNER, ..#CREDENTIALVALUE)
}

/// <p>The credential refusals a credential tool's fresh read answers when the action does not fit the credential, as a
/// <class>%List</class>; the three violations, which the write alone judges, are not among them.</p>
ClassMethod CredentialPreconditionCodes() As %List
{
    Quit $ListBuild(..#CREDENTIALTAKEN)
}

/// <p>The schedule spec codes (Story 24.15), as a <class>%List</class>: the refusals of a name the namespace holds in some letter case and of a
/// namespace under source control, and the three violations. The two consequence codes are <method>ConsequenceCodes</method>'s.</p>
ClassMethod ScheduleCodes() As %List
{
    Quit $ListBuild(..#SCHEDULETAKEN, ..#SCHEDULENAME, ..#SCHEDULESPEC, ..#SCHEDULEDESCRIPTION, ..#SCHEDULESOURCECONTROL)
}

/// <p>The schedule spec refusals a schedule tool's fresh read answers when the action does not fit the namespace or the schedule spec, as a
/// <class>%List</class>; the three violations, which the write alone judges, are not among them.</p>
ClassMethod SchedulePreconditionCodes() As %List
{
    Quit $ListBuild(..#SCHEDULETAKEN, ..#SCHEDULESOURCECONTROL)
}

/// <p>The workflow codes (Story 24.17 Batch 3a), as a <class>%List</class>: the refusals of a name the namespace holds in some letter case and of a
/// namespace under source control, and the two violations of a new user's name and a full name. The two consequence codes are
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod WorkflowCodes() As %List
{
    Quit $ListBuild(..#WORKFLOWUSERTAKEN, ..#WORKFLOWUSERNAME, ..#WORKFLOWFULLNAME, ..#WORKFLOWSOURCECONTROL, ..#WORKFLOWROLENAME, ..#WORKFLOWROLETAKEN, ..#WORKFLOWROLEDESCRIPTION, ..#WORKFLOWROLECAPACITY, ..#WORKFLOWMEMBERUSER, ..#WORKFLOWMEMBERTAKEN, ..#WORKFLOWMEMBERRANK, ..#WORKFLOWMEMBERTITLE)
}

/// <p>The workflow refusals a workflow user tool's fresh read answers when the action does not fit the namespace or the user, as a
/// <class>%List</class>; the two violations, which the write alone judges, are not among them.</p>
ClassMethod WorkflowPreconditionCodes() As %List
{
    Quit $ListBuild(..#WORKFLOWUSERTAKEN, ..#WORKFLOWSOURCECONTROL)
}

/// <p>The purge codes (Story 24.16), as a <class>%List</class>: the refusal of days that are not a whole number from 0 to 99999 and of a purge
/// that is already running. The two consequence codes are <method>ConsequenceCodes</method>'s.</p>
ClassMethod PurgeCodes() As %List
{
    Quit $ListBuild(..#PURGEDAYS, ..#PURGERUNNING)
}

/// <p>The purge refusal a purge tool's fresh read answers when the action does not fit the namespace: a purge that is already running. The days,
/// which the write alone judges, are not among them.</p>
ClassMethod PurgePreconditionCodes() As %List
{
    Quit $ListBuild(..#PURGERUNNING)
}

/// <p>The archive codes (Story 24.16 Batch 4), as a <class>%List</class>: a run already running, no target, a stored class that is not the vendor's, too many messages in the
/// namespace, and a target that holds an id the run would move. The consequence code is <method>ConsequenceCodes</method>'s.</p>
ClassMethod ArchiveCodes() As %List
{
    Quit $ListBuild(..#ARCHIVERUNNING, ..#ARCHIVENOTARGET, ..#ARCHIVECLASS, ..#ARCHIVETOOMANY, ..#ARCHIVETAKEN)
}

/// <p>The archive refusals an archive tool's fresh read answers when the action does not fit the namespace: the four the namespace itself decides. A target that holds an id the run
/// would move is judged at the write alone, since the review does not read the target.</p>
ClassMethod ArchivePreconditionCodes() As %List
{
    Quit $ListBuild(..#ARCHIVERUNNING, ..#ARCHIVENOTARGET, ..#ARCHIVECLASS, ..#ARCHIVETOOMANY)
}

/// <p>The managed alert codes (Story 24.17 Batch 1), as a <class>%List</class>: an alert that is gone, an update that changes nothing and the four value rules. The consequence code is
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod AlertCodes() As %List
{
    Quit $ListBuild(..#ALERTNOTFOUND, ..#ALERTUNCHANGED, ..#ALERTOWNER, ..#ALERTLEVEL, ..#ALERTNEXTACTION, ..#ALERTREASON)
}

/// <p>The suspended message codes (Story 24.16), as a <class>%List</class>: the refusal of a selection none of which can be acted on and of a selection that changed
/// after it was reviewed. The four consequence codes are <method>ConsequenceCodes</method>'s.</p>
ClassMethod SuspendedCodes() As %List
{
    Quit $ListBuild(..#SUSPENDEDNONE, ..#SUSPENDEDCHANGED)
}

/// <p>The startup codes (Story 24.3), as a <class>%List</class>: the three violations, the refusal of a value the production
/// already holds, the all-namespaces refusal and the read-only refusal. The two consequence codes are
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod StartupCodes() As %List
{
    Quit $ListBuild(..#STARTUPSAME, ..#STARTUPPRIORITY, ..#STARTUPGROUP, ..#STARTUPNOPRIORITY, ..#STARTUPALLNAMESPACES, ..#STARTUPREADONLY)
}

/// <p>The startup refusals a startup tool's fresh read answers when the values do not fit the production: the value it
/// already holds and a priority with auto-start off. The shape violations and the two refusals the write alone judges are not among
/// them.</p>
ClassMethod StartupPreconditionCodes() As %List
{
    Quit $ListBuild(..#STARTUPSAME, ..#STARTUPNOPRIORITY)
}

/// <p>The host test's codes (Story 20.6), as a <class>%List</class>: the five refusals a test is refused with before a request is
/// built and the three violations of its fields. The consequence code is <method>ConsequenceCodes</method>'s.</p>
ClassMethod TestCodes() As %List
{
    Quit $ListBuild(..#TESTDISABLED, ..#TESTTARGETTYPE, ..#TESTTARGETDISABLED, ..#TESTREQUESTTYPE, ..#TESTSECRET, ..#TESTFIELD, ..#TESTVALUE, ..#TESTREQUEST)
}

/// <p>The test refusals the host test tool's fresh read answers when the test does not fit the item, as a <class>%List</class>:
/// the production-not-running refusal and the four that follow it in the read's order, then the credential refusal. The
/// violations (<parameter>TESTFIELD</parameter>, <parameter>TESTVALUE</parameter> and <parameter>TESTREQUEST</parameter>) are the
/// request's and are not among them.</p>
ClassMethod TestPreconditionCodes() As %List
{
    Quit $ListBuild(..#NOTRUNNING, ..#TESTDISABLED, ..#TESTTARGETTYPE, ..#TESTTARGETDISABLED, ..#TESTREQUESTTYPE, ..#TESTSECRET)
}

/// <p>The data transformation test's codes (Story 20.27), as a <class>%List</class>: the two format refusals and the violation of the
/// pasted source message. The consequence code is <method>ConsequenceCodes</method>'s.</p>
ClassMethod TransformCodes() As %List
{
    Quit $ListBuild(..#TRANSFORMSOURCEFORMAT, ..#TRANSFORMTARGETFORMAT, ..#TRANSFORMCONTENT)
}

/// <p>The message codes, as a <class>%List</class>: the contents refusal of a body OcuPilot cannot draw as text (Story 20.9),
/// and the resend and edit-and-resend refusals and violations (Story 20.31). The two consequence codes are
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod MessageCodes() As %List
{
    Quit $ListBuild(..#MESSAGECONTENTS, ..#RESENDNONE, ..#RESENDCHANGED, ..#EDITNOTEDITABLE, ..#EDITNOCHANGE, ..#EDITFIELD, ..#EDITSECRET, ..#EDITVALUE)
}

/// <p>The message export's refusals (Story 24.16 Batch 3), as a <class>%List</class>: none to export, a moved review and a file over the cap. The consequence code is
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod ExportCodes() As %List
{
    Quit $ListBuild(..#EXPORTNONE, ..#EXPORTCHANGED, ..#EXPORTTOOLARGE)
}

/// <p>The words that say <var>pVerdict</var>, one of <parameter>VERDICTS</parameter>, or <code>""</code> for any other.</p>
ClassMethod VerdictSentence(pVerdict As %String) As %String
{
    If pVerdict = "resend" Quit ..#VERDICTRESEND
    If pVerdict = "gone" Quit ..#VERDICTGONE
    If pVerdict = "nobody" Quit ..#VERDICTNOBODY
    If pVerdict = "targetoff" Quit ..#VERDICTTARGETOFF
    If pVerdict = "noreplyqueue" Quit ..#VERDICTNOREPLYQUEUE
    If pVerdict = "notsuspended" Quit ..#VERDICTNOTSUSPENDED
    If pVerdict = "resubmit" Quit ..#VERDICTRESUBMIT
    If pVerdict = "discard" Quit ..#VERDICTDISCARD
    If pVerdict = "delete" Quit ..#VERDICTDELETE
    If pVerdict = "export" Quit ..#VERDICTEXPORT
    If pVerdict = "notext" Quit ..#VERDICTNOTEXT
    Quit ""
}

/// <p>The refusals the data transformation tool's fresh read answers when the transformation cannot be tested, as a
/// <class>%List</class>: the source format, then the target format. The content violation is the pasted message's and is not
/// among them.</p>
ClassMethod TransformPreconditionCodes() As %List
{
    Quit $ListBuild(..#TRANSFORMSOURCEFORMAT, ..#TRANSFORMTARGETFORMAT)
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
    If pCode = ..#ITEMCOPY Quit ..#REASONITEMCOPY
    If pCode = ..#ITEMCOPYSOURCE Quit ..#REASONITEMCOPYSOURCE
    If pCode = ..#ITEMNEWCLASS Quit ..#REASONITEMNEWCLASS
    If pCode = ..#ITEMSAMECLASS Quit ..#REASONITEMSAMECLASS
    If pCode = ..#ITEMREVIEWCHANGED Quit ..#REASONITEMREVIEWCHANGED
    If pCode = ..#ITEMCHANGECLASS Quit ..#REASONITEMCHANGECLASS
    If pCode = ..#ITEMNOTENABLED Quit ..#REASONITEMNOTENABLED
    If pCode = ..#ITEMTEMPSTOPPED Quit ..#REASONITEMTEMPSTOPPED
    If pCode = ..#ITEMNOTTEMPSTOPPED Quit ..#REASONITEMNOTTEMPSTOPPED
    If pCode = ..#ITEMNOJOBS Quit ..#REASONITEMNOJOBS
    If pCode = ..#ITEMSTARTPENDING Quit ..#REASONITEMSTARTPENDING
    If pCode = ..#ITEMSTOP Quit ..#REASONITEMSTOP
    If pCode = ..#ITEMSTART Quit ..#REASONITEMSTART
    If pCode = ..#ITEMRESTART Quit ..#REASONITEMRESTART
    If pCode = ..#SETTINGSECRET Quit ..#REASONSETTINGSECRET
    If pCode = ..#SETTINGSUPPLIED Quit ..#REASONSETTINGSUPPLIED
    If pCode = ..#SETTINGSAME Quit ..#REASONSETTINGSAME
    If pCode = ..#SETTINGDEFAULTED Quit ..#REASONSETTINGDEFAULTED
    If pCode = ..#SETTINGCORE Quit ..#REASONSETTINGCORE
    If pCode = ..#SETTINGVALUE Quit ..#REASONSETTINGVALUE
    If pCode = ..#SETTINGLOCATION Quit ..#REASONSETTINGLOCATION
    If pCode = ..#SETTINGDESCENT Quit ..#REASONSETTINGDESCENT
    If pCode = ..#QUEUEEMPTY Quit ..#REASONQUEUEEMPTY
    If pCode = ..#QUEUECHANGED Quit ..#REASONQUEUECHANGED
    If pCode = ..#JOBDEAD Quit ..#REASONJOBDEAD
    If pCode = ..#JOBNOTRETRYING Quit ..#REASONJOBNOTRETRYING
    If pCode = ..#JOBNOTSTOPPED Quit ..#REASONJOBNOTSTOPPED
    If pCode = ..#MESSAGEABORT Quit ..#REASONMESSAGEABORT
    If pCode = ..#QUEUEABORT Quit ..#REASONQUEUEABORT
    If pCode = ..#JOBABORT Quit ..#REASONJOBABORT
    If pCode = ..#JOBSUSPEND Quit ..#REASONJOBSUSPEND
    If pCode = ..#JOBSTOP Quit ..#REASONJOBSTOP
    If pCode = ..#LOOKUPTAKEN Quit ..#REASONLOOKUPTAKEN
    If pCode = ..#LOOKUPTABLECASE Quit ..#REASONLOOKUPTABLECASE
    If pCode = ..#LOOKUPSAME Quit ..#REASONLOOKUPSAME
    If pCode = ..#LOOKUPSECRET Quit ..#REASONLOOKUPSECRET
    If pCode = ..#LOOKUPSOURCECONTROL Quit ..#REASONLOOKUPSOURCECONTROL
    If pCode = ..#LOOKUPLOCKED Quit ..#REASONLOOKUPLOCKED
    If pCode = ..#LOOKUPTABLENAME Quit ..#REASONLOOKUPTABLENAME
    If pCode = ..#LOOKUPKEY Quit ..#REASONLOOKUPKEY
    If pCode = ..#LOOKUPVALUE Quit ..#REASONLOOKUPVALUE
    If pCode = ..#LOOKUPREMOVE Quit ..#REASONLOOKUPREMOVE
    If pCode = ..#LOOKUPDELETE Quit ..#REASONLOOKUPDELETE
    If pCode = ..#LOOKUPIMPORTSHAPE Quit ..#REASONLOOKUPIMPORTSHAPE
    If pCode = ..#LOOKUPIMPORTCHANGED Quit ..#REASONLOOKUPIMPORTCHANGED
    If pCode = ..#LOOKUPTOOLARGE Quit ..#REASONLOOKUPTOOLARGE
    If pCode = ..#LOOKUPEXPORTNAME Quit ..#REASONLOOKUPEXPORTNAME
    If pCode = ..#LOOKUPIMPORT Quit ..#REASONLOOKUPIMPORT
    If pCode = ..#PARTNERTAKEN Quit ..#REASONPARTNERTAKEN
    If pCode = ..#PARTNERNAMECASE Quit ..#REASONPARTNERNAMECASE
    If pCode = ..#PARTNERNAMED Quit ..#REASONPARTNERNAMED
    If pCode = ..#PARTNERSOURCECONTROL Quit ..#REASONPARTNERSOURCECONTROL
    If pCode = ..#PARTNERNAME Quit ..#REASONPARTNERNAME
    If pCode = ..#PARTNERLENGTH Quit ..#REASONPARTNERLENGTH
    If pCode = ..#PARTNERREMOVE Quit ..#REASONPARTNERREMOVE
    If pCode = ..#DEFAULTSETTINGTAKEN Quit ..#REASONDEFAULTSETTINGTAKEN
    If pCode = ..#DEFAULTSETTINGSECRET Quit ..#REASONDEFAULTSETTINGSECRET
    If pCode = ..#DEFAULTSETTINGKEY Quit ..#REASONDEFAULTSETTINGKEY
    If pCode = ..#DEFAULTSETTINGVALUE Quit ..#REASONDEFAULTSETTINGVALUE
    If pCode = ..#DEFAULTSETTINGRESTRICTED Quit ..#REASONDEFAULTSETTINGRESTRICTED
    If pCode = ..#DEFAULTSETTINGSOURCECONTROL Quit ..#REASONDEFAULTSETTINGSOURCECONTROL
    If pCode = ..#DEFAULTSETTINGTOOMANY Quit ..#REASONDEFAULTSETTINGTOOMANY
    If pCode = ..#DEFAULTSETTINGREMOVE Quit ..#REASONDEFAULTSETTINGREMOVE
    If pCode = ..#DEFAULTSETTINGPENDING Quit ..#REASONDEFAULTSETTINGPENDING
    If pCode = ..#CREDENTIALTAKEN Quit ..#REASONCREDENTIALTAKEN
    If pCode = ..#CREDENTIALNAME Quit ..#REASONCREDENTIALNAME
    If pCode = ..#CREDENTIALPARTNER Quit ..#REASONCREDENTIALPARTNER
    If pCode = ..#CREDENTIALVALUE Quit ..#REASONCREDENTIALVALUE
    If pCode = ..#CREDENTIALREMOVE Quit ..#REASONCREDENTIALREMOVE
    If pCode = ..#CREDENTIALCHANGE Quit ..#REASONCREDENTIALCHANGE
    If pCode = ..#SCHEDULETAKEN Quit ..#REASONSCHEDULETAKEN
    If pCode = ..#SCHEDULENAME Quit ..#REASONSCHEDULENAME
    If pCode = ..#SCHEDULESPEC Quit ..#REASONSCHEDULESPEC
    If pCode = ..#SCHEDULEDESCRIPTION Quit ..#REASONSCHEDULEDESCRIPTION
    If pCode = ..#SCHEDULESOURCECONTROL Quit ..#REASONSCHEDULESOURCECONTROL
    If pCode = ..#SCHEDULEREMOVE Quit ..#REASONSCHEDULEREMOVE
    If pCode = ..#SCHEDULECHANGE Quit ..#REASONSCHEDULECHANGE
    If pCode = ..#WORKFLOWSOURCECONTROL Quit ..#REASONWORKFLOWSOURCECONTROL
    If pCode = ..#WORKFLOWUSERNAME Quit ..#REASONWORKFLOWUSERNAME
    If pCode = ..#WORKFLOWUSERTAKEN Quit ..#REASONWORKFLOWUSERTAKEN
    If pCode = ..#WORKFLOWFULLNAME Quit ..#REASONWORKFLOWFULLNAME
    If pCode = ..#WORKFLOWUSERREMOVE Quit ..#REASONWORKFLOWUSERREMOVE
    If pCode = ..#WORKFLOWUSERINACTIVE Quit ..#REASONWORKFLOWUSERINACTIVE
    If pCode = ..#WORKFLOWROLENAME Quit ..#REASONWORKFLOWROLENAME
    If pCode = ..#WORKFLOWROLETAKEN Quit ..#REASONWORKFLOWROLETAKEN
    If pCode = ..#WORKFLOWROLEDESCRIPTION Quit ..#REASONWORKFLOWROLEDESCRIPTION
    If pCode = ..#WORKFLOWROLECAPACITY Quit ..#REASONWORKFLOWROLECAPACITY
    If pCode = ..#WORKFLOWMEMBERUSER Quit ..#REASONWORKFLOWMEMBERUSER
    If pCode = ..#WORKFLOWMEMBERTAKEN Quit ..#REASONWORKFLOWMEMBERTAKEN
    If pCode = ..#WORKFLOWMEMBERRANK Quit ..#REASONWORKFLOWMEMBERRANK
    If pCode = ..#WORKFLOWMEMBERTITLE Quit ..#REASONWORKFLOWMEMBERTITLE
    If pCode = ..#WORKFLOWROLEREMOVE Quit ..#REASONWORKFLOWROLEREMOVE
    If pCode = ..#WORKFLOWMEMBERADD Quit ..#REASONWORKFLOWMEMBERADD
    If pCode = ..#WORKFLOWMEMBERREMOVE Quit ..#REASONWORKFLOWMEMBERREMOVE
    If pCode = ..#PURGEDAYS Quit ..#REASONPURGEDAYS
    If pCode = ..#PURGERUNNING Quit ..#REASONPURGERUNNING
    If pCode = ..#PURGERUN Quit ..#REASONPURGERUN
    If pCode = ..#PURGEBITMAP Quit ..#REASONPURGEBITMAP
    If pCode = ..#RULELOGPURGE Quit ..#REASONRULELOGPURGE
    If pCode = ..#PROCESSLOGPURGE Quit ..#REASONPROCESSLOGPURGE
    If pCode = ..#ARCHIVERUNNING Quit ..#REASONARCHIVERUNNING
    If pCode = ..#ARCHIVENOTARGET Quit ..#REASONARCHIVENOTARGET
    If pCode = ..#ARCHIVECLASS Quit ..#REASONARCHIVECLASS
    If pCode = ..#ARCHIVETOOMANY Quit ..#REASONARCHIVETOOMANY
    If pCode = ..#ARCHIVETAKEN Quit ..#REASONARCHIVETAKEN
    If pCode = ..#ARCHIVERUN Quit ..#REASONARCHIVERUN
    If pCode = ..#ALERTNOTFOUND Quit ..#REASONALERTNOTFOUND
    If pCode = ..#ALERTUNCHANGED Quit ..#REASONALERTUNCHANGED
    If pCode = ..#ALERTOWNER Quit ..#REASONALERTOWNER
    If pCode = ..#ALERTLEVEL Quit ..#REASONALERTLEVEL
    If pCode = ..#ALERTNEXTACTION Quit ..#REASONALERTNEXTACTION
    If pCode = ..#ALERTREASON Quit ..#REASONALERTREASON
    If pCode = ..#ALERTUPDATE Quit ..#REASONALERTUPDATE
    If pCode = ..#STARTUPSAME Quit ..#REASONSTARTUPSAME
    If pCode = ..#STARTUPPRIORITY Quit ..#REASONSTARTUPPRIORITY
    If pCode = ..#STARTUPGROUP Quit ..#REASONSTARTUPGROUP
    If pCode = ..#STARTUPNOPRIORITY Quit ..#REASONSTARTUPNOPRIORITY
    If pCode = ..#STARTUPALLNAMESPACES Quit ..#REASONSTARTUPALLNAMESPACES
    If pCode = ..#STARTUPREADONLY Quit ..#REASONSTARTUPREADONLY
    If pCode = ..#AUTOSTART Quit ..#REASONAUTOSTART
    If pCode = ..#SHUTDOWNGROUP Quit ..#REASONSHUTDOWNGROUP
    If pCode = ..#TESTDISABLED Quit ..#REASONTESTDISABLED
    If pCode = ..#TESTTARGETTYPE Quit ..#REASONTESTTARGETTYPE
    If pCode = ..#TESTTARGETDISABLED Quit ..#REASONTESTTARGETDISABLED
    If pCode = ..#TESTREQUESTTYPE Quit ..#REASONTESTREQUESTTYPE
    If pCode = ..#TESTSECRET Quit ..#REASONTESTSECRET
    If pCode = ..#TESTFIELD Quit ..#REASONTESTFIELD
    If pCode = ..#TESTVALUE Quit ..#REASONTESTVALUE
    If pCode = ..#TESTREQUEST Quit ..#REASONTESTREQUEST
    If pCode = ..#TESTSENDS Quit ..#REASONTESTSENDS
    If pCode = ..#TRANSFORMSOURCEFORMAT Quit ..#REASONTRANSFORMSOURCEFORMAT
    If pCode = ..#TRANSFORMTARGETFORMAT Quit ..#REASONTRANSFORMTARGETFORMAT
    If pCode = ..#TRANSFORMCONTENT Quit ..#REASONTRANSFORMCONTENT
    If pCode = ..#TRANSFORMRUNS Quit ..#REASONTRANSFORMRUNS
    If pCode = ..#MESSAGECONTENTS Quit ..#REASONMESSAGECONTENTS
    If pCode = ..#RESENDNONE Quit ..#REASONRESENDNONE
    If pCode = ..#RESENDCHANGED Quit ..#REASONRESENDCHANGED
    If pCode = ..#EDITNOTEDITABLE Quit ..#REASONEDITNOTEDITABLE
    If pCode = ..#EDITNOCHANGE Quit ..#REASONEDITNOCHANGE
    If pCode = ..#EDITFIELD Quit ..#REASONEDITFIELD
    If pCode = ..#EDITSECRET Quit ..#REASONEDITSECRET
    If pCode = ..#EDITVALUE Quit ..#REASONEDITVALUE
    If pCode = ..#MESSAGERESEND Quit ..#REASONMESSAGERESEND
    If pCode = ..#MESSAGEEDITRESEND Quit ..#REASONMESSAGEEDITRESEND
    If pCode = ..#SUSPENDEDNONE Quit ..#REASONSUSPENDEDNONE
    If pCode = ..#SUSPENDEDCHANGED Quit ..#REASONSUSPENDEDCHANGED
    If pCode = ..#SUSPENDEDRESUBMIT Quit ..#REASONSUSPENDEDRESUBMIT
    If pCode = ..#SUSPENDEDEDIT Quit ..#REASONSUSPENDEDEDIT
    If pCode = ..#SUSPENDEDDISCARD Quit ..#REASONSUSPENDEDDISCARD
    If pCode = ..#SUSPENDEDDELETE Quit ..#REASONSUSPENDEDDELETE
    If pCode = ..#EXPORTNONE Quit ..#REASONEXPORTNONE
    If pCode = ..#EXPORTCHANGED Quit ..#REASONEXPORTCHANGED
    If pCode = ..#EXPORTTOOLARGE Quit ..#REASONEXPORTTOOLARGE
    If pCode = ..#MESSAGEEXPORT Quit ..#REASONMESSAGEEXPORT
    Quit ""
}

}
