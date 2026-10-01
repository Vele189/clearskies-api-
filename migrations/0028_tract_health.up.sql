-- CDC PLACES, the sixth data source (CP-10). Modeled tract prevalence of the
-- three conditions methodology section 16 names: asthma, COPD and coronary
-- heart disease. This is a source of record only. CP-11 decides what becomes an
-- indicator, and the scorer interpolates from here as it does from
-- tract_exposure.

ALTER TABLE source_snapshot DROP CONSTRAINT source_snapshot_source_check;
ALTER TABLE source_snapshot ADD CONSTRAINT source_snapshot_source_check CHECK (source IN (
    'echo', 'tri', 'airtoxscreen', 'openaq', 'acs',
    'census_tract', 'census_block', 'rsei', 'places'
));

CREATE TABLE tract_health (
    tract_geoid   char(11) NOT NULL REFERENCES census_tract(geoid) ON DELETE CASCADE,
    release_year  smallint NOT NULL,
    asthma_pct    numeric CHECK (asthma_pct BETWEEN 0 AND 100),
    asthma_ci_low numeric CHECK (asthma_ci_low BETWEEN 0 AND 100),
    asthma_ci_high numeric CHECK (asthma_ci_high BETWEEN 0 AND 100),
    copd_pct      numeric CHECK (copd_pct BETWEEN 0 AND 100),
    copd_ci_low   numeric CHECK (copd_ci_low BETWEEN 0 AND 100),
    copd_ci_high  numeric CHECK (copd_ci_high BETWEEN 0 AND 100),
    chd_pct       numeric CHECK (chd_pct BETWEEN 0 AND 100),
    chd_ci_low    numeric CHECK (chd_ci_low BETWEEN 0 AND 100),
    chd_ci_high   numeric CHECK (chd_ci_high BETWEEN 0 AND 100),
    snapshot_id   bigint   NOT NULL REFERENCES source_snapshot(snapshot_id),
    PRIMARY KEY (tract_geoid, release_year)
);

COMMENT ON TABLE tract_health IS
    'CDC PLACES crude prevalence among adults, by 2020 tract. Modeled from BRFSS, '
    'not counted. A tract PLACES does not publish has no row, which is an absence.';
COMMENT ON COLUMN tract_health.release_year IS
    'PLACES release year. The survey it models is about two years older, which the '
    'c_recency term in section 12 does not see; the manifest records it.';
COMMENT ON COLUMN tract_health.asthma_pct IS
    'Current asthma among adults, crude prevalence, percent.';
COMMENT ON COLUMN tract_health.copd_pct IS
    'Chronic obstructive pulmonary disease among adults, crude prevalence, percent.';
COMMENT ON COLUMN tract_health.chd_pct IS
    'Coronary heart disease among adults, crude prevalence, percent.';
