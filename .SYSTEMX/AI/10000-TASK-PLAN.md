# CSA-iEM SYSTEMX Full SU 10,000-Task Forward Execution Plan

> Generated from the native CSA-iEM 20-Phase Product Roadmap. The JSON manifest is the task-level source of truth.

## Exact allocation

| Layer | Count |
| --- | ---: |
| Phases | 20 |
| Groups per phase | 5 |
| Waves per group | 10 |
| Todo tasks per wave | 10 |
| Tasks per phase | 500 |
| Total tasks | 10000 |

Every task has `todo: true`, canonical status `planned`, a lane, an actor, a predecessor, an acceptance condition, and a next action.

## Forward loop

`planned → in_progress → needs_review → done → archived`; blocked work resumes only after its blocker and evidence are recorded. The loop never silently skips or resets a task.

Use:

```bash
node .SYSTEMX/scripts/validate-10000-task-plan.mjs
node .SYSTEMX/scripts/forward-todo.mjs init
node .SYSTEMX/scripts/forward-todo.mjs status
node .SYSTEMX/scripts/forward-todo.mjs next
```

## Phase and milestone index

| Phase | Milestone | Groups | Waves | Tasks |
| --- | --- | ---: | ---: | ---: |
| P01 — Unified Backend Contract | M01 — Phase 01 exit — Unified Backend Contract | 5 | 50 | 500 |
| P02 — Native Job Engine Everywhere | M02 — Phase 02 exit — Native Job Engine Everywhere | 5 | 50 | 500 |
| P03 — GUI Terminal Console Layer | M03 — Phase 03 exit — GUI Terminal Console Layer | 5 | 50 | 500 |
| P04 — Native Import Center | M04 — Phase 04 exit — Native Import Center | 5 | 50 | 500 |
| P05 — Project Library 2.0 | M05 — Phase 05 exit — Project Library 2.0 | 5 | 50 | 500 |
| P06 — Devcontainer Control Center | M06 — Phase 06 exit — Devcontainer Control Center | 5 | 50 | 500 |
| P07 — Runner Fleet Manager | M07 — Phase 07 exit — Runner Fleet Manager | 5 | 50 | 500 |
| P08 — Workflow Control Center | M08 — Phase 08 exit — Workflow Control Center | 5 | 50 | 500 |
| P09 — Workflow Runs Explorer | M09 — Phase 09 exit — Workflow Runs Explorer | 5 | 50 | 500 |
| P10 — Cleanup and Cost-Control Command Center | M10 — Phase 10 exit — Cleanup and Cost-Control Command Center | 5 | 50 | 500 |
| P11 — GitHub Account and Org Admin Hub | M11 — Phase 11 exit — GitHub Account and Org Admin Hub | 5 | 50 | 500 |
| P12 — Issues, Bugs, and Incident Hub | M12 — Phase 12 exit — Issues, Bugs, and Incident Hub | 5 | 50 | 500 |
| P13 — Deep Research Workspace | M13 — Phase 13 exit — Deep Research Workspace | 5 | 50 | 500 |
| P14 — Secrets, Variables, Policies, and Rules | M14 — Phase 14 exit — Secrets, Variables, Policies, and Rules | 5 | 50 | 500 |
| P15 — Local Files, Backups, Snapshots, and Restore | M15 — Phase 15 exit — Local Files, Backups, Snapshots, and Restore | 5 | 50 | 500 |
| P16 — Native Windows Desktop GUI | M16 — Phase 16 exit — Native Windows Desktop GUI | 5 | 50 | 500 |
| P17 — Packaging, Signing, Notarization, and Trusted Updates | M17 — Phase 17 exit — Packaging, Signing, Notarization, and Trusted Updates | 5 | 50 | 500 |
| P18 — Automated QA and Recovery Testing | M18 — Phase 18 exit — Automated QA and Recovery Testing | 5 | 50 | 500 |
| P19 — Collaboration, Templates, and Automation | M19 — Phase 19 exit — Collaboration, Templates, and Automation | 5 | 50 | 500 |
| P20 — Product Polish and Best-in-Class Pass | M20 — Phase 20 exit — Product Polish and Best-in-Class Pass | 5 | 50 | 500 |

## Group and wave todo index

### P01 — Unified Backend Contract

Milestone: **Phase 01 exit — Unified Backend Contract** — Every major operation has one stable conceptual input, output, status, log, report, and recovery shape across native clients and shell backends.

#### P01-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Unified Backend Contract.

- **P01-G01-W01 — Scope and objective** — 10 todo tasks, SU-00001 through SU-00010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P01-G01-W02 — Evidence inventory** — 10 todo tasks, SU-00011 through SU-00020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P01-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-00021 through SU-00030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P01-G01-W04 — Native design** — 10 todo tasks, SU-00031 through SU-00040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P01-G01-W05 — Scoped implementation** — 10 todo tasks, SU-00041 through SU-00050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P01-G01-W06 — Architecture integration** — 10 todo tasks, SU-00051 through SU-00060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P01-G01-W07 — Behavior verification** — 10 todo tasks, SU-00061 through SU-00070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P01-G01-W08 — Security and release hardening** — 10 todo tasks, SU-00071 through SU-00080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P01-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00081 through SU-00090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P01-G01-W10 — Wave exit gate** — 10 todo tasks, SU-00091 through SU-00100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P01-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Unified Backend Contract.

- **P01-G02-W01 — Scope and objective** — 10 todo tasks, SU-00101 through SU-00110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P01-G02-W02 — Evidence inventory** — 10 todo tasks, SU-00111 through SU-00120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P01-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-00121 through SU-00130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P01-G02-W04 — Native design** — 10 todo tasks, SU-00131 through SU-00140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P01-G02-W05 — Scoped implementation** — 10 todo tasks, SU-00141 through SU-00150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P01-G02-W06 — Architecture integration** — 10 todo tasks, SU-00151 through SU-00160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P01-G02-W07 — Behavior verification** — 10 todo tasks, SU-00161 through SU-00170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P01-G02-W08 — Security and release hardening** — 10 todo tasks, SU-00171 through SU-00180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P01-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00181 through SU-00190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P01-G02-W10 — Wave exit gate** — 10 todo tasks, SU-00191 through SU-00200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P01-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Unified Backend Contract.

- **P01-G03-W01 — Scope and objective** — 10 todo tasks, SU-00201 through SU-00210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P01-G03-W02 — Evidence inventory** — 10 todo tasks, SU-00211 through SU-00220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P01-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-00221 through SU-00230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P01-G03-W04 — Native design** — 10 todo tasks, SU-00231 through SU-00240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P01-G03-W05 — Scoped implementation** — 10 todo tasks, SU-00241 through SU-00250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P01-G03-W06 — Architecture integration** — 10 todo tasks, SU-00251 through SU-00260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P01-G03-W07 — Behavior verification** — 10 todo tasks, SU-00261 through SU-00270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P01-G03-W08 — Security and release hardening** — 10 todo tasks, SU-00271 through SU-00280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P01-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00281 through SU-00290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P01-G03-W10 — Wave exit gate** — 10 todo tasks, SU-00291 through SU-00300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P01-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Unified Backend Contract.

- **P01-G04-W01 — Scope and objective** — 10 todo tasks, SU-00301 through SU-00310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P01-G04-W02 — Evidence inventory** — 10 todo tasks, SU-00311 through SU-00320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P01-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-00321 through SU-00330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P01-G04-W04 — Native design** — 10 todo tasks, SU-00331 through SU-00340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P01-G04-W05 — Scoped implementation** — 10 todo tasks, SU-00341 through SU-00350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P01-G04-W06 — Architecture integration** — 10 todo tasks, SU-00351 through SU-00360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P01-G04-W07 — Behavior verification** — 10 todo tasks, SU-00361 through SU-00370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P01-G04-W08 — Security and release hardening** — 10 todo tasks, SU-00371 through SU-00380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P01-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00381 through SU-00390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P01-G04-W10 — Wave exit gate** — 10 todo tasks, SU-00391 through SU-00400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P01-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Unified Backend Contract.

- **P01-G05-W01 — Scope and objective** — 10 todo tasks, SU-00401 through SU-00410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P01-G05-W02 — Evidence inventory** — 10 todo tasks, SU-00411 through SU-00420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P01-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-00421 through SU-00430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P01-G05-W04 — Native design** — 10 todo tasks, SU-00431 through SU-00440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P01-G05-W05 — Scoped implementation** — 10 todo tasks, SU-00441 through SU-00450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P01-G05-W06 — Architecture integration** — 10 todo tasks, SU-00451 through SU-00460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P01-G05-W07 — Behavior verification** — 10 todo tasks, SU-00461 through SU-00470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P01-G05-W08 — Security and release hardening** — 10 todo tasks, SU-00471 through SU-00480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P01-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00481 through SU-00490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P01-G05-W10 — Wave exit gate** — 10 todo tasks, SU-00491 through SU-00500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P02 — Native Job Engine Everywhere

Milestone: **Phase 02 exit — Native Job Engine Everywhere** — Long-running import, cleanup, patch, backup, runner, and devcontainer work is visible through one jobs model.

#### P02-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Native Job Engine Everywhere.

- **P02-G01-W01 — Scope and objective** — 10 todo tasks, SU-00501 through SU-00510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P02-G01-W02 — Evidence inventory** — 10 todo tasks, SU-00511 through SU-00520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P02-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-00521 through SU-00530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P02-G01-W04 — Native design** — 10 todo tasks, SU-00531 through SU-00540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P02-G01-W05 — Scoped implementation** — 10 todo tasks, SU-00541 through SU-00550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P02-G01-W06 — Architecture integration** — 10 todo tasks, SU-00551 through SU-00560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P02-G01-W07 — Behavior verification** — 10 todo tasks, SU-00561 through SU-00570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P02-G01-W08 — Security and release hardening** — 10 todo tasks, SU-00571 through SU-00580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P02-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00581 through SU-00590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P02-G01-W10 — Wave exit gate** — 10 todo tasks, SU-00591 through SU-00600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P02-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Native Job Engine Everywhere.

- **P02-G02-W01 — Scope and objective** — 10 todo tasks, SU-00601 through SU-00610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P02-G02-W02 — Evidence inventory** — 10 todo tasks, SU-00611 through SU-00620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P02-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-00621 through SU-00630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P02-G02-W04 — Native design** — 10 todo tasks, SU-00631 through SU-00640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P02-G02-W05 — Scoped implementation** — 10 todo tasks, SU-00641 through SU-00650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P02-G02-W06 — Architecture integration** — 10 todo tasks, SU-00651 through SU-00660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P02-G02-W07 — Behavior verification** — 10 todo tasks, SU-00661 through SU-00670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P02-G02-W08 — Security and release hardening** — 10 todo tasks, SU-00671 through SU-00680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P02-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00681 through SU-00690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P02-G02-W10 — Wave exit gate** — 10 todo tasks, SU-00691 through SU-00700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P02-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Native Job Engine Everywhere.

- **P02-G03-W01 — Scope and objective** — 10 todo tasks, SU-00701 through SU-00710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P02-G03-W02 — Evidence inventory** — 10 todo tasks, SU-00711 through SU-00720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P02-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-00721 through SU-00730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P02-G03-W04 — Native design** — 10 todo tasks, SU-00731 through SU-00740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P02-G03-W05 — Scoped implementation** — 10 todo tasks, SU-00741 through SU-00750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P02-G03-W06 — Architecture integration** — 10 todo tasks, SU-00751 through SU-00760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P02-G03-W07 — Behavior verification** — 10 todo tasks, SU-00761 through SU-00770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P02-G03-W08 — Security and release hardening** — 10 todo tasks, SU-00771 through SU-00780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P02-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00781 through SU-00790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P02-G03-W10 — Wave exit gate** — 10 todo tasks, SU-00791 through SU-00800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P02-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Native Job Engine Everywhere.

- **P02-G04-W01 — Scope and objective** — 10 todo tasks, SU-00801 through SU-00810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P02-G04-W02 — Evidence inventory** — 10 todo tasks, SU-00811 through SU-00820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P02-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-00821 through SU-00830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P02-G04-W04 — Native design** — 10 todo tasks, SU-00831 through SU-00840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P02-G04-W05 — Scoped implementation** — 10 todo tasks, SU-00841 through SU-00850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P02-G04-W06 — Architecture integration** — 10 todo tasks, SU-00851 through SU-00860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P02-G04-W07 — Behavior verification** — 10 todo tasks, SU-00861 through SU-00870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P02-G04-W08 — Security and release hardening** — 10 todo tasks, SU-00871 through SU-00880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P02-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00881 through SU-00890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P02-G04-W10 — Wave exit gate** — 10 todo tasks, SU-00891 through SU-00900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P02-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Native Job Engine Everywhere.

