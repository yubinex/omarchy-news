import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "yubinex.omarchy-news"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property string filter: "All"
  property string selectedTag: ""
  readonly property var feed: hostWidget ? hostWidget.feed : ({releases: []})
  readonly property var releases: (feed.releases || []).filter(function(r) {
    if (search.text && (r.title + " " + r.body).toLowerCase().indexOf(search.text.toLowerCase()) < 0) return false
    return filter === "All" || (filter === "Available" && r.status === "available")
      || (filter === "Installed" && (r.status === "installed" || r.justInstalled))
      || (filter === "History" && r.status === "history") || (filter === "Previews" && r.status === "preview")
  })
  readonly property var selected: {
    var all = feed.releases || []
    for (var i = 0; i < all.length; i++) if (all[i].tag === selectedTag) return all[i]
    return null
  }
  readonly property color fg: Commons.Color.foreground
  readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.65)
  readonly property color tint: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

  function readable(body) {
    // Plain text deliberately: no remote images, HTML, or executable instructions.
    return (body || "No official release notes available.")
      .replace(/!\[[^\]]*\]\([^\n]*\)/g, "")
      .replace(/<img[^>]*>/g, "")
      .replace(/^#{1,6}\s+/gm, "")
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, "$1 ($2)")
      .replace(/\r/g, "").replace(/\n{3,}/g, "\n\n").trim()
  }
  function label(release) {
    return (release.justInstalled ? "Just installed · " : "")
      + ({installed: "Installed", available: "Newer release", history: "History", preview: "Preview"}[release.status] || release.status)
  }
  function openSource() {
    if (selected && /^https:\/\/github\.com\/omacom\/omarchy\/releases\/tag\/[^\s]+$/.test(selected.url))
      Qt.openUrlExternally(selected.url)
  }

  KeyboardPanel {
    id: popup
    owner: root
    anchorItem: root.anchorItem
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: popup.fittedContentWidth(Style.space(880))
    contentHeight: popup.fittedContentHeight(Style.space(680))
    focusTarget: keyCatcher

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      z: -1
      onCloseRequested: root.close()
    }
    Column {
      id: content
      anchors.fill: parent
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(12)
        Text {
          width: parent.width - refreshButton.width - parent.spacing
          text: "OMARCHY NEWS"
          color: root.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }
        Controls.Button {
          id: refreshButton
          text: root.hostWidget && root.hostWidget.busy ? "Refreshing…" : "Refresh"
          enabled: root.hostWidget && !root.hostWidget.busy
          onClicked: root.hostWidget.refresh(true)
        }
      }
      Text {
        width: parent.width
        text: "Installed " + (root.feed.installedVersion || "unknown") + "  ·  " + (root.feed.channel || "unknown") + " channel"
          + (root.feed.fetchedAt ? "  ·  Checked " + root.feed.fetchedAt.replace("T", " ").slice(0, 16) + " UTC" : "")
        color: root.muted
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
      Text {
        width: parent.width
        visible: text !== ""
        text: (root.hostWidget ? root.hostWidget.processError : "") || root.feed.error || root.feed.statusNote || ""
        color: root.muted
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }
      Row {
        spacing: Style.space(6)
        Repeater {
          model: ["All", "Available", "Installed", "History", "Previews"]
          delegate: Controls.Button {
            required property string modelData
            text: modelData
            highlighted: root.filter === modelData
            onClicked: root.filter = modelData
          }
        }
      }
      Controls.TextField {
        id: search
        width: parent.width
        placeholderText: "Search release notes — shortcuts, apps, fixes…"
        selectByMouse: true
      }
      Row {
        width: parent.width
        height: Math.max(Style.space(100), content.height - y)
        spacing: Style.space(16)
        ListView {
          id: releaseList
          width: parent.width * 0.31
          height: parent.height
          clip: true
          spacing: Style.space(8)
          model: root.releases
          Controls.ScrollBar.vertical: Controls.ScrollBar {}
          delegate: Rectangle {
            required property var modelData
            width: releaseList.width
            height: card.implicitHeight + Style.space(24)
            radius: Style.space(8)
            color: root.selectedTag === modelData.tag ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.17) : root.tint
            Column {
              id: card
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(12) }
              spacing: Style.space(7)
              Text {
                width: parent.width
                text: (modelData.unread ? "●  " : "") + modelData.title
                textFormat: Text.PlainText
                color: root.fg
                font.pixelSize: Style.font.body
                font.bold: true
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                text: root.label(modelData) + "\n" + (modelData.date || "").slice(0, 10)
                color: root.muted
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedTag = modelData.tag; detailScroll.contentY = 0 } }
          }
          Text {
            anchors.centerIn: parent
            width: parent.width - Style.space(20)
            visible: releaseList.count === 0
            text: root.hostWidget && root.hostWidget.busy ? "Loading official notes…" : "No releases in this view."
            color: root.muted
            wrapMode: Text.Wrap
          }
        }
        Rectangle { width: 1; height: parent.height; color: root.tint }
        Column {
          width: parent.width - releaseList.width - parent.spacing * 2 - 1
          height: parent.height
          spacing: Style.space(10)
          Text {
            width: parent.width
            text: root.selected ? root.selected.title : "What changed?"
            textFormat: Text.PlainText
            color: root.fg
            font.pixelSize: Style.font.heading
            font.bold: true
            wrapMode: Text.Wrap
          }
          Row {
            visible: root.selected !== null
            spacing: Style.space(8)
            Controls.Button { text: "Official notes ↗"; onClicked: root.openSource() }
            Controls.Button {
              text: root.selected && root.selected.unread ? "Mark as read" : "Read ✓"
              enabled: root.selected && root.selected.unread && root.hostWidget && !root.hostWidget.busy
              onClicked: root.hostWidget.markRead(root.selected.tag)
            }
          }
          Flickable {
            id: detailScroll
            width: parent.width
            height: Math.max(0, parent.height - y)
            contentWidth: width
            contentHeight: notes.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            TextEdit {
              id: notes
              width: parent.width - Style.space(16)
              readOnly: true
              selectByMouse: true
              textFormat: TextEdit.PlainText
              wrapMode: TextEdit.Wrap
              color: root.fg
              selectionColor: root.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              text: root.selected ? root.readable(root.selected.body)
                : "Select a release to read its official changes.\n\nNewer releases are shown before updating. Installed and historical notes remain available afterward.\n\nPreviews are separate from stable updates. ‘Removed from new installs’ does not mean an app was removed from your machine.\n\nThis first version shows upstream release notes, not a per-file audit of your computer. It never installs updates."
            }
          }
        }
      }
    }
  }
}
