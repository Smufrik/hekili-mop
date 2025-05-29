-- Rogue: Combat APL
-- Updated May 28, 2025 - Modern Structure
-- MoP Action Priority List v5.4.8

local addon, ns = ...
local Hekili = _G[ addon ]

local class = Hekili.Class
local state = Hekili.State

-- Combat Rogue APL for Mists of Pandaria
spec:RegisterPack( "Combat", 20250528, [[
# Combat Rogue - MoP APL
# Updated May 28, 2025 - Modern Structure

## Pre-combat
actions.precombat+=/apply_poison,lethal=instant,nonlethal=crippling
actions.precombat+=/stealth
actions.precombat+=/slice_and_dice,if=!buff.slice_and_dice.up

## Main rotation
actions+=/kick
actions+=/vanish,if=time>10&!buff.adrenaline_rush.up&cooldown.shadowclone.up&combo_points<=3
actions+=/shadowclone,if=buff.stealth.up|buff.vanish.up
actions+=/adrenaline_rush,if=time>4&(combo_points<=2|energy<=30)
actions+=/killing_spree,if=energy<=30&buff.slice_and_dice.up
actions+=/blade_flurry,if=!buff.blade_flurry.up&spell_targets.blade_flurry>=2
actions+=/blade_flurry,if=buff.blade_flurry.up&spell_targets.blade_flurry=1
actions+=/slice_and_dice,if=combo_points>=1&buff.slice_and_dice.remains<=2
actions+=/revealing_strike,if=!debuff.revealing_strike.up&combo_points<=4
actions+=/eviscerate,if=combo_points>=5&target.time_to_die>6
actions+=/sinister_strike,if=combo_points<=4
actions+=/eviscerate,if=combo_points>=4&target.time_to_die<=6
]] )