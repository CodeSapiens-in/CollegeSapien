export type ChallengeId = 'ch01' | 'ch02' | 'ch03' | 'ch04' | 'ch05' | 'ch06' | 'ch07';

export interface Challenge {
  id: ChallengeId;
  name: string;
  points: number;
  // Anonymous challenges form the top of the funnel — no account needed.
  requiresAuth: boolean;
  // Personal flags embed the solver's fingerprint; static flags are shareable.
  personal: boolean;
  teaches: string;
  brief: string;
  hint: string;
}

// Seven challenges on a deliberate difficulty curve. The first three need no
// account so a curious visitor can start immediately; the last four need a
// signed-in student so solves can be attributed to a real person.
//
// ch06 is the one that actually separates talent: it cannot be done by hand,
// it is verified in constant time, and because the seed is derived per-user a
// shared answer is worthless.
export const CHALLENGES: Challenge[] = [
  {
    id: 'ch01',
    name: 'handshake',
    points: 10,
    requiresAuth: false,
    personal: false,
    teaches: 'A response is more than its body.',
    brief: 'You already have the flag. You just are not looking at all of the response.',
    hint: 'curl -i, or the Network tab. Headers count.',
  },
  {
    id: 'ch02',
    name: 'layers',
    points: 20,
    requiresAuth: false,
    personal: false,
    teaches: 'Recognising and peeling common encodings.',
    brief: 'This endpoint returns something wrapped a few times over. Unwrap it.',
    hint: 'Three layers. Two of them are the same idea; the one in between just rotates.',
  },
  {
    id: 'ch03',
    name: 'preconditions',
    points: 30,
    requiresAuth: false,
    personal: false,
    teaches: 'HTTP conditional requests — the part of the spec nobody reads.',
    brief:
      'A plain GET will not do. This resource wants you to prove you know which version you are asking about.',
    hint: 'The 428 response hands you an ETag. Ask again, and say which version you mean.',
  },
  {
    id: 'ch04',
    name: 'token',
    points: 50,
    requiresAuth: true,
    personal: true,
    teaches: 'What is actually inside the token your app sends on every request.',
    brief:
      'Here is a token. It is inert — it authenticates nothing and never will. But it is shaped like the real thing, and it is carrying something.',
    hint: 'Three parts, separated by dots. The middle one is not encrypted, only encoded.',
  },
  {
    id: 'ch05',
    name: 'relay',
    points: 80,
    requiresAuth: true,
    personal: true,
    teaches: 'Driving an HTTP API from code instead of a browser.',
    brief:
      'Fifty hops stand between you and the flag. Each one tells you where to go next. Doing this by hand is possible. It is also a waste of your evening.',
    hint: 'Start the chain, then follow X-Next-Hop until the server stops giving you one.',
  },
  {
    id: 'ch06',
    name: 'grind',
    points: 150,
    requiresAuth: true,
    personal: true,
    teaches: 'Writing real code against a real constraint. This is the one we care about.',
    brief:
      'You get a seed. Find a nonce such that sha256(seed + nonce) begins with enough zeros. Your seed is yours alone, so there is nobody to copy from.',
    hint: 'A loop and a hash function. Any language. It should take seconds, not hours.',
  },
  {
    id: 'ch07',
    name: 'finale',
    points: 200,
    requiresAuth: true,
    personal: true,
    teaches: 'Finishing what you started.',
    brief: 'Solve the other six. Then come back.',
    hint: 'There is no shortcut here, and that is the point.',
  },
];

export const CHALLENGE_BY_ID = new Map<string, Challenge>(CHALLENGES.map(c => [c.id, c]));

export const TOTAL_POINTS = CHALLENGES.reduce((sum, c) => sum + c.points, 0);

// ch05: long enough that scripting beats clicking, short enough to stay polite.
export const RELAY_HOPS = 50;

// ch06: 5 hex zeros is ~1M hashes — seconds in any language, on any laptop.
export const POW_DIFFICULTY = 5;

// Scope statement. Served with every briefing so nobody has to guess what is
// fair game — the difference between a CTF player and an incident is usually
// just that nobody wrote this down.
export const RULES = {
  inScope: [
    'Every endpoint under this CTF service.',
    'The public marketing site, robots.txt and security.txt.',
    'The public source repository.',
  ],
  outOfScope: [
    'The production API, database and storage buckets.',
    'Any other student account, or any real student data.',
    'Denial of service, traffic floods, and load testing of any kind.',
    'Social engineering of students, staff or moderators.',
  ],
  ifYouFindARealBug: [
    'Stop. Do not exploit it, and do not touch anyone else data.',
    'Email security@collegesapien.com with what you found.',
    'A real, responsibly disclosed vulnerability is worth more to us than every flag here combined.',
  ],
  participation: [
    'Playing is voluntary and has nothing to do with your grades or your account standing.',
    'We store which challenges you solved and when, so we can rank and contact you.',
    'Appearing on the leaderboard is opt-in. You can ask us to erase your CTF record at any time.',
  ],
};