- **P02-G05-W01 — Scope and objective** — 10 todo tasks, SU-00901 through SU-00910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P02-G05-W02 — Evidence inventory** — 10 todo tasks, SU-00911 through SU-00920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P02-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-00921 through SU-00930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P02-G05-W04 — Native design** — 10 todo tasks, SU-00931 through SU-00940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P02-G05-W05 — Scoped implementation** — 10 todo tasks, SU-00941 through SU-00950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P02-G05-W06 — Architecture integration** — 10 todo tasks, SU-00951 through SU-00960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P02-G05-W07 — Behavior verification** — 10 todo tasks, SU-00961 through SU-00970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P02-G05-W08 — Security and release hardening** — 10 todo tasks, SU-00971 through SU-00980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P02-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-00981 through SU-00990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P02-G05-W10 — Wave exit gate** — 10 todo tasks, SU-00991 through SU-01000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P03 — GUI Terminal Console Layer

Milestone: **Phase 03 exit — GUI Terminal Console Layer** — Advanced shell output remains available in the app while terminal fallback becomes optional diagnostics.

#### P03-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: GUI Terminal Console Layer.

- **P03-G01-W01 — Scope and objective** — 10 todo tasks, SU-01001 through SU-01010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P03-G01-W02 — Evidence inventory** — 10 todo tasks, SU-01011 through SU-01020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P03-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-01021 through SU-01030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P03-G01-W04 — Native design** — 10 todo tasks, SU-01031 through SU-01040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P03-G01-W05 — Scoped implementation** — 10 todo tasks, SU-01041 through SU-01050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P03-G01-W06 — Architecture integration** — 10 todo tasks, SU-01051 through SU-01060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P03-G01-W07 — Behavior verification** — 10 todo tasks, SU-01061 through SU-01070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P03-G01-W08 — Security and release hardening** — 10 todo tasks, SU-01071 through SU-01080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P03-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01081 through SU-01090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P03-G01-W10 — Wave exit gate** — 10 todo tasks, SU-01091 through SU-01100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P03-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: GUI Terminal Console Layer.

- **P03-G02-W01 — Scope and objective** — 10 todo tasks, SU-01101 through SU-01110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P03-G02-W02 — Evidence inventory** — 10 todo tasks, SU-01111 through SU-01120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P03-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-01121 through SU-01130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P03-G02-W04 — Native design** — 10 todo tasks, SU-01131 through SU-01140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P03-G02-W05 — Scoped implementation** — 10 todo tasks, SU-01141 through SU-01150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P03-G02-W06 — Architecture integration** — 10 todo tasks, SU-01151 through SU-01160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P03-G02-W07 — Behavior verification** — 10 todo tasks, SU-01161 through SU-01170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P03-G02-W08 — Security and release hardening** — 10 todo tasks, SU-01171 through SU-01180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P03-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01181 through SU-01190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P03-G02-W10 — Wave exit gate** — 10 todo tasks, SU-01191 through SU-01200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P03-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: GUI Terminal Console Layer.

- **P03-G03-W01 — Scope and objective** — 10 todo tasks, SU-01201 through SU-01210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P03-G03-W02 — Evidence inventory** — 10 todo tasks, SU-01211 through SU-01220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P03-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-01221 through SU-01230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P03-G03-W04 — Native design** — 10 todo tasks, SU-01231 through SU-01240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P03-G03-W05 — Scoped implementation** — 10 todo tasks, SU-01241 through SU-01250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P03-G03-W06 — Architecture integration** — 10 todo tasks, SU-01251 through SU-01260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P03-G03-W07 — Behavior verification** — 10 todo tasks, SU-01261 through SU-01270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P03-G03-W08 — Security and release hardening** — 10 todo tasks, SU-01271 through SU-01280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P03-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01281 through SU-01290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P03-G03-W10 — Wave exit gate** — 10 todo tasks, SU-01291 through SU-01300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P03-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: GUI Terminal Console Layer.

- **P03-G04-W01 — Scope and objective** — 10 todo tasks, SU-01301 through SU-01310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P03-G04-W02 — Evidence inventory** — 10 todo tasks, SU-01311 through SU-01320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P03-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-01321 through SU-01330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P03-G04-W04 — Native design** — 10 todo tasks, SU-01331 through SU-01340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P03-G04-W05 — Scoped implementation** — 10 todo tasks, SU-01341 through SU-01350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P03-G04-W06 — Architecture integration** — 10 todo tasks, SU-01351 through SU-01360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P03-G04-W07 — Behavior verification** — 10 todo tasks, SU-01361 through SU-01370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P03-G04-W08 — Security and release hardening** — 10 todo tasks, SU-01371 through SU-01380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P03-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01381 through SU-01390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P03-G04-W10 — Wave exit gate** — 10 todo tasks, SU-01391 through SU-01400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P03-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: GUI Terminal Console Layer.

- **P03-G05-W01 — Scope and objective** — 10 todo tasks, SU-01401 through SU-01410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P03-G05-W02 — Evidence inventory** — 10 todo tasks, SU-01411 through SU-01420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P03-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-01421 through SU-01430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P03-G05-W04 — Native design** — 10 todo tasks, SU-01431 through SU-01440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P03-G05-W05 — Scoped implementation** — 10 todo tasks, SU-01441 through SU-01450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P03-G05-W06 — Architecture integration** — 10 todo tasks, SU-01451 through SU-01460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P03-G05-W07 — Behavior verification** — 10 todo tasks, SU-01461 through SU-01470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P03-G05-W08 — Security and release hardening** — 10 todo tasks, SU-01471 through SU-01480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P03-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01481 through SU-01490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P03-G05-W10 — Wave exit gate** — 10 todo tasks, SU-01491 through SU-01500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P04 — Native Import Center

Milestone: **Phase 04 exit — Native Import Center** — Normal repo migration and local setup can be completed from the native import workflow with resumable evidence.

#### P04-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Native Import Center.

- **P04-G01-W01 — Scope and objective** — 10 todo tasks, SU-01501 through SU-01510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P04-G01-W02 — Evidence inventory** — 10 todo tasks, SU-01511 through SU-01520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P04-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-01521 through SU-01530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P04-G01-W04 — Native design** — 10 todo tasks, SU-01531 through SU-01540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P04-G01-W05 — Scoped implementation** — 10 todo tasks, SU-01541 through SU-01550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P04-G01-W06 — Architecture integration** — 10 todo tasks, SU-01551 through SU-01560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P04-G01-W07 — Behavior verification** — 10 todo tasks, SU-01561 through SU-01570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P04-G01-W08 — Security and release hardening** — 10 todo tasks, SU-01571 through SU-01580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P04-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01581 through SU-01590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P04-G01-W10 — Wave exit gate** — 10 todo tasks, SU-01591 through SU-01600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P04-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Native Import Center.

- **P04-G02-W01 — Scope and objective** — 10 todo tasks, SU-01601 through SU-01610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P04-G02-W02 — Evidence inventory** — 10 todo tasks, SU-01611 through SU-01620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P04-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-01621 through SU-01630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P04-G02-W04 — Native design** — 10 todo tasks, SU-01631 through SU-01640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P04-G02-W05 — Scoped implementation** — 10 todo tasks, SU-01641 through SU-01650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P04-G02-W06 — Architecture integration** — 10 todo tasks, SU-01651 through SU-01660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P04-G02-W07 — Behavior verification** — 10 todo tasks, SU-01661 through SU-01670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P04-G02-W08 — Security and release hardening** — 10 todo tasks, SU-01671 through SU-01680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P04-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01681 through SU-01690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P04-G02-W10 — Wave exit gate** — 10 todo tasks, SU-01691 through SU-01700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P04-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Native Import Center.

- **P04-G03-W01 — Scope and objective** — 10 todo tasks, SU-01701 through SU-01710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P04-G03-W02 — Evidence inventory** — 10 todo tasks, SU-01711 through SU-01720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P04-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-01721 through SU-01730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P04-G03-W04 — Native design** — 10 todo tasks, SU-01731 through SU-01740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P04-G03-W05 — Scoped implementation** — 10 todo tasks, SU-01741 through SU-01750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P04-G03-W06 — Architecture integration** — 10 todo tasks, SU-01751 through SU-01760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P04-G03-W07 — Behavior verification** — 10 todo tasks, SU-01761 through SU-01770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P04-G03-W08 — Security and release hardening** — 10 todo tasks, SU-01771 through SU-01780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P04-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01781 through SU-01790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P04-G03-W10 — Wave exit gate** — 10 todo tasks, SU-01791 through SU-01800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P04-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Native Import Center.

- **P04-G04-W01 — Scope and objective** — 10 todo tasks, SU-01801 through SU-01810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P04-G04-W02 — Evidence inventory** — 10 todo tasks, SU-01811 through SU-01820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P04-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-01821 through SU-01830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P04-G04-W04 — Native design** — 10 todo tasks, SU-01831 through SU-01840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P04-G04-W05 — Scoped implementation** — 10 todo tasks, SU-01841 through SU-01850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P04-G04-W06 — Architecture integration** — 10 todo tasks, SU-01851 through SU-01860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P04-G04-W07 — Behavior verification** — 10 todo tasks, SU-01861 through SU-01870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P04-G04-W08 — Security and release hardening** — 10 todo tasks, SU-01871 through SU-01880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P04-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01881 through SU-01890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P04-G04-W10 — Wave exit gate** — 10 todo tasks, SU-01891 through SU-01900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P04-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Native Import Center.

- **P04-G05-W01 — Scope and objective** — 10 todo tasks, SU-01901 through SU-01910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P04-G05-W02 — Evidence inventory** — 10 todo tasks, SU-01911 through SU-01920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P04-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-01921 through SU-01930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P04-G05-W04 — Native design** — 10 todo tasks, SU-01931 through SU-01940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P04-G05-W05 — Scoped implementation** — 10 todo tasks, SU-01941 through SU-01950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P04-G05-W06 — Architecture integration** — 10 todo tasks, SU-01951 through SU-01960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P04-G05-W07 — Behavior verification** — 10 todo tasks, SU-01961 through SU-01970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P04-G05-W08 — Security and release hardening** — 10 todo tasks, SU-01971 through SU-01980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P04-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-01981 through SU-01990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P04-G05-W10 — Wave exit gate** — 10 todo tasks, SU-01991 through SU-02000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P05 — Project Library 2.0

Milestone: **Phase 05 exit — Project Library 2.0** — The project library becomes the primary operating surface for grouped views, search, filters, favorites, and health.

#### P05-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Project Library 2.0.

- **P05-G01-W01 — Scope and objective** — 10 todo tasks, SU-02001 through SU-02010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P05-G01-W02 — Evidence inventory** — 10 todo tasks, SU-02011 through SU-02020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P05-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-02021 through SU-02030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P05-G01-W04 — Native design** — 10 todo tasks, SU-02031 through SU-02040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P05-G01-W05 — Scoped implementation** — 10 todo tasks, SU-02041 through SU-02050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P05-G01-W06 — Architecture integration** — 10 todo tasks, SU-02051 through SU-02060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P05-G01-W07 — Behavior verification** — 10 todo tasks, SU-02061 through SU-02070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P05-G01-W08 — Security and release hardening** — 10 todo tasks, SU-02071 through SU-02080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P05-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02081 through SU-02090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P05-G01-W10 — Wave exit gate** — 10 todo tasks, SU-02091 through SU-02100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P05-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Project Library 2.0.

- **P05-G02-W01 — Scope and objective** — 10 todo tasks, SU-02101 through SU-02110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P05-G02-W02 — Evidence inventory** — 10 todo tasks, SU-02111 through SU-02120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P05-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-02121 through SU-02130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P05-G02-W04 — Native design** — 10 todo tasks, SU-02131 through SU-02140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P05-G02-W05 — Scoped implementation** — 10 todo tasks, SU-02141 through SU-02150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P05-G02-W06 — Architecture integration** — 10 todo tasks, SU-02151 through SU-02160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P05-G02-W07 — Behavior verification** — 10 todo tasks, SU-02161 through SU-02170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P05-G02-W08 — Security and release hardening** — 10 todo tasks, SU-02171 through SU-02180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P05-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02181 through SU-02190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P05-G02-W10 — Wave exit gate** — 10 todo tasks, SU-02191 through SU-02200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P05-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Project Library 2.0.

- **P05-G03-W01 — Scope and objective** — 10 todo tasks, SU-02201 through SU-02210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P05-G03-W02 — Evidence inventory** — 10 todo tasks, SU-02211 through SU-02220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P05-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-02221 through SU-02230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P05-G03-W04 — Native design** — 10 todo tasks, SU-02231 through SU-02240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P05-G03-W05 — Scoped implementation** — 10 todo tasks, SU-02241 through SU-02250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P05-G03-W06 — Architecture integration** — 10 todo tasks, SU-02251 through SU-02260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P05-G03-W07 — Behavior verification** — 10 todo tasks, SU-02261 through SU-02270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P05-G03-W08 — Security and release hardening** — 10 todo tasks, SU-02271 through SU-02280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P05-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02281 through SU-02290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P05-G03-W10 — Wave exit gate** — 10 todo tasks, SU-02291 through SU-02300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P05-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Project Library 2.0.

