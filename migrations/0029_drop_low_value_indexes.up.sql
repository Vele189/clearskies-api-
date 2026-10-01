-- Two indexes whose space costs more than they return on Neon's 512 MB plan,
-- where methodology v0.3.0's run and the rebuilt section 7 crosswalk left the
-- database over the cap. About 31 MB between them.
--
-- statute_chunk_embedding_idx (HNSW, about 21 MB). The corpus is 4,026 chunks.
-- An exact cosine scan over that is a few milliseconds, and it is exact, where
-- HNSW is approximate: dropping the index can only improve recall. Retrieval
-- orders by `embedding <=> $1` with a LIMIT and needs no index to do so.
--
-- hex_pilot_idx (about 10 MB). A partial index on h3 for in-pilot cells, which
-- hex_pkey already indexes for every cell. It had been scanned five times.

DROP INDEX statute_chunk_embedding_idx;
DROP INDEX hex_pilot_idx;
