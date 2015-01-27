BEGIN TRANSACTION;
    CREATE TABLE IF NOT EXISTS player (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        handle TEXT NOT NULL UNIQUE
    );

    CREATE TABLE IF NOT EXISTS unit (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER NOT NULL,
        ingame_name TEXT NOT NULL,
        experience REAL NOT NULL DEFAULT 0,
        health REAL NOT NULL,
        ammo INTEGER,
        FOREIGN KEY(player_id) REFERENCES player(id)
    );

    CREATE TABLE IF NOT EXISTS game (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        spring_id TEXT NOT NULL,
        start_time INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        end_time INTEGER
    );

    CREATE TABLE IF NOT EXISTS bank_account (
        player_id INTEGER NOT NULL PRIMARY KEY,
        amount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(player_id) REFERENCES player(id)
    );

END TRANSACTION;