- **P05-G04-W01 — Scope and objective** — 10 todo tasks, SU-02301 through SU-02310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P05-G04-W02 — Evidence inventory** — 10 todo tasks, SU-02311 through SU-02320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P05-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-02321 through SU-02330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P05-G04-W04 — Native design** — 10 todo tasks, SU-02331 through SU-02340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P05-G04-W05 — Scoped implementation** — 10 todo tasks, SU-02341 through SU-02350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P05-G04-W06 — Architecture integration** — 10 todo tasks, SU-02351 through SU-02360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P05-G04-W07 — Behavior verification** — 10 todo tasks, SU-02361 through SU-02370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P05-G04-W08 — Security and release hardening** — 10 todo tasks, SU-02371 through SU-02380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P05-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02381 through SU-02390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P05-G04-W10 — Wave exit gate** — 10 todo tasks, SU-02391 through SU-02400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P05-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Project Library 2.0.

- **P05-G05-W01 — Scope and objective** — 10 todo tasks, SU-02401 through SU-02410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P05-G05-W02 — Evidence inventory** — 10 todo tasks, SU-02411 through SU-02420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P05-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-02421 through SU-02430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P05-G05-W04 — Native design** — 10 todo tasks, SU-02431 through SU-02440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P05-G05-W05 — Scoped implementation** — 10 todo tasks, SU-02441 through SU-02450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P05-G05-W06 — Architecture integration** — 10 todo tasks, SU-02451 through SU-02460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P05-G05-W07 — Behavior verification** — 10 todo tasks, SU-02461 through SU-02470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P05-G05-W08 — Security and release hardening** — 10 todo tasks, SU-02471 through SU-02480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P05-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02481 through SU-02490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P05-G05-W10 — Wave exit gate** — 10 todo tasks, SU-02491 through SU-02500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P06 — Devcontainer Control Center

Milestone: **Phase 06 exit — Devcontainer Control Center** — Devcontainer lifecycle, health, mapping, configuration, and warnings are controllable in-app.

#### P06-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Devcontainer Control Center.

- **P06-G01-W01 — Scope and objective** — 10 todo tasks, SU-02501 through SU-02510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P06-G01-W02 — Evidence inventory** — 10 todo tasks, SU-02511 through SU-02520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P06-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-02521 through SU-02530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P06-G01-W04 — Native design** — 10 todo tasks, SU-02531 through SU-02540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P06-G01-W05 — Scoped implementation** — 10 todo tasks, SU-02541 through SU-02550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P06-G01-W06 — Architecture integration** — 10 todo tasks, SU-02551 through SU-02560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P06-G01-W07 — Behavior verification** — 10 todo tasks, SU-02561 through SU-02570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P06-G01-W08 — Security and release hardening** — 10 todo tasks, SU-02571 through SU-02580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P06-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02581 through SU-02590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P06-G01-W10 — Wave exit gate** — 10 todo tasks, SU-02591 through SU-02600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P06-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Devcontainer Control Center.

- **P06-G02-W01 — Scope and objective** — 10 todo tasks, SU-02601 through SU-02610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P06-G02-W02 — Evidence inventory** — 10 todo tasks, SU-02611 through SU-02620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P06-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-02621 through SU-02630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P06-G02-W04 — Native design** — 10 todo tasks, SU-02631 through SU-02640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P06-G02-W05 — Scoped implementation** — 10 todo tasks, SU-02641 through SU-02650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P06-G02-W06 — Architecture integration** — 10 todo tasks, SU-02651 through SU-02660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P06-G02-W07 — Behavior verification** — 10 todo tasks, SU-02661 through SU-02670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P06-G02-W08 — Security and release hardening** — 10 todo tasks, SU-02671 through SU-02680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P06-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02681 through SU-02690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P06-G02-W10 — Wave exit gate** — 10 todo tasks, SU-02691 through SU-02700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P06-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Devcontainer Control Center.

- **P06-G03-W01 — Scope and objective** — 10 todo tasks, SU-02701 through SU-02710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P06-G03-W02 — Evidence inventory** — 10 todo tasks, SU-02711 through SU-02720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P06-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-02721 through SU-02730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P06-G03-W04 — Native design** — 10 todo tasks, SU-02731 through SU-02740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P06-G03-W05 — Scoped implementation** — 10 todo tasks, SU-02741 through SU-02750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P06-G03-W06 — Architecture integration** — 10 todo tasks, SU-02751 through SU-02760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P06-G03-W07 — Behavior verification** — 10 todo tasks, SU-02761 through SU-02770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P06-G03-W08 — Security and release hardening** — 10 todo tasks, SU-02771 through SU-02780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P06-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02781 through SU-02790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P06-G03-W10 — Wave exit gate** — 10 todo tasks, SU-02791 through SU-02800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P06-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Devcontainer Control Center.

- **P06-G04-W01 — Scope and objective** — 10 todo tasks, SU-02801 through SU-02810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P06-G04-W02 — Evidence inventory** — 10 todo tasks, SU-02811 through SU-02820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P06-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-02821 through SU-02830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P06-G04-W04 — Native design** — 10 todo tasks, SU-02831 through SU-02840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P06-G04-W05 — Scoped implementation** — 10 todo tasks, SU-02841 through SU-02850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P06-G04-W06 — Architecture integration** — 10 todo tasks, SU-02851 through SU-02860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P06-G04-W07 — Behavior verification** — 10 todo tasks, SU-02861 through SU-02870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P06-G04-W08 — Security and release hardening** — 10 todo tasks, SU-02871 through SU-02880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P06-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02881 through SU-02890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P06-G04-W10 — Wave exit gate** — 10 todo tasks, SU-02891 through SU-02900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P06-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Devcontainer Control Center.

- **P06-G05-W01 — Scope and objective** — 10 todo tasks, SU-02901 through SU-02910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P06-G05-W02 — Evidence inventory** — 10 todo tasks, SU-02911 through SU-02920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P06-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-02921 through SU-02930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P06-G05-W04 — Native design** — 10 todo tasks, SU-02931 through SU-02940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P06-G05-W05 — Scoped implementation** — 10 todo tasks, SU-02941 through SU-02950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P06-G05-W06 — Architecture integration** — 10 todo tasks, SU-02951 through SU-02960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P06-G05-W07 — Behavior verification** — 10 todo tasks, SU-02961 through SU-02970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P06-G05-W08 — Security and release hardening** — 10 todo tasks, SU-02971 through SU-02980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P06-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-02981 through SU-02990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P06-G05-W10 — Wave exit gate** — 10 todo tasks, SU-02991 through SU-03000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P07 — Runner Fleet Manager

Milestone: **Phase 07 exit — Runner Fleet Manager** — Self-hosted runner installation, repair, labels, services, health, activity, and paths are managed visibly.

#### P07-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Runner Fleet Manager.

- **P07-G01-W01 — Scope and objective** — 10 todo tasks, SU-03001 through SU-03010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P07-G01-W02 — Evidence inventory** — 10 todo tasks, SU-03011 through SU-03020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P07-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-03021 through SU-03030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P07-G01-W04 — Native design** — 10 todo tasks, SU-03031 through SU-03040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P07-G01-W05 — Scoped implementation** — 10 todo tasks, SU-03041 through SU-03050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P07-G01-W06 — Architecture integration** — 10 todo tasks, SU-03051 through SU-03060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P07-G01-W07 — Behavior verification** — 10 todo tasks, SU-03061 through SU-03070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P07-G01-W08 — Security and release hardening** — 10 todo tasks, SU-03071 through SU-03080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P07-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03081 through SU-03090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P07-G01-W10 — Wave exit gate** — 10 todo tasks, SU-03091 through SU-03100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P07-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Runner Fleet Manager.

- **P07-G02-W01 — Scope and objective** — 10 todo tasks, SU-03101 through SU-03110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P07-G02-W02 — Evidence inventory** — 10 todo tasks, SU-03111 through SU-03120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P07-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-03121 through SU-03130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P07-G02-W04 — Native design** — 10 todo tasks, SU-03131 through SU-03140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P07-G02-W05 — Scoped implementation** — 10 todo tasks, SU-03141 through SU-03150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P07-G02-W06 — Architecture integration** — 10 todo tasks, SU-03151 through SU-03160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P07-G02-W07 — Behavior verification** — 10 todo tasks, SU-03161 through SU-03170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P07-G02-W08 — Security and release hardening** — 10 todo tasks, SU-03171 through SU-03180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P07-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03181 through SU-03190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P07-G02-W10 — Wave exit gate** — 10 todo tasks, SU-03191 through SU-03200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P07-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Runner Fleet Manager.

- **P07-G03-W01 — Scope and objective** — 10 todo tasks, SU-03201 through SU-03210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P07-G03-W02 — Evidence inventory** — 10 todo tasks, SU-03211 through SU-03220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P07-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-03221 through SU-03230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P07-G03-W04 — Native design** — 10 todo tasks, SU-03231 through SU-03240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P07-G03-W05 — Scoped implementation** — 10 todo tasks, SU-03241 through SU-03250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P07-G03-W06 — Architecture integration** — 10 todo tasks, SU-03251 through SU-03260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P07-G03-W07 — Behavior verification** — 10 todo tasks, SU-03261 through SU-03270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P07-G03-W08 — Security and release hardening** — 10 todo tasks, SU-03271 through SU-03280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P07-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03281 through SU-03290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P07-G03-W10 — Wave exit gate** — 10 todo tasks, SU-03291 through SU-03300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P07-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Runner Fleet Manager.

- **P07-G04-W01 — Scope and objective** — 10 todo tasks, SU-03301 through SU-03310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P07-G04-W02 — Evidence inventory** — 10 todo tasks, SU-03311 through SU-03320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P07-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-03321 through SU-03330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P07-G04-W04 — Native design** — 10 todo tasks, SU-03331 through SU-03340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P07-G04-W05 — Scoped implementation** — 10 todo tasks, SU-03341 through SU-03350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P07-G04-W06 — Architecture integration** — 10 todo tasks, SU-03351 through SU-03360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P07-G04-W07 — Behavior verification** — 10 todo tasks, SU-03361 through SU-03370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P07-G04-W08 — Security and release hardening** — 10 todo tasks, SU-03371 through SU-03380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P07-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03381 through SU-03390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P07-G04-W10 — Wave exit gate** — 10 todo tasks, SU-03391 through SU-03400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P07-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Runner Fleet Manager.

- **P07-G05-W01 — Scope and objective** — 10 todo tasks, SU-03401 through SU-03410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P07-G05-W02 — Evidence inventory** — 10 todo tasks, SU-03411 through SU-03420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P07-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-03421 through SU-03430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P07-G05-W04 — Native design** — 10 todo tasks, SU-03431 through SU-03440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P07-G05-W05 — Scoped implementation** — 10 todo tasks, SU-03441 through SU-03450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P07-G05-W06 — Architecture integration** — 10 todo tasks, SU-03451 through SU-03460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P07-G05-W07 — Behavior verification** — 10 todo tasks, SU-03461 through SU-03470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P07-G05-W08 — Security and release hardening** — 10 todo tasks, SU-03471 through SU-03480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P07-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03481 through SU-03490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P07-G05-W10 — Wave exit gate** — 10 todo tasks, SU-03491 through SU-03500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P08 — Workflow Control Center

Milestone: **Phase 08 exit — Workflow Control Center** — Workflow inventory, enable/disable, dispatch, patch preview, YAML, and runner-target analysis are native flows.

#### P08-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Workflow Control Center.

- **P08-G01-W01 — Scope and objective** — 10 todo tasks, SU-03501 through SU-03510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P08-G01-W02 — Evidence inventory** — 10 todo tasks, SU-03511 through SU-03520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P08-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-03521 through SU-03530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P08-G01-W04 — Native design** — 10 todo tasks, SU-03531 through SU-03540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P08-G01-W05 — Scoped implementation** — 10 todo tasks, SU-03541 through SU-03550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P08-G01-W06 — Architecture integration** — 10 todo tasks, SU-03551 through SU-03560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P08-G01-W07 — Behavior verification** — 10 todo tasks, SU-03561 through SU-03570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P08-G01-W08 — Security and release hardening** — 10 todo tasks, SU-03571 through SU-03580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P08-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03581 through SU-03590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P08-G01-W10 — Wave exit gate** — 10 todo tasks, SU-03591 through SU-03600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P08-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Workflow Control Center.

- **P08-G02-W01 — Scope and objective** — 10 todo tasks, SU-03601 through SU-03610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P08-G02-W02 — Evidence inventory** — 10 todo tasks, SU-03611 through SU-03620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P08-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-03621 through SU-03630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P08-G02-W04 — Native design** — 10 todo tasks, SU-03631 through SU-03640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P08-G02-W05 — Scoped implementation** — 10 todo tasks, SU-03641 through SU-03650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P08-G02-W06 — Architecture integration** — 10 todo tasks, SU-03651 through SU-03660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P08-G02-W07 — Behavior verification** — 10 todo tasks, SU-03661 through SU-03670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P08-G02-W08 — Security and release hardening** — 10 todo tasks, SU-03671 through SU-03680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P08-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03681 through SU-03690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P08-G02-W10 — Wave exit gate** — 10 todo tasks, SU-03691 through SU-03700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P08-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Workflow Control Center.

