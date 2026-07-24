# Validation

## Validation order

Start with the cheapest relevant checks and progress only after they pass:

1. Parser and import resolution.
2. Geometry and topology.
3. Property and boundary-condition coverage.
4. Process-specific convergence.
5. Coupled response and engineering acceptance criteria.
6. Broader regression or parameter sensitivity.

## Console and files

Fail the run when any of these occur:

- The runner times out at an interactive `3dec>` prompt.
- Console output contains a `***` error, bad parameter conversion, traceback, or processing-line error.
- The process returns a nonzero code.
- A new `errorlog.txt` or crash dump is produced.
- The expected `.sav`, CSV, table, or history output is absent or stale.

Do not treat a zero process exit code as sufficient validation.

## Geometry and zoning

Check:

- All imported paths resolve from the intended working directory.
- Geometry is in the expected coordinate system and uses the intended offset.
- Layer order and group coverage match the conceptual model.
- Faults intersect the intended blocks and do not create unintended fragments.
- Zone quality and sizes are appropriate near monitored or loaded locations.
- Block, zone, contact, flow-knot, and flow-plane counts change only as intended.

Inspect plots for material geometry changes. Numerical counts alone cannot detect misplaced surfaces.

## Mechanical calculations

Record at least:

- Mechanical ratio-average and ratio-maximum or the project-selected equivalents.
- Maximum unbalanced force.
- Displacement or velocity at representative locations.
- Contact state, slip, opening, and plastic-zone changes when relevant.

Use a project-defined convergence target. Confirm that important response histories have stabilized and that the result is insensitive to a reasonable extension of cycling.

Very large contact stiffness can reduce the stable timestep without materially improving behavior. Very small normal stiffness can permit excessive interpenetration. Compare contact displacement with adjacent zone size and perform stiffness sensitivity when stiffness is not calibrated.

## Fluid calculations

Cycle count is a numerical effort measure, not a physical-time criterion.

Record:

- `model history fluid time-total`.
- Pore-pressure histories at several representative locations and units.
- Maximum pore-pressure change over a final cycle batch.
- Current unbalanced flow volume, such as the maximum absolute `flowknot.vol.unbal` across knots, when supported.
- Applied and discharged fluid-volume balance when sources or sinks exist.

For initialization or steady-state adjustment, continue for another batch and compare the new pressure field with the previous checkpoint. Accept the earlier checkpoint only when the change is below a project-defined absolute and relative tolerance.

Do not use a mechanical ratio as proof of fluid convergence. Verify whether a documented fluid solve ratio is available for the installed 3DEC version before using one.

## Coupled calculations

Check both processes independently:

- Mechanical equilibrium after representative fluid steps.
- Fluid time and pore-pressure stabilization.
- Effective stress, aperture, contact state, and displacement sensitivity.
- Adequacy of mechanical follower/substep limits.

Be careful with `or` solve limits: the first satisfied condition stops the solve. Use `and` only when every specified limit must be reached, and confirm that the command semantics match the installed manual.

## Staged models

For a staged chain:

```text
geometry -> properties -> boundary conditions -> initial state -> loading
```

Validate the changed stage and every downstream stage whose assumptions or restored state changed. Do not rerun unaffected upstream stages unless reproducibility or geometry changes require it.

Record the exact upstream save file used. A stale `.sav` can make a correct downstream script appear valid while bypassing new source changes.

## Repository hygiene

Track source:

- `.dat`, FISH, and project-owned Python scripts.
- Source DXF/STL and other intentional geometry.
- Parameter files, validation scripts, and engineering documentation.

Exclude by default:

- `.sav`, `.temp`, `.backup`, dumps, routine logs, automatic recovery files, and local UI state.
- The runner output directory `.itasca-agent/`.
- Installation paths containing user-specific data.
- License credentials or server details.

Run the repository's whitespace and status checks before commit. Report unrelated working-tree changes without modifying them.
