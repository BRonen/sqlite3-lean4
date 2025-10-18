namespace Sqlite.FFI
namespace Constants

def SQLITE_CONFIG_SINGLETHREAD        : UInt32 := 1
def SQLITE_CONFIG_MULTITHREAD         : UInt32 := 2
def SQLITE_CONFIG_SERIALIZED          : UInt32 := 3
def SQLITE_CONFIG_MALLOC              : UInt32 := 4
def SQLITE_CONFIG_GETMALLOC           : UInt32 := 5
def SQLITE_CONFIG_SCRATCH             : UInt32 := 6
def SQLITE_CONFIG_PAGECACHE           : UInt32 := 7
def SQLITE_CONFIG_HEAP                : UInt32 := 8
def SQLITE_CONFIG_MEMSTATUS           : UInt32 := 9
def SQLITE_CONFIG_MUTEX               : UInt32 := 10
def SQLITE_CONFIG_GETMUTEX            : UInt32 := 11
-- /* previously SQLITE_CONFIG_CHUNKALLOC    12 which is now unused. */
def SQLITE_CONFIG_LOOKASIDE           : UInt32 := 13
def SQLITE_CONFIG_PCACHE              : UInt32 := 14
def SQLITE_CONFIG_GETPCACHE           : UInt32 := 15
def SQLITE_CONFIG_LOG                 : UInt32 := 16
def SQLITE_CONFIG_URI                 : UInt32 := 17
def SQLITE_CONFIG_PCACHE2             : UInt32 := 18
def SQLITE_CONFIG_GETPCACHE2          : UInt32 := 19
def SQLITE_CONFIG_COVERING_INDEX_SCAN : UInt32 := 20
def SQLITE_CONFIG_SQLLOG              : UInt32 := 21
def SQLITE_CONFIG_MMAP_SIZE           : UInt32 := 22
def SQLITE_CONFIG_WIN32_HEAPSIZE      : UInt32 := 23
def SQLITE_CONFIG_PCACHE_HDRSZ        : UInt32 := 24
def SQLITE_CONFIG_PMASZ               : UInt32 := 25
def SQLITE_CONFIG_STMTJRNL_SPILL      : UInt32 := 26
def SQLITE_CONFIG_SMALL_MALLOC        : UInt32 := 27
def SQLITE_CONFIG_SORTERREF_SIZE      : UInt32 := 28
def SQLITE_CONFIG_MEMDB_MAXSIZE       : UInt32 := 29
def SQLITE_CONFIG_ROWID_IN_VIEW       : UInt32 := 30

def SQLITE_OPEN_READONLY      : UInt32 := 1
def SQLITE_OPEN_READWRITE     : UInt32 := 2
def SQLITE_OPEN_CREATE        : UInt32 := 4
def SQLITE_OPEN_DELETEONCLOSE : UInt32 := 8
def SQLITE_OPEN_EXCLUSIVE     : UInt32 := 16
def SQLITE_OPEN_AUTOPROXY     : UInt32 := 32
def SQLITE_OPEN_URI           : UInt32 := 64
def SQLITE_OPEN_MEMORY        : UInt32 := 128
def SQLITE_OPEN_MAIN_DB       : UInt32 := 256
def SQLITE_OPEN_TEMP_DB       : UInt32 := 512
def SQLITE_OPEN_TRANSIENT_DB  : UInt32 := 1024
def SQLITE_OPEN_MAIN_JOURNAL  : UInt32 := 2048
def SQLITE_OPEN_TEMP_JOURNAL  : UInt32 := 4096
def SQLITE_OPEN_SUBJOURNAL    : UInt32 := 8192
def SQLITE_OPEN_SUPER_JOURNAL : UInt32 := 16384
def SQLITE_OPEN_NOMUTEX       : UInt32 := 32768
def SQLITE_OPEN_FULLMUTEX     : UInt32 := 65536
def SQLITE_OPEN_SHAREDCACHE   : UInt32 := 131072
def SQLITE_OPEN_PRIVATECACHE  : UInt32 := 262144
def SQLITE_OPEN_WAL           : UInt32 := 524288
def SQLITE_OPEN_NOFOLLOW      : UInt32 := 16777216
def SQLITE_OPEN_EXRESCODE     : UInt32 := 33554432

end Constants

private opaque Nonempty : NonemptyType

def RawConn : Type := Nonempty.type
def RawCursor : Type := Nonempty.type

structure Cursor where
  cursor : RawCursor
  step : IO Bool
  bindText : UInt32 → String → IO Unit
  bindInt : UInt32 → Int32 → IO Unit
  reset : IO Unit
  columnsCount : IO UInt32
  columnText : UInt32 → IO String
  columnInt : UInt32 → IO Int32
  cursorExplain : UInt32 → IO Int

structure Connection where
  path : String
  conn : RawConn
  prepare : String → IO (Except String Cursor)

instance : ToString Connection where
  toString (conn : Connection) := s!"Connection('{conn.path}')"

@[extern "lean_sqlite_initialize"]
private opaque sqliteInit : IO Unit
builtin_initialize sqliteInit

@[extern "lean_sqlite_open"]
private opaque sqliteOpen : String → UInt32 → IO RawConn

@[extern "lean_sqlite_prepare"]
private opaque sqlitePrepare : @&RawConn → String → IO (Except String RawCursor)

@[extern "lean_sqlite_cursor_bind_text"]
private opaque cursorBindText : @&RawCursor → UInt32 → String → IO Unit

@[extern "lean_sqlite_cursor_bind_int"]
private opaque cursorBindInt : @&RawCursor → UInt32 → Int32 → IO Unit

@[extern "lean_sqlite_cursor_bind_parameter_name"]
private opaque cursorBindParameterName : @&RawCursor → Int32 → String → IO Unit

@[extern "lean_sqlite_cursor_step"]
private opaque cursorStep : @&RawCursor → IO Bool

@[extern "lean_sqlite_cursor_reset"]
private opaque cursorReset : @&RawCursor → IO Unit

@[extern "lean_sqlite_cursor_columns_count"]
private opaque cursorColumnsCount : @&RawCursor → IO UInt32

@[extern "lean_sqlite_cursor_column_text"]
private opaque cursorColumnText : @&RawCursor → UInt32 → IO String

@[extern "lean_sqlite_cursor_column_int"]
private opaque cursorColumnInt : @&RawCursor → UInt32 → IO Int32

@[extern "lean_sqlite_cursor_explain"]
private opaque cursorExplain : @&RawCursor → UInt32 → IO Int

@[extern "lean_sqlite_threadsafe"]
opaque sqliteThreadsafe : IO Int

@[extern "lean_sqlite_config"]
opaque sqliteConfig : UInt32 → IO Unit

private def sqlitePrepareWrap (conn : RawConn) (query : String) : IO (Except String Cursor) := do
  pure $ match ← sqlitePrepare conn query with
  | Except.ok c => pure { cursor := c,
                          step := cursorStep c,
                          bindText := cursorBindText c,
                          bindInt := cursorBindInt c,
                          reset := cursorReset c,
                          columnsCount := cursorColumnsCount c,
                          columnText := cursorColumnText c,
                          columnInt := cursorColumnInt c,
                          cursorExplain := cursorExplain c, }
  | Except.error e => Except.error e

def connect (s : String) (flags : UInt32) : IO Connection := do
  let rawconn ← sqliteOpen s flags
  pure { path := s,
         conn := rawconn,
         prepare := (sqlitePrepareWrap rawconn ·) }

end Sqlite.FFI