- **P08-G03-W01 — Scope and objective** — 10 todo tasks, SU-03701 through SU-03710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P08-G03-W02 — Evidence inventory** — 10 todo tasks, SU-03711 through SU-03720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P08-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-03721 through SU-03730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P08-G03-W04 — Native design** — 10 todo tasks, SU-03731 through SU-03740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P08-G03-W05 — Scoped implementation** — 10 todo tasks, SU-03741 through SU-03750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P08-G03-W06 — Architecture integration** — 10 todo tasks, SU-03751 through SU-03760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P08-G03-W07 — Behavior verification** — 10 todo tasks, SU-03761 through SU-03770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P08-G03-W08 — Security and release hardening** — 10 todo tasks, SU-03771 through SU-03780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P08-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03781 through SU-03790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P08-G03-W10 — Wave exit gate** — 10 todo tasks, SU-03791 through SU-03800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P08-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Workflow Control Center.

- **P08-G04-W01 — Scope and objective** — 10 todo tasks, SU-03801 through SU-03810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P08-G04-W02 — Evidence inventory** — 10 todo tasks, SU-03811 through SU-03820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P08-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-03821 through SU-03830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P08-G04-W04 — Native design** — 10 todo tasks, SU-03831 through SU-03840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P08-G04-W05 — Scoped implementation** — 10 todo tasks, SU-03841 through SU-03850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P08-G04-W06 — Architecture integration** — 10 todo tasks, SU-03851 through SU-03860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P08-G04-W07 — Behavior verification** — 10 todo tasks, SU-03861 through SU-03870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P08-G04-W08 — Security and release hardening** — 10 todo tasks, SU-03871 through SU-03880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P08-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03881 through SU-03890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P08-G04-W10 — Wave exit gate** — 10 todo tasks, SU-03891 through SU-03900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P08-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Workflow Control Center.

- **P08-G05-W01 — Scope and objective** — 10 todo tasks, SU-03901 through SU-03910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P08-G05-W02 — Evidence inventory** — 10 todo tasks, SU-03911 through SU-03920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P08-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-03921 through SU-03930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P08-G05-W04 — Native design** — 10 todo tasks, SU-03931 through SU-03940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P08-G05-W05 — Scoped implementation** — 10 todo tasks, SU-03941 through SU-03950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P08-G05-W06 — Architecture integration** — 10 todo tasks, SU-03951 through SU-03960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P08-G05-W07 — Behavior verification** — 10 todo tasks, SU-03961 through SU-03970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P08-G05-W08 — Security and release hardening** — 10 todo tasks, SU-03971 through SU-03980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P08-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-03981 through SU-03990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P08-G05-W10 — Wave exit gate** — 10 todo tasks, SU-03991 through SU-04000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P09 — Workflow Runs Explorer

Milestone: **Phase 09 exit — Workflow Runs Explorer** — The app explains what ran, what failed, the relevant logs and artifacts, and the safe next action.

#### P09-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Workflow Runs Explorer.

- **P09-G01-W01 — Scope and objective** — 10 todo tasks, SU-04001 through SU-04010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P09-G01-W02 — Evidence inventory** — 10 todo tasks, SU-04011 through SU-04020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P09-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-04021 through SU-04030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P09-G01-W04 — Native design** — 10 todo tasks, SU-04031 through SU-04040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P09-G01-W05 — Scoped implementation** — 10 todo tasks, SU-04041 through SU-04050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P09-G01-W06 — Architecture integration** — 10 todo tasks, SU-04051 through SU-04060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P09-G01-W07 — Behavior verification** — 10 todo tasks, SU-04061 through SU-04070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P09-G01-W08 — Security and release hardening** — 10 todo tasks, SU-04071 through SU-04080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P09-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04081 through SU-04090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P09-G01-W10 — Wave exit gate** — 10 todo tasks, SU-04091 through SU-04100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P09-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Workflow Runs Explorer.

- **P09-G02-W01 — Scope and objective** — 10 todo tasks, SU-04101 through SU-04110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P09-G02-W02 — Evidence inventory** — 10 todo tasks, SU-04111 through SU-04120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P09-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-04121 through SU-04130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P09-G02-W04 — Native design** — 10 todo tasks, SU-04131 through SU-04140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P09-G02-W05 — Scoped implementation** — 10 todo tasks, SU-04141 through SU-04150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P09-G02-W06 — Architecture integration** — 10 todo tasks, SU-04151 through SU-04160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P09-G02-W07 — Behavior verification** — 10 todo tasks, SU-04161 through SU-04170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P09-G02-W08 — Security and release hardening** — 10 todo tasks, SU-04171 through SU-04180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P09-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04181 through SU-04190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P09-G02-W10 — Wave exit gate** — 10 todo tasks, SU-04191 through SU-04200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P09-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Workflow Runs Explorer.

- **P09-G03-W01 — Scope and objective** — 10 todo tasks, SU-04201 through SU-04210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P09-G03-W02 — Evidence inventory** — 10 todo tasks, SU-04211 through SU-04220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P09-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-04221 through SU-04230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P09-G03-W04 — Native design** — 10 todo tasks, SU-04231 through SU-04240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P09-G03-W05 — Scoped implementation** — 10 todo tasks, SU-04241 through SU-04250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P09-G03-W06 — Architecture integration** — 10 todo tasks, SU-04251 through SU-04260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P09-G03-W07 — Behavior verification** — 10 todo tasks, SU-04261 through SU-04270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P09-G03-W08 — Security and release hardening** — 10 todo tasks, SU-04271 through SU-04280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P09-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04281 through SU-04290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P09-G03-W10 — Wave exit gate** — 10 todo tasks, SU-04291 through SU-04300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P09-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Workflow Runs Explorer.

- **P09-G04-W01 — Scope and objective** — 10 todo tasks, SU-04301 through SU-04310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P09-G04-W02 — Evidence inventory** — 10 todo tasks, SU-04311 through SU-04320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P09-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-04321 through SU-04330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P09-G04-W04 — Native design** — 10 todo tasks, SU-04331 through SU-04340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P09-G04-W05 — Scoped implementation** — 10 todo tasks, SU-04341 through SU-04350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P09-G04-W06 — Architecture integration** — 10 todo tasks, SU-04351 through SU-04360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P09-G04-W07 — Behavior verification** — 10 todo tasks, SU-04361 through SU-04370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P09-G04-W08 — Security and release hardening** — 10 todo tasks, SU-04371 through SU-04380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P09-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04381 through SU-04390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P09-G04-W10 — Wave exit gate** — 10 todo tasks, SU-04391 through SU-04400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P09-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Workflow Runs Explorer.

- **P09-G05-W01 — Scope and objective** — 10 todo tasks, SU-04401 through SU-04410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P09-G05-W02 — Evidence inventory** — 10 todo tasks, SU-04411 through SU-04420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P09-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-04421 through SU-04430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P09-G05-W04 — Native design** — 10 todo tasks, SU-04431 through SU-04440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P09-G05-W05 — Scoped implementation** — 10 todo tasks, SU-04441 through SU-04450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P09-G05-W06 — Architecture integration** — 10 todo tasks, SU-04451 through SU-04460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P09-G05-W07 — Behavior verification** — 10 todo tasks, SU-04461 through SU-04470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P09-G05-W08 — Security and release hardening** — 10 todo tasks, SU-04471 through SU-04480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P09-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04481 through SU-04490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P09-G05-W10 — Wave exit gate** — 10 todo tasks, SU-04491 through SU-04500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P10 — Cleanup and Cost-Control Command Center

Milestone: **Phase 10 exit — Cleanup and Cost-Control Command Center** — Cost and cleanup decisions are preview-first, risk-scored, no-spend-aware, and receipt-bound.

#### P10-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Cleanup and Cost-Control Command Center.

- **P10-G01-W01 — Scope and objective** — 10 todo tasks, SU-04501 through SU-04510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P10-G01-W02 — Evidence inventory** — 10 todo tasks, SU-04511 through SU-04520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P10-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-04521 through SU-04530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P10-G01-W04 — Native design** — 10 todo tasks, SU-04531 through SU-04540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P10-G01-W05 — Scoped implementation** — 10 todo tasks, SU-04541 through SU-04550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P10-G01-W06 — Architecture integration** — 10 todo tasks, SU-04551 through SU-04560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P10-G01-W07 — Behavior verification** — 10 todo tasks, SU-04561 through SU-04570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P10-G01-W08 — Security and release hardening** — 10 todo tasks, SU-04571 through SU-04580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P10-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04581 through SU-04590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P10-G01-W10 — Wave exit gate** — 10 todo tasks, SU-04591 through SU-04600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P10-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Cleanup and Cost-Control Command Center.

- **P10-G02-W01 — Scope and objective** — 10 todo tasks, SU-04601 through SU-04610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P10-G02-W02 — Evidence inventory** — 10 todo tasks, SU-04611 through SU-04620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P10-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-04621 through SU-04630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P10-G02-W04 — Native design** — 10 todo tasks, SU-04631 through SU-04640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P10-G02-W05 — Scoped implementation** — 10 todo tasks, SU-04641 through SU-04650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P10-G02-W06 — Architecture integration** — 10 todo tasks, SU-04651 through SU-04660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P10-G02-W07 — Behavior verification** — 10 todo tasks, SU-04661 through SU-04670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P10-G02-W08 — Security and release hardening** — 10 todo tasks, SU-04671 through SU-04680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P10-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04681 through SU-04690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P10-G02-W10 — Wave exit gate** — 10 todo tasks, SU-04691 through SU-04700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P10-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Cleanup and Cost-Control Command Center.

- **P10-G03-W01 — Scope and objective** — 10 todo tasks, SU-04701 through SU-04710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P10-G03-W02 — Evidence inventory** — 10 todo tasks, SU-04711 through SU-04720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P10-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-04721 through SU-04730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P10-G03-W04 — Native design** — 10 todo tasks, SU-04731 through SU-04740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P10-G03-W05 — Scoped implementation** — 10 todo tasks, SU-04741 through SU-04750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P10-G03-W06 — Architecture integration** — 10 todo tasks, SU-04751 through SU-04760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P10-G03-W07 — Behavior verification** — 10 todo tasks, SU-04761 through SU-04770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P10-G03-W08 — Security and release hardening** — 10 todo tasks, SU-04771 through SU-04780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P10-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04781 through SU-04790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P10-G03-W10 — Wave exit gate** — 10 todo tasks, SU-04791 through SU-04800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P10-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Cleanup and Cost-Control Command Center.

- **P10-G04-W01 — Scope and objective** — 10 todo tasks, SU-04801 through SU-04810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P10-G04-W02 — Evidence inventory** — 10 todo tasks, SU-04811 through SU-04820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P10-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-04821 through SU-04830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P10-G04-W04 — Native design** — 10 todo tasks, SU-04831 through SU-04840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P10-G04-W05 — Scoped implementation** — 10 todo tasks, SU-04841 through SU-04850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P10-G04-W06 — Architecture integration** — 10 todo tasks, SU-04851 through SU-04860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P10-G04-W07 — Behavior verification** — 10 todo tasks, SU-04861 through SU-04870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P10-G04-W08 — Security and release hardening** — 10 todo tasks, SU-04871 through SU-04880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P10-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04881 through SU-04890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P10-G04-W10 — Wave exit gate** — 10 todo tasks, SU-04891 through SU-04900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P10-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Cleanup and Cost-Control Command Center.

- **P10-G05-W01 — Scope and objective** — 10 todo tasks, SU-04901 through SU-04910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P10-G05-W02 — Evidence inventory** — 10 todo tasks, SU-04911 through SU-04920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P10-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-04921 through SU-04930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P10-G05-W04 — Native design** — 10 todo tasks, SU-04931 through SU-04940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P10-G05-W05 — Scoped implementation** — 10 todo tasks, SU-04941 through SU-04950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P10-G05-W06 — Architecture integration** — 10 todo tasks, SU-04951 through SU-04960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P10-G05-W07 — Behavior verification** — 10 todo tasks, SU-04961 through SU-04970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P10-G05-W08 — Security and release hardening** — 10 todo tasks, SU-04971 through SU-04980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P10-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-04981 through SU-04990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P10-G05-W10 — Wave exit gate** — 10 todo tasks, SU-04991 through SU-05000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P11 — GitHub Account and Org Admin Hub

Milestone: **Phase 11 exit — GitHub Account and Org Admin Hub** — Multi-account and organization contexts, inventory, roles, scopes, and context switching are clear and safe.

#### P11-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: GitHub Account and Org Admin Hub.

- **P11-G01-W01 — Scope and objective** — 10 todo tasks, SU-05001 through SU-05010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P11-G01-W02 — Evidence inventory** — 10 todo tasks, SU-05011 through SU-05020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P11-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-05021 through SU-05030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P11-G01-W04 — Native design** — 10 todo tasks, SU-05031 through SU-05040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P11-G01-W05 — Scoped implementation** — 10 todo tasks, SU-05041 through SU-05050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P11-G01-W06 — Architecture integration** — 10 todo tasks, SU-05051 through SU-05060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P11-G01-W07 — Behavior verification** — 10 todo tasks, SU-05061 through SU-05070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P11-G01-W08 — Security and release hardening** — 10 todo tasks, SU-05071 through SU-05080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P11-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05081 through SU-05090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P11-G01-W10 — Wave exit gate** — 10 todo tasks, SU-05091 through SU-05100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P11-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: GitHub Account and Org Admin Hub.

