-- Create playlists table with cover_photo_url column
CREATE TABLE IF NOT EXISTS playlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR DEFAULT 'My Playlist',
    is_public BOOLEAN DEFAULT FALSE,
    cover_photo_url VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_playlists_user_id ON playlists(user_id);

-- Create playlist_songs junction table
CREATE TABLE IF NOT EXISTS playlist_songs (
    id SERIAL PRIMARY KEY,
    playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    song_id INTEGER NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(playlist_id, song_id)
);

CREATE INDEX IF NOT EXISTS idx_playlist_songs_playlist_id ON playlist_songs(playlist_id);
CREATE INDEX IF NOT EXISTS idx_playlist_songs_song_id ON playlist_songs(song_id);
