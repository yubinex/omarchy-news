import QtQuick
import Quickshell
import "./Plugin" as News

ShellRoot {
  QtObject {
    id: host
    property bool busy: false
    property string processError: ""
    property var feed: ({
      installedVersion: "4.0.6-1", channel: "stable", error: "", fetchedAt: "2026-10-30T12:00:00Z",
      releases: [
        {tag: "v4.0.7", title: "Omarchy 4.0.7", date: "2026-10-30", body: "## Added\n\n- Sample feature\n\n## Removed\n\n- Removed from new installs only.", status: "available", unread: true, justInstalled: false, url: "https://github.com/omacom/omarchy/releases/tag/v4.0.7"},
        {tag: "v4.0.6", title: "Omarchy 4.0.6", date: "2026-10-19", body: "## Fixes\n\n- Sample fix", status: "installed", unread: false, justInstalled: false, url: "https://github.com/omacom/omarchy/releases/tag/v4.0.6"}
      ]
    })
    function refresh(force) {}
    function markRead(tag) {}
    function markAllRead() {}
  }
  News.Panel { id: panel; hostWidget: host }
  Timer {
    interval: 200
    running: true
    onTriggered: {
      if (!panel.selected || panel.selected.tag !== "v4.0.7") throw new Error("Default release selection failed")
      panel.selectedTag = "v4.0.7"
      panel.open()
      if (panel.releases.length !== 2 || panel.selected.tag !== "v4.0.7") throw new Error("Feed binding failed")
      panel.filter = "Installed"
      if (panel.releases.length !== 1) throw new Error("Installed filter failed")
      panel.filter = "All"
    }
  }
  Timer {
    interval: 1000
    running: true
    onTriggered: { panel.close(); console.log("NEWS_SMOKE_OK"); Qt.quit() }
  }
}