- **P11-G02-W01 — Scope and objective** — 10 todo tasks, SU-05101 through SU-05110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P11-G02-W02 — Evidence inventory** — 10 todo tasks, SU-05111 through SU-05120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P11-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-05121 through SU-05130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P11-G02-W04 — Native design** — 10 todo tasks, SU-05131 through SU-05140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P11-G02-W05 — Scoped implementation** — 10 todo tasks, SU-05141 through SU-05150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P11-G02-W06 — Architecture integration** — 10 todo tasks, SU-05151 through SU-05160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P11-G02-W07 — Behavior verification** — 10 todo tasks, SU-05161 through SU-05170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P11-G02-W08 — Security and release hardening** — 10 todo tasks, SU-05171 through SU-05180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P11-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05181 through SU-05190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P11-G02-W10 — Wave exit gate** — 10 todo tasks, SU-05191 through SU-05200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P11-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: GitHub Account and Org Admin Hub.

- **P11-G03-W01 — Scope and objective** — 10 todo tasks, SU-05201 through SU-05210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P11-G03-W02 — Evidence inventory** — 10 todo tasks, SU-05211 through SU-05220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P11-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-05221 through SU-05230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P11-G03-W04 — Native design** — 10 todo tasks, SU-05231 through SU-05240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P11-G03-W05 — Scoped implementation** — 10 todo tasks, SU-05241 through SU-05250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P11-G03-W06 — Architecture integration** — 10 todo tasks, SU-05251 through SU-05260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P11-G03-W07 — Behavior verification** — 10 todo tasks, SU-05261 through SU-05270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P11-G03-W08 — Security and release hardening** — 10 todo tasks, SU-05271 through SU-05280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P11-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05281 through SU-05290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P11-G03-W10 — Wave exit gate** — 10 todo tasks, SU-05291 through SU-05300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P11-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: GitHub Account and Org Admin Hub.

- **P11-G04-W01 — Scope and objective** — 10 todo tasks, SU-05301 through SU-05310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P11-G04-W02 — Evidence inventory** — 10 todo tasks, SU-05311 through SU-05320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P11-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-05321 through SU-05330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P11-G04-W04 — Native design** — 10 todo tasks, SU-05331 through SU-05340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P11-G04-W05 — Scoped implementation** — 10 todo tasks, SU-05341 through SU-05350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P11-G04-W06 — Architecture integration** — 10 todo tasks, SU-05351 through SU-05360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P11-G04-W07 — Behavior verification** — 10 todo tasks, SU-05361 through SU-05370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P11-G04-W08 — Security and release hardening** — 10 todo tasks, SU-05371 through SU-05380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P11-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05381 through SU-05390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P11-G04-W10 — Wave exit gate** — 10 todo tasks, SU-05391 through SU-05400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P11-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: GitHub Account and Org Admin Hub.

- **P11-G05-W01 — Scope and objective** — 10 todo tasks, SU-05401 through SU-05410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P11-G05-W02 — Evidence inventory** — 10 todo tasks, SU-05411 through SU-05420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P11-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-05421 through SU-05430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P11-G05-W04 — Native design** — 10 todo tasks, SU-05431 through SU-05440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P11-G05-W05 — Scoped implementation** — 10 todo tasks, SU-05441 through SU-05450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P11-G05-W06 — Architecture integration** — 10 todo tasks, SU-05451 through SU-05460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P11-G05-W07 — Behavior verification** — 10 todo tasks, SU-05461 through SU-05470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P11-G05-W08 — Security and release hardening** — 10 todo tasks, SU-05471 through SU-05480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P11-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05481 through SU-05490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P11-G05-W10 — Wave exit gate** — 10 todo tasks, SU-05491 through SU-05500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P12 — Issues, Bugs, and Incident Hub

Milestone: **Phase 12 exit — Issues, Bugs, and Incident Hub** — Recoverable and fatal results become understandable incident records with resume, retry, evidence, and optional issue drafts while safe unrelated work continues.

#### P12-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Issues, Bugs, and Incident Hub.

- **P12-G01-W01 — Scope and objective** — 10 todo tasks, SU-05501 through SU-05510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P12-G01-W02 — Evidence inventory** — 10 todo tasks, SU-05511 through SU-05520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P12-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-05521 through SU-05530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P12-G01-W04 — Native design** — 10 todo tasks, SU-05531 through SU-05540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P12-G01-W05 — Scoped implementation** — 10 todo tasks, SU-05541 through SU-05550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P12-G01-W06 — Architecture integration** — 10 todo tasks, SU-05551 through SU-05560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P12-G01-W07 — Behavior verification** — 10 todo tasks, SU-05561 through SU-05570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P12-G01-W08 — Security and release hardening** — 10 todo tasks, SU-05571 through SU-05580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P12-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05581 through SU-05590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P12-G01-W10 — Wave exit gate** — 10 todo tasks, SU-05591 through SU-05600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P12-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Issues, Bugs, and Incident Hub.

- **P12-G02-W01 — Scope and objective** — 10 todo tasks, SU-05601 through SU-05610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P12-G02-W02 — Evidence inventory** — 10 todo tasks, SU-05611 through SU-05620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P12-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-05621 through SU-05630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P12-G02-W04 — Native design** — 10 todo tasks, SU-05631 through SU-05640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P12-G02-W05 — Scoped implementation** — 10 todo tasks, SU-05641 through SU-05650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P12-G02-W06 — Architecture integration** — 10 todo tasks, SU-05651 through SU-05660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P12-G02-W07 — Behavior verification** — 10 todo tasks, SU-05661 through SU-05670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P12-G02-W08 — Security and release hardening** — 10 todo tasks, SU-05671 through SU-05680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P12-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05681 through SU-05690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P12-G02-W10 — Wave exit gate** — 10 todo tasks, SU-05691 through SU-05700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P12-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Issues, Bugs, and Incident Hub.

- **P12-G03-W01 — Scope and objective** — 10 todo tasks, SU-05701 through SU-05710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P12-G03-W02 — Evidence inventory** — 10 todo tasks, SU-05711 through SU-05720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P12-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-05721 through SU-05730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P12-G03-W04 — Native design** — 10 todo tasks, SU-05731 through SU-05740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P12-G03-W05 — Scoped implementation** — 10 todo tasks, SU-05741 through SU-05750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P12-G03-W06 — Architecture integration** — 10 todo tasks, SU-05751 through SU-05760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P12-G03-W07 — Behavior verification** — 10 todo tasks, SU-05761 through SU-05770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P12-G03-W08 — Security and release hardening** — 10 todo tasks, SU-05771 through SU-05780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P12-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05781 through SU-05790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P12-G03-W10 — Wave exit gate** — 10 todo tasks, SU-05791 through SU-05800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P12-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Issues, Bugs, and Incident Hub.

- **P12-G04-W01 — Scope and objective** — 10 todo tasks, SU-05801 through SU-05810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P12-G04-W02 — Evidence inventory** — 10 todo tasks, SU-05811 through SU-05820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P12-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-05821 through SU-05830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P12-G04-W04 — Native design** — 10 todo tasks, SU-05831 through SU-05840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P12-G04-W05 — Scoped implementation** — 10 todo tasks, SU-05841 through SU-05850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P12-G04-W06 — Architecture integration** — 10 todo tasks, SU-05851 through SU-05860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P12-G04-W07 — Behavior verification** — 10 todo tasks, SU-05861 through SU-05870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P12-G04-W08 — Security and release hardening** — 10 todo tasks, SU-05871 through SU-05880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P12-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05881 through SU-05890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P12-G04-W10 — Wave exit gate** — 10 todo tasks, SU-05891 through SU-05900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P12-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Issues, Bugs, and Incident Hub.

- **P12-G05-W01 — Scope and objective** — 10 todo tasks, SU-05901 through SU-05910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P12-G05-W02 — Evidence inventory** — 10 todo tasks, SU-05911 through SU-05920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P12-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-05921 through SU-05930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P12-G05-W04 — Native design** — 10 todo tasks, SU-05931 through SU-05940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P12-G05-W05 — Scoped implementation** — 10 todo tasks, SU-05941 through SU-05950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P12-G05-W06 — Architecture integration** — 10 todo tasks, SU-05951 through SU-05960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P12-G05-W07 — Behavior verification** — 10 todo tasks, SU-05961 through SU-05970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P12-G05-W08 — Security and release hardening** — 10 todo tasks, SU-05971 through SU-05980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P12-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-05981 through SU-05990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P12-G05-W10 — Wave exit gate** — 10 todo tasks, SU-05991 through SU-06000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P13 — Deep Research Workspace

Milestone: **Phase 13 exit — Deep Research Workspace** — Metadata-first source snapshots, deterministic Smart Logic, local research, active-tool discovery, and evidence views prevent false-positive repository promotion.

#### P13-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Deep Research Workspace.

- **P13-G01-W01 — Scope and objective** — 10 todo tasks, SU-06001 through SU-06010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P13-G01-W02 — Evidence inventory** — 10 todo tasks, SU-06011 through SU-06020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P13-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-06021 through SU-06030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P13-G01-W04 — Native design** — 10 todo tasks, SU-06031 through SU-06040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P13-G01-W05 — Scoped implementation** — 10 todo tasks, SU-06041 through SU-06050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P13-G01-W06 — Architecture integration** — 10 todo tasks, SU-06051 through SU-06060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P13-G01-W07 — Behavior verification** — 10 todo tasks, SU-06061 through SU-06070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P13-G01-W08 — Security and release hardening** — 10 todo tasks, SU-06071 through SU-06080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P13-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06081 through SU-06090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P13-G01-W10 — Wave exit gate** — 10 todo tasks, SU-06091 through SU-06100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P13-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Deep Research Workspace.

- **P13-G02-W01 — Scope and objective** — 10 todo tasks, SU-06101 through SU-06110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P13-G02-W02 — Evidence inventory** — 10 todo tasks, SU-06111 through SU-06120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P13-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-06121 through SU-06130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P13-G02-W04 — Native design** — 10 todo tasks, SU-06131 through SU-06140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P13-G02-W05 — Scoped implementation** — 10 todo tasks, SU-06141 through SU-06150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P13-G02-W06 — Architecture integration** — 10 todo tasks, SU-06151 through SU-06160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P13-G02-W07 — Behavior verification** — 10 todo tasks, SU-06161 through SU-06170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P13-G02-W08 — Security and release hardening** — 10 todo tasks, SU-06171 through SU-06180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P13-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06181 through SU-06190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P13-G02-W10 — Wave exit gate** — 10 todo tasks, SU-06191 through SU-06200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P13-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Deep Research Workspace.

- **P13-G03-W01 — Scope and objective** — 10 todo tasks, SU-06201 through SU-06210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P13-G03-W02 — Evidence inventory** — 10 todo tasks, SU-06211 through SU-06220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P13-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-06221 through SU-06230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P13-G03-W04 — Native design** — 10 todo tasks, SU-06231 through SU-06240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P13-G03-W05 — Scoped implementation** — 10 todo tasks, SU-06241 through SU-06250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P13-G03-W06 — Architecture integration** — 10 todo tasks, SU-06251 through SU-06260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P13-G03-W07 — Behavior verification** — 10 todo tasks, SU-06261 through SU-06270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P13-G03-W08 — Security and release hardening** — 10 todo tasks, SU-06271 through SU-06280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P13-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06281 through SU-06290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P13-G03-W10 — Wave exit gate** — 10 todo tasks, SU-06291 through SU-06300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P13-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Deep Research Workspace.

- **P13-G04-W01 — Scope and objective** — 10 todo tasks, SU-06301 through SU-06310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P13-G04-W02 — Evidence inventory** — 10 todo tasks, SU-06311 through SU-06320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P13-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-06321 through SU-06330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P13-G04-W04 — Native design** — 10 todo tasks, SU-06331 through SU-06340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P13-G04-W05 — Scoped implementation** — 10 todo tasks, SU-06341 through SU-06350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P13-G04-W06 — Architecture integration** — 10 todo tasks, SU-06351 through SU-06360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P13-G04-W07 — Behavior verification** — 10 todo tasks, SU-06361 through SU-06370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P13-G04-W08 — Security and release hardening** — 10 todo tasks, SU-06371 through SU-06380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P13-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06381 through SU-06390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P13-G04-W10 — Wave exit gate** — 10 todo tasks, SU-06391 through SU-06400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P13-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Deep Research Workspace.

- **P13-G05-W01 — Scope and objective** — 10 todo tasks, SU-06401 through SU-06410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P13-G05-W02 — Evidence inventory** — 10 todo tasks, SU-06411 through SU-06420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P13-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-06421 through SU-06430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P13-G05-W04 — Native design** — 10 todo tasks, SU-06431 through SU-06440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P13-G05-W05 — Scoped implementation** — 10 todo tasks, SU-06441 through SU-06450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P13-G05-W06 — Architecture integration** — 10 todo tasks, SU-06451 through SU-06460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P13-G05-W07 — Behavior verification** — 10 todo tasks, SU-06461 through SU-06470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P13-G05-W08 — Security and release hardening** — 10 todo tasks, SU-06471 through SU-06480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P13-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06481 through SU-06490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P13-G05-W10 — Wave exit gate** — 10 todo tasks, SU-06491 through SU-06500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P14 — Secrets, Variables, Policies, and Rules

