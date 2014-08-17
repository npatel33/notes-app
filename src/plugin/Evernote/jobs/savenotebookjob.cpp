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
 *
 * Authors: Michael Zanetti <michael.zanetti@canonical.com>
 */

#include "savenotebookjob.h"
#include "notebook.h"

#include <QDebug>

SaveNotebookJob::SaveNotebookJob(Notebook *notebook, QObject *parent) :
    NotesStoreJob(parent)
{
    // Need to clone it. As startJob() will run in another thread we can't access the real note from there.
    m_notebook = notebook->clone();

    // Make sure we delete the clone when done
    m_notebook->setParent(this);
}

void SaveNotebookJob::startJob()
{
    evernote::edam::Notebook notebook;
    notebook.guid = m_notebook->guid().toStdString();
    notebook.__isset.guid = true;
    notebook.name = m_notebook->guid().toStdString();
    notebook.__isset.name = true;

    client()->updateNotebook(token().toStdString(), notebook);
}

void SaveNotebookJob::emitJobDone(EvernoteConnection::ErrorCode errorCode, const QString &errorMessage)
{
    emit jobDone(errorCode, errorMessage);
}
