#
# Copyright (c) 2008--2016 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.
#
# entry points for the rhnSQL module
#

import sys

from uyuni.common.usix import raise_with_tb
from spacewalk.common.rhnLog import log_debug
from spacewalk.common.rhnConfig import CFG, initCFG
from spacewalk.common.rhnException import rhnException
from spacewalk.common.rhnTB import add_to_seclist

# SQL objects
from . import sql_table
from . import sql_row
from . import sql_sequence
from . import dbi
from . import sql_types
types = sql_types

from .const import POSTGRESQL, SUPPORTED_BACKENDS

# expose exceptions
from .sql_base import SQLError, SQLSchemaError, SQLConnectError, \
    SQLStatementPrepareError, Statement, ModifiedRowError

# ths module works with a private global __DB object that is
# instantiated by the initDB call. This object/instance should NEVER,
# EVER be exposed to the calling applications.


def __init__DB(backend, host, port, username, password, database, sslmode, sslrootcert):
    """
    Establish and check the connection so we can wrap it and handle
    exceptions.
    """
    # __DB global object created here and pushed into the global namespace.
    global __DB
    try:
        my_db = __DB
    except NameError:  # __DB has not been set up
        db_class = dbi.get_database_class(backend=backend)
        __DB = db_class(host, port, username, password, database, sslmode, sslrootcert)
        __DB.connect()
        return
    else:
        del my_db

    if __DB.is_connected_to(backend, host, port, username, password,
                            database, sslmode, sslrootcert):
        __DB.check_connection()
        return

    __DB.commit()
    __DB.close()
    # now we have to get a different connection
    __DB = dbi.get_database_class(backend=backend)(
        host, port, username, password, database, sslmode, sslrootcert)
    __DB.connect()
    return 0


def initDB(backend=None, host=None, port=None, username=None,
           password=None, database=None, sslmode=None, sslrootcert=None, reportdb=False):
    """
    Initialize the database.

    Either we get backend and all parameter which means the caller
    knows what they are doing, or we populate everything from the
    config files.
    """

    if backend is None:
        if CFG is None or not CFG.is_initialized():
            initCFG('server')

        if reportdb:
            backend = CFG.REPORT_DB_BACKEND
            host = CFG.REPORT_DB_HOST
            port = CFG.REPORT_DB_PORT
            database = CFG.REPORT_DB_NAME
            username = CFG.REPORT_DB_USER
            password = CFG.REPORT_DB_PASSWORD
            if CFG.REPORT_DB_SSL_ENABLED:
                sslmode = 'verify-full'
                sslrootcert = CFG.REPORT_DB_SSLROOTCERT
            else:
                sslmode = None
                sslrootcert = None
        else:
            backend = CFG.DB_BACKEND
            host = CFG.DB_HOST
            port = CFG.DB_PORT
            database = CFG.DB_NAME
            username = CFG.DB_USER
            password = CFG.DB_PASSWORD
            if CFG.DB_SSL_ENABLED:
                sslmode = 'verify-full'
                sslrootcert = CFG.DB_SSLROOTCERT
            else:
                sslmode = None
                sslrootcert = None

    if backend not in SUPPORTED_BACKENDS:
        raise rhnException("Unsupported database backend", backend)

    if port:
        port = int(port)

    # Hide the password
    add_to_seclist(password)
    try:
        __init__DB(backend, host, port, username, password, database, sslmode, sslrootcert)
#    except (rhnException, SQLError):
#        raise  # pass on, we know those ones
#    except (KeyboardInterrupt, SystemExit):
#        raise
    except SQLConnectError:
        e = sys.exc_info()[1]
        try:
            closeDB()
        except NameError:
            pass
        raise_with_tb(e, sys.exc_info()[2])
    except:
        raise
        #e_type, e_value = sys.exc_info()[:2]
        # raise rhnException("Could not initialize Oracle database connection",
        #                   str(e_type), str(e_value))
    return 0

# close the database


def closeDB(committing=True, closing=True):
    global __DB
    try:
        my_db = __DB
    except NameError:
        return
    else:
        del my_db
    if committing:
        __DB.commit()
    if closing:
        __DB.close()
    del __DB
    return


# common function for testing the connection state (ie, __DB defined
def __test_DB():
    global __DB
    try:
        return __DB
    except NameError:
        raise_with_tb(SystemError("Not connected to any database!"), sys.exc_info()[2])

# wrapper for a Procedure callable class


def Procedure(name):
    db = __test_DB()
    return db.procedure(name)


# wrapper for a Procedure callable class
def Function(name, ret_type):
    db = __test_DB()
    return db.function(name, ret_type)


# Wrapper for the Sequence class
def Sequence(seq):
    db = __test_DB()
    return sql_sequence.Sequence(db, seq)


# Wrapper for the Row class
def Row(table, hash_name, hash_value=None):
    db = __test_DB()
    return sql_row.Row(db, table, hash_name, hash_value)


# Wrapper for the Table class
def Table(table, hash_name, local_cache=0):
    db = __test_DB()
    return sql_table.Table(db, table, hash_name, local_cache)


###########################
# Functions points of entry
###########################


def cursor():
    db = __test_DB()
    return db.cursor()


def prepare(sql, blob_map=None):
    db = __test_DB()
    if isinstance(sql, Statement):
        sql = sql.statement
    return db.prepare(sql, blob_map=blob_map)


def execute(sql, *args, **kwargs):
    db = __test_DB()
    return db.execute(sql, *args, **kwargs)


def fetchall_dict(sql, *args, **kwargs):
    h = prepare(sql)
    h.execute(sql, *args, **kwargs)
    return h.fetchall_dict()


def fetchone_dict(sql, *args, **kwargs):
    h = prepare(sql)
    h.execute(sql, *args, **kwargs)
    return h.fetchone_dict()


def commit():
    db = __test_DB()
    return db.commit()


def rollback(name=None):
    db = __test_DB()
    return db.rollback(name)


def transaction(name):
    db = __test_DB()
    return db.transaction(name)


def TimestampFromTicks(*args, **kwargs):
    db = __test_DB()
    return db.TimestampFromTicks(*args, **kwargs)


def DateFromTicks(*args, **kwargs):
    db = __test_DB()
    return db.DateFromTicks(*args, **kwargs)


def Date(*args, **kwargs):
    db = __test_DB()
    return db.Date(*args, **kwargs)


def _fix_encoding(text):
    if isinstance(text, str):
        return text
    elif isinstance(text, bytes):
        try:
            return text.decode("utf8")
        except:
            return text.decode("iso8859-1")


def read_lob(lob):
    if not lob:
        return None
    db = __test_DB()
    return db._read_lob(lob)


class _Callable(object):

    def __init__(self, name):
        self._name = name
        self._implementor = None

    def __getattr__(self, name):
        return self.__class__("%s.%s" % (self._name, name))

    def __call__(self, *args):
        proc = self._implementor.__call__(self._name)
        return proc(*args)


class _Procedure(_Callable):

    def __init__(self, name):
        _Callable.__init__(self, name)
        self._implementor = Procedure


class _Function(_Callable):

    def __init__(self, name):
        _Callable.__init__(self, name)
        self._implementor = Function


class _CallableWrapper(object):

    def __init__(self, wrapped):
        self._wrapped = wrapped

    def __getattr__(self, x):
        return self._wrapped(x)

procedure = _CallableWrapper(_Procedure)
function = _CallableWrapper(_Function)