Milestone: **Phase 14 exit — Secrets, Variables, Policies, and Rules** — High-impact GitHub governance is visible, permission-aware, and explicitly reviewed before writes.

#### P14-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Secrets, Variables, Policies, and Rules.

- **P14-G01-W01 — Scope and objective** — 10 todo tasks, SU-06501 through SU-06510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P14-G01-W02 — Evidence inventory** — 10 todo tasks, SU-06511 through SU-06520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P14-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-06521 through SU-06530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P14-G01-W04 — Native design** — 10 todo tasks, SU-06531 through SU-06540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P14-G01-W05 — Scoped implementation** — 10 todo tasks, SU-06541 through SU-06550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P14-G01-W06 — Architecture integration** — 10 todo tasks, SU-06551 through SU-06560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P14-G01-W07 — Behavior verification** — 10 todo tasks, SU-06561 through SU-06570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P14-G01-W08 — Security and release hardening** — 10 todo tasks, SU-06571 through SU-06580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P14-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06581 through SU-06590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P14-G01-W10 — Wave exit gate** — 10 todo tasks, SU-06591 through SU-06600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P14-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Secrets, Variables, Policies, and Rules.

- **P14-G02-W01 — Scope and objective** — 10 todo tasks, SU-06601 through SU-06610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P14-G02-W02 — Evidence inventory** — 10 todo tasks, SU-06611 through SU-06620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P14-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-06621 through SU-06630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P14-G02-W04 — Native design** — 10 todo tasks, SU-06631 through SU-06640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P14-G02-W05 — Scoped implementation** — 10 todo tasks, SU-06641 through SU-06650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P14-G02-W06 — Architecture integration** — 10 todo tasks, SU-06651 through SU-06660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P14-G02-W07 — Behavior verification** — 10 todo tasks, SU-06661 through SU-06670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P14-G02-W08 — Security and release hardening** — 10 todo tasks, SU-06671 through SU-06680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P14-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06681 through SU-06690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P14-G02-W10 — Wave exit gate** — 10 todo tasks, SU-06691 through SU-06700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P14-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Secrets, Variables, Policies, and Rules.

- **P14-G03-W01 — Scope and objective** — 10 todo tasks, SU-06701 through SU-06710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P14-G03-W02 — Evidence inventory** — 10 todo tasks, SU-06711 through SU-06720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P14-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-06721 through SU-06730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P14-G03-W04 — Native design** — 10 todo tasks, SU-06731 through SU-06740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P14-G03-W05 — Scoped implementation** — 10 todo tasks, SU-06741 through SU-06750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P14-G03-W06 — Architecture integration** — 10 todo tasks, SU-06751 through SU-06760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P14-G03-W07 — Behavior verification** — 10 todo tasks, SU-06761 through SU-06770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P14-G03-W08 — Security and release hardening** — 10 todo tasks, SU-06771 through SU-06780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P14-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06781 through SU-06790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P14-G03-W10 — Wave exit gate** — 10 todo tasks, SU-06791 through SU-06800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P14-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Secrets, Variables, Policies, and Rules.

- **P14-G04-W01 — Scope and objective** — 10 todo tasks, SU-06801 through SU-06810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P14-G04-W02 — Evidence inventory** — 10 todo tasks, SU-06811 through SU-06820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P14-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-06821 through SU-06830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P14-G04-W04 — Native design** — 10 todo tasks, SU-06831 through SU-06840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P14-G04-W05 — Scoped implementation** — 10 todo tasks, SU-06841 through SU-06850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P14-G04-W06 — Architecture integration** — 10 todo tasks, SU-06851 through SU-06860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P14-G04-W07 — Behavior verification** — 10 todo tasks, SU-06861 through SU-06870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P14-G04-W08 — Security and release hardening** — 10 todo tasks, SU-06871 through SU-06880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P14-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06881 through SU-06890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P14-G04-W10 — Wave exit gate** — 10 todo tasks, SU-06891 through SU-06900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P14-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Secrets, Variables, Policies, and Rules.

- **P14-G05-W01 — Scope and objective** — 10 todo tasks, SU-06901 through SU-06910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P14-G05-W02 — Evidence inventory** — 10 todo tasks, SU-06911 through SU-06920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P14-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-06921 through SU-06930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P14-G05-W04 — Native design** — 10 todo tasks, SU-06931 through SU-06940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P14-G05-W05 — Scoped implementation** — 10 todo tasks, SU-06941 through SU-06950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P14-G05-W06 — Architecture integration** — 10 todo tasks, SU-06951 through SU-06960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P14-G05-W07 — Behavior verification** — 10 todo tasks, SU-06961 through SU-06970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P14-G05-W08 — Security and release hardening** — 10 todo tasks, SU-06971 through SU-06980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P14-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-06981 through SU-06990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P14-G05-W10 — Wave exit gate** — 10 todo tasks, SU-06991 through SU-07000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P15 — Local Files, Backups, Snapshots, and Restore

Milestone: **Phase 15 exit — Local Files, Backups, Snapshots, and Restore** — A dedicated Project Backups dashboard composes import, index, decision, transfer, merge, verify, archive, jobs, snapshots, and recovery without repackaging canonical directories.

#### P15-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Local Files, Backups, Snapshots, and Restore.

- **P15-G01-W01 — Scope and objective** — 10 todo tasks, SU-07001 through SU-07010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P15-G01-W02 — Evidence inventory** — 10 todo tasks, SU-07011 through SU-07020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P15-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-07021 through SU-07030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P15-G01-W04 — Native design** — 10 todo tasks, SU-07031 through SU-07040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P15-G01-W05 — Scoped implementation** — 10 todo tasks, SU-07041 through SU-07050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P15-G01-W06 — Architecture integration** — 10 todo tasks, SU-07051 through SU-07060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P15-G01-W07 — Behavior verification** — 10 todo tasks, SU-07061 through SU-07070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P15-G01-W08 — Security and release hardening** — 10 todo tasks, SU-07071 through SU-07080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P15-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07081 through SU-07090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P15-G01-W10 — Wave exit gate** — 10 todo tasks, SU-07091 through SU-07100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P15-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Local Files, Backups, Snapshots, and Restore.

- **P15-G02-W01 — Scope and objective** — 10 todo tasks, SU-07101 through SU-07110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P15-G02-W02 — Evidence inventory** — 10 todo tasks, SU-07111 through SU-07120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P15-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-07121 through SU-07130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P15-G02-W04 — Native design** — 10 todo tasks, SU-07131 through SU-07140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P15-G02-W05 — Scoped implementation** — 10 todo tasks, SU-07141 through SU-07150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P15-G02-W06 — Architecture integration** — 10 todo tasks, SU-07151 through SU-07160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P15-G02-W07 — Behavior verification** — 10 todo tasks, SU-07161 through SU-07170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P15-G02-W08 — Security and release hardening** — 10 todo tasks, SU-07171 through SU-07180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P15-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07181 through SU-07190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P15-G02-W10 — Wave exit gate** — 10 todo tasks, SU-07191 through SU-07200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P15-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Local Files, Backups, Snapshots, and Restore.

- **P15-G03-W01 — Scope and objective** — 10 todo tasks, SU-07201 through SU-07210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P15-G03-W02 — Evidence inventory** — 10 todo tasks, SU-07211 through SU-07220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P15-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-07221 through SU-07230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P15-G03-W04 — Native design** — 10 todo tasks, SU-07231 through SU-07240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P15-G03-W05 — Scoped implementation** — 10 todo tasks, SU-07241 through SU-07250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P15-G03-W06 — Architecture integration** — 10 todo tasks, SU-07251 through SU-07260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P15-G03-W07 — Behavior verification** — 10 todo tasks, SU-07261 through SU-07270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P15-G03-W08 — Security and release hardening** — 10 todo tasks, SU-07271 through SU-07280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P15-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07281 through SU-07290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P15-G03-W10 — Wave exit gate** — 10 todo tasks, SU-07291 through SU-07300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P15-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Local Files, Backups, Snapshots, and Restore.

- **P15-G04-W01 — Scope and objective** — 10 todo tasks, SU-07301 through SU-07310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P15-G04-W02 — Evidence inventory** — 10 todo tasks, SU-07311 through SU-07320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P15-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-07321 through SU-07330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P15-G04-W04 — Native design** — 10 todo tasks, SU-07331 through SU-07340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P15-G04-W05 — Scoped implementation** — 10 todo tasks, SU-07341 through SU-07350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P15-G04-W06 — Architecture integration** — 10 todo tasks, SU-07351 through SU-07360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P15-G04-W07 — Behavior verification** — 10 todo tasks, SU-07361 through SU-07370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P15-G04-W08 — Security and release hardening** — 10 todo tasks, SU-07371 through SU-07380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P15-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07381 through SU-07390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P15-G04-W10 — Wave exit gate** — 10 todo tasks, SU-07391 through SU-07400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P15-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Local Files, Backups, Snapshots, and Restore.

- **P15-G05-W01 — Scope and objective** — 10 todo tasks, SU-07401 through SU-07410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P15-G05-W02 — Evidence inventory** — 10 todo tasks, SU-07411 through SU-07420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P15-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-07421 through SU-07430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P15-G05-W04 — Native design** — 10 todo tasks, SU-07431 through SU-07440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P15-G05-W05 — Scoped implementation** — 10 todo tasks, SU-07441 through SU-07450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P15-G05-W06 — Architecture integration** — 10 todo tasks, SU-07451 through SU-07460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P15-G05-W07 — Behavior verification** — 10 todo tasks, SU-07461 through SU-07470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P15-G05-W08 — Security and release hardening** — 10 todo tasks, SU-07471 through SU-07480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P15-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07481 through SU-07490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P15-G05-W10 — Wave exit gate** — 10 todo tasks, SU-07491 through SU-07500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P16 — Native Windows Desktop GUI

Milestone: **Phase 16 exit — Native Windows Desktop GUI** — Windows receives the same GUI-first operator experience over the existing PowerShell backend contract.

#### P16-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Native Windows Desktop GUI.

- **P16-G01-W01 — Scope and objective** — 10 todo tasks, SU-07501 through SU-07510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P16-G01-W02 — Evidence inventory** — 10 todo tasks, SU-07511 through SU-07520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P16-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-07521 through SU-07530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P16-G01-W04 — Native design** — 10 todo tasks, SU-07531 through SU-07540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P16-G01-W05 — Scoped implementation** — 10 todo tasks, SU-07541 through SU-07550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P16-G01-W06 — Architecture integration** — 10 todo tasks, SU-07551 through SU-07560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P16-G01-W07 — Behavior verification** — 10 todo tasks, SU-07561 through SU-07570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P16-G01-W08 — Security and release hardening** — 10 todo tasks, SU-07571 through SU-07580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P16-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07581 through SU-07590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P16-G01-W10 — Wave exit gate** — 10 todo tasks, SU-07591 through SU-07600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P16-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Native Windows Desktop GUI.

- **P16-G02-W01 — Scope and objective** — 10 todo tasks, SU-07601 through SU-07610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P16-G02-W02 — Evidence inventory** — 10 todo tasks, SU-07611 through SU-07620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P16-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-07621 through SU-07630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P16-G02-W04 — Native design** — 10 todo tasks, SU-07631 through SU-07640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P16-G02-W05 — Scoped implementation** — 10 todo tasks, SU-07641 through SU-07650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P16-G02-W06 — Architecture integration** — 10 todo tasks, SU-07651 through SU-07660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P16-G02-W07 — Behavior verification** — 10 todo tasks, SU-07661 through SU-07670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P16-G02-W08 — Security and release hardening** — 10 todo tasks, SU-07671 through SU-07680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P16-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07681 through SU-07690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P16-G02-W10 — Wave exit gate** — 10 todo tasks, SU-07691 through SU-07700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P16-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Native Windows Desktop GUI.

- **P16-G03-W01 — Scope and objective** — 10 todo tasks, SU-07701 through SU-07710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P16-G03-W02 — Evidence inventory** — 10 todo tasks, SU-07711 through SU-07720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P16-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-07721 through SU-07730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P16-G03-W04 — Native design** — 10 todo tasks, SU-07731 through SU-07740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P16-G03-W05 — Scoped implementation** — 10 todo tasks, SU-07741 through SU-07750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P16-G03-W06 — Architecture integration** — 10 todo tasks, SU-07751 through SU-07760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P16-G03-W07 — Behavior verification** — 10 todo tasks, SU-07761 through SU-07770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P16-G03-W08 — Security and release hardening** — 10 todo tasks, SU-07771 through SU-07780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P16-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07781 through SU-07790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P16-G03-W10 — Wave exit gate** — 10 todo tasks, SU-07791 through SU-07800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P16-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Native Windows Desktop GUI.

