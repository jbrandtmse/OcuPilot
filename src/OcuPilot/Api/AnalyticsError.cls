/// <p>The analytics codes and sentences (AD-29, AD-39, AD-65, Story 20.11): every <code>ANALYTICS.*</code> code
/// <class>OcuPilot.Port.AnalyticsPort</class> answers with, and the sentence each carries. Each sentence is
/// published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/analytics.test.mjs</file>. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000
/// parameters (ERROR #5290).</p>
/// <p>Every refusal is rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409: the
/// vendor's analytics classes check no <code>%DeepSee_*</code> resource, so the port decides before any call. The
/// <code>ANALYTICS.MDX.*</code> codes (Story 20.33) are MDX query's, each on the slug and status its comment names;
/// <code>ANALYTICS.MDX.SQL</code> (Story 20.35) is the agent's MDX read's.</p>
Class OcuPilot.Api.AnalyticsError Extends %RegisteredObject
{

/// <p>The route's namespace does not report analytics.</p>
Parameter NAMESPACE = "ANALYTICS.NAMESPACE";

Parameter REASONNAMESPACE = "Analytics is not enabled in this namespace.";

/// <p>400: the statement is empty or too long, or a drill-through does not name one cell of the answer.</p>
Parameter MDXINPUT = "ANALYTICS.MDX.INPUT";

Parameter REASONMDXINPUT = "Send one MDX statement of up to 100,000 characters; a drill-through names one cell of its answer.";

/// <p>422: the statement is not a SELECT or a DRILLTHROUGH.</p>
Parameter MDXKIND = "ANALYTICS.MDX.KIND";

Parameter REASONMDXKIND = "Only SELECT and DRILLTHROUGH statements run here; CREATE and DROP change only a session, which this tool does not keep.";

/// <p>422: the statement names more than two axes.</p>
Parameter MDXAXES = "ANALYTICS.MDX.AXES";

Parameter REASONMDXAXES = "A query here uses at most two axes: columns and rows.";

/// <p>409: the database the vendor keeps its result cache in is read-only.</p>
Parameter MDXREADONLY = "ANALYTICS.MDX.READONLY";

Parameter REASONMDXREADONLY = "This namespace keeps its analytics cache in a read-only database, so MDX cannot run here.";

/// <p>409: the caller already has an MDX run live.</p>
Parameter MDXBUSY = "ANALYTICS.MDX.BUSY";

Parameter REASONMDXBUSY = "An MDX query you started is still running; cancel it or wait for it to end.";

/// <p>503: the instance's live background runs, of every kind together, are at their cap.</p>
Parameter MDXFULL = "ANALYTICS.MDX.FULL";

Parameter REASONMDXFULL = "As many background queries as this instance allows are running, SQL and MDX together; try again when one ends.";

/// <p>404: no MDX run of the caller's has this id, or it has been swept.</p>
Parameter MDXNOTFOUND = "ANALYTICS.MDX.NOTFOUND";

Parameter REASONMDXNOTFOUND = "No MDX run of yours has this id; an ended run is kept for 15 minutes.";

/// <p>503: the run ended without an answer.</p>
Parameter MDXLOST = "ANALYTICS.MDX.LOST";

Parameter REASONMDXLOST = "The MDX run ended without an answer; run it again.";

/// <p>422: the agent's MDX read refuses a statement that may run server-side code or SQL, or that cannot be read as MDX.</p>
Parameter MDXSQL = "ANALYTICS.MDX.SQL";

Parameter REASONMDXSQL = "This query may run server-side code or SQL, which the agent's read never runs; you can run it yourself on MDX query after confirming.";

/// <p>409: a cube this build or synchronize reaches, the target or a cube that depends on it, is being built or synchronized now
/// (Story 20.34).</p>
Parameter CUBEBUSY = "ANALYTICS.CUBE.BUSY";

Parameter REASONCUBEBUSY = "This cube, or a cube that depends on it, is being built or synchronized now. Try again when that ends.";

/// <p>409: a synchronize of a cube, or of a cube that depends on it, whose source does not record its changes (DSTIME).</p>
Parameter CUBENODSTIME = "ANALYTICS.CUBE.NODSTIME";

Parameter REASONCUBENODSTIME = "This cube, or a cube that depends on it, has a source that does not record its changes (DSTIME), so it can only be built.";

/// <p>409: a synchronize of a cube, or of a cube that depends on it, that has never been built.</p>
Parameter CUBENOTBUILT = "ANALYTICS.CUBE.NOTBUILT";

Parameter REASONCUBENOTBUILT = "This cube, or a cube that depends on it, has never been built, so there is nothing to synchronize. Build it first.";

/// <p>409: the database the namespace keeps its cubes' facts in is read-only or not mounted.</p>
Parameter CUBEREADONLY = "ANALYTICS.CUBE.READONLY";

Parameter REASONCUBEREADONLY = "This namespace keeps its cubes' facts in a read-only database, so they cannot be built or synchronized here.";

/// <p>409: the instance answered a build or synchronize with an error it was not asked about by name; its text is logged, never sent.</p>
Parameter CUBEFAILED = "ANALYTICS.CUBE.FAILED";

Parameter REASONCUBEFAILED = "The instance answered this update with an error, so it may not have finished. The cube's Facts and Last update show what it holds now.";

/// <p>The consequence code of a build, which the proposal card and the typed-name dialog name.</p>
Parameter CUBEBUILD = "ANALYTICS.CUBE.BUILD";

/// <p>The consequence code of a synchronize.</p>
Parameter CUBESYNCHRONIZE = "ANALYTICS.CUBE.SYNCHRONIZE";

/// <p>409: a create whose name matches an existing term list without regard to case (Story 24.2).</p>
Parameter TERMLISTTAKEN = "ANALYTICS.TERMLIST.TAKEN";

Parameter REASONTERMLISTTAKEN = "This namespace already holds a term list with that name. Names are compared without regard to case.";

/// <p>409: an entry add whose key the term list already holds.</p>
Parameter TERMLISTENTRYTAKEN = "ANALYTICS.TERMLIST.ENTRYTAKEN";

Parameter REASONTERMLISTENTRYTAKEN = "This term list already holds an entry with that key.";

/// <p>404: the term list is not there.</p>
Parameter TERMLISTABSENT = "ANALYTICS.TERMLIST.ABSENT";

Parameter REASONTERMLISTABSENT = "This term list no longer exists.";

/// <p>422: a term list name, an entry key or a field name that breaks its shape rule (<method>OcuPilot.Port.AnalyticsPort.TermListViolations</method>).</p>
Parameter TERMLISTNAME = "ANALYTICS.TERMLIST.NAME";

Parameter REASONTERMLISTNAME = "A term list name is 1 to 255 characters with no control character, within the length the instance can store.";

Parameter TERMLISTKEY = "ANALYTICS.TERMLIST.KEY";

Parameter REASONTERMLISTKEY = "An entry key is 1 to 255 characters with no control character and no ^, within the length the instance can store.";

Parameter TERMLISTFIELD = "ANALYTICS.TERMLIST.FIELD";

Parameter REASONTERMLISTFIELD = "A field name is 1 to 255 characters with no control character and no ^. It is not Value, and no two fields share a name. A term list has at most 50 fields.";

/// <p>422: an entry value names a field the term list does not hold.</p>
Parameter TERMLISTNOFIELD = "ANALYTICS.TERMLIST.NOFIELD";

Parameter REASONTERMLISTNOFIELD = "This term list has no field of that name.";

/// <p>422: a field leaves the term list while an entry holds a value for it.</p>
Parameter TERMLISTFIELDINUSE = "ANALYTICS.TERMLIST.FIELDINUSE";

Parameter REASONTERMLISTFIELDINUSE = "Some entries hold a value for this field. Clear those values first, then remove the field.";

/// <p>422: a caption, pattern, subject area, description or value over its length.</p>
Parameter TERMLISTVALUE = "ANALYTICS.TERMLIST.VALUE";

Parameter REASONTERMLISTVALUE = "A caption, pattern or subject area is at most 255 characters, and a description or value at most 32,000.";

/// <p>409: the database that holds the namespace's term lists is read-only or not mounted.</p>
Parameter TERMLISTREADONLY = "ANALYTICS.TERMLIST.READONLY";

Parameter REASONTERMLISTREADONLY = "The database that holds this namespace's term lists is read-only, so nothing was written.";

/// <p>409: the database that holds the namespace's term lists is not journaled, so a write could be left half done.</p>
Parameter TERMLISTNOTJOURNALED = "ANALYTICS.TERMLIST.NOTJOURNALED";

Parameter REASONTERMLISTNOTJOURNALED = "Term lists can be changed only in a journaled database, so that a change is never left half done. Journaling is off for the database that holds this namespace's term lists.";

/// <p>409: a term list file or export holds more than the product transfers (Story 24.10).</p>
Parameter TERMLISTTOOLARGE = "ANALYTICS.TERMLIST.TOOLARGE";

Parameter REASONTERMLISTTOOLARGE = "The file is larger than OcuPilot imports or exports.";

/// <p>409: an import file is not a term list export, holds no entry, or holds another list than the one the call names.</p>
Parameter TERMLISTIMPORTSHAPE = "ANALYTICS.TERMLIST.IMPORTSHAPE";

Parameter REASONTERMLISTIMPORTSHAPE = "This file is not a term list export, or it holds no entry.";

/// <p>409: the import file no longer reads as it did when it was reviewed.</p>
Parameter TERMLISTIMPORTCHANGED = "ANALYTICS.TERMLIST.IMPORTCHANGED";

Parameter REASONTERMLISTIMPORTCHANGED = "The file changed after it was reviewed, so nothing was imported.";

/// <p>409: an import file names a folder item the namespace already holds, in any letter case and whoever may see it (Story 24.10).</p>
Parameter FOLDERITEMTAKEN = "ANALYTICS.FOLDERITEM.TAKEN";

Parameter REASONFOLDERITEMTAKEN = "This namespace already holds a folder item with a name in this file. Names are compared without regard to case.";

/// <p>404: the folder item is not there, or not shown to the caller.</p>
Parameter FOLDERITEMABSENT = "ANALYTICS.FOLDERITEM.ABSENT";

Parameter REASONFOLDERITEMABSENT = "This folder item no longer exists.";

/// <p>409: the folder item is not a pivot on a cube this namespace holds, so its MDX cannot be composed and run here (Story 24.14).</p>
Parameter PIVOTCUBE = "ANALYTICS.PIVOT.CUBE";

Parameter REASONPIVOTCUBE = "This folder item is not a pivot on a cube this namespace holds, so it runs only in the classic portal.";

/// <p>The PMML model tester's refusals (Story 24.14): 400, the body or the data source is not one this model offers; 404, the model is not there; 422, the SQL data source is not a query; 409, a cube
/// data source's cube is not one the caller may read, and the caller's own run is still going; 503, the instance's runs are all busy, and a run that ended without an answer; 404, no run of the caller has the id.</p>
Parameter PMMLINPUT = "ANALYTICS.PMML.INPUT";

Parameter REASONPMMLINPUT = "Choose one of this model's data sources; a custom data source is one SQL query.";

Parameter PMMLABSENT = "ANALYTICS.PMML.ABSENT";

Parameter REASONPMMLABSENT = "This PMML model no longer exists.";

Parameter PMMLQUERYONLY = "ANALYTICS.PMML.QUERYONLY";

Parameter REASONPMMLQUERYONLY = "A model is tested here only against an SQL query; this data source is not one.";

Parameter PMMLCUBE = "ANALYTICS.PMML.CUBE";

Parameter REASONPMMLCUBE = "This data source's cube is not one this namespace holds, or you cannot read it.";

Parameter PMMLBUSY = "ANALYTICS.PMML.BUSY";

Parameter REASONPMMLBUSY = "A PMML test you started is still running; cancel it or wait for it to end.";

Parameter PMMLFULL = "ANALYTICS.PMML.FULL";

Parameter REASONPMMLFULL = "As many background runs as this instance allows are running; try again when one ends.";

Parameter PMMLNOTFOUND = "ANALYTICS.PMML.NOTFOUND";

Parameter REASONPMMLNOTFOUND = "No PMML test of yours has this id; an ended run is kept for 15 minutes.";

Parameter PMMLLOST = "ANALYTICS.PMML.LOST";

Parameter REASONPMMLLOST = "The PMML test ended without an answer; run it again.";

/// <p>The PMML definition create's refusals (Story 24.14, Batch 3): 422, the class name is not one a definition can take; 409, the class or a class of its package is held; 422, the text is empty, too long, or holds
/// a document type declaration or a <code>}</code>; 422, the instance refused to compile the definition; 409, the database that holds the namespace's classes is read-only. <code>PMMLSAVE</code> is the create's
/// consequence code.</p>
Parameter PMMLCLASS = "ANALYTICS.PMML.CLASS";

Parameter REASONPMMLCLASS = "Name the class with letters, digits and dots, outside the % and OcuPilot packages.";

Parameter PMMLTAKEN = "ANALYTICS.PMML.TAKEN";

Parameter REASONPMMLTAKEN = "This namespace already holds this class, or classes in its package.";

Parameter PMMLTEXT = "ANALYTICS.PMML.TEXT";

Parameter REASONPMMLTEXT = "Paste one PMML document of at most 3,000,000 characters, with no document type declaration and no } character.";

Parameter PMMLCOMPILE = "ANALYTICS.PMML.COMPILE";

Parameter REASONPMMLCOMPILE = "The instance refused to compile the PMML definition, so nothing was changed.";

Parameter PMMLREADONLY = "ANALYTICS.PMML.READONLY";

Parameter REASONPMMLREADONLY = "The database that holds this namespace's classes is read-only.";

Parameter PMMLSAVE = "ANALYTICS.PMML.SAVE";

/// <p>The PMML export to a cube's refusals (Story 24.14, Batch 4): 422, the result class and the cube class are one class or one is in the other's package; 409, the namespace holds a cube of that name; 422, the cube name
/// is outside 1 to 250 characters or holds a control character or a <code>}</code>; 422, the class to link to is not one the namespace holds; 422, the export's own test did not finish; 422, the instance refused
/// the export's classes or rows. <code>PMMLEXPORT</code> is the export's consequence code.</p>
Parameter PMMLSAME = "ANALYTICS.PMML.SAME";

Parameter REASONPMMLSAME = "The result class and the cube class must be two classes, neither in the other's package.";

Parameter PMMLCUBETAKEN = "ANALYTICS.PMML.CUBETAKEN";

Parameter REASONPMMLCUBETAKEN = "This namespace already holds a cube with this name.";

Parameter PMMLCUBENAME = "ANALYTICS.PMML.CUBENAME";

Parameter REASONPMMLCUBENAME = "A cube name is 1 to 250 characters, with no control character and no } character.";

Parameter PMMLSOURCECLASS = "ANALYTICS.PMML.SOURCECLASS";

Parameter REASONPMMLSOURCECLASS = "The class to link to is not one this namespace holds.";

Parameter PMMLEXPORTRUN = "ANALYTICS.PMML.EXPORTRUN";

Parameter REASONPMMLEXPORTRUN = "The test did not finish, so nothing was exported.";

Parameter PMMLEXPORTCOMPILE = "ANALYTICS.PMML.EXPORTCOMPILE";

Parameter REASONPMMLEXPORTCOMPILE = "The instance refused the export's classes or rows, so nothing was changed.";

Parameter PMMLEXPORT = "ANALYTICS.PMML.EXPORT";

/// <p>409: a delete of a locked folder item.</p>
Parameter FOLDERITEMLOCKED = "ANALYTICS.FOLDERITEM.LOCKED";

Parameter REASONFOLDERITEMLOCKED = "This folder item is locked, so it cannot be deleted.";

/// <p>409: the database that holds the namespace's folder items is read-only or not mounted.</p>
Parameter FOLDERITEMREADONLY = "ANALYTICS.FOLDERITEM.READONLY";

Parameter REASONFOLDERITEMREADONLY = "The database that holds this namespace's folder items is read-only, so nothing was written.";

/// <p>409: the database that holds the namespace's folder items is not journaled, so an import could be left half done.</p>
Parameter FOLDERITEMNOTJOURNALED = "ANALYTICS.FOLDERITEM.NOTJOURNALED";

Parameter REASONFOLDERITEMNOTJOURNALED = "Folder items can be changed only in a journaled database, so that a change is never left half done. Journaling is off for the database that holds this namespace's folder items.";

/// <p>409: a folder item file or export holds more than the product transfers (Story 24.10).</p>
Parameter FOLDERITEMTOOLARGE = "ANALYTICS.FOLDERITEM.TOOLARGE";

Parameter REASONFOLDERITEMTOOLARGE = "The file is larger than OcuPilot imports or exports.";

/// <p>409: an import file holds no folder item, or holds something other than folder items.</p>
Parameter FOLDERITEMIMPORTSHAPE = "ANALYTICS.FOLDERITEM.IMPORTSHAPE";

Parameter REASONFOLDERITEMIMPORTSHAPE = "This file holds no folder item, or something other than folder items.";

/// <p>409: the import file no longer reads as it did when it was reviewed.</p>
Parameter FOLDERITEMIMPORTCHANGED = "ANALYTICS.FOLDERITEM.IMPORTCHANGED";

Parameter REASONFOLDERITEMIMPORTCHANGED = "The file changed after it was reviewed, so nothing was imported.";

/// <p>409: a listing group add or copy whose name matches a group the namespace holds, or whose class is already defined (Story 24.11).</p>
Parameter LISTINGGROUPTAKEN = "ANALYTICS.LISTINGGROUP.TAKEN";

Parameter REASONLISTINGGROUPTAKEN = "This namespace already holds a listing group or class with that name.";

/// <p>422: a listing group class name that is malformed, begins with <code>%</code> or is in an <code>OcuPilot</code> package.</p>
Parameter LISTINGGROUPCLASS = "ANALYTICS.LISTINGGROUP.CLASS";

Parameter REASONLISTINGGROUPCLASS = "Name the class with letters, digits and dots, outside the % and OcuPilot packages.";

/// <p>422: a target cube that does not exist or does not accept listing groups.</p>
Parameter LISTINGGROUPCUBE = "ANALYTICS.LISTINGGROUP.CUBE";

Parameter REASONLISTINGGROUPCUBE = "A target cube does not exist or does not accept listing groups.";

/// <p>409: a listing the group repeats, or that a target cube or another listing group already defines.</p>
Parameter LISTINGGROUPLISTINGTAKEN = "ANALYTICS.LISTINGGROUP.LISTINGTAKEN";

Parameter REASONLISTINGGROUPLISTINGTAKEN = "A listing of this group is already defined for a target cube. Choose other target cubes.";

/// <p>409: two classes declare the listing group's name, so a write keyed by the name cannot tell which to change.</p>
Parameter LISTINGGROUPAMBIGUOUS = "ANALYTICS.LISTINGGROUP.AMBIGUOUS";

Parameter REASONLISTINGGROUPAMBIGUOUS = "Two classes define this listing group. Change it in its class instead.";

/// <p>422: the instance refused to compile the listing group's class, and the write was undone.</p>
Parameter LISTINGGROUPCOMPILE = "ANALYTICS.LISTINGGROUP.COMPILE";

Parameter REASONLISTINGGROUPCOMPILE = "The instance refused to compile the listing group, so nothing was changed.";

/// <p>404: the listing group, or the listing, is not there.</p>
Parameter LISTINGGROUPABSENT = "ANALYTICS.LISTINGGROUP.ABSENT";

Parameter REASONLISTINGGROUPABSENT = "This listing group or listing no longer exists.";

/// <p>409: the database that holds the namespace's listing groups is read-only or not mounted.</p>
Parameter LISTINGGROUPREADONLY = "ANALYTICS.LISTINGGROUP.READONLY";

Parameter REASONLISTINGGROUPREADONLY = "The database that holds listing groups is read-only.";

/// <p>The consequence codes of the listing group delete, the listing remove, a listing that sets SQL, and every other listing group write (Story 24.11).</p>
Parameter LISTINGGROUPDELETE = "ANALYTICS.LISTINGGROUP.DELETE";

Parameter LISTINGGROUPREMOVE = "ANALYTICS.LISTINGGROUP.REMOVE";

Parameter LISTINGGROUPSQL = "ANALYTICS.LISTINGGROUP.SQL";

Parameter LISTINGGROUPSAVE = "ANALYTICS.LISTINGGROUP.SAVE";

/// <p>409: a quality measure add or copy whose name is listed or registered, or whose class is already defined (Story 24.12).</p>
Parameter QUALITYMEASURETAKEN = "ANALYTICS.QUALITYMEASURE.TAKEN";

Parameter REASONQUALITYMEASURETAKEN = "This namespace already holds a quality measure or class with that name.";

/// <p>409: two classes declare the quality measure's name, so a write keyed by the name cannot tell which to change.</p>
Parameter QUALITYMEASUREAMBIGUOUS = "ANALYTICS.QUALITYMEASURE.AMBIGUOUS";

Parameter REASONQUALITYMEASUREAMBIGUOUS = "Two classes define this quality measure. Change it in its class instead.";

/// <p>422: the instance refused to compile the quality measure's class, or its model does not validate, and the write was undone or never made.</p>
Parameter QUALITYMEASURECOMPILE = "ANALYTICS.QUALITYMEASURE.COMPILE";

Parameter REASONQUALITYMEASURECOMPILE = "The instance refused to compile the quality measure, so nothing was changed.";

/// <p>404: the quality measure is not there.</p>
Parameter QUALITYMEASUREABSENT = "ANALYTICS.QUALITYMEASURE.ABSENT";

Parameter REASONQUALITYMEASUREABSENT = "This quality measure no longer exists.";

/// <p>409: the database that holds the namespace's quality measures is read-only or not mounted.</p>
Parameter QUALITYMEASUREREADONLY = "ANALYTICS.QUALITYMEASURE.READONLY";

Parameter REASONQUALITYMEASUREREADONLY = "The database that holds quality measures is read-only.";

/// <p>422: the expression names a group the measure does not hold or whose elements are all disabled, or its brackets do not match.</p>
Parameter QUALITYMEASUREEXPRESSION = "ANALYTICS.QUALITYMEASURE.EXPRESSION";

Parameter REASONQUALITYMEASUREEXPRESSION = "The expression names a group this quality measure does not hold, or its brackets do not match.";

/// <p>409: a quality measure linked to another measure, whose expression, format and URL the master defines, cannot have them changed.</p>
Parameter QUALITYMEASURELINKED = "ANALYTICS.QUALITYMEASURE.LINKED";

Parameter REASONQUALITYMEASURELINKED = "This quality measure is linked to another measure, which defines its expression, format and URL.";

/// <p>422: a quality measure class name that is malformed, begins with <code>%</code> or is in an <code>OcuPilot</code> package; the listing groups' sentence.</p>
Parameter QUALITYMEASURECLASS = "ANALYTICS.QUALITYMEASURE.CLASS";

Parameter REASONQUALITYMEASURECLASS = "Name the class with letters, digits and dots, outside the % and OcuPilot packages.";

/// <p>409: the group the element add names already holds an element of that name, without regard to case, disabled or not.</p>
Parameter QUALITYMEASUREELEMENTTAKEN = "ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN";

Parameter REASONQUALITYMEASUREELEMENTTAKEN = "This group already holds an element with that name.";

/// <p>409: the quality measure already holds a documentation item of that name, without regard to case, disabled or not.</p>
Parameter QUALITYMEASUREMETATAKEN = "ANALYTICS.QUALITYMEASURE.METATAKEN";

Parameter REASONQUALITYMEASUREMETATAKEN = "This quality measure already holds a documentation item with that name.";

/// <p>404: the group, element or documentation item the write names is not there.</p>
Parameter QUALITYMEASUREPARTABSENT = "ANALYTICS.QUALITYMEASURE.PARTABSENT";

Parameter REASONQUALITYMEASUREPARTABSENT = "This group, element or documentation item no longer exists.";

/// <p>409: a linked quality measure's groups and documentation are its master's, which the classic page shows read-only.</p>
Parameter QUALITYMEASURELINKEDPARTS = "ANALYTICS.QUALITYMEASURE.LINKEDPARTS";

Parameter REASONQUALITYMEASURELINKEDPARTS = "This quality measure is linked to another measure, which defines its groups and documentation.";

/// <p>The consequence codes of the quality measure delete, of the removal of a group, element or documentation item, and of every other quality measure write (Story 24.12).</p>
Parameter QUALITYMEASUREDELETE = "ANALYTICS.QUALITYMEASURE.DELETE";

Parameter QUALITYMEASUREREMOVE = "ANALYTICS.QUALITYMEASURE.REMOVE";

Parameter QUALITYMEASURESAVE = "ANALYTICS.QUALITYMEASURE.SAVE";

/// <p>409: the database that holds the namespace's analytics settings is read-only (Story 24.13).</p>
Parameter SETTINGREADONLY = "ANALYTICS.SETTING.READONLY";

Parameter REASONSETTINGREADONLY = "The database that holds this namespace's analytics settings is read-only.";

/// <p>409: the setting is a secret, which only its own action sets.</p>
Parameter SETTINGSECRET = "ANALYTICS.SETTING.SECRET";

Parameter REASONSETTINGSECRET = "This setting is a secret. It is set with its own action, which asks for the value when it is confirmed.";

/// <p>The consequence code of a general setting write that stores every general setting, as the classic page's Save does.</p>
Parameter SETTINGSAVE = "ANALYTICS.SETTING.SAVE";

Parameter REASONSETTINGSAVE = "Saving stores every general setting with the value shown here, as the classic page's Save does.";

/// <p>409: the worklists are not customized in this namespace, so a show or hide changes nothing the portal reads.</p>
Parameter WORKLISTNOTCUSTOMIZED = "ANALYTICS.WORKLIST.NOTCUSTOMIZED";

Parameter REASONWORKLISTNOTCUSTOMIZED = "Worklists are not customized in this namespace, so the portal shows its default worklists. Set Worklist to 1 on the General tab first.";

/// <p>404: no worklist option has that page, panel and class.</p>
Parameter WORKLISTABSENT = "ANALYTICS.WORKLIST.ABSENT";

Parameter REASONWORKLISTABSENT = "There is no worklist with that page, panel and class.";

/// <p>409: the namespace already holds a run-time variable, or a user-defined icon, with the name an add names (Story 24.13, Batch 3).</p>
Parameter VARIABLETAKEN = "ANALYTICS.VARIABLE.TAKEN";

Parameter REASONVARIABLETAKEN = "This namespace already holds a run-time variable with that name.";

Parameter ICONTAKEN = "ANALYTICS.ICON.TAKEN";

Parameter REASONICONTAKEN = "This namespace already holds a user-defined icon with that name.";

/// <p>404: the run-time variable, or the user-defined icon, a change or a removal names is not there.</p>
Parameter VARIABLEABSENT = "ANALYTICS.VARIABLE.ABSENT";

Parameter REASONVARIABLEABSENT = "This run-time variable no longer exists.";

Parameter ICONABSENT = "ANALYTICS.ICON.ABSENT";

Parameter REASONICONABSENT = "This user-defined icon no longer exists.";

/// <p>400: a name is not 1 to 255 characters with no control character, or is longer than the instance can store.</p>
Parameter SETTINGNAME = "ANALYTICS.SETTING.NAME";

Parameter REASONSETTINGNAME = "A name is 1 to 255 characters with no control character, within the length the instance can store.";

/// <p>400: an expression, comment, context or path is not text of at most 2,000 characters with no control character.</p>
Parameter SETTINGTEXT = "ANALYTICS.SETTING.TEXT";

Parameter REASONSETTINGTEXT = "An expression, comment, context or path is at most 2,000 characters with no control character.";

/// <p>400: a run-time variable's expression does not pass the syntax check. The check never runs it.</p>
Parameter VARIABLEEXPRESSION = "ANALYTICS.VARIABLE.EXPRESSION";

Parameter REASONVARIABLEEXPRESSION = "This expression is not valid ObjectScript. It was checked, not run, and nothing was saved.";

/// <p>The consequence codes of a run-time variable that stores an expression, which is code, and of the removal of a run-time variable and of an icon (Story 24.13, Batch 3).</p>
Parameter VARIABLECODE = "ANALYTICS.VARIABLE.CODE";

Parameter REASONVARIABLECODE = "This expression is code. It runs with the rights of whoever opens a dashboard that uses it.";

Parameter VARIABLEREMOVE = "ANALYTICS.VARIABLE.REMOVE";

Parameter REASONVARIABLEREMOVE = "Removing this run-time variable cannot be undone from OcuPilot. A dashboard that uses it then gets an empty value.";

Parameter ICONREMOVE = "ANALYTICS.ICON.REMOVE";

Parameter REASONICONREMOVE = "Removing this icon cannot be undone from OcuPilot.";

/// <p>The consequence code of the folder item delete.</p>
Parameter FOLDERITEMDELETE = "ANALYTICS.FOLDERITEM.DELETE";

/// <p>The consequence codes of the term list delete and the entry remove.</p>
Parameter TERMLISTDELETE = "ANALYTICS.TERMLIST.DELETE";

Parameter TERMLISTREMOVE = "ANALYTICS.TERMLIST.REMOVE";

/// <p>The sentence for <var>pCode</var>, or <code>""</code> for a code this class does not hold.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    If pCode = ..#MDXINPUT Quit ..#REASONMDXINPUT
    If pCode = ..#MDXKIND Quit ..#REASONMDXKIND
    If pCode = ..#MDXAXES Quit ..#REASONMDXAXES
    If pCode = ..#MDXREADONLY Quit ..#REASONMDXREADONLY
    If pCode = ..#MDXBUSY Quit ..#REASONMDXBUSY
    If pCode = ..#MDXFULL Quit ..#REASONMDXFULL
    If pCode = ..#MDXNOTFOUND Quit ..#REASONMDXNOTFOUND
    If pCode = ..#MDXLOST Quit ..#REASONMDXLOST
    If pCode = ..#MDXSQL Quit ..#REASONMDXSQL
    If pCode = ..#CUBEBUSY Quit ..#REASONCUBEBUSY
    If pCode = ..#CUBENODSTIME Quit ..#REASONCUBENODSTIME
    If pCode = ..#CUBENOTBUILT Quit ..#REASONCUBENOTBUILT
    If pCode = ..#CUBEREADONLY Quit ..#REASONCUBEREADONLY
    If pCode = ..#CUBEFAILED Quit ..#REASONCUBEFAILED
    If pCode = ..#TERMLISTTAKEN Quit ..#REASONTERMLISTTAKEN
    If pCode = ..#TERMLISTENTRYTAKEN Quit ..#REASONTERMLISTENTRYTAKEN
    If pCode = ..#TERMLISTABSENT Quit ..#REASONTERMLISTABSENT
    If pCode = ..#TERMLISTNAME Quit ..#REASONTERMLISTNAME
    If pCode = ..#TERMLISTKEY Quit ..#REASONTERMLISTKEY
    If pCode = ..#TERMLISTFIELD Quit ..#REASONTERMLISTFIELD
    If pCode = ..#TERMLISTNOFIELD Quit ..#REASONTERMLISTNOFIELD
    If pCode = ..#TERMLISTFIELDINUSE Quit ..#REASONTERMLISTFIELDINUSE
    If pCode = ..#TERMLISTVALUE Quit ..#REASONTERMLISTVALUE
    If pCode = ..#TERMLISTREADONLY Quit ..#REASONTERMLISTREADONLY
    If pCode = ..#TERMLISTNOTJOURNALED Quit ..#REASONTERMLISTNOTJOURNALED
    If pCode = ..#TERMLISTTOOLARGE Quit ..#REASONTERMLISTTOOLARGE
    If pCode = ..#TERMLISTIMPORTSHAPE Quit ..#REASONTERMLISTIMPORTSHAPE
    If pCode = ..#TERMLISTIMPORTCHANGED Quit ..#REASONTERMLISTIMPORTCHANGED
    If pCode = ..#FOLDERITEMTAKEN Quit ..#REASONFOLDERITEMTAKEN
    If pCode = ..#FOLDERITEMABSENT Quit ..#REASONFOLDERITEMABSENT
    If pCode = ..#PIVOTCUBE Quit ..#REASONPIVOTCUBE
    If pCode = ..#PMMLINPUT Quit ..#REASONPMMLINPUT
    If pCode = ..#PMMLABSENT Quit ..#REASONPMMLABSENT
    If pCode = ..#PMMLQUERYONLY Quit ..#REASONPMMLQUERYONLY
    If pCode = ..#PMMLCUBE Quit ..#REASONPMMLCUBE
    If pCode = ..#PMMLBUSY Quit ..#REASONPMMLBUSY
    If pCode = ..#PMMLFULL Quit ..#REASONPMMLFULL
    If pCode = ..#PMMLNOTFOUND Quit ..#REASONPMMLNOTFOUND
    If pCode = ..#PMMLLOST Quit ..#REASONPMMLLOST
    If pCode = ..#PMMLCLASS Quit ..#REASONPMMLCLASS
    If pCode = ..#PMMLTAKEN Quit ..#REASONPMMLTAKEN
    If pCode = ..#PMMLTEXT Quit ..#REASONPMMLTEXT
    If pCode = ..#PMMLCOMPILE Quit ..#REASONPMMLCOMPILE
    If pCode = ..#PMMLREADONLY Quit ..#REASONPMMLREADONLY
    If pCode = ..#PMMLSAME Quit ..#REASONPMMLSAME
    If pCode = ..#PMMLCUBETAKEN Quit ..#REASONPMMLCUBETAKEN
    If pCode = ..#PMMLCUBENAME Quit ..#REASONPMMLCUBENAME
    If pCode = ..#PMMLSOURCECLASS Quit ..#REASONPMMLSOURCECLASS
    If pCode = ..#PMMLEXPORTRUN Quit ..#REASONPMMLEXPORTRUN
    If pCode = ..#PMMLEXPORTCOMPILE Quit ..#REASONPMMLEXPORTCOMPILE
    If pCode = ..#FOLDERITEMLOCKED Quit ..#REASONFOLDERITEMLOCKED
    If pCode = ..#FOLDERITEMREADONLY Quit ..#REASONFOLDERITEMREADONLY
    If pCode = ..#FOLDERITEMNOTJOURNALED Quit ..#REASONFOLDERITEMNOTJOURNALED
    If pCode = ..#FOLDERITEMTOOLARGE Quit ..#REASONFOLDERITEMTOOLARGE
    If pCode = ..#FOLDERITEMIMPORTSHAPE Quit ..#REASONFOLDERITEMIMPORTSHAPE
    If pCode = ..#FOLDERITEMIMPORTCHANGED Quit ..#REASONFOLDERITEMIMPORTCHANGED
    If pCode = ..#LISTINGGROUPTAKEN Quit ..#REASONLISTINGGROUPTAKEN
    If pCode = ..#LISTINGGROUPCLASS Quit ..#REASONLISTINGGROUPCLASS
    If pCode = ..#LISTINGGROUPCUBE Quit ..#REASONLISTINGGROUPCUBE
    If pCode = ..#LISTINGGROUPLISTINGTAKEN Quit ..#REASONLISTINGGROUPLISTINGTAKEN
    If pCode = ..#LISTINGGROUPAMBIGUOUS Quit ..#REASONLISTINGGROUPAMBIGUOUS
    If pCode = ..#LISTINGGROUPCOMPILE Quit ..#REASONLISTINGGROUPCOMPILE
    If pCode = ..#LISTINGGROUPABSENT Quit ..#REASONLISTINGGROUPABSENT
    If pCode = ..#LISTINGGROUPREADONLY Quit ..#REASONLISTINGGROUPREADONLY
    If pCode = ..#QUALITYMEASURETAKEN Quit ..#REASONQUALITYMEASURETAKEN
    If pCode = ..#QUALITYMEASUREAMBIGUOUS Quit ..#REASONQUALITYMEASUREAMBIGUOUS
    If pCode = ..#QUALITYMEASURECOMPILE Quit ..#REASONQUALITYMEASURECOMPILE
    If pCode = ..#QUALITYMEASUREABSENT Quit ..#REASONQUALITYMEASUREABSENT
    If pCode = ..#QUALITYMEASUREREADONLY Quit ..#REASONQUALITYMEASUREREADONLY
    If pCode = ..#QUALITYMEASUREEXPRESSION Quit ..#REASONQUALITYMEASUREEXPRESSION
    If pCode = ..#QUALITYMEASURELINKED Quit ..#REASONQUALITYMEASURELINKED
    If pCode = ..#QUALITYMEASURECLASS Quit ..#REASONQUALITYMEASURECLASS
    If pCode = ..#QUALITYMEASUREELEMENTTAKEN Quit ..#REASONQUALITYMEASUREELEMENTTAKEN
    If pCode = ..#QUALITYMEASUREMETATAKEN Quit ..#REASONQUALITYMEASUREMETATAKEN
    If pCode = ..#QUALITYMEASUREPARTABSENT Quit ..#REASONQUALITYMEASUREPARTABSENT
    If pCode = ..#QUALITYMEASURELINKEDPARTS Quit ..#REASONQUALITYMEASURELINKEDPARTS
    If pCode = ..#SETTINGREADONLY Quit ..#REASONSETTINGREADONLY
    If pCode = ..#SETTINGSECRET Quit ..#REASONSETTINGSECRET
    If pCode = ..#WORKLISTNOTCUSTOMIZED Quit ..#REASONWORKLISTNOTCUSTOMIZED
    If pCode = ..#WORKLISTABSENT Quit ..#REASONWORKLISTABSENT
    If pCode = ..#VARIABLETAKEN Quit ..#REASONVARIABLETAKEN
    If pCode = ..#ICONTAKEN Quit ..#REASONICONTAKEN
    If pCode = ..#VARIABLEABSENT Quit ..#REASONVARIABLEABSENT
    If pCode = ..#ICONABSENT Quit ..#REASONICONABSENT
    If pCode = ..#SETTINGNAME Quit ..#REASONSETTINGNAME
    If pCode = ..#SETTINGTEXT Quit ..#REASONSETTINGTEXT
    If pCode = ..#VARIABLEEXPRESSION Quit ..#REASONVARIABLEEXPRESSION
    Quit ""
}

