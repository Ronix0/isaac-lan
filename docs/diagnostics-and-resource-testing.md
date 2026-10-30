# Diagnostics and Resource Testing

Configuration parsing and bounded statistics are in [`core/`](https://github.com/BMingSY/isaac-lan/tree/main/src/core), file I/O is in [`app/configuration.*`](https://github.com/BMingSY/isaac-lan/tree/main/src/app), runtime measurements are in [`diagnostics/`](https://github.com/BMingSY/isaac-lan/tree/main/src/diagnostics), and Lua phase timing is in [`bridge/diagnostics/`](https://github.com/BMingSY/isaac-lan/tree/main/src/bridge/diagnostics). Diagnostic options control recording only; they do not control gameplay, state fields, or backpressure.

## Configuration and Logs

The extension creates `config.ini` on first launch. Existing configuration text and values are preserved; only missing entries and explanatory comments are added. Restart after changing the file. Defaults are INFO logging, performance statistics disabled, and a 1000 ms sampling interval.

- UTF-8, optionally with BOM and CRLF; blank lines and comments beginning with `;` or `#` are supported. End-of-line comments are not supported.
- Keys and values are case-sensitive. For duplicate keys, the first value wins. Unknown keys and invalid values are written to the startup log; invalid entries fall back to defaults. If the file exceeds 64 KiB, the entire file falls back to defaults.
- Set `[logging] level = DEBUG` to enable detailed logs and `[diagnostics] performance = true` to enable performance windows. The installer does not overwrite user configuration.

Logs are archived alongside the original game's `log.txt`, separated by startup and run. `startup.log` records startup and exit; `runtime.log` records in-run events; enabling performance statistics also creates `performance.jsonl`.

Each run gets a new sequence number, even when continuing with the same seed; existing logs are never overwritten. The startup log is updated on exit. Records include millisecond timestamps, timezone, level, and PID; message newlines are escaped. Switching directories closes the previous handle. Errors are flushed immediately. Before the path is determined, the cache is limited to 256 KiB. There is no automatic rotation or total-size limit; old directories can be removed manually.

## Performance Metrics

| Metric | Meaning |
| --- | --- |
| Process resources | Run time/window duration, CPU as a percentage of one core, private memory, working set, and handles; unavailable readings are `null`. |
| Phase duration | Render interval; capture/application, encode/decode, inventory, entities, grids, sprites, compression/decompression. Application is also divided into position, character, map, room, and commit phases. |
| Objects and queues | Lua heap, entity/grid/map sizes, connections, queue/state capacity, and retired sessions. |
| `cached_world_bytes` | Allocated capacity of full-view history. |
| `world_in_flight_bytes` / `world_in_flight_states` | Unacknowledged payload bytes/views in the send window; excludes UDP recovery packets still being retransmitted after the record timeout. |
| `world_delivery_window` / `world_oldest_unapplied_ms` | Sum of connection windows with views in flight / age of the oldest unacknowledged view. |
| `input_coalesced` | Number of unsent inputs coalesced for the current connection; excludes inputs already handed to the transport protocol. |
| `world_snapshots_total` / `world_delta_snapshots_total` | Cumulative full views / delta views in the current session. |
| `world_raw_bytes_total` / `world_wire_bytes_total` / `world_full_wire_bytes_total` | Raw bytes / published compressed payload / full-compression comparison for the same batch. |

Payload counters include low-frequency dependencies actually sent and large-view validation fragments and headers. They exclude UDP/ENet framing, retransmissions, frp, and reliable save traffic; use relay records for actual link usage. `compress` already includes `delta.encode`; do not add them together. DEBUG `state_transfer` records provide `raw`, `wire`, `full_wire`, `delta`, and `base`.

Network compression/decompression timings are produced by worker threads and returned to the main thread through a bounded queue. When the queue is full, diagnostic samples are dropped rather than blocking transport. `checkpoint_capture` separates main-thread native capture from save packaging. `checkpoint_pack` records raw/compressed byte counts and background duration. `checkpoint_received` records background restore duration and elapsed time from the startup header to restore completion. These metrics do not include the subsequent native Continue operation or application of the first real-time view, so they are not full reconnect duration.

`input.present` measures local sampling through completion of the first draw callback. `input.ack` measures sampling through application of the authoritative view containing the corresponding acknowledgement number. Both use the local monotonic clock; neither includes hardware input time before the operating system delivers it, and neither proves that a particular firing effect actually triggered. `view.age` is the clock-mapped estimate of capture-to-application age and does not replace measured view age in same-machine logs. `prediction.corrections` records correction count after replay. `sum_millipixels` and `max_millipixels` record total and maximum correction in thousandths of a coordinate unit. `prediction.bucket1` through `bucket5` count correction magnitudes of ≤1, (1,4], (4,16], (16,64], and >64. Counts include zero corrections, reset per session, and are not written to the game UI.

Mean and maximum use every sample received in the window. p50/p95/p99 use the latest 512 samples. Cost names and counters are limited to 64 each and reset per window. Lua heap readings are read-only samples; they do not force game garbage collection. When statistics are disabled, the original function is called directly.

Set `ISAAC_RUN_OUTPUT` and `ISAAC_PERFORMANCE_SUMMARY` to the current run's recording and summary destinations, then execute:

```sh
python3 tools/check_performance.py "$ISAAC_RUN_OUTPUT" --output "$ISAAC_PERFORMANCE_SUMMARY"
```

The summary computes call-count-weighted averages and lists the slowest window percentiles; window percentiles are not treated as global percentiles. To investigate stutter, inspect render intervals, application cost, network queues, and object counts together. Memory growth caused by cross-floor resource loading is not by itself evidence of a leak. Heap debugging, concurrent load, and recording affect performance and must be compared separately.

## Bandwidth Measurement

[`tools/datagram_relay.py`](https://github.com/BMingSY/isaac-lan/blob/main/tools/datagram_relay.py) shares a downstream budget across guests and uses a separate shared upstream budget; both are unlimited by default. 375000 bytes/second corresponds to decimal 3 Mbps. `--relay-control` accepts bidirectional bandwidth, delay, jitter, pause, loss, and duplication settings in JSON. The complete configuration is validated before it is applied. The relay drops, duplicates, and reorders complete UDP datagrams; a pause window represents burst loss. `run_network_engine.py --record-relay` saves timestamped UDP datagrams. Per-second relay records include forwarded bytes in both directions and the actual configuration. See [Development and Testing](https://github.com/BMingSY/isaac-lan/blob/main/docs/development-and-testing.md) for weak-network behavior and state-age acceptance.

[`tools/analyze_delirium_performance.py`](https://github.com/BMingSY/isaac-lan/blob/main/tools/analyze_delirium_performance.py) summarizes payloads, application frequency, and frame intervals. State lag requires clock calibration using `tick_ms`/`utc_ms`; combat cost excludes loading windows.

## Codec Benchmarks

[`benchmark_state_codec.py`](https://github.com/BMingSY/isaac-lan/blob/main/tools/benchmark_state_codec.py) compares the production C++ binding with the Lua reference implementation in Linux Lua 5.3 without launching the game. Use a separate Release build to avoid timing interference from sanitizers and debug builds:

```sh
cmake -S . -B build-codec -DISAAC_LAN_BUILD_ENGINE=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build-codec --target isaac_lan_state_codec_runner
python tools/benchmark_state_codec.py --runner build-codec/isaac_lan_state_codec_runner \
  --iterations 100 --output "$ISAAC_CODEC_REPORT"
```

The default input is a synthetic state simulating inventory and entity fields. First verify byte-for-byte equivalence, then measure encoding, decoding, and fragment reuse for three guests in the same room. `transfer-one-peer`, `transfer-three-peers`, and `transfer-split-rooms` also execute production layered projection and dual real-time/dependency encoding, simulating one guest, three guests in one room, and guests in separate rooms. Each measurement creates a fragment cache for an independent generation; `bytes` is the total payload for all recipients in that operation. These operations do not include game-object capture and cannot be used to infer game frame rate. `--snapshot` accepts a restored full binary view; layered operations still use simulated recipients and room positions. Output preserves per-operation CPU time, sample count, mean/P95, speed ratio, runner hash, and JSON/JUnit. Missing measurements from either side, mismatched input sizes, or execution failure do not count as completion. A passing report means the comparison ran completely, not that live-game performance passed.

[`run_shared_view_encoding.py`](https://github.com/BMingSY/isaac-lan/blob/main/tools/run_shared_view_encoding.py) uses `--host`, `--client`, and two `--extra-client` arguments to specify four isolated instances. It continuously checks three guests in the same room, split rooms, regrouping, Devil Deal prices, and floor-transition cleanup. `--build` selects the candidate build and `--output` saves evidence; `--baseline` switches only the ordinary-room price-scan assertion to the old behavior. Each room defaults to 200 stationary tears (600 total across split rooms, avoiding load changes from native entity-pool recycling). After warm-up, each case is measured for 15 seconds. `fixture.capture.same/split` records total production capture and dual-path encoding time per recipient; `fixture.encode.same/split` records the duration of each encoding call within that total. Byte comparisons and scenario preparation are excluded from these operations, so results cannot be directly converted to frame rate. No other game process may be running. The tool restores isolated data and verifies hashes on exit.

[`benchmark_compression.py`](https://github.com/BMingSY/isaac-lan/blob/main/tools/benchmark_compression.py) compares complete miniz, LZ4, and Zstd frames from real snapshots, as well as miniz byte patches and Zstd prefix compression in the full send path. When building, set `ISAAC_LAN_LZ4_SOURCE_DIR` to the upstream LZ4 1.10.0 `lib` directory and build `isaac_lan_compression_benchmark`. LZ4 is used only for the benchmark and is not linked into the game DLL.

```sh
python tools/benchmark_compression.py --runner "$ISAAC_COMPRESSION_RUNNER" \
  --pair "$ISAAC_BASE_SNAPSHOT" "$ISAAC_NEXT_SNAPSHOT" \
  --iterations 100 --output "$ISAAC_COMPRESSION_REPORT"
```

Each input pair is a confirmed baseline and the next complete byte sequence. One `--pair` measures the same view; supply up to three pairs to measure different views. The benchmark separately performs sender compression and receiver decompression for 2/3/4 players; decompression time is the sum across guests. Every restore must match byte-for-byte. Reports preserve input and runner hashes, actual sizes, mean/P95/P99, context memory, and JSON/JUnit. Timing includes prefix indexing and full-frame candidates, but excludes network, Lua, and game rendering. Run it separately on the target Windows x86 Release build; do not run it concurrently with live-game performance tests.

## On-Demand Performance and Resource Regression

Routine commands are in [Development and Testing](https://github.com/BMingSY/isaac-lan/blob/main/docs/development-and-testing.md). CI covers sanitizers, repeated Lua entity creation/deletion and weak-reference release, bounded transport under a slow consumer, and log-handle cleanup after repeated sessions. These checks do not establish resource behavior in the game or in Hooks that were not executed.

Performance and stress tests are not part of the default release scope. To investigate a related issue, use a separate isolated host/guest pair and select the relevant load. The item stress suite and `pickup-pressure` check for other game processes before startup and after shutdown; if another instance is running, the performance round is invalid. Do not launch other games or CPU-intensive tasks during measurement. For example, run a long campaign resource check with:

```sh
python3 tools/run_special_routes.py \
  --host "$ISAAC_HOST_LAB" \
  --client "$ISAAC_CLIENT_LAB" \
  --case campaign --performance --output "$ISAAC_RUN_OUTPUT"
```

`pickup-pressure` keeps 0/100/300/500 real in-game pickups in the same run, including hearts, coins, keys, bombs, and item pedestals. Each level lasts 400 ticks. After excluding creation and cleanup, it samples 300 ticks, verifies actual counts on both sides, and outputs frame intervals, capture/application time, and raw byte counts under `LAN_PICKUP_PRESSURE`. Pickups remain uncollectable; this does not evaluate the pickup experience. Baseline and candidate must use the same fixtures and diagnostic settings, with recording and heap observation disabled:

```sh
python3 tools/run_special_routes.py \
  --host "$ISAAC_HOST_LAB" --client "$ISAAC_CLIENT_LAB" \
  --case pickup-pressure --performance --latency-ms 40 --record-relay \
  --output "$ISAAC_RUN_OUTPUT"
```

`--latency-ms` is relay delay in each direction; 40 ms corresponds to approximately 80 ms RTT. Item audits also accept this option. Compare actual payload differences by dividing cumulative counter differences by view count within the same stable load level; do not compare whole-run totals when run durations differ. Delta hit rate does not replace guest application time: a received delta still has to restore the complete view and game objects.

`engine_test.py run item-audit -- --mode stress ...` enables performance statistics and disables heap observation and recording by default. Add `--heap-check` for native anomaly work and `--record` for visuals; measure those separately from pure performance runs. Other item-audit modes retain heap observation. `stress:idle-baseline`, `stress:idle-inventory-100/300/500`, and `stress:idle-copies-1000` disable automatic attacks and require at least 100 rendered samples on both sides, with P95 no higher than 33.33 ms. Existing cases without the `idle-` prefix still include brief attacks and must be interpreted separately.

`--no-phase-profile` explicitly disables detailed diagnostics in the isolated configuration for comparison with default production settings. The fixture still records render intervals frame by frame, plus each capture/application duration and byte count; acceptance budgets remain unchanged. Under large entity counts, per-entity/sprite timing can distort results, so baseline and candidate must use identical diagnostic settings.

A slower baseline can use `--case-timeout` to extend the per-case watchdog and complete the same target tick. This does not change item load, sampling start, or frame-time budget. Preserve the original timed-out round.

`--verify-codec` checks old and new encoding of one real view on both sides in every scenario and saves the original snapshot and the next tick's snapshot. It also compares native batch fields for tears, familiars, pickups, and effect entities with the game Lua API; the guest additionally checks write results and that invalid arrays cause no writes. The `entity-fields` case ensures all four entity categories actually appear and compares shop-price and slot write results. Stress scenarios run before the statistics window at tick 150. `codec_verified` and `entity_fields_verified` are independent evidence; they do not replace scenario completion or exit results.

`campaign` uses a fixed route, Boss-room positioning, protection, and accelerated damage. Original combat, pickups, exits, floor transitions, and The Lamb ending still execute, but this is not an unaided random run. Recording is off by default; add `--record` when needed. Isolated data is backed up and restored file by file. Any nonzero process exit fails the entire round.

Unlock prerequisites are written to the isolated save before startup by [`tools/progress_fixture.py`](https://github.com/BMingSY/isaac-lan/blob/main/tools/progress_fixture.py). It validates the J460 header, sections, and checksum algorithm, then atomically replaces the file through a temporary file. An original baseline must already exist. Do not modify the in-memory unlock table after the character menu has initialized.

## Native Anomalies and Heap Checks

Schedule anomaly capture for Boss, transition, and exit acceptance separately from performance stress tests. `--heap-check` uses the independent `isaac_lan_heap_watch.exe` to observe processes in marked directories with validated paths. The exception context is copied to the experiment's shared directory, then the original exception chain continues after the dump completes. Observe at most the first three exceptions, waiting up to 30 seconds for each; do not wait when no observer is available. Allow 45 seconds for normal shutdown. A forced termination after timeout must be treated as a failure.

Full dumps are first written to the Windows temporary directory and then copied into the artifact dump archive. If copying fails, retain the temporary file and report the error; do not include dumps in the installer. The observer does not modify IFEO or the registry and does not attach a debugger. Fail-fast or earlier startup errors are not guaranteed to be captured, so still inspect the process exit result. Windows CI verifies the dump pipeline with a synthetic process; it does not launch the game, and "no anomaly observed" does not prove that all heap corruption has been ruled out.
