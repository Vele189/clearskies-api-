-- Reverses 0029: both indexes come back exactly as 0003 and 0010 created them.

CREATE INDEX hex_pilot_idx ON hex (h3) WHERE in_pilot_state;
CREATE INDEX statute_chunk_embedding_idx
    ON statute_chunk USING hnsw (embedding vector_cosine_ops);
