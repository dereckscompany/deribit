# DVOL volatility-index candle resolutions

The `resolution` values `get_volatility_index_data()` accepts, in
seconds (plus the `"1D"` daily token). The named list is the whitelist
the method validates its `resolution` argument against.

## Usage

``` r
DVOL_RESOLUTIONS
```

## Format

A named `list` of `scalar<character>` wire tokens: `1`, `60`, `3600`,
`43200`, `1D`.
