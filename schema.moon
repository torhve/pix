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
    {"token", "VARCHAR(6) NOT NULL"}
    {"user_id", foreign_key}
    {"album_id", foreign_key}
    {"views", integer}
    {"created_at", time}
    {"updated_at", time}
    {"expires_at", time}

    "PRIMARY KEY (id)"
  }
  create_index "accesstokens", "user_id"
  create_index "accesstokens", "album_id"
  create_index "accesstokens", "token", unique: true

  -- Persona session
  create_table "sessions", {
    {"sessionid", "VARCHAR(32)"}
    {"email", foreign_key}
    {"created_at", time}
    {"updated_at", time}
    {"expires_at", time}

    "PRIMARY KEY (sessionid)"
  }
  create_index "sessions", "sessionid", unique: true
  create_index "sessions", "email"

--migrations.create_migrations_table!

destroy_schema = ->
    tbls = {
      "users", "albums", "images", "accesstokens", "sessions"
    }

    for t in *tbls
        drop_table t


{ :make_schema, :destroy_schema }
