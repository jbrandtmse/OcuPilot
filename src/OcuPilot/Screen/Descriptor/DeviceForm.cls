/// <p>The device editor: one device, created or edited here, rendered by the <code>form-page</code>
/// archetype (AD-5). Its Save and the agent's confirmed <code>osmgmt.devices.create</code> and
/// <code>osmgmt.devices.update</code> are two callers of one tool each (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.DeviceList</class>'s Create and from a
/// row's name cell, at that list's own route with <code>/edit</code> appended, with the device's name
/// as its one id segment when it edits.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read
/// answers the device it edits, and the list is where the declared read lives.</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Manage:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- so a caller who can read the devices can open the form (AD-8).
/// Saving needs one pair more, the device tools' own <code>%DB_IRISSYS:WRITE</code>:
/// <code>Config.Devices</code> saves a device into the system database, and a principal without the
/// write is refused there (AD-29, <class>OcuPilot.Test.DeviceWire</class>).
/// <class>OcuPilot.Area.OsMgmt.DeviceSave</class> asks it before anything is sent.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.Config.Device</code></b> (AD-44), whose nine
/// fields it carries in the same order. It declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.DeviceForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/devices/edit",
  "area": "os-management",
  "labelKey": "deviceFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "device",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.Config.Device",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.deviceform"
}
}

}
