db = require "lapis.nginx.postgres"
schema = require "lapis.db.schema"
migrations = require "lapis.db.migrations"

import types, create_table, create_index, drop_table from schema

make_schema = ->
  {
    :serial
    :varchar
    :text
    :time
    :integer
    :foreign_key
    :boolean
  } = schema.types

  -- Users
  create_table "users", {
    {"id", serial}
    {"token", "VARCHAR(6) NOT NULL"}
    {"email", text}
    {"name", text}
    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "users", "email", unique: true
  create_index "users", "token", unique: true

  -- Albums
  create_table "albums", {
    {"id", serial}
    {"user_id", foreign_key}
    {"token", "VARCHAR(6) NOT NULL"}
    {"title", text}
    {"metadata", "hstore"}
    {"views", integer}
    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "albums", "user_id"
  create_index "albums", "token", unique: true

  -- Images
  create_table "images", {
    {"id", serial}
    {"user_id", foreign_key}
    {"album_id", foreign_key}
    {"token", "VARCHAR(6) NOT NULL"}
    {"title", text}
    {"file_name", text}
    {"thumb_name", text}
    {"huge_name", text}
    {"metadata", "hstore"}
    {"views", integer}
    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "images", "user_id"
  create_index "images", "album_id"
  create_index "images", "token", unique: true

  -- Access
  create_table "accesstokens", {
    {"id", serial}
    {"user_id", foreign_key}
    {"album_id", foreign_key}
    {"slug", text}
    {"views", integer}
    {"created_at", time}
    {"updated_at", time}
    {"expires_at", time}

    "PRIMARY KEY (id)"
  }
  create_index "accesstokens", "user_id"
  create_index "accesstokens", "album_id"

--migrations.create_migrations_table!

destroy_schema = ->
    tbls = {
      "users", "albums", "images", "accesstokens" 
    }

    for t in *tbls
        drop_table t


{ :make_schema, :destroy_schema }
