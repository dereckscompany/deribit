# deribit return shapes

Reusable roxyassert `@type` shapes for the parsed deribit `data.table`s.
Measurement columns (market prices, sizes, greeks, funding, and any
venue field that is legitimately absent for a given instrument kind) are
typed `| NA`; structural columns (identifiers, instrument descriptors,
sides, period timestamps, and flags) are strict. Faithful field names
are preserved verbatim and only snake_cased; nested JSON objects are
flattened with the parent field as a prefix (`stats.high` -\>
stats_high, `greeks.delta` -\> greeks_delta). `deribit` is a leaf
connector: nothing internal calls a per-shape validator and no
downstream package validates against these shapes, so there is no
`@genassert` and no `@exportassert`; the shapes exist only to be
expanded into each method's own return contract.
