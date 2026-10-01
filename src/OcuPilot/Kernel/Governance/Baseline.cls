/// <p>The governance baseline (AD-22): every write key this instance's tools registered when the
/// policy shipped, with the value it takes when neither a stored setting nor a preset decides it.</p>
/// <p><b>Grown by addition, never regenerated.</b> A story that ships a new write tool adds its line
/// here in the same change, <code>true</code> unless that story's criteria say disabled;
/// <class>OcuPilot.Test.GovernanceBaseline</class> fails, naming the key, while a registered write
/// key has no line. A write key with no line reads <code>false</code>
/// (<method>Seed</method>), so a tool that slipped past that test is disabled rather than enabled.</p>
/// <p>One line per key, <code>"&lt;key&gt;": true|false</code>, in name order. A key is the tool's
/// canonical name, or <code>tool:action</code> for a tool declaring
/// <parameter>OcuPilot.Screen.Tool.Base.GOVERNANCEACTION</parameter>.</p>
Class OcuPilot.Kernel.Governance.Baseline Extends %RegisteredObject
{

/// <p>The name of the XData block the keys are declared in.</p>
Parameter KEYSXDATA = "Keys";

XData Keys [ MimeType = application/json ]
{
{
  "logs.applicationerrors.delete": true,
  "osmgmt.databasedetails.compact": false,
  "osmgmt.databasedetails.defragment": false,
  "osmgmt.databasedetails.dismount": false,
  "osmgmt.databasedetails.mount": false,
  "osmgmt.databasedetails.truncate": false,
  "osmgmt.databases.integrity": false,
  "osmgmt.devices.create": true,
  "osmgmt.devices.delete": true,
  "osmgmt.devices.update": true,
  "osmgmt.globalmappings.create": true,
  "osmgmt.globalmappings.delete": true,
  "osmgmt.globalmappings.update": true,
  "osmgmt.localdatabases.create": true,
  "osmgmt.localdatabases.delete": false,
  "osmgmt.localdatabases.expand": false,
  "osmgmt.localdatabases.grow": false,
  "osmgmt.localdatabases.update": true,
  "osmgmt.localdatabases.updatemount": true,
  "osmgmt.namespaces.copymappings": true,
  "osmgmt.namespaces.create": true,
  "osmgmt.namespaces.delete": false,
  "osmgmt.namespaces.update": true,
  "osmgmt.packagemappings.create": true,
  "osmgmt.packagemappings.delete": true,
  "osmgmt.packagemappings.update": true,
  "osmgmt.processes.resume": true,
  "osmgmt.processes.suspend": true,
  "osmgmt.processes.terminate": true,
  "osmgmt.processes.terminatewitherror": true,
  "osmgmt.routinemappings.create": true,
  "osmgmt.routinemappings.delete": true,
  "osmgmt.routinemappings.update": true,
  "permissions.resources.create": true,
  "permissions.resources.delete": true,
  "permissions.resources.update": true,
  "permissions.roles.create": true,
  "permissions.roles.delete": true,
  "permissions.roles.update": true,
  "permissions.services.update": true,
  "permissions.users.create": true,
  "permissions.users.delete": true,
  "permissions.users.password": true,
  "permissions.users.revoketokens": true,
  "permissions.users.update": true,
  "security.auditing.copy": true,
  "security.auditing.purge": false,
  "security.auditing.update": true,
  "security.auditsystemevents.reset": true,
  "security.auditsystemevents.update": true,
  "security.audituserevents.create": true,
  "security.audituserevents.delete": true,
  "security.audituserevents.reset": true,
  "security.audituserevents.update": true,
  "security.ldap.create": true,
  "security.ldap.delete": true,
  "security.ldap.password": true,
  "security.ldap.update": true,
  "security.oauthclients.create": true,
  "security.oauthclients.delete": true,
  "security.oauthclients.register": true,
  "security.oauthclients.rotatekeys": true,
  "security.oauthclients.setsecrets": true,
  "security.oauthclients.update": true,
  "security.oauthresourceservers.addmapping": true,
  "security.oauthresourceservers.create": true,
  "security.oauthresourceservers.delete": true,
  "security.oauthresourceservers.removemapping": true,
  "security.oauthresourceservers.setsecret": true,
  "security.oauthresourceservers.update": true,
  "security.oauthserver.create": true,
  "security.oauthserver.delete": true,
  "security.oauthserver.rotatekeys": true,
  "security.oauthserver.setpassword": true,
  "security.oauthserver.update": true,
  "security.oauthserverclients.create": true,
  "security.oauthserverclients.delete": true,
  "security.oauthserverclients.setsecret": true,
  "security.oauthserverclients.update": true,
  "security.oauthserverclients.updatejwks": true,
  "security.oauthserverdescriptions.create": true,
  "security.oauthserverdescriptions.delete": true,
  "security.oauthserverdescriptions.settoken": true,
  "security.oauthserverdescriptions.update": true,
  "security.oauthserverdescriptions.updatejwks": true,
  "security.secrets.create": true,
  "security.secrets.delete": true,
  "security.secrets.update": true,
  "security.ssl.create": true,
  "security.ssl.delete": true,
  "security.ssl.update": true,
  "security.x509.delete": true,
  "security.x509.import": true,
  "security.x509.update": true,
  "tasks.ondemand.run": true,
  "tasks.schedule.create": true,
  "tasks.schedule.delete": true,
  "tasks.schedule.resume": true,
  "tasks.schedule.run": true,
  "tasks.schedule.suspend": true,
  "tasks.schedule.update": true,
  "webapp.list.create": true,
  "webapp.list.delete": true,
  "webapp.list.update": true,
  "webapp.sessions.end": true,
  "tasks.background.cancel": true,
  "tasks.background.pause": true,
  "tasks.background.resume": true,
  "osmgmt.processes.broadcast": true,
  "tasks.schedule.export": true,
  "tasks.schedule.import": false,
  "osmgmt.languageservers.start": true,
  "osmgmt.languageservers.stop": true,
  "osmgmt.languageservers.create": true,
  "osmgmt.languageservers.update": true,
  "osmgmt.languageservers.delete": true,
  "tasks.schedule.suspendmanager": true,
  "tasks.schedule.resumemanager": true,
  "tasks.schedule.startmanager": true,
  "osmgmt.locks.remove": true,
  "osmgmt.locks.removeprocess": true,
  "osmgmt.locks.removeclient": true
}
}

/// <p>The value <var>pKey</var> takes from the baseline: its listed value, with <var>pListed</var>
/// 1, or <code>0</code> with <var>pListed</var> 0 for a key the baseline does not list. A baseline
/// that cannot be read lists nothing, so every write key reads disabled.</p>
ClassMethod Seed(pKey As %String, Output pListed As %Boolean) As %Boolean
{
    Set pListed = 0
    Set tSC = ..Keys(.tKeys)
    If $$$ISERR(tSC) || '$IsObject(tKeys) Quit 0
    If tKeys.%GetTypeOf(pKey) '= "boolean" Quit 0
    Set pListed = 1
    Quit ''tKeys.%Get(pKey)
}

/// <p>Every listed key and its value, as the <class>%DynamicObject</class> the XData block
/// declares, in <var>pList</var>. An unreadable block, or one that is not a JSON object, is an
/// error with <var>pList</var> <code>""</code>.</p>
ClassMethod Keys(Output pList As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pList = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), ..#KEYSXDATA, , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the governance baseline carries no " _ ..#KEYSXDATA _ " XData block")
            Quit
        }
        Do tXData.Data.Rewind()
        Set pList = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        If '$IsObject(pList) || 'pList.%IsA("%Library.DynamicObject") {
            Set pList = ""
            Set tSC = $$$ERROR($$$GeneralError, "the governance baseline is not a JSON object")
        }
    } Catch ex {
        Set pList = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