- **P16-G04-W01 — Scope and objective** — 10 todo tasks, SU-07801 through SU-07810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P16-G04-W02 — Evidence inventory** — 10 todo tasks, SU-07811 through SU-07820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P16-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-07821 through SU-07830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P16-G04-W04 — Native design** — 10 todo tasks, SU-07831 through SU-07840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P16-G04-W05 — Scoped implementation** — 10 todo tasks, SU-07841 through SU-07850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P16-G04-W06 — Architecture integration** — 10 todo tasks, SU-07851 through SU-07860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P16-G04-W07 — Behavior verification** — 10 todo tasks, SU-07861 through SU-07870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P16-G04-W08 — Security and release hardening** — 10 todo tasks, SU-07871 through SU-07880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P16-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07881 through SU-07890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P16-G04-W10 — Wave exit gate** — 10 todo tasks, SU-07891 through SU-07900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P16-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Native Windows Desktop GUI.

- **P16-G05-W01 — Scope and objective** — 10 todo tasks, SU-07901 through SU-07910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P16-G05-W02 — Evidence inventory** — 10 todo tasks, SU-07911 through SU-07920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P16-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-07921 through SU-07930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P16-G05-W04 — Native design** — 10 todo tasks, SU-07931 through SU-07940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P16-G05-W05 — Scoped implementation** — 10 todo tasks, SU-07941 through SU-07950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P16-G05-W06 — Architecture integration** — 10 todo tasks, SU-07951 through SU-07960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P16-G05-W07 — Behavior verification** — 10 todo tasks, SU-07961 through SU-07970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P16-G05-W08 — Security and release hardening** — 10 todo tasks, SU-07971 through SU-07980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P16-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-07981 through SU-07990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P16-G05-W10 — Wave exit gate** — 10 todo tasks, SU-07991 through SU-08000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P17 — Packaging, Signing, Notarization, and Trusted Updates

Milestone: **Phase 17 exit — Packaging, Signing, Notarization, and Trusted Updates** — macOS and Windows distribution is verifiable, signed or trust-anchored, versioned, and update-safe.

#### P17-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Packaging, Signing, Notarization, and Trusted Updates.

- **P17-G01-W01 — Scope and objective** — 10 todo tasks, SU-08001 through SU-08010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P17-G01-W02 — Evidence inventory** — 10 todo tasks, SU-08011 through SU-08020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P17-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-08021 through SU-08030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P17-G01-W04 — Native design** — 10 todo tasks, SU-08031 through SU-08040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P17-G01-W05 — Scoped implementation** — 10 todo tasks, SU-08041 through SU-08050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P17-G01-W06 — Architecture integration** — 10 todo tasks, SU-08051 through SU-08060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P17-G01-W07 — Behavior verification** — 10 todo tasks, SU-08061 through SU-08070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P17-G01-W08 — Security and release hardening** — 10 todo tasks, SU-08071 through SU-08080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P17-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08081 through SU-08090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P17-G01-W10 — Wave exit gate** — 10 todo tasks, SU-08091 through SU-08100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P17-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Packaging, Signing, Notarization, and Trusted Updates.

- **P17-G02-W01 — Scope and objective** — 10 todo tasks, SU-08101 through SU-08110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P17-G02-W02 — Evidence inventory** — 10 todo tasks, SU-08111 through SU-08120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P17-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-08121 through SU-08130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P17-G02-W04 — Native design** — 10 todo tasks, SU-08131 through SU-08140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P17-G02-W05 — Scoped implementation** — 10 todo tasks, SU-08141 through SU-08150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P17-G02-W06 — Architecture integration** — 10 todo tasks, SU-08151 through SU-08160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P17-G02-W07 — Behavior verification** — 10 todo tasks, SU-08161 through SU-08170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P17-G02-W08 — Security and release hardening** — 10 todo tasks, SU-08171 through SU-08180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P17-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08181 through SU-08190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P17-G02-W10 — Wave exit gate** — 10 todo tasks, SU-08191 through SU-08200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P17-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Packaging, Signing, Notarization, and Trusted Updates.

- **P17-G03-W01 — Scope and objective** — 10 todo tasks, SU-08201 through SU-08210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P17-G03-W02 — Evidence inventory** — 10 todo tasks, SU-08211 through SU-08220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P17-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-08221 through SU-08230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P17-G03-W04 — Native design** — 10 todo tasks, SU-08231 through SU-08240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P17-G03-W05 — Scoped implementation** — 10 todo tasks, SU-08241 through SU-08250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P17-G03-W06 — Architecture integration** — 10 todo tasks, SU-08251 through SU-08260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P17-G03-W07 — Behavior verification** — 10 todo tasks, SU-08261 through SU-08270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P17-G03-W08 — Security and release hardening** — 10 todo tasks, SU-08271 through SU-08280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P17-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08281 through SU-08290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P17-G03-W10 — Wave exit gate** — 10 todo tasks, SU-08291 through SU-08300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P17-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Packaging, Signing, Notarization, and Trusted Updates.

- **P17-G04-W01 — Scope and objective** — 10 todo tasks, SU-08301 through SU-08310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P17-G04-W02 — Evidence inventory** — 10 todo tasks, SU-08311 through SU-08320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P17-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-08321 through SU-08330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P17-G04-W04 — Native design** — 10 todo tasks, SU-08331 through SU-08340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P17-G04-W05 — Scoped implementation** — 10 todo tasks, SU-08341 through SU-08350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P17-G04-W06 — Architecture integration** — 10 todo tasks, SU-08351 through SU-08360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P17-G04-W07 — Behavior verification** — 10 todo tasks, SU-08361 through SU-08370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P17-G04-W08 — Security and release hardening** — 10 todo tasks, SU-08371 through SU-08380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P17-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08381 through SU-08390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P17-G04-W10 — Wave exit gate** — 10 todo tasks, SU-08391 through SU-08400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P17-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Packaging, Signing, Notarization, and Trusted Updates.

- **P17-G05-W01 — Scope and objective** — 10 todo tasks, SU-08401 through SU-08410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P17-G05-W02 — Evidence inventory** — 10 todo tasks, SU-08411 through SU-08420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P17-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-08421 through SU-08430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P17-G05-W04 — Native design** — 10 todo tasks, SU-08431 through SU-08440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P17-G05-W05 — Scoped implementation** — 10 todo tasks, SU-08441 through SU-08450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P17-G05-W06 — Architecture integration** — 10 todo tasks, SU-08451 through SU-08460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P17-G05-W07 — Behavior verification** — 10 todo tasks, SU-08461 through SU-08470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P17-G05-W08 — Security and release hardening** — 10 todo tasks, SU-08471 through SU-08480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P17-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08481 through SU-08490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P17-G05-W10 — Wave exit gate** — 10 todo tasks, SU-08491 through SU-08500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P18 — Automated QA and Recovery Testing

Milestone: **Phase 18 exit — Automated QA and Recovery Testing** — Install, GUI, backend, GitHub permission, identity false-positive, index reuse, continuation, move/export, and rollback behavior has repeatable preflight coverage.

#### P18-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Automated QA and Recovery Testing.

- **P18-G01-W01 — Scope and objective** — 10 todo tasks, SU-08501 through SU-08510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P18-G01-W02 — Evidence inventory** — 10 todo tasks, SU-08511 through SU-08520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P18-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-08521 through SU-08530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P18-G01-W04 — Native design** — 10 todo tasks, SU-08531 through SU-08540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P18-G01-W05 — Scoped implementation** — 10 todo tasks, SU-08541 through SU-08550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P18-G01-W06 — Architecture integration** — 10 todo tasks, SU-08551 through SU-08560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P18-G01-W07 — Behavior verification** — 10 todo tasks, SU-08561 through SU-08570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P18-G01-W08 — Security and release hardening** — 10 todo tasks, SU-08571 through SU-08580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P18-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08581 through SU-08590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P18-G01-W10 — Wave exit gate** — 10 todo tasks, SU-08591 through SU-08600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P18-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Automated QA and Recovery Testing.

- **P18-G02-W01 — Scope and objective** — 10 todo tasks, SU-08601 through SU-08610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P18-G02-W02 — Evidence inventory** — 10 todo tasks, SU-08611 through SU-08620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P18-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-08621 through SU-08630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P18-G02-W04 — Native design** — 10 todo tasks, SU-08631 through SU-08640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P18-G02-W05 — Scoped implementation** — 10 todo tasks, SU-08641 through SU-08650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P18-G02-W06 — Architecture integration** — 10 todo tasks, SU-08651 through SU-08660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P18-G02-W07 — Behavior verification** — 10 todo tasks, SU-08661 through SU-08670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P18-G02-W08 — Security and release hardening** — 10 todo tasks, SU-08671 through SU-08680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P18-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08681 through SU-08690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P18-G02-W10 — Wave exit gate** — 10 todo tasks, SU-08691 through SU-08700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P18-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Automated QA and Recovery Testing.

- **P18-G03-W01 — Scope and objective** — 10 todo tasks, SU-08701 through SU-08710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P18-G03-W02 — Evidence inventory** — 10 todo tasks, SU-08711 through SU-08720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P18-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-08721 through SU-08730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P18-G03-W04 — Native design** — 10 todo tasks, SU-08731 through SU-08740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P18-G03-W05 — Scoped implementation** — 10 todo tasks, SU-08741 through SU-08750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P18-G03-W06 — Architecture integration** — 10 todo tasks, SU-08751 through SU-08760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P18-G03-W07 — Behavior verification** — 10 todo tasks, SU-08761 through SU-08770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P18-G03-W08 — Security and release hardening** — 10 todo tasks, SU-08771 through SU-08780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P18-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08781 through SU-08790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P18-G03-W10 — Wave exit gate** — 10 todo tasks, SU-08791 through SU-08800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P18-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Automated QA and Recovery Testing.

- **P18-G04-W01 — Scope and objective** — 10 todo tasks, SU-08801 through SU-08810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P18-G04-W02 — Evidence inventory** — 10 todo tasks, SU-08811 through SU-08820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P18-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-08821 through SU-08830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P18-G04-W04 — Native design** — 10 todo tasks, SU-08831 through SU-08840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P18-G04-W05 — Scoped implementation** — 10 todo tasks, SU-08841 through SU-08850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P18-G04-W06 — Architecture integration** — 10 todo tasks, SU-08851 through SU-08860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P18-G04-W07 — Behavior verification** — 10 todo tasks, SU-08861 through SU-08870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P18-G04-W08 — Security and release hardening** — 10 todo tasks, SU-08871 through SU-08880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P18-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08881 through SU-08890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P18-G04-W10 — Wave exit gate** — 10 todo tasks, SU-08891 through SU-08900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P18-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Automated QA and Recovery Testing.

- **P18-G05-W01 — Scope and objective** — 10 todo tasks, SU-08901 through SU-08910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P18-G05-W02 — Evidence inventory** — 10 todo tasks, SU-08911 through SU-08920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P18-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-08921 through SU-08930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P18-G05-W04 — Native design** — 10 todo tasks, SU-08931 through SU-08940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P18-G05-W05 — Scoped implementation** — 10 todo tasks, SU-08941 through SU-08950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P18-G05-W06 — Architecture integration** — 10 todo tasks, SU-08951 through SU-08960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P18-G05-W07 — Behavior verification** — 10 todo tasks, SU-08961 through SU-08970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P18-G05-W08 — Security and release hardening** — 10 todo tasks, SU-08971 through SU-08980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P18-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-08981 through SU-08990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P18-G05-W10 — Wave exit gate** — 10 todo tasks, SU-08991 through SU-09000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P19 — Collaboration, Templates, and Automation

Milestone: **Phase 19 exit — Collaboration, Templates, and Automation** — Teams can reuse task templates, project presets, workspace configurations, interoperable CLI/editor bridges, and approved automation hooks.

#### P19-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Collaboration, Templates, and Automation.

- **P19-G01-W01 — Scope and objective** — 10 todo tasks, SU-09001 through SU-09010. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P19-G01-W02 — Evidence inventory** — 10 todo tasks, SU-09011 through SU-09020. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P19-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-09021 through SU-09030. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P19-G01-W04 — Native design** — 10 todo tasks, SU-09031 through SU-09040. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P19-G01-W05 — Scoped implementation** — 10 todo tasks, SU-09041 through SU-09050. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P19-G01-W06 — Architecture integration** — 10 todo tasks, SU-09051 through SU-09060. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P19-G01-W07 — Behavior verification** — 10 todo tasks, SU-09061 through SU-09070. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P19-G01-W08 — Security and release hardening** — 10 todo tasks, SU-09071 through SU-09080. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P19-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09081 through SU-09090. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P19-G01-W10 — Wave exit gate** — 10 todo tasks, SU-09091 through SU-09100. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P19-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Collaboration, Templates, and Automation.

