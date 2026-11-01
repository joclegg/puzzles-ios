#!/usr/bin/env bash
set -euo pipefail

PART="$1"
TIMES="$2"
INDEX="${PART%/*}"
TOTAL="${PART#*/}"

awk -v index_="$INDEX" -v total="$TOTAL" '
  FNR == NR { if (NF >= 2) known[$1] = $2 + 0; next }
  NF {
    name = $0
    sub(/.*\//, "", name)
    sub(/\.yaml$/, "", name)
    n++
    path[n] = $0
    key[n] = name
  }
  END {
    m = 0
    for (k in known) values[++m] = known[k]
    for (i = 2; i <= m; i++) { v = values[i]; j = i - 1; while (j > 0 && values[j] > v) { values[j + 1] = values[j]; j-- } values[j + 1] = v }
    median = m == 0 ? 60 : (m % 2 ? values[(m + 1) / 2] : (values[m / 2] + values[m / 2 + 1]) / 2)
    for (i = 1; i <= n; i++) { t[i] = (key[i] in known) ? known[key[i]] : median; order[i] = i }
    for (i = 2; i <= n; i++) {
      o = order[i]; j = i - 1
      while (j > 0 && (t[order[j]] < t[o] || (t[order[j]] == t[o] && key[order[j]] > key[o]))) { order[j + 1] = order[j]; j-- }
      order[j + 1] = o
    }
    for (s = 1; s <= total; s++) load[s] = 0
    for (i = 1; i <= n; i++) {
      o = order[i]; best = 1
      for (s = 2; s <= total; s++) if (load[s] < load[best]) best = s
      load[best] += t[o]
      shard[o] = best
    }
    for (i = 1; i <= n; i++) if (shard[i] == index_) print path[i]
  }
' "$TIMES" -
