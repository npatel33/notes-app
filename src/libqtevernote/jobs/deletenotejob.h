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

#ifndef DELETENOTEJOB_H
#define DELETENOTEJOB_H

#include "notesstorejob.h"

class DeleteNoteJob : public NotesStoreJob
{
    Q_OBJECT
public:
    DeleteNoteJob(const QString &guid, QObject *parent = 0);

    virtual bool operator==(const EvernoteJob *other) const override;
    virtual void attachToDuplicate(const EvernoteJob *other) override;

signals:
    void jobDone(EvernoteConnection::ErrorCode errorCode, const QString &errorMessage, const QString &guid);

protected:
    void startJob();
    void emitJobDone(EvernoteConnection::ErrorCode errorCode, const QString &errorMessage);

private:
    QString m_guid;
};

#endif // DELETENOTEJOB_H
