import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Notes.js" as Notes

Panel {
  id: root
  moduleName: "yubinex.omarchy-news"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property string filter: "All"
  property string selectedTag: ""
  readonly property var feed: hostWidget ? hostWidget.feed : ({releases: []})
  readonly property color fg: Commons.Color.foreground
  readonly property color muted: Qt.alpha(fg, 0.58)
  readonly property color line: Qt.alpha(fg, 0.09)
  readonly property string error: (hostWidget ? hostWidget.processError : "") || feed.error || ""
  readonly property var releases: (feed.releases || []).filter(function(r) {
    if (search.text && (r.title + " " + r.body).toLowerCase().indexOf(search.text.toLowerCase()) < 0) return false
    return filter === "All" || (filter === "Available" && r.status === "available")
      || (filter === "Installed" && (r.status === "installed" || r.justInstalled))
      || (filter === "History" && r.status === "history") || (filter === "Previews" && r.status === "preview")
  })
  readonly property var selected: {
    for (var i = 0; i < releases.length; i++) if (releases[i].tag === selectedTag) return releases[i]
    return null
  }
  function chooseDefault() {
    if (selected || !releases.length) return
    var preferred = releases.filter(function(r) { return r.status === "available" || r.status === "installed" })
    selectedTag = (preferred.length ? preferred[0] : releases[0]).tag
  }
  onReleasesChanged: Qt.callLater(chooseDefault)
  onOpenedChanged: if (opened) chooseDefault()
  onSelectedTagChanged: detailScroll.contentY = 0
  function label(release) {
    if (release.justInstalled) return "Just installed"
    return {installed: "Installed", available: "Available", history: "Earlier release", preview: "Preview"}[release.status] || release.status
  }
  function dateLabel(value) {
    var date = new Date(value)
    return isNaN(date.getTime()) ? "" : Qt.formatDate(date, "d MMM yyyy")
  }
  function openSource() {
    if (selected && /^https:\/\/github\.com\/omacom\/omarchy\/releases\/tag\/[^\s]+$/.test(selected.url)) Qt.openUrlExternally(selected.url)
  }

  KeyboardPanel {
    id: popup
    owner: root
    anchorItem: root.anchorItem
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: popup.fittedContentWidth(Style.space(900))
    contentHeight: popup.fittedContentHeight(Style.space(660))
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
      spacing: Style.space(18)
      Row {
        width: parent.width
        spacing: Style.space(12)
        Column {
          width: parent.width - refreshButton.width - parent.spacing
          spacing: Style.space(5)
          Text {
            text: "Omarchy News"
            color: root.fg
            font { family: "sans-serif"; pixelSize: Style.space(22); weight: Font.DemiBold }
          }
          Text {
            text: (root.feed.installedVersion || "Unknown version") + "  /  " + (root.feed.channel || "unknown")
            color: root.muted
            font { family: "sans-serif"; pixelSize: Style.font.bodySmall }
          }
        }
        NewsButton {
          id: refreshButton
          text: root.hostWidget && root.hostWidget.busy ? "Refreshing…" : "↻  Refresh"
          enabled: root.hostWidget && !root.hostWidget.busy
          onClicked: root.hostWidget.refresh(true)
        }
      }
      Rectangle { width: parent.width; height: 1; color: root.line }
      Row {
        width: parent.width
        spacing: Style.space(4)
        Repeater {
          model: ["All", "Available", "Installed", "History", "Previews"]
          delegate: NewsButton {
            required property string modelData
            text: modelData
            quiet: true
            selected: root.filter === modelData
            onClicked: root.filter = modelData
          }
        }
        Item { width: Math.max(0, parent.width - x - markAllButton.width - parent.spacing); height: 1 }
        NewsButton {
          id: markAllButton
          text: "Mark all as read"
          quiet: true
          enabled: root.hostWidget && !root.hostWidget.busy
            && (root.feed.releases || []).some(function(r) { return r.unread })
          onClicked: root.hostWidget.markAllRead()
        }
      }
      Text {
        width: parent.width
        visible: root.error !== ""
        text: root.error
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.muted
        font { family: "sans-serif"; pixelSize: Style.font.bodySmall }
      }
      Row {
        width: parent.width
        height: Math.max(Style.space(100), content.height - y - footer.height - content.spacing)
        spacing: Style.space(22)
        Column {
          id: sidebar
          width: parent.width * 0.27
          height: parent.height
          spacing: Style.space(12)
          Controls.TextField {
            id: search
            width: parent.width
            height: Style.space(34)
            placeholderText: "Search changes…"
            placeholderTextColor: root.muted
            color: root.fg
            selectByMouse: true
            leftPadding: Style.space(12)
            font { family: "sans-serif"; pixelSize: Style.font.body }
            background: Rectangle {
              radius: Style.space(7)
              color: Qt.alpha(root.fg, 0.035)
              border { width: 1; color: search.activeFocus ? Qt.alpha(root.fg, 0.3) : root.line }
            }
          }
          ListView {
            id: releaseList
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: Style.space(4)
            model: root.releases
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
            delegate: Rectangle {
              id: releaseCard
              required property var modelData
              readonly property bool current: root.selectedTag === modelData.tag
              width: releaseList.width
              height: Style.space(76)
              radius: Style.space(8)
              color: Qt.alpha(root.fg, current ? 0.095 : cardMouse.containsMouse ? 0.045 : 0)
              Rectangle {
                visible: releaseCard.current
                x: 0; y: Style.space(17)
                width: Style.space(3); height: parent.height - y * 2
                radius: width / 2
                color: Commons.Color.accent
              }
              Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Style.space(14); rightMargin: Style.space(12) }
                spacing: Style.space(7)
                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text {
                    width: parent.width - Style.space(14)
                    text: releaseCard.modelData.tag
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.fg
                    font { family: "sans-serif"; pixelSize: Style.font.body; weight: releaseCard.current ? Font.DemiBold : Font.Medium }
                  }
                  Rectangle {
                    visible: releaseCard.modelData.unread
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(5); height: width; radius: width / 2
                    color: Qt.alpha(root.fg, 0.55)
                  }
                }
                Text {
                  width: parent.width
                  text: root.label(releaseCard.modelData) + " · " + root.dateLabel(releaseCard.modelData.date)
                  elide: Text.ElideRight
                  color: root.muted
                  font { family: "sans-serif"; pixelSize: Style.font.bodySmall }
                }
              }
              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedTag = releaseCard.modelData.tag
              }
            }
            Text {
              anchors { top: parent.top; topMargin: Style.space(20); horizontalCenter: parent.horizontalCenter }
              width: parent.width - Style.space(20)
              visible: releaseList.count === 0
              text: root.hostWidget && root.hostWidget.busy ? "Loading notes…" : "No matching releases"
              color: root.muted
              wrapMode: Text.Wrap
              font { family: "sans-serif"; pixelSize: Style.font.body }
            }
          }
        }
        Rectangle { width: 1; height: parent.height; color: root.line }
        Column {
          width: parent.width - sidebar.width - parent.spacing * 2 - 1
          height: parent.height
          spacing: Style.space(12)
          Text {
            width: parent.width
            text: root.selected ? root.selected.title : "You're all caught up"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.fg
            font { family: "sans-serif"; pixelSize: Style.space(23); weight: Font.DemiBold }
          }
          Row {
            width: parent.width
            visible: root.selected !== null
            spacing: Style.space(8)
            Text {
              width: Math.max(0, parent.width - sourceButton.width - readButton.width - parent.spacing * 2)
              anchors.verticalCenter: parent.verticalCenter
              text: root.selected ? root.dateLabel(root.selected.date) : ""
              color: root.muted
              elide: Text.ElideRight
              font { family: "sans-serif"; pixelSize: Style.font.bodySmall }
            }
            NewsButton { id: sourceButton; text: "Source ↗"; quiet: true; onClicked: root.openSource() }
            NewsButton {
              id: readButton
              text: root.selected && root.selected.unread ? "Mark read" : "✓ Read"
              enabled: root.selected && root.selected.unread && root.hostWidget && !root.hostWidget.busy
              onClicked: root.hostWidget.markRead(root.selected.tag)
            }
          }
          Rectangle {
            id: notesFrame
            width: parent.width
            height: Math.max(0, parent.height - y)
            radius: Style.space(8)
            color: Qt.alpha(root.fg, 0.025)
            border { width: 1; color: Qt.alpha(root.fg, 0.18) }

            Flickable {
              id: detailScroll
              anchors { fill: parent; margins: Style.space(14) }
              contentWidth: width
              contentHeight: notes.implicitHeight + Style.space(8)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: size < 1 ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                minimumSize: 0.06
                implicitWidth: Style.space(5)
                background: Rectangle {
                  radius: width / 2
                  color: Qt.alpha(root.fg, 0.05)
                }
                contentItem: Rectangle {
                  implicitWidth: Style.space(5)
                  radius: width / 2
                  color: Qt.alpha(root.fg, parent.pressed ? 0.65 : 0.32)
                }
              }
              TextEdit {
                id: notes
                width: parent.width - Style.space(18)
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.RichText
                wrapMode: TextEdit.Wrap
                color: Qt.alpha(root.fg, 0.88)
                selectionColor: Qt.alpha(root.fg, 0.25)
                font { family: "sans-serif"; pixelSize: Style.space(14) }
                text: root.selected ? Notes.render(root.selected.body) : "<p>Try another filter or search to explore the release notes.</p>"
              }
            }
          }
        }
      }
      Text {
        id: footer
        width: parent.width
        text: "Official release notes · " + (root.feed.fetchedAt ? "Updated " + Qt.formatDateTime(new Date(root.feed.fetchedAt), "HH:mm") : "Not yet synced")
        color: root.muted
        font { family: "sans-serif"; pixelSize: Style.font.bodySmall }
        Controls.ToolTip.visible: footerMouse.containsMouse
        Controls.ToolTip.text: root.feed.statusNote || "Notes describe upstream releases, not every local change."
        MouseArea { id: footerMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
      }
    }
  }
}
