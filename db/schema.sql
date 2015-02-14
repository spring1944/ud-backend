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
    spring_id TEXT NOT NULL,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    map TEXT NOT NULL,
    players JSONB,
    PRIMARY KEY ("id")
);

CREATE TYPE side AS ENUM('gbr', 'ger', 'ita', 'jpn', 'rus', 'us');

CREATE TABLE unitdef (
    name TEXT UNIQUE NOT NULL,
    human_name TEXT NOT NULL,
    side side NOT NULL,
    unitpic TEXT NOT NULL,
    description TEXT,
    health INTEGER NOT NULL,
    ammo INTEGER,
    armor JSONB,
    cost INTEGER NOT NULL,
    squad_members JSONB,
    available_in_shop BOOLEAN NOT NULL DEFAULT 'n'
);
