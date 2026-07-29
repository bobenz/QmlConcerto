import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Concerto 1.0

ApplicationWindow {
    id: window
    width: 980
    height: 680
    visible: true
    title: "Concerto Demo — arbitrary melody + report catcher"

    // A custom error registered at runtime through RegRep's ConstantRegistry,
    // exposed here under Concerto's backward-compatible "ErrorRegistry"/"Errors" names.
    Component.onCompleted: {
        ErrorRegistry.declare({
            name: "demo_injected_fault", source: "Demo", code: -9101,
            description: "Injected fault (demo)"
        })
    }

    // ── The "arbitrary melody" ────────────────────────────────────────────
    // A Sequence (serial) with a nested Chord (parallel) in the middle —
    // demonstrates composition, not just a flat list of steps.
    Sequence {
        id: melody
        title: "Deploy Pipeline"

        Pause { id: step1; title: "Warm up";  timeout: 700 }

        Chord {
            id: parallelStage
            title: "Parallel Checks"
            Pause { id: step2a; title: "Left channel";  timeout: 1000 }
            Pause { id: step2b; title: "Right channel"; timeout: 1500 }
        }

        Pause { id: step3; title: "Cool down"; timeout: 600 }
    }

    // ── Report catchers ────────────────────────────────────────────────────
    // Every report goes to the global ReportRouter regardless of which
    // Phrase emitted it; ReportsReceiver subscribes with regex filters.

    // Live-filterable receiver driving the log view below.
    ReportsReceiver {
        id: liveFilter
        sourceFilter: sourceFilterField.text
        categoryFilter: categoryFilterField.text
        messageFilter: messageFilterField.text
        onReportReceived: function(r) {
            reportModel.insert(0, {
                time: Qt.formatTime(r.timestamp, "hh:mm:ss.zzz"),
                source: r.source,
                category: r.category,
                message: r.message
            })
            if (reportModel.count > 300)
                reportModel.remove(300, reportModel.count - 300)
        }
    }

    // Background counters — unaffected by the live filter above.
    ReportsReceiver {
        id: allCatcher
        onReportReceived: totalReports++
    }
    ReportsReceiver {
        id: errorCatcher
        categoryFilter: "Error|Critical"
        onReportReceived: errorReports++
    }

    property int totalReports: 0
    property int errorReports: 0

    ListModel { id: reportModel }

    function stateText(p) {
        if (!p) return "—"
        switch (p.state) {
        case Phrase.Silent:       return "Silent"
        case Phrase.Playing:      return "Playing"
        case Phrase.Accompanying: return "Accompanying"
        case Phrase.Resolved:
            switch (p.finalized) {
            case Phrase.Consonant: return "Resolved · Consonant"
            case Phrase.Dissonant: return "Resolved · Dissonant"
            case Phrase.Aborted:   return "Resolved · Aborted"
            default:                return "Resolved"
            }
        default: return "—"
        }
    }

    function stateColor(p) {
        if (!p) return "#888888"
        switch (p.state) {
        case Phrase.Playing:
        case Phrase.Accompanying: return "#e0a800"
        case Phrase.Resolved:
            if (p.finalized === Phrase.Consonant) return "#28a745"
            if (p.finalized === Phrase.Aborted)   return "#fd7e14"
            return "#dc3545"
        default: return "#888888"
        }
    }

    component StepRow: RowLayout {
        property var phrase
        spacing: 8
        Rectangle {
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            radius: 7
            color: window.stateColor(phrase)
            border.color: "#333"
        }
        Label {
            Layout.preferredWidth: 150
            text: phrase ? phrase.title : ""
        }
        Label {
            Layout.fillWidth: true
            text: window.stateText(phrase)
            color: "#555"
        }
        Button {
            text: "Fail"
            visible: phrase && (phrase.state === Phrase.Playing || phrase.state === Phrase.Accompanying)
            onClicked: phrase.finish(Errors.demo_injected_fault)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── Toolbar ──────────────────────────────────────────────────────
        RowLayout {
            spacing: 8
            Button {
                text: "Play"
                enabled: melody.state === Phrase.Silent
                onClicked: melody.play()
            }
            Button {
                text: "Abort"
                enabled: melody.playing
                onClicked: melody.abort()
            }
            Button {
                text: "Reset"
                enabled: melody.state !== Phrase.Silent
                onClicked: melody.reset()
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "Melody: " + window.stateText(melody)
                font.bold: true
                color: window.stateColor(melody)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // ── Left: melody visualization ─────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                spacing: 10

                Label { text: "Melody — " + melody.title; font.bold: true }

                StepRow { phrase: step1 }

                Frame {
                    Layout.fillWidth: true
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6
                        Label { text: parallelStage.title + " (parallel)"; font.italic: true; color: "#555" }
                        StepRow { phrase: step2a }
                        StepRow { phrase: step2b }
                    }
                }

                StepRow { phrase: step3 }

                Item { Layout.fillHeight: true }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    visible: melody.finalized === Phrase.Dissonant
                    color: "#dc3545"
                    text: "Last error: " + melody.lastError.text
                }
            }

            // ── Right: report catcher panel ────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Label { text: "Report catcher (ReportsReceiver)"; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label { text: "source:" }
                    TextField {
                        id: sourceFilterField
                        Layout.preferredWidth: 130
                        placeholderText: "regex, e.g. Cool"
                    }
                    Label { text: "category:" }
                    TextField {
                        id: categoryFilterField
                        Layout.preferredWidth: 130
                        placeholderText: "e.g. Error|Warning"
                    }
                    Label { text: "message:" }
                    TextField {
                        id: messageFilterField
                        Layout.fillWidth: true
                        placeholderText: "regex"
                    }
                    Button {
                        text: "Clear log"
                        onClicked: reportModel.clear()
                    }
                }

                RowLayout {
                    spacing: 20
                    Label { text: "Total reports: " + window.totalReports }
                    Label {
                        text: "Errors/Critical: " + window.errorReports
                        color: window.errorReports > 0 ? "#dc3545" : "#555"
                        font.bold: window.errorReports > 0
                    }
                    Label {
                        text: "Shown: " + reportModel.count
                        color: "#555"
                    }
                }

                Frame {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: logView
                        anchors.fill: parent
                        clip: true
                        model: reportModel
                        spacing: 2
                        ScrollBar.vertical: ScrollBar {}

                        delegate: RowLayout {
                            width: logView.width
                            spacing: 8
                            Label {
                                Layout.preferredWidth: 90
                                text: model.time
                                font.family: "monospace"
                                color: "#888"
                            }
                            Label {
                                Layout.preferredWidth: 150
                                text: model.source
                                elide: Text.ElideLeft
                            }
                            Label {
                                Layout.preferredWidth: 70
                                text: model.category
                                color: model.category === "Error" || model.category === "Critical" ? "#dc3545"
                                     : model.category === "Warning"                                 ? "#e0a800"
                                     : "#555"
                                font.bold: model.category === "Error" || model.category === "Critical"
                            }
                            Label {
                                Layout.fillWidth: true
                                text: model.message
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
