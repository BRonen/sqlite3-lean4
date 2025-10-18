#include <lean/lean.h>
#include <sqlite3.h>
#include <stdio.h>

lean_external_class* g_sqlite_connection_external_class = NULL;
lean_external_class* g_sqlite_cursor_external_class = NULL;

void noop_foreach(void* mod, b_lean_obj_arg fn) {}

lean_object* box_connection(sqlite3* conn) {
  return lean_alloc_external(g_sqlite_connection_external_class, conn);
}

sqlite3* unbox_connection(lean_object* o) {
  return (sqlite3*) lean_get_external_data(o);
}

lean_object* box_cursor(sqlite3_stmt* cursor) {
  return lean_alloc_external(g_sqlite_cursor_external_class, cursor);
}

sqlite3_stmt* unbox_cursor(lean_object* o) {
  return (sqlite3_stmt*) lean_get_external_data(o);
}

void connection_finalize(void* conn) {
  if (!conn) return;

  printf("connection_finalize: %x\n", conn);

  sqlite3_close(conn);
}

void cursor_finalize(void* cursor) {
  if (!cursor) return;

  printf("cursor_finalize: %x\n", cursor);

  sqlite3_finalize(cursor);
}

lean_obj_res lean_sqlite_initialize() {
  g_sqlite_connection_external_class = lean_register_external_class(connection_finalize, noop_foreach);
  g_sqlite_cursor_external_class = lean_register_external_class(cursor_finalize, noop_foreach);
  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res lean_sqlite_open(b_lean_obj_arg path, uint32_t flags) {
  const char* path_str = lean_string_cstr(path);
  sqlite3* conn = malloc(sizeof(sqlite3*));

  printf("initialize_connection: %x\n", conn);

  int32_t c = sqlite3_open_v2(path_str, &conn, flags, NULL);

  if (c == SQLITE_OK)
    return lean_io_result_mk_ok(box_connection(conn));

  lean_object* err = lean_mk_string(sqlite3_errmsg(conn));

  sqlite3_close(conn);

  return lean_io_result_mk_error(lean_mk_io_error_other_error(c, err));
}

lean_obj_res lean_sqlite_prepare(b_lean_obj_arg conn_box, b_lean_obj_arg query_str) {
  sqlite3* conn = unbox_connection(conn_box);
  const char* query = lean_string_cstr(query_str);

  sqlite3_stmt* cursor = malloc(sizeof(sqlite3_stmt*));

  printf("initialize_cursor: %x\n", cursor);

  int32_t c = sqlite3_prepare_v2(conn, query, -1, &cursor, NULL);

  if (c != SQLITE_OK) {
    lean_object* err = lean_mk_string(sqlite3_errmsg(conn));
    free(cursor);

    lean_object* res = lean_alloc_ctor(0, 1, 0);
    lean_ctor_set(res, 0, err);
    return lean_io_result_mk_ok(res);
  }

  lean_object* res = lean_alloc_ctor(1, 1, 0);
  lean_ctor_set(res, 0, box_cursor(cursor));
  return lean_io_result_mk_ok(res);
}

lean_obj_res lean_sqlite_cursor_bind_text(b_lean_obj_arg cursor_box, uint32_t col, b_lean_obj_arg value) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);
  const char* value_str = lean_string_cstr(value);

  const int32_t c = sqlite3_bind_text(cursor, col, value_str, -1, NULL);

  if (c != SQLITE_OK) {
    lean_object* err = lean_mk_string(sqlite3_errmsg(sqlite3_db_handle(cursor)));
    return lean_io_result_mk_error(lean_mk_io_error_other_error(c, err));
  }

  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res lean_sqlite_cursor_bind_int(b_lean_obj_arg cursor_box, uint32_t col, int32_t value) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  const int32_t c = sqlite3_bind_int(cursor, col, value);

  if (c != SQLITE_OK) {
    lean_object* err = lean_mk_string(sqlite3_errmsg(sqlite3_db_handle(cursor)));
    return lean_io_result_mk_error(lean_mk_io_error_other_error(c, err));
  }

  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res lean_sqlite_cursor_bind_parameter_name(b_lean_obj_arg cursor_box, int32_t value) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  const char* name = sqlite3_bind_parameter_name(cursor, value);

  return lean_io_result_mk_ok(lean_mk_string(name));
}

lean_obj_res lean_sqlite_cursor_column_text(b_lean_obj_arg cursor_box, uint32_t col) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  const unsigned char* text = sqlite3_column_text(cursor, col);

  lean_object* s = lean_mk_string((const char*) text);

  return lean_io_result_mk_ok(s);
}

lean_obj_res lean_sqlite_cursor_column_int(b_lean_obj_arg cursor_box, uint32_t col) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  const int32_t integer = sqlite3_column_int(cursor, col);

  return lean_io_result_mk_ok(lean_box(integer));
}

lean_obj_res lean_sqlite_cursor_step(b_lean_obj_arg cursor_box) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  int32_t c = sqlite3_step(cursor);

  if (c == SQLITE_ROW) {
    return lean_io_result_mk_ok(lean_box(1));
  }

  if (c == SQLITE_DONE) {
    return lean_io_result_mk_ok(lean_box(0));
  }

  lean_object* err = lean_mk_string(sqlite3_errmsg(sqlite3_db_handle(cursor)));
  return lean_io_result_mk_error(lean_mk_io_error_other_error(c, err));
}

lean_obj_res lean_sqlite_cursor_reset(b_lean_obj_arg cursor_box) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  int32_t c = sqlite3_reset(cursor);

  if (c == SQLITE_OK)
    return lean_io_result_mk_ok(lean_box(0));

  lean_object *err = lean_mk_string(sqlite3_errmsg(sqlite3_db_handle(cursor)));
  return lean_io_result_mk_error(lean_mk_io_error_other_error(c, err));
}

lean_obj_res lean_sqlite_cursor_columns_count(b_lean_obj_arg cursor_box) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  const int c = sqlite3_column_count(cursor);

  return lean_io_result_mk_ok(lean_box(c));
}

lean_obj_res lean_sqlite_threadsafe() {
  const int threadsafe = sqlite3_threadsafe();

  return lean_io_result_mk_ok(lean_box(threadsafe));
}

lean_obj_res lean_sqlite_config(int32_t config) {
  int c = sqlite3_config(config);

  if (c != SQLITE_OK) {
    lean_object* err = lean_mk_string("Error sqlite");
    return lean_io_result_mk_error(lean_mk_io_error_other_error(c, err));
  }

  return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res lean_sqlite_cursor_explain(b_lean_obj_arg cursor_box, int32_t emode) {
  sqlite3_stmt* cursor = unbox_cursor(cursor_box);

  const int c = sqlite3_stmt_explain(cursor, emode);

  return lean_io_result_mk_ok(lean_box(c));
}
