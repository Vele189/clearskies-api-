-- Reverses 0028: the table goes, and so do the snapshots that only it used,
-- because the restored constraint would refuse them.

DROP TABLE tract_health;
DELETE FROM source_snapshot WHERE source = 'places';

ALTER TABLE source_snapshot DROP CONSTRAINT source_snapshot_source_check;
ALTER TABLE source_snapshot ADD CONSTRAINT source_snapshot_source_check CHECK (source IN (
    'echo', 'tri', 'airtoxscreen', 'openaq', 'acs',
    'census_tract', 'census_block', 'rsei'
));
