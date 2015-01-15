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

#include "evernotejob.h"
#include "evernoteconnection.h"

// Thrift
#include <arpa/inet.h> // seems thrift forgot this one
#include <protocol/TBinaryProtocol.h>
#include <transport/THttpClient.h>
#include <transport/TSSLSocket.h>
#include <Thrift.h>

// Evernote SDK
#include <Errors_types.h>

#include <libintl.h>

#include <QDebug>

using namespace apache::thrift;
using namespace apache::thrift::protocol;
using namespace apache::thrift::transport;

EvernoteJob::EvernoteJob(QObject *parent) :
    QThread(parent),
    m_token(EvernoteConnection::instance()->token())
{
}

EvernoteJob::~EvernoteJob()
{
}

void EvernoteJob::run()
{
    if (!EvernoteConnection::instance()->isConnected()) {
        qWarning() << "EvernoteConnection is not connected. (" << this->metaObject()->className() << ")";
        emitJobDone(EvernoteConnection::ErrorCodeUserException, QStringLiteral("Not connected."));
        return;
    }

    bool retry = false;
    int tryCount = 0;
    do {
        retry = false;
        try {
            startJob();
            emitJobDone(EvernoteConnection::ErrorCodeNoError, QString());
        } catch (const TTransportException & e) {
            qWarning() << "TTransportException in" << metaObject()->className() << e.what();
            if (tryCount < 2) {
                qWarning() << "Resetting connection...";
                try {
                    resetConnection();
                } catch(...) {}
                retry = true;
            } else {
                emitJobDone(EvernoteConnection::ErrorCodeConnectionLost, e.what());
            }
        } catch (const TApplicationException &e) {
            qWarning() << "TApplicationException in " << metaObject()->className() << e.what();
            if (tryCount < 2) {
                qWarning() << "Resetting connection...";
                try {
                    resetConnection();
                } catch(...) {}
                retry = true;
            } else {
                emitJobDone(EvernoteConnection::ErrorCodeConnectionLost, e.what());
            }
        } catch (const evernote::edam::EDAMUserException &e) {
            QString message;
            switch (e.errorCode) {
            case evernote::edam::EDAMErrorCode::UNKNOWN:
                message = "Unknown Error: %1";
                break;
            case evernote::edam::EDAMErrorCode::BAD_DATA_FORMAT:
                message = "Bad data format: %1";
                break;
            case evernote::edam::EDAMErrorCode::PERMISSION_DENIED:
                message = "Permission denied: %1";
                break;
            case evernote::edam::EDAMErrorCode::INTERNAL_ERROR:
                message = "Internal Error: %1";
                break;
            case evernote::edam::EDAMErrorCode::DATA_REQUIRED:
                message = "Data required: %1";
                break;
            case evernote::edam::EDAMErrorCode::LIMIT_REACHED:
                message = "Limit reached: %1";
                break;
            case evernote::edam::EDAMErrorCode::QUOTA_REACHED:
                message = "Quota reached: %1";
                break;
            case evernote::edam::EDAMErrorCode::INVALID_AUTH:
                message = "Invalid auth: %1";
                break;
            case evernote::edam::EDAMErrorCode::AUTH_EXPIRED:
                message = "Auth expired: %1";
                break;
            case evernote::edam::EDAMErrorCode::DATA_CONFLICT:
                message = "Data conflict: %1";
                break;
            case evernote::edam::EDAMErrorCode::ENML_VALIDATION:
                message = "ENML validation: %1";
                break;
            case evernote::edam::EDAMErrorCode::SHARD_UNAVAILABLE:
                message = "Shard unavailable: %1";
                break;
            case evernote::edam::EDAMErrorCode::LEN_TOO_SHORT:
                message = "Length too short: %1";
                break;
            case evernote::edam::EDAMErrorCode::LEN_TOO_LONG:
                message = "Length too long: %1";
                break;
            case evernote::edam::EDAMErrorCode::TOO_FEW:
                message = "Too few: %1";
                break;
            case evernote::edam::EDAMErrorCode::TOO_MANY:
                message = "Too many: %1";
                break;
            case evernote::edam::EDAMErrorCode::UNSUPPORTED_OPERATION:
                message = "Unsupported operation: %1";
                break;
            case evernote::edam::EDAMErrorCode::TAKEN_DOWN:
                message = "Taken down: %1";
                break;
            case evernote::edam::EDAMErrorCode::RATE_LIMIT_REACHED:
                message = "Rate limit reached: %1";
                break;
            }
            message = message.arg(QString::fromStdString(e.parameter));
            qWarning() << metaObject()->className() << "EDAMUserException:" << message;
            emitJobDone(EvernoteConnection::ErrorCodeUserException, message);
        } catch (const evernote::edam::EDAMSystemException &e) {
            qWarning() << "EDAMSystemException in" << metaObject()->className() << e.what() << e.errorCode << QString::fromStdString(e.message);
            QString message;
            EvernoteConnection::ErrorCode errorCode;
            switch (e.errorCode) {
            case evernote::edam::EDAMErrorCode::AUTH_EXPIRED:
                message = gettext("Authentication expired.");
                errorCode = EvernoteConnection::ErrorCodeAuthExpired;
                break;
            case evernote::edam::EDAMErrorCode::LIMIT_REACHED:
                message = gettext("Limit exceeded.");
                errorCode = EvernoteConnection::ErrorCodeLimitExceeded;
                break;
            case evernote::edam::EDAMErrorCode::RATE_LIMIT_REACHED:
                message = gettext("Rate limit exceeded.");
                errorCode = EvernoteConnection::ErrorCodeRateLimitExceeded;
                break;
            case evernote::edam::EDAMErrorCode::QUOTA_REACHED:
                message = gettext("Quota exceeded.");
                errorCode = EvernoteConnection::ErrorCodeQutaExceeded;
                break;
            default:
                message = e.what();
                errorCode = EvernoteConnection::ErrorCodeSystemException;
            }
            emitJobDone(errorCode, message);
        } catch (const evernote::edam::EDAMNotFoundException &e) {
            emitJobDone(EvernoteConnection::ErrorCodeNotFoundExcpetion, QString::fromStdString(e.identifier));
        }
        tryCount++;
    } while (retry);
}

QString EvernoteJob::token()
{
    return m_token;
}
