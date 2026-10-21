1. **Yes, all of them are addressed.** The plan now:
   - explains the magnification as gamescope scaling each window to fill the screen, with smooth filtering and no docking dependence;
   - drops the "design tension" section;
   - sets the width rule to the full `:0` root width with a modest height, and rules out widths between 1201 and the canvas width;
   - notes docked vs undocked for each symptom and adds the undocked check;
   - adds checks that the dialog actually got the requested size, plus the gamescope command-line, scaling-filter and zoom-property captures;
   - tests for width equal to the mocked root width;
   - updates the checklist.

   Both archived review links resolve.

2. **Verdict: approve.**

3. **Yes, it's ready to implement in phases.** First confirm the cause on the Deck. Then build the main fix (full-width dialog, gamescope only) alongside the extra logging. Retest with the on-device checklist. Fall back to checking the Steam overlay opacity tie, then to documenting display-only behavior. Each step has a clear go/no-go check.

4. **STATUS_CHANGE: remove NEEDS REVIEW.** The plan is ready for a human to approve implementation; nothing is implemented yet.

   Two optional nits, neither blocking:
   - Add the `DISPLAY=:0` prefix to the H1 confirmation commands.
   - At implementation time, quote the global input-pick code verbatim. The plan already says to do this.
