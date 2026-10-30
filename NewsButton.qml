import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

Controls.AbstractButton {
  id: root
  property bool selected: false
  property bool quiet: false
  implicitWidth: label.implicitWidth + Style.space(24)
  implicitHeight: Style.space(32)
  hoverEnabled: true
  opacity: enabled ? 1 : 0.45
  background: Rectangle {
    radius: Style.space(7)
    color: Qt.alpha(Commons.Color.foreground, root.down ? 0.18 : root.selected ? 0.13 : root.hovered ? 0.09 : root.quiet ? 0 : 0.045)
    border.width: root.activeFocus ? 1 : 0
    border.color: Commons.Color.accent
  }
  contentItem: Text {
    id: label
    text: root.text
    textFormat: Text.PlainText
    color: root.selected ? Commons.Color.foreground : Qt.alpha(Commons.Color.foreground, 0.75)
    font.family: "sans-serif"
    font.pixelSize: Style.font.body
    font.weight: root.selected ? Font.DemiBold : Font.Normal
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
