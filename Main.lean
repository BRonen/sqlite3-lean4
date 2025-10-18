import Sqlite

open IO

def double (f : Nat -> Nat) n := f (f n)
def inc := fun n => n + 1

def cursorExplain (c : Sqlite.FFI.Connection) (emode : UInt32) : IO Unit := do
  match ← c.prepare "select * from users limit 50;" with
  | Except.error e => println s!"error {e}"
  | Except.ok q => do
    let _ ← q.cursorExplain emode
    let c ← q.columnsCount
    println s!"columnsCount: {c}"
    for i in [0:100] do
      match ← q.step with
      | false => pure ()
      | true => do
        println s!"{i} explain: {← q.columnInt 0} {← q.columnText 1}"


def printUser (fuel : Nat) (cursor : Sqlite.FFI.Cursor) : IO Unit := do
  if fuel = 0 then
    pure ()
  else
    match ← cursor.step with
    | false => pure ()
    | true => do
      println s!"id: {← cursor.columnInt 0} | name: {← cursor.columnText 1}"
      printUser (fuel - 1) cursor

def main : IO Unit := do
  println $ ← Sqlite.FFI.sqliteThreadsafe
  println Sqlite.FFI.Constants.SQLITE_CONFIG_SINGLETHREAD
  println Sqlite.FFI.Constants.SQLITE_CONFIG_MULTITHREAD
  println $ ← Sqlite.FFI.sqliteConfig Sqlite.FFI.Constants.SQLITE_CONFIG_MULTITHREAD
  let flags := Sqlite.FFI.Constants.SQLITE_OPEN_READWRITE ||| Sqlite.FFI.Constants.SQLITE_OPEN_CREATE
  let conn ← Sqlite.FFI.connect "test.sqlite3" flags
  cursorExplain conn 1
  match ← conn.prepare "delete from users where id = 154;" with
  | Except.ok c => c.step
  | _ => pure false
  match ← conn.prepare "insert into users values (?, ?);" with
  | Except.error e => println s!"error {e}"
  | Except.ok c =>
    c.bindInt 1 154
    c.bindText 2 "giga chad"
    printUser 10 c
  println "----------------------------------------------------------------"
  match ← conn.prepare "select count(1) from users;" with
  | Except.ok c =>
    println s!"{← c.columnsCount}"
    match ← c.step with
    | false => println "error"
    | true => println "step"
    let count ← c.columnInt 0
    println s!"count: {count}"
    match ← conn.prepare "select * from users;" with
     | Except.error e => println e
     | Except.ok c =>
       printUser count.toNatClampNeg c
  | Except.error e => println s!"error: {e}"
  println s!"Hello, {conn}"
