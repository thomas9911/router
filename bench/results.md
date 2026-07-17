# Route matching benchmark: linear scan vs trie

Same route set on both branches: `resource-N/items/{id}` templates, 5000
iterations per measurement. `main` = linear scan (pre-trie). `feat/tree-lookup`
= trie.

| routes | linear: last-registered | linear: first-registered | linear: no match | trie: last-registered | trie: first-registered | trie: no match |
|---|---|---|---|---|---|---|
| 10 | 5.3µs | 2.3µs | 1.8µs | 1.5µs | 1.6µs | 0.9µs |
| 100 | 33µs | 3.3µs | 7.2µs | 1.4µs | 1.7µs | 1.0µs |
| 500 | 139µs | 3.4µs | 32µs | 2.0µs | 1.2µs | 0.9µs |
| 1000 | 285µs | 5.3µs | 61µs | 1.5µs | 1.2µs | 0.9µs |
| 2000 | 598µs | 7.3µs | 119µs | 1.5µs | 1.2µs | 0.9µs |
| 4000 | 1148µs | 11.2µs | 240µs | 2.2µs | 1.2µs | 0.9µs |

Linear scan grows ~O(N) with route count. Trie stays flat regardless of
route count.

Reproduce: `mix run bench/route_bench.exs` on each branch.
