Combat Design Document
Into the Dreamlands
Core Philosophy
Combat is a strategic puzzle about resource management and calculated risk. Every decision should feel meaningful, with no optimal strategy that works in all situations. Players succeed through understanding system interactions, not grinding or RNG luck.

1. COMBAT STRUCTURE
1.1 Participants

Two combatants: Player vs Enemy (1v1 only)
Each combatant consists of 6 Body Parts maximum
Each combatant has 3 Heart Points
Combat ends when one combatant reaches 0 Heart Points

1.2 Round Structure
Each round proceeds through these phases in strict order:

Upkeep Phase

Trigger start-of-round effects
Expire end-of-round effects from previous round
Process passive crest effects


Tech Selection Phase

Both combatants simultaneously select one Tech
Techs come from currently equipped Body Parts
Some Techs have requirements (must be met to select)


Attack Assignment Phase

Each combatant assigns any attack rolls from their Tech to enemy Body Parts
Multiple attacks can target the same Body Part
Unassigned attacks are lost


Defense Assignment Phase

Each combatant assigns any defense rolls from their Tech to their own Body Parts
Multiple defenses can protect the same Body Part
Unassigned defenses are lost


Resolution Phase

Roll all dice simultaneously
For each attack: Compare (Attack Roll + Keywords) vs (Target Toughness + Defense Roll)
If attack exceeds threshold: Body Part takes damage
Process damage triggers and state changes
Apply any additional Tech effects


End Phase

Check for combat end (either combatant at 0 HP)
Process end-of-round effects
Increment round counter




2. BODY PARTS
2.1 Properties
Each Body Part has:

Name: Display name
Type: HEAD, BODY, ARM (×2), LEG (×2)
Status: Healthy → Wounded → Maimed
Toughness: Base defense value (typically 1-4)
HP Value: Heart Points lost when Maimed (typically 1-3)
Techs: List of available Techs (typically 1-3)
Tags: Properties for overworld/requirements (STRONG, SCHOLARLY, etc.)

2.2 Damage States

Healthy: Full functionality
Wounded: Still functional, may trigger effects
Maimed: No longer usable, owner loses HP Value in Heart Points

2.3 Body Part Configuration

Combatants may have fewer than 6 Body Parts
Body Parts must be of appropriate types (max 1 HEAD, 1 BODY, 2 ARMS, 2 LEGS)
Empty slots are valid (combatant with only 3 Body Parts is legal)


3. TECHS
3.1 Structure
Each Tech consists of:

Name: Display name
Actions: Ordered list of effects (see 3.2)
Requirements: Conditions to use (see 3.3)
Keywords: Modifiers that affect resolution

3.2 Action Types

Attack Roll: Roll Xd6 for attack (assigned in Attack Phase)
Defense Roll: Roll Xd6 for defense (assigned in Defense Phase)
Gain Crest: Add specified crest to pool
Consume Crest: Remove specified crest from pool (requirement)
Damage Body Part: Direct damage to specific part (no roll)
Heal Body Part: Restore status one step
Special Effect: Unique mechanical effect

3.3 Requirements
Techs may require:

Crests: Minimum count of specific crest type
Body Part Status: Number of Wounded/Maimed parts
Tags: Body Part must have specific tag
Round Count: Only available on certain rounds
Unique: Cannot be used if opponent uses same Tech


4. DICE SYSTEM
4.1 Die Types

d4: Low variance (1-4), reliable
d6: Standard die (1-6), baseline
d8: High variance (1-8), risky

4.2 Rolling

Roll specified number and type of dice
Sum all results for total
Keywords may modify results (see 5.0)

4.3 Attack Resolution
Attack Success if: (Attack Roll + Attack Modifiers) > (Target Toughness + Defense Roll + Defense Modifiers)

5. KEYWORDS
Keywords modify Tech behavior. Examples:

Consistent X: Force all dice to show X
Reliable X-Y: Dice cannot roll below X or above Y
Piercing: Ignore X points of defense
Brutal: +1 damage

6. CREST SYSTEM
6.1 Crest Types
Beneficial (want to accumulate):

Shadow: Defensive utility
Valor: Offensive bonuses
Knowledge: Information/tactical advantage
Cunning: Flexibility/control

Detrimental (want to remove):

Madness: Chaotic effects
Greed: Resource lock
Corruption: Spreading damage

6.2 Crest Mechanics
Each crest has:

Expend Effect: Activated by player choice, removes crest
Passive Effect: May trigger at threshold counts
Stack Limit: None (can accumulate infinitely)

6.3 Example Crest Effects
Shadow

Expend: Target Body Part becomes Untargetable this round
Passive: None

Madness

Expend: Reroll one die (forced), gain random crest
Passive: At 3+, all your dice become "chaotic"

Valor

Expend: +2 to one attack roll
Passive: At 2+, gain +1 die value to all attacks


7. COMBAT FLOW EXAMPLE
Round 1: Upkeep

No effects to process

Round 1: Tech Selection

Player selects "Cleave" from Butcher's Arm
Enemy selects "Shamble" from Zombie Legs

Round 1: Attack Assignment

Player assigns Cleave's 2d6 attack to Enemy's Head
Enemy assigns Shamble's 1d6 attack to Player's Arm

Round 1: Defense Assignment

Player has no defense from Cleave
Enemy assigns Shamble's 1d4 defense to Head

Round 1: Resolution

Player rolls 2d6: [4,3] = 7
Enemy Head has Toughness 2, Defense 1d4: [2] = 2
Total defense: 4
7 > 4, Enemy Head becomes Wounded
Enemy rolls 1d6: [5] = 5
Player Arm has Toughness 3, no defense
5 > 3, Player Arm becomes Wounded

Round 1: End

Check combat end: Both still have HP
Continue to Round 2


8. VICTORY & REWARDS
8.1 Combat End
Combat ends when either combatant reaches 0 Heart Points
8.2 Player Victory

May claim ONE non-Maimed Body Part from enemy
Gains any combat completion rewards (items, progress)
Crests do NOT persist to next combat

8.3 Player Defeat

Returns to wake state
Loses progress in current dream run
Knowledge/routing information persists


9. DESIGN PRINCIPLES

No Dominant Strategy: Rock-paper-scissors dynamics between offensive/defensive/tactical approaches
Meaningful Damage: Every hit matters with only 3 HP and 6 body parts
Calculated Risk: Dice provide uncertainty but not chaos
Build Expression: Body Part collection enables diverse strategies
Readable Complexity: Systems are deep but parseable
Failforward: Defeat teaches rather than frustrates


10. BALANCE TARGETS

Average combat: 3-5 rounds
Player win rate (learning): ~40%
Player win rate (mastered): ~80%
Decisions per round: 3-4 meaningful choices
RNG impact: 30% (tactics > luck)