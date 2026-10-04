import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    // ---- Easy-to-edit settings ----
    property int animDuration: 280    // ms for a gentler scroll animation
    // Preserve the original near/far carousel depth while widening each
    // panel enough to make the added side slots fill more of the screen.
    property real zoomScale: 0.92     // scale of the tile at screen center (peak)
    property real edgeScale: 0.68     // scale of tiles at the screen edges (trough)
    property real panelWidthFactor: 1.5
    property real skewFactor: 0       // italic-style shear on tiles
    property int baseSpacing: 24      // fixed gap between carousel slots
    // --------------------------------

    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"

    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])
    }

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
        }
    }

    FolderListModel {
        id: folderModel
        // JsonAdapter loads asynchronously.  Do not let an empty path resolve
        // to the process working directory while it is still loading.
        folder: configs.wallpaper_path ? "file://" + configs.wallpaper_path : "file:///nonexistent"
        showDirs: false
        nameFilters: ["*.png", "*.jpg"]
        sortField: FolderListModel.Name
    }

    ListView {
        id: list
        anchors.fill: parent
        focus: true

        orientation: ListView.Horizontal
        spacing: main.baseSpacing
        clip: true
        cacheBuffer: width * 2

        // A repeated model makes the selector feel endless.  We recenter the
        // current item before either physical end becomes visible, so the user
        // can keep scrolling in either direction without hitting an edge.
        property int wallpaperCount: folderModel.count
        property int repeatCount: 5
        property int selectedIndex: -1
        property int middleBlock: Math.floor(repeatCount / 2)
        property bool recentering: false
        // This is the actual number of visible panels.  Eleven shows two more
        // panels on each side than the previous seven-panel layout.
        property int visiblePanelCount: Math.max(4, configs.number_of_pictures)
        property real tileWidth: Math.max(120, (width - main.baseSpacing * (visiblePanelCount - 1)) / visiblePanelCount)
        property real viewportCenterX: width / 2

        model: wallpaperCount > 0 ? wallpaperCount * repeatCount : 0
        currentIndex: selectedIndex
        preferredHighlightBegin: (width - tileWidth) / 2
        preferredHighlightEnd: (width + tileWidth) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange

        function wallpaperIndex(index) {
            return ((index % wallpaperCount) + wallpaperCount) % wallpaperCount
        }

        function centerOnCurrent(animate) {
            if (selectedIndex < 0)
                return

            recentering = !animate
            positionViewAtIndex(selectedIndex, ListView.Center)
            recentering = false
        }

        function activateCurrent() {
            if (wallpaperCount === 0 || selectedIndex < 0)
                return

            const path = folderModel.get(wallpaperIndex(selectedIndex), "filePath")
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path])
            Qt.quit()
        }

        function normalizePosition() {
            if (wallpaperCount === 0 || selectedIndex < wallpaperCount || selectedIndex >= wallpaperCount * (repeatCount - 1))
                return

            selectedIndex = middleBlock * wallpaperCount + wallpaperIndex(selectedIndex)
            centerOnCurrent(false)
        }

        function moveSelection(delta) {
            if (wallpaperCount === 0)
                return

            selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + delta))
            // Let the movement animate first; the recenter is invisible because
            // every repeated block contains the same ordered wallpapers.
            Qt.callLater(normalizePosition)
        }

        Behavior on contentX {
            enabled: !list.recentering
            NumberAnimation {
                duration: main.animDuration
                easing.type: Easing.InOutCubic
            }
        }

        onWallpaperCountChanged: {
            if (wallpaperCount > 0) {
                selectedIndex = middleBlock * wallpaperCount
                Qt.callLater(function() { centerOnCurrent(false) })
            }
        }

        delegate: Item {
            id: delegateItem
            height: 500
            z: Math.round(scaleFactor * 100)
            property bool active: index === list.selectedIndex
            property int sourceIndex: list.wallpaperIndex(index)

            // Slots stay a fixed width.  Only their contents scale, avoiding the
            // shifting content width and jitter caused by resizing ListView items
            // while ListView is trying to scroll them.
            readonly property real baseWidth: list.tileWidth

            // --- Dock-style magnification: scale depends on on-screen position ---
            // contentX animates smoothly, so this recomputes once per frame without
            // competing animations on the tile itself.
            property real scaleFactor: {
                const centerX = x - list.contentX + baseWidth / 2
                const frac = Math.min(1, Math.abs(centerX - list.viewportCenterX) / list.viewportCenterX)
                const t = 1 - frac * frac * (3 - 2 * frac) // smoothstep falloff
                return main.edgeScale + (main.zoomScale - main.edgeScale) * t
            }

            width: baseWidth

            Item {
                id: content
                anchors.centerIn: parent
                width: parent.width * delegateItem.scaleFactor * main.panelWidthFactor
                // Height scale uses the same factor but caps at 1.0 - the row is already
                // full window height, so growing past that would just get clipped.
                height: delegateItem.height * Math.min(0.92, delegateItem.scaleFactor)

                Text {
                    id: alt
                    text: ""
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    transform: Shear { xFactor: main.skewFactor }
                }

                Image {
                    id: img
                    anchors.fill: parent
                    opacity: 0.8
                    fillMode: Image.PreserveAspectCrop

                    asynchronous: true
                    cache: false
                    smooth: true

                    source: "file://" + configs.cache_path + folderModel.get(delegateItem.sourceIndex, "fileName")

                    // Decode once at the largest size this image will ever be shown at
                    // (the active/zoomed size), rather than tracking the animating
                    // width/height - that would re-decode on every animation frame
                    // and cause a visible blink.
                    sourceSize.width: delegateItem.baseWidth * main.zoomScale * main.panelWidthFactor
                    sourceSize.height: delegateItem.height

                    transform: Shear { xFactor: main.skewFactor }

                    Timer {
                        id: retryTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            const s = img.source
                            img.source = ""
                            img.source = s
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            alt.text = "Caching"
                            retryTimer.start()
                        }
                    }
                }

                Rectangle {
                    id: border
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"

                    border.width: 2
                    border.color: configs.border_color

                    transform: Shear { xFactor: main.skewFactor }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    list.selectedIndex = index
                    list.activateCurrent()
                }

                onWheel: function(wheel) {
                    const amount = wheel.angleDelta.y || wheel.pixelDelta.y
                    if (amount !== 0)
                        list.moveSelection(amount < 0 ? 1 : -1)
                    wheel.accepted = true
                }
            }
        }

        Keys.onPressed: function(event) {
            const big = configs.number_of_pictures

            switch (event.key) {
            case Qt.Key_J:
            case Qt.Key_Right:
                moveSelection(1)
                break
            case Qt.Key_K:
            case Qt.Key_Left:
                moveSelection(-1)
                break
            case Qt.Key_D:
                moveSelection(big)
                break
            case Qt.Key_U:
                moveSelection(-big)
                break
            case Qt.Key_Space:
            case Qt.Key_Return:
                activateCurrent()
                break
            case Qt.Key_Escape:
                Qt.quit()
                break
            default:
                return
            }

            event.accepted = true
        }
    }
}
