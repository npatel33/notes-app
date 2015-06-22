﻿/*
 * Copyright: 2013 - 2014 Canonical, Ltd
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

import QtQuick 2.3
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.1
import Ubuntu.Components.Popups 1.0
import Ubuntu.Components.ListItems 1.0
import Ubuntu.Connectivity 1.0
import Evernote 0.1
import Ubuntu.OnlineAccounts 0.1
import Ubuntu.OnlineAccounts.Client 0.1
import Ubuntu.PushNotifications 0.1
import "components"
import "ui"

MainView {
    id: root

    // objectName for functional testing purposes (autopilot-qt5)
    objectName: "mainView"

    // Note! applicationName needs to match the "name" field of the click manifest
    applicationName: "com.ubuntu.reminders"

    useDeprecatedToolbar: false

    /*
     This property enables the application to change orientation
     when the device is rotated. The default is false.
    */
    automaticOrientation: true

    property bool narrowMode: root.width < units.gu(80)
    property var uri: undefined

    onNarrowModeChanged: {
        if (narrowMode) {
            // Clean the toolbar
            notesPage.selectedNote = null;
        }
    }

    Connections {
        target: UriHandler
        onOpened: {
            root.uri = uris[0];
            processUri();
        }
    }

    Connections {
        target: NetworkingStatus
        onStatusChanged: {
            switch (NetworkingStatus.status) {
            case NetworkingStatus.Offline:
                EvernoteConnection.disconnectFromEvernote();
                break;
            case NetworkingStatus.Online:
                // Seems DNS still fails most of the time when we get this signal.
                connectDelayTimer.start();
                break;
            }
        }
    }

    Timer {
        id: connectDelayTimer
        interval: 2000
        onTriggered: EvernoteConnection.connectToEvernote();
    }

    Connections {
        target: EvernoteConnection
        onIsConnectedChanged: {
            if (EvernoteConnection.isConnected && root.uri) {
                processUri();
            }
        }
    }

    backgroundColor: "#dddddd"

    function openAccountPage() {
        var unauthorizedAccounts = allAccounts.count - accounts.count > 0 ? true : false
        var accountPage = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/AccountSelectorPage.qml")), { accounts: accounts, unauthorizedAccounts: unauthorizedAccounts, oaSetup: setup });
        accountPage.accountSelected.connect(function(username, handle) { accountService.startAuthentication(username, handle); pagestack.pop(); root.accountPage = null });
    }

    function displayNote(note, conflictMode) {
        if (conflictMode == undefined) {
            conflictMode = false;
        }

        print("displayNote:", note.guid)
        note.load(true);
        if (root.narrowMode) {
            print("creating noteview");
            if (!conflictMode && note.conflicting) {
                // User wants to open the note even though it is conflicting! Show the Conflict page instead.
                var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NoteConflictPage.qml")), {note: note});
                page.displayNote.connect(function(note) { root.displayNote(note, true); } );
                page.resolveConflict.connect(function(keepLocal) {
                    var confirmation = PopupUtils.open(Qt.resolvedUrl("components/ResolveConflictConfirmationDialog.qml"), page, {keepLocal: keepLocal, remoteDeleted: note.conflictingNote.deleted, localDeleted: note.deleted});
                    confirmation.accepted.connect(function() {
                        NotesStore.resolveConflict(note.guid, keepLocal ? NotesStore.KeepLocal : NotesStore.KeepRemote);
                        pagestack.pop();
                    });
                })
            } else {
                var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NotePage.qml")), {readOnly: conflictMode, note: note })
                page.editNote.connect(function(note) {root.switchToEditMode(note)})
            }
        } else {
            var view;
            if (!conflictMode && note.conflicting) {
                // User wants to open the note even though it is conflicting! Show the Conflict page instead.
                notesPage.conflictMode = true;
                sideViewLoader.clear();
                view = sideViewLoader.embed(Qt.resolvedUrl("ui/NoteConflictView.qml"))
                view.displayNote.connect(function(note) {root.displayNote(note,true)})
                view.resolveConflict.connect(function(keepLocal) {
                    var confirmation = PopupUtils.open(Qt.resolvedUrl("components/ResolveConflictConfirmationDialog.qml"), page, {keepLocal: keepLocal, remoteDeleted: note.conflictingNote.deleted, localDeleted: note.deleted});
                    confirmation.accepted.connect(function() {
                        NotesStore.resolveConflict(note.guid, keepLocal ? NotesStore.KeepLocal : NotesStore.KeepRemote);
                    });
                })
            } else {
                notesPage.conflictMode = conflictMode;
                sideViewLoader.clear();
                view = sideViewLoader.embed(Qt.resolvedUrl("ui/NoteView.qml"))
                view.editNote.connect(function() {root.switchToEditMode(view.note)})
            }
            view.note = note;
        }
    }

    function switchToEditMode(note) {
        note.load(true)
        if (root.narrowMode) {
            if (pagestack.depth > 1) {
                pagestack.pop();
            }
            var page = pagestack.push(Qt.resolvedUrl("ui/EditNotePage.qml"), {note: note});
            page.exitEditMode.connect(function() {Qt.inputMethod.hide(); pagestack.pop()});
        } else {
            sideViewLoader.clear();
            var view = sideViewLoader.embed(Qt.resolvedUrl("ui/EditNoteView.qml"))
            print("--- setting note:", note)
            view.note = note;
            view.exitEditMode.connect(function(note) {root.displayNote(note)});
        }
    }

    function openSearch() {
        var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/SearchNotesPage.qml")))
        page.noteSelected.connect(function(note) {root.displayNote(note)})
        page.editNote.connect(function(note) {root.switchToEditMode(note)})
    }

    function doLogin() {
        var accountName = preferences.accountName;
        if (accountName == "@local") {
            accountService.startAuthentication("@local", null);
            return;
        }

        if (accountName) {
            print("Last used account:", accountName);
            var i;
            for (i = 0; i < accounts.count; i++) {
                if (accounts.get(i, "displayName") == accountName) {
                    print("Account", accountName, "still valid in Online Accounts.");
                    accountService.startAuthentication(accounts.get(i, "displayName"), accounts.get(i, "accountServiceHandle"));
                    return;
                }
            }
        }

        switch (accounts.count) {
        case 0:
            PopupUtils.open(noAccountDialog, root);
            print("No account available! Please setup an account in the system settings");
            break;
        case 1:
            print("Connecting to account", accounts.get(0, "displayName"), "as there is only one account available");
            accountService.startAuthentication(accounts.get(0, "displayName"), accounts.get(0, "accountServiceHandle"));
            break;
        default:
            print("There are multiple accounts. Allowing user to select one.");
            openAccountPage();
        }
    }

    function processUri() {
        var commands = root.uri.split("://")[1].split("/");
        if (EvernoteConnection.isConnected && commands && NotesStore) {
            switch(commands[0].toLowerCase()) {
                case "notes": // evernote://notes
                    rootTabs.selectedTabIndex = 0;
                    break;

                case "note": // evernote://note/<noteguid>
                    if (commands[1]) {
                        var note = NotesStore.note(commands[1])
                        if (note) {
                            displayNote(note);
                        } else {
                            console.warn("No such note:", commands[1])
                        }
                    }
                    break;

                case "newnote": // evernote://newnote  or  evernote://newnote/<notebookguid>
                    if (commands[1]) {
                        if (NotesStore.notebook(commands[1])) {
                            NotesStore.createNote(i18n.tr("Untitled"), commands[1]);
                        } else {
                            console.warn("No such notebook.");
                        }
                    } else {
                        NotesStore.createNote(i18n.tr("Untitled"));
                    }
                    break;

                case "editnote": // evernote://editnote/<noteguid>
                    if (commands[1]) {
                        var note = NotesStore.note(commands[1]);
                        displayNote(note);
                        switchToEditMode(note);
                    }
                    break;

                case "notebooks": // evernote://notebooks
                    rootTabs.selectedTabIndex = 1;
                    break;

                case "notebook": // evernote://notebook/<notebookguid>
                    if (commands[1]) {
                        if (NotesStore.notebook(commands[1])) {
                            notebooksPage.openNotebook(commands[1]);
                        } else {
                            console.warn("No such notebook:", commands[1]);
                        }
                    }
                    break;

                case "reminders": // evernote://reminders
                    rootTabs.selectedTabIndex = 2;
                    break;

                case "tags": // evernote://tags
                    rootTabs.selectedTabIndex = 3;
                    break;

                case "tag": // evernote://tag/<tagguid>
                    if (commands[1]) {
                        tagsPage.openTaggedNotes(commands[1]);
                    }
                    break;

                default: console.warn('WARNING: Unmanaged URI: ' + commands);
            }
            commands = undefined;
        }
    }

    function registerPushClient() {
        console.log("Registering push client");
        var req = new XMLHttpRequest();
        req.open("post", "http://162.213.35.108/register", true);
        req.setRequestHeader("content-type", "application/json");
        req.onreadystatechange = function() {//Call a function when the state changes.
            print("push client register response")
            if(req.readyState == 4) {
                if (req.status == 200) {
                    print("PushClient registered")
                } else {
                    print("Error registering PushClient:", req.status, req.responseText, req.statusText);
                }
            }
        }
        req.send(JSON.stringify({
            "userId" : UserStore.username,
            "appId": root.applicationName + "_reminders",
            "token": pushClient.token
        }))
    }

    function openTaggedNotes(title, tagGuid, narrowMode) {
        print("!!!opening note page for tag", tagGuid)
        var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NotesPage.qml")), {title: title, filterTagGuid: tagGuid, narrowMode: narrowMode});
        page.selectedNoteChanged.connect(function() {
            if (page.selectedNote) {
                root.displayNote(page.selectedNote);
                if (root.narrowMode) {
                    page.selectedNote = null;
                }
            }
        })
        page.editNote.connect(function(note) {
            root.switchToEditMode(note)
        })
    }

    PushClient {
        id: pushClient
        appId: root.applicationName + "_reminders"

        onNotificationsChanged: {
            print("PushClient notification:", notifications)
            var notification = JSON.parse(notifications)["payload"];
            print("user", notification["userId"])
            if (notification["userId"] !== UserStore.username) {
                console.warn("user mismatch:", notification["userId"], "!=", UserStore.username)
                return;
            }

            if (notification["notebookGUID"] !== undefined) {
                NotesStore.refreshNotebooks();
                NotesStore.refreshNotes(notification["notebookGUID"]);
            }
            if (notification["noteGUID"] !== undefined) {
                NotesStore.refreshNoteContent(notification["noteGUID"]);
            }
        }

        onError: {
            console.warn("PushClient Error:", error)
        }
    }

    AccountServiceModel {
        id: accounts
        applicationId: "com.ubuntu.reminders_reminders"
    }

    AccountServiceModel {
        id: allAccounts
        applicationId: "com.ubuntu.reminders_reminders"
        service: useSandbox ? "evernote-sandbox" : "evernote"
        includeDisabled: true
    }

    AccountService {
        id: accountService
        function startAuthentication(username, objectHandle) {
            //Load the cache
            EvernoteConnection.disconnectFromEvernote();
            EvernoteConnection.token = "";
            NotesStore.username = username;
            preferences.accountName = username;
            if (username === "@local" && !preferences.haveLocalUser) {
                NotesStore.createNotebook(i18n.tr("Default notebook"));
                preferences.haveLocalUser = true;
            }

            if (objectHandle === null) {
                return;
            }

            accountService.objectHandle = objectHandle;
            // FIXME: workaround for lp:1351041. We'd normally set the hostname
            // under onAuthenticated, but it seems that now returns empty parameters
            EvernoteConnection.hostname = accountService.authData.parameters["HostName"];
            authenticate(null);
        }

        onAuthenticated: {
            EvernoteConnection.token = reply.AccessToken;
            print("token is:", EvernoteConnection.token)
            print("NetworkingStatus.online:", NetworkingStatus.Online)
            if (NetworkingStatus.Online) {
                EvernoteConnection.connectToEvernote();
            }
        }
        onAuthenticationError: {
            console.log("Authentication failed, code " + error.code)
        }
    }

    Component.onCompleted: {
        if (tablet) {
            width = units.gu(100);
            height = units.gu(75);
        } else if (phone) {
            width = units.gu(40);
            height = units.gu(75);
        }

        pagestack.push(rootTabs);
        doLogin();

        if (uriArgs) {
            root.uri = uriArgs[0];
        }
    }

    Connections {
        target: UserStore
        onUsernameChanged: {
            print("Logged in as user:", UserStore.username);
            // Disabling push notifications as we haven't had a chance to properly test that yet
            //registerPushClient();
        }
    }

    Connections {
        target: NotesStore
        onNoteCreated: {
            var note = NotesStore.note(guid);
            print("note created:", note.guid);
            if (root.narrowMode) {
                var page = pagestack.push(Qt.resolvedUrl("ui/EditNotePage.qml"), {note: note});
                page.exitEditMode.connect(function() {Qt.inputMethod.hide(); pagestack.pop();});
            } else {
                notesPage.selectedNote = note;
                var view = sideViewLoader.embed(Qt.resolvedUrl("ui/EditNoteView.qml"));
                view.note = note;
                view.exitEditMode.connect(function(note) {root.displayNote(note)});
            }
        }
    }

    StatusBar {
        id: statusBar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: units.gu(9) }
        color: root.backgroundColor
        shown: text
        text: EvernoteConnection.error || NotesStore.error
        iconName: "sync-error"

        Timer {
            interval: 5000
            repeat: true
            running: NotesStore.error
            onTriggered: NotesStore.clearError();
        }

        MouseArea {
            anchors.fill: parent
            onClicked: NotesStore.clearError();
        }

    }

    PageStack {
        id: pagestack
        anchors.rightMargin: root.narrowMode ? 0 : root.width - units.gu(40)
        anchors.topMargin: statusBar.height


        Tabs {
            id: rootTabs

            anchors.fill: parent

            Tab {
                title: i18n.tr("Notes")
                objectName: "NotesTab"
                page: NotesPage {
                    id: notesPage
                    readOnly: conflictMode
                    property bool conflictMode: false

                    narrowMode: root.narrowMode

                    onEditNote: {
                        root.switchToEditMode(note)
                    }

                    onSelectedNoteChanged: {
                        if (selectedNote !== null) {
                            root.displayNote(selectedNote);
                            if (root.narrowMode) {
                                selectedNote = null;
                            }
                        } else {
                            sideViewLoader.clear();
                        }
                    }
                    onOpenSearch: root.openSearch();
                }
            }

            Tab {
                title: i18n.tr("Notebooks")
                objectName: "NotebookTab"
                page: NotebooksPage {
                    id: notebooksPage

                    narrowMode: root.narrowMode

                    onOpenNotebook: {
                        var notebook = NotesStore.notebook(notebookGuid)
                        print("have notebook:", notebook, notebook.name)
                        print("opening note page for notebook", notebookGuid)
                        var page = pagestack.push(Qt.createComponent(Qt.resolvedUrl("ui/NotesPage.qml")), {title: notebook.name, filterNotebookGuid: notebookGuid, narrowMode: root.narrowMode});
                        page.selectedNoteChanged.connect(function() {
                            if (page.selectedNote) {
                                root.displayNote(page.selectedNote);
                                if (root.narrowMode) {
                                    page.selectedNote = null;
                                }
                            }
                        })
                        page.editNote.connect(function(note) {
                            root.switchToEditMode(note)
                        })
                        page.openSearch.connect(function() {
                            root.openSearch();
                        })
                        NotesStore.refreshNotes();
                    }

                    onOpenSearch: root.openSearch();
                }
            }

            Tab {
                title: i18n.tr("Reminders")
                page: RemindersPage {
                    id: remindersPage

                    onSelectedNoteChanged: {
                        if (selectedNote !== null) {
                            root.displayNote(selectedNote);
                        } else {
                            sideViewLoader.clear();
                        }
                    }

                    onOpenSearch: root.openSearch();
                }
            }

            Tab {
                title: i18n.tr("Tags")
                page: TagsPage {
                    id: tagsPage

                    onOpenTaggedNotes: {
                        var tag = NotesStore.tag(tagGuid);
                        root.openTaggedNotes(tag.name, tag.guid, root.narrowMode)
                    }

                    onOpenSearch: root.openSearch();
                }
            }
            Tab {
                title: i18n.tr("Accounts")

                page: AccountSelectorPage {
                    accounts: accounts
                    unauthorizedAccounts: true
                    oaSetup: setup
                    onAccountSelected: {
                        accountService.startAuthentication(username, handle)
                        rootTabs.selectedTabIndex = 0;
                    }
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: pagestack.width / 2
        visible: !root.narrowMode
        text: i18n.tr("No note selected.\nSelect a note to see it in detail.")
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        fontSize: "large"
        width: parent.width - pagestack.width
    }

    Loader {
        id: sideViewLoader
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom; topMargin: units.gu(10) }
        width: root.width - pagestack.width

        ThinDivider {
            width: sideViewLoader.height
            anchors { right: null; left: parent.left; }
            z: 5

            transform: Rotation {
                angle: 90
            }
        }

        function embed(view, args) {
            source = view;
            return item;
        }

        function clear() {
            source = "";
        }
    }

    Setup {
        id: setup
        applicationId: "com.ubuntu.reminders_reminders"
        providerId: useSandbox ? "com.ubuntu.reminders_evernote-account-plugin-sandbox" : "com.ubuntu.reminders_evernote-account-plugin"
    }

    Component {
        id: noAccountDialog
        Dialog {
            id: noAccount
            objectName: "noAccountDialog"
            title: i18n.tr("Setup Evernote connection?")
            text: i18n.tr("Notes can be stored on this device, or optionally synced with Evernote.") + " "
                          + i18n.tr("In order to synchronize notes with Evernote, an account at Evernote is required.") + " "
                          + i18n.tr("Do you want to setup an account now?")

            Connections {
                target: accounts
                onCountChanged: {
                    if (accounts.count == 1) {
                        PopupUtils.close(noAccount)
                        doLogin();
                    }
                }
            }

            RowLayout {
                Button {
                    objectName: "openAccountButton"
                    text: i18n.tr("No")
                    color: UbuntuColors.red
                    onClicked: {
                        PopupUtils.close(noAccount)
                        accountService.startAuthentication("@local", null);
                    }
                    Layout.fillWidth: true
                }
                Button {
                    objectName: "openAccountButton"
                    text: i18n.tr("Yes")
                    color: UbuntuColors.green
                    onClicked: setup.exec()
                    Layout.fillWidth: true
                }
            }
        }
    }
}
