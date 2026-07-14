# Deribit instrument kinds

The `kind` values the instrument and book-summary endpoints accept as a
filter. The name and value coincide (the value *is* the wire token); a
`NULL` `kind` returns every kind. `future_combo` and `option_combo` are
Deribit's multi-leg structured products.

## Usage

``` r
INSTRUMENT_KIND
```

## Format

A named `list` of `scalar<character>` wire tokens:

- future: linear/inverse futures and perpetuals.

- option: calls and puts.

- spot: spot pairs.

- future_combo: multi-leg futures structures.

- option_combo: multi-leg option structures.
