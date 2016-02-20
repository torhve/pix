import add_column, create_index, types from require "lapis.db.schema"

{
  [1455929083]: =>
    add_column "users", "encrypted_password", types.text { default:'' }
}
