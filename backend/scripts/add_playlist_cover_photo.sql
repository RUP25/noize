-- Migration script to add cover_photo_url column to playlists table
-- Run this SQL directly in your PostgreSQL database

-- Check if column exists, and add it if it doesn't
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='playlists' AND column_name='cover_photo_url'
    ) THEN
        ALTER TABLE playlists ADD COLUMN cover_photo_url VARCHAR;
        RAISE NOTICE 'Added cover_photo_url column to playlists table';
    ELSE
        RAISE NOTICE 'cover_photo_url column already exists in playlists table';
    END IF;
END $$;
