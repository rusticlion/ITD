Animated Resolution Sequence
Goal: Implement the choreographed, step-by-step resolution sequence to make the results of the round clear and dramatic.
Tasks:
Create a simple animation queue system or use a tweening library.
When the UI receives events from the RESOLUTION phase (DICE_ROLLED, DAMAGE_DEALT), instead of updating the view instantly, add a sequence of animations to the queue.
Implement animations for: dice settling, energy lines connecting attacker to target, "HIT!"/"MISS!" text, BP flashing, and HP loss.
The game's update loop should be blocked from proceeding to the next round until the animation queue is empty.
Deliverables:
The Resolution phase is no longer instantaneous but plays out as a clear and easy-to-follow sequence of events.
The visual feedback makes the outcome of each attack and defense immediately obvious.
Design Notes/Pitfalls:
Engine Decoupling is Paramount: This is the most important architectural constraint. The engine must not wait for animations. It should fire all its resolution events in a single frame and enter the ROUND_END state. The UI layer is solely responsible for catching those events and taking its time to display them visually before allowing the next round to begin (e.g., before sending the "start next round" input if one is needed, or by simply waiting until its queue is clear before rendering the next phase's UI).