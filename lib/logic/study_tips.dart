// A rotating "study tip of the day". Deterministic per day so it feels stable
// within a day but changes tomorrow.

const studyTips = <String>[
  'Study in short focused blocks — your brain remembers more from 25 focused minutes than an hour of half-attention.',
  'Review new material within 24 hours. A quick recap today saves hours of re-learning later.',
  'Start with the hardest task while your energy is highest.',
  'Teach a concept out loud as if explaining it to a friend — gaps show up fast.',
  'Space out your reviews. Cramming feels productive but fades quickly.',
  'Put your phone in another room during a focus session. Out of sight, out of mind.',
  'Break big assignments into small next-actions. "Write essay" is scary; "outline intro" is doable.',
  'Take real breaks. Stand up, look far away, drink water — then come back sharper.',
  'Turn your notes into questions. Retrieval beats re-reading every time.',
  'Set a tiny goal to start. Momentum is easier to keep than to create.',
  'Sleep is part of studying — memories consolidate overnight.',
  'Mix subjects in a session (interleaving). It feels harder but sticks better.',
  'Reward yourself after finishing a block. Small wins keep you going.',
  'If you\'re stuck, explain the problem from scratch — the answer often appears.',
  'Plan tomorrow tonight. Deciding in advance removes the morning friction.',
];

String tipForDay(DateTime day) {
  final epochDay = DateTime(day.year, day.month, day.day)
      .difference(DateTime(2020, 1, 1))
      .inDays;
  return studyTips[epochDay % studyTips.length];
}
