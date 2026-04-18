-- Add lyrics column to songs table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='songs' AND column_name='lyrics'
    ) THEN
        ALTER TABLE songs ADD COLUMN lyrics TEXT;
        RAISE NOTICE 'Added lyrics column to songs table';
    ELSE
        RAISE NOTICE 'lyrics column already exists';
    END IF;
END $$;
