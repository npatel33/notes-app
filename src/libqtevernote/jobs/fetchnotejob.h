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

#ifndef FETCHNOTEJOB_H
#define FETCHNOTEJOB_H

#include "notesstorejob.h"

class FetchNoteJob : public NotesStoreJob
{
    Q_OBJECT
public:
    enum LoadWhat {
        LoadContent = 0x01,
        LoadResources = 0x02
    };
    Q_DECLARE_FLAGS(LoadWhatFlags, LoadWhat)

    explicit FetchNoteJob(const QString &guid, LoadWhatFlags what, QObject *parent = 0);

    virtual bool operator==(const EvernoteJob *other) const override;
    virtual void attachToDuplicate(const EvernoteJob *other) override;
    virtual QString toString() const override;

signals:
    void resultReady(EvernoteConnection::ErrorCode error, const QString &errorMessage, const evernote::edam::Note &note, LoadWhatFlags what);

protected:
    void startJob();
    void emitJobDone(EvernoteConnection::ErrorCode errorCode, const QString &errorMessage);

private:
    evernote::edam::NoteStoreClient *m_client;
    QString m_token;
    QString m_guid;
    LoadWhatFlags m_what;

    evernote::edam::Note m_result;

};

#endif // FETCHNOTEJOB_H
