import QtQuick

// Place behind a transient panel. Empty space inside its bounds stays inside,
// including during scale/slide animations; child controls retain normal input.
MouseArea {
    id: root
    property Item surface: null
    signal outsideClicked()
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: mouse => {
        if (!surface) return;
        const point = surface.mapFromItem(root, mouse.x, mouse.y);
        if (point.x < 0 || point.y < 0 || point.x >= surface.width || point.y >= surface.height)
            root.outsideClicked();
    }
}
