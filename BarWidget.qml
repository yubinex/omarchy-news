import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "yubinex.omarchy-news"
  property var feed: ({releases: [], installedVersion: "", channel: "", error: ""})
  property string processError: ""
  readonly property bool busy: fetcher.running
  readonly property int unreadCount: (feed.releases || []).filter(function(r) {
    return r.unread && (r.status === "available" || r.status === "installed" || r.justInstalled)
  }).length
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function run(args) {
    if (fetcher.running) return
    fetcher.command = ["python3", Qt.resolvedUrl("news.py").toString().replace(/^file:\/\//, "")].concat(args)
    processError = ""
    fetcher.running = true
  }
  function refresh(force) { run(force ? ["feed", "--refresh"] : ["feed"]) }
  function markRead(tag) { run(["read", tag]) }
  function markAllRead() { run(["read-all"]) }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  Loader {
    id: panelLoader
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      item.hostWidget = root
      item.anchorItem = button
      item.bar = Qt.binding(function() { return root.bar })
    }
  }
  Timer {
    interval: 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh(false)
  }
  Process {
    id: fetcher
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var value = JSON.parse(text)
          if (!Array.isArray(value.releases)) throw new Error("Invalid feed response")
          root.feed = value
        } catch (e) { root.processError = "Could not read the news feed: " + e.message }
      }
    }
    onExited: function(code, status) {
      if (code !== 0) root.processError = "News helper failed (exit " + code + "). Cached notes remain visible."
    }
  }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf1ea"
    slotSize: Style.bar.statusSlot
    active: root.opened
    useActiveColor: false
    tooltipText: "Omarchy News\n" + root.feed.installedVersion + " · " + root.feed.channel + "\n" + root.unreadCount + " unread releases"
    Rectangle {
      visible: root.unreadCount > 0
      width: Style.space(4)
      height: width
      radius: width / 2
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: Style.bar.iconCanvas / 2 + Style.space(1)
      anchors.verticalCenterOffset: -Style.bar.iconCanvas / 2
      color: button.foreground
    }
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.refresh(true)
      else root.toggle()
    }
  }
}