- **P19-G02-W01 — Scope and objective** — 10 todo tasks, SU-09101 through SU-09110. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P19-G02-W02 — Evidence inventory** — 10 todo tasks, SU-09111 through SU-09120. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P19-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-09121 through SU-09130. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P19-G02-W04 — Native design** — 10 todo tasks, SU-09131 through SU-09140. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P19-G02-W05 — Scoped implementation** — 10 todo tasks, SU-09141 through SU-09150. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P19-G02-W06 — Architecture integration** — 10 todo tasks, SU-09151 through SU-09160. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P19-G02-W07 — Behavior verification** — 10 todo tasks, SU-09161 through SU-09170. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P19-G02-W08 — Security and release hardening** — 10 todo tasks, SU-09171 through SU-09180. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P19-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09181 through SU-09190. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P19-G02-W10 — Wave exit gate** — 10 todo tasks, SU-09191 through SU-09200. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P19-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Collaboration, Templates, and Automation.

- **P19-G03-W01 — Scope and objective** — 10 todo tasks, SU-09201 through SU-09210. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P19-G03-W02 — Evidence inventory** — 10 todo tasks, SU-09211 through SU-09220. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P19-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-09221 through SU-09230. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P19-G03-W04 — Native design** — 10 todo tasks, SU-09231 through SU-09240. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P19-G03-W05 — Scoped implementation** — 10 todo tasks, SU-09241 through SU-09250. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P19-G03-W06 — Architecture integration** — 10 todo tasks, SU-09251 through SU-09260. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P19-G03-W07 — Behavior verification** — 10 todo tasks, SU-09261 through SU-09270. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P19-G03-W08 — Security and release hardening** — 10 todo tasks, SU-09271 through SU-09280. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P19-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09281 through SU-09290. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P19-G03-W10 — Wave exit gate** — 10 todo tasks, SU-09291 through SU-09300. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P19-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Collaboration, Templates, and Automation.

- **P19-G04-W01 — Scope and objective** — 10 todo tasks, SU-09301 through SU-09310. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P19-G04-W02 — Evidence inventory** — 10 todo tasks, SU-09311 through SU-09320. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P19-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-09321 through SU-09330. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P19-G04-W04 — Native design** — 10 todo tasks, SU-09331 through SU-09340. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P19-G04-W05 — Scoped implementation** — 10 todo tasks, SU-09341 through SU-09350. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P19-G04-W06 — Architecture integration** — 10 todo tasks, SU-09351 through SU-09360. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P19-G04-W07 — Behavior verification** — 10 todo tasks, SU-09361 through SU-09370. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P19-G04-W08 — Security and release hardening** — 10 todo tasks, SU-09371 through SU-09380. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P19-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09381 through SU-09390. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P19-G04-W10 — Wave exit gate** — 10 todo tasks, SU-09391 through SU-09400. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P19-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Collaboration, Templates, and Automation.

- **P19-G05-W01 — Scope and objective** — 10 todo tasks, SU-09401 through SU-09410. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P19-G05-W02 — Evidence inventory** — 10 todo tasks, SU-09411 through SU-09420. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P19-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-09421 through SU-09430. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P19-G05-W04 — Native design** — 10 todo tasks, SU-09431 through SU-09440. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P19-G05-W05 — Scoped implementation** — 10 todo tasks, SU-09441 through SU-09450. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P19-G05-W06 — Architecture integration** — 10 todo tasks, SU-09451 through SU-09460. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P19-G05-W07 — Behavior verification** — 10 todo tasks, SU-09461 through SU-09470. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P19-G05-W08 — Security and release hardening** — 10 todo tasks, SU-09471 through SU-09480. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P19-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09481 through SU-09490. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P19-G05-W10 — Wave exit gate** — 10 todo tasks, SU-09491 through SU-09500. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

### P20 — Product Polish and Best-in-Class Pass

Milestone: **Phase 20 exit — Product Polish and Best-in-Class Pass** — The dashboard grammar, deterministic Smart Logic boundary, onboarding, language, accessibility, recovery, consistency, and public release readiness are complete.

#### P20-G01 — Cross-platform contract and domain model

Resolve the operation, job, receipt, workspace, and recovery contract for the phase. Phase context: Product Polish and Best-in-Class Pass.

- **P20-G01-W01 — Scope and objective** — 10 todo tasks, SU-09501 through SU-09510. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Cross-platform contract and domain model.
- **P20-G01-W02 — Evidence inventory** — 10 todo tasks, SU-09511 through SU-09520. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Cross-platform contract and domain model.
- **P20-G01-W03 — Contract and acceptance** — 10 todo tasks, SU-09521 through SU-09530. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Cross-platform contract and domain model.
- **P20-G01-W04 — Native design** — 10 todo tasks, SU-09531 through SU-09540. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Cross-platform contract and domain model.
- **P20-G01-W05 — Scoped implementation** — 10 todo tasks, SU-09541 through SU-09550. Implement one bounded change in the declared files and lane. Group context: Cross-platform contract and domain model.
- **P20-G01-W06 — Architecture integration** — 10 todo tasks, SU-09551 through SU-09560. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Cross-platform contract and domain model.
- **P20-G01-W07 — Behavior verification** — 10 todo tasks, SU-09561 through SU-09570. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Cross-platform contract and domain model.
- **P20-G01-W08 — Security and release hardening** — 10 todo tasks, SU-09571 through SU-09580. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Cross-platform contract and domain model.
- **P20-G01-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09581 through SU-09590. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Cross-platform contract and domain model.
- **P20-G01-W10 — Wave exit gate** — 10 todo tasks, SU-09591 through SU-09600. Close only when every task is evidenced and the next forward mission is explicit. Group context: Cross-platform contract and domain model.

#### P20-G02 — Native GUI and operator UX

Make the phase observable, usable, accessible, and safely actionable in the native app. Phase context: Product Polish and Best-in-Class Pass.

- **P20-G02-W01 — Scope and objective** — 10 todo tasks, SU-09601 through SU-09610. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Native GUI and operator UX.
- **P20-G02-W02 — Evidence inventory** — 10 todo tasks, SU-09611 through SU-09620. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Native GUI and operator UX.
- **P20-G02-W03 — Contract and acceptance** — 10 todo tasks, SU-09621 through SU-09630. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Native GUI and operator UX.
- **P20-G02-W04 — Native design** — 10 todo tasks, SU-09631 through SU-09640. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Native GUI and operator UX.
- **P20-G02-W05 — Scoped implementation** — 10 todo tasks, SU-09641 through SU-09650. Implement one bounded change in the declared files and lane. Group context: Native GUI and operator UX.
- **P20-G02-W06 — Architecture integration** — 10 todo tasks, SU-09651 through SU-09660. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Native GUI and operator UX.
- **P20-G02-W07 — Behavior verification** — 10 todo tasks, SU-09661 through SU-09670. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Native GUI and operator UX.
- **P20-G02-W08 — Security and release hardening** — 10 todo tasks, SU-09671 through SU-09680. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Native GUI and operator UX.
- **P20-G02-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09681 through SU-09690. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Native GUI and operator UX.
- **P20-G02-W10 — Wave exit gate** — 10 todo tasks, SU-09691 through SU-09700. Close only when every task is evidenced and the next forward mission is explicit. Group context: Native GUI and operator UX.

#### P20-G03 — GitHub and local operations

Extend existing GitHub, filesystem, workspace, runner, and consolidation controls without duplication. Phase context: Product Polish and Best-in-Class Pass.

- **P20-G03-W01 — Scope and objective** — 10 todo tasks, SU-09701 through SU-09710. Turn the phase milestone into a bounded wave objective and stop condition. Group context: GitHub and local operations.
- **P20-G03-W02 — Evidence inventory** — 10 todo tasks, SU-09711 through SU-09720. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: GitHub and local operations.
- **P20-G03-W03 — Contract and acceptance** — 10 todo tasks, SU-09721 through SU-09730. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: GitHub and local operations.
- **P20-G03-W04 — Native design** — 10 todo tasks, SU-09731 through SU-09740. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: GitHub and local operations.
- **P20-G03-W05 — Scoped implementation** — 10 todo tasks, SU-09741 through SU-09750. Implement one bounded change in the declared files and lane. Group context: GitHub and local operations.
- **P20-G03-W06 — Architecture integration** — 10 todo tasks, SU-09751 through SU-09760. Connect the change through existing registries, jobs, receipts, and user flows. Group context: GitHub and local operations.
- **P20-G03-W07 — Behavior verification** — 10 todo tasks, SU-09761 through SU-09770. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: GitHub and local operations.
- **P20-G03-W08 — Security and release hardening** — 10 todo tasks, SU-09771 through SU-09780. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: GitHub and local operations.
- **P20-G03-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09781 through SU-09790. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: GitHub and local operations.
- **P20-G03-W10 — Wave exit gate** — 10 todo tasks, SU-09791 through SU-09800. Close only when every task is evidenced and the next forward mission is explicit. Group context: GitHub and local operations.

#### P20-G04 — Platform runtime and packaging

Cover macOS, Windows, CLI, app bundle, service, install, update, and platform-specific boundaries. Phase context: Product Polish and Best-in-Class Pass.

- **P20-G04-W01 — Scope and objective** — 10 todo tasks, SU-09801 through SU-09810. Turn the phase milestone into a bounded wave objective and stop condition. Group context: Platform runtime and packaging.
- **P20-G04-W02 — Evidence inventory** — 10 todo tasks, SU-09811 through SU-09820. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: Platform runtime and packaging.
- **P20-G04-W03 — Contract and acceptance** — 10 todo tasks, SU-09821 through SU-09830. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: Platform runtime and packaging.
- **P20-G04-W04 — Native design** — 10 todo tasks, SU-09831 through SU-09840. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: Platform runtime and packaging.
- **P20-G04-W05 — Scoped implementation** — 10 todo tasks, SU-09841 through SU-09850. Implement one bounded change in the declared files and lane. Group context: Platform runtime and packaging.
- **P20-G04-W06 — Architecture integration** — 10 todo tasks, SU-09851 through SU-09860. Connect the change through existing registries, jobs, receipts, and user flows. Group context: Platform runtime and packaging.
- **P20-G04-W07 — Behavior verification** — 10 todo tasks, SU-09861 through SU-09870. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: Platform runtime and packaging.
- **P20-G04-W08 — Security and release hardening** — 10 todo tasks, SU-09871 through SU-09880. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: Platform runtime and packaging.
- **P20-G04-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09881 through SU-09890. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: Platform runtime and packaging.
- **P20-G04-W10 — Wave exit gate** — 10 todo tasks, SU-09891 through SU-09900. Close only when every task is evidenced and the next forward mission is explicit. Group context: Platform runtime and packaging.

#### P20-G05 — QA, security, docs, and handoff

Verify behavior, protect the operator boundary, document evidence, and prepare the next mission. Phase context: Product Polish and Best-in-Class Pass.

- **P20-G05-W01 — Scope and objective** — 10 todo tasks, SU-09901 through SU-09910. Turn the phase milestone into a bounded wave objective and stop condition. Group context: QA, security, docs, and handoff.
- **P20-G05-W02 — Evidence inventory** — 10 todo tasks, SU-09911 through SU-09920. Inspect current source, runtime state, dependencies, reports, and prior evidence. Group context: QA, security, docs, and handoff.
- **P20-G05-W03 — Contract and acceptance** — 10 todo tasks, SU-09921 through SU-09930. Define interfaces, invariants, acceptance criteria, risk, and ownership. Group context: QA, security, docs, and handoff.
- **P20-G05-W04 — Native design** — 10 todo tasks, SU-09931 through SU-09940. Choose the smallest extension of existing models, helpers, views, and scripts. Group context: QA, security, docs, and handoff.
- **P20-G05-W05 — Scoped implementation** — 10 todo tasks, SU-09941 through SU-09950. Implement one bounded change in the declared files and lane. Group context: QA, security, docs, and handoff.
- **P20-G05-W06 — Architecture integration** — 10 todo tasks, SU-09951 through SU-09960. Connect the change through existing registries, jobs, receipts, and user flows. Group context: QA, security, docs, and handoff.
- **P20-G05-W07 — Behavior verification** — 10 todo tasks, SU-09961 through SU-09970. Exercise happy paths, failure paths, boundaries, recovery, and cross-platform behavior. Group context: QA, security, docs, and handoff.
- **P20-G05-W08 — Security and release hardening** — 10 todo tasks, SU-09971 through SU-09980. Run secret, authorization, destructive-action, packaging, and regression gates. Group context: QA, security, docs, and handoff.
- **P20-G05-W09 — Evidence and Copilot handoff** — 10 todo tasks, SU-09981 through SU-09990. Record commands, artifacts, decisions, limits, risks, and operator instructions. Group context: QA, security, docs, and handoff.
- **P20-G05-W10 — Wave exit gate** — 10 todo tasks, SU-09991 through SU-10000. Close only when every task is evidenced and the next forward mission is explicit. Group context: QA, security, docs, and handoff.

## Machine-readable source

- [`10000-task-plan.json`](./10000-task-plan.json) contains every task record.
- [`FULL-SU-AGI-OPERATING-CONTRACT.md`](./FULL-SU-AGI-OPERATING-CONTRACT.md) defines the operating rules.
- [`../scripts/forward-todo.mjs`](../scripts/forward-todo.mjs) enforces the local cursor transitions.
- [`../../.github/copilot-instructions.md`](../../.github/copilot-instructions.md) scopes IDE Copilot to the current task.
