import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../config"
import "../../components"

ColumnLayout {
    id:root
    property bool detailed:false
    readonly property var player:Mpris.players.values.find(player=>player.isPlaying) || Mpris.players.values[0] || null
    spacing:QuickControlStyle.gap
    Timer {
        interval:1000;repeat:true
        running:root.visible && root.detailed && root.player && root.player.isPlaying && root.player.positionSupported && root.player.canSeek && root.player.lengthSupported
        onTriggered:root.player.positionChanged()
    }
    QuickControlSection {title:"Now playing"}
    RowLayout {
        Layout.fillWidth:true;spacing:QuickControlStyle.gap
        Image {visible:root.player && source.toString().length>0;source:root.player ? root.player.trackArtUrl : "";Layout.preferredWidth:44;Layout.preferredHeight:44;fillMode:Image.PreserveAspectCrop;asynchronous:true}
        ColumnLayout {Layout.fillWidth:true;spacing:3
            QuickControlLabel {Layout.fillWidth:true;text:root.player ? root.player.trackTitle || root.player.identity : "No media player";elide:Text.ElideRight;font.family:Fonts.poppinsSB.name}
            QuickControlLabel {Layout.fillWidth:true;text:root.player ? root.player.trackArtist || root.player.identity : "Open a player to use media controls";elide:Text.ElideRight;color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
        }
        QuickControlIconButton {visible:root.detailed;symbol:"\ue045";label:"Previous track";enabled:root.player && root.player.canGoPrevious;onClicked:root.player.previous()}
        QuickControlIconButton {symbol:root.player && root.player.isPlaying ? "\ue034" : "\ue037";label:"Play or pause";enabled:root.player && root.player.canTogglePlaying;onClicked:root.player.togglePlaying()}
        QuickControlIconButton {visible:root.detailed;symbol:"\ue044";label:"Next track";enabled:root.player && root.player.canGoNext;onClicked:root.player.next()}
    }
    Loader {
        Layout.fillWidth:true
        active:root.detailed && root.player && root.player.canSeek && root.player.positionSupported && root.player.lengthSupported && root.player.length>0
        visible:active
        sourceComponent:QuickControlSlider {objectName:"quickMediaSeek";iconInteractive:false;label:"Position";symbol:"\ue01b";value:root.player.position/root.player.length;valueText:Math.floor(root.player.position/60)+":"+String(Math.floor(root.player.position%60)).padStart(2,"0");onUserChanged:next=>root.player.position=next*root.player.length}
    }
}
