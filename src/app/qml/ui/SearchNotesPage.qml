/*
 * Copyright: 2013 Canonical, Ltd
 *
 * This file is part of reminders
 *
 * reminders is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * reminders is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3
import Ubuntu.Components.Popups 1.3
import Evernote 0.1
import "../components"

Page {
    id: root

    signal noteSelected(var note)
    signal editNote(var note)

    title: i18n.tr("Search notes")

    onActiveChanged: {
        searchField.forceActiveFocus();
    }

    Column {
        anchors { fill: parent; topMargin: units.gu(2); bottomMargin: units.gu(2) }
        spacing: units.gu(2)

        Row {
            anchors { left: parent.left; right: parent.right; margins: units.gu(2) }
            spacing: units.gu(1)

            TextField {
                id: searchField
                width: parent.width - searchButton.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                focus: true

                primaryItem: Icon {
                    height: searchField.height - units.gu(1)
                    width: height
                    name: "search"
                }

                onAccepted: {
                    NotesStore.findNotes(searchField.text)
                }
            }
            Button {
                id: searchButton
                height: searchField.height
                text: i18n.tr("Search")
                onClicked: {
                    NotesStore.findNotes(searchField.text)
                }
            }
        }

        ListView {
            anchors { left: parent.left; right: parent.right }
            height: parent.height - y
            clip: true

            model: Notes {
                onlySearchResults: true

                Component.onCompleted: {
                    if (count > 0) {
                        NotesStore.clearSearchResults();
                    }
                }
            }

            delegate: NotesDelegate {
                title: model.title
                date: model.created
                content: model.tagline
                resource: model.resourceUrls.length > 0 ? model.resourceUrls[0] : ""
                notebookColor: preferences.colorForNotebook(model.notebookGuid)
                reminder: model.reminder
                synced: model.synced
                loading: model.loading
                syncError: model.syncError
                conflicting: model.conflicting
                deleted: model.deleted

                tags: {
                    var tags = new Array();
                    for (var i = 0; i < model.tagGuids.length; i++) {
                        tags.push(NotesStore.tag(model.tagGuids[i]).name)
                    }
                    return tags.join(" ");
                }

                onItemClicked: {
                    root.noteSelected(NotesStore.note(guid))
                }
                onDeleteNote: {
                    NotesStore.deleteNote(model.guid)
                }
                onEditNote: {
                    root.editNote(NotesStore.note(model.guid));
                }
                onEditReminder: {
                    pageStack.push(Qt.resolvedUrl("SetReminderPage.qml"), { note: NotesStore.note(model.guid) });
                }
                onEditTags: {
                    var popup = PopupUtils.open(Qt.resolvedUrl("../components/EditTagsDialog.qml"), root,
                                    { note: NotesStore.note(model.guid) });
                    popup.done.connect(function() { NotesStore.saveNote(popup.note.guid)})
                }
            }
        }
    }
}
