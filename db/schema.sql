CREATE TABLE player (
    id SERIAL,
    name TEXT UNIQUE NOT NULL,
    bank JSONB,
    PRIMARY KEY ("id")
);

CREATE TABLE unit (
    id SERIAL,
    owner TEXT NOT NULL references player(name),
    ingame TEXT,
    stats JSONB,
    PRIMARY KEY ("id")
);

CREATE TABLE game (
    id SERIAL,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    map TEXT NOT NULL,
    players JSONB,
    PRIMARY KEY ("id")
);

CREATE TYPE side AS ENUM('gbr', 'ger', 'ita', 'jpn', 'rus', 'us');

CREATE TABLE unitdef (
    name TEXT UNIQUE NOT NULL,
    side side NOT NULL,
    description TEXT,
    health INTEGER NOT NULL,
    ammo INTEGER,
    cost INTEGER NOT NULL
);
