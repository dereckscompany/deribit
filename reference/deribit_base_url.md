# Deribit API base URL (the `/api/v2` root)

The root under which every public JSON-RPC method is addressed (e.g.
`/api/v2/public/get_instruments`, `/api/v2/public/ticker`). Overridable
with the `DERIBIT_BASE_URL` environment variable (e.g. point it at
`https://test.deribit.com/api/v2` for the testnet).

## Usage

``` r
deribit_base_url(url = env_or(var, default))
```

## Arguments

- url:

  (scalar\<character\>) an explicit base URL override. Defaults to the
  `DERIBIT_BASE_URL` environment variable, or the public host when
  unset.

## Value

(scalar\<character\>) the base URL.