/// <p>The analytics settings writes' four refusal codes (Story 24.13), then the seven of the run-time variable and icon writes (Batch 3), as a <class>%List</class>.</p>
ClassMethod SettingCodes() As %List
{
    Quit $ListBuild(..#SETTINGREADONLY, ..#SETTINGSECRET, ..#WORKLISTNOTCUSTOMIZED, ..#WORKLISTABSENT, ..#VARIABLETAKEN, ..#ICONTAKEN, ..#VARIABLEABSENT, ..#ICONABSENT, ..#SETTINGNAME, ..#SETTINGTEXT, ..#VARIABLEEXPRESSION)
}

/// <p>The consequence codes of the analytics settings writes (Story 24.13), as a <class>%List</class>: the General save, and the code a variable's expression is and the two removals (Batch 3).</p>
ClassMethod SettingConsequenceCodes() As %List
{
    Quit $ListBuild(..#SETTINGSAVE, ..#VARIABLECODE, ..#VARIABLEREMOVE, ..#ICONREMOVE)
}

/// <p>The cube manager's codes (Story 20.34), as a <class>%List</class>: the five refusals of a build or synchronize.</p>
ClassMethod CubeCodes() As %List
{
    Quit $ListBuild(..#CUBEBUSY, ..#CUBENODSTIME, ..#CUBENOTBUILT, ..#CUBEREADONLY, ..#CUBEFAILED)
}

/// <p>The refusals the cube manager's fresh read answers when the action does not fit the state, as a <class>%List</class>:
/// those a build and a synchronize are refused with before any vendor call. <parameter>CUBEFAILED</parameter> is the vendor's
/// answer, not a state.</p>
ClassMethod CubePreconditionCodes() As %List
{
    Quit $ListBuild(..#CUBEBUSY, ..#CUBENODSTIME, ..#CUBENOTBUILT, ..#CUBEREADONLY, ..#NAMESPACE)
}

/// <p>The consequence codes of the cube manager's two writes, as a <class>%List</class>.</p>
ClassMethod CubeConsequenceCodes() As %List
{
    Quit $ListBuild(..#CUBEBUILD, ..#CUBESYNCHRONIZE)
}

/// <p>The term list editor's refusal codes (Story 24.2) and its transfers' three (Story 24.10), as a <class>%List</class>.</p>
ClassMethod TermListCodes() As %List
{
    Quit $ListBuild(..#TERMLISTTAKEN, ..#TERMLISTENTRYTAKEN, ..#TERMLISTABSENT, ..#TERMLISTNAME, ..#TERMLISTKEY, ..#TERMLISTFIELD, ..#TERMLISTNOFIELD, ..#TERMLISTFIELDINUSE, ..#TERMLISTVALUE, ..#TERMLISTREADONLY, ..#TERMLISTNOTJOURNALED, ..#TERMLISTTOOLARGE, ..#TERMLISTIMPORTSHAPE, ..#TERMLISTIMPORTCHANGED)
}

/// <p>The folder item transfers' and delete's eight refusal codes (Story 24.10), then the viewer's pivot refusal (Story 24.14), as a <class>%List</class>.</p>
ClassMethod FolderItemCodes() As %List
{
    Quit $ListBuild(..#FOLDERITEMTAKEN, ..#FOLDERITEMABSENT, ..#FOLDERITEMLOCKED, ..#FOLDERITEMREADONLY, ..#FOLDERITEMNOTJOURNALED, ..#FOLDERITEMTOOLARGE, ..#FOLDERITEMIMPORTSHAPE, ..#FOLDERITEMIMPORTCHANGED, ..#PIVOTCUBE)
}

/// <p>The PMML model tester's eight refusal codes (Story 24.14), then the five of the definition create (Batch 3) and the six of the export to a cube (Batch 4), as a <class>%List</class>.</p>
ClassMethod PmmlCodes() As %List
{
    Quit $ListBuild(..#PMMLINPUT, ..#PMMLABSENT, ..#PMMLQUERYONLY, ..#PMMLCUBE, ..#PMMLBUSY, ..#PMMLFULL, ..#PMMLNOTFOUND, ..#PMMLLOST, ..#PMMLCLASS, ..#PMMLTAKEN, ..#PMMLTEXT, ..#PMMLCOMPILE, ..#PMMLREADONLY, ..#PMMLSAME, ..#PMMLCUBETAKEN, ..#PMMLCUBENAME, ..#PMMLSOURCECLASS, ..#PMMLEXPORTRUN, ..#PMMLEXPORTCOMPILE)
}

/// <p>The consequence codes of the PMML definition create (Story 24.14, Batch 3) and of the export to a cube (Batch 4), as a <class>%List</class>.</p>
ClassMethod PmmlConsequenceCodes() As %List
{
    Quit $ListBuild(..#PMMLSAVE, ..#PMMLEXPORT)
}

/// <p>The listing group writes' eight refusal codes (Story 24.11), as a <class>%List</class>.</p>
ClassMethod ListingGroupCodes() As %List
{
    Quit $ListBuild(..#LISTINGGROUPTAKEN, ..#LISTINGGROUPCLASS, ..#LISTINGGROUPCUBE, ..#LISTINGGROUPLISTINGTAKEN, ..#LISTINGGROUPAMBIGUOUS, ..#LISTINGGROUPCOMPILE, ..#LISTINGGROUPABSENT, ..#LISTINGGROUPREADONLY)
}

/// <p>The consequence codes of the listing group writes (Story 24.11), as a <class>%List</class>.</p>
ClassMethod ListingGroupConsequenceCodes() As %List
{
    Quit $ListBuild(..#LISTINGGROUPDELETE, ..#LISTINGGROUPREMOVE, ..#LISTINGGROUPSQL, ..#LISTINGGROUPSAVE)
}

/// <p>The quality measure writes' twelve refusal codes (Story 24.12), as a <class>%List</class>.</p>
ClassMethod QualityMeasureCodes() As %List
{
    Quit $ListBuild(..#QUALITYMEASURETAKEN, ..#QUALITYMEASUREAMBIGUOUS, ..#QUALITYMEASURECOMPILE, ..#QUALITYMEASUREABSENT, ..#QUALITYMEASUREREADONLY, ..#QUALITYMEASUREEXPRESSION, ..#QUALITYMEASURELINKED, ..#QUALITYMEASURECLASS, ..#QUALITYMEASUREELEMENTTAKEN, ..#QUALITYMEASUREMETATAKEN, ..#QUALITYMEASUREPARTABSENT, ..#QUALITYMEASURELINKEDPARTS)
}

/// <p>The consequence codes of the quality measure writes (Story 24.12), as a <class>%List</class>.</p>
ClassMethod QualityMeasureConsequenceCodes() As %List
{
    Quit $ListBuild(..#QUALITYMEASUREDELETE, ..#QUALITYMEASUREREMOVE, ..#QUALITYMEASURESAVE)
}

/// <p>The consequence codes of the term list delete and the entry remove, as a <class>%List</class>.</p>
ClassMethod TermListConsequenceCodes() As %List
{
    Quit $ListBuild(..#TERMLISTDELETE, ..#TERMLISTREMOVE)
}

}
