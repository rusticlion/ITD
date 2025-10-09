Design Document: Combat Presentation
Core Philosophy: The combat UI must be a clear, unified, and tactile interface that visually reinforces the game's core mechanics. It prioritizes immediate contextual feedback and direct manipulation over abstract menus, ensuring players understand the source and consequence of every action. The flow of a round should feel like a single, seamless sequence of decisions within one consistent space.
1. The Unified View: "The Anatomical Display"
Combat takes place on a single, static screen. There is no switching between views to support the phases of combat - elements update in-place instead.
Layout: The screen is split vertically.
Left Side: The Player's "Dreamform" (a stylized anatomical layout of their equipped Body Parts).
Right Side: The Enemy's "Dreamform" (a mirror image).
Core Components (Always Visible):
Body Parts (BPs): Each combatant's equipped BPs are displayed in their logical anatomical positions (Head, Body, Arms, Legs). Each BP display clearly shows:
Its artwork.
Its current status (e.g., color-coded outline: Green for Healthy, Yellow for Wounded).
Its Toughness value.
Heart Points (HP): Three heart icons are displayed directly below each combatant's Dreamform.
Crest Pools: A dedicated area at the bottom-left of the screen displays the Player's Crests. The bottom-right displays the Enemy's.
Action Bar: A central space at the bottom of the screen that contains the primary interaction button (e.g., "Commit Tech," "Resolve").
2. Round Flow & UI Transformation
The UI will transform in-place to guide the player through the phases of a round.
Visuals: A brief, subtle animation plays to signify the start of a new round. Any passive Crest effects are visually indicated (e.g., Valor crests begin to glow if the 2+ threshold is met, with a "+1 ATK" icon appearing briefly).
Goal: Visually link Techs to their source Body Parts and show the immediate consequence of a selection.
Interaction Flow:
The Player's functional (Healthy/Wounded) Body Parts gain a subtle interactive glow.
On Mouse-Over a BP: A "fan" of Tech cards animates out directly from that BP.
On Click a Tech Card: The card animates to a "Selected Tech" slot near the player's side of the Action Bar.
Instant Feedback: Simultaneously, a "Dice Preview" area appears next to the selected Tech card. This area shows icons of the dice the Tech provides (e.g., two d6 icons, one d4 icon). These icons are animated (rolling/spinning) to signify they are not yet settled.
The player can freely test different Tech selections, with the "Selected Tech" and "Dice Preview" updating in real-time.
When satisfied, the player clicks the central "Commit Tech" button. The enemy's selected Tech card animates into view on their side, and the phase ends.
Goal: Provide the player with perfect knowledge of their own resources and partial knowledge of the enemy's, creating a puzzle of "calculated risk."
Interaction Flow:
Dice Settle:
The Player's dice in their Dice Preview roll and settle on their final values (e.g., the two d6 icons become a static 6 and 2). These now move to a "Dice Shelf" on the player's side of the Action Bar.
The Enemy's dice remain animatedly rolling on their Dice Shelf. The player knows the enemy has a 1d8 attack, but not its value.
Targets Highlighted:
All enemy BPs gain a red "targetable" outline.
All player BPs gain a blue "defendable" outline.
Direct Manipulation:
The player clicks and drags a die with a known value from their shelf.
As they drag, valid "Attack Slots" and "Defense Slots" appear next to the corresponding BPs.
They drop the die into a slot to assign it.
Simultaneous Enemy Action: As the player assigns their dice, the enemy AI simultaneously assigns its unsettled, rolling dice to its chosen targets. The player sees where the enemy is attacking and defending, but not with what strength.
Once all dice from both sides are assigned, the central button glows, now reading "Resolve."
Goal: Provide a clear, dramatic, and easily understandable resolution sequence.
Visual Flow (Automated Sequence):
On clicking "Resolve," all of the enemy's dice settle on their final values.
For each attack in sequence, a visual effect (e.g., a line of energy) connects the attack die to its target BP.
Key numbers are displayed clearly near the target: Attack Roll vs. (Toughness + Defense Roll).
The result is shown with a large, clear graphic ("HIT!", "MISS!", "BLOCKED!").
On a successful hit, the target BP flashes, and its status color/artwork updates.
HP loss is animated by a heart icon cracking or fading away.
After all actions resolve, the UI returns to its neutral state for the next Upkeep phase.
3. Information Display & Keywords
Tooltips are Key: Complexity is managed via contextual tooltips. Mousing over any game piece (a BP, a Tech card, a Crest, a die on the shelf) will provide a detailed "info box."
Communicating Keywords:
When a Tech is selected, its keywords (Piercing, Brutal, etc.) are displayed as icons on the Tech card in the "Selected Tech" slot.
When the dice are generated from that Tech, they inherit these keyword icons. A die on the shelf will have small Piercing or Brutal icons attached to it.
This visually confirms that this specific die carries that specific property. The tooltip for the die will explain the keyword's effect.
Crest Interaction:
The Crest Pool is always visible. Crests can be clicked to expend them during valid phases (primarily the Tech Selection phase).
A glowing aura or similar visual effect will indicate when a Crest's passive effect is active. The tooltip will provide the details.