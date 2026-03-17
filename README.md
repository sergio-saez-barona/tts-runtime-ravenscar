# TTS-Runtime-Ravenscar
Ravenscar implementation at the runtime level of a Time-Triggered scheduler.

## Version 0.4.1

This version extends the framework with support for **mixed-criticality systems
(MCS)**, while preserving its ability to combine **time-triggered and event-triggered
(ET)** execution.

The main contributions of this work are summarised below:

### Mixed-Criticality Task Model

- Tasks are extended to support **multiple execution-time estimates** per job, one for
  each criticality level.

- Jobs can be selectively **disabled at higher criticality levels** (e.g., by
  assigning zero execution time).

- The model preserves **multi-frame task semantics**, introducing the notion of *task
  cycle* and ensuring consistent behaviour across jobs.

### Criticality-Aware Time-Triggered Scheduling

- TT slots are extended to support **criticality-dependent execution times** through
  adaptive work durations.
- Work slots are divided into:
  - an **active part** (execution window),  
  - and an **empty part** (used for overrun handling and safe transitions).
- Execution overruns no longer trigger fatal errors. Instead:
  - **application-defined overrun handlers** can be registered,
  - enabling **custom reactions**, such as changing the system criticality level (SCL).
- The framework introduces both:
  - a **system criticality level (SCL)**, and  
  - a **task-local active criticality level**,  
  ensuring **semantic consistency of multi-frame tasks** during criticality changes.

### Controlled Criticality-Level Transitions

- The execution of a full task cycle is preserved under SCL changes:
  - ongoing tasks continue with a consistent criticality level,
  - external SCL changes are deferred until the end of the cycle,
  - internal events (e.g., overruns) may trigger immediate adaptation.
- Additional slot attributes allow identifying:
  - task ownership, and  
  - task cycle boundaries.

### Timed Mode-Change Extensions

- The original mode-change mechanism is extended to support **timed mode changes**.
- Mode changes can now:
  - be requested for a **specific point in time**,  
  - occur immediately if the request falls within a mode-change slot, or  
  - be deferred to the next valid slot otherwise.
- This enables:
  - **precise coordination of schedules**,  
  - **synchronisation across distributed systems**, and  
  - compensation for **clock drift**.

### Current Limitations and Future Work

- Mixed-criticality support is currently focused on the **TT domain**.
- Due to platform constraints (e.g., Ravenscar profile limitations), **execution
  overrun detection is not supported in the ET domain**.
- Future work includes extending:
  - **multi-frame semantics**, and  
  - **overrun management**  
  to event-triggered activities.


## Version v0.3.0.

This is the version cited from paper "A Hierarchical Architecture for Time- and Event-Triggered Real-Time Systems"
_J. Real, S. Sáez., A. Crespo_, in the 24th International Conference on Reliable Software Technologies - Ada-Europe 2019, in June 2019.

 - The `runtime` folder contains the latest version of the modified/added runtime source files. These files are covered by a different license that can be found in the file [runtime/LICENSE](runtime/LICENSE)

 - The `extensions` folder contains the latest version of the files proposed that extends the ada runtime. API documentation can be found in [API](doc/API.md).

 - The `utilities` folder contains the current implementation of a library of TT utilities and patterns.

 - The `examples` folder contains an example application for the STM34F4 Discovery board. To observe its output, you can for example use "debug on board" from GPS and see the printed messages in the st-util window.

Version v0.3.0: <a href="https://doi.org/10.5281/zenodo.3490505"><img src="https://zenodo.org/badge/DOI/10.5281/zenodo.3490505.svg" alt="DOI"></a>

## Version 0.2.0

Version v0.2.0: <a href="https://doi.org/10.5281/zenodo.1206197"><img src="https://zenodo.org/badge/DOI/10.5281/zenodo.1206197.svg" alt="DOI"></a>


