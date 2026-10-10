enum SpellVisual { orb, lightning, runes, stars, blade }

SpellVisual spellFor(String jobId) => switch (jobId) {
  'engineer' || 'president' => SpellVisual.lightning,
  'scholar' || 'mage' || 'archmage' => SpellVisual.runes,
  'artist' || 'mentor' || 'doctor' || 'merchant' => SpellVisual.stars,
  'warrior' ||
  'hero' ||
  'paladin' ||
  'ranger' ||
  'ranger_master' ||
  'adventurer' => SpellVisual.blade,
  'alchemist' || 'sage' => SpellVisual.runes,
  'bard' || 'maestro' || 'dancer' || 'celestial_dancer' => SpellVisual.stars,
  'guardian' ||
  'warlord' ||
  'beast_tamer' ||
  'dragon_tamer' => SpellVisual.blade,
  _ => SpellVisual.orb,
};
